function [Delta] = CompDelta(Falg,Fpareto,Nalg,Npareto,AMALGAMPar);
% Now compute the delta convergence metric

for qq = 2:Nalg,
    d(qq-1,1) = sqrt(sum((Falg(qq,1:AMALGAMPar.nobj)-Falg(qq-1,1:AMALGAMPar.nobj)).^2));
end
% Remove points with large distance -> indicates a discontinuous Pareto set
[i] = find(d < 10*mean(d)); d = d(i,:);
% Now compute average Euclidean distance between members nondominated set
dmean = mean(d);
% Now compute dl (qq=1) and df (qq=2)
for qq = 1:2,
    if qq == 1,
        % determine df
        temp = repmat(Fpareto(1,1:AMALGAMPar.nobj),Nalg,1);
    else
        % determine dl
        temp = repmat(Fpareto(end,1:AMALGAMPar.nobj),Nalg,1);
    end;
    % Compute distance between extreme Falg solutions and Fpareto solutions
    Dist = sqrt(sum((temp - Falg).^2,[2]));
    % Find minimum distance
    idx = find(Dist==min(Dist)); idx = idx(1);
    % Find dx and dy between
    if qq == 1,
        % Check whether algorithm found better point than end of Pareto set
        if sum(abs(Fpareto(1,1:AMALGAMPar.nobj)-Falg(idx,1:AMALGAMPar.nobj))) == AMALGAMPar.nobj,
            df = 0;
        else
            df = Dist(idx);
        end;
    end;
    if qq == 2,
        % Check whether algorithm found better point than end of Pareto set
        if sum(abs(Fpareto(end,1:AMALGAMPar.nobj)-Falg(idx,1:AMALGAMPar.nobj))) == AMALGAMPar.nobj,
            dl = 0;
        else
            dl = Dist(idx);
        end;
    end;
end;

D = ((df + dl ) + sum(abs(d-dmean)))./((df + dl) + ((Nalg-1)*dmean));
Delta = [mean(D)];
