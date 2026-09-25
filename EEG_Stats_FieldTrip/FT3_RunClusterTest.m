function stat = FT3_RunClusterTest(cfg, test)
% FieldTrip performs the paired sign-flip cluster permutation itself.

nSub = numel(cfg.subjectIDs);
ftcfg = [];
ftcfg.channel = test.expected{1}.label;
ftcfg.latency = cfg.scanWin_ms / 1000;
ftcfg.parameter = 'avg';
ftcfg.method = 'montecarlo';
ftcfg.statistic = 'depsamplesT';
ftcfg.correctm = 'cluster';
ftcfg.clusteralpha = 0.05;
ftcfg.clusterstatistic = 'maxsum';
ftcfg.neighbours = [];
ftcfg.minnbchan = 0;
ftcfg.tail = 0;
ftcfg.clustertail = 0;
ftcfg.correcttail = 'prob';
ftcfg.alpha = 0.05;
ftcfg.numrandomization = cfg.nPermutations;
ftcfg.design = [1:nSub 1:nSub; ones(1, nSub) 2*ones(1, nSub)];
ftcfg.uvar = 1;
ftcfg.ivar = 2;

stat = ft_timelockstatistics(ftcfg, test.unexpected{:}, test.expected{:});
end
