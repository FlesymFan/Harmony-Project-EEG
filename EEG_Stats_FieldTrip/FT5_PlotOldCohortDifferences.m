function outputFiles = FT5_PlotOldCohortDifferences()
% Plot full-trial Unexpected - Expected ERPs for the three tested frontal ROIs.

scriptFolder = fileparts(mfilename('fullpath'));
dataFolder = fullfile(fileparts(scriptFolder), 'Data');
expectedCfg = FT1_Config(dataFolder);
resultRoot = fullfile(scriptFolder, 'fieldtrip_results');

roiSets = { ...
    'right_frontal', 'Right Frontal Electrodes', {'F4','F8','FC4','FT8'}; ...
    'left_frontal', 'Left Frontal Electrodes', {'F7','F3','FT7','FC3'}; ...
    'bilateral_frontal', 'Bilateral Frontal Electrodes', ...
        {'F7','F3','FT7','FC3','F4','F8','FC4','FT8'}};

labels = readChannelLabels(scriptFolder);
savedResults = cell(1, size(roiSets, 1));
roiIndices = cell(1, size(roiSets, 1));
for iRoi = 1:size(roiSets, 1)
    roiIndices{iRoi} = findChannelIndices(labels, roiSets{iRoi, 3});
    resultFile = newestResultFile(resultRoot, roiSets{iRoi, 1});
    saved = load(resultFile, 'results', 'cfg');
    validateSavedRun(saved, expectedCfg, roiSets{iRoi, 3}, resultFile);
    savedResults{iRoi} = saved.results;
end

% Build the same ROI differences and target-pre baselines as FT2, but keep
% the full epoch for display. Only FT3's 0-600 ms target window was tested.
panels = struct('roiTitle', {}, 'roiLabels', {}, 'conditionNumber', {}, ...
    'contrast', {}, 'timeMs', {}, 'meanWave', {}, 'semWave', {}, ...
    'testP', {}, 'familyP', {}, 'stat', {}, 'color', {});
nSubjects = numel(expectedCfg.subjectIDs);
for iCond = 1:numel(expectedCfg.conditionNumbers)
    conditionNumber = expectedCfg.conditionNumbers(iCond);
    source = fullfile(dataFolder, sprintf( ...
        'EEGDataAvgAcrossTrials_allSubject_cond%d.mat', conditionNumber));
    loaded = load(source, 'EEGDataAvg');
    for iContrast = 1:size(expectedCfg.contrasts, 1)
        contrast = expectedCfg.contrasts{iContrast, 1};
        expField = expectedCfg.contrasts{iContrast, 2};
        unexpField = expectedCfg.contrasts{iContrast, 3};
        for iRoi = 1:size(roiSets, 1)
            result = findTestResult(savedResults{iRoi}, conditionNumber, contrast);
            waves = [];
            for iSubject = 1:nSubjects
                subjectField = sprintf('Sub%d_cond%d', ...
                    expectedCfg.subjectIDs(iSubject), conditionNumber);
                subject = loaded.EEGDataAvg.(subjectField);
                expected = double(subject.(expField));
                unexpected = double(subject.(unexpField));
                if ~isequal(size(expected), size(unexpected)) || ...
                        size(expected, 1) ~= 64 || ...
                        ~all(isfinite(expected(:))) || ...
                        ~all(isfinite(unexpected(:)))
                    error('FT5: invalid averages in %s.', subjectField);
                end
                if isempty(waves)
                    nPoints = size(expected, 2);
                    timeMs = expectedCfg.epochStart_ms + ...
                        (0:nPoints-1) / expectedCfg.sampleRate * 1000;
                    baseline = timeMs >= expectedCfg.targetOnset_ms + expectedCfg.baselineWin_ms(1) & ...
                        timeMs < expectedCfg.targetOnset_ms + expectedCfg.baselineWin_ms(2);
                    if ~any(baseline)
                        error('FT5: target-pre baseline has no samples.');
                    end
                    waves = zeros(nSubjects, nPoints);
                elseif size(expected, 2) ~= nPoints
                    error('FT5: time length differs in %s.', subjectField);
                end
                difference = mean(unexpected(roiIndices{iRoi}, :), 1) - ...
                    mean(expected(roiIndices{iRoi}, :), 1);
                waves(iSubject, :) = difference - mean(difference(baseline));
            end

            verifyPlottedDifference(waves, timeMs, expectedCfg, result.stat);
            idx = numel(panels) + 1;
            panels(idx).roiTitle = roiSets{iRoi, 2};
            panels(idx).roiLabels = roiSets{iRoi, 3};
            panels(idx).conditionNumber = conditionNumber;
            panels(idx).contrast = contrast;
            panels(idx).timeMs = timeMs;
            panels(idx).meanWave = mean(waves, 1);
            panels(idx).semWave = std(waves, 0, 1) / sqrt(nSubjects);
            panels(idx).testP = result.testP;
            panels(idx).familyP = result.familyP;
            panels(idx).stat = result.stat;
            if strcmp(contrast, 'withSP')
                panels(idx).color = [0 0.6 0];
            else
                panels(idx).color = [0.85 0.3 0.1];
            end
        end
    end
