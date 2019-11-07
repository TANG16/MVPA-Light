function y_pred = test_svr(model, X)
% Applies a LIBSVM regression model to test data and produces predicted
% responses.
%
% This function exists for convenience: In train_libsvm, the default value 
% for svm_type is 0 (classification), whereas for train_svr it is 3
% (regression). 
%
% % See test_libsvm for more information about LIBSVM.

if model.kernel_type == 4
    n_te = size(X,1);
    y_pred = svmpredict(zeros(n_te,1), [(1:n_te)', X], model.model,'-q');
else
    y_pred = svmpredict(zeros(size(X,1),1), X, model.model,'-q');
end

