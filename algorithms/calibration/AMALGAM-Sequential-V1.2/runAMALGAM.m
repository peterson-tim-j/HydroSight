% --------------------------------------------------------------------------------------------- %
%                                                                                               %
%        AA      MM       MM     AA      LL            GGGGGGGGG       AA      MM       MM      %
%        AA      MM       MM     AA      LL           GG               AA      MM       MM      %
%        AA      MM       MM     AA      LL           GG               AA      MM       MM      %
%       AAAA     MM       MM    AAAA     LL           GG              AAAA     MM       MM      %
%       AAAA     MM       MM    AAAA     LL           GG              AAAA     MM       MM      %
%      AA  AA    MMM     MMM   AA  AA    LL           GG             AA  AA    MMM     MMM      %
%      AA  AA    MMMM   MMMM   AA  AA    LL           GG   GGGGGG    AA  AA    MMMM   MMMM      %
%      AAAAAA    MM MM MM MM   AAAAAA    LL           GG   GGGGGG    AAAAAA    MM MM MM MM      %
%     AA    AA   MM  MMM  MM  AA    AA   LL           GG       GG   AA    AA   MM  MMM  MM      %
%     AA    AA   MM       MM  AA    AA   LL           GG       GG   AA    AA   MM       MM      %
%    AA      AA  MM       MM AA      AA  LL           GG       GG  AA      AA  MM       MM      %
%    AA      AA  MM       MM AA      AA  LL           GG       GG  AA      AA  MM       MM      %
%    AA      AA  MM       MM AA      AA  LL           GGGGGGGGGGG  AA      AA  MM       MM      %
%    AA      AA  MM       MM AA      AA  LLLLLLLLLLL   GGGGGGGGG   AA      AA  MM       MM      %
%                                                                                               %
% --------------------------------------------------------------------------------------------- %

% ------------------ The AMALGAM multiobjective optimization algorithm ------------------------ % 
%                                                                                               %
% This general purpose MATLAB code is designed to find a set of parameter values that defines   %
% the Pareto trade-off surface corresponding to a vector of different objective functions. In   %
% principle, each Pareto solution is a different weighting of the objectives used. Therefore,   %
% one could use multiple trials with a single objective optimization algorithms using diferent  %
% values of the weights to find different Pareto solutions. However, various contributions to   %
% the optimization literature have demonstrated that this approach is rather inefficient. The   %
% AMALGAM code developed herein is designed to find an approximation of the Pareto solution set %
% within a single optimization run. The AMALGAM method combines two new concepts,               %
% simultaneous multimethod search, and self-adaptive offspring creation, to ensure a fast,      %
% reliable, and computationally efficient solution to multiobjective optimization problems. 	%
% This method is called a multi-algorithm, genetically adaptive multiobjective, or AMALGAM, 	%
% method, to evoke the image of a procedure that blends the attributes of the best available 	%
% individual optimization algorithms.                                                           %
%                                                                                               %
% This algorithm has been described in:                                                         %
%                                                                                               %
% J.A. Vrugt, and B.A. Robinson, Improved evolutionary optimization from genetically adaptive   %
%    multimethod search, Proceedings of the National Academy of Sciences of the United States   %
%    of America, 104, 708 - 711, doi:10.1073/pnas.0610471104, 2007.                             %
%                                                                                               %
% J.A. Vrugt, B.A. Robinson, and J.M. Hyman, Self-adaptive multimethod search for global        %
%    optimization in real-parameter spaces, IEEE Transactions on Evolutionary Computation,      %
%    13(2), 243-259, doi:10.1109/TEVC.2008.924428, 2009.					%
%                                                                                               %
% For more information please read:                                                             %
%                                                                                               %
% J.A. Vrugt, H.V. Gupta, L.A. Bastidas, W. Bouten, and S. Sorooshian, Effective and efficient  %
%    algorithm for multi-objective optimization of hydrologic models, Water Resources Research, %
%    39(8), art. No. 1214, doi:10.1029/2002WR001746, 2003.                                      %
%                                                                                               %
% G.H. Schoups, J.W. Hopmans, C.A. Young, J.A. Vrugt, and W.W.Wallender, Multi-objective        %
%    optimization of a regional spatially-distributed subsurface water flow model, Journal      %
%    of Hydrology, 20 - 48, 311(1-4), doi:10.1016/j.jhydrol.2005.01.001, 2005.                  %
%                                                                                               %
% J.A. Vrugt, P.H. Stauffer, T. Wöhling, B.A. Robinson, and V.V. Vesselinov, Inverse modeling   %
%    of subsurface flow and transport properties: A review with new developments, Vadose Zone   %
%    Journal, 7(2), 843 - 864, doi:10.2136/vzj2007.0078, 2008.                                  %
%                                                                                               %
% T. Wöhling, J.A. Vrugt, and G.F. Barkle, Comparison of three multiobjective optimization      %
%    algorithms for inverse modeling of vadose zone hydraulic properties, Soil Science Society  %
%    of America Journal, 72, 305 - 319, doi:10.2136/sssaj2007.0176, 2008.                       %
%                                                                                               %
% T. Wöhling, and J.A. Vrugt, Combining multi-objective optimization and Bayesian model         %
%    averaging to calibrate forecast ensembles of soil hydraulic models, Water Resources        %
%    Research, 44, W12432, doi:10.1029/2008WR007154, 2008.                                      %
%                                                                                               %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                                               %
%     Copyright (C) 2011-2012  the authors                                                      %
%                                                                                               %
%     This program is free software: you can modify it under the terms of the GNU General       %
%     Public License as published by the Free Software Foundation, either version 3 of the      %
%     License, or (at your option) any later version.                                           %
%                                                                                               %
%     This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; %
%     without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. %
%     See the GNU General Public License for more details.                                      %
%                                                                                               %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                                               %
% AMALGAM code developed by Jasper A. Vrugt, University of California Irvine: jasper@uci.edu    %
%                                                                                               %
% Version 0.5:   June 2006                                                                      %
% Version 1.0:   January 2009    Cleaned up source code and implemented 4 test example problems %
% Version 1.1:   January 2010    Population size flexible and does not divide by # algorithms   %
% Version 1.2:   August 2010     Sampling from prior distribution                               %
%                                                                                               %
% --------------------------------------------------------------------------------------------- %

