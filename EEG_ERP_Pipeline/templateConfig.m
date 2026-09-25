% Default constructor of a configuration (a run for the figure)

function cfg = templateConfig()

    % Parameters
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
    cfg.indivLineWidth  = 0.6;        % thin subject-level traces
    cfg.indivLineAlpha  = 0.20;       % transparency of subject-level traces
    cfg.meanLineWidth   = 4.0;        % group-average trace in ROI/single plots
    cfg.multiMeanLineWidth = 2.5;     % group-average trace in channel grids

    % Time axis:
    %   false → full trial (context + target)
    %   true  → target waveform only (zoom-in)
    cfg.plotCloseUp     = false;

    % Response axis
    cfg.yAxisFlip       = false;
    cfg.yLim            = [];         % optional expert override for both scales
    cfg.individualYLim  = [-10 10];   % fixed scale when individual traces are shown
    cfg.groupYLim       = [-5 5];     % fixed scale for group mean and SEM

    % Plot mode: 'roiAverage' | 'singleChannel' | 'multiChannel'
    cfg.plotMode        = '';

    % Default ROI: bilateral frontal as a starting point
    cfg.roiNames        = [];

    % For potential single-channel mode
    cfg.selectedChannel = '';

    % Channel set for multiChannel mode:
    %   'koelsch20' | 'all64' | 'custom'
    % For 'custom', channelList takes labels ("Fz","F3") or row numbers.
    % Leave channelList empty and S230 prints the lookup table and prompts.
    cfg.channelMode     = 'koelsch20';
    cfg.channelList     = [];

    % Acquisition parameters used to build the millisecond time axis in S220.
    % These are not stored in the P8 output files, so they live here.
    cfg.srate           = 1024;       % Hz, after the P1 resample
    cfg.epochStart_ms   = -100;       % P1 epoch window start
    cfg.chordSOA_ms     = 500;        % quarter note at 120 BPM
end
