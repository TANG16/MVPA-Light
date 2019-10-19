function stat = mv_statistics(cfg, result, varargin)
% Performs statistical analysis on classification or regression results of
% the high-level functions such as mv_classify_across time and mv_regress.
%
% Usage:
% stat = mv_statistics(cfg, result, ...)
%
%Parameters:
% result       - struct describing the classification outcome. Can be
%                obtained as second output argument from functions
%                mv_crossvalidate, mv_classify_across_time,
%                mv_classify_timextime, mv_searchlight, mv_classify, and
%                mv_regress.
%
% cfg is a struct with parameters:
% .test        - specify the statistical test that is applied. Some tests
%                are applied to a single subject (and hence need only one
%                result struct as input), some are applied across subjects
%                to a group and hence need a cell array as input
%                'binomial': binomial test [single-subject analysis]
%                            performed on accuracy values (needs a result
%                            using the accuracy metric)
%                'permutation': permutation test calculates p-values by
%                               repeating the classification using shuffled
%                               class labels
% .alpha       - significance threshold (default 0.05)
% .metric      - if results contains multiple metrics, choose the target
%                metric (default [])
%
% Further details regarding specific tests:
% BINOMIAL (single-subject analysis):
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
% The classification or regression analysis is repeated many times using
% shuffle class lavbels or responses.
%
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
mv_set_default(cfg,'chance', 0.5);
mv_set_default(cfg,'feedback', 1);

%% select metric
if isempty(cfg.metric)
    if iscell(result.perf) && numel(result.perf) > 1
        error('Multiple metrics vailable (%s), set cfg.metric to select one', strjoin(metric))
    end
    perf = result.perf;
    metric = result.metric;
else
    if iscell(result.metric)
        ix = (ismember(result.metric, cfg.metric));
        perf = result.perf{ix};
        metric = result.metric{ix};
    elseif strcmp(result.metric)
        perf = result.perf;
        metric = result.metric;
    else
        error('Metric %s requested but only %s available', cfg.metric, result.metric)
    end
end

%% Statistical testing
stat = struct('test',cfg.test,'statistic',[],'p',[]);

switch(cfg.test)
    case 'binomial'
        %%% --- BINOMIAL ---
        if ~ismember(metric, {'acc' 'accuracy'})
            error('Binomial test requires accuracy but the only available metric is %s', metric)
        end
        
        % N is the total number of samples
        n = result.n;
        
        % Calculate p-value using the cumulative distribution function, testing
        % H0: the observed accuracy was due to chance
        stat.p = 1 - binocdf( round(perf * n), n, cfg.chance);

    case 'permutation'
        %%% --- PERMUTATION ---
end

stat.mask = stat.p < cfg.alpha;


% %% Print output
% if cfg.feedback
%     fprintf('\nPerforming a %s test\n',upper(cfg.test))
%     fprintf('p-value(s): %s\n',sprintf('%0.3f ',stat.p) )
%     fprintf('significant (p > alpha): %s\n',sprintf('%d ',stat.mask) )
% end


end