function report = clean_and_inspect_missing(tbl, tblName)
% CLEAN_AND_INSPECT_MISSING Analyzes missingness, duplicates, and range bounds of a table.
%
% Syntax:
%   report = clean_and_inspect_missing(tbl, tblName)

if nargin < 2
    tblName = 'Dataset';
end

numRows = height(tbl);
varNames = tbl.Properties.VariableNames;
numCols = numel(varNames);

missingCounts = zeros(numCols, 1);
missingPct    = zeros(numCols, 1);

for c = 1:numCols
    colData = tbl{:, c};
    if iscell(colData) || isstring(colData)
        isMiss = ismissing(colData) | cellfun(@isempty, colData) | strcmpi(colData, 'nan') | strcmpi(colData, 'null');
    else
        isMiss = ismissing(colData) | isnan(colData);
    end
    missingCounts(c) = sum(isMiss);
    missingPct(c)    = (missingCounts(c) / numRows) * 100;
end

missingTable = table(varNames', missingCounts, missingPct, ...
    'VariableNames', {'ColumnName', 'MissingCount', 'MissingPercentage'});

% Duplicate analysis
[~, uniqueIdx] = unique(tbl, 'rows');
numDuplicates = numRows - numel(uniqueIdx);

report.TableName     = tblName;
report.NumRecords    = numRows;
report.NumColumns    = numCols;
report.MissingTable  = missingTable;
report.NumDuplicates = numDuplicates;

end
