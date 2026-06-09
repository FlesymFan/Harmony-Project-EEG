% =========================================================================
% Layout of presets:
% 4 full-waveform figures (Broadband only, plotCloseUp = false)
%     * SP   (Exp vs. Unexp vs. Atonal), Left frontal
%     * SP   (Exp vs. Unexp vs. Atonal), Right frontal
%     * noSP (Exp vs. Unexp vs. Atonal), Left frontal
%     * noSP (Exp vs. Unexp vs. Atonal), Right frontal
%
% 27 target-waveform figures (plotCloseUp = true)
%     * 9 Diff (SP + noSP),       3 filters(1/4/5) × 3 ROIs (L/R/BL)
%     * 9 SP   (Exp + Unexp),     3 filters(1/4/5) × 3 ROIs (L/R/BL)
%     * 9 noSP (Exp + Unexp),     3 filters(1/4/5) × 3 ROIs (L/R/BL)
%
% Filter conditions used:
%   conditionNumber = 1  → Broadband
%   conditionNumber = 4  → Low High (LH)
%   conditionNumber = 5  → High Low (HL)
%
% ROIs:
%   Left frontal      : ["F7","F3","FT7","FC3"]
%   Right frontal     : ["F4","F8","FC4","FT8"]
%   Bilateral frontal : concatenation of left + right
% =========================================================================

