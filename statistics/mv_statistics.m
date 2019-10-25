function stat = mv_statistics(cfg, result, X, y)
% Performs statistical analysis on classification or regression results of
% the high-level functions such as mv_classify_across time and mv_regress.
%
% mv_statistics implements level 1 (subject-level) statistical analysis.
%
% Usage:
% stat = mv_statistics(cfg, result, X, y)
%
%Parameters:
% result       - struct describing the classification outcome. Can be
%                obtained as second output argument from functions
%                mv_crossvalidate, mv_classify_across_time,
%                mv_classify_timextime, mv_searchlight, mv_classify, and
%                mv_regress.
% X            - input data used to obtain result
% y            - input class labels or responses used to obtain result
%
% cfg is a struct with parameters:
% .test        - specify the statistical test that is applied. Some tests
%                are applied to a single subject (and hence need only one
%                result struct as input), some are applied across subjects
%                to a group and hence need a cell array as input
%                'binomial': binomial test (classification only) is 
%                            performed on accuracy values. Requires a 
%                            classification result using the accuracy metric
%                'permutation': permutation test calculates p-values by
%                               repeating the classification using shuffled
%                               class labels or repsonse values
% .alpha       - significance threshold (default 0.05)
% .metric      - if results contains multiple metrics, choose the target
%                metric (default [])
% .width       - width of progress bar in characters (default 20)
%
% Further details regarding specific tests:
%
% BINOMIAL:
% Uses a binomial distribution to calculate the p-value under the null
% hypothesis that classification accuracy = chance (typically 0.5)
% Treating results from cross-validation analysis: since the 
% sum (which is the unnormalized mean) of binomially distributed variables 
% is binomial, too, we can treat the results on the folds and repetitions
% as a single large binomial test. This is possible because the 
% classification accuracy has been calculated using weighted averaging, and
% hence the total number of hits is equal to the average accuracy *  total
% number of samples.
% Additional parameters for binomial test:
% .chance      - specify chance level (default 0.5)
%
% PERMUTATION:
% Permutation testing is a non-parametric approach based on an empirical
% null-distribution obtained via permutations. To this end, the
% multivariate analysis is repeated many times (typically 1000's) with
% class labels/responses being randomly shuffled 
% The classification or regression analysis is repeated many times using
% randomly shuffled class labels or responses.
% Additional parameters for permutation test:
% .n_permutations        - number of permutations (default 1000)
% .correctm              - correction applied for multiple comparisons
%                         'none'
%                         'bonferroni'
%                         'cluster'
% .tail                 - -1 or 1 (default = 1), specifies whether the
%                          lower tail (-1), or the upper tail (+1) is 
%                          computed Typically, for accuracy
%                          measures such as AUC, precision/recall etc we
%                          set tail=1 since we want to test whether
%                          the performance metric is larger than expected
%                          by chance. Vice versa, for error metrics often 
%                          used in regression (eg MSE, MAE), tail=-1 since
%                          we want to check whether the error is lower than
%                          expected. (two-tailed testing is current not
%                          supported)
% .keep_null_distribution - if 1, the full null distribution is saved 
%                          in a matrix [n_permutations x (size of result)].
%                          Note that for multi-dimensional data this matrix
%                          can be very large (default 0)
% 
% For cluster-based multiple comparisons correction the procedure laid out
% in Maris & Oostenveld (2007) and implemented in FieldTrip is followed.
% Here, the classification or regression metrics serve as statistics that
% quantify the difference between experimental conditions. The following 
% options determine how the metrics will be thresholded and combined into 
% one statistical value per cluster. 
% 
%   .clusterstatistic    - how to combine the single samples that belong to 
%                          a cluster, 'maxsum', 'maxsize' (default = 'maxsum')
%   .clustercritval      - cutoff-value for thresholding (this parameter 
%                          must be set by the user). For instance it could
%                          be 0.7 for classification accuracy so that all
%                          accuracy values >= 0.7 would be considered for
%                          clusters. If clustertail=0, a vector of two
%                          numbers must be provided (high and low cutoff).
%                          The exact numerical choice of the critical
%                          value is up to the user (see Maris & Oostenveld, 
%                          2007, discussion).
%    .conndef            - 'minimal' or 'maximal', how neighbours are
%                          defined. Minimal means only directly
%                          neighbouring elements in a matrix are
%                          neighbours. Maximal means that also diagonally
%                          related elements are considered neighbours. E.g.
%                          in the matrix [1 2; 3 4] 1 and 4 are neighbours
%                          for conndef ='maximal' but not 'minimal'
%                          (default 'minimal'). Note that this requires the
%                          Image Processing Toolbox. 
%   .neighbours          - in some cases the neighbourhood cannot be
%                          purely spatially (eg when one dimension encodes
%                          channels). A cell array of binary matrices can
%                          be used in this case.
%                          (see mv_classify or mv_searchlight for details)
%
%
% Returns:
% stat       - structure with description of the statistical result.
%              Important fields:
%           stat.p       - matrix of p-values
%           stat.mask    - logical significance mask (giving 1 when p < alpha)
%
% Reference:
% Maris, E., & Oostenveld, R. (2007). Nonparametric statistical testing of 
% EEG- and MEG-data. Journal of Neuroscience Methods, 164(1), 177–190. 
% https://doi.org/10.1016/j.jneumeth.2007.03.024


%Output:
% stat - struct with statistical output

% (c) Matthias Treder

%                For group analysis (across subjects), a cell array should
%                be provided where each element corresponds to one subject.
%                For instance, result{1} corresponds to the first subject,
%                result{2} to the second, and so on.
% 
%                In case of multiple conditions, additional structs or
%                struct arrays can be provided as additional input arguments 
%                out2, out3, etc.


mv_set_default(cfg,'alpha', 0.05);
mv_set_default(cfg,'metric', []);
mv_set_default(cfg,'feedback', 1);
mv_set_default(cfg,'width', 30);

mv_set_default(cfg,'chance', 0.5);

mv_set_default(cfg,'correctm', 'none');
mv_set_default(cfg,'n_permutations', 1000);
mv_set_default(cfg,'clusterstatistic', 'maxsum');
mv_set_default(cfg,'tail', 1);
mv_set_default(cfg,'keep_null_distribution', false);
mv_set_default(cfg,'conndef', 'minimal');

%% Statistical testing
stat = struct('test',cfg.test,'alpha',cfg.alpha);

switch(cfg.test)
    case 'binomial'
        %%% --- BINOMIAL ---
        if ~iscell(result.metric)
            metric = {result.metric}; 
            perf = {result.perf}; 
        else
            metric = result.metric;
            perf = result.perf; 
        end
        ix = find(ismember(metric, {'acc' 'accuracy'}));
        if isempty(ix)
            error('Binomial test requires accuracy but the only available metric is %s', strjoin(metric))
        end
        perf = perf{ix};
        stat.chance = cfg.chance;
        
        % N is the total number of samples
        n = result.n;
        
        % Calculate p-value using the cumulative distribution function, testing
        % H0: the observed accuracy was due to chance
        stat.p = 1 - binocdf( floor(perf * n), n, cfg.chance);

        % Create binary mask (1 = significant)
        stat.mask = stat.p < cfg.alpha;

    case 'permutation'
        %%% --- PERMUTATION ---
        check_for_multiple_metrics;
        result.cfg.metric = metric;
        result.cfg.feedback = 0;
        is_clustertest = strcmp(cfg.correctm, 'cluster');

        % some sanity checks
        if nargin<4, error('Data and class labels/responses need to be provided as inputs for permutation tests'); end
        if strcmp(cfg.correctm, 'cluster') && ~isfield(cfg, 'clustercritval')
            error('cfg.correctm=''cluster'' but cfg.clustercritval is not set')
        end
        
        % high-level function
        fun = eval(['@' result.function]);
        
        % bonferroni correction of alpha value
        if strcmp(cfg.correctm, 'bonferroni')
            alpha = cfg.alpha / numel(result.perf);
        else
            alpha = cfg.alpha;
        end
        
        if cfg.feedback
            if strcmp(cfg.correctm, 'none'), cor = 'no'; else cor = cfg.correctm; end
            fprintf('Performing permutation test with %s correction for multiple comparisons.\n', cor);
        end
        
        if is_clustertest
            % Initialize cluster test: find initial clusters and calculate 
            % cluster sizes. Keep it stored in vector
            conn = conndef(ndims(result.perf), cfg.conndef); % init connectivity type
            critval = cfg.clustercritval;
            if cfg.tail == 1, C = (perf > critval);
            else C = (perf < critval);
            end
            CC_init = bwconncomp(C,conn);
            n_clusters = numel(CC_init.PixelIdxList);
            if n_clusters == 0; error('Found no clusters in input data. Consider changing clustercritval'), end
            if cfg.feedback, fprintf('Found %d clusters.\n', n_clusters); end
            
            real_clusterstat = compute_cluster_statistic(CC_init, perf, 0);
            % 2) after each permutation recalculate clusters and cluster values
            % and create a counts vector (a count for each original cluster)
            counts = zeros(size(real_clusterstat));
        else
            % Standard permutation test:
            % represents the histogram: counts how many times the permutation
            % statistic is more extreme that the reference values in perf
            counts = zeros(size(perf));
            if cfg.keep_null_distribution, null_distribution = zeros([cfg.n_permutations, size(perf)]); end
        end
        
        if cfg.feedback, fprintf('Running %d permutations ', cfg.n_permutations); end
        
        % run permutations
        for n=1:cfg.n_permutations
            
            % permute class labels/responses
            y_perm = y(randperm(result.n), :);
            
            % run mvpa with permuted data
            permutation_perf = fun(result.cfg, X, y_perm);
            if cfg.keep_null_distribution, null_distribution(n,:,:,:,:,:,:,:,:,:,:,:) = permutation_perf; end
            
            if is_clustertest
                if cfg.tail == 1, C = (permutation_perf > critval);
                else C = (permutation_perf < critval);
                end
                CC = bwconncomp(C,conn);
                permutation_clusterstat = compute_cluster_statistic(CC, permutation_perf, 1);
                if ~isempty(permutation_clusterstat)
                    if cfg.tail == 1
                        counts = counts + double(permutation_clusterstat > real_clusterstat);
                    else
                        counts = counts + double(permutation_clusterstat < real_clusterstat);
                    end
                end
            else
                % standard permutation test
                if cfg.tail == 1
                    counts = counts + double(permutation_perf > perf);
                else
                    counts = counts + double(permutation_perf < perf);
                end
            end
            
            % update progress bar
            if cfg.feedback, mv_print_progress_bar(n, cfg.n_permutations, cfg.width); end

        end
        if cfg.feedback, fprintf('\n'); end
        
        stat.p = counts / cfg.n_permutations;
        if is_clustertest
            sig = find(stat.p < cfg.alpha);
            stat.mask = false(size(perf));
            stat.mask_with_cluster_numbers = zeros(size(perf));
            for ii=1:numel(sig)
                stat.mask(CC_init.PixelIdxList{sig(ii)}) = true;
                stat.mask_with_cluster_numbers(CC_init.PixelIdxList{sig(ii)}) = sig(ii);
            end
            stat.n_significant_clusters = numel(sig);
        else
            stat.mask = stat.p < cfg.alpha;
        end
        
        stat.correctm = cfg.correctm;
        stat.n_permutations = cfg.n_permutations;
        if cfg.keep_null_distribution, stat.null_distribution = null_distribution; end
end

%% -- helper functions --
    function check_for_multiple_metrics
        if isempty(cfg.metric)
            if iscell(result.perf) && numel(result.perf) > 1
                error('Multiple metrics available (%s), you need to set cfg.metric to select one', strjoin(result.metric))
            end
            perf = result.perf;
            metric = result.metric;
        else
            if iscell(result.metric)
                ix = (ismember(result.metric, cfg.metric));
                perf = result.perf{ix};
                metric = result.metric{ix};
            elseif strcmp(result.metric, cfg.metric)
                perf = result.perf;
                metric = result.metric;
            else
                error('Metric %s requested but only %s available', cfg.metric, result.metric)
            end
        end
    end

    function clusterstat = compute_cluster_statistic(CC, P, max_only)
        % max_only : if 1 returns only the cluster statistic for the
        % largest cluster
        switch(cfg.clusterstatistic)
            case 'maxsize'
                clusterstat = cellfun(@numel, CC.PixelIdxList);
            case 'maxsum'
                clusterstat = cellfun(@(ix) sum(P(ix)), CC.PixelIdxList);
        end
        if max_only
            clusterstat = max(clusterstat);
        end
    end
end