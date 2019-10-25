function result = mv_prepare_plot(result, varargin)
% Adds a .plot substruct to the result structure with detailed plotting
% instructions for mv_plot_result (eg type of plot, labels for the axes).
%
%Usage:
% result = mv_prepare_plot(result)
%
%Parameters:
% result            - results struct obtained from one of the
%                     classification functions above. 
%
%Returns:
% result            - struct enhanced with a result.plot struct with
%                     plotting details

% (c) matthias treder

metric                  = result.metric;
perf                    = result.perf;
perf_std                = result.perf_std;
perf_dimension_names    = result.perf_dimension_names;
n_metrics               = result.n_metrics;

if n_metrics == 1
    metric   = {metric};
    perf     = {perf};
    perf_std = {perf_std};
    perf_dimension_names = {perf_dimension_names};
end

plt = cell(n_metrics);

for mm = 1:n_metrics
    
    % number of data dimensions (excluding the metric in case it is
    % multi-dimensional like dval and confusion)
    result_dimensions = numel(setdiff(perf_dimension_names{mm},'metric'));
    
    p = [];
    switch(result_dimensions)
        case 0      %%% --- BAR PLOT ---
            p.type = 'bar';
            p.ylabel = metric{mm};
        case 1      %%% --- LINE PLOT ---
            p.type      = 'line';
            p.xlabel    = perf_dimension_names{1};
        case 2      %%% --- IMAGE PLOT ---
            p.type = 'image';
        otherwise   %%% --- HIGH DIMENSIONAL ---
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

result.plot = plt;