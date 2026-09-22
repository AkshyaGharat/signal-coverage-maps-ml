function nonStat = compute_nonstationarity(lats, lons, rsrp, numRegions)
% COMPUTE_NONSTATIONARITY Evaluates spatial non-stationarity across geographic sub-regions.
%
% Syntax:
%   nonStat = compute_nonstationarity(lats, lons, rsrp, numRegions)

if nargin < 4 || isempty(numRegions)
    numRegions = 4; % 2x2 geographic grid
end

latMin = min(lats); latMax = max(lats);
lonMin = min(lons); lonMax = max(lons);

latMid = (latMin + latMax) / 2;
lonMid = (lonMin + lonMax) / 2;

regionStats = [];

for r = 1:4
    switch r
        case 1, mask = lats >= latMid & lons < lonMid;  rName = 'NorthWest';
        case 2, mask = lats >= latMid & lons >= lonMid; rName = 'NorthEast';
        case 3, mask = lats < latMid  & lons < lonMid;  rName = 'SouthWest';
        case 4, mask = lats < latMid  & lons >= lonMid; rName = 'SouthEast';
    end
    
    rRsrp = rsrp(mask);
    rLat = lats(mask);
    rLon = lons(mask);
    
    if numel(rRsrp) > 10
        rMean = mean(rRsrp);
        rStd  = std(rRsrp);
        rVar  = var(rRsrp);
        
        % Simple correlation length estimate
        autoCorr = spatial_autocorrelation(rLat, rLon, rRsrp, 0:20:300);
        idxDecay = find(autoCorr.Correlation < 0.368, 1);
        if ~isempty(idxDecay)
            corrLength = autoCorr.BinCenters(idxDecay);
        else
            corrLength = 300;
        end
    else
        rMean = NaN; rStd = NaN; rVar = NaN; corrLength = NaN;
    end
    
    s.RegionName = rName;
    s.RecordCount = sum(mask);
    s.MeanRSRP = rMean;
    s.StdRSRP  = rStd;
    s.VarRSRP  = rVar;
    s.CorrelationLength = corrLength;
    
    regionStats = [regionStats; s];
end

nonStat.RegionStats = regionStats;

end
