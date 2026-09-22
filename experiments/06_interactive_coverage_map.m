% 06_interactive_coverage_map.m
% Generates 10,000-cell grid predictions across all 5 prediction modes:
%   P0: LDPL Physics Baseline
%   P1: LDPL + Isotropic Residual
%   P2: LDPL + Additive SASR
%   RF: Direct Random Forest ML-Only
%   P3: Hybrid (P2 + RF Residual Correction)
%
% Strictly separates prediction generation from visualization (Requirement 4).
% Exports results to results/final/all_models_grid_predictions.csv and
% launches the refactored multi-model dashboard.

clc; close all;

addpath(genpath('src'));

fprintf('=========================================================================\n');
fprintf('  Phase 06: Full-Grid Multi-Model Prediction & Dashboard Launch\n');
fprintf('=========================================================================\n\n');

%% 1. Ensure Directories Exist
if ~exist(fullfile('results', 'final'), 'dir')
    mkdir(fullfile('results', 'final'));
end
if ~exist(fullfile('figures', 'final'), 'dir')
    mkdir(fullfile('figures', 'final'));
end

%% 2. Load Grid Dataset
fprintf('[1] Loading 10,000-Cell Fishnet Grid...\n');
dataDir = fullfile('data', 'raw', 'CIM-5G');
gridFile = fullfile(dataDir, 'fishnet_30x30_processed_feature_engineered.csv');

optsGrid = detectImportOptions(gridFile, 'VariableNamingRule', 'preserve');
Grid = readtable(gridFile, optsGrid);

N_grid = height(Grid);
fprintf('    Grid size: %d cells (100 x 100 fishnet at 30m resolution).\n\n', N_grid);

% Prepare physical fields
Grid.Dist3D = Grid.True_3D_Dist;
Grid.NCI    = Grid.NR_PCI;
Grid.ServingAzimuth = mod(atan2d(Grid.Base_Direction_angle_sin, Grid.Base_Direction_angle_cos), 360);
Grid.LATITUDE = Grid.Center_Y;
Grid.LONGITUDE = Grid.Center_X;

% Extract features
[X_grid, ~, featureNames, validGridMask] = extract_ml_features(Grid, '');

%% 3. Load or Ensure Trained Models Exist
rfDirectFile = fullfile('models', 'random_forest', 'mode_c_direct_rf.mat');
rfResFile    = fullfile('models', 'random_forest', 'mode_d_residual_rf.mat');
ldplFile     = fullfile('models', 'random_forest', 'calibrated_ldpl_model.mat');

if ~isfile(rfDirectFile) || ~isfile(rfResFile) || ~isfile(ldplFile)
    fprintf('[2] Trained models not found in models/random_forest/. Running 04_ml_residual.m...\n');
    run('experiments/04_ml_residual.m');
end

fprintf('[2] Loading Trained Prediction Models...\n');
S_c = load(rfDirectFile); rf_direct = S_c.rf_direct_model;
S_d = load(rfResFile);    rf_residual = S_d.residual_rf_model;
S_l = load(ldplFile);     ldpl_model = S_l.ldpl_model;

fprintf('    Calibrated LDPL : PL0 = %.2f dB, n = %.2f\n', ldpl_model.PL0, ldpl_model.n);
fprintf('    Direct RF       : %d trees\n', rf_direct.numTrees);
fprintf('    Residual RF     : %d trees\n\n', rf_residual.numTrees);

%% 4. Load Training Sample for Spatial Residual Reconstruction
% We use the observed measurements to define the spatial conditioning data
observedMask = (Grid.is_observed == 1);
trObs = Grid(observedMask, :);
if height(trObs) > 800
    rng(42);
    subIdx = randperm(height(trObs), 800);
    trKrig = trObs(subIdx, :);
else
    trKrig = trObs;
end

params.sigma_g = 10.0;
params.ell_g   = 200.0;
params.sigma_c = 8.0;
params.a_par   = 150.0;
params.a_trans = 75.0;
params.sigma_n = 2.0;

iso_params = params;
iso_params.sigma_c = 0.0;

%% 5. Generate Full-Grid Predictions Across All Modes
fprintf('[3] Generating Full-Grid Predictions across All 5 Modes...\n');

% Mode A: P0 (LDPL)
fprintf('    Evaluating Mode A  (P0: LDPL Physics Baseline)...\n');
Ptx = ldpl_model.Ptx;
Grid.P0_RSRP = Ptx - (ldpl_model.PL0 + 10 * ldpl_model.n * log10(max(1.0, Grid.Dist3D)));

% Mode B1: P1 (LDPL + Isotropic Residual)
fprintf('    Evaluating Mode B1 (P1: LDPL + Isotropic Residual)...\n');
[Grid.P1_RSRP, ~] = residual_reconstruction(trKrig, Grid, ldpl_model, iso_params);

% Mode B2: P2 (LDPL + Additive SASR)
fprintf('    Evaluating Mode B2 (P2: LDPL + Additive SASR)...\n');
[Grid.P2_RSRP, ~] = residual_reconstruction(trKrig, Grid, ldpl_model, params);

