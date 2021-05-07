function [ModPred] = ROT(x,Extra);
% Rotated problem

% Test function: Rotated problem
y = Extra.R * x';
% Now compute g
g = 1 + 10 * (Extra.m - 1);
% Update g
for qq = 2:Extra.m,
    g = g + y(qq)^2 - 10*cos(4 * pi * y(qq));
end;

% Define the model output
ModPred.y = y; ModPred.g = g;