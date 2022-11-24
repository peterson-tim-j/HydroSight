function [ isOutlier, noise_sigma, x_opt, model_calib ] = outlierDetection(boreID, headData, isOutlier, nSigma_threshold)

    % Initialise outputs    
    noise_sigma = inf;
    x_opt = [];
    model_calib = [];
     
    % Initialise 'isOutliers' if its not supplied by the user
    if isempty(isOutlier)
        isOutlier = false(size(headData,1),1);
    end    
    isOutlier_input = isOutlier;
    
    % Build inputs for exponential smoothing model
    t = headData(:,1);
    h_obs = headData(:,2);
    h_obs_model = [year(t), month(t), day(t), hour(t), minute(t), second(t), h_obs];
    t = datenum(h_obs_model(:,1),h_obs_model(:,2),h_obs_model(:,3),h_obs_model(:,4),h_obs_model(:,5),h_obs_model(:,6));
    forcingData = ((t(1)-10):(t(end)+10))';
    forcingData = table(year(forcingData),month(forcingData),day(forcingData),zeros(size(forcingData,1),1),'VariableNames',{'Year';'Month';'Day';'Precip'});   
    coordinates = {boreID, -999, -999; 'Precip', -999, -999};

    % Set non-default calibration settings: 2 complexes per model parameter
    % and silience outputs to command window.
    calibSchemeSettings.ngs = 2;
    calibSchemeSettings.silent = true;

    % Calibrate exponential smoothing model
    noise_sigma = 0;
    i=1;
    doFinalCalibration = false;
    el=0;
    while i==1 || sum(isNewOutlier)>0 || doFinalCalibration
        % Reset vector of new outliers for this iteration.
        isNewOutlier = false(size(headData,1),1);

        % Build model        
        model_calib = HydroSightModel('Outlier detection', boreID, 'ExpSmooth', h_obs_model(~isOutlier,:), -999, forcingData, coordinates, false);
        
        % Calibrate model   
        calibrateModel(model_calib, [],0, inf, 'SPUCI',calibSchemeSettings);
        
        % Get the standard deviation of the noise.
        noise_sigma = model_calib.model.variables.sigma_n;
        
        % Exit if the this loop is being undertaken 
        if doFinalCalibration
            break
        end

        % Solve the model to get a forecast estimate at every observation
        % time point. Note the forecast is derived using the prior
        % observations and excludes the observation at the time point being
        % forecast.
        [~] = solveModel(model_calib, t(~isOutlier), [], 'NoLabel',false);
        h_forecast = model_calib.model.variables.h_forecast;
        
        % Calculate the difference between each observation and the
        % forecast estimate.
        t_obs = headData(~isOutlier,1);
        resid = h_obs(~isOutlier) - h_forecast;
        nObs = length(resid);
        resid_point = resid;

        % Exit if the there are only 3 observations.
        if nObs <=3
            break
        end       

        % Calculate the time step from each point being forecast (ie the
        % diagonals) to the prior time point
        delta_t = diff(t_obs);

        % To assess the forecast error at each time step, expand the
        % residual vector to a matrix and set the diagnonals to nan.
        resid = repmat(resid, 1, nObs);
        resid(logical(eye(nObs))) = NaN;
        tmat = repmat(t_obs, 1, nObs);
        tmat(logical(eye(nObs))) = NaN;       
        
        % To minimise the impacts of outliers as yet identified, exclude
        % the most negative and positive values from the residuals by 
        % setting them to nan.       
        [~,ind_min] = min(resid,[], 'omitnan','linear');
        [~,ind_max] = max(resid,[], 'omitnan','linear');
        resid([ind_min, ind_max]) = NaN;
        tmat([ind_min, ind_max]) = NaN;

        % Remove nans from residual matrix. Note, each column will have
        % three nans.
        ind = ~isnan(resid);
        resid = reshape(resid(ind),nObs-3,nObs);
        tmat = reshape(tmat(ind),nObs-3,nObs);

        % Calculate the mean squared innovations for each column.
        innov = mean((resid(2:end,:) - resid(1:end-1,:).*exp( -10.^model_calib.model.parameters.beta .*diff(tmat,1,1))).^2,1);

        % Calculate st. dev. of residual for the current forecast only
        % Note: estimate of sigma_n at a spacific time step is derived
        % from von Asmuth 2015  doi:10.1029/2004WR00372 eqn A7 but with
        % the innovations at t, v_t, replaced with the mean. The was
        % undertaken so that sigma_n,t is independent from the residual forecast.
        sigma_n_trimmed = sqrt(innov(2:end) ./ (1 - exp( -2 .* 10.^model_calib.model.parameters.beta .* delta_t' )));

        % Assess if the error at each time point exceeds a user defined
        % number of standard deviations of the remaining residuals.
        %firstOutlierIndex = find(abs(resid_point(2:end)') >= nSigma_threshold * sigma_n_trimmed, 1, 'first');
        errOverThreshold = abs(resid_point(2:end)') - nSigma_threshold * sigma_n_trimmed;
        [errOverThreshold_max, errOverThreshold_ind] = max(errOverThreshold);
        if errOverThreshold_max>0
            firstOutlierIndex = errOverThreshold_ind;
        else
            firstOutlierIndex = [];
        end

        % If an outlier is detected, then record details, omit observation 
        % repeat while loop (ie recalibrate without this outlier). If no
        % outlier is detected then set doFinalCalibration=true to finalise while loop. 
        if ~isempty(firstOutlierIndex)
            % Add one to index because the first time point is omitted from
            % the find() filter - because the first time point cannot be
            % assessed as being an outlier.
            firstOutlierIndex = firstOutlierIndex +1;
            
            % Map the outlier index (ie from the observations that were
            % assessed from prior while-loop iterations as not outliers) to
            % the list of all observations (ie as store in isNewOutlier).
            ind_notOutlier = find(~isOutlier);
            ind_newOutlier = ind_notOutlier(firstOutlierIndex);
            isNewOutlier(ind_newOutlier) = true;            

            % Aggregate new outliers with previously detected outliers
            isOutlier = isOutlier | isNewOutlier;
        else
            doFinalCalibration = true;
        end

        i=i+1;
        
%         continue;
% 
%         % Loop through each non-outlier observation to omit is from the
%         % simulation. This is done to exclude a possible outlier point from
%         % the smoothened estimate and the resulting calculation of the
%         % noise. If the difference between the current obs point and the
%         % forcast is greater than this noise estimate, then it is denoted
%         % as an outlier. Importantly, in calculating the noise the min and
%         % max points are also excluded.
%         isNewOutlier = false(size(isOutlier));        
%         filt = isOutlier;
%         ind = find(~isOutlier)';   
%         k=1;
%         for j=ind(2:end)
%             % Get a vector of obs points excluding the current obs point, point ind(j).
%             k=k+1;
%             filt(j) = true;
%             h_obs_trim = headData(~filt,:);
%             time_points_trim =  t(~filt);
%             delta_t = t(j) - t(j-1);
% 
%             % Update the model head data without the current time point. 
%             model_calib.model.inputData.head = h_obs_trim;            
%             model_calib.model.variables.calibraion_time_points = time_points_trim;
% 
%             % Add current point back in for the simulation. Note, when
%             % the simulation is undertaken for a point that does not exist in
%             % the model, then it is forecast estimate.
%             filt(j) = false;
%             time_points_trimExtended =  t(~filt);            
%             [~] = solveModel(model_calib, time_points_trimExtended, [], 'NoLabel',false);    
%             h_forecast_trim = model_calib.model.variables.h_forecast;            
%             
%             % Create a filter to remove the current point from the forecast
%             % and then calculate the residuals
%             obs_filt = [1:k-1,k+1:length(ind)];
%             resid_trim = h_obs_trim(:,end) - h_forecast_trim(obs_filt);
%                         
%             % To minimise the impacts of outliers as yet identified, create
%             % a filter to remove the most negative and posative values from
%             % the residuals
%             resid_filt = resid_trim> min(resid_trim) & resid_trim < max(resid_trim);
%             resid_trim = resid_trim(resid_filt);
%             time_points_trim = time_points_trim(resid_filt);
%             
%             % Calculate innovations
%             innov = resid_trim(2:end,:) - resid_trim(1:end-1,:).*exp( -10.^model_calib.model.parameters.beta .*diff(time_points_trim) );      
%                                     
%             % Calculate st. dev. of residual for the current forecast only
%             % Note: estimate of sigma_n at a spacific time step is derived
%             % from von Asmuth 2015  doi:10.1029/2004WR00372 eqn A7 but with
%             % the innovations at t, v_t, replaced with the mean. The was
%             % undertaken so that sigma_n,t is independent from the residual forecast.
%             sigma_n_trimmed = sqrt(mean(innov.^2) ./ (1 - exp( -2 .* 10.^model_calib.model.parameters.beta .* delta_t )));        
%                         
%             % Calculate residual for omitted obs point.
%             resid_point = h_obs(j) - h_forecast_trim(k);
%             
%             % Break for-loop if an outlier is detected.
%             if abs(resid_point) >= nSigma_threshold* sigma_n_trimmed
%                 isNewOutlier(j) = true;
%                 el=el+1;
%                  summaryStr{el} = ['Date : ',datestr(t(j)),', Head : ',num2str(h_obs(j)), ...
%                        ', Smoothed forecast head : ',num2str( h_forecast_trim(k)),', Residual head : ',num2str(resid_point), ...
%                        ', St. dev of noise : ',num2str(sigma_n_trimmed)];
%                 break;
%             end
%         end
%         
%         % Aggregate new outliers with previously detected outliers
%         isOutlier = isOutlier | isNewOutlier;
%         
%         % If the while loop is to exit, then set flag to do one last
%         % calibration so that the noise is best estimated.
%         if sum(isNewOutlier)==0
%             doFinalCalibration = true;
%         end
%         
%         %update counter
%         i=i+1;        
    end

    % Assign the final parameters 
    x_opt = getParameters(model_calib.model);
    
    % Exclude input outliers from those input. That is, only return the
    % outliers identified from the exponential smoothing model
    isOutlier(isOutlier_input) = false;
    
    % Print summary: NOTE, summary is commented out because writting text
    % when this function is run in parallel does not produce sensible
    % outputs to the command window.
%     disp(['Summary of Outiers Detected:',boreID]);
%     disp('---------------------------');
%     for i=1:el
%         display(summaryStr{i});
%     end
%     disp('---------------------------');
%     
end

