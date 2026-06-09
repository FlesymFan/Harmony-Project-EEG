function hFig = S242_plotSingleChannel(cfg, Extract_Data_Indiv, meta, timeInfo, roiTitle, rowIdxSubset)
% Single-channel ERP plotting with baseline correction

    % Resolve channel label + index
    channelLabel = '';
    if isfield(cfg,'selectedChannel') && ~isempty(cfg.selectedChannel)
        channelLabel = string(cfg.selectedChannel);
    elseif isfield(cfg,'roiNames') && ~isempty(cfg.roiNames)
        channelLabel = string(cfg.roiNames(1));
    end

    if ~isempty(rowIdxSubset)
        rowIdx = rowIdxSubset(1);
    else
        [tf, loc] = ismember(channelLabel, meta.channels);
        if ~tf
            error('singleChannel: channel "%s" not found in meta.channels.', channelLabel);
        end
        rowIdx = meta.channel_indices(loc);
    end

    % Condition list (same as ROI)
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
        warning('S242_plotSingleChannel: no conditions toggled on; nothing to plot.');
        hFig = figure('Name','Single Channel - Empty','Color','w');
        text(0.5,0.5,'No conditions toggled on','HorizontalAlignment','center','FontSize',16);
        axis off;
        return;
    end

    % Time info
    Start = timeInfo.Start; End = timeInfo.End;
    numSubjects = meta.numSubjects;
    newTimeAxis = timeInfo.newTimeAxis;
    inWin = timeInfo.inWin;
    baselineIdx_old = timeInfo.baselineIdx_old;
    expectOnsetRemapped = timeInfo.expectOnsetRemapped;
    unexpectOnsetRemapped = timeInfo.unexpectOnsetRemapped;

    % Figure
    hFig = figure('Name','Single Channel','Color','w','Visible','on');
    hold on;

    for c = 1:numel(condsToPlot)
        condName = condsToPlot{c};
        cColor   = colorsToPlot{c};
        cLabel   = labelsToPlot{c};

        dataCond = Extract_Data_Indiv.(condName); % subj × ch × time
        chData   = squeeze(dataCond(:, rowIdx, :)); % subj × time (or time if 1 subj)

        if numSubjects == 1
            chData = reshape(chData, [1, numel(chData)]);
        end

        grandMean = mean(chData, 1);
        if numSubjects > 1
            sem = std(chData, 0, 1) / sqrt(numSubjects);
        else
            sem = zeros(size(grandMean));
        end

        % Baseline correction (SAME as ROI)
        baseline    = mean(grandMean(baselineIdx_old));
        waveBC_full = grandMean - baseline;

        ub_full = waveBC_full + sem;
        lb_full = waveBC_full - sem;

        x  = newTimeAxis(inWin);
        y  = waveBC_full(inWin);
        ub = ub_full(inWin);
        lb = lb_full(inWin);

        if cfg.plotSE
            plot(x, y, 'LineWidth', 3, 'Color', cColor, 'DisplayName', cLabel);
            fill([x, fliplr(x)], [ub, fliplr(lb)], cColor, ...
                 'FaceAlpha', 0.3, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        else
            plot(x, y, 'LineWidth', 3, 'Color', cColor, 'DisplayName', cLabel);
        end
    end

    % Onsets + ticks (match ROI formatting)
    if cfg.plotCloseUp
        xline(unexpectOnsetRemapped, '--', 'Color', [0 0 0], 'LineWidth', 1, ...
              'DisplayName', 'Onset of Target chord');
        pbaspect([1 1 1]);
        tickSize = 100;
        xlim([Start, 3600]);
        xticks(3100:tickSize:3600);
        xticklabels(string(3000:tickSize:3500));
    else
        xline(expectOnsetRemapped(1), '--', 'Color', [0.2 0.4 1], 'LineWidth', 1, ...
              'DisplayName', 'Onset of Context chord');
        for i = 2:numel(expectOnsetRemapped)
            xline(expectOnsetRemapped(i), '--', 'Color', [0.2 0.4 1], ...
                  'LineWidth', 1, 'HandleVisibility', 'off');
        end
        xline(unexpectOnsetRemapped, '--', 'Color', [0 0 0], 'LineWidth', 1.5, ...
              'DisplayName', 'Onset of Target chord');

        tickSize = 500;
        xlim([Start, 4600]);
        xticks(600:tickSize:4600);
        xticklabels(string(500:tickSize:4500));
    end

    yline(0, '--', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
    hold off;

    % Titles/labels
    if strlength(channelLabel) == 0
        channelLabel = "Unknown";
    end

    title({sprintf('Single Channel: %s (%s)', channelLabel, roiTitle); ...
           [meta.conditionNames(meta.conditionNumber), ...
            ' (Condition ', num2str(meta.conditionNumber), ')']}, ...
           'FontSize', 30);

    lgd = legend('Location','northeast');
    lgd.Box = 'on'; lgd.EdgeColor = 'white'; lgd.Color = [1 1 1]; lgd.FontSize = 26;

    xlabel('Time (ms)', 'FontSize', 16);
    ylabel('Amplitude (µV)', 'FontSize', 16);
    set(gca, 'LineWidth', 1);
    set(gca, 'FontName', 'Arial', 'FontSize', 26);

    ylim([-5, 10]);
    if cfg.yAxisFlip
        set(gca,'YDir','reverse');
    end
end

