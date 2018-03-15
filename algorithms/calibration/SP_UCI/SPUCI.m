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
%     = the optimized parameter array at the end;
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
% if useDerivedForcing 
%     nspl=2*nps;%  nspl = number of evolution steps for each complex before shuffling
% else
%     nspl=nps;%  nspl = number of evolution steps for each complex before shuffling
% end
npt=npg*ngs;%npt = the total number of members (the population size)

bound = bu_plausible - bl_plausible;% boundary of the feasible space.

rand('seed',iseed);
randn('seed',iseed);

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

% Get the derived forcing data and then conduct Gaussian Resampling 
%[stochDerivedForcingData] = getStochForcingData(varargin{1});
%[x, xf, icall]=GauSamp(funcHandle,funcHangle_validParams, x,xf,bl_plausible, bu_plausible,icall, stochDerivedForcingData_prior, varargin{:});

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
while icall<maxn && gnrng>peps && criter_change>pcento;
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
            
            % Find the index to the lowest objective function prior solution.
            % This is achieved by finding the index (within the points for
            % complex igs only) to the lowest objective function for the
            % initial parameter sets to the evolution of the complex.
            % value within this complex. 
            %ind_bestf = find(xf(ind{igs}) == min(xf(ind{igs})),1,'first');
            %ind_derivedForcing = xigs(ind{igs});
            
            % The index is then used to find the appropriate derived
            % forcing data for each complex. The required forcing is then
            % copies into each of the new complexes.
            stochDerivedForcingData_new{igs} = stochDerivedForcingData{xigs(igs)};
        end
        stochDerivedForcingData = stochDerivedForcingData_new;
        clear stochDerivedForcingData_new
        
    end
        
    
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
        
        % THis is the major computionation load. It was shifted into a
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


%NOTE: The code below is required ONLY when the stochastic updating is
%undertaken within MCCE.m.
%-----------------
    % Importantly, with the derived forcing changing then objective
    % function value for each parameter set is most likely to change. 
    % Therefore, all parameter sets are re-vealuatted.    
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
    
    % Shuffle the complexes, and record the best and worst points;
    [xf,idx] = sort(xf); 
    x=x(idx,:);
    bestx=x(1,:); 
    bestf=xf(1);
    worstx=x(npt,:); 
    worstf=xf(npt); 

    % Sort xigs numbers using xf order
    xigs=xigs(idx);
    
    disp(['Evolution Loop: ' num2str(nloop) '  - Trial - ' num2str(icall)]);
    disp(['BESTF loop : ' num2str(bestf)]);
    disp(['BESTF ever : ' num2str(bestf_ever)]);
    disp(['BESTX      : ' num2str(bestx)]);
    disp(['WORSTF     : ' num2str(worstf)]);
    disp(['WORSTX     : ' num2str(worstx)]);
    disp(' ');
    
    
    % Set the focring to the model object in case it is the last evolution
    % loop.
    if useDerivedForcing                
        % Add the best ever solution to the model, or else if this loop produced the best 
        % ever solution, then update the best ever data.
        if bestf < bestf_ever %|| abs(bestf-bestf_ever)<=pcento
            
            % Set the best derived forcing from this evolution to the model.
            updateStochForcingData(varargin{1}, stochDerivedForcingData{xigs(1)});                
                        
            %criter=[criter;bestf];  
            bestf_ever = bestf;
            bestx_ever = bestx;
            stochDerivedForcingData_best = stochDerivedForcingData{xigs(1)};                                             
        else               
            
            % Set the derived forcing from the best ever evolution to the model.
            updateStochForcingData(varargin{1},stochDerivedForcingData_best);                
            
           % Use bestf from loop in convergence criteria. Not the best every. 
           %criter=[criter;bestf];   
            
           % Insert to the first sample of last complex 
           stochDerivedForcingData{xigs(ngs)}  = stochDerivedForcingData_best;
           x(ngs,:) = bestx_ever;
           xf(ngs) = bestf_ever;
           bestf = bestf_ever;
           bestx = bestx_ever;                      
           
        end
    else
        if bestf < bestf_ever 
            bestf_ever = bestf;
            bestx_ever = bestx;
        end
    end
    
    
    % Computes the normalized geometric range of the parameters
    gnrng=exp(mean(log((max(x)-min(x))./bound)));

    % Check for convergency;
    exitCalib = false;
    if icall >= maxn;
        disp('*** OPTIMIZATION SEARCH TERMINATED BECAUSE THE LIMIT');
        disp(['ON THE MAXIMUM NUMBER OF TRIALS ' num2str(maxn) ' HAS BEEN EXCEEDED!']);        
    end;
           
    criter_change = inf;
    criter=[criter;bestf];      
    isbestf_ever_inkstop = false;
    if (nloop >= kstop);
        criter_change=abs(criter(nloop)-criter(nloop-kstop+1))*100;
        criter_change=criter_change/mean(abs(criter(nloop-kstop+1:nloop)));
        
        % Check if bestf_ever is within the last kstop iterations.
        if any(criter(nloop-kstop+1:nloop)==bestf_ever)
            isbestf_ever_inkstop = true;
        end
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
            % Initialization of the populaton and calculate their objective function value.
            % TO DO: SET BEST STOCH FORCING
            [x,xf, icall] = initialisePopulation(funcHandle, funcHangle_validParams, bestx_ever,bl_plausible, bu_plausible, true, npt, nopt, icall, varargin{:});

            % TO DO: RESET BEST STOCH FORCING
            
            % Check if the population degeneration occured
            [x, xf, icall]=DimRest(funcHandle, funcHangle_validParams, x,xf,bl_phys,bu_phys,icall, varargin{:});
            
            % Initialise convergence measures.
            criter_change =  inf;
            gnrng = inf;
            criter = criter(end);
            nloop=1;
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
                
        % Get the initial best solition
        cfbest=min(cf);
        
%         % Try to update each stochastic forcing using the best parameter set
%         % atleast 'minTrials'.
%         if useDerivedForcing            
%             % Re-evaluate the whole population using the stochastic
%             % forcing. Note the input stochastic forcing was that which
%             % produced the best solution from the complex. The other points
%             % in the complex are likely to have been derived using 
%             % stochastic forcing data sets form other complexes.
%             for loop=1:size(cx,1)
%                cf(loop)= feval(funcHandle,cx(loop,:)', varargin{:});                                
%             end
%             
%             % Resort, because the order may have changed.
%             [cf,idd]=sort(cf);
%             cx=cx(idd,:);                        
%         end        
        
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

            % TO DO: REMOVE ALL HANDLING OF STOCH FORCING (I THINK)
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
        
        % Get final derived forcing
        if useDerivedForcing
            forcingData= getStochForcingData(varargin{1});
            % Re-valuate complex using the final stochastic forcing.            
            for loop=1:size(cx,1)
                updateStochForcingData(varargin{1}, forcingData);
                cf(loop)= feval(funcHandle,cx(loop,:)', varargin{:});                                
                icall = icall + 1;
            end            
        end
        
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

    if iniflg==1
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