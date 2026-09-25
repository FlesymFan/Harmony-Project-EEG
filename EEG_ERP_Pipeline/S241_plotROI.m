function hFig = S241_plotROI(cfg, Extract_Data_Indiv, meta, timeInfo, ...
                        roiTitle, rowIdxSubset)

    % Shorthands to match your original variable names
 
    yAxisFlip = getOpt(cfg,'yAxisFlip',false);
    showSE    = getOpt(cfg,'plotSE',true);
    showIndiv = getOpt(cfg,'plotIndividual',false);
    plotCloseUp = getOpt(cfg,'plotCloseUp',false);
    yFixed    = getOpt(cfg,'yLim',[]);
    individualYLim = getOpt(cfg,'individualYLim',[-10 10]);
    groupYLim      = getOpt(cfg,'groupYLim',[-5 5]);
    indivLW   = getOpt(cfg,'indivLineWidth',0.6);
    indivAlpha = getOpt(cfg,'indivLineAlpha',0.20);
    meanLW     = getOpt(cfg,'meanLineWidth',4.0);
    highlightSubjects = getOpt(cfg,'highlightSubjects',[24 25 26 27 28]);

    %---------------------- Colors and condition labels -----------------
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
    useTips      = showIndiv && (meta.numSubjects * numel(condsToPlot)) <= 100;
 
    if isempty(condsToPlot)
        warning('S241_plotROI: no conditions toggled on; nothing to plot.');
        hFig = figure('Name','ROI Average - Empty','Color','w');
        text(0.5,0.5,'No conditions toggled on','HorizontalAlignment','center','FontSize',16);
        axis off;
        return;
    end
    if isempty(rowIdxSubset)
        error('S241_plotROI: rowIdxSubset is empty; no channels to average.');
    end
 
    %---------------------- Time info (milliseconds) --------------------
    t_ms  = timeInfo.newTimeAxis;
    inWin = timeInfo.inWin;
    x     = t_ms(inWin);
 
    splitPanels = showIndiv && showSE;
    if splitPanels
        panelIndiv  = [true false];
        panelSE     = [false true];
        panelTitles = {'Individual subject traces', 'Group mean with standard error'};
        hFig = figure('Name','ROI Average - Individual and SEM','Color','w','Visible','on');
        if plotCloseUp
            set(hFig,'Units','normalized','Position',[0.04 0.10 0.92 0.78]);
            layout = tiledlayout(hFig, 1, 2, 'TileSpacing','compact', 'Padding','compact');
        else
            layout = tiledlayout(hFig, 2, 1, 'TileSpacing','compact', 'Padding','compact');
        end
    else
        panelIndiv  = showIndiv;
        panelSE     = showSE;
        panelTitles = {''};
        hFig = figure('Name','ROI Average','Color','w','Visible','on');
        layout = [];
    end
    if showIndiv, makeHoverLabel(hFig); end

    nPanels = numel(panelIndiv);
    axAll   = gobjects(1,nPanels);

    for p = 1:nPanels
        if splitPanels
            ax = nexttile(layout);
        else
            ax = axes('Parent',hFig);
        end
        axAll(p) = ax;
        hold(ax,'on');

        for c = 1:numel(condsToPlot)
            cColor = colorsToPlot{c};
            tr = prepareTraces(Extract_Data_Indiv.(condsToPlot{c}), ...
                               rowIdxSubset, timeInfo.baselineIdx_old);

            if panelIndiv(p) && tr.n > 1
                for s = 1:tr.n
                    ys = tr.indiv(s, inWin);
                    hInd = plot(ax, x, ys, 'LineWidth', indivLW, ...
                                'Color', [cColor indivAlpha], 'HandleVisibility','off');
                    attachSubjectTip(hInd, cleanSubjectName(meta.subjectNames{s}), ...
                                     labelsToPlot{c}, useTips);
                end
            end

            y = tr.mean(inWin);
            if panelSE(p) && tr.n > 1
                ub = y + tr.sem(inWin);
                lb = y - tr.sem(inWin);
                fill(ax, [x fliplr(x)], [ub fliplr(lb)], cColor, ...
                     'FaceAlpha',0.3, 'EdgeColor','none', 'HandleVisibility','off', ...
                     'PickableParts','none');
            end

            plot(ax, x, y, 'LineWidth',meanLW, 'Color',cColor, ...
                 'DisplayName',labelsToPlot{c});
        end

        %------------------ Chord onsets and ticks ----------------------
        if cfg.plotCloseUp
            xline(ax, timeInfo.unexpectOnsetRemapped, '--', 'Color',[0 0 0], ...
                  'LineWidth',1.5, 'DisplayName','Onset of Target chord');
            pbaspect(ax,[1 1 1]);
            xlim(ax,[timeInfo.Start timeInfo.End]);
            xticks(ax,timeInfo.unexpectOnsetRemapped : 100 : timeInfo.End);
        else
            onsets = timeInfo.expectOnsetRemapped;
            xline(ax,onsets(1),'--','Color',[0.2 0.4 1],'LineWidth',1, ...
                  'DisplayName','Onset of Context chord');
            for i = 2:numel(onsets)
                xline(ax,onsets(i),'--','Color',[0.2 0.4 1],'LineWidth',1, ...
                      'HandleVisibility','off');
            end
            xline(ax,timeInfo.unexpectOnsetRemapped,'--','Color',[0 0 0], ...
                  'LineWidth',1.5,'DisplayName','Onset of Target chord');
            xlim(ax,[timeInfo.Start timeInfo.End]);
            xticks(ax,0 : 500 : timeInfo.End);
        end

        yline(ax,0,'--','Color',[0 0 0],'LineWidth',1,'HandleVisibility','off');
        xlabel(ax,'Time (ms)','FontSize',18);
        ylabel(ax,'Amplitude (\muV)','FontSize',18);
        set(ax,'LineWidth',1,'FontName','Arial','FontSize',20);
        lgd = legend(ax,'Location','northeast');
        lgd.Box = 'off';
        lgd.Color = 'none';
        lgd.FontSize = 20;
        if splitPanels
            title(ax,panelTitles{p},'FontSize',18);
        end
        hold(ax,'off');
    end

    if ~isempty(yFixed)
        set(axAll,'YLim',yFixed);
    elseif splitPanels && plotCloseUp
        set(axAll,'YLim',individualYLim);
    elseif splitPanels
        ylim(axAll(1),individualYLim);
        ylim(axAll(2),groupYLim);
    elseif showIndiv
        ylim(axAll(1),individualYLim);
    else
        ylim(axAll(1),groupYLim);
    end
    if yAxisFlip
        set(axAll,'YDir','reverse');
    end
    if splitPanels
        linkaxes(axAll,'x');
    end

    %---------------------- Figure title -------------------------------
    roiFullLabel = sprintf('%s (%s)', roiTitle, strjoin(cellstr(string(cfg.roiNames)), ', '));
    figureTitle = {roiFullLabel; ...
                   sprintf('%s (Condition %d)  |  n = %d', ...
                           meta.conditionNames(meta.conditionNumber), ...
                           meta.conditionNumber, meta.numSubjects)};
    if splitPanels
        title(layout,figureTitle,'FontSize',24);
    else
        title(axAll(1),figureTitle,'FontSize',26);
    end

    if showIndiv
        S244_cohortHighlight('install', hFig, highlightSubjects);
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
% subjects. Keep identical to the copies in S242 and S243.
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
