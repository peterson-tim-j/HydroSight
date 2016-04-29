% ----------------------------------------------------------------------------------------------%
%                                                                                               %
% DDDDDDDDDDDDDDD    RRRRRRRRRRRRRR     EEEEEEEEEEEEEEEE       AAAAA       MMM             MMM  %
% DDDDDDDDDDDDDDDD   RRRRRRRRRRRRRRR    EEEEEEEEEEEEEEEE       AAAAA       MMMM           MMMM  %
% DDD          DDD   RRR          RRR   EEE                   AAA AAA      MMMMM         MMMMM  %
% DDD          DDD   RRR          RRR   EEE                   AAA AAA      MMMMMM       MMMMMM  %
% DDD          DDD   RRR          RRR   EEE                  AAA   AAA     MMM MMM     MMM MMM  %
% DDD          DDD   RRR          RRR   EEE                  AAA   AAA     MMM  MMM   MMM  MMM  %
% DDD          DDD   RRRRRRRRRRRRRRRR   EEEEEEEEEEEEEEEE    AAA     AAA    MMM   MMM MMM   MMM  %
% DDD          DDD   RRRRRRRRRRRRRRRR   EEEEEEEEEEEEEEEE    AAAAAAAAAAA    MMM    MMMM     MMM  %
% DDD          DDD   RRR          RRR   EEE                AAA       AAA   MMM             MMM  %
% DDD          DDD   RRR          RRR   EEE                AAA       AAA   MMM             MMM  %
% DDD          DDD   RRR          RRR   EEE               AAA         AAA  MMM             MMM  %
% DDD          DDD   RRR          RRR   EEE               AAA         AAA  MMM             MMM  %
% DDDDDDDDDDDDDDDD   RRR          RRR   EEEEEEEEEEEEEEEE  AAA         AAA  MMM             MMM  %
% DDDDDDDDDDDDDDD    RRR          RRR   EEEEEEEEEEEEEEEE  AAA         AAA  MMM             MMM  %
%                                                                                               %
% ----------------------------------------------------------------------------------------------%

% ----------------- DiffeRential Evolution Adaptive Metropolis algorithm -----------------------%
%                                                                                               %
% DREAM runs multiple different chains simultaneously for global exploration, and automatically %
% tunes the scale and orientation of the proposal distribution using differential evolution.    %
% The algorithm maintains detailed balance and ergodicity and works well and efficient for a    %
% large range of problems, especially in the presence of high-dimensionality and                %
% multimodality.                                                                                %
%                                                                                               %
% DREAM developed by Jasper A. Vrugt and Cajo ter Braak                                         %
%                                                                                               %
% --------------------------------------------------------------------------------------------- %
%                                                                                               %
% SYNOPSIS: [chain,output,fx,log_L] = DREAM(Func_name,DREAMPar)                                 %
%           [chain,output,fx,log_L] = DREAM(Func_name,DREAMPar,Par_info)                        %
%           [chain,output,fx,log_L] = DREAM(Func_name,DREAMPar,Par_info,Meas_info)              %
%                                                                                               %
% Input:    Func_name = name of the function ( = model ) that returns density of proposal       %
%           DREAMPar = structure with algorithmic / computatinal settings of DREAM              %
%           Par_info = structure with parameter ranges, prior distribution, boundary handling   %
%           Meas_info = optional structure with measurements to be evaluated against            %
%                                                                                               %
% Output:   chain = 3D array with chain trajectories, log-prior and log-likelihood values       %
%           output = structure with convergence properties, acceptance rate, CR values, etc.    %
%           fx = matrix with model simulations                                                  %
%           log_L = matrix with log-likelihood values sampled chains                            %
%                                                                                               %
% The directory \PostProcessing contains a script "PostProcMCMC" that will compute various      %
% posterior statistics (MEAN, STD, MAP, CORR) and create create various plots including,        % 
% marginal posterior parameter distributions, R_stat convergence diagnostic, two-dimensional    %
% correlation plots of the posterior parameter samples, chain convergence plots, and parameter  % 
% and total posterior simulation uncertainty ranges (interval can be specified)                 % 
%                                                                                               %
% --------------------------------------------------------------------------------------------- %
%                                                                                               %
% This algorithm has been described in:                                                         %
%                                                                                               %
%   Vrugt, J.A., C.J.F. ter Braak, M.P. Clark, J.M. Hyman, and B.A. Robinson, Treatment of      %
%      input uncertainty in hydrologic modeling: Doing hydrology backward with Markov chain     %
%      Monte Carlo simulation, Water Resources Research, 44, W00B09, doi:10.1029/2007WR006720,  %
%      2008.                                                                                    %
%                                                                                               %
%   Vrugt, J.A., C.J.F. ter Braak, C.G.H. Diks, D. Higdon, B.A. Robinson, and J.M. Hyman,       %
%       Accelerating Markov chain Monte Carlo simulation by differential evolution with         %
%       self-adaptive randomized subspace sampling, International Journal of Nonlinear          %
%       Sciences and Numerical Simulation, 10(3), 271-288, 2009.                                %
%                                                                                               %
%   Vrugt, J.A., C.J.F. ter Braak, H.V. Gupta, and B.A. Robinson, Equifinality of formal        %
%       (DREAM) and informal (GLUE) Bayesian approaches in hydrologic modeling?, Stochastic     %
%       Environmental Research and Risk Assessment, 23(7), 1011-1026, 				            %
%       doi:10.1007/s00477-008-0274-y, 2009                                                     %
%                                                                                               %
%   Laloy, E., and J.A. Vrugt, High-dimensional posterior exploration of hydrologic models      %
%       using multiple-try DREAM_(ZS) and high-performance computing, Water Resources Research, %
%       48, W01526, doi:10.1029/2011WR010608, 2012.                                             %
%                                                                                               %
%   Vrugt, J.A., and M. Sadegh, Toward diagnostic model calibration and evaluation:             %
%       Approximate Bayesian computation, Water Resources Research, 49, 4335–4345,              %
%       doi:10.1002/wrcr.20354, 2013.                                                           %
%                                                                                               %
%   Sadegh, M., and J.A. Vrugt, Approximate Bayesian computation using Markov chain Monte       %
%       Carlo simulation: DREAM_(ABC), Water Resources Research, doi:10.1002/2014WR015386,      %  
%       2014.                                                                                   %
%                                                                                               %
% For more information please read:                                                             %
%                                                                                               %
%   Ter Braak, C.J.F., A Markov Chain Monte Carlo version of the genetic algorithm Differential %
%       Evolution: easy Bayesian computing for real parameter spaces, Stat. Comput., 16,        %
%       239 - 249, doi:10.1007/s11222-006-8769-1, 2006.                                         %
%                                                                                               %
%   Vrugt, J.A., H.V. Gupta, W. Bouten and S. Sorooshian, A Shuffled Complex Evolution          %
%       Metropolis algorithm for optimization and uncertainty assessment of hydrologic model    %
%       parameters, Water Resour. Res., 39 (8), 1201, doi:10.1029/2002WR001642, 2003.           %
%                                                                                               %
%   Ter Braak, C.J.F., and J.A. Vrugt, Differential Evolution Markov Chain with snooker updater %
%       and fewer chains, Statistics and Computing, 10.1007/s11222-008-9104-9, 2008.            %
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
% MATLAB code written by Jasper A. Vrugt, University of California Irvine, jasper@uci.edu      	%
%                                                                                               %
% Version 0.5: June 2008                                                                        %
% Version 1.0: October 2008       Adaption updated and generalized CR implementation            %
% Version 1.1: January 2010       Restart run and new AR-1 likelihood function with model error %
% Version 1.2: August 2010        Generalized likelihood function and prior distribution        %
% Version 1.3: September 2010     Explicit treatment of prior distribution                      %
% Version 1.4: October 2010       Limits of acceptability (GLUE) and few small changes          %
% Version 1.5: April 2011         Small maintenance updates -- 2 external executables           %
% Version 1.6: August 2011        Whittle likelihood function (SPECTRAL ANALYSIS !!)            %
% Version 1.7: April 2012         Simplified code (removed variables) + graphical interface     %
% Version 1.8: May 2012           Added new option for Approximate Bayesian Computation         %
% Version 1.9: June 2012          Simulations stored, new example, and updated likelihood func. %
% Version 2.0: January 2013       Simplification of metrop.m and DREAM.m                        %
% Version 2.1: September 2013     Added inference of measurement error as new option            %
% Version 2.4: May 2014           Parallellization using parfor (done if CPU > 1)               %
%                                                                                               %
% --------------------------------------------------------------------------------------------- %

