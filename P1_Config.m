function cfg = P1_Config()
% REQUIRED  Nothing.
% EFFECT    Returns every setting the stats pipeline reads.
% MODIFY    This is the only file you should need to edit for a normal run.

    %===================== Data ==========================================
    % REQUIRED  EEGDataAvgAcrossTrials_allSubject_cond*.mat on the path.
    % EFFECT    Which filtering conditions enter the design.
    % MODIFY    Drop entries to analyse a subset.
    cfg.conditionNumbers = [1 4 5];        % 1 Broadband, 4 Low-High, 5 High-Low
    cfg.dataPattern      = 'EEGDataAvgAcrossTrials_allSubject_cond%d.mat';

    %===================== Time axis =====================================
    % REQUIRED  Must match what P1 of the preprocessing pipeline produced.
    % EFFECT    Places the target chord at 6 * chordSOA_ms = 3000 ms.
    % MODIFY    chordSOA_ms only if the stimulus rate differs for this cohort.
    cfg.srate            = 1024;
    cfg.epochStart_ms    = -100;
    cfg.chordSOA_ms      = 500;

    %===================== Baseline ======================================
    % REQUIRED  A window inside the epoch, relative to the target onset.
    % EFFECT    Subtracted per subject before any statistic is computed.
    % MODIFY    [-200 0] for a longer baseline.
    cfg.baselineWin_ms   = [-100 0];

    %===================== ROI ===========================================
    % REQUIRED  Channel labels present in the 64-channel BioSemi montage.
    % EFFECT    Averaged before the amplitude and ROI cluster tests.
    % MODIFY    Decide once. Changing it after seeing results invalidates the p.
    cfg.roiNames         = ["Fz","F3","F4","FCz","FC3","FC4"];

    %===================== Branch A: parametric ==========================
    % REQUIRED  A window chosen before looking at results.
    % EFFECT    Each subject collapses to one mean amplitude per design cell.
    % MODIFY    eranWin_ms to test a different latency range.
    cfg.eranWin_ms       = [150 250];
    cfg.alpha            = 0.05;

    %===================== Branch B: nonparametric =======================
    % REQUIRED  A search window; no latency commitment needed.
    % EFFECT    Controls sensitivity and runtime of the permutation test.
    % MODIFY    clusterDomain 'scalp' to cluster over channels too (slower).
    cfg.clusterDomain    = 'roi';          % 'roi' | 'scalp'
    cfg.clusterWin_ms    = [0 600];
    cfg.clusterAlpha     = 0.05;           % cluster-forming threshold
    cfg.clusterTail      = 0;              % 0 two-tailed, -1 neg, +1 pos
    cfg.nPermutations    = 5000;
    cfg.minClusterLength = 2;              % samples
    cfg.neighbourDist    = 0.13;           % scalp adjacency radius, .loc units
    cfg.randomSeed       = 42;             % [] for a non-reproducible run

    %===================== Contrasts =====================================
    % REQUIRED  Field names present in the P8 output.
    % EFFECT    Each row becomes one difference wave, Unexpected minus Expected.
    % MODIFY    Add a row to test another pair.
    cfg.contrasts = {
        'withSP', 'UnexpwithSensPrim',    'ExpwithSensPrim';
        'noSP',   'UnexpwithoutSensPrim', 'ExpwithoutSensPrim'
    };

    %===================== Which branches to run =========================
    % REQUIRED  At least one true.
    % EFFECT    P0_Main runs branch B first, then branch A.
    % MODIFY    Set one false to run a single branch.
    cfg.runParametric    = true;
    cfg.runNonparametric = true;

    %===================== Output ========================================
    % REQUIRED  Write access to outDir.
    % EFFECT    Timestamped CSV and .mat written by P5_SaveResults.
    % MODIFY    saveTables false to keep results in the workspace only.
    cfg.outDir           = fullfile(pwd, 'stats_results');
    cfg.saveTables       = true;
end
