% Main driver for the pipeline
%
% Output:
% 1) Ask user whether to use the full preset 31-figure set.
%   1A) If yes: loop over all preset configs from S1A0_getPresetConfigs().
%   1B) If no: ask whether to build a config manually or load from a .m file.
% 2) For each config, call S200_runOneConfig(cfg), which:
%    1) loads data (dataLoading.m)
%    2) prepares time/baseline info                    (timeBaselineInfo.m)
%    3) load the ROI and electrode indices        (getROILabelAndIndices.m)
%    4) plots the figure                                     (plotFigure.m)
%    5) saves the figure                                     (saveFigure.m)

clc; clear; close all;

% ---------------------------------------------------------------------
% Use full preset set (31 figures) or custom single configuration?
% ---------------------------------------------------------------------
usePresets = [];
while isempty(usePresets)
    resp = strtrim(lower(input('Use preset 31-figure set? (y/n): ', 's')));
    if any(strcmp(resp, {'y','yes'}))
        usePresets = true;
    elseif any(strcmp(resp, {'n','no'}))
        usePresets = false;
    else
        fprintf('Please answer with y or n.\n');
    end
end

% =====================================================================
% PRESET MODE: generate all figures from S1A0_getPresetConfigs.m
% =====================================================================
if usePresets
    fprintf('\n[Preset mode] Loading preset configurations (1.A.0. S1A0_getPresetConfigs.m)...\n');
    
    configs = S1A0_getPresetConfigs();   % 1.A.0.
    if isempty(configs)
        error('S1A0_getPresetConfigs returned an empty configuration array.');
    end
    
    nCfg = numel(configs);
    fprintf('Found %d preset configurations.\n', nCfg);
    fprintf('Generating figures for all presets...\n\n');
    
    for k = 1:nCfg
        cfg = configs(k);
        
        % Ensure there is at least a name field for logging / filenames.
        if ~isfield(cfg, 'name') || isempty(cfg.name)
            cfg.name = sprintf('preset_%02d', k);
        end
        
        fprintf('(%2d/%2d) Running config: %s\n', k, nCfg, cfg.name);
        
        try
            S200_runOneConfig(cfg);     % 2.0.0.
        catch ME
            warning('Error while running preset %d (%s): %s', ...
                    k, cfg.name, ME.message);
        end
        
        fprintf('Finished config: %s\n\n', cfg.name);
    end
    
    fprintf('All preset figures generated.\n');

% =====================================================================
% CUSTOM MODE: single configuration (manual or from .m file)
% =====================================================================
else
    fprintf('\n[CUSTOM MODE]\n');
    fprintf('You can either:\n');
    fprintf('  (1) Enter parameters interactively (S1B0_configBuilder.m), or\n');
    fprintf('  (2) Use an existing .m file that returns a config struct.\n\n');
    
    choice = [];
    while isempty(choice)
        tmp = str2double(input('Choose 1 (manual) or 2 (.m file): ', 's'));
        if ismember(tmp, [1 2])
            choice = tmp;
        else
            fprintf('Please enter 1 or 2.\n');
        end
    end
    
    switch choice
        % ---------------------- Manual config ----------------------------
        case 1
            fprintf('\nBuilding configuration interactively (S1B0_configBuilder.m)...\n');
            cfg = S1B0_configBuilder();   % 1.B.0.
            
            if ~isfield(cfg, 'name') || isempty(cfg.name)
                cfg.name = 'custom_manual';
            end
            
            fprintf('Running custom manual configuration: %s\n', cfg.name);
            S200_runOneConfig(cfg);       % 2.0.0.
            fprintf('Custom manual figure generated.\n');
        
        % ---------------------- Config from .m file ----------------------
        case 2
            fprintf('\nUsing an existing config .m file.\n');
            fprintf('The file should be on the MATLAB path and look like:\n');
            fprintf('    function cfg = myConfigFile()\n');
            fprintf('        cfg = templateConfig(); %% or similar\n');
            fprintf('        %% override fields...\n');
            fprintf('    end\n\n');
            
            cfgFunc = strtrim(input('Enter config function name (without .m): ', 's'));
            if isempty(cfgFunc)
                error('No config function name provided.');
            end
            
            try
                cfg = feval(cfgFunc);   % user-defined config function
            catch ME
                error('Error calling config function "%s": %s', cfgFunc, ME.message);
            end
            
            if ~isstruct(cfg)
                error('Config function "%s" did not return a struct.', cfgFunc);
            end
            
            if ~isfield(cfg, 'name') || isempty(cfg.name)
                cfg.name = cfgFunc;
            end
            
            fprintf('Running custom config from file: %s\n', cfg.name);
            S200_runOneConfig(cfg);         % 2.0.0.
            fprintf('Custom figure generated from %s.m.\n', cfgFunc);
    end
end

fprintf('\nDone.\n');