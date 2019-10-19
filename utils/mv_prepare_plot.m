function plt = mv_prepare_plot(metric, perf, perf_std, dimension_names)
% Given set of results, prepares instructions for plotting these results,
% including choice of the plot type (bar, matrix, line, image), labels, and
% legend. 
% Returns plotting instructions used by mv_plot_result.
%
%Usage:
% plt = mv_prepare_plot(caller, metric, perf, perf_std, <dimension_names>)
% 
%Parameters:
% caller           - [string] name of the high-level function used to
%                    generate the result (eg 'mv_crossvalidate')
% metric           - [char or cell array] metric(s)
% perf             - classification performance measure
% perf_std         - standard deviation of perf across folds and repeats
% dimension_names  - names of the dimensions of perf, e.g. 'time points' if perf
%                    is a vector that stems from mv_classify_across_time.
%                    Only required if perf is not scalar
%
%Output:
% plt  - [struct or cell array] with plotting instructions and the
% following fields:
% type    - bar line image 

if ischar(metric), n_metrics = 1;
else               n_metrics = numel(metric);
end
if nargin < 4, dimension_names = ''; end

if ~iscell(metric),   metric = {metric}; end
if ~iscell(perf),     perf = {perf}; end
if ~iscell(perf_std), perf_std = {perf_std}; end

plt = cell(n_metrics);

for mm = 1:n_metrics
    
    % infer dimensionality of result
    if numel(perf{mm}) == 1, nd = 0;
    elseif isvector(perf{mm}), nd = 1;
    else nd = ndims(perf{mm});
    end
    
    % current plot
    p = [];
    p.warning = '';
    p.title = '';
    
    % different types of plots are required for different metrics
    switch metric{mm}
        
        case {'acc' 'accuracy' 'auc' 'tval' 'f1' 'precision' 'recall' 'kappa'}
            p.legend = 0;
            p.legend_label = {};
            if strcmp(metric{mm}, 'tval')
                p.y_zero = 0;
            else
                p.y_zero = 0.5; 
            end
            if nd==0
                p.ylabel = metric{mm};
                p.type = 'bar';
            elseif nd==1
                p.ylabel = metric{mm};
                p.type = 'line';
                p.xlabel = dimension_names{1};
            elseif nd==2
                p.type = 'image';
                p.xlabel = dimension_names{1};
                p.ylabel = dimension_names{2};
                p.colorbar_label =  metric{mm};
            else 
                % what to do with higher-dimensional data?
            end

        case 'confusion'
        case 'dval'
    end    
    plt{mm} = p;
end
