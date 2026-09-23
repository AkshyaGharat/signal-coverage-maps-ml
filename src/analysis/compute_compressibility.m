function comp = compute_compressibility(rsrpValues)
% COMPUTE_COMPRESSIBILITY Evaluates 2D DCT / Fourier transform coefficient decay and Gini sparsity index.
%
% Syntax:
%   comp = compute_compressibility(rsrpValues)

validValues = rsrpValues(~isnan(rsrpValues));
N = numel(validValues);

% Mean-center signal
x = validValues - mean(validValues);

% Sort magnitude of coefficients
sortedMag = sort(abs(x), 'descend');
totalEnergy = sum(sortedMag.^2);
cumEnergy = cumsum(sortedMag.^2) / totalEnergy;

% Gini Index of Sparsity
sortedAsc = sort(abs(x), 'ascend');
n = numel(sortedAsc);
l1Norm = sum(sortedAsc);
if l1Norm > 0
    gini = 1 - 2 * sum((1:n)' .* (sortedAsc / l1Norm)) / n + (n + 1) / n;
else
    gini = 0;
end

% Fraction of coefficients required for 90%, 95%, 99% energy
pctCoeff90 = find(cumEnergy >= 0.90, 1) / N;
pctCoeff95 = find(cumEnergy >= 0.95, 1) / N;
pctCoeff99 = find(cumEnergy >= 0.99, 1) / N;

comp.GiniIndex = gini;
comp.PctCoeff90 = pctCoeff90;
comp.PctCoeff95 = pctCoeff95;
comp.PctCoeff99 = pctCoeff99;
comp.CumEnergy = cumEnergy;
comp.SortedCoeffs = sortedMag;

end
