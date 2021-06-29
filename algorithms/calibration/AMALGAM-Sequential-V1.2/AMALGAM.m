function [output,ParGen,ObjVals,ParSet,allOriginalObjVals_Flow] = AMALGAM(AMALGAMPar,ModelName,ParRange,Measurement,Extra,Fpareto,model_object);
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

% Initialize algorithmic variables and other properties
[AMALGAMPar,Extra,output,Bounds,ParSet,V] = InitVariables(AMALGAMPar,Extra);

% Sample AMALGAMPar.N points in the parameter space
ParGen = LHSU(ParRange.minn,ParRange.maxn,AMALGAMPar.N);

if strcmp(Extra.InitPopulation,'LHS'),
    % Latin hypercube sampling when indicated
    [ParGen] = LHSU(ParRange.minn,ParRange.maxn,AMALGAMPar.N);
elseif strcmp(Extra.InitPopulation,'PRIOR');
    % Loop over each parameter and create MCMCPar.seq number of samples from respective distribution
    for qq = 1:AMALGAMPar.n,
        for zz = 1:AMALGAMPar.N,
            ParGen(zz,qq) = eval(Extra.prior(qq,1:end));
        end;
    end;
end;

% Calculate objective function values for each of the AMALGAMPar.N points
% [ObjVals,Cg] = CompOF(ParGen,AMALGAMPar,Measurement,ModelName,Extra);

ObjVals = repmat(inf, AMALGAMPar.N, 2); % initialize to speed up the parfor loop with the correct matrix of ObjVals
allOriginalObjVals_Flow = repmat(inf, AMALGAMPar.N, 6); % initialize to speed up the parfor loop with the correct matrix of all original ObjVals for flow
Cg = repmat(0, AMALGAMPar.N, 1); % Initialize/Define the contstraint violation



%     parfor ii = 1:AMALGAMPar.N % computing the Obj-functions using parallel computing
    for ii = 1:AMALGAMPar.N % computing the Obj-functions using parallel computing

