function rf_model = train_rf_model(X_train, y_train, opts)
% TRAIN_RF_MODEL Trains a Random Forest (TreeBagger) model for Direct RSRP Prediction (Mode C).
%
% Syntax:
%   rf_model = train_rf_model(X_train, y_train)
%   rf_model = train_rf_model(X_train, y_train, opts)
%
% Inputs:
%   X_train - N_train x P matrix of predictor features.
%   y_train - N_train x 1 vector of target values (e.g., measured SS_RSRP in dBm).
%   opts    - (Optional) Struct with configuration options:
%               .numTrees    : Number of trees (default: 300, imported baseline configuration)
%               .minLeafSize : Minimum observations per leaf (default: 10, imported baseline configuration)
%               .featureNames: Cell array of feature names (1 x P)
%
% Outputs:
%   rf_model - Struct containing:
%               .model         : Trained TreeBagger object
%               .numTrees      : Number of trees
%               .minLeafSize   : Minimum leaf size
%               .featureNames  : Cell array of feature names
%               .importance    : OOB predictor importance scores
%               .targetType    : 'Direct_RSRP'

    if nargin < 3 || isempty(opts)
        opts = struct();
    end

    % Imported baseline configuration from SignalCoverageML Phase 3D/3F
    if ~isfield(opts, 'numTrees') || isempty(opts.numTrees)
        opts.numTrees = 300;
    end
    if ~isfield(opts, 'minLeafSize') || isempty(opts.minLeafSize)
        opts.minLeafSize = 10;
    end
    if ~isfield(opts, 'featureNames') || isempty(opts.featureNames)
        opts.featureNames = cellstr(strcat('Feature_', string(1:size(X_train, 2))));
    end

    fprintf('    [ML Core] Training Direct Random Forest (Mode C)...\n');
    fprintf('              Configuration: %d trees, min leaf size %d (imported baseline configuration)\n', ...
        opts.numTrees, opts.minLeafSize);
    fprintf('              Training samples: %d, Predictors: %d\n', size(X_train, 1), size(X_train, 2));

    t_start = tic;
    baggerModel = TreeBagger(opts.numTrees, X_train, y_train, ...
        'Method', 'regression', ...
        'MinLeafSize', opts.minLeafSize, ...
        'OOBPrediction', 'on', ...
        'OOBPredictorImportance', 'on');
    trainTime = toc(t_start);

    fprintf('              Training completed in %.2f s.\n', trainTime);

    % Extract predictor importance
    importance = baggerModel.OOBPermutedPredictorDeltaError;

    rf_model = struct();
    rf_model.model        = baggerModel;
    rf_model.numTrees     = opts.numTrees;
    rf_model.minLeafSize  = opts.minLeafSize;
    rf_model.featureNames = opts.featureNames;
    rf_model.importance   = importance;
    rf_model.trainTime    = trainTime;
    rf_model.targetType   = 'Direct_RSRP';
end
