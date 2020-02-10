function [ isOutlier, noise_sigma, x_opt, model_calib ] = outlierDetection( headData, isOutlier, nSigma_threshold)

    % Initialise outputs    
    noise_sigma = inf;
    x_opt = [];
    model_calib = [];
     
    % Initialise 'isOutliers' if its not supplied by the user
    if isempty(isOutlier)
        isOutlier = false(size(headData,1));
    end
    isNewOutlier = false(size(headData,1));
    isOutlier_input = isOutlier;
    
    % Build inputs for exponential smoothing model
    t = headData(:,1);
    h_obs = headData(:,2);
    dummyBoreID = 'BoreID_123';
    coordinates = {dummyBoreID, -999, -999; 'Precip', -999, -999};
    forcingData = [t(1)-10: t(end)+10]';
    forcingData = table(year(forcingData),month(forcingData),day(forcingData),zeros(size(forcingData,1),1),'VariableNames',{'Year';'Month';'Day';'Precip'});   
    h_obs_model = [year(t), month(t), day(t), hour(t), minute(t), second(t), h_obs];
    
    % Calibrate exponential smoothing model
    summaryStr={};
    noise_sigma = 0;
    i=1;
    doFinalCalibration = false;
    el=0;
    while i==1 || sum(isNewOutlier)>0 || doFinalCalibration

        % Build model        
        model_calib = HydroSightModel('Outlier detection', dummyBoreID, 'ExpSmooth', h_obs_model(~isOutlier,:), -999, forcingData, coordinates, false);
        
        % Calibrate model
        calibrateModel(model_calib, [],0, inf, 'SPUCI',2)
        
        % Get the standard deviation of the noise.
        noise_sigma = model_calib.model.variables.sigma_n;
        
        % Exit if the this loop is being undertaken 
        if doFinalCalibration
            break
        end
        
        % Store calibrated parameters
        alpha = model_calib.model.parameters.alpha;
        beta = model_calib.model.parameters.beta;
        gamma = model_calib.model.parameters.gamma;
        meanHead_calib = model_calib.model.variables.meanHead_calib;
        initialHead = model_calib.model.variables.initialHead;
        initialTrend = model_calib.model.variables.initialTrend; 
         
        % Loop through each non-outlier observation to omit is from the
        % simulation. THis is doen to exclude a possible outlier point from
        % the smoothened estimate and the resulting calculation of the
        % noise. If the difference between the current obs point and the
        % forcast is greater than this noise estimate, then it is denoted
        % as an outlier. Importantly, in calculating the noise the min and
        % max points are also excluded.
        isNewOutlier = false(size(isOutlier));        
        filt = isOutlier;
        ind = find(~isOutlier)';   
        k=1;
        for j=ind(2:end)
            % Get a vector of obs points excluding the current obs point, point ind(j).
            k=k+1;
            filt(j) = true;
            time_points_trim =  headData(~filt,1);
            delta_t = headData(j,1) - headData(j-1,1);
            h_obs_trim = headData(~filt,2);
            h_obs_trim = [year(time_points_trim), month(time_points_trim), day(time_points_trim), hour(time_points_trim), minute(time_points_trim), second(time_points_trim), h_obs_trim];

            % Rebuild the model without the current time point, assign the
            % calibrated parameters and solve the model.
            model = HydroSightModel('Outlier detection', dummyBoreID, 'ExpSmooth', h_obs_trim, -999, forcingData, coordinates, false);
            model.model.parameters.alpha = alpha;
            model.model.parameters.beta = beta;
            model.model.parameters.gamma = gamma;
            model.model.variables.meanHead_calib = meanHead_calib;
            model.model.variables.calibraion_time_points = time_points_trim;            
            model.model.variables.initialHead = initialHead;
            model.model.variables.initialTrend = initialTrend; 
            
            % Add current point back in the simulation. Note, when
            % the simulation is undertaken for a point does not exist in
            % model, then it is forecast.
            filt(j) = false;
            time_points_trimExtended =  headData(~filt,1);            
            h_mod_trim = solveModel(model, time_points_trimExtended, [], 'NoLabel',false);    
            h_forecast_trim = model.model.variables.h_forecast;            
            
            % Create a filter to remove the current point from the forecast
            % and then calculate the residuals
            obs_filt = [1:k-1,k+1:length(ind)];
            resid_trim = h_obs_trim(:,end) - h_forecast_trim(obs_filt);
                        
            % To minimise the impacts of outliers as yet identified, create
            % a filter to remove the most negative and posative values from
            % the residuals
            resid_filt = resid_trim> min(resid_trim) & resid_trim < max(resid_trim);
            resid_trim = resid_trim(resid_filt);
            time_points_trim = time_points_trim(resid_filt);
            
            % Calculate innovations
            innov = resid_trim(2:end) - resid_trim(1:end-1).*exp( -10.^model.model.parameters.beta .*diff(time_points_trim) );      
                        
            % Calculate st. dev. of residuals noise
            %sigma_n_trimmed = sqrt(mean(innov.^2 ./ (1 - exp( -2 .* 10.^model.model.parameters.beta .* diff(time_points_trim) ))));        
            
            % Calculate st. dev. of residual for the current forecast only
            % Note: estimate of sigma_n at a spacific time step is derived
            % from von Asmuth 2015  doi:10.1029/2004WR00372 eqn A7 but with
            % the innovations at t, v_t, replaced with the mean. The was
            % undertaken so that sigma_n,t is independent from the residual forecast.
            sigma_n_trimmed = sqrt(mean(innov.^2) ./ (1 - exp( -2 .* 10.^model.model.parameters.beta .* delta_t )));        
                        
            % Calculate residual for omitted obs point.
            resid_point = h_obs(j) - h_forecast_trim(k);
            
            % Break for-loop if an outlier is detected.
            if abs(resid_point) >= nSigma_threshold* sigma_n_trimmed;
                isNewOutlier(j) = true;
                el=el+1;
                 summaryStr{el} = ['Date : ',datestr(t(j)),', Head : ',num2str(h_obs(j)), ...
                       ', Smoothed forecast head : ',num2str( h_forecast_trim(k)),', Residual head : ',num2str(resid_point), ...
                       ', St. dev of noise : ',num2str(sigma_n_trimmed)];
                break;
            end
        end
        
        % Aggregate new outliers with previously detected outliers
        isOutlier = isOutlier | isNewOutlier;
        
        % If the while loop is to exit, then set flag to do one last
        % calibration so that the noise is best estimated.
        if sum(isNewOutlier)==0
            doFinalCalibration = true;
        end
        
        %update counter
        i=i+1;        
    end

    % Assign the final parameters 
    x_opt = getParameters(model_calib.model);
    
    % Exclude input outliers from those input. That is, only return the
    % outliers identified from the exponential smoothing model
    isOutlier(isOutlier_input) = false;
    
    % Print summary:
    display('Summary of Outiers Detected');
    display('---------------------------');
    for i=1:el
        display(summaryStr{i});
    end
    display('---------------------------');
end

