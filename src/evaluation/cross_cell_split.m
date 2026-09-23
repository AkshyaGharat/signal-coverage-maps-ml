function [trainIdx, testIdx] = cross_cell_split(ueNCI, testCellNCIs)
% CROSS_CELL_SPLIT Partitions dataset into Train (Cells 1-8) and Test (Cells 9-10).
%
% Syntax:
%   [trainIdx, testIdx] = cross_cell_split(ueNCI, testCellNCIs)

if nargin < 2 || isempty(testCellNCIs)
    uniqueNCIs = unique(ueNCI(~isnan(ueNCI)));
    if numel(uniqueNCIs) >= 2
        testCellNCIs = uniqueNCIs(end-1:end);
    else
        testCellNCIs = uniqueNCIs;
    end
end

testMask = ismember(ueNCI, testCellNCIs);
trainIdx = find(~testMask);
testIdx  = find(testMask);

end
