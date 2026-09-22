% 03_anisotropic_reconstruction.m
% Sector-Aligned Anisotropic Spatial Reconstruction (SASR) & Physics Residual Ablation
% Project: Signal Coverage Maps Using Measurements and Machine Learning

clear; clc; close all;

addpath(genpath('src'));

fprintf('====================================================\n');
fprintf('  Phase 03: SASR Spatial Reconstruction & Ablation\n');
fprintf('====================================================\n\n');

%% Ensure Output Directories Exist
if ~exist(fullfile('figures', 'reconstruction'), 'dir')
    mkdir(fullfile('figures', 'reconstruction'));
end
if ~exist(fullfile('results', 'reconstruction'), 'dir')
    mkdir(fullfile('results', 'reconstruction'));
end

%% 1. Load Raw Datasets
fprintf('[1] Loading Datasets...\n');
dataDir = fullfile('data', 'raw', 'CIM-5G');
[rawData, bsData, ~] = load_raw_data(dataDir);
[distTable, ~] = compute_distance_metrics(rawData, bsData);

% Attach distances and serving azimuths
bsAzMap = containers.Map('KeyType', 'double', 'ValueType', 'double');
for b = 1:height(bsData)
    if ismember('ECI', bsData.Properties.VariableNames) && ~isnan(bsData.ECI(b))
        bsAzMap(bsData.ECI(b)) = bsData.angle(b);
    end
end

azVec = zeros(height(rawData), 1);
for i = 1:height(rawData)
    if isKey(bsAzMap, rawData.NCI(i))
        azVec(i) = bsAzMap(rawData.NCI(i));
    else
        azVec(i) = 0.0;
    end
end
rawData.ServingAzimuth = azVec;
rawData.Dist3D = distTable.Distance_3D_m;

validMask = ~isnan(rawData.LATITUDE) & ~isnan(rawData.LONGITUDE) & ...
            ~isnan(rawData.SS_RSRP) & ~isnan(rawData.Dist3D) & (rawData.NCI > 0);
dataClean = rawData(validMask, :);

N_total = height(dataClean);
fprintf('    Clean measurement dataset: %d records.\n\n', N_total);

%% 2. Data-Driven Range Estimation from Training Variograms
fprintf('[2] Data-Driven Variogram Estimation of a_parallel & a_transverse...\n');
dirVar = compute_directional_variogram(dataClean.LATITUDE, dataClean.LONGITUDE, ...
    dataClean.SS_RSRP, dataClean.NCI, bsData, 0:25:500);

% Estimate range where semivariance reaches 95% of sill
sill = var(dataClean.SS_RSRP);
idxPar   = find(dirVar.GammaParallel >= 0.95 * sill, 1);
idxTrans = find(dirVar.GammaTransverse >= 0.95 * sill, 1);

aParEst   = ifelse(~isempty(idxPar), dirVar.BinCenters(idxPar), 180.0);
aTransEst = ifelse(~isempty(idxTrans), dirVar.BinCenters(idxTrans), 75.0);

fprintf('    Estimated Range: a_parallel = %.1fm, a_transverse = %.1fm\n\n', aParEst, aTransEst);

%% 3. Evaluate Sampling Budgets across 3 Protocols (Random, Uniform, Clustered)
fprintf('[3] Benchmarking Methods Across Sampling Protocols...\n');
sampleRatios = [0.10, 0.05, 0.02, 0.01];
protocols    = {'random', 'uniform', 'clustered'};
methods      = {'LDPL', 'Isotropic_Kriging', 'SASR_Raw', 'LDPL_SASR_Residual'};

resultsMatrix = struct();

