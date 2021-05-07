function  [Gamma] = CompGamma(Falg,Fpareto,Nalg,Npareto,AMALGAMPar);
% Computes Gamma convergence measure

for qq = 1:Nalg,
    % Fill array with alg values of length Npareto
    A = Falg(qq,1:AMALGAMPar.nobj);
    temp = A(ones(Npareto,1),:);
    % Compute Euclidean distance
    Dist = sqrt(sum((temp - Fpareto).^2,[2]));
    idx = find(Dist==min(Dist));
    D(qq,1) = Dist(idx(1),1);
end
% Now compute Gamma from average distance
Gamma = mean(D);