function tests = FT2_LoadP8Timelocks(cfg)
% Convert each P8 subject average into a paired, target-relative timelock.

validateSelections(cfg);
labels = readLabels();
roiIdx = zeros(1, numel(cfg.roiNames));
for k = 1:numel(cfg.roiNames)
    hit = find(strcmpi(labels, cfg.roiNames{k}), 1);
    if isempty(hit)
        error('FT2: ROI label %s is absent from BioSemi64.loc.', cfg.roiNames{k});
    end
    roiIdx(k) = hit;
end

tests = struct('conditionNumber', {}, 'contrast', {}, 'expected', {}, 'unexpected', {});
nSub = numel(cfg.subjectIDs);
for iCond = 1:numel(cfg.conditionNumbers)
    conditionNumber = cfg.conditionNumbers(iCond);
    source = fullfile(cfg.dataFolder, ...
        sprintf('EEGDataAvgAcrossTrials_allSubject_cond%d.mat', conditionNumber));
    if exist(source, 'file') ~= 2
        error('FT2: missing P8 input: %s', source);
    end
    S = load(source, 'EEGDataAvg');
    if ~isfield(S, 'EEGDataAvg') || ~isstruct(S.EEGDataAvg)
        error('FT2: EEGDataAvg is missing from %s.', source);
    end
    for iContrast = 1:size(cfg.contrasts, 1)
        expected = cell(1, nSub);
        unexpected = cell(1, nSub);
        for iSub = 1:nSub
            field = sprintf('Sub%d_cond%d', cfg.subjectIDs(iSub), conditionNumber);
            if ~isfield(S.EEGDataAvg, field)
                error('FT2: %s is missing from %s.', field, source);
            end
            one = S.EEGDataAvg.(field);
            expName = cfg.contrasts{iContrast, 2};
            unexpName = cfg.contrasts{iContrast, 3};
            if ~isfield(one, expName) || ~isfield(one, unexpName)
                error('FT2: %s lacks one or both %s averages.', field, cfg.contrasts{iContrast, 1});
            end
            E = one.(expName);
            U = one.(unexpName);
            if ~isnumeric(E) || ~isnumeric(U) || ~isequal(size(E), size(U)) || ...
                    size(E, 1) ~= 64 || ~all(isfinite(E(:))) || ~all(isfinite(U(:)))
                error('FT2: %s must have finite, matching 64-channel averages.', field);
            end
            nPts = size(E, 2);
            trial_ms = cfg.epochStart_ms + (0:nPts-1) / cfg.sampleRate * 1000;
            relative_ms = trial_ms - cfg.targetOnset_ms;
            baselineIdx = relative_ms >= cfg.baselineWin_ms(1) & ...
                          relative_ms < cfg.baselineWin_ms(2);
            scanIdx = relative_ms >= cfg.scanWin_ms(1) & ...
                      relative_ms <= cfg.scanWin_ms(2);
            if ~any(baselineIdx) || nnz(scanIdx) < 2
                error('FT2: baseline or scan window is outside %s.', field);
            end
            expWave = mean(double(E(roiIdx, :)), 1);
            unexpWave = mean(double(U(roiIdx, :)), 1);
            expected{iSub} = makeTimelock(expWave, relative_ms, baselineIdx, scanIdx);
            unexpected{iSub} = makeTimelock(unexpWave, relative_ms, baselineIdx, scanIdx);
            if iSub > 1 && ~isequal(expected{iSub}.time, expected{1}.time)
                error('FT2: subject time axes differ in condition %d.', conditionNumber);
            end
        end
        idx = numel(tests) + 1;
        tests(idx).conditionNumber = conditionNumber;
        tests(idx).contrast = cfg.contrasts{iContrast, 1};
        tests(idx).expected = expected;
        tests(idx).unexpected = unexpected;
    end
    fprintf('Validated condition %d from %s\n', conditionNumber, source);
end
end

