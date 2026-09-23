function graphMetrics = compute_graph_smoothness(lats, lons, rsrp, kNN)
% COMPUTE_GRAPH_SMOOTHNESS Evaluates graph Laplacian smoothness S(x) = (x' * L * x) / ||x||^2.
%
% Syntax:
%   graphMetrics = compute_graph_smoothness(lats, lons, rsrp, kNN)

if nargin < 4 || isempty(kNN)
    kNN = 8;
end

validMask = ~isnan(lats) & ~isnan(lons) & ~isnan(rsrp);
lats = lats(validMask); lons = lons(validMask); rsrp = rsrp(validMask);

N = numel(rsrp);
if N > 1500
    rng(42);
    subIdx = randperm(N, 1500);
    lats = lats(subIdx); lons = lons(subIdx); rsrp = rsrp(subIdx);
    N = numel(rsrp);
end

R = 6371000;
[iGrid, jGrid] = meshgrid(1:N, 1:N);
dLat = deg2rad(lats(jGrid) - lats(iGrid));
dLon = deg2rad(lons(jGrid) - lons(iGrid));
lat1 = deg2rad(lats(iGrid)); lat2 = deg2rad(lats(jGrid));

a = sin(dLat/2).^2 + cos(lat1).*cos(lat2).*sin(dLon/2).^2;
distMatrix = R * (2 * atan2(sqrt(a), sqrt(1-a)));

% k-NN Adjacency matrix W
W = zeros(N, N);
sigmaG = 50; % 50m kernel width

for i = 1:N
    [sortedD, sortIdx] = sort(distMatrix(i, :));
    knnIdx = sortIdx(2:kNN+1); % Exclude self
    W(i, knnIdx) = exp(-sortedD(2:kNN+1).^2 / (2 * sigmaG^2));
end

W = (W + W') / 2; % Symmetrize
D = diag(sum(W, 2));
L = D - W;

% Graph Dirichlet energy / Smoothness
x = rsrp - mean(rsrp);
normX = norm(x);

if normX > 0
    smoothness = (x' * L * x) / (normX^2);
else
    smoothness = 0;
end

graphMetrics.GraphSmoothness = smoothness;
graphMetrics.NumNodes = N;
graphMetrics.kNN = kNN;

end
