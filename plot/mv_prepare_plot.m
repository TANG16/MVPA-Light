function result = mv_prepare_plot(result, varargin)
% Adds a .plot substruct to the result structure with detailed plotting
% instructions for mv_plot_result (eg type of plot, labels for the axes).
%
%Usage:
% result = mv_prepare_plot(result, <x, y>)
%
%Parameters:
% result            - results struct obtained from one of the
%                     classification functions above. 
%
%Returns:
% result            - struct enhanced with a result.plot struct with
%                     plotting details

% (c) matthias treder

tmp = [];
tmp.metric                  = result.metric;
tmp.perf                    = result.perf;
tmp.perf_std                = result.perf_std;
tmp.perf_dimension_names    = result.perf_dimension_names;
n_metrics                   = result.n_metrics;

if n_metrics == 1
    tmp.metric   = {tmp.metric};
    tmp.perf     = {tmp.perf};
    tmp.perf_std = {tmp.perf_std};
    tmp.perf_dimension_names = {tmp.perf_dimension_names};
end

plt = cell(n_metrics);
class_labels = strcat({'class ' }, arrayfun(@(x) {num2str(x)}, 1:result.n_classes));

for mm = 1:n_metrics
    
    metric      = tmp.metric{mm};
    perf        = tmp.perf{mm};
    perf_std    = tmp.perf_std{mm};
    perf_dimension_names = tmp.perf_dimension_names{mm};
    
    % number of data dimensions (excluding the metric in case it is
    % multi-dimensional like dval and confusion)
    result_dimensions = numel(setdiff(perf_dimension_names,'metric'));
    
    p = [];
    p.title = '';

    if strcmp(metric,'confusion')     %%% --- for CONFUSION MATRIX ---
        if result_dimensions == 0
            p.plot_type = 'confusion_matrix';
        else
            p.plot_type = 'interactive';
        end
        p.xlabel = 'Predicted class';
        p.ylabel = 'True class';
        p.title  = 'Confusion matrix';
            
    else
        switch(result_dimensions)
            case 0      %%% --- for BAR PLOT ---
                p.plot_type = 'bar';
                p.ylabel    = metric;
                p.n_bars    = numel(perf);
                if p.n_bars == result.n_classes
                    p.xticklabel = class_labels;
                else
                    p.xticklabel = '';
                end
                
            case 1      %%% --- for LINE PLOT ---
                p.plot_type     = 'line';
                p.xlabel        = perf_dimension_names{1};
                p.ylabel        = metric{mm};
                p.add_legend    = strcmp(metric{mm},'dval');
                p.legend_labels = class_labels;
                
            case 2      %%% --- for IMAGE PLOT ---
                p.plot_type = 'image';
                p.ylabel        = perf_dimension_names{1};
                p.xlabel        = perf_dimension_names{end};
                
                %%% TODO ...
                
            otherwise   %%% --- for HIGH DIMENSIONAL ---
                p.plot_type = 'interactive';
        end
    end
    
    % Add options for graphical elements
    p.text_options = {'Fontsize',15,'HorizontalAlignment','center'};
    p.legend_options = {'Interpreter','none'};
    p.label_options = {'Fontsize', 14};
    p.title_options = {'Fontsize', 16, 'Fontweight', 'bold'};
    p.errorbar_options = {'Color' 'k' 'LineWidth' 1.5};
    
    % metric-specific settings
    switch(metric)
        case {'auc', 'acc','accuracy','precision','recall','f1'}
            p.hor = 1 / result.n_classes;
        otherwise
            p.hor = 0;     
    end
    p.climzero = p.hor;
    
    % current plot
    p.warning = '';
    
  
    plt{mm} = p;
end

result.plot = plt;