for p = 1:numel(protocols)
    prot = protocols{p};
    fprintf('    Testing Protocol: %s...\n', prot);
    
    for r = 1:numel(sampleRatios)
        sRatio = sampleRatios(r);
        [trIdx, teIdx] = sparse_sampling(dataClean.LATITUDE, dataClean.LONGITUDE, sRatio, prot, 42);
        
        trData = dataClean(trIdx, :);
        teData = dataClean(teIdx, :);
        
        % 1. LDPL
        predLDPL = ldpl_baseline(trData.Dist3D, trData.SS_RSRP, teData.Dist3D, 24.0);
        mLDPL = evaluate_reconstruction(teData.SS_RSRP, predLDPL);
        
        % 2. Isotropic Kriging
        predIso = isotropic_kriging(trData.LATITUDE, trData.LONGITUDE, trData.SS_RSRP, ...
            teData.LATITUDE, teData.LONGITUDE, 100.0, 12.0, 2.0);
        mIso = evaluate_reconstruction(teData.SS_RSRP, predIso);
        
        % 3. SASR Raw
        predSASR = anisotropic_kriging(trData.LATITUDE, trData.LONGITUDE, trData.SS_RSRP, trData.ServingAzimuth, ...
            teData.LATITUDE, teData.LONGITUDE, teData.ServingAzimuth, aParEst, aTransEst, 12.0, 2.0);
        mSASR = evaluate_reconstruction(teData.SS_RSRP, predSASR);
        
        % 4. LDPL + SASR Residual
        predResSASR = residual_reconstruction(trData.LATITUDE, trData.LONGITUDE, trData.Dist3D, trData.SS_RSRP, trData.ServingAzimuth, ...
            teData.LATITUDE, teData.LONGITUDE, teData.Dist3D, teData.ServingAzimuth, aParEst, aTransEst);
        mResSASR = evaluate_reconstruction(teData.SS_RSRP, predResSASR);
        
        key = sprintf('%s_ratio_%d', prot, round(sRatio*100));
        resultsMatrix.(key).LDPL = mLDPL;
        resultsMatrix.(key).Isotropic = mIso;
        resultsMatrix.(key).SASR_Raw = mSASR;
        resultsMatrix.(key).LDPL_SASR = mResSASR;
    end
end
fprintf('    Completed multi-protocol benchmark.\n\n');

%% 4. Statistical Significance Testing (30 Monte Carlo Random Splits)
fprintf('[4] Running 30-Run Monte Carlo Paired Significance Test...\n');
numRuns = 30;
rmseIsoRuns  = zeros(numRuns, 1);
rmseSASRRuns = zeros(numRuns, 1);

for run = 1:numRuns
    [trIdx, teIdx] = sparse_sampling(dataClean.LATITUDE, dataClean.LONGITUDE, 0.05, 'random', run*10);
    trData = dataClean(trIdx, :); teData = dataClean(teIdx, :);
    
    predIso  = isotropic_kriging(trData.LATITUDE, trData.LONGITUDE, trData.SS_RSRP, teData.LATITUDE, teData.LONGITUDE, 100.0, 12.0, 2.0);
    predSASR = anisotropic_kriging(trData.LATITUDE, trData.LONGITUDE, trData.SS_RSRP, trData.ServingAzimuth, ...
        teData.LATITUDE, teData.LONGITUDE, teData.ServingAzimuth, aParEst, aTransEst, 12.0, 2.0);
    
    rmseIsoRuns(run)  = sqrt(mean((teData.SS_RSRP - predIso).^2));
    rmseSASRRuns(run) = sqrt(mean((teData.SS_RSRP - predSASR).^2));
end

meanIso  = mean(rmseIsoRuns);  stdIso  = std(rmseIsoRuns);
meanSASR = mean(rmseSASRRuns); stdSASR = std(rmseSASRRuns);

pctImprov = ((meanIso - meanSASR) / meanIso) * 100;
[~, pValue] = ttest(rmseIsoRuns, rmseSASRRuns);

fprintf('    Isotropic Kriging RMSE : %.2f +/- %.2f dB\n', meanIso, stdIso);
fprintf('    SASR Reconstruction    : %.2f +/- %.2f dB\n', meanSASR, stdSASR);
fprintf('    Mean Improvement       : %.2f%% (p = %.5e)\n\n', pctImprov, pValue);

%% 5. Cross-Cell Generalizability Test (Train: Cells 1-8, Test: Cells 9-10)
fprintf('[5] Cross-Cell Generalizability Evaluation (Train Cells 1-8, Test Cells 9-10)...\n');
[trCrossIdx, teCrossIdx] = cross_cell_split(dataClean.NCI);

