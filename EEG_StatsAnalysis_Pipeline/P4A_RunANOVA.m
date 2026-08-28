function R = P4A_RunANOVA(cfg, D, amp, longTbl) % REQUIRED  amp from P3A_MeanAmplitude. fitrm/ranova need the Statistics
%           Toolbox; the t-tests use local helpers and run without it.
% EFFECT    Repeated-measures ANOVA, Expectancy x Priming x Filtering, all
%           within subject, plus one-sample t-tests of each difference wave
%           against zero with Cohen's dz and a CI.
% MODIFY    cfg.alpha; cfg.contrasts to change which difference waves are tested.
%
% The ERAN is the main effect of Expectancy. Expectancy x Priming tests
% whether it survives when context and target share no pitches.
% If Mauchly p < .05, read pValueGG rather than pValue.

    R = struct();
    nCond = numel(D.cond);

    %================== 1) one-sample t-tests ===========================
    fprintf('\n--- Difference wave vs zero (%g-%g ms, ROI) ---\n', ...
            cfg.eranWin_ms(1), cfg.eranWin_ms(2));
    fprintf('%-10s %-12s %8s %8s %8s %8s %10s %s\n', ...
            'priming','filtering','mean','sd','t','df','p','dz');

    rows = {};
    for c = 1:size(cfg.contrasts,1)
        lbl   = cfg.contrasts{c,1};
        field = ['Diff_' lbl];
        for k = 1:nCond
            v  = amp.(field)(:,k);
            n  = numel(v);
            m  = mean(v);
            sd = std(v);
            se = sd/sqrt(n);
            tv = m/se;
            df = n-1;
            p  = 2*(1 - localTcdf(abs(tv), df));
            dz = m/sd;                       % Cohen's dz for a paired design
            ci = m + [-1 1]*localTinv(1-cfg.alpha/2, df)*se;

            fprintf('%-10s %-12s %8.3f %8.3f %8.2f %8d %10.4f %6.2f\n', ...
                    lbl, D.cond(k).label, m, sd, tv, df, p, dz);
            rows(end+1,:) = {lbl, D.cond(k).label, m, sd, tv, df, p, dz, ci(1), ci(2)}; %#ok<AGROW>
        end
    end
    R.ttests = cell2table(rows, 'VariableNames', ...
        {'Priming','Filtering','Mean','SD','t','df','p','dz','CI_lo','CI_hi'});

    %================== 2) repeated-measures ANOVA ======================
    if exist('fitrm','file') ~= 2
        warning('P4A_RunANOVA: Statistics Toolbox not found; skipping the ANOVA.');
        R.anova = [];
        return;
    end

    % Wide format: one column per cell, rows = subjects.
    cells = {'ExpwithSensPrim','withSP','Expected'; ...
             'UnexpwithSensPrim','withSP','Unexpected'; ...
             'ExpwithoutSensPrim','noSP','Expected'; ...
             'UnexpwithoutSensPrim','noSP','Unexpected'};

    Y = []; Expectancy = {}; Priming = {}; Filtering = {}; vn = {};
    for k = 1:nCond
        for c = 1:size(cells,1)
            Y(:,end+1)      = amp.(cells{c,1})(:,k);            %#ok<AGROW>
            Priming{end+1}  = cells{c,2};                       %#ok<AGROW>
            Expectancy{end+1} = cells{c,3};                     %#ok<AGROW>
            Filtering{end+1}  = D.cond(k).label;                %#ok<AGROW>
            vn{end+1} = sprintf('Y%d', size(Y,2));              %#ok<AGROW>
        end
    end

    within = table(categorical(Expectancy(:)), categorical(Priming(:)), ...
                   categorical(Filtering(:)), ...
                   'VariableNames', {'Expectancy','Priming','Filtering'});

    tblWide = array2table(Y, 'VariableNames', vn);
    rm = fitrm(tblWide, sprintf('%s-%s ~ 1', vn{1}, vn{end}), 'WithinDesign', within);

    R.rm    = rm;
    R.anova = ranova(rm, 'WithinModel', 'Expectancy*Priming*Filtering');

    fprintf('\n--- Repeated-measures ANOVA (Expectancy x Priming x Filtering) ---\n');
    disp(R.anova);

    try
        R.mauchly = mauchly(rm);
        fprintf('--- Mauchly sphericity test ---\n');
        disp(R.mauchly);
        fprintf(['If Mauchly p < .05, read the pValueGG column of the ANOVA table ' ...
                 '(Greenhouse-Geisser corrected) rather than pValue.\n']);
    catch
        % mauchly needs more than one within level per factor; skip quietly.
    end
end

% ---------------------------------------------------------------------
% Local t distribution helpers, so the t-tests run without the toolbox.
function p = localTcdf(t, df)
    x = df ./ (df + t.^2);
    p = 1 - 0.5 * betainc(x, df/2, 0.5);
end

function t = localTinv(p, df)
    lo = 0; hi = 100;
    for i = 1:200                      % bisection is plenty for a CI bound
        mid = (lo+hi)/2;
        if localTcdf(mid, df) < p, lo = mid; else, hi = mid; end
    end
    t = (lo+hi)/2;
end
