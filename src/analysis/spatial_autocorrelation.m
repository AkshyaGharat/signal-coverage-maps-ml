function autoCorr = spatial_autocorrelation(lats, lons, rsrp, binEdges, maxPairs)
% SPATIAL_AUTOCORRELATION Calculates distance-binned spatial correlation & semivariance.
%
% Syntax:
%   autoCorr = spatial_autocorrelation(lats, lons, rsrp, binEdges, maxPairs)
%
% Inputs:
%   lats     - Vector of latitudes
%   lons     - Vector of longitudes
%   rsrp     - Vector of RSRP measurements (dBm)
%   binEdges - Vector of distance bin boundaries in meters (e.g. 0:20:500)
%   maxPairs - Maximum pair samples to compute for large datasets (default: 50,000)

if nargin < 4 || isempty(binEdges)
    binEdges = 0:20:500; % 20-meter distance bins up to 500m
end
if nargin < 5 || isempty(maxPairs)
    maxPairs = 50000;
end

% Filter NaNs
validIdx = ~isnan(lats) & ~isnan(lons) & ~isnan(rsrp);
lats = lats(validIdx);
lons = lons(validIdx);
rsrp = rsrp(validIdx);

N = numel(rsrp);
R = 6371000; % Earth radius in meters

% Subsample if dataset is extremely large to keep computation tractable
if N > 2500
    rng(42); % Reproducible seed
    subIdx = randperm(N, 2500);
    lats = lats(subIdx);
    lons = lons(subIdx);
    rsrp = rsrp(subIdx);
    N = numel(rsrp);
end

% Compute pairwise Haversine distances & RSRP differences
numBins = numel(binEdges) - 1;
binCenters = (binEdges(1:end-1) + binEdges(2:end)) / 2;

sumSquareDiff = zeros(numBins, 1);
pairCounts    = zeros(numBins, 1);

meanRSRP = mean(rsrp);
varRSRP  = var(rsrp);

% Compute pairwise distances and semivariance
[iGrid, jGrid] = meshgrid(1:N, 1:N);
upperTri = iGrid < jGrid;
iIdx = iGrid(upperTri);
jIdx = jGrid(upperTri);

totalPairs = numel(iIdx);
if totalPairs > maxPairs
    rng(42);
    pSub = randperm(totalPairs, maxPairs);
    iIdx = iIdx(pSub);
    jIdx = jIdx(pSub);
end

dLat = deg2rad(lats(jIdx) - lats(iIdx));
dLon = deg2rad(lons(jIdx) - lons(iIdx));
lat1 = deg2rad(lats(iIdx));
lat2 = deg2rad(lats(jIdx));

a = sin(dLat/2).^2 + cos(lat1).*cos(lat2).*sin(dLon/2).^2;
c = 2 * atan2(sqrt(a), sqrt(1-a));
pairDists = R * c;

rsrpDiff = rsrp(iIdx) - rsrp(jIdx);
rsrpPairProd = (rsrp(iIdx) - meanRSRP) .* (rsrp(jIdx) - meanRSRP);

semivariance = zeros(numBins, 1);
correlation  = zeros(numBins, 1);

for b = 1:numBins
    inBin = pairDists >= binEdges(b) & pairDists < binEdges(b+1);
    cnt = sum(inBin);
    pairCounts(b) = cnt;
    
    if cnt > 5
        semivariance(b) = sum(rsrpDiff(inBin).^2) / (2 * cnt);
        correlation(b)  = sum(rsrpPairProd(inBin)) / (cnt * varRSRP);
    else
        semivariance(b) = NaN;
        correlation(b)  = NaN;
    end
end

autoCorr.BinEdges      = binEdges;
autoCorr.BinCenters    = binCenters;
autoCorr.Semivariance  = semivariance;
autoCorr.Correlation   = correlation;
autoCorr.PairCounts    = pairCounts;
autoCorr.MeanRSRP      = meanRSRP;
autoCorr.VarRSRP       = varRSRP;

end
