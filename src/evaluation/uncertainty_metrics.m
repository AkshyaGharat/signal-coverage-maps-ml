function uncert = uncertainty_metrics(yTrue, yPred, predVar)
% UNCERTAINTY_METRICS Evaluates predictive variance calibration against true empirical error.

err = abs(yTrue - yPred);
predStd = sqrt(predVar);

validMask = ~isnan(err) & ~isnan(predStd) & predStd > 0;
err = err(validMask);
predStd = predStd(validMask);

meanErr = mean(err);
meanStd = mean(predStd);

corrErrVar = corr(err, predStd);
ratio = meanStd / (meanErr + 1e-6);

uncert.MeanError = meanErr;
uncert.MeanPredictedStd = meanStd;
uncert.CalibrationRatio = ratio;
uncert.CorrelationErrStd = corrErrVar;

end
