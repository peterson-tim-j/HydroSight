function [chain,output,fx,log_L] = DREAM(Func_name,func_name_validParams, DREAMPar,Par_info,Meas_info, GUIobj, varargin)
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
%       Approximate Bayesian computation, Water Resources Research, 49, 4335�4345,              %
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

% Check how many input variables
if nargin < 4, Meas_info.Y = []; end
if isempty(Meas_info), Meas_info.Y = []; end

%if ~isfield(DREAMPar,'restart') || strcmp(DREAMPar.restart,'no')
    % Initialize the main variables used in DREAM
    [DREAMPar,Par_info,Meas_info,chain,output,log_L,Table_gamma,iloc,iteration,...
        gen] = DREAM_setup(DREAMPar,Par_info,Meas_info);

    % Set random seed
    rng(DREAMPar.iseed);     % random number generator state %TJP

    % Check for setup errors
    [stop,fid] = DREAM_check(DREAMPar,Par_info,Meas_info);

    % Return to main program
    if strcmp(stop,'yes')
        return; 
    end

    % Create computing environment (depending whether multi-core is used)
    %[DREAMPar,f_handle] = DREAM_calc_setup(DREAMPar,Func_name);

    % Setup function handle and default number of cores. Note, if parpool has been 
    % opened then >1 core will be  used within parfor loops indifferent of
    % the number of cores defined here. TJP 2022
    if isa(Func_name,'function_handle')
        f_handle = Func_name;
    else
        f_handle = eval(['@(x)',char(Func_name),'(x)']);
    end
    DREAMPar.CPU = 1;

    % Now check how the measurement sigma is arranged (estimated or defined)
    Meas_info = Check_sigma(Meas_info); T_start = 2;

    % Create the initial states of each of the chains (initial population)
    [chain,output,X,fx,CR,pCR,lCR,delta_tot,log_L] = DREAM_initialize(DREAMPar,Par_info,Meas_info,f_handle,chain,output,log_L, varargin{:});

% elseif strcmp(DREAMPar.restart,'yes')
%     % Print to screen restart run
%     disp('Restart run');
%     % If a restart run is being done: just load the output from the previous ongoing trial
%     load DREAM.mat; [CR] = Draw_CR(DREAMPar,pCR); DREAMPar.T = 2 * DREAMPar.T;
%     % And make sure we add zeros to "chain" array
%     chain = [chain ; nan(size(chain,1)-1,size(chain,2),size(chain,3))];
%     % Open warning file and set T_start
%     fid = fopen('warning_file.txt','a+'); T_start = t + 1;
% end

% Initialize waitbar. 
%if usejava('desktop')
%    h = waitbar(0,'Running DREAM - Please wait...');  
%end
totaccept = 0; tic;

