function results = P0_Main(cfg)
% REQUIRED  P8 output files on the MATLAB path. No arguments needed.
% EFFECT    Runs the shared data prep, then branch B (nonparametric) and
%           branch A (parametric), and saves whatever ran.
% MODIFY    cfg.runParametric / cfg.runNonparametric to run one branch.
%
%   results = P0_Main();
%   cfg = P1_Config(); cfg.eranWin_ms = [100 300]; results = P0_Main(cfg);
%
% Steps
%   P1  config
%   P2  prepare data                       (shared)
%   P3B cluster permutation      branch B  (nonparametric)
%   P4B cluster summary          branch B
%   P3A mean amplitude           branch A  (parametric)
%   P4A rmANOVA and t-tests      branch A
%   P5  save                               (shared)
%
% Branch B runs first because it needs no latency window and so cannot be
% biased by one. Fix cfg.eranWin_ms before reading branch B output, or state
% in the write-up that the window came from the data.

    if nargin < 1 || isempty(cfg)
        cfg = P1_Config();
    end
    if ~cfg.runParametric && ~cfg.runNonparametric
        error('P0_Main: both branches are disabled in the config.');
    end

    fprintf('\n=====================================================\n');
    fprintf(' EEG statistics pipeline\n');
    fprintf('=====================================================\n\n');

    %===================== P2  shared prep ==============================
    D = P2_PrepareData(cfg);

    results = struct();
    results.cfg = cfg;
    results.D   = rmfield(D, 'cond');      % keep the summary, drop the arrays

    %===================== Branch B  nonparametric ======================
    if cfg.runNonparametric
        fprintf('=====================================================\n');
        fprintf(' Branch B: cluster-based permutation\n');
        fprintf('=====================================================\n\n');

        clusters = {};
        for c = 1:size(cfg.contrasts,1)
            for k = 1:numel(D.cond)
                clusters{end+1} = ...
                    P3B_ClusterPermutation(cfg, D, cfg.contrasts{c,1}, k); %#ok<AGROW>
            end
        end
        results.clusters     = clusters;
        results.clusterTable = P4B_ClusterSummary(cfg, clusters);
    end

    %===================== Branch A  parametric =========================
    if cfg.runParametric
        fprintf('=====================================================\n');
        fprintf(' Branch A: mean amplitude and rmANOVA\n');
        fprintf('=====================================================\n');

        [amp, longTbl]     = P3A_MeanAmplitude(cfg, D);
        results.amp        = amp;
        results.longTbl    = longTbl;
        results.parametric = P4A_RunANOVA(cfg, D, amp, longTbl);
    end

    %===================== P5  save =====================================
    P5_SaveResults(cfg, results);

    fprintf('\nDone.\n');
end
