rng(42)
tol = 10e-10;

N = 100;
P = 10;

[X, clabel] = simulate_gaussian_data(N, P, 2, [], [], 0);

X = repmat(X, [1 1 30]);

%% produce a result
cfg = [];
cfg.metric      = {'acc', 'auc'};
cfg.classifier  = 'lda';
cfg.feedback    = 0;
[~, result] = mv_classify_across_time(cfg, X, clabel);

%% BINOMIAL TEST
cfg = [];
cfg.test = 'binomial';

stat = mv_statistics(cfg, result);

%% result between 0 and 1
print_unittest_result('[Gaussian data primal] result between 0 and 1', true, 0 <= LW(X, 'primal') <= 1, tol);
print_unittest_result('[randn data primal] result between 0 and 1', true, 0 <= LW(X2, 'primal') <= 1, tol);
print_unittest_result('[spiral data primal] result between 0 and 1', true, 0 <= LW(X3, 'primal') <= 1, tol);

print_unittest_result('[Gaussian data dual] result between 0 and 1', true, 0 <= LW(X, 'dual') <= 1, tol);
print_unittest_result('[randn data dual] result between 0 and 1', true, 0 <= LW(X2, 'dual') <= 1, tol);
print_unittest_result('[spiral data dual] result between 0 and 1', true, 0 <= LW(X3, 'dual') <= 1, tol);

