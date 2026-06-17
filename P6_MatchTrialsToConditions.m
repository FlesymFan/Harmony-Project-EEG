function outputFiles = P6_MatchTrialsToConditions(varargin)
% Adapted from original script: Context_EEGAnalyses_Step3.m

% Expected EEG input: cleaned/interpolated run files in Data/Subject Data/Sub#.
% Example EEG input: Data/Subject Data/Sub1/Sub1_Cond1_run1_withICA2_cleaned.set

% Expected trial-order input: matching .mat files in Data/Context Trial Order/Sub#.
% Example trial-order input: Data/Context Trial Order/Sub1/Sub1_Cond1_run1.mat

% Output: subject-level condition .mat files in Data/Subject Data/Sub#.
% Example output: Data/Subject Data/Sub1/Sub1_cond1_EEGdata.mat

printStageIntro();

% Start with fixed matching settings, then ask which files to process.
cfg = defaultConfig();

if nargin == 0
    cfg = promptConfig(cfg);
else
    cfg = parseConfig(cfg, varargin{:});
end

if isempty(cfg.subjects)
    cfg.subjects = subjectsFromFolder(cfg.subjectDataRoot);
end

validateRequestedInputs(cfg);
printStagePlan(cfg);
if cfg.confirmBeforeRun && ~confirmProceed()
    fprintf('P6 canceled. No files were changed.\n');
    outputFiles = {};
    return;
end

categoryFields = trialCategoryFields();
ensureFolder(cfg.subjectDataRoot);

fprintf('\nChecking/creating labeled subject EEGdata files...\n');
fprintf('Subject Data folder: %s\n', cfg.subjectDataRoot);
fprintf('Trial-order folder:  %s\n', cfg.trialOrderRoot);
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

    fprintf('=== %s ===\n', subName);

    for iCond = 1:numel(cfg.conditions)
        condNumber = cfg.conditions(iCond);
        outFile = canonicalLabeledFile(subPath, subID, condNumber);
        existingFile = findLabeledSubjectFile(subPath, subID, condNumber);
        [canBuildFromCleanedRuns, missingRunInputs] = haveAllRunInputs(cfg, subPath, subID, condNumber);

        if ~isempty(existingFile) && ~canBuildFromCleanedRuns
            fprintf('  Cond %d: existing matched file detected and verified: %s\n', ...
                    condNumber, existingFile);
            fprintf('    Cleaned .set/trial-order inputs are incomplete, so keeping the existing matched file.\n');
            outputFiles{end+1} = existingFile; %#ok<AGROW>
            continue;
        end

        if isempty(existingFile)
            fprintf('  Cond %d: no existing matched file detected.\n', condNumber);
            fprintf('    Cleaned .set and trial-order files found. Generating %s.\n', getFileName(outFile));
        else
            fprintf('  Cond %d: existing matched file detected and verified: %s\n', ...
                    condNumber, existingFile);
            fprintf('    Cleaned .set and trial-order files were also found, so this file can be regenerated.\n');
            if ~shouldOverwriteExisting(cfg, subID, condNumber, existingFile)
                fprintf('    Keeping existing matched file.\n');
                outputFiles{end+1} = existingFile; %#ok<AGROW>
                continue;
            end
            fprintf('    Rebuilding and overwriting with %s.\n', getFileName(outFile));
        end

        EEGdata_cond = struct();
        meta = initMeta(cfg, subID, condNumber);

        fprintf('  Cond %d\n', condNumber);
        for iRun = 1:numel(cfg.runs)
            runNumber = cfg.runs(iRun);

            [data, sourceInfo] = loadRunData(cfg, subPath, subID, condNumber, runNumber);

            if cfg.keepFirst64Channels && size(data, 1) > 64
                data = data(1:64, :, :);
            end

            nTrials = size(data, 3);
            [trialOrder, trialOrderFile] = loadTrialOrder( ...
                cfg.trialOrderRoot, subID, condNumber, runNumber, nTrials);

            for iField = 1:numel(categoryFields)
                fieldName = categoryFields{iField};
                thisData = data(:, :, trialOrder.(fieldName));

                if iRun == 1
                    EEGdata_cond.(fieldName) = thisData;
                else
                    EEGdata_cond.(fieldName) = cat(3, EEGdata_cond.(fieldName), thisData);
                end

                meta.categoryCountsByRun.(fieldName)(iRun) = numel(trialOrder.(fieldName));
            end

            meta.sourceFiles{iRun} = sourceInfo.path;
            meta.sourceKinds{iRun} = sourceInfo.kind;
            meta.trialOrderFiles{iRun} = trialOrderFile;

            if isfield(sourceInfo, 'srate'), meta.srate = sourceInfo.srate; end
            if isfield(sourceInfo, 'times'), meta.times = sourceInfo.times; end
            if isfield(sourceInfo, 'channelLabels'), meta.channelLabels = sourceInfo.channelLabels; end

            fprintf('    Run %d: %s, %d trials\n', runNumber, sourceInfo.kind, nTrials);
        end

        validateAndPrintCounts(EEGdata_cond, categoryFields);
        save(outFile, 'EEGdata_cond', 'meta', '-v7.3');
        outputFiles{end+1} = outFile; %#ok<AGROW>
        fprintf('    Saved: %s\n\n', outFile);
    end
