function framePaths = topoplotFrameSeries()
% Generate a sequence of multi-subject topoplot frames.
%
% This is a standalone helper for making pseudo-video frames. It is not
% called by main.m. Run it directly when you want a folder of PNG frames.

scriptDir = fileparts(mfilename('fullpath'));
pipelineDir = fileparts(scriptDir);
addpath(pipelineDir);
previousDir = pwd;
cleanupDir = onCleanup(@() cd(previousDir)); %#ok<NASGU>
cd(scriptDir);

cfg = config();
cfg.plotMode = 'multi';
cfg.subjectIndices = 1:15;
cfg.plotConditions = {'Diff_withSP'};
cfg.outputDir = 'topoplot_frames';
cfg.useInteractiveConfig = false;
cfg.multiSubjectColumns = 5;
cfg.showChannelLabels = true;
cfg.multiPanelTitleFontSize = 13;
cfg.multiLabelFontSize = 5;
cfg.multiMarkerSize = 10;

firstWindowStart = 3100;
lastWindowStart = 3700;
windowStep = 20;
exportResolution = 150;
maximizeBeforeExport = true;
maximizePauseSeconds = 20;

fprintf('\n[Topoplot frame series]\n');
fprintf('This will clean the output folder before saving new frames.\n\n');

useDefaults = promptYesNo('Use default frame-series config? (y/n)', false);

if ~useDefaults
    cfg.subjectIndices = promptNumericVector('Subject indices, e.g. 1:15 or [1 2 3]', ...
                                             cfg.subjectIndices);
    cfg.conditionNumber = promptScalar('Filtering condition 1/4/5', cfg.conditionNumber);
    if ~ismember(cfg.conditionNumber, [1 4 5])
        error('topoplotFrameSeries: filtering condition must be 1, 4, or 5.');
    end

    cfg.plotConditions = promptPlotConditions(cfg.plotConditions);

    firstWindowStart = promptScalar('First window start', firstWindowStart);
    lastWindowStart = promptScalar('Last window start', lastWindowStart);
    cfg.windowWidth_remap = promptScalar('Window width', cfg.windowWidth_remap);
    windowStep = promptScalar('Window-start increment', windowStep);

    cfg.outputDir = promptText('Output folder', cfg.outputDir);
else
    printDefaultSummary(cfg, firstWindowStart, lastWindowStart, windowStep, ...
                        maximizeBeforeExport, maximizePauseSeconds, ...
                        exportResolution);
end

if lastWindowStart < firstWindowStart
    error('topoplotFrameSeries: last window start must be >= first window start.');
end
if cfg.windowWidth_remap <= 0 || windowStep <= 0
    error('topoplotFrameSeries: window width and increment must be positive.');
end
if exportResolution <= 0 || cfg.multiMarkerSize <= 0 || maximizePauseSeconds < 0
    error('topoplotFrameSeries: export resolution, electrode dot size, and maximize wait time must be valid positive values.');
end

outDir = prepareOutputFolder(cfg.outputDir);
windowStarts = firstWindowStart:windowStep:lastWindowStart;
nFrames = numel(windowStarts);
framePaths = strings(nFrames, 1);
topoValuesByFrame = cell(nFrames, 1);
plotInfoByFrame = cell(nFrames, 1);
allFrameValues = [];

[EEGDataAvg, subjectNames, dataFile] = loadData(cfg);
fprintf('\nLoaded: %s\n', dataFile);
fprintf('Preparing %d frame(s) so one fixed color scale can be used.\n\n', nFrames);

for f = 1:nFrames
    cfg.windowStart_remap = windowStarts(f);

    [topoValuesAll, plotInfo] = scalpValues(EEGDataAvg, subjectNames, cfg);
    plotInfo.dataFile = dataFile;
    topoValuesByFrame{f} = topoValuesAll;
    plotInfoByFrame{f} = plotInfo;
    allFrameValues = [allFrameValues; topoValuesAll(:)]; %#ok<AGROW>

    fprintf('Prepared frame %d/%d: [%d %d]\n', ...
            f, nFrames, ...
            plotInfo.timeWindow_remap(1), plotInfo.timeWindow_remap(2));
