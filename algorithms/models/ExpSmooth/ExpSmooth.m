classdef ExpSmooth < model_abstract
    %ExpSmooth Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end

%%  STATIC METHODS        
% Static methods used by the Graphical User Interface to inform the
% user of the available model types. Any new models must be listed here
% in order to be accessable within the GUI.
    methods(Static)
        % Provides a simple description of the function for the user
        % interface.
        function str = description()
           
            str = {['"ExpSmooth" is a double exponential smoothing time-series model for irregular spaced  ', ...
                   'observations (Cipra et al. 2008). The double exponential smoothing undertakes an ', ...
                   'smoothing of the trend in the head and exponential smoothing of the component of the ', ...
                   'head not captured by the trend. Importantly, the trend is linear and is updated at each', ...
                   'observation. Therefore, when the model is used for interpolation of the head the estimate', ...
                   'has a discontinuity at each observation because of the updating of the trend.'], ...
                   '', ...
                  ['In fitting the exponential model to an observerd hydrograph, the exponential noise model', ...
                   'from Peterson & Western (2014) was been added. This provides a weighted least squares ', ...
                   'objective function and hence a means for minimisation all of three model parameters.'], ...
                   '', ...
                  ['In using the model, it does not use any forcing data, such as rainfall or extraction rate.', ...
                   'However, the toolkit user interface does require all models to have forcing data and ', ...
                   'coordinate data. Therefore, in using this model, forcing and coordinate data files must be', ...
                   'input but the files can contain junk data, e.g. all rainfall days can be zero.'], ...
                   '', ...
                   'For further details of the algorithms see:', ...
                   '', ...
                   '   - Peterson, T. J., and A. W. Western (2014), Nonlinear time-series modeling of unconfined groundwater head, Water Resour. Res., 50, 8330–8355, doi:10.1002/2013WR014800.', ...
                   '   - Cipra T. and Hanzák T. (2008). Exponential smoothing for irregular time series. _Kybernetika_,  44(3), 385-399.'};                     
               
               
        end        
    end        
    
