function outputFiles = P8_AverageTrialsWithinSubjects(varargin)
% Expected input: condition-level files in Data/EEGData_allSubject_cond#.mat.
% Output: trial-averaged ERP/topoplot input files in Data/EEGDataAvgAcrossTrials_allSubject_cond#.mat.

printStageIntro();

% Start with the standard Data structure, then ask what to average.
cfg = defaultConfig();

if nargin == 0
    cfg = promptConfig(cfg);
else
    cfg = parseConfig(cfg, varargin{:});
end

validateRequestedInputs(cfg);
printStagePlan(cfg);
if cfg.confirmBeforeRun && ~confirmProceed()
    fprintf('P8 canceled. No files were changed.\n');
    outputFiles = {};
    return;
end

ensureFolder(cfg.dataRoot);

fprintf('\nAveraging subject trials...\n');
fprintf('Data folder: %s\n', cfg.dataRoot);
fprintf('Conditions: %s\n', mat2str(cfg.conditions));
fprintf('Trial segments: %d\n\n', cfg.nSegments);

outputFiles = {};

% Average every requested condition file created by P7.
for iCond = 1:numel(cfg.conditions)
    conditionNumber = cfg.conditions(iCond);
    inputFile = fullfile(cfg.dataRoot, sprintf('EEGData_allSubject_cond%d.mat', conditionNumber));

    if ~exist(inputFile, 'file')
        warning('Missing input file: %s. Skipping condition %d.', inputFile, conditionNumber);
        continue;
    end

    loaded = load(inputFile, 'EEGData');
    EEGData = loaded.EEGData;
    subCondFields = fieldnames(EEGData);

    fprintf('Condition %d: loaded %s\n', conditionNumber, inputFile);

    if cfg.nSegments == 1
        % Default path: average across all trials for each subject/condition.
        EEGDataAvg = averageOneSegment(EEGData, subCondFields, 1, []);
        saveFileName = sprintf('EEGDataAvgAcrossTrials_allSubject_cond%d.mat', conditionNumber);
        savePath = fullfile(cfg.dataRoot, saveFileName);
        save(savePath, 'EEGDataAvg', '-v7.3');
        outputFiles{end+1} = savePath; %#ok<AGROW>
        fprintf('Saved: %s\n\n', savePath);
    else
        % Optional path: split each trial set into segments before averaging.
        for iSegment = 1:cfg.nSegments
            [EEGDataAvg, startIdx, endIdx] = averageOneSegment( ...
                EEGData, subCondFields, iSegment, cfg.nSegments);

            saveFileName = sprintf('EEGDataAvgAcrossTrials_%dto%d_allSubject_cond%d.mat', ...
                                   startIdx, endIdx, conditionNumber);
            savePath = fullfile(cfg.dataRoot, saveFileName);
            save(savePath, 'EEGDataAvg', '-v7.3');
            outputFiles{end+1} = savePath; %#ok<AGROW>
            fprintf('Saved: %s\n', savePath);
        end
        fprintf('\n');
    end
end

fprintf('Done averaging subject trials.\n');

end

function cfg = defaultConfig()
    % The user chooses the Data folder; no machine-specific path is assumed.
    cfg.dataRoot = '';
    cfg = applyDataRoot(cfg);
    cfg.conditions = [1 4 5];
    cfg.nSegments = 1;
    cfg.confirmBeforeRun = true;
end

function cfg = applyDataRoot(cfg)
    % The standardized Data folder keeps P8 aligned with the full pipeline.
    cfg.subjectDataRoot = fullfile(cfg.dataRoot, 'Subject Data');
    cfg.trialOrderRoot = fullfile(cfg.dataRoot, 'Context Trial Order');
end

function cfg = promptConfig(cfg)
    % Ask for only the project-specific choices.
    cfg.dataRoot = promptDataRoot(cfg.dataRoot);
    cfg = applyDataRoot(cfg);
    cfg.conditions = promptAllowedNumericVector('Condition numbers (1/4/5)', ...
                                               cfg.conditions, [1 4 5]);
    cfg.nSegments = promptScalar('Number of trial segments', cfg.nSegments);
    cfg.confirmBeforeRun = true;
end

function cfg = parseConfig(cfg, varargin)
    if mod(numel(varargin), 2) ~= 0
        error('Inputs must be name-value pairs.');
    end

    for i = 1:2:numel(varargin)
        key = lower(char(varargin{i}));
        value = varargin{i+1};
        switch key
            case {'dataroot', 'datafolder'}
                cfg.dataRoot = char(value);
            case {'conditions', 'conds'}
                cfg.conditions = value(:)';
            case {'nsegments', 'segments'}
                cfg.nSegments = value;
            case {'confirmbeforerun', 'confirm'}
                cfg.confirmBeforeRun = logical(value);
            otherwise
                error('Unknown option: %s', varargin{i});
        end
    end

    cfg = applyDataRoot(cfg);

    validateAllowedVector(cfg.conditions, [1 4 5], 'conditions');
    validatePositiveInteger(cfg.nSegments, 'number of trial segments');
