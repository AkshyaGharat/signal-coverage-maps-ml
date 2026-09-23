% 00_environment_test.m
% Environment and Toolbox Availability Verification Script
% Project: Signal Coverage Maps Using Measurements and Machine Learning

fprintf('====================================================\n');
fprintf('  MATLAB Environment & Setup Audit\n');
fprintf('====================================================\n\n');

%% 1. MATLAB System & Release Info
fprintf('[1] Checking MATLAB Release Info...\n');
sysVer = version;
fprintf('    MATLAB Version: %s\n', sysVer);
[~, sysRelease] = version;
fprintf('    Release: %s\n\n', sysRelease);

%% 2. Installed Products & Toolboxes Audit
fprintf('[2] Auditing Installed Products & Toolboxes...\n');
verStruct = ver;
installedToolboxes = {verStruct.Name}';
for i = 1:numel(installedToolboxes)
    fprintf('    - %s (%s)\n', verStruct(i).Name, verStruct(i).Version);
end
fprintf('\n');

%% 3. Target Research Toolboxes Verification
fprintf('[3] Checking Availability of Target Research Toolboxes...\n');
targetToolboxes = { ...
    'Communications Toolbox', 'communications_toolbox'; ...
    'Statistics and Machine Learning Toolbox', 'statistics_toolbox'; ...
    'Mapping Toolbox', 'map_toolbox'; ...
    'Signal Processing Toolbox', 'signal_toolbox'; ...
    'Image Processing Toolbox', 'image_toolbox' ...
};

for i = 1:size(targetToolboxes, 1)
    tbName = targetToolboxes{i, 1};
    tbLic  = targetToolboxes{i, 2};
    hasLic = license('test', tbLic);
    isInstalled = any(strcmpi({verStruct.Name}, tbName));
    
    if isInstalled && hasLic
        status = 'AVAILABLE & LICENSED';
    elseif isInstalled
        status = 'INSTALLED (No active license)';
    else
        status = 'NOT INSTALLED';
    end
    fprintf('    %-40s : %s\n', tbName, status);
end
fprintf('\n');

%% 4. Communications Toolbox & RF Propagation Functionality
fprintf('[4] Verifying RF Propagation & Coverage Functions...\n');
propFunctions = { ...
    'txsite', ...
    'rxsite', ...
    'propagationModel', ...
    'sigstrength', ...
    'pathloss', ...
    'coverage', ...
    'raytrace', ...
    'los' ...
};

for i = 1:numel(propFunctions)
    fnName = propFunctions{i};
    fnPath = which(fnName);
    if ~isempty(fnPath)
        fprintf('    %-20s : FOUND (%s)\n', fnName, fnPath);
    else
        fprintf('    %-20s : NOT FOUND\n', fnName);
    end
end
fprintf('\n');

%% 5. Verification of Basic Plotting & Graphics Output
fprintf('[5] Testing Basic Plotting & Figure Generation...\n');
try
    hFig = figure('Name', 'Environment Plot Test', 'Visible', 'off');
    [X, Y] = meshgrid(-10:0.5:10, -10:0.5:10);
    R = sqrt(X.^2 + Y.^2) + eps;
    Z = sin(R)./R;
    contourf(X, Y, Z);
    title('MATLAB Figure Output Test - Signal Coverage Verification');
    xlabel('X Position');
    ylabel('Y Position');
    colorbar;
    
    % Save sample plot in results/figures
    if ~exist('figures', 'dir')
        mkdir('figures');
    end
    saveas(hFig, fullfile('figures', 'environment_plot_test.png'));
    close(hFig);
    fprintf('    Plot generation test: SUCCESS (Saved to figures/environment_plot_test.png)\n');
catch me
    fprintf('    Plot generation test: FAILED (%s)\n', me.message);
end

fprintf('\n====================================================\n');
fprintf('  Environment Test Complete\n');
fprintf('====================================================\n');