%%  PUBLIC METHODS                  
    methods
        function obj = ExpSmooth(bore_ID, obsHead, forcingData_data,  forcingData_colnames, siteCoordinates, varargin)
            
            % Set observed head data
            obj.inputData.head = obsHead;
            
            % Initialise parameters
            obj.parameters.alpha = -1;            % Exponential smoothing parameter            
            obj.parameters.beta = -3;             % Noise model parameter            
            obj.parameters.gamma = -1;            % Exponential trend parameter (optional)
                        
            % Set Parameter names
            obj.variables.param_names = {'Auto-regressive','alpha';'Moving-average','beta';'Auto-regressive', 'gamma'};
            
        end
        
        function [head, colnames, noise] = solve(obj, time_points, tor_min, tor_max)
            % Check that the model has first been calibrated.
            %if ~isfield(obj.variables, 'meanHead_calib') || ~isfield(obj.parameters,'Const')
            if ~isfield(obj.variables, 'meanHead_calib')
                error('The model does not appear to have first been calibrated. Please calibrate the model before running a simulation.');
            end        
            
            % Check the time points are al unique
            if length(unique(time_points)) ~= length(time_points)
                error('The time points for simulation must be unique.');
            end
            
            % Create logical matrix indicating if the time point is an
            % observation. If true, then the data point is used to update
            % the exponential smoothing.  Else, a forecast is made using
            % the exonential smoothing using the smooth terms from the 
            % previous observation. 
            % To calculate this vector, the following steps are undertaken:
            % 1. Unique time points are derived from the simulation time
            % points and the observed time points within the calibration
            % period.
            % 2. Find the time points within the unique list that are
            % observations.
            % 3. Create a logical vector with the time points from 2 as true
            % 4. Assign vector from 3 to the object for access within the
            % objective function.
            time_points_all = [time_points; obj.variables.calibraion_time_points];
            time_points_all = unique(sort(time_points_all));
            [~, ind] = intersect(time_points_all,obj.variables.calibraion_time_points);
            obj.variables.isObsTimePoints = false(size(time_points_all));
            obj.variables.isObsTimePoints(ind) = true;                                    
            
            % Create vector of the time steps for only the time points with
            % observed heads.
            obj.variables.delta_t = diff(time_points_all(obj.variables.isObsTimePoints))./365;
            obj.variables.meanDelta_t = mean(obj.variables.delta_t);
            
            % Convert logical to double for MEX input
            obj.variables.isObsTimePoints = double(obj.variables.isObsTimePoints);
            
            % Calc deterministic component of the head at 'time_points_all'.
            params = getParameters(obj);
            obj.variables.doingCalibration = false;
            [~, head, obj.variables.h_forecast] = objectiveFunction(params, time_points_all, obj);            
            
            % Filter 'head' to only those time points input to the
            % function.
            [~, ind] = intersect(time_points_all,time_points);            
            head = [time_points, head(ind,:)];
            
            % Assign column names
            colnames = {'time','h_star'};
            
            % Create noise component output.
            if isfield(obj.variables,'sigma_n');
                noise = [head(:,1), obj.variables.sigma_n(ones(size(head,1),2))];
            else
                noise = [head(:,1), zeros(size(head,1),2)];
            end                        
        end
        
        function [params_initial, time_points] = calibration_initialise(obj, t_start, t_end)
            
            % Extract time steps
            t_filt = find( obj.inputData.head(:,1) >=t_start  ...
                & obj.inputData.head(:,1) <= t_end );   
            obj.variables.calibraion_time_points = obj.inputData.head(t_filt,1);
            time_points =  obj.variables.calibraion_time_points;
            
            % STore time difference
            obj.variables.delta_t = diff(time_points,1)./365;
            obj.variables.meanDelta_t = mean(obj.variables.delta_t);
            
            % Set a flag to indicate that calibration is complete.
            obj.variables.doingCalibration = true;
            
            % Calculate the mean head during the calibration period
            obj.variables.meanHead_calib = mean(obj.inputData.head(t_filt,2));

            % Create logical matrix indicating if the time point is an
            % observation. If true, then the data point is used to update
            % the exponential smoothing.  Else, a forecast is made using
            % the exonential smoothing using the smooth terms from the 
            % previous observation. For the calibration, this vector is
            % true.
            obj.variables.isObsTimePoints = true(size(obj.variables.calibraion_time_points));
            
            % Convert logical to double for MEX input
            obj.variables.isObsTimePoints = double(obj.variables.isObsTimePoints);
            
            % Estimate the initial value and slope by fitting a smoothed
            % spline.
            %spline_model = smooth(time_points, obj.inputData.head(t_filt,2), 'rloess');
            spline_time_points = [0; 1; (time_points(2:end)-time_points(1))]./365;
            spline_vals = csaps((time_points-time_points(1))./365, obj.inputData.head(t_filt,2) - obj.variables.meanHead_calib,0.1,spline_time_points );
            obj.variables.initialHead = spline_vals(1);
            obj.variables.initialTrend = (spline_vals(2) - spline_vals(1))./(spline_time_points(2) - spline_time_points(1) );
            
            % Find upper limit for alpha above which numerical errors arise.
            beta_upperLimit = 1000; 
            delta_time = diff(obj.inputData.head(:,1),1)./365;
            while abs(sum( exp( -2.*beta_upperLimit .* delta_time ) )) < eps() ...
            || exp(mean(log( 1- exp( -2.*beta_upperLimit .* delta_time) ))) < eps()
                beta_upperLimit = beta_upperLimit - 0.1;
                if beta_upperLimit <= eps()                                   
                    break;
                end
            end
            if beta_upperLimit <= eps()
                obj.variables.beta_upperLimit = 3;
            else
                % Transform alpha log10 space.
                obj.variables.beta_upperLimit = log10(beta_upperLimit);
            end      
            
            % Find lower limit for alpha. This is based on the assumption
            % that if the best model (ie explains 95% of variance) then 
            % for such a model the estimate of the
            % moving average noise should be << than the observed
            % head standard dev..                        
            if ~isinf(obj.variables.beta_upperLimit)
                beta_lowerLimit = -10;         
                obsHead_std = std(obj.inputData.head(t_filt,2));   
                while sqrt(mean( 0.05.*obsHead_std^2 ./ (1 - exp( -2 .* 10.^beta_lowerLimit .* obj.variables.delta_t)))) ...
                > obsHead_std                       

                    if beta_lowerLimit >= obj.variables.beta_upperLimit - 2
                        break;
                    end

                    beta_lowerLimit = beta_lowerLimit + 0.1;
                end
                obj.variables.beta_lowerLimit = beta_lowerLimit;
            else
                obj.variables.beta_lowerLimit = -5;
            end
            
            
            % Assign initial params to outputs
            params_initial = getParameters(obj);
            
            % Clear estimate of constant
            if isfield(obj.parameters,'Const')
                obj.parameters.Const = [];
            end
        end
        
        function calibration_finalise(obj, params)
            
            % Re-calc objective function and deterministic component of the head and innocations.
            % Importantly, the drainage elevation (ie the constant term for
            % the regression) is calculated within 'objectiveFunction' and
            % assigned to the object. When the calibrated model is solved
            % for a different time period then this
            % drainage value will be used by 'objectiveFunction'.
            [obj.variables.objFn, obj.variables.h_star, obj.variables.h_forecast] = objectiveFunction(params, obj.variables.calibraion_time_points, obj);                        
 
            % Re-calc residuals and assign to object                        
            t_filt = obj.inputData.head(:,1) >=obj.variables.calibraion_time_points(1)  ...
                & obj.inputData.head(:,1) <= obj.variables.calibraion_time_points(end);                           
            obj.variables.resid = obj.inputData.head(t_filt,2)  -  obj.variables.h_forecast;
            
            % Calculate mean of noise. This should be zero +- eps()
            % because the drainage value is approximated assuming n-bar = 0.
            obj.variables.n_bar = real(mean( obj.variables.resid ));
            
            % Calculate noise standard deviation.
            obj.variables.sigma_n = sqrt(mean( obj.variables.resid(1:end-1).^2 ./ (1 - exp( -2 .* 10.^obj.parameters.beta .* obj.variables.delta_t))));                    
            
            % Set a flag to indicate that calibration is complete.
            obj.variables.doingCalibration = false;
        end
        
        function [objFn, h_star, h_forecast] = objectiveFunction(params, time_points, obj)                

            % Check the required object variables are set.
            if ~isfield(obj.variables,'isObsTimePoints') ...
            || ~isfield(obj.variables,'meanHead_calib')    
                error('The model does not appear to have been initialised for calibration.');
            end
               
            % Check the input time points and the logical vector denoting
            % observartion time points are of equal length
            if length(time_points) ~= length(obj.variables.isObsTimePoints)
                error('The input time points vector must be the same length as the logical vector of observation time points.');
            end
                        
            % Set model parameters         
            setParameters(obj, params, {'alpha','beta','gamma'});            
            
            % Get model parameters and transform them from log10 space.
            alpha = 10.^obj.parameters.alpha;            
            beta = 10.^obj.parameters.beta;
            gamma = 10.^obj.parameters.gamma;
            
            % Get time points
            t = obj.inputData.head(:,1);

            % Create filter for time points and apply to t
            t_filt =  find(t >=time_points(1) & t <= time_points(end));                   
            
            % Setup time-varying weigting terms from input parameters
            % and their values at t0 using ONLY the time points with
            % observed head values!
            q = mean(obj.variables.delta_t);
            alpha_i = 1 - (1 - alpha)^q;
            gamma_i = 1 - (1 - gamma)^q;
            
            % Initialise the output and subract the mean from the observed
            % head.
            h_ar = zeros(length(time_points),1);
            h_obs = obj.inputData.head(:,2) - obj.variables.meanHead_calib;            
            
            % Assign linear regression estimate the initial slope and intercept.
            %h_trend(1) = obj.variables.initialTrend_calib;
            %h_trend = obj.variables.initialTrend_calib;
            h_trend = obj.variables.initialTrend;
            h_ar(1) = obj.variables.initialHead;
            h_forecast = h_ar;
            indPrevObsTimePoint = 1;
            indPrevObs = 1;
            
            % Undertake double exponential smoothing.
            % Note: It is based on Cipra T. and Hanzák T. (2008). Exponential 
            % smoothing for irregular time series. Kybernetika,  44(3), 385-399.
            % Importantly, this can be undertaken for time-points that have observed 
            % heads and those that are to be interpolated (or extrapolated). 
            % The for loop cycles though each time point to be simulated.
            % If the time point is an observation then the alpha, gamma and
            % h_trend are updates and an index is stored pointng to the last true obs point. 
            % If the time point is not an observation then a forecast is
            % undertaken using the most recent values of alpha, gamma and
            % h_trend
            for i=2:length(time_points)
               
               delta_t = (time_points(i)-time_points(indPrevObsTimePoint))/365;
                
               if obj.variables.isObsTimePoints(i)
                   % Update smoothing model using the observation at the
                   % current time point.
                   if indPrevObs==1
                       gamma_weight = (1-gamma)^delta_t;
                   else                                              
                       gamma_weight = delta_t_prev/delta_t * (1-gamma)^delta_t;            
                   end                    
                   
                   alpha_weight = (1-alpha).^delta_t;
                   
                   alpha_i = alpha_i./(alpha_weight + alpha_i); 
                   gamma_i = gamma_i./(gamma_weight + gamma_i);
                   h_ar(i) = (1-alpha_i) * (h_ar(indPrevObsTimePoint) + delta_t * h_trend) + alpha_i * h_obs(indPrevObs+1);
                   h_forecast(i) = h_ar(indPrevObsTimePoint) + delta_t * h_trend;
                   h_trend = (1-gamma_i) * h_trend + gamma_i * (h_ar(i) - h_ar(indPrevObsTimePoint))./delta_t;
                                                         
                   indPrevObsTimePoint = i;
                   indPrevObs = indPrevObs+1;
                   delta_t_prev = delta_t;
               else
                   % Make a forecast to the current non-observation time
                   % point.
                   h_forecast(i) = h_ar(indPrevObsTimePoint) + delta_t * h_trend;
                   h_ar(i) = h_forecast(i);
               end
            end            
            
            % Add the mean head onto the smoothed estimate and forecast
            h_ar = h_ar + obj.variables.meanHead_calib;
            h_forecast = h_forecast + obj.variables.meanHead_calib;

