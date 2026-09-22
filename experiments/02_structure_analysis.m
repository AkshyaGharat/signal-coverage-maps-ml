% 02_structure_analysis.m
% Radio Field Structure Discovery & Physical Residual Diagnostics
% Project: Signal Coverage Maps Using Measurements and Machine Learning

clear; clc; close all;

addpath(genpath('src'));

fprintf('====================================================\n');
fprintf('  Phase 02: Radio Field Structure Discovery\n');
fprintf('====================================================\n\n');

%% Ensure Output Directories Exist
if ~exist(fullfile('figures', 'structure'), 'dir')
    mkdir(fullfile('figures', 'structure'));
end
if ~exist(fullfile('results', 'structure'), 'dir')
    mkdir(fullfile('results', 'structure'));
end

%% 1. Load Raw Datasets
fprintf('[1] Loading Raw Datasets...\n');
dataDir = fullfile('data', 'raw', 'CIM-5G');
[rawData, bsData, fishnetData] = load_raw_data(dataDir);
fprintf('    Loaded %d raw records and %d base stations.\n\n', height(rawData), height(bsData));

%% 2. Directional Anisotropy & Directional Variograms
fprintf('[2] Computing Directional Anisotropy & Semivariograms...\n');
anisotropy   = compute_anisotropy(rawData.LATITUDE, rawData.LONGITUDE, rawData.SS_RSRP, rawData.NCI, bsData, 0:25:500);
dirVariogram = compute_directional_variogram(rawData.LATITUDE, rawData.LONGITUDE, rawData.SS_RSRP, rawData.NCI, bsData, 0:25:500);

h1 = figure('Name', 'Directional Anisotropy and Variograms', 'Visible', 'off');
subplot(2, 1, 1);
plot(anisotropy.BinCenters, anisotropy.CorrParallel, '-o', 'LineWidth', 1.8, 'Color', [0.1 0.5 0.8], 'MarkerFaceColor', [0.1 0.5 0.8]); hold on;
plot(anisotropy.BinCenters, anisotropy.CorrTransverse, '-s', 'LineWidth', 1.8, 'Color', [0.8 0.3 0.1], 'MarkerFaceColor', [0.8 0.3 0.1]);
title('Directional Spatial Autocorrelation: Azimuth Parallel vs Transverse');
xlabel('Distance Lag h (m)'); ylabel('Correlation \rho(h)');
legend('\rho_\parallel(h) (Azimuth Parallel)', '\rho_\perp(h) (Transverse)', 'Location', 'best'); grid on;

subplot(2, 1, 2);
plot(dirVariogram.BinCenters, dirVariogram.GammaParallel, '-o', 'LineWidth', 1.8, 'Color', [0.1 0.5 0.8], 'MarkerFaceColor', [0.1 0.5 0.8]); hold on;
plot(dirVariogram.BinCenters, dirVariogram.GammaTransverse, '-s', 'LineWidth', 1.8, 'Color', [0.8 0.3 0.1], 'MarkerFaceColor', [0.8 0.3 0.1]);
title('Directional Semivariogram: \gamma_\parallel(h) vs \gamma_\perp(h)');
xlabel('Distance Lag h (m)'); ylabel('Semivariance \gamma(h) (dB^2)');
legend('\gamma_\parallel(h) (Azimuth Parallel)', '\gamma_\perp(h) (Transverse)', 'Location', 'best'); grid on;
saveas(h1, fullfile('figures', 'structure', 'fig01_directional_anisotropy_variogram.png'));
close(h1);
fprintf('    Saved fig01_directional_anisotropy_variogram.png\n\n');

%% 3. Spatial & Cell-Wise Non-Stationarity Analysis
fprintf('[3] Spatial & Cell-Wise Non-Stationarity Analysis...\n');
nonStat   = compute_nonstationarity(rawData.LATITUDE, rawData.LONGITUDE, rawData.SS_RSRP, 4);
cellStats = compute_cellwise_structure(rawData, bsData);

