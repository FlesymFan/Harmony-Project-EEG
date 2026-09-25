function S245_FigureDeck(figDir)
% Browse saved ERP figures by category and open them as a presentation deck.

    pipelineDir = fileparts(mfilename('fullpath'));

    if nargin < 1 || isempty(figDir)
        figDir = fullfile(pipelineDir, 'figures');
    end

    figDir = char(string(figDir));
    if ~isfolder(figDir)
        selectedDir = uigetdir(pipelineDir, 'Select the folder containing ERP .fig files');
        if isequal(selectedDir, 0)
            fprintf('Figure browser cancelled.\n');
            return;
        end
        figDir = selectedDir;
    end

    files = dir(fullfile(figDir, '*.fig'));
    if isempty(files)
        error('S245_FigureDeck:NoFigures', ...
              'No .fig files were found in %s.', figDir);
    end

    files = sortFigureFiles(files);
    metadata = parseFigureMetadata(files);
    if any(~metadata.valid)
        badNames = string({files(~metadata.valid).name});
        error('S245_FigureDeck:UnexpectedFilename', ...
              'These filenames do not match the ERP batch format:\n%s', ...
              strjoin(cellstr(badNames), '\n'));
    end

    oldBrowsers = findall(0, 'Type','figure', 'Tag','S245FigureBrowser');
    if ~isempty(oldBrowsers)
        close(oldBrowsers);
    end

    state = struct();
    state.figDir = figDir;
    state.files = files;
    state.metadata = metadata;
    state.currentFigure = [];

    hBrowser = buildBrowser(state);
    refreshBrowser(hBrowser);

    fprintf('Figure browser: %d files in %s\n', numel(files), figDir);
    fprintf(['Choose filters, then double-click a result, open one deck, ' ...
             'or compare multiple selections.\n']);
end

function files = sortFigureFiles(files)
% Sort the leading figure numbers numerically instead of alphabetically.

    names = lower(string({files.name}));
    [~, alphabeticOrder] = sort(names);
    files = files(alphabeticOrder);

    prefix = inf(numel(files), 1);
    for k = 1:numel(files)
        token = regexp(files(k).name, '^(\d+)_', 'tokens', 'once');
        if ~isempty(token)
            prefix(k) = str2double(token{1});
        end
    end

    [~, numericOrder] = sort(prefix);
    files = files(numericOrder);
end

function metadata = parseFigureMetadata(files)
    nFiles = numel(files);
    metadata.valid = false(nFiles, 1);
    metadata.number = nan(nFiles, 1);
    metadata.view = strings(nFiles, 1);
    metadata.filtering = strings(nFiles, 1);
    metadata.content = strings(nFiles, 1);
    metadata.roi = strings(nFiles, 1);
    metadata.displayName = strings(nFiles, 1);

    pattern = ['^(\d+)_AllComb_(Full|Target)_' ...
               '(Single|Comparison)_([^_]+)_' ...
               '(LeftFrontal|RightFrontal|BilateralFrontal)_' ...
               'cond\d+_(Broadband|LowHigh|HighLow)_roiAverage\.fig$'];

    for k = 1:nFiles
        token = regexp(files(k).name, pattern, 'tokens', 'once');
        if isempty(token)
            continue;
        end

        metadata.valid(k) = true;
        metadata.number(k) = str2double(token{1});
        metadata.view(k) = string(token{2});
        metadata.content(k) = string(token{4});
        metadata.roi(k) = string(token{5});
        metadata.filtering(k) = string(token{6});

        metadata.displayName(k) = sprintf('%03d  |  %s  |  %s  |  %s  |  %s', ...
            metadata.number(k), displayLabel(metadata.view(k)), ...
            displayLabel(metadata.filtering(k)), ...
            displayLabel(metadata.content(k)), ...
            displayLabel(metadata.roi(k)));
    end
end

