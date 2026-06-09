function S250_saveFigure(hFig, cfg, meta)

    %---------------------- Output directory ----------------------------
    outDir = fullfile(pwd, 'figures');
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    %---------------------- Build base file name ------------------------
    if ~isfield(cfg, 'name') || isempty(cfg.name)
        baseName = 'unnamed';
    else
        baseName = cfg.name;
    end
    baseName = strrep(baseName, ' ', '_');

    condLabel = '';
    if isfield(meta, 'conditionNames') && isKey(meta.conditionNames, meta.conditionNumber)
        condLabel = meta.conditionNames(meta.conditionNumber);
        condLabel = strrep(condLabel, ' ', '');
    end

    if isfield(cfg, 'index') && ~isempty(cfg.index) && isnumeric(cfg.index)
        idxStr = sprintf('%02d_', cfg.index);
    else
        idxStr = '';
    end

    if isfield(cfg, 'plotMode')
        modeStr = cfg.plotMode;
    else
        modeStr = 'plot';
    end

    fnameFig = sprintf('%s%s_cond%d_%s_%s.fig', ...
                       idxStr, baseName, cfg.conditionNumber, condLabel, modeStr);
    fullPathFig = fullfile(outDir, fnameFig);

    %---------------------- Make figure "full screen" -------------------
    if ishghandle(hFig)
        try
            % For newer MATLAB versions
            set(hFig, 'WindowState', 'maximized');
        catch
            % Fallback: normalized outer position
            set(hFig, 'Units', 'normalized', 'OuterPosition', [0 0 1 1]);
        end
    end

    %---------------------- Save as .fig --------------------------------
    try
        savefig(hFig, fullPathFig);
        fprintf('Saved figure (FIG): %s\n', fullPathFig);
    catch ME
        warning('S250_saveFigure: savefig failed: %s', ME.message);
    end

    %---------------------- Close the figure ----------------------------
    if ishghandle(hFig)
        close(hFig);
    end
end