end

cfg.fixedColorLimits = fixedColorLimits(allFrameValues);
fprintf('\nFixed color scale for all frames: [%.3f %.3f] microvolts\n', ...
        cfg.fixedColorLimits(1), cfg.fixedColorLimits(2));
fprintf('Generating %d frame(s) into: %s\n\n', nFrames, outDir);

for f = 1:nFrames
    topoValuesAll = topoValuesByFrame{f};
    plotInfo = plotInfoByFrame{f};
    hFig = plotFigure(topoValuesAll, plotInfo, cfg);
    set(hFig, 'Color', 'w');
    if maximizeBeforeExport
        maximizeFigure(hFig, maximizePauseSeconds);
    else
        drawnow;
    end

    frameName = sprintf('frame_%04d_%d_%d.png', ...
                        f, plotInfo.timeWindow_remap(1), plotInfo.timeWindow_remap(2));
    framePath = fullfile(outDir, frameName);
    exportgraphics(hFig, framePath, 'Resolution', exportResolution);
    framePaths(f) = string(framePath);

    close(hFig);

    fprintf('Saved frame %d/%d: [%d %d]\n', ...
            f, nFrames, ...
            plotInfo.timeWindow_remap(1), plotInfo.timeWindow_remap(2));
end

fprintf('\nFrame series complete.\n');
fprintf('Output folder: %s\n', outDir);
end

function value = promptScalar(prompt, defaultValue)
    resp = strtrim(input(sprintf('%s [%g]: ', prompt, defaultValue), 's'));
    if isempty(resp)
        value = defaultValue;
    else
        value = str2double(resp);
    end

    if isempty(value) || ~isscalar(value) || isnan(value)
        error('topoplotFrameSeries: "%s" must be one number.', prompt);
    end
end

function value = promptNumericVector(prompt, defaultValue)
    resp = strtrim(input(sprintf('%s [%s]: ', prompt, vectorText(defaultValue)), 's'));
    if isempty(resp)
        value = defaultValue;
    else
        value = str2num(resp); %#ok<ST2NM>
    end

    if isempty(value) || ~isnumeric(value) || any(~isfinite(value(:)))
        error('topoplotFrameSeries: "%s" must be numeric.', prompt);
    end

    value = value(:)';
end

function value = promptText(prompt, defaultValue)
    resp = strtrim(input(sprintf('%s [%s]: ', prompt, defaultValue), 's'));
    if isempty(resp)
        value = defaultValue;
    else
        value = resp;
    end
end

function tf = promptYesNo(prompt, defaultValue)
    if defaultValue
        defaultText = 'y';
    else
        defaultText = 'n';
    end

    resp = strtrim(lower(input(sprintf('%s [%s]: ', prompt, defaultText), 's')));
    if isempty(resp)
        tf = defaultValue;
    else
        tf = any(strcmp(resp, {'y','yes'}));
    end
end

function maximizeFigure(hFig, pauseSeconds)
    figure(hFig);

    try
        set(hFig, 'WindowState', 'maximized');
    catch
        set(hFig, 'Units', 'normalized', 'OuterPosition', [0 0 1 1]);
    end

    drawnow;
    if pauseSeconds > 0
        pause(pauseSeconds);
    end
    drawnow;
end

function clim = fixedColorLimits(values)
    values = abs(values(:));
    values = values(~isnan(values));

    if isempty(values)
        vMax = 1;
    else
        vMax = prctile(values, 99);
        if vMax == 0
            vMax = max(values);
            if vMax == 0
                vMax = 1;
            end
        end
    end

    clim = [-vMax, vMax];
end

