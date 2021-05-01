function [pBest,nBest] = SelBest(NmbOfFront,ParSet,AMALGAMPar,Extra);
% Selects Pbest and Nbest for the Particle Swarm Optimization

% First remove the solutions that violate constraints
Cg = ParSet(:,AMALGAMPar.n+1);
% and select the appropriate ones
[idx] = find(Cg==0); ParSet = ParSet(idx,:);

% Now compute pBest and nBest;
pBest = []; nBest = [];
% Determine the number of complexes that do particle swarm optimization
Complex = find(strcmp(Extra.Alg,'PSO')==1); Nc = length(Complex);
% Other approach -- first find minimum of individual objectives
minF = min(ParSet(:,AMALGAMPar.n+2:end)); minF = minF(ones(length(ParSet),1),:);
% Now determine Euclidean distance from these optimal solutions
[T] = sqrt(sum(((ParSet(:,AMALGAMPar.n+2:end)-minF).^2),[2]));
% Sort T and determine idx
[dummy,idx] = sort(T);
% Now sort ParSet
P = ParSet(idx,1:AMALGAMPar.n);

if Nc > 0,
    % Initialize pBest with values
    pBest = repmat(P(1,1:AMALGAMPar.n),AMALGAMPar.N,1);
    % Now initialize nBest with values
    nBest = P(1:AMALGAMPar.N,1:AMALGAMPar.n);  
end;