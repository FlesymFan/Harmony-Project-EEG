clear; clc;

% Main script for the single-subject topoplot pipeline.

cfg = topoplotConfig();

if cfg.useInteractiveConfig
    useDefault = strtrim(lower(input('Use default topoplot config? (y/n) [y]: ', 's')));
    if any(strcmp(useDefault, {'n','no'}))
        cfg = topoplotConfigBuilder(cfg);
    end
end

[EEGDataAvg, subjectNames, dataFile] = topoplotData(cfg);
[topoValuesAll, plotInfo] = topoplotScalpValues(EEGDataAvg, subjectNames, cfg);

plotInfo.dataFile = dataFile;

hFig = topoplotFigure(topoValuesAll, plotInfo, cfg);
topoplotSave(hFig, plotInfo, cfg);
