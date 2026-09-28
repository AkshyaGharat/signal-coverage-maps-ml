% verify_additive_covariance.m
% Synthetic Mathematical Verification of Additive Anisotropic Covariance Model
% Project: Signal Coverage Maps Using Measurements and Machine Learning

clear; clc; close all;

fprintf('=========================================================================\n');
fprintf('  Step 1: Synthetic Mathematical Verification of Additive SASR Kernel\n');
fprintf('=========================================================================\n\n');

%% 1. Synthetic Multi-Cell Layout Setup
% Cell A: North sector (azimuth 0 deg)
% Cell B: East sector (azimuth 90 deg)
% Cell C: South-West sector (azimuth 225 deg)

cellIDs = [1; 1; 1; 2; 2; 2; 3; 3; 3];
azimuths = [0; 0; 0; 90; 90; 90; 225; 225; 225];

% Local metric East and North coordinates (meters)
xE = [0; 50; 100;  200; 250; 300; -100; -150; -200];
yN = [0; 80; 150; -100; -50;   0; -100; -180; -250];
N = numel(xE);

fprintf('[1] Synthetic Multi-Cell Test Setup (%d observations, 3 cell sectors):\n', N);
for i = 1:N
    fprintf('    Obs %d: Cell %d, Azimuth %3d deg, Pos=(%4.0fm, %4.0fm)\n', ...
        i, cellIDs(i), azimuths(i), xE(i), yN(i));
end
fprintf('\n');

%% 2. Verify Compass-Aligned Metric Transformations
fprintf('[2] Verifying Compass-Aligned Metric Transformations...\n');

% Test North (0 deg): h_par == h_N, h_perp == h_E
[hp_0, ht_0] = sector_transform_compass(100, 50, 0);
fprintf('    Azimuth 0 deg  (North): h_E=100m, h_N=50m  -> h_par=%.1fm, h_perp=%.1fm ', hp_0, ht_0);
if abs(hp_0 - 50) < 1e-6 && abs(ht_0 - 100) < 1e-6
    fprintf('[PASS]\n');
else
    fprintf('[FAIL]\n');
end

% Test East (90 deg): h_par == h_E, h_perp == -h_N
[hp_90, ht_90] = sector_transform_compass(100, 50, 90);
fprintf('    Azimuth 90 deg (East) : h_E=100m, h_N=50m  -> h_par=%.1fm, h_perp=%.1fm ', hp_90, ht_90);
if abs(hp_90 - 100) < 1e-6 && abs(ht_90 - (-50)) < 1e-6
    fprintf('[PASS]\n');
else
    fprintf('[FAIL]\n');
end
fprintf('\n');

%% 3. Construct Component Matrices
fprintf('[3] Constructing Component Matrices & Evaluating Symmetry + Eigenvalues...\n');

sigma_g = 10.0; ell_g = 200.0;
sigma_c = 8.0;  a_par = 150.0; a_trans = 75.0;
sigma_n = 2.0;

Kg = zeros(N, N);
Kc = zeros(N, N);

for i = 1:N
    for j = 1:N
        hE_ij = xE(j) - xE(i);
        hN_ij = yN(j) - yN(i);
        d_ij  = sqrt(hE_ij^2 + hN_ij^2);
        
        % Global isotropic component
        Kg(i,j) = sigma_g^2 * exp(-d_ij / ell_g);
        
        % Cell-conditioned anisotropic component
        if cellIDs(i) == cellIDs(j)
            az_c = azimuths(i); % Verified single serving cell azimuth
            [h_p, h_t] = sector_transform_compass(hE_ij, hN_ij, az_c);
            dA_c = sqrt((h_p / a_par)^2 + (h_t / a_trans)^2);
            Kc(i,j) = sigma_c^2 * exp(-dA_c);
        else
            Kc(i,j) = 0.0; % Cross-cell anisotropic component is strictly 0
        end
    end
end

K_sum  = Kg + Kc;
K_full = Kg + Kc + (sigma_n^2)*eye(N);

matrices = {Kg, Kc, K_sum, K_full};
matNames = {'Global Isotropic Kernel (K_g)', ...
            'Cell Anisotropic Kernel (K_c)', ...
            'Combined Additive (K_g + K_c)', ...
            'Full Regularized Kernel (K_full)'};

fprintf('\n------------------------------------------------------------------------------------------\n');
fprintf('  Matrix Component                         Max Symmetry Error    Min Eigenvalue    PSD Status\n');
fprintf('------------------------------------------------------------------------------------------\n');

allPassed = true;
for m = 1:numel(matrices)
    K_m = matrices{m};
    
    symErr = max(abs(K_m - K_m'), [], 'all');
    eigVals = eig((K_m + K_m')/2);
    minEig = min(eigVals);
    
    if minEig >= -1e-6 && symErr <= 1e-12
        psdStr = 'PASS (PSD Verified)';
    else
        psdStr = 'FAIL';
        allPassed = false;
    end
    
    fprintf('  %-40s %-20.4e %-17.4e %s\n', matNames{m}, symErr, minEig, psdStr);
end
fprintf('------------------------------------------------------------------------------------------\n\n');

if allPassed
    fprintf('>>> SYNTHETIC MATHEMATICAL VERIFICATION COMPLETED SUCCESSFULLY: ALL MATRICES PSD! <<<\n\n');
else
    fprintf('>>> ERROR: SYNTHETIC VERIFICATION FAILED! <<<\n\n');
end

%% Helper Function
function [h_par, h_perp] = sector_transform_compass(h_E, h_N, theta_deg)
    t_rad = deg2rad(theta_deg);
    h_par  =  h_E * sin(t_rad) + h_N * cos(t_rad);
    h_perp =  h_E * cos(t_rad) - h_N * sin(t_rad);
end
