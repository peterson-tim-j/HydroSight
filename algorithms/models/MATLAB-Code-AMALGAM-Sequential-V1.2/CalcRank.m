function [Ranking,CrowdDist] = CalcRank(ObjVals,Bounds,Cg);
% Ranking based on Pareto rank and constraint violation

% First find the individuals with no constraint violation
[idx] = find(Cg == 0); Ntot = length(idx);
if Ntot > 0,
    % Rank these individuals
    [Ranking(idx,:),CrowdDist(idx,:)] = ParetoRanking(ObjVals(idx,:),Bounds,Cg(idx,1),0);
end;

if Ntot > 0,
    % Now derive maximum Rank and NmbOfFront of this one
    maxRank = max(Ranking); 
else
    maxRank = 0; maxFront = 0;
end;

% Now find the individuals with constraint violation
[idx] = find(Cg < 0); Ntot = length(idx);

% Now do the ranking of these individuals
if Ntot > 0,
    [Rank,CrowdDist(idx,:)] = ParetoRanking(ObjVals(idx,:),Bounds,Cg(idx,1),1);
    % Now update the Rank and the NmbOfFront
    Ranking(idx,:) = Rank + maxRank; 
end;