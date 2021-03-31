function [log_L] = Whittle(Meas_info,fx);
% Calculates whittle's log-likelihood function using spectral analysis

% Do the following
Err = (Meas_info.Y - fx);

% Derive first-order autoregressive error coefficient: Err_(t)^ = rho * Err_(t-1) + error(t)
[rho,var_Err] = armcov(Err,1); phi = rho(2);

% ----- This part can be computed up front to speed up calculations  ------

N_half = floor( ( Meas_info.N - 1 ) / 2);

% Compute the periodogram of the model simulation (spectral density)
per_obs = abs(fft(Meas_info.Y)).^(2 / ( 2 * pi * Meas_info.N));

% Now take a certain set of points from per_obs
per_obs = per_obs ( 2: ( N_half + 1 ) );

% Now work with autoregressive error model
idx = [ 1 : N_half ]' * (( 2 * pi ) / Meas_info.N);

% Now calculate cos of idx
cos_idx = cos(idx);

% Now calculate the sin of idx
sin_idx = sin(idx);

% -------------------------------------------------------------------------

% Compute the periodogram of the observations (spectral density)
per_sim = abs(fft(fx)).^(2 / ( 2 * pi * Meas_info.N));

% Now take a certain set of points from per_sim
per_sim = per_sim ( 2 : ( N_half + 1 ) );

% Now define R_ar
R_ar = phi * cos_idx;

% Now define I_ar
I_ar = phi * sin_idx;

% Now calculate f_ar
f_ar = (1 - R_ar).^2 + I_ar.^2;

% Calculate f_spec
f_spec = (1./f_ar).* var_Err / (2 * pi);

% Add special density of model to spectral density of the autoregressive error model
per_tot = per_sim + f_spec;

% Now calculate ratio of spectral density of joint model and data
y_f = per_obs./ per_tot;

% Define which elements of per_tot are larger than zero
idx = per_tot > 0;

% Now calculate Whittle's log-likelihood
log_L = - ( sum ( log (per_tot ( idx ) ) ) + sum(y_f ( idx ) ) );