%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                                                            %
% THIS PROGRAMS HELPS TO POSTPROCESS AND PLOT THE RESULTS OF THE DREAM PACKAGE                               %
%                                                                                                            %
% Written by Jasper A. Vrugt                                                                                 %
%                                                                                                            %
% Version 0.5: April 2012: 	Initial setup and evaluation                                                     %
% Version 1.0: May 2012:    Generalization to problems with and without simulation writing, more plotting    %
% Version 1.1: August 2014  Clean up and new options                                                         %
%                                                                                                            %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% ------------------------------------------------------------------------------------------------------------
% ------------------------------------------------------------------------------------------------------------
% ------------------------------------------------ PRE-PROCESSING -------------------------------------------
% ------------------------------------------------------------------------------------------------------------
% ------------------------------------------------------------------------------------------------------------

% First assemble all chain in one matrix
ParSet = genparset(chain); DREAMPar.N = size(chain,3);

% Take the last 25% of the posterior samples -- assume that these samples
% are posterior samples (double check that R_stat < 1.2 for all parameters)
Pars = ParSet ( floor ( 0.75 * size(ParSet,1) ) : size(ParSet,1), 1 : DREAMPar.d );

% How many posterior parameter samples?
N_Pars = size(Pars,1);

% Define function handle
f_handle = eval(['@(x)',char(Func_name),'(x)']);

% If not now check whether model produces simulation or not?
sim_out = [];

% Now see whether we use real data or not
if exist('Meas_info')
    % Check if field Y exists
    if isfield(Meas_info,'Y'),
        % How many elements does Meas_info have?
        Meas_info.N = size(Meas_info.Y,1);
        % Did we store runs in fx or not?
        if isfield(DREAMPar,'modout'),
            % If yes, then take from fx
            sim_out = fx ( floor ( 0.75 * size(fx,1) ) : size(fx,1), 1 : Meas_info.N );
        else
            sim_out = NaN ( N_Pars , Meas_info.N );
            % Initialize waitbar
            h = waitbar(0,'Running posterior simulations - Please wait...');
            % Loop over each sample
            for qq = 1 : N_Pars,
                sim_out(qq,1:Meas_info.N) = f_handle(Pars(qq,1:DREAMPar.d));
                % Update the waitbar --> to see simulation progress on screen
                waitbar(qq/N_Pars,h);
            end;
            % Now close waitbar
            close(h);
        end
    end
else
    % No simulations and no summary metrics
    fx_post = []; FX_post = [];
end;

% Not ABC
if ~isfield(DREAMPar,'ABC');
    % And sim_out exists
    if ~isempty(sim_out),
        % must be posterior simulations
        fx_post = sim_out; FX_post = [];
    end
elseif isfield(DREAMPar,'ABC');
    % If field "S" of Meas_info exists --> summary metrics as prior
    if isfield(Meas_info,'S'),
        % sim_out are model simulations
        fx_post = sim_out;
        % Now compute summary statistics from fx (model simulations)
        h = waitbar(0,'Calculating posterior summary metrics - Please wait...');
        for qq = 1 : N_Pars,
            FX_post(qq,:) = DREAMPar.prior_handle(fx_post(qq,:));
            % Update the waitbar --> to see simulation progress on screen
            waitbar(qq/N_Pars,h);
        end;
        % Now close waitbar
        close(h);
        
    else
        % Field "S" of Meas_info does not exist --> summary metrics as likelihood
        fx_post = []; FX_post = sim_out;
    end;
end;

% Now determine the size of fx_post (columns is number observations)
Meas_info.N = size(fx_post,2);

% ------------------------------------------------------------------------------------------------------------
% ------------------------------------------------------------------------------------------------------------
% -------------------------------------------- END OF PRE-PROCESSING -----------------------------------------
% ------------------------------------------------------------------------------------------------------------
% ------------------------------------------------------------------------------------------------------------

