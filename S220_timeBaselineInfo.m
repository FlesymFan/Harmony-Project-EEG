function timeInfo = S220_timeBaselineInfo(cfg, meta)

    %----------------------- Lengths and remapping ----------------------
    oldLen = meta.numTimePoints;   % e.g., 5222
    newLen = 5000;                 % fixed target domain

    ratio  = oldLen / newLen;
    % newTimeAxis has oldLen points, spanning [1 .. newLen]
    newTimeAxis = linspace(1, newLen, oldLen);

    %----------------------- Time window [Start, End] -------------------
    % Allow optional override via cfg.Start / cfg.End; otherwise use
    % defaults based on plotCloseUp.
    if isfield(cfg, 'Start') && isfield(cfg, 'End') && ...
       ~isempty(cfg.Start)   && ~isempty(cfg.End)
        Start = cfg.Start;
        End   = cfg.End;
    else
        if cfg.plotCloseUp
            % Target waveform window (same as your example: 3000–4000)
            Start = 3000;
            End   = 4000;
        else
            % Full trial
            Start = 1;
            End   = newLen;
        end
    end

    inWin = (newTimeAxis >= Start) & (newTimeAxis <= End);

    %----------------------- Chord onset positions (remapped) ----------
    % These are defined in the remapped [1..newLen] domain,
    % matching your original script.
    expectOnsetRemapped   = [100, 600, 1100, 1600, 2100, 2600];
    unexpectOnsetRemapped = 3100;

    %----------------------- Baseline range (remapped) ------------------
    if cfg.plotCloseUp
        % If zoomed in, baseline is from pre-target segment
        baselineRange_remapped = 3000:unexpectOnsetRemapped;
    else
        % If full scale, use the first 100 ms
        baselineRange_remapped = 1:100;
    end

    % Map [baselineRange_remapped] from remapped domain back into
    % the original index space (1..oldLen).
    b1_old = max(1, floor((baselineRange_remapped(1) - 1) * ratio) + 1);
    b2_old = min(oldLen, ceil(baselineRange_remapped(end) * ratio));
    baselineIdx_old = b1_old:b2_old;

    %----------------------- Pack output struct -------------------------
    timeInfo = struct();
    timeInfo.oldLen                = oldLen;
    timeInfo.newLen                = newLen;
    timeInfo.ratio                 = ratio;
    timeInfo.newTimeAxis           = newTimeAxis;

    timeInfo.Start                 = Start;
    timeInfo.End                   = End;
    timeInfo.inWin                 = inWin;

    timeInfo.expectOnsetRemapped   = expectOnsetRemapped;
    timeInfo.unexpectOnsetRemapped = unexpectOnsetRemapped;

    timeInfo.baselineIdx_old       = baselineIdx_old;
end