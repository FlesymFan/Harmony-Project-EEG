function cfg = FT1_Config(dataFolder)

cfg.dataFolder = char(dataFolder);
cfg.subjectIDs = [24 25 26 27 28];
% 1 2 5 6 8 9 10 11 12 13 14 16 17 19 20
cfg.conditionNumbers = [1 4 5];
cfg.contrasts = { ...
    'withSP', 'ExpwithSensPrim', 'UnexpwithSensPrim'; ...
    'noSP', 'ExpwithoutSensPrim', 'UnexpwithoutSensPrim'};
cfg.roiNames = {'Fz', 'F3', 'F4', 'FCz', 'FC3', 'FC4'};
cfg.sampleRate = 1024;
cfg.epochStart_ms = -100;
cfg.targetOnset_ms = 3000;
cfg.baselineWin_ms = [-100 0];
cfg.scanWin_ms = [0 600];
cfg.nPermutations = 5000;
cfg.randomSeed = 42;
cfg.outFolder = fullfile(fileparts(mfilename('fullpath')), 'fieldtrip_results');
end
