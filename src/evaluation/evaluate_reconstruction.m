function metrics = evaluate_reconstruction(yTrue, yPred)
% EVALUATE_RECONSTRUCTION Computes RMSE, MAE, Max Error, and Weak-Signal Region RMSE/MAE.

validMask = ~isnan(yTrue) & ~isnan(yPred);
yt = yTrue(validMask);
yp = yPred(validMask);

err = yt - yp;

metrics.RMSE = sqrt(mean(err.^2));
metrics.MAE  = mean(abs(err));
metrics.MaxError = max(abs(err));

% Weak-signal region evaluation (RSRP < -90 dBm)
weakMask = yt < -90.0;
if sum(weakMask) > 5
    errWeak = yt(weakMask) - yp(weakMask);
    metrics.WeakRMSE = sqrt(mean(errWeak.^2));
    metrics.WeakMAE  = mean(abs(errWeak));
else
    metrics.WeakRMSE = NaN;
    metrics.WeakMAE  = NaN;
end

end
