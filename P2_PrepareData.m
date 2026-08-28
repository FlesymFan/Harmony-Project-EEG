function D = P2_PrepareData(cfg)
% REQUIRED  cfg from P1_Config; the P8 output files on the MATLAB path.
% EFFECT    Loads every filtering condition, builds the millisecond axis,
%           baseline-corrects each subject against the pre-target window,
%           and resolves the ROI to data-row indices.
% MODIFY    cfg.conditionNumbers, cfg.baselineWin_ms, cfg.roiNames.
%
% Returns D with fields t_ms, targetOnset_ms, subjects, nSubj, chanLabels,
% chanXY, roiIdx, and cond(k).data.<trialCategory> as nSubj x nChan x nPts.

    fields = {'ExpwithSensPrim','ExpwithoutSensPrim', ...
              'UnexpwithSensPrim','UnexpwithoutSensPrim','Atonal'};

    nCond = numel(cfg.conditionNumbers);
    D = struct();

    for k = 1:nCond
        cn   = cfg.conditionNumbers(k);
        fn   = sprintf(cfg.dataPattern, cn);
        if exist(fn, 'file') ~= 2
            error('P2_PrepareData: cannot find %s on the path.', fn);
        end
        S = load(fn, 'EEGDataAvg');
        EEGDataAvg = S.EEGDataAvg;
        fprintf('Loaded %s\n', fn);

        subjNames = fieldnames(EEGDataAvg);
        nSubj     = numel(subjNames);
        ex        = EEGDataAvg.(subjNames{1}).(fields{1});
        nChan     = size(ex,1);
        nPts      = size(ex,2);

        % --- axis and baseline, built once from the first file ---
        if k == 1
            t_ms   = (0:nPts-1)/cfg.srate*1000 + cfg.epochStart_ms;
            target = 6 * cfg.chordSOA_ms;
            bLo    = target + cfg.baselineWin_ms(1);
            bHi    = target + cfg.baselineWin_ms(2);
            bIdx   = find(t_ms >= bLo & t_ms < bHi);
            if isempty(bIdx)
                error('P2_PrepareData: baseline [%g %g] ms has no samples.', bLo, bHi);
            end
            D.t_ms           = t_ms;
            D.targetOnset_ms = target;
            D.baselineIdx    = bIdx;
            D.baselineWin_ms = [bLo bHi];
            D.subjects       = subjNames;
            D.nSubj          = nSubj;
            D.nChan          = nChan;
            D.nPts           = nPts;
        else
            % Subject order and array size must match across conditions,
            % otherwise the repeated-measures design is misaligned.
            if nSubj ~= D.nSubj || nPts ~= D.nPts || nChan ~= D.nChan
                error(['P2_PrepareData: cond%d has %d subjects / %d chan / %d pts, ' ...
                       'but cond%d had %d / %d / %d.'], cn, nSubj, nChan, nPts, ...
                       cfg.conditionNumbers(1), D.nSubj, D.nChan, D.nPts);
            end
            if ~isequal(stripCond(subjNames), stripCond(D.subjects))
                error('P2_PrepareData: subject order differs between conditions.');
            end
        end

        % --- stack subjects, baseline-correct each one ---
        dat = struct();
        for f = 1:numel(fields)
            A = zeros(nSubj, nChan, nPts);
            for s = 1:nSubj
                w = EEGDataAvg.(subjNames{s}).(fields{f});     % nChan x nPts
                A(s,:,:) = w - mean(w(:, D.baselineIdx), 2);   % per-subject baseline
            end
            dat.(fields{f}) = A;
        end

        % --- derived difference waves ---
        dat.Diff_withSP = dat.UnexpwithSensPrim    - dat.ExpwithSensPrim;
        dat.Diff_noSP   = dat.UnexpwithoutSensPrim - dat.ExpwithoutSensPrim;

        D.cond(k).number = cn;
        D.cond(k).label  = condLabel(cn);
        D.cond(k).data   = dat;
    end

    %---------------------- Channels ------------------------------------
    [D.chanLabels, D.chanXY] = channelTable64();
    D.roiIdx = labelsToIdx(cfg.roiNames, D.chanLabels);

    fprintf('\n%d subjects, %d channels, %d samples, %d filtering conditions\n', ...
            D.nSubj, D.nChan, D.nPts, nCond);
    fprintf('target chord at %g ms; baseline [%g %g] ms (%d samples)\n', ...
            D.targetOnset_ms, D.baselineWin_ms(1), D.baselineWin_ms(2), numel(D.baselineIdx));
    fprintf('ROI: %s\n\n', strjoin(cellstr(cfg.roiNames), ', '));