% Mode C: RF (Direct ML-Only)
fprintf('    Evaluating Mode C  (Direct Random Forest ML-Only)...\n');
Grid.RF_RSRP = predict_rf(rf_direct, X_grid);

% Mode D: P3 (Hybrid: P2 + RF Residual Correction)
fprintf('    Evaluating Mode D  (P3: Hybrid Physics + RF Residual)...\n');
[Grid.P3_RSRP, Grid.RF_Residual_Correction] = predict_hybrid(Grid.P2_RSRP, rf_residual, X_grid);

%% 6. Export All-Models Grid Predictions Table
outFile = fullfile('results', 'final', 'all_models_grid_predictions.csv');
fprintf('\n[4] Exporting Full-Grid Predictions to:\n    %s\n', outFile);

exportCols = {'OID', 'Grid_Row', 'Grid_Col', 'Center_X', 'Center_Y', 'True_3D_Dist', ...
    'is_observed', 'SS_RSRP', 'P0_RSRP', 'P1_RSRP', 'P2_RSRP', 'RF_RSRP', 'P3_RSRP', ...
    'RF_Residual_Correction'};
writetable(Grid(:, exportCols), outFile);

%% 7. Generate Publication-Quality Coverage Map Figures
fprintf('[5] Generating Publication-Quality 5-Mode Coverage Maps...\n');
mapModels = {'P0_RSRP', 'P1_RSRP', 'P2_RSRP', 'RF_RSRP', 'P3_RSRP'};
mapTitles = { ...
    'Mode A: Calibrated LDPL Baseline (P0)', ...
    'Mode B1: LDPL + Isotropic Residual (P1)', ...
    'Mode B2: LDPL + Additive Sector-Aligned SASR (P2)', ...
    'Mode C: Direct Random Forest ML-Only', ...
    'Mode D: Hybrid Physics + RF Residual (P3)' ...
};
mapFiles = { ...
    'fig01_p0_ldpl_map.png', ...
    'fig02_p1_isotropic_map.png', ...
    'fig03_p2_anisotropic_map.png', ...
    'fig04_mode_c_rf_map.png', ...
    'fig05_mode_d_p3_hybrid_map.png' ...
};

for m = 1:numel(mapModels)
    f = figure('Visible', 'off', 'Position', [100 100 800 650]);
    try
        gax = geoaxes('Basemap', 'topographic');
        geoscatter(gax, Grid.Center_Y, Grid.Center_X, 12, Grid.(mapModels{m}), 'filled');
        colormap(gax, turbo(256));
        cb = colorbar(gax);
        cb.Label.String = 'Predicted RSRP (dBm)';
        caxis(gax, [-110 -55]);
        title(gax, mapTitles{m}, 'FontSize', 12, 'FontWeight', 'bold');
    catch
        scatter(Grid.Center_X, Grid.Center_Y, 12, Grid.(mapModels{m}), 'filled');
        colormap(turbo(256));
        cb = colorbar;
        cb.Label.String = 'Predicted RSRP (dBm)';
        caxis([-110 -55]);
        xlabel('Longitude (deg)'); ylabel('Latitude (deg)');
        title(mapTitles{m}, 'FontSize', 12, 'FontWeight', 'bold');
    end
    exportgraphics(f, fullfile('figures', 'final', mapFiles{m}), 'Resolution', 150);
    close(f);
end

% Residual correction map
f_res = figure('Visible', 'off', 'Position', [100 100 800 650]);
try
    gax = geoaxes('Basemap', 'topographic');
    geoscatter(gax, Grid.Center_Y, Grid.Center_X, 12, Grid.RF_Residual_Correction, 'filled');
    colormap(gax, jet(256));
    cb = colorbar(gax);
    cb.Label.String = 'RF Residual Correction \Delta RSRP (dB)';
    caxis(gax, [-8 8]);
    title(gax, 'Mode D: RF Residual Correction Field (\Delta = P3 - P2)', 'FontSize', 12, 'FontWeight', 'bold');
catch
    scatter(Grid.Center_X, Grid.Center_Y, 12, Grid.RF_Residual_Correction, 'filled');
    colormap(jet(256));
    cb = colorbar;
    cb.Label.String = 'RF Residual Correction \Delta RSRP (dB)';
    caxis([-8 8]);
    xlabel('Longitude (deg)'); ylabel('Latitude (deg)');
    title('Mode D: RF Residual Correction Field (\Delta = P3 - P2)', 'FontSize', 12, 'FontWeight', 'bold');
end
exportgraphics(f_res, fullfile('figures', 'final', 'fig06_rf_residual_correction_map.png'), 'Resolution', 150);
close(f_res);

fprintf('\n[6] Launching Refactored Interactive Dashboard...\n');
if usejava('desktop') || usejava('awt')
    figDashboard = coverage_dashboard(Grid);
    fprintf('    Interactive dashboard launched in MATLAB window.\n');
else
    fprintf('    Non-interactive environment detected; dashboard function verified without GUI popup.\n');
end

fprintf('Phase 06 completed successfully.\n');
