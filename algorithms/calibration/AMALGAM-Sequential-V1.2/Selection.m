function [ChildGen] = Selection(ParGen,Cviols,ObjVals,CrowdDist,ParRange,AMALGAMPar,pC,etaC);
% Function performs genetic selection and crossover

% First determine the dimension of the Children
[nmbOfIndivs,dim] = size(ParGen);


% Define a1 and a2
a1 = randperm(nmbOfIndivs); a2 = randperm(nmbOfIndivs);

% Initialize the new Children Generation
ChildGen = [];
% Now do tournament selection and crossover
for qq = 0:4:nmbOfIndivs-4,
    % Select parents
    a_1 = a1(qq+1); a_2 = a1(qq+2); a_3 = a1(qq+3); a_4 = a1(qq+4);

    parent1 = Tournament(ParGen(a_1,:),ParGen(a_2,:),Cviols(a_1,1),Cviols(a_2,1),ObjVals(a_1,:),ObjVals(a_2,:),...
        CrowdDist(a_1,1),CrowdDist(a_2,1),AMALGAMPar);
    parent2 = Tournament(ParGen(a_3,:),ParGen(a_4,:),Cviols(a_3,1),Cviols(a_4,1),ObjVals(a_3,:),ObjVals(a_4,:),...
        CrowdDist(a_3,1),CrowdDist(a_4,1),AMALGAMPar);
    % Now do crossover
    [child1,child2] = Crossover(parent1,parent2,AMALGAMPar,ParRange,pC,etaC); 
    % Append the children to the offspring 
    ChildGen = [ChildGen;child1;child2];
    
    % Select parents
    a_1 = a2(qq+1); a_2 = a2(qq+2); a_3 = a2(qq+3); a_4 = a2(qq+4);
    
    parent1 = Tournament(ParGen(a_1,:),ParGen(a_2,:),Cviols(a_1,1),Cviols(a_2,1),ObjVals(a_1,:),ObjVals(a_2,:),...
        CrowdDist(a_1,1),CrowdDist(a_2,1),AMALGAMPar);
    parent2 = Tournament(ParGen(a_3,:),ParGen(a_4,:),Cviols(a_3,1),Cviols(a_4,1),ObjVals(a_3,:),ObjVals(a_4,:),...
        CrowdDist(a_3,1),CrowdDist(a_4,1),AMALGAMPar);
    % Now do crossover
    [child1,child2] = Crossover(parent1,parent2,AMALGAMPar,ParRange,pC,etaC); 
    % Append the children to the offspring
    ChildGen = [ChildGen;child1;child2];
    
end;

% Check whether size of 
if (size(ChildGen,1) < nmbOfIndivs),
    % Possible to miss 2 children if population size does not divide by 4 
    a_1 = a1(end-1); a_2 = a1(end); a_3 = a1(round(0.5*nmbOfIndivs)); a_4 = a1(round(0.5*nmbOfIndivs)); 
    % Select two parents
    parent1 = Tournament(ParGen(a_1,:),ParGen(a_2,:),Cviols(a_1,1),Cviols(a_2,1),ObjVals(a_1,:),ObjVals(a_2,:),...
        CrowdDist(a_1,1),CrowdDist(a_2,1),AMALGAMPar);
     parent2 = Tournament(ParGen(a_3,:),ParGen(a_4,:),Cviols(a_3,1),Cviols(a_4,1),ObjVals(a_3,:),ObjVals(a_4,:),...
        CrowdDist(a_3,1),CrowdDist(a_4,1),AMALGAMPar);
    % Now do crossover
    [child1,child2] = Crossover(parent1,parent2,AMALGAMPar,ParRange,pC,etaC); ChildGen = [ChildGen;child1;child2];
end; 
    
% ------------------------------------------------------------------------
function [parent] = Tournament(a,b,cviola,cviolb,obja,objb,CrowdDa,CrowdDb,AMALGAMPar);
% Function performs tournament selection

% First draw random number
rnd = rand; done = 0;
% First check dominance

flagout = Check_dominance(cviola,cviolb,obja,objb,AMALGAMPar);
% Now check various flags
if flagout == 1,
    parent = a; done = 1;
