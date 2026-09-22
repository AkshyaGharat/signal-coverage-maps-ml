function K = anisotropic_covariance(h_E, h_N, cell_i, cell_j, az_vec, sigma_g, ell_g, sigma_c, a_par, a_trans, sigma_n)
% ANISOTROPIC_COVARIANCE Computes the Additive Positive Semi-Definite Covariance Matrix:
% K(i,j) = K_global(i,j) + 1(cell_i == cell_j) * K_cell,c(i,j) + sigma_n^2 * delta_ij
%
% Inputs:
%   h_E       - Matrix of pairwise East metric offsets (N x N)
%   h_N       - Matrix of pairwise North metric offsets (N x N)
%   cell_i    - Vector of serving cell IDs for row observations (N x 1)
%   cell_j    - Vector of serving cell IDs for column observations (N x 1)
%   az_vec    - Vector of serving cell compass azimuths (N x 1)
%   sigma_g   - Global isotropic signal variance (dB)
%   ell_g     - Global isotropic correlation range (meters)
%   sigma_c   - Cell-conditioned anisotropic variance (dB)
%   a_par     - Sector-aligned parallel correlation range (meters)
%   a_trans   - Sector-aligned transverse correlation range (meters)
%   sigma_n   - Noise variance / nugget (dB)
%
% Outputs:
%   K         - N x N symmetric positive semi-definite covariance matrix

    N_row = size(h_E, 1);
    N_col = size(h_E, 2);
    
    % Global Isotropic Component
    d_ij = sqrt(h_E.^2 + h_N.^2);
    Kg = (sigma_g^2) * exp(-d_ij ./ max(1.0, ell_g));
    
    % Cell-conditioned Anisotropic Component
    Kc = zeros(N_row, N_col);
    
    for i = 1:N_row
        for j = 1:N_col
            if cell_i(i) == cell_j(j) && cell_i(i) > 0
                az_c = az_vec(i);
                [hp, ht] = sector_coordinate_transform(h_E(i,j), h_N(i,j), az_c);
                dA_c = sqrt((hp / max(1.0, a_par))^2 + (ht / max(1.0, a_trans))^2);
                Kc(i,j) = (sigma_c^2) * exp(-dA_c);
            end
        end
    end
    
    K = Kg + Kc;
    
    if N_row == N_col
        K = K + (sigma_n^2 + 1e-5) * eye(N_row);
    end
end