% --------------------------------------------------------------------------------------------- %
%                                                                                               %
%           Note: DE-MC of ter Braak et al. (2006) is a special variant of DREAM                %
%                     It can be executed using the following options                            %
%                                                                                               %
%       DREAMPar.N = 2 * DREAMPar.d;                                                            %
%       DREAMPar.delta = 1;                                                                     %
%       DREAMPar.nCR = 1;                                                                       %
%       DREAMPar.lambda = 0;                                                                    %
%                                                                                               %
% --------------------------------------------------------------------------------------------- %

% --------------------------------------------------------------------------------------------- %
%                                                                                               %
%           Note: prior INFORMATION IN DREAM CAN BE SPECIFIED AS FOLLOWS                        %
%                                                                                               %
%       Set Par_info.prior = 'prior'. Then for each parameter specify the prior                 %
%       distribution using MATLAB language.                                                     %
%                                                                                               %
%       Example: Four parameters with prior distribution according to                           %
%       (1) weibull, (2) lognormal, (3) normal and (4) uniform distribution                     %
%                                                                                               %
%       DREAMPar.prior_marginal ={'wblrnd(9,3)','lognrnd(0,2)','normrnd(-2,3)','unifrnd(0,10)'} %
%                                                                                               %
%       Weibull:   scale = 9; shape = 3;                                                        %
%       Lognormal: mu = 0; sigma = 2;                                                           %
%       Normal:    mu = -2; sigma = 3;                                                          %
%       Uniform:   lower bound = 0; upper bound = 10;                                           %
%                                                                                               %
%       To calculate the Metropolis ratio, DREAM will assume that the respective densities      %
%       of the various prior distributions end with "pdf" rather than "rnd"                     %
%                                                                                               %
% --------------------------------------------------------------------------------------------- %

% --------------------------------------------------------------------------------------------- %
%                                                                                               %
%            Note: IF WORKING WITH INTEGER PROBLEMS, PLEASE USED DREAM_(D)                	    %
%                                                                                               %
% --------------------------------------------------------------------------------------------- %

% Different test examples
% example 1: n-dimensional banana shaped Gaussian distribution
% example 2: n-dimensional Gaussian distribution
% example 3: n-dimensional multimodal mixture distribution
% example 4: real-world example using hymod rainfall - runoff model (HYMOD code in MATLAB)
% example 5: real-world example using hymod rainfall - runoff model (HYMOD code in FORTRAN)
% example 6: rainfall-runoff model with generalized log-likelihood function
% example 7: HYDRUS-1D soil hydraulic model: using prior information on soil hydraulic parameters
% example 8: Simple 1D mixture distribution -- Approximate Bayesian Computation
% example 9: Rainfall-runoff model with Whittle's likelihood function
% example 10: the use of prior information in a multimodel mixture distrbibution
% example 11: multivariate student t distribution with 60 degrees of freedom
% example 12: pedometrics problem involving variogram fitting
% example 13: Nash-Cascade example --> heteroscedastic errors
% example 14: ABC inference for hydrologic model
% example 15: ABC inference using 10 bivariate normal distributions
% example 16: Hydrogeophysics example
% example 17: Hymod rainfall - runoff model with estimation of measurement error

% -------------------------------------------------------------------------

% Clear memory and close pool of matlab nodes (cores)   
%clear all; 
clc; warning off

% Which example to run?
example = 7;

global DREAM_dir EXAMPLE_dir CONV_dir

% Store working directory and subdirectory containing the files needed to run this example
DREAM_dir = pwd; EXAMPLE_dir = [pwd '\example_' num2str(example)]; CONV_dir = [pwd '\diagnostics'];

% Add subdirectory to search path
addpath(EXAMPLE_dir); addpath(CONV_dir); addpath(DREAM_dir);

% #########################################################################
%   Func_name: Name of the function script of the model/function
% #########################################################################
%                        CASE STUDY DEPENDENT
% -------------------------------------------------------------------------
% Func_name                 % Name of the model function script (.m file)
% -------------------------------------------------------------------------

% #########################################################################
%   DREAMPar: Computational setup DREAM and values algorithmic parameters
% #########################################################################
%                         CASE STUDY DEPENDENT
% -------------------------------------------------------------------------
% DREAMPar.d                        % Dimensionality target distribution
% DREAMPar.N                        % Number of Markov chains
% DREAMPar.T                        % Number of generations
% DREAMPar.lik                      % Choice of likelihood function
% -------------------------------------------------------------------------
%                           DEFAULT VALUES
% -------------------------------------------------------------------------
% DREAMPar.nCR = 3;                 % Number of crossover values 
% DREAMPar.delta = 3;               % Number chain pairs for proposal
% DREAMPar.lambda = 0.05;           % Random error for ergodicity
% DREAMPar.zeta = 0.05;             % Randomization
% DREAMPar.outlier = 'iqr';         % Test to detect outlier chains
% DREAMPar.pJumpRate_one = 0.2;     % Probability of jumprate of 1
% DREAMPar.pCR = 'yes';             % Adaptive tuning crossover values
% DREAMPar.thinning = 1;            % Each Tth sample is stored
% -------------------------------------------------------------------------
%                      OPTIONAL (DEFAULT = 'no'  / not used )
% -------------------------------------------------------------------------
% DREAMPar.prior                    % Explicit (non-flat) prior distribution?
% DREAMPar.ABC                      % Approximate Bayesian computation? 
% DREAMPar.rho                      % ABC distance function ( inline format )
% DREAMPar.parallel                 % Multi-core computation chains?
% DREAMPar.IO                       % If parallel, IO writing model?
% DREAMPar.modout                   % Return model (function) simulations?
% DREAMPar.restart                  % Restart run? (only with "save")
% DREAMPar.save                     % Save DREAM output during the run?
% DREAMPar.prior_handle             % If diagnostic Bayes
% DREAMPar.epsilon                  % Epsilon value, if ABC is used
% -------------------------------------------------------------------------

