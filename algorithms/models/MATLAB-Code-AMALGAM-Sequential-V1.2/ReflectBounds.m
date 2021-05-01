function [y] = ReflectBounds(new,ParRange);
% Checks the bounds of the parameters

% First determine the size of new
[nmbOfIndivs,Dim] = size(new);
% Now replicate minn and maxn
minn = repmat(ParRange.minn,nmbOfIndivs,1); maxn = repmat(ParRange.maxn,nmbOfIndivs,1);
% Define y
y = new;
% Now check whether points are within bond
[ii] = find(y<minn); y(ii)= 2 * minn(ii) - y(ii); % reflect in minn
[ii] = find(y>maxn); y(ii)= 2 * maxn(ii) - y(ii); % reflect in maxn

% Now double check if all elements are within bounds
[ii] = find(y<minn); y(ii) = minn(ii) + rand*(maxn(ii)-minn(ii));
[ii] = find(y>maxn); y(ii) = minn(ii) + rand*(maxn(ii)-minn(ii));