end

fprintf('Done checking/creating labeled subject EEGdata files.\n');

end

function cfg = defaultConfig()
    % The user chooses the Data folder; no machine-specific path is assumed.
    cfg.dataRoot = '';
    cfg = applyDataRoot(cfg);
    cfg.subjects = [];
    cfg.conditions = [1 4 5];
    cfg.runs = [1 2];
    cfg.keepFirst64Channels = true;
    cfg.overwriteExisting = [];
    cfg.confirmBeforeRun = true;
end

function cfg = applyDataRoot(cfg)
    % The standardized Data folder gives P6 both EEG data and trial orders.
    cfg.subjectDataRoot = fullfile(cfg.dataRoot, 'Subject Data');
    cfg.trialOrderRoot = fullfile(cfg.dataRoot, 'Context Trial Order');
end

function cfg = promptConfig(cfg)
    % Ask for only the project-specific choices.
    cfg.dataRoot = promptDataRoot(cfg.dataRoot);
    cfg = applyDataRoot(cfg);

    defaultSubjects = subjectsFromFolder(cfg.subjectDataRoot);
    cfg.subjects = promptSubjectVector('Subject numbers', defaultSubjects);
    cfg.conditions = promptAllowedNumericVector('Condition numbers (1/4/5)', ...
                                               cfg.conditions, [1 4 5]);
    cfg.runs = promptAllowedNumericVector('Run numbers (1/2)', cfg.runs, [1 2]);
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
    fprintf('\nP6: Match trials to experimental conditions\n');
    fprintf('Expected input: cleaned EEG .set run files plus matching Sub#_Cond#_run#.mat trial-order files.\n');
    fprintf('Output: subject-level Sub#_cond#_EEGdata.mat files with trials split into condition fields.\n\n');
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

    for iSub = 1:numel(cfg.subjects)
        subID = cfg.subjects(iSub);
        subPath = fullfile(cfg.subjectDataRoot, sprintf('Sub%d', subID));

        if ~isfolder(subPath)
            missingFiles{end+1} = subPath; %#ok<AGROW>
            continue;
        end

        for iCond = 1:numel(cfg.conditions)
            condNumber = cfg.conditions(iCond);
            existingFile = findLabeledSubjectFile(subPath, subID, condNumber);
            [canBuildFromCleanedRuns, missingRunInputs] = haveAllRunInputs(cfg, subPath, subID, condNumber);

            if isempty(existingFile) && ~canBuildFromCleanedRuns
                missingFiles = [missingFiles, missingRunInputs]; %#ok<AGROW>
            end
        end
    end

    if ~isempty(missingFiles)
        fprintf('Missing required P6 input file(s):\n');
        printFileList(missingFiles);
        error('P6 cannot start until the missing EEG/trial-order files exist.');
    end
