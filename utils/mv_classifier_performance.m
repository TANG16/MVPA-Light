function perf = mv_classifier_performance(metric, cf_output, label, dim)
%Calculates a classifier performance metric such as classification accuracy
%based on the classifier output (labels or decision values). In
%cross-validation, the metric needs to be calculated on each test fold
%separately and then averaged across folds, since a different classifier
%has been trained in each fold.
%
%Usage:
%  perf = mv_classifier_performance(metric, cf_output, label, dim)
%
%Parameters:
% metric            - desired performance metric:
%                     'acc': classification accuracy, i.e. the fraction
%                     correctly predicted labels labels
%                     'dval': decision values. Average dvals are calculated
%                     for each class separately. The first dimension of
%                     the output refers to the class, ie perf(1,...)
%                     refers to class 1 and perf(2,...) refers to class 2
%                     'auc': area under the ROC curve
%                     'roc': ROC curve TODO
% cf_output         - vector of classifier outputs (labels or dvals). If
%                     multiple test sets have been validated using
%                     cross-validation, a (possibly mult-dimensional) 
%                     cell array should be provided with each cell 
%                     corresponding to one test set.
% label             - vector of true class labels. If multiple test sets
%                     have been validated using cross-validation, a cell
%                     array of labels should be provided
% dim               - index of dimension across which values are averaged
%                     (e.g. dim=2 if the second dimension is the number of
%                     repeats of a cross-validation). Default: [] (no
%                     averaging)
%
%Note: cf_output is typically a cell array. The following functions provide
%classifier output as multi-dimensional cell arrays:
% - mv_crossvalidate: 2D [repeats x K] cell array
% - mv_classify_across_time: 3D [repeats x K x time points] cell array
% - mv_classify_timextime: 3D [repeat x K x time points] cell array
%
% In all three cases, however, the corresponding label array is just 
% [repeats x K] since
% the labels are repeated for all time points. If cf_output has more
% dimensions than label, the label array is assumed to be identical across
% the extra dimensions.
%
% Each cell should contain a [testlabel x 1] vector of classifier outputs
% (ie labels or dvals) for the according test set. Alternatively, it can
% contain a [testlabel x ... x ...] matrix, like the output of
% mv_classify_timextime. But then all other dimensions need to have the
% same size.
%
%Returns:
% perf - performance metric

if nargin<4
    dim=[];
end

if ~iscell(cf_output), cf_output={cf_output}; end
if ~iscell(label), label={label}; end

% Check the size of the cf_output and label. nExtra keeps the number of
% elements in the extra dimensions if ndims(cf_output) > ndims(label). For
% instance, if we classify across time, cf_output is [repeats x folds x time] 
% and label is [repeats x time] so we have 1 extra dimension (time).
sz_cf_output = size(cf_output);
nExtra = prod(sz_cf_output(ndims(label)+1:end));
% dimSkipToken helps us looping across the extra dimensions 
dimSkipToken = repmat({':'},[1, ndims(label)]);

% Check whether the classifier output is given as predicted labels or
% dvals. In the former case, it should consist of 1's and 2's only.
isLabel = all(ismember( unique(cf_output{1}), [1 2] ));

% For some metrics dvals are required
if isLabel && any(strcmp(metric,{'dval' 'roc' 'auc'}))
    error('To calculate %s, classifier output must be given as dvals not as labels', metric)
end

perf = cell(sz_cf_output);

