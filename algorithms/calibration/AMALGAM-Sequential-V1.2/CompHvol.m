function [Hvol] = CompHvol(Falg,Fpareto,Nalg,Npareto,AMALGAMPar);
% Compute hypervolume

% Start to compute maximum and minimum of objective values
minF1 = min(Fpareto(:,1)); maxF1 = max(Fpareto(:,1)); minF2 = min(Fpareto(:,2)); maxF2 = max(Fpareto(:,2));

% First start with the 2-D estimation problem
ideal = 100; Sideal = (maxF1-minF1) * (ideal-minF2); 

% Compute hypervolume of true Pareto front
Strue = 0; 
for qq = 2:Npareto,
    
    if AMALGAMPar.nobj == 2,
        % Volume is x size multiplied with the y value
        dx = (Fpareto(qq,1) - Fpareto(qq-1,1)); dy = (ideal - Fpareto(qq-1,2));
    end

    if AMALGAMPar.nobj == 3,
        dx = sqrt(sum((Fpareto(qq,1:2)-Fpareto(qq-1,1:2)).^2)); dy = (ideal-Fpareto(qq-1,3));
    end;
    
    % Compute Strue and normalize according to ideal
    Strue = Strue + abs(dx * dy);
end;

Sfront = 0; 
% Then compute hypervolume using approximation from algorithm
for qq = 1:Nalg,
    
    % First  check whether extreme solutions algorithms are more extreme than the true set
    if (Falg(qq,1) < minF1) & (Falg(qq,2) > maxF2),
        Falg(qq,1) = minF1; Falg(qq,2) = maxF2;
    end;
    
    if (Falg(qq,1) > maxF1) & (Falg(qq,2) < minF2),
        Falg(qq,1) = maxF1; Falg(qq,2) = minF2;
    end;
    
    % Now check whether algorithm found better nondominated solutions than true set
    if (Falg(qq,2) < minF2) & (Falg(qq,1) < maxF1),
        Falg(qq,1:2) = Fpareto(end,1:2);
    end;
end;

Falg = sortrows(Falg,[1]);

% Now compute hypervolume
for qq = 2:Nalg,
    
    % First do 2-D case
    if AMALGAMPar.nobj == 2,
        % Now Calculate Hypervolume
        if (Falg(qq-1,1) >= minF1) & (Falg(qq,1) <= maxF1)
            % Now compute distance
            dx = (Falg(qq,1) - Falg(qq-1,1)); dy = (ideal - Falg(qq-1,2));
        else
            dx = 0; dy = 0;
        end;
    end;
    
    % Now do 3-D case
    if AMALGAMPar.nobj == 3,
        if (Falg(qq-1,1) >= minF1) & (Falg(qq,1) <= maxF1) & (Falg(qq-1,2) >= minF2) & (Falg(qq,2) <= maxF2)
            % Now compute distance
            dx = sqrt(sum((Falg(qq,1:2)-Falg(qq-1,1:2)).^2)); dy = (ideal-Falg(qq-1,3));
        else
            dx = 0; dy = 0;
        end;
    end;

    % Compute Strue and normalize according to ideal
    Sfront = Sfront + abs(dx * dy);
end;

% Check whether front is positive or negative
Hvol = 1 - Sfront/Strue;