% run_all.m
% Master Entry Point for the 5G Signal Coverage Reconstruction & ML Hybrid Project
% Project: Signal Coverage Maps Using Measurements and Machine Learning
%
% Pipeline Execution Stages:
%   Stage 1: Dataset Exploration & Spatial Characterization (01_dataset_exploration.m)
%   Stage 2: Spatial & Anisotropic Structure Analysis (02_structure_analysis.m)
%   Stage 3: Spatial Reconstruction & Physics Residual Baseline (03_anisotropic_reconstruction.m)
%   Stage 4: Direct P1 vs P2 Paired Statistical Validation (validate_p1_vs_p2.m)
%   Stage 5: ML Feature Prep & Residual RF Training (04_ml_residual.m)
%   Stage 6: Multi-Regime 5-Mode Comparison & Ablation (05_model_comparison.m)
%   Stage 7: Full 10,000-Cell Coverage Map & Interactive Dashboard (06_interactive_coverage_map.m)

clear; clc; close all;

fprintf('=========================================================================\n');
fprintf('  SIGNAL-COVERAGE-MAPS: MASTER REPRODUCIBLE RESEARCH PIPELINE\n');
fprintf('=========================================================================\n\n');

% Add repository source paths
if exist(fullfile(pwd, 'experiments'), 'dir')
    projectRoot = pwd;
else
    thisDir = fileparts(mfilename('fullpath'));
    if exist(fullfile(thisDir, '..', 'experiments'), 'dir')
        projectRoot = fullfile(thisDir, '..');
    else
        projectRoot = thisDir;
    end
end
addpath(genpath(fullfile(projectRoot, 'src')));

%% ========================================================================
% CONFIGURATION FLAGS (Control Execution of Expensive Stages)
% ========================================================================
RUN_DATA_AUDIT          = false;  % Stage 1: Dataset exploration & audit
RUN_STRUCTURE_ANALYSIS  = false;  % Stage 2: Variograms, low-rank, nonstationarity
RUN_RECONSTRUCTION      = false;  % Stage 3: Phase 03 SASR spatial reconstruction
RUN_VALIDATION_P1_VS_P2 = false;  % Stage 4: 30-run paired Monte Carlo P1 vs P2
RUN_ML                  = true;   % Stage 5: Mode C direct RF & Mode D residual RF
RUN_MODEL_COMPARISON    = false;  % Stage 6: Multi-regime 5-mode benchmark (set true for full 12 regimes)
RUN_COVERAGE_GRID       = true;   % Stage 7: 10k grid prediction & dashboard launch

fprintf('Active Pipeline Execution Configuration:\n');
fprintf('  [1] RUN_DATA_AUDIT          : %s\n', mat2str(RUN_DATA_AUDIT));
fprintf('  [2] RUN_STRUCTURE_ANALYSIS  : %s\n', mat2str(RUN_STRUCTURE_ANALYSIS));
fprintf('  [3] RUN_RECONSTRUCTION      : %s\n', mat2str(RUN_RECONSTRUCTION));
fprintf('  [4] RUN_VALIDATION_P1_VS_P2 : %s\n', mat2str(RUN_VALIDATION_P1_VS_P2));
fprintf('  [5] RUN_ML                  : %s\n', mat2str(RUN_ML));
fprintf('  [6] RUN_MODEL_COMPARISON    : %s\n', mat2str(RUN_MODEL_COMPARISON));
fprintf('  [7] RUN_COVERAGE_GRID       : %s\n\n', mat2str(RUN_COVERAGE_GRID));

% Runner helper to support script names starting with digits
runScript = @(scriptPath) evalin('caller', fileread(scriptPath));

totalTimer = tic;

%% STAGE 1: Dataset Exploration
if RUN_DATA_AUDIT
    fprintf('\n>>> Executing Stage 1: Dataset Exploration & Audit (01_dataset_exploration.m)...\n');
    tStage = tic;
    runScript(fullfile(projectRoot, 'experiments', '01_dataset_exploration.m'));
    fprintf('>>> Stage 1 completed in %.2f s.\n', toc(tStage));
end

%% STAGE 2: Spatial Structure Analysis
if RUN_STRUCTURE_ANALYSIS
    fprintf('\n>>> Executing Stage 2: Spatial Structure Analysis (02_structure_analysis.m)...\n');
    tStage = tic;
    runScript(fullfile(projectRoot, 'experiments', '02_structure_analysis.m'));
    fprintf('>>> Stage 2 completed in %.2f s.\n', toc(tStage));
end

%% STAGE 3: Reconstruction & Physics Residual Baseline
if RUN_RECONSTRUCTION
    fprintf('\n>>> Executing Stage 3: SASR Reconstruction (03_anisotropic_reconstruction.m)...\n');
    tStage = tic;
    runScript(fullfile(projectRoot, 'experiments', '03_anisotropic_reconstruction.m'));
    fprintf('>>> Stage 3 completed in %.2f s.\n', toc(tStage));
end

%% STAGE 4: P1 vs P2 Paired Statistical Validation
if RUN_VALIDATION_P1_VS_P2
    fprintf('\n>>> Executing Stage 4: Paired P1 vs P2 Statistical Validation (validate_p1_vs_p2.m)...\n');
    tStage = tic;
    runScript(fullfile(projectRoot, 'experiments', 'validate_p1_vs_p2.m'));
    fprintf('>>> Stage 4 completed in %.2f s.\n', toc(tStage));
end

%% STAGE 5: Machine Learning Residual Learning (Mode C & Mode D)
if RUN_ML
    fprintf('\n>>> Executing Stage 5: ML Residual Learning (04_ml_residual.m)...\n');
    tStage = tic;
    runScript(fullfile(projectRoot, 'experiments', '04_ml_residual.m'));
    fprintf('>>> Stage 5 completed in %.2f s.\n', toc(tStage));
end

%% STAGE 6: Multi-Regime 5-Mode Comparison & Ablation
if RUN_MODEL_COMPARISON
    fprintf('\n>>> Executing Stage 6: Multi-Regime 5-Mode Comparison (05_model_comparison.m)...\n');
    tStage = tic;
    runScript(fullfile(projectRoot, 'experiments', '05_model_comparison.m'));
    fprintf('>>> Stage 6 completed in %.2f s.\n', toc(tStage));
end

%% STAGE 7: Full-Grid Coverage Map & Interactive Dashboard
if RUN_COVERAGE_GRID
    fprintf('\n>>> Executing Stage 7: Full-Grid Prediction & Dashboard (06_interactive_coverage_map.m)...\n');
    tStage = tic;
    runScript(fullfile(projectRoot, 'experiments', '06_interactive_coverage_map.m'));
    fprintf('>>> Stage 7 completed in %.2f s.\n', toc(tStage));
end

fprintf('\n=========================================================================\n');
fprintf('  PIPELINE EXECUTION COMPLETE (Total elapsed time: %.2f s)\n', toc(totalTimer));
fprintf('=========================================================================\n');
