function model = train_svr(param,X,y)
% Trains a Support Vector Regression (SVR) model using LIBSVM. 
% For installation details and further information see
% https://github.com/cjlin1/libsvm and 
% https://www.csie.ntu.edu.tw/~cjlin/libsvm
%
% This function exists for convenience: In train_libsvm, the default value 
% for svm_type is 0 (classification), whereas for train_svr it is 3
% (regression). 
%
% See train_libsvm for more information about LIBSVM.

model = train_libsvm(param, X, y);

