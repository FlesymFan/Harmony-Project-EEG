function topoplotFrameViewer()
% View topoplot PNG frames with exact frame-by-frame control.
%
% This is for inspecting generated pseudo-video frames. Each slider step is
% exactly one PNG frame. Use left/right arrow keys or the Prev/Next buttons
% to move one frame at a time.

scriptDir = fileparts(mfilename('fullpath'));
pipelineDir = fileparts(scriptDir);
addpath(pipelineDir);
previousDir = pwd;
cleanupDir = onCleanup(@() cd(previousDir)); %#ok<NASGU>
cd(scriptDir);

fprintf('\n[Topoplot frame viewer]\n');
frameFolder = promptText('Frame folder', 'topoplot_frames');
framePath = fullfile(pwd, frameFolder);

if exist(framePath, 'dir') ~= 7
    error('topoplotFrameViewer: frame folder not found: %s', framePath);
end

frameFiles = dir(fullfile(framePath, 'frame_*.png'));
if isempty(frameFiles)
    frameFiles = dir(fullfile(framePath, '*.png'));
end
if isempty(frameFiles)
    error('topoplotFrameViewer: no PNG frames found in %s', framePath);
end

frameFiles = sortFrameFiles(frameFiles);
nFrames = numel(frameFiles);
currentFrame = 1;

firstImage = imread(fullfile(framePath, frameFiles(currentFrame).name));

hFig = figure('Name', 'Topoplot Frame Viewer', ...
              'Color', 'w', ...
              'NumberTitle', 'off', ...
              'WindowKeyPressFcn', @keyPressed, ...
              'WindowKeyReleaseFcn', @keyReleased, ...
              'CloseRequestFcn', @closeViewer, ...
              'Interruptible', 'off', ...
              'BusyAction', 'cancel');
try
    set(hFig, 'WindowState', 'maximized');
catch
    set(hFig, 'Units', 'normalized', 'OuterPosition', [0 0 1 1]);
end

heldKey = '';
stepDirection = 0;
stepTimer = timer('ExecutionMode', 'fixedSpacing', ...
                  'Period', 0.12, ...
                  'TimerFcn', @timerStep, ...
                  'BusyMode', 'drop');

ax = axes('Parent', hFig, ...
          'Units', 'normalized', ...
          'Position', [0.04 0.14 0.92 0.80]);
hImg = image(ax, firstImage);
axis(ax, 'image');
axis(ax, 'off');

if nFrames == 1
    sliderStep = [1 1];
else
    sliderStep = [1/(nFrames - 1), min(10/(nFrames - 1), 1)];
end

prevBtn = uicontrol('Parent', hFig, ...
                    'Style', 'pushbutton', ...
                    'String', 'Prev', ...
                    'Units', 'normalized', ...
                    'Position', [0.04 0.055 0.07 0.04], ...
                    'Callback', @(~,~) goToFrame(currentFrame - 1));

nextBtn = uicontrol('Parent', hFig, ...
                    'Style', 'pushbutton', ...
                    'String', 'Next', ...
                    'Units', 'normalized', ...
                    'Position', [0.12 0.055 0.07 0.04], ...
                    'Callback', @(~,~) goToFrame(currentFrame + 1));

slider = uicontrol('Parent', hFig, ...
                   'Style', 'slider', ...
                   'Units', 'normalized', ...
                   'Position', [0.21 0.057 0.50 0.035], ...
                   'Min', 1, ...
                   'Max', nFrames, ...
                   'Value', 1, ...
                   'SliderStep', sliderStep, ...
                   'Callback', @sliderMoved);

frameEdit = uicontrol('Parent', hFig, ...
                      'Style', 'edit', ...
                      'Units', 'normalized', ...
                      'Position', [0.73 0.055 0.08 0.04], ...
                      'String', '1', ...
                      'Callback', @frameEditChanged);

frameText = uicontrol('Parent', hFig, ...
                      'Style', 'text', ...
                      'Units', 'normalized', ...
                      'Position', [0.82 0.052 0.14 0.045], ...
                      'BackgroundColor', 'w', ...
                      'HorizontalAlignment', 'left');

updateFrame(1);

