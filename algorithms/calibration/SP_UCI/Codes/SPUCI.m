function [bestx,bestf,icall, exitFlag, exitStatus] = SPUCI(funcHandle, funcHangle_validParams, x0,bl_plausible, bu_plausible, bl_phys,bu_phys,maxn,kstop,pcento,peps,ngs,iseed,iniflg, varargin) 
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

% Initialization of agorithmic 
nopt=length(x0); %dimentions of the problem
npg=2*nopt+1;%  npg = number of members is a complex
nps=nopt+1;%  nps = number of members in a simplex
nspl=nps;%  nspl = number of evolution steps for each complex before shuffling
npt=npg*ngs;%npt = the total number of members (the population size)

bound = bu_plausible - bl_plausible;% boundary of the feasible space.

rand('seed',iseed);
randn('seed',iseed);

% Initialise exist outputs. Tim Peterson 2016
exitFlag = 0;
exitStatus = 'Calibration scheme did not start.';

% Initialization of the populaton
x=zeros(npt,nopt);
for i=1:npt;
    while 1
        x(i,:)=bl_plausible+rand(1,nopt).*bound;
       
        % Check if the parameters are valid
        isValid = feval(funcHangle_validParams, x(i,:)', varargin{:});
        
        if all(isValid)
            break;
        end
    end            
end;

if iniflg==1; x(1,:)=x0; end;

nloop=0;
icall=0;
xf=10000*ones(1,npt);
parfor i=1:npt;
    xf(i) = feval(funcHandle, x(i,:)', varargin{:});
    icall = icall + 1;
end;

% Sort the population in order of increasing function values;
[xf,idx]=sort(xf);
x=x(idx,:);

% Check if the population degeneration occured
[x, xf, icall]=DimRest(funcHandle, funcHangle_validParams, x,xf,bl_phys,bu_phys,icall, varargin{:});

% Conduct Gaussian Resampling 
[x, xf, icall]=GauSamp(funcHandle,funcHangle_validParams, x,xf,bl_plausible, bu_plausible,icall, varargin{:});

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

% Update exist status output. Tim Peterson 2016
exitStatus = 'Calibration scheme did started.';

% Begin evolution loops:
criter=[];
criter_change=1e+5;

while icall<maxn && gnrng>peps && criter_change>pcento;
    nloop=nloop+1;
    %%%%%%%%%%%%%%%%%%%%%%%%
    idexx=randperm(npt);
    %%%%%%%%%%%%%%%%%%%%%%%%
    
    % Create indexes for each complex
    for igs = 1: ngs;
        ind{igs} = idexx(npg*(igs-1)+1:npg*igs);
    end
    
    % Initialise cell array for cx and cf
    cx = cell(ngs,1);
    cf = cell(ngs,1);
    cicall = zeros(ngs,1);
    
    % Loop on complexes (sub-populations);
    parfor igs = 1: ngs;

        % THis is the major computionation load. It was shifted into a
        % stand alone function by Tim Peterson to allow parrellisation.
        [cx{igs}, cf{igs}, cicall(igs)] = doComplexEvolution(funcHandle, funcHangle_validParams, ind{igs}, x, xf, bl_plausible, bu_plausible, bl_phys,bu_phys, nspl, nps, npg, varargin{:});
        
    % End of Loop on Complex Evolution;
    end;
    
    % Put cx and cf back into the population;
    for igs = 1: ngs;
        x(ind{igs},:)=cx{igs};
        xf(ind{igs})=cf{igs};
    end
    
    % Sum the function calls per complex and add to icall
    icall = icall + sum(cicall);
    
    % Shuffle the complexes, and record the best and worst points;
    [xf,idx] = sort(xf); x=x(idx,:);
    bestx=x(1,:); bestf=xf(1);
    worstx=x(npt,:); worstf=xf(npt); 
 
    % Computes the normalized geometric range of the parameters
    gnrng=exp(mean(log((max(x)-min(x))./bound)));

    disp(['Evolution Loop: ' num2str(nloop) '  - Trial - ' num2str(icall)]);
    disp(['BESTF  : ' num2str(bestf)]);
    disp(['BESTX  : ' num2str(bestx)]);
    disp(['WORSTF : ' num2str(worstf)]);
    disp(['WORSTX : ' num2str(worstx)]);
    disp(' ');

    % Check for convergency;
    if icall >= maxn;
        disp('*** OPTIMIZATION SEARCH TERMINATED BECAUSE THE LIMIT');
        disp(['ON THE MAXIMUM NUMBER OF TRIALS ' num2str(maxn) ' HAS BEEN EXCEEDED!']);
    end;

    if gnrng < peps;
        disp('THE POPULATION HAS CONVERGED TO A PRESPECIFIED SMALL PARAMETER SPACE');
    end;

    criter=[criter;bestf]; %#ok<AGROW>
    if (nloop >= kstop);
        criter_change=abs(criter(nloop)-criter(nloop-kstop+1))*100;
        criter_change=criter_change/mean(abs(criter(nloop-kstop+1:nloop)));
        if criter_change < pcento;
            disp(['THE BEST POINT HAS IMPROVED IN LAST ' num2str(kstop) ' LOOPS BY ', ...
                'LESS THAN THE THRESHOLD ' num2str(pcento) '%']);
            disp('CONVERGENCY HAS ACHIEVED BASED ON OBJECTIVE FUNCTION CRITERIA!!!')
        end;
    end;

    % End of the Outer Loops
end;

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


end

function [cx, cf, icall] = doComplexEvolution(funcHandle, funcHangle_validParams, ind, x, xf, bl_plausible, bu_plausible, bl, bu, nspl, nps, npg, varargin)

        % initialse count of local function calls
        icall = 0;
        
        % Partition the population into complexes (sub-populations);
        cx=x(ind,:);
        cf=xf(ind);
        [cf,idd]=sort(cf);
        cx=cx(idd,:);
  
        % Check if the population degeneration occured
        [cx, cf, icall]=DimRest(funcHandle, funcHangle_validParams, cx,cf,bl,bu,icall, varargin{:});
        
        % Evolve sub-population igs for nspl steps:
        for loop=1:nspl;
            % Select simplex by sampling the complex according to a linear
            % probability distribution            
            lcs(1) = 1;
            for k3=2:nps;
                for iter=1:1e9;
                    lpos = 1 + floor(npg+0.5-sqrt((npg+0.5)^2 - npg*(npg+1)*rand));
                    idx=find(lcs(1:k3-1)==lpos); if isempty(idx)&&lpos<npg+1; break; end; %#ok<EFIND>
                end;
                lcs(k3) = lpos;
            end;
            lcs=sort(lcs);

            % Construct the simplex:
            s=cx(lcs,:); sf = cf(lcs);

            [s,sf,icall]=MCCE(funcHandle, funcHangle_validParams, s,sf,bl,bu,icall, varargin{:});

            % Replace the simplex into the complex;
            cx(lcs,:) = s;
            cf(lcs) = sf;

            % Sort the complex;
            [cf,idx] = sort(cf); cx=cx(idx,:);
            clear lcs

            % End of Inner Loop for Competitive Evolution of Simplexes
        end;

        % Conduct Gaussian Resampling 
        [cx, cf, icall]=GauSamp(funcHandle, funcHangle_validParams, cx,cf,bl_plausible, bu_plausible,icall, varargin{:});
end