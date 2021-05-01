function [NmbOfFront, CrowdDist] = ParetoRanking(ObjVals,Bounds,Cg,flag);
% This function ranks the individuals according to:
% 1. Their degree of constraint violation,
% 2. The number of their Pareto-optimal front, 
% 3. The degree to which they are `crowded' by other individuals

% Do normal ranking based on objective function values
if flag == 0,
    % First compute size of individual arrays    
    [nmbOfIndivs nmbOfObjs] = size(ObjVals);
    % Pareto-optimal fronts
    Front = {[]};
    % number of Pareto-optimal front for each individual; 2nd highest priority sorting key
    NmbOfFront = zeros( nmbOfIndivs, 1);
    % set of individuals a particular individual dominates
    Dominated = cell( nmbOfIndivs, 1);
    % number of individuals by which a particular individual is dominated
    NmbOfDominating = zeros( nmbOfIndivs, 1);

    for p = 1:nmbOfIndivs,
        % First replicate current point
        Ptemp = ObjVals(p,1:nmbOfObjs); Pobj = Ptemp(ones(nmbOfIndivs,1),:);
        % Then find set of Dominated points
        [idx] = find((sum(Pobj <= ObjVals,[2]) == nmbOfObjs) & (sum(Pobj < ObjVals,[2]) > 0)); Nidx = length(idx);
        if Nidx > 0,
            Dominated{ p} = idx';
        end
        % Now find set of Nondominated points
        [idx] = find((sum(ObjVals <= Pobj,[2]) == nmbOfObjs) & (sum(ObjVals < Pobj,[2]) > 0)); Nidx = length(idx);
        if Nidx > 0,
            NmbOfDominating( p) = NmbOfDominating( p) + Nidx;
        end;

        if NmbOfDominating( p) == 0
            NmbOfFront( p) = 1;
            Front{ 1}(end + 1) = p;
        end
    end
    i = 1;

    while ~isempty( Front{ i})
        NextFront = [];
        for k = 1:length( Front{ i})
            p = Front{ i}( k);
            % Instead of loop try direct implementation
            q = Dominated{p}; NmbOfDominating( q) = NmbOfDominating( q) - 1;
            % Now do second line
            idx = (NmbOfDominating( q)==0); NmbOfFront(q(idx)) = i + 1;
            % Updat the front
            NextFront = [NextFront q(idx)];
        end
        i = i + 1;
        Front{ end + 1} = NextFront;
    end
end;

% Rank point based on their constraint violation
if flag == 1,
    % First compute size of individual arrays  
    [nmbOfIndivs nmbOfObjs] = size(Cg);
    % Sort the vector
    [CgSorted SortIdx] = sort(-Cg);
    % Generate initial rank
    [Rank] = [1:nmbOfIndivs]';
    % Generate final rank
    NmbOfFront(SortIdx,1) = Rank;
end;

% Crowding distance assignment
maxF = max(NmbOfFront);
% Loop over the individual fronts
for j = 1:maxF,
    % First find the particular rank points
    [SelectIdx] = find(NmbOfFront==j); Ntot = length(SelectIdx);
    % Select the appropriate points
    ObjValsSelected = ObjVals(SelectIdx,1:nmbOfObjs);
    % Re-initialize the crowding distance
    CrowdDist = zeros(Ntot, 1);
    % Now loop over the individual objectives
    for i = 1:nmbOfObjs
        % First sort the objective function in ascending order
        [ObjValsSorted SortIdx] = sort( ObjValsSelected( :, i));
        % Then assign boundary solutions extreme value
        CrowdDist(SortIdx(1),1) = CrowdDist(SortIdx(1),1) + inf; CrowdDist(SortIdx(Ntot),1) = CrowdDist(SortIdx(Ntot),1) + inf;
        % Now determine the crowding distance of the other individuals
        for z = 2:(Ntot - 1),
            % Now compute the distance of the other solutions and normalize
            CrowdDist(SortIdx(z),1) = CrowdDist(SortIdx(z),1) + (ObjValsSorted( z + 1) - ObjValsSorted( z - 1));
        end
    end
    Crowd(SelectIdx,1) = CrowdDist;
end;
% Assign crowding distance
CrowdDist = Crowd;
