function S244_cohortHighlight(action, target, value)
% Add and operate the saved-figure button for highlighted subjects.

    switch lower(action)
        case 'install'
            installToggle(target, value);
        case 'toggle'
            applyToggle(target, logical(value));
        otherwise
            error('S244_cohortHighlight: unknown action "%s".', action);
    end
end

function installToggle(hFig, subjectNumbers)
    if ~ishghandle(hFig)
        return;
    end

    subjectNumbers = unique(double(subjectNumbers(:)'));
    subjectText = strjoin(cellstr(string(subjectNumbers)), ', ');
    targetNames = lower("Sub" + string(subjectNumbers));
    allLines = findall(hFig, 'Type','line', 'Tag','indivTrace');
    nTargets = 0;

    for i = 1:numel(allLines)
        hLine = allLines(i);
        info = hLine.UserData;
        if ~isstruct(info) || ~isfield(info,'subject')
            continue;
        end

        subjectName = lower(strtrim(string(info.subject)));
        if ~any(subjectName == targetNames)
            continue;
        end

        baseColor = hLine.Color;
        info.cohortHighlightTarget = true;
        info.cohortBaseColor = baseColor;
        info.cohortBaseLineWidth = hLine.LineWidth;
        info.cohortHighlightColor = complementaryColor(baseColor);
        info.cohortHighlightLineWidth = max(2.0, 3 * hLine.LineWidth);
        hLine.UserData = info;
        nTargets = nTargets + 1;
    end

    if nTargets == 0
        warning('S244_cohortHighlight:NoMatchingSubjects', ...
            ['Found %d tagged individual traces, but none matched ', ...
             'subjects %s.'], numel(allLines), subjectText);
        return;
    end

    oldTool = findall(hFig, 'Type','uitoggletool', ...
                      'Tag','cohortHighlightToggle');
    if ~isempty(oldTool)
        delete(oldTool);
    end

    oldButton = findall(hFig, 'Type','uicontrol', ...
                        'Tag','cohortHighlightToggle');
    if ~isempty(oldButton)
        delete(oldButton);
    end

    if numel(subjectNumbers) > 1 ...
            && isequal(subjectNumbers, subjectNumbers(1):subjectNumbers(end))
        offLabel = sprintf('Highlight Sub%d-%d', ...
            subjectNumbers(1), subjectNumbers(end));
    else
        offLabel = 'Highlight selected subjects';
    end

    tooltipText = sprintf('Highlight subjects %s', subjectText);

    uicontrol(hFig, ...
        'Style','togglebutton', ...
        'Units','normalized', ...
        'Position',[0.012 0.952 0.14 0.032], ...
        'String',offLabel, ...
        'FontName','Arial', ...
        'FontSize',10, ...
        'FontWeight','bold', ...
        'BackgroundColor',[0.94 0.94 0.94], ...
        'ForegroundColor',[0.10 0.10 0.10], ...
        'Value',0, ...
        'Tag','cohortHighlightToggle', ...
        'TooltipString',tooltipText, ...
        'UserData',struct('subjectText',subjectText, ...
                          'offLabel',offLabel, ...
                          'onLabel','Restore all traces'), ...
        'Callback',@(src,~) S244_cohortHighlight( ...
            'toggle',src,logical(src.Value)));
end

function applyToggle(tool, isOn)
    hFig = ancestor(tool, 'figure');
    if isempty(hFig) || ~ishghandle(hFig)
        return;
    end

    allLines = findall(hFig, 'Type','line', 'Tag','indivTrace');
    for i = 1:numel(allLines)
        hLine = allLines(i);
        info = hLine.UserData;
        if ~isstruct(info) || ~isfield(info,'cohortHighlightTarget') ...
                || ~info.cohortHighlightTarget
            continue;
        end

        if isOn
            set(hLine, 'Color',info.cohortHighlightColor, ...
                       'LineWidth',info.cohortHighlightLineWidth);
        else
            set(hLine, 'Color',info.cohortBaseColor, ...
                       'LineWidth',info.cohortBaseLineWidth);
        end
    end

    info = tool.UserData;
    if isstruct(info) && isfield(info,'subjectText')
        if isOn
            tool.String = info.onLabel;
            tool.BackgroundColor = [1.00 0.88 0.55];
            tool.TooltipString = sprintf( ...
                'Restore subjects %s', info.subjectText);
        else
            tool.String = info.offLabel;
            tool.BackgroundColor = [0.94 0.94 0.94];
            tool.TooltipString = sprintf( ...
                'Highlight subjects %s', info.subjectText);
        end
    end

    drawnow limitrate;
end

function color = complementaryColor(baseColor)
    rgb = double(baseColor(1:3));
    if max(rgb) - min(rgb) < 0.05
        rgb = [0 0 0];
    else
        rgb = 1 - rgb;
    end
    color = [rgb 1];
end
