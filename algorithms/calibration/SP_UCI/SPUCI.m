function [bestx,bestf,icall, exitFlag, exitStatus] = SPUCI(funcHandle, funcHangle_validParams, x0,bl_plausible, bu_plausible, bl_phys, bu_phys, ... 
                                                            maxn, kstop,pcento,peps,ngs,iseed,iniflg, calibGUI_interface_obj, varargin) 
% This is the Matlab code implementing the SP-UCI algorithm,written by Dr.
% Wei Chu, 08/2012, based on the SCE Matlab codes written by Dr. Q. Duan
% 9/2004.
% 
% If you have any questions or comments,Please contact Dr. Wei Chu at
% wchu2@uci.edu
% 
% This algorithm has been published in Infomration Sciences and shoud be
% cited as:
%
%   Wei	Chu,	X. Gao and S. Sorooshian,(2011), A new evolutionary search
%   strategy for global optimization of high-dimensional Problems,
%   Information Sciences, doi:10.1016/j.ins. 2011.06.024.
%
%
% Definition of input variables:
%  x0 = the initial parameter array at the start;
%     = the optimized parameter array at the end

%  f0 = the objective function value corresponding to the initial parameters
%     = the objective function value corresponding to the optimized parameters
%  bl = the lower bound of the parameters
%  bu = the upper bound of the parameters
%  iseed = the random seed number (for repetetive testing purpose)
%  iniflg = flag for initial parameter array (=1, included it in initial
%           population; otherwise, not included)
%  ngs = number of complexes (sub-populations)
%  maxn = maximum number of function evaluations allowed during optimization
%  kstop = maximum number of evolution loops before convergency
%  percento = the percentage change allowed in kstop loops before
%  convergency
%
% Definition of outputs
%  bestx = best parameter values at the end of the search.
%  besft = best objective function value at the end of the search.
%
% Additional outputs (edits by Tim Peterson 2016)
%  exitFlag = 0: did not converge, 1=partial convergence, 2 = converged
%  exitStatus = statement of why the scheme ended.
%
% Additional modifications (Tim Peterson 2017)
%  - Numerous additions were made to SPUCI.m and MCCE.m to handle derived
%  forcing data (specifically down-scaled pumping forcing data derived from
%  a simulated annealing approach). 
%  - Construction of complexes changed from using randperm() to the
%  standard method of SCE-UA. This was undertaken to allow the assignment
%  of the best derived forcing time series to the top 'ngs' solutions. That
%  is, the derived forcing could be extracted for the best ngs parameter
%  sets and then the derived forcing applied to each of the other parameter
%  sets within the complex.
%  - GauSamp() was commented out. It increased the number of model
%  evaluations by 'npt' for little identifiable improvement in the
%  solution.
%

% Check if derived forcing is to be handled
stochDerivedForcingData_prior = getStochForcingData(varargin{1});
useDerivedForcing = false;
if any(~isempty(stochDerivedForcingData_prior))
    useDerivedForcing = true;
end

% Initialization of agorithmic 
%iseed= 123456
nopt=length(x0); %dimentions of the problem
npg=2*nopt+1;%  npg = number of members is a complex
nps=nopt+1;%  nps = number of members in a simplex
nspl=nps;%  nspl = number of evolution steps for each complex before shuffling
if useDerivedForcing
    nspl=2*nps;%  nspl = number of evolution steps for each complex before shuffling
end
npt=npg*ngs;%npt = the total number of members (the population size)

bound = bu_plausible - bl_plausible;% boundary of the feasible space.

% Initialise exist outputs. Tim Peterson 2016
exitFlag = 0;
exitStatus = 'Calibration scheme did not start.';
bestf_ever = inf;

% Initialization of the populaton and calculate their objective function value. 
[x,xf, icall] = initialisePopulation(funcHandle, funcHangle_validParams, x0,bl_plausible, bu_plausible, iniflg, npt, nopt, 0, varargin{:});

% Check if the population degeneration occured
[x, xf, icall]=DimRest(funcHandle, funcHangle_validParams, x,xf,bl_phys,bu_phys,icall, varargin{:});

