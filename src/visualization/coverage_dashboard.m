function fig = coverage_dashboard(predictionInput)
% COVERAGE_DASHBOARD Refactored Interactive Geographic Coverage Map Dashboard
%
% Visualizes and compares 5 prediction modes over the 10,000-cell 30m x 30m grid:
%   - Mode A  : P0 (LDPL Physics Baseline)
%   - Mode B1 : P1 (LDPL + Isotropic Residual Reconstruction)
%   - Mode B2 : P2 (LDPL + Additive SASR Anisotropic Reconstruction)
%   - Mode C  : RF (Direct Random Forest ML-Only)
%   - Mode D  : P3 (Hybrid: P2 + RF Residual Correction)
%
% Architecture:
%   The dashboard is strictly decoupled from training. It consumes precomputed
%   prediction results and switches between models instantly without retraining.
%
% Syntax:
%   coverage_dashboard()
%   coverage_dashboard(predictionTable)
%   coverage_dashboard('path/to/predictions.csv')

    %% 1. Load Precomputed Predictions
    if nargin < 1 || isempty(predictionInput)
        defaultFile = fullfile('results', 'final', 'all_models_grid_predictions.csv');
        if ~isfile(defaultFile)
            error('coverage_dashboard: Prediction file not found: %s. Run experiments/06_interactive_coverage_map.m first.', defaultFile);
        end
        predictionInput = defaultFile;
    end

    if ischar(predictionInput) || isstring(predictionInput)
        fprintf('[Dashboard] Loading precomputed grid predictions from: %s\n', predictionInput);
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

    % Available Prediction Models
    modelMap = containers.Map();
    if ismember('P0_RSRP', T.Properties.VariableNames)
        modelMap('Mode A: LDPL (Physics Baseline)') = double(T.P0_RSRP);
    end
    if ismember('P1_RSRP', T.Properties.VariableNames)
        modelMap('Mode B1: LDPL + Isotropic Res (P1)') = double(T.P1_RSRP);
    end
    if ismember('P2_RSRP', T.Properties.VariableNames)
        modelMap('Mode B2: LDPL + Additive SASR (P2)') = double(T.P2_RSRP);
    end
    if ismember('RF_RSRP', T.Properties.VariableNames)
        modelMap('Mode C: Random Forest (ML-Only)') = double(T.RF_RSRP);
    elseif ismember('Predicted_RSRP', T.Properties.VariableNames)
        modelMap('Mode C: Random Forest (ML-Only)') = double(T.Predicted_RSRP);
    end
    if ismember('P3_RSRP', T.Properties.VariableNames)
        modelMap('Mode D: Physics + RF Res Hybrid (P3)') = double(T.P3_RSRP);
    end

    % Fallback if single prediction column exists
    if isempty(modelMap)
        if ismember('Predicted_RSRP', T.Properties.VariableNames)
            modelMap('Mode C: Random Forest (ML-Only)') = double(T.Predicted_RSRP);
        else
            error('coverage_dashboard: No valid prediction columns found in table.');
        end
    end

    modelKeys = keys(modelMap);
    currentModelKey = modelKeys{1};
    % Prefer P3 or P2 as initial view if available
    if ismember('Mode D: Physics + RF Res Hybrid (P3)', modelKeys)
        currentModelKey = 'Mode D: Physics + RF Res Hybrid (P3)';
    elseif ismember('Mode B2: LDPL + Additive SASR (P2)', modelKeys)
        currentModelKey = 'Mode B2: LDPL + Additive SASR (P2)';
    end

    rsrpCurrent = modelMap(currentModelKey);
    valid = isfinite(latFull) & isfinite(lonFull) & isfinite(rsrpCurrent);
    validIdx = find(valid);

    % Color Palette
    bgColor     = [0.035 0.055 0.085];
    panelColor  = [0.055 0.080 0.120];
    panelColor2 = [0.065 0.095 0.140];
    whiteColor  = [0.92 0.95 1.00];
    grayColor   = [0.65 0.70 0.78];
    blueColor   = [0.10 0.45 0.95];
    cyanColor   = [0.00 0.75 0.95];
    greenColor  = [0.10 0.80 0.35];
    orangeColor = [1.00 0.60 0.05];
    redColor    = [0.95 0.20 0.20];

    % Display Downsampling for smooth rendering
    maxDisplayPoints = 3000;
    nValid = numel(validIdx);
    if nValid > maxDisplayPoints
        stride = ceil(nValid / maxDisplayPoints);
        dispIdx = validIdx(1:stride:end);
    else
        dispIdx = validIdx;
    end

    %% 2. UI Layout Construction
    fig = uifigure( ...
        'Name', '5G SIGNAL COVERAGE PREDICTION SYSTEM - RESEARCH DASHBOARD', ...
        'Color', bgColor, ...
        'Position', [40 40 1560 900]);

    mainGrid = uigridlayout(fig, [3 3]);
    mainGrid.RowHeight = {75, '1x', 145};
    mainGrid.ColumnWidth = {310, '1x', 320};
    mainGrid.Padding = [10 10 10 10];

    % HEADER
    header = uipanel(mainGrid, 'BackgroundColor', bgColor, 'BorderType', 'none');
    header.Layout.Row = 1;
    header.Layout.Column = [1 3];
    headerGrid = uigridlayout(header, [2 2]);
    headerGrid.RowHeight = {36, 24};
    headerGrid.ColumnWidth = {'1x', 280};
    headerGrid.Padding = [0 0 0 0];

    titleLabel = uilabel(headerGrid, ...
        'Text', '5G RSRP SIGNAL COVERAGE RECONSTRUCTION DASHBOARD', ...
        'FontName', 'Segoe UI', 'FontSize', 19, 'FontWeight', 'bold', ...
        'FontColor', whiteColor);
    titleLabel.Layout.Row = 1; titleLabel.Layout.Column = 1;

    subLabel = uilabel(headerGrid, ...
        'Text', 'CIM-5G Mountainous Urban Terrain | Four-Mode Prediction & Physics-ML Residual Synthesis', ...
        'FontName', 'Segoe UI', 'FontSize', 12, 'FontColor', grayColor);
    subLabel.Layout.Row = 2; subLabel.Layout.Column = 1;

    statusLabel = uilabel(headerGrid, ...
        'Text', sprintf('Total Grid Points: %d | Active: %d', numel(latFull), nValid), ...
        'FontName', 'Segoe UI', 'FontSize', 12, 'FontColor', cyanColor, ...
        'HorizontalAlignment', 'right');
    statusLabel.Layout.Row = 1; statusLabel.Layout.Column = 2;

    %% 3. LEFT CONTROL PANEL
    leftPanel = uipanel(mainGrid, 'BackgroundColor', panelColor, 'BorderType', 'line', ...
        'HighlightColor', [0.15 0.22 0.32]);
    leftPanel.Layout.Row = 2; leftPanel.Layout.Column = 1;
    leftGrid = uigridlayout(leftPanel, [11 1]);
    leftGrid.RowHeight = {25, 32, 25, 32, 25, 35, 25, 25, 25, '1x', 36};

    % Model Selector (Requirement 12)
    uilabel(leftGrid, 'Text', 'PREDICTION MODEL ARCHITECTURE:', 'FontWeight', 'bold', ...
        'FontColor', cyanColor, 'FontSize', 11);
    modelDropDown = uidropdown(leftGrid, 'Items', modelKeys, 'Value', currentModelKey, ...
        'BackgroundColor', panelColor2, 'FontColor', whiteColor, 'FontSize', 11);

    % Basemap Selector
    uilabel(leftGrid, 'Text', 'BASEMAP LAYER:', 'FontWeight', 'bold', ...
        'FontColor', cyanColor, 'FontSize', 11);
    basemapDropDown = uidropdown(leftGrid, ...
        'Items', {'topographic', 'satellite', 'streets', 'darkwater'}, ...
        'Value', 'topographic', 'BackgroundColor', panelColor2, 'FontColor', whiteColor);

    % Weak Signal Threshold Slider
    thresholdLabel = uilabel(leftGrid, 'Text', 'WEAK SIGNAL CUTOFF: -85.0 dBm', ...
        'FontWeight', 'bold', 'FontColor', orangeColor, 'FontSize', 11);
    thresholdSlider = uislider(leftGrid, 'Limits', [-110 -65], 'Value', -85.0, ...
        'FontColor', whiteColor, 'MajorTicks', -110:10:-65);

    % Zone Display Filter
    uilabel(leftGrid, 'Text', 'DISPLAY REGION:', 'FontWeight', 'bold', ...
        'FontColor', cyanColor, 'FontSize', 11);
    zoneDropDown = uidropdown(leftGrid, ...
        'Items', {'All Prediction Points', 'Weak / Critical Zones Only', 'Strong Zones (>= -70 dBm) Only'}, ...
        'Value', 'All Prediction Points', 'BackgroundColor', panelColor2, 'FontColor', whiteColor);

    % Reset View Button
    exportBtn = uibutton(leftGrid, 'push', 'Text', 'Export Current Map (PNG)', ...
        'BackgroundColor', [0.12 0.35 0.65], 'FontColor', whiteColor, 'FontWeight', 'bold');

    %% 4. CENTER GEOGRAPHIC MAP
    mapPanel = uipanel(mainGrid, 'BackgroundColor', panelColor, 'BorderType', 'line', ...
        'HighlightColor', [0.15 0.22 0.32], 'AutoResizeChildren', 'off');
    mapPanel.Layout.Row = 2; mapPanel.Layout.Column = 2;

    % Precompute geographic bounding box and metric aspect ratio
    minLat = min(latFull(valid)); maxLat = max(latFull(valid));
    minLon = min(lonFull(valid)); maxLon = max(lonFull(valid));
    meanLat = (minLat + maxLat) / 2;
    dLat = max(1e-6, maxLat - minLat);
    dLon = max(1e-6, (maxLon - minLon) * cosd(meanLat));
    geoAspect = dLon / dLat; % Local metric aspect-ratio preservation: longitude span adjusted by cos(meanLat)

    latPad = dLat * 0.02;
    lonPad = (maxLon - minLon) * 0.02;
    latLimits = [minLat - latPad, maxLat + latPad];
    lonLimits = [minLon - lonPad, maxLon + lonPad];

    try
        geoAx = geoaxes(mapPanel, 'Basemap', 'topographic');
    catch
        % Fallback to standard axes if mapping toolbox geoaxes is unsupported
        geoAx = axes(mapPanel);
        geoAx.Color = [0.04 0.06 0.09];
    end

    % Plot scatter layer
    hold(geoAx, 'on');
    scatterPlot = geoscatter(geoAx, latFull(dispIdx), lonFull(dispIdx), 16, rsrpCurrent(dispIdx), 'filled');
    colormap(geoAx, turbo(256));
    cbar = colorbar(geoAx);
    cbar.Color = whiteColor;
    cbar.Label.String = 'Predicted RSRP (dBm)';
    cbar.Label.Color = whiteColor;
    try
        clim(geoAx, [-110 -55]);
    catch
        caxis(geoAx, [-110 -55]);
    end

    % Click selection marker
    clickMarker = geoscatter(geoAx, NaN, NaN, 120, 'r', 'p', 'LineWidth', 2);

    %% 5. RIGHT INSPECTION & STATISTICS PANEL
    rightPanel = uipanel(mainGrid, 'BackgroundColor', panelColor, 'BorderType', 'line', ...
        'HighlightColor', [0.15 0.22 0.32]);
    rightPanel.Layout.Row = 2; rightPanel.Layout.Column = 3;
    rightGrid = uigridlayout(rightPanel, [10 1]);
    rightGrid.RowHeight = {25, 22, 22, 22, 22, 25, 22, 22, 22, '1x'};

    uilabel(rightGrid, 'Text', 'COVERAGE STATISTICS (WHOLE DOMAIN):', 'FontWeight', 'bold', ...
        'FontColor', cyanColor, 'FontSize', 11);
    lblMean = uilabel(rightGrid, 'Text', 'Mean RSRP : -- dBm', 'FontColor', whiteColor);
    lblRange = uilabel(rightGrid, 'Text', 'Range     : [-- , --] dBm', 'FontColor', whiteColor);
    lblStd = uilabel(rightGrid, 'Text', 'Std Dev   : -- dB', 'FontColor', whiteColor);
    lblCov70 = uilabel(rightGrid, 'Text', 'Coverage >= -70 dBm : -- %', 'FontColor', greenColor);

    uilabel(rightGrid, 'Text', 'CRITICAL ZONE METRICS:', 'FontWeight', 'bold', ...
        'FontColor', orangeColor, 'FontSize', 11);
    lblWeakPct = uilabel(rightGrid, 'Text', 'Weak Signal (< Cutoff) : -- %', 'FontColor', orangeColor);
    lblCov80 = uilabel(rightGrid, 'Text', 'Coverage >= -80 dBm   : -- %', 'FontColor', whiteColor);
    lblCov85 = uilabel(rightGrid, 'Text', 'Coverage >= -85 dBm   : -- %', 'FontColor', whiteColor);

    % Click inspector panel
    clickPanel = uipanel(rightGrid, 'BackgroundColor', panelColor2, 'Title', 'CLICKED GRID CELL COMPARISON', ...
        'ForegroundColor', cyanColor, 'FontWeight', 'bold');
    clickPanelGrid = uigridlayout(clickPanel, [7 1]);
    clickPanelGrid.RowHeight = {20, 18, 18, 18, 18, 18, 18};

    lblClickCoord = uilabel(clickPanelGrid, 'Text', 'Click map to inspect any grid location.', 'FontColor', grayColor, 'FontSize', 10);
    lblP0 = uilabel(clickPanelGrid, 'Text', 'P0 (LDPL)       : --', 'FontColor', whiteColor, 'FontSize', 10);
    lblP1 = uilabel(clickPanelGrid, 'Text', 'P1 (Isotropic)  : --', 'FontColor', whiteColor, 'FontSize', 10);
    lblP2 = uilabel(clickPanelGrid, 'Text', 'P2 (SASR)       : --', 'FontColor', whiteColor, 'FontSize', 10);
    lblRF = uilabel(clickPanelGrid, 'Text', 'RF (ML-Only)    : --', 'FontColor', whiteColor, 'FontSize', 10);
    lblP3 = uilabel(clickPanelGrid, 'Text', 'P3 (Hybrid)     : --', 'FontColor', cyanColor, 'FontWeight', 'bold', 'FontSize', 10);
    lblDelta = uilabel(clickPanelGrid, 'Text', 'ML Correction   : --', 'FontColor', orangeColor, 'FontSize', 10);

    %% 6. BOTTOM METRICS BAR
    bottomPanel = uipanel(mainGrid, 'BackgroundColor', panelColor, 'BorderType', 'line', ...
        'HighlightColor', [0.15 0.22 0.32]);
    bottomPanel.Layout.Row = 3; bottomPanel.Layout.Column = [1 3];
    bottomGrid = uigridlayout(bottomPanel, [1 5]);
    bottomGrid.ColumnWidth = {'1x', '1x', '1x', '1x', '1x'};

    cardP0 = createMetricCard(bottomGrid, 'MODE A (P0: LDPL)', 'Macro-scale path loss', [0.5 0.5 0.5]);
    cardP1 = createMetricCard(bottomGrid, 'MODE B1 (P1: ISO)', 'Isotropic spatial res', [0.2 0.5 0.8]);
    cardP2 = createMetricCard(bottomGrid, 'MODE B2 (P2: SASR)', 'Sector-aligned aniso', [0.1 0.7 0.3]);
    cardRF = createMetricCard(bottomGrid, 'MODE C (RF-ONLY)', 'Direct ML prediction', [0.8 0.5 0.1]);
    cardP3 = createMetricCard(bottomGrid, 'MODE D (P3: HYBRID)', 'P2 + RF residual', [0.1 0.5 0.95]);

    %% 7. Callbacks and Interactivity
    function updateStatistics(rsrpVals, cutoff)
        valR = rsrpVals(isfinite(rsrpVals));
        lblMean.Text  = sprintf('Mean RSRP : %.2f dBm', mean(valR));
        lblRange.Text = sprintf('Range     : [%.1f, %.1f] dBm', min(valR), max(valR));
        lblStd.Text   = sprintf('Std Dev   : %.2f dB', std(valR));
        lblCov70.Text = sprintf('Coverage >= -70 dBm : %.1f%%', mean(valR >= -70.0) * 100);
        lblCov80.Text = sprintf('Coverage >= -80 dBm : %.1f%%', mean(valR >= -80.0) * 100);
        lblCov85.Text = sprintf('Coverage >= -85 dBm : %.1f%%', mean(valR >= -85.0) * 100);
        lblWeakPct.Text = sprintf('Weak Signal (< Cutoff) : %.1f%%', mean(valR < cutoff) * 100);
    end

    function refreshMap()
        activeKey = modelDropDown.Value;
        rsrpActive = modelMap(activeKey);
        cutoff = thresholdSlider.Value;
        zoneChoice = zoneDropDown.Value;

        % Filter indices
        if strcmp(zoneChoice, 'Weak / Critical Zones Only')
            mask = (rsrpActive < cutoff);
        elseif strcmp(zoneChoice, 'Strong Zones (>= -70 dBm) Only')
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

        updateStatistics(rsrpActive, cutoff);
        statusLabel.Text = sprintf('Active Model: %s | Display Points: %d', activeKey, numel(curDispIdx));
    end

    % Attach Callbacks
    modelDropDown.ValueChangedFcn = @(s, e) refreshMap();
    zoneDropDown.ValueChangedFcn  = @(s, e) refreshMap();
    thresholdSlider.ValueChangedFcn = @(s, e) handleThresholdChange(e.Value);

    function handleThresholdChange(val)
        thresholdLabel.Text = sprintf('WEAK SIGNAL CUTOFF: %.1f dBm', val);
        refreshMap();
    end

    basemapDropDown.ValueChangedFcn = @(s, e) set(geoAx, 'Basemap', e.Value);

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
        uialert(fig, sprintf('Map view successfully exported to:\n%s', fName), 'Export Complete', 'Icon', 'success');
    end

    % Dynamic Map Sizing preserving Local Metric Aspect Ratio
    function fitMapToPanel()
        pPos = getpixelposition(mapPanel);
        W_panel = pPos(3);
        H_panel = pPos(4);
        if W_panel < 50 || H_panel < 50
            return;
        end

        x_left_margin   = 68; % Space for latitude ticks and axis label
        x_right_margin  = 25; % Clearance to right edge of panel
        y_bottom_margin = 38; % Space for longitude ticks and axis label
        y_top_margin    = 25; % Clearance to top edge of panel
        w_cbar_slot     = 75; % Space allocated for colorbar, ticks, and label
        w_cbar_bar      = 20; % Width of colorbar bar itself

        W_avail = max(10, W_panel - x_left_margin - x_right_margin - w_cbar_slot);
        H_avail = max(10, H_panel - y_bottom_margin - y_top_margin);

        if (W_avail / H_avail) > geoAspect
            % Height is constraining dimension
            H_map = H_avail;
            W_map = H_map * geoAspect;
        else
            % Width is constraining dimension
            W_map = W_avail;
            H_map = W_map / geoAspect;
        end

        X_map = x_left_margin + (W_avail - W_map) / 2;
        Y_map = y_bottom_margin + (H_avail - H_map) / 2;

        set(geoAx, 'Units', 'pixels', 'Position', [X_map, Y_map, W_map, H_map]);
        try
            geolimits(geoAx, latLimits, lonLimits);
        catch
        end

        if exist('cbar', 'var') && isvalid(cbar)
            set(cbar, 'Units', 'pixels', 'Position', [X_map + W_map + 15, Y_map, w_cbar_bar, H_map]);
        end
    end

    mapPanel.SizeChangedFcn = @(s, e) fitMapToPanel();

    % Map Click Callback for Traceable Grid Inspection
    set(geoAx, 'ButtonDownFcn', @(s, e) handleMapClick(geoAx.CurrentPoint));

    function handleMapClick(pt)
        clickLat = pt(1, 1);
        clickLon = pt(1, 2);

        % Nearest grid point lookup
        dists = (latFull - clickLat).^2 + (lonFull - clickLon).^2;
        [minDist, nearestIdx] = min(dists);

        % Update click marker
        set(clickMarker, 'LatitudeData', latFull(nearestIdx), 'LongitudeData', lonFull(nearestIdx));

        lblClickCoord.Text = sprintf('Cell [%d]: %.4f N, %.4f E', nearestIdx, latFull(nearestIdx), lonFull(nearestIdx));

        if isKey(modelMap, 'Mode A: LDPL (Physics Baseline)')
            v0 = modelMap('Mode A: LDPL (Physics Baseline)'); lblP0.Text = sprintf('P0 (LDPL)       : %.2f dBm', v0(nearestIdx));
        end
        if isKey(modelMap, 'Mode B1: LDPL + Isotropic Res (P1)')
            v1 = modelMap('Mode B1: LDPL + Isotropic Res (P1)'); lblP1.Text = sprintf('P1 (Isotropic)  : %.2f dBm', v1(nearestIdx));
        end
        if isKey(modelMap, 'Mode B2: LDPL + Additive SASR (P2)')
            v2 = modelMap('Mode B2: LDPL + Additive SASR (P2)'); lblP2.Text = sprintf('P2 (SASR)       : %.2f dBm', v2(nearestIdx));
        end
        if isKey(modelMap, 'Mode C: Random Forest (ML-Only)')
            vrf = modelMap('Mode C: Random Forest (ML-Only)'); lblRF.Text = sprintf('RF (ML-Only)    : %.2f dBm', vrf(nearestIdx));
        end
        if isKey(modelMap, 'Mode D: Physics + RF Res Hybrid (P3)')
            v3 = modelMap('Mode D: Physics + RF Res Hybrid (P3)'); lblP3.Text = sprintf('P3 (Hybrid)     : %.2f dBm', v3(nearestIdx));
            if exist('v2', 'var')
                lblDelta.Text = sprintf('ML Correction   : %+.2f dB', v3(nearestIdx) - v2(nearestIdx));
            end
        end
    end

    % Initial Layout Fit and Refresh
    fitMapToPanel();
    refreshMap();
end

function p = createMetricCard(parent, titleText, descText, accentColor)
    p = uipanel(parent, 'BackgroundColor', [0.065 0.095 0.140], 'BorderType', 'line', ...
        'HighlightColor', accentColor);
    g = uigridlayout(p, [2 1]);
    g.RowHeight = {22, 18};
    uilabel(g, 'Text', titleText, 'FontWeight', 'bold', 'FontColor', accentColor, 'FontSize', 11);
    uilabel(g, 'Text', descText, 'FontColor', [0.7 0.75 0.85], 'FontSize', 9);
end
