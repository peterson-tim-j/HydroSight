function [ChildGen] = Mutate(ChildGen,AMALGAMPar,ParRange,pM,etaM);
% This function performs Mutation of Children

% First determine the dimension of the Children
[nmbOfIndivs,dim] = size(ChildGen);
% Now loop over individuals
for qq = 1:nmbOfIndivs,
    % Loop over individual elements of each individual
    for jj = 1:AMALGAMPar.n,
        % Check whether this number if larger than mutation factpr
        if (rand <= pM),
            y = ChildGen(qq,jj);
            % Define boundaries 
            yl = ParRange.minn(jj); yu = ParRange.maxn(jj);
            % Normalize range
            delta1 = (y-yl)/(yu-yl); delta2 = (yu-y)/(yu-yl);
            % Again draw random number
            rnd = rand;
            % Compute mutation power
            mut_pow = 1/(etaM+1);
            if rnd <= 0.5,
                xy = 1-delta1;
                val = 2.0*rnd+(1.0-2.0*rnd)*(xy^(etaM+1.0));
                deltaq = val^mut_pow - 1;
            else
                xy = 1.0-delta2;
                val = 2.0*(1.0-rnd)+2.0*(rnd-0.5)*(xy^(etaM+1.0));
                deltaq = 1.0 - val^mut_pow;
            end;
            % Check found bounds
            y = y + deltaq*(yu-yl);
            if (y<yl), y = yl; end;
            if (y>yu), y = yu; end;
            % Now update ChildGen
            ChildGen(qq,jj) = y;
        end;
    end;
end;