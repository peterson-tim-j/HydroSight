function [V] = InitVel(AMALGAMPar,Extra);
% Initializes PSO velocity
V = [];

% Determine the number of complexes that do particle swarm optimization
NrSwarm = find(strcmp(Extra.Alg,'PSO')==1); Nc = length(NrSwarm);
if Nc > 0,
    % First initialize with zeros
    V = zeros(AMALGAMPar.N,AMALGAMPar.n,AMALGAMPar.q);  
    for qq = 1:Nc,
        V(:,:,NrSwarm(qq)) = rand(AMALGAMPar.N,AMALGAMPar.n);
    end;
end
