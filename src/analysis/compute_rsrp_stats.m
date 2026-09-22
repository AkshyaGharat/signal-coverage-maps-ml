function stats = compute_rsrp_stats(rsrpValues)
% COMPUTE_RSRP_STATS Computes comprehensive RSRP summary statistics and percentiles.
%
% Syntax:
%   stats = compute_rsrp_stats(rsrpValues)

rsrpClean = rsrpValues(~isnan(rsrpValues) & ~ismissing(rsrpValues));

stats.Count   = numel(rsrpClean);
stats.Min     = min(rsrpClean);
stats.Max     = max(rsrpClean);
stats.Mean    = mean(rsrpClean);
stats.Median  = median(rsrpClean);
stats.Std     = std(rsrpClean);
stats.P5      = prctile(rsrpClean, 5);
stats.P25     = prctile(rsrpClean, 25);
stats.P50     = prctile(rsrpClean, 50);
stats.P75     = prctile(rsrpClean, 75);
stats.P95     = prctile(rsrpClean, 95);
stats.IQR     = stats.P75 - stats.P25;

end
