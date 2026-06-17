function outputFiles = P3_EpochedNoICAToICA(varargin)
% Adapted from original script: Analysis_ContextEEG_Step2_withICA.m

% Expected input: inspected no-ICA .set files in Data/Subject Data/Sub#.
% Example input: Data/Subject Data/Sub1/Sub1_Cond1_run1_noICA.set

% Output: ICA-decomposed .set/.fdt files in Data/Subject Data/Sub#.
% Example output: Data/Subject Data/Sub1/Sub1_Cond1_run1_withICA2.set

% If a channel was removed in P2, the output keeps that note in the name:
% Data/Subject Data/Sub1/Sub1_Cond1_run1_withICA2_B31removed.set

% Processing: filter 0.5-10 Hz, apply BioSemi64.loc, remove any channel
% locations that were rejected during P2, and run extended ICA.
% Note: manual ICA component rejection happens afterward in EEGLAB.

printStageIntro();

% Start with fixed Step 2 settings, then ask which files to process.
cfg = defaultConfig();

if nargin == 0
    cfg = promptConfig(cfg);
else
    cfg = parseConfig(cfg, varargin{:});
end

validateRequestedInputs(cfg);
printStagePlan(cfg);
if cfg.confirmBeforeRun && ~confirmProceed()
    fprintf('P3 canceled. No files were changed.\n');
    outputFiles = {};
    return;
end

% EEGLAB is needed for loading .set files, channel locations, and ICA.
ensureEEGLABOnPath();
cfg = resolveLookupFile(cfg);

if exist(cfg.fullChannelLocationFile, 'file') ~= 2
    error('Full channel-location file not found: %s', cfg.fullChannelLocationFile);
end

if ~isempty(cfg.lookupFile) && exist(cfg.lookupFile, 'file') ~= 2
    error('EEGLAB lookup file not found: %s', cfg.lookupFile);
end

fprintf('\nEpoched no-ICA .set files to ICA .set files\n');
fprintf('Data folder:       %s\n', cfg.dataRoot);
fprintf('Subject Data folder: %s\n', cfg.subjectDataRoot);
fprintf('Full channel file: %s\n', cfg.fullChannelLocationFile);
fprintf('Subjects:          %s\n', mat2str(cfg.subjects));
fprintf('Conditions:        %s\n', mat2str(cfg.conditions));
fprintf('Runs:              %s\n\n', mat2str(cfg.runs));

outputFiles = {};

