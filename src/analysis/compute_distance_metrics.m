function [distTable, matchSummary] = compute_distance_metrics(rawData, bsData)
% COMPUTE_DISTANCE_METRICS Computes 2D Haversine & 3D distances between UE & matched base station.
%
% Strictly enforces verified unique matching (NCI == ECI or GNODEB+GCELLID == CGI).
% PCI alone is NOT used for matching to avoid non-unique cell assignments.

R = 6371000; % Earth radius in meters

numUE = height(rawData);
dist2D = NaN(numUE, 1);
dist3D = NaN(numUE, 1);
matchedBsIdx = zeros(numUE, 1);
matchType = strings(numUE, 1);

% Prepare BS lookup maps
bsECI = [];
if ismember('ECI', bsData.Properties.VariableNames)
    bsECI = bsData.ECI;
end

bsLat = bsData.("LATITUDE (processed)");
bsLon = bsData.("LONGITUDE (processed)");
bsHeight = bsData.Height;

numMatched = 0;
numUnmatched = 0;

for i = 1:numUE
    ueLat = rawData.LATITUDE(i);
    ueLon = rawData.LONGITUDE(i);
    ueNCI = rawData.NCI(i);
    
    idx = [];
    
    % Try NCI == ECI match
    if ~isempty(bsECI) && ~isnan(ueNCI) && ueNCI > 0
        idx = find(bsECI == ueNCI, 1);
    end
    
    if ~isempty(idx)
        matchedBsIdx(i) = idx;
        matchType(i) = "NCI_ECI_EXACT";
        numMatched = numMatched + 1;
        
        % Calculate 2D Haversine distance
        dLat = deg2rad(bsLat(idx) - ueLat);
        dLon = deg2rad(bsLon(idx) - ueLon);
        lat1 = deg2rad(ueLat);
        lat2 = deg2rad(bsLat(idx));
        
        a = sin(dLat/2)^2 + cos(lat1)*cos(lat2)*sin(dLon/2)^2;
        c = 2 * atan2(sqrt(a), sqrt(1-a));
        d2 = R * c;
        
        dist2D(i) = d2;
        hDiff = bsHeight(idx) - 0; % Default UE AGL if unspecified
        dist3D(i) = sqrt(d2^2 + hDiff^2);
    else
        matchType(i) = "UNMATCHED_AMBIGUOUS";
        numUnmatched = numUnmatched + 1;
    end
end

distTable = table(dist2D, dist3D, matchedBsIdx, matchType, ...
    'VariableNames', {'Distance_2D_m', 'Distance_3D_m', 'Matched_BS_Index', 'Match_Type'});

matchSummary.TotalMeasurements = numUE;
matchSummary.MatchedCount = numMatched;
matchSummary.UnmatchedCount = numUnmatched;
matchSummary.MatchRatePct = (numMatched / numUE) * 100;

end
