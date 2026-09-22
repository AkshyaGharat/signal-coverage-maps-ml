function [h_par, h_perp] = sector_coordinate_transform(h_E, h_N, theta_compass_deg)
% SECTOR_COORDINATE_TRANSFORM Transforms East/North metric offsets into transmitter-aligned parallel and perpendicular offsets using compass azimuth theta (clockwise from True North).
%
% Inputs:
%   h_E               - Local metric offset in East direction (meters)
%   h_N               - Local metric offset in North direction (meters)
%   theta_compass_deg - Base station sector compass azimuth (degrees clockwise from True North)
%
% Outputs:
%   h_par             - Parallel offset along sector main-lobe direction (meters)
%   h_perp            - Perpendicular offset transverse to sector main-lobe (meters)

    t_rad = deg2rad(theta_compass_deg);
    h_par  =  h_E .* sin(t_rad) + h_N .* cos(t_rad);
    h_perp =  h_E .* cos(t_rad) - h_N .* sin(t_rad);
end
