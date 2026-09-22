% 01_dataset_exploration.m
% Comprehensive Dataset Exploration & Spatial Characterization
% Project: Signal Coverage Maps Using Measurements and Machine Learning

clear; clc; close all;

% Add src folders to MATLAB path
addpath(genpath('src'));

fprintf('====================================================\n');
fprintf('  Phase 01: Dataset Exploration & Spatial Audit\n');
fprintf('====================================================\n\n');

%% Ensure Output Directories Exist
if ~exist(fullfile('figures', 'dataset'), 'dir')
    mkdir(fullfile('figures', 'dataset'));
end
if ~exist(fullfile('results', 'dataset'), 'dir')
    mkdir(fullfile('results', 'dataset'));
end

%% 1. Load Datasets
fprintf('[1] Loading Datasets from data/raw/CIM-5G...\n');
dataDir = fullfile('data', 'raw', 'CIM-5G');
[rawData, bsData, fishnetData] = load_raw_data(dataDir);

numRaw = height(rawData);
fprintf('    Loaded raw_datas.csv: %d records, %d columns.\n', numRaw, width(rawData));
fprintf('    Loaded base_station_data.csv: %d records, %d columns.\n', height(bsData), width(bsData));
fprintf('    Loaded fishnet_30x30: %d records, %d columns.\n\n', height(fishnetData), width(fishnetData));

%% 2. Missing Values & Duplicate Records Analysis
fprintf('[2] Auditing Missing Values and Duplicate Records...\n');
reportRaw = clean_and_inspect_missing(rawData, 'raw_datas');
reportBs  = clean_and_inspect_missing(bsData, 'base_station_data');
reportFish = clean_and_inspect_missing(fishnetData, 'fishnet_30x30');

fprintf('    Duplicate records in raw_datas.csv: %d\n', reportRaw.NumDuplicates);
fprintf('    Duplicate records in base_station_data.csv: %d\n\n', reportBs.NumDuplicates);

%% 3. Spatial & Temporal Coverage Bounds
fprintf('[3] Spatial & Temporal Coverage Bounds...\n');
latMin = min(rawData.LATITUDE);
latMax = max(rawData.LATITUDE);
lonMin = min(rawData.LONGITUDE);
lonMax = max(rawData.LONGITUDE);

fprintf('    Latitude Range  : [%.6f, %.6f] deg\n', latMin, latMax);
fprintf('    Longitude Range : [%.6f, %.6f] deg\n', lonMin, lonMax);

if ismember('TIME_dt', rawData.Properties.VariableNames)
    tValid = rawData.TIME_dt(~isnat(rawData.TIME_dt));
    if ~isempty(tValid)
        fprintf('    Timestamp Start : %s\n', datestr(min(tValid)));
        fprintf('    Timestamp End   : %s\n', datestr(max(tValid)));
    end
end

% Altitude coverage
if ismember('ALT_M_', fishnetData.Properties.VariableNames)
    altMin = min(fishnetData.ALT_M_);
    altMax = max(fishnetData.ALT_M_);
    fprintf('    Fishnet Altitude Range (ALT_M_): [%.2f, %.2f] m\n', altMin, altMax);
end
fprintf('\n');

%% 4. Cell ID & Base Station Hierarchy Analysis
fprintf('[4] Cell Identity & Base Station Hierarchy Analysis...\n');
numUniqueNCI   = numel(unique(rawData.NCI(~isnan(rawData.NCI))));
numUniqueGCELL = numel(unique(rawData.GCELLID(~isnan(rawData.GCELLID))));
numUniqueGNODE = numel(unique(rawData.GNODEB(~isnan(rawData.GNODEB))));
numUniquePCI   = numel(unique(rawData.NR_PCI(~isnan(rawData.NR_PCI))));

fprintf('    Unique NCIs    : %d\n', numUniqueNCI);
fprintf('    Unique GNODEBs : %d\n', numUniqueGNODE);
fprintf('    Unique GCELLIDs: %d\n', numUniqueGCELL);
fprintf('    Unique PCIs    : %d\n\n', numUniquePCI);

%% 5. RSRP Summary Statistics
fprintf('[5] Computing RSRP Summary Statistics...\n');
rsrpStats = compute_rsrp_stats(rawData.SS_RSRP);