% --------------------------------------------------------------------------------------------- %
%                                                                                               %
%           Note: PRIOR INFORMATION IN AMALGAM CAN BE SPECIFIED AS FOLLOWS                      %
%                                                                                               %
%       Set the following: Extra.InitPopulation = 'PRIOR' instead of 'LHS'                      %
%       Then for each parameter specify the prior distribution using MATLAB language            %
%       Example: Three parameters: (1) weibull, (2) lognormal, and (3) normal distribution      %
%                                                                                               %
%       Extra.prior = [ 'wblrnd(9,3)' ; 'lognrnd(0,2)' ; 'normrnd(-2,3)' ];                     %
%                                                                                               %
%       Weibull:   scale = 9; shape = 3;                                                        %
%       Lognormal: mean = 0; sigma = 2;                                                         %
%       normal:    mean = -2; sigma = 3;                                                        %
%                                                                                               %
% --------------------------------------------------------------------------------------------- %

% Different test examples (1 - 3 are synthetic problems, 4 is real world problem)

% example 1: multimodal Pareto optimal front with 21^9 local Pareto fronts
% example 2: Pareto-optimal front consists of several noncontiguous convex parts
% example 3: rotated problem
% example 4: real-world example using streamflow forecasting with hymod model


% Define which algorithms to use in AMALGAM
Extra.Alg = {'GA','PSO','AMS','DE'};

% Define the number of algorithms
AMALGAMPar.q = size(Extra.Alg,2);

% Which example to run?
example = 4;

if example == 1,    % Zitzler and Thiele function 4: Multimodal Pareto optimal front with 21^9 local Pareto fronts

    AMALGAMPar.n = 10;                      % Dimension of the problem
    AMALGAMPar.N = 100;                     % Size of the population
    AMALGAMPar.nobj = 2;                    % Number of objectives
    AMALGAMPar.ndraw = 10000;               % Maximum number of function evaluations

    % Define the parameter ranges (minimum and maximum values)
    ParRange.minn = [0 -5*ones(1,AMALGAMPar.n-1)]; ParRange.maxn = [1  5*ones(1,AMALGAMPar.n-1)];

    % How is the initial sample created -- Latin Hypercube sampling
    Extra.InitPopulation = 'LHS';
   
    % Define the measured streamflow data
    Measurement.MeasData = []; Measurement.Sigma = []; Measurement.N = size(Measurement.MeasData,1);

    % Define ModelName
    ModelName = 'ZT_4';
    
    % Define the boundary handling
    Extra.BoundHandling = 'Bound';
    
    % Load the true Pareto optimal front (derived with other script)
    load ZT_4_front.txt; Fpareto = ZT_4_front;

