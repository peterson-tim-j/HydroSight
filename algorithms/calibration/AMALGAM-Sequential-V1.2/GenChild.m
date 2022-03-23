function [NewGen,V,Itot] = GenChild(ParGen,ObjVals,Ranking,CrowdDist,Cviols,V,pBest,nBest,AMALGAMPar,ParRange,Extra);
% Test function generates new offspring

% First initialize ChildGen and other variables
NewGen = []; Itot = zeros(length(ParGen),1);
% Define Cons 
Cons = [ParRange.minn' ParRange.maxn']; 
% Define size of ParGen
[nmbOfIndivs nmbOfVars] = size(ParGen);

% ------------------- NSGA-II GENETIC ALGORITHM ----------------------
[NrGenetic] = find(strcmp(Extra.Alg,'GA')==1); Nc = length(NrGenetic);
for qq = 1:Nc,
    % Define number first
    NrPoints = AMALGAMPar.m(NrGenetic(qq));
    % Define algorithmic settings
    pC = 0.9; pM = 1/AMALGAMPar.n; etaC = 20; etaM = 20;    
    % Create children using Genetic rules
    [ChildGen] = NSGA_ChildGen(ParGen,ObjVals,Cviols,CrowdDist,ParRange,AMALGAMPar,pC,etaC,pM,etaM);
    % Now randomly select NrPoints from AMALGAMPar.N
    [ii] = randperm(AMALGAMPar.N); ii = ii(1:NrPoints)';
    % Now add ChildGen
    NewGen = [NewGen ; ChildGen(ii,1:AMALGAMPar.n)]; Itot = [Itot;NrGenetic(qq)*ones(NrPoints,1)];
end;

% --------------------------------------------------------------------

% ---------------- METROPOLIS HASTINGS ALGORITHM ---------------------
[NrMetro] = find(strcmp(Extra.Alg,'AMS')==1); Nc = length(NrMetro);
for qq = 1:Nc,
    % Define number first
    NrPoints = AMALGAMPar.m(NrMetro(qq));
    % Create children using Metropolis rules
    [ChildGen] = Metro_ChildGen(ParGen,Ranking,AMALGAMPar,Extra);
    % Now randomly select NrPoints from AMALGAMPar.N
    [ii] = randperm(AMALGAMPar.N); ii = ii(1:NrPoints)';
    % Now add ChildGen
    NewGen = [NewGen ; ChildGen(ii,1:AMALGAMPar.n)]; Itot = [Itot;NrMetro(qq)*ones(NrPoints,1)];
end;
% --------------------------------------------------------------------

% ----------------- PARTICLE SWARM OPTIMIZATION ----------------------
[NrSwarm] = find(strcmp(Extra.Alg,'PSO')==1); Nc = length(NrSwarm);
for qq = 1:Nc,
    % Define number first
    NrPoints = AMALGAMPar.m(NrSwarm(qq));
    % Create children using Particle Swam Optimization
    [ChildGen,V(:,:,NrSwarm(qq))] = Swarm_ChildGen(ParGen,V(:,:,NrSwarm(qq)),pBest,nBest,AMALGAMPar,Extra);
    % Now randomly select NrPoints from AMALGAMPar.N
    [ii] = randperm(AMALGAMPar.N); ii = ii(1:NrPoints)';
    % Now add ChildGen
    NewGen = [NewGen ; ChildGen(ii,1:AMALGAMPar.n)]; Itot = [Itot;NrSwarm(qq)*ones(NrPoints,1)];
end;
% --------------------------------------------------------------------

% ------------------ DIFFERENTIAL EVOLUTION --------------------------
[NrRand] = find(strcmp(Extra.Alg,'DE')==1); Nc = length(NrRand);
for qq = 1:Nc,
    % Define number first
    NrPoints = AMALGAMPar.m(NrRand(qq));
    % Create children using Particle Swam Optimization
    [ChildGen] = DE_ChildGen(ParGen,Ranking,pBest,nBest,AMALGAMPar);
    % Now randomly select NrPoints from AMALGAMPar.N
    [ii] = randperm(AMALGAMPar.N); ii = ii(1:NrPoints)';
    % Now add ChildGen
    NewGen = [NewGen ; ChildGen(ii,1:AMALGAMPar.n)]; Itot = [Itot;NrRand(qq)*ones(NrPoints,1)];
end;
% --------------------------------------------------------------------