function label = displayLabel(value)
    switch char(value)
        case 'Full',                      label = 'Full trial';
        case 'Target',                    label = 'Target only';
        case 'Broadband',                 label = 'Broadband';
        case 'LowHigh',                   label = 'Low-High';
        case 'HighLow',                   label = 'High-Low';
        case 'ExpectedWithSP',            label = 'Expected with SP';
        case 'UnexpectedWithSP',          label = 'Unexpected with SP';
        case 'ExpectedWithoutSP',         label = 'Expected without SP';
        case 'UnexpectedWithoutSP',       label = 'Unexpected without SP';
        case 'DifferenceWithSP',          label = 'Difference with SP';
        case 'DifferenceWithoutSP',       label = 'Difference without SP';
        case 'SP',                        label = 'SP comparison';
        case 'NoSP',                      label = 'No-SP comparison';
        case 'LeftFrontal',               label = 'Left frontal';
        case 'RightFrontal',              label = 'Right frontal';
        case 'BilateralFrontal',          label = 'Bilateral frontal';
        otherwise,                        label = char(value);
    end
end

function hBrowser = buildBrowser(state)
    hBrowser = figure( ...
        'Name','ERP Figure Browser', ...
        'NumberTitle','off', ...
        'Tag','S245FigureBrowser', ...
        'Color',[0.96 0.97 0.98], ...
        'MenuBar','none', ...
        'ToolBar','none', ...
        'Units','pixels', ...
        'Position',[90 70 1040 720], ...
        'Resize','off');

    setappdata(hBrowser, 'S245FigureBrowserState', state);

    uicontrol(hBrowser, ...
        'Style','text', ...
        'Position',[22 675 996 28], ...
        'String','ERP Figure Browser', ...
        'FontName','Arial', ...
        'FontSize',16, ...
        'FontWeight','bold', ...
        'HorizontalAlignment','left', ...
        'BackgroundColor',hBrowser.Color);

    buildViewPanel(hBrowser);
    buildFilteringPanel(hBrowser);
    buildROIPanel(hBrowser);
    buildContentPanel(hBrowser);

    uicontrol(hBrowser, ...
        'Style','pushbutton', ...
        'Position',[22 18 125 34], ...
        'String','Select all', ...
        'FontName','Arial', ...
        'FontSize',10, ...
        'Callback',@(src,~) setAllFilters(src, true));

    uicontrol(hBrowser, ...
        'Style','pushbutton', ...
        'Position',[157 18 125 34], ...
        'String','Clear all', ...
        'FontName','Arial', ...
        'FontSize',10, ...
        'Callback',@(src,~) setAllFilters(src, false));

    uicontrol(hBrowser, ...
        'Style','text', ...
        'Position',[320 642 698 26], ...
        'String','', ...
        'Tag','S245ResultCount', ...
        'FontName','Arial', ...
        'FontSize',11, ...
        'FontWeight','bold', ...
        'HorizontalAlignment','left', ...
        'BackgroundColor',hBrowser.Color);

    uicontrol(hBrowser, ...
        'Style','listbox', ...
        'Position',[320 70 698 566], ...
        'String',{'Loading figures...'}, ...
        'Value',1, ...
        'Min',0, ...
        'Max',2, ...
        'Tag','S245ResultList', ...
        'FontName','Consolas', ...
        'FontSize',10, ...
        'BackgroundColor',[1 1 1], ...
        'Callback',@resultListAction);

    uicontrol(hBrowser, ...
        'Style','pushbutton', ...
        'Position',[828 18 190 38], ...
        'String','Open as deck', ...
        'FontName','Arial', ...
        'FontSize',11, ...
        'FontWeight','bold', ...
        'BackgroundColor',[0.80 0.88 0.98], ...
        'Callback',@openSelectedResult);

    uicontrol(hBrowser, ...
        'Style','pushbutton', ...
        'Position',[620 18 195 38], ...
        'String','Compare selected', ...
        'FontName','Arial', ...
        'FontSize',11, ...
        'FontWeight','bold', ...
        'BackgroundColor',[0.88 0.84 0.96], ...
        'TooltipString','Ctrl-click or Shift-click two or more results', ...
        'Callback',@compareSelectedResults);
