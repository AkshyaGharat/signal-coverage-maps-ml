function cellStats = compute_cellwise_structure(rawData, bsData)
% COMPUTE_CELLWISE_STRUCTURE Evaluates spatial correlation decay and statistics per serving macro cell.
%
% Syntax:
%   cellStats = compute_cellwise_structure(rawData, bsData)

uniqueNCIs = unique(rawData.NCI(~isnan(rawData.NCI)));
cellStats = [];

for c = 1:numel(uniqueNCIs)
    nciVal = uniqueNCIs(c);
    mask = rawData.NCI == nciVal;
    cCount = sum(mask);
    
    if cCount >= 100
        cLats = rawData.LATITUDE(mask);
        cLons = rawData.LONGITUDE(mask);
        cRsrp = rawData.SS_RSRP(mask);
        
        cMean = mean(cRsrp);
        cStd  = std(cRsrp);
        cVar  = var(cRsrp);
        
        autoCorr = spatial_autocorrelation(cLats, cLons, cRsrp, 0:20:400);
        idxDecay = find(autoCorr.Correlation < 0.368, 1);
        if ~isempty(idxDecay)
            cCorrLen = autoCorr.BinCenters(idxDecay);
        else
            cCorrLen = 400;
        end
        
        s.NCI = nciVal;
        s.RecordCount = cCount;
        s.MeanRSRP = cMean;
        s.StdRSRP  = cStd;
        s.VarRSRP  = cVar;
        s.CorrelationLength_m = cCorrLen;
        
        cellStats = [cellStats; s];
    end
end

end