%         ObjVals_prime = objectiveFunction_joint(ParGen(ii,:)', Measurement.time_points_head, Measurement.time_points_streamflow, model_object,{}); % using time points from calibration_initialise to avoid mismatch of dimensions in line 2803 of model_TFN
        [ObjVals_prime, ~, ~, objFn_flow_NSE, objFn_flow_NNSE, objFn_flow_RMSE, objFn_flow_SSE, objFn_flow_bias, objFn_flow_KGE, ~, ~,~] = objectiveFunction_joint(ParGen(ii,:)', Measurement.time_points_head, Measurement.time_points_streamflow, model_object,{}); % using time points from calibration_initialise to avoid mismatch of dimensions in line 2803 of model_TFN
%         model_object.variables.doingCalibration = true; % true to pass through objectiveFunction_joint with the correct input during the loop.
        
%         
        % Store the objective function values for each point that are minimized in AMALGAM
        ObjVals(ii,:) = ObjVals_prime;

        % Store the all original objective function values for flow for each point
        allOriginalObjVals_Flow(ii,:) = [objFn_flow_NSE objFn_flow_NNSE objFn_flow_RMSE objFn_flow_SSE objFn_flow_bias objFn_flow_KGE];

        Cg(ii,1) = 0; % Define the constraint violation

    end
  
% This function now contains the body
% of the parfor-loop

    
    
% ParGen a matrix of parameter sets
% AMALGAMPar is a struct variable of number of parameters etc
% Measurements I this can be empty
% ModelName is 'objectiveFunction_joint'
% Extra will be the model object eg model_7params.model

% Ranking and CrowdDistance Calculation
[Ranking,CrowdDist] = CalcRank(ObjVals,Bounds,Cg);

% Define the current iteration value
Iter = AMALGAMPar.N;

% Compute convergence diagnostics -- distance to Pareeto optimal front (only values for synthetic problems!)
[Gamma,Delta,Hvol] = CompConv(AMALGAMPar,Fpareto,ObjVals);

% Store the convergence statistics in output.R
output.R(1,1:4) = [Iter Gamma Delta Hvol];

% Store current population in ParSet
ParSet(1:AMALGAMPar.N,1:AMALGAMPar.n + AMALGAMPar.nobj + 1) = [ParGen Cg ObjVals]; 

% Define counter
counter = 2;

% Now iterate
while (Iter < AMALGAMPar.ndraw),

    % Step 1: Now determine Pbest and Nbest for Particle Swarm Optimization
    [pBest,nBest] = SelBest(Ranking,ParSet(1:Iter,1:end),AMALGAMPar,Extra);

    % Step 2: Generate offspring
    [NewGen,V,Itot] = GenChild(ParGen,ObjVals,Ranking,CrowdDist,Cg,V,pBest,nBest,AMALGAMPar,ParRange,Extra);

    % Step 2b: Check whether parameters are in bound
    [NewGen] = CheckPars(NewGen,ParRange,Extra.BoundHandling);

    % Step 3: Compute Objective Function values offspring
%     [ChildObjVals,ChildCg] = objectiveFunction_joint4AMALGAM(NewGen,AMALGAMPar,Measurement,ModelName,Extra);

    ChildObjVals = repmat(inf, AMALGAMPar.N, 2); % initialize to speed up the parfor loop with the correct matrix of ObjVals
    ChildallOriginalObjVals_Flow = repmat(inf, AMALGAMPar.N, 6); % initialize to speed up the parfor loop with the correct matrix of all original ObjVals for flow
    ChildCg = repmat(inf, AMALGAMPar.N, 1); % initialize physical constrains matrix

    parfor ii = 1:AMALGAMPar.N % computing the Obj-functions using parallel computing
%      for ii = 1:AMALGAMPar.N % computing the Obj-functions 
         
%          ObjVals_prime = objectiveFunction_joint(NewGen(ii,:)', Measurement.time_points_head, Measurement.time_points_streamflow, model_object,{}); % using time points from calibration_initialise to avoid mismatch of dimensions in line 2803 of model_TFN
         [ObjVals_prime, ~, ~, objFn_flow_NSE, objFn_flow_NNSE, objFn_flow_RMSE, objFn_flow_SSE, objFn_flow_bias, objFn_flow_KGE, ~, ~,~] = objectiveFunction_joint(NewGen(ii,:)', Measurement.time_points_head, Measurement.time_points_streamflow, model_object,{}); % using time points from calibration_initialise to avoid mismatch of dimensions in line 2803 of model_TFN
%          model_object.variables.doingCalibration = true; % true to pass through objectiveFunction_joint with the correct input during the loop.
         
         % Store the objective function values for each point
         ChildObjVals(ii,:) = ObjVals_prime;
         
         % Store the all original objective function values for flow for each point
         ChildallOriginalObjVals_Flow(ii,:) = [objFn_flow_NSE objFn_flow_NNSE objFn_flow_RMSE objFn_flow_SSE objFn_flow_bias objFn_flow_KGE];
         
         % Define the contstraint violation
         ChildCg(ii,1) = 0;
         
     end
     
     

    % Step 4: Now merge parent and child populations and generate new one
    [ParGen,ObjVals,Ranking,CrowdDist,Iout,Cg] = CreateNewPop(ParGen,NewGen,ObjVals,ChildObjVals,Itot,Cg,ChildCg,ParRange,Bounds); 

    % Step 5: Determine the new number of offspring points for individual algorithms
    [AMALGAMPar] = DetN(Iout,AMALGAMPar);

    % Step 6: Append the new points to ParSet
    ParSet(Iter+1:Iter+AMALGAMPar.N,1:end) = [ParGen Cg ObjVals];
    
    
    % Step 6b: Append the new points to allOriginalObjVals_Flow
    allOriginalObjVals_Flow(Iter+1:Iter+AMALGAMPar.N,1:end) = ChildallOriginalObjVals_Flow;
    

    % Step 7: Compute convergence statistics -- this can only be done for synthetic problems
    [Gamma,Delta,Hvol] = CompConv(AMALGAMPar,Fpareto,ObjVals);

    % Step 8: Update Iteration
    Iter = Iter + AMALGAMPar.N;

    % Step 9a: Save AMALGAMPar.m
    output.algN(counter,1:AMALGAMPar.q + 1) = [Iter AMALGAMPar.m];

    % Step 9b: Store the convergence statistics in output.R
    output.R(counter,1:4) = [Iter Gamma Delta Hvol];

    % Step 10: Update counter
    counter = counter + 1;

    % Write Iter to screen -- to show progress
    Iter
    
    % Plot Pareto Fronts on top of each other to show progress
%     figure(1)
%     scatter( ObjVals(:,1), ObjVals(:,2))
%     title({['Pareto Front - GW head vs. Streamflow Obj-Functions' ]
%         [model_object.inputData.bore_ID ' - ' 'Brucknell Creek' ]});
% %     xlabel('pseudo likelihood (GW head)')
%     xlabel('(1-NSE) (Flow)')
%     ylabel('(1-NSE) (Flow)')
%     grid on
%     ax = gca;
%     ax.FontSize = 13;
%     hold on
    
end;