function y_hat = test_ridge(model, X)
% Applies an ridge regression model to test data and outputs predicted
% responses.
% 
% Usage:
% y_hat = test_ridge(model, X)
% 
%Parameters:
% model          - struct describing the regression model obtained from training 
%                  data. Must contain the fields w and b.
% X              - [samples x features] matrix of test samples
%
%Output:
% y_hat          - predicted responses

y_hat = X * model.w + model.b;