% Find the maximum aposteriori parameter values (last column of ParSet are log-density values!)
[~,idx] = max(ParSet(:,end)); idx = idx(1);

% Print those to screen
MAP = ParSet(idx,1:DREAMPar.d)

% Calculate the mean posterior value of each parameter
MEAN = mean(Pars)

% Calculate the posterior standard deviation of the parameters
STD = std(Pars)

% Calculate the DREAMPar.d-dimensional parameter correlation matrix (R-values)
CORR = corrcoef(Pars)

% Set figure number
fig_number = 1;

% ------------------------------------------------------------------------------------------------------------
% -------------------------------- EVOLUTION OF R_STATISTIC OF GELMAN AND RUBIN ------------------------------
% ------------------------------------------------------------------------------------------------------------

% Now plot the R_statistic for each parameter
figure(fig_number),
% Update figure number
fig_number = fig_number + 1;
% First print the R-statistic of Gelman and Rubin (each parameter a different color)
plot(output.R_stat(:,1),output.R_stat(:,2:DREAMPar.d+1)); hold on;
% Add labels
xlabel('Number of generations','fontsize',14,'fontweight','bold','fontname','Times');
ylabel('R_{stat}','fontsize',14,'fontweight','bold','fontname','Times');
% Add title
title('Convergence of sampled chains','fontsize',14,'fontweight','bold','fontname','Times');
% Now add the theoretical convergence value of 1.2 as horizontal line
plot([0 output.R_stat(end,1)],[1.2 1.2],'k--','linewidth',2);
% Set the the axes
axis([0 output.R_stat(end,1) 0.8 5]);
% Add a legend
evalstr = strcat('legend(''par.1''');
% Each parameter a different color
for j = 2:DREAMPar.d,
    % Add the other parameters
    evalstr = strcat(evalstr,',''par. ',num2str(j),'''');
end;
% And now conclude with a closing bracket
evalstr = strcat(evalstr,');');
% Now evaluate the legend
eval(evalstr);

% ------------------------------------------------------------------------------------------------------------
% -------------------------------- HISTOGRAMS OF MARGINAL DENSITIES OF PARAMETERS ----------------------------
% ------------------------------------------------------------------------------------------------------------

% Plot the histograms (marginal density) of each parameter;
% What lay out of marginal distributions is desired subplot(r,t)
r = 3; t = 2;
% How many figures do we need to create with this layout?
N_fig = ceil( DREAMPar.d / (r * t) ); counter = 1; j = 1;
% Open new figure
figure(fig_number);
% Now plot each parameter
while counter <= DREAMPar.d
    % Check whether to open a new figure?
    if j == (r * t) + 1,
        % Update fig_number
        fig_number = fig_number + 1;
        % Open new figure
        figure(fig_number);
        % Reset j to 1
        j = 1;
    end;
    % Now create histogram
    [N,X] = hist(Pars(:,counter));
    % And plot histogram in red
    subplot(r,t,j),bar(X,N/sum(N),'r'); hold on; % --> can be scaled to 1 if using "trapz(X,N)" instead of "sum(N)"!
    if j == 1,
        % Add title
        title('Histograms of marginal distributions of individual parameters','fontsize',14,'fontweight','bold','fontname','Times');
    end;
    % Add x-labels
    evalstr = strcat('Par',{' '},num2str(counter)); xlabel(evalstr,'fontsize',14,'fontweight','bold','fontname','Times');
    % Then add y-label (only if j == 1 or j = r;
    if j == 1 | ( min(abs(j - ([1:r]*t+1))) == 0 ),
        ylabel('Marginal density','fontsize',14,'fontweight','bold','fontname','Times');
    end;
    % Now determine the min and max X values of the plot
    minX = min(X); maxX = max(X); minY = 0; maxY = max(N/sum(N));
    % Now determine appropriate scales
    deltaX = 0.1*(maxX - minX);
    % Calculate x_min and x_max
    x_min = minX - deltaX; x_max = maxX + deltaX;
    % Now determine the min and max Y values of the plot
    y_min = 0; y_max = 1.1*maxY;
    % Lets add the MAP value
    plot(MAP(counter),0.98*y_max,'bx','Markersize',15,'linewidth',3);
    % Adjust the axis
    axis([x_min x_max y_min y_max]);
    % Check if counter = 1,
    if counter == 1, % --> add a title for first figure
        % Add title
        title('Histograms of marginal distributions of individual parameters','fontsize',14,'fontweight','bold','fontname','Times');
    end;
    % Now update the counter
    counter = counter + 1;
    
    % Update j
    j = j + 1;
end;

% Update fig_number
fig_number = fig_number + 1;

% ------------------------------------------------------------------------------------------------------------
% -------------------------------------- MARGINAL DENSITIES OF PARAMETERS ------------------------------------
% ------------------------------------------------------------------------------------------------------------

% Plot the histograms (marginal density) of each parameter;
% What lay out of marginal distributions is desired subplot(r,t)
r = 3; t = 2;
% How many figures do we need to create with this layout?
N_fig = ceil( DREAMPar.d / (r * t) ); counter = 1; j = 1;
% Open new figure
figure(fig_number);
% Now plot each parameter
while counter <= DREAMPar.d
    % Check whether to open a new figure?
    if j == (r * t) + 1,
        % Update fig_number
        fig_number = fig_number + 1;
        % Open new figure
        figure(fig_number);
        % Reset j to 1
        j = 1;
    end;
    % Now create density
    [N,X]=density(Pars(:,counter),[]);
    % And plot density in red
    subplot(r,t,j),plot(X,N,'r-','linewidth',2); hold on;
    if j == 1,
        % Add title
        title('Marginal posterior density of individual parameters','fontsize',14,'fontweight','bold','fontname','Times');
    end;
    % Add x-labels
    evalstr = strcat('Par',{' '},num2str(counter)); xlabel(evalstr,'fontsize',14,'fontweight','bold','fontname','Times');
    % Then add y-label (only if j == 1 or j = r;
    if j == 1 | ( min(abs(j - ([1:r]*t+1))) == 0 ),
        ylabel('Marginal density','fontsize',14,'fontweight','bold','fontname','Times');
    end;
    % Now determine the min and max X values of the plot
    minX = min(X); maxX = max(X); minY = 0; maxY = max(N);
    % Now determine appropriate scales
    deltaX = 0.1*(maxX - minX);
    % Calculate x_min and x_max
    x_min = minX - deltaX; x_max = maxX + deltaX;
    % Now determine the min and max Y values of the plot
    y_min = 0; y_max = 1.1*maxY;
    % Lets add the MAP value
    plot(MAP(counter),0.98*y_max,'bx','Markersize',15,'linewidth',3);
    % Adjust the axis
    axis([x_min x_max y_min y_max]);
    % Check if counter = 1,
    if counter == 1, % --> add a title for first figure
        % Add title
        title('Marginal posterior density of individual parameters','fontsize',14,'fontweight','bold','fontname','Times');
    end;
    % Now update the counter
    counter = counter + 1;
    
    % Update j
    j = j + 1;
end;

% Update fig_number
fig_number = fig_number + 1;

% ------------------------------------------------------------------------------------------------------------
% -------------------------------- CORRELATION PLOTS OF THE POSTERIOR PARAMETER SAMPLES ----------------------
% ------------------------------------------------------------------------------------------------------------

% Only plot this matrix if less or equal to 30 parameters
if ( DREAMPar.d <= 30 ),
    % Open a new plot
    figure(fig_number); fig_number = fig_number + 1;
    % Plot a matrix (includes unscaled marginals on main diagonal!
    plotmatrix(Pars,'+r');
    % Add title
    title('Marginal distributions and two-dimensional correlation plots of posterior parameter samples','fontsize',14,'fontweight','bold','fontname','Times');
end;


% ------------------------------------------------------------------------------------------------------------
% ------------------------------ AUTOCORRELATION PLOTS OF THE POSTERIOR PARAMETER SAMPLES --------------------
% ------------------------------------------------------------------------------------------------------------

% Plot the histograms (marginal density) of each parameter;
% What lay out of marginl distributions is desired subplot(r,t)
r = 3; t = 1;
% How many figures do we need to create with this layout?
N_fig = ceil( DREAMPar.d / (r * t) ); counter = 1; j = 1;
% Open new figure
figure(fig_number);
% Calculate the ACF for each individual chain
N = size(chain,1); color = {'r','b','g'};
% Now determine maxlag
maxlag = min(250,N);
% Now plot each parameter
while counter <= DREAMPar.d
    % Check whether to open a new figure?
    if j == (r * t) + 1,
        % Update fig_number
        fig_number = fig_number + 1;
        % Open new figure
        figure(fig_number);
        % Reset j to 1
        j = 1;
    end;
    
    % Plot the ACF of each parameter
    for z = 1:min(3,DREAMPar.N),
        % Plot the ACF
        subplot(r,t,j),plot(acf(chain(1:N,j,z),maxlag),char(color(z))); hold on;
        % Adjust axis
        axis([0 maxlag -1 1]);
    end;
    
    if j == 1,
        % Add title
        title('Autocorrelation plot of sampled parameters','fontsize',14,'fontweight','bold','fontname','Times');
    end;
    
    % Add x-labels
    evalstr = strcat('Par',{' '},num2str(counter));
    title('Autocrrelation plot of sampled parameters','fontsize',14,'fontweight','bold','fontname','Times');
    
    % Now update the counter
    counter = counter + 1;
    
    % Update j
    j = j + 1;
    
end;

% Update fig_number
fig_number = fig_number + 1;

% ------------------------------------------------------------------------------------------------------------
% -------------------------------- PLOT HISTOGRAMS OF THE SUMMARY STATISTICS ---------------------------------
% ------------------------------------------------------------------------------------------------------------

% Only do this part if ABC is done
if ~isempty(FX_post),
    
    % Plot the histograms (marginal density) of each summary statistic;
    % What lay out of marginal distributions is desired subplot(r,t)
    r = 2; t = 3;
    % How many figures do we need to create with this layout?
    N_fig = ceil( Meas_info.N / (r * t) ); counter = 1; j = 1;
    % Open new figure
    figure(fig_number);
    % Now plot each parameter
    while counter <= size(FX_post,2),
        % Check whether to open a new figure?
        if j == (r * t) + 1,
            % Update fig_number
            fig_number = fig_number + 1;
            % Open new figure
            figure(fig_number);
            % Reset j to 1
            j = 1;
        end;
        % Now create histogram
        [N,X] = hist(FX_post(:,counter));
        % And plot histogram in red
        subplot(r,t,j),bar(X,N/sum(N),'r'); hold on; % --> can be scaled to 1 if using "trapz(X,N)" instead of "sum(N)"!
        if j == 1,
            % Add title
            title('Marginal posterior density of individual summary statistics','fontsize',14,'fontweight','bold','fontname','Times');
        end;
        % Add x-labels
        evalstr = strcat('S_',num2str(counter)); xlabel(evalstr,'fontsize',14,'fontweight','bold','fontname','Times');
        % Then add y-label (only if j == 1 or j = r;
        if j == 1 | ( min(abs(j - ([1:r]*t+1))) == 0 ),
            ylabel('Marginal density','fontsize',14,'fontweight','bold','fontname','Times');
        end;
        % Unpack each of the observed summary metrics
        if isfield(Meas_info,'S'),
            Xobs = Meas_info.S(counter);
        else
            Xobs = Meas_info.Y(counter);
        end;
        % Now determine the min and max X values of the plot
        minX = min( [ X Xobs] ); maxX = max( [ X Xobs] ); minY = 0; maxY = max(N/sum(N));
        % Now determine appropriate scales
        deltaX = 0.1*(maxX - minX);
        % Calculate x_min and x_max
        x_min = minX - deltaX; x_max = maxX + deltaX;
        % Now determine the min and max Y values of the plot
        y_min = 0; y_max = 1.1*maxY;
        % Lets add the MAP value
        if isfield(Meas_info,'S'),
            plot(Xobs,0.98*y_max,'bx','Markersize',15,'linewidth',3);
        else
            plot(Xobs,0.98*y_max,'bx','Markersize',15,'linewidth',3);
        end
        % Adjust the axis
        axis([x_min x_max y_min y_max]);
        % Check if counter = 1,
        if counter == 1, % --> add a title for first figure
            % Add title
            title('Marginal posterior density of individual summary statistics','fontsize',14,'fontweight','bold','fontname','Times');
        end;
        % Now update the counter
        counter = counter + 1;
        
        % Update j
        j = j + 1;
    end;
    
    % Update fig_number
    fig_number = fig_number + 1;
    
end;

% ------------------------------------------------------------------------------------------------------------
% -------------------------------- CALCULATE THE RMSE OF THE BEST SOLUTION -----------------------------------
% ------------------------------------------------------------------------------------------------------------

if ~isempty(fx_post),
    
    % Now check whether output simulations have been saved our not?
    if ~isfield(DREAMPar,'modout');
        ModPred = f_handle(MAP);
    else
        % Derive model simulation from fx
        ModPred = fx(idx,1:end);
    end;
    
    % Compute the RMSE of the maximum aposteriori solution
    RMSE_MAP = sqrt ( sum ( ( ModPred(:) - Meas_info.Y).^2) / prod(size(ModPred)) )
    
else
    
    % Do nothing
    RMSE_MAP = []
    
end;

% If you use option 3, then this RMSE value should be equal to "sqrt(-max(X(:,end-1))/Meas_info.N)" !!
% Hence, option 3 uses a standard Gaussian likelihood function, minimizing the SSE (RMSE)

% ------------------------------------------------------------------------------------------------------------
% -------------------------------- CONVERGENCE OF INDIVIDUAL CHAINS TO TARGET DISTRIUBUTION ------------------
% ------------------------------------------------------------------------------------------------------------

% Define colors for different chains
symbol = {'ys','rx','g+','ko','c<'};

% Now loop over each parameter
for j = 1:DREAMPar.d,
    % Open new figures
    figure(fig_number);
    % Update fig_number
    fig_number = fig_number + 1;
    % How many elements does the chain have
    Nseq = size(chain,1)-1;
    % Now plot a number of chains
    for i = 1:min(DREAMPar.N,5);
        plot([0:Nseq],chain(1:end,j,i),char(symbol(i)),'markersize',3,'linewidth',3); if i == 1; hold on; end;
    end
    % Add an axis
    if isfield(Par_info,'min'),
        % Use scaling with prior parameter ranges
        axis([0 Nseq Par_info.min(j) Par_info.max(j)]);
    else
        % Ranges have not been defined -- need to derive them from ParSet
        min_j = min(ParSet(:,j)); max_j = max(ParSet(:,j));
        % Now make the ranges a little wider
        if min_j < 0,
            min_j = 1.1*min_j;
        else
            min_j = 0.9*min_j;
        end;
        if max_j > 0,
            max_j = 1.1*max_j;
        else
            max_j = 0.9*max_j;
        end;
        % And scale the figure
        axis([0 Nseq min_j max_j]);
    end;
    % Lets add the MAP value
    plot( Nseq , MAP(j),'bx','Markersize',15,'linewidth',3);
    % Add a legend
    evalstr = strcat('legend(''chain. 1''');
    % Each parameter a different color
    for jj = 2:min(DREAMPar.N,5),
        % Add the other parameters
        evalstr = strcat(evalstr,',''chain.',{' '},num2str(jj),'''');
    end;
    % And now conclude with a closing bracket
    evalstr = strcat(evalstr,');');
    % Now evaluate the legend
    eval(char(evalstr));
    % Add a title
    xlabel('Sample number of chain','fontsize',14,'fontweight','bold','fontname','Times');
    % Then add a y-label
    evalstr = strcat('par ',{' '},num2str(j)); ylabel(evalstr,'fontsize',14,'fontweight','bold','fontname','bold','fontname','times');
    % Then add title
    title('Chain convergence plot','fontsize',14,'fontweight','bold','fontname','bold','fontname','times');
end;

% ------------------------------------------------------------------------------------------------------------
% -------------------------------- PLOT THE 95% POSTERIOR SIMULATION UNCERTAINTY -----------------------------
% ------------------------------------------------------------------------------------------------------------

if ~isempty(fx_post),
    
    % Set the prediction uncertainty ranges
    PredInt = 95;
    
    % Derive the rspective 95% simulation uncertainty ranges (can change 95 to any other value!)
    [par_unc,tot_unc] = predMCMC(RMSE_MAP,fx_post,PredInt);
    
    % Open new figure
    figure(fig_number),
    
    % Update fig_number
    fig_number = fig_number + 1;
    
    % We start with the total uncertainty
    Fill_Ranges([1:size(tot_unc,1)],tot_unc(:,1),tot_unc(:,2),[0.75 0.75 0.75]); hold on;
    
    % And then plot the parameter uncertainty
    Fill_Ranges([1:size(tot_unc,1)],par_unc(:,1),par_unc(:,2),[0.25 0.25 0.25]);
    
    % Now add the observations
    plot([1:size(tot_unc,1)],Meas_info.Y,'r.');
    
    % Fit axes
    axis([0 size(tot_unc,1) 0 1.1 * max(max(tot_unc))])
    
    % Add labels
    xlabel('y','fontsize',14,'fontweight','bold','fontname','bold','fontname','times');
    ylabel('x','fontsize',14,'fontweight','bold','fontname','bold','fontname','times');
    title('95% Posterior simulation uncertainty ranges (homoscedastic error!)','fontsize',14,'fontweight','bold','fontname','bold','fontname','times');
    % -------------------------------------------------------------------------
    
    % Now calculate percentage inside the PredInt bound defined in predMCMC
    Contained = 100 * (1 - length( find ( Meas_info.Y < tot_unc(:,1) | Meas_info.Y > tot_unc(:,2) ) ) / size ( tot_unc,1) )
    % This should be close to the PredInt that was used
    
end;

% ------------------------------------------------------------------------------------------------------------
% ------------------------------------------- NOW DO THE RESIDUAL ANALYSIS -----------------------------------
% ------------------------------------------------------------------------------------------------------------

if exist('ModPred'),
    
    % Calculate the residual
    res = ModPred(:) - Meas_info.Y(:);
    
    % Now create new autocorrelation function
    figure(fig_number), autocorr(res);
    
    % Then add title
    title('Autocorrelation plot of residuals','fontsize',14,'fontweight','bold','fontname','bold','fontname','times');
    
    % Define ylabel
    ylabel('Autocorrelation','fontsize',14,'fontweight','bold','fontname','Times');
    
    % Update fig_number
    fig_number = fig_number + 1;
    
    % Now create qq plots
    figure(fig_number), qqplot(res);
    
    % Define xlabel
    xlabel('Standard normal quantiles','fontsize',14,'fontweight','bold','fontname','Times');
    
    % Define ylabel
    ylabel('Quantiles of posterior sample','fontsize',14,'fontweight','bold','fontname','Times');
    
    % Then add title
    title('QQ plot of posterior sample versus standard normal distribution','fontsize',14,'fontweight','bold','fontname','bold','fontname','times');
    
end;

% ------------------------------------------------------------------------------------------------------------
% ------------------------------------------------------------------------------------------------------------