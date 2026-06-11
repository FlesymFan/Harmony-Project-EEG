function cfg = configBuilder(cfg)
% Interactive configuration builder for subject-wise and multi-subject topoplots.

fprintf('\n[Topoplot configuration]\n');

if ~isfield(cfg, 'plotMode') || isempty(cfg.plotMode)
    cfg.plotMode = 'single';
end
if ~isfield(cfg, 'subjectIndices') || isempty(cfg.subjectIndices)
    cfg.subjectIndices = 1;
end

defaultModeChoice = modeChoiceFromName(cfg.plotMode);
resp = strtrim(input(sprintf('Plot mode: 1 = single subject, 2 = multi-subject [%d]: ', ...
                             defaultModeChoice), 's'));
if isempty(resp)
    modeChoice = defaultModeChoice;
else
    modeChoice = str2double(resp);
end
cfg.plotMode = modeNameFromChoice(modeChoice);

if strcmp(cfg.plotMode, 'single')
    defaultSubject = cfg.subjectIndices(1);
    resp = strtrim(input(sprintf('Subject index [%d]: ', defaultSubject), 's'));
    if isempty(resp)
        subjectIndices = defaultSubject;
    else
        subjectIndices = str2num(resp); %#ok<ST2NM>
    end

    if numel(subjectIndices) ~= 1
        error('configBuilder: single-subject mode needs exactly one subject index.');
    end
else
    defaultSubjects = defaultMultiSubjects(cfg);
    resp = strtrim(input(sprintf('Subject indices, e.g. 1:15 or [1 2 3] [%s]: ', ...
                                 subjectInputText(defaultSubjects)), 's'));
    if isempty(resp)
        subjectIndices = defaultSubjects;
    else
        subjectIndices = str2num(resp); %#ok<ST2NM>
    end
end

cfg.subjectIndices = validateSubjectIndices(subjectIndices);

resp = strtrim(input(sprintf('Filtering condition 1/4/5 [%d]: ', cfg.conditionNumber), 's'));
if ~isempty(resp)
    condNum = str2double(resp);
    if ~ismember(condNum, [1 4 5])
        error('configBuilder: conditionNumber must be 1, 4, or 5.');
    end
    cfg.conditionNumber = condNum;
end

resp = strtrim(input(sprintf('Topoplot window start [%d]: ', ...
                             cfg.windowStart_remap), 's'));
if ~isempty(resp)
    cfg.windowStart_remap = str2double(resp);
end

resp = strtrim(input(sprintf('Topoplot window width [%d]: ', ...
                             cfg.windowWidth_remap), 's'));
if ~isempty(resp)
    cfg.windowWidth_remap = str2double(resp);
end

fprintf('\nTopoplot conditions/contrasts:\n');
fprintf('  1 = Exp_withSP\n');
fprintf('  2 = Unexp_withSP\n');
fprintf('  3 = Diff_withSP    (Unexpected with SP - Expected with SP)\n');
fprintf('  4 = Exp_noSP\n');
fprintf('  5 = Unexp_noSP\n');
fprintf('  6 = Diff_noSP      (Unexpected without SP - Expected without SP)\n');
fprintf('  7 = Atonal\n');

defaultChoices = choicesFromConditions(cfg.plotConditions);
resp = strtrim(input(sprintf('Choose one or more numbers, e.g. 3 or [1 2 3] [%s]: ', ...
                             mat2str(defaultChoices)), 's'));
if isempty(resp)
    choices = defaultChoices;
else
    choices = str2num(resp); %#ok<ST2NM>
end

cfg.plotConditions = conditionsFromChoices(choices);
fprintf('\nSelected plot conditions: %s\n\n', strjoin(cfg.plotConditions, ', '));
end

function choice = modeChoiceFromName(modeName)
    if strcmpi(modeName, 'multi')
        choice = 2;
    else
        choice = 1;
    end
end

function modeName = modeNameFromChoice(choice)
    switch choice
        case 1
            modeName = 'single';
        case 2
            modeName = 'multi';
        otherwise
            error('configBuilder: plot mode must be 1 or 2.');
    end
end

function subjectIndices = defaultMultiSubjects(cfg)
    if isfield(cfg, 'subjectIndices') && numel(cfg.subjectIndices) > 1
        subjectIndices = cfg.subjectIndices;
    else
        subjectIndices = 1:15;
    end
end

function text = subjectInputText(subjectIndices)
    subjectIndices = subjectIndices(:)';
    if numel(subjectIndices) > 1 && isequal(subjectIndices, subjectIndices(1):subjectIndices(end))
        text = sprintf('%d:%d', subjectIndices(1), subjectIndices(end));
    else
        text = mat2str(subjectIndices);
    end
end

function subjectIndices = validateSubjectIndices(subjectIndices)
    if isempty(subjectIndices) || ~isnumeric(subjectIndices)
        error('configBuilder: subject indices must be numeric.');
    end

    subjectIndices = subjectIndices(:)';

    if any(~isfinite(subjectIndices)) || any(subjectIndices < 1) || ...
       any(subjectIndices ~= round(subjectIndices))
        error('configBuilder: subject indices must be positive integers.');
    end
end

function names = conditionsFromChoices(choices)
    allNames = {'Exp_withSP', 'Unexp_withSP', 'Diff_withSP', ...
                'Exp_noSP', 'Unexp_noSP', 'Diff_noSP', 'Atonal'};

    if isempty(choices) || any(~ismember(choices, 1:numel(allNames)))
        error('configBuilder: condition choices must be numbers 1..7.');
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
