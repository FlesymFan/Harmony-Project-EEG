function outputFiles = P5_InterpolateRemovedChannels(varargin)
% Expected input: manually ICA-cleaned .set files in Data/Subject Data/Sub#.
% Example input: Data/Subject Data/Sub1/Sub1_Cond1_run1_withICA2_B31removed_cleaned.set

% If no channel was removed, the input can already be *_withICA2_cleaned.set.

% Output: final 64-channel .set/.fdt files in Data/Subject Data/Sub#.
% Example output: Data/Subject Data/Sub1/Sub1_Cond1_run1_withICA2_cleaned.set

% Processing: interpolate any channels removed before ICA, using BioSemi64.loc.

printStageIntro();

% Start with fixed interpolation settings, then ask which files to process.
cfg = defaultConfig();

if nargin == 0
    cfg = promptConfig(cfg);
else
    cfg = parseConfig(cfg, varargin{:});
end

validateRequestedInputs(cfg);
printStagePlan(cfg);
if cfg.confirmBeforeRun && ~confirmProceed()
    fprintf('P5 canceled. No files were changed.\n');
    outputFiles = {};
    return;
end

% EEGLAB is needed for loading .set files and interpolating channels.
ensureEEGLABOnPath();

if exist(cfg.fullChannelLocationFile, 'file') ~= 2
    error('Full channel-location file not found: %s', cfg.fullChannelLocationFile);
end

fullChanlocs = readlocs(cfg.fullChannelLocationFile);
fullLabels = channelLabels(fullChanlocs);
fullLabelsLower = lowerLabels(fullLabels);
expectedNChannels = numel(fullChanlocs);

fprintf('\nInterpolating removed channels back to the final 64-channel layout...\n');
fprintf('Data folder: %s\n', cfg.dataRoot);
fprintf('Subject Data folder: %s\n', cfg.subjectDataRoot);
fprintf('Full channel layout: %s\n', cfg.fullChannelLocationFile);
fprintf('Subjects: %s\n', mat2str(cfg.subjects));
fprintf('Conditions: %s\n', mat2str(cfg.conditions));
fprintf('Runs: %s\n\n', mat2str(cfg.runs));

outputFiles = {};

for iSub = 1:numel(cfg.subjects)
    subID = cfg.subjects(iSub);
    subName = sprintf('Sub%d', subID);
    subPath = fullfile(cfg.subjectDataRoot, subName);

    if ~isfolder(subPath)
        warning('Missing subject folder: %s. Skipping %s.', subPath, subName);
        continue;
    end

    fprintf('=== %s ===\n', subName);

    for iCond = 1:numel(cfg.conditions)
        condNumber = cfg.conditions(iCond);

        for iRun = 1:numel(cfg.runs)
            runNumber = cfg.runs(iRun);
            outFile = fullfile(subPath, sprintf( ...
                'Sub%d_Cond%d_run%d_withICA2_cleaned.set', ...
                subID, condNumber, runNumber));

            if exist(outFile, 'file') == 2
                sourceFile = outFile;
                sourceKind = 'withICA2_cleaned';
            else
                [sourceFile, sourceKind] = findSourceFile(subPath, subID, condNumber, runNumber);
                if isempty(sourceFile)
                    warning('Missing post-ICA source file for Sub%d Cond%d Run%d. Skipping.', ...
                            subID, condNumber, runNumber);
                    continue;
                end
            end

            fprintf('  Cond %d Run %d: loading %s\n', condNumber, runNumber, sourceKind);

            EEG = pop_loadset('filename', fileNameOnly(sourceFile), ...
                              'filepath', fileparts(sourceFile));
            EEG = eeg_checkset(EEG);

            beforeLabels = channelLabels(EEG.chanlocs);
            missingLabels = setdiff(fullLabelsLower, lowerLabels(beforeLabels), 'stable');

            if EEG.nbchan == expectedNChannels && isempty(missingLabels)
                fprintf('    Already has %d channels.\n', expectedNChannels);

                if strcmp(sourceFile, outFile)
                    fprintf('    Final cleaned file is already interpolated. Skipping save.\n');
                    outputFiles{end+1} = outFile; %#ok<AGROW>
                    continue;
                end
            else
                fprintf('    Channels before interpolation: %d\n', EEG.nbchan);
                if ~isempty(missingLabels)
                    fprintf('    Missing channel(s): %s\n', strjoin(missingLabels, ', '));
                end

                if strcmp(sourceFile, outFile)
                    backupExistingDataset(outFile);
                elseif exist(outFile, 'file') == 2 && ~cfg.overwriteExisting
                    warning('Final file exists and overwriteExisting is false: %s. Skipping.', outFile);
                    continue;
                end

                EEG = pop_interp(EEG, fullChanlocs, 'spherical');
                EEG = eeg_checkset(EEG);
            end

            validateFinalLayout(EEG, fullLabelsLower, expectedNChannels, sourceFile);

            EEG.setname = sprintf('Sub%d_Cond%d_run%d_withICA2_cleaned', ...
                                  subID, condNumber, runNumber);
            EEG = pop_saveset(EEG, 'filename', fileNameOnly(outFile), ...
                              'filepath', subPath);

            outputFiles{end+1} = outFile; %#ok<AGROW>
            fprintf('    Saved final cleaned file: %s\n', outFile);
        end
    end

    fprintf('\n');
