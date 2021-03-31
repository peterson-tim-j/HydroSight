function [Snew,Sfnew,icall]=DimRest(funcHandle, funcHangle_validParams, S,Sf,bl,bu,icall, varargin)
%subroutine for testing if there is any lost dimensions. If the number of
%lost dimension is greater than a certain threshold (one-tenth of the original
%dimenisions in this codes, but it can be changed by users' preferences).

[N,Dim]=size(S); %get size and full dimension of population.
Snew=S;
Sfnew=Sf;
Nmean=mean(S);
Nstd=std(S);
a=S';
for i=1:Dim
    a(i,:)=(a(i,:)-Nmean(i))/Nstd(i);
end
r=max(max(a)-min(a));

%Peform Principal Component Analysis
c=(a*a')/N;
[v,d]=eig(c);
d=diag(d);
vtemp=v;
dtemp=d;
for i=1:Dim
    v(:,i)=vtemp(:,Dim-i+1);
    d(i)=dtemp(Dim-i+1);
end
d=d./sum(d);

%Find the number of lost dimensions.  A lost diemnsion is defined as a
%dimension that has a relative variances less than one percent of the
%total variance divided by the dimensionality.
lastdim=find(d > (0.01/Dim),1,'last');
nlost=Dim-lastdim; 

% Get the initial derived forcing
stochDerivedForcingData = getStochForcingData(varargin{1});


%If the number of the lost dimensions is greater than one-tenth of the total
%dimensionality, restore the lost dimensions.
if nlost > floor(Dim/10)+1 
    for i=lastdim+1:Dim
        happen=0;
        
        % Generate new sample and check the parameter is valid
        nmax = 250;
        imax=0;
        while imax<nmax
            stemp=((randn+2)*r*v(:,i))';
            for j=1:Dim
                stemp(j)=stemp(j)*Nstd(j)+Nmean(j);
            end

            stemp(stemp>bu)=2*bu(stemp>bu)-stemp(stemp>bu);
            stemp(stemp<bl)=2*bl(stemp<bl)-stemp(stemp<bl);
            stemp(stemp>bu)=bu(stemp>bu);
            stemp(stemp<bl)=bl(stemp<bl);            
            
            % Check if the parameters are valid
            isValid = feval(funcHangle_validParams, stemp', varargin{:});

            if all(isValid)
                break;
            end
            imax=imax+1;
        end 
                    
        % No valid parameter set found to try next for-loop iteration.
        if ~all(isValid)
            continue;
        end
        
        ftemp=feval(funcHandle,stemp', varargin{:});
        icall=icall+1;
        
        if ftemp > max(Sfnew)
            % Re-generate sample
            imax=0;
            stemp_initial = stemp;
            while imax<nmax
                stemp=((randn-2)*r*v(:,i))';
                for j=1:Dim
                    stemp(j)=stemp(j)*Nstd(j)+Nmean(j);
                end

                stemp(stemp>bu)=2*bu(stemp>bu)-stemp(stemp>bu);
                stemp(stemp<bl)=2*bl(stemp<bl)-stemp(stemp<bl);
                stemp(stemp>bu)=bu(stemp>bu);
                stemp(stemp<bl)=bl(stemp<bl);           

                % Check if the parameters are valid
                isValid = feval(funcHangle_validParams, stemp', varargin{:});

                if all(isValid)
                    break;
                end
                imax=imax+1;
            end             
            
            if ~all(isValid)
                stemp = stemp_initial;
            else
                % Reset the input derived forcing
                if any(~isempty(stochDerivedForcingData))
                    updateStochForcingData(varargin{1}, stochDerivedForcingData);
                end       
                
                ftemp=feval(funcHandle,stemp', varargin{:});
                icall=icall+1;
            end
        end
        if ftemp < max(Sfnew)
            happen=1;
            Snew(N,:)=stemp;
            Sfnew(N)=ftemp;
        end
        if happen==1
            [Sfnew,idx]=sort(Sfnew);
            Snew=Snew(idx,:);
        end
    end
end

return




