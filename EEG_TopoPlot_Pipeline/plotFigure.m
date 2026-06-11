function hFig = plotFigure(topoValuesAll, plotInfo, cfg)
% Create the topoplot figure for one subject or a multi-subject canvas.

[chanLabels, chanXY] = channelLayout();

if size(topoValuesAll, 1) ~= numel(chanLabels)
    warning(['plotFigure: topoValues has %d channels but the channel ' ...
             'layout has %d labels. Check channel ordering.'], ...
             size(topoValuesAll, 1), numel(chanLabels));
end

if isfield(cfg, 'fixedColorLimits') && numel(cfg.fixedColorLimits) == 2
    clim = cfg.fixedColorLimits;
else
    clim = sharedColorLimits(topoValuesAll);
end
nConditions = size(topoValuesAll, 2);
nSubjects = size(topoValuesAll, 3);

if nSubjects == 1
    hFig = singleSubjectFigure(topoValuesAll, plotInfo, ...
                               chanLabels, chanXY, clim, nConditions);
else
    hFig = multiSubjectFigure(topoValuesAll, plotInfo, cfg, ...
                              chanLabels, chanXY, clim, nConditions, nSubjects);
end
end

function hFig = singleSubjectFigure(topoValuesAll, plotInfo, ...
                                    chanLabels, chanXY, clim, nConditions)
if nConditions == 1
    titleStr = sprintf('%s | %s | Window [%d %d] | Chord onset %d | Baseline [%d %d]', ...
                       char(plotInfo.subjectNames(1)), char(plotInfo.conditionLabels(1)), ...
                       plotInfo.timeWindow_remap(1), plotInfo.timeWindow_remap(2), ...
                       plotInfo.baselineChordOnset_remap, ...
                       plotInfo.baselineWindow_remap(1), plotInfo.baselineWindow_remap(2));

    hFig = scalpMapPanel(topoValuesAll(:,1,1), chanLabels, chanXY, clim, titleStr);
else
    hFig = figure('Color','w');
    t = tiledlayout(1, nConditions, 'TileSpacing','compact', 'Padding','compact');

    for c = 1:nConditions
        ax = nexttile(t);
        titleStr = char(plotInfo.conditionLabels(c));
        scalpMapPanel(topoValuesAll(:,c,1), chanLabels, chanXY, clim, titleStr, ax, false);
    end

    sgtitle(sprintf('%s | Window [%d %d] | Chord onset %d | Baseline [%d %d]', ...
            char(plotInfo.subjectNames(1)), ...
            plotInfo.timeWindow_remap(1), plotInfo.timeWindow_remap(2), ...
            plotInfo.baselineChordOnset_remap, ...
            plotInfo.baselineWindow_remap(1), plotInfo.baselineWindow_remap(2)), ...
            'FontName','Arial', 'FontSize', 18, 'Interpreter','none');

    cb = colorbar;
    cb.Layout.Tile = 'east';
    cb.Label.String = 'Voltage (\muV)';
end
end

function hFig = multiSubjectFigure(topoValuesAll, plotInfo, cfg, ...
                                   chanLabels, chanXY, clim, nConditions, nSubjects)
hFig = figure('Color','w');
applyFigureSize(hFig, cfg);

if nConditions == 1
    nCols = min(defaultMultiColumns(cfg), nSubjects);
    nRows = ceil(nSubjects / nCols);
else
    nRows = nSubjects;
    nCols = nConditions;
end

t = tiledlayout(nRows, nCols, 'TileSpacing','compact', 'Padding','compact');
lastMapAx = [];

for s = 1:nSubjects
    for c = 1:nConditions
        if nConditions == 1
            tileIndex = s;
        else
            tileIndex = (s - 1) * nCols + c;
        end

        ax = nexttile(t, tileIndex);

        if nConditions == 1
            titleStr = char(plotInfo.subjectNames(s));
        else
            titleStr = sprintf('%s | %s', ...
                               char(plotInfo.subjectNames(s)), ...
                               char(plotInfo.conditionLabels(c)));
        end

        scalpMapPanel(topoValuesAll(:,c,s), chanLabels, chanXY, clim, ...
                      titleStr, ax, false, ...
                      multiPanelTitleFontSize(cfg), ...
                      multiLabelFontSize(cfg), ...
                      multiMarkerSize(cfg), ...
                      showChannelLabels(cfg));
        lastMapAx = ax;
    end
end

if nConditions == 1
    for tileIndex = (nSubjects + 1):(nRows * nCols)
        ax = nexttile(t, tileIndex);
        axis(ax, 'off');
    end
end

if nConditions == 1
    conditionText = char(plotInfo.conditionLabels(1));
else
    conditionText = sprintf('%d conditions/contrasts', nConditions);
end

sgtitle(sprintf('%s | %d subjects | Window [%d %d] | Chord onset %d | Baseline [%d %d]', ...
        conditionText, nSubjects, ...
        plotInfo.timeWindow_remap(1), plotInfo.timeWindow_remap(2), ...
        plotInfo.baselineChordOnset_remap, ...
        plotInfo.baselineWindow_remap(1), plotInfo.baselineWindow_remap(2)), ...
        'FontName','Arial', 'FontSize', 18, 'Interpreter','none');

if ~isempty(lastMapAx)
    cb = colorbar(lastMapAx);
    cb.Layout.Tile = 'east';
    cb.Label.String = 'Voltage (\muV)';
end
end

function applyFigureSize(hFig, cfg)
    if isfield(cfg, 'figureSizePixels') && numel(cfg.figureSizePixels) == 2
        width = cfg.figureSizePixels(1);
        height = cfg.figureSizePixels(2);

        if all(isfinite([width height])) && width > 0 && height > 0
            set(hFig, 'Units', 'pixels', 'Position', [50 50 width height]);
        end
    end
end

function fontSize = multiPanelTitleFontSize(cfg)
    if isfield(cfg, 'multiPanelTitleFontSize') && ~isempty(cfg.multiPanelTitleFontSize)
        fontSize = cfg.multiPanelTitleFontSize;
    else
        fontSize = 11;
    end
end

function fontSize = multiLabelFontSize(cfg)
    if isfield(cfg, 'multiLabelFontSize') && ~isempty(cfg.multiLabelFontSize)
        fontSize = cfg.multiLabelFontSize;
    else
        fontSize = 7;
    end
end

function markerSize = multiMarkerSize(cfg)
    if isfield(cfg, 'multiMarkerSize') && ~isempty(cfg.multiMarkerSize)
        markerSize = cfg.multiMarkerSize;
    else
        markerSize = 18;
    end
end

function tf = showChannelLabels(cfg)
    if isfield(cfg, 'showChannelLabels') && ~isempty(cfg.showChannelLabels)
        tf = cfg.showChannelLabels;
    else
        tf = true;
    end
end

function nCols = defaultMultiColumns(cfg)
    if isfield(cfg, 'multiSubjectColumns') && ~isempty(cfg.multiSubjectColumns)
        nCols = cfg.multiSubjectColumns;
    else
        nCols = 5;
    end

    if ~isscalar(nCols) || nCols < 1
        nCols = 5;
    end

    nCols = round(nCols);
end

function clim = sharedColorLimits(values)
    vAbs = abs(values(:));
    vAbs = vAbs(~isnan(vAbs));

    if isempty(vAbs)
        vMax = 1;
    else
        vMax = prctile(vAbs, 99);
        if vMax == 0
            vMax = max(vAbs);
            if vMax == 0
                vMax = 1;
            end
        end
    end

    clim = [-vMax, vMax];
end
