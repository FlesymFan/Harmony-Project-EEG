function [roiTitle, rowIdxSubset] = S230_getROILabelAndIndices(roiNames, meta)
    
    rowIdxSubset = [];
    if isempty(roiNames)
        roiTitle = 'All channels';
        return;
    end
    
    roiNames = string(roiNames);
    channels = string(meta.channels);
    channel_indices = meta.channel_indices;

    %---------------------- Channel indices for this ROI ----------------
    [tf, loc] = ismember(roiNames, channels);
    if any(~tf)
        warning('Some ROI channels not found: %s', strjoin(roiNames(~tf), ', '));
    end

    validLocs      = loc(tf);
    rowIdxSubset   = channel_indices(validLocs);

    if isempty(rowIdxSubset)
        warning('getROILabelAndIndices: no valid channels found in ROI.');
    end

    %---------------------- ROI label map (frontal/posterior) ----------
    roiLabelMap = containers.Map( ...
        string({ ...
            join(["F7","F3","FT7","FC3"]), ...
            join(["F4","F8","FC4","FT8"]), ...
            join(["T7","C3","P7","P3"]), ...
            join(["C4","T8","P4","P8"]), ...
            join(["F7","F3","FT7","FC3","F4","F8","FC4","FT8"]) ...
        }), ...
        { ...
            'Left Frontal Electrodes', ...
            'Right Frontal Electrodes', ...
            'Left Posterior Electrodes', ...
            'Right Posterior Electrodes', ...
            'Bilateral Frontal Electrodes' ...
        } ...
    );

    % Key is just all roiNames joined with a space, like in your script
    roiKey = join(roiNames);

    if isKey(roiLabelMap, roiKey)
        roiTitle = roiLabelMap(roiKey);
    else
        % Generic fallback if we don't recognize this specific combination
        roiTitle = ['ROI: ', strjoin(cellstr(roiNames), ', ')];
    end
end