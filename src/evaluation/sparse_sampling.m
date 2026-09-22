function [trainIdx, testIdx] = sparse_sampling(lats, lons, sampleRatio, protocol, seed)
% SPARSE_SAMPLING Generates train/test split indices under 3 sampling protocols:
%   1. 'random'    - Random sampling
%   2. 'uniform'   - Spatially uniform grid sampling
%   3. 'clustered' - Clustered trajectory sampling

if nargin < 5 || isempty(seed), seed = 42; end
rng(seed);

N = numel(lats);
nTrain = round(sampleRatio * N);

switch lower(protocol)
    case 'random'
        p = randperm(N);
        trainIdx = p(1:nTrain);
        testIdx  = p(nTrain+1:end);
        
    case 'uniform'
        % Grid stride sampling
        stride = round(1 / sampleRatio);
        trainIdx = 1:stride:N;
        if numel(trainIdx) > nTrain
            trainIdx = trainIdx(1:nTrain);
        end
        testIdx = setdiff(1:N, trainIdx);
        
    case 'clustered'
        % Cluster centers simulate flight track gaps
        kClusters = max(5, round(nTrain / 50));
        cIndices = randperm(N, kClusters);
        
        dMat = zeros(N, kClusters);
        R = 6371000;
        for c = 1:kClusters
            dLat = deg2rad(lats - lats(cIndices(c)));
            dLon = deg2rad(lons - lons(cIndices(c)));
            a = sin(dLat/2).^2 + cos(deg2rad(lats(cIndices(c)))).*cos(deg2rad(lats)).*sin(dLon/2).^2;
            dMat(:, c) = R * (2 * atan2(sqrt(a), sqrt(1-a)));
        end
        minD = min(dMat, [], 2);
        [~, sIdx] = sort(minD, 'ascend');
        trainIdx = sIdx(1:nTrain);
        testIdx = sIdx(nTrain+1:end);
        
    otherwise
        error('Unknown sampling protocol: %s', protocol);
end

end
