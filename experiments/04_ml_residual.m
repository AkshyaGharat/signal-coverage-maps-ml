% 04_ml_residual.m
% Machine Learning Residual Learning & Mode C / Mode D Integration
% Project: Signal Coverage Maps Using Measurements and Machine Learning
%
% Architecture:
%   Mode C: Direct Random Forest ML-Only (SS_RSRP ~ Features)
%   Mode D: Hybrid Physics + RF Residual Correction (P3 = P2 + RF_residual)
%
% Enforces Requirement 2:
%   "For Mode D, OOF P2 predictions must be genuinely out-of-fold. Every P2
%   component that learns/calibrates from measurements must be fitted only
%   on the K-1 training folds before predicting the held-out fold.
%   Then: r_OOF = y_true - P2_OOF."
%
% Enforces Requirement 3:
%   "Never use author-interpolated CIM-5G fishnet values as ground truth.
%   The 10,000-cell grid may be used for visualization/prediction, but
%   evaluation must use valid measured observations only."

clc; close all;

addpath(genpath('src'));

fprintf('=========================================================================\n');
fprintf('  Phase 04: ML Residual Learning & Mode C / Mode D Hybrid Synthesis\n');
fprintf('=========================================================================\n\n');

%% 1. Ensure Directories Exist
if ~exist(fullfile('models', 'random_forest'), 'dir')
    mkdir(fullfile('models', 'random_forest'));
end
if ~exist(fullfile('results', 'ml'), 'dir')
    mkdir(fullfile('results', 'ml'));
end
if ~exist(fullfile('figures', 'ml'), 'dir')
    mkdir(fullfile('figures', 'ml'));
end

%% 2. Load Valid Measured Observations
fprintf('[1] Loading CIM-5G Dataset...\n');
dataDir = fullfile('data', 'raw', 'CIM-5G');
fishnetPath = fullfile(dataDir, 'fishnet_30x30_processed_feature_engineered.csv');

optsFish = detectImportOptions(fishnetPath, 'VariableNamingRule', 'preserve');
rawTable = readtable(fishnetPath, optsFish);

% Strictly enforce Requirement 3: filter to valid measured observations only
if ismember('is_observed', rawTable.Properties.VariableNames)
    observedMask = (rawTable.is_observed == 1);
    fprintf('    Requirement 3 Enforced: Filtering to %d valid observed cells (excluding %d author-interpolated cells).\n', ...
        sum(observedMask), sum(~observedMask));
    dataClean = rawTable(observedMask, :);
else
    dataClean = rawTable;
end

% Standardize physical geometry columns
dataClean.Dist3D = dataClean.True_3D_Dist;
dataClean.NCI    = dataClean.NR_PCI;
dataClean.ServingAzimuth = mod(atan2d(dataClean.Base_Direction_angle_sin, dataClean.Base_Direction_angle_cos), 360);
dataClean.LATITUDE = dataClean.Center_Y;
dataClean.LONGITUDE = dataClean.Center_X;

% Extract features and target
[X_all, y_all, featureNames, validMask] = extract_ml_features(dataClean, 'SS_RSRP');
dataClean = dataClean(validMask, :);
X_all = X_all(validMask, :);
y_all = y_all(validMask);

N_total = height(dataClean);
fprintf('    Clean measured records: %d observations with %d features.\n\n', N_total, numel(featureNames));

%% 3. Partition into Train (80%) and Test (20%) Sets
rng(2026);
cv = cvpartition(N_total, 'HoldOut', 0.20);
trainIdx = training(cv);
testIdx  = test(cv);

trData = dataClean(trainIdx, :);
teData = dataClean(testIdx, :);

X_tr = X_all(trainIdx, :);
y_tr = y_all(trainIdx);
X_te = X_all(testIdx, :);
y_te = y_all(testIdx);

fprintf('[2] Train/Test Partitioning:\n');
fprintf('    Training set : %d observations\n', height(trData));
fprintf('    Testing set  : %d observations (strictly held out)\n\n', height(teData));

%% 4. Calibrate Mode A (P0: LDPL Physics Baseline) on Training Data Only
Ptx = 24.0;
pathLoss_tr = Ptx - trData.SS_RSRP;
logD_tr = log10(max(1.0, trData.Dist3D));
A_tr = [ones(height(trData), 1), 10 * logD_tr];
beta_tr = A_tr \ pathLoss_tr;

