function outputFiles = P7_CollectSubjectsByCondition(varargin)

% Expected input: labeled subject files in Data/Subject Data/Sub#.
% Output: condition-level files in Data/EEGData_allSubject_cond#.mat.

printStageIntro();

% Start with the standard Data structure, then ask what to collect.
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
    fprintf('P7 canceled. No files were changed.\n');
    outputFiles = {};
    return;
end

ensureFolder(cfg.dataRoot);

fprintf('\nCollecting matched subject files...\n');
fprintf('Subject Data folder: %s\n', cfg.subjectDataRoot);
fprintf('Output folder: %s\n', cfg.dataRoot);
fprintf('Subjects: %s\n', mat2str(cfg.subjects));
fprintf('Conditions: %s\n\n', mat2str(cfg.conditions));

outputFiles = {};

% Build one group file for each filtering condition.
for iCond = 1:numel(cfg.conditions)
    conditionNumber = cfg.conditions(iCond);
    EEGData = struct();

    fprintf('Condition %d\n', conditionNumber);

    % Add each requested subject into the condition-level structure.
    for iSub = 1:numel(cfg.subjects)
        subID = cfg.subjects(iSub);
        subFolder = fullfile(cfg.subjectDataRoot, sprintf('Sub%d', subID));
        fullFilePath = findLabeledSubjectFile(subFolder, subID, conditionNumber);
        fieldName = sprintf('Sub%d_cond%d', subID, conditionNumber);

        if isempty(fullFilePath)
            warning('Missing labeled subject file for Sub%d Cond%d in %s. Skipping subject.', ...
                    subID, conditionNumber, subFolder);
            continue;
        end

        tempStruct = load(fullFilePath);
        if ~isfield(tempStruct, 'EEGdata_cond')
            warning('No EEGdata_cond field in %s. Skipping subject.', fullFilePath);
            continue;
        end

        EEGData.(fieldName) = tempStruct.EEGdata_cond;
        fprintf('  Added %s\n', fieldName);
    end

    % Save the group file that P8 will average across trials.
    saveFileName = sprintf('EEGData_allSubject_cond%d.mat', conditionNumber);
    savePath = fullfile(cfg.dataRoot, saveFileName);
    save(savePath, 'EEGData', '-v7.3');
    outputFiles{end+1} = savePath; %#ok<AGROW>
    fprintf('Saved: %s\n\n', savePath);
end

fprintf('Done collecting subject files.\n');

end

function cfg = defaultConfig()
    % The user chooses the Data folder; no machine-specific path is assumed.
    cfg.dataRoot = '';
    cfg = applyDataRoot(cfg);
    cfg.subjects = [];
    cfg.conditions = [1 4 5];
    cfg.confirmBeforeRun = true;
end

function cfg = applyDataRoot(cfg)
    % P7 reads subject files and writes group files inside the same Data folder.
    cfg.subjectDataRoot = fullfile(cfg.dataRoot, 'Subject Data');
    cfg.trialOrderRoot = fullfile(cfg.dataRoot, 'Context Trial Order');
end

function filePath = findLabeledSubjectFile(subFolder, subID, conditionNumber)
    candidates = { ...
        sprintf('Sub%d_cond%d_EEGdata.mat', subID, conditionNumber), ...
        sprintf('Sub%d_Cond%d_EEGdata.mat', subID, conditionNumber)};

    filePath = '';
    for i = 1:numel(candidates)
        candidatePath = fullfile(subFolder, candidates{i});
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

function cfg = promptConfig(cfg)
    % Ask for only the project-specific choices.
    cfg.dataRoot = promptDataRoot(cfg.dataRoot);
    cfg = applyDataRoot(cfg);

    defaultSubjects = subjectsFromFolder(cfg.subjectDataRoot);
    cfg.subjects = promptSubjectVector('Subject numbers', defaultSubjects);
    cfg.conditions = promptAllowedNumericVector('Condition numbers (1/4/5)', ...
                                               cfg.conditions, [1 4 5]);
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
end

function printStageIntro()
    fprintf('\nP7: Collect subjects by filtering condition\n');
    fprintf(['Expected input: subject-level Sub#_cond#_EEGdata.mat files. ' ...
             'Output: EEGData_allSubject_cond#.mat group files in the Data folder.\n\n']);
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

    for iSub = 1:numel(cfg.subjects)
        subID = cfg.subjects(iSub);
        subFolder = fullfile(cfg.subjectDataRoot, sprintf('Sub%d', subID));

        for iCond = 1:numel(cfg.conditions)
            conditionNumber = cfg.conditions(iCond);
            fullFilePath = findLabeledSubjectFile(subFolder, subID, conditionNumber);

            if isempty(fullFilePath)
                missingFiles{end+1} = fullfile(subFolder, sprintf( ...
                    'Sub%d_cond%d_EEGdata.mat', subID, conditionNumber)); %#ok<AGROW>
            end
        end
    end

    if ~isempty(missingFiles)
        fprintf('Missing or unusable required P7 subject file(s):\n');
        printFileList(missingFiles);
        error('P7 cannot start until the requested subject-condition files exist.');
    end
end

function printStagePlan(cfg)
    nInputs = numel(cfg.subjects) * numel(cfg.conditions);
    nOutputs = numel(cfg.conditions);

    fprintf('P7 preflight passed.\n');
    fprintf('  Data folder: %s\n', cfg.dataRoot);
    fprintf('  Subject Data folder: %s\n', cfg.subjectDataRoot);
    fprintf('  Subjects: %s\n', mat2str(cfg.subjects));
    fprintf('  Conditions: %s\n', mat2str(cfg.conditions));
    fprintf('  Input subject-condition files found: %d\n', nInputs);
    fprintf('  Output group files to create/update: %d\n\n', nOutputs);
end

function tf = confirmProceed()
    tf = promptYesNo('Proceed with P7 processing?', true);
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
