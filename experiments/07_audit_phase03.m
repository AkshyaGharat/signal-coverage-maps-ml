% audit_phase03.m
% Diagnostic Audit & Mathematical Verification of Phase 03 SASR Implementation
% Project: Signal Coverage Maps Using Measurements and Machine Learning

clear; clc; close all;

addpath(genpath('src'));

fprintf('====================================================\n');
fprintf('  Phase 03 Implementation Audit & Diagnostics\n');
fprintf('====================================================\n\n');

%% Ensure Output Directories Exist
if ~exist(fullfile('results', 'reconstruction'), 'dir')
    mkdir(fullfile('results', 'reconstruction'));
end

%% 1. Load Raw Datasets
fprintf('[1] Loading Raw Datasets for Audit...\n');
dataDir = fullfile('data', 'raw', 'CIM-5G');
[rawData, bsData, ~] = load_raw_data(dataDir);
[distTable, ~] = compute_distance_metrics(rawData, bsData);

bsAzMap = containers.Map('KeyType', 'double', 'ValueType', 'double');
for b = 1:height(bsData)
    if ismember('ECI', bsData.Properties.VariableNames) && ~isnan(bsData.ECI(b))
        bsAzMap(bsData.ECI(b)) = bsData.angle(b);
    end
end

azVec = zeros(height(rawData), 1);
for i = 1:height(rawData)
    if isKey(bsAzMap, rawData.NCI(i))
        azVec(i) = bsAzMap(rawData.NCI(i));
    else
        azVec(i) = 0.0;
    end
end
rawData.ServingAzimuth = azVec;
rawData.Dist3D = distTable.Distance_3D_m;

validMask = ~isnan(rawData.LATITUDE) & ~isnan(rawData.LONGITUDE) & ...
            ~isnan(rawData.SS_RSRP) & ~isnan(rawData.Dist3D) & (rawData.NCI > 0);
dataClean = rawData(validMask, :);

fprintf('    Clean Audit Dataset: %d records.\n\n', height(dataClean));

%% 2. Audit Check 1: Metric Local Coordinate Projection
fprintf('[2] Auditing Coordinate System & Local Metric Offsets...\n');
lat0 = mean(dataClean.LATITUDE);
lon0 = mean(dataClean.LONGITUDE);
R = 6371000;

xEast = R * deg2rad(dataClean.LONGITUDE - lon0) * cos(deg2rad(lat0));
yNorth = R * deg2rad(dataClean.LATITUDE - lat0);

fprintf('    xEast Range  : [%.2f, %.2f] m\n', min(xEast), max(xEast));
fprintf('    yNorth Range : [%.2f, %.2f] m\n\n', min(yNorth), max(yNorth));

%% 3. Audit Check 2: Actual Training Matrix Symmetry & Positive Semidefiniteness
fprintf('[3] Auditing Training Matrix Symmetry & Eigenvalues...\n');
sampleRatios = [0.10, 0.05, 0.02, 0.01];
auditResults = struct();