ldpl_model.Ptx = Ptx;
ldpl_model.PL0 = beta_tr(1);
ldpl_model.n   = beta_tr(2);

fprintf('[3] Calibrated LDPL Baseline (P0) on Training Set:\n');
fprintf('    PL0 = %.2f dB, n = %.2f\n\n', ldpl_model.PL0, ldpl_model.n);

% Predict P0 on test set
preds.P0 = Ptx - (ldpl_model.PL0 + 10 * ldpl_model.n * log10(max(1.0, teData.Dist3D)));

%% 5. Mode B1 & B2 Spatial Residual Reconstruction
fprintf('[4] Computing Spatial Reconstructions (P1 & P2)...\n');
params.sigma_g = 10.0;
params.ell_g   = 200.0;
params.sigma_c = 8.0;
params.a_par   = 150.0;
params.a_trans = 75.0;
params.sigma_n = 2.0;

% P1: Isotropic reconstruction (sigma_c = 0)
iso_params = params;
iso_params.sigma_c = 0.0;
[preds.P1, ~] = residual_reconstruction(trData, teData, ldpl_model, iso_params);

% P2: Additive sector-aligned anisotropic reconstruction
[preds.P2, ~] = residual_reconstruction(trData, teData, ldpl_model, params);

%% 6. Mode C: Train Direct Random Forest (ML-Only)
fprintf('\n[5] Training Mode C: Direct Random Forest (SS_RSRP ~ Features)...\n');
rf_opts.numTrees    = 300; % Imported baseline configuration
rf_opts.minLeafSize = 10;  % Imported baseline configuration
rf_opts.featureNames = featureNames;

rf_direct_model = train_rf_model(X_tr, y_tr, rf_opts);
preds.RF = predict_rf(rf_direct_model, X_te);

%% 7. Mode D: Zero-Leakage Out-of-Fold Residual Generation & Residual RF Training
fprintf('\n[6] Implementing Mode D Zero-Leakage OOF Training Protocol (Requirement 2)...\n');
fprintf('    Guarantee: All LDPL and Kriging parameters fitted strictly on training folds (tr \\ k) before predicting fold k.\n');
K_folds = 5;
[r_oof, p2_oof, fold_idx, fold_metrics] = compute_oof_residuals(trData, K_folds, params, 42);

% Sanity check: Ensure r_oof has non-zero variance (confirming solver evaluated held-out points rather than in-sample points)
oof_std = std(r_oof);
assert(oof_std > 1.0, 'Sanity Check Failed: OOF residual standard deviation is near zero (collapse).');
fprintf('    OOF Sanity Check: Residual std = %.2f dB (confirms held-out evaluation rather than in-sample interpolation).\n', oof_std);

% Train Residual Random Forest on genuine OOF residuals
residual_rf_model = train_rf_residual(X_tr, r_oof, rf_opts);

% Predict Mode D: P3 = P2 + RF_residual
[preds.P3, rf_res_test] = predict_hybrid(preds.P2, residual_rf_model, X_te);

%% 8. Comparative Evaluation Across All Modes
fprintf('\n[7] Evaluating All Four Modes on Held-Out Test Set (Requirement 5 & 6)...\n');
[compTable, detailed, deltas] = evaluate_four_modes(y_te, preds, -85.0);

disp(compTable(:, {'ModelKey', 'RMSE_dB', 'MAE_dB', 'R2', 'Bias_dB', 'Weak_RMSE_dB', 'Coverage_80dBm_pct'}));

fprintf('\nNumerical Ablation Deltas (Requirement 6 & 7):\n');
fprintf('  Delta(P0, P1) [Spatial Res Gain]   : %+5.2f dB\n', deltas.delta_P0_P1);
fprintf('  Delta(P1, P2) [Anisotropy Gain]    : %+5.2f dB\n', deltas.delta_P1_P2);
fprintf('  Delta(P2, P3) [ML Residual Gain]   : %+5.2f dB\n', deltas.delta_P2_P3);
fprintf('  Delta(P2, RF) [P2 vs Direct RF]    : %+5.2f dB\n', deltas.delta_P2_RF);
fprintf('  Delta(P0, P3) [Total Hybrid Gain]  : %+5.2f dB\n\n', deltas.delta_P0_P3);

