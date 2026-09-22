function [y_pred, y_var] = anisotropic_kriging(tr_data, te_data, target_col, params)
% ANISOTROPIC_KRIGING Core Reconstruction Engine using Additive Sector-Aligned Anisotropic Covariance Model.
%
% Inputs:
%   tr_data    - Table of training observations with LATITUDE, LONGITUDE, NCI, ServingAzimuth, and target_col
%   te_data    - Table of test observations with LATITUDE, LONGITUDE, NCI, ServingAzimuth
%   target_col - String name of target variable (e.g. 'SS_RSRP' or 'residual')
%   params     - Struct of hyper-parameters (sigma_g, ell_g, sigma_c, a_par, a_trans, sigma_n)

    if nargin < 4 || isempty(params)
        params.sigma_g = 10.0;
        params.ell_g   = 200.0;
        params.sigma_c = 8.0;
        params.a_par   = 150.0;
        params.a_trans = 75.0;
        params.sigma_n = 2.0;
    end
    
    R = 6371000.0;
    lat0 = mean(tr_data.LATITUDE);
    lon0 = mean(tr_data.LONGITUDE);
    
    tr_xE = R * deg2rad(tr_data.LONGITUDE - lon0) * cos(deg2rad(lat0));
    tr_yN = R * deg2rad(tr_data.LATITUDE - lat0);
    tr_y  = tr_data.(target_col);
    tr_cells = tr_data.NCI;
    tr_az    = tr_data.ServingAzimuth;
    
    te_xE = R * deg2rad(te_data.LONGITUDE - lon0) * cos(deg2rad(lat0));
    te_yN = R * deg2rad(te_data.LATITUDE - lat0);
    te_cells = te_data.NCI;
    te_az    = te_data.ServingAzimuth;
    
    N_tr = height(tr_data);
    N_te = height(te_data);
    
    % Subsample training if too large for direct matrix inversion
    if N_tr > 800
        sub_idx = randperm(N_tr, 800);
        tr_xE = tr_xE(sub_idx); tr_yN = tr_yN(sub_idx); tr_y = tr_y(sub_idx);
        tr_cells = tr_cells(sub_idx); tr_az = tr_az(sub_idx);
        N_tr = 800;
    end
    
    [xE1, xE2] = meshgrid(tr_xE, tr_xE);
    [yN1, yN2] = meshgrid(tr_yN, tr_yN);
    [cell1, cell2] = meshgrid(tr_cells, tr_cells);
    
    hE_tr = xE2 - xE1;
    hN_tr = yN2 - yN1;
    
    % Construct Training Covariance Matrix K_tr
    K_tr = anisotropic_covariance(hE_tr, hN_tr, cell1(:,1), cell2(1,:)', tr_az, ...
        params.sigma_g, params.ell_g, params.sigma_c, params.a_par, params.a_trans, params.sigma_n);
    
    K_inv = inv(K_tr);
    
    y_pred = zeros(N_te, 1);
    y_var  = zeros(N_te, 1);
    
    total_var = params.sigma_g^2 + params.sigma_c^2;
    
    for i = 1:N_te
        hE_te = te_xE(i) - tr_xE;
        hN_te = te_yN(i) - tr_yN;
        
        k_te = zeros(N_tr, 1);
        for j = 1:N_tr
            d_ij = sqrt(hE_te(j)^2 + hN_te(j)^2);
            k_g = (params.sigma_g^2) * exp(-d_ij / max(1.0, params.ell_g));
            
            if te_cells(i) == tr_cells(j) && te_cells(i) > 0
                az_c = te_az(i);
                [hp, ht] = sector_coordinate_transform(hE_te(j), hN_te(j), az_c);
                dA_c = sqrt((hp / max(1.0, params.a_par))^2 + (ht / max(1.0, params.a_trans))^2);
                k_c = (params.sigma_c^2) * exp(-dA_c);
            else
                k_c = 0.0;
            end
            k_te(j) = k_g + k_c;
        end
        
        w = K_inv * k_te;
        y_pred(i) = sum(w .* tr_y);
        y_var(i)  = max(0.0, total_var - sum(w .* k_te));
    end
end
