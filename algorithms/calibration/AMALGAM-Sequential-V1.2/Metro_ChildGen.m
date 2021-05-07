function [ChildGen] = Metro_ChildGen(ParGen,Ranking,SCEMPar,Extra);
% Does multi-objective offspring generation

% First determine array size of Parset
[nmbOfIndivs nmbOfVars] = size(ParGen);
% Now find which points jave rank 1
idx = find(Ranking==1);  
% Then set JumpRate
JumpRate = Extra.Jump;
% Calculate the covariance structure
[TT,pp] = chol(cov(JumpRate * ParGen(idx,1:SCEMPar.n)));
if pp > 0,
    % Random point
    ChildGen = LHSU(min(ParGen(:,1:SCEMPar.n)),max(ParGen(:,1:SCEMPar.n)),nmbOfIndivs);
end;
if pp <= 0,
    % No do Metropolis offspring creation
    for tt = 1:nmbOfIndivs,
        muC = ParGen(tt,1:SCEMPar.n);
        % Generate draw from multi-normal distribution
        ru = normrnd(0,1,SCEMPar.n,1)';
        % Now generate new candidate point
        ChildGen(tt,1:SCEMPar.n) = real(muC+(ru*TT));
    end;
end;