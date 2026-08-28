function P5_SaveResults(cfg, results)
% REQUIRED  cfg.saveTables true and write access to cfg.outDir.
% EFFECT    Writes timestamped CSVs for whichever branches ran, plus a .mat
%           holding everything including the permutation null distribution.
% MODIFY    cfg.outDir for the destination; cfg.saveTables false to skip.

    if ~cfg.saveTables
        return;
    end
    if ~exist(cfg.outDir, 'dir')
        mkdir(cfg.outDir);
    end

    stamp = datestr(now, 'yyyymmdd_HHMMSS'); %#ok<TNOW1,DATST>

    if isfield(results,'longTbl') && ~isempty(results.longTbl)
        writetable(results.longTbl, ...
                   fullfile(cfg.outDir, ['A_meanAmplitude_' stamp '.csv']));
    end

    if isfield(results,'parametric') && ~isempty(results.parametric)
        writetable(results.parametric.ttests, ...
                   fullfile(cfg.outDir, ['A_ttests_' stamp '.csv']));
        if ~isempty(results.parametric.anova)
            writetable(results.parametric.anova, ...
                       fullfile(cfg.outDir, ['A_anova_' stamp '.csv']), ...
                       'WriteRowNames', true);
        end
    end

    if isfield(results,'clusterTable') && ~isempty(results.clusterTable)
        writetable(results.clusterTable, ...
                   fullfile(cfg.outDir, ['B_clusters_' stamp '.csv']));
    end

    save(fullfile(cfg.outDir, ['statsResults_' stamp '.mat']), 'results');
    fprintf('Written to %s\n', cfg.outDir);
end