fprintf('Loaded %d frame(s) from:\n%s\n\n', nFrames, framePath);
fprintf('Use the slider, Prev/Next buttons, or left/right arrow keys.\n');

    function sliderMoved(~, ~)
        goToFrame(round(get(slider, 'Value')));
    end

    function frameEditChanged(~, ~)
        requestedFrame = str2double(get(frameEdit, 'String'));
        if isnan(requestedFrame)
            requestedFrame = currentFrame;
        end
        goToFrame(round(requestedFrame));
    end

    function keyPressed(~, event)
        switch event.Key
            case {'rightarrow', 'downarrow', 'space'}
                startKeyHold(event.Key, 1);
            case {'leftarrow', 'uparrow', 'backspace'}
                startKeyHold(event.Key, -1);
            case 'home'
                stopKeyHold();
                goToFrame(1);
            case 'end'
                stopKeyHold();
                goToFrame(nFrames);
        end
    end

    function keyReleased(~, event)
        if strcmp(event.Key, heldKey)
            stopKeyHold();
        end
    end

    function startKeyHold(keyName, direction)
        if strcmp(heldKey, keyName) && stepDirection == direction
            return;
        end

        stopKeyHold();
        heldKey = keyName;
        stepDirection = direction;
        goToFrame(currentFrame + stepDirection);

        if strcmp(get(stepTimer, 'Running'), 'off')
            start(stepTimer);
        end
    end

    function stopKeyHold()
        heldKey = '';
        stepDirection = 0;

        if isvalid(stepTimer) && strcmp(get(stepTimer, 'Running'), 'on')
            stop(stepTimer);
        end
        drawnow limitrate;
    end

    function timerStep(~, ~)
        if stepDirection == 0
            return;
        end

        nextFrame = currentFrame + stepDirection;
        if nextFrame < 1 || nextFrame > nFrames
            stopKeyHold();
            return;
        end

        goToFrame(nextFrame);
    end

    function goToFrame(frameNumber)
        frameNumber = max(1, min(nFrames, frameNumber));
        updateFrame(frameNumber);
    end

    function updateFrame(frameNumber)
        currentFrame = frameNumber;
        img = imread(fullfile(framePath, frameFiles(currentFrame).name));
        set(hImg, 'CData', img);
        set(slider, 'Value', currentFrame);
        set(frameEdit, 'String', num2str(currentFrame));
        set(frameText, 'String', sprintf('/ %d', nFrames));

        title(ax, frameTitle(frameFiles(currentFrame).name, currentFrame, nFrames), ...
              'Interpreter', 'none', ...
              'FontName', 'Arial', ...
              'FontSize', 14);
        drawnow;
    end

    function closeViewer(~, ~)
        if exist('stepTimer', 'var') && isvalid(stepTimer)
            stop(stepTimer);
            delete(stepTimer);
        end
        delete(hFig);
    end
end

function value = promptText(prompt, defaultValue)
    resp = strtrim(input(sprintf('%s [%s]: ', prompt, defaultValue), 's'));
    if isempty(resp)
        value = defaultValue;
    else
        value = resp;
    end
end

function files = sortFrameFiles(files)
    names = {files.name};
    frameNums = nan(numel(names), 1);

    for i = 1:numel(names)
        token = regexp(names{i}, '^frame_(\d+)', 'tokens', 'once');
        if ~isempty(token)
            frameNums(i) = str2double(token{1});
        end
    end

    if all(~isnan(frameNums))
        [~, order] = sort(frameNums);
    else
        [~, order] = sort(lower(names));
    end

    files = files(order);
end

function titleStr = frameTitle(filename, currentFrame, nFrames)
    token = regexp(filename, '^frame_(\d+)_(\d+)_(\d+)\.png$', 'tokens', 'once');

    if ~isempty(token)
        frameNumber = str2double(token{1});
        windowStart = str2double(token{2});
        windowEnd = str2double(token{3});
        titleStr = sprintf('Frame %d/%d | File frame %04d | Window [%d %d]', ...
                           currentFrame, nFrames, frameNumber, windowStart, windowEnd);
    else
        titleStr = sprintf('Frame %d/%d | %s', currentFrame, nFrames, filename);
    end
end
