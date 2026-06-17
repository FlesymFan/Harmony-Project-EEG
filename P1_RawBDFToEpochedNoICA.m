function outputFiles = P1_RawBDFToEpochedNoICA(varargin)
% Adapted from original script: Analysis_ContextEEG_Step1_noICA.m

% Expected input: raw BioSemi .bdf files in Data/Subject Data/Unprocessed/Sub#.
% Example input: Data/Subject Data/Unprocessed/Sub1/Sub1_Cond1_run1.bdf

% Output: epoched no-ICA .set/.fdt files in Data/Subject Data/Sub#.
% Example output: Data/Subject Data/Sub1/Sub1_Cond1_run1_noICA.set

% Processing: import BDF, resample to 1024 Hz, filter 0.1-15 Hz,
% rereference to EXG1/EXG2, remove EXG3-EXG8, and epoch -0.1 to 5 s.

% Print a message of what this stage expects and creates.
printStageIntro();

% Load the fixed preprocessing settings before asking which data to process.
cfg = defaultConfig();

% If no inputs are given, ask the user what to process.
% If inputs are given, use those values instead of asking.
if nargin == 0
    cfg = promptConfig(cfg);
else
    cfg = parseConfig(cfg, varargin{:});
end

% Check that every requested raw BDF file exists before EEGLAB starts.
validateRequestedInputs(cfg);

% Print the processing plan and ask for a final yes/no confirmation.
printStagePlan(cfg);
if cfg.confirmBeforeRun && ~confirmProceed()
    fprintf('P1 canceled. No files were changed.\n');
    outputFiles = {};
    return;
end

% Make sure EEGLAB and the BioSig reader are available.
ensureEEGLABOnPath();

fprintf('\nRaw BDF to epoched no-ICA .set files\n');
fprintf('Unprocessed folder: %s\n', cfg.rawDataRoot);
fprintf('Subject Data folder: %s\n', cfg.subjectDataRoot);
fprintf('Subjects:          %s\n', mat2str(cfg.subjects));
fprintf('Conditions:        %s\n', mat2str(cfg.conditions));
fprintf('Runs:              %s\n\n', mat2str(cfg.runs));

% Store the files created or skipped, so the caller can inspect the result.
outputFiles = {};