% #########################################################################
%   Par_info: All information about the parameter space and prior
% #########################################################################
%                        CASE STUDY DEPENDENT
% -------------------------------------------------------------------------
% Par_info.prior            % Initial sampling distribution ('uniform'/'latin'/'normal'/'prior')
% Par_info.min              % If 'latin', min parameter values
% Par_info.max              % If 'latin', max parameter values
% Par_info.mu               % If 'normal', provide mean of initial sampling distribution
% Par_info.cov              % If 'normal', provide initial covariance
% Par_info.prior_marginal   % Marginal prior distribution of each parameter 
%   (if DREAMPar.prior = 'yes') or (Par_info.prior = 'prior')
% Par_info.boundhandling    % Boundary handling ("reflect","bound","fold")
% -------------------------------------------------------------------------
%                          DEFAULT VALUES
% -------------------------------------------------------------------------
% Par_info.min              % -Inf^{d}
% Par_info.max              %  Inf^{d}
% Par_info.boundhandling    % no boundary handling (unbounded problem)
% -------------------------------------------------------------------------

% #########################################################################
%   Meas_info: Measurement data to compare model output against
% #########################################################################
%                             OPTIONAL 
% -------------------------------------------------------------------------
% Meas_info.Y        % Scalar/vector with calibration data measurements
% Meas_info.Sigma           % Scalar/vector with corresponding measurement errors
% Meas_info.S               % Scalar/vector with summary metrics data (if diagnostic Bayes)
% -------------------------------------------------------------------------


% -------------------------------------------------------------------------
% If DREAMPar.modout = 'yes' --> the simulations of the model are stored. 
% in a binary output file during the run. This file is read at the end of
% the program and returned as variable "fx" (output argument 4 of DREAM). 
% !! This will only be useful if model creates actual simulation !!
% -------------------------------------------------------------------------

% -------------------------------------------------------------------------
%   Likelihood functions can be found in the function CalcDensity.m
% Some of these functions (2 and 7) require the measurement error sigma to 
% be defined. One can set "Meas_info.Sigma" to be a single value. This 
% assumes homoscedastic errors. Or one can assume heteroscedasticity by
% using a vector of similar length as the Meas_info.Y. As an 
% alternative one can also define a model for the measurement error, for
% instance, Meas_info.Sigma = inline('a * x + b'), where "a" and "b" are
% additional parameters to be estimated, and "x" is Meas_info.Y.
% Example 17 gives an illustration how to do this in practice.
% -------------------------------------------------------------------------


% ############################ EXAMPLES ###################################

if example == 1, % n-dimensional banana shaped Gaussian distribution

    % ---------------------------- Check the following 2 papers ------------------------------- %
    %                                                                                           %
    %   Vrugt, J.A., C.J.F. ter Braak, C.G.H. Diks, D. Higdon, B.A. Robinson, and J.M. Hyman    %
    %       (2009), Accelerating Markov chain Monte Carlo simulation by differential evolution  %
    %       with self-adaptive randomized subspace sampling, International Journal of Nonlinear %
    %       Sciences and Numerical Simulation, 10(3), 271-288.                                  %
    %                                                                                           %
    %   Vrugt, J.A., H.V. Gupta, W. Bouten and S. Sorooshian (2003), A Shuffled Complex         %
    %       Evolution Metropolis algorithm for optimization and uncertainty assessment of       %
    %       hydrologic model parameters, Water Resour. Res., 39 (8), 1201,                      %
    %       doi:10.1029/2002WR001642.                                                           %
    %                                                                                           %
    % ----------------------------------------------------------------------------------------- %

    % Problem settings defined by user
    DREAMPar.d = 10;                        % Dimension of the problem
    DREAMPar.N = 10;                        % Number of Markov chains
    DREAMPar.T = 25000;                     % Number of generations
    DREAMPar.lik = 2;                       % Model output is log-likelihood
    
    % Provide information parameter space and initial sampling  
    Par_info.prior = 'normal';              % multinormal initial sampling distribution
    Par_info.mu = zeros(1,DREAMPar.d);      % if 'normal', define mean of distribution
    Par_info.cov = 10 * eye(DREAMPar.d);    % if 'normal', define covariance matrix
    
    % Define name of function (.m file) for posterior exploration
    Func_name = 'banana_func';
    
    % Run the DREAM algorithm
    [chain,output,fx] = DREAM(Func_name,DREAMPar,Par_info);

end;

if example == 2,    % n-dimensional Gaussian distribution

    % ---------------------------- Check the following two papers ----------------------------- %
    %                                                                                           %
    %   Vrugt, J.A., C.J.F. ter Braak, C.G.H. Diks, D. Higdon, B.A. Robinson, and J.M. Hyman    %
    %       (2009), Accelerating Markov chain Monte Carlo simulation by differential evolution  %
    %       with self-adaptive randomized subspace sampling, International Journal of Nonlinear %
    %       Sciences and Numerical Simulation, 10(3), 271-288.                                  %
    %                                                                                           %
    %   Ter Braak, C.J.F., and J.A. Vrugt (2008), Differential Evolution Markov Chain with      %
    %       snooker updater and fewer chains, Statistics and Computing,                         %
    %       10.1007/s11222-008-9104-9.                                                          %
    %                                                                                           %
    % ----------------------------------------------------------------------------------------- %

    % Problem settings defined by user
    DREAMPar.d = 100;                       % Dimension of the problem
    DREAMPar.N = 100;                       % Number of Markov chains
    DREAMPar.T = 10000;                     % Number of generations
    DREAMPar.thinning = 10;                 % Only store each 10th sample
    DREAMPar.lik = 2;                       % Model output is log-likelihood
    
    % Provide information parameter space and initial sampling  
    Par_info.prior = 'latin';               % Latin hypercube sampling
    Par_info.min = -5 * ones(1,DREAMPar.d); % If 'latin', min values
    Par_info.max = 15 * ones(1,DREAMPar.d); % If 'latin', max values

    % Define name of function (.m file) for posterior exploration
    Func_name = 'normalfunc';

    % Run the DREAM algorithm
    [chain,output,fx] = DREAM(Func_name,DREAMPar,Par_info);

end;

if example == 3,    % n-dimensional multimodal mixture distribution

    % ---------------------------- Check the following two papers ----------------------------- %
    %                                                                                           %
    %   Vrugt, J.A., C.J.F. ter Braak, C.G.H. Diks, D. Higdon, B.A. Robinson, and J.M. Hyman    %
    %       (2009), Accelerating Markov chain Monte Carlo simulation by differential evolution  %
    %       with self-adaptive randomized subspace sampling, International Journal of Nonlinear %
    %       Sciences and Numerical Simulation, 10(3), 271-288.                                  %
    %                                                                                           %
    %   Ter Braak, C.J.F., and J.A. Vrugt (2008), Differential Evolution Markov Chain with      %
    %       snooker updater and fewer chains, Statistics and Computing,                         %
    %       10.1007/s11222-008-9104-9.                                                          %
    %                                                                                           %
    % ----------------------------------------------------------------------------------------- %

    % Problem settings defined by user
    DREAMPar.d = 10;                        % Dimension of the problem
    DREAMPar.N = DREAMPar.d;                % Number of Markov chains
    DREAMPar.T = 100000;                    % Number of generations
    DREAMPar.thinning = 10;                 % Only store each 10th sample
    DREAMPar.lik = 1;                       % Model output is likelihood
    
    % Define name of function (.m file) for posterior exploration
    Func_name = 'mixturemodel';

    % Provide information parameter space and initial sampling  
    Par_info.prior = 'normal';              % Multinormal initial sampling distribution
    Par_info.mu = zeros(1,DREAMPar.d);      % If 'normal', define mean of distribution
    Par_info.cov = eye(DREAMPar.d);         % If 'normal', define covariance matrix

    % Run the DREAM algorithm
    [chain,output,fx] = DREAM(Func_name,DREAMPar,Par_info);

