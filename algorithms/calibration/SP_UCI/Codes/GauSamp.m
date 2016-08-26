function [Snew,Sfnew,icall]=GauSamp(funcHandle, funcHangle_validParams, S,Sf,bl,bu,icall, varargin)
%subroutine for restoring the population using multinormal distribution
        
    [N,D]=size(S);
    Norig = N;
    N = 2*N;
    Smean=mean(S);
    Ssig=cov(S);
    Srand=2*mvnrnd(zeros(1,D),Ssig,N)+repmat(Smean,N,1);

    % Move points that are outside bounds back to the feasible space.
    % Check the points are alsoe valid. If not resample.
    for i=1:N
        iResamples=0;
        while 1
                        
            % Resample only those parameteres that exceed a boounds. 
            t=Srand(i,:);
            R=rand(1,D);
            Diff=bu-bl;
            idxx=t>bu;
            t(idxx)=bl(idxx)+R(idxx).*Diff(idxx);
            idxx=t<bl;
            t(idxx)=bl(idxx)+R(idxx).*Diff(idxx);
            Srand(i,:)=t;
           
            % If the point is still invalid then resample 
            % the parameter that violates a bound (or is invalid) using
            % increasingly larger fraction of the sample range.
            isValid = feval(funcHangle_validParams, Srand(i,:)', varargin{:});          
            if any(~isValid)
                Stemp=2*mvnrnd(zeros(1,D),Ssig,1)+repmat(Smean,1,1);
                Srand(i,~isValid) = Stemp(~isValid);
            
                % Re-assess if the parameters are all valid
                isValid = feval(funcHangle_validParams, Srand(i,:)', varargin{:});
                
                if all(isValid)
                    break;
                end
            else
                break;
            end            
            
            iResamples = iResamples +1;
        end
    end
    
    
    
    Sfrand=zeros(1,N);
    parfor k=1:N
        Sfrand(k)= feval(funcHandle,Srand(k,:)', varargin{:});
        icall = icall + 1;
    end

    Stotal=[S; Srand];
    Sftotal=[Sf Sfrand];
    [Sftotal,idx]=sort(Sftotal); Stotal=Stotal(idx,:);
    Snew=Stotal(1:Norig,:);
    Sfnew=Sftotal(1:Norig);
return
