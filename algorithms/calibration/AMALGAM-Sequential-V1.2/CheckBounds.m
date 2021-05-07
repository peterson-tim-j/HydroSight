function [new] = CheckBounds(new,old,ParRange);
% Checks the bounds of the parameters

minn = ParRange.minn; maxn = ParRange.maxn;

% First determine the size of new
[NrComb,Dim] = size(new);

% Loop over each individual element
for qq = 1:NrComb,
    [ii] = find(new(qq,:)<minn); if isempty(ii) == 0, new(qq,ii) = minn(ii); end; 
    [ii] = find(new(qq,:)>maxn); if isempty(ii) == 0, new(qq,ii) = maxn(ii); end; 
end;