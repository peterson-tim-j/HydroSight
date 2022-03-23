function [ModPred] = ZT_6(x,Extra);
% Zitzler and Thiele function 6: Pareto-optimal front consists of several noncontiguous convex parts

% Calculate f, g and h
f = 1 - exp(-4 * x(1)) * sin((6 * pi * x(1))).^6;
g = 1 + 9*(sum(x(2:end)./(Extra.m - 1)))^(1/4);
h = 1 - (f / g)^2;

% Define the model output
ModPred.f = f; ModPred.g = g; ModPred.h = h;