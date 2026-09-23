% run_all.m (Master Root Entry Point)
% Executes experiments/run_all.m
evalin('caller', fileread(fullfile('experiments', 'run_all.m')));
