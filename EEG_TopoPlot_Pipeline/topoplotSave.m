function figPath = topoplotSave(hFig, plotInfo, cfg)
% Save the generated topoplot figure as a MATLAB .fig file.

outDir = fullfile(pwd, cfg.outputDir);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

conditionTag = strjoin(cellstr(plotInfo.conditionNames), '_');
conditionTag = regexprep(conditionTag, '[^A-Za-z0-9_]', '');

if numel(plotInfo.conditionNames) == 1
    figName = sprintf('Topo_Subj%d_%s_cond%d_%s_%d_%d.fig', ...
                      plotInfo.subjectIndex, char(plotInfo.subjectName), ...
                      plotInfo.conditionNumber, conditionTag, ...
                      plotInfo.timeWindow_remap(1), plotInfo.timeWindow_remap(2));
else
    figName = sprintf('Topo_Subj%d_%s_cond%d_nCond%d_%s_%d_%d.fig', ...
                      plotInfo.subjectIndex, char(plotInfo.subjectName), ...
                      plotInfo.conditionNumber, numel(plotInfo.conditionNames), ...
                      conditionTag, ...
                      plotInfo.timeWindow_remap(1), plotInfo.timeWindow_remap(2));
end

figPath = fullfile(outDir, figName);
savefig(hFig, figPath);
fprintf('Saved topoplot: %s\n', figPath);
end
