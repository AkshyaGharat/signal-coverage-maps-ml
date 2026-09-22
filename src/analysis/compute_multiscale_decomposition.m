function multiScale = compute_multiscale_decomposition(lats, lons, rsrp)
% COMPUTE_MULTISCALE_DECOMPOSITION Evaluates spatial scale-space power spectrum across continuous scale ranges.
%
% Syntax:
%   multiScale = compute_multiscale_decomposition(lats, lons, rsrp)

validMask = ~isnan(lats) & ~isnan(lons) & ~isnan(rsrp);
lats = lats(validMask); lons = lons(validMask); rsrp = rsrp(validMask);

% Spatial autocorrelation scale spectrum
binEdges = 0:10:500;
autoCorr = spatial_autocorrelation(lats, lons, rsrp, binEdges);

% Continuous spatial scale power via FFT of spatial autocorrelation function
corrVec = autoCorr.Correlation;
corrVec(isnan(corrVec)) = 0;

scalePower = abs(fft(corrVec));
scaleFreqs = (0:numel(corrVec)-1) / (numel(corrVec) * 10); % 1/m

% Energy breakdown in scale bands
macroEnergy = sum(scalePower(scaleFreqs < 1/200));       % Scale > 200m
mesoEnergy  = sum(scalePower(scaleFreqs >= 1/200 & scaleFreqs < 1/50)); % 50-200m
microEnergy = sum(scalePower(scaleFreqs >= 1/50));        % Scale < 50m

totalE = macroEnergy + mesoEnergy + microEnergy;

multiScale.ScaleFreqs = scaleFreqs;
multiScale.ScalePower = scalePower;
multiScale.MacroPct   = (macroEnergy / totalE) * 100;
multiScale.MesoPct    = (mesoEnergy / totalE) * 100;
multiScale.MicroPct   = (microEnergy / totalE) * 100;

end