h2 = figure('Name', 'Cell-Wise Structure Comparison', 'Visible', 'off');
bar([cellStats.CorrelationLength_m]);
set(gca, 'XTick', 1:numel(cellStats), 'XTickLabel', {cellStats.NCI});
xtickangle(45);
title('Spatial Correlation Length (m) per Serving Cell');
xlabel('Serving Cell NCI'); ylabel('Correlation Decay Length (m)'); grid on;
saveas(h2, fullfile('figures', 'structure', 'fig02_spatial_cellwise_nonstationarity.png'));
close(h2);
fprintf('    Saved fig02_spatial_cellwise_nonstationarity.png\n\n');

%% 4. Calibrated Physical Baseline & Residual Field
fprintf('[4] Calibrated Physical Baseline & Residual Analysis...\n');
[distTable, ~] = compute_distance_metrics(rawData, bsData);
[residual, rsrpPhys, modelParams] = compute_physical_baseline(distTable.Distance_3D_m, rawData.SS_RSRP, 24.0);

fprintf('    Calibrated LDPL Model: PL0 = %.2f dB, n = %.2f, RMSE = %.2f dB\n', ...
    modelParams.PL0, modelParams.PathLossExponent_n, modelParams.RMSE);

h3 = figure('Name', 'Calibrated Physical Residual Map', 'Visible', 'off');
validMask = ~isnan(residual);
scatter(rawData.LONGITUDE(validMask), rawData.LATITUDE(validMask), 8, residual(validMask), 'filled');
colorbar; title('Calibrated Physical Residual Field (RSRP_{measured} - RSRP_{phys}) [dB]');
xlabel('Longitude (deg)'); ylabel('Latitude (deg)'); grid on; axis equal;
saveas(h3, fullfile('figures', 'structure', 'fig03_calibrated_physical_residual.png'));
close(h3);
fprintf('    Saved fig03_calibrated_physical_residual.png\n\n');

%% 5. Raw Field vs. Residual Autocorrelation Comparison
fprintf('[5] Comparing Raw Field vs Residual Spatial Autocorrelation...\n');
autoCorrRaw  = spatial_autocorrelation(rawData.LATITUDE, rawData.LONGITUDE, rawData.SS_RSRP, 0:20:500);
autoCorrRes  = spatial_autocorrelation(rawData.LATITUDE(validMask), rawData.LONGITUDE(validMask), residual(validMask), 0:20:500);

h4 = figure('Name', 'Raw vs Residual Autocorrelation', 'Visible', 'off');
plot(autoCorrRaw.BinCenters, autoCorrRaw.Correlation, '-o', 'LineWidth', 1.8, 'Color', [0.2 0.4 0.8]); hold on;
plot(autoCorrRes.BinCenters, autoCorrRes.Correlation, '-s', 'LineWidth', 1.8, 'Color', [0.8 0.2 0.2]);
title('Spatial Correlation Decay: Raw RSRP vs Calibrated Physical Residual');
xlabel('Distance Lag h (m)'); ylabel('Correlation \rho(h)');
legend('Raw RSRP', 'Calibrated Residual Field', 'Location', 'best'); grid on;
saveas(h4, fullfile('figures', 'structure', 'fig04_raw_vs_residual_autocorr.png'));
close(h4);
fprintf('    Saved fig04_raw_vs_residual_autocorr.png\n\n');

%% 6. Low-Rank Spectrum Test
fprintf('[6] Low-Rank Spectrum Diagnostic...\n');
lowRankRaw = compute_low_rank_spectrum(rawData.LATITUDE, rawData.LONGITUDE, rawData.SS_RSRP, 30);
lowRankRes = compute_low_rank_spectrum(rawData.LATITUDE(validMask), rawData.LONGITUDE(validMask), residual(validMask), 30);

