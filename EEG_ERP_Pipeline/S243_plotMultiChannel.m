function hFig = S243_plotMultiChannel(cfg, Extract_Data_Indiv, meta, timeInfo)
% Multi-channel ERP plotting with baseline correction

    condInfo = {
        'Exp_noSP',      cfg.Exp_noSP,      [0.6, 0,   0.6], 'Expected w/o SP';
        'Unexp_noSP',    cfg.Unexp_noSP,    [0,   0.6, 0.3], 'Unexpected w/o SP';
        'Diff_noSP',     cfg.Diff_noSP,     [0.85,0.3, 0.1], 'Unexp-Exp w/o. SP';
        'Exp_withSP',    cfg.Exp_withSP,    [0.6, 0.8, 1],   'Expected w SP';
        'Unexp_withSP',  cfg.Unexp_withSP,  [0.9, 0.6, 0.4], 'Unexpected w SP';
        'Diff_withSP',   cfg.Diff_withSP,   [0,   0.6, 0],   'Unexp-Exp w. SP';
        'Atonal',        cfg.Atonal,        [0.5, 0.5, 0.5], 'Atonal'
    };

    keep         = cell2mat(condInfo(:,2));
    condsToPlot  = condInfo(keep,1);
    colorsToPlot = condInfo(keep,3);
    labelsToPlot = condInfo(keep,4);
 
    if isempty(condsToPlot)
        warning('S243_plotMultiChannel: no conditions toggled on; nothing to plot.');
        hFig = figure('Name','Multi Channel - Empty','Color','w');
        text(0.5,0.5,'No conditions toggled on','HorizontalAlignment','center','FontSize',16);
        axis off;
        return;
    end
 
    %---------------------- Channel selection ---------------------------
    channelMode = lower(getOpt(cfg,'channelMode','koelsch20'));
    channelList = getOpt(cfg,'channelList',[]);
    [chLabels, chRowIdx] = S230_getROILabelAndIndices('select', channelMode, channelList);
    nCh = numel(chRowIdx);
 
    showSE    = getOpt(cfg,'plotSE',true);
    showIndiv = getOpt(cfg,'plotIndividual',false);
    yFixed    = getOpt(cfg,'yLim',[]);
    individualYLim = getOpt(cfg,'individualYLim',[-10 10]);
    groupYLim      = getOpt(cfg,'groupYLim',[-5 5]);
    indivLW    = getOpt(cfg,'indivLineWidth',0.6);
    indivAlpha = getOpt(cfg,'indivLineAlpha',0.20);
    meanLW     = getOpt(cfg,'multiMeanLineWidth',2.5);
 
    t_ms  = timeInfo.newTimeAxis;
    inWin = timeInfo.inWin;
    x     = t_ms(inWin);
 
    %---------------------- Grid geometry -------------------------------
    if nCh <= 20
        nColsPlot = 5;
    elseif nCh <= 36
        nColsPlot = 6;
    else
        nColsPlot = 8;
    end
    nRowsPlot = ceil(nCh / nColsPlot);
    nCols     = nColsPlot + 1;              % last column holds the legend
 
    hFig = figure('Name','Multi Channel','Color','w','Visible','on');
    set(hFig,'Units','normalized','OuterPosition',[0.02 0.05 0.96 0.88]);
 
    t = tiledlayout(nRowsPlot, nCols, 'TileSpacing','compact', 'Padding','compact');

    % tiledlayout clears existing axes, so add the hover label after it.
    if showIndiv, makeHoverLabel(hFig); end
    useTips = showIndiv && (nCh * meta.numSubjects * numel(condsToPlot)) <= 100;
    axLeg = nexttile(t, nCols, [nRowsPlot 1]);
    axis(axLeg,'off'); set(axLeg,'HitTest','off');
 
    legLines  = gobjects(0);
    legLabels = {};
    axAll     = gobjects(1,nCh);
 
    for ch = 1:nCh
        row = ceil(ch / nColsPlot);
        col = mod(ch-1, nColsPlot) + 1;
        ax  = nexttile(t, (row-1)*nCols + col);
        axAll(ch) = ax;
        hold(ax,'on');
 
        for c = 1:numel(condsToPlot)
            cColor = colorsToPlot{c};
            tr = prepareTraces(Extract_Data_Indiv.(condsToPlot{c}), ...
                               chRowIdx(ch), timeInfo.baselineIdx_old);
 
            if showIndiv && tr.n > 1
                for s = 1:tr.n
                    ys = tr.indiv(s, inWin);
                    hInd = plot(ax, x, ys, 'LineWidth', indivLW, ...
                                'Color', [cColor indivAlpha], 'HandleVisibility','off');
                    attachSubjectTip(hInd, cleanSubjectName(meta.subjectNames{s}), labelsToPlot{c}, useTips);
                end
            end
 
            y = tr.mean(inWin);
            if showSE && tr.n > 1
                ub = y + tr.sem(inWin);
                lb = y - tr.sem(inWin);
                fill(ax, [x fliplr(x)], [ub fliplr(lb)], cColor, ...
                     'FaceAlpha', 0.2, 'EdgeColor','none', 'HandleVisibility','off', ...
                     'PickableParts','none');
            end
 
            hLine = plot(ax, x, y, 'LineWidth', meanLW, 'Color', cColor);
 
            % Legend handles come from the first tile only.
            if ch == 1
                hLine.DisplayName = labelsToPlot{c};
                legLines(end+1)   = hLine;            %#ok<AGROW>
                legLabels{end+1}  = labelsToPlot{c};  %#ok<AGROW>
            else
                hLine.HandleVisibility = 'off';
            end
        end
 
        if ~cfg.plotCloseUp
            onsets = timeInfo.expectOnsetRemapped;
            for i = 1:numel(onsets)
                xline(ax, onsets(i), '--', 'Color',[0.2 0.4 1], ...
                      'LineWidth', 1, 'HandleVisibility','off');
            end
        end
        xline(ax, timeInfo.unexpectOnsetRemapped, '--', 'Color',[0 0 0], ...
              'LineWidth', 1.5, 'HandleVisibility','off');
        yline(ax, 0, '--', 'Color',[0 0 0], 'LineWidth', 1, 'HandleVisibility','off');
 
        xlim(ax, [timeInfo.Start, timeInfo.End]);
        title(ax, char(chLabels(ch)), 'FontSize', 10);
        set(ax, 'FontName','Arial', 'FontSize', 9, 'LineWidth', 1);
        if row < nRowsPlot, set(ax,'XTickLabel',[]); end
        if col ~= 1,        set(ax,'YTickLabel',[]); end
        hold(ax,'off');
    end
 
    %---------------------- Shared y limits -----------------------------
    if ~isempty(yFixed)
        yl = yFixed;
    elseif showIndiv
        yl = individualYLim;
    else
        yl = groupYLim;
    end
    for ch = 1:nCh
        ylim(axAll(ch), yl);
        if getOpt(cfg,'yAxisFlip',false)
            set(axAll(ch),'YDir','reverse');
        end
    end
 
    %---------------------- Labels and legend ---------------------------
    xlabel(t, 'Time (ms)', 'FontSize', 12);
    ylabel(t, 'Amplitude (\muV)', 'FontSize', 12);
    title(t, sprintf('%s (Condition %d)  |  n = %d  |  %s', ...
          meta.conditionNames(meta.conditionNumber), meta.conditionNumber, ...
          meta.numSubjects, channelMode), 'FontSize', 16, 'FontWeight','bold');
 
    if ~isempty(legLines)
        lgd = legend(legLines, legLabels);
        lgd.Box = 'off'; lgd.Color = 'none';
        lgd.FontName = 'Arial'; lgd.FontSize = 9;
        lgd.Orientation = 'vertical';
        lgd.Units = 'normalized'; axLeg.Units = 'normalized';
        p = axLeg.Position;
        lgd.Position = [p(1)+0.03*p(3), p(2)+0.72*p(4), 0.92*p(3), 0.24*p(4)];
        uistack(lgd,'top');
 
        note = sprintf('n = %d subjects', meta.numSubjects);
        if showIndiv, note = [note newline 'faint = individual']; end
        if showSE,    note = [note newline 'shaded = ' char(177) '1 SEM']; end
        text(axLeg, 0.05, 0.60, note, 'Units','normalized', ...
             'FontSize', 9, 'VerticalAlignment','top', 'Color',[0.3 0.3 0.3]);
    end
