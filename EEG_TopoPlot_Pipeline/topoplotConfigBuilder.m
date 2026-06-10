function cfg = topoplotConfigBuilder(cfg)
% Interactive configuration builder for single-subject topoplots.

fprintf('\n[Single-subject topoplot configuration]\n');

resp = strtrim(input(sprintf('Subject index [%d]: ', cfg.subjectIndex), 's'));
if ~isempty(resp)
    cfg.subjectIndex = str2double(resp);
end

resp = strtrim(input(sprintf('Filtering condition 1/4/5 [%d]: ', cfg.conditionNumber), 's'));
if ~isempty(resp)
    condNum = str2double(resp);
    if ~ismember(condNum, [1 4 5])
        error('topoplotConfigBuilder: conditionNumber must be 1, 4, or 5.');
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

function names = conditionsFromChoices(choices)
    allNames = {'Exp_withSP', 'Unexp_withSP', 'Diff_withSP', ...
                'Exp_noSP', 'Unexp_noSP', 'Diff_noSP', 'Atonal'};

    if isempty(choices) || any(~ismember(choices, 1:numel(allNames)))
        error('topoplotConfigBuilder: condition choices must be numbers 1..7.');
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
