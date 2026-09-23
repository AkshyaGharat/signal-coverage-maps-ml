% validate_p1_vs_p2.m
% Direct Paired P1 vs P2 Statistical Validation & Delta Decomposition
% Project: Signal Coverage Maps Using Measurements and Machine Learning

clear; clc; close all;

addpath(genpath('src'));

fprintf('=========================================================================\n');
fprintf('  Phase 03-R Direct P1 vs P2 Paired Validation & Delta Decomposition\n');
fprintf('=========================================================================\n\n');

%% 1. Ensure Output Directories Exist
if ~exist(fullfile('results', 'reconstruction'), 'dir')
    mkdir(fullfile('results', 'reconstruction'));
end

%% 2. Load Clean Dataset
fprintf('[1] Loading Raw Datasets...\n');
dataDir = fullfile('data', 'raw', 'CIM-5G');
[rawData, bsData, ~] = load_raw_data(dataDir);
[distTable, ~] = compute_distance_metrics(rawData, bsData);

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
    end
end
rawData.ServingAzimuth = azVec;
rawData.Dist3D = distTable.Distance_3D_m;

validMask = ~isnan(rawData.LATITUDE) & ~isnan(rawData.LONGITUDE) & ...
            ~isnan(rawData.SS_RSRP) & ~isnan(rawData.Dist3D) & (rawData.NCI > 0);
dataClean = rawData(validMask, :);
fprintf('    Clean Validation Dataset: %d records.\n\n', height(dataClean));

%% 3. Fit Calibrated LDPL Baseline (P0)
Ptx = 24.0;
pathLoss = Ptx - dataClean.SS_RSRP;
logD = log10(dataClean.Dist3D);
A = [ones(height(dataClean), 1), 10 * logD];
beta = A \ pathLoss;
ldpl_model.Ptx = Ptx;
ldpl_model.PL0 = beta(1);
ldpl_model.n   = beta(2);

dataClean.rsrp_ldpl = Ptx - (ldpl_model.PL0 + 10 * ldpl_model.n * log10(dataClean.Dist3D));
dataClean.residual  = dataClean.SS_RSRP - dataClean.rsrp_ldpl;

fprintf('[2] Calibrated LDPL Baseline (P0): PL0 = %.2f dB, n = %.2f\n\n', ldpl_model.PL0, ldpl_model.n);

%% 4. Define Experimental Parameters & Protocols
params.sigma_g = 10.0; params.ell_g   = 200.0;
params.sigma_c = 8.0;  params.a_par   = 150.0; params.a_trans = 75.0;
params.sigma_n = 2.0;

protocols = {'random', 'uniform', 'clustered'};
sampleRatios = [0.10, 0.05, 0.02, 0.01];
N_runs = 30;

valResults = struct();

fprintf('[3] Running Paired P1 vs P2 30-Run Monte Carlo Evaluation across Regimes...\n');
fprintf('------------------------------------------------------------------------------------------------------------------------\n');
fprintf('  Protocol    Budget  P0 (LDPL)   P1 (Iso Res)       P2 (Additive SASR)   d_physics   d_anisotropy   d_total   p-value\n');
fprintf('------------------------------------------------------------------------------------------------------------------------\n');

