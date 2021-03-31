function [x] = Boundary_handling(x,Par_info);
% Function to check whether parameter values remain within prior bounds

% First determine the size of new
[m,n] = size(x);

% Now replicate min and max
min_d = repmat(Par_info.min,m,1); max_d = repmat(Par_info.max,m,1);

% Now find which elements of x are smaller than their respective bound
[ii_low] = find(x < min_d); 

% Now find which elements of x are larger than their respective bound
[ii_up] = find(x > max_d); 

% Reflection
if strcmp(Par_info.boundhandling,'reflect');

    % reflect in min
    x(ii_low)= 2 * min_d(ii_low) - x(ii_low);     

    % reflect in max
    x(ii_up)= 2 * max_d(ii_up) - x(ii_up); 

end;

% Bound
if strcmp(Par_info.boundhandling,'bound');

    % set lower values to min
    x(ii_low)= min_d(ii_low); 
    
    % set upper values to max
    x(ii_up)= max_d(ii_up);

end;

% Folding
if strcmp(Par_info.boundhandling,'fold');

    % Fold parameter space lower values
    x(ii_low) = max_d(ii_low) - ( min_d(ii_low) - x(ii_low) );
    
    % Fold parameter space upper values
    x(ii_up) = min_d(ii_up) + ( x(ii_up) - max_d(ii_up) );

end;

% Now double check in case elements are still out of bound -- this is
% theoretically possible if values are very small or large

% Now double check if all elements are within bounds
[ii_low] = find(x < min_d); x(ii_low) = min_d(ii_low) + rand(size(ii_low)).* ( max_d(ii_low) - min_d(ii_low) );
[ii_up]  = find(x > max_d); x(ii_up)  = min_d(ii_up)  + rand(size(ii_up)).*  ( max_d(ii_up)  - min_d(ii_up)  );