function [X, y, featureNames, validMask] = extract_ml_features(dataTable, targetCol)
% EXTRACT_ML_FEATURES Extracts standardized ML features from CIM-5G data table.
%
% Syntax:
%   [X, y, featureNames, validMask] = extract_ml_features(dataTable)
%   [X, y, featureNames, validMask] = extract_ml_features(dataTable, targetCol)
%
% Inputs:
%   dataTable  - Table containing measurements or grid records.
%   targetCol  - (Optional) Name of target variable (e.g. 'SS_RSRP').
%                Default: 'SS_RSRP'. If empty, y is returned empty.
%
% Outputs:
%   X            - N x 16 numeric matrix of predictor features.
%   y            - N x 1 numeric vector of target values (or [] if no target).
%   featureNames - 16 x 1 cell array of feature names.
%   validMask    - N x 1 logical mask indicating rows with complete finite values.

    if nargin < 2
        targetCol = 'SS_RSRP';
    end

    % Standard 16 features from the feature redundancy audit
    featureNames = { ...
        'Center_X', ...
        'Center_Y', ...
        'NDVI_center', ...
        'Building_Coverage', ...
        'Weighted_Height', ...
        'DEM_center', ...
        'Base_Central_frequency_point', ...
        'Base_Electronic_downtilt', ...
        'Base_Mechanical_downtilt', ...
        'Base_Power', ...
        'True_3D_Dist', ...
        'Match_Angle_sin', ...
        'Match_Angle_cos', ...
        'Base_Direction_angle_sin', ...
        'Base_Direction_angle_cos', ...
        'Power_to_Dist_ratio' ...
    };

    varNames = dataTable.Properties.VariableNames;
    N = height(dataTable);

    % Synthesize Power_to_Dist_ratio if missing but Base_Power and True_3D_Dist exist
    if ~ismember('Power_to_Dist_ratio', varNames)
        if ismember('Base_Power', varNames) && ismember('True_3D_Dist', varNames)
            dataTable.Power_to_Dist_ratio = dataTable.Base_Power ./ max(1.0, dataTable.True_3D_Dist);
            varNames{end+1} = 'Power_to_Dist_ratio';
        end
    end

    % Synthesize Match angles if missing
    if ~ismember('Match_Angle_sin', varNames) && ismember('Match_Dist', varNames) && ismember('True_3D_Dist', varNames)
        dataTable.Match_Angle_sin = zeros(N, 1);
        dataTable.Match_Angle_cos = ones(N, 1);
    end

    % Synthesize Direction angles if missing but ServingAzimuth or angle exists
    if ~ismember('Base_Direction_angle_sin', varNames)
        if ismember('ServingAzimuth', varNames)
            az = dataTable.ServingAzimuth;
            dataTable.Base_Direction_angle_sin = sind(az);
            dataTable.Base_Direction_angle_cos = cosd(az);
        elseif ismember('angle', varNames)
            az = dataTable.angle;
            dataTable.Base_Direction_angle_sin = sind(az);
            dataTable.Base_Direction_angle_cos = cosd(az);
        end
    end

    % Coordinate column aliases
    if ~ismember('Center_X', varNames) && ismember('LONGITUDE', varNames)
        dataTable.Center_X = dataTable.LONGITUDE;
    end
    if ~ismember('Center_Y', varNames) && ismember('LATITUDE', varNames)
        dataTable.Center_Y = dataTable.LATITUDE;
    end

    % Build numeric feature matrix
    numFeatures = numel(featureNames);
    X = nan(N, numFeatures);

    for j = 1:numFeatures
        fName = featureNames{j};
        if ismember(fName, dataTable.Properties.VariableNames)
            colVal = dataTable.(fName);
            if isnumeric(colVal)
                X(:, j) = double(colVal);
            elseif iscell(colVal) || isstring(colVal)
                X(:, j) = str2double(colVal);
            end
        else
            warning('Feature "%s" not found in input table; filling with 0.', fName);
            X(:, j) = 0.0;
        end
    end

    % Extract target if specified and present
    y = [];
    if ~isempty(targetCol) && ismember(targetCol, dataTable.Properties.VariableNames)
        targetVal = dataTable.(targetCol);
        if isnumeric(targetVal)
            y = double(targetVal);
        else
            y = str2double(targetVal);
        end
        validMask = all(isfinite(X), 2) & isfinite(y);
    else
        validMask = all(isfinite(X), 2);
    end
end
