function [p3_pred, rf_residual_pred] = predict_hybrid(p2_pred, residual_model, X_test)
% PREDICT_HYBRID Evaluates Mode D (Hybrid Physics + RF Residual):
%   P3(x) = P2(x) + rf_residual_pred(x)
%
% Inputs:
%   p2_pred        - N_test x 1 vector of Mode B2 (Additive SASR) predictions (dBm).
%   residual_model - Trained residual TreeBagger model struct from train_rf_residual.
%   X_test         - N_test x P feature matrix or Table for test points.
%
% Outputs:
%   p3_pred          - N_test x 1 vector of final hybrid RSRP predictions (dBm).
%   rf_residual_pred - N_test x 1 vector of predicted residual corrections (dB).

    % Predict the residual correction
    rf_residual_pred = predict_rf(residual_model, X_test);

    % Synthesize hybrid prediction
    p3_pred = p2_pred + rf_residual_pred;
end