function printDefaultSummary(cfg, firstWindowStart, lastWindowStart, windowStep, maximizeBeforeExport, maximizePauseSeconds, exportResolution)
    fprintf('\nUsing default frame-series config:\n');
    fprintf('  Subject indices: %s\n', vectorText(cfg.subjectIndices));
    fprintf('  Filtering condition: %d\n', cfg.conditionNumber);
    fprintf('  Plot condition(s): %s\n', strjoin(cfg.plotConditions, ', '));
    fprintf('  First window start: %d\n', firstWindowStart);
    fprintf('  Last window start: %d\n', lastWindowStart);
    fprintf('  Window width: %d\n', cfg.windowWidth_remap);
    fprintf('  Window-start increment: %d\n', windowStep);
    fprintf('  Multi-subject columns: %d\n', cfg.multiSubjectColumns);
    if maximizeBeforeExport
        fprintf('  Maximize before saving: yes\n');
        fprintf('  Wait after maximizing: %.2f seconds\n', maximizePauseSeconds);
    else
        fprintf('  Maximize before saving: no\n');
    end
    fprintf('  PNG export resolution: %d\n', exportResolution);
    if cfg.showChannelLabels
        fprintf('  Show channel labels: yes\n');
    else
        fprintf('  Show channel labels: no\n');
    end
    fprintf('  Electrode dot size: %d\n', cfg.multiMarkerSize);
    fprintf('  Output folder: %s\n', cfg.outputDir);
    fprintf('  Save .fig files: no\n');
    fprintf('  Color scale: fixed across all frames\n\n');
end

function conditions = promptPlotConditions(defaultConditions)
    fprintf('\nTopoplot conditions/contrasts:\n');
    fprintf('  1 = Exp_withSP\n');
    fprintf('  2 = Unexp_withSP\n');
    fprintf('  3 = Diff_withSP    (Unexpected with SP - Expected with SP)\n');
    fprintf('  4 = Exp_noSP\n');
    fprintf('  5 = Unexp_noSP\n');
    fprintf('  6 = Diff_noSP      (Unexpected without SP - Expected without SP)\n');
    fprintf('  7 = Atonal\n');

    defaultChoices = choicesFromConditions(defaultConditions);
    choices = promptNumericVector('Choose one or more numbers, e.g. 3 or [1 2 3]', ...
                                  defaultChoices);
    conditions = conditionsFromChoices(choices);
    fprintf('Selected plot conditions: %s\n\n', strjoin(conditions, ', '));
end

function names = conditionsFromChoices(choices)
    allNames = {'Exp_withSP', 'Unexp_withSP', 'Diff_withSP', ...
                'Exp_noSP', 'Unexp_noSP', 'Diff_noSP', 'Atonal'};

    if isempty(choices) || any(~ismember(choices, 1:numel(allNames)))
        error('topoplotFrameSeries: condition choices must be numbers 1..7.');
    end

    names = allNames(choices);
end

function choices = choicesFromConditions(names)
    allNames = {'Exp_withSP', 'Unexp_withSP', 'Diff_withSP', ...
                'Exp_noSP', 'Unexp_noSP', 'Diff_noSP', 'Atonal'};
    choices = [];

    for i = 1:numel(names)
        idx = find(strcmp(names{i}, allNames), 1);
        if ~isempty(idx)
            choices(end+1) = idx; %#ok<AGROW>
        end
    end

    if isempty(choices)
        choices = 3;
    end
end

function outDir = prepareOutputFolder(outputDirName)
    outDir = fullfile(pwd, outputDirName);
    currentFolder = char(java.io.File(pwd).getCanonicalPath());
    targetFolder = char(java.io.File(outDir).getCanonicalPath());

    if ~startsWith([targetFolder filesep], [currentFolder filesep])
        error('topoplotFrameSeries: output folder must be inside the current topoplot_animation folder.');
    end
    if strcmp(targetFolder, currentFolder)
        error('topoplotFrameSeries: output folder cannot be the current folder.');
    end

    if exist(outDir, 'dir')
        rmdir(outDir, 's');
    end

    mkdir(outDir);
end

function text = vectorText(value)
    value = value(:)';
    if numel(value) > 1 && isequal(value, value(1):value(end))
        text = sprintf('%g:%g', value(1), value(end));
    else
        text = mat2str(value);
    end
end
