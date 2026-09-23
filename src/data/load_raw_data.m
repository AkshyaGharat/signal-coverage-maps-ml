function [rawData, bsData, fishnetData] = load_raw_data(dataDir)
% LOAD_RAW_DATA Loads raw CSV files from CIM-5G dataset directory.
%
% Syntax:
%   [rawData, bsData, fishnetData] = load_raw_data(dataDir)
%
% Inputs:
%   dataDir - Optional path to CIM-5G directory. Default: 'data/raw/CIM-5G'
%
% Outputs:
%   rawData     - Table containing records from raw_datas.csv
%   bsData      - Table containing records from base_station_data.csv
%   fishnetData - Table containing records from fishnet_30x30_processed_feature_engineered.csv

if nargin < 1 || isempty(dataDir)
    dataDir = fullfile('data', 'raw', 'CIM-5G');
end

rawPath     = fullfile(dataDir, 'raw_datas.csv');
bsPath      = fullfile(dataDir, 'base_station_data.csv');
fishnetPath = fullfile(dataDir, 'fishnet_30x30_processed_feature_engineered.csv');

assert(exist(rawPath, 'file') == 2, 'File not found: %s', rawPath);
assert(exist(bsPath, 'file') == 2, 'File not found: %s', bsPath);
assert(exist(fishnetPath, 'file') == 2, 'File not found: %s', fishnetPath);

optsRaw = detectImportOptions(rawPath, 'VariableNamingRule', 'preserve');
rawData = readtable(rawPath, optsRaw);

% Convert TIME string to MATLAB datetime if present
timeCol = 'TIME(BeiJing)';
if ismember(timeCol, rawData.Properties.VariableNames)
    try
        rawData.TIME_dt = datetime(rawData.(timeCol), 'InputFormat', 'yyyyMMdd HH:mm:ss.SSS');
    catch
        try
            rawData.TIME_dt = datetime(rawData.(timeCol));
        catch
            rawData.TIME_dt = NaT(height(rawData), 1);
        end
    end
end

optsBs = detectImportOptions(bsPath, 'VariableNamingRule', 'preserve');
bsData = readtable(bsPath, optsBs);

optsFish = detectImportOptions(fishnetPath, 'VariableNamingRule', 'preserve');
fishnetData = readtable(fishnetPath, optsFish);

end
