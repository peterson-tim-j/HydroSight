function [ChildGen] = DE_ChildGen(ParGen,NmbOfFront,pBest,nBest,AMALGAMPar);
% Performs differential evolution

% F = 0.8; K = 0.4 -- in Previous papers
for tt = 1:AMALGAMPar.N,
    % Randomly generate F 
    F = unifrnd(0.6,1.0); 
    % Randomly generate K
    K = unifrnd(0.2,0.6); 
    % Now randomly select 3 Points from SCEMPar.s
    [ii] = randperm(AMALGAMPar.N); ii = ii(1:3);
    % Define the various r values
    r1 = ii(1); r2 = ii(2); r3 = ii(3);
    % Generate children using differential evolution
    ChildGen(tt,1:AMALGAMPar.n) = ParGen(tt,1:AMALGAMPar.n) + K.*(ParGen(r3,1:AMALGAMPar.n) - ParGen(tt,1:AMALGAMPar.n)) + ...
        F.*(ParGen(r1,1:AMALGAMPar.n) - ParGen(r2,1:AMALGAMPar.n));
end;