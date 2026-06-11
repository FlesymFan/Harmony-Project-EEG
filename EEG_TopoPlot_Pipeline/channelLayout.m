function [chanLabels, chanXY] = channelLayout()
% 64-channel cap labels and approximate XY positions for topoplots.

chanLabels = dataChannelLabels64();
nChan = numel(chanLabels);
chanXY = nan(nChan, 2);

% Rows are anterior to posterior, left to right.
rows = {
    ["Fp1","Fpz","Fp2"];
    ["AF7","AF3","AFz","AF4","AF8"];
    ["F7","F5","F3","F1","Fz","F2","F4","F6","F8"];
    ["FT7","FC5","FC3","FC1","FCz","FC2","FC4","FC6","FT8"];
    ["T7","C5","C3","C1","Cz","C2","C4","C6","T8"];
    ["TP7","CP5","CP3","CP1","CPz","CP2","CP4","CP6","TP8"];
    ["P9","P7","P5","P3","P1","Pz","P2","P4","P6","P8","P10"];
    ["PO7","PO3","Poz","PO4","PO8"];
    ["O1","Oz","O2","Iz"];
};

nRows = numel(rows);
yVals = linspace(0.9, -0.9, nRows);
coordsMap = containers.Map('KeyType','char','ValueType','any');

for r = 1:nRows
    rowLabels = rows{r};
    nInRow = numel(rowLabels);
    y = yVals(r);

    maxX = sqrt(max(0, 1 - y^2));
    xVals = linspace(-maxX, maxX, nInRow);

    for c = 1:nInRow
        coordsMap(char(rowLabels(c))) = [xVals(c), y];
    end
end

for k = 1:nChan
    lab = char(chanLabels(k));
    if isKey(coordsMap, lab)
        chanXY(k,:) = coordsMap(lab);
    else
        warning('channelLayout: label "%s" not in row layout; placing at (0,0).', lab);
        chanXY(k,:) = [0 0];
    end
end
end

function labels = dataChannelLabels64()
labels = strings(64,1);

% A1-A32 channels 1-32
labels( 1) = "Fp1";
labels( 2) = "AF7";
labels( 3) = "AF3";
labels( 4) = "F1";
labels( 5) = "F3";
labels( 6) = "F5";
labels( 7) = "F7";
labels( 8) = "FT7";
labels( 9) = "FC5";
labels(10) = "FC3";
labels(11) = "FC1";
labels(12) = "C1";
labels(13) = "C3";
labels(14) = "C5";
labels(15) = "T7";
labels(16) = "TP7";
labels(17) = "CP5";
labels(18) = "CP3";
labels(19) = "CP1";
labels(20) = "P1";
labels(21) = "P3";
labels(22) = "P5";
labels(23) = "P7";
labels(24) = "P9";
labels(25) = "PO7";
labels(26) = "PO3";
labels(27) = "O1";
labels(28) = "Iz";
labels(29) = "Oz";
labels(30) = "Poz";
labels(31) = "Pz";
labels(32) = "CPz";

% B1-B32 channels 33-64
labels(33) = "Fpz";
labels(34) = "Fp2";
labels(35) = "AF8";
labels(36) = "AF4";
labels(37) = "AFz";
labels(38) = "Fz";
labels(39) = "F2";
labels(40) = "F4";
labels(41) = "F6";
labels(42) = "F8";
labels(43) = "FT8";
labels(44) = "FC6";
labels(45) = "FC4";
labels(46) = "FC2";
labels(47) = "FCz";
labels(48) = "Cz";
labels(49) = "C2";
labels(50) = "C4";
labels(51) = "C6";
labels(52) = "T8";
labels(53) = "TP8";
labels(54) = "CP6";
labels(55) = "CP4";
labels(56) = "CP2";
labels(57) = "P2";
labels(58) = "P4";
labels(59) = "P6";
labels(60) = "P8";
labels(61) = "P10";
labels(62) = "PO8";
labels(63) = "PO4";
labels(64) = "O2";
end
