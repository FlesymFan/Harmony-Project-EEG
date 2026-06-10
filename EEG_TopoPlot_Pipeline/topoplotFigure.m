function hFig = topoplotFigure(topoValuesAll, plotInfo, cfg)
% Create the topoplot figure for one subject.

[chanLabels, chanXY] = topoplotChannelLayout();

if size(topoValuesAll, 1) ~= numel(chanLabels)
    warning(['topoplotFigure: topoValues has %d channels but the channel ' ...
             'layout has %d labels. Check channel ordering.'], ...
             size(topoValuesAll, 1), numel(chanLabels));
end

clim = sharedColorLimits(topoValuesAll);
nConditions = size(topoValuesAll, 2);

if nConditions == 1
    titleStr = sprintf('%s | %s | Window [%d %d] | Chord onset %d | Baseline [%d %d]', ...
                       char(plotInfo.subjectName), char(plotInfo.conditionLabels(1)), ...
                       plotInfo.timeWindow_remap(1), plotInfo.timeWindow_remap(2), ...
                       plotInfo.baselineChordOnset_remap, ...
                       plotInfo.baselineWindow_remap(1), plotInfo.baselineWindow_remap(2));

    hFig = scalpMapPanel(topoValuesAll(:,1), chanLabels, chanXY, clim, titleStr);
else
    hFig = figure('Color','w');
    t = tiledlayout(1, nConditions, 'TileSpacing','compact', 'Padding','compact');

    for c = 1:nConditions
        ax = nexttile(t);
        titleStr = char(plotInfo.conditionLabels(c));
        scalpMapPanel(topoValuesAll(:,c), chanLabels, chanXY, clim, titleStr, ax, false);
    end

    sgtitle(sprintf('%s | Window [%d %d] | Chord onset %d | Baseline [%d %d]', ...
            char(plotInfo.subjectName), ...
            plotInfo.timeWindow_remap(1), plotInfo.timeWindow_remap(2), ...
            plotInfo.baselineChordOnset_remap, ...
            plotInfo.baselineWindow_remap(1), plotInfo.baselineWindow_remap(2)), ...
            'FontName','Arial', 'FontSize', 18, 'Interpreter','none');

    cb = colorbar;
    cb.Layout.Tile = 'east';
    cb.Label.String = 'Voltage (\muV)';
end
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