end

function printStageIntro()
    fprintf('\nP8: Average trials within each subject\n');
    fprintf(['Expected input: EEGData_allSubject_cond#.mat group files from P7. ' ...
             'Output: EEGDataAvgAcrossTrials_allSubject_cond#.mat files for ERP/topoplot analysis.\n\n']);
end

function validateRequestedInputs(cfg)
    missingFiles = {};

    if exist(cfg.dataRoot, 'dir') ~= 7
        error('Data folder not found: %s', cfg.dataRoot);
    end
    if exist(cfg.subjectDataRoot, 'dir') ~= 7
        error('Subject Data folder not found: %s', cfg.subjectDataRoot);
    end
    if exist(cfg.trialOrderRoot, 'dir') ~= 7
        error('Context Trial Order folder not found: %s', cfg.trialOrderRoot);
    end

    validateAllowedVector(cfg.conditions, [1 4 5], 'conditions');
    validatePositiveInteger(cfg.nSegments, 'number of trial segments');

    for iCond = 1:numel(cfg.conditions)
        conditionNumber = cfg.conditions(iCond);
        inputFile = fullfile(cfg.dataRoot, sprintf('EEGData_allSubject_cond%d.mat', conditionNumber));

        if exist(inputFile, 'file') ~= 2
            missingFiles{end+1} = inputFile; %#ok<AGROW>
        end
    end

    if ~isempty(missingFiles)
        fprintf('Missing required P8 input file(s):\n');
        printFileList(missingFiles);
        error('P8 cannot start until the group condition files exist.');
    end
end

function printStagePlan(cfg)
    fprintf('P8 preflight passed.\n');
    fprintf('  Data folder: %s\n', cfg.dataRoot);
    fprintf('  Conditions: %s\n', mat2str(cfg.conditions));
    fprintf('  Trial segments: %d\n', cfg.nSegments);
    fprintf('  Output averaged files to create/update: %d\n\n', numel(cfg.conditions));
end

function tf = confirmProceed()
    tf = promptYesNo('Proceed with P8 processing?', true);
end

function printFileList(files)
    maxToPrint = min(numel(files), 20);
    for i = 1:maxToPrint
        fprintf('  %s\n', files{i});
    end
    if numel(files) > maxToPrint
        fprintf('  ... and %d more\n', numel(files) - maxToPrint);
    end
end

function [EEGDataAvg, startIdx, endIdx] = averageOneSegment(EEGData, subCondFields, segmentIndex, nSegments)
    EEGDataAvg = struct();
    startIdx = 1;
    endIdx = [];

    for iField = 1:numel(subCondFields)
        thisFieldName = subCondFields{iField};
        subFields = fieldnames(EEGData.(thisFieldName));
        EEGDataAvg.(thisFieldName) = struct();

        for jField = 1:numel(subFields)
            dataName = subFields{jField};
            rawData3D = EEGData.(thisFieldName).(dataName);

            if ndims(rawData3D) ~= 3
                error('Expected 3D data in %s.%s.', thisFieldName, dataName);
            end

            nTrials = size(rawData3D, 3);
            if isempty(nSegments)
                useIdx = 1:nTrials;
                startIdx = 1;
                endIdx = nTrials;
            else
                trialsPerSegment = floor(nTrials / nSegments);
                startIdx = (segmentIndex - 1) * trialsPerSegment + 1;
                if segmentIndex == nSegments
                    endIdx = nTrials;
                else
                    endIdx = segmentIndex * trialsPerSegment;
                end
                useIdx = startIdx:endIdx;
            end

            EEGDataAvg.(thisFieldName).(dataName) = mean(rawData3D(:, :, useIdx), 3, 'omitnan');
        end
    end
end

function ensureFolder(pathIn)
    if ~isfolder(pathIn)
        mkdir(pathIn);
    end
end

function dataRoot = promptDataRoot(defaultPath)
    % The selected Data folder must contain the standard pipeline folders.
    msg = inputMessages();

    while true
        dataRoot = promptExistingPath('Data folder', defaultPath, true);
        subjectDataRoot = fullfile(dataRoot, 'Subject Data');
        trialOrderRoot = fullfile(dataRoot, 'Context Trial Order');

        if exist(subjectDataRoot, 'dir') == 7 && exist(trialOrderRoot, 'dir') == 7
            return;
        end

        fprintf('%s\n', msg.invalidDataStructure);
        fprintf('  Expected: %s\n', subjectDataRoot);
        fprintf('  Expected: %s\n', trialOrderRoot);
        defaultPath = dataRoot;
    end