end;

if example == 4,    % HYMOD rainfall - runoff model (HYMOD coded in MATLAB)

    % ---------------------------- Check the following 3 papers ------------------------------- %
    %                                                                                           %
    %   Vrugt, J.A., C.J.F. ter Braak, M.P. Clark, J.M. Hyman, and B.A. Robinson (2008),        %
    %      Treatment of input uncertainty in hydrologic modeling: Doing hydrology backward with %
    %      Markov chain Monte Carlo simulation, Water Resources Research, 44, W00B09,           %
    %      doi:10.1029/2007WR006720, 2008.                                                      %
    %                                                                                           %
    %   Vrugt, J.A., C.J.F. ter Braak, H.V. Gupta, and B.A. Robinson (2009), Equifinality of    %
    %       formal (DREAM) and informal (GLUE) Bayesian approaches in hydrologic modeling?      %
    %       Stochastic Environmental Research and Risk Assessment, 23(7), 1011-1026, 		    %
    %       doi:10.1007/s00477-008-0274-y.                                                      %
    %                                                                                           %
    %   Vrugt, J.A., H.V. Gupta, W. Bouten and S. Sorooshian (2003), A Shuffled Complex         %
    %       Evolution Metropolis algorithm for optimization and uncertainty assessment of       %
    %       hydrologic model parameters, Water Resour. Res., 39 (8), 1201,                      %
    %       doi:10.1029/2002WR001642, 2003.                                                     %
    %                                                                                           %
    % ----------------------------------------------------------------------------------------- %

    % Problem settings defined by user
    DREAMPar.d = 5;                         % Dimension of the problem
    DREAMPar.N = 10;                        % Number of Markov chains
    DREAMPar.T = 1000;                      % Number of generations
    DREAMPar.lik = 11;                      % Model output is simulation: Gaussian likelihood function
    DREAMPar.modout = 'yes';                % Return model (function) simulations of samples (yes/no)?
    DREAMPar.parallel = 'yes';              % Run each chain on a different core
    
    % Provide information parameter space and initial sampling  
    Par_info.prior = 'latin';                   % Latin hypercube sampling
    Par_info.boundhandling = 'reflect';         % Explicit boundary handling
    Par_info.min = [1.0 0.10 0.10 0.00 0.10];   % If 'latin', min values
    Par_info.max = [500 2.00 0.99 0.10 0.99];   % If 'latin', max values

    % Define name of function (.m file) for posterior exploration
    Func_name = 'hymodMATLAB';

    % Load the Leaf River data
    load bound.txt;

    % Define the measured streamflow data
    Meas_info.Y = bound(65:795,4);

    % We need to specify the Meas_info error of the data in Meas_info.Sigma
    % With DREAMPar.lik = 3, Meas_info.Sigma is integrated out the likelihoon function
    % With some other likelihood functions, you have to define Sigma 
    
    % We can estimate the measurement error directly if we use temporal differencing
    % The function MeasError provides an estimate of error versus flow level
    % out = MeasError(Meas_info.Y);
    % For the Leaf River watershed this results in a heteroscedastic error
    % that is about 10% of the actual measured discharge value, thus
    % You can check this by plotting out(:,1) versus out(:,2)
    % Meas_info.Sigma = 0.1 * Meas_info.Y; % DREAMPar.lik = 2 or 7

    % We can also estimate the measurement error by specifying 
    % Meas_info.Sigma = inline('a'); --> homoscedastic
    % And add to Par_info min and max the ranges of "a"
    % One can also do a heteroscedastic error. Please check example 17
    
    % Run the DREAM algorithm
    [chain,output,fx] = DREAM(Func_name,DREAMPar,Par_info,Meas_info);

end;

if example == 5,    % HYMOD rainfall - runoff model (HYMOD coded in FORTRAN)

    % Problem settings defined by user
    DREAMPar.d = 5;                          % Dimension of the problem
    DREAMPar.N = 10;                         % Number of Markov chains
    DREAMPar.T = 1000;                       % Number of generations
    DREAMPar.lik = 11;                       % Model output is simulation: Gaussian likelihood function
    DREAMPar.IO = 'yes';                     % Input-output writing of model files (only for parallel!)
    DREAMPar.modout = 'yes';                 % Return model (function) simulations of samples (yes/no)?
    
    % Provide information parameter space and initial sampling  
    Par_info.prior = 'latin';                   % Latin hypercube sampling
    Par_info.boundhandling = 'reflect';         % Explicit boundary handling
    Par_info.min = [1.0 0.10 0.10 0.00 0.10];   % If 'latin', min values
    Par_info.max = [500 2.00 0.99 0.10 0.99];   % If 'latin', max values
    
    % Define name of function (.m file) for posterior exploration
    Func_name = 'hymodFORTRAN';

    % Load the Leaf River data
    load bound.txt;

    % Define the measured streamflow data
    Meas_info.Y = bound(65:795,4);

    % Run the DREAM algorithm
    [chain,output,fx] = DREAM(Func_name,DREAMPar,Par_info,Meas_info);

end;

if example == 6,    % Rainfall-runoff model with generalized log-likelihood

    % ---------------------------- Check the following 2 papers ------------------------------- %
    %                                                                                           %
    %   Schoups, G., J.A. Vrugt, F. Fenicia, and N.C. van de Giesen (2010), Corruption of       %
    %       accuracy and efficiency of Markov Chain Monte Carlo simulation by inaccurate        %
    %       numerical implementation of conceptual hydrologic models, Water Resources           %
    %       Research, 46, W10530, doi:10.1029/2009WR008648.                                     %
    %                                                                                           %
    %   Schoups, G., and J.A. Vrugt (2010), A formal likelihood function for parameter and      %
    %       predictive inference of hydrologic models with correlated, heteroscedastic and      %
    %       non-Gaussian errors, Water Resources Research, 46, W10531, doi:10.1029/2009WR008933.%
    %                                                                                           %
    % ----------------------------------------------------------------------------------------- %

    % Problem settings defined by user
    DREAMPar.d = 11;                         % Dimension of the problem
    DREAMPar.N = DREAMPar.d;                 % Number of Markov chains
    DREAMPar.T = 3000;                       % Number of generations
    DREAMPar.lik = 14;                       % Model output is simulation: Generalized likelihood function
    DREAMPar.parallel = 'no';              % This example ONLY runs in parallel!!
    
    % Provide information parameter space and initial sampling  
    Par_info.prior = 'latin';                % Latin hypercube sampling
    % Give the parameter ranges (minimum and maximum values)
    %parno:       1     2     3     4     5     6     7      8    9     10    11   12   13   14   15   16   17   18   19   20  21
    %parname:     fA    Imax  Smax  Qsmax alE   alS   alF    Pf   Kfast Kslow std0 std1 beta xi   mu1  phi1 phi2 phi3 phi4 K   lambda
    parmin =     [1     0     10    0     1e-6  1e-6 -10     0    0     0     0    0   -1    0.1  0    0    0    0    0    0   0.1 ];
    parmax =     [1     10    1000  100   100   1e-6  10     0    10    150   1    1    1    10   100  1    1    1    1    1   1];
    % Select the parameters to be sampled
    idx_vpar = [2 3 4 5 7 9 10 11 12 13 16];
    
    Par_info.boundhandling = 'reflect';     % Explicit boundary handling
    Par_info.min = parmin(idx_vpar);        % If 'latin', min values
    Par_info.max = parmax(idx_vpar);        % If 'latin', max values

    % Define name of function (.m file) for posterior exploration
    Func_name = 'hmodel';
    
    % Load the French Broad data
    daily_data = load('03451500.dly');
    % Define the measured streamflow data (two-year spin up period)
    Meas_info.Y = daily_data(731:end,6);

    % Run the DREAM algorithm
    [chain,output,fx] = DREAM(Func_name,DREAMPar,Par_info,Meas_info);

