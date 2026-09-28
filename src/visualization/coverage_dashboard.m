function fig = coverage_dashboard(predictionInput)
% COVERAGE_DASHBOARD Enhanced Interactive Geographic Coverage Map Dashboard
%
% Visualizes and compares 5 prediction modes over the 10,000-cell 30m x 30m grid:
%   - Mode A  : P0 (LDPL Physics Baseline)
%   - Mode B1 : P1 (LDPL + Isotropic Residual Reconstruction)
%   - Mode B2 : P2 (LDPL + Additive SASR Anisotropic Reconstruction)
%   - Mode C  : RF (Direct Random Forest ML-Only)
%   - Mode D  : P3 (Hybrid: P2 + RF Residual Correction)
%
% Features:
%   - Difference map modes (P3-P0, P2-P1, etc.) with diverging colormap
%   - Base station overlay with toggle (auto-loaded from CIM-5G data)
%   - Per-model metric cards with live RMSE / coverage statistics
%   - Click inspector with horizontal bar chart comparison
%   - RSRP distribution histogram
%   - Active model card highlighting
%   - Dynamic metric-preserving geographic map sizing
%
% Architecture:
%   The dashboard is strictly decoupled from training. It consumes precomputed
%   prediction results and switches between models instantly without retraining.
%
% Syntax:
%   coverage_dashboard()
%   coverage_dashboard(predictionTable)
%   coverage_dashboard('path/to/predictions.csv')

    %% ========== 1. LOAD PRECOMPUTED PREDICTIONS ==========
    if nargin < 1 || isempty(predictionInput)
        defaultFile = fullfile('results', 'final', 'all_models_grid_predictions.csv');
        if ~isfile(defaultFile)
            error('coverage_dashboard: Prediction file not found: %s. Run experiments/06_interactive_coverage_map.m first.', defaultFile);
        end
        predictionInput = defaultFile;
    end

    if ischar(predictionInput) || isstring(predictionInput)
        fprintf('[Dashboard] Loading predictions from: %s\n', predictionInput);
        T = readtable(predictionInput, 'VariableNamingRule', 'preserve');
    elseif istable(predictionInput)
        T = predictionInput;
    else
        error('coverage_dashboard: Input must be a table or filepath string.');
    end

    % Standardize Coordinate Columns
    if ismember('Center_X', T.Properties.VariableNames)
        lonFull = double(T.Center_X);
    elseif ismember('LONGITUDE', T.Properties.VariableNames)
        lonFull = double(T.LONGITUDE);
    else
        error('coverage_dashboard: Longitude column (Center_X) missing.');
    end

    if ismember('Center_Y', T.Properties.VariableNames)
        latFull = double(T.Center_Y);
    elseif ismember('LATITUDE', T.Properties.VariableNames)
        latFull = double(T.LATITUDE);
    else
        error('coverage_dashboard: Latitude column (Center_Y) missing.');
    end

    %% ========== 2. BUILD MODEL MAP ==========
    modelMap = containers.Map();
    modelNames = {};

    if ismember('P0_RSRP', T.Properties.VariableNames)
        modelMap('P0: LDPL Physics') = double(T.P0_RSRP);
        modelNames{end+1} = 'P0: LDPL Physics';
    end
    if ismember('P1_RSRP', T.Properties.VariableNames)
        modelMap('P1: Isotropic Kriging') = double(T.P1_RSRP);
        modelNames{end+1} = 'P1: Isotropic Kriging';
    end
    if ismember('P2_RSRP', T.Properties.VariableNames)
        modelMap('P2: Additive SASR') = double(T.P2_RSRP);
        modelNames{end+1} = 'P2: Additive SASR';
    end
    if ismember('RF_RSRP', T.Properties.VariableNames)
        modelMap('RF: Random Forest') = double(T.RF_RSRP);
        modelNames{end+1} = 'RF: Random Forest';
    elseif ismember('Predicted_RSRP', T.Properties.VariableNames)
        modelMap('RF: Random Forest') = double(T.Predicted_RSRP);
        modelNames{end+1} = 'RF: Random Forest';
    end
    if ismember('P3_RSRP', T.Properties.VariableNames)
        modelMap('P3: Hybrid (P2+RF)') = double(T.P3_RSRP);
        modelNames{end+1} = 'P3: Hybrid (P2+RF)';
    end

    if isempty(modelMap)
        if ismember('Predicted_RSRP', T.Properties.VariableNames)
            modelMap('RF: Random Forest') = double(T.Predicted_RSRP);
            modelNames{end+1} = 'RF: Random Forest';
        else
            error('coverage_dashboard: No valid prediction columns found.');
        end
    end

    % Add difference map modes
    diffPrefix = char(916);  % Greek Delta
    diffNames = {};
    if isKey(modelMap, 'P3: Hybrid (P2+RF)') && isKey(modelMap, 'P0: LDPL Physics')
        k = [diffPrefix ' P3-P0 (Total Gain)'];
        modelMap(k) = modelMap('P3: Hybrid (P2+RF)') - modelMap('P0: LDPL Physics');
        diffNames{end+1} = k;
    end
    if isKey(modelMap, 'P2: Additive SASR') && isKey(modelMap, 'P1: Isotropic Kriging')
        k = [diffPrefix ' P2-P1 (SASR Effect)'];
        modelMap(k) = modelMap('P2: Additive SASR') - modelMap('P1: Isotropic Kriging');
        diffNames{end+1} = k;
    end
    if isKey(modelMap, 'P3: Hybrid (P2+RF)') && isKey(modelMap, 'P2: Additive SASR')
        k = [diffPrefix ' P3-P2 (ML Residual)'];
        modelMap(k) = modelMap('P3: Hybrid (P2+RF)') - modelMap('P2: Additive SASR');
        diffNames{end+1} = k;
    end
    if isKey(modelMap, 'RF: Random Forest') && isKey(modelMap, 'P2: Additive SASR')
        k = [diffPrefix ' RF-P2 (ML vs Kriging)'];
        modelMap(k) = modelMap('RF: Random Forest') - modelMap('P2: Additive SASR');
        diffNames{end+1} = k;
    end

    allKeys = [modelNames, diffNames];

    % Default: prefer P3 or P2 as initial view
    if ismember('P3: Hybrid (P2+RF)', allKeys)
        currentModelKey = 'P3: Hybrid (P2+RF)';
    elseif ismember('P2: Additive SASR', allKeys)
        currentModelKey = 'P2: Additive SASR';
    else
        currentModelKey = allKeys{1};
    end

    rsrpCurrent = modelMap(currentModelKey);
    valid = isfinite(latFull) & isfinite(lonFull) & isfinite(rsrpCurrent);
    validIdx = find(valid);

    %% ========== 3. LOAD BASE STATION DATA ==========
    bsLat = []; bsLon = []; bsLabels = {}; bsAzimuths = [];
    bsLoaded = false;
    bsFile = fullfile('data', 'raw', 'CIM-5G', 'base_station_data.csv');
    if isfile(bsFile)
        try
            bsT = readtable(bsFile, 'VariableNamingRule', 'preserve');
            % CIM-5G column names
            latCol = 'LATITUDE (processed)';
            lonCol = 'LONGITUDE (processed)';
            if ismember(latCol, bsT.Properties.VariableNames) && ismember(lonCol, bsT.Properties.VariableNames)
                bsLat = double(bsT.(latCol));
                bsLon = double(bsT.(lonCol));
            elseif ismember('LATITUDE', bsT.Properties.VariableNames) && ismember('LONGITUDE', bsT.Properties.VariableNames)
                bsLat = double(bsT.LATITUDE);
                bsLon = double(bsT.LONGITUDE);
            end
            if ~isempty(bsLat)
                % Station labels from ECI or index
                if ismember('ECI', bsT.Properties.VariableNames)
                    eciVals = bsT.ECI;
                    if isnumeric(eciVals)
                        bsLabels = arrayfun(@(i) sprintf('BS%d', i), (1:numel(bsLat))', 'UniformOutput', false);
                    else
                        bsLabels = cellstr(eciVals);
                    end
                else
                    bsLabels = arrayfun(@(i) sprintf('BS%d', i), (1:numel(bsLat))', 'UniformOutput', false);
                end
                % Sector azimuths for directional markers
                if ismember('angle', bsT.Properties.VariableNames)
                    bsAzimuths = double(bsT.angle);
                end
                bsLoaded = true;
                fprintf('[Dashboard] Loaded %d base stations.\n', numel(bsLat));
            end
        catch ME
            fprintf('[Dashboard] Warning: Could not load base stations: %s\n', ME.message);
        end
    end

    %% ========== 4. COLOR PALETTE ==========
    bgColor     = [0.025 0.038 0.065];
    panelColor  = [0.042 0.062 0.098];
    panelColor2 = [0.058 0.082 0.125];
    borderColor = [0.10 0.16 0.25];
    whiteColor  = [0.92 0.95 1.00];
    grayColor   = [0.55 0.60 0.70];
    mutedColor  = [0.38 0.42 0.52];
    accentBlue  = [0.18 0.52 0.95];
    cyanColor   = [0.00 0.78 0.95];
    greenColor  = [0.15 0.82 0.40];
    orangeColor = [1.00 0.55 0.10];

    % Per-model accent colors for cards and bar chart
    mColors = struct();
    mColors.P0 = [0.50 0.52 0.58];
    mColors.P1 = [0.25 0.55 0.85];
    mColors.P2 = [0.15 0.75 0.40];
    mColors.RF = [0.95 0.55 0.10];
    mColors.P3 = [0.20 0.50 0.95];

    % Model card configuration (order matters)
    cardOrder  = {'P0: LDPL Physics', 'P1: Isotropic Kriging', 'P2: Additive SASR', ...
                  'RF: Random Forest', 'P3: Hybrid (P2+RF)'};
    cardTitles = {'MODE A: P0', 'MODE B1: P1', 'MODE B2: P2', 'MODE C: RF', 'MODE D: P3'};
    cardDescs  = {'LDPL Physics', 'Isotropic Kriging', 'Additive SASR', 'Random Forest', 'Hybrid P2+RF'};
    cardAccent = {mColors.P0, mColors.P1, mColors.P2, mColors.RF, mColors.P3};

    % Display downsampling for smooth rendering
    maxDisplayPoints = 5000;
    nValid = numel(validIdx);
    if nValid > maxDisplayPoints
        stride = ceil(nValid / maxDisplayPoints);
        dispIdx = validIdx(1:stride:end);
    else
        dispIdx = validIdx;
    end

    %% ========== 5. MAIN FIGURE & GRID ==========
    fig = uifigure( ...
        'Name', '5G RSRP Coverage Reconstruction Dashboard', ...
        'Color', bgColor, ...
        'Position', [30 30 1600 920]);

    mainGrid = uigridlayout(fig, [3 3]);
    mainGrid.RowHeight = {60, '1x', 100};
    mainGrid.ColumnWidth = {280, '1x', 330};
    mainGrid.Padding = [8 8 8 8];
    mainGrid.RowSpacing = 6;
    mainGrid.ColumnSpacing = 6;

    %% ========== 6. HEADER ==========
    header = uipanel(mainGrid, 'BackgroundColor', bgColor, 'BorderType', 'none');
    header.Layout.Row = 1; header.Layout.Column = [1 3];

    headerGrid = uigridlayout(header, [2 2]);
    headerGrid.RowHeight = {28, 18};
    headerGrid.ColumnWidth = {'1x', 360};
    headerGrid.Padding = [4 0 4 0];
    headerGrid.RowSpacing = 2;

    titleLbl = uilabel(headerGrid, ...
        'Text', '5G RSRP SIGNAL COVERAGE RECONSTRUCTION', ...
        'FontName', 'Segoe UI', 'FontSize', 17, 'FontWeight', 'bold', ...
        'FontColor', whiteColor);
    titleLbl.Layout.Row = 1; titleLbl.Layout.Column = 1;

    subLbl = uilabel(headerGrid, ...
        'Text', 'CIM-5G Mountainous Urban Terrain  |  Five-Mode Prediction & Physics-ML Residual Synthesis', ...
        'FontName', 'Segoe UI', 'FontSize', 10, 'FontColor', grayColor);
    subLbl.Layout.Row = 2; subLbl.Layout.Column = 1;

    activeModelLabel = uilabel(headerGrid, ...
        'Text', sprintf('Active: %s', currentModelKey), ...
        'FontName', 'Segoe UI', 'FontSize', 12, 'FontWeight', 'bold', ...
        'FontColor', cyanColor, 'HorizontalAlignment', 'right');
    activeModelLabel.Layout.Row = 1; activeModelLabel.Layout.Column = 2;

    statusLabel = uilabel(headerGrid, ...
        'Text', sprintf('Grid: %d cells  |  Valid: %d  |  Display: %d', numel(latFull), nValid, numel(dispIdx)), ...
        'FontName', 'Segoe UI', 'FontSize', 9, 'FontColor', mutedColor, ...
        'HorizontalAlignment', 'right');
    statusLabel.Layout.Row = 2; statusLabel.Layout.Column = 2;

    %% ========== 7. LEFT CONTROL PANEL ==========
    leftPanel = uipanel(mainGrid, 'BackgroundColor', panelColor, 'BorderType', 'line', ...
        'HighlightColor', borderColor);
    leftPanel.Layout.Row = 2; leftPanel.Layout.Column = 1;

    leftGrid = uigridlayout(leftPanel, [14 1]);
    leftGrid.RowHeight = {18, 28, 6, 18, 28, 6, 18, 38, 10, 18, 28, 28, 10, 32};
    leftGrid.Padding = [10 10 10 8];
    leftGrid.RowSpacing = 2;

    % Model selector
    uilabel(leftGrid, 'Text', 'PREDICTION MODEL', 'FontWeight', 'bold', ...
        'FontColor', cyanColor, 'FontSize', 10);
    modelDropDown = uidropdown(leftGrid, 'Items', allKeys, 'Value', currentModelKey, ...
        'BackgroundColor', panelColor2, 'FontColor', whiteColor, 'FontSize', 10);

    % Separator
    uilabel(leftGrid, 'Text', '', 'BackgroundColor', borderColor);

    % Basemap selector
    uilabel(leftGrid, 'Text', 'BASEMAP', 'FontWeight', 'bold', ...
        'FontColor', cyanColor, 'FontSize', 10);
    basemapDropDown = uidropdown(leftGrid, ...
        'Items', {'topographic', 'satellite', 'streets', 'darkwater'}, ...
        'Value', 'topographic', 'BackgroundColor', panelColor2, 'FontColor', whiteColor, 'FontSize', 10);

    % Separator
    uilabel(leftGrid, 'Text', '', 'BackgroundColor', borderColor);

    % Weak signal threshold
    thresholdLabel = uilabel(leftGrid, 'Text', 'WEAK SIGNAL CUTOFF: -85.0 dBm', ...
        'FontWeight', 'bold', 'FontColor', orangeColor, 'FontSize', 10);
    thresholdSlider = uislider(leftGrid, 'Limits', [-110 -65], 'Value', -85.0, ...
        'FontColor', whiteColor, 'MajorTicks', -110:10:-70);

    % Spacer
    uilabel(leftGrid, 'Text', '');

    % Zone filter
    uilabel(leftGrid, 'Text', 'DISPLAY FILTER', 'FontWeight', 'bold', ...
        'FontColor', cyanColor, 'FontSize', 10);
    zoneDropDown = uidropdown(leftGrid, ...
        'Items', {'All Points', 'Weak Zones Only', 'Strong Zones (>= -70 dBm)'}, ...
        'Value', 'All Points', 'BackgroundColor', panelColor2, 'FontColor', whiteColor, 'FontSize', 10);

    % Base station toggle
    if bsLoaded
        bsToggle = uicheckbox(leftGrid, ...
            'Text', sprintf('  Show %d Base Stations', numel(bsLat)), ...
            'FontColor', greenColor, 'FontSize', 10, 'Value', false);
    else
        bsToggle = uicheckbox(leftGrid, ...
            'Text', '  Base Stations (not found)', ...
            'FontColor', mutedColor, 'FontSize', 10, 'Value', false, 'Enable', 'off');
    end

    % Spacer
    uilabel(leftGrid, 'Text', '');

    % Export button
    exportBtn = uibutton(leftGrid, 'push', 'Text', 'Export Map (PNG)', ...
        'BackgroundColor', accentBlue, 'FontColor', whiteColor, ...
        'FontWeight', 'bold', 'FontSize', 10);

    %% ========== 8. CENTER GEOGRAPHIC MAP ==========
    mapPanel = uipanel(mainGrid, 'BackgroundColor', panelColor, 'BorderType', 'line', ...
        'HighlightColor', borderColor, 'AutoResizeChildren', 'off');
    mapPanel.Layout.Row = 2; mapPanel.Layout.Column = 2;

    % Geographic bounding box with local metric aspect ratio
    minLat = min(latFull(valid)); maxLat = max(latFull(valid));
    minLon = min(lonFull(valid)); maxLon = max(lonFull(valid));
    meanLat = (minLat + maxLat) / 2;
    dLat = max(1e-6, maxLat - minLat);
    dLon = max(1e-6, (maxLon - minLon) * cosd(meanLat));
    geoAspect = dLon / dLat;

    latPad = dLat * 0.02;
    lonPad = (maxLon - minLon) * 0.02;
    latLimits = [minLat - latPad, maxLat + latPad];
    lonLimits = [minLon - lonPad, maxLon + lonPad];

    try
        geoAx = geoaxes(mapPanel, 'Basemap', 'topographic');
    catch
        geoAx = axes(mapPanel);
        geoAx.Color = bgColor;
    end

    hold(geoAx, 'on');
    scatterPlot = geoscatter(geoAx, latFull(dispIdx), lonFull(dispIdx), ...
        22, rsrpCurrent(dispIdx), 'filled');

    % Standard turbo colormap
    cmap_turbo = turbo(256);
    colormap(geoAx, cmap_turbo);
    cbar = colorbar(geoAx);
    cbar.Color = whiteColor;
    cbar.Label.String = 'Predicted RSRP (dBm)';
    cbar.Label.Color = whiteColor;
    cbar.Label.FontSize = 9;
    try clim(geoAx, [-110 -55]); catch; caxis(geoAx, [-110 -55]); end

    % Click marker (white star)
    clickMarker = geoscatter(geoAx, NaN, NaN, 220, orangeColor, 'p', 'LineWidth', 2.5, ...
        'MarkerEdgeColor', [0.2 0.1 0]);

    % Base station markers (initially hidden)
    bsScatter = [];
    bsTextHandles = {};
    if bsLoaded
        bsScatter = geoscatter(geoAx, bsLat, bsLon, 110, ...
            'r', '^', 'filled', 'LineWidth', 1.5, 'MarkerEdgeColor', [1 1 1]);
        bsScatter.Visible = 'off';
        for bi = 1:numel(bsLat)
            ht = text(geoAx, bsLat(bi) + dLat*0.012, bsLon(bi), bsLabels{bi}, ...
                'Color', [1 0.35 0.35], 'FontSize', 8, 'FontWeight', 'bold', 'Visible', 'off');
            bsTextHandles{end+1} = ht;
        end
    end

    %% ========== 9. RIGHT PANEL (Statistics + Histogram + Click Inspector) ==========
    rightPanel = uipanel(mainGrid, 'BackgroundColor', panelColor, 'BorderType', 'line', ...
        'HighlightColor', borderColor);
    rightPanel.Layout.Row = 2; rightPanel.Layout.Column = 3;

    rightGrid = uigridlayout(rightPanel, [3 1]);
    rightGrid.RowHeight = {145, '1x', '1.4x'};
    rightGrid.Padding = [6 6 6 6];
    rightGrid.RowSpacing = 6;

    % --- Statistics Sub-Panel ---
    statsPanel = uipanel(rightGrid, 'BackgroundColor', panelColor2, 'BorderType', 'none');
    statsGrid = uigridlayout(statsPanel, [8 2]);
    statsGrid.RowHeight = {17, 15, 15, 15, 4, 17, 15, 15};
    statsGrid.ColumnWidth = {'1x', '1x'};
    statsGrid.Padding = [8 6 8 4];
    statsGrid.RowSpacing = 1;

    sLbl1 = uilabel(statsGrid, 'Text', 'COVERAGE STATISTICS', 'FontWeight', 'bold', ...
        'FontColor', cyanColor, 'FontSize', 10);
    sLbl1.Layout.Row = 1; sLbl1.Layout.Column = [1 2];

    lblMean = uilabel(statsGrid, 'Text', 'Mean: --', 'FontColor', whiteColor, 'FontSize', 10);
    lblMean.Layout.Row = 2; lblMean.Layout.Column = 1;
    lblStd = uilabel(statsGrid, 'Text', 'Std: --', 'FontColor', whiteColor, 'FontSize', 10);
    lblStd.Layout.Row = 2; lblStd.Layout.Column = 2;

    lblRange = uilabel(statsGrid, 'Text', 'Range: --', 'FontColor', whiteColor, 'FontSize', 10);
    lblRange.Layout.Row = 3; lblRange.Layout.Column = [1 2];

    lblCov70 = uilabel(statsGrid, 'Text', '>= -70 dBm: --', 'FontColor', greenColor, 'FontSize', 10);
    lblCov70.Layout.Row = 4; lblCov70.Layout.Column = 1;
    lblCov80 = uilabel(statsGrid, 'Text', '>= -80 dBm: --', 'FontColor', whiteColor, 'FontSize', 10);
    lblCov80.Layout.Row = 4; lblCov80.Layout.Column = 2;

    % Separator line
    sepLine = uilabel(statsGrid, 'Text', '', 'BackgroundColor', borderColor);
    sepLine.Layout.Row = 5; sepLine.Layout.Column = [1 2];

    sLbl2 = uilabel(statsGrid, 'Text', 'CRITICAL ZONES', 'FontWeight', 'bold', ...
        'FontColor', orangeColor, 'FontSize', 10);
    sLbl2.Layout.Row = 6; sLbl2.Layout.Column = [1 2];

    lblWeakPct = uilabel(statsGrid, 'Text', 'Weak: --', 'FontColor', orangeColor, 'FontSize', 10);
    lblWeakPct.Layout.Row = 7; lblWeakPct.Layout.Column = 1;
    lblCov85 = uilabel(statsGrid, 'Text', '>= -85 dBm: --', 'FontColor', whiteColor, 'FontSize', 10);
    lblCov85.Layout.Row = 7; lblCov85.Layout.Column = 2;

    lblMedian = uilabel(statsGrid, 'Text', 'Median: --', 'FontColor', whiteColor, 'FontSize', 10);
    lblMedian.Layout.Row = 8; lblMedian.Layout.Column = 1;
    lblIQR = uilabel(statsGrid, 'Text', 'IQR: --', 'FontColor', whiteColor, 'FontSize', 10);
    lblIQR.Layout.Row = 8; lblIQR.Layout.Column = 2;

    % --- Histogram Sub-Panel ---
    histPanel = uipanel(rightGrid, 'BackgroundColor', panelColor2, 'BorderType', 'none');
    histLayout = uigridlayout(histPanel, [2 1]);
    histLayout.RowHeight = {16, '1x'};
    histLayout.Padding = [6 4 6 2];
    histLayout.RowSpacing = 2;

    uilabel(histLayout, 'Text', 'RSRP DISTRIBUTION', 'FontWeight', 'bold', ...
        'FontColor', cyanColor, 'FontSize', 10);

    histAx = uiaxes(histLayout);
    histAx.Color = panelColor;
    histAx.XColor = grayColor; histAx.YColor = grayColor;
    histAx.FontSize = 8;
    histAx.Box = 'off';
    histAx.Toolbar.Visible = 'off';

    % --- Click Inspector Sub-Panel ---
    clickPanel = uipanel(rightGrid, 'BackgroundColor', panelColor2, 'BorderType', 'none');
    clickLayout = uigridlayout(clickPanel, [3 1]);
    clickLayout.RowHeight = {16, 14, '1x'};
    clickLayout.Padding = [6 4 6 2];
    clickLayout.RowSpacing = 2;

    uilabel(clickLayout, 'Text', 'CELL INSPECTOR', 'FontWeight', 'bold', ...
        'FontColor', cyanColor, 'FontSize', 10);
    lblClickCoord = uilabel(clickLayout, 'Text', 'Click any map location to inspect', ...
        'FontColor', mutedColor, 'FontSize', 9);

    barAx = uiaxes(clickLayout);
    barAx.Color = panelColor;
    barAx.XColor = grayColor; barAx.YColor = grayColor;
    barAx.FontSize = 8;
    barAx.Box = 'off';
    barAx.YDir = 'reverse';
    barAx.Toolbar.Visible = 'off';
    title(barAx, '');

    %% ========== 10. BOTTOM METRIC CARDS ==========
    bottomPanel = uipanel(mainGrid, 'BackgroundColor', bgColor, 'BorderType', 'none');
    bottomPanel.Layout.Row = 3; bottomPanel.Layout.Column = [1 3];

    bottomGrid = uigridlayout(bottomPanel, [1 5]);
    bottomGrid.ColumnWidth = {'1x', '1x', '1x', '1x', '1x'};
    bottomGrid.Padding = [0 0 0 0];
    bottomGrid.ColumnSpacing = 6;

    cardPanels = cell(1, 5);
    cardMetricLabels = cell(1, 5);
    cardCovLabels = cell(1, 5);

    for ci = 1:5
        mKey = cardOrder{ci};
        accent = cardAccent{ci};

        cp = uipanel(bottomGrid, 'BackgroundColor', panelColor, 'BorderType', 'line', ...
            'HighlightColor', accent);
        cg = uigridlayout(cp, [3 1]);
        cg.RowHeight = {17, 13, 13};
        cg.Padding = [8 4 8 3];
        cg.RowSpacing = 1;

        uilabel(cg, 'Text', cardTitles{ci}, 'FontWeight', 'bold', ...
            'FontColor', accent, 'FontSize', 10);

        if isKey(modelMap, mKey)
            vals = modelMap(mKey);
            vf = vals(isfinite(vals));
            ml = uilabel(cg, 'Text', ...
                sprintf('Mean: %.1f dBm  |  Std: %.1f dB', mean(vf), std(vf)), ...
                'FontColor', whiteColor, 'FontSize', 9);
            cl = uilabel(cg, 'Text', ...
                sprintf('>=-80: %.0f%%  |  >=-85: %.0f%%', mean(vf >= -80)*100, mean(vf >= -85)*100), ...
                'FontColor', grayColor, 'FontSize', 9);
        else
            ml = uilabel(cg, 'Text', 'No data', 'FontColor', mutedColor, 'FontSize', 9);
            cl = uilabel(cg, 'Text', '', 'FontColor', mutedColor, 'FontSize', 9);
        end

        cardPanels{ci} = cp;
        cardMetricLabels{ci} = ml;
        cardCovLabels{ci} = cl;
    end

    %% ========== 11. DIVERGING COLORMAP (for difference maps) ==========
    n = 128;
    half_blue = [linspace(0.12, 1, n)', linspace(0.28, 1, n)', linspace(0.84, 1, n)'];
    half_red  = [linspace(1, 0.84, n)', linspace(1, 0.18, n)', linspace(1, 0.12, n)'];
    cmap_diverging = [half_blue; half_red];

    %% ========== 12. CALLBACK FUNCTIONS ==========

    function isDiff = isDifferenceMap(keyName)
        isDiff = ~isempty(keyName) && keyName(1) == char(916);
    end

    function updateStatistics(rsrpVals, cutoff, isDiffMode)
        valR = rsrpVals(isfinite(rsrpVals));
        if isDiffMode
            lblMean.Text    = sprintf('Mean: %+.2f dB', mean(valR));
            lblStd.Text     = sprintf('Std: %.2f dB', std(valR));
            lblRange.Text   = sprintf('Range: [%+.1f, %+.1f] dB', min(valR), max(valR));
            lblCov70.Text   = sprintf('Gain > 0: %.1f%%', mean(valR > 0)*100);
            lblCov80.Text   = sprintf('Loss < 0: %.1f%%', mean(valR < 0)*100);
            lblWeakPct.Text = sprintf('|D| > 3 dB: %.1f%%', mean(abs(valR) > 3)*100);
            lblCov85.Text   = sprintf('|D| > 5 dB: %.1f%%', mean(abs(valR) > 5)*100);
            lblMedian.Text  = sprintf('Median: %+.2f', median(valR));
            lblIQR.Text     = sprintf('IQR: %.2f dB', iqr(valR));
        else
            lblMean.Text    = sprintf('Mean: %.1f dBm', mean(valR));
            lblStd.Text     = sprintf('Std: %.1f dB', std(valR));
            lblRange.Text   = sprintf('Range: [%.0f, %.0f] dBm', min(valR), max(valR));
            lblCov70.Text   = sprintf('>= -70 dBm: %.1f%%', mean(valR >= -70.0)*100);
            lblCov80.Text   = sprintf('>= -80 dBm: %.1f%%', mean(valR >= -80.0)*100);
            lblWeakPct.Text = sprintf('Weak (< cutoff): %.1f%%', mean(valR < cutoff)*100);
            lblCov85.Text   = sprintf('>= -85 dBm: %.1f%%', mean(valR >= -85.0)*100);
            lblMedian.Text  = sprintf('Median: %.1f dBm', median(valR));
            lblIQR.Text     = sprintf('IQR: %.1f dB', iqr(valR));
        end
    end

    function updateHistogram(rsrpVals, isDiffMode)
        cla(histAx);
        valR = rsrpVals(isfinite(rsrpVals));
        if isDiffMode
            histogram(histAx, valR, 40, 'FaceColor', [0.55 0.30 0.78], ...
                'EdgeColor', 'none', 'FaceAlpha', 0.85);
            xlabel(histAx, 'Difference (dB)', 'Color', grayColor, 'FontSize', 8);
            % Add zero reference line
            hold(histAx, 'on');
            yl = ylim(histAx);
            plot(histAx, [0 0], yl, '--', 'Color', [0.8 0.8 0.8], 'LineWidth', 1);
            hold(histAx, 'off');
        else
            histogram(histAx, valR, 40, 'FaceColor', accentBlue, ...
                'EdgeColor', 'none', 'FaceAlpha', 0.85);
            xlabel(histAx, 'RSRP (dBm)', 'Color', grayColor, 'FontSize', 8);
        end
        ylabel(histAx, '', 'Color', grayColor, 'FontSize', 8);
        histAx.Color = panelColor;
        histAx.XColor = grayColor;
        histAx.YColor = grayColor;
    end

    function highlightActiveCard(activeKey)
        for hi = 1:5
            cp = cardPanels{hi};
            if strcmp(activeKey, cardOrder{hi})
                cp.HighlightColor = [1 1 1];
                cp.BackgroundColor = [panelColor(1)+0.025, panelColor(2)+0.025, panelColor(3)+0.035];
            else
                cp.HighlightColor = cardAccent{hi};
                cp.BackgroundColor = panelColor;
            end
        end
    end

    function refreshMap()
        activeKey = modelDropDown.Value;
        rsrpActive = modelMap(activeKey);
        cutoff = thresholdSlider.Value;
        zoneChoice = zoneDropDown.Value;
        isDiffMode = isDifferenceMap(activeKey);

        % Apply zone filter
        if contains(zoneChoice, 'Weak')
            mask = (rsrpActive < cutoff);
        elseif contains(zoneChoice, 'Strong')
            mask = (rsrpActive >= -70.0);
        else
            mask = isfinite(rsrpActive);
        end

        curDispIdx = intersect(dispIdx, find(mask));
        if isempty(curDispIdx)
            set(scatterPlot, 'LatitudeData', NaN, 'LongitudeData', NaN, 'CData', []);
        else
            set(scatterPlot, 'LatitudeData', latFull(curDispIdx), ...
                             'LongitudeData', lonFull(curDispIdx), ...
                             'CData', rsrpActive(curDispIdx));
        end

        % Switch colormap and limits based on mode type
        if isDiffMode
            colormap(geoAx, cmap_diverging);
            try clim(geoAx, [-15 15]); catch; caxis(geoAx, [-15 15]); end
            cbar.Label.String = 'RSRP Difference (dB)';
        else
            colormap(geoAx, cmap_turbo);
            try clim(geoAx, [-110 -55]); catch; caxis(geoAx, [-110 -55]); end
            cbar.Label.String = 'Predicted RSRP (dBm)';
        end

        updateStatistics(rsrpActive, cutoff, isDiffMode);
        updateHistogram(rsrpActive, isDiffMode);
        highlightActiveCard(activeKey);

        activeModelLabel.Text = sprintf('Active: %s', activeKey);
        statusLabel.Text = sprintf('Grid: %d cells  |  Display: %d', numel(latFull), numel(curDispIdx));
    end

    % Attach primary callbacks
    modelDropDown.ValueChangedFcn = @(s, e) refreshMap();
    zoneDropDown.ValueChangedFcn  = @(s, e) refreshMap();
    thresholdSlider.ValueChangedFcn = @(s, e) handleThresholdChange(e.Value);

    function handleThresholdChange(val)
        thresholdLabel.Text = sprintf('WEAK SIGNAL CUTOFF: %.1f dBm', val);
        refreshMap();
    end

    basemapDropDown.ValueChangedFcn = @(s, e) set(geoAx, 'Basemap', e.Value);

    % Base station toggle callback
    if bsLoaded
        bsToggle.ValueChangedFcn = @(s, e) toggleBaseStations(e.Value);
    end

    function toggleBaseStations(showBS)
        if showBS
            vis = 'on';
        else
            vis = 'off';
        end
        if ~isempty(bsScatter) && isvalid(bsScatter)
            bsScatter.Visible = vis;
        end
        for ti = 1:numel(bsTextHandles)
            if isvalid(bsTextHandles{ti})
                bsTextHandles{ti}.Visible = vis;
            end
        end
    end

    % Export callback
    exportBtn.ButtonPushedFcn = @(s, e) exportCurrentView();

    function exportCurrentView()
        outDir = fullfile('figures', 'ml');
        if ~exist(outDir, 'dir'), mkdir(outDir); end
        fName = fullfile(outDir, sprintf('dashboard_view_%s.png', datestr(now, 'yyyymmdd_HHMMSS')));
        try
            exportapp(fig, fName);
        catch
            exportgraphics(fig, fName, 'Resolution', 150);
        end
        uialert(fig, sprintf('Exported to:\n%s', fName), 'Export Complete', 'Icon', 'success');
    end

    %% ========== 13. DYNAMIC MAP SIZING (Metric Aspect Ratio Preservation) ==========
    function fitMapToPanel()
        pPos = getpixelposition(mapPanel);
        W_panel = pPos(3);
        H_panel = pPos(4);
        if W_panel < 50 || H_panel < 50, return; end

        x_left   = 68;
        x_right  = 25;
        y_bottom = 38;
        y_top    = 25;
        w_cbar   = 75;
        w_bar    = 20;

        W_avail = max(10, W_panel - x_left - x_right - w_cbar);
        H_avail = max(10, H_panel - y_bottom - y_top);

        if (W_avail / H_avail) > geoAspect
            H_map = H_avail; W_map = H_map * geoAspect;
        else
            W_map = W_avail; H_map = W_map / geoAspect;
        end

        X_map = x_left + (W_avail - W_map) / 2;
        Y_map = y_bottom + (H_avail - H_map) / 2;

        set(geoAx, 'Units', 'pixels', 'Position', [X_map, Y_map, W_map, H_map]);
        try geolimits(geoAx, latLimits, lonLimits); catch; end

        if exist('cbar', 'var') && isvalid(cbar)
            set(cbar, 'Units', 'pixels', 'Position', [X_map + W_map + 15, Y_map, w_bar, H_map]);
        end
    end

    mapPanel.SizeChangedFcn = @(s, e) fitMapToPanel();

    %% ========== 14. MAP CLICK CALLBACK (Cell Inspector with Bar Chart) ==========
    set(geoAx, 'ButtonDownFcn', @(s, e) handleMapClick(geoAx.CurrentPoint));

    function handleMapClick(pt)
        clickLat = pt(1, 1);
        clickLon = pt(1, 2);

        % Nearest grid point lookup
        dists = (latFull - clickLat).^2 + (lonFull - clickLon).^2;
        [~, nearestIdx] = min(dists);

        % Update click marker
        set(clickMarker, 'LatitudeData', latFull(nearestIdx), ...
                         'LongitudeData', lonFull(nearestIdx));
        lblClickCoord.Text = sprintf('Cell %d  |  %.4f N, %.4f E', ...
            nearestIdx, latFull(nearestIdx), lonFull(nearestIdx));

        % Collect prediction values across all regular models
        barLabels = {};
        barVals = [];
        barClrs = [];
        allAccents = {mColors.P0, mColors.P1, mColors.P2, mColors.RF, mColors.P3};

        for mi = 1:numel(modelNames)
            mKey = modelNames{mi};
            if isKey(modelMap, mKey)
                v = modelMap(mKey);
                val = v(nearestIdx);
                if isfinite(val)
                    % Short label: first token before ':'
                    parts = strsplit(mKey, ':');
                    barLabels{end+1} = strtrim(parts{1});
                    barVals(end+1) = val;
                    if mi <= numel(allAccents)
                        barClrs(end+1, :) = allAccents{mi};
                    else
                        barClrs(end+1, :) = grayColor;
                    end
                end
            end
        end

        % Draw horizontal bar chart
        cla(barAx);
        if ~isempty(barVals)
            bh = barh(barAx, barVals, 0.6, 'FaceColor', 'flat', 'EdgeColor', 'none');
            bh.CData = barClrs;
            barAx.YTick = 1:numel(barLabels);
            barAx.YTickLabel = barLabels;
            barAx.YDir = 'reverse';
            barAx.Color = panelColor;
            barAx.XColor = grayColor;
            barAx.YColor = grayColor;
            barAx.FontSize = 8;
            xlabel(barAx, 'RSRP (dBm)', 'Color', grayColor, 'FontSize', 8);

            % Value labels on bars
            hold(barAx, 'on');
            for vi = 1:numel(barVals)
                text(barAx, barVals(vi) + 0.8, vi, sprintf('%.1f', barVals(vi)), ...
                    'Color', whiteColor, 'FontSize', 7, 'FontWeight', 'bold', ...
                    'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
            end
            hold(barAx, 'off');

            % Set axis limits with some padding
            xMin = min(barVals) - 5;
            xMax = max(barVals) + 8;
            xlim(barAx, [xMin xMax]);
        end
    end

    %% ========== 15. INITIAL RENDER ==========
    fitMapToPanel();
    refreshMap();
end
