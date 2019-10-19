function cf = train_kernel_ridge(param, X, Y)
% Trains a kernel ridge regression model.
%
% Usage:
% cf = train_kernel_fda(param, X, Y)
%
%Parameters:
% X              - [samples x features] matrix of training samples (should
%                                 not include intercept term/column of 1's)
%                  -OR-
%                  [samples x samples] kernel matrix
% Y              - [samples x 1] vector of responses (for univariate
%                                regression) -or- 
%                  [samples x m] matrix of responses (for multivariate 
%                                regression with m response variables)
%
% param          - struct with hyperparameters:
% .lambda        - regularization parameter for ridge regression, ranges
%                  from 0 (no regularization) to infinity. For lambda=0,
%                  the model yields standard linear (OLS) regression, for 
%                  lambda > 0 it yields ridge regression (default 1).
% .kernel        - kernel function:
%                  'linear'     - linear kernel ker(x,y) = x' y
%                  'rbf'        - radial basis function or Gaussian kernel
%                                 ker(x,y) = exp(-gamma * |x-y|^2);
%                  'polynomial' - polynomial kernel
%                                 ker(x,y) = (gamma * x * y' + coef0)^degree
%                  Alternatively, a custom kernel can be provided if there
%                  is a function called *_kernel is in the MATLAB path, 
%                  where "*" is the name of the kernel (e.g. rbf_kernel).
%
%                  If a precomputed kernel matrix is provided as X, set
%                  param.kernel = 'precomputed'.
%
% HYPERPARAMETERS for specific kernels:
%
% gamma         - (kernel: rbf, polynomial) controls the 'width' of the
%                  kernel. If set to 'auto', gamma is set to 1/(nr of features)
%                  (default 'auto')
% coef0         - (kernel: polynomial) constant added to the polynomial
%                 term in the polynomial kernel. If 0, the kernel is
%                 homogenous (default 1)
% degree        - (kernel: polynomial) degree of the polynomial term. A too
%                 high degree makes overfitting likely (default 2)
%
% IMPLEMENTATION DETAILS:
% The solution to the kernel ridge regression problem is given by
%
% alpha = (K + lambda I)^-1  y    (dual form)
%
% where lambda is the regularization hyperparameter and K is the [samples x
% samples] kernel matrix. Predictions on new data are then obtained using 
%
% f(x) = alpha' *  k 
%
% where k = (k(x1, x), ... , k(xn, x))' is the vector of kernel evaluations
% between the training data and the test sample x.
%
% REFERENCE:
% https://people.eecs.berkeley.edu/~bartlett/courses/281b-sp08/10.pdf

% (c) Matthias Treder

[N, P] = size(X);
model = struct();

% indicates whether kernel matrix has been precomputed
is_precomputed = strcmp(param.kernel,'precomputed');

%% Set kernel hyperparameter defaults
if ischar(param.gamma) && strcmp(param.gamma,'auto') && ~is_precomputed
    param.gamma = 1/size(X,2);
end

%% Compute kernel
if is_precomputed
    K = X;
else
    kernelfun = eval(['@' param.kernel '_kernel']);     % Kernel function
    K = kernelfun(param, X);                            % Compute kernel matrix
end


%% --- the rest ---

% For tuning, we do not need to compute the kernel again
tmp = param;
tmp.kernel = 'precomputed';

%% Regularization of N
lambda = param.lambda;

if strcmp(param.reg,'shrink')
    % SHRINKAGE REGULARIZATION
    % We write the regularized scatter matrix as a convex combination of
    % the N and an identity matrix scaled to have the same trace as N
    N = (1-lambda)* N + lambda * eye(nsamples) * trace(N)/nsamples;

else
    % RIDGE REGULARIZATION
    % The ridge lambda must be provided directly as a positive number
    N = N + lambda * eye(nsamples);
end

%% M: "Dual" of between-classes scatter matrix

% Get indices of samples for each class
cidx = arrayfun( @(c) clabel==c, 1:nclasses,'Un',0);

% Get class-wise means
Mj = zeros(nsamples,nclasses);
for c=1:nclasses
    Mj(:,c) = mean( K(:, cidx{c}), 2);
end

% Sample mean
Ms = mean(K,2);

% Calculate M
M = zeros(nsamples);
for c=1:nclasses
    M = M + l(c) * (Mj(:,c)-Ms) * (Mj(:,c)-Ms)';
end

%% Calculate A (matrix of alpha's)
[A,~] = eigs( N\M, nclasses-1);

%% Set up classifier struct
cf              = [];
cf.kernel       = param.kernel;
cf.A            = A;
cf.nclasses     = nclasses;

if ~is_precomputed
    cf.kernelfun    = kernelfun;
    cf.Xtrain       = X;
end

% Save projected class centroids
cf.class_means  = Mj'*A;

% Hyperparameters
cf.gamma        = param.gamma;
cf.coef0        = param.coef0;
cf.degree       = param.degree;
    
end