end

function buildViewPanel(hBrowser)
    panel = uipanel(hBrowser, ...
        'Title','View', ...
        'FontName','Arial', ...
        'FontSize',11, ...
        'FontWeight','bold', ...
        'Units','pixels', ...
        'Position',[20 552 280 108], ...
        'BackgroundColor',[0.96 0.97 0.98]);

    addFilterCheckbox(panel, 'Full trial', 'view', 'Full', [14 48 240 24]);
    addFilterCheckbox(panel, 'Target only', 'view', 'Target', [14 18 240 24]);
end

function buildFilteringPanel(hBrowser)
    panel = uipanel(hBrowser, ...
        'Title','Filtering condition', ...
        'FontName','Arial', ...
        'FontSize',11, ...
        'FontWeight','bold', ...
        'Units','pixels', ...
        'Position',[20 408 280 132], ...
        'BackgroundColor',[0.96 0.97 0.98]);

    addFilterCheckbox(panel, 'Broadband', 'filtering', 'Broadband', [14 72 240 24]);
    addFilterCheckbox(panel, 'Low-High', 'filtering', 'LowHigh', [14 42 240 24]);
    addFilterCheckbox(panel, 'High-Low', 'filtering', 'HighLow', [14 12 240 24]);
end

function buildROIPanel(hBrowser)
    panel = uipanel(hBrowser, ...
        'Title','ROI', ...
        'FontName','Arial', ...
        'FontSize',11, ...
        'FontWeight','bold', ...
        'Units','pixels', ...
        'Position',[20 264 280 132], ...
        'BackgroundColor',[0.96 0.97 0.98]);

    addFilterCheckbox(panel, 'Left frontal', 'roi', 'LeftFrontal', [14 72 240 24]);
    addFilterCheckbox(panel, 'Right frontal', 'roi', 'RightFrontal', [14 42 240 24]);
    addFilterCheckbox(panel, 'Bilateral frontal', 'roi', 'BilateralFrontal', [14 12 240 24]);
end

function buildContentPanel(hBrowser)
    panel = uipanel(hBrowser, ...
        'Title','Condition display', ...
        'FontName','Arial', ...
        'FontSize',11, ...
        'FontWeight','bold', ...
        'Units','pixels', ...
        'Position',[20 62 280 190], ...
        'BackgroundColor',[0.96 0.97 0.98]);

    options = {
        'Expected with SP',       'ExpectedWithSP';
        'Unexpected with SP',     'UnexpectedWithSP';
        'Expected without SP',    'ExpectedWithoutSP';
        'Unexpected without SP',  'UnexpectedWithoutSP';
        'Difference with SP',     'DifferenceWithSP';
        'Difference without SP',  'DifferenceWithoutSP';
        'SP comparison',          'SP';
        'No-SP comparison',       'NoSP'};

    y = 142;
    for k = 1:size(options, 1)
        addFilterCheckbox(panel, options{k,1}, 'content', options{k,2}, ...
                          [14 y 248 20]);
        y = y - 20;
    end
end

function addFilterCheckbox(parent, label, group, value, position)
    uicontrol(parent, ...
        'Style','checkbox', ...
        'Position',position, ...
        'String',label, ...
        'Value',1, ...
        'FontName','Arial', ...
        'FontSize',10, ...
        'BackgroundColor',parent.BackgroundColor, ...
        'Tag','S245FilterCheckbox', ...
        'UserData',struct('group',group, 'value',value), ...
        'Callback',@(src,~) refreshBrowser(owningFigure(src)));
end

function setAllFilters(source, value)
    hBrowser = owningFigure(source);
    boxes = findall(hBrowser, 'Tag','S245FilterCheckbox');
    set(boxes, 'Value',double(value));
    refreshBrowser(hBrowser);
end

