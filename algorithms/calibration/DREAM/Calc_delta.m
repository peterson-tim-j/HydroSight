function [delta_tot] = Calc_delta(DREAMPar,delta_tot,delta_normX,CR);
% Calculate total normalized Euclidean distance for each crossover value

% Derive sum_p2 for each different CR value 
for j = 1:DREAMPar.nCR;
    
    % Find which chains are updated with j/DREAMPar.nCR
    idx = find(CR==j/DREAMPar.nCR); 
    
    % Add the normalized squared distance tot the current delta_tot;
    delta_tot(1,j) = delta_tot(1,j) + sum(delta_normX(idx,1));
    
end;