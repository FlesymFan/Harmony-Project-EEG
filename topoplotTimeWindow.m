function [newTimeAxis, inWin, idx_old] = topoplotTimeWindow(meta, cfg, window_remap)
% Map a remapped topoplot time window back to sample indices.

if isfield(meta, 'numTimePoints')
    oldLen = meta.numTimePoints;
else
    oldLen = meta.oldLen;
end

newLen = cfg.newLen;
t1 = window_remap(1);
t2 = window_remap(2);

newTimeAxis = linspace(1, newLen, oldLen);
inWin = (newTimeAxis >= t1) & (newTimeAxis <= t2);
idx_old = find(inWin);

if isempty(idx_old)
    error('topoplotTimeWindow: window [%d %d] produced no samples.', t1, t2);
end
end