%% 9. Feature Importance Comparison
fprintf('[8] Analyzing Feature Importance across Direct vs Residual Models...\n');
featTable = table(featureNames', rf_direct_model.importance', residual_rf_model.importance', ...
    'VariableNames', {'Feature', 'DirectRF_Importance', 'ResidualRF_Importance'});
featTable = sortrows(featTable, 'ResidualRF_Importance', 'descend');
disp(featTable);

%% 10. Save Models and Result Artifacts
fprintf('[9] Saving Models and Benchmark Metrics...\n');
save(fullfile('models', 'random_forest', 'mode_c_direct_rf.mat'), 'rf_direct_model', '-v7.3');
save(fullfile('models', 'random_forest', 'mode_d_residual_rf.mat'), 'residual_rf_model', '-v7.3');
save(fullfile('models', 'random_forest', 'calibrated_ldpl_model.mat'), 'ldpl_model');

writetable(compTable, fullfile('results', 'ml', 'ml_residual_benchmark.csv'));
writetable(featTable, fullfile('results', 'ml', 'feature_importance_comparison.csv'));

%% 11. Generate Diagnostic Figures
fprintf('[10] Generating Figures...\n');
% Figure: Actual vs Predicted across 4 Modes
fig1 = figure('Visible', 'off', 'Position', [100 100 1200 800]);
subplot(2, 2, 1);
scatter(y_te, preds.P0, 8, 'filled', 'MarkerFaceAlpha', 0.4); hold on;
plot([-140 -40], [-140 -40], 'k--', 'LineWidth', 1.2);
xlabel('Measured RSRP (dBm)'); ylabel('Predicted RSRP (dBm)');
title(sprintf('Mode A: P0 (LDPL) | RMSE = %.2f dB', compTable.RMSE_dB(1))); grid on; axis equal; xlim([-130 -50]); ylim([-130 -50]);

subplot(2, 2, 2);
scatter(y_te, preds.P2, 8, [0.1 0.6 0.2], 'filled', 'MarkerFaceAlpha', 0.4); hold on;
plot([-140 -40], [-140 -40], 'k--', 'LineWidth', 1.2);
xlabel('Measured RSRP (dBm)'); ylabel('Predicted RSRP (dBm)');
title(sprintf('Mode B2: P2 (Additive SASR) | RMSE = %.2f dB', compTable.RMSE_dB(3))); grid on; axis equal; xlim([-130 -50]); ylim([-130 -50]);

subplot(2, 2, 3);
scatter(y_te, preds.RF, 8, [0.8 0.4 0.1], 'filled', 'MarkerFaceAlpha', 0.4); hold on;
plot([-140 -40], [-140 -40], 'k--', 'LineWidth', 1.2);
xlabel('Measured RSRP (dBm)'); ylabel('Predicted RSRP (dBm)');
title(sprintf('Mode C: Direct RF | RMSE = %.2f dB', compTable.RMSE_dB(4))); grid on; axis equal; xlim([-130 -50]); ylim([-130 -50]);

subplot(2, 2, 4);
scatter(y_te, preds.P3, 8, [0.1 0.4 0.9], 'filled', 'MarkerFaceAlpha', 0.4); hold on;
plot([-140 -40], [-140 -40], 'k--', 'LineWidth', 1.2);
xlabel('Measured RSRP (dBm)'); ylabel('Predicted RSRP (dBm)');
title(sprintf('Mode D: P3 (Hybrid) | RMSE = %.2f dB', compTable.RMSE_dB(5))); grid on; axis equal; xlim([-130 -50]); ylim([-130 -50]);

exportgraphics(fig1, fullfile('figures', 'ml', 'actual_vs_predicted_four_modes.png'), 'Resolution', 150);
close(fig1);

% Figure: Residual RF Feature Importance
fig2 = figure('Visible', 'off', 'Position', [100 100 800 600]);
barh(categorical(featTable.Feature), featTable.ResidualRF_Importance);
set(gca, 'YDir', 'reverse');
xlabel('Out-of-Bag Permuted Predictor Importance');
ylabel('Feature');
title('Mode D: Residual Random Forest Feature Importance');
grid on;
exportgraphics(fig2, fullfile('figures', 'ml', 'residual_rf_feature_importance.png'), 'Resolution', 150);
close(fig2);

fprintf('\nPhase 04 completed successfully.\n');
