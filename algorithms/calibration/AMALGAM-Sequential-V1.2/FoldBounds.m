function [y] = FoldBounds(new,ParRange);
% Checks the bounds of the parameters

% ------- New approach that maintains detailed balance ----------

% First determine the size of new
[nmbOfIndivs,Dim] = size(new);

% Now replicate minn and maxn
minn = repmat(ParRange.minn,nmbOfIndivs,1); maxn = repmat(ParRange.maxn,nmbOfIndivs,1);

% Define y
y = new;

% Now check whether points are within bound
[ii] = find(y < minn); y(ii) = maxn(ii) - (minn(ii) - y(ii));
% Do upper bound
[ii] = find(y > maxn); y(ii) = minn(ii) + (y(ii) - maxn(ii));

% ----- End New approach that maintains detailed balance --------

% Just in case if still outside bound (should not happen)
[ii] = find(y < minn); y(ii) = minn(ii) + rand * (maxn(ii) - minn(ii));
% Do upper bound
[ii] = find(y > maxn); y(ii) = minn(ii) + rand * (maxn(ii) - minn(ii));