end

% =====================================================================
function s = condLabel(cn)
    switch cn
        case 1, s = 'Broadband';
        case 4, s = 'LowHigh';
        case 5, s = 'HighLow';
        otherwise, s = sprintf('cond%d', cn);
    end
end

function out = stripCond(names)
    out = regexprep(names, '_[cC]ond\d+$', '');
end

function idx = labelsToIdx(names, labels)
    names = string(names); names = names(:)';
    idx   = zeros(1, numel(names));
    for k = 1:numel(names)
        hit = find(strcmpi(labels, names(k)), 1);
        if isempty(hit)
            error('P2_PrepareData: unknown channel "%s".', names(k));
        end
        idx(k) = hit;
    end
end

% Labels and approximate scalp coordinates, BioSemi A1-A32 / B1-B32 order,
% taken from BioSemi64.loc (its Afz / Poz casing normalised).
function [labels, xy] = channelTable64()
    labels = [ ...
        "Fp1", "AF7", "AF3", "F1",  "F3",  "F5",  "F7",  "FT7", ...
        "FC5", "FC3", "FC1", "C1",  "C3",  "C5",  "T7",  "TP7", ...
        "CP5", "CP3", "CP1", "P1",  "P3",  "P5",  "P7",  "P9",  ...
        "PO7", "PO3", "O1",  "Iz",  "Oz",  "POz", "Pz",  "CPz", ...
        "Fpz", "Fp2", "AF8", "AF4", "AFz", "Fz",  "F2",  "F4",  ...
        "F6",  "F8",  "FT8", "FC6", "FC4", "FC2", "FCz", "Cz",  ...
        "C2",  "C4",  "C6",  "T8",  "TP8", "CP6", "CP4", "CP2", ...
        "P2",  "P4",  "P6",  "P8",  "P10", "PO8", "PO4", "O2"];

    xy = [ ...
        -0.1342,  0.4131; -0.2553,  0.3514; -0.1477,  0.3167; -0.0884,  0.2189;
        -0.1783,  0.2202; -0.2673,  0.2324; -0.3514,  0.2553; -0.4131,  0.1342;
        -0.3174,  0.1218; -0.2085,  0.1108; -0.1068,  0.1068; -0.1086,  0.0000;
        -0.2172,  0.0000; -0.3258,  0.0000; -0.4344,  0.0000; -0.4131, -0.1342;
        -0.3174, -0.1218; -0.2085, -0.1108; -0.1068, -0.1068; -0.0884, -0.2189;
        -0.1783, -0.2202; -0.2673, -0.2324; -0.3514, -0.2553; -0.4341, -0.3643;
        -0.2553, -0.3514; -0.1477, -0.3167; -0.1342, -0.4131;  0.0000, -0.5667;
         0.0000, -0.4344;  0.0000, -0.3258;  0.0000, -0.2172;  0.0000, -0.1086;
         0.0000,  0.4344;  0.1342,  0.4131;  0.2553,  0.3514;  0.1477,  0.3167;
         0.0000,  0.3258;  0.0000,  0.2172;  0.0884,  0.2189;  0.1783,  0.2202;
         0.2673,  0.2324;  0.3514,  0.2553;  0.4131,  0.1342;  0.3174,  0.1218;
         0.2085,  0.1108;  0.1068,  0.1068;  0.0000,  0.1086;  0.0000,  0.0000;
         0.1086,  0.0000;  0.2172,  0.0000;  0.3258,  0.0000;  0.4344,  0.0000;
         0.4131, -0.1342;  0.3174, -0.1218;  0.2085, -0.1108;  0.1068, -0.1068;
         0.0884, -0.2189;  0.1783, -0.2202;  0.2673, -0.2324;  0.3514, -0.2553;
         0.4341, -0.3643;  0.2553, -0.3514;  0.1477, -0.3167;  0.1342, -0.4131];
end
