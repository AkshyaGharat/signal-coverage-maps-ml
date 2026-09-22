% 05_model_comparison.m
% Standardized Multi-Regime Comparison Across All Five Prediction Modes:
%   Mode A  : P0 (Calibrated LDPL Physics Baseline)
%   Mode B1 : P1 (LDPL + Isotropic Residual Reconstruction)
%   Mode B2 : P2 (LDPL + Additive Sector-Aligned Anisotropic Residual)
%   Mode C  : RF (Direct Random Forest ML-Only)
%   Mode D  : P3 (Hybrid: P2 + RF Residual Correction)
%
% Sampling Regimes:
%   Budgets   : 10%, 5%, 2%, 1%
%   Protocols : Random, Uniform, Clustered
%
% Strictly enforces:
%   - Zero test-set leakage
%   - Genuine out-of-fold P2 training targets for Mode D (Requirement 2)
%   - Measured observations only for evaluation (Requirement 3)
%   - Honest numerical reporting of deltas without subjective hype (Requirement 6 & 7)

clc; close all;

addpath(genpath('src'));

fprintf('=========================================================================\n');
fprintf('  Phase 05: Standardized Multi-Regime 5-Mode Model Comparison\n');
fprintf('=========================================================================\n\n');

%% 1. Ensure Directories Exist
if ~exist(fullfile('results', 'comparison'), 'dir')
    mkdir(fullfile('results', 'comparison'));
end
if ~exist(fullfile('figures', 'comparison'), 'dir')
    mkdir(fullfile('figures', 'comparison'));
end

%% 2. Load Valid Measured Observations
fprintf('[1] Loading Clean Measured CIM-5G Data...\n');
dataDir = fullfile('data', 'raw', 'CIM-5G');
fishnetPath = fullfile(dataDir, 'fishnet_30x30_processed_feature_engineered.csv');

optsFish = detectImportOptions(fishnetPath, 'VariableNamingRule', 'preserve');
rawTable = readtable(fishnetPath, optsFish);

% Requirement 3: Filter strictly to valid measured observations
if ismember('is_observed', rawTable.Properties.VariableNames)
    observedMask = (rawTable.is_observed == 1);
    dataClean = rawTable(observedMask, :);
else
    dataClean = rawTable;
end

dataClean.Dist3D = dataClean.True_3D_Dist;
dataClean.NCI    = dataClean.NR_PCI;
dataClean.ServingAzimuth = mod(atan2d(dataClean.Base_Direction_angle_sin, dataClean.Base_Direction_angle_cos), 360);
dataClean.LATITUDE = dataClean.Center_Y;
dataClean.LONGITUDE = dataClean.Center_X;

[X_all, y_all, featureNames, validMask] = extract_ml_features(dataClean, 'SS_RSRP');
dataClean = dataClean(validMask, :);
X_all = X_all(validMask, :);
y_all = y_all(validMask);

N_total = height(dataClean);
fprintf('    Evaluation Dataset: %d valid measured records.\n\n', N_total);

%% 3. Experimental Parameters
protocols = {'random', 'uniform', 'clustered'};
sampleRatios = [0.10, 0.05, 0.02, 0.01];

% For full evaluation, N_mc = 10 runs per regime
N_mc = 10;

params.sigma_g = 10.0;
params.ell_g   = 200.0;
params.sigma_c = 8.0;
params.a_par   = 150.0;
params.a_trans = 75.0;
params.sigma_n = 2.0;

iso_params = params;
iso_params.sigma_c = 0.0;

rf_opts.numTrees    = 150; % Scaled for Monte Carlo speed
rf_opts.minLeafSize = 10;
rf_opts.featureNames = featureNames;

comparisonResults = struct();
summaryRows = {};

fprintf('[2] Running Monte Carlo Evaluation Across 12 Sampling Regimes...\n');
fprintf('--------------------------------------------------------------------------------------------------------\n');
fprintf('  Protocol   Budget   P0 (LDPL)     P1 (Iso)      P2 (SASR)     RF (Direct)   P3 (Hybrid)   d(P1,P2)  d(P2,P3)\n');
fprintf('--------------------------------------------------------------------------------------------------------\n');

