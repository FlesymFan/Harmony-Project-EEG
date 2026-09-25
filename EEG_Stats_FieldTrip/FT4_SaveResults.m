function results = FT4_SaveResults(cfg, results)
% Save FieldTrip output and adjust across the selected test family.

p = [results.testP];
[sortedP, order] = sort(p);
adjusted = zeros(size(p));
running = 0;
m = numel(p);
for k = 1:m
    running = max(running, min(1, (m-k+1) * sortedP(k)));
    adjusted(order(k)) = running;
end
for k = 1:m
    results(k).familyP = adjusted(k);
end

if exist(cfg.outFolder, 'dir') ~= 7
    mkdir(cfg.outFolder);
end
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
runFolder = fullfile(cfg.outFolder, ['run_' stamp]);
if exist(runFolder, 'dir') == 7
    error('FT4: result directory already exists: %s', runFolder);
end
mkdir(runFolder);
toolboxVersion = ft_version;
save(fullfile(runFolder, 'fieldtrip_cluster_results.mat'), ...
     'results', 'cfg', 'toolboxVersion', '-v7.3');

fid = fopen(fullfile(runFolder, 'summary.txt'), 'w');
if fid < 0
    error('FT4: cannot create summary.txt in %s.', runFolder);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'FieldTrip version: %s\n', char(toolboxVersion));
fprintf(fid, 'Data folder: %s\n', cfg.dataFolder);
fprintf(fid, 'Selected subjects: %s\n', mat2str(cfg.subjectIDs));
fprintf(fid, 'Conditions: %s\n', mat2str(cfg.conditionNumbers));
fprintf(fid, 'Contrasts: %s\n', strjoin(cfg.contrasts(:, 1), ', '));
fprintf(fid, 'ROI: %s\n', strjoin(cfg.roiNames, ', '));
fprintf(fid, 'Sample rate: %.3f Hz; epoch start: %.3f ms\n', ...
        cfg.sampleRate, cfg.epochStart_ms);
fprintf(fid, 'Target onset: %.3f ms after trial trigger\n', cfg.targetOnset_ms);
fprintf(fid, 'Baseline: %.3f to %.3f ms relative to target\n', cfg.baselineWin_ms);
fprintf(fid, 'Scan: %.3f to %.3f ms relative to target; permutations: %d\n', ...
        cfg.scanWin_ms, cfg.nPermutations);
fprintf(fid, 'Random seed: %d\n', cfg.randomSeed);
fprintf(fid, 'FieldTrip cluster p is two-sided; family p uses Holm across %d tests.\n\n', m);
for k = 1:m
    fprintf(fid, 'Condition %d, %s: cluster p = %.4f, family p = %.4f\n', ...
            results(k).conditionNumber, results(k).contrast, ...
            results(k).testP, results(k).familyP);
    fprintf('Condition %d, %s: family p = %.4f\n', ...
            results(k).conditionNumber, results(k).contrast, results(k).familyP);
end
fprintf('FieldTrip results saved to %s\n', runFolder);
end