function refreshBrowser(hBrowser)
    state = getappdata(hBrowser, 'S245FigureBrowserState');
    boxes = findall(hBrowser, 'Tag','S245FilterCheckbox');

    selected.view = strings(0, 1);
    selected.filtering = strings(0, 1);
    selected.content = strings(0, 1);
    selected.roi = strings(0, 1);

    for k = 1:numel(boxes)
        if boxes(k).Value ~= 1
            continue;
        end
        info = boxes(k).UserData;
        selected.(info.group)(end+1, 1) = string(info.value);
    end

    metadata = state.metadata;
    mask = ismember(metadata.view, selected.view) ...
         & ismember(metadata.filtering, selected.filtering) ...
         & ismember(metadata.content, selected.content) ...
         & ismember(metadata.roi, selected.roi);

    matchIndices = find(mask);
    resultList = findall(hBrowser, 'Tag','S245ResultList');
    resultCount = findall(hBrowser, 'Tag','S245ResultCount');

    if isempty(matchIndices)
        resultList.String = {'No figures match the selected filters.'};
        resultList.Value = 1;
        resultList.UserData = [];
    else
        selectedRows = resultList.Value;
        selectedRows = selectedRows(selectedRows <= numel(matchIndices));
        if isempty(selectedRows)
            selectedRows = 1;
        end
        resultList.String = cellstr(metadata.displayName(matchIndices));
        resultList.Value = selectedRows;
        resultList.UserData = matchIndices;
    end

    resultCount.String = sprintf([ ...
        '%d of %d figures match   |   Ctrl-click or Shift-click to compare'], ...
        numel(matchIndices), numel(state.files));
end

function resultListAction(source, ~)
    hBrowser = owningFigure(source);
    if strcmp(hBrowser.SelectionType, 'open')
        openSelectedResult(source, []);
    end
end

function openSelectedResult(source, ~)
    hBrowser = owningFigure(source);
    state = getappdata(hBrowser, 'S245FigureBrowserState');
    resultList = findall(hBrowser, 'Tag','S245ResultList');
    matchIndices = resultList.UserData;

    if isempty(matchIndices)
        warndlg('Choose at least one option in every filter group.', ...
                'No matching figures');
        return;
    end

    selectedRows = resultList.Value;
    selectedPosition = min(selectedRows(1), numel(matchIndices));
    deckState = struct();
    deckState.figDir = state.figDir;
    deckState.files = state.files(matchIndices);
    deckState.index = selectedPosition;
    deckState.browser = hBrowser;
    deckState.comparisonMode = false;

    oldFigure = state.currentFigure;
    try
        newFigure = openDeckFigure(deckState);
        state.currentFigure = newFigure;
        setappdata(hBrowser, 'S245FigureBrowserState', state);

        if ~isempty(oldFigure) && isgraphics(oldFigure) && oldFigure ~= newFigure
            close(oldFigure);
        end
    catch ME
        errordlg(sprintf('Could not open the selected figure:\n\n%s', ME.message), ...
                 'Figure browser');
    end
end

