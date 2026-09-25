function [roiTitle, rowIdxSubset] = S230_getROILabelAndIndices(roiNames, meta, customList)
    
% Resolve channel labels to data-row indices, and hold the channel table.

% Lookups: 
% - S230_getROILabelAndIndices('print')            print the lookup table
% - labels = S230_getROILabelAndIndices('all')     64 labels in row order
% - [names, idx] = S230_getROILabelAndIndices('select', mode)
%       mode: 'koelsch20' | 'all64' | 'custom'

 
    %---------------------- Dispatch on keyword forms -------------------
    if (ischar(roiNames) || isstring(roiNames)) && isscalar(string(roiNames))
        kw = lower(char(roiNames));
        switch kw
            case 'print'
                printChannelTable();
                roiTitle = ''; rowIdxSubset = [];
                return;
            case 'all'
                roiTitle = channelLabels64();
                rowIdxSubset = 1:64;
                return;
            case 'select'
                if nargin < 2, mode = 'koelsch20'; else, mode = meta; end
                if nargin < 3, customList = []; end
                [names, idx] = selectChannels(lower(char(mode)), customList);
                roiTitle = names; rowIdxSubset = idx;
                return;
        end
    end
 
    %---------------------- Normal ROI resolution -----------------------
    rowIdxSubset = [];
    if isempty(roiNames)
        roiTitle = 'All channels';
        return;
    end
 
    roiNames     = string(roiNames);
    roiNames     = roiNames(:)';
    rowIdxSubset = labelsToIndices(roiNames);
 
    knownROIs = {
        ["F7","F3","FT7","FC3"],                       'Left Frontal Electrodes';
        ["F4","F8","FC4","FT8"],                       'Right Frontal Electrodes';
        ["F7","F3","FT7","FC3","F4","F8","FC4","FT8"], 'Bilateral Frontal Electrodes';
        ["T7","C3","P7","P3"],                         'Left Posterior Electrodes';
        ["C4","T8","P4","P8"],                         'Right Posterior Electrodes';
        ["Fz","F3","F4","FCz","FC3","FC4"],            'Frontal ROI (Leino et al., 2007)'
    };
 
    roiTitle = '';
    key = sort(lower(roiNames));
    for k = 1:size(knownROIs,1)
        if isequal(key, sort(lower(knownROIs{k,1})))
            roiTitle = knownROIs{k,2};
            break;
        end
    end
    if isempty(roiTitle)
        roiTitle = ['ROI: ', strjoin(cellstr(roiNames), ', ')];
    end
end
 
% =====================================================================
% Channel table. Labels are the BioSemi A1-A32 / B1-B32 order from
% BioSemi64.loc, with that file's casing typos (Afz, Poz) normalised.
% =====================================================================
function labels = channelLabels64()
    labels = [ ...
        "Fp1", "AF7", "AF3", "F1",  "F3",  "F5",  "F7",  "FT7", ...
        "FC5", "FC3", "FC1", "C1",  "C3",  "C5",  "T7",  "TP7", ...
        "CP5", "CP3", "CP1", "P1",  "P3",  "P5",  "P7",  "P9",  ...
        "PO7", "PO3", "O1",  "Iz",  "Oz",  "POz", "Pz",  "CPz", ...
        "Fpz", "Fp2", "AF8", "AF4", "AFz", "Fz",  "F2",  "F4",  ...
        "F6",  "F8",  "FT8", "FC6", "FC4", "FC2", "FCz", "Cz",  ...
        "C2",  "C4",  "C6",  "T8",  "TP8", "CP6", "CP4", "CP2", ...
        "P2",  "P4",  "P6",  "P8",  "P10", "PO8", "PO4", "O2"];
end
 
function names = koelsch20()
    % Ordered so a 4x5 grid reads left-to-right, front-to-back.
    names = ["F7","F3","Fz","F4","F8", ...
             "FT7","FC3","FCz","FC4","FT8", ...
             "T7","C3","Cz","C4","T8", ...
             "P7","P3","Pz","P4","P8"];
end
 
function printChannelTable()
    labels = channelLabels64();
    k20    = koelsch20();
    ab     = strings(1,64);
    for i = 1:32, ab(i) = sprintf("A%d", i); ab(32+i) = sprintf("B%d", i); end
 
    fprintf('\n  BioSemi 64-channel lookup (data row -> label)\n');
    fprintf('  * marks the 20 channels in the Koelsch 20 montage\n\n');
    fprintf('   %-4s %-6s %-5s %-3s  |  %-4s %-6s %-5s %-3s\n', ...
            'row','label','A/B','K20','row','label','A/B','K20');
    fprintf('   %s\n', repmat('-',1,58));
    for i = 1:32
        j = i + 32;
        fprintf('   %-4d %-6s %-5s %-3s  |  %-4d %-6s %-5s %-3s\n', ...
                i, labels(i), ab(i), star(labels(i),k20), ...
                j, labels(j), ab(j), star(labels(j),k20));
    end
    fprintf('\n');
end
 
function s = star(label, k20)
    if any(strcmpi(label, k20)), s = '*'; else, s = ''; end
end
 
function [names, idx] = selectChannels(mode, custom)
    switch mode
        case 'koelsch20'
            names = koelsch20();
 
        case 'all64'
            names = channelLabels64();
 
        case 'custom'
            if isempty(custom)
                printChannelTable();
                fprintf('  Enter channels as labels (e.g. F3 Fz F4 FC3) or as row\n');
                fprintf('  numbers (e.g. 5 38 40 10). Spaces or commas.\n\n');
                raw = strtrim(input('  Channels: ', 's'));
                if isempty(raw)
                    fprintf('  No entry; using the Koelsch 20 montage.\n');
                    names = koelsch20();
                else
                    names = parseEntry(raw);
                end
            else
                names = normaliseCustom(custom);
            end
 
        otherwise
            error(['S230_getROILabelAndIndices: unknown channel mode "%s". ' ...
                   'Use koelsch20, all64, or custom.'], mode);
    end
    idx = labelsToIndices(names);
end
 
function names = parseEntry(raw)
    parts = strsplit(strtrim(strrep(raw, ',', ' ')));
    parts = parts(~cellfun(@isempty, parts));
    nums  = str2double(parts);
    if all(~isnan(nums))
        names = normaliseCustom(nums);
    else
        names = string(parts);
    end
end
 
function names = normaliseCustom(custom)
    if isnumeric(custom)
        bad = custom < 1 | custom > 64 | custom ~= round(custom);
        if any(bad)
            error('S230_getROILabelAndIndices: row indices must be integers 1..64. Bad: %s', ...
                  mat2str(custom(bad)));
        end
        labels = channelLabels64();
        names  = labels(custom(:)');
    else
        names = string(custom);
        names = names(:)';
    end
    if isempty(names)
        error('S230_getROILabelAndIndices: empty channel selection.');
    end
end
 
function idx = labelsToIndices(names)
    labels = channelLabels64();
    names  = string(names);
    names  = names(:)';
    idx    = zeros(1, numel(names));
    for k = 1:numel(names)
        hit = find(strcmpi(labels, names(k)), 1);
        if isempty(hit)
            error(['S230_getROILabelAndIndices: unknown channel "%s". ' ...
                   'Run S230_getROILabelAndIndices(''print'') for the list.'], names(k));
        end
        idx(k) = hit;
    end
end