end

function printStagePlan(cfg)
    fprintf('P6 input check passed.\n');
    fprintf('  Data folder: %s\n', cfg.dataRoot);
    fprintf('  Subject Data folder: %s\n', cfg.subjectDataRoot);
    fprintf('  Context Trial Order folder: %s\n', cfg.trialOrderRoot);
    fprintf('  Subjects: %s\n', mat2str(cfg.subjects));
    fprintf('  Conditions: %s\n', mat2str(cfg.conditions));
    fprintf('  Runs: %s\n\n', mat2str(cfg.runs));
end

function [tf, missingInputs] = haveAllRunInputs(cfg, subPath, subID, condNumber)
    missingInputs = {};

    for iRun = 1:numel(cfg.runs)
        runNumber = cfg.runs(iRun);
        sourceFile = cleanedSetFile(subPath, subID, condNumber, runNumber);
        trialOrderFile = findTrialOrderFile(cfg.trialOrderRoot, subID, condNumber, runNumber);

        if exist(sourceFile, 'file') ~= 2
            missingInputs{end+1} = sprintf( ...
                'Missing cleaned EEG SET file: %s', sourceFile); %#ok<AGROW>
        end

        if isempty(trialOrderFile)
            missingInputs{end+1} = sprintf( ...
                'Missing trial-order file: %s', ...
                trialOrderFileName(cfg.trialOrderRoot, subID, condNumber, runNumber)); %#ok<AGROW>
        end
    end

    tf = isempty(missingInputs);
end

function tf = shouldOverwriteExisting(cfg, subID, condNumber, existingFile)
    if ~isempty(cfg.overwriteExisting)
        tf = cfg.overwriteExisting;
        return;
    end

    fprintf('    Existing matched file: %s\n', existingFile);
    tf = promptYesNo(sprintf( ...
        '    Overwrite Sub%d Cond%d matched file from cleaned SET inputs?', ...
        subID, condNumber), false);
end

function tf = confirmProceed()
    tf = promptYesNo('Proceed with P6 processing?', true);
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

function meta = initMeta(cfg, subID, condNumber)
    meta = struct();
    meta.subject = subID;
    meta.conditionNumber = condNumber;
    meta.runs = cfg.runs;
    meta.dataRoot = cfg.dataRoot;
    meta.subjectDataRoot = cfg.subjectDataRoot;
    meta.trialOrderRoot = cfg.trialOrderRoot;
    meta.keepFirst64Channels = cfg.keepFirst64Channels;
    meta.createdBy = mfilename;
    meta.createdOn = char(datetime('now'));
    meta.sourceFiles = cell(1, numel(cfg.runs));
    meta.sourceKinds = cell(1, numel(cfg.runs));
    meta.trialOrderFiles = cell(1, numel(cfg.runs));
    meta.categoryCountsByRun = struct();
end

function fields = trialCategoryFields()
    fields = {'UnexpwithSensPrim', ...
              'UnexpwithoutSensPrim', ...
              'Atonal', ...
              'ExpwithSensPrim', ...
              'ExpwithoutSensPrim'};
end

function [data, sourceInfo] = loadRunData(cfg, subPath, subID, condNumber, runNumber)
    sourcePath = cleanedSetFile(subPath, subID, condNumber, runNumber);

    if exist(sourcePath, 'file') ~= 2
        error('Missing source EEG file for Sub%d Cond%d Run%d in %s.', ...
              subID, condNumber, runNumber, subPath);
    end

    sourceInfo = struct();
    sourceInfo.path = sourcePath;
    sourceInfo.kind = cleanedSetKind(sourcePath);

    ensureEEGLABOnPath();
    EEG = pop_loadset('filename', getFileName(sourcePath), 'filepath', fileparts(sourcePath));
    EEG = eeg_checkset(EEG);
    data = EEG.data;

    if isfield(EEG, 'srate'), sourceInfo.srate = EEG.srate; end
    if isfield(EEG, 'times'), sourceInfo.times = EEG.times; end
    if isfield(EEG, 'chanlocs') && isfield(EEG.chanlocs, 'labels')
        sourceInfo.channelLabels = {EEG.chanlocs.labels};
    end

    if ndims(data) ~= 3
        error('Expected 3D epoched EEG data in %s, but got %d dimensions.', ...
              sourcePath, ndims(data));
    end