fprintf('    Count  : %d\n', rsrpStats.Count);
fprintf('    Min    : %.2f dBm\n', rsrpStats.Min);
fprintf('    Max    : %.2f dBm\n', rsrpStats.Max);
fprintf('    Mean   : %.2f dBm\n', rsrpStats.Mean);
fprintf('    Median : %.2f dBm\n', rsrpStats.Median);
fprintf('    Std    : %.2f dB\n', rsrpStats.Std);
fprintf('    P5     : %.2f dBm | P25: %.2f dBm | P75: %.2f dBm | P95: %.2f dBm\n\n', ...
    rsrpStats.P5, rsrpStats.P25, rsrpStats.P75, rsrpStats.P95);

%% 6. Base-Station Matching & Distance Calculation
fprintf('[6] Base-Station Matching & Distance Calculation...\n');
[distTable, matchSummary] = compute_distance_metrics(rawData, bsData);
fprintf('    Matched Measurements   : %d / %d (%.2f%%)\n', ...
    matchSummary.MatchedCount, matchSummary.TotalMeasurements, matchSummary.MatchRatePct);
fprintf('    Unmatched/Ambiguous    : %d\n\n', matchSummary.UnmatchedCount);

%% 7. Spatial Autocorrelation & Semivariance
fprintf('[7] Computing Spatial Autocorrelation & Semivariance...\n');
autoCorr = spatial_autocorrelation(rawData.LATITUDE, rawData.LONGITUDE, rawData.SS_RSRP, 0:20:500);
fprintf('    Calculated correlation across %d distance bins (0 to 500m).\n\n', numel(autoCorr.BinCenters));

%% 8. Figure Generation
fprintf('[8] Generating Visualization Figures in figures/dataset/...\n');

% Fig 1: RSRP Distribution (Histogram & Empirical CDF)
h1 = figure('Name', 'RSRP Distribution', 'Visible', 'off');
subplot(1, 2, 1);
histogram(rawData.SS_RSRP, 30, 'FaceColor', [0.2 0.4 0.8], 'EdgeColor', 'w');
title('RSRP Histogram');
xlabel('SS_RSRP (dBm)'); ylabel('Frequency'); grid on;

subplot(1, 2, 2);
[f, x] = ecdf(rawData.SS_RSRP);
plot(x, f, 'LineWidth', 2, 'Color', [0.8 0.2 0.2]);
title('RSRP Empirical CDF');
xlabel('SS_RSRP (dBm)'); ylabel('Cumulative Probability'); grid on;
saveas(h1, fullfile('figures', 'dataset', 'fig01_rsrp_distribution.png'));
close(h1);

% Fig 2: Geographic Measurement Scatter Plot
h2 = figure('Name', 'Geographic Measurements Track', 'Visible', 'off');
scatter(rawData.LONGITUDE, rawData.LATITUDE, 6, [0.1 0.6 0.3], 'filled');
title('Geographic Measurement Tracks');
xlabel('Longitude (deg)'); ylabel('Latitude (deg)'); grid on; axis equal;
saveas(h2, fullfile('figures', 'dataset', 'fig02_geographic_measurements.png'));
close(h2);

% Fig 3: Geographic RSRP Map
h3 = figure('Name', 'Geographic RSRP Map', 'Visible', 'off');
scatter(rawData.LONGITUDE, rawData.LATITUDE, 10, rawData.SS_RSRP, 'filled');
colorbar; title('Geographic RSRP Map (dBm)');
xlabel('Longitude (deg)'); ylabel('Latitude (deg)'); grid on; axis equal;
saveas(h3, fullfile('figures', 'dataset', 'fig03_geographic_rsrp_map.png'));
close(h3);

% Fig 4: Measurement Density Grid
h4 = figure('Name', 'Measurement Density Grid', 'Visible', 'off');
histogram2(rawData.LONGITUDE, rawData.LATITUDE, [50 50], 'DisplayStyle', 'tile', 'ShowEmptyBins', 'on');
colorbar; title('Measurement Density Grid (Count per Bin)');
xlabel('Longitude (deg)'); ylabel('Latitude (deg)'); grid on; axis equal;
saveas(h4, fullfile('figures', 'dataset', 'fig04_measurement_density.png'));
close(h4);

