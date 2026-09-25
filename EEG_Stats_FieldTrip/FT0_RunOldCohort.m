function results = FT0_RunOldCohort(dataFolder, fieldtripFolder)
% Run the FT1-selected paired ROI cluster tests with FieldTrip.

% Input: EEGDataAvgAcrossTrials_allSubject_cond#.mat in the Data folder.

if nargin < 1 || isempty(dataFolder)
    dataFolder = strtrim(input('Data folder: ', 's'));
end
dataFolder = char(dataFolder);
if exist(dataFolder, 'dir') ~= 7
    error('FT0: Data folder does not exist: %s', dataFolder);
end

if exist('ft_defaults', 'file') ~= 2 || ...
        exist('ft_timelockstatistics', 'file') ~= 2
    if nargin < 2 || isempty(fieldtripFolder)
        fieldtripFolder = strtrim(input('FieldTrip toolbox folder: ', 's'));
    end
    fieldtripFolder = char(fieldtripFolder);
    if exist(fullfile(fieldtripFolder, 'ft_defaults.m'), 'file') ~= 2
        error('FT0: select the FieldTrip root folder containing ft_defaults.m.');
    end
    addpath(fieldtripFolder);
    ft_defaults;
end
if exist('ft_timelockstatistics', 'file') ~= 2
    error('FT0: ft_timelockstatistics is not available after ft_defaults.');
end

cfg = FT1_Config(dataFolder);
tests = FT2_LoadP8Timelocks(cfg);
fprintf('\nActive FT1 selections:\n');
fprintf('  Subjects (%d): %s\n', numel(cfg.subjectIDs), mat2str(cfg.subjectIDs));
fprintf('  Conditions: %s\n', mat2str(cfg.conditionNumbers));
fprintf('  Contrasts: %s\n', strjoin(cfg.contrasts(:, 1), ', '));
fprintf('  ROI electrodes: %s\n', strjoin(cfg.roiNames, ', '));
fprintf('  Sample rate: %.3f Hz; epoch start: %.3f ms\n', ...
        cfg.sampleRate, cfg.epochStart_ms);
fprintf('  Target onset: %.3f ms; baseline: %s ms; scan: %s ms\n', ...
        cfg.targetOnset_ms, mat2str(cfg.baselineWin_ms), mat2str(cfg.scanWin_ms));
fprintf('  Permutations per test: %d; random seed: %d\n', ...
        cfg.nPermutations, cfg.randomSeed);
fprintf('  Output folder: %s\n', cfg.outFolder);
fprintf('Validated %d paired subjects and %d planned tests.\n', ...
        numel(cfg.subjectIDs), numel(tests));
answer = strtrim(lower(input(sprintf( ...
    'Proceed with %d permutations per test? (y/n) [n]: ', ...
    cfg.nPermutations), 's')));
if ~strcmp(answer, 'y')
    fprintf('Cancelled; no result files were written.\n');
    results = struct([]);
    return;
end

rng(cfg.randomSeed, 'twister');
results = struct('conditionNumber', {}, 'contrast', {}, 'stat', {}, 'testP', {}, 'familyP', {});
for iTest = 1:numel(tests)
    fprintf('\nTest %d/%d: condition %d, %s\n', iTest, numel(tests), ...
            tests(iTest).conditionNumber, tests(iTest).contrast);
    stat = FT3_RunClusterTest(cfg, tests(iTest));
    results(iTest).conditionNumber = tests(iTest).conditionNumber;
    results(iTest).contrast = tests(iTest).contrast;
    results(iTest).stat = stat;
    results(iTest).testP = clusterMinimumP(stat);
    results(iTest).familyP = NaN;
    fprintf('Smallest FieldTrip two-sided cluster p: %.4f\n', results(iTest).testP);
end

results = FT4_SaveResults(cfg, results);
end

function p = clusterMinimumP(stat)
    p = 1;
    if isfield(stat, 'posclusters') && ~isempty(stat.posclusters)
        p = min(p, min([stat.posclusters.prob]));
    end
    if isfield(stat, 'negclusters') && ~isempty(stat.negclusters)
        p = min(p, min([stat.negclusters.prob]));
    end
end
