function [topoValuesAll, plotInfo] = scalpValues(EEGDataAvg, subjectNames, cfg)
% Prepare the channel-level values that will be drawn on the scalp.
%
% This is the main neuroscience step for the topoplot pipeline:
%   1) select the subject or subjects
%   2) select the condition or contrast
%   3) find the relevant chord onset
%   4) baseline-correct the waveform
%   5) average the selected topoplot time window

nSubj = numel(subjectNames);
subjectIndices = selectedSubjectIndices(cfg, nSubj);
nSubjects = numel(subjectIndices);

if nSubjects > 1
    plotMode = 'multi';
else
    plotMode = 'single';
end

plotConditions = cfg.plotConditions;
if isempty(plotConditions)
    error('scalpValues: cfg.plotConditions is empty.');
end

timeWindow_remap = [cfg.windowStart_remap, ...
                    cfg.windowStart_remap + cfg.windowWidth_remap];

chordOnsetsBeforeWindow = cfg.chordOnsets_remap(cfg.chordOnsets_remap <= timeWindow_remap(1));
if isempty(chordOnsetsBeforeWindow)
    error('scalpValues: no chord onset found before window start %d.', timeWindow_remap(1));
end

baselineChordOnset_remap = chordOnsetsBeforeWindow(end);
baselineWindow_remap = [baselineChordOnset_remap - cfg.baselineLength_remap, ...
                        baselineChordOnset_remap - 1];

nConditions = numel(plotConditions);

topoValuesAll = [];
conditionLabels = strings(nConditions, 1);
selectedSubjectNames = strings(nSubjects, 1);

fprintf('Using %d subject(s) of %d.\n', nSubjects, nSubj);

for s = 1:nSubjects
    subjectIndex = subjectIndices(s);
    subjectName = subjectNames{subjectIndex};
    subjectData = EEGDataAvg.(subjectName);
    selectedSubjectNames(s) = string(subjectName);

    fprintf('Subject %d of %d: %s\n', subjectIndex, nSubj, subjectName);

    for c = 1:nConditions
        conditionName = plotConditions{c};
        [wave, meta, conditionLabel] = conditionWave(subjectData, conditionName);

        if s == 1
            conditionLabels(c) = string(conditionLabel);
        end

        [~, ~, idx_old] = timeWindow(meta, cfg, timeWindow_remap);
        [~, ~, baseline_idx_old] = timeWindow(meta, cfg, baselineWindow_remap);

        baseline = mean(wave(:, baseline_idx_old), 2);
        waveBC = wave - baseline;
        topoValues = mean(waveBC(:, idx_old), 2);    % channels x 1

        fprintf('  %s: window [%d %d], baseline [%d %d], nChan = %d.\n', ...
                conditionName, ...
                timeWindow_remap(1), timeWindow_remap(2), ...
                baselineWindow_remap(1), baselineWindow_remap(2), ...
                meta.nChan);

        if isempty(topoValuesAll)
            topoValuesAll = zeros(numel(topoValues), nConditions, nSubjects);
        end

        topoValuesAll(:, c, s) = topoValues;
    end
end

plotInfo = struct();
plotInfo.plotMode = plotMode;
plotInfo.subjectIndices = subjectIndices;
plotInfo.subjectNames = selectedSubjectNames;
plotInfo.subjectIndex = subjectIndices(1);
plotInfo.subjectName = selectedSubjectNames(1);
plotInfo.nSubjects = nSubjects;
plotInfo.conditionNames = string(plotConditions);
plotInfo.conditionLabels = conditionLabels;
plotInfo.timeWindow_remap = timeWindow_remap;
plotInfo.baselineChordOnset_remap = baselineChordOnset_remap;
plotInfo.baselineWindow_remap = baselineWindow_remap;
plotInfo.conditionNumber = cfg.conditionNumber;
end

function subjectIndices = selectedSubjectIndices(cfg, nSubj)
    if isfield(cfg, 'subjectIndices') && ~isempty(cfg.subjectIndices)
        subjectIndices = cfg.subjectIndices;
    elseif isfield(cfg, 'subjectIndex') && ~isempty(cfg.subjectIndex)
        subjectIndices = cfg.subjectIndex;
    else
        subjectIndices = 1;
    end

    subjectIndices = subjectIndices(:)';

    if any(~isfinite(subjectIndices)) || any(subjectIndices < 1) || ...
       any(subjectIndices ~= round(subjectIndices)) || any(subjectIndices > nSubj)
        error('scalpValues: subject indices must be positive integers within 1..%d.', nSubj);
    end
end

function [wave, meta, label] = conditionWave(subjectData, conditionName)
% Return one channel x time waveform for a selected condition or contrast.

conditionName = char(conditionName);

switch conditionName
    case 'Exp_withSP'
        wave = fieldERP(subjectData, 'ExpwithSensPrim');
        label = 'Expected with SP';

    case 'Unexp_withSP'
        wave = fieldERP(subjectData, 'UnexpwithSensPrim');
        label = 'Unexpected with SP';

    case 'Diff_withSP'
        wave = fieldERP(subjectData, 'UnexpwithSensPrim') - ...
               fieldERP(subjectData, 'ExpwithSensPrim');
        label = 'Unexpected - Expected with SP';

    case 'Exp_noSP'
        wave = fieldERP(subjectData, 'ExpwithoutSensPrim');
        label = 'Expected without SP';

    case 'Unexp_noSP'
        wave = fieldERP(subjectData, 'UnexpwithoutSensPrim');
        label = 'Unexpected without SP';

    case 'Diff_noSP'
        wave = fieldERP(subjectData, 'UnexpwithoutSensPrim') - ...
               fieldERP(subjectData, 'ExpwithoutSensPrim');
        label = 'Unexpected - Expected without SP';

    case 'Atonal'
        wave = fieldERP(subjectData, 'Atonal');
        label = 'Atonal';

    otherwise
        error('scalpValues: unknown condition "%s".', conditionName);
end

meta = struct();
meta.nChan = size(wave, 1);
meta.oldLen = size(wave, 2);
meta.numTimePoints = meta.oldLen;
end

function erp = fieldERP(subjectData, fieldName)
    if ~isfield(subjectData, fieldName)
        error('scalpValues: subject is missing field "%s".', fieldName);
    end

    data = subjectData.(fieldName);

    if ndims(data) == 3
        erp = mean(data, 3, 'omitnan');
    else
        erp = data;
    end
end
