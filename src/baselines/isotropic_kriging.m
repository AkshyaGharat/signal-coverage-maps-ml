function [predMean, predVar] = isotropic_kriging(trainLats, trainLons, trainY, testLats, testLons, lengthScale, sigmaF, sigmaN)
% ISOTROPIC_KRIGING Performs Ordinary Kriging / Isotropic Gaussian Process Regression.
%
% Formula:
%   C(h) = sigmaF^2 * exp(-||h|| / lengthScale) + sigmaN^2 * delta

if nargin < 6 || isempty(lengthScale), lengthScale = 100.0; end
if nargin < 7 || isempty(sigmaF),      sigmaF = 12.0;       end
if nargin < 8 || isempty(sigmaN),      sigmaN = 2.0;        end

R = 6371000;
N_tr = numel(trainY);
N_te = numel(testLats);

% Pairwise training distance matrix
[lat1, lat2] = meshgrid(trainLats, trainLats);
[lon1, lon2] = meshgrid(trainLons, trainLons);
dLat = deg2rad(lat2 - lat1); dLon = deg2rad(lon2 - lon1);
a = sin(dLat/2).^2 + cos(deg2rad(lat1)).*cos(deg2rad(lat2)).*sin(dLon/2).^2;
K_tr = sigmaF^2 * exp(-(R * (2 * atan2(sqrt(a), sqrt(1-a)))) / lengthScale) + (sigmaN^2 + 1e-6) * eye(N_tr);

% Add Ordinary Kriging row/col for constant mean estimation
K_aug = [K_tr, ones(N_tr, 1); ones(1, N_tr), 0];
y_aug = [trainY; 0];

% Solve Kriging weights for test points
predMean = zeros(N_te, 1);
predVar  = zeros(N_te, 1);

for i = 1:N_te
    dLat_te = deg2rad(trainLats - testLats(i));
    dLon_te = deg2rad(trainLons - testLons(i));
    a_te = sin(dLat_te/2).^2 + cos(deg2rad(testLats(i))).*cos(deg2rad(trainLats)).*sin(dLon_te/2).^2;
    d_te = R * (2 * atan2(sqrt(a_te), sqrt(1-a_te)));
    
    k_te = sigmaF^2 * exp(-d_te / lengthScale);
    k_aug = [k_te; 1];
    
    w_aug = K_aug \ k_aug;
    predMean(i) = sum(w_aug(1:N_tr) .* trainY);
    predVar(i)  = max(0, sigmaF^2 - sum(w_aug(1:N_tr) .* k_te) - w_aug(end));
end

end