end

% Use one amplitude scale for all 18 figures so they can be compared fairly.
maxAmplitude = 0;
for iPanel = 1:numel(panels)
    shown = panels(iPanel).timeMs >= -100 & panels(iPanel).timeMs <= 4500;
    maxAmplitude = max(maxAmplitude, max(abs( ...
        panels(iPanel).meanWave(shown)) + panels(iPanel).semWave(shown)));
end
yCap = max(5, 5 * ceil(maxAmplitude / 5));
outputFolder = fullfile(resultRoot, 'full_trial_differences', ...
    ['run_' char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'))]);
mkdir(outputFolder);
outputFiles = cell(numel(panels), 2);
for iPanel = 1:numel(panels)
    panel = panels(iPanel);
    name = sprintf('%02d_Cond%d_Diff_%s_%s_Old15', iPanel, ...
        panel.conditionNumber, panel.contrast, ...
        regexprep(panel.roiTitle, '[^A-Za-z]', ''));
    fig = drawPanel(panel, expectedCfg, [-yCap yCap], nSubjects);
    outputFiles{iPanel, 1} = fullfile(outputFolder, [name '.fig']);
    outputFiles{iPanel, 2} = fullfile(outputFolder, [name '.png']);
    savefig(fig, outputFiles{iPanel, 1});
    exportgraphics(fig, outputFiles{iPanel, 2}, 'Resolution', 180);
    close(fig);
end
fprintf('Saved %d full-trial difference plots (FIG and PNG) to %s\n', ...
    numel(panels), outputFolder);
end

function labels = readChannelLabels(scriptFolder)
locFile = fullfile(fileparts(scriptFolder), ...
    'EEG_Preprocessing_Pipeline', 'BioSemi64.loc');
fid = fopen(locFile, 'r');
if fid < 0
    error('FT5: cannot read %s.', locFile);
end
cleanup = onCleanup(@() fclose(fid));
columns = textscan(fid, '%f %f %f %s', ...
    'Delimiter', {' ', sprintf('\t')}, 'MultipleDelimsAsOne', true);
labels = columns{4};
if numel(labels) ~= 64 || ~isequal(columns{1}(:)', 1:64)
    error('FT5: BioSemi64.loc must contain numbered channels 1 through 64.');
end
end

function indices = findChannelIndices(labels, roiLabels)
indices = zeros(1, numel(roiLabels));
for i = 1:numel(roiLabels)
    hit = find(strcmpi(labels, roiLabels{i}), 1);
    if isempty(hit)
        error('FT5: ROI channel %s is not in BioSemi64.loc.', roiLabels{i});
    end
    indices(i) = hit;
end
end

function file = newestResultFile(resultRoot, roiFolder)
runs = dir(fullfile(resultRoot, roiFolder, 'run_*'));
runs = runs([runs.isdir]);
if isempty(runs)
    error('FT5: no saved FieldTrip run for %s.', roiFolder);
end
[~, order] = sort({runs.name});
latest = runs(order(end));
file = fullfile(latest.folder, latest.name, 'fieldtrip_cluster_results.mat');
if ~isfile(file)
    error('FT5: missing FieldTrip result file: %s', file);
end
end

function validateSavedRun(saved, expected, roiLabels, file)
if ~isfield(saved, 'cfg') || ~isfield(saved, 'results')
    error('FT5: %s lacks cfg or results.', file);
end
cfg = saved.cfg;
fields = {'subjectIDs','conditionNumbers','contrasts','sampleRate', ...
    'epochStart_ms','targetOnset_ms','baselineWin_ms','scanWin_ms'};
for i = 1:numel(fields)
    field = fields{i};
    if ~isfield(cfg, field) || ~isequal(cfg.(field), expected.(field))
        error('FT5: saved %s does not match current FT1 settings in %s.', field, file);
    end
end
if ~isequal(cfg.roiNames, roiLabels) || ...
        numel(saved.results) ~= numel(cfg.conditionNumbers) * size(cfg.contrasts, 1)
    error('FT5: ROI or test count does not match in %s.', file);
end
end

function result = findTestResult(results, conditionNumber, contrast)
hit = find([results.conditionNumber] == conditionNumber & ...
    strcmp({results.contrast}, contrast));
if numel(hit) ~= 1
    error('FT5: expected one saved result for condition %d, %s.', ...
        conditionNumber, contrast);
end
result = results(hit);
end

function verifyPlottedDifference(waves, timeMs, cfg, stat)
scan = timeMs >= cfg.targetOnset_ms + cfg.scanWin_ms(1) & ...
    timeMs <= cfg.targetOnset_ms + cfg.scanWin_ms(2);
statTimeMs = cfg.targetOnset_ms + stat.time(:)' * 1000;
if numel(statTimeMs) ~= nnz(scan) || ...
        max(abs(statTimeMs - timeMs(scan))) > 1e-6
    error('FT5: plotted and tested time axes do not match.');
end
tWave = mean(waves(:, scan), 1) ./ ...
    (std(waves(:, scan), 0, 1) / sqrt(size(waves, 1)));
savedT = stat.stat(:)';
if numel(savedT) ~= numel(tWave) || ...
        any(~isfinite(tWave)) || ...
        max(abs(tWave - savedT)) > 1e-5 * max(1, max(abs(savedT)))
    error('FT5: plotted differences do not reproduce the saved t-waveform.');
end
end

function fig = drawPanel(panel, cfg, yLimits, nSubjects)
fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'pixels', ...
    'Position', [100 100 1700 820], 'Name', 'Old cohort full-trial difference');
ax = axes('Parent', fig, 'Position', [0.08 0.14 0.87 0.69]);
hold(ax, 'on');
xlim(ax, [-100 4500]);
ylim(ax, yLimits);

targetMs = cfg.targetOnset_ms;
scanEndMs = targetMs + cfg.scanWin_ms(2);
hWindow = patch(ax, [targetMs scanEndMs scanEndMs targetMs], ...
    [yLimits(1) yLimits(1) yLimits(2) yLimits(2)], ...
    [0.8 0.83 0.87], 'FaceAlpha', 0.22, 'EdgeColor', 'none', ...
    'DisplayName', 'Tested target window');
x = panel.timeMs;
upper = panel.meanWave + panel.semWave;
lower = panel.meanWave - panel.semWave;
fill(ax, [x fliplr(x)], [upper fliplr(lower)], panel.color, ...
    'FaceAlpha', 0.23, 'EdgeColor', 'none', 'HandleVisibility', 'off');
hWave = plot(ax, x, panel.meanWave, 'Color', panel.color, ...
    'LineWidth', 3, 'DisplayName', 'Unexpected - Expected (mean +/- SEM)');
yline(ax, 0, '--', 'Color', [0.3 0.3 0.3], 'LineWidth', 1, ...
    'HandleVisibility', 'off');
hContext = xline(ax, 0, '--', 'Color', [0.25 0.48 0.85], ...
    'LineWidth', 1, 'DisplayName', 'Context chord onset');
for onset = 500:500:2500
    xline(ax, onset, '--', 'Color', [0.25 0.48 0.85], ...
        'LineWidth', 1, 'HandleVisibility', 'off');
end
hTarget = xline(ax, targetMs, '--', 'Color', [0 0 0], ...
    'LineWidth', 1.7, 'DisplayName', 'Target chord onset');

if panel.familyP < 0.05
    markSignificantCluster(ax, panel, targetMs, yLimits);
    status = sprintf('Significant cluster (Holm p = %.3f)', panel.familyP);
else
    status = sprintf('Cluster p = %.3f (not significant)', panel.testP);
end
hStatus = plot(ax, nan, nan, 'LineStyle', 'none', 'Marker', 'none');
lgd = legend(ax, [hWave hContext hTarget hWindow hStatus], ...
    {'Unexpected - Expected (mean +/- SEM)', 'Context chord onset', ...
     'Target chord onset', 'Tested target window', status}, ...
     'Location', 'northeast');
lgd.Box = 'off';
lgd.Color = 'none';
lgd.FontSize = 15;
set(ax, 'FontName', 'Arial', 'FontSize', 18, 'LineWidth', 1);
xticks(ax, 0:500:4500);
xlabel(ax, 'Time from trial onset (ms)', 'FontSize', 20);
ylabel(ax, 'Amplitude (\muV)', 'FontSize', 20);
if strcmp(panel.contrast, 'withSP')
    contrastTitle = 'With sensory priming';
else
    contrastTitle = 'Without sensory priming';
end
switch panel.conditionNumber
    case 1, conditionTitle = 'Broadband (Condition 1)';
    case 4, conditionTitle = 'Low High (Condition 4)';
    case 5, conditionTitle = 'High Low (Condition 5)';
end
title(ax, {sprintf('%s (%s)', panel.roiTitle, ...
    strjoin(panel.roiLabels, ', ')), ...
    sprintf('%s | %s | n = %d', conditionTitle, contrastTitle, nSubjects)}, ...
    'FontSize', 24, 'FontWeight', 'normal');
hold(ax, 'off');
end

function markSignificantCluster(ax, panel, targetMs, yLimits)
stat = panel.stat;
height = yLimits(2) - 0.04 * diff(yLimits);
for polarity = 1:2
    if polarity == 1
        clusters = stat.posclusters;
        labels = stat.posclusterslabelmat;
        color = [0.12 0.35 0.75];
    else
        clusters = stat.negclusters;
        labels = stat.negclusterslabelmat;
        color = [0.72 0.1 0.16];
    end
    for iCluster = 1:numel(clusters)
        if abs(clusters(iCluster).prob - panel.testP) > 1e-8
            continue;
        end
        idx = labels(:)' == iCluster;
        if ~any(idx)
            continue;
        end
        spanMs = targetMs + stat.time(idx) * 1000;
        plot(ax, [min(spanMs) max(spanMs)], [height height], ...
            'Color', color, 'LineWidth', 7, 'HandleVisibility', 'off');
    end
end
end
