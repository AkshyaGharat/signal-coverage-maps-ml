function y_pred = predict_rf(rf_model, X_test)
% PREDICT_RF Predicts RSRP or residuals using trained Random Forest model.
%
% Syntax:
%   y_pred = predict_rf(rf_model, X_test)
%
% Inputs:
%   rf_model - Struct produced by train_rf_model or train_rf_residual,
%              or a direct TreeBagger object.
%   X_test   - N_test x P feature matrix or Table containing feature columns.
%
% Outputs:
%   y_pred   - N_test x 1 numeric vector of predictions.

    if isstruct(rf_model) && isfield(rf_model, 'model')
        modelObj = rf_model.model;
        fNames = rf_model.featureNames;
    else
        modelObj = rf_model;
        fNames = {};
    end

    if istable(X_test)
        if ~isempty(fNames) && all(ismember(fNames, X_test.Properties.VariableNames))
            X_mat = table2array(X_test(:, fNames));
        else
            [X_mat, ~, ~] = extract_ml_features(X_test, '');
        end
    else
        X_mat = X_test;
    end

    rawPred = predict(modelObj, X_mat);

    if iscell(rawPred)
        y_pred = str2double(rawPred);
    else
        y_pred = double(rawPred);
    end
end