for p = 1:numel(protocols)
    prot = protocols{p};
    for r = 1:numel(sampleRatios)
        sRatio = sampleRatios(r);
        regimeKey = sprintf('%s_%02d', prot, round(sRatio * 100));

        p0_runs  = zeros(N_mc, 1);
        p1_runs  = zeros(N_mc, 1);
        p2_runs  = zeros(N_mc, 1);
        rf_runs  = zeros(N_mc, 1);
        p3_runs  = zeros(N_mc, 1);

        mae_p2_runs = zeros(N_mc, 1);
        mae_p3_runs = zeros(N_mc, 1);

        for s = 1:N_mc
            % Spatial sparse sampling on measured locations
            [trIdx, teIdx] = sparse_sampling(dataClean.LATITUDE, dataClean.LONGITUDE, sRatio, prot, s * 100 + r);

            trData = dataClean(trIdx, :);
            teData = dataClean(teIdx, :);

            % Cap test evaluation size to 500 for computational efficiency during Monte Carlo
            if height(teData) > 500
                teSub = 1:500;
                teData = teData(teSub, :);
                teIdx_sub = teIdx(teSub);
            else
                teIdx_sub = teIdx;
            end

            X_tr = X_all(trIdx, :);
            y_tr = y_all(trIdx);
            X_te = X_all(teIdx_sub, :);
            y_te = teData.SS_RSRP;

            % 1. Mode A: Calibrate LDPL strictly on trData
            Ptx = 24.0;
            pathLoss_tr = Ptx - trData.SS_RSRP;
            logD_tr = log10(max(1.0, trData.Dist3D));
            A_tr = [ones(height(trData), 1), 10 * logD_tr];
            beta_tr = A_tr \ pathLoss_tr;

            ldpl_fold.Ptx = Ptx;
            ldpl_fold.PL0 = beta_tr(1);
            ldpl_fold.n   = beta_tr(2);

            p0_pred = Ptx - (ldpl_fold.PL0 + 10 * ldpl_fold.n * log10(max(1.0, teData.Dist3D)));

            % 2. Mode B1: LDPL + Isotropic Residual
            [p1_pred, ~] = residual_reconstruction(trData, teData, ldpl_fold, iso_params);

            % 3. Mode B2: LDPL + Additive SASR Residual
            [p2_pred, ~] = residual_reconstruction(trData, teData, ldpl_fold, params);

            % 4. Mode C: Direct Random Forest
            rf_direct = train_rf_model(X_tr, y_tr, rf_opts);
            rf_pred = predict_rf(rf_direct, X_te);

            % 5. Mode D: Zero-Leakage OOF Residual RF
            K_oof = min(5, max(2, floor(height(trData) / 20)));
            [r_oof, ~, ~, ~] = compute_oof_residuals(trData, K_oof, params, s);
            rf_res_model = train_rf_residual(X_tr, r_oof, rf_opts);
            p3_pred = predict_hybrid(p2_pred, rf_res_model, X_te);

            % Evaluate RMSE
            p0_runs(s) = sqrt(mean((y_te - p0_pred).^2));
            p1_runs(s) = sqrt(mean((y_te - p1_pred).^2));
            p2_runs(s) = sqrt(mean((y_te - p2_pred).^2));
            rf_runs(s) = sqrt(mean((y_te - rf_pred).^2));
            p3_runs(s) = sqrt(mean((y_te - p3_pred).^2));

            mae_p2_runs(s) = mean(abs(y_te - p2_pred));
            mae_p3_runs(s) = mean(abs(y_te - p3_pred));
        end

        % Compute summary metrics
        mP0 = mean(p0_runs); sP0 = std(p0_runs);
        mP1 = mean(p1_runs); sP1 = std(p1_runs);
        mP2 = mean(p2_runs); sP2 = std(p2_runs);
        mRF = mean(rf_runs); sRF = std(rf_runs);
        mP3 = mean(p3_runs); sP3 = std(p3_runs);

        dP1_P2 = mP1 - mP2;
        dP2_P3 = mP2 - mP3;

        % Paired t-test between P1 vs P2, and P2 vs P3
        [~, p_P1_P2] = ttest(p1_runs, p2_runs);
        [~, p_P2_P3] = ttest(p2_runs, p3_runs);

        fprintf('  %-9s %4d%%   %5.2f +/-%.2f  %5.2f +/-%.2f  %5.2f +/-%.2f  %5.2f +/-%.2f  %5.2f +/-%.2f  %+5.2f dB  %+5.2f dB\n', ...
            prot, round(sRatio * 100), mP0, sP0, mP1, sP1, mP2, sP2, mRF, sRF, mP3, sP3, dP1_P2, dP2_P3);

        summaryRows(end+1, :) = { ...
            prot, sRatio * 100, mP0, sP0, mP1, sP1, mP2, sP2, mRF, sRF, mP3, sP3, ...
            dP1_P2, dP2_P3, p_P1_P2, p_P2_P3 ...
        };

        comparisonResults.(regimeKey).P0_mean = mP0;
        comparisonResults.(regimeKey).P1_mean = mP1;
        comparisonResults.(regimeKey).P2_mean = mP2;
        comparisonResults.(regimeKey).RF_mean = mRF;
        comparisonResults.(regimeKey).P3_mean = mP3;
        comparisonResults.(regimeKey).delta_P1_P2 = dP1_P2;
        comparisonResults.(regimeKey).delta_P2_P3 = dP2_P3;
        comparisonResults.(regimeKey).p_val_P1_P2 = p_P1_P2;
        comparisonResults.(regimeKey).p_val_P2_P3 = p_P2_P3;
    end