% Calculate the performance metric
switch(metric)

    case 'acc'
        %%% ACC: classification accuracy -------------------------------
       
        if isLabel
            % Compare predicted labels to the true labels. To this end, we
            % create a function that compares the predicted labels to the
            % true labels and takes the mean of the comparison. This gives
            % us the classification performance for each test fold.
            fun = @(cfo,lab) mean(bsxfun(@eq,cfo,lab(:)));
        else
            % We want class 1 labels to be positive, and class 2 labels to
            % be negative, because then their sign corresponds to the sign 
            % of the dvals. To this end, we transform the labels as 
            % label =  -label + 1.5 => class 1 will be +0.5 now, class 2
            % will be -0.5
            % We first need to transform the classifier output into labels.
            % To this end, we create a function that multiplies the the
            % dvals by the true labels - for correct classification the
            % product is positive, so compare whether the result is > 0.
            % Taking the mean of this comparison gives classification
            % performance.
            fun = @(cfo,lab) mean(bsxfun(@times,cfo,-lab(:)+1.5) > 0);
        end

        % Looping across the extra dimensions if cf_output is multi-dimensional
        for xx=1:nExtra 
            % Use cellfun to apply the function defined above to each cell
            perf(dimSkipToken{:},xx) = cellfun(fun, cf_output(dimSkipToken{:},xx), label, 'Un', 0);
        end
        
    case 'dval'
        %%% DVAL: average decision value for each class -------------------------------

        perf = cell([sz_cf_output,2]);

        % Aggregate across samples, for each class separately
        if nExtra == 1
            perf(dimSkipToken{:},1) = cellfun( @(cfo,lab) nanmean(cfo(lab==1,:,:,:,:,:),1), cf_output, label, 'Un',0);
            perf(dimSkipToken{:},2) = cellfun( @(cfo,lab) nanmean(cfo(lab==2,:,:,:,:,:),1), cf_output, label, 'Un',0);
        else
            for xx=1:nExtra % Looping across the extra dimensions if cf_output is multi-dimensional
                perf(dimSkipToken{:},xx,1) = cellfun( @(cfo,lab) nanmean(cfo(lab==1,:,:,:,:,:),1), cf_output(dimSkipToken{:},xx), label, 'Un',0);
                perf(dimSkipToken{:},xx,2) = cellfun( @(cfo,lab) nanmean(cfo(lab==2,:,:,:,:,:),1), cf_output(dimSkipToken{:},xx), label, 'Un',0);
            end
        end

    case 'auc'
        %%% AUC: area under the ROC curve -------------------------------
        % AUC can be calculated by sorting the dvals, traversing the
        % positive examples (class 1) and counting the number of negative
        % examples (class 2) with lower values
        
%         [cf_output,soidx] = sort(cf_output,'descend');
% 
%         sz= size(cf_output);
%         perf= zeros([1, sz(2:end)]);
% 
%         % Calculate AUC for each column of cf_output
%         for ii=1:prod(sz(2:end))
%             clabel = label(soidx(:,ii));
% 
%             % Find all class indices
%             isClass1Idx = find(clabel(:)== 1);
%             isClass2 = (clabel(:)==2 );
% 
%             % Count number of False Positives with lower value
%             for ix=1:numel(isClass1Idx)
%                 perf(1,ii) = perf(1,ii) + sum(isClass2(isClass1Idx(ix)+1:end));
%             end
% 
%             % Correct by number of True Positives * False Positives
%             perf(1,ii) = perf(1,ii)/ (numel(isClass1Idx) * sum(isClass2));
%         end
        
        % There is different ways to calculate AUC. An efficient one for
        % our purpose is to sort the label vector in an ascending fashion,
        % the dvals are later sorted accordingly using soidx.
        [label, soidx] = cellfun(@(lab) sort(lab,'ascend'), label, 'Un',0);
        N1 = cellfun( @(lab) {sum(lab==1)}, label);
        N2 = cellfun( @(lab) {sum(lab==2)}, label);
        for xx=1:nExtra
            % Sort decision values using the indices of the sorted labels.
            % Add a bunch of :'s to make sure that we preserve the other
            % (possible) dimensions
            cf_so = cellfun(@(c,so) c(so,:,:,:,:,:) , cf_output(dimSkipToken{:},xx), soidx, 'Un',0);
            % Use cellfun to perform the following operation within each
            % cell:
            % For each class 1 sample, we count how many class 2 exemplars 
            % have a lower decision value than this sample. If there is a 
            % tie (dvals equal for two exemplars of different classes), 
            % we add 0.5. Dividing that number by the #class 1 x #class 2
            % (n1*n2) gives the AUC
            perf(dimSkipToken{:},xx) = cellfun(@(c,n1,n2) (sum(arrayfun(@(ii) (sum(c(ii)>c(n1+1:end)) + 0.5*sum(c(ii)==c(n1+1:end)) ), 1:n1))/(n1*n2)), cf_so, N1,N2, 'Un',0);
        end
end

% Convert cell array to matrix. Since each cell can also contain a multi-
% dimensional array instead of a scalar, we need to make sure that these
% arrays are correctly appended as extra dimensions.
nd = find(size(perf{1})>1,1,'last'); % Number of non-singleton dimensions
if nd>1
    % Extra singleton dimensions within the cells. To cope with this, we
    % prepend the dimensions of the cell array as extra singleton
    % dimensions. Eg. for a [5 x 2] cell array, we do something like 
    % perf{1}(1,1,:) = perf{1} so that the content of the cell is pushed to
    % dimensions 3 and higher
    dimSkip1 = repmat({1},[1, ndims(perf)]);
    innerCellSkip = repmat({':'},[1, nd-1]);
    tmp = [];
    for ii=1:numel(perf)
        tmp(dimSkip1{:},innerCellSkip{:}) = perf{ii};
        perf{ii} = tmp;
    end
end
perf = cell2mat(perf);

% Average across requested dimensions
for nn=1:numel(dim)
    perf = nanmean(perf, dim(nn));
end

perf = squeeze(perf);
