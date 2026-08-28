function C = P3B_ClusterPermutation(cfg, D, contrastLabel, condIdx)
% REQUIRED  D from P2_PrepareData. No toolbox.
% EFFECT    Cluster-based permutation test of one difference wave against
%           zero (Maris & Oostenveld, 2007): t at every point, threshold,
%           group adjacent survivors, sum t per cluster, then sign-flip the
%           subjects cfg.nPermutations times to build the null distribution
%           of the largest cluster mass.
% MODIFY    cfg.clusterWin_ms, cfg.clusterAlpha, cfg.nPermutations,
%           cfg.clusterDomain ('roi' = time only, 'scalp' = channel x time).
%
% A significant cluster means an effect exists somewhere in the window.
% Cluster extent is not a confidence interval on onset or offset.

    field = ['Diff_' contrastLabel];
    if ~isfield(D.cond(condIdx).data, field)
        error('P3B_ClusterPermutation: no field %s.', field);
    end

    %---------------------- Restrict to the search window ---------------
    win  = D.targetOnset_ms + cfg.clusterWin_ms;
    tIdx = find(D.t_ms >= win(1) & D.t_ms <= win(2));
    if numel(tIdx) < 2
        error('P3B_ClusterPermutation: window [%g %g] ms has too few samples.', win(1), win(2));
    end
    tWin = D.t_ms(tIdx) - D.targetOnset_ms;      % ms relative to target onset

    A = D.cond(condIdx).data.(field);            % subj x chan x time
    switch lower(cfg.clusterDomain)
        case 'roi'
            X  = mean(A(:, D.roiIdx, tIdx), 2);  % subj x 1 x time
            nb = [];                             % one "channel", no spatial links
            chanUsed = "ROI average";
        case 'scalp'
            X  = A(:, :, tIdx);                  % subj x chan x time
            nb = neighbourMatrix(D.chanXY, cfg.neighbourDist);
            chanUsed = D.chanLabels;
        otherwise
            error('P3B_ClusterPermutation: clusterDomain must be ''roi'' or ''scalp''.');
    end

    [nSubj, nChan, nT] = size(X);
    df    = nSubj - 1;
    tCrit = tinvLocal(1 - cfg.clusterAlpha/2, df);

    %---------------------- Observed clusters ---------------------------
    tObs = tStat(X);
    [obsClusters, obsMass] = findClusters(tObs, tCrit, nb, cfg.clusterTail, cfg.minClusterLength);

    %---------------------- Permutation null ----------------------------
    if ~isempty(cfg.randomSeed), rng(cfg.randomSeed); end
    nPerm   = cfg.nPermutations;
    maxNull = zeros(nPerm,1);

    fprintf('Cluster test: %s, %s, %s domain, %d permutations\n', ...
            contrastLabel, D.cond(condIdx).label, lower(cfg.clusterDomain), nPerm);

    for p = 1:nPerm
        sgn  = sign(rand(nSubj,1) - 0.5);
        sgn(sgn == 0) = 1;
        tPerm = tStat(X .* sgn);                 % sign flip: the exchangeability
        [~, m] = findClusters(tPerm, tCrit, nb, cfg.clusterTail, cfg.minClusterLength);
        if isempty(m), maxNull(p) = 0; else, maxNull(p) = max(abs(m)); end
        if mod(p, max(1,round(nPerm/10))) == 0
            fprintf('  %d%%\n', round(100*p/nPerm));
        end
    end

    %---------------------- p per observed cluster ----------------------
    C = struct();
    C.contrast   = contrastLabel;
    C.filtering  = D.cond(condIdx).label;
    C.domain     = lower(cfg.clusterDomain);
    C.t_ms       = tWin;
    C.tObs       = tObs;
    C.tCrit      = tCrit;
    C.df         = df;
    C.nPerm      = nPerm;
    C.maxNull    = maxNull;
    C.chanLabels = chanUsed;
    C.clusters   = struct('mass',{},'p',{},'tStart_ms',{},'tEnd_ms',{}, ...
                          'peak_t',{},'peak_ms',{},'channels',{});

    for i = 1:numel(obsClusters)
        mask = obsClusters{i};
        mass = obsMass(i);
        pval = (1 + sum(maxNull >= abs(mass))) / (nPerm + 1);   % +1: never report p = 0

        anyT      = find(any(mask,1));
        sub       = tObs; sub(~mask) = 0;
        [~, lin]  = max(abs(sub(:)));
        [pc, pt]  = ind2sub(size(sub), lin);

        cl = struct();
        cl.mass      = mass;
        cl.p         = pval;
        cl.tStart_ms = tWin(min(anyT));
        cl.tEnd_ms   = tWin(max(anyT));
        cl.peak_t    = tObs(pc, pt);
        cl.peak_ms   = tWin(pt);
        cl.channels  = chanUsed(find(any(mask,2)));   %#ok<FNDSB>
        C.clusters(end+1) = cl;
    end

    %---------------------- Report --------------------------------------
    if isempty(C.clusters)
        fprintf('  no clusters passed the forming threshold (|t| > %.2f)\n\n', tCrit);
    else
        fprintf('  %-6s %10s %8s %10s %10s %9s\n', 'sign','mass','p','start ms','end ms','peak ms');
        for i = 1:numel(C.clusters)
            cl = C.clusters(i);
            fprintf('  %-6s %10.1f %8.4f %10.0f %10.0f %9.0f%s\n', ...
                    ternary(cl.mass < 0,'neg','pos'), cl.mass, cl.p, ...
                    cl.tStart_ms, cl.tEnd_ms, cl.peak_ms, ...
                    ternary(cl.p < cfg.alpha, '  *', ''));
        end
        fprintf('\n');
    end