end
 
% Attach the subject name to an individual trace, for hover readout and
% for the data tip shown when the trace is clicked.
function attachSubjectTip(hLine, subjName, condLabel, withTip)
    hLine.Tag      = 'indivTrace';
    hLine.UserData = struct('subject', subjName, 'cond', condLabel);

    % The data-tip rows need one string per sample, so they are only worth
    % building for a modest number of traces. Hover still works either way.
    if ~withTip, return; end

    try
        n   = numel(hLine.XData);
        tip = hLine.DataTipTemplate;
        tip.DataTipRows(1).Label = 'Time (ms)';
        tip.DataTipRows(2).Label = 'Amplitude (uV)';
        tip.DataTipRows(end+1)   = dataTipTextRow('Subject', repmat(string(subjName),1,n));
        tip.DataTipRows(end+1)   = dataTipTextRow('Condition', repmat(string(condLabel),1,n));
    catch
        % DataTipTemplate needs R2019a; the hover readout still works.
    end
end

% Small floating label that follows the cursor and names the trace under it.
function makeHoverLabel(hFig)
    lbl = uicontrol(hFig, 'Style','text', 'Units','pixels', ...
                    'BackgroundColor',[1 1 0.85], 'ForegroundColor',[0 0 0], ...
                    'FontName','Arial', 'FontSize', 9, ...
                    'HorizontalAlignment','left', 'Visible','off');
    setappdata(hFig, 'hoverLabel', lbl);
    set(hFig, 'WindowButtonMotionFcn', @(src,~) hoverFcn(src));