end;

if example == 2,    % Zitzler and Thiele function 6: Pareto-optimal front consists of several noncontiguous convex parts

    AMALGAMPar.n = 10;                      % Dimension of the problem
    AMALGAMPar.N = 100;                     % Size of the population
    AMALGAMPar.nobj = 2;                    % Number of objectives
    AMALGAMPar.ndraw = 10000;               % Maximum number of function evaluations

    % Define the parameter ranges (minimum and maximum values)
    ParRange.minn = zeros(1,AMALGAMPar.n); ParRange.maxn = ones(1,AMALGAMPar.n);

    % How is the initial sample created -- Latin Hypercube sampling
    Extra.InitPopulation = 'LHS';

    % Define the measured streamflow data
    Measurement.MeasData = []; Measurement.Sigma = []; Measurement.N = size(Measurement.MeasData,1);

    % Define ModelName
    ModelName = 'ZT_6';

    % Define the boundary handling
    Extra.BoundHandling = 'Bound';

    % Load the true Pareto optimal front (derived with other script)
    load ZT_6_front.txt; Fpareto = ZT_6_front;

end;

if example == 3,    % Rotated problem

    AMALGAMPar.n = 10;                      % Dimension of the problem
    AMALGAMPar.N = 100;                     % Size of the population
    AMALGAMPar.nobj = 2;                    % Number of objectives
    AMALGAMPar.ndraw = 25000;               % Maximum number of function evaluations

    % Define the parameter ranges (minimum and maximum values)
    ParRange.minn = -0.3*ones(1,AMALGAMPar.n); ParRange.maxn = 0.3*ones(1,AMALGAMPar.n);

    % How is the initial sample created -- Latin Hypercube sampling
    Extra.InitPopulation = 'LHS';

    % Do 45 degrees problem
    [Extra.R] = rotmat(AMALGAMPar.n,(pi/4));

    % Define the measured streamflow data
    Measurement.MeasData = []; Measurement.Sigma = []; Measurement.N = size(Measurement.MeasData,1);

    % Define ModelName
    ModelName = 'ROT'; 
    
    % Define the boundary handling
    Extra.BoundHandling = 'Bound';

    % Load the true Pareto optimal front (derived with other script)
    load ROT_front.txt; Fpareto = ROT_front;
    
end;

if example == 4,    % HYMOD rainfall - runoff model

    AMALGAMPar.n = 5;                       % Dimension of the problem
    AMALGAMPar.N = 100;                     % Size of the population
    AMALGAMPar.nobj = 2;                    % Number of objectives
    AMALGAMPar.ndraw = 10000;               % Maximum number of function evaluations

    % Define the parameter ranges (minimum and maximum values)
    ParRange.minn = [1.0 0.10 0.10 1e-5 0.10]; ParRange.maxn = [500 2.00 0.99 0.10 0.99];

    % How is the initial sample created -- Latin Hypercube sampling
    Extra.InitPopulation = 'LHS';

    % Load the Leaf River data
    load bound.txt;

    % Then read the boundary conditions -- only do two years
    Extra.MaxT = 795;

    % Define the PET, Measured Streamflow and Precipitation.
    Extra.PET = bound(1:Extra.MaxT,5); Extra.Precip = sum(bound(1:Extra.MaxT,6:9),2);

    % Define the measured streamflow data
    Measurement.MeasData = bound(65:Extra.MaxT,4); Measurement.Sigma = []; Measurement.N = size(Measurement.MeasData,1);

    % Define ModelName
    ModelName = 'hymod';
       
    % Define the boundary handling
    Extra.BoundHandling = 'Bound';

    % True Pareto front is not available -- real world problem
    Fpareto = [];

end;

% Store example number in structure Extra
Extra.example = example; Extra.m = AMALGAMPar.n;

% Run the AMALGAM code and obtain non-dominated solution set
[output,ParGen,ObjVals,ParSet] = AMALGAM(AMALGAMPar,ModelName,ParRange,Measurement,Extra,Fpareto);