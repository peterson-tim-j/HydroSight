function [log_L,log_PR] = Calc_density(x,fx,DREAMPar,Par_info,Meas_info);
% Now calculate the likelihood (not used) and log-likelihood (used)

% If number of measurements larger than 0 --> simulation
if Meas_info.N > 0,
    
    % Initialize "res" (residual matrix)
    res = NaN(Meas_info.N,DREAMPar.N);
    
    % Loop over each model realization
    for ii = 1 : DREAMPar.N,
        
        % We now calculate the error residual
        res(:,ii) = (Meas_info.Y(:) - fx(1:Meas_info.N,ii));
        
    end;
    
else
    
    % Do nothing, fx is a density or log-density returned by the PDF handle
    
end;

% ----------------------- Calculate log-prior  ----------------------------

% No ABC --> regular priors (pdfs)
if strcmp(DREAMPar.ABC,'no')
    
    % Calculate the log-prior
    if isfield(Par_info,'prior_marginal'),
        
        % Compute prior densities for each parameter in each sequence
        for qq = 1 : DREAMPar.d,
            for zz = 1 : DREAMPar.N,
                % Compute prior density of proposal
                PR(zz,qq) = max ( eval(char(strrep(Par_info.prior_marginal(qq),'rnd(','pdf(x(zz,qq),'))) , 1e-299 );
            end;
        end;
        
        % Take the log of the densities and their sum
        log_PR = sum ( log ( PR ) , 2 );
    
    % No use of prior --> set log-prior to zero (no effect in Metropolis)
    else
        
        log_PR = zeros ( DREAMPar.N , 1 );
        
    end;
    

else

    % Diagnostic Bayes --> if summary metric is defined as prior
    if isfield(DREAMPar,'prior_handle'), 
    
        % Evaluate distance between observed and simulated summary metrics
        for ii = 1 : DREAMPar.N,
        
            % Calculate summary metrics for "fx"
            S_sim = DREAMPar.prior_handle ( fx(:,ii) );
        
            % Now calculate log-density (not a true log-density! - but does not matter)
            log_PR(ii,1) = max ( abs ( Meas_info.S(:) - S_sim(:) ) );
        
        end;

    % Regular ABC with summary metrics as likelihood function
    else
    
        log_PR = zeros ( DREAMPar.N , 1 );
        
    end;
                
end;

% --------------------- End Calculate log-prior ---------------------------


% -------------------- Calculate log-likelihood ---------------------------

% Loop over each model realization and calculate log-likelihood of each fx
for ii = 1 : DREAMPar.N,
    
    % Check whether the measurement resor is estimated jointly with the parameters
    if isfield(Meas_info,'Sigma'),
        if isfield(Meas_info,'n'),
            % If yes --> create the current value of Sigma from the inline function and ii-th candidate point
            eval(Meas_info.str_sigma);
        else
            Sigma = Meas_info.Sigma;
        end;
    else
        % Sigma is either not needed in likelihood function or already defined numerically by the user
    end;
    
    % Model output is equal to posterior density (standard statistical distribution)
    if DREAMPar.lik == 1,
        log_L(ii,1) = log ( fx(1,ii) );
    end;
    
    % Model output is equal to log-density
    if DREAMPar.lik == 2,
        log_L(ii,1) = fx(1,ii);
    end;
    
    % Gaussian likelihood with measurement integrated out (see lecture script for derivation)
    if DREAMPar.lik == 11,
        % Calculate log-likelihood
        log_L(ii,1) = - Meas_info.N/2 * log( sum(abs(res(:,ii)).^2) );
    end;
    
    % Gaussian likelihood with homoscedastic or heteroscedastic measurement error
    if DREAMPar.lik == 12,
        % Derive the log density
        if size(Sigma,1) == 1,  % --> homoscedastic resor
            log_L(ii,1) = - ( Meas_info.N / 2) * log(2 * pi) - Meas_info.N * log( Sigma ) - 1/2 * Sigma^(-2) * sum ( res(:,ii).^2 );
        else                                % --> heteroscedastic resor
            log_L(ii,1) = - ( Meas_info.N / 2) * log(2 * pi) - sum ( log( Sigma ) ) - 1/2 * sum ( ( res(:,ii)./Sigma ).^2);
        end;
    end;
    
    % Gaussian likelihood function with homoscedastic/heteroscedastic error and AR-1 model of residuals
    if DREAMPar.lik == 13,
        % First order autoregressive (AR-1) correction of residuals
        rho = x(ii,DREAMPar.d); res_2 = res(2:Meas_info.N,ii) - rho * res(1:Meas_info.N-1,ii);
        % Now compute the log-likelihood
        if size(Sigma,1) == 1,  % --> homoscedastic error
            log_L(ii,1) = -(Meas_info.N/2) * log(2*pi) - (Meas_info.N/2) * log( Sigma^2 / (1-rho^2)) - ...
                (1/2) * (1-rho^2) * ( res(1,ii) / Sigma )^2 - (1/2) * sum( ( res_2 ./ Sigma ).^2 );
        else                                % --> heteroscedastic error
            log_L(ii,1) = -(Meas_info.N/2) * log(2*pi) - (Meas_info.N/2) * log(mean( Sigma.^2 ) / (1-rho^2)) - ...
                (1/2) * (1-rho^2) * ( res(1,ii) / Sigma(1) )^2 - (1/2) * sum( ( res_2 ./ Sigma(2:Meas_info.N ) ).^2 );
        end;
    end;
    
    % Generalized likelihood function (see Schoups and Vrugt, 2010)
    if DREAMPar.lik == 14,
        % Extract statistical model parameters
        par = Extra.fpar;               % fixed parameters
        par(Extra.idx_vpar) = x(ii,:);  % variable parameters
        par = par';                     % make it a column vector
        statpar = par(end-10:end);
        % Compute the log-likelihood
        log_L(ii,1) = GL('est',statpar,fx(1:Meas_info.N,ii),Meas_info.Y);
    end;
    
    % Whittle likelihood function (see Whittle, 1953)
    if DREAMPar.lik == 15,
        % Calculate the log-likelihood using spectral density
        log_L(ii,1) = Whittle(Meas_info,fx(1:Meas_info.N,ii));
    end;
    
    % Approximate Bayesian Computation (some estimate DREAMPar.delta along)
    if DREAMPar.lik == 21,
        % Now calculate rho
        rho = DREAMPar.rho( fx(1:Meas_info.N,ii) , Meas_info.Y(:) ) + normrnd(0,DREAMPar.epsilon,Meas_info.N,1);
        % Easier to work with log-density in practice --> when distance to 0 is large (with small delta)
        log_L(ii,1) = - ( Meas_info.N / 2) * log(2 * pi) - Meas_info.N * log( DREAMPar.epsilon ) - 1/2 * DREAMPar.epsilon^(-2) * sum ( rho.^2 );
    end;
    
    % Approximate Bayesian Computation (alternative to continuous kernel)
    if DREAMPar.lik == 22,
        % Now calculate log-density (not a true log-density! - but does not matter)
        log_L(ii,1) = max ( abs ( DREAMPar.rho( fx(1:Meas_info.N,ii) , Meas_info.Y(:) ) ) );
    end;
    
end;

% ------------------ End Calculate log-likelihood -------------------------