% Get the initial derived forcing data
stochDerivedForcingData_best = getStochForcingData(varargin{1});


% Sort the population again and record the best and worst points
[xf,idx]=sort(xf);
x=x(idx,:);
bestx=x(1,:); bestf=xf(1);
worstx=x(npt,:); worstf=xf(npt);

% Computes the normalized geometric range of the parameters
gnrng=exp(mean(log((max(x)-min(x))./bound)));

disp('The Initial Loop: 0');
disp(['BESTF  : ' num2str(bestf)]);
disp(['BESTX  : ' num2str(bestx)]);
disp(['WORSTF : ' num2str(worstf)]);
disp(['WORSTX : ' num2str(worstx)]);
disp(' ');

% Check for convergency;
if icall >= maxn;
    disp('*** OPTIMIZATION SEARCH TERMINATED BECAUSE THE LIMIT');
    disp('ON THE MAXIMUM NUMBER OF TRIALS ');
    disp(maxn);
    disp('HAS BEEN EXCEEDED.  SEARCH WAS STOPPED AT TRIAL NUMBER:');
    disp(icall);
    disp('OF THE INITIAL LOOP!');
end;

if gnrng < peps;
    disp('THE POPULATION HAS CONVERGED TO A PRESPECIFIED SMALL PARAMETER SPACE');
end;

% Update the diary file
if ~isempty(calibGUI_interface_obj)
    updatetextboxFromDiary(calibGUI_interface_obj);
    [doQuit, exitFlagQuit, exitStatusQuit] = getCalibrationQuitState(calibGUI_interface_obj);
    if doQuit
        exitFlag = exitFlagQuit;
        exitStatus = exitStatusQuit;
        return;
    end    
end

% Update exist status output. Tim Peterson 2016
exitStatus = 'Calibration scheme did started.';