function timelock = makeTimelock(wave, relative_ms, baselineIdx, scanIdx)
    wave = wave - mean(wave(baselineIdx));
    timelock = struct();
    timelock.label = {'ROI'};
    timelock.time = relative_ms(scanIdx) / 1000;
    timelock.avg = wave(scanIdx);
    timelock.dimord = 'chan_time';
end

function validateSelections(cfg)
    ids = cfg.subjectIDs(:)';
    if isempty(ids) || any(~isfinite(ids)) || any(ids < 1) || ...
            any(ids ~= round(ids)) || numel(unique(ids)) ~= numel(ids)
        error('FT2: subjectIDs must contain unique positive integers.');
    end
    conditions = cfg.conditionNumbers(:)';
    if isempty(conditions) || any(~ismember(conditions, [1 4 5])) || ...
            numel(unique(conditions)) ~= numel(conditions)
        error('FT2: conditionNumbers must be distinct values from 1, 4, 5.');
    end
    if ~iscell(cfg.contrasts) || size(cfg.contrasts, 2) ~= 3 || ...
            isempty(cfg.contrasts) || ...
            any(~cellfun(@(x) ischar(x) && ~isempty(x), cfg.contrasts(:))) || ...
            numel(unique(cfg.contrasts(:, 1))) ~= size(cfg.contrasts, 1)
        error('FT2: contrasts must have unique names and three text columns.');
    end
    if isempty(cfg.roiNames) || ~iscell(cfg.roiNames) || ...
            any(~cellfun(@(x) ischar(x) && ~isempty(x), cfg.roiNames)) || ...
            numel(unique(lower(string(cfg.roiNames)))) ~= numel(cfg.roiNames)
        error('FT2: roiNames must contain unique electrode labels.');
    end
    if ~isscalar(cfg.sampleRate) || ~isfinite(cfg.sampleRate) || cfg.sampleRate <= 0 || ...
            ~isscalar(cfg.epochStart_ms) || ~isfinite(cfg.epochStart_ms) || ...
            ~isscalar(cfg.targetOnset_ms) || ~isfinite(cfg.targetOnset_ms) || ...
            numel(cfg.baselineWin_ms) ~= 2 || ...
            any(~isfinite(cfg.baselineWin_ms)) || ...
            cfg.baselineWin_ms(1) >= cfg.baselineWin_ms(2) || ...
            numel(cfg.scanWin_ms) ~= 2 || any(~isfinite(cfg.scanWin_ms)) || ...
            cfg.scanWin_ms(1) >= cfg.scanWin_ms(2)
        error('FT2: sample rate, timing, baseline, or scan window is invalid.');
    end
    if ~isscalar(cfg.nPermutations) || ~isfinite(cfg.nPermutations) || ...
            cfg.nPermutations < 1 || cfg.nPermutations ~= round(cfg.nPermutations) || ...
            ~isscalar(cfg.randomSeed) || ~isfinite(cfg.randomSeed) || ...
            cfg.randomSeed < 0 || cfg.randomSeed ~= round(cfg.randomSeed)
        error('FT2: nPermutations must be positive and randomSeed nonnegative integers.');
    end
    if isempty(cfg.outFolder) || ~ischar(cfg.outFolder)
        error('FT2: outFolder must be a directory path.');
    end
end

function labels = readLabels()
    scriptFolder = fileparts(mfilename('fullpath'));
    locFile = fullfile(fileparts(scriptFolder), 'EEG_Preprocessing_Pipeline', ...
                       'BioSemi64.loc');
    fid = fopen(locFile, 'r');
    if fid < 0
        error('FT2: cannot read %s.', locFile);
    end
    cleanup = onCleanup(@() fclose(fid));
    columns = textscan(fid, '%f %f %f %s', ...
        'Delimiter', {' ', sprintf('\t')}, 'MultipleDelimsAsOne', true);
    labels = columns{4};
    if numel(labels) ~= 64 || ~isequal(columns{1}(:)', 1:64)
        error('FT2: BioSemi64.loc must contain numbered channels 1 through 64.');
    end
end