end

function [trialOrder, trialOrderFile] = loadTrialOrder(trialOrderRoot, subID, condNumber, runNumber, nTrials)
    trialOrderFile = findTrialOrderFile(trialOrderRoot, subID, condNumber, runNumber);

    if isempty(trialOrderFile)
        error('Missing trial-order file for Sub%d Cond%d Run%d in %s.', ...
              subID, condNumber, runNumber, fullfile(trialOrderRoot, sprintf('Sub%d', subID)));
    end

    loaded = load(trialOrderFile);
    if isfield(loaded, 'Trialorder')
        trialOrder = loaded.Trialorder;
    elseif isfield(loaded, 'fname')
        trialOrder = trialOrderFromFname(loaded.fname);
    else
        error('Trial-order file has neither Trialorder nor fname: %s', trialOrderFile);
    end

    validateTrialOrder(trialOrder, nTrials, trialOrderFile);
end

function trialOrderFile = findTrialOrderFile(trialOrderRoot, subID, condNumber, runNumber)
    trialOrderFile = trialOrderFileName(trialOrderRoot, subID, condNumber, runNumber);

    if exist(trialOrderFile, 'file') ~= 2
        trialOrderFile = '';
    end
end

function filePath = cleanedSetFile(subPath, subID, condNumber, runNumber)
    candidates = { ...
        fullfile(subPath, sprintf( ...
            'Sub%d_Cond%d_run%d_withICA2_cleaned.set', ...
            subID, condNumber, runNumber)), ...
        fullfile(subPath, sprintf( ...
            'Sub%d_cond%d_run%d_withICA2_cleaned.set', ...
            subID, condNumber, runNumber)), ...
        fullfile(subPath, sprintf( ...
            'Sub%d_Cond%d_run%d_withICA_cleaned.set', ...
            subID, condNumber, runNumber)), ...
        fullfile(subPath, sprintf( ...
            'Sub%d_cond%d_run%d_withICA_cleaned.set', ...
            subID, condNumber, runNumber))};

    filePath = firstExistingOrCanonical(candidates);
end

function kind = cleanedSetKind(sourcePath)
    if contains(lower(sourcePath), 'withica2_cleaned')
        kind = 'withICA2_cleaned_set';
    else
        kind = 'withICA_cleaned_set';
    end
end

function filePath = trialOrderFileName(trialOrderRoot, subID, condNumber, runNumber)
    orderPath = fullfile(trialOrderRoot, sprintf('Sub%d', subID));
    candidates = { ...
        fullfile(orderPath, sprintf('Sub%d_Cond%d_run%d.mat', subID, condNumber, runNumber)), ...
        fullfile(orderPath, sprintf('Sub%d_cond%d_run%d.mat', subID, condNumber, runNumber))};

    filePath = firstExistingOrCanonical(candidates);
end

function filePath = firstExistingOrCanonical(candidates)
    filePath = candidates{1};

    for i = 1:numel(candidates)
        if exist(candidates{i}, 'file') == 2
            filePath = candidates{i};
            return;
        end
    end
end

function filePath = canonicalLabeledFile(subPath, subID, condNumber)
    filePath = fullfile(subPath, sprintf('Sub%d_cond%d_EEGdata.mat', subID, condNumber));
end

function filePath = findLabeledSubjectFile(subPath, subID, condNumber)
    candidates = { ...
        sprintf('Sub%d_cond%d_EEGdata.mat', subID, condNumber), ...
        sprintf('Sub%d_Cond%d_EEGdata.mat', subID, condNumber)};

    filePath = '';
    for i = 1:numel(candidates)
        candidatePath = fullfile(subPath, candidates{i});
        if exist(candidatePath, 'file') && hasUsableEEGdataCond(candidatePath)
            filePath = candidatePath;
            return;
        end
    end
