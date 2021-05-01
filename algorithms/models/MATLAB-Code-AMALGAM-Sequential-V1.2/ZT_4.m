function [ModPred] = ZT_4(x,Extra);
% Zitzler and Thiele function 4: Multimodal Pareto optimal front with 21^9 local Pareto fronts

% Define f
f = x(1);
% Define g
g = 1 + 10 * (Extra.m - 1);
% Update g
for qq = 2:Extra.m,
    g = g + x(qq)^2 - 10*cos(4*pi*x(qq));
end;
% Define h
h = 1 - sqrt(f/g);

% Define the model output
ModPred.f = f; ModPred.g = g; ModPred.h = h;