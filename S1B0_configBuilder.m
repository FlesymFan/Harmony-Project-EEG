function cfg = S1B0_configBuilder()

    fprintf('-----------------------------------------------------\n');
    fprintf(' 1.B.0. configBuilder.m  (interactive config builder)\n');
    fprintf('-----------------------------------------------------\n\n');

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
    % Priming / contrast pattern
    %--------------------------------------------------------------
    fprintf('\nPriming / contrast type (which conditions to toggle):\n');
    fprintf('  1 = SP group          (Exp_withSP + Unexp_withSP + Atonal)\n');
    fprintf('  2 = noSP group        (Exp_noSP + Unexp_noSP + Atonal)\n');
    fprintf('  3 = Diff with SP      (Diff_withSP only)\n');
    fprintf('  4 = Diff without SP   (Diff_noSP only)\n');
    fprintf('  5 = Atonal only       (Atonal only)\n');

    while true
        s = strtrim(input('Choose 1–5 [default 1]: ', 's'));
        if isempty(s)
            modeChoice = 1;
            break;
        end
        modeChoice = str2double(s);
        if ismember(modeChoice, 1:5)
            break;
        else
            fprintf('Please enter a number between 1 and 5.\n');
        end
    end

    % Reset all toggles first
    cfg.Exp_noSP      = false;
    cfg.Unexp_noSP    = false;
    cfg.Diff_noSP     = false;
    cfg.Exp_withSP    = false;
    cfg.Unexp_withSP  = false;
    cfg.Diff_withSP   = false;
    cfg.Atonal        = false;

    switch modeChoice
        case 1  % SP group
            cfg.Exp_withSP   = true;
            cfg.Unexp_withSP = true;
            cfg.Atonal       = true;

        case 2  % noSP group
            cfg.Exp_noSP     = true;
            cfg.Unexp_noSP   = true;
            cfg.Atonal       = true;

        case 3  % Diff with SP
            cfg.Diff_withSP  = true;

        case 4  % Diff without SP
            cfg.Diff_noSP    = true;

        case 5  % Atonal only
            cfg.Atonal       = true;
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
    end
end