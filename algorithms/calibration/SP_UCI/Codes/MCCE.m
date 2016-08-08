%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [S,Sf,icall]=MCCE(funcHandle,funcHangle_validParams,s,sf,bl,bu,icall, varargin)
% This is the subroutine implementing the simplex algorithm

% Definition of input/output variables
%  s/S = simplex members(vertices)in order of increasing function values
%  sf/Sf = objective functions at simplex vertices

nps = size(s,1);
n = nps;
alpha = 1.0; % reflection coefficient.
beta = 0.5;% contraction coefficient.

% Assign the best and worst points:
sb=s(1,:); fb=sf(1);
sN=s(n-1,:); fN=sf(n-1);
sw=s(n,:); fw=sf(n);

% Compute the centroid of the simplex excluding the worst point:
ce=mean(s(1:n-1,:));

% Attempt a reflection point
snew = ce + alpha*(ce-sw);

% If the reflection point is outside bound, reflect it back into the feasible
% space
snew(snew>bu)=2*bu(snew>bu)-snew(snew>bu) ;
snew(snew<bl)=2*bl(snew<bl)-snew(snew<bl);
snew(snew>bu)=bu(snew>bu);
snew(snew<bl)=bl(snew<bl);

% Check if the point is valid
isValid = feval(funcHangle_validParams,snew', varargin{:});
isValid = all(isValid);

if isValid
    fnew = feval(funcHandle,snew', varargin{:});
    icall = icall + 1;
else
    fnew = inf;
end

if fnew < fN;
    if fnew < fb
        snew1 = snew + alpha*(snew-ce);
        snew1(snew1>bu)=2*bu(snew1>bu)-snew1(snew1>bu) ;
        snew1(snew1<bl)=2*bl(snew1<bl)-snew(snew1<bl);
        snew1(snew1>bu)=bu(snew1>bu);
        snew1(snew1<bl)=bl(snew1<bl);

        % Check the new point is valid
        isValid = feval(funcHangle_validParams,snew1', varargin{:});
        isValid = all(isValid);        
        
        if isValid
            fnew1 = feval(funcHandle,snew1', varargin{:});
            icall = icall + 1;

            if fnew1 < fnew
                fnew=fnew1;
                snew=snew1;
            end
        end
    end
    
else % Contraction point
    
    if fnew < fw
        snew1 = ce + beta*(snew-ce);

        % Check the new point is valid
        isValid = feval(funcHangle_validParams,snew1', varargin{:});
        isValid = all(isValid);        
        
        if isValid                
            fnew1 = feval(funcHandle,snew1', varargin{:});
            icall = icall + 1;
            if fnew1 < fnew
                fnew=fnew1;
                snew=snew1;
            end
        end
        
    else        
        snew = sw + beta*(ce-sw);
        
        % Check if the point is valid
        isValid = feval(funcHangle_validParams,snew', varargin{:});
        isValid = all(isValid);        
        
        if isValid
            fnew = feval(funcHandle,snew', varargin{:});
            icall = icall + 1;
        end
        if ~isValid || fnew > fw
            while 1
                sig=cov(s);
                Dia=diag(sig);
                sig=diag((Dia+mean(Dia))*2);
                snew=mvnrnd(ce,sig,1);
                snew(snew>bu)=2*bu(snew>bu)-snew(snew>bu) ;
                snew(snew<bl)=2*bl(snew<bl)-snew(snew<bl);
                snew(snew>bu)=bu(snew>bu);
                snew(snew<bl)=bl(snew<bl);
                
                % Check if the point is valid
                isValid = feval(funcHangle_validParams,snew', varargin{:});
                if all(isValid)
                    break;
                end                
            end
            
            fnew = feval(funcHandle,snew', varargin{:});
            icall = icall + 1;
        end
    end
end;

S=s;
Sf=sf;
S(n,:)=snew;
Sf(n)=fnew;

return;


