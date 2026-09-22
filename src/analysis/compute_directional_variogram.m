function dirVariogram = compute_directional_variogram(lats, lons, rsrp, ueNCI, bsData, binEdges)
% COMPUTE_DIRECTIONAL_VARIOGRAM Calculates directional semivariograms gamma_parallel(h) vs gamma_transverse(h).
%
% Syntax:
%   dirVariogram = compute_directional_variogram(lats, lons, rsrp, ueNCI, bsData, binEdges)

if nargin < 6 || isempty(binEdges)
    binEdges = 0:25:500;
end

R = 6371000;
validIdx = ~isnan(lats) & ~isnan(lons) & ~isnan(rsrp) & ~isnan(ueNCI);
lats = lats(validIdx); lons = lons(validIdx); rsrp = rsrp(validIdx); ueNCI = ueNCI(validIdx);

bsECIMap = containers.Map('KeyType', 'double', 'ValueType', 'double');
for b = 1:height(bsData)
    if ismember('ECI', bsData.Properties.VariableNames) && ~isnan(bsData.ECI(b))
        bsECIMap(bsData.ECI(b)) = bsData.angle(b);
    end
end

N = numel(rsrp);
if N > 2000
    rng(42);
    subIdx = randperm(N, 2000);
    lats = lats(subIdx); lons = lons(subIdx); rsrp = rsrp(subIdx); ueNCI = ueNCI(subIdx);
    N = numel(rsrp);
end

[iGrid, jGrid] = meshgrid(1:N, 1:N);
upperTri = iGrid < jGrid;
iIdx = iGrid(upperTri); jIdx = jGrid(upperTri);

dLat = deg2rad(lats(jIdx) - lats(iIdx));
dLon = deg2rad(lons(jIdx) - lons(iIdx));
lat1 = deg2rad(lats(iIdx)); lat2 = deg2rad(lats(jIdx));

a = sin(dLat/2).^2 + cos(lat1).*cos(lat2).*sin(dLon/2).^2;
pairDists = R * (2 * atan2(sqrt(a), sqrt(1-a)));

y = sin(dLon) .* cos(lat2);
x = cos(lat1).*sin(lat2) - sin(lat1).*cos(lat2).*cos(dLon);
pairBearings = mod(rad2deg(atan2(y, x)), 360);

rsrpDiffSq = (rsrp(iIdx) - rsrp(jIdx)).^2;

numBins = numel(binEdges) - 1;
binCenters = (binEdges(1:end-1) + binEdges(2:end)) / 2;

gammaParallel  = zeros(numBins, 1);
gammaTransverse = zeros(numBins, 1);

for b = 1:numBins
    inDist = pairDists >= binEdges(b) & pairDists < binEdges(b+1);
    
    isPar = false(size(pairDists));
    isTrans = false(size(pairDists));
    
    for p = 1:numel(pairDists)
        if inDist(p)
            cID = ueNCI(iIdx(p));
            if isKey(bsECIMap, cID)
                az = bsECIMap(cID);
                bAngle = pairBearings(p);
                angleDiff = mod(abs(bAngle - az), 180);
                if angleDiff < 30 || angleDiff > 150
                    isPar(p) = true;
                elseif angleDiff >= 60 && angleDiff <= 120
                    isTrans(p) = true;
                end
            end
        end
    end
    
    cntPar = sum(isPar);
    cntTrans = sum(isTrans);
    
    if cntPar > 3
        gammaParallel(b) = sum(rsrpDiffSq(isPar)) / (2 * cntPar);
    else
        gammaParallel(b) = NaN;
    end
    
    if cntTrans > 3
        gammaTransverse(b) = sum(rsrpDiffSq(isTrans)) / (2 * cntTrans);
    else
        gammaTransverse(b) = NaN;
    end
end

dirVariogram.BinCenters      = binCenters;
dirVariogram.GammaParallel   = gammaParallel;
dirVariogram.GammaTransverse = gammaTransverse;

end
