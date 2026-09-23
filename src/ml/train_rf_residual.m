function residual_model = train_rf_residual(X_train, r_oof, opts)
% TRAIN_RF_RESIDUAL Trains a Random Forest on genuine Out-Of-Fold P2 residuals (Mode D).
%
% Mode D Architecture:
%   r_OOF = y_true - P2_OOF
%   RF_target = r_OOF
%   P3 = P2 + RF_pred_residual
%
% Inputs:
%   X_train - N_train x P matrix of predictor features.
%   r_oof   - N_train x 1 vector of genuine out-of-fold residuals.
%   opts    - (Optional) Struct with configuration options:
%               .numTrees    : Number of trees (default: 300, imported baseline configuration)
%               .minLeafSize : Minimum leaf size (default: 10, imported baseline configuration)
%               .featureNames: Cell array of predictor feature names
%
% Outputs:
%   residual_model - Struct containing:
%                     .model         : Trained TreeBagger object
%                     .numTrees      : Number of trees
%                     .minLeafSize   : Minimum leaf size
%                     .featureNames  : Cell array of feature names
%                     .importance    : OOB predictor importance scores
%                     .targetType    : 'P2_Residual'

    if nargin < 3 || isempty(opts)
        opts = struct();
    end

    if ~isfield(opts, 'numTrees') || isempty(opts.numTrees)
        opts.numTrees = 300;
    end
    if ~isfield(opts, 'minLeafSize') || isempty(opts.minLeafSize)
        opts.minLeafSize = 10;
    end
    if ~isfield(opts, 'featureNames') || isempty(opts.featureNames)
        opts.featureNames = cellstr(strcat('Feature_', string(1:size(X_train, 2))));
    end

    % Ensure finite values
    validMask = all(isfinite(X_train), 2) & isfinite(r_oof);
    X_train = X_train(validMask, :);
    r_oof   = r_oof(validMask);

    fprintf('    [ML Core] Training Residual Random Forest (Mode D)...\n');
    fprintf('              Configuration: %d trees, min leaf size %d (imported baseline configuration)\n', ...
        opts.numTrees, opts.minLeafSize);
    fprintf('              Training samples: %d, Residual target mean = %.3f dB, std = %.3f dB\n', ...
        size(X_train, 1), mean(r_oof), std(r_oof));

    t_start = tic;
    baggerModel = TreeBagger(opts.numTrees, X_train, r_oof, ...
        'Method', 'regression', ...
        'MinLeafSize', opts.minLeafSize, ...
        'OOBPrediction', 'on', ...
        'OOBPredictorImportance', 'on');
    trainTime = toc(t_start);

    fprintf('              Residual RF training completed in %.2f s.\n', trainTime);

    importance = baggerModel.OOBPermutedPredictorDeltaError;

    residual_model = struct();
    residual_model.model        = baggerModel;
    residual_model.numTrees     = opts.numTrees;
    residual_model.minLeafSize  = opts.minLeafSize;
    residual_model.featureNames = opts.featureNames;
    residual_model.importance   = importance;
    residual_model.trainTime    = trainTime;
    residual_model.targetType   = 'P2_Residual';
    residual_model.targetMean   = mean(r_oof);
    residual_model.targetStd    = std(r_oof);
end