for iSub = 1:numel(cfg.subjects)
    subID = cfg.subjects(iSub);
    subName = sprintf('Sub%d', subID);
    subPath = fullfile(cfg.subjectDataRoot, subName);

    if ~isfolder(subPath)
        warning('Missing subject folder: %s. Skipping %s.', subPath, subName);
        continue;
    end

    subjectSettings = settingsForSubject(cfg, subID);

    fprintf('=== %s ===\n', subName);
    if ~isempty(subjectSettings.removedChannelLabel)
        fprintf('  Using reduced channel layout without %s.\n', ...
                subjectSettings.removedChannelLabel);
    end

    for iCond = 1:numel(cfg.conditions)
        condNumber = cfg.conditions(iCond);

        for iRun = 1:numel(cfg.runs)
            runNumber = cfg.runs(iRun);
            inputFile = fullfile(subPath, sprintf( ...
                'Sub%d_Cond%d_run%d%s', ...
                subID, condNumber, runNumber, subjectSettings.inputSuffix));
            outputFile = fullfile(subPath, sprintf( ...
                'Sub%d_Cond%d_run%d%s', ...
                subID, condNumber, runNumber, subjectSettings.outputSuffix));

            if exist(outputFile, 'file') == 2 && ~cfg.overwriteExisting
                fprintf('  Cond %d Run %d: skipping existing %s\n', ...
                        condNumber, runNumber, fileNameOnly(outputFile));
                outputFiles{end+1} = outputFile; %#ok<AGROW>
                continue;
            end

            if exist(inputFile, 'file') ~= 2
                warning('Missing no-ICA source file: %s. Skipping.', inputFile);
                continue;
            end

            fprintf('  Cond %d Run %d: loading %s\n', ...
                    condNumber, runNumber, fileNameOnly(inputFile));

            [ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab; %#ok<ASGLU>

            EEG = pop_loadset('filename', fileNameOnly(inputFile), ...
                              'filepath', fileparts(inputFile));
            [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, 0);

            % Step 2 ICA-stage filter: 0.5-10 Hz.
            EEG = pop_eegfiltnew(EEG, ...
                'locutoff', cfg.icaFilterHz(1), ...
                'hicutoff', cfg.icaFilterHz(2));
            [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 1, 'gui', 'off');

            % Apply the BioSemi scalp-channel locations. If a channel was
            % removed during P2, use the same template with that one location
            % omitted so the location count matches the data.
            EEG = eeg_checkset(EEG);
            EEG.chanlocs = channelLocationsForDataset( ...
                cfg.fullChannelLocationFile, ...
                subjectSettings.removedChannelLabel, ...
                EEG.nbchan);

            if ~isempty(cfg.lookupFile)
                EEG = pop_chanedit(EEG, 'lookup', cfg.lookupFile);
            end
            [ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);

            % Run ICA. Component rejection is intentionally manual in P4.
            EEG = eeg_checkset(EEG);
            EEG = pop_runica(EEG, ...
                'icatype', cfg.icaType, ...
                'extended', cfg.extendedICA, ...
                'interrupt', 'on');
            [ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);

            EEG = eeg_checkset(EEG);
            EEG = pop_saveset(EEG, ...
                'filename', fileNameOnly(outputFile), ...
                'filepath', subPath);
            [ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);

            outputFiles{end+1} = outputFile; %#ok<AGROW>
            fprintf('    Saved: %s\n', outputFile);
        end
    end

    fprintf('\n');
end

fprintf('Done creating ICA files.\n');

end

function cfg = defaultConfig()
    % The user chooses the Data folder; no machine-specific path is assumed.
    scriptDir = fileparts(mfilename('fullpath'));

    cfg.dataRoot = '';
    cfg = applyDataRoot(cfg);
    cfg.fullChannelLocationFile = fullfile(scriptDir, 'BioSemi64.loc');
    cfg.lookupFile = '';
    cfg.subjects = [];
    cfg.conditions = [1 4 5];
    cfg.runs = [1 2];
    % Original Step 2 ICA-stage filter settings.
    cfg.icaFilterHz = [0.5 10];
    cfg.icaType = 'runica';
    cfg.extendedICA = 1;
    cfg.defaultInputSuffix = '_noICA.set';
    cfg.defaultOutputSuffix = '_withICA2.set';
    cfg.subjectOverrides = defaultSubjectOverrides();
    cfg.overwriteExisting = false;
    cfg.confirmBeforeRun = true;
end

function cfg = applyDataRoot(cfg)
    % The standardized Data folder gives P3 its subject folders.
    cfg.subjectDataRoot = fullfile(cfg.dataRoot, 'Subject Data');
    cfg.trialOrderRoot = fullfile(cfg.dataRoot, 'Context Trial Order');
end

function overrides = defaultSubjectOverrides()
    overrides = struct();

    overrides.Sub27 = struct( ...
        'inputSuffix', '_noICA_B31removed.set', ...
        'outputSuffix', '_withICA2_B31removed.set', ...
        'removedChannelLabel', 'PO4');

    overrides.Sub28 = struct( ...
        'inputSuffix', '_noICA_B25removed.set', ...
        'outputSuffix', '_withICA2_B25removed.set', ...
        'removedChannelLabel', 'P2');
end

function pathOut = defaultLookupFile()
    % Try to find standard_1005.elc from the currently loaded EEGLAB copy.
    pathOut = '';
    eeglabFile = which('eeglab');
    if isempty(eeglabFile)
        return;
    end

    eeglabRoot = fileparts(eeglabFile);
    matches = dir(fullfile(eeglabRoot, 'plugins', 'dipfit*', ...
        'standard_BEM', 'elec', 'standard_1005.elc'));

    if ~isempty(matches)
        pathOut = fullfile(matches(1).folder, matches(1).name);
    end
end

function cfg = promptConfig(cfg)
    % Ask for only the project-specific choices.
    cfg.dataRoot = promptDataRoot(cfg.dataRoot);
    cfg = applyDataRoot(cfg);

    cfg.subjects = subjectsFromFolder(cfg.subjectDataRoot);
    cfg.subjects = promptSubjectVector('Subject numbers', cfg.subjects);
    cfg.conditions = promptAllowedNumericVector('Condition numbers (1/4/5)', ...
                                               cfg.conditions, [1 4 5]);
    cfg.runs = promptAllowedNumericVector('Run numbers (1/2)', cfg.runs, [1 2]);
    cfg.overwriteExisting = promptYesNo('Overwrite existing ICA files?', ...
                                        cfg.overwriteExisting);
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
            case {'subjects', 'subjectnumbers'}
                cfg.subjects = value(:)';
            case {'conditions', 'conds'}
                cfg.conditions = value(:)';
            case 'runs'
                cfg.runs = value(:)';
            case 'subjectoverrides'
                cfg.subjectOverrides = value;
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
        cfg.subjects = subjectsFromFolder(cfg.subjectDataRoot);
    end
    validateSubjectVector(cfg.subjects);
    validateAllowedVector(cfg.conditions, [1 4 5], 'conditions');
    validateAllowedVector(cfg.runs, [1 2], 'runs');
end

function printStageIntro()
    fprintf('\nP3: Epoched no-ICA .set files to ICA .set files\n');
    fprintf(['Expected input: inspected *_noICA.set files in each subject folder. ' ...
             'Output: ICA-decomposed *_withICA2*.set files for later manual ICA rejection.\n\n']);
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

    validateSubjectVector(cfg.subjects);
    validateAllowedVector(cfg.conditions, [1 4 5], 'conditions');
    validateAllowedVector(cfg.runs, [1 2], 'runs');

    if exist(cfg.fullChannelLocationFile, 'file') ~= 2
        missingFiles{end+1} = cfg.fullChannelLocationFile; %#ok<AGROW>
    end

    for iSub = 1:numel(cfg.subjects)
        subID = cfg.subjects(iSub);
        subPath = fullfile(cfg.subjectDataRoot, sprintf('Sub%d', subID));
        subjectSettings = settingsForSubject(cfg, subID);

        for iCond = 1:numel(cfg.conditions)
            condNumber = cfg.conditions(iCond);
            for iRun = 1:numel(cfg.runs)
                runNumber = cfg.runs(iRun);
                inputFile = fullfile(subPath, sprintf( ...
                    'Sub%d_Cond%d_run%d%s', ...
                    subID, condNumber, runNumber, subjectSettings.inputSuffix));

                if exist(inputFile, 'file') ~= 2
                    missingFiles{end+1} = inputFile; %#ok<AGROW>
                end
            end
        end
    end

    if ~isempty(missingFiles)
        fprintf('Missing required P3 input file(s):\n');
        printFileList(missingFiles);
        error('P3 cannot start until the missing files exist.');
    end
end

function printStagePlan(cfg)
    nFiles = numel(cfg.subjects) * numel(cfg.conditions) * numel(cfg.runs);

    fprintf('P3 preflight passed.\n');
    fprintf('  Data folder: %s\n', cfg.dataRoot);
    fprintf('  Subject Data folder: %s\n', cfg.subjectDataRoot);
    fprintf('  Subjects: %s\n', mat2str(cfg.subjects));
    fprintf('  Conditions: %s\n', mat2str(cfg.conditions));
    fprintf('  Runs: %s\n', mat2str(cfg.runs));
    fprintf('  Input files found: %d inspected no-ICA .set file(s)\n', nFiles);
    fprintf('  Channel locations: %s\n', cfg.fullChannelLocationFile);
    fprintf('  Overwrite existing outputs: %d\n\n', cfg.overwriteExisting);
end

function tf = confirmProceed()
    tf = promptYesNo('Proceed with P3 processing?', true);
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

function subjectSettings = settingsForSubject(cfg, subID)
    subjectSettings = struct( ...
        'inputSuffix', cfg.defaultInputSuffix, ...
        'outputSuffix', cfg.defaultOutputSuffix, ...
        'removedChannelLabel', '');

    fieldName = sprintf('Sub%d', subID);
    if isstruct(cfg.subjectOverrides) && isfield(cfg.subjectOverrides, fieldName)
        override = cfg.subjectOverrides.(fieldName);
        overrideFields = fieldnames(override);

        for iField = 1:numel(overrideFields)
            thisField = overrideFields{iField};
            subjectSettings.(thisField) = override.(thisField);
        end
    end
end

function chanlocsOut = channelLocationsForDataset(fullChanlocFile, removedChannelLabel, nChannels)
    fullChanlocs = readlocs(fullChanlocFile);

    if isempty(removedChannelLabel)
        chanlocsOut = fullChanlocs;
    else
        labels = {fullChanlocs.labels};
        keep = ~strcmpi(labels, removedChannelLabel);
        chanlocsOut = fullChanlocs(keep);
    end

    if numel(chanlocsOut) ~= nChannels
        error(['Channel-location count mismatch. Expected %d labels for this ' ...
               'dataset, but got %d from the channel-location file.'], ...
              nChannels, numel(chanlocsOut));
    end
end

function ensureEEGLABOnPath()
    % Load EEGLAB only when the needed functions are missing.
    if ~isempty(which('pop_loadset')) && ~isempty(which('pop_runica'))
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

function cfg = resolveLookupFile(cfg)
    % The standard lookup is helpful but should not contain a hard-coded path.
    if isempty(cfg.lookupFile)
        cfg.lookupFile = defaultLookupFile();
    end

    if isempty(cfg.lookupFile)
        cfg.lookupFile = promptExistingFile( ...
            'EEGLAB standard_1005.elc lookup file', '', false);
    end
end

function name = fileNameOnly(filePath)
    [~, baseName, ext] = fileparts(filePath);
    name = [baseName ext];
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

function fileOut = promptExistingFile(label, defaultPath, requireAnswer)
    % Ask only if the standard EEGLAB lookup file was not found automatically.
    msg = inputMessages();
    if nargin < 3
        requireAnswer = false;
    end

    while true
        promptText = promptWithOptionalDefault(label, defaultPath);
        answer = strtrim(input(promptText, 's'));

        if isempty(answer) && requireAnswer
            fprintf('%s\n', msg.requiredFile);
            continue;
        elseif isempty(answer)
            fileOut = defaultPath;
        else
            fileOut = stripOuterQuotes(answer);
        end

        if isempty(fileOut) || exist(fileOut, 'file') == 2
            return;
        end

        fprintf('%s\n  %s\n', msg.invalidFile, fileOut);
    end
end

function values = promptSubjectVector(label, defaultValues)
    % Read subject lists like 27, [27 28], or 1:28.
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
    % Read condition/run choices and reject values outside the expected set.
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

function subjects = subjectsFromFolder(rootPath)
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
    msg.requiredFile = 'Please enter the full path to the requested file.';
    msg.invalidFolder = 'That folder does not exist. Please enter an existing folder.';
    msg.invalidFile = 'That file does not exist. Please enter an existing file.';
    msg.invalidDataStructure = 'That folder exists, but it does not match the required Data folder structure.';
    msg.invalidSubjects = 'Invalid subject input. Use positive whole numbers, for example 27 or [27 28].';
    msg.invalidChoice = 'Invalid input.';
    msg.invalidYesNo = 'Invalid input. Please enter y or n.';
end