for p = 1:numel(protocols)
    prot = protocols{p};
    for r = 1:numel(sampleRatios)
        sRatio = sampleRatios(r);
        
        p0_runs = zeros(N_runs, 1);
        p1_runs = zeros(N_runs, 1);
        p2_runs = zeros(N_runs, 1);
        delta_runs = zeros(N_runs, 1);
        
        for s = 1:N_runs
            % Exact identical split for both P1 and P2
            [trIdx, teIdx] = sparse_sampling(dataClean.LATITUDE, dataClean.LONGITUDE, sRatio, prot, s);
            trData = dataClean(trIdx, :);
            teData = dataClean(teIdx, :);
            
            if height(teData) > 300, teData = teData(1:300, :); end
            
            % P0: LDPL Physical Baseline
            y_true = teData.SS_RSRP;
            p0_pred = teData.rsrp_ldpl;
            p0_runs(s) = sqrt(mean((y_true - p0_pred).^2));
            
            % P1: LDPL + Isotropic Residual
            iso_params = params; iso_params.sigma_c = 0; % Pure isotropic
            [~, res_p1, ~] = residual_reconstruction(trData, teData, ldpl_model, iso_params);
            p1_pred = teData.rsrp_ldpl + res_p1;
            p1_runs(s) = sqrt(mean((y_true - p1_pred).^2));
            
            % P2: LDPL + Additive SASR Residual
            [~, res_p2, ~] = residual_reconstruction(trData, teData, ldpl_model, params);
            p2_pred = teData.rsrp_ldpl + res_p2;
            p2_runs(s) = sqrt(mean((y_true - p2_pred).^2));
            
            % Paired difference per run
            delta_runs(s) = p1_runs(s) - p2_runs(s);
        end
        
        m_p0 = mean(p0_runs);
        m_p1 = mean(p1_runs); std_p1 = std(p1_runs);
        m_p2 = mean(p2_runs); std_p2 = std(p2_runs);
        
        d_phys  = m_p0 - m_p1;
        d_aniso = m_p1 - m_p2;
        d_tot   = m_p0 - m_p2;
        
        % Paired t-test
        [~, p_val] = ttest(p1_runs, p2_runs);
        
        fprintf('  %-10s %-7s %-11.2f %-18s %-20s %-11.2f %-14.2f %-9.2f %.2e\n', ...
            prot, sprintf('%.0f%%', sRatio*100), m_p0, ...
            sprintf('%.2f +/- %.2f', m_p1, std_p1), ...
            sprintf('%.2f +/- %.2f', m_p2, std_p2), ...
            d_phys, d_aniso, d_tot, p_val);
            
        key = sprintf('%s_%d', prot, round(sRatio*100));
        valResults.(key).P0_LDPL = m_p0;
        valResults.(key).P1_Mean = m_p1; valResults.(key).P1_Std = std_p1;
        valResults.(key).P2_Mean = m_p2; valResults.(key).P2_Std = std_p2;
        valResults.(key).delta_physics = d_phys;
        valResults.(key).delta_anisotropy = d_aniso;
        valResults.(key).delta_total = d_tot;
        valResults.(key).p_value = p_val;
    end
end
fprintf('------------------------------------------------------------------------------------------------------------------------\n\n');

%% 5. Cross-Cell Validation Audit (Train: Cells 1-8, Test: Cells 9-10)
fprintf('[4] Executing Cross-Cell Generalizability Verification (Train: Cells 1-8, Test: Cells 9-10)...\n');
uniqueCells = unique(dataClean.NCI);
trCellData  = dataClean(~ismember(dataClean.NCI, uniqueCells(end-1:end)), :);
teCellData  = dataClean(ismember(dataClean.NCI, uniqueCells(end-1:end)), :);
if height(teCellData) > 300, teCellData = teCellData(1:300, :); end

y_cross_true = teCellData.SS_RSRP;
p0_cross = teCellData.rsrp_ldpl;
rmse_cross_p0 = sqrt(mean((y_cross_true - p0_cross).^2));

iso_params = params; iso_params.sigma_c = 0;
[~, res_cross_p1, ~] = residual_reconstruction(trCellData, teCellData, ldpl_model, iso_params);
p1_cross = teCellData.rsrp_ldpl + res_cross_p1;
rmse_cross_p1 = sqrt(mean((y_cross_true - p1_cross).^2));

[~, res_cross_p2, ~] = residual_reconstruction(trCellData, teCellData, ldpl_model, params);
p2_cross = teCellData.rsrp_ldpl + res_cross_p2;
rmse_cross_p2 = sqrt(mean((y_cross_true - p2_cross).^2));

fprintf('    Cross-Cell Test Results:\n');
fprintf('      P0 (LDPL Physical Baseline) : %.2f dB\n', rmse_cross_p0);
fprintf('      P1 (LDPL + Isotropic Res)   : %.2f dB\n', rmse_cross_p1);
fprintf('      P2 (LDPL + Additive SASR)   : %.2f dB\n\n', rmse_cross_p2);

crossCellStruct.P0 = rmse_cross_p0;
crossCellStruct.P1 = rmse_cross_p1;
crossCellStruct.P2 = rmse_cross_p2;

%% 6. Save Results
save(fullfile('results', 'reconstruction', 'phase03_p1_vs_p2_validation.mat'), 'valResults', 'crossCellStruct');

fprintf('=========================================================================\n');
fprintf('  Phase 03-R Direct P1 vs P2 Validation Completed Successfully\n');
fprintf('=========================================================================\n');
