function cfg = config()
% Default configuration for the topoplot pipeline.

cfg = struct();

% Plot mode: 'single' draws one subject; 'multi' draws several subjects
% on one canvas using the same analysis settings.
cfg.plotMode = 'single';

% Data file pattern. The filtering condition is inserted below.
% 1 = Broadband, 4 = Low High, 5 = High Low
cfg.conditionNumber = 1;
cfg.dataFilePattern = 'EEGDataAvgAcrossTrials_allSubject_cond%d.mat';

% Subject or subjects to plot. Use one value for subject-wise plots,
% or a vector such as 1:15 for a multi-subject canvas.
cfg.subjectIndices = 1;

% Topoplot time window in remapped 1..5000 coordinates.
% The window is computed as [windowStart_remap, windowStart_remap + windowWidth_remap].
cfg.windowStart_remap = 3100;
cfg.windowWidth_remap = 50;

% Chord onsets in remapped coordinates. These match the vertical-bar
% convention used in the ERP analysis pipeline.
cfg.chordOnsets_remap = [100, 600, 1100, 1600, 2100, 2600, 3100];

% Baseline length before the nearest preceding chord onset.
% Example: for a window starting at 3100, the selected onset is 3100
% and the baseline window is 3000:3099.
cfg.baselineLength_remap = 100;

% Which topoplot conditions/contrasts to draw.
% Default: sensory-primed difference, Unexpected - Expected.
cfg.plotConditions = {'Diff_withSP'};

% Fixed remapped axis length (same as ERP script).
cfg.newLen = 5000;

% Output folders.
cfg.outputDir = 'topo_subjectwise';
cfg.multiOutputDir = 'topo_multisubject';

% Multi-subject canvas layout. The default gives 15 subjects as 3 x 5.
cfg.multiSubjectColumns = 5;

% Set true to answer questions in MATLAB at runtime.
cfg.useInteractiveConfig = true;
end