trCross = dataClean(trCrossIdx, :);
teCross = dataClean(teCrossIdx, :);

predCrossIso  = isotropic_kriging(trCross.LATITUDE, trCross.LONGITUDE, trCross.SS_RSRP, teCross.LATITUDE, teCross.LONGITUDE, 100.0, 12.0, 2.0);
predCrossSASR = anisotropic_kriging(trCross.LATITUDE, trCross.LONGITUDE, trCross.SS_RSRP, trCross.ServingAzimuth, ...
    teCross.LATITUDE, teCross.LONGITUDE, teCross.ServingAzimuth, aParEst, aTransEst, 12.0, 2.0);

mCrossIso  = evaluate_reconstruction(teCross.SS_RSRP, predCrossIso);
mCrossSASR = evaluate_reconstruction(teCross.SS_RSRP, predCrossSASR);

fprintf('    Cross-Cell Isotropic RMSE: %.2f dB\n', mCrossIso.RMSE);
fprintf('    Cross-Cell SASR RMSE     : %.2f dB\n\n', mCrossSASR.RMSE);

%% 6. Render Figures
fprintf('[6] Rendering Figures in figures/reconstruction/...\n');

% Fig 1: Reconstructed Spatial Maps Comparison
h1 = figure('Name', 'Reconstructed Coverage Maps', 'Visible', 'off');
subplot(2, 2, 1); scatter(dataClean.LONGITUDE, dataClean.LATITUDE, 6, dataClean.SS_RSRP, 'filled'); title('True RSRP Field'); colorbar; grid on;
subplot(2, 2, 2); scatter(teData.LONGITUDE, teData.LATITUDE, 6, predIso, 'filled'); title('Isotropic Kriging'); colorbar; grid on;
subplot(2, 2, 3); scatter(teData.LONGITUDE, teData.LATITUDE, 6, predSASR, 'filled'); title('SASR (Sector-Aligned)'); colorbar; grid on;
subplot(2, 2, 4); scatter(teData.LONGITUDE, teData.LATITUDE, 6, predResSASR, 'filled'); title('LDPL + SASR Residual'); colorbar; grid on;
saveas(h1, fullfile('figures', 'reconstruction', 'fig01_reconstructed_maps_comparison.png')); close(h1);

% Fig 2: Error Surface Maps
h2 = figure('Name', 'Error Surface Maps', 'Visible', 'off');
subplot(1, 2, 1); scatter(teData.LONGITUDE, teData.LATITUDE, 6, abs(teData.SS_RSRP - predIso), 'filled'); title('Isotropic Absolute Error (dB)'); colorbar; grid on;
subplot(1, 2, 2); scatter(teData.LONGITUDE, teData.LATITUDE, 6, abs(teData.SS_RSRP - predSASR), 'filled'); title('SASR Absolute Error (dB)'); colorbar; grid on;
saveas(h2, fullfile('figures', 'reconstruction', 'fig02_error_surface_maps.png')); close(h2);

% Fig 3: Sampling Protocol Performance Comparison
h3 = figure('Name', 'Sampling Protocol Performance', 'Visible', 'off');
bar([resultsMatrix.random_ratio_5.Isotropic.RMSE, resultsMatrix.random_ratio_5.SASR_Raw.RMSE; ...
     resultsMatrix.uniform_ratio_5.Isotropic.RMSE, resultsMatrix.uniform_ratio_5.SASR_Raw.RMSE; ...
     resultsMatrix.clustered_ratio_5.Isotropic.RMSE, resultsMatrix.clustered_ratio_5.SASR_Raw.RMSE]);
set(gca, 'XTickLabel', {'Random (5%)', 'Uniform (5%)', 'Clustered (5%)'});
legend('Isotropic Kriging', 'SASR (Novelty)'); title('Reconstruction RMSE across 3 Sampling Protocols');
ylabel('RMSE (dB)'); grid on;
saveas(h3, fullfile('figures', 'reconstruction', 'fig03_sampling_protocol_performance.png')); close(h3);

