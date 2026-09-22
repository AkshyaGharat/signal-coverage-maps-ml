function [rsrpPred, modelParams] = ldpl_baseline(trainDist3D, trainRSRP, testDist3D, pTx)
% LDPL_BASELINE Fits a 2-parameter calibrated Log-Distance Pathloss model on training data.
%
% Formula:
%   RSRP_phys = pTx - (PL0 + 10 * n * log10(dist3D))

if nargin < 4 || isempty(pTx)
    pTx = 24.0;
end

validTrain = ~isnan(trainDist3D) & ~isnan(trainRSRP) & trainDist3D > 1.0;

pathLossTrain = pTx - trainRSRP(validTrain);
logDistTrain  = log10(trainDist3D(validTrain));

X = [ones(sum(validTrain), 1), 10 * logDistTrain];
beta = X \ pathLossTrain;

PL0 = beta(1);
n_exp = beta(2);

validTest = ~isnan(testDist3D) & testDist3D > 1.0;
rsrpPred = NaN(size(testDist3D));
rsrpPred(validTest) = pTx - (PL0 + 10 * n_exp * log10(testDist3D(validTest)));

modelParams.PL0 = PL0;
modelParams.PathLossExponent_n = n_exp;
modelParams.PTx = pTx;

end
