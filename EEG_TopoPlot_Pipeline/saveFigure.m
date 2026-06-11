function figPath = saveFigure(hFig, plotInfo, cfg)
% Save the generated topoplot figure as a MATLAB .fig file.

if isfield(plotInfo, 'nSubjects')
    nSubjects = plotInfo.nSubjects;
else
    nSubjects = 1;
end

if nSubjects > 1 && isfield(cfg, 'multiOutputDir')
    outDirName = cfg.multiOutputDir;
else
    outDirName = cfg.outputDir;
end

outDir = fullfile(pwd, outDirName);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

conditionTag = strjoin(cellstr(plotInfo.conditionNames), '_');
conditionTag = regexprep(conditionTag, '[^A-Za-z0-9_]', '');

if nSubjects == 1 && numel(plotInfo.conditionNames) == 1
    figName = sprintf('Topo_Subj%d_%s_cond%d_%s_%d_%d.fig', ...
                      plotInfo.subjectIndices(1), char(plotInfo.subjectNames(1)), ...
                      plotInfo.conditionNumber, conditionTag, ...
                      plotInfo.timeWindow_remap(1), plotInfo.timeWindow_remap(2));
elseif nSubjects == 1
    figName = sprintf('Topo_Subj%d_%s_cond%d_nCond%d_%s_%d_%d.fig', ...
                      plotInfo.subjectIndices(1), char(plotInfo.subjectNames(1)), ...
                      plotInfo.conditionNumber, numel(plotInfo.conditionNames), ...
                      conditionTag, ...
                      plotInfo.timeWindow_remap(1), plotInfo.timeWindow_remap(2));
else
    figName = sprintf('Topo_MultiSubj_%s_cond%d_nCond%d_%s_%d_%d.fig', ...
                      subjectTag(plotInfo.subjectIndices), ...
                      plotInfo.conditionNumber, numel(plotInfo.conditionNames), ...
                      conditionTag, ...
                      plotInfo.timeWindow_remap(1), plotInfo.timeWindow_remap(2));
end

figPath = fullfile(outDir, figName);
savefig(hFig, figPath);
fprintf('Saved topoplot: %s\n', figPath);
end

function tag = subjectTag(subjectIndices)
    subjectIndices = subjectIndices(:)';

    if numel(subjectIndices) == 1
        tag = sprintf('Subj%d', subjectIndices(1));
    elseif isequal(subjectIndices, subjectIndices(1):subjectIndices(end))
        tag = sprintf('Subj%d-%d', subjectIndices(1), subjectIndices(end));
    else
        tag = sprintf('SubjN%d', numel(subjectIndices));
    end
end