end;

if example == 7,	% HYDRUS-1D soil hydraulic model: using prior information on soil hydraulic parameters

    % -------------------------------- Check the following paper ------------------------------ %
    %                                                                                           %
    %   Scharnagl, B., J.A. Vrugt, H. Vereecken, and M. Herbst (2011), Bayesian inverse         %
    %	    modeling of soil water dynamics at the field scale: using prior information         %
    %	    on soil hydraulic properties, Hydrology and Earth System Sciences, 15, 3043–3059,   %
    %       doi:10.5194/hess-15-3043-2011.                                                      %
    %                                                                                           %
    % ----------------------------------------------------------------------------------------- %

    % Problem settings defined by user
    DREAMPar.d = 7;                         % Dimension of the problem
    DREAMPar.N = 10;                        % Number of Markov chains
    DREAMPar.T = 1000;                      % Number of generations
    DREAMPar.lik = 2;                       % Model output is log-likelihood
    DREAMPar.IO = 'yes';                    % Input-output writing of model files (only for parallel!)
    DREAMPar.parallel = 'no';              % This example ONLY runs in parallel!!
    DREAMPar.prior = 'yes';                 % Use an explicit prior distribution

    % Provide information parameter space and initial sampling  
    Par_info.prior = 'prior';               % Initial sample from prior distribution
    % Specify the marginal prior distribution of each individual parameter
    Par_info.prior_marginal = { 'normrnd(0.0670,0.0060)',...
                                'normrnd(0.4450,0.0090)',...
                                'normrnd(-2.310,0.0600)',...
                                'normrnd(0.2230,0.0110)',...
                                'normrnd(-1.160,0.2700)',...
                                'normrnd(0.3900,1.4700)',...
                                'unifrnd(-250,-50)'};
    % Define feasible parameter space (minimum and maximum values)
    %				1		2		3				4			5			6		7
    %				[thetar	thetas	log10(alpha)	log10(n)	log10(Ks)	L		hLB
    Par_info.boundhandling = 'reflect';     % Explicit boundary handling
    Par_info.min =	[0.0430	0.4090	-2.5528			0.1790		-2.2366		-5.4900	-250];  % For boundary handling
    Par_info.max =	[0.0910 0.4810	-2.0706			0.2670		-0.0800		6.2700	-50];   % For boundary handling

    % Define name of function (.m file) for posterior exploration
    Func_name = 'HYDRUS';

    % Run the DREAM algorithm
    [chain,output,fx] = DREAM(Func_name,DREAMPar,Par_info);

end;

if example == 8,    % Simple 1D mixture distribution -- Approximate Bayesian Computation

    % ---------------------------- Check the following 4 papers ------------------------------- %
    %                                                                                           %
    %   Sadegh, M., and J.A. Vrugt (2013), Bridging the gap between GLUE and formal statistical %
    %       approaches: approximate Bayesian computation, Hydrology and Earth System Sciences,  %
    %       17, 4831–4850.                                                                      % 
    %                                                                                           %
    %   Vrugt, J.A., and M. Sadegh (2013), Toward diagnostic model calibration and evaluation:  %
    %       Approximate Bayesian computation, Water Resources Research, 49, 4335–4345,          %
    %       doi:10.1002/wrcr.20354.                                                             %
    %                                                                                           %
    %   Sadegh, M., and J.A. Vrugt (2014), Approximate Bayesian computation using Markov chain  %
    %       Monte Carlo simulation: DREAM_(ABC), Water Resources Research,                      %
    %       doi:10.1002/2014WR015386.                                                           %
    %                                                                                           %
    %   Turner, B.M., and P.B. Sederberg (2013), Approximate Bayesian computation with          %
    %       differential evolution, Journal of Mathematical Psychology, In Press.               %
    %                                                                                           %
    % ----------------------------------------------------------------------------------------- %

    % Problem settings defined by user
    DREAMPar.d = 1;                         % Dimension of the problem
    DREAMPar.N = 5;                         % Number of Markov chains
    DREAMPar.T = 10000;                     % Number of generations
    DREAMPar.ABC = 'yes';                   % Specify that we perform ABC
    DREAMPar.lik = 22;                      % ABC informal likelihood function
    DREAMPar.epsilon = 0.025;               % Epsilon of the noisy ABC implementation
    DREAMPar.rho = inline('X - Y');         % Define the distance function
    DREAMPar.delta = 1;                     % Use only 1 pair of chains to create proposal

    % Provide information parameter space and initial sampling  
    Par_info.prior = 'latin';               % Latin hypercube sampling
    Par_info.boundhandling = 'reflect';     % Explicit boundary handling
    Par_info.min = -10;                     % If 'latin', min values
    Par_info.max =  10;                     % If 'latin', max values

    % Define name of function (.m file) for posterior exploration
    Func_name = 'ABC_func';

    % Define Meas_info.Y --> "Y" in paper
    Meas_info.Y = 0;
    
    % Run the DREAM_ZS algorithm
    [chain,output,fx] = DREAM(Func_name,DREAMPar,Par_info,Meas_info);

end;

if example == 9,    % Rainfall-runoff model with Whittle's likelihood function

    % ---------------------------- Check the following 2 papers ------------------------------- %
    %                                                                                           %
    %   Schoups, G., J.A. Vrugt, F. Fenicia, and N.C. van de Giesen (2010), Corruption of       %
    %       accuracy and efficiency of Markov Chain Monte Carlo simulation by inaccurate        %
    %       numerical implementation of conceptual hydrologic models, Water Resources           %
    %       Research, 46, W10530, doi:10.1029/2009WR008648.                                     %
    %                                                                                           %
    %   Schoups, G., and J.A. Vrugt (2010), A formal likelihood function for parameter and      %
    %       predictive inference of hydrologic models with correlated, heteroscedastic and      %
    %       non-Gaussian errors, Water Resources Research, 46, W10531, doi:10.1029/2009WR008933.%
    %                                                                                           %
    % ----------------------------------------------------------------------------------------- %

    % and for Whittle's likelihood function and application:

    % ----------------------------------------------------------------------------------------- %
    %                                                                                           %
    %   Montanari, A., and E. Toth (2007), Calibration of hydrological models in the spectral   %
    %       domain: An opportunity for scarcely gauged basins?, Water Resources Research, 43,   %
    %       W05434, doi:10.1029/2006WR005184.                                                   %
    %                                                                                           %
    % ----------------------------------------------------------------------------------------- %

    % Problem settings defined by user
    DREAMPar.d = 7;                         % Dimension of the problem
    DREAMPar.N = 10;                        % Number of Markov chains
    DREAMPar.T = 1500;                      % Number of generations
    DREAMPar.lik = 15;                      % Model output is simulation: Whittle's likelood function

    % Provide information parameter space and initial sampling  
    Par_info.prior = 'latin';               % Latin hypercube sampling
    % Give the parameter ranges (minimum and maximum values)
    %parno:      1     2     3     4     5     6     7      8    9     10    11   12   13   14   15   16   17   18   19   20  21
    %parname:   fA    Imax  Smax  Qsmax alE   alS   alF    Pf   Kfast Kslow std0 std1 beta xi   mu1  phi1 phi2 phi3 phi4 K   lambda
    fpar =      [1     0     100   10    100   1e-6  1e-6   0    2     70    0.1  0    0    1    0    0    0    0    0    0   1];
    parmin =    [1     0     10    0     1e-6  1e-6 -10     0    0     0     0    0   -1    0.1  0    0    0    0    0    0   0.1 ];
    parmax =    [1     10    1000  100   100   1e-6  10     0    10    150   1    1    1    10   100  1    1    1    1    1   1];
    idx_vpar = [2 3 4 5 7 9 10];
    % Define parameter ranges and boundary handling
    Par_info.boundhandling = 'reflect';     % Explicit boundary handling
    Par_info.min = parmin(idx_vpar);        % If 'latin', min values
    Par_info.max = parmax(idx_vpar);        % If 'latin', max values

    % Define name of function (.m file) for posterior exploration
    Func_name = 'hmodel';
    
    % Load the French Broad data
    daily_data = load('03451500.dly');
    % Define the measured streamflow data (two-year spin up period)
    Meas_info.Y = daily_data(731:end,6);

    % Run the DREAM algorithm
    [chain,output,fx] = DREAM(Func_name,DREAMPar,Par_info,Meas_info);
    
end;

if example == 10,    % the use of prior information in a multimodel mixture distrbibution

    % Problem settings defined by user
    DREAMPar.d = 2;                         % Dimension of the problem
    DREAMPar.N = 10;                        % Number of Markov chains
    DREAMPar.T = 1000;                      % Number of generations
    DREAMPar.lik = 1;                       % Model output is likelihood
    DREAMPar.prior = 'yes';                 % Use an explicit prior distribution
    
    % Provide information parameter space and initial sampling  
    Par_info.prior = 'normal';              % Multinormal initial sampling distribution
    Par_info.mu = zeros(1,DREAMPar.d);      % If 'normal', define mean of distribution
    Par_info.cov = eye(DREAMPar.d);         % If 'normal', define covariance matrix
    % Specify the marginal prior distribution of each individual parameter
    Par_info.prior_marginal = {  'normrnd(-5,0.1)',...
                                 'normrnd(-5,0.1)',...
                              };
    
    % Define name of function (.m file) for posterior exploration
    Func_name = 'mixturemodel';
    
    % So the mixture models has two modes at -5 and 5; with the specified prior
    % distribution the mode around 5 should disappear. You can compare the
    % theoretical distribution with the DREAM(ZS) results by plotting the
    % target distribution and adding in the density derived from the posterior samples. 
    
    % Run the DREAM algorithm   
    [chain,output,fx] = DREAM(Func_name,DREAMPar,Par_info);

end;

if example == 11,    % multivariate student t distribution with 60 degrees of freedom

    % ---------------------------- Check the following paper ---------------------------------- %
    %                                                                                           %
    %   Ter Braak, C.J.F., and J.A. Vrugt (2008), Differential Evolution Markov Chain with      %
    %       snooker updater and fewer chains, Statistics and Computing,                         %
    %       10.1007/s11222-008-9104-9.                                                          %
    %                                                                                           %
    % ----------------------------------------------------------------------------------------- %

    % Problem specific parameter settings
    DREAMPar.d = 25;                        % Dimension of the problem
    DREAMPar.N = 20;                        % Number of Markov chains
    DREAMPar.T = 5000;                      % Number of generations
    DREAMPar.lik = 2;                       % Model output is log-likelihood

    % Provide information parameter space and initial sampling    
    Par_info.prior = 'latin';                   % Latin hypercube sampling
    Par_info.min = -5 * ones(1,DREAMPar.d);     % Lower bound parameter values
    Par_info.max = 15 * ones(1,DREAMPar.d);     % Upper bound parameter values

    % Define name of function (.m file) for posterior exploration
    Func_name = 'multi_student';
 
    % Run the DREAM algorithm   
    [chain,output,fx] = DREAM(Func_name,DREAMPar,Par_info);
    
end;

if example == 12,    % pedometrics problem involving variogram fitting

    % ---------------------------- Check the following paper ---------------------------------- %
    %                                                                                           %
    %   Minasny, B., J.A. Vrugt, and A.B. McBratney (2011), Confronting uncertainty in model-   %
    %       based geostatistics using Markov chain Monte Carlo simulation, Geoderma, 163,       %
    %       150-162, doi:10.1016/j.geoderma.2011.03.011.                                        %
    %                                                                                           %   
    % ----------------------------------------------------------------------------------------- %
   
    % Problem settings defined by user
    DREAMPar.d = 5;                         % Dimension of the problem
    DREAMPar.N = 10;                        % Number of Markov chains
    DREAMPar.T = 1000;                      % Number of generations
    DREAMPar.lik = 2;                       % Model output is log-likelihood
    
    % Provide information parameter space and initial sampling  
    Par_info.prior = 'latin';               % Latin hypercube sampling
    Par_info.boundhandling = 'reflect';     % Explicit boundary handling
    Par_info.min = [0 0.00 0.00 0.00 0];    % If 'latin', min values
    Par_info.max = [100 100 1000 1000 20];  % If 'latin', max values

    % Define name of function (.m file) for posterior exploration
    Func_name = 'blpmodel';

    % Run the DREAM algorithm   
    [chain,output,fx] = DREAM(Func_name,DREAMPar,Par_info);

    % Create a single matrix with values sampled by chains
    ParSet = GenParSet(chain);

    % Postprocess the results to generate some fitting results
    Postproc_variogram
    
end;

if example == 13,    % Nash-Cascade series of reservoirs

    % ---------------------------- Check the following 2 papers ------------------------------- %
    %                                                                                           %
    %   Nash, J.E. (1960), A unit hydrograph study with particular reference to British         %
    %       catchments, Proceedings - Institution of Civil Engineers, 17, 249-282      .        % 
    %                                                                                           %
    %   Nash, J.E., J.V. Sutcliffe (1970), River flow forecasting through conceptual models     %
    %       part I - A discussion of principles, Journal of Hydrology, 10(3), 282-290.          %
    %                                                                                           %   
    % ----------------------------------------------------------------------------------------- %

    % Problem settings defined by user
    DREAMPar.d = 1;                         % Dimension of the problem
    DREAMPar.N = 10;                        % Number of Markov chains
    DREAMPar.T = 1000;                      % Number of generations
    DREAMPar.lik = 12;                      % Model output is simulation: Gaussian likelihod with explicit measurement error
    DREAMPar.modout = 'yes';                % Return model (function) simulations of samples (yes/no)?

    % Provide information parameter space and initial sampling  
    Par_info.prior = 'latin';               % Latin hypercube sampling
    Par_info.boundhandling = 'reflect';     % Explicit boundary handling
    Par_info.min =  1;                      % If 'latin', min values
    Par_info.max = 100;                     % If 'latin', max values

    % Define name of function (.m file) for posterior exploration
    Func_name = 'Nash_Cascade';

    % Create the synthetic time series
    [S] = Nash_Cascade(2);
    % Now define heteroscedastic measurement error
    Meas_info.Sigma = max( 1/5*S , 1e-2);   
    % Observed data: Model simulation with heteroscedastic measurement error
    Meas_info.Y = normrnd(S,Meas_info.Sigma);
    
    % Run the DREAM algorithm
    [chain,output,fx] = DREAM(Func_name,DREAMPar,Par_info,Meas_info);

end;

if example == 14, % Diagnostic Bayes using rainfall runoff modeling example
 
    % ---------------------------- Check the following 4 papers ------------------------------- %
    %                                                                                           %
    %   Vrugt, J.A., and M. Sadegh (2014), Diagnostic Bayes: Sufficient statistics, Water       %
    %       Resources Research, In preparation.                                                 %
    %                                                                                           %
    %   Lochbuhler, T., J.A. Vrugt, M. Sadegh, and N. Linde (2014), Summary statistics from     %
    %       training images as prior information in probabilistic inversion, Geophysical        %
    %       Journal International, XX, XX--XX, doi:GJI-S-13-0278.                               %
    %                                                                                           %
    %   Sadegh, M., and J.A. Vrugt (2014), Approximate Bayesian computation using Markov chain  %
    %       Monte Carlo simulation: DREAM_(ABC), Water Resources Research,                      %
    %       doi:10.1002/2014WR015386.                                                           % 
    %                                                                                           %
    %   Vrugt, J.A., and M. Sadegh (2013), Toward diagnostic model calibration and evaluation:  %
    %       Approximate Bayesian computation, Water Resources Research, 49, 4335–4345,          %
    %       doi:10.1002/wrcr.20354.                                                             %
    %                                                                                           %
   % ----------------------------------------------------------------------------------------- %

    % Problem settings defined by user
    DREAMPar.d = 7;                         % Dimension of the problem
    DREAMPar.N = 10;                        % Number of Markov Chains / chain
    DREAMPar.T = 5000;                      % Number of generations
    DREAMPar.lik = 11;                      % Model output is simulation: Gaussian likelihood
    DREAMPar.ABC = 'yes';                   % Diagnostic Bayes: ABC with summary metrics as prior
    DREAMPar.epsilon = 0.025;               % Epsilon of the noisy ABC implementation
    DREAMPar.parallel = 'yes';              % Run each chain on different core      
    DREAMPar.modout = 'yes';                % Store model simulations
    
    % Provide information parameter space and initial sampling  
    Par_info.prior = 'latin';               % Latin hypercube sampling
    Par_info.boundhandling = 'reflect';     % Explicit boundary handling
    %parname:       Imax  Smax  Qsmax   alE   alF   Kfast  Kslow  
    Par_info.min = [ 0.5   10     0    1e-6   -10     0      0    ];    % If 'latin', min values
    Par_info.max = [ 10   1000   100   100     10     10    150   ];    % If 'latin', max values

    % Define name of function (.m file) for posterior exploration
    Func_name = 'rainfall_runoff';
    
    % Load the French Broad data
    daily_data = load('03451500.dly');
    % Define the observed streamflow data
    Meas_info.Y = daily_data(731:end,6);
    % Now calculate summary metrics from the discharge data and define as prior distribution by using field "S"
    Meas_info.S = CalcMetrics( Meas_info.Y )';
        
    % Now create call to summary metric calculator
    DREAMPar.prior_handle = eval(['@(fx)','CalcMetrics','(fx)''']);
                            
    % Run the DREAM algorithm
    [chain,output,fx] = DREAM(Func_name,DREAMPar,Par_info,Meas_info);
    
end;

if example == 15,    % 10 bivariate normal distributions -- Approximate Bayesian Computation

    % ---------------------------- Check the following 4 papers ------------------------------- %
    %                                                                                           %
    %   Sadegh, M., and J.A. Vrugt (2014), Approximate Bayesian computation using Markov chain  %
    %       Monte Carlo simulation: DREAM_(ABC), Water Resources Research,                      %
    %       doi:10.1002/2014WR015386.                                                           % 
    %                                                                                           %
    %   Vrugt, J.A., and M. Sadegh (2013), Toward diagnostic model calibration and evaluation:  %
    %       Approximate Bayesian computation, Water Resources Research, 49, 4335–4345,          %
    %       doi:10.1002/wrcr.20354.                                                             %
    %                                                                                           %
    %   Sadegh, M., and J.A. Vrugt (2013), Bridging the gap between GLUE and formal statistical %
    %       approaches: approximate Bayesian computation, Hydrology and Earth System Sciences,  %
    %       17, 4831–4850.                                                                      % 
    %                                                                                           %
    %   Turner, B.M., and P.B. Sederberg (2013), Approximate Bayesian computation with          %
    %       differential evolution, Journal of Mathematical Psychology, In Press.               %
    %                                                                                           %
    % ----------------------------------------------------------------------------------------- %

    %How many bivariate normal distributions?
    func.Npairs = 10;
    
    % Problem settings defined by user
    DREAMPar.d = 2 * func.Npairs;            % Dimension of the problem
    DREAMPar.N = 10;                         % Number of Markov chains
    DREAMPar.T = 3000;                       % Number of generations
    DREAMPar.lik = 22;                       % ABC informal likelihood function
    DREAMPar.ABC = 'yes';                    % Specify that we perform ABC
    DREAMPar.rho = inline(' sqrt( 1 / 20 * sum((X - Y).^2)) ');  

    % Provide information parameter space and initial sampling  
    Par_info.prior = 'latin';                % Latin hypercube sampling
    Par_info.boundhandling = 'fold';         % Explicit boundary handling
    Par_info.min = zeros(1,2*func.Npairs);   % If 'latin', min values      
    Par_info.max = 10*ones(1,2*func.Npairs); % If 'latin', max values   
    
    % Define name of function (.m file) for posterior exploration
    Func_name = 'ABC_binormal';
    
    % Lets create the data - the mean (mu) of ten bivariate normals
    Meas_info.Y = Par_info.min' + rand(DREAMPar.d,1) .* ( Par_info.max - Par_info.min )';
    
    % Run the DREAM algorithm
    [chain,output,fx] = DREAM(Func_name,DREAMPar,Par_info,Meas_info);

end;

if example == 16,   % Crosshole GPR slowness distribution based on a straight-ray approximation using the discrete cosine transform. 
                    % The problem is simplified compared to the paper cited below as it considers a problem in which the true model 
                    % represent a model with the same dimension as the inverse parameterization and it uses straight rays.

    % ### Results can be visualized by the function visualize_results.m ###

    % -------------------------- Check the following 4 papers --------------------------------- %
    %                                                                                           %
    %   Linde, N., and J.A. Vrugt (2013), Spatially distributed soil moisture from traveltime   %
    %       observations of crosshole ground penetrating radar using Markov chain Monte Carlo,  %
    %       Vadose Zone Journal, 12(1), 1-16                                                    %
    %                                                                                           %
    %   Laloy, E., N. Linde, and J.A. Vrugt (2012), Mass conservative three-dimensional water   %
    %       tracer distribution from Markov chain Monte Carlo inversion of time-lapse           %
    %       ground-penetrating radar data, Water Resour. Res., 48, W07510,                      %  
    %       doi:10.1029/2011WR011238.                                                           %
    %                                                                                           %
    %   Carbajal, M.R., N. Linde, T. Kalscheuer, and J.A. Vrugt (2014), Two-dimensional         %
    %       probabilistic inversion of plane-wave electromagnetic data: Methodology, model      %
    %       constraints and joint inversion with electrical resistivity data, Geophysical       % 
    %       Journal International}, 196(3), 1508-1524, doi: 10.1093/gji/ggt482.                 %
    %                                                                                           %
    %   Lochbuhler, T., S.J. Breen, R.L. Detwiler, J.A. Vrugt, and N. Linde (2014),             %
    %       Probabilistic electrical resistivity tomography for a CO_2 sequestration analog,    %
    %       \Journal of Applied Geophysics, 107, 80-92, doi:10.1016/j.jappgeo.2014.05.013.      %
    %                                                                                           %
    % ----------------------------------------------------------------------------------------- %
       
    % DCT order in x and z dimension?
    func.parx = 8; func.parz = 8;           
    
    % Problem settings defined by user
    DREAMPar.d = func.parx * func.parz;     % Dimension of the problem       
    DREAMPar.N = 30;                        % Number of Markov chains
    DREAMPar.T = 10000;                     % Number of generations
    DREAMPar.thinning = 5;                  % Only store each 5th sample
    DREAMPar.lik = 2;                       % Model output is log-likelihood
    
    % Define name of function (.m file) for posterior exploration
    Func_name = 'DCT_GPR';

    % Provide information parameter space and initial sampling  
    Par_info = GPR_par_ranges ( func );                                 % Define the parameter ranges
    Par_info.prior = 'normal';                                          % Multinormal initial sampling distribution
    Par_info.mu = Par_info.min + 0.5 * ( Par_info.max - Par_info.min ); % If 'normal', define mean of distribution
    Par_info.cov = 0.001 * diag( Par_info.max - Par_info.min );         % If 'normal', define covariance matrix
    
    % Provide information to do initial sampling ('normal') --> The initial
    % chain positions are concentrated in the middle of the parameter ranges
    % This will speed up convergence -- but cannot be done in practice!

    % Run the DREAM algorithm
    [chain,output,fx] = DREAM(Func_name,DREAMPar,Par_info);
    