end

function hoverFcn(hFig)
    lbl = getappdata(hFig, 'hoverLabel');
    if isempty(lbl) || ~isvalid(lbl), return; end

    obj = hittest(hFig);
    if ~isempty(obj) && isprop(obj,'Tag') && strcmp(obj.Tag,'indivTrace') ...
            && isstruct(obj.UserData) && isfield(obj.UserData,'subject')
        str = sprintf(' %s  |  %s ', obj.UserData.subject, obj.UserData.cond);
        oldU = hFig.Units; hFig.Units = 'pixels';
        p = hFig.CurrentPoint; hFig.Units = oldU;
        w = 7.2*numel(str) + 10;
        set(lbl, 'String', str, 'Position', [p(1)+14, p(2)+14, w, 18], ...
                 'Visible','on');
        uistack(lbl,'top');
    else
        set(lbl, 'Visible','off');
    end
end

% Strip the trailing _condN from an EEGDataAvg field name for display.
function s = cleanSubjectName(raw)
    s = regexprep(char(raw), '_[cC]ond\d+$', '');
end

% Baseline each subject before averaging, then take the SEM across
% subjects. Keep identical to the copies in S241 and S242.
function tr = prepareTraces(dataCond, rowIdx, baselineIdx)
    nSubj = size(dataCond,1);
    sub   = dataCond(:, rowIdx, :);
    if numel(rowIdx) > 1
        sub = mean(sub, 2);
    end
    sub = reshape(sub, nSubj, []);
 
    base  = mean(sub(:, baselineIdx), 2);
    indiv = sub - base;
 
    tr.indiv = indiv;
    tr.mean  = mean(indiv, 1);
    tr.n     = nSubj;
    if nSubj > 1
        tr.sem = std(indiv, 0, 1) / sqrt(nSubj);
    else
        tr.sem = zeros(1, size(indiv,2));
    end
end
 
function v = getOpt(s, f, dflt)
    if isfield(s, f) && ~isempty(s.(f))
        v = s.(f);
    else
        v = dflt;
    end
end
