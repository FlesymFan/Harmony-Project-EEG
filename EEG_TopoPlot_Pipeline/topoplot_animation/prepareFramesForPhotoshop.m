function prepareFramesForPhotoshop()
% Copy topoplot frames into Photoshop-friendly sequential filenames.
%
% Original files are not changed. The copied files are named:
%   frame_0001.png
%   frame_0002.png
%   frame_0003.png
%   ...

scriptDir = fileparts(mfilename('fullpath'));
pipelineDir = fileparts(scriptDir);
addpath(pipelineDir);
previousDir = pwd;
cleanupDir = onCleanup(@() cd(previousDir)); %#ok<NASGU>
cd(scriptDir);

fprintf('\n[Prepare frames for Photoshop]\n');
fprintf('This copies PNG frames into simple sequential filenames.\n');
fprintf('Original frame files are not changed.\n\n');

sourceDir = promptText('Source frame folder', 'topoplot_frames');
outputDir = promptText('Output folder', 'topoplot_frames_photoshop');

sourcePath = fullfile(pwd, sourceDir);
outputPath = fullfile(pwd, outputDir);

if exist(sourcePath, 'dir') ~= 7
    error('prepareFramesForPhotoshop: source folder not found: %s', sourcePath);
end

frameFiles = dir(fullfile(sourcePath, 'frame_*.png'));
if isempty(frameFiles)
    frameFiles = dir(fullfile(sourcePath, '*.png'));
end
if isempty(frameFiles)
    error('prepareFramesForPhotoshop: no PNG files found in %s', sourcePath);
end

frameFiles = sortFrameFiles(frameFiles);
prepareOutputFolder(outputPath);

for i = 1:numel(frameFiles)
    oldPath = fullfile(sourcePath, frameFiles(i).name);
    newName = sprintf('frame_%04d.png', i);
    newPath = fullfile(outputPath, newName);
    copyfile(oldPath, newPath);
end

fprintf('\nCopied %d frame(s).\n', numel(frameFiles));
fprintf('Photoshop-ready folder:\n%s\n\n', outputPath);
fprintf('In Photoshop: File > Open, select frame_0001.png, check Image Sequence.\n');
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

function prepareOutputFolder(outputPath)
    currentFolder = char(java.io.File(pwd).getCanonicalPath());
    targetFolder = char(java.io.File(outputPath).getCanonicalPath());

    if ~startsWith([targetFolder filesep], [currentFolder filesep])
        error('prepareFramesForPhotoshop: output folder must be inside the current topoplot_animation folder.');
    end
    if strcmp(targetFolder, currentFolder)
        error('prepareFramesForPhotoshop: output folder cannot be the current folder.');
    end

    if exist(outputPath, 'dir')
        rmdir(outputPath, 's');
    end

    mkdir(outputPath);
end
