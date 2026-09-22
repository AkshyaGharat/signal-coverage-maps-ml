function [rsrp_pred, residual_pred, rsrp_var] = residual_reconstruction(tr_data, te_data, ldpl_model, params)
% RESIDUAL_RECONSTRUCTION Predicts RSRP via Physics + Additive Sector-Aligned Anisotropic Residual Model:
% RSRP_pred(x) = RSRP_LDPL(x) + residual_pred(x)
%
% Inputs:
%   tr_data    - Table of training observations with Dist3D, SS_RSRP, LATITUDE, LONGITUDE, NCI, ServingAzimuth
%   te_data    - Table of test observations with Dist3D, LATITUDE, LONGITUDE, NCI, ServingAzimuth
%   ldpl_model - Calibrated LDPL model struct (PL0, n, Ptx)
%   params     - Struct of hyper-parameters for Additive SASR
%
% Outputs:
%   rsrp_pred     - Final RSRP predictions (dBm)
%   residual_pred - Predicted spatial shadow residuals (dB)
%   rsrp_var      - Predictive uncertainty variance (dB^2)

    Ptx = ldpl_model.Ptx;
    PL0 = ldpl_model.PL0;
    n_exp = ldpl_model.n;
    
    % Compute physical LDPL predictions
    tr_ldpl = Ptx - (PL0 + 10 * n_exp * log10(max(1.0, tr_data.Dist3D)));
    te_ldpl = Ptx - (PL0 + 10 * n_exp * log10(max(1.0, te_data.Dist3D)));
    
    % Residual field
    tr_data.residual = tr_data.SS_RSRP - tr_ldpl;
    
    % Reconstruct spatial residual field using Additive SASR Kernel
    [residual_pred, rsrp_var] = anisotropic_kriging(tr_data, te_data, 'residual', params);
    
    % Add physical pathloss prediction
    rsrp_pred = te_ldpl + residual_pred;
end
