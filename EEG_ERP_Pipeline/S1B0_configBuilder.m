function cfg = S1B0_configBuilder()

    % Start from a template
    if exist('templateConfig', 'file') == 2
        cfg = templateConfig();
    else
        error('templateConfig.m not found on path.');
    end

    %--------------------------------------------------------------
    % Name for this configuration
    %--------------------------------------------------------------
    nameInput = strtrim(input('Enter a name for this configuration (blank = "custom_manual"): ', 's'));
    if isempty(nameInput)
        cfg.name = 'custom_manual';
    else
        cfg.name = nameInput;
    end

    % index is mostly for preset bookkeeping, so keep as 0 here
    cfg.index = 0;

    %--------------------------------------------------------------
    % Filter / condition number
    %--------------------------------------------------------------
    fprintf('\nFilter condition (conditionNumber):\n');
    fprintf('  1 = Broadband\n');
    fprintf('  4 = Low High (LH)\n');
    fprintf('  5 = High Low (HL)\n');

    while true
        s = strtrim(input('Choose 1, 4, or 5 [default 1]: ', 's'));
        if isempty(s)
            condNum = 1;
            break;
        end
        condNum = str2double(s);
        if ismember(condNum, [1 4 5])
            break;
        else
            fprintf('Please enter 1, 4, or 5.\n');
        end
    end
    cfg.conditionNumber = condNum;

    %--------------------------------------------------------------
    % Time axis: full trial vs target-only
    %--------------------------------------------------------------
    fprintf('\nTime axis:\n');
    fprintf('  1 = Full trial (context + target)\n');
    fprintf('  2 = Target-only (zoom-in)\n');

    s = strtrim(input('Choose 1 or 2 [default 2]: ', 's'));
    choice = str2double(s);
    if isnan(choice) || ~ismember(choice, [1 2])
        choice = 2;
    end

    if choice == 1
        cfg.plotCloseUp = false;   % full waveform
    else
        cfg.plotCloseUp = true;    % target waveform
    end

    %--------------------------------------------------------------
    % Condition display mode
    %--------------------------------------------------------------
    fprintf('\nPriming condition display mode:\n');
    fprintf('  1 = Single condition\n');
    fprintf('  2 = Comparison\n');

    while true
        s = strtrim(input('Choose 1 or 2 [default 2]: ', 's'));
        if isempty(s)
            displayMode = 2;
            break;
        end
        displayMode = str2double(s);
        if ismember(displayMode, [1 2])
            break;
        else
            fprintf('Please enter 1 or 2.\n');
        end
    end

    % Reset every condition before enabling the requested traces.
    cfg.Exp_noSP      = false;
    cfg.Unexp_noSP    = false;
    cfg.Diff_noSP     = false;
    cfg.Exp_withSP    = false;
    cfg.Unexp_withSP  = false;
    cfg.Diff_withSP   = false;
    cfg.Atonal        = false;

    if displayMode == 1
        fprintf('\nSingle condition:\n');
        fprintf('  1 = Expected with sensory priming\n');
        fprintf('  2 = Unexpected with sensory priming\n');
        fprintf('  3 = Expected without sensory priming\n');
        fprintf('  4 = Unexpected without sensory priming\n');
        fprintf('  5 = Difference with sensory priming\n');
        fprintf('  6 = Difference without sensory priming\n');
        fprintf('  7 = Atonal\n');

        while true
            s = strtrim(input('Choose 1-7 [default 1]: ', 's'));
            if isempty(s)
                conditionChoice = 1;
                break;
            end
            conditionChoice = str2double(s);
            if ismember(conditionChoice, 1:7)
                break;
            else
                fprintf('Please enter a number between 1 and 7.\n');
            end
        end

        switch conditionChoice
            case 1, cfg.Exp_withSP   = true;
            case 2, cfg.Unexp_withSP = true;
            case 3, cfg.Exp_noSP     = true;
            case 4, cfg.Unexp_noSP   = true;
            case 5, cfg.Diff_withSP  = true;
            case 6, cfg.Diff_noSP    = true;
            case 7, cfg.Atonal       = true;
        end
    else
        fprintf('\nComparison:\n');
        fprintf('  1 = SP group          (Exp_withSP + Unexp_withSP + Atonal)\n');
        fprintf('  2 = noSP group        (Exp_noSP + Unexp_noSP + Atonal)\n');
        fprintf('  3 = Diff with SP      (Diff_withSP only)\n');
        fprintf('  4 = Diff without SP   (Diff_noSP only)\n');
        fprintf('  5 = Atonal only       (Atonal only)\n');

        while true
            s = strtrim(input('Choose 1-5 [default 1]: ', 's'));
            if isempty(s)
                comparisonChoice = 1;
                break;
            end
            comparisonChoice = str2double(s);
            if ismember(comparisonChoice, 1:5)
                break;
            else
                fprintf('Please enter a number between 1 and 5.\n');
            end
        end

        switch comparisonChoice
            case 1
                cfg.Exp_withSP   = true;
                cfg.Unexp_withSP = true;
                cfg.Atonal       = true;
            case 2
                cfg.Exp_noSP     = true;
                cfg.Unexp_noSP   = true;
                cfg.Atonal       = true;
            case 3
                cfg.Diff_withSP  = true;
            case 4
                cfg.Diff_noSP    = true;
            case 5
                cfg.Atonal       = true;
        end
    end

    %--------------------------------------------------------------
    % ROI / plot mode
    %--------------------------------------------------------------
    fprintf('\nROI / plot mode:\n');
    fprintf('  1 = Left frontal      ["F7","F3","FT7","FC3"]\n');
    fprintf('  2 = Right frontal     ["F4","F8","FC4","FT8"]\n');
    fprintf('  3 = Bilateral frontal (Left + Right)\n');
    fprintf('  4 = Manual ROI list   (roiAverage)\n');
    fprintf('  5 = Single channel    (plotMode = "singleChannel")\n');
    fprintf('  6 = Multi channel     (plotMode = "multiChannel")\n');

    while true
        s = strtrim(input('Choose 1–6 [default 3]: ', 's'));
        if isempty(s)
            roiChoice = 3;  % default bilateral
            break;
        end
        roiChoice = str2double(s);
        if ismember(roiChoice, 1:6)
            break;
        else
            fprintf('Please enter a number between 1 and 6.\n');
        end
    end

    leftROI      = ["F7","F3","FT7","FC3"];
    rightROI     = ["F4","F8","FC4","FT8"];
    bilateralROI = [leftROI, rightROI];

    switch roiChoice
        case 1
            cfg.plotMode = 'roiAverage';
            cfg.roiNames = leftROI;

        case 2
            cfg.plotMode = 'roiAverage';
            cfg.roiNames = rightROI;

        case 3
            cfg.plotMode = 'roiAverage';
            cfg.roiNames = bilateralROI;

        case 4
            cfg.plotMode = 'roiAverage';
            roiStr = strtrim(input(['Enter ROI channel labels separated by spaces or commas ', ...
                                    '(e.g., F7 F3 FT7 FC3): '], 's'));
            if isempty(roiStr)
                cfg.roiNames = bilateralROI;
            else
                roiStr = strrep(roiStr, ',', ' ');
                parts = strsplit(roiStr);
                cfg.roiNames = string(parts(~cellfun(@isempty, parts)));
            end

        case 5
            cfg.plotMode = 'singleChannel';
            ch = strtrim(input('Enter channel label for singleChannel mode (e.g., "F3"): ', 's'));
            if isempty(ch)
                ch = 'F3';
            end
            cfg.selectedChannel = ch;
            cfg.roiNames        = string(ch);  % not really used, but harmless

        case 6
            cfg.plotMode = 'multiChannel';
            cfg.roiNames = [];
            cfg.selectedChannel = '';

            % Channel set for the grid.
            fprintf('\nChannel set:\n');
            fprintf('  1 = Koelsch 20  (F7..P8, 4x5 grid)\n');
            fprintf('  2 = All 64      (8x8 grid)\n');
            fprintf('  3 = Custom subset (a lookup table will be shown)\n');
            cs = str2double(strtrim(input('Choose 1-3 [default 1]: ', 's')));
            switch cs
                case 2
                    cfg.channelMode = 'all64';
                    cfg.channelList = [];
                case 3
                    cfg.channelMode = 'custom';
                    cfg.channelList = [];   % S230 prints the table and prompts
                otherwise
                    cfg.channelMode = 'koelsch20';
                    cfg.channelList = [];
            end
    end

    %--------------------------------------------------------------
    % Individual traces and standard error
    %--------------------------------------------------------------
    s = strtrim(input('\nOverlay individual subject traces? (y/n) [n]: ', 's'));
    cfg.plotIndividual = any(strcmpi(s, {'y','yes'}));

    s = strtrim(input('Show standard error shading? (y/n) [y]: ', 's'));
    cfg.plotSE = ~any(strcmpi(s, {'n','no'}));
end
