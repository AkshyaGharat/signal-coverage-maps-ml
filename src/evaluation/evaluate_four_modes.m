function [comparisonTable, detailedMetrics, deltas] = evaluate_four_modes(y_true, preds, weak_threshold)
% EVALUATE_FOUR_MODES Standardized comparative evaluation across prediction modes:
%   Mode A  : P0 (Calibrated LDPL Physics Baseline)
%   Mode B1 : P1 (LDPL + Isotropic Residual Reconstruction)
%   Mode B2 : P2 (LDPL + Additive Sector-Aligned Anisotropic Residual)
%   Mode C  : RF (Direct Random Forest ML-Only)
%   Mode D  : P3 (Hybrid: P2 + RF Residual Correction)
%
% Inputs:
%   y_true         - N x 1 vector of true observed RSRP values (dBm).
%   preds          - Struct with fields: .P0, .P1, .P2, .RF, .P3 (each N x 1)
%                    Alternatively, can also accept .P_RF for RF.
%   weak_threshold - (Optional) Weak-signal cutoff in dBm. Default: -85.0 dBm.
%
% Outputs:
%   comparisonTable - MATLAB table containing RMSE, MAE, R2, Bias, Weak-RMSE,
%                     and Coverage percentages for each model.
%   detailedMetrics - Struct containing granular diagnostic distributions.
%   deltas          - Struct containing numerical ablation deltas:
%                     d_P0_P1, d_P1_P2, d_P2_P3, d_P2_RF, d_P0_P3.

    if nargin < 3 || isempty(weak_threshold)
        weak_threshold = -85.0;
    end

    % Normalize field names
    if isfield(preds, 'P_RF') && ~isfield(preds, 'RF')
        preds.RF = preds.P_RF;
    end

    modelKeys = {'P0', 'P1', 'P2', 'RF', 'P3'};
    modelLabels = { ...
        'Mode A (P0: LDPL Baseline)', ...
        'Mode B1 (P1: LDPL + Isotropic Res)', ...
        'Mode B2 (P2: LDPL + Additive SASR)', ...
        'Mode C (Direct RF ML-Only)', ...
        'Mode D (P3: Hybrid P2 + RF Res)' ...
    };

    % Ensure valid evaluation points
    N_models = numel(modelKeys);
    valid = isfinite(y_true);
    for m = 1:N_models
        k = modelKeys{m};
        if isfield(preds, k)
            valid = valid & isfinite(preds.(k));
        else
            error('evaluate_four_modes: Missing required prediction vector for "%s".', k);
        end
    end

    y_true = y_true(valid);
    N_eval = numel(y_true);
    ss_tot = sum((y_true - mean(y_true)).^2);

    weakMask = (y_true < weak_threshold);
    N_weak = sum(weakMask);

    rmseVec      = zeros(N_models, 1);
    maeVec       = zeros(N_models, 1);
    r2Vec        = zeros(N_models, 1);
    biasVec      = zeros(N_models, 1);
    weakRmseVec  = zeros(N_models, 1);
    weakRecall   = zeros(N_models, 1);
    cov70Vec     = zeros(N_models, 1);
    cov80Vec     = zeros(N_models, 1);
    cov85Vec     = zeros(N_models, 1);

    detailedMetrics = struct();

    for m = 1:N_models
        k = modelKeys{m};
        y_hat = preds.(k)(valid);
        err = y_hat - y_true;

        rmse = sqrt(mean(err.^2));
        mae  = mean(abs(err));
        r2   = 1.0 - (sum(err.^2) / max(1e-6, ss_tot));
        bias = mean(err);

        if N_weak > 0
            weak_rmse = sqrt(mean(err(weakMask).^2));
            predWeakMask = (y_hat < weak_threshold);
            recall = sum(weakMask & predWeakMask) / N_weak;
        else
            weak_rmse = NaN;
            recall = NaN;
        end

        cov70 = mean(y_hat >= -70.0) * 100.0;
        cov80 = mean(y_hat >= -80.0) * 100.0;
        cov85 = mean(y_hat >= -85.0) * 100.0;

        rmseVec(m)     = rmse;
        maeVec(m)      = mae;
        r2Vec(m)       = r2;
        biasVec(m)     = bias;
        weakRmseVec(m) = weak_rmse;
        weakRecall(m)  = recall;
        cov70Vec(m)    = cov70;
        cov80Vec(m)    = cov80;
        cov85Vec(m)    = cov85;

        detailedMetrics.(k).errors = err;
        detailedMetrics.(k).rmse = rmse;
        detailedMetrics.(k).mae = mae;
        detailedMetrics.(k).r2 = r2;
        detailedMetrics.(k).bias = bias;
        detailedMetrics.(k).weak_rmse = weak_rmse;
    end

    comparisonTable = table( ...
        modelKeys', ...
        modelLabels', ...
        rmseVec, ...
        maeVec, ...
        r2Vec, ...
        biasVec, ...
        weakRmseVec, ...
        weakRecall * 100.0, ...
        cov70Vec, ...
        cov80Vec, ...
        cov85Vec, ...
        'VariableNames', { ...
            'ModelKey', 'ModelDescription', 'RMSE_dB', 'MAE_dB', 'R2', ...
            'Bias_dB', 'Weak_RMSE_dB', 'Weak_Recall_pct', ...
            'Coverage_70dBm_pct', 'Coverage_80dBm_pct', 'Coverage_85dBm_pct' ...
        });

    % Compute numerical ablation deltas
    % Positive delta means the latter model achieves lower RMSE (improvement)
    deltas = struct();
    deltas.delta_P0_P1 = rmseVec(1) - rmseVec(2); % Physical residual reconstruction gain
    deltas.delta_P1_P2 = rmseVec(2) - rmseVec(3); % Sector-aligned anisotropy gain
    deltas.delta_P2_P3 = rmseVec(3) - rmseVec(5); % ML residual correction gain over P2
    deltas.delta_P2_RF = rmseVec(3) - rmseVec(4); % P2 vs direct ML difference
    deltas.delta_P0_P3 = rmseVec(1) - rmseVec(5); % Total physical-to-hybrid gain
end
