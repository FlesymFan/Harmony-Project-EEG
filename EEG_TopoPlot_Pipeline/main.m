clear; clc;

% Main script for the subject-wise and multi-subject topoplot pipeline.

cfg = config();

if cfg.useInteractiveConfig
    useDefault = strtrim(lower(input('Use default topoplot config? (y/n) [y]: ', 's')));
    if any(strcmp(useDefault, {'n','no'}))
        cfg = configBuilder(cfg);
    end
end

[EEGDataAvg, subjectNames, dataFile] = loadData(cfg);
[topoValuesAll, plotInfo] = scalpValues(EEGDataAvg, subjectNames, cfg);

plotInfo.dataFile = dataFile;

hFig = plotFigure(topoValuesAll, plotInfo, cfg);
saveFigure(hFig, plotInfo, cfg);