function configs = S1A0_getPresetConfigs()
    %==================================================================
    % Base config (template)
    %==================================================================
    if exist('templateConfig', 'file') == 2
        base = templateConfig();
    else
        base = struct();
        base.name            = '';
        base.index           = 0;
        base.conditionNumber = 1;

        base.Exp_noSP        = false;
        base.Unexp_noSP      = false;
        base.Diff_noSP       = false;
        base.Exp_withSP      = false;
        base.Unexp_withSP    = false;
        base.Diff_withSP     = false;
        base.Atonal          = false;

        base.plotIndividual  = false;
        base.plotSE          = true;
        base.plotCloseUp     = false;
        base.yAxisFlip       = false;

        base.plotMode        = 'roiAverage';
        base.roiNames        = ["F7","F3","FT7","FC3"];
        base.selectedChannel = 'Fz';
    end

    % Ensure required fields exist (and ignore any extra ones)
    requiredFields = { ...
        'name','index','conditionNumber', ...
        'Exp_noSP','Unexp_noSP','Diff_noSP', ...
        'Exp_withSP','Unexp_withSP','Diff_withSP','Atonal', ...
        'plotIndividual','plotSE','plotCloseUp','yAxisFlip', ...
        'plotMode','roiNames','selectedChannel' ...
    };

    % Canonicalize base: only keep requiredFields, with defaults if missing
    canon = struct();
    for i = 1:numel(requiredFields)
        f = requiredFields{i};
        if isfield(base, f)
            canon.(f) = base.(f);
        else
            switch f
                case 'name'
                    canon.(f) = '';
                case 'index'
                    canon.(f) = 0;
                case 'conditionNumber'
                    canon.(f) = 1;
                case {'plotIndividual','plotSE','plotCloseUp','yAxisFlip', ...
                      'Exp_noSP','Unexp_noSP','Diff_noSP', ...
                      'Exp_withSP','Unexp_withSP','Diff_withSP','Atonal'}
                    canon.(f) = false;
                case 'plotMode'
                    canon.(f) = 'roiAverage';
                case 'roiNames'
                    canon.(f) = ["F7","F3","FT7","FC3"];
                case 'selectedChannel'
                    canon.(f) = 'Fz';
                otherwise
                    canon.(f) = [];
            end
        end
    end
    base = canon;  % from now on, everyone has exactly these fields

    %------------------------------------------------------------------
    % ROI definitions
    %------------------------------------------------------------------
    leftROI      = ["F7","F3","FT7","FC3"];
    rightROI     = ["F4","F8","FC4","FT8"];
    bilateralROI = [leftROI, rightROI];

    roiSets   = {bilateralROI, leftROI, rightROI};
    roiLabels = {'BilatFrontal','LeftFrontal','RightFrontal'};

    % Filter conditions: Broadband, Low High, High Low
    filterConds = [1, 4, 5];

    %==================================================================
    % Pre-allocate configs so all elements share same structure
    %==================================================================
    numFull      = 4;
    numPerGroup  = numel(filterConds) * numel(roiSets); % 3 * 3 = 9
    numGroups    = 3;                                    % Diff, SP, noSP
    totalConfigs = numFull + numGroups * numPerGroup;    % 4 + 3*9 = 31

    configs = repmat(base, totalConfigs, 1);  % all identical to start

    idx = 0;

    %==================================================================
    % 1) FULL-WAVEFORM PRESETS (4)        plotCloseUp = false
    %==================================================================
    fullCond = 1;

    % --- Full: SP, Left frontal ---
    idx = idx + 1;
    configs(idx).index           = idx;
    configs(idx).conditionNumber = fullCond;
    configs(idx).plotCloseUp     = false;
    configs(idx).plotMode        = 'roiAverage';
    configs(idx).roiNames        = leftROI;
    configs(idx).plotIndividual  = false;
    configs(idx).plotSE          = true;
    configs(idx).yAxisFlip       = false;

    configs(idx).Exp_noSP        = false;
    configs(idx).Unexp_noSP      = false;
    configs(idx).Diff_noSP       = false;
    configs(idx).Exp_withSP      = true;
    configs(idx).Unexp_withSP    = true;
    configs(idx).Diff_withSP     = false;
    configs(idx).Atonal          = true;

    configs(idx).name = 'Full_Broadband_SP_LeftFrontal';

    % --- Full: SP, Right frontal ---
    idx = idx + 1;
    configs(idx).index           = idx;
    configs(idx).conditionNumber = fullCond;
    configs(idx).plotCloseUp     = false;
    configs(idx).plotMode        = 'roiAverage';
    configs(idx).roiNames        = rightROI;
    configs(idx).plotIndividual  = false;
    configs(idx).plotSE          = true;
    configs(idx).yAxisFlip       = false;

    configs(idx).Exp_noSP        = false;
    configs(idx).Unexp_noSP      = false;
    configs(idx).Diff_noSP       = false;
    configs(idx).Exp_withSP      = true;
    configs(idx).Unexp_withSP    = true;
    configs(idx).Diff_withSP     = false;
    configs(idx).Atonal          = true;

    configs(idx).name = 'Full_Broadband_SP_RightFrontal';

    % --- Full: noSP, Left frontal ---
    idx = idx + 1;
    configs(idx).index           = idx;
    configs(idx).conditionNumber = fullCond;
    configs(idx).plotCloseUp     = false;
    configs(idx).plotMode        = 'roiAverage';
    configs(idx).roiNames        = leftROI;
    configs(idx).plotIndividual  = false;
    configs(idx).plotSE          = true;
    configs(idx).yAxisFlip       = false;

    configs(idx).Exp_noSP        = true;
    configs(idx).Unexp_noSP      = true;
    configs(idx).Diff_noSP       = false;
    configs(idx).Exp_withSP      = false;
    configs(idx).Unexp_withSP    = false;
    configs(idx).Diff_withSP     = false;
    configs(idx).Atonal          = true;

    configs(idx).name = 'Full_Broadband_noSP_LeftFrontal';

    % --- Full: noSP, Right frontal ---
    idx = idx + 1;
    configs(idx).index           = idx;
    configs(idx).conditionNumber = fullCond;
    configs(idx).plotCloseUp     = false;
    configs(idx).plotMode        = 'roiAverage';
    configs(idx).roiNames        = rightROI;
    configs(idx).plotIndividual  = false;
    configs(idx).plotSE          = true;
    configs(idx).yAxisFlip       = false;

    configs(idx).Exp_noSP        = true;
    configs(idx).Unexp_noSP      = true;
    configs(idx).Diff_noSP       = false;
    configs(idx).Exp_withSP      = false;
    configs(idx).Unexp_withSP    = false;
    configs(idx).Diff_withSP     = false;
    configs(idx).Atonal          = true;

    configs(idx).name = 'Full_Broadband_noSP_RightFrontal';

    %==================================================================
    % 2) TARGET-WAVEFORM PRESETS (27)     plotCloseUp = true
    %==================================================================

    % (a) Diff wave group (9)
    for f = 1:numel(filterConds)
        condNum = filterConds(f);
        for r = 1:numel(roiSets)
            idx = idx + 1;
            configs(idx).index           = idx;
            configs(idx).conditionNumber = condNum;
            configs(idx).plotCloseUp     = true;
            configs(idx).plotMode        = 'roiAverage';
            configs(idx).roiNames        = roiSets{r};
            configs(idx).plotIndividual  = false;
            configs(idx).plotSE          = true;
            configs(idx).yAxisFlip       = false;
            
            configs(idx).Exp_noSP        = false;
            configs(idx).Unexp_noSP      = false;
            configs(idx).Diff_noSP       = true;
            configs(idx).Exp_withSP      = false;
            configs(idx).Unexp_withSP    = false;
            configs(idx).Diff_withSP     = true;
            configs(idx).Atonal          = false;

            configs(idx).name = sprintf('Target_DiffSP_cond%d_%s', condNum, roiLabels{r});
        end
    end

    % (b) SP group (9) – Exp_withSP + Unexp_withSP
    for f = 1:numel(filterConds)
        condNum = filterConds(f);
        for r = 1:numel(roiSets)
            idx = idx + 1;
            configs(idx).index           = idx;
            configs(idx).conditionNumber = condNum;
            configs(idx).plotCloseUp     = true;
            configs(idx).plotMode        = 'roiAverage';
            configs(idx).roiNames        = roiSets{r};
            configs(idx).plotIndividual  = false;
            configs(idx).plotSE          = true;
            configs(idx).yAxisFlip       = false;

            configs(idx).Exp_noSP        = false;
            configs(idx).Unexp_noSP      = false;
            configs(idx).Diff_noSP       = false;
            configs(idx).Exp_withSP      = true;
            configs(idx).Unexp_withSP    = true;
            configs(idx).Diff_withSP     = false;
            configs(idx).Atonal          = false;

            configs(idx).name = sprintf('Target_SP_cond%d_%s', condNum, roiLabels{r});
        end
    end

    % (c) noSP group (9) – Exp_noSP + Unexp_noSP
    for f = 1:numel(filterConds)
        condNum = filterConds(f);
        for r = 1:numel(roiSets)
            idx = idx + 1;
            configs(idx).index           = idx;
            configs(idx).conditionNumber = condNum;
            configs(idx).plotCloseUp     = true;
            configs(idx).plotMode        = 'roiAverage';
            configs(idx).roiNames        = roiSets{r};
            configs(idx).plotIndividual  = false;
            configs(idx).plotSE          = true;
            configs(idx).yAxisFlip       = false;
            
            configs(idx).Exp_noSP        = true;
            configs(idx).Unexp_noSP      = true;
            configs(idx).Diff_noSP       = false;
            configs(idx).Exp_withSP      = false;
            configs(idx).Unexp_withSP    = false;
            configs(idx).Diff_withSP     = false;
            configs(idx).Atonal          = false;

            configs(idx).name = sprintf('Target_noSP_cond%d_%s', condNum, roiLabels{r});
        end
    end

    if idx ~= totalConfigs
        warning('S1A0_getPresetConfigs: expected %d configs, built %d.', ...
                totalConfigs, idx);
    end
end
