function [xi, yi, zi] = scalpInterpolation(values, chanXY)
% Interpolate electrode values across the scalp circle.

values = double(values(:));
chanXY = double(chanXY);

headRadius = 1.0;
gridRes = 500;
plotRadius = headRadius * 1.015;

[xi, yi] = meshgrid(linspace(-plotRadius, plotRadius, gridRes));
mask = (xi.^2 + yi.^2) <= plotRadius^2;

% Smooth virtual points keep the heatmap filled to the circular head edge
% without creating nearest-neighbor bands.
nBoundary = 240;
thBoundary = linspace(0, 2*pi, nBoundary + 1)';
thBoundary(end) = [];
boundaryXY = headRadius * [cos(thBoundary), sin(thBoundary)];
boundaryVals = boundaryValuesIDW(boundaryXY, chanXY, values, 8, 2);

interpXY = [chanXY; boundaryXY];
interpVals = [values; boundaryVals];

F = scatteredInterpolant(interpXY(:,1), interpXY(:,2), interpVals, ...
                         'natural', 'none');
zi = F(xi, yi);
zi(~mask) = NaN;
end

function boundaryVals = boundaryValuesIDW(boundaryXY, chanXY, values, kNearest, powerVal)
% Estimate virtual boundary values from nearby electrodes.

nBoundary = size(boundaryXY, 1);
boundaryVals = nan(nBoundary, 1);

for i = 1:nBoundary
    dx = chanXY(:,1) - boundaryXY(i,1);
    dy = chanXY(:,2) - boundaryXY(i,2);
    dist = sqrt(dx.^2 + dy.^2);

    [distSorted, idx] = sort(dist, 'ascend');
    idx = idx(1:min(kNearest, numel(idx)));
    distSorted = distSorted(1:numel(idx));

    if distSorted(1) < eps
        boundaryVals(i) = values(idx(1));
    else
        w = 1 ./ (distSorted .^ powerVal);
        boundaryVals(i) = sum(w .* values(idx)) / sum(w);
    end
end
end
