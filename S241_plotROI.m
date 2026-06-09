function hFig = S241_plotROI(cfg, Extract_Data_Indiv, meta, timeInfo, ...
                        roiTitle, rowIdxSubset)

    % Shorthands to match your original variable names
    roiNames        = cfg.roiNames;
    yAxisFlip       = cfg.yAxisFlip;
    conditionNames  = meta.conditionNames;
    conditionNumber = meta.conditionNumber;

    Start = timeInfo.Start;
    End   = timeInfo.End;

    %---------------------- Colors and condition labels -----------------
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

    for k = 1:size(condInfo, 1)
        cName   = condInfo{k,1};
        cToggle = condInfo{k,2};
        cColor  = condInfo{k,3};
        cLabel  = condInfo{k,4};

        if cToggle
            condsToPlot{end+1}  = cName;   %#ok<AGROW>
            colorsToPlot{end+1} = cColor;  %#ok<AGROW>
            labelsToPlot{end+1} = cLabel;  %#ok<AGROW>
        end
    end

    if isempty(condsToPlot)
        warning('S241_plotROI: no conditions toggled on; nothing to plot.');
        hFig = figure('Name','ROI Average - Empty', ...
                      'Color','w', 'Visible','on');
        text(0.5, 0.5, 'No conditions toggled on', ...
             'HorizontalAlignment','center', 'FontSize', 16);
        axis off;
        return;
    end

    %---------------------- Meta / time info ----------------------------
    numSubjects = meta.numSubjects;

    oldLen      = timeInfo.oldLen;
    newTimeAxis = timeInfo.newTimeAxis;           % length = oldLen
    inWin       = timeInfo.inWin;                 % same length as oldLen

    expectOnsetRemapped   = timeInfo.expectOnsetRemapped;
    unexpectOnsetRemapped = timeInfo.unexpectOnsetRemapped;

    baselineIdx_old       = timeInfo.baselineIdx_old;

    %---------------------- Figure setup --------------------------------
    hFig = figure('Name','ROI Average', ...
                  'Color','w', ...
                  'Visible','on');   % invisible, will be saved+closed
    hold on;

    %---------------------- Loop over conditions ------------------------
    for c = 1:numel(condsToPlot)
        condName = condsToPlot{c};
        cColor   = colorsToPlot{c};
        cLabel   = labelsToPlot{c};

        dataCond = Extract_Data_Indiv.(condName);          % subj × ch × time
        roiData  = dataCond(:, rowIdxSubset, :);           % subj × roiCh × time
        roiMeanPerSubject = squeeze(mean(roiData, 2));     % subj × time

        if numSubjects > 1
            roiGrandMean = mean(roiMeanPerSubject, 1);              % 1 × time
            roiSEM       = std(roiMeanPerSubject, 0, 1) / sqrt(numSubjects);
        else
            roiGrandMean = roiMeanPerSubject;
            roiSEM       = zeros(size(roiGrandMean));
        end

        baseline    = mean(roiGrandMean(baselineIdx_old));
        waveBC_full = roiGrandMean - baseline;

        ub_full = waveBC_full + roiSEM;
        lb_full = waveBC_full - roiSEM;

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

    %---------------------- Chord onsets + ticks (EXACT FORMAT) --------
    if cfg.plotCloseUp
        % Only show unexpected chord
        xline(unexpectOnsetRemapped, '--', 'Color', [0 0 0], ...
              'LineWidth', 1, 'DisplayName', 'Onset of Target chord');
        
        % Adjust the display ratio to [1 1 1]
        pbaspect([1 1 1]);

        % Adjust the tickSize, tickLimits, and tickLabels
        tickSize = 100;
        xlim([Start, 3600]);
        xticks(3100:tickSize:3600);  % Location of the ticks (onset of chords)
        xticklabels(string(3000:tickSize:3500)); % label 600 as 500 for clarity

    else
        % Show all expected chords in blue
        xline(expectOnsetRemapped(1), '--', 'Color', [0.2 0.4 1], ...
              'LineWidth', 1, 'DisplayName', 'Onset of Context chord');
        
        for i = 2:numel(expectOnsetRemapped)
            xline(expectOnsetRemapped(i), '--', 'Color', [0.2 0.4 1], ...
                  'LineWidth', 1, 'HandleVisibility', 'off');
        end

        % Label the unexpected chord in black
        xline(unexpectOnsetRemapped, '--', 'Color', [0 0 0], ...
              'LineWidth', 1.5, 'DisplayName', 'Onset of Target chord');

        % Adjust the tickSize, tickLimits, and tickLabels
        tickSize = 500;
        xlim([Start, 4600]);
        xticks(600:tickSize:4600);  % Location of the ticks (onset of chords)
        xticklabels(string(500:tickSize:4500)); % label 600 as 500 for clarity
    end

    % Baseline line
    yline(0, '--', 'Color', [0, 0, 0], 'LineWidth', 1, 'HandleVisibility', 'off');
    hold off;

    %---------------------- Title, legend, labels (EXACT FORMAT) -------
    roiFullLabel = sprintf('%s (%s)', roiTitle, strjoin(roiNames, ', '));
    title({roiFullLabel; ...
           [conditionNames(conditionNumber), ...
            ' (Condition ', num2str(conditionNumber), ')']}, ...
           'FontSize', 30);

    % Legend
    lgd = legend('Location', 'northeast');
    lgd.Box = 'on';
    lgd.EdgeColor = 'white';      % Match to background color
    lgd.Color = [1 1 1];          % Force background white
    lgd.FontSize = 26;

    % Axis labels
    xlabel('Time (ms)', 'FontSize', 16); 
    ylabel('Amplitude (µV)', 'FontSize', 16);

    % Axis styling (tick labels etc.)
    set(gca, 'LineWidth', 1);  
    set(gca, 'FontName', 'Arial', 'FontSize', 26);

    % y-limits and flipping
    ylim([-5, 10]);
    if yAxisFlip
        set(gca, 'YDir', 'reverse');
    end
end