% Now start iteration ...
for t = T_start : DREAMPar.T
    
    % Unoack current state of chain and associated log-likelihood and log-prior values
    [xold,log_PR_xold,log_L_xold] = deal(X(:,1:end-2),X(:,end-1),X(:,end));
    
    % Now generate candidate in each sequence using current point and members of X
    [xnew,CR(:,gen)] = Calc_proposal(xold,CR(:,gen),DREAMPar,Table_gamma,Par_info);
    
    % Check if the parameters are valid - TJP
    isValid = all(feval(func_name_validParams,xnew', varargin{:}),1)';
    fx_new = -inf(1,size(xnew,1));

    % Now evaluate the model ( = pdf ) and return fx
    %[fx_new] = Evaluate_model(xnew,DREAMPar,Meas_info,f_handle, varargin{:});
    fx_new(isValid) = f_handle(xnew(isValid,:)', varargin{:});   % For for calling HydroSight model - TJP
    
    % Calculate the log-likelihood and log-prior of x (fx)
    [log_L_xnew,log_PR_xnew] = Calc_density(xnew,fx_new,DREAMPar,Par_info,Meas_info);
    
    % Calculate the Metropolis ratio
    [accept,idx_ac] = Metropolis_rule(DREAMPar,log_L_xnew,log_PR_xnew,log_L_xold,log_PR_xold);
    
    % And update X and the model simulation
    X(idx_ac,1:DREAMPar.d+2) = [xnew(idx_ac,1:DREAMPar.d) log_PR_xnew(idx_ac,1) log_L_xnew(idx_ac,1)]; 
    fx(:,idx_ac) = fx_new(:,idx_ac);
    
    % Check whether to add the current points to the chains or not?
    if mod(t,DREAMPar.thinning) == 0
        % Store the current sample in chain
        iloc = iloc + 1; chain(iloc,1:DREAMPar.d+2,1:DREAMPar.N) = reshape(X',1,DREAMPar.d+2,DREAMPar.N);
        
        % Store the model simulations (if appropriate)
        DREAM_store_results ( DREAMPar , fx , Meas_info , 'a+' );
    end
    
    % Check whether we update the crossover values
    if strcmp(DREAMPar.adapt_pCR,'yes')
        % Calculate the standard deviation of each dimension of X
        r = repmat(std(X(1:DREAMPar.N,1:DREAMPar.d)),DREAMPar.N,1);
        % Compute the Euclidean distance between new X and old X
        delta_normX = sum(((xold(1:end,1:DREAMPar.d) - X(1:end,1:DREAMPar.d))./r).^2,2);
        % Use this information to update sum_p2 to update N_CR
        delta_tot = Calc_delta(DREAMPar,delta_tot,delta_normX,CR(1:DREAMPar.N,gen));
    end
    % Update gen
    gen = gen + 1;
    
    % How many candidate points have been accepted -- to calculate acceptance rate
    totaccept = totaccept + sum(accept);
    
    % Update log_L
    log_L(t,1:DREAMPar.N+1) = [ t * DREAMPar.N X(1:DREAMPar.N,DREAMPar.d+2)'];
        
    % If t equal to MCMC.steps then convergence checks and updates
    if mod(t,DREAMPar.steps) == 0
        
        % Save some important output -- Acceptance Rate
        output.AR(iteration,1:2) = [ t * DREAMPar.N 100 * sum(totaccept) / (DREAMPar.N * DREAMPar.steps)];
        
        % Check whether to update individual pCR values
        if ( t <= DREAMPar.T / 10 )
            if strcmp(DREAMPar.adapt_pCR,'yes')
                % Update pCR values
                [pCR,lCR] = Adapt_pCR(DREAMPar,CR,delta_tot,lCR);
            end
        else
            % See whether there are any outlier chains, and remove them to current best value of X
            [X,log_L(1:t,2:DREAMPar.N+1),output.outlier] = Remove_outlier(X,log_L(1:t,2:DREAMPar.N+1),output.outlier,DREAMPar,fid);
        end
        
        % Store diagnostic information -- Probability of individual crossover values
        output.CR(iteration,1:DREAMPar.nCR+1) = [ t * DREAMPar.N pCR];
        
        % Generate new crossover values
        CR = Draw_CR(DREAMPar,pCR);
        
        % Calculate Gelman and Rubin Convergence Diagnostic
        start_idx = max(1,floor(iloc/2)); end_idx = iloc;
        
        % Compute the R-statistic using 50% burn-in from chain
        [output.R_stat(iteration,1:DREAMPar.d+1)] = [ t * DREAMPar.N Gelman(chain(start_idx:end_idx,1:DREAMPar.d,1:DREAMPar.N),DREAMPar)];        
        
        % Save the output or not?
        if strcmpi(DREAMPar.save,'yes')
            % Store in memory
            save DREAM.mat            
        end

        % Update GUI and check if user has quit - TJP
        if ~isempty(GUIobj)  && isa(GUIobj, 'HydroSight_GUI')

            % Update the GUI plots
            r2 = output.R_stat(iteration,2:DREAMPar.d+1)';
            modelCalibration_CalibPlotsUpdate(GUIobj, false,'DREAM',[], t, t*DREAMPar.N, xnew', fx_new', r2,max(r2),max(r2));

            % Get quit/skip state for calibration.
            exitCalib = modelCalibration_getCalibState(GUIobj);
            if exitCalib
                break
            end
        end

        % Update the iteration, set gen back to 1 and totaccept to zero
        iteration = iteration + 1;  gen = 1; totaccept = 0;

        % Check convergence (Peterson 2022)
        %-----------
        % Extract the R_statistic values and dilter for those
        % where R_statistic<1.2 for all parameters in the set.
        r_stat_acceptable = all(output.R_stat(1: end, 2: DREAMPar.d + 1)<DREAMPar.r2_threshold,2);

        % Find the threshold generations where R-stat criteria is first met.
        convergedParamSamplesThreshold = min(output.R_stat(r_stat_acceptable,1));

        % Find the number oif converged gens    
        numFunctionEvals = output.R_stat(end, 1);
        convergedParamSamples = max(1,numFunctionEvals - convergedParamSamplesThreshold);
        if convergedParamSamples>DREAMPar.Tmin*DREAMPar.d
            break;
        end
        %-----------
    end

    % Update the waitbar. TJP Edit to check for graphical enviro
    if mod(t,100)==0
        display(['... Finished iteration ',num2str(t), ', of ', num2str(DREAMPar.T)])
    end

end

% -------------------------------------------------------------------------

% Determine total run time
output.RunTime = toc;

% Variables have been pre-allocated --> need to remove zeros at end
[chain,output,fx] = DREAM_end(DREAMPar,Meas_info,chain,output,iteration,iloc,fid);

% Close the waitbar
%if usejava('desktop')
%    close(h);
%end
