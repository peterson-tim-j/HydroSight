function [R_stat] = Gelman(chain,DREAMPar)
% Calculates the R-statistic convergence diagnostic
% ----------------------------------------------------
% For more information please refer to: Gelman, A. and D.R. Rubin, 1992. 
% Inference from Iterative Simulation Using Multiple chain, 
% Statistical Science, Volume 7, Issue 4, 457-472.
%
% Written by Jasper A. Vrugt
% Los Alamos, August 2007
% ----------------------------------------------------

% Compute the dimensions of chain
[n,nrY,m] = size(chain);

if (n < 10),
    % Set the R-statistic to a large value
    R_stat = NaN(1,DREAMPar.d);
else
    % Step 1: Determine the _chainuence means
    mean_chain = mean(chain); mean_chain = reshape(mean_chain(:),DREAMPar.d,m)';
    
    % Step 1: Determine the variance between the _chainuence means 
    B = n * var(mean_chain);
    
    % Step 2: Compute the variance of the various chain
    for zz = 1:DREAMPar.N,
        var_chain(zz,:) = var(chain(:,:,zz));
    end;
    
    % Step 2: Calculate the average of the within _chainuence variances
    W = mean(var_chain);
    
    % Step 3: Estimate the target mean
    %mu = mean(mean_chain);
    
    % Step 4: Estimate the target variance
    sigma2 = ((n - 1)/n) * W + (1/n) * B;
    
    % Step 5: Compute the R-statistic
    R_stat = sqrt((m + 1)/m * sigma2 ./ W - (n-1)/m/n);
    
end;