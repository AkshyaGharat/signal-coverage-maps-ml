function anisotropy = compute_anisotropy(lats, lons, rsrp, ueNCI, bsData, binEdges)
% COMPUTE_ANISOTROPY Computes directional spatial correlation along serving sector azimuth vs transverse directions.
%
% Syntax:
%   anisotropy = compute_anisotropy(lats, lons, rsrp, ueNCI, bsData, binEdges)

if nargin < 6 || isempty(binEdges)
    binEdges = 0:25:500;
end

R = 6371000;
validIdx = ~isnan(lats) & ~isnan(lons) & ~isnan(rsrp) & ~isnan(ueNCI);
lats = lats(validIdx); lons = lons(validIdx); rsrp = rsrp(validIdx); ueNCI = ueNCI(validIdx);

% Map BS azimuths
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

% Compute pairwise distance & bearings
dLat = deg2rad(lats(jIdx) - lats(iIdx));
dLon = deg2rad(lons(jIdx) - lons(iIdx));
lat1 = deg2rad(lats(iIdx)); lat2 = deg2rad(lats(jIdx));

a = sin(dLat/2).^2 + cos(lat1).*cos(lat2).*sin(dLon/2).^2;
pairDists = R * (2 * atan2(sqrt(a), sqrt(1-a)));

% Pairwise bearing (0 to 360 deg)
y = sin(dLon) .* cos(lat2);
x = cos(lat1).*sin(lat2) - sin(lat1).*cos(lat2).*cos(dLon);
pairBearings = mod(rad2deg(atan2(y, x)), 360);

meanR = mean(rsrp); varR = var(rsrp);
rsrpPairProd = (rsrp(iIdx) - meanR) .* (rsrp(jIdx) - meanR);

numBins = numel(binEdges) - 1;
binCenters = (binEdges(1:end-1) + binEdges(2:end)) / 2;

corrParallel  = zeros(numBins, 1);
corrTransverse = zeros(numBins, 1);

for b = 1:numBins
    inDist = pairDists >= binEdges(b) & pairDists < binEdges(b+1);
    
    % Sector azimuth alignment: check if pair bearing aligns with serving cell azimuth
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
        corrParallel(b) = sum(rsrpPairProd(isPar)) / (cntPar * varR);
    else
        corrParallel(b) = NaN;
    end
    
    if cntTrans > 3
        corrTransverse(b) = sum(rsrpPairProd(isTrans)) / (cntTrans * varR);
    else
        corrTransverse(b) = NaN;
    end
end

anisotropy.BinCenters     = binCenters;
anisotropy.CorrParallel   = corrParallel;
anisotropy.CorrTransverse = corrTransverse;

end