% Begin evolution loops:
criter=[];
criter_change=1e+5;
xigs = [];
bestf_ever=bestf;
bestx_ever=bestx;
nloop=0;
%doReEval_DerivedForcing = false;
while icall<maxn && gnrng>peps && criter_change>pcento
    nloop=nloop+1;
    %%%%%%%%%%%%%%%%%%%%%%%%
    %idexx=randperm(npt);
    %%%%%%%%%%%%%%%%%%%%%%%%

    % Create indexes for each complex
    %or igs = 1: ngs;
    %    ind{igs} = idexx(npg*(igs-1)+1:npg*igs);
    %end    
    
    % NOTE: SPU-UCI originally used randperm for distribution of the
    % points to complexes. It is unclear why this was adopted over the
    % determinsitic partitioning approach of SCE-UA. TIm Peterson.
    for igs = 1: ngs        
        k1=1:npg;
        ind{igs}=(k1-1)*ngs+igs;
    end
    
    % Get the stochastic derived forcing data
    stochDerivedForcingData_prior = getStochForcingData(varargin{1});
        
    % Check if derived forcing is to be handled
    useDerivedForcing = false;
    if any(~isempty(stochDerivedForcingData_prior))
        useDerivedForcing = true;
    end    
    
    % Sort derived forcings by new index complexes    
    if useDerivedForcing && nloop>1
        stochDerivedForcingData_new = cell(ngs,1);
        for igs = 1: ngs;
            % Get the appropriate derived forcing data for each complex. 
            stochDerivedForcingData_new{igs} = stochDerivedForcingData{xigs(igs)};
        end
        stochDerivedForcingData = stochDerivedForcingData_new;
        clear stochDerivedForcingData_new
        
    end

    %-----------------
    % Importantly, with the derived forcing changing then objective
    % function value for each parameter set is most likely to change. 
    % Therefore, all parameter sets are re-evaluated.    
    if useDerivedForcing                
        if ~isempty(xigs) && iscell(stochDerivedForcingData) && length(stochDerivedForcingData)==ngs
            model = varargin{1};
            stochDerivedForcingData_sliced = stochDerivedForcingData(xigs);
            parfor i=1:npt
                % Assign derived forcing using xigs
                updateStochForcingData(model, stochDerivedForcingData_sliced{i});
                xf(i) = feval(funcHandle, x(i,:)', varargin{:});
            end
            clear stochDerivedForcingData_sliced;
        end
        icall = icall + npt;
    end       
    %-----------------
    
    % Initialise cell array for cx and cf
    cx = cell(ngs,1);
    cf = cell(ngs,1);
    cicall = zeros(ngs,1);
    if nloop==1
     stochDerivedForcingData = cell(ngs,1);
    end
    model = varargin{1};
        
    % Loop on complexes (sub-populations);
    parfor igs = 1: ngs

        % Assign derived forcing using xigs
        if useDerivedForcing && nloop>1
            updateStochForcingData(model, stochDerivedForcingData{igs});
        end
        
        % This is the major computionation load. It was shifted into a
        % stand alone function by Tim Peterson to allow parrellisation.
        [cx{igs}, cf{igs}, cicall(igs), stochDerivedForcingData{igs}] = doComplexEvolution(funcHandle, funcHangle_validParams, ind{igs}, x, xf, ...
        bl_plausible, bu_plausible, bl_phys,bu_phys, nspl, nps, npg, useDerivedForcing , varargin{:});
        
    % End of Loop on Complex Evolution;
    end
    %display(['... parfor run time =',num2str(toc)]);
        
    % Check if derived forcing is to be handled
    if any(cellfun(@(x) ~isempty(x), stochDerivedForcingData))
        useDerivedForcing = true;
    end

    % Put cx and cf back into the population;
    for igs = 1: ngs;
        x(ind{igs},:)=cx{igs};
        xf(ind{igs})=cf{igs};
    end

    % Record the igs number for each parameter. 
    for igs = 1: ngs;
        xigs(ind{igs})=igs;
    end
    
    % Sum the function calls per complex and add to icall
    icall = icall + sum(cicall);            

    % Sort the complexes, and record the best and worst points;
    [xf,idx] = sort(xf); 
    x=x(idx,:);
    bestx=x(1,:); 
    bestf=xf(1);
    worstx=x(npt,:); 
    worstf=xf(npt); 

    % Sort xigs numbers using xf order
    xigs=xigs(idx);
    
    % Computes the normalized geometric range of the parameters
    gnrng=exp(mean(log((max(x)-min(x))./bound)));

    % Update the objective function IF derived forcing is being used. 
    %-----------------
    if useDerivedForcing                
        % Importantly, the best solution from each complex may not be the
        % actual best (or may further decline) because it may be been
        % derived using a stochastic forcing time-series from ealier within
        % the evolutionary loop, rather than the stocastic forcing from the
        % end of the loop. Therefore, the best ngs*2 points agre re-derived
        % below (note, only ngs*2 are derived rather than all simply to
        % reduce the computational load).
        model = varargin{1};
        stochDerivedForcingData_sliced = stochDerivedForcingData(xigs);
        parfor i=1:(ngs*2)
            % Assign derived forcing using xigs
            updateStochForcingData(model, stochDerivedForcingData_sliced{i});
            xf(i) = feval(funcHandle, x(i,:)', varargin{:});
        end
        clear stochDerivedForcingData_sliced;
        icall = icall + npt;
        
        % Re-sort the complexes, and re-record the best and worst points;
        [xf,idx] = sort(xf);
        x=x(idx,:);
        bestx=x(1,:);
        bestf=xf(1);
        worstx=x(npt,:);
        worstf=xf(npt);

        % Re-sort xigs numbers using xf order
        xigs=xigs(idx);

        % Add the best ever solution to the model, or else if this loop produced the best 
        % ever solution, then update the best ever data.
        if bestf < bestf_ever %|| abs(bestf-bestf_ever)<=pcento
            
            % Set the best derived forcing from this evolution to the model.
            updateStochForcingData(varargin{1}, stochDerivedForcingData{xigs(1)});                
                        
            bestf_ever = bestf;
            bestx_ever = bestx;
            stochDerivedForcingData_best = stochDerivedForcingData{xigs(1)};                                             
%         else               
%             
%             % Insert the best ever forcing series into a random complex
%             % (except the best complex)
%             ind_rand_ngs = xigs(1);
%             while ind_rand_ngs == xigs(1)
%                 ind_rand_ngs = randi(ngs);
%             end
%             stochDerivedForcingData{ind_rand_ngs}  = stochDerivedForcingData_best;
%             
%             % Build an index to only the parameter sets within complex 'ind_rand'.
%             ind_rand_ngs = find(xigs==ind_rand_ngs);
%             ind_rand_ngs = sort(ind_rand_ngs);
%             
%             % Set the derived forcing from the best ever evolution to the model.
%             updateStochForcingData(varargin{1},stochDerivedForcingData_best);
%             
%             % Recalculate the xf for ONLY complex 'ind_rand'.
%             x_tmp = x(ind_rand_ngs,:);
%             xf_tmp = inf(1,length(ind_rand_ngs));
%             parfor i=1:length(ind_rand_ngs)
%                 xf_tmp(i) = feval(funcHandle, x_tmp(i,:)', varargin{:});
%             end
%             xf(ind_rand_ngs) = xf_tmp;
%             icall = icall + length(ind_rand_ngs);
%             
%             
%             % Again, re-sort the complexes, and re-record the best and worst points;
%             [xf,idx] = sort(xf);
%             x=x(idx,:);
%             bestx=x(1,:);
%             bestf=xf(1);
%             worstx=x(npt,:);
%             worstf=xf(npt);
%             
%             % Again, re-sort xigs numbers using xf order
%             xigs=xigs(idx);
%             
%             % Check if there is a new bestf.
%             if bestf < bestf_ever
%                 bestf_ever = bestf;
%                 bestx_ever = bestx;
%             end
        end
    else 
        if bestf < bestf_ever
            bestf_ever = bestf;
            bestx_ever = bestx;
        end
    end       
%-----------------


    criter_change = inf;
    criter=[criter;bestf];        
    isbestf_ever_inkstop = false;
    if (nloop >= kstop)
        criter_change=abs(criter(nloop)-criter(nloop-kstop+1))*100;
        criter_change=criter_change/mean(abs(criter(nloop-kstop+1:nloop)));
        
        %Check if bestf_ever is within the last kstop iterations.
        if any(criter(nloop-kstop+1:nloop)==bestf_ever)
          isbestf_ever_inkstop = true;
        end
    end
    
    disp(['LOOP       : ' num2str(nloop) '  - Trial - ' num2str(icall)]);
    if useDerivedForcing   
        disp(['BESTF loop : ' num2str(bestf,8)]);
        disp(['BESTF ever : ' num2str(bestf_ever,8)]);
    else
        disp(['BESTF      : ' num2str(bestf,8)]);
    end
    disp(['BESTX      : ' num2str(bestx)]);
    disp(['WORSTF     : ' num2str(worstf,8)]);
    disp(['WORSTX     : ' num2str(worstx)]);
    disp(['F convergence val.: ',num2str(criter_change,8)]);
    disp(['X convergence val.: ',num2str(gnrng,8)]);
    disp(' ');    
    
    % Check for convergency;
    exitCalib = false;
    if icall >= maxn;
        disp('*** OPTIMIZATION SEARCH TERMINATED BECAUSE THE LIMIT');
        disp(['ON THE MAXIMUM NUMBER OF TRIALS ' num2str(maxn) ' HAS BEEN EXCEEDED!']);        
    end;
    
    % If stochastic derived forcing is used, then assess if the method
    % should be refined (ie for pumpingRate_SAestimation() the
    % time-step reduced). This feature was added to allow the
    % downscaling to operate an increasingly fine temporal scales. 
    if useDerivedForcing && ((criter_change < pcento && isbestf_ever_inkstop) || gnrng < peps)
        refineStochForcingMethod = true;
        finishedStochForcing = updateStochForcingData(varargin{1},stochDerivedForcingData_best, refineStochForcingMethod);
        
        % If the stochastic forcing has been refined, then repeat the
        % calibration using the refined apprach eg a finer downscaling
        % timestep. Considering that the parameter sets are probably very
        % clustered, then if the stochastic forcing has not finished re-run
        % but with randomised parameters AND the best solution yet.
        if ~finishedStochForcing 
            disp('');
            disp('NOTE: The derived stochastic forcing is being refined. The calibration is being re-run.');
            % Initialization of the populaton and calculate their objective
            % function value AND add the best parameter set so far.
            %bestf_ever = inf;
            [x,xf, icall] = initialisePopulation(funcHandle, funcHangle_validParams, bestx_ever,bl_plausible, bu_plausible, false, npt, nopt, icall, varargin{:});            

            % Check if the population degeneration occured
            [x, xf, icall]=DimRest(funcHandle, funcHangle_validParams, x,xf,bl_phys,bu_phys,icall, varargin{:});
            
            % Initialise convergence measures.
            criter_change =  inf;
            gnrng = inf;
            criter = criter(end);
            nloop=1;
            %doReEval_DerivedForcing=false;
        else
            disp('NOTE: The derived stochastic forcing has reached the user set resolution.');
        end
    end    
        

    if criter_change < pcento && isbestf_ever_inkstop
        disp(['THE BEST POINT HAS IMPROVED IN LAST ' num2str(kstop) ' LOOPS BY ', ...
            'LESS THAN THE THRESHOLD ' num2str(pcento) '%']);
        disp('CONVERGENCY HAS ACHIEVED BASED ON OBJECTIVE FUNCTION CRITERIA!!!')
    end;
    
    if gnrng < peps;
        disp('THE POPULATION HAS CONVERGED TO A PRESPECIFIED SMALL PARAMETER SPACE');
    end;
    
    % Update the diary file
    if ~isempty(calibGUI_interface_obj)
        updatetextboxFromDiary(calibGUI_interface_obj);
        [doQuit, exitFlagQuit, exitStatusQuit] = getCalibrationQuitState(calibGUI_interface_obj);
        if doQuit
            exitFlag = exitFlagQuit;
            exitStatus = exitStatusQuit;
            return;
        end
    end    
    
    % End of the Outer Loops
end;

% Apply best model settings
model = varargin{1};
if useDerivedForcing                
    updateStochForcingData(model, stochDerivedForcingData_best);
end
bestf = feval(funcHandle, bestx_ever', varargin{:});

disp(['SEARCH WAS STOPPED AT TRIAL NUMBER: ' num2str(icall)]);
disp(['NORMALIZED GEOMETRIC RANGE = ' num2str(gnrng)]);
disp(['THE BEST POINT HAS IMPROVED IN LAST ' num2str(kstop) ' LOOPS BY ', ...
    num2str(criter_change) '%']);

% Update exist status output. Tim Peterson 2016
if icall>=maxn 
    exitFlag=1;
    exitStatus = 'Insufficient maximum number of model evaluations for convergence.';
elseif gnrng<peps && criter_change>pcento;
    exitFlag=1;
    exitStatus = ['Only parameter convergence (obj func. convergence = ',num2str(criter_change),' & threshold = ',num2str(pcento),') achieved in ', num2str(icall),' function evaluations.'];
elseif gnrng>peps && criter_change<pcento;
    exitFlag=1;
    exitStatus = ['Only objective function convergence achieved (param. convergence = ',num2str(gnrng),' & threshold = ',num2str(peps),') in ', num2str(icall),' function evaluations.'];
elseif gnrng<peps && criter_change<pcento;
    exitFlag=2;
    exitStatus = ['Parameter and objective function convergence achieved in ', num2str(icall),' function evaluations.'];
end

% Update the diary file
if ~isempty(calibGUI_interface_obj)
    updatetextboxFromDiary(calibGUI_interface_obj);
    [doQuit, exitFlagQuit, exitStatusQuit] = getCalibrationQuitState(calibGUI_interface_obj);
    if doQuit
        exitFlag = exitFlagQuit;
        exitStatus = exitStatusQuit;
        return;
    end    
end

end

function [cx, cf, icall, forcingData] = doComplexEvolution(funcHandle, funcHangle_validParams, ind, x, xf, bl_plausible, bu_plausible, bl, bu, nspl, nps, npg, useDerivedForcing, varargin)

        % initialse count of local function calls
        icall = 0;
                
        % Partition the population into complexes (sub-populations);
        cx=x(ind,:);
        cf=xf(ind);                 
        
        % Sort population
        [cf,idd]=sort(cf);
        cx=cx(idd,:);
                
        % Check if the population degeneration occured
        [cx, cf, icall]=DimRest(funcHandle, funcHangle_validParams, cx,cf,bl,bu,icall, varargin{:});

        % Get initial derived forcing.        
        if useDerivedForcing
            forcingData_tmp = getStochForcingData(varargin{1});    
            forcingData = forcingData_tmp;
        else
            forcingData={};
        end
                        
        % Evolve sub-population igs for nspl steps:
        for loop=1:nspl
            % Select simplex by sampling the complex according to a linear
            % probability distribution            
            lcs(1) = 1;
            for k3=2:nps
                for iter=1:1e9
                    lpos = 1 + floor(npg+0.5-sqrt((npg+0.5)^2 - npg*(npg+1)*rand));
                    idx=find(lcs(1:k3-1)==lpos); 
                    if isempty(idx)&&lpos<npg+1 
                        break; 
                    end 
                end
                lcs(k3) = lpos;
            end
            lcs=sort(lcs);

            % Construct the simplex:
            s=cx(lcs,:); 
            sf = cf(lcs);

            %[s,sf,icall, forcingData]=MCCE(funcHandle, funcHangle_validParams, s,sf,bl,bu,icall, useDerivedForcing,  forcingData, varargin{:});
            [s,sf,icall]=MCCE(funcHandle, funcHangle_validParams, s,sf,bl,bu,icall, varargin{:});
  
            % Replace the simplex into the complex;
            cx(lcs,:) = s;
            cf(lcs) = sf;

            % Sort the complex;
            [cf,idx] = sort(cf); cx=cx(idx,:);
            clear lcs

            % End of Inner Loop for Competitive Evolution of Simplexes
        end
        
        % Conduct Gaussian Resampling 
        %[cx, cf, icall]=GauSamp(funcHandle, funcHangle_validParams, cx,cf,bl_plausible, bu_plausible,icall,  forcingData, varargin{:});
        
%         % Get final derived forcing
%         if useDerivedForcing
%             forcingData= getStochForcingData(varargin{1});
%             % Re-valuate complex using the final stochastic forcing.            
%             for loop=1:size(cx,1)
%                 updateStochForcingData(varargin{1}, forcingData);
%                 cf(loop)= feval(funcHandle,cx(loop,:)', varargin{:});                                
%                 icall = icall + 1;
%             end            
%         end
        
end

function [x,xf, icall] = initialisePopulation(funcHandle, funcHangle_validParams, x0,bl_plausible, bu_plausible, iniflg, npt, nopt, icall, varargin)

    bound = bu_plausible - bl_plausible;
    x=zeros(npt,nopt);
    parfor i=1:npt
        while 1
            x(i,:)=bl_plausible+rand(1,nopt).*bound;

            % Check if the parameters are valid
            isValid = feval(funcHangle_validParams, x(i,:)', varargin{:});

            if all(isValid)
                break;
            end
        end            
    end

    if iniflg
        x(1,:)=x0; 
    end
    
    xf=10000*ones(1,npt);
    stochDerivedForcingData = getStochForcingData(varargin{1}); 
    
    %tic;
    parfor i=1:npt
        xf(i) = feval(funcHandle, x(i,:)', varargin{:});
        icall = icall + 1;
    end
    %display(['... parfor run time =',num2str(toc)]);

    % Sort the population in order of increasing function values;
    [xf,idx]=sort(xf);
    x=x(idx,:);

    % Reset the input derived forcing
    if any(~isempty(stochDerivedForcingData))
        updateStochForcingData(varargin{1}, stochDerivedForcingData);
    end       
    
    
end