%             % Calculate the mean error and add to estimates.
%             if obj.variables.doingCalibration
%                 obj.parameters.Const = mean(h_forecast) - obj.variables.meanHead_calib;
%             end       
%             h_ar = h_ar - obj.parameters.Const;
%             h_forecast = h_forecast - obj.parameters.Const;
%             
            % Assign output for non-corrected head
            h_star = h_ar;
            
            %% Calculate the moving average componant.                        
            if ~obj.variables.doingCalibration
                objFn=[];
                return
            end

            % Create natrix ob observed and forecast heads
            h_mat = [obj.inputData.head(t_filt,2), h_forecast];

            % Calculate residuals (excluding input outliers).
            resid = diff(h_mat,1,2);

            % Calculate the innovations
            innov = resid(2:end,:) - resid(1:end-1,:).*exp( bsxfun(@times, -beta ,obj.variables.delta_t) );

            % Calculate the weighted least squares objective function
            objFn = sqrt( bsxfun(@rdivide, exp(mean(log( 1- exp( bsxfun(@times, -2*beta ,obj.variables.delta_t )) ))) ...
                        ,(1- exp(  bsxfun(@times, -2*beta ,obj.variables.delta_t) ))) .* innov.^2);   
                    
        end
        
        function setParameters(obj, params, param_names)
            obj.parameters.(param_names{1})= params(1);
            obj.parameters.(param_names{2})= params(2);
            obj.parameters.(param_names{3})= params(3);
        end
        
        function [params, param_names] = getParameters(obj)
            params(1,:) = obj.parameters.alpha;
            params(2,:) = obj.parameters.beta;
            params(3,:) = obj.parameters.gamma;
            param_names = {'alpha','beta','gamma'};
        end
        
        function [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj)            
            
            if isfield(obj.variables,'beta_upperLimit')
                params_upperLimit = [0; obj.variables.beta_upperLimit; 0];
            else
                params_upperLimit = [0; 5 ; 0];
            end
            if isfield(obj.variables,'beta_lowerLimit')
                params_lowerLimit = [-inf; obj.variables.beta_lowerLimit; -inf];
            else
                params_lowerLimit = [-inf; -5 ; -inf];
            end            
        end
        
        function [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(obj)

            params_upperLimit = [0; 2; 0];
            params_lowerLimit = [-3; -2; -3];

        end        
        
        function isValidParameter = getParameterValidity(obj, params, time_points)

            % Get physical limits and test if parames are within the range
            [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj);
            isValidParameter = params >= repmat(params_lowerLimit,1,size(params,2)) & params <= repmat(params_upperLimit,1,size(params,2));
                        
            % Check the alphanoise parameter is large enough not to cause numerical
            % problems in the calcuation of the objective function.            
            filt_noiseErr = exp(mean(log( 1- exp( bsxfun(@times,-2.*10.^params(2,:) , obj.variables.delta_t) )),1)) <= eps() ...
                         | abs(sum( exp( bsxfun(@times,-2.*10.^params(2,:) , obj.variables.delta_t) ),1)) < eps();                
            isValidParameter(2,filt_noiseErr)= false;                
        end
       
        %% Get the forcing data from the model
        function [forcingData, forcingData_colnames] = getForcingData(obj)
            forcingData = [];
            forcingData_colnames = {}; 
        end
        
        %% Set the forcing data from the model
        function setForcingData(obj, forcingData, forcingData_colnames)
            % do nothing. The model does not use forcing data.
        end          
        

        %% Get the obs head data from the model
        function head = getObservedHead(obj)
            head = obj.inputData.head;
        end
        
    end
       
end