end

fprintf('--------------------------------------------------------------------------------------------------------\n\n');

%% 4. Export Comparison Artifacts
summaryTable = cell2table(summaryRows, 'VariableNames', { ...
    'Protocol', 'Budget_pct', 'P0_Mean_dB', 'P0_Std_dB', ...
    'P1_Mean_dB', 'P1_Std_dB', 'P2_Mean_dB', 'P2_Std_dB', ...
    'RF_Mean_dB', 'RF_Std_dB', 'P3_Mean_dB', 'P3_Std_dB', ...
    'Delta_Anisotropy_dB', 'Delta_ML_Residual_dB', ...
    'p_val_P1_vs_P2', 'p_val_P2_vs_P3' ...
});

writetable(summaryTable, fullfile('results', 'comparison', 'model_comparison_summary.csv'));

jsonStr = jsonencode(comparisonResults, 'PrettyPrint', true);
fid = fopen(fullfile('results', 'comparison', 'model_comparison_results.json'), 'w');
fwrite(fid, jsonStr, 'char');
fclose(fid);

%% 5. Publication-Ready Figures
fprintf('[3] Generating Comparison Figures...\n');

% Figure 1: RMSE vs Sampling Budget under Random Protocol
randRows = summaryTable(strcmp(summaryTable.Protocol, 'random'), :);
fig1 = figure('Visible', 'off', 'Position', [100 100 800 500]);
plot(randRows.Budget_pct, randRows.P0_Mean_dB, 'k--', 'LineWidth', 1.5, 'Marker', 's'); hold on;
plot(randRows.Budget_pct, randRows.P1_Mean_dB, 'b-o', 'LineWidth', 1.5);
plot(randRows.Budget_pct, randRows.P2_Mean_dB, 'g-^', 'LineWidth', 1.5);
plot(randRows.Budget_pct, randRows.RF_Mean_dB, 'm-d', 'LineWidth', 1.5);
plot(randRows.Budget_pct, randRows.P3_Mean_dB, 'r-s', 'LineWidth', 1.8);
xlabel('Measurement Budget (%)'); ylabel('Test RMSE (dB)');
title('RMSE vs Measurement Sparsity (Random Protocol)');
legend({'P0: LDPL', 'P1: LDPL + Isotropic', 'P2: LDPL + Additive SASR', 'Mode C: Direct RF', 'Mode D: P3 Hybrid'}, ...
    'Location', 'northeast');
grid on;
set(gca, 'XDir', 'reverse');
exportgraphics(fig1, fullfile('figures', 'comparison', 'fig01_rmse_vs_sampling_ratio.png'), 'Resolution', 150);
close(fig1);

% Figure 2: Bar Comparison Across Sampling Protocols at 5% Budget
budget5 = summaryTable(summaryTable.Budget_pct == 5, :);
fig2 = figure('Visible', 'off', 'Position', [100 100 900 500]);
barData = [budget5.P0_Mean_dB, budget5.P1_Mean_dB, budget5.P2_Mean_dB, budget5.RF_Mean_dB, budget5.P3_Mean_dB];
bar(categorical(budget5.Protocol), barData);
ylabel('Test RMSE (dB)');
title('Comparative Performance Across Sampling Spatial Regimes (5% Budget)');
legend({'P0 (LDPL)', 'P1 (Isotropic)', 'P2 (Additive SASR)', 'RF (Direct)', 'P3 (Hybrid)'}, 'Location', 'northwest');
grid on;
exportgraphics(fig2, fullfile('figures', 'comparison', 'fig02_rmse_across_protocols.png'), 'Resolution', 150);
close(fig2);

fprintf('Phase 05 Model Comparison completed successfully.\n');