end

% =====================================================================
function t = tStat(X)
% One-sample t against zero along the subject dimension.
% X: subj x chan x time  ->  t: chan x time
    n  = size(X,1);
    m  = mean(X,1);
    sd = std(X,0,1);
    sd(sd == 0) = eps;
    t  = reshape(m ./ (sd/sqrt(n)), size(X,2), size(X,3));
end

function [clusters, masses] = findClusters(t, tCrit, nb, tail, minLen)
% Group suprathreshold points into connected clusters and sum t within each.
% Positive and negative clusters are grown separately so they never merge.
    clusters = {}; masses = [];
    signs = [1 -1];
    if tail > 0, signs = 1; elseif tail < 0, signs = -1; end

    for sg = signs
        if sg > 0, mask = t >  tCrit; else, mask = t < -tCrit; end
        if ~any(mask(:)), continue; end
        lab = labelMask(mask, nb);
        for id = 1:max(lab(:))
            m = (lab == id);
            if numel(find(any(m,1))) < minLen    % too few time samples
                continue;
            end
            clusters{end+1} = m;              %#ok<AGROW>
            masses(end+1)   = sum(t(m));      %#ok<AGROW>
        end
    end
end

function lab = labelMask(mask, nb)
% Flood fill over time neighbours (always) and channel neighbours (if given).
    [nChan, nT] = size(mask);
    lab = zeros(nChan, nT);
    cur = 0;
    hasSpace = ~isempty(nb);

    for c = 1:nChan
        for k = 1:nT
            if ~mask(c,k) || lab(c,k), continue; end
            cur = cur + 1;
            stack = [c k];
            lab(c,k) = cur;
            while ~isempty(stack)
                cc = stack(end,1); kk = stack(end,2); stack(end,:) = [];
                % time neighbours
                for dk = [-1 1]
                    k2 = kk + dk;
                    if k2 >= 1 && k2 <= nT && mask(cc,k2) && ~lab(cc,k2)
                        lab(cc,k2) = cur; stack(end+1,:) = [cc k2]; %#ok<AGROW>
                    end
                end
                % channel neighbours at the same time point
                if hasSpace
                    for c2 = find(nb(cc,:))
                        if mask(c2,kk) && ~lab(c2,kk)
                            lab(c2,kk) = cur; stack(end+1,:) = [c2 kk]; %#ok<AGROW>
                        end
                    end
                end
            end
        end
    end
end

function nb = neighbourMatrix(xy, radius)
% Channels within radius of each other count as spatial neighbours.
    n  = size(xy,1);
    d  = sqrt((xy(:,1)-xy(:,1)').^2 + (xy(:,2)-xy(:,2)').^2);
    nb = d > 0 & d <= radius;
    isolated = find(~any(nb,2));
    for i = isolated(:)'                     % never leave a channel unlinked
        dd = d(i,:); dd(i) = inf;
        [~, j] = min(dd);
        nb(i,j) = true; nb(j,i) = true;
    end
end

function t = tinvLocal(p, df)
    lo = 0; hi = 100;
    for i = 1:200
        mid = (lo+hi)/2;
        x = df/(df + mid^2);
        c = 1 - 0.5*betainc(x, df/2, 0.5);
        if c < p, lo = mid; else, hi = mid; end
    end
    t = (lo+hi)/2;
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end