h5 = figure('Name', 'Low-Rank Spectrum', 'Visible', 'off');
plot(lowRankRaw.CumEnergy, '-o', 'LineWidth', 1.8, 'Color', [0.2 0.4 0.8]); hold on;
plot(lowRankRes.CumEnergy, '-s', 'LineWidth', 1.8, 'Color', [0.8 0.2 0.2]);
title('SVD Cumulative Energy Spectrum (Un-interpolated Grid)');
xlabel('Singular Value Index (Rank)'); ylabel('Cumulative Energy Fraction');
legend('Raw RSRP Matrix', 'Residual Matrix', 'Location', 'best'); grid on;
saveas(h5, fullfile('figures', 'structure', 'fig05_low_rank_spectrum.png'));
close(h5);
fprintf('    Saved fig05_low_rank_spectrum.png\n\n');

%% 7. Transform Compressibility Test
fprintf('[7] Transform Compressibility Diagnostic...\n');
compRaw = compute_compressibility(rawData.SS_RSRP);
compRes = compute_compressibility(residual(validMask));

h6 = figure('Name', 'Compressibility Spectrum', 'Visible', 'off');
plot(compRaw.CumEnergy(1:1000), 'LineWidth', 1.8, 'Color', [0.2 0.4 0.8]); hold on;
plot(compRes.CumEnergy(1:1000), 'LineWidth', 1.8, 'Color', [0.8 0.2 0.2]);
title('Transform Coefficient Energy Concentration (Sorted Coefficients)');
xlabel('Top N Coefficients'); ylabel('Cumulative Energy Fraction');
legend('Raw RSRP', 'Residual Field', 'Location', 'best'); grid on;
saveas(h6, fullfile('figures', 'structure', 'fig06_sparsity_compressibility.png'));
close(h6);
fprintf('    Saved fig06_sparsity_compressibility.png\n\n');

%% 8. Graph Smoothness Test
fprintf('[8] Graph Smoothness Test...\n');
graphRaw = compute_graph_smoothness(rawData.LATITUDE, rawData.LONGITUDE, rawData.SS_RSRP, 8);
graphRes = compute_graph_smoothness(rawData.LATITUDE(validMask), rawData.LONGITUDE(validMask), residual(validMask), 8);

h7 = figure('Name', 'Graph Smoothness', 'Visible', 'off');
bar([graphRaw.GraphSmoothness, graphRes.GraphSmoothness]);
set(gca, 'XTickLabel', {'Raw RSRP', 'Residual Field'});
title('Graph Dirichlet Smoothness S(x) = (x^T L x) / ||x||^2');
ylabel('Graph Smoothness Metric (Lower = Smoother)'); grid on;
saveas(h7, fullfile('figures', 'structure', 'fig07_graph_smoothness.png'));
close(h7);
fprintf('    Saved fig07_graph_smoothness.png\n\n');

%% 9. Multi-Scale Scale-Space Analysis
fprintf('[9] Multi-Scale Scale-Space Analysis...\n');
multiScale = compute_multiscale_decomposition(rawData.LATITUDE, rawData.LONGITUDE, rawData.SS_RSRP);

h8 = figure('Name', 'Multi-Scale Spectrum', 'Visible', 'off');
bar([multiScale.MacroPct, multiScale.MesoPct, multiScale.MicroPct]);
set(gca, 'XTickLabel', {'Macro (>200m)', 'Meso (50-200m)', 'Micro (<50m)'});
title('Spatial Power Distribution Across Scale Bands');
ylabel('Percentage Energy (%)'); grid on;
saveas(h8, fullfile('figures', 'structure', 'fig08_multiscale_decomposition.png'));
close(h8);
fprintf('    Saved fig08_multiscale_decomposition.png\n\n');

%% 10. Save Master Diagnostic Summary to results/structure/
fprintf('[10] Saving Master Diagnostic Summary...\n');
save(fullfile('results', 'structure', 'structure_summary.mat'), ...
    'anisotropy', 'dirVariogram', 'nonStat', 'cellStats', 'modelParams', ...
    'lowRankRaw', 'lowRankRes', 'compRaw', 'compRes', 'graphRaw', 'graphRes', 'multiScale');

fprintf('====================================================\n');
fprintf('  Phase 02 Structure Analysis Completed Successfully\n');
fprintf('====================================================\n');
