function mv_tune_hyperparameters(param, X, y, train_fun, test_fun, eval_fun, tune_fields, k, is_kernel_matrix)
% Generic hyperparameter tuning function. To this end, cross-validation is 
% run using a search grid. 
%
% Usage:
% ix = mv_tune_hyperparameters(param, X, y, train_fun, test_fun, tune_fields)
%
%Parameters:
% param          - struct with hyperparameters for the classifier/model
% X              - [samples x features] matrix of training samples  -OR-
%                  [samples x samples] kernel matrix
% Y              - class labels or vector/matrix of regression targets
% train_fun      - training function (e.g. @train_lda)
% test_fun       - test function (e.g. @test_lda)
% eval_fun       - evaluation function that take y and predicted y as
%                  inputs and returns a metric (e.g. accuracy, MSE). Note
%                  that we are looking for MAXIMA of the evaluation
%                  function, so for error metrics such as MSE one should
%                  provide -MSE instead.
% tune_fields    - cell array specifying which fields of param contain
%                  hyperparameters to be tuned
% k              - number of folds for cross-validation
% is_kernel_matrix - indicates whether X is a kernel matrix
%
% Returns:
% ix             - a vector of indices for the best 

% Loop through all lambdas

N = size(X,1);
CV = cvpartition(N,'KFold', k);
metric = zeros(numel(param.lambda),1);  % sum of squared errors

for ff=1:param.k
    X_train = X(CV.training(ff),:);
    Y_train = Y(CV.training(ff),:);
    
    m = mean(X_train);
    X_train = X_train - repmat(m, [size(X_train,1) 1]);

    % Loop through lambdas
    for ll=1:numel(param.lambda)
        lambda = param.lambda(ll);
        
        %%% TRAIN
        % Perform regularization and calculate weights
        if strcmp(form, 'primal')
            w = (X_train'*X_train + lambda * eye(P)) \ (X_train' * Y_train);   % primal
        else
            w = X_train' * ((X_train*X_train' + lambda * eye(N)) \ Y_train);   % dual
        end
        
        % Estimate intercept
        b = mean(Y_train) - m*w; % m*w makes sure that we do not need to center the test data
        
        %%% TEST
        Y_hat = X(CV.test(ff),:) * w + b;
        
        MSE(ll) = sum(sum( (Y(CV.test(ff),:) - Y_hat).^2 ));
    end
    
end

MSE = MSE / N;

[~, ix] = min(MSE);
lambda = param.lambda(ix);

% Diagnostic plot if requested
if param.plot

    % Plot cross-validated classification performance
    figure
    semilogx(param.lambda, MSE)
    title([num2str(param.k) '-fold cross-validation error'])
    hold all
    plot([lambda, lambda],ylim,'r--'),plot(lambda, MSE(ix),'ro')
    xlabel('Lambda'),ylabel('MSE')
end