end
if flagout == -1,
    parent = b; done = 1;
end;
if (CrowdDa > CrowdDb) & (done == 0),
    parent = a; done = 1;
end;
if (CrowdDa < CrowdDb) & (done == 0),
    parent = b; done = 1;
end;
if (rnd <= 0.5) & (done == 0),
    parent = a; 
end;
if (rnd > 0.5) & (done == 0),
    parent = b;
end;

% ------------------------------------------------------------------------
function [flagout] = Check_dominance(cviola,cviolb,obja,objb,AMALGAMPar);
% Function checks for dominance

% First initialize some important variables
flag1 = 0; flag2 = 0;
% Now start loop to determine flag
if (cviola < 0) & (cviolb < 0),
    % If overall contraint violation a < b -> select individual a
    if cviola > cviolb,
        flagout = 1,
    end;
    % If overall contraint violation a > b -> select individual b
    if cviola < cviolb,
        flagout = -1,
    end
    if cviola == cviolb,
        flagout = 0;
    end;
end;
% If contraint violation a = 0 and b < 0 -> select individual a
if (cviola == 0) & (cviolb < 0),
    flagout = 1;
end;
% If contraint violation a < 0 and b = 0 -> select individual b
if (cviola < 0) & (cviolb == 0),
    flagout = -1;
end;
% If there is no contraint violation, do objective function analysis
if (cviola == 0) & (cviolb == 0),
    for qq = 1:AMALGAMPar.nobj,
        if obja(qq) < objb(qq),
            flag1 = 1;
        end;
        if obja(qq) > objb(qq),
            flag2 = 1;
        end;
    end;
    if (flag1==1) & (flag2==0),
        flagout = 1;
    end
    if (flag1==0) & (flag2==1),
        flagout = -1;
    end;
    if (flag1==1) & (flag2==1),
        flagout = 0;
    end;
    if (flag1==0) & (flag2==0),
        flagout = 0;
    end;
end;

% ------------------------------------------------------------------------
function [child1,child2] = Crossover(parent1,parent2,AMALGAMPar,ParRange,pC,etaC);
% Function performs crossover of two individuals

newgen = []; EPS = 1e-14; 
% Now do if loop
if (rand <= pC),
    for qq = 1:AMALGAMPar.n,
        if (rand <= 0.5),
            if abs(parent1(qq)-parent2(qq)) > EPS,
                if parent1(qq) < parent2(qq),
                    y1 = parent1(qq); y2 = parent2(qq);
                else
                    y1 = parent2(qq); y2 = parent1(qq);
                end
                yl = ParRange.minn(qq); yu = ParRange.maxn(qq);
                rnd = rand;
                beta = 1.0 + (2.0*(y1-yl)/(y2-y1)); alpha = 2.0 - beta^(-(etaC+1.0));

                if (rnd <= (1.0/alpha)),
                    betaq = (rnd*alpha)^(1.0/(etaC+1.0));
                else
                    betaq = (1.0/(2.0 - rnd*alpha))^(1.0/(etaC+1.0));
                end;

                c1 = 0.5*((y1+y2)-betaq*(y2-y1));
                beta = 1.0 + (2.0*(yu-y2)/(y2-y1));
                alpha = 2.0 - beta^(-(etaC+1.0));

                if (rnd <= (1.0/alpha)),
                    betaq = (rnd*alpha)^(1.0/(etaC+1.0));
                else
                    betaq = (1.0/(2.0 - rnd*alpha))^(1.0/(etaC+1.0));
                end;

                c2 = 0.5*((y1+y2)+betaq*(y2-y1));
                if (c1<yl), c1=yl; end;
                if (c2<yl), c2=yl; end;
                if (c1>yu), c1=yu; end;
                if (c2>yu), c2=yu; end;

                if (rand<=0.5),
                    child1(qq) = c2; child2(qq) = c1;
                else
                    child1(qq) = c1; child2(qq) = c2;
                end;
            else
                child1(qq) = parent1(qq); child2(qq) = parent2(qq);
            end;
        else
            child1(qq) = parent1(qq); child2(qq) = parent2(qq);
        end;
    end;
else
    child1 = parent1; child2 = parent2;
end;