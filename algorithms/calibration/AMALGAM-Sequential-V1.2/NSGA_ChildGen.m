function [ChildGen] = NSGA_ChildGen(ParGen,ObjVals,Cviols,CrowdDist,ParRange,AMALGAMPar,pC,etaC,pM,etaM);
% Written by Jasper Vrugt based on C-code supplied by Deb

% First do selection
[ChildGen] = Selection(ParGen,Cviols,ObjVals,CrowdDist,ParRange,AMALGAMPar,pC,etaC);

% Do the normal mutation
[ChildGen] = Mutate(ChildGen,AMALGAMPar,ParRange,pM,etaM);