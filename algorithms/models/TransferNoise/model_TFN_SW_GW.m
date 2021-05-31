classdef model_TFN_SW_GW < model_TFN & model_abstract
% Class definition for Transfer Function Noise (TFN) model for use with
% HydroSight to simulate SW-GW interactions 

    %   Model uses the weighting function of the GW head interpolation to
    %   inform the behavior of baseflow, whether it is discharge to or recharging from the river.
    
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
           
            str = {['"model_TFN_SW_GW" is a highly flexible nonlinear transfer function noise time-series model. '], ...
                   'The model has the following additional features:', ...
                   '   - joint simulation of groundwater head and streamflow time-series', ...
                   '', ...
                   'For further details of the algorithms use the help menu or see:', ...
                   '', ...
                   '   - Future publication', ...
                   '', ...
                   '   - Peterson, T. J., and A. W. Western (2014), Nonlinear time-series modeling of unconfined groundwater head, Water Resour. Res., 50, 8330–8355, doi:10.1002/2013WR014800.', ...
                   '', ...
                   '   - Shapoori V., Peterson T. J., Western A. W. and Costelloe J. F., (2015), Top-down groundwater hydrograph time series modeling for climate-pumping decomposition. Hydrogeology Journal'};                     
               
        end        
    end        
    
    
    
    %%  PUBLIC METHODS              

    methods
        
        
        %% Model constructor
        %function obj = model_TFN_SW_GW(bore_ID, stream_ID, obsHead, forcingData_data,  forcingData_colnames, siteCoordinates, varargin)           
        function obj = model_TFN_SW_GW(bore_ID, obsData, forcingData_data,  forcingData_colnames, siteCoordinates, varargin)           
% model_TFN constructs for linear and nonlinear Transfer Function Noise model
%
% Syntax:
%   model = model_TFN(bore_ID, obsData, forcingData_data, ...
%           forcingData_colnames, siteCoordinates, modelOptions)
%       

            % Get model option for which ID is stream gauge
            
            % identify what is bore and what is river, so define what is bore in bore_ID and what is streamflow... 
            % impose to the user to put streamflow data as the "first
            % bore"in the observed data file, so in this function we pick
            % the first "bore_id" as the river... 
            
            %bore_ID = 124705
            
            % streamID = "first bore_id in the observed data file..." 
            
            % tranforms streamflow to mm to compare with the 
            
            % estimate the baseflow using GW data so it can be used to calculate the objective function based on the
            % simulated time series of GW head and quick-flow from the
            % soil-moisture model, like  total_sim_flow = BaseFlow(GW) +
            % quickFlow (soil_moisture), then we compare the total_sim_flow
            % com observed_flow from the BOM database.. 
            
            
            % Use sub-class constructor.
            obj = obj@model_TFN(bore_ID, obsData, forcingData_data,  forcingData_colnames, siteCoordinates, varargin{1});

            %% Read in file with obs flow.
            % Note, eventually site_IDs needs to be chnaged from a single
            % string with the bore ID to a vector of stream and bore IDs.
            % Maybe the first could be the stream ID.  

            %   -------- CHANGE THE CACTHMENT ACCORDINGLY  -----------
     
            obsDataFlow = readtable('obsFlow_Brucknell.csv'); % read in the obs flow data
            obsDataFlow = obsDataFlow(:,[2:4 6]); % FLOW UNIT -> columns -> [5] = daily average [m3/s], [6] = [mm/day], [7] = [ML/day], [8] = [mm/day]^(1/5),
            obsDataFlow = table2array(obsDataFlow);

            
            
            % Derive columns of year, month, day etc to matlab date value
            % for the observed streamflow time-series
            switch size(obsDataFlow,2)-1
                case 3
                    obsDates = datenum(obsDataFlow(:,1), obsDataFlow(:,2), obsDataFlow(:,3));
                case 4
                    obsDates = datenum(obsDataFlow(:,1), obsDataFlow(:,2), obsDataFlow(:,3),obsDataFlow(:,4), zeros(size(obsDataFlow,1),1), zeros(size(obsDataFlow,1),1));
                case 5
                    obsDates = datenum(obsDataFlow(:,1), obsDataFlow(:,2), obsDataFlow(:,3),obsDataFlow(:,4),obsDataFlow(:,5), zeros(size(obsDataFlow,1),1));
                case 6
                    obsDates = datenum(obsDataFlow(:,1), obsDataFlow(:,2), obsDataFlow(:,3),obsDataFlow(:,4),obsDataFlow(:,5),obsDataFlow(:,6));
                otherwise
                    error('The input observed head must be 4 to 7 columns with right hand column being the head and the left columns: year; month; day; hour (optional), minute (optionl), second (optional).');
            end
            
            
            % Use all input data
            obsDataFlow = [obsDates, obsDataFlow(:,end)];
            
            
            % THERE IS A ERROR THAT HAS BEEN CAUSED BY GAPS IN THE
            % STREAMFLOW TIMESERIES. THIS IS CAUSING THE FORCING TIMESERIES
            % TO BE LONGER THAN THE STREAMFLOW TIMESERIES, WHICH DATES ARE
            % USED TO GENERATE THE BASEFLOW OUTPUT...
            %maybe streamflow starts before gw head timeseries or the opposte? causing
            % issues....
            
            % Trim streamflow data to be <= GW head end date
            endDate  = min(obsData(end,1), obsDataFlow(end,1));
            filt = obsDataFlow(:,1)<=endDate;
            obsDataFlow = obsDataFlow(filt,:);
