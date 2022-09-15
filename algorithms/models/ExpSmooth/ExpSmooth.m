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
            nObs = size(obsHead,1);
            
            % Initialise parameters
            obj.parameters.alpha = -1;              % Exponential smoothing parameter            
            obj.parameters.beta = 1;                % Noise model parameter            
            obj.parameters.gamma = -1;              % Exponential trend parameter (optional)

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
            
            % Set percentile for noise 
            Pnoise = 0.95;            
            
            % Calc deterministic component of the head at 'time_points_all'.
            params = getParameters(obj);
            obj.variables.doingCalibration = false;
            [~, headtmp, obj.variables.h_forecast] = objectiveFunction(params, time_points_all, obj);            
            
            % Filter 'head' to only those time points input to the
            % function.
            [~, ind] = intersect(time_points_all,time_points);            
            headtmp = [time_points, headtmp(ind,:)];            
                        
            if size(params,2)>1
                head = zeros(size(headtmp,1),size(headtmp,2), size(params,2));
                noise = zeros(size(headtmp,1),3, size(params,2));
                head(:,:,1)= headtmp;
                for ii=1:size(params,2)
                    
                    % Calc deterministic component of the head at 'time_points_all'.
                    params = getParameters(obj);
                    obj.variables.doingCalibration = false;
                    [~, headtmp, obj.variables.h_forecast] = objectiveFunction(params(:,ii), time_points_all, obj);            

                    % Filter 'head' to only those time points input to the
                    % function.
                    [~, ind] = intersect(time_points_all,time_points);            
                    head(:,:,ii) = [time_points, headtmp(ind,:)];                                
                
                    % Create noise component output.
                    if isfield(obj.variables,'sigma_n')
                        noise(:,:,ii) = [head(:,1,ii), ones(size(head,1),2) .* norminv(Pnoise,0,1) .* obj.variables.sigma_n(ii)];
                    else
                        noise(:,:,ii) = [head(:,1,ii), zeros(size(head,1),2)];
                    end                
                end
            else
                head = headtmp;                
                
                % Create noise component output.
                if isfield(obj.variables,'sigma_n')
                    noise(:,:) = [head(:,1), norminv(Pnoise,0,1) .* obj.variables.sigma_n(ones(size(head,1),2))];
                else
                    noise(:,:) = [head(:,1), zeros(size(head,1),2)];
                end                
                
            end            
                        
            % Assign column names
            colnames = {'time','h_star'};
                                 
        end
        
        function noise = getNoise(obj, time_points, noisePercnile)

            % Check if there is the noise variable, sigma
            if ~isfield(obj.variables,'sigma_n')
                noise = zeros(length(time_points),1);
                return;
            end

            % Set percentile for noise
            if nargin==2
                noisePercnile = 0.95;
            else
                noisePercnile = noisePercnile(1);
            end

            noise = obj.variables.sigma_n;
            nparamsets = length(noise);
            if nparamsets>1
                noise = reshape(noise, 1, 1, nparamsets);
            end            

            noise = [repmat(time_points,1,1,nparamsets), ones(size(time_points,1),2) .* norminv(noisePercnile,0,1) .* noise];
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
            % spline (if there's the fitting toolbox), else use linear regression.
            x = (time_points-time_points(1))./365;
            y = obj.inputData.head(t_filt,2) - obj.variables.meanHead_calib;
            try
                spline_time_points = [0; 1/365];            
                spline_vals = csaps(x, y ,0.1,spline_time_points );

                obj.variables.initialHead = spline_vals(1) + obj.variables.meanHead_calib;
                obj.variables.initialTrend = (spline_vals(2) - spline_vals(1))./(spline_time_points(2) - spline_time_points(1) );                
            catch
                % Use linear regression over the first 5 data points to get the initial
                % slope and constant.
                nPts = 5;
                X = [ones(nPts ,1) x(1:nPts)];
                b = X\y(1:nPts);

                obj.variables.initialHead = b(1) + obj.variables.meanHead_calib;
                obj.variables.initialTrend = b(2);                
            end

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

                    if beta_lowerLimit >= (obj.variables.beta_upperLimit - 2)
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
        
        function h_star = calibration_finalise(obj, params, useLikelihood)          
            
            % Re-calc objective function and deterministic component of the head and innocations.
            % Importantly, the drainage elevation (ie the constant term for
            % the regression) is calculated within 'objectiveFunction' and
            % assigned to the object. When the calibrated model is solved
            % for a different time period then this
            % drainage value will be used by 'objectiveFunction'.
            h_star = [];
            [obj.variables.objFn, obj.variables.h_star, obj.variables.h_forecast] = objectiveFunction(params, obj.variables.calibraion_time_points, obj, useLikelihood);                        
            h_star = [obj.variables.calibraion_time_points, obj.variables.h_star];
 
            % Re-calc residuals and assign to object                        
            t_filt = obj.inputData.head(:,1) >=obj.variables.calibraion_time_points(1)  ...
                & obj.inputData.head(:,1) <= obj.variables.calibraion_time_points(end);                           
            obj.variables.resid = obj.inputData.head(t_filt,2)  -  obj.variables.h_forecast;
            
            % Calculate mean of noise. This should be zero +- eps()
            % because the drainage value is approximated assuming n-bar = 0.
            obj.variables.n_bar = real(mean( obj.variables.resid ));
            
            % Calculate innovations
            innov = obj.variables.resid(2:end) - obj.variables.resid(1:end-1).*exp( -10.^obj.parameters.beta .* obj.variables.delta_t );            
            
            % Calculate noise standard deviation.
            obj.variables.sigma_n = sqrt(mean( innov.^2 ./ (1 - exp( -2 .* 10.^obj.parameters.beta .* obj.variables.delta_t))));                    

            % Get noise component and omit columns for components.
            noise = getNoise(obj, obj.variables.calibraion_time_points);
            h_star = [h_star(:,:,:), h_star(:,2,:) - noise(:,2,:), h_star(:,2,:) + noise(:,3,:)];

            % Set a flag to indicate that calibration is complete.
            obj.variables.doingCalibration = false;
        end
        
        function [objFn, h_star, h_forecast] = objectiveFunction(params, time_points, obj, getLikelihood)                

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
            setParameters(obj, params, {'alpha','beta','gamma','initialHead','initialTrend'});            
            
            % Get model parameters and transform them from log10 space.
            alpha = 10.^obj.parameters.alpha;            
            beta = 10.^obj.parameters.beta;
            gamma = 10.^obj.parameters.gamma;
            initialHead = obj.variables.initialHead;
            initialTrend = obj.variables.initialTrend;
            q = mean(obj.variables.delta_t);
            
            % Get time points
            t = obj.inputData.head(:,1);

            % Create filter for time points and apply to t
            t_filt =  find(t >=time_points(1) & t <= time_points(end));                   
             
            % do head smoothing and forecast.
            nObs = int32(length(time_points));
            h_obs = obj.inputData.head(:,2);
            isObsTimePoints = double(obj.variables.isObsTimePoints);
            meanHead_calib = obj.variables.meanHead_calib;
            [h_ar,h_forecast] = doExpSmoothing(nObs, time_points,h_obs, isObsTimePoints, ...
                meanHead_calib, alpha,gamma,q, initialHead, initialTrend);
             
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
            objFn = sum( bsxfun(@rdivide, exp(mean(log( 1- exp( bsxfun(@times, -2*beta ,obj.variables.delta_t )) ))) ...
                        ,(1- exp(  bsxfun(@times, -2*beta ,obj.variables.delta_t) ))) .* innov.^2);   
                    
            % Calculate log liklihood    
            if getLikelihood
                N = size(resid,1);
                objFn = -0.5 * N * ( log(2*pi) + log(objFn./N)+1); 
            end                    
                    
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
            % Create parameter range and use limits if derived prior.
            if isfield(obj.variables,'beta_upperLimit')
                params_upperLimit = [0; obj.variables.beta_upperLimit; 0];
            else
                params_upperLimit = [0; 5 ; 0];
            end
            if isfield(obj.variables,'beta_lowerLimit')
                params_lowerLimit = [-inf; obj.variables.beta_lowerLimit; -inf];
            else
                params_lowerLimit = [-inf; -5; -inf];
            end            
        end
        
        function [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(obj)
            if isfield(obj.variables,'beta_upperLimit')
                params_upperLimit = [0; obj.variables.beta_upperLimit; 0];
            else
                params_upperLimit = [0; 2; 0];
            end
            if isfield(obj.variables,'beta_lowerLimit')
                params_lowerLimit = [-3; obj.variables.beta_lowerLimit; -3];
            else
                params_lowerLimit = [-3; -2; -3];
            end 
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
        
        
        function delete(obj)
% delete class destructor
%
% Syntax:
%   delete(obj)
%
% Description:
%   Loops through parameters and, if not an object, empties them. Else, calls
%   the sub-object's destructor.
%
% Input:
%   obj -  model object
%
% Output:  
%   (none)
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure Engineering, 
%   The University of Melbourne.
%
% Date:
%   24 Aug 2016
%%            
            propNames = properties(obj);
            for i=1:length(propNames)
               if isempty(obj.(propNames{i}))
                   continue;
               end                
               if isobject(obj.(propNames{i}))
                delete(obj.(propNames{i}));
               else               
                obj.(propNames{i}) = []; 
               end
            end
        end            
    end
       
end

