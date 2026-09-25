function timeInfo = S220_timeBaselineInfo(cfg, meta)
% Time axis and baseline window, in milliseconds relative to stimulus onset.
%
%   t = 0      onset of the first chord
%   t = -100   start of the pre-stimulus baseline
%   chords at  0, 500, 1000, 1500, 2000, 2500, 3000 ms
%   t = 3000   onset of the target (7th) chord
 
    %---------------------- Acquisition parameters ----------------------
    srate         = getOpt(cfg, 'srate',         1024);   % Hz, after P1 resample
    epochStart_ms = getOpt(cfg, 'epochStart_ms', -100);   % P1 epoch window start
    chordSOA_ms   = getOpt(cfg, 'chordSOA_ms',    500);   % quarter note at 120 BPM
 
    nPts = meta.numTimePoints;
    t_ms = (0:nPts-1) / srate * 1000 + epochStart_ms;     % -100 ... 4998.6
 
    %---------------------- Chord onsets --------------------------------
    expectOnset   = (0:5) * chordSOA_ms;                  % 0 500 ... 2500
    unexpectOnset = 6 * chordSOA_ms;                      % 3000
 
    %---------------------- Display window ------------------------------
    if isfield(cfg,'Start') && isfield(cfg,'End') && ...
       ~isempty(cfg.Start) && ~isempty(cfg.End)
        Start = cfg.Start;
        End   = cfg.End;
    elseif getOpt(cfg,'plotCloseUp',false)
        Start = unexpectOnset - 100;                      % 2900
        End   = unexpectOnset + 500;                      % 3500
    else
        Start = epochStart_ms;                            % -100
        End   = 4500;
    end
    Start = max(Start, t_ms(1));
    End   = min(End,   t_ms(end));
    inWin = (t_ms >= Start) & (t_ms <= End);
 
    if ~any(inWin)
        error('S220_timeBaselineInfo: window [%g %g] ms contains no samples.', Start, End);
    end
 
    %---------------------- Baseline window -----------------------------
    % Full trial: the 100 ms before stimulus onset.
    % Close-up:   the 100 ms before the target chord, so the target
    %             response is measured against its own pre-onset level.
    if getOpt(cfg,'plotCloseUp',false)
        bLo = unexpectOnset - 100;                        % 2900
        bHi = unexpectOnset;                              % 3000
    else
        bLo = epochStart_ms;                              % -100
        bHi = 0;
    end
 
    baselineIdx = find(t_ms >= bLo & t_ms < bHi);
    if isempty(baselineIdx)
        error('S220_timeBaselineInfo: baseline [%g %g] ms contains no samples.', bLo, bHi);
    end
 
    %---------------------- Pack ----------------------------------------
    timeInfo = struct();
    timeInfo.newTimeAxis           = t_ms;
    timeInfo.oldLen                = nPts;
    timeInfo.srate                 = srate;
    timeInfo.epochStart_ms         = epochStart_ms;
    timeInfo.chordSOA_ms           = chordSOA_ms;
 
    timeInfo.Start                 = Start;
    timeInfo.End                   = End;
    timeInfo.inWin                 = inWin;
 
    timeInfo.expectOnsetRemapped   = expectOnset;
    timeInfo.unexpectOnsetRemapped = unexpectOnset;
 
    timeInfo.baselineIdx_old       = baselineIdx;
    timeInfo.baselineWin_ms        = [bLo bHi];
end
 
function v = getOpt(s, f, dflt)
    if isfield(s, f) && ~isempty(s.(f))
        v = s.(f);
    else
        v = dflt;
    end
end