function compareSelectedResults(source, ~)
    hBrowser = owningFigure(source);
    state = getappdata(hBrowser, 'S245FigureBrowserState');
    resultList = findall(hBrowser, 'Tag','S245ResultList');
    matchIndices = resultList.UserData;

    if isempty(matchIndices)
        warndlg('Choose at least one option in every filter group.', ...
                'No matching figures');
        return;
    end

    selectedRows = unique(resultList.Value(:)');
    selectedRows = selectedRows(selectedRows <= numel(matchIndices));
    if numel(selectedRows) < 2
        warndlg(['Select at least two results using Ctrl-click or ' ...
                 'Shift-click, then click Compare selected.'], ...
                'Select multiple figures');
        return;
    end

    if numel(selectedRows) > 6
        answer = questdlg(sprintf(['You selected %d figures. Opening many interactive ' ...
            'figures may be slow. Continue?'], numel(selectedRows)), ...
            'Open comparison figures', 'Continue', 'Cancel', 'Cancel');
        if ~strcmp(answer, 'Continue')
            return;
        end
    end

    selectedFiles = state.files(matchIndices(selectedRows));
    [rows, columns] = comparisonGrid(numel(selectedFiles));
    positions = comparisonPositions(rows, columns, numel(selectedFiles));

    openedFigures = gobjects(0);
    for k = 1:numel(selectedFiles)
        compareState = struct();
        compareState.figDir = state.figDir;
        compareState.files = selectedFiles;
        compareState.index = k;
        compareState.browser = hBrowser;
        compareState.comparisonMode = true;

        try
            hFig = openDeckFigure(compareState);
            set(hFig, 'WindowState','normal');
            drawnow;
            set(hFig, 'Units','pixels', 'OuterPosition',positions(k,:));
            openedFigures(end+1) = hFig; %#ok<AGROW>
        catch ME
            warning('S245_FigureDeck:CompareOpenFailed', ...
                    'Could not open %s: %s', selectedFiles(k).name, ME.message);
        end
    end

    if isempty(openedFigures)
        errordlg('None of the selected figures could be opened.', ...
                 'Figure comparison');
    end
end

function [rows, columns] = comparisonGrid(nFigures)
    if nFigures == 2
        rows = 1;
        columns = 2;
    else
        columns = ceil(sqrt(nFigures));
        rows = ceil(nFigures / columns);
    end
end

function positions = comparisonPositions(rows, columns, nFigures)
    screen = get(0, 'ScreenSize');
    gap = 12;
    sideMargin = 16;
    bottomMargin = 48;
    topMargin = 42;

    usableWidth = screen(3) - 2 * sideMargin - (columns - 1) * gap;
    usableHeight = screen(4) - bottomMargin - topMargin - (rows - 1) * gap;
    tileWidth = floor(usableWidth / columns);
    tileHeight = floor(usableHeight / rows);

    positions = zeros(nFigures, 4);
    for k = 1:nFigures
        column = mod(k - 1, columns);
        rowFromTop = floor((k - 1) / columns);
        x = screen(1) + sideMargin + column * (tileWidth + gap);
        y = screen(2) + bottomMargin ...
            + (rows - 1 - rowFromTop) * (tileHeight + gap);
        positions(k,:) = [x y tileWidth tileHeight];
    end
end

function hFig = openDeckFigure(state)
    figureFile = fullfile(state.figDir, state.files(state.index).name);
    hFig = openfig(figureFile, 'new', 'visible');

    isComparison = isfield(state, 'comparisonMode') && state.comparisonMode;
    if isComparison
        windowName = sprintf('ERP Comparison - %d of %d - %s', ...
            state.index, numel(state.files), state.files(state.index).name);
    else
        windowName = sprintf('ERP Figure Deck - %d of %d - %s', ...
            state.index, numel(state.files), state.files(state.index).name);
    end

    set(hFig, ...
        'Name',windowName, ...
        'NumberTitle','off', ...
        'Tag','S245FigureDeckDisplay');

    setappdata(hFig, 'S245FigureDeckState', state);

    % Add the cohort control at runtime if this figure predates that button.
    cohortButton = findall(hFig, 'Type','uicontrol', ...
                           'Tag','cohortHighlightToggle');
    individualLines = findall(hFig, 'Type','line', 'Tag','indivTrace');
    if isempty(cohortButton) && ~isempty(individualLines)
        S244_cohortHighlight('install', hFig, [24 25 26 27 28]);
    end

    oldControls = findall(hFig, 'Tag','S245FigureDeckControl');
    if ~isempty(oldControls)
        delete(oldControls);
    end

    uicontrol(hFig, ...
        'Style','pushbutton', ...
        'Units','normalized', ...
        'Position',[0.012 0.914 0.140 0.032], ...
        'String','Filter / Jump', ...
        'FontName','Arial', ...
        'FontSize',10, ...
        'FontWeight','bold', ...
        'Tag','S245FigureDeckControl', ...
        'TooltipString','Show the figure browser', ...
        'Callback',@(src,~) showBrowser(src));

    if ~isComparison
        uicontrol(hFig, ...
            'Style','pushbutton', ...
            'Units','normalized', ...
            'Position',[0.758 0.952 0.088 0.032], ...
            'String','< Previous', ...
            'FontName','Arial', ...
            'FontSize',10, ...
            'FontWeight','bold', ...
            'Tag','S245FigureDeckControl', ...
            'TooltipString','Open the previous matching figure', ...
            'Callback',@(src,~) navigateDeck(src, -1));

        uicontrol(hFig, ...
            'Style','text', ...
            'Units','normalized', ...
            'Position',[0.851 0.954 0.061 0.026], ...
            'String',sprintf('%d / %d', state.index, numel(state.files)), ...
            'FontName','Arial', ...
            'FontSize',10, ...
            'FontWeight','bold', ...
            'BackgroundColor',[1 1 1], ...
            'Tag','S245FigureDeckControl');

        uicontrol(hFig, ...
            'Style','pushbutton', ...
            'Units','normalized', ...
            'Position',[0.917 0.952 0.071 0.032], ...
            'String','Next >', ...
            'FontName','Arial', ...
            'FontSize',10, ...
            'FontWeight','bold', ...
            'Tag','S245FigureDeckControl', ...
            'TooltipString','Open the next matching figure', ...
            'Callback',@(src,~) navigateDeck(src, 1));
    end

    if ~isComparison
        set(hFig, 'WindowKeyPressFcn',@deckKeyPress);
        syncBrowserSelection(state);
    else
        set(hFig, 'WindowKeyPressFcn','');
    end
    drawnow;
end

function showBrowser(source)
    hFig = owningFigure(source);
    state = getappdata(hFig, 'S245FigureDeckState');
    if isfield(state, 'browser') && isgraphics(state.browser)
        figure(state.browser);
    end
end

function navigateDeck(source, step)
    hFig = owningFigure(source);
    if isempty(hFig) || ~isgraphics(hFig)
        return;
    end

    state = getappdata(hFig, 'S245FigureDeckState');
    if isempty(state)
        return;
    end

    nFiles = numel(state.files);
    state.index = mod(state.index - 1 + step, nFiles) + 1;

    set(hFig, 'Pointer','watch');
    drawnow;

    try
        nextFigure = openDeckFigure(state);
        updateBrowserCurrentFigure(state, nextFigure);
        if isgraphics(hFig) && hFig ~= nextFigure
            close(hFig);
        end
    catch ME
        if isgraphics(hFig)
            set(hFig, 'Pointer','arrow');
        end
        errordlg(sprintf('Could not open the next figure:\n\n%s', ME.message), ...
                 'Figure deck');
    end
end

function syncBrowserSelection(state)
    if ~isfield(state, 'browser') || ~isgraphics(state.browser)
        return;
    end
    resultList = findall(state.browser, 'Tag','S245ResultList');
    if ~isempty(resultList) && state.index <= numel(resultList.String)
        resultList.Value = state.index;
    end
end

function updateBrowserCurrentFigure(state, hFig)
    if ~isfield(state, 'browser') || ~isgraphics(state.browser)
        return;
    end
    browserState = getappdata(state.browser, 'S245FigureBrowserState');
    browserState.currentFigure = hFig;
    setappdata(state.browser, 'S245FigureBrowserState', browserState);
    syncBrowserSelection(state);
end

function deckKeyPress(source, event)
    switch event.Key
        case {'rightarrow','pagedown'}
            navigateDeck(source, 1);
        case {'leftarrow','pageup'}
            navigateDeck(source, -1);
        case 'home'
            goToDeckEnd(source, false);
        case 'end'
            goToDeckEnd(source, true);
    end
end

function goToDeckEnd(source, useLast)
    hFig = owningFigure(source);
    state = getappdata(hFig, 'S245FigureDeckState');
    if isempty(state)
        return;
    end

    if useLast
        step = numel(state.files) - state.index;
    else
        step = 1 - state.index;
    end

    if step ~= 0
        navigateDeck(source, step);
    end
end

function hFig = owningFigure(source)
    if isgraphics(source, 'figure')
        hFig = source;
    else
        hFig = ancestor(source, 'figure');
    end
end
