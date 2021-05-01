function [y] = SetToBounds(new,ParRange);
% Checks the bounds of the parameters

% First determine the size of new
[nmbOfIndivs,Dim] = size(new);
% Now replicate minn and maxn
minn = repmat(ParRange.minn,nmbOfIndivs,1); maxn = repmat(ParRange.maxn,nmbOfIndivs,1);
% Define y
y = new;
% Now check whether points are within bond
[ii] = find(y<minn); y(ii)= minn(ii); % set to bound value
[ii] = find(y>maxn); y(ii)= maxn(ii); % set to bound value