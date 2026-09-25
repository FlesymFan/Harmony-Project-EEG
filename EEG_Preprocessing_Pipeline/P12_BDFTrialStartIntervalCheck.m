function P12_BDFTrialStartIntervalCheck(dataDir)
% Measure trial start-to-start intervals directly from raw BioSemi BDF files.
%
% Input:  the project Data folder containing Subject Data/Sub#/ raw BDF files.
% Output: Command Window summary and an on-screen plot of the run medians.
%
% This reads the BioSemi Status channel only. It does not infer timing from
% EEG amplitudes and it does not change any BDF, SET, MAT, or pipeline file.

% This reads recorded trial-start triggers from each BDF Status channel, 
% it measures trial start-to-start timing

    fprintf('\nP12: Raw BDF trial start-to-start interval check\n');

    if nargin < 1 || isempty(dataDir)
        dataDir = requestDataFolder();
    else
        dataDir = normalizePath(dataDir);
        validateDataFolder(dataDir);
    end

    subjectDataDir = fullfile(dataDir, 'Subject Data');
    oldSubjects = [1 2 5 6 8 9 10 11 12 13 14 16 17 19 20];
    newSubjects = 24:29;

    files = findRawBDFFiles(subjectDataDir, oldSubjects, newSubjects);
    if isempty(files)
        error('P12_BDFTrialStartIntervalCheck:NoBDF', ...
              'No raw Sub#_Cond#_run#.bdf files were found under %s.', ...
              subjectDataDir);
    end

    fprintf('Reading Status channels from %d raw BDF runs...\n', ...
            numel(files));

    rows = emptyRunRows();
    failures = strings(0,1);
    for fileIndex = 1:numel(files)
        item = files(fileIndex);
        fprintf('  Sub%d Cond%d Run%d: ', ...
                item.Subject, item.Condition, item.Run);
        try
            timing = readBDFStatusTiming(item.Path, item.Condition);
            rows(end+1) = makeRunRow(item, timing, oldSubjects, newSubjects); %#ok<AGROW>
            fprintf('%d triggers, median %.4f s\n', ...
                    timing.TriggerCount, timing.MedianInterval_s);
        catch ME
            if strcmp(ME.identifier, ...
                      'P12_BDFTrialStartIntervalCheck:MissingTriggerCode')
                rethrow(ME);
            end
            fprintf('SKIPPED (%s)\n', ME.message);
            failures(end+1,1) = sprintf('%s: %s', item.Path, ME.message); %#ok<AGROW>
        end
    end

    if isempty(rows)
        error('P12_BDFTrialStartIntervalCheck:NoReadableBDF', ...
              'None of the available BDF Status channels could be read.');
    end

    runTable = struct2table(rows);
    runTable = sortrows(runTable, {'Subject','Condition','Run'});
    if ~any(runTable.Cohort == "Old") || ~any(runTable.Cohort == "New")
        error('P12_BDFTrialStartIntervalCheck:MissingCohort', ...
              ['The comparison requires at least one readable old-cohort BDF ' ...
               'and one readable new-cohort BDF.']);
    end
    subjectTable = summarizeSubjects(runTable);
    summary = summarizeCohorts(runTable, subjectTable, failures);

    printSummary(summary, subjectTable);
    makeTimingFigure(runTable, subjectTable, summary);
end

function dataDir = requestDataFolder()
    while true
        answer = input('Data folder: ', 's');
        dataDir = normalizePath(answer);
        try
            validateDataFolder(dataDir);
            return;
        catch ME
            fprintf('%s\nPlease enter the project Data folder again.\n\n', ME.message);
        end
    end
end

function pathText = normalizePath(pathText)
    pathText = strtrim(char(string(pathText)));
    if numel(pathText) >= 2
        isDoubleQuoted = pathText(1) == '"' && pathText(end) == '"';
        isSingleQuoted = pathText(1) == '''' && pathText(end) == '''';
        if isDoubleQuoted || isSingleQuoted
            pathText = pathText(2:end-1);
        end
    end
end