% Fig 4: Sparsity Decay Curves (RMSE vs 10%, 5%, 2%, 1%)
h4 = figure('Name', 'Sparsity Decay Curves', 'Visible', 'off');
ratios = [10, 5, 2, 1];
rmseIsoCurve  = [resultsMatrix.random_ratio_10.Isotropic.RMSE, resultsMatrix.random_ratio_5.Isotropic.RMSE, resultsMatrix.random_ratio_2.Isotropic.RMSE, resultsMatrix.random_ratio_1.Isotropic.RMSE];
rmseSASRCurve = [resultsMatrix.random_ratio_10.SASR_Raw.RMSE, resultsMatrix.random_ratio_5.SASR_Raw.RMSE, resultsMatrix.random_ratio_2.SASR_Raw.RMSE, resultsMatrix.random_ratio_1.SASR_Raw.RMSE];
plot(ratios, rmseIsoCurve, '-o', 'LineWidth', 2, 'Color', [0.8 0.2 0.2]); hold on;
plot(ratios, rmseSASRCurve, '-s', 'LineWidth', 2, 'Color', [0.1 0.5 0.8]);
set(gca, 'XDir', 'reverse'); title('RMSE vs Sparse Sampling Ratio');
xlabel('Sampling Budget Ratio (%)'); ylabel('RMSE (dB)'); legend('Isotropic Kriging', 'SASR', 'Location', 'best'); grid on;
saveas(h4, fullfile('figures', 'reconstruction', 'fig04_sparsity_decay_curves.png')); close(h4);

% Fig 5: Cross-Cell Generalizability
h5 = figure('Name', 'Cross-Cell Generalizability', 'Visible', 'off');
bar([mCrossIso.RMSE, mCrossSASR.RMSE; mCrossIso.WeakRMSE, mCrossSASR.WeakRMSE]);
set(gca, 'XTickLabel', {'Overall RMSE', 'Weak-Signal RMSE'});
legend('Isotropic Kriging', 'SASR'); title('Cross-Cell Evaluation (Train: Cells 1-8, Test: Cells 9-10)');
ylabel('RMSE (dB)'); grid on;
saveas(h5, fullfile('figures', 'reconstruction', 'fig05_cross_cell_generalizability.png')); close(h5);

% Fig 6: Uncertainty Calibration
h6 = figure('Name', 'Uncertainty Calibration', 'Visible', 'off');
[~, predVarSASR] = anisotropic_kriging(trData.LATITUDE, trData.LONGITUDE, trData.SS_RSRP, trData.ServingAzimuth, ...
    teData.LATITUDE, teData.LONGITUDE, teData.ServingAzimuth, aParEst, aTransEst, 12.0, 2.0);
scatter(sqrt(predVarSASR), abs(teData.SS_RSRP - predSASR), 6, [0.3 0.6 0.3], 'filled'); hold on;
plot([0 15], [0 15], 'k--', 'LineWidth', 1.5);
title('Predictive Uncertainty Calibration (Predicted \sigma vs Absolute Error)');
xlabel('Predicted Uncertainty \sigma_p (dB)'); ylabel('Absolute Reconstruction Error (dB)'); grid on;
saveas(h6, fullfile('figures', 'reconstruction', 'fig06_uncertainty_calibration.png')); close(h6);

fprintf('    Saved all 6 reconstruction figures in figures/reconstruction/.\n\n');

%% 7. Save Results Summary to results/reconstruction/
fprintf('[7] Saving Results Summary to results/reconstruction/...\n');
save(fullfile('results', 'reconstruction', 'reconstruction_summary.mat'), ...
    'resultsMatrix', 'meanIso', 'stdIso', 'meanSASR', 'stdSASR', 'pctImprov', 'pValue', ...
    'mCrossIso', 'mCrossSASR', 'aParEst', 'aTransEst');

fprintf('====================================================\n');
fprintf('  Phase 03 SASR Reconstruction Completed Successfully\n');
fprintf('====================================================\n');

function y = ifelse(cond, valTrue, valFalse)
    if cond, y = valTrue; else, y = valFalse; end
end