end

function pathOut = promptExistingPath(label, defaultPath, requireAnswer)
    % Keep asking until the user gives an existing folder.
    msg = inputMessages();
    if nargin < 3
        requireAnswer = false;
    end

    while true
        promptText = promptWithOptionalDefault(label, defaultPath);
        answer = strtrim(input(promptText, 's'));

        if isempty(answer) && requireAnswer
            fprintf('%s\n', msg.requiredFolder);
            continue;
        elseif isempty(answer)
            pathOut = defaultPath;
        else
            pathOut = stripOuterQuotes(answer);
        end

        if exist(pathOut, 'dir') == 7
            return;
        end

        fprintf('%s\n  %s\n', msg.invalidFolder, pathOut);
    end
end

function values = promptAllowedNumericVector(label, defaultValues, allowedValues)
    % Read condition choices and reject values outside 1/4/5.
    msg = inputMessages();

    while true
        answer = strtrim(input(sprintf('%s [%s]: ', label, vectorText(defaultValues)), 's'));
        values = parseNumericAnswer(answer, defaultValues);

        if isValidAllowedVector(values, allowedValues)
            values = values(:)';
            return;
        end

        fprintf('%s Allowed values: %s\n', msg.invalidChoice, mat2str(allowedValues));
    end
end

function value = promptScalar(label, defaultValue)
    % Read a positive whole-number setting.
    msg = inputMessages();

    while true
        answer = strtrim(input(sprintf('%s [%d]: ', label, defaultValue), 's'));
        if isempty(answer)
            value = defaultValue;
        else
            value = str2double(answer);
        end

        if isValidPositiveInteger(value)
            return;
        end

        fprintf('%s\n', msg.invalidPositiveInteger);
    end
end

function tf = promptYesNo(label, defaultValue)
    % Repeat y/n questions until the answer is clear.
    msg = inputMessages();
    if defaultValue
        defaultText = 'y';
    else
        defaultText = 'n';
    end

    while true
        answer = strtrim(lower(input(sprintf('%s (y/n) [%s]: ', label, defaultText), 's')));
        if isempty(answer)
            tf = defaultValue;
            return;
        end
        if any(strcmp(answer, {'y', 'yes'}))
            tf = true;
            return;
        end
        if any(strcmp(answer, {'n', 'no'}))
            tf = false;
            return;
        end

        fprintf('%s\n', msg.invalidYesNo);
    end
end

function values = parseNumericAnswer(answer, defaultValues)
    if isempty(answer)
        values = defaultValues;
    else
        values = str2num(answer); %#ok<ST2NM>
    end
end

function tf = isValidAllowedVector(values, allowedValues)
    tf = isnumeric(values) && ~isempty(values) && ...
         all(isfinite(values)) && all(values == round(values)) && ...
         all(ismember(values(:)', allowedValues));
end

function validateAllowedVector(values, allowedValues, label)
    if ~isValidAllowedVector(values, allowedValues)
        error('Invalid %s. Allowed values are %s.', label, mat2str(allowedValues));
    end
end

function tf = isValidPositiveInteger(value)
    tf = isnumeric(value) && isscalar(value) && isfinite(value) && ...
         value >= 1 && value == floor(value);
end

function validatePositiveInteger(value, label)
    if ~isValidPositiveInteger(value)
        error('Invalid %s. Enter a positive whole number.', label);
    end
end

function textOut = promptWithOptionalDefault(label, defaultPath)
    if isempty(defaultPath)
        textOut = sprintf('%s: ', label);
    else
        textOut = sprintf('%s [%s]: ', label, defaultPath);
    end
end

function textOut = vectorText(values)
    if isempty(values)
        textOut = '[]';
    else
        textOut = mat2str(values);
    end
end

function textOut = stripOuterQuotes(textIn)
    textOut = textIn;
    if numel(textOut) >= 2
        if (textOut(1) == '"' && textOut(end) == '"') || ...
           (textOut(1) == '''' && textOut(end) == '''')
            textOut = textOut(2:end-1);
        end
    end
end

function msg = inputMessages()
    msg.requiredFolder = 'Please enter the full path to the Data folder.';
    msg.invalidFolder = 'That folder does not exist. Please enter an existing folder.';
    msg.invalidDataStructure = 'That folder exists, but it does not match the required Data folder structure.';
    msg.invalidChoice = 'Invalid input.';
    msg.invalidPositiveInteger = 'Invalid input. Please enter a positive whole number.';
    msg.invalidYesNo = 'Invalid input. Please enter y or n.';
end