for r = 1:numel(sampleRatios)
    sRatio = sampleRatios(r);
    [trIdx, ~] = sparse_sampling(dataClean.LATITUDE, dataClean.LONGITUDE, sRatio, 'random', 42);
    trData = dataClean(trIdx, :);
    N_tr = height(trData);
    
    if N_tr > 800
        trData = trData(1:800, :);
        N_tr = 800;
    end
    
    [lat1, lat2] = meshgrid(trData.LATITUDE, trData.LATITUDE);
    [lon1, lon2] = meshgrid(trData.LONGITUDE, trData.LONGITUDE);
    [az1, az2]   = meshgrid(trData.ServingAzimuth, trData.ServingAzimuth);
    
    hx = R * deg2rad(lon2 - lon1) .* cos(deg2rad((lat1 + lat2)/2));
    hy = R * deg2rad(lat2 - lat1);
    
    % Test arithmetic mean azimuth
    azAvg = (az1 + az2) / 2;
    [hPar, hTrans] = sector_coordinate_transform(hx, hy, azAvg);
    K_tr = anisotropic_covariance(hPar, hTrans, 150.0, 75.0, 12.0, 2.0);
    
    maxAbsDiff = max(abs(K_tr - K_tr'), [], 'all');
    relFrobDiff = norm(K_tr - K_tr', 'fro') / norm(K_tr, 'fro');
    
    % Eigenvalue decomposition of symmetrized matrix
    K_sym = (K_tr + K_tr') / 2;
    eigVals = eig(K_sym);
    minEig = min(eigVals);
    maxEig = max(eigVals);
    condNum = maxEig / max(eps, abs(minEig));
    numNegEig = sum(eigVals < -1e-5);
    
    fprintf('    [Ratio %.0f%% (N=%d)] MaxAbsDiff = %.5e | RelFrob = %.5e | minEig = %.5e | cond = %.2e | negEigs = %d\n', ...
        sRatio*100, N_tr, maxAbsDiff, relFrobDiff, minEig, condNum, numNegEig);
    
    key = sprintf('ratio_%d', round(sRatio*100));
    auditResults.(key).N_tr = N_tr;
    auditResults.(key).MaxAbsDiff = maxAbsDiff;
    auditResults.(key).RelFrobDiff = relFrobDiff;
    auditResults.(key).MinEigenvalue = minEig;
    auditResults.(key).MaxEigenvalue = maxEig;
    auditResults.(key).ConditionNumber = condNum;
    auditResults.(key).NumNegEigenvalues = numNegEig;
end
fprintf('\n');

%% 4. Audit Check 3: Multi-Cell Pairwise Azimuth Asymmetry Audit
fprintf('[4] Auditing Multi-Cell Asymmetry d_A(i,j) vs d_A(j,i)...\n');
[trIdx, ~] = sparse_sampling(dataClean.LATITUDE, dataClean.LONGITUDE, 0.10, 'random', 42);
trData = dataClean(trIdx, :);
if height(trData) > 500, trData = trData(1:500, :); end

% Test individual observation azimuth: using observation i's azimuth vs observation j's
N_tr = height(trData);
asymDiffCount = 0;
maxAsymErr = 0;

for i = 1:N_tr
    for j = 1:N_tr
        if trData.NCI(i) ~= trData.NCI(j) % Pair across different cells
            az_i = trData.ServingAzimuth(i);
            az_j = trData.ServingAzimuth(j);
            
            hx_ij = R * deg2rad(trData.LONGITUDE(j) - trData.LONGITUDE(i)) * cos(deg2rad((trData.LATITUDE(i) + trData.LATITUDE(j))/2));
            hy_ij = R * deg2rad(trData.LATITUDE(j) - trData.LATITUDE(i));
            
            [hp_i, ht_i] = sector_coordinate_transform(hx_ij, hy_ij, az_i);
            dA_ij = sqrt((hp_i/150)^2 + (ht_i/75)^2);
            
            [hp_j, ht_j] = sector_coordinate_transform(-hx_ij, -hy_ij, az_j);
            dA_ji = sqrt((hp_j/150)^2 + (ht_j/75)^2);
            
            err = abs(dA_ij - dA_ji);
            if err > maxAsymErr, maxAsymErr = err; end
            if err > 1e-4, asymDiffCount = asymDiffCount + 1; end
        end
    end
end

fprintf('    Cross-Cell Pair Count with d_A(i,j) != d_A(j,i): %d / %d\n', asymDiffCount, N_tr*N_tr);
fprintf('    Max Distance Asymmetry Error: %.4f\n\n', maxAsymErr);

%% 5. Audit Check 4: Circular Angle Wrapping Audit
fprintf('[5] Auditing Circular Angle Wrapping (e.g. 359 deg vs 1 deg)...\n');
ang1 = 359.0; ang2 = 1.0;
arithMean = (ang1 + ang2) / 2;
circMean  = mod(rad2deg(atan2(sin(deg2rad(ang1)) + sin(deg2rad(ang2)), cos(deg2rad(ang1)) + cos(deg2rad(ang2)))), 360);

fprintf('    Angle 1: %.1f deg, Angle 2: %.1f deg\n', ang1, ang2);
fprintf('    Arithmetic Mean : %.1f deg (FLAWED)\n', arithMean);
fprintf('    Circular Mean   : %.1f deg (CORRECT)\n\n', circMean);

%% 6. Save Audit Results
fprintf('[6] Saving Phase 03 Audit Results to results/reconstruction/phase03_audit.mat...\n');
save(fullfile('results', 'reconstruction', 'phase03_audit.mat'), ...
    'auditResults', 'maxAsymErr', 'asymDiffCount', 'lat0', 'lon0');

fprintf('====================================================\n');
fprintf('  Phase 03 Audit Execution Completed Successfully\n');
fprintf('====================================================\n');
