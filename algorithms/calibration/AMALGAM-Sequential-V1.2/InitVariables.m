function [AMALGAMPar,Extra,output,Bounds,ParSet,V] = InitVariables(AMALGAMPar,Extra);
% Initialize algorithmic variables and other properties

% Define the number of offspring points each algorithm is initially creating
AMALGAMPar.m = ones(1,AMALGAMPar.q) * floor(AMALGAMPar.N/AMALGAMPar.q);

% Make sure that offspring is of similze size as AMALGAMPar.N
Delta = AMALGAMPar.N - sum(AMALGAMPar.m);

% Change algorithm with max contribution of points; probably least sensitive
t = randperm(AMALGAMPar.q); AMALGAMPar.m(t(1)) = AMALGAMPar.m(t(1)) + Delta;

% Define the minimum number of points each algorithm should contribute
AMALGAMPar.min_m = 5 * ones(1,AMALGAMPar.q);

% Initialize matrix with AMALGAMPar.m as function of Iter
output.algN = zeros(round(AMALGAMPar.ndraw/AMALGAMPar.N),AMALGAMPar.q + 1);

% Save initial contribution of different algorithms
output.algN(1,1:AMALGAMPar.q + 1) = [AMALGAMPar.N AMALGAMPar.m];

% Initialize matrix with convergence diagnostics of AMALGAM 
output.R = zeros(round(AMALGAMPar.ndraw/AMALGAMPar.N),4);

% Define the bounds on the objective functions
Bounds = [-1000*ones(AMALGAMPar.nobj,1) 1000*ones(AMALGAMPar.nobj,1)];
% Bounds = [-1000*ones(AMALGAMPar.nobj,1) inf*ones(AMALGAMPar.nobj,1)]; %%
% TO DO: maybe we need to increase the upper bound depending on the
% obj-function. Currently using SSE so the value can be very high and
% require inf. upper bound..

% Define algorithmic parameters
Extra.Jump = (2.4/sqrt(AMALGAMPar.n)).^2; Extra.m = AMALGAMPar.n;

% Allocate memory for ParSet and initialize this matrix with zeros
ParSet = zeros(AMALGAMPar.ndraw,AMALGAMPar.n + AMALGAMPar.nobj + 1);

% Initialize the velocity of the particles for PSO
[V] = InitVel(AMALGAMPar,Extra);