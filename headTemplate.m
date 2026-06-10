function headTemplate(ax)
% Draw the scalp outline, nose, and ears for one topoplot panel.

if nargin < 1 || isempty(ax)
    ax = gca;
end

axes(ax); %#ok<LAXES>

headRadius = 1.0;

% Head circle
th = linspace(0, 2*pi, 360);
plot(headRadius*cos(th), headRadius*sin(th), 'k', 'LineWidth', 2);

% Nose
noseBaseY = headRadius;
noseApexY = headRadius + 0.12;
noseHalfW = 0.12;
noseXs = [-noseHalfW, 0, noseHalfW, -noseHalfW];
noseYs = [noseBaseY, noseApexY, noseBaseY, noseBaseY];
plot(noseXs, noseYs, 'k', 'LineWidth', 2);

% Ears attached to the circle boundary
earH = 0.25;
earW = 0.10;
xEdge = sqrt(headRadius^2 - earH^2);
yTop = earH;
yBot = -earH;

rightEarX = [xEdge, xEdge+earW, xEdge+earW, xEdge];
rightEarY = [yTop,  yTop*0.55,  yBot*0.55,  yBot];
leftEarX = -rightEarX;
leftEarY = rightEarY;

plot(rightEarX, rightEarY, 'k', 'LineWidth', 2);
plot(leftEarX, leftEarY, 'k', 'LineWidth', 2);
end
