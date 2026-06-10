function [EEGDataAvg, subjectNames, dataFile] = topoplotData(cfg)
% Load the averaged ERP data file used by the topoplot pipeline.

dataFile = sprintf(cfg.dataFilePattern, cfg.conditionNumber);

if exist(dataFile, 'file') ~= 2
    error('topoplotData: data file "%s" not found.', dataFile);
end

tmp = load(dataFile);          % must contain EEGDataAvg
if ~isfield(tmp, 'EEGDataAvg')
    error('topoplotData: "%s" does not contain EEGDataAvg.', dataFile);
end

EEGDataAvg = tmp.EEGDataAvg;
subjectNames = fieldnames(EEGDataAvg);
end