%             filt = climateForcing(:,1)<=endDate;
%             climateForcing = climateForcing(filt,:);
%             t = datenum(boreDataWL(:,1),boreDataWL(:,2),boreDataWL(:,3));
%             
            % Check streamflow for Nans
            filt = isnan(obsDataFlow(:,2));
            obsDataFlow = obsDataFlow(~filt,:);

            % including the flow data into the input data object
            obj.inputData.flow = obsDataFlow;

            
            %% check the SW and GW and how to separate them... 
            
            
            
            %% logical part of how to store the data in the object... 
            
            %% Set Obj parameters for the baseflow calculation
           
            obj.parameters.baseflow = baseflow(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates, [], []);

            
        end
    
        
        function  [params_initial, time_points_head, time_points_streamflow ] = calibration_initialise(obj, t_start, t_end);
            
            
            % Set a flag to indicate that calibration is being undertaken.
            obj.variables.doingCalibration = true;
            
            % Get parameter names and initial values
            [params_initial, obj.variables.param_names] = getParameters(obj);
            
            calibration_initialise@model_TFN(obj, t_start, t_end);
            
            
            % Derive time points for groundwater head objective
            % function calc.
            obsHead = getObservedHead(obj);
            t_filt = find( obsHead(:,1) >=t_start  ...
                & obsHead(:,1) <= t_end );
            time_points_head = obsHead(t_filt,1);
            obj.variables.time_points_head = time_points_head;
            
            
%             % Derive time steps for streamflow data
%             t_filt = find( obj.inputData.flow(:,1) >=t_start  ...
%                 & obj.inputData.flow(:,1) <= t_end );   
%             time_points_streamflow = obj.inputData.flow(t_filt,1);
%             obj.variables.time_points_streamflow = time_points_streamflow;


            % Derive time steps for streamflow data matching the period
            % with gw head obs. data 
            t_filt = find( obj.inputData.flow(:,1) >=time_points_head(1)  ...
                & obj.inputData.flow(:,1) <= time_points_head(end) );   
            time_points_streamflow = obj.inputData.flow(t_filt,1);
            obj.variables.time_points_streamflow = time_points_streamflow;
            
            
            
        end
        
        
        
    function [objFn_joint, objFn_head, objFn_flow, objFn_flow_NSE, objFn_flow_NNSE, objFn_flow_RMSE, objFn_flow_SSE, objFn_flow_bias, totalFlow_sim, colnames, drainage_elevation] = objectiveFunction_joint(params, time_points_head, time_points_streamflow, obj, varargin)
       
     
          % here i wad trying to see if using
          % obj.variables.doingCalibration = false to allow
          % objectiveFunction to use "time_points_streamflow" and later
          % calculate the obj-func would solve the issue. 
%         obj.variables.doingCalibration = false; % false to allow objectiveFunction to use "time_points_streamflow"
%         [objFn_head, h_star, colnames, drainage_elevation] = objectiveFunction(params, time_points_streamflow, obj, false);  % "false" to pass the condition in "islogical(varargin{1})" in line 1826 in model_TFN of "objectiveFunction@model_TFN"
%           % Calcaulte mean head.
%           obj.variables.d = mean(obj.inputData.head( :,2 ));
%         [head, colnames, noise] = solve(obj, time_points_streamflow); % just the deterministic . is it at the same time step (daily)?

        
        % Call objectiveFunction in model_TFN to get head objFn
        [objFn_head, h_star, colnames, drainage_elevation] = objectiveFunction(params, time_points_head, obj, false);  % "false" to pass the condition in "islogical(varargin{1})" in line 1826 in model_TFN of "objectiveFunction@model_TFN"
