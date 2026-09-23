function [r_oof, p2_oof, fold_indices, fold_metrics] = compute_oof_residuals(tr_data, K_folds, params, seed)
% COMPUTE_OOF_RESIDUALS Computes genuine Out-Of-Fold (OOF) P2 predictions and residuals for Mode D.
%
% Requirement 2:
%   "For Mode D, OOF P2 predictions must be genuinely out-of-fold. Every P2
%   component that learns/calibrates from measurements must be fitted only
%   on the K-1 training folds before predicting the held-out fold.
%   Then: r_OOF = y_true - P2_OOF."
%
% Inputs:
%   tr_data      - Table of training observations with LATITUDE, LONGITUDE,
%                  SS_RSRP, Dist3D, ServingAzimuth, and NCI (or NR_PCI).
%   K_folds      - (Optional) Number of folds. Default: 5.
%   params       - (Optional) Additive SASR hyperparameters struct.
%   seed         - (Optional) Random seed for fold partitioning. Default: 42.
%
% Outputs:
%   r_oof        - N_tr x 1 vector of held-out residuals: y_true - p2_oof
%   p2_oof       - N_tr x 1 vector of held-out P2 predictions
%   fold_indices - N_tr x 1 vector of fold assignments (1 to K)
%   fold_metrics - Struct containing per-fold RMSE, MAE, and calibrated LDPL parameters

    if nargin < 2 || isempty(K_folds)
        K_folds = 5;
    end
    if nargin < 3 || isempty(params)
        params.sigma_g = 10.0;
        params.ell_g   = 200.0;
        params.sigma_c = 8.0;
        params.a_par   = 150.0;
        params.a_trans = 75.0;
        params.sigma_n = 2.0;
    end
    if nargin < 4 || isempty(seed)
        seed = 42;
    end

    % Standardize column names if needed
    if ~ismember('ServingAzimuth', tr_data.Properties.VariableNames)
        if ismember('angle', tr_data.Properties.VariableNames)
            tr_data.ServingAzimuth = tr_data.angle;
        elseif ismember('Base_Direction_angle_sin', tr_data.Properties.VariableNames)
            tr_data.ServingAzimuth = mod(atan2d(tr_data.Base_Direction_angle_sin, tr_data.Base_Direction_angle_cos), 360);
        else
            tr_data.ServingAzimuth = zeros(height(tr_data), 1);
        end
    end

    if ~ismember('NCI', tr_data.Properties.VariableNames)
        if ismember('NR_PCI', tr_data.Properties.VariableNames)
            tr_data.NCI = tr_data.NR_PCI;
        elseif ismember('PCI', tr_data.Properties.VariableNames)
            tr_data.NCI = tr_data.PCI;
        else
            tr_data.NCI = ones(height(tr_data), 1);
        end
    end

    if ~ismember('Dist3D', tr_data.Properties.VariableNames)
        if ismember('True_3D_Dist', tr_data.Properties.VariableNames)
            tr_data.Dist3D = tr_data.True_3D_Dist;
        else
            error('compute_oof_residuals: Dist3D or True_3D_Dist column is required.');
        end
    end

    if ~ismember('LATITUDE', tr_data.Properties.VariableNames) && ismember('Center_Y', tr_data.Properties.VariableNames)
        tr_data.LATITUDE = tr_data.Center_Y;
    end
    if ~ismember('LONGITUDE', tr_data.Properties.VariableNames) && ismember('Center_X', tr_data.Properties.VariableNames)
        tr_data.LONGITUDE = tr_data.Center_X;
    end

    N = height(tr_data);
    rng(seed);

    % Partition training observations into K folds
    shuffled_idx = randperm(N);
    fold_indices = zeros(N, 1);
    for i = 1:N
        fold_indices(shuffled_idx(i)) = mod(i - 1, K_folds) + 1;
    end

    p2_oof = nan(N, 1);
    r_oof  = nan(N, 1);

    fold_metrics = repmat(struct('fold', 0, 'N_train', 0, 'N_val', 0, ...
        'PL0', 0, 'n_exp', 0, 'rmse', 0, 'mae', 0), K_folds, 1);

    fprintf('    [OOF Engine] Generating genuine Out-Of-Fold P2 residuals across %d folds...\n', K_folds);

    Ptx = 24.0; % Nominal transmit power in dBm

    for k = 1:K_folds
        val_mask = (fold_indices == k);
        train_mask = ~val_mask;

        sub_train = tr_data(train_mask, :);
        sub_val   = tr_data(val_mask, :);

        % 1. Fit LDPL purely on training folds (tr \ k)
        pathLoss_tr = Ptx - sub_train.SS_RSRP;
        logD_tr = log10(max(1.0, sub_train.Dist3D));
        A_tr = [ones(height(sub_train), 1), 10 * logD_tr];
        beta_tr = A_tr \ pathLoss_tr;

        ldpl_model_fold.Ptx = Ptx;
        ldpl_model_fold.PL0 = beta_tr(1);
        ldpl_model_fold.n   = beta_tr(2);

        % 2. Predict LDPL baseline on held-out fold k
        val_ldpl = Ptx - (ldpl_model_fold.PL0 + 10 * ldpl_model_fold.n * log10(max(1.0, sub_val.Dist3D)));

        % 3. Calculate spatial residuals on training folds using fold's LDPL
        tr_ldpl = Ptx - (ldpl_model_fold.PL0 + 10 * ldpl_model_fold.n * log10(max(1.0, sub_train.Dist3D)));
        sub_train.residual = sub_train.SS_RSRP - tr_ldpl;

        % 4. Predict spatial residual on held-out fold k via Additive SASR
        % Anisotropic Kriging fitted strictly on sub_train observations
        [val_residual_pred, ~] = anisotropic_kriging(sub_train, sub_val, 'residual', params);

        % 5. Form held-out P2 prediction and held-out residual
        p2_pred_k = val_ldpl + val_residual_pred;
        r_oof_k   = sub_val.SS_RSRP - p2_pred_k;

        p2_oof(val_mask) = p2_pred_k;
        r_oof(val_mask)  = r_oof_k;

        err_k = sub_val.SS_RSRP - p2_pred_k;
        fold_metrics(k).fold    = k;
        fold_metrics(k).N_train = height(sub_train);
        fold_metrics(k).N_val   = height(sub_val);
        fold_metrics(k).PL0     = ldpl_model_fold.PL0;
        fold_metrics(k).n_exp   = ldpl_model_fold.n;
        fold_metrics(k).rmse    = sqrt(mean(err_k.^2));
        fold_metrics(k).mae     = mean(abs(err_k));

        fprintf('      Fold %d/%d: Val Samples = %4d | Calibrated PL0 = %6.2f dB, n = %4.2f | Val RMSE = %5.2f dB\n', ...
            k, K_folds, height(sub_val), ldpl_model_fold.PL0, ldpl_model_fold.n, fold_metrics(k).rmse);
    end

    total_oof_rmse = sqrt(mean(r_oof.^2));
    total_oof_mae  = mean(abs(r_oof));
    fprintf('    [OOF Engine] Completed. Total OOF P2 RMSE = %.2f dB, MAE = %.2f dB (std = %.2f dB).\n', ...
        total_oof_rmse, total_oof_mae, std(r_oof));
    fprintf('                 Procedural zero-leakage protocol enforced: all LDPL & Kriging parameters fitted on tr \\ k before predicting fold k.\n');
end
