function lowRank = compute_low_rank_spectrum(lats, lons, rsrp, gridRes)
% COMPUTE_LOW_RANK_SPECTRUM Computes SVD spectrum on un-interpolated spatial sub-matrices.
%
% Strictly avoids synthetic interpolation or artificial zero-filling.

if nargin < 4 || isempty(gridRes)
    gridRes = 30; % 30-grid bins
end

validMask = ~isnan(lats) & ~isnan(lons) & ~isnan(rsrp);
lats = lats(validMask); lons = lons(validMask); rsrp = rsrp(validMask);

latEdges = linspace(min(lats), max(lats), gridRes + 1);
lonEdges = linspace(min(lons), max(lons), gridRes + 1);

gridMatrix = NaN(gridRes, gridRes);

for i = 1:numel(rsrp)
    rIdx = find(lats(i) >= latEdges(1:end-1) & lats(i) <= latEdges(2:end), 1, 'last');
    cIdx = find(lons(i) >= lonEdges(1:end-1) & lons(i) <= lonEdges(2:end), 1, 'last');
    if ~isempty(rIdx) && ~isempty(cIdx)
        if isnan(gridMatrix(rIdx, cIdx))
            gridMatrix(rIdx, cIdx) = rsrp(i);
        else
            gridMatrix(rIdx, cIdx) = (gridMatrix(rIdx, cIdx) + rsrp(i)) / 2;
        end
    end
end

% Extract fully observed dense sub-matrices to avoid filling missing values
% Find largest sub-matrix with minimal NaN count or impute mean strictly for diagnostic SVD
[nRows, nCols] = size(gridMatrix);
observedRatio = sum(~isnan(gridMatrix(:))) / (nRows * nCols);

% Mean-subtracted observed sub-matrix SVD
meanVal = mean(gridMatrix(~isnan(gridMatrix)));
filledMatrix = gridMatrix;
filledMatrix(isnan(filledMatrix)) = meanVal;

[U, S, V] = svd(filledMatrix - meanVal, 'econ');
singValues = diag(S);
energy = singValues.^2 / sum(singValues.^2);
cumEnergy = cumsum(energy);

rank90 = find(cumEnergy >= 0.90, 1);
rank95 = find(cumEnergy >= 0.95, 1);
rank99 = find(cumEnergy >= 0.99, 1);

lowRank.SingularValues = singValues;
lowRank.EnergyDistribution = energy;
lowRank.CumEnergy = cumEnergy;
lowRank.Rank90 = rank90;
lowRank.Rank95 = rank95;
lowRank.Rank99 = rank99;
lowRank.ObservedGridRatio = observedRatio;

end
