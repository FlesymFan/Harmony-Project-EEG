function hFig = S243_plotMultiChannel(cfg, Extract_Data_Indiv, meta, timeInfo)
% Multi-channel ERP plotting with baseline correction
% Default behavior: plot all channels in meta.channels (20) as a grid.

    condInfo = {
        'Exp_noSP',      cfg.Exp_noSP,      [0.6, 0,   0.6], 'Expected w/o SP';
        'Unexp_noSP',    cfg.Unexp_noSP,    [0,   0.6, 0.3], 'Unexpected w/o SP';
        'Diff_noSP',     cfg.Diff_noSP,     [0.6, 0,   0.6], 'Unexp-Exp w/o. SP';
        'Exp_withSP',    cfg.Exp_withSP,    [0.6, 0.8, 1],   'Expected w SP';
        'Unexp_withSP',  cfg.Unexp_withSP,  [0.9, 0.6, 0.4], 'Unexpected w SP';
        'Diff_withSP',   cfg.Diff_withSP,   [0,   0.6, 0],   'Unexp-Exp w. SP';
        'Atonal',        cfg.Atonal,        [0.5, 0.5, 0.5], 'Atonal'
    };

    condsToPlot  = {};
    colorsToPlot = {};
    labelsToPlot = {};
    for k = 1:size(condInfo,1)
        if condInfo{k,2}
            condsToPlot{end+1}  = condInfo{k,1}; %#ok<AGROW>
            colorsToPlot{end+1} = condInfo{k,3}; %#ok<AGROW>
            labelsToPlot{end+1} = condInfo{k,4}; %#ok<AGROW>
        end
    end

    if isempty(condsToPlot)
        warning('S243_plotMultiChannel: no conditions toggled on; nothing to plot.');
        hFig = figure('Name','Multi Channel - Empty','Color','w');
        text(0.5,0.5,'No conditions toggled on','HorizontalAlignment','center','FontSize',16);
        axis off;
        return;
    end

    % Time info
    Start = timeInfo.Start;
    numSubjects = meta.numSubjects;
    newTimeAxis = timeInfo.newTimeAxis;
    inWin = timeInfo.inWin;
    baselineIdx_old = timeInfo.baselineIdx_old;
    expectOnsetRemapped = timeInfo.expectOnsetRemapped;
    unexpectOnsetRemapped = timeInfo.unexpectOnsetRemapped;

    % Channels to plot
    chLabels = meta.channels;
    chRowIdx = meta.channel_indices;

    nRowsPlot = 4;
    nColsPlot = 5;
    nChTarget = nRowsPlot * nColsPlot;
    nCh = min(numel(chLabels), nChTarget);

    % Figure (widen to accommodate legend column)
    hFig = figure('Name','Multi Channel','Color','w','Visible','on');
    try
        pos = get(hFig, 'Position');
        pos(3) = round(pos(3) * 1.35); % widen more so plots keep size
        set(hFig, 'Position', pos);
    catch
    end

    % Tiled layout: 4 rows × (5 plot cols + 1 legend col)
    nRows = nRowsPlot;
    nCols = nColsPlot + 1; % 6
    t = tiledlayout(nRows, nCols, 'TileSpacing','compact', 'Padding','compact');

    % Legend panel tile (row 1 col 6) spanning 4 rows
    legTileIndex = nCols; % tile #6 in first row
    axLeg = nexttile(t, legTileIndex, [nRows 1]);
    axis(axLeg, 'off');
    set(axLeg, 'HitTest', 'off'); % avoid accidental clicks

    % Capture deterministic legend handles from FIRST plotted tile only
    legLines  = gobjects(0);
    legLabels = {};

    for ch = 1:nCh
        row = ceil(ch / nColsPlot);
        col = mod(ch-1, nColsPlot) + 1;     % 1..5 (plot columns only)
        tileIdx = (row-1)*nCols + col;      % map into 6-column layout

        ax = nexttile(t, tileIdx);
        hold(ax, 'on');

        rowIdx  = chRowIdx(ch);
        chLabel = chLabels(ch);

        for c = 1:numel(condsToPlot)
            condName = condsToPlot{c};
            cColor   = colorsToPlot{c};
            cLabel   = labelsToPlot{c};

            dataCond = Extract_Data_Indiv.(condName);     % subj × ch × time
            chData   = squeeze(dataCond(:, rowIdx, :));   % subj × time

            if numSubjects == 1
                chData = reshape(chData, [1, numel(chData)]);
            end

            grandMean = mean(chData, 1);
            if numSubjects > 1
                sem = std(chData, 0, 1) / sqrt(numSubjects);
            else
                sem = zeros(size(grandMean));
            end

            % Baseline correction
            baseline    = mean(grandMean(baselineIdx_old));
            waveBC_full = grandMean - baseline;

            ub_full = waveBC_full + sem;
            lb_full = waveBC_full - sem;

            x  = newTimeAxis(inWin);
            y  = waveBC_full(inWin);
            ub = ub_full(inWin);
            lb = lb_full(inWin);

            if cfg.plotSE
                hLine = plot(ax, x, y, 'LineWidth', 1.5, 'Color', cColor);
                fill(ax, [x, fliplr(x)], [ub, fliplr(lb)], cColor, ...
                     'FaceAlpha', 0.2, 'EdgeColor', 'none', 'HandleVisibility', 'off');
            else
                hLine = plot(ax, x, y, 'LineWidth', 1.5, 'Color', cColor);
            end

            % Keep legend handles ONLY from the first channel
            if ch == 1
                hLine.DisplayName = cLabel;
                legLines(end+1)  = hLine;   %#ok<AGROW>
                legLabels{end+1} = cLabel;  %#ok<AGROW>
            else
                hLine.HandleVisibility = 'off';
            end
        end

        % Onsets (no legend)
        if cfg.plotCloseUp
            xline(ax, unexpectOnsetRemapped, '--', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility','off');
            xlim(ax, [Start, 3600]);
        else
            xline(ax, expectOnsetRemapped(1), '--', 'Color', [0.2 0.4 1], 'LineWidth', 1, 'HandleVisibility','off');
            for i = 2:numel(expectOnsetRemapped)
                xline(ax, expectOnsetRemapped(i), '--', 'Color', [0.2 0.4 1], 'LineWidth', 1, 'HandleVisibility','off');
            end
            xline(ax, unexpectOnsetRemapped, '--', 'Color', [0 0 0], 'LineWidth', 1.5, 'HandleVisibility','off');
            xlim(ax, [Start, 4600]);
        end

        yline(ax, 0, '--', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility','off');

        title(ax, string(chLabel), 'FontSize', 10);
        set(ax, 'FontName', 'Arial', 'FontSize', 9, 'LineWidth', 1);
        ylim(ax, [-5, 5]);

        if cfg.yAxisFlip
            set(ax, 'YDir', 'reverse');
        end

        % Reduce tick clutter
        if row < nRowsPlot
            set(ax, 'XTickLabel', []);
        end
        if col ~= 1
            set(ax, 'YTickLabel', []);
        end

        hold(ax, 'off');
    end

    % Global title
    sgtitle([meta.conditionNames(meta.conditionNumber), ' (Condition ', num2str(meta.conditionNumber), ')'], ...
            'FontSize', 18);

    % ---- Legend: place it inside the legend tile region (figure-normalized) ----
    if ~isempty(legLines)
        lgd = legend(legLines, legLabels);
        lgd.Box = 'on';
        lgd.FontName = 'Arial';
        lgd.FontSize = 8;
        lgd.Orientation = 'vertical';

        % Put legend in figure normalized units using axLeg position as reference
        lgd.Units = 'normalized';
        axLeg.Units = 'normalized';
        p = axLeg.Position;  % [x y w h] in figure normalized units

        % Padding inside the legend panel (tweak these if desired)
        padX = 0.05 * p(3);
        padY = 0.05 * p(4);

        % Place near the top-left inside the legend panel
        lgd.Position = [p(1) + padX, p(2) + p(4) - 0.30*p(4), 0.90*p(3), 0.25*p(4)];

        % Ensure legend draws on top of axes
        uistack(lgd, 'top');
    end
end