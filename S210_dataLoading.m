function [Extract_Data, Extract_Data_Indiv, meta] = S210_dataLoading(conditionNumber)

    %----------------------- Condition name map -------------------------
    conditionNames = containers.Map( ...
        {1, 4, 5}, ...
        {'Broadband', 'Low High', 'High Low'} ...
    );

    %----------------------- Channel layout -----------------------------
    channels = ["F7","F3","Fz","F4","F8", ...
                "FT7","FC3","FCz","FC4","FT8", ...
                "T7","C3","Cz","C4","T8", ...
                "P7","P3","Pz","P4","P8"];

    channel_indices = [7,5,38,40,42,...
                       8,10,47,45,43,...
                       15,13,48,50,52,...
                       23,21,31,58,60];

    %----------------------- Load EEGDataAvg ----------------------------
    filename = sprintf('EEGDataAvgAcrossTrials_allSubject_cond%d.mat', ...
                       conditionNumber);
    load(filename, 'EEGDataAvg');
    fprintf('Loaded: %s\n', filename);

    subjectNames  = fieldnames(EEGDataAvg);
    numSubjects   = numel(subjectNames);
    exampleField  = EEGDataAvg.(subjectNames{1}).ExpwithSensPrim;

    numChannels   = size(exampleField, 1);
    numTimePoints = size(exampleField, 2);

    %----------------------- Preallocate arrays -------------------------
    data_Exp_noSP     = zeros(numSubjects, numChannels, numTimePoints);
    data_Unexp_noSP   = zeros(numSubjects, numChannels, numTimePoints);
    data_Diff_noSP    = zeros(numSubjects, numChannels, numTimePoints);

    data_Exp_withSP   = zeros(numSubjects, numChannels, numTimePoints);
    data_Unexp_withSP = zeros(numSubjects, numChannels, numTimePoints);
    data_Diff_withSP  = zeros(numSubjects, numChannels, numTimePoints);

    data_Atonal       = zeros(numSubjects, numChannels, numTimePoints);

    %----------------------- Fill subject-level data --------------------
    for iSubj = 1:numSubjects
        subjName = subjectNames{iSubj};
        subjData = EEGDataAvg.(subjName);

        % Without sensory priming
        data_Exp_noSP(iSubj, :, :)   = subjData.ExpwithoutSensPrim;
        data_Unexp_noSP(iSubj, :, :) = subjData.UnexpwithoutSensPrim;
        data_Diff_noSP(iSubj, :, :)  = subjData.UnexpwithoutSensPrim - ...
                                       subjData.ExpwithoutSensPrim;

        % With sensory priming
        data_Exp_withSP(iSubj, :, :)   = subjData.ExpwithSensPrim;
        data_Unexp_withSP(iSubj, :, :) = subjData.UnexpwithSensPrim;
        data_Diff_withSP(iSubj, :, :)  = subjData.UnexpwithSensPrim - ...
                                         subjData.ExpwithSensPrim;

        % Atonal
        data_Atonal(iSubj, :, :)       = subjData.Atonal;
    end

    %----------------------- Pack individual-level struct ---------------
    Extract_Data_Indiv = struct();
    Extract_Data_Indiv.Exp_noSP      = data_Exp_noSP;
    Extract_Data_Indiv.Unexp_noSP    = data_Unexp_noSP;
    Extract_Data_Indiv.Diff_noSP     = data_Diff_noSP;
    Extract_Data_Indiv.Exp_withSP    = data_Exp_withSP;
    Extract_Data_Indiv.Unexp_withSP  = data_Unexp_withSP;
    Extract_Data_Indiv.Diff_withSP   = data_Diff_withSP;
    Extract_Data_Indiv.Atonal        = data_Atonal;

    %----------------------- Compute GrandERP + SE ----------------------
    [GrandERP_Exp_noSP,     SE_Exp_noSP]      = computeGrandAndSEM(data_Exp_noSP,     numSubjects);
    [GrandERP_Unexp_noSP,   SE_Unexp_noSP]    = computeGrandAndSEM(data_Unexp_noSP,   numSubjects);
    [GrandERP_Diff_noSP,    SE_Diff_noSP]     = computeGrandAndSEM(data_Diff_noSP,    numSubjects);

    [GrandERP_Exp_withSP,   SE_Exp_withSP]    = computeGrandAndSEM(data_Exp_withSP,   numSubjects);
    [GrandERP_Unexp_withSP, SE_Unexp_withSP]  = computeGrandAndSEM(data_Unexp_withSP, numSubjects);
    [GrandERP_Diff_withSP,  SE_Diff_withSP]   = computeGrandAndSEM(data_Diff_withSP,  numSubjects);

    [GrandERP_Atonal,       SE_Atonal]        = computeGrandAndSEM(data_Atonal,       numSubjects);

    %----------------------- Pack grand-average struct -----------------
    Extract_Data = struct();

    Extract_Data.Exp_noSP.GrandERP      = GrandERP_Exp_noSP;
    Extract_Data.Exp_noSP.SE            = SE_Exp_noSP;

    Extract_Data.Unexp_noSP.GrandERP    = GrandERP_Unexp_noSP;
    Extract_Data.Unexp_noSP.SE          = SE_Unexp_noSP;

    Extract_Data.Diff_noSP.GrandERP     = GrandERP_Diff_noSP;
    Extract_Data.Diff_noSP.SE           = SE_Diff_noSP;

    Extract_Data.Exp_withSP.GrandERP    = GrandERP_Exp_withSP;
    Extract_Data.Exp_withSP.SE          = SE_Exp_withSP;

    Extract_Data.Unexp_withSP.GrandERP  = GrandERP_Unexp_withSP;
    Extract_Data.Unexp_withSP.SE        = SE_Unexp_withSP;

    Extract_Data.Diff_withSP.GrandERP   = GrandERP_Diff_withSP;
    Extract_Data.Diff_withSP.SE         = SE_Diff_withSP;

    Extract_Data.Atonal.GrandERP        = GrandERP_Atonal;
    Extract_Data.Atonal.SE              = SE_Atonal;

    %----------------------- Meta info for later steps ------------------
    meta = struct();
    meta.subjectNames   = subjectNames;
    meta.numSubjects    = numSubjects;
    meta.numChannels    = numChannels;
    meta.numTimePoints  = numTimePoints;

    meta.channels       = channels;
    meta.channel_indices= channel_indices;

    meta.conditionNames = conditionNames;
    meta.conditionNumber= conditionNumber;
end

%======================================================================
% Local helper: GrandERP + SEM from 3D data array
%======================================================================
function [grand, se] = computeGrandAndSEM(data3D, numSubjects)
    % data3D: (subjects × channels × time)
    grand = squeeze(mean(data3D, 1));                 % (channels × time)
    se    = squeeze(std(data3D, 0, 1) ./ sqrt(numSubjects));
end