function S200_runOneConfig(cfg)

    %---------------------- 1) Load + organize data ---------------------
    [Extract_Data, Extract_Data_Indiv, meta] = S210_dataLoading(cfg.conditionNumber);

    %---------------------- 2) Time + baseline info ---------------------
    timeInfo = S220_timeBaselineInfo(cfg, meta);

    %---------------------- 3) ROI label and indices --------------------
    roiTitle = '';
    rowIdxSubset = [];

    if ~isfield(cfg, 'plotMode') || isempty(cfg.plotMode)
        error('S200_runOneConfig: cfg.plotMode is missing or empty.');
    end

    % Only compute ROI indices when needed
    if ~strcmpi(cfg.plotMode, 'multichannel')
        if ~isfield(cfg, 'roiNames')
            error('S200_runOneConfig: cfg.roiNames is missing (needed for plotMode "%s").', cfg.plotMode);
        end
        [roiTitle, rowIdxSubset] = S230_getROILabelAndIndices(cfg.roiNames, meta);
    end

    %---------------------- 4) Plot figure ------------------------------
    hFig = S240_plotFigure(cfg, Extract_Data, Extract_Data_Indiv, meta, ...
                           timeInfo, roiTitle, rowIdxSubset);

    %---------------------- 5) Save to disk -----------------------------
    S250_saveFigure(hFig, cfg, meta);

    %---------------------- 6) Close figure (no pop-up clutter) --------
    if ishghandle(hFig)
        close(hFig);
    end
end