%         [objFn_head, h_star, colnames, drainage_elevation] = objectiveFunction(params, time_points_streamflow, obj, false);  % "false" to pass the condition in "islogical(varargin{1})" in line 1826 in model_TFN of "objectiveFunction@model_TFN"

        objFn_head; % print to show progress
        
        % Add the drainage elevation to the object. This
        % is just done because the model needs to be solved for the
        % streamflow time steps, and to do so model_TFN assumes the
        % calibration has assigned obj.variables.d.
        obj.variables.d = drainage_elevation;
        obj.variables.doingCalibration = false; % false as used in Hydromod, but should it be "true"?
        
        % Store some variables that are cleared when the model_TFN
        % solve() is called. These will be added back.
        theta_est_indexes_min = obj.variables.theta_est_indexes_min;
        theta_est_indexes_max = obj.variables.theta_est_indexes_max;
        delta_time = obj.variables.delta_time;
        
        % adding the forcingMean in obj.variables."precip or
        % ET".forcingMean, which function "solves" requires
        companants = fieldnames(obj.inputData.componentData);
        nCompanants = size(companants,1);
        
        for j=1:nCompanants  
        obj.variables.(companants{j}).forcingMean(:,1) = mean(obj.variables.(companants{j}).forcingData);
        end 
        
               
        % Call method in model_TFN_SW_GW to return simulated flow
        % (using the simulated head to calculate baseflow at the timepoints
        % with stream obs.)
        [totalFlow_sim, baseFlow, quickFlow] = getStreamFlow(time_points_streamflow, obj, varargin, theta_est_indexes_min, theta_est_indexes_max, delta_time, params);
                
        
        % Call method in model_TFN_SW_GW to return obs flow
        obsFlow = getObservedFlow(obj);
        
        % trim obs. flow data to match the period used for calibreation
        t_filt = find( obsFlow(:,1) >=time_points_streamflow(1)  ...
            & obsFlow(:,1) <= time_points_streamflow(end) );
        obsFlow = obsFlow(t_filt,:);
        
                
        % Calc. flow objFn using:
        
        % NSE
        objFn_flow_NSE = 1 - ( sum((totalFlow_sim - obsFlow(:,2)).^2)./ ...
                       sum((obsFlow(:,2) - mean(obsFlow(:,2))).^2));
        % normalized NSE, where zero is equivalent to -Inf, 0 to 0, and 1 to 1 in NSE (Nossent and Bauwens, EGU 2012)
        objFn_flow_NNSE = 1 / (2- objFn_flow_NSE); 
        % RMSE
        objFn_flow_RMSE = sqrt(sum((totalFlow_sim - obsFlow(:,2)).^2)/ size(obsFlow,1));
        % SSE
        objFn_flow_SSE = sum((totalFlow_sim - obsFlow(:,2)).^2); 
        % Bias
        objFn_flow_bias = sum(totalFlow_sim - obsFlow(:,2))/length(obsFlow(:,2));

        %  IMPORTANT: in AMALGAM we want to minize the obj-func!
        
%         objFn_flow = 1 - objFn_flow_NSE; % (1 - NSE) cause AMALGAM is set up to minimize the Obj-Func.
%         objFn_flow = 1 - objFn_flow_NNSE; % (1 - NNSE) cause AMALGAM is set up to minimize the Obj-Func.
        objFn_flow = objFn_flow_RMSE; % AMALGAM is set up to minimize the Obj-Func.
%         objFn_flow = objFn_flow_SSE; % AMALGAM is set up to minimize the Obj-Func.
%         objFn_flow = abs(objFn_flow_bias); % abs(Bias) cause AMALGAM is set up to minimize the Obj-Func.
        

        
        % merging objFunctions for head and flow
        objFn_joint = [objFn_head, objFn_flow];
        
        % Rten combined objFun and other terms 
        
        % ploting obs total streamflow
%         figure(1)
%         plot( obsFlow(:,1), obsFlow(:,2))
%         title(' streamflow observations')
%         xlabel('Numeric Date ')
%         ylabel('mm/day')
%         grid on
%         ax = gca;
%         ax.FontSize = 13;
        
        % ploting simulated total streamflow
%         figure(2)
%         plot(obsFlow(:,1),totalFlow_sim)
%         title(' streamflow simulation')
%         xlabel('Numeric Date ')
%         ylabel('mm/day')
%         ylim([0 (max(totalFlow_sim)+10)])
%         grid on
%         ax = gca;
%         ax.FontSize = 12;
%         hold on
%         plot(obsFlow(:,1),baseFlow)
%         hold on
%         plot(obsFlow(:,1),quickFlow)
%         hold off
%         legend('totalFlow_sim','baseFlow','quickFlow')

