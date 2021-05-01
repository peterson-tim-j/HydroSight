function [ParGen,ObjVals,Ranking,CrowdDist,Iout,Cg] = CreateNewPop(ParGen,ChildGen,ObjVals,ChildObjVals,Itot,Cg,ChildCg,ParRange,Bounds);
% Function selects new population based on current offspring and parents

% Save ParGen in memory
oldParGen = ParGen; counter = 0; rk = 1;

% Determine the number of individuals in population
[nmbOfIndivs] = size(ParGen,1); 

% Append children to parents
Par_ChildGen = [ParGen;ChildGen]; ObjVals = [ObjVals;ChildObjVals]; Cg = [Cg;ChildCg];

% Rank children and parents together
[Ranking,CrowdDist] = CalcRank(ObjVals,Bounds,Cg);

% Now generate new population
for rk = 1:max(Ranking),
    % Check how many members in next front
    [ii] = length(find(Ranking == rk));
    % Now save this information
    N(rk) = ii;
end;

% Check whether population is full, otherwise select from first rank based on crowding distance
Ntot = cumsum(N);
if Ntot(1) >= nmbOfIndivs,
    ii = find(Ranking==1);
    [Cdist sortidx] = sortrows(-CrowdDist(ii)); 
    % Select from first rank based on crowding distance
    ii = ii(sortidx); ii = ii(1:nmbOfIndivs);
end;
if Ntot(1) < nmbOfIndivs,
    % Now select which ranks are within the size of the population
    idx = find(Ntot>nmbOfIndivs); rk = idx(1) - 1;
    if Ntot(rk) ~= nmbOfIndivs,
        % Fill population by selecting from next population
        ii = find(Ranking==rk+1);
        % How many points?
        T = nmbOfIndivs - Ntot(rk);
        % Now select based on Crowding Distance
        [Cdist sortidx] = sortrows(-CrowdDist(ii));
        %
        ii = ii(sortidx); ii = ii(1:T);
    else
        ii = [];
    end;
    % Now fill with all the other ranks
    ii = [ii;find(Ranking<=rk)]; 
end;

% Generate new population
ParGen = Par_ChildGen(ii,:); ObjVals = ObjVals(ii,:); Cg = Cg(ii,:);

% Select appropriate Rank and Distance Operator
Ranking = Ranking(ii,:); CrowdDist = CrowdDist(ii,:);

% Update Itot
Iout = Itot(ii,:);