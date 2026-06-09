function hFig = S240_plotFigure(cfg, Extract_Data, Extract_Data_Indiv, ...
                           meta, timeInfo, roiTitle, rowIdxSubset)

    switch lower(cfg.plotMode)
        case 'roiaverage'
            % 2.4.1. plotROI.m
            hFig = S241_plotROI(cfg, Extract_Data_Indiv, meta, timeInfo, ...
                           roiTitle, rowIdxSubset);

        case 'singlechannel'
            hFig = S242_plotSingleChannel(cfg, Extract_Data_Indiv, meta, timeInfo, roiTitle, rowIdxSubset);

        case 'multichannel'
            hFig = S243_plotMultiChannel(cfg, Extract_Data_Indiv, meta, timeInfo);

        otherwise
            error('plotFigure: unknown plotMode "%s". Use roiAverage, singleChannel, or multiChannel.', ...
                  cfg.plotMode);
    end
end