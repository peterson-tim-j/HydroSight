function [par_unc,tot_unc] = predMCMC(RMSE_MAP,fx_post,PredInt);
% Calculates the desired parameter and total prediction uncertainty from the MCMC samples
%
% If PredInt is not defined, automatically assume 95% uncertainty ranges
if nargin < 5,
    PredInt = 95;
end;

% Define the lower bound of the prediction interval
alpha = ( 100 - PredInt ) / 2;

% Now add the RMSE to create the total uncertainty (homoscedastic error!)
fx_mod = fx_post + normrnd(0,RMSE_MAP,size(fx_post));

% Calculate the 2.5 and 97.5 percentile posterior simulation uncertainty due to parameter uncertainty
par_unc(:,1) = prctile(fx_post,alpha); par_unc(:,2) = prctile(fx_post,100-alpha);

% Calculate the 2.5 and 97.5 percentile posterior simulation uncertainty due to total uncertainty
tot_unc(:,1) = prctile(fx_mod,alpha); tot_unc(:,2) = prctile(fx_mod,100-alpha);