end

fprintf('Done interpolating removed channels.\n');

end

function cfg = defaultConfig()
    % The user chooses the Data folder; no machine-specific path is assumed.
    scriptDir = fileparts(mfilename('fullpath'));

    cfg.dataRoot = '';
    cfg = applyDataRoot(cfg);
    cfg.fullChannelLocationFile = fullfile(scriptDir, 'BioSemi64.loc');
    cfg.subjects = [];
    cfg.conditions = [1 4 5];
    cfg.runs = [1 2];
    cfg.overwriteExisting = false;
    cfg.confirmBeforeRun = true;
end

function cfg = applyDataRoot(cfg)
    % The standardized Data folder gives P5 its subject folders.
    cfg.subjectDataRoot = fullfile(cfg.dataRoot, 'Subject Data');
    cfg.trialOrderRoot = fullfile(cfg.dataRoot, 'Context Trial Order');
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
    cfg.overwriteExisting = promptYesNo('Overwrite existing final cleaned files?', ...
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
    fprintf('\nP5: Interpolate removed channels\n');
    fprintf(['Expected input: manually ICA-cleaned .set files, usually *_withICA2_cleaned.set. ' ...
             'Output: final cleaned files restored to the full 64-channel BioSemi layout.\n\n']);
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

        for iCond = 1:numel(cfg.conditions)
            condNumber = cfg.conditions(iCond);
            for iRun = 1:numel(cfg.runs)
                runNumber = cfg.runs(iRun);
                outFile = fullfile(subPath, sprintf( ...
                    'Sub%d_Cond%d_run%d_withICA2_cleaned.set', ...
                    subID, condNumber, runNumber));

                if exist(outFile, 'file') ~= 2
                    [sourceFile, ~] = findSourceFile(subPath, subID, condNumber, runNumber);
                    if isempty(sourceFile)
                        missingFiles{end+1} = outFile; %#ok<AGROW>
                    end
                end
            end
        end
    end

    if ~isempty(missingFiles)
        fprintf('Missing required P5 source file(s):\n');
        printFileList(missingFiles);
        error('P5 cannot start until the missing cleaned/interpolatable .set files exist.');
    end
end

function printStagePlan(cfg)
    nFiles = numel(cfg.subjects) * numel(cfg.conditions) * numel(cfg.runs);

    fprintf('P5 preflight passed.\n');
    fprintf('  Data folder: %s\n', cfg.dataRoot);
    fprintf('  Subject Data folder: %s\n', cfg.subjectDataRoot);
    fprintf('  Subjects: %s\n', mat2str(cfg.subjects));
    fprintf('  Conditions: %s\n', mat2str(cfg.conditions));
    fprintf('  Runs: %s\n', mat2str(cfg.runs));
    fprintf('  Source files found: %d cleaned/interpolatable .set file(s)\n', nFiles);
    fprintf('  Full channel layout: %s\n', cfg.fullChannelLocationFile);
    fprintf('  Overwrite existing final cleaned files: %d\n\n', cfg.overwriteExisting);
end

function tf = confirmProceed()
    tf = promptYesNo('Proceed with P5 processing?', true);
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

function [sourceFile, sourceKind] = findSourceFile(subPath, subID, condNumber, runNumber)
    sourceFile = '';
    sourceKind = '';

    bases = { ...
        sprintf('Sub%d_Cond%d_run%d_withICA2_B31removed_cleaned', subID, condNumber, runNumber), 'withICA2_B31removed_cleaned'; ...
        sprintf('Sub%d_Cond%d_run%d_withICA2_B25removed_cleaned', subID, condNumber, runNumber), 'withICA2_B25removed_cleaned'; ...
        sprintf('Sub%d_Cond%d_run%d_withICA2_B31removed',         subID, condNumber, runNumber), 'withICA2_B31removed'; ...
        sprintf('Sub%d_Cond%d_run%d_withICA2_B25removed',         subID, condNumber, runNumber), 'withICA2_B25removed'; ...
        sprintf('Sub%d_cond%d_run%d_withICA2_B31removed_cleaned', subID, condNumber, runNumber), 'withICA2_B31removed_cleaned'; ...
        sprintf('Sub%d_cond%d_run%d_withICA2_B25removed_cleaned', subID, condNumber, runNumber), 'withICA2_B25removed_cleaned'; ...
        sprintf('Sub%d_cond%d_run%d_withICA2_B31removed',         subID, condNumber, runNumber), 'withICA2_B31removed'; ...
        sprintf('Sub%d_cond%d_run%d_withICA2_B25removed',         subID, condNumber, runNumber), 'withICA2_B25removed'};

    for i = 1:size(bases, 1)
        candidate = fullfile(subPath, [bases{i, 1} '.set']);
        if exist(candidate, 'file') == 2
            sourceFile = candidate;
            sourceKind = bases{i, 2};
            return;
        end
    end
end

function backupExistingDataset(setFile)
    [folderPath, baseName, ext] = fileparts(setFile);
    backupSet = fullfile(folderPath, [baseName '_beforeInterpolation' ext]);

    if exist(backupSet, 'file') ~= 2
        copyfile(setFile, backupSet);
        fprintf('    Backed up pre-interpolation SET: %s\n', backupSet);
    end

    fdtFile = fullfile(folderPath, [baseName '.fdt']);
    backupFdt = fullfile(folderPath, [baseName '_beforeInterpolation.fdt']);

    if exist(fdtFile, 'file') == 2 && exist(backupFdt, 'file') ~= 2
        copyfile(fdtFile, backupFdt);
        fprintf('    Backed up pre-interpolation FDT: %s\n', backupFdt);
    end
end

function validateFinalLayout(EEG, fullLabelsLower, expectedNChannels, sourceFile)
    if EEG.nbchan ~= expectedNChannels
        error('Expected %d channels after interpolation, but got %d in %s.', ...
              expectedNChannels, EEG.nbchan, sourceFile);
    end

    finalLabels = channelLabels(EEG.chanlocs);
    missingLabels = setdiff(fullLabelsLower, lowerLabels(finalLabels), 'stable');

    if ~isempty(missingLabels)
        error('Final file is still missing channel(s): %s', ...
              strjoin(missingLabels, ', '));
    end
end

function labelsLower = lowerLabels(labels)
    labelsLower = cellfun(@lower, labels, 'UniformOutput', false);
end

function labels = channelLabels(chanlocs)
    labels = cell(1, numel(chanlocs));

    for i = 1:numel(chanlocs)
        if isfield(chanlocs, 'labels') && ~isempty(chanlocs(i).labels)
            labels{i} = strtrim(char(chanlocs(i).labels));
        else
            labels{i} = sprintf('Chan%d', i);
        end
    end
end

function ensureEEGLABOnPath()
    % Load EEGLAB only when interpolation functions are missing.
    if ~isempty(which('pop_loadset')) && ~isempty(which('pop_interp'))
        return;
    end

    eeglabDir = strtrim(input('EEGLAB folder containing eeglab.m [already on path]: ', 's'));
    if ~isempty(eeglabDir)
        addpath(eeglabDir);
    end

    if isempty(which('eeglab'))
        error('EEGLAB is not on the MATLAB path. Add EEGLAB, then rerun this function.');
    end

    eeglab nogui;

    if isempty(which('pop_loadset')) || isempty(which('pop_interp'))
        error('EEGLAB loaded, but pop_loadset/pop_interp is still unavailable.');
    end
end

function name = fileNameOnly(pathIn)
    [~, baseName, ext] = fileparts(pathIn);
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
    msg.invalidFolder = 'That folder does not exist. Please enter an existing folder.';
    msg.invalidDataStructure = 'That folder exists, but it does not match the required Data folder structure.';
    msg.invalidSubjects = 'Invalid subject input. Use positive whole numbers, for example 27 or [27 28].';
    msg.invalidChoice = 'Invalid input.';
    msg.invalidYesNo = 'Invalid input. Please enter y or n.';
end