end

function tf = hasUsableEEGdataCond(matFile)
    minUsableBytes = 1000000;

    try
        fileInfo = dir(matFile);
        if isempty(fileInfo) || fileInfo.bytes < minUsableBytes
            tf = false;
            return;
        end

        info = whos('-file', matFile);
        names = {info.name};
        tf = any(strcmp(names, 'EEGdata_cond'));
    catch
        tf = false;
    end
end

function trialOrder = trialOrderFromFname(fname)
    if isstring(fname)
        names = cellstr(fname);
    elseif iscell(fname)
        names = fname(:);
    else
        error('fname must be a cell array or string array.');
    end

    trialOrder = struct();
    trialOrder.UnexpwithSensPrim = [];
    trialOrder.UnexpwithoutSensPrim = [];
    trialOrder.Atonal = [];
    trialOrder.ExpwithSensPrim = [];
    trialOrder.ExpwithoutSensPrim = [];

    for i = 1:numel(names)
        thisName = lower(char(names{i}));

        if contains(thisName, 'atonal') || contains(thisName, '_xsp_') || contains(thisName, '_xhv_')
            trialOrder.Atonal(end+1) = i; %#ok<AGROW>
        elseif contains(thisName, '_ysp_') && contains(thisName, '_yhv_')
            trialOrder.UnexpwithSensPrim(end+1) = i; %#ok<AGROW>
        elseif contains(thisName, '_ysp_') && contains(thisName, '_nhv_')
            trialOrder.ExpwithSensPrim(end+1) = i; %#ok<AGROW>
        elseif contains(thisName, '_nsp_') && contains(thisName, '_yhv_')
            trialOrder.UnexpwithoutSensPrim(end+1) = i; %#ok<AGROW>
        elseif contains(thisName, '_nsp_') && contains(thisName, '_nhv_')
            trialOrder.ExpwithoutSensPrim(end+1) = i; %#ok<AGROW>
        else
            error('Cannot classify trial %d from filename: %s', i, char(names{i}));
        end
    end
end

function validateTrialOrder(trialOrder, nTrials, sourceFile)
    requiredFields = trialCategoryFields();
    used = [];

    for i = 1:numel(requiredFields)
        fieldName = requiredFields{i};
        if ~isfield(trialOrder, fieldName)
            error('Missing %s in trial order: %s', fieldName, sourceFile);
        end

        idx = trialOrder.(fieldName);
        if isempty(idx)
            error('Empty %s in trial order: %s', fieldName, sourceFile);
        end

        if any(idx < 1) || any(idx > nTrials)
            error('%s has indices outside 1..%d in %s.', fieldName, nTrials, sourceFile);
        end

        used = [used, idx(:)']; %#ok<AGROW>
    end

    if numel(unique(used)) ~= numel(used)
        error('Some trials are assigned to more than one category in %s.', sourceFile);
    end

    if numel(used) ~= nTrials
        error('Trial-order file assigns %d trials, but EEG data has %d trials: %s', ...
              numel(used), nTrials, sourceFile);
    end
end

function validateAndPrintCounts(EEGdata_cond, categoryFields)
    fprintf('    Final trial counts:\n');
    for i = 1:numel(categoryFields)
        fieldName = categoryFields{i};
        nTrials = size(EEGdata_cond.(fieldName), 3);
        fprintf('      %-25s %d\n', fieldName, nTrials);
    end
end

function ensureEEGLABOnPath()
    % Load EEGLAB only when .set loading is needed.
    if ~isempty(which('pop_loadset'))
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

    if isempty(which('pop_loadset'))
        error('EEGLAB loaded, but pop_loadset is still unavailable.');
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

function ensureFolder(pathIn)
    if ~isfolder(pathIn)
        mkdir(pathIn);
    end
end

function dataRoot = promptDataRoot(defaultPath)
    % The selected Data folder must contain Subject Data and Context Trial Order.
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

function name = getFileName(pathIn)
    [~, baseName, ext] = fileparts(pathIn);
    name = [baseName ext];
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