% Fig 5: RSRP vs Distance
h5 = figure('Name', 'RSRP vs Distance', 'Visible', 'off');
validDist = ~isnan(distTable.Distance_2D_m);
scatter(distTable.Distance_2D_m(validDist), rawData.SS_RSRP(validDist), 10, [0.4 0.2 0.6], 'filled', 'MarkerFaceAlpha', 0.5);
title('SS_RSRP vs Base Station Haversine Distance');
xlabel('2D Distance to Base Station (m)'); ylabel('SS_RSRP (dBm)'); grid on;
saveas(h5, fullfile('figures', 'dataset', 'fig05_rsrp_vs_distance.png'));
close(h5);

% Fig 6: Base Stations Spatial Map
h6 = figure('Name', 'Base Stations Map', 'Visible', 'off');
scatter(bsData.("LONGITUDE (processed)"), bsData.("LATITUDE (processed)"), 60, [0.8 0.1 0.1], '^', 'filled');
hold on;
for k = 1:height(bsData)
    text(bsData.("LONGITUDE (processed)")(k)+0.0005, bsData.("LATITUDE (processed)")(k), ...
        sprintf('CGI:%d (Height:%dm)', bsData.CGI(k), bsData.Height(k)), 'FontSize', 7);
end
title('Physical Base Station Locations');
xlabel('Longitude (deg)'); ylabel('Latitude (deg)'); grid on; axis equal;
saveas(h6, fullfile('figures', 'dataset', 'fig06_base_stations_map.png'));
close(h6);

% Fig 7: Fishnet Observed vs Interpolated
h7 = figure('Name', 'Fishnet Observed vs Interpolated', 'Visible', 'off');
obsIdx = fishnetData.is_observed == 1;
interpIdx = fishnetData.is_interpolated == 1;

scatter(fishnetData.Center_X(obsIdx), fishnetData.Center_Y(obsIdx), 8, [0.1 0.7 0.2], 'filled'); hold on;
scatter(fishnetData.Center_X(interpIdx), fishnetData.Center_Y(interpIdx), 6, [0.8 0.4 0.1], 'filled', 'MarkerFaceAlpha', 0.4);
legend('Direct Observations (is\_observed=1)', 'Author Interpolated (is\_interpolated=1)', 'Location', 'best');
title('Fishnet Grid 30x30: Observed vs Author-Interpolated Cells');
xlabel('Center X (Longitude)'); ylabel('Center Y (Latitude)'); grid on; axis equal;
saveas(h7, fullfile('figures', 'dataset', 'fig07_fishnet_observed_vs_interpolated.png'));
close(h7);

% Fig 8: Spatial Autocorrelation & Semivariance vs Distance
h8 = figure('Name', 'Spatial Autocorrelation', 'Visible', 'off');
subplot(2, 1, 1);
plot(autoCorr.BinCenters, autoCorr.Correlation, '-o', 'LineWidth', 1.8, 'Color', [0.1 0.4 0.7], 'MarkerFaceColor', [0.1 0.4 0.7]);
title('Spatial RSRP Autocorrelation \rho(h) vs Distance Lag h');
xlabel('Separation Distance Lag h (m)'); ylabel('Correlation \rho(h)'); grid on;

subplot(2, 1, 2);
plot(autoCorr.BinCenters, autoCorr.Semivariance, '-s', 'LineWidth', 1.8, 'Color', [0.8 0.3 0.1], 'MarkerFaceColor', [0.8 0.3 0.1]);
title('Empirical Semivariance \gamma(h) vs Distance Lag h');
xlabel('Separation Distance Lag h (m)'); ylabel('Semivariance \gamma(h) (dB^2)'); grid on;
saveas(h8, fullfile('figures', 'dataset', 'fig08_spatial_correlation_vs_distance.png'));
close(h8);

fprintf('    All 8 figures successfully generated and saved in figures/dataset/.\n\n');

%% 9. Save Summary Outputs to results/dataset/
fprintf('[9] Saving Summary Outputs to results/dataset/...\n');
save(fullfile('results', 'dataset', 'raw_data_summary.mat'), 'rsrpStats', 'matchSummary', 'autoCorr', 'reportRaw', 'reportBs', 'reportFish');

fprintf('====================================================\n');
fprintf('  Phase 01 Dataset Exploration Completed Successfully\n');
fprintf('====================================================\n');
