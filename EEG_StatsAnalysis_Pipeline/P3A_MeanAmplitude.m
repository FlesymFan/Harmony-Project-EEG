function [amp, longTbl] = P3A_MeanAmplitude(cfg, D)
% REQUIRED  D from P2_PrepareData.
% EFFECT    Collapses each subject's ROI waveform to one mean amplitude per
%           design cell, over cfg.eranWin_ms relative to the target onset.
% MODIFY    cfg.eranWin_ms to move the window; cfg.roiNames for electrodes.
%
% amp      struct of nSubj x nFilterCond matrices, one per trial category
% longTbl  Subject, Filtering, Expectancy, Priming, Amplitude
%          Atonal stays in amp but is excluded from longTbl: it has no
%          Expectancy or Priming level, so it needs its own one-way test.

    win  = D.targetOnset_ms + cfg.eranWin_ms;
    wIdx = find(D.t_ms >= win(1) & D.t_ms <= win(2));
    if isempty(wIdx)
        error('P3A_MeanAmplitude: window [%g %g] ms has no samples.', win(1), win(2));
    end

    fields = {'ExpwithSensPrim','ExpwithoutSensPrim', ...
              'UnexpwithSensPrim','UnexpwithoutSensPrim','Atonal', ...
              'Diff_withSP','Diff_noSP'};

    nCond = numel(D.cond);
    for f = 1:numel(fields)
        amp.(fields{f}) = zeros(D.nSubj, nCond);
    end

    for k = 1:nCond
        for f = 1:numel(fields)
            A = D.cond(k).data.(fields{f});          % subj x chan x time
            roi = mean(A(:, D.roiIdx, :), 2);        % subj x 1 x time
            roi = reshape(roi, D.nSubj, []);         % subj x time
            amp.(fields{f})(:,k) = mean(roi(:, wIdx), 2);
        end
    end

    fprintf('Mean amplitude window: %g to %g ms after target onset (%d samples)\n', ...
            cfg.eranWin_ms(1), cfg.eranWin_ms(2), numel(wIdx));

    %---------------------- Long table for the ANOVA --------------------
    cells = {  % field,                   Expectancy,   Priming
        'ExpwithSensPrim',      'Expected',   'withSP';
        'UnexpwithSensPrim',    'Unexpected', 'withSP';
        'ExpwithoutSensPrim',   'Expected',   'noSP';
        'UnexpwithoutSensPrim', 'Unexpected', 'noSP'};

    Subject = {}; Filtering = {}; Expectancy = {}; Priming = {}; Amplitude = [];
    for k = 1:nCond
        for c = 1:size(cells,1)
            v = amp.(cells{c,1})(:,k);
            Subject    = [Subject;    regexprep(D.subjects, '_[cC]ond\d+$', '')]; %#ok<AGROW>
            Filtering  = [Filtering;  repmat({D.cond(k).label}, D.nSubj, 1)];     %#ok<AGROW>
            Expectancy = [Expectancy; repmat(cells(c,2),        D.nSubj, 1)];     %#ok<AGROW>
            Priming    = [Priming;    repmat(cells(c,3),        D.nSubj, 1)];     %#ok<AGROW>
            Amplitude  = [Amplitude;  v];                                         %#ok<AGROW>
        end
    end

    longTbl = table(categorical(Subject), categorical(Filtering), ...
                    categorical(Expectancy), categorical(Priming), Amplitude, ...
                    'VariableNames', {'Subject','Filtering','Expectancy','Priming','Amplitude'});
end