%          obj.variables.doingCalibration = true; % true to allow the parfor loop in AMALGAM - TURN THIS OFF when not using AMALGAM 
    end
    
    % get quickFlow and baseFlow using simulated head and streamflow 
    function [totalFlow, baseFlow, quickFlow] = getStreamFlow(time_points_streamflow, obj, varargin, theta_est_indexes_min, theta_est_indexes_max, delta_time, params)
     
        % solve is calling back objectiveFunction that calls
        % calibration_initialise, maybe take calibration_initialise ouside
        % of objectiveFunction???      
        
     % get simulated head to use to estimate baseflow AT A DAILY TIMESTEP        
     [head, colnames, noise] = solve(obj, time_points_streamflow); % just the deterministic . is it at the same time step (daily)? 
      obj.parameters.variables.doingCalibration = true;
           
      % Add model_TFN variables back that are cleared when the model_TFN
      % solve() is called
      obj.variables.theta_est_indexes_min = theta_est_indexes_min;
      obj.variables.theta_est_indexes_max = theta_est_indexes_max;
      obj.variables.delta_time = delta_time;
      clear theta_est_indexes_min theta_est_indexes_max delta_time
     
     
     % set head in "baseflow" (using setForcingData)
     setForcingData(obj.parameters.baseflow, head, 'head')
     
     % calc. baseflow using setTransformedForcing in "baseflow"
     setTransformedForcing(obj.parameters.baseflow, time_points_streamflow, true)
     
     % get calculated baseflow in baseflow
     baseFlow = getTransformedForcing(obj.parameters.baseflow, time_points_streamflow);
     
     
     % calc. runoff using setTransformedForcing in model_TFN - this is
     % needed to get the derived runoff from the
     % "climateTransform_soilMoistureModels" or "climateTransform_soilMoistureModels_2layer_v2" only for the dates with
     % streamflow observations 
     
     % USING 1-D soil model
%      setTransformedForcing(obj.parameters.climateTransform_soilMoistureModels, time_points_streamflow, true) 
     % USING 2-D soil model
     setTransformedForcing(obj.parameters.climateTransform_soilMoistureModels_2layer_v2, time_points_streamflow, true)
     
     
     
     % detect if there was parameter change for the soil model
%      detectParameterChange(obj.parameters.climateTransform_soilMoistureModels, params(1:2,:)) % didnt make difference..
%      detectParameterChange(obj.parameters.climateTransform_soilMoistureModels_2layer_v2,
%      params(1:2,:)) % didnt make difference, plus this is available in
%      climateTransform_soilMoistureModels and might not work with a climateTransform_soilMoistureModels_2layers_v2 object

     
     % getting the derived forcing data, which includes the quick flow
     % (runoff and interflow)
     [allDerivedForcingData, derivedForcingData_colnames] = getDerivedForcingData(obj, time_points_streamflow);
     
     % getting the forcing data (precip, ET) with the date column
     [allForcingData, forcingData_colnames] = getForcingData(obj);
     
        
     % Initialise total flow 
     obj.variables.totalFlow = [];
     
     % Get the runoff from the derived forcing output
     % USING 2-D soil model
     [tf, column_number] = ismember('runoff_total', derivedForcingData_colnames); % shall we now use runoff_total??
     % USING 1-D soil model
%      [tf, column_number] = ismember('runoff', derivedForcingData_colnames); % shall we now use runoff_total??
     
     if ~tf
         error('runoff_total is not one of the derivedForcingData variables. Check if using 2-layer v2 soil model')
     end

     quickFlow = allDerivedForcingData(:,column_number); % runoff in [mm/day], to get ML/day, mutiply by the catchmentArea - (quickflow from the runoff of the lumped 1-d soil moisture model)
     
     % TO DO:
     % CHECK IF GW HEAD OBS TIME-SERIES LENGTH IS LONGER OR EQUAL TO STREAMFLOW TIME-SERIES.. IT MAY BE CAUSING THE ERROR FOR FORD AND SUNDAY... 
    
     % THERE IS A ERROR THAT HAS BEEN CAUSED BY GAPS IN THE
     % STREAMFLOW TIMESERIES. THIS IS CAUSING THE FORCING TIMESERIES
     % TO BE LONGER THAN THE STREAMFLOW TIMESERIES, WHICH DATES ARE
     % USED TO GENERATE THE BASEFLOW OUTPUT...
            
     % calculate total flow 
     totalFlow = quickFlow + baseFlow; 
     
     % limit the total flow to be above zero
     if totalFlow < 0 
        totalFlow = 0; 
     end
     
     % Storing total flow
     obj.variables.totalFlow = totalFlow;
     
    end
     
    % Get the observed streamflow
    function obsFlow = getObservedFlow(obj)
        obsFlow = obj.inputData.flow;
    end
      

    
    end
end
