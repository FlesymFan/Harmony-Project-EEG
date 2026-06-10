function hFig = scalpMapPanel(values, chanLabels, chanXY, clim, titleStr, ax, showColorbar)
% Draw one scalp map into one axes.

if nargin < 3
    error('scalpMapPanel: need values, chanLabels, chanXY.');
end

values = double(values(:));
chanLabels = string(chanLabels(:));
chanXY = double(chanXY);

if size(chanXY, 1) ~= numel(values)
    error('scalpMapPanel: chanXY rows (%d) must match values (%d).', ...
          size(chanXY, 1), numel(values));
end

if nargin < 4 || isempty(clim)
    clim = defaultColorLimits(values);
end
if nargin < 5
    titleStr = '';
end
if nargin < 6 || isempty(ax)
    hFig = figure('Color','w');
    ax = axes('Parent', hFig);
else
    hFig = ancestor(ax, 'figure');
end
if nargin < 7 || isempty(showColorbar)
    showColorbar = true;
end

[xi, yi, zi] = scalpInterpolation(values, chanXY);

axes(ax); %#ok<LAXES>
cla(ax);
hold on;

contourf(xi, yi, zi, 80, 'LineColor', 'none');
colormap(ax, blueWhiteRedColormap(256));
caxis(clim);

if showColorbar
    cb = colorbar;
    cb.Label.String = 'Voltage (\muV)';
    cb.Label.FontSize = 16;
    cb.FontSize = 14;
end

headTemplate(ax);

scatter(chanXY(:,1), chanXY(:,2), 40, 'k', 'filled');

labelFontSize = 13;
for k = 1:numel(values)
    text(chanXY(k,1), chanXY(k,2), char(chanLabels(k)), ...
        'HorizontalAlignment','center', ...
        'VerticalAlignment','bottom', ...
        'FontSize', labelFontSize, ...
        'Color','k');
end

axis equal off;

if ~isempty(titleStr)
    title(titleStr, ...
          'FontName','Arial', ...
          'FontSize',18, ...
          'Interpreter','none');
end

hold off;
end

function clim = defaultColorLimits(values)
    vAbs = abs(values(:));
    vAbs = vAbs(~isnan(vAbs));

    if isempty(vAbs)
        vMax = 1;
    else
        vMax = prctile(vAbs, 99);
        if vMax == 0
            vMax = max(vAbs);
            if vMax == 0
                vMax = 1;
            end
        end
    end

    clim = [-vMax, vMax];
end

function cmap = blueWhiteRedColormap(nCol)
    half = nCol / 2;
    r = [linspace(0,1,half)'; ones(half,1)];
    g = [linspace(0,1,half)'; linspace(1,0,half)'];
    b = [ones(half,1);       linspace(1,0,half)'];
    cmap = [r g b];
end
