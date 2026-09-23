function [residual, rsrpPhys, modelParams] = compute_physical_baseline(dist3D, rsrpMeasured, pTx)
% COMPUTE_PHYSICAL_BASELINE Fits a calibrated Log-Distance Path Loss (LDPL) physical baseline.
%
% Formula:
%   RSRP_phys = pTx - (PL0 + 10 * n * log10(dist3D / d0))
%
% Inputs:
%   dist3D       - Vector of 3D slant distances to base station (meters)
%   rsrpMeasured - Vector of measured SS_RSRP values (dBm)
%   pTx          - Transmit power (dBm, default 24)

if nargin < 3 || isempty(pTx)
    pTx = 24.0;
end

validMask = ~isnan(dist3D) & ~isnan(rsrpMeasured) & dist3D > 1.0;

% Fit linear model: (pTx - rsrpMeasured) = PL0 + 10 * n * log10(dist3D)
pathLoss = pTx - rsrpMeasured(validMask);
logDist  = log10(dist3D(validMask));

% Calibration via Ordinary Least Squares on valid observations
X = [ones(sum(validMask), 1), 10 * logDist];
beta = X \ pathLoss;

PL0 = beta(1);
n_exp = beta(2);

rsrpPhys = NaN(size(rsrpMeasured));
rsrpPhys(validMask) = pTx - (PL0 + 10 * n_exp * log10(dist3D(validMask)));

residual = NaN(size(rsrpMeasured));
residual(validMask) = rsrpMeasured(validMask) - rsrpPhys(validMask);

modelParams.PL0 = PL0;
modelParams.PathLossExponent_n = n_exp;
modelParams.PTx = pTx;
modelParams.RMSE = sqrt(mean((residual(validMask)).^2));

end
