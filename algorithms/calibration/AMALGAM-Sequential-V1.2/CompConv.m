function [Gamma,Delta,Hvol] = CompConv(AMALGAMPar,Fpareto,Falg);
% ---------- Computes the gamma convergence metric ---------------

% Return empty values if true Pareto front does not exist
if isempty(Fpareto) == 1,
    % Define some numbers
    Gamma = NaN; Delta = NaN; Hvol = NaN;
end;

% Return values if true Pareto front does exist
if isempty(Fpareto) == 0,
    
    % First sort the data in Falg and Fpareto
    Falg = sortrows(Falg,[1]); Fpareto = sortrows(Fpareto,[1]);
    
    % Now compute the length of both arrays
    Npareto = size(Fpareto,[1]); Nalg = size(Falg,[1]);
    
    % Now compute Gamma convergence measures
    [Gamma] = CompGamma(Falg,Fpareto,Nalg,Npareto,AMALGAMPar);
    
    % Now compute the delta convergence metric 
    [Delta] = CompDelta(Falg,Fpareto,Nalg,Npareto,AMALGAMPar);
    
    % Now compute hypervolume
    [Hvol] = CompHvol(Falg,Fpareto,Nalg,Npareto,AMALGAMPar);
    
end;