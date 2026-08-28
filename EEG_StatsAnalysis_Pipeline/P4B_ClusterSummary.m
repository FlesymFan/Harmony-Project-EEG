function tbl = P4B_ClusterSummary(cfg, clusters)
% REQUIRED  clusters, the cell array of results from P3B_ClusterPermutation.
% EFFECT    Flattens every cluster from every contrast into one table and
%           prints it, marking those below cfg.alpha.
% MODIFY    cfg.alpha changes which rows are starred.
%
% Empty rows mean no cluster passed the forming threshold, which is a
% different statement from "no effect": widen cfg.clusterWin_ms or lower
% cfg.clusterAlpha before concluding anything from an empty table.

    rows = {};
    for i = 1:numel(clusters)
        C = clusters{i};
        for j = 1:numel(C.clusters)
            cl = C.clusters(j);
            if numel(cl.channels) > 4
                chStr = sprintf('%d channels', numel(cl.channels));
            else
                chStr = strjoin(cellstr(cl.channels), ' ');
            end
            rows(end+1,:) = { C.contrast, C.filtering, C.domain, ...
                              ternary(cl.mass < 0, 'neg', 'pos'), ...
                              cl.mass, cl.p, cl.tStart_ms, cl.tEnd_ms, ...
                              cl.peak_t, cl.peak_ms, chStr }; %#ok<AGROW>
        end
    end

    if isempty(rows)
        fprintf('\nNo clusters passed the forming threshold in any contrast.\n');
        tbl = table();
        return;
    end

    tbl = cell2table(rows, 'VariableNames', ...
        {'Contrast','Filtering','Domain','Sign','Mass','p', ...
         'Start_ms','End_ms','Peak_t','Peak_ms','Channels'});

    [~, ord] = sort(cell2mat(rows(:,6)));      % by p
    tbl = tbl(ord,:);

    fprintf('\n--- Cluster summary (times relative to target chord onset) ---\n');
    fprintf('%-8s %-11s %-5s %9s %8s %9s %8s %9s\n', ...
            'contrast','filtering','sign','mass','p','start ms','end ms','peak ms');
    for i = 1:height(tbl)
        star = '';
        if tbl.p(i) < cfg.alpha, star = '  *'; end
        fprintf('%-8s %-11s %-5s %9.1f %8.4f %9.0f %8.0f %9.0f%s\n', ...
                tbl.Contrast{i}, tbl.Filtering{i}, tbl.Sign{i}, ...
                tbl.Mass(i), tbl.p(i), tbl.Start_ms(i), tbl.End_ms(i), ...
                tbl.Peak_ms(i), star);
    end
    fprintf('\n');
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end
