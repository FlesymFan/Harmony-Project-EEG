% Default constructor of a configuration (a run for the figure)

function cfg = templateConfig()

    % Identification / bookkeeping
    cfg.name            = '';     % filled by caller
    cfg.index           = 0;      % used mainly in preset loops

    % Filter / condition
    % 1 = Broadband, 4 = Low High, 5 = High Low
    cfg.conditionNumber = 0;

    % Condition toggles
    cfg.Exp_noSP        = false;
    cfg.Unexp_noSP      = false;
    cfg.Diff_noSP       = false;

    cfg.Exp_withSP      = false;
    cfg.Unexp_withSP    = false;
    cfg.Diff_withSP     = false;

    cfg.Atonal          = false;

    % Plotting behavior
    cfg.plotIndividual  = false;      % subject-level traces
    cfg.plotSE          = true;       % standard error shading

    % Time axis:
    %   false → full trial (context + target)
    %   true  → target waveform only (zoom-in)
    cfg.plotCloseUp     = false;

    % Response axis
    cfg.yAxisFlip       = false;

    % Plot mode: 'roiAverage' | 'singleChannel' | 'multiChannel'
    cfg.plotMode        = '';

    % Default ROI: bilateral frontal as a starting point
    cfg.roiNames        = [];

    % For potential single-channel mode
    cfg.selectedChannel = '';
end