% Process every requested subject.
for iSub = 1:numel(cfg.subjects)
    subID = cfg.subjects(iSub);
    subName = sprintf('Sub%d', subID);
    rawSubjectDir = fullfile(cfg.rawDataRoot, subName);
    outputSubjectDir = fullfile(cfg.subjectDataRoot, subName);
    ensureFolder(outputSubjectDir);

    fprintf('=== %s ===\n', subName);

    % For each subject, process every requested filtering condition.
    for iCond = 1:numel(cfg.conditions)
        condNumber = cfg.conditions(iCond);

        % For each condition, process every run separately.
        for iRun = 1:numel(cfg.runs)
            runNumber = cfg.runs(iRun);

            % Build the raw input path and the no-ICA output path.
            bdfFile = fullfile(rawSubjectDir, sprintf( ...
                'Sub%d_Cond%d_run%d.bdf', subID, condNumber, runNumber));
            outputFile = fullfile(outputSubjectDir, sprintf( ...
                'Sub%d_Cond%d_run%d%s', subID, condNumber, runNumber, cfg.outputSuffix));

            % Do not overwrite previous outputs unless the user asked for it.
            if exist(outputFile, 'file') == 2 && ~cfg.overwriteExisting
                fprintf('  Cond %d Run %d: skipping existing %s\n', ...
                        condNumber, runNumber, fileNameOnly(outputFile));
                outputFiles{end+1} = outputFile; %#ok<AGROW>
                continue;
            end

            % This is a second safety check in case files changed after preflight.
            if exist(bdfFile, 'file') ~= 2
                warning('Missing BDF file: %s. Skipping.', bdfFile);
                continue;
            end

            fprintf('  Cond %d Run %d: loading %s\n', ...
                    condNumber, runNumber, fileNameOnly(bdfFile));

            % Start a clean EEGLAB workspace for this one file.
            [ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab; %#ok<ASGLU>

            % Import the raw BioSemi BDF recording.
            EEG = pop_biosig(bdfFile);
            [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 0, 'gui', 'off');
            EEG = eeg_checkset(EEG);

            % Step 1 resampling: match the lab preprocessing rate of 1024 Hz.
            EEG = pop_resample(EEG, cfg.sampleRate);
            [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 1, 'gui', 'off');

            % Step 1 broad preprocessing filter: 0.1-15 Hz.
            EEG = pop_eegfiltnew(EEG, ...
                'locutoff', cfg.initialFilterHz(1), ...
                'hicutoff', cfg.initialFilterHz(2), ...
                'plotfreqz', double(cfg.plotFilterResponse));
            [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 2, 'gui', 'off');

            % Rereference to EXG1/EXG2 mastoids, stored as original channels
            % 65/66 in the BioSemi file.
            EEG = eeg_checkset(EEG);
            EEG = pop_reref(EEG, cfg.referenceChannels);
            [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 3, 'gui', 'off');

            % Remove the remaining external/non-scalp channels after
            % rereferencing. The final analysis expects the 64 scalp channels.
            EEG = eeg_checkset(EEG);
            EEG = pop_select(EEG, 'nochannel', cfg.channelsToRemove);
            [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 4, 'gui', 'off');

            % Epoch around every event. This follows the original Step 1
            % window of -100 ms to 5000 ms.
            EEG = eeg_checkset(EEG);
            EEG = pop_epoch(EEG, {}, cfg.epochWindowSec, ...
                'newname', 'BDF file resampled epochs', ...
                'epochinfo', 'yes');
            [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 5, 'gui', 'off');

            % Final check and save as the P1 output file.
            EEG = eeg_checkset(EEG);
            EEG = pop_saveset(EEG, ...
                'filename', fileNameOnly(outputFile), ...
                'filepath', outputSubjectDir);

            outputFiles{end+1} = outputFile; %#ok<AGROW>
            fprintf('    Saved: %s\n', outputFile);
        end
    end

    fprintf('\n');
end

fprintf('Done creating epoched no-ICA files.\n');

end

function cfg = defaultConfig()
    % The user must choose the Data folder; no computer-specific path is assumed.
    cfg.dataRoot = '';
    cfg = applyDataRoot(cfg);

    cfg.subjects = subjectsFromFolder(cfg.rawDataRoot);
    cfg.conditions = [1 4 5];
    cfg.runs = [1 2];
    % Original Step 1 preprocessing settings.
    cfg.sampleRate = 1024;
    cfg.initialFilterHz = [0.1 15];
    % BioSemi EXG1/EXG2 mastoid reference channels in the raw 72-channel file.
    cfg.referenceChannels = [65 66];
    % Extra EXG channels are not part of the final 64-channel scalp layout.
    cfg.channelsToRemove = {'EXG3', 'EXG4', 'EXG5', 'EXG6', 'EXG7', 'EXG8'};
    cfg.epochWindowSec = [-0.1 5];
    cfg.outputSuffix = '_noICA.set';
    cfg.overwriteExisting = false;
    cfg.plotFilterResponse = true;
    cfg.confirmBeforeRun = true;
end

function cfg = applyDataRoot(cfg)
    % One Data folder is enough; the rest follows the required structure.
    cfg.rawDataRoot = fullfile(cfg.dataRoot, 'Subject Data', 'Unprocessed');
    cfg.subjectDataRoot = fullfile(cfg.dataRoot, 'Subject Data');
    cfg.trialOrderRoot = fullfile(cfg.dataRoot, 'Context Trial Order');
end

function cfg = promptConfig(cfg)
    % Ask one setup question at a time and validate before moving on.
    cfg.dataRoot = promptDataRoot(cfg.dataRoot);
    cfg = applyDataRoot(cfg);

    cfg.subjects = subjectsFromFolder(cfg.rawDataRoot);

    cfg.subjects = promptSubjectVector('Subject numbers', cfg.subjects);
    cfg.conditions = promptAllowedNumericVector('Condition numbers (1/4/5)', ...
                                               cfg.conditions, [1 4 5]);
    cfg.runs = promptAllowedNumericVector('Run numbers (1/2)', cfg.runs, [1 2]);
    cfg.overwriteExisting = promptYesNo('Overwrite existing no-ICA files?', ...
                                        cfg.overwriteExisting);
    cfg.confirmBeforeRun = true;
end

function cfg = parseConfig(cfg, varargin)
    % Non-interactive version: allows calls such as
    % P1_RawBDFToEpochedNoICA('dataRoot','C:\...\Data','subjects',[27 28]).
    if mod(numel(varargin), 2) ~= 0
        error('Inputs must be name-value pairs.');
    end

    for i = 1:2:numel(varargin)
        key = lower(char(varargin{i}));
        value = varargin{i+1};

        switch key
            case {'dataroot', 'datafolder'}
                cfg.dataRoot = char(value);
            case {'subjects', 'subjectnumbers'}
                cfg.subjects = value(:)';
            case {'conditions', 'conds'}
                cfg.conditions = value(:)';
            case 'runs'
                cfg.runs = value(:)';
            case 'overwriteexisting'
                cfg.overwriteExisting = logical(value);
            case {'confirmbeforerun', 'confirm'}
                cfg.confirmBeforeRun = logical(value);
            otherwise
                error('Unknown option: %s', varargin{i});
        end
    end

    cfg = applyDataRoot(cfg);
    if isempty(cfg.subjects)
        cfg.subjects = subjectsFromFolder(cfg.rawDataRoot);
    end
    validateSubjectVector(cfg.subjects);
    validateAllowedVector(cfg.conditions, [1 4 5], 'conditions');
    validateAllowedVector(cfg.runs, [1 2], 'runs');
end

function printStageIntro()
    % First message shown when the user calls P1.
    fprintf('\nP1: Raw BDF to epoched no-ICA .set files\n');
    fprintf(['Expected input: a Data folder containing raw BioSemi .bdf files in ' ...
             'Subject Data/Unprocessed/Sub#.\n']);
    fprintf('Output: epoched *_noICA.set files in Data/Subject Data/Sub#.\n\n');
end

function validateRequestedInputs(cfg)
    % Confirm that the requested subject/condition/run BDF files exist.
    if exist(cfg.dataRoot, 'dir') ~= 7
        error('Data folder not found: %s', cfg.dataRoot);
    end
    if exist(cfg.rawDataRoot, 'dir') ~= 7
        error('Raw BDF folder not found: %s', cfg.rawDataRoot);
    end
    if exist(cfg.subjectDataRoot, 'dir') ~= 7
        error('Subject Data folder not found: %s', cfg.subjectDataRoot);
    end
    if exist(cfg.trialOrderRoot, 'dir') ~= 7
        error('Context Trial Order folder not found: %s', cfg.trialOrderRoot);
    end

    validateSubjectVector(cfg.subjects);
    validateAllowedVector(cfg.conditions, [1 4 5], 'conditions');
    validateAllowedVector(cfg.runs, [1 2], 'runs');

    missingFiles = {};

    for iSub = 1:numel(cfg.subjects)
        subID = cfg.subjects(iSub);
        subName = sprintf('Sub%d', subID);
        rawSubjectDir = fullfile(cfg.rawDataRoot, subName);

        for iCond = 1:numel(cfg.conditions)
            condNumber = cfg.conditions(iCond);
            for iRun = 1:numel(cfg.runs)
                runNumber = cfg.runs(iRun);
                bdfFile = fullfile(rawSubjectDir, sprintf( ...
                    'Sub%d_Cond%d_run%d.bdf', subID, condNumber, runNumber));

                if exist(bdfFile, 'file') ~= 2
                    missingFiles{end+1} = bdfFile; %#ok<AGROW>
                end
            end
        end
    end

    if ~isempty(missingFiles)
        fprintf('Missing required raw BDF file(s):\n');
        printFileList(missingFiles);
        error('P1 cannot start until the missing raw BDF files exist.');
    end
end

function printStagePlan(cfg)
    % Tell the user exactly what P1 is about to process.
    nFiles = numel(cfg.subjects) * numel(cfg.conditions) * numel(cfg.runs);

    fprintf('P1 preflight passed.\n');
    fprintf('  Data folder: %s\n', cfg.dataRoot);
    fprintf('  Raw BDF folder: %s\n', cfg.rawDataRoot);
    fprintf('  Output folder: %s\n', cfg.subjectDataRoot);
    fprintf('  Subjects: %s\n', mat2str(cfg.subjects));
    fprintf('  Conditions: %s\n', mat2str(cfg.conditions));
    fprintf('  Runs: %s\n', mat2str(cfg.runs));
    fprintf('  Input files found: %d raw .bdf file(s)\n', nFiles);
    fprintf('  Output suffix: %s\n', cfg.outputSuffix);
    fprintf('  Overwrite existing outputs: %d\n\n', cfg.overwriteExisting);
end

function tf = confirmProceed()
    % Final guardrail before creating or overwriting files.
    tf = promptYesNo('Proceed with P1 processing?', true);
end

function printFileList(files)
    % Print enough missing files to diagnose the folder problem.
    maxToPrint = min(numel(files), 20);
    for i = 1:maxToPrint
        fprintf('  %s\n', files{i});
    end
    if numel(files) > maxToPrint
        fprintf('  ... and %d more\n', numel(files) - maxToPrint);
    end
end

function ensureEEGLABOnPath()
    % EEGLAB and BioSig are needed for loading .bdf and saving .set files.
    if ~isempty(which('pop_biosig')) && ~isempty(which('pop_saveset'))
        return;
    end

    eeglabDir = strtrim(input('EEGLAB folder containing eeglab.m [already on path]: ', 's'));
    if ~isempty(eeglabDir)
        addpath(eeglabDir);
    end

    if isempty(which('eeglab'))
        error('EEGLAB is not on the MATLAB path. Add EEGLAB, then rerun this function.');
    end

    eeglab;
end

function ensureFolder(folderPath)
    % Create the subject output folder if it does not exist yet.
    if exist(folderPath, 'dir') ~= 7
        mkdir(folderPath);
    end
end

function name = fileNameOnly(filePath)
    % EEGLAB save/load functions usually want filename and folder separately.
    [~, baseName, ext] = fileparts(filePath);
    name = [baseName ext];
end

function dataRoot = promptDataRoot(defaultPath)
    % The selected Data folder must contain the standardized project folders.
    msg = inputMessages();

    while true
        dataRoot = promptExistingPath('Data folder', defaultPath, true);
        subjectDataRoot = fullfile(dataRoot, 'Subject Data');
        rawDataRoot = fullfile(subjectDataRoot, 'Unprocessed');
        trialOrderRoot = fullfile(dataRoot, 'Context Trial Order');

        if exist(subjectDataRoot, 'dir') == 7 && ...
           exist(rawDataRoot, 'dir') == 7 && ...
           exist(trialOrderRoot, 'dir') == 7
            return;
        end

        fprintf('%s\n', msg.invalidDataStructure);
        fprintf('  Expected: %s\n', subjectDataRoot);
        fprintf('  Expected: %s\n', rawDataRoot);
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
        if isempty(defaultPath)
            promptText = sprintf('%s: ', label);
        else
            promptText = sprintf('%s [%s]: ', label, defaultPath);
        end

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

function values = promptSubjectVector(label, defaultValues)
    % Read subject lists like [27 28] or 1:28.
    msg = inputMessages();

    while true
        answer = strtrim(input(sprintf('%s [%s]: ', label, vectorText(defaultValues)), 's'));
        values = parseNumericAnswer(answer, defaultValues);

        if isValidSubjectVector(values)
            values = values(:)';
            return;
        end

        fprintf('%s\n', msg.invalidSubjects);
    end
end

function values = promptAllowedNumericVector(label, defaultValues, allowedValues)
    % Read condition/run choices and reject anything outside the allowed set.
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

function tf = promptYesNo(label, defaultValue)
    % Simple y/n prompt that repeats until the answer is clear.
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
    % MATLAB-friendly parsing for inputs like 27, [27 28], or 1:28.
    if isempty(answer)
        values = defaultValues;
    else
        values = str2num(answer); %#ok<ST2NM>
    end
end

function tf = isValidSubjectVector(values)
    tf = isnumeric(values) && ~isempty(values) && ...
         all(isfinite(values)) && all(values == round(values)) && all(values > 0);
end

function validateSubjectVector(values)
    if ~isValidSubjectVector(values)
        error('Invalid subjects. Enter positive whole-number subject IDs, for example [27 28].');
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

function textOut = vectorText(values)
    if isempty(values)
        textOut = '[]';
    else
        textOut = mat2str(values);
    end
end

function textOut = stripOuterQuotes(textIn)
    % Let users paste Windows paths with or without quotes.
    textOut = textIn;
    if numel(textOut) >= 2
        if (textOut(1) == '"' && textOut(end) == '"') || ...
           (textOut(1) == '''' && textOut(end) == '''')
            textOut = textOut(2:end-1);
        end
    end
end

function msg = inputMessages()
    % Central place for the short interactive error messages.
    msg.requiredFolder = 'Please enter the full path to the Data folder.';
    msg.invalidFolder = 'That folder does not exist. Please enter an existing Data folder.';
    msg.invalidDataStructure = 'That folder exists, but it does not match the required Data folder structure.';
    msg.invalidSubjects = 'Invalid subject input. Use positive whole numbers, for example 27 or [27 28].';
    msg.invalidChoice = 'Invalid input.';
    msg.invalidYesNo = 'Invalid input. Please enter y or n.';
end

function subjects = subjectsFromFolder(rootPath)
    % Use Sub# folder names to suggest a default subject list.
    if ~isfolder(rootPath)
        subjects = [];
        return;
    end

    dirs = dir(fullfile(rootPath, 'Sub*'));
    dirs = dirs([dirs.isdir]);
    subjects = [];

    for i = 1:numel(dirs)
        subID = str2double(regexprep(dirs(i).name, '^Sub', '', 'ignorecase'));
        if ~isnan(subID)
            subjects(end+1) = subID; %#ok<AGROW>
        end
    end

    subjects = sort(subjects);
end