end;

if example == 17,    % HYMOD rainfall - runoff model with measurement error estimation

    % ---------------------------- Check the following 2 papers ------------------------------- %
    %                                                                                           %
    %   Bikowski, J., J.A. Huisman, J.A. Vrugt, H. Vereecken, and J. van der Kruk (2012),       %
    %      Inversion and sensitivity analysis of ground penetrating radar data with waveguide   %
    %      dispersion using deterministic and Markov chain Monte Carlo methods, Near Surface    %
    %      Geophysics, Special issue "Physics-based integrated characterization", 10(6),        %
    %      641-652, doi:10.3997/1873-0604.2012041, 2012.                                        %
    %                                                                                           %
    %   Vrugt, J.A., C.J.F. ter Braak, H.V. Gupta, and B.A. Robinson (2009), Equifinality of    %
    %       formal (DREAM) and informal (GLUE) Bayesian approaches in hydrologic modeling?,     %
    %       Stochastic Environmental Research and Risk Assessment, 23(7), 1011-1026, 	        %
    %       doi:10.1007/s00477-008-0274-y.                                                      %
    %                                                                                           %
    % ----------------------------------------------------------------------------------------- %

    % Problem settings defined by user
    DREAMPar.N = 10;                         % Number of Markov chains
    DREAMPar.T = 1000;                       % Number of generations
    DREAMPar.lik = 12;                       % Model output is simulation: Gaussian log-likelihood with inference of measurement error
    DREAMPar.modout = 'yes';                 % Return model (function) simulations of samples (yes/no)?

    % Provide information parameter space and initial sampling  
    Par_info.prior = 'latin';                   % Latin hypercube sampling
    Par_info.boundhandling = 'reflect';         % Explicit boundary handling
    Par_info.min = [ 1.0 0.10 0.10 0.00 0.10 ]; % If 'latin', min values      
    Par_info.max = [ 500 2.00 0.99 0.10 0.99 ]; % If 'latin', max values      

    % Define name of function (.m file) for posterior exploration
    Func_name = 'hymodMATLAB';

    % ---------------------------------------------------------------------
    % Which measurement error shall we take? (with DREAMPar.lik = 2 or 7 !!)
    homoscedastic = 1; heteroscedastic = 0;
    
    % We attempt to estimate the Meas_info error (homoscedastic)
    if homoscedastic == 1,
        % Sigma independent of magnitude of y (Meas_info.Y)
        Meas_info.Sigma = inline('a'); 
        % How many parameters does this error model have?
        Meas_info.n = 1;
        % Now add "a" to the parameter ranges ("a" will be estimated)
        Par_info.min = [Par_info.min 0.5]; Par_info.max = [Par_info.max 100];
    elseif heteroscedastic == 1,
        % Sigma linearly dependent on y (Meas_info.Y)
        Meas_info.Sigma = inline('a * y + b'); 
        % "a" is slope, and "b" is intercept !! (make sure that Sigma > 0 )

        % How many parameters does this error model have?
        Meas_info.n = 2;
        % Add "a" and "b" to parameter ranges (in order of "b" and "a" !!)
        Par_info.min = [Par_info.min 0 0]; Par_info.max = [Par_info.max 1 1];
    end;
    % NOTE: ONE CAN SPECIFY ANY TYPE OF HETEROSCEDASTIC ERROR MODEL! 
    % ---------------------------------------------------------------------
    
    % How many parameters do we have total?
    DREAMPar.d = size(Par_info.min,2); 

    % Load the Leaf River data
    load bound.txt;
    % Define the measured streamflow data
    Meas_info.Y = bound(65:795,4);

    % Run the DREAM algorithm
    [chain,output,fx] = DREAM(Func_name,DREAMPar,Par_info,Meas_info);

end;

% Create a single matrix with values sampled by chains
ParSet = GenParSet(chain);

% --------------------------------------------------------------------------------------------- %
% ------------------------------------ POSTPROCESSING ----------------------------------------- %
%                                                                                               %
% For postprocessing of results --> please go to directory \PostProcessing and run the          %  
% "postprocMCMC" script. This will compute various statistic and create a number of different   % 
% plots, including the R_stat convergence diagnostic, marginal posterior parameter              % 
% distributions, two-dimensional correlation plots of the posterior parameter samples, and      %  
% parameter and total uncertainty posterior simulation uncertainty ranges.                      %
%                                                                                               %
% --------------------------------------------------------------------------------------------- %
% --------------------------------------------------------------------------------------------- %