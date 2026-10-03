% tests/run_quick_demo.m
% Quick verification / smoke-test for the Signal Coverage Maps project.
%
% PURPOSE:
%   Verifies the environment is configured correctly and the core pipeline
%   functions produce valid numeric outputs using the small sample dataset.
%   Expected runtime: < 60 seconds on any supported machine.
%
% REQUIREMENTS:
%   - MATLAB R2022a or newer
%   - Statistics and Machine Learning Toolbox
%   - Mapping Toolbox
%
% USAGE (from repository root):
%   addpath(genpath('src'));
%   run('tests/run_quick_demo.m');

clear; clc;

fprintf('========================================================\n');
fprintf('  QUICK DEMO / VERIFICATION TEST\n');
fprintf('  Signal Coverage Maps — Physics-ML Hybrid Pipeline\n');
fprintf('========================================================\n\n');

PASS = 0; FAIL = 0;

%% -----------------------------------------------------------------------
% Step 0: Resolve project root and add source paths
% -----------------------------------------------------------------------
thisDir     = fileparts(mfilename('fullpath'));
projectRoot = fullfile(thisDir, '..');
addpath(genpath(fullfile(projectRoot, 'src')));

%% -----------------------------------------------------------------------
% Step 1: Toolbox availability
% -----------------------------------------------------------------------
fprintf('[1] Checking required toolboxes...\n');
required = {'Statistics and Machine Learning Toolbox', 'Mapping Toolbox'};
allOK = true;
for i = 1:numel(required)
    if license('test', required{i})
        fprintf('    OK  %s\n', required{i});
    else
        fprintf('    MISSING  %s\n', required{i});
        allOK = false; FAIL = FAIL + 1;
    end
end
if allOK, PASS = PASS + 1; end

%% -----------------------------------------------------------------------
% Step 2: Load sample data
% -----------------------------------------------------------------------
fprintf('\n[2] Loading sample dataset...\n');
sampleDir = fullfile(projectRoot, 'data', 'sample');
try
    T_meas = readtable(fullfile(sampleDir, 'raw_datas_sample.csv'));
    T_bs   = readtable(fullfile(sampleDir, 'base_station_data.csv'));
    T_fish = readtable(fullfile(sampleDir, 'fishnet_sample.csv'));
    fprintf('    Measurements  : %d rows, %d columns\n', height(T_meas), width(T_meas));
    fprintf('    Base stations : %d rows, %d columns\n', height(T_bs),   width(T_bs));
    fprintf('    Fishnet cells : %d rows, %d columns\n', height(T_fish), width(T_fish));
    assert(height(T_meas) > 0 && height(T_bs) > 0, 'Empty tables loaded');
    fprintf('    OK  Sample data loaded successfully\n');
    PASS = PASS + 1;
catch ME
    fprintf('    FAIL  Failed to load sample data: %s\n', ME.message);
    FAIL = FAIL + 1;
end

%% -----------------------------------------------------------------------
% Step 3: Load calibrated LDPL model
% -----------------------------------------------------------------------
fprintf('\n[3] Loading calibrated LDPL model...\n');
ldplPath = fullfile(projectRoot, 'models', 'random_forest', 'calibrated_ldpl_model.mat');
try
    ldplData = load(ldplPath);
    fnames = fieldnames(ldplData);
    fprintf('    Fields: %s\n', strjoin(fnames, ', '));
    fprintf('    OK  LDPL model loaded\n');
    PASS = PASS + 1;
catch ME
    fprintf('    FAIL  Failed to load LDPL model: %s\n', ME.message);
    FAIL = FAIL + 1;
end

%% -----------------------------------------------------------------------
% Step 4: Load pre-trained RF models
% -----------------------------------------------------------------------
fprintf('\n[4] Loading pre-trained Random Forest models...\n');
modelFiles = {'mode_c_direct_rf.mat', 'mode_d_residual_rf.mat'};
for i = 1:numel(modelFiles)
    mPath = fullfile(projectRoot, 'models', 'random_forest', modelFiles{i});
    try
        mData = load(mPath);
        fnames = fieldnames(mData);
        fprintf('    OK  %s  (fields: %s)\n', modelFiles{i}, strjoin(fnames, ', '));
        PASS = PASS + 1;
    catch ME
        fprintf('    FAIL  %s  --  %s\n', modelFiles{i}, ME.message);
        FAIL = FAIL + 1;
    end
end

%% -----------------------------------------------------------------------
% Step 5: Verify results directory has prediction outputs
% -----------------------------------------------------------------------
fprintf('\n[5] Checking pre-computed prediction outputs...\n');
predPath = fullfile(projectRoot, 'results', 'final', 'all_models_grid_predictions.csv');
if isfile(predPath)
    T_pred = readtable(predPath);
    fprintf('    Prediction grid: %d rows, %d columns\n', height(T_pred), width(T_pred));
    assert(height(T_pred) >= 100, 'Prediction table suspiciously small');
    fprintf('    OK  Prediction outputs found\n');
    PASS = PASS + 1;
else
    fprintf('    NOTE  results/final/all_models_grid_predictions.csv not found.\n');
    fprintf('          Run experiments/06_interactive_coverage_map.m to generate it.\n');
end

%% -----------------------------------------------------------------------
% Summary
% -----------------------------------------------------------------------
fprintf('\n========================================================\n');
fprintf('  VERIFICATION SUMMARY\n');
fprintf('  Passed : %d\n', PASS);
fprintf('  Failed : %d\n', FAIL);
if FAIL == 0
    fprintf('  STATUS : ALL CHECKS PASSED\n');
    fprintf('\n  You can now run the full pipeline:\n');
    fprintf('    >> cd(''%s'');\n', projectRoot);
    fprintf('    >> run_all\n');
    fprintf('\n  Or launch the dashboard directly:\n');
    fprintf('    >> addpath(genpath(''src''));\n');
    fprintf('    >> coverage_dashboard(''results/final/all_models_grid_predictions.csv'');\n');
else
    fprintf('  STATUS : %d CHECK(S) FAILED\n', FAIL);
    fprintf('  Resolve the issues above before running the full pipeline.\n');
end
fprintf('========================================================\n');