function validateDataFolder(dataDir)
    if isempty(dataDir) || ~isfolder(dataDir)
        error('P12_BDFTrialStartIntervalCheck:BadDataFolder', ...
              'That Data folder does not exist.');
    end
    if ~isfolder(fullfile(dataDir, 'Subject Data'))
        error('P12_BDFTrialStartIntervalCheck:BadStructure', ...
              'That folder does not contain the required Subject Data subfolder.');
    end
end

function files = findRawBDFFiles(subjectDataDir, oldSubjects, newSubjects)
    files = struct('Path',{}, 'Name',{}, 'Subject',{}, 'Condition',{}, 'Run',{});
    subjectDirs = dir(fullfile(subjectDataDir, 'Sub*'));
    subjectDirs = subjectDirs([subjectDirs.isdir]);

    for dirIndex = 1:numel(subjectDirs)
        subjectToken = regexp(subjectDirs(dirIndex).name, '^Sub(\d+)$', ...
                              'tokens','once','ignorecase');
        if isempty(subjectToken)
            continue;
        end
        subjectNumber = str2double(subjectToken{1});
        if ~ismember(subjectNumber, [oldSubjects newSubjects])
            continue;
        end

        subjectDir = fullfile(subjectDirs(dirIndex).folder, subjectDirs(dirIndex).name);
        bdfFiles = dir(fullfile(subjectDir, '*.bdf'));
        for fileIndex = 1:numel(bdfFiles)
            token = regexp(bdfFiles(fileIndex).name, ...
                '^Sub(\d+)_Cond(\d+)_run(\d+)\.bdf$', ...
                'tokens','once','ignorecase');
            if isempty(token)
                continue;
            end

            item.Path = fullfile(bdfFiles(fileIndex).folder, bdfFiles(fileIndex).name);
            item.Name = bdfFiles(fileIndex).name;
            item.Subject = str2double(token{1});
            item.Condition = str2double(token{2});
            item.Run = str2double(token{3});
            files(end+1) = item; %#ok<AGROW>
        end
    end

    if ~isempty(files)
        sortMatrix = [[files.Subject]' [files.Condition]' [files.Run]'];
        [~, order] = sortrows(sortMatrix, [1 2 3]);
        files = files(order);
    end
end

function timing = readBDFStatusTiming(filePath, expectedCode)
    fid = fopen(filePath, 'r', 'ieee-le');
    if fid < 0
        error('Could not open the file.');
    end
    closer = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fixedHeader = fread(fid, 256, '*uint8')';
    if numel(fixedHeader) ~= 256
        error('The fixed BDF header is incomplete.');
    end

    headerBytes = asciiNumber(fixedHeader(185:192), 'header byte count');
    nRecords = asciiNumber(fixedHeader(237:244), 'record count');
    recordDuration_s = asciiNumber(fixedHeader(245:252), 'record duration');
    nSignals = asciiNumber(fixedHeader(253:256), 'signal count');

    signalHeader = fread(fid, headerBytes - 256, '*uint8')';
    if numel(signalHeader) ~= headerBytes - 256
        error('The signal header is incomplete.');
    end

    labelBytes = reshape(signalHeader(1:16*nSignals), 16, nSignals)';
    labels = strings(nSignals,1);
    for signalIndex = 1:nSignals
        labels(signalIndex) = strtrim(char(labelBytes(signalIndex,:)));
    end

    samplesOffset = nSignals * (16 + 80 + 8 + 8 + 8 + 8 + 8 + 80);
    sampleBytes = signalHeader(samplesOffset + (1:8*nSignals));
    sampleBytes = reshape(sampleBytes, 8, nSignals)';
    samplesPerRecord = zeros(nSignals,1);
    for signalIndex = 1:nSignals
        samplesPerRecord(signalIndex) = ...
            asciiNumber(sampleBytes(signalIndex,:), 'samples per record');
    end

    statusIndex = find(strcmpi(labels, 'Status'), 1);
    if isempty(statusIndex)
        error('No BioSemi Status channel was found.');
    end

    recordBytes = 3 * sum(samplesPerRecord);
    statusRecordOffset = 3 * sum(samplesPerRecord(1:statusIndex-1));
    statusSamplesPerRecord = samplesPerRecord(statusIndex);
    statusRate = statusSamplesPerRecord / recordDuration_s;

    if nRecords < 0
        fileInfo = dir(filePath);
        nRecords = floor((fileInfo.bytes - headerBytes) / recordBytes);
    end

    triggerSamples = zeros(0,1);
    triggerCodes = zeros(0,1);
    previousStatus = uint32(0);

    for recordIndex = 1:nRecords
        bytePosition = headerBytes + (recordIndex-1)*recordBytes + statusRecordOffset;
        if fseek(fid, bytePosition, 'bof') ~= 0
            error('Could not seek to Status data record %d.', recordIndex);
        end
        raw = fread(fid, [3 statusSamplesPerRecord], '*uint8');
        if size(raw,2) ~= statusSamplesPerRecord
            error('Status data record %d is incomplete.', recordIndex);
        end

        status = uint32(raw(1,:)) ...
               + bitshift(uint32(raw(2,:)), 8) ...
               + bitshift(uint32(raw(3,:)), 16);
        status = bitand(status, uint32(65535));
        prior = [previousStatus status(1:end-1)];
        onsetWithinRecord = find(status ~= prior & status ~= 0);

        if ~isempty(onsetWithinRecord)
            absoluteSamples = (recordIndex-1)*statusSamplesPerRecord ...
                            + onsetWithinRecord;
            selectedCodes = double(status(onsetWithinRecord));
            triggerSamples = [triggerSamples; absoluteSamples(:)]; %#ok<AGROW>
            triggerCodes = [triggerCodes; selectedCodes(:)]; %#ok<AGROW>
        end
        previousStatus = status(end);
    end

    if isempty(triggerCodes)
        error('No nonzero Status-channel trigger transitions were found.');
    end

    if ~any(triggerCodes == expectedCode)
        observedCodes = strjoin(string(unique(triggerCodes)), ', ');
        error('P12_BDFTrialStartIntervalCheck:MissingTriggerCode', ...
              'Expected trial-start trigger %d is missing; observed Status codes: %s.', ...
              expectedCode, observedCodes);
    end

    triggerSamples = triggerSamples(triggerCodes == expectedCode);
    intervals_s = diff(triggerSamples) / statusRate;
    intervals_s = intervals_s(isfinite(intervals_s) & intervals_s > 0);
    if isempty(intervals_s)
        error('Fewer than two usable trial-start triggers were found.');
    end

    rawMedian = median(intervals_s);
    absoluteDeviation = median(abs(intervals_s - rawMedian));
    tolerance_s = max(0.10, 6 * 1.4826 * absoluteDeviation);
    retained = abs(intervals_s - rawMedian) <= tolerance_s;
    retainedIntervals_s = intervals_s(retained);

    timing.TriggerCode = expectedCode;
    timing.TriggerCount = numel(triggerSamples);
    timing.IntervalCount = numel(intervals_s);
    timing.RetainedIntervalCount = numel(retainedIntervals_s);
    timing.ExcludedIntervalCount = sum(~retained);
    timing.MedianInterval_s = median(retainedIntervals_s);
    timing.MeanInterval_s = mean(retainedIntervals_s);
    timing.SDInterval_ms = std(retainedIntervals_s) * 1000;
    timing.MinInterval_s = min(retainedIntervals_s);
    timing.MaxInterval_s = max(retainedIntervals_s);
    timing.RecordingDuration_s = nRecords * recordDuration_s;
end

function value = asciiNumber(bytes, fieldDescription)
    value = str2double(strtrim(char(bytes)));
    if ~isscalar(value) || ~isfinite(value)
        error('Could not read BDF %s.', fieldDescription);
    end
end

function rows = emptyRunRows()
    rows = struct( ...
        'Subject',{}, 'Cohort',{}, 'Condition',{}, 'Run',{}, ...
        'TriggerCode',{}, 'TriggerCount',{}, 'IntervalCount',{}, ...
        'RetainedIntervalCount',{}, 'ExcludedIntervalCount',{}, ...
        'MedianInterval_s',{}, 'MeanInterval_s',{}, 'SDInterval_ms',{}, ...
        'MinInterval_s',{}, 'MaxInterval_s',{}, 'RecordingDuration_s',{}, ...
        'FileName',{}, 'SourceFile',{});
end

function row = makeRunRow(item, timing, oldSubjects, newSubjects)
    if ismember(item.Subject, oldSubjects)
        cohort = "Old";
    elseif ismember(item.Subject, newSubjects)
        cohort = "New";
    else
        cohort = "Other";
    end

    row.Subject = item.Subject;
    row.Cohort = cohort;
    row.Condition = item.Condition;
    row.Run = item.Run;
    row.TriggerCode = timing.TriggerCode;
    row.TriggerCount = timing.TriggerCount;
    row.IntervalCount = timing.IntervalCount;
    row.RetainedIntervalCount = timing.RetainedIntervalCount;
    row.ExcludedIntervalCount = timing.ExcludedIntervalCount;
    row.MedianInterval_s = timing.MedianInterval_s;
    row.MeanInterval_s = timing.MeanInterval_s;
    row.SDInterval_ms = timing.SDInterval_ms;
    row.MinInterval_s = timing.MinInterval_s;
    row.MaxInterval_s = timing.MaxInterval_s;
    row.RecordingDuration_s = timing.RecordingDuration_s;
    row.FileName = string(item.Name);
    row.SourceFile = string(item.Path);
end

function subjectTable = summarizeSubjects(runTable)
    subjects = unique(runTable.Subject, 'sorted');
    rows = struct('Subject',{}, 'Cohort',{}, 'RunCount',{}, ...
                  'MedianInterval_s',{}, 'MinRunMedian_s',{}, ...
                  'MaxRunMedian_s',{});
    for subjectIndex = 1:numel(subjects)
        subjectNumber = subjects(subjectIndex);
        mask = runTable.Subject == subjectNumber;
        row.Subject = subjectNumber;
        row.Cohort = runTable.Cohort(find(mask,1));
        row.RunCount = sum(mask);
        row.MedianInterval_s = median(runTable.MedianInterval_s(mask));
        row.MinRunMedian_s = min(runTable.MedianInterval_s(mask));
        row.MaxRunMedian_s = max(runTable.MedianInterval_s(mask));
        rows(end+1) = row; %#ok<AGROW>
    end
    subjectTable = struct2table(rows);
end

function summary = summarizeCohorts(runTable, subjectTable, failures)
    oldRuns = runTable.Cohort == "Old";
    newRuns = runTable.Cohort == "New";
    oldSubjects = subjectTable.Cohort == "Old";
    newSubjects = subjectTable.Cohort == "New";

    summary = struct();
    summary.availableOldSubjects = subjectTable.Subject(oldSubjects)';
    summary.availableNewSubjects = subjectTable.Subject(newSubjects)';
    summary.oldRunCount = sum(oldRuns);
    summary.newRunCount = sum(newRuns);
    summary.oldMedianInterval_s = median(runTable.MedianInterval_s(oldRuns));
    summary.newMedianInterval_s = median(runTable.MedianInterval_s(newRuns));
    summary.difference_ms = 1000 * ...
        (summary.oldMedianInterval_s - summary.newMedianInterval_s);
    summary.failedFiles = failures;
end

function printSummary(summary, subjectTable)
    fprintf('\nRaw BDF timing summary\n');
    fprintf('  Old cohort: %d subjects, %d runs\n', ...
            numel(summary.availableOldSubjects), summary.oldRunCount);
    fprintf('  New cohort: %d subjects, %d runs\n', ...
            numel(summary.availableNewSubjects), summary.newRunCount);
    fprintf('  Old available-data median: %.4f s\n', ...
            summary.oldMedianInterval_s);
    fprintf('  New-cohort median:         %.4f s\n', ...
            summary.newMedianInterval_s);
    fprintf('  Start-to-start difference: %.1f ms\n', summary.difference_ms);

    if height(subjectTable(subjectTable.Cohort == "Old",:)) < 2
        fprintf(['\n  IMPORTANT: Raw old-cohort BDF files are available for only one subject.\n' ...
                 '  This directly demonstrates a recording-period difference, but it is\n' ...
                 '  not a 15-versus-5 subject-level inferential comparison.\n']);
    end

    if ~isempty(summary.failedFiles)
        fprintf('\n  %d file(s) could not be read. See skipped messages above.\n', ...
                numel(summary.failedFiles));
    end
end

function hFig = makeTimingFigure(runTable, subjectTable, summary)
    oldColor = [0.05 0.25 0.42];
    newColor = [0.91 0.40 0.07];
    subjects = subjectTable.Subject;

    hFig = figure( ...
        'Color','w', ...
        'Name','Raw BDF trial start-to-start timing', ...
        'NumberTitle','off', ...
        'Units','normalized', ...
        'OuterPosition',[0 0 1 1]);
    ax = axes('Parent',hFig, 'Position',[0.09 0.14 0.86 0.70]);
    hold(ax, 'on');

    oldLegend = gobjects(0);
    newLegend = gobjects(0);
    medianLegend = gobjects(0);

    for subjectIndex = 1:numel(subjects)
        subjectNumber = subjects(subjectIndex);
        mask = runTable.Subject == subjectNumber;
        values = runTable.MedianInterval_s(mask);
        offsets = centeredOffsets(numel(values), 0.22);
        x = subjectIndex + offsets;

        if subjectTable.Cohort(subjectIndex) == "Old"
            color = oldColor;
            scatterHandle = scatter(ax, x, values, 78, color, 'filled', ...
                'MarkerFaceAlpha',0.78, 'MarkerEdgeColor','none');
            if isempty(oldLegend)
                oldLegend = scatterHandle;
                oldLegend.DisplayName = 'Old-cohort run';
            else
                scatterHandle.HandleVisibility = 'off';
            end
        else
            color = newColor;
            scatterHandle = scatter(ax, x, values, 78, color, 'filled', ...
                'MarkerFaceAlpha',0.78, 'MarkerEdgeColor','none');
            if isempty(newLegend)
                newLegend = scatterHandle;
                newLegend.DisplayName = 'New-cohort run';
            else
                scatterHandle.HandleVisibility = 'off';
            end
        end

        medianHandle = plot(ax, subjectIndex, ...
            subjectTable.MedianInterval_s(subjectIndex), 'kd', ...
            'MarkerFaceColor','w', 'MarkerSize',10, 'LineWidth',2);
        if isempty(medianLegend)
            medianLegend = medianHandle;
            medianLegend.DisplayName = 'Subject median';
        else
            medianHandle.HandleVisibility = 'off';
        end
    end

    oldPositions = find(subjectTable.Cohort == "Old");
    newPositions = find(subjectTable.Cohort == "New");
    if ~isempty(oldPositions)
        plot(ax, [min(oldPositions)-0.35 max(oldPositions)+0.35], ...
             [summary.oldMedianInterval_s summary.oldMedianInterval_s], ...
             '-', 'Color',oldColor, 'LineWidth',3, 'HandleVisibility','off');
    end
    if ~isempty(newPositions)
        plot(ax, [min(newPositions)-0.35 max(newPositions)+0.35], ...
             [summary.newMedianInterval_s summary.newMedianInterval_s], ...
             '-', 'Color',newColor, 'LineWidth',3, 'HandleVisibility','off');
    end

    xlim(ax, [0.5 numel(subjects)+0.5]);
    xticks(ax, 1:numel(subjects));
    xticklabels(ax, "Sub" + string(subjects));

    allValues = runTable.MedianInterval_s;
    valueRange = max(allValues) - min(allValues);
    padding = max(0.06, 0.12 * valueRange);
    ylim(ax, [min(allValues)-padding max(allValues)+padding]);

    ylabel(ax, 'Median trial start-to-start interval (s)', 'FontSize',18);
    xlabel(ax, 'Subject with available raw BDF recordings', 'FontSize',18);
    set(ax, 'FontName','Arial', 'FontSize',20, 'LineWidth',1);
    grid(ax, 'on');
    box(ax, 'off');

    legendHandles = [oldLegend newLegend medianLegend];
    legendHandles = legendHandles(isgraphics(legendHandles));
    lgd = legend(ax, legendHandles, 'Location','northeast');
    set(lgd, 'Box','off', 'Color','none', 'FontSize',18);

    title(ax, 'Raw BDF trial timing', ...
        'FontSize',24, 'FontWeight','normal');
    hold(ax, 'off');
end

function offsets = centeredOffsets(count, width)
    if count <= 1
        offsets = 0;
    else
        offsets = linspace(-width, width, count);
    end
end
