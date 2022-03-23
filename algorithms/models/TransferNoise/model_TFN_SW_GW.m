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
        function obj = model_TFN_SW_GW(model_label, bore_ID, obsData, forcingData_data,  forcingData_colnames, siteCoordinates, varargin)           
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
            
            
            % Use sub-class constructor to inherit properties from model_TFN.
            obj = obj@model_TFN(bore_ID, obsData, forcingData_data,  forcingData_colnames, siteCoordinates, varargin{1});

            %% Read in file with obs flow.
            % Note, eventually site_IDs needs to be chnaged from a single
            % string with the bore ID to a vector of stream and bore IDs.
            % Maybe the first could be the stream ID.  

            %   -------- CHANGE THE CACTHMENT ACCORDINGLY  -----------
     
            obsDataFlow = readtable('obsFlow_Brucknell.csv'); % read in the obs flow data. Choose from obsFlow_"Catchment".csv
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
           
            % Choose "baseflow" object from the following options:
            %-----------------------------------------------------
            % baseflow_v1, baseflow_v2, baseflow_m1, baseflow_m2, baseflow_m3,
            % baseflow_m4, baseflow_m5, baseflow_m6, baseflow_m7,
            % baseflow_m8, baseflow_m9, baseflow_bi_1, baseflow_bi_2, baseflow_bi_3, baseflow_bi_4
            %----------------------------------------------------
            
            if contains(model_label,'baseflow_v1')
                obj.parameters.baseflow = baseflow_v1(bore_ID, forcingData_data, forcingData_colnames, siteCoordinates, [], []);
            elseif contains(model_label,'baseflow_v2')
                obj.parameters.baseflow = baseflow_v2(bore_ID, forcingData_data, forcingData_colnames, siteCoordinates, [], []);
            elseif contains(model_label,'baseflow_m1')
                obj.parameters.baseflow = baseflow_m1(bore_ID, forcingData_data, forcingData_colnames, siteCoordinates, [], []);                
            elseif contains(model_label,'baseflow_m2')
                obj.parameters.baseflow = baseflow_m2(bore_ID, forcingData_data, forcingData_colnames, siteCoordinates, [], []);                
            elseif contains(model_label,'baseflow_m3')
                obj.parameters.baseflow = baseflow_m3(bore_ID, forcingData_data, forcingData_colnames, siteCoordinates, [], []);                
            elseif contains(model_label,'baseflow_m4')
                obj.parameters.baseflow = baseflow_m4(bore_ID, forcingData_data, forcingData_colnames, siteCoordinates, [], []);                
            elseif contains(model_label,'baseflow_m5')
                obj.parameters.baseflow = baseflow_m5(bore_ID, forcingData_data, forcingData_colnames, siteCoordinates, [], []);                
            elseif contains(model_label,'baseflow_m6')                
                obj.parameters.baseflow = baseflow_m6(bore_ID, forcingData_data, forcingData_colnames, siteCoordinates, [], []);                
            elseif contains(model_label,'baseflow_m7')
                obj.parameters.baseflow = baseflow_m7(bore_ID, forcingData_data, forcingData_colnames, siteCoordinates, [], []);                
            elseif contains(model_label,'baseflow_m8')
                obj.parameters.baseflow = baseflow_m8(bore_ID, forcingData_data, forcingData_colnames, siteCoordinates, [], []);
            elseif contains(model_label,'baseflow_m9')
                obj.parameters.baseflow = baseflow_m9(bore_ID, forcingData_data, forcingData_colnames, siteCoordinates, [], []);
            elseif contains(model_label,'baseflow_bi_1')
                obj.parameters.baseflow = baseflow_bi_1(bore_ID, forcingData_data, forcingData_colnames, siteCoordinates, [], []);
            elseif contains(model_label,'baseflow_bi_2')
                obj.parameters.baseflow = baseflow_bi_2(bore_ID, forcingData_data, forcingData_colnames, siteCoordinates, [], []);
            elseif contains(model_label,'baseflow_bi_3')
                obj.parameters.baseflow = baseflow_bi_3(bore_ID, forcingData_data, forcingData_colnames, siteCoordinates, [], []);
            elseif contains(model_label,'baseflow_bi_4')
                obj.parameters.baseflow = baseflow_bi_4(bore_ID, forcingData_data, forcingData_colnames, siteCoordinates, [], []);
            else
               error('Please, include a valid baseflow object option in the model_label. Options are: baseflow_v1, baseflow_v2, baseflow_m1, baseflow_m2, baseflow_m3, baseflow_m4, baseflow_m5, baseflow_m6, baseflow_m7, baseflow_m8, baseflow_m9, baseflow_bi_1, baseflow_bi_2, baseflow_bi_3, baseflow_bi_4');
            end
                        
        obj.parameters.baseflow % print the baseflow object to see if indeed using the one assigned
        end
    
        
%         function  [params_initial, time_points_head, time_points_streamflow ] = calibration_initialise(obj, t_start, t_end);
        function  [params_initial, time_points_head, time_points_streamflow ] = calibration_initialise_joint(obj, t_start, t_end);

    
            
            % Set a flag to indicate that calibration is being undertaken.
            obj.variables.doingCalibration = true;
            
            % Get parameter names and initial values
            [params_initial, obj.variables.param_names] = getParameters(obj);
            
			% Using calibration_initialize function from model_TFN object. 
            % calibration_initialise@model_TFN(obj, t_start, t_end); This
            % step includes the properties needed for the drainage convolution and 
            % and GW head Obj-Function and calibration 
            calibration_initialise(obj, t_start, t_end); 

            
            
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
            
            % Create properties necessary for the convolution of runoff and include them
            % into the object
            
            % Setup matrix of indexes for tor at each runoff time_points
            % that match GW head observation period
            % Setup matrix of indexes for tor at each time_points
            filt = obj.inputData.forcingData ( : ,1) <= ceil(time_points_streamflow(end));
            tor = flipud([0:time_points_streamflow(end)  - obj.inputData.forcingData(filt,1)+1]');
            ntor =  size(tor, 1);                                                     
            clear tor;
            
            obj.variables.theta_est_indexes_min_flow = zeros(1,length(time_points_streamflow) );
            obj.variables.theta_est_indexes_max_flow = zeros(1,length(time_points_streamflow) );
                        
            for ii= 1:length(time_points_streamflow)              
                ntheta = sum( obj.inputData.forcingData ( : ,1) <= time_points_streamflow(ii) );                                
                obj.variables.theta_est_indexes_min_flow(ii) = ntor-ntheta;
                obj.variables.theta_est_indexes_max_flow(ii) = max(1,ntor);
            end  
            
            
            
        end
        
        
        
    function [objFn_joint, objFn_head, objFn_flow, objFn_flow_NSE, objFn_flow_NNSE, objFn_flow_RMSE, objFn_flow_SSE, objFn_flow_bias, objFn_flow_KGE, totalFlow_sim, colnames, drainage_elevation] = objectiveFunction_joint(params, time_points_head, time_points_streamflow, obj, varargin)
       
     
          % here i wad trying to see if using
          % obj.variables.doingCalibration = false to allow
          % objectiveFunction to use "time_points_streamflow" and later
          % calculate the obj-func would solve the issue. 
%         obj.variables.doingCalibration = false; % false to allow objectiveFunction to use "time_points_streamflow"
%         [objFn_head, h_star, colnames, drainage_elevation] = objectiveFunction(params, time_points_streamflow, obj, false);  % "false" to pass the condition in "islogical(varargin{1})" in line 1826 in model_TFN of "objectiveFunction@model_TFN"
%           % Calcaulte mean head.
%           obj.variables.d = mean(obj.inputData.head( :,2 ));
%         [head, colnames, noise] = solve(obj, time_points_streamflow); % just the deterministic . is it at the same time step (daily)?

        
        % Call objectiveFunction in model_TFN to get GW head objFn
        [objFn_head, h_star, colnames, drainage_elevation] = objectiveFunction(params, time_points_head, obj, false);  % "false" to pass the condition in "islogical(varargin{1})" in line 1826 in model_TFN of "objectiveFunction@model_TFN"
%         [objFn_head, h_star, colnames, drainage_elevation] = objectiveFunction(params, time_points_streamflow, obj, false);  % "false" to pass the condition in "islogical(varargin{1})" in line 1826 in model_TFN of "objectiveFunction@model_TFN"


        % get soilMoisture from here... 
%       getTransformedForcing(obj.parameters.climateTransform_soilMoistureModels, time_points_streamflow);
%       baseFlow = getTransformedForcing(obj.parameters.baseflow, time_points_streamflow);
       
        % Add the drainage elevation to the object. This
        % is just done because the model needs to be solved for the
        % streamflow time steps, and to do so model_TFN assumes the
        % calibration has assigned obj.variables.d.
%         drainage_elevation
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
        
        %--------------------------------------------------------------------------------------------------------------------------
        % EXAMPLE OF HOW TO EXTRACT FROM THE SOIL-MOISTURE MODEL THE RUNOFF ONLY FOR THE DAYS WITH OBSERVED FLOW, AS THE SOIL MOISTURE    
        % WAS CALCULATED AS PER THE METHOD FOR HEAD THAT USES ALL FORCING DATA PRIOR TO OBS. HEAD.
        
%         % Get the runoff from the forcing tranform function.
%         runoff = getTransformedForcing(obj.parameters.runoffGW_model.parameters.(obj.variables.streamflow_function), obj.variables.streamflow_variable);
%         
%         
%         % Filter the daily runoff data (without gaps) to the dates
%         % having observed flow.
%         % TO DO: The streamflow final obs is after the final head
%         % obs. This is causing the runoff (from the soil model) to
%         % be too short.
%         filt =  runoff(:,1) >= obj.variables.time_points_streamflow(1) ...
%             & runoff(:,1) <= obj.variables.time_points_streamflow(end);
%         runoff = runoff(filt,:);
%         runoff = runoff(obj.variables.runoff_filt,:);
        %--------------------------------------------------------------------------------------------------------------------------
        
        
        
        % Call method in model_TFN_SW_GW to return simulated flow
        % (using the simulated head to calculate baseflow at the timepoints
        % with stream obs.)
        [totalFlow_sim, baseFlow, quickFlow] = getStreamFlow(time_points_streamflow, obj, varargin, theta_est_indexes_min, theta_est_indexes_max, delta_time, params);
                
        
        % Call method in model_TFN_SW_GW to return obs flow
        obsFlow = getObservedFlow(obj);
        
        % trim obs. flow data to match the period used for calibration
        t_filt = find( obsFlow(:,1) >=time_points_streamflow(1)  ...
            & obsFlow(:,1) <= time_points_streamflow(end) );
        obsFlow = obsFlow(t_filt,:);
        
                
        % Calc. flow objFn using:
        
        % NSE
        objFn_flow_NSE = 1 - ( sum((totalFlow_sim(:,2) - obsFlow(:,2)).^2)./ ...
                       sum((obsFlow(:,2) - mean(obsFlow(:,2))).^2));
        % normalized NSE, where zero is equivalent to -Inf, 0.5 to 0, and 1 to 1 in NSE (Nossent and Bauwens, EGU 2012)
        objFn_flow_NNSE = 1 / (2- objFn_flow_NSE); 
        % RMSE
        objFn_flow_RMSE = sqrt(sum((totalFlow_sim(:,2) - obsFlow(:,2)).^2)/ size(obsFlow,1));
        % SSE
        objFn_flow_SSE = sum((totalFlow_sim(:,2) - obsFlow(:,2)).^2); 
        % Bias
        objFn_flow_bias = sum(totalFlow_sim(:,2) - obsFlow(:,2))/length(obsFlow(:,2));
        % KGE 
        w = [1,1,1];                              % no weights specified, use defaults
        c(1) = corr(obsFlow(:,2),totalFlow_sim(:,2));       % r: linear correlation
        c(2) = std(totalFlow_sim(:,2))/std(obsFlow(:,2));   % alpha: ratio of standard deviations
        c(3) = mean(totalFlow_sim(:,2))/mean(obsFlow(:,2)); % beta: bias
        objFn_flow_KGE = 1-sqrt((w(1)*(c(1)-1))^2 + (w(2)*(c(2)-1))^2 + (w(3)*(c(3)-1))^2); % weighted KGE
        if isnan(objFn_flow_KGE)
            objFn_flow_KGE = -9998;
        end

        %  IMPORTANT: in AMALGAM we want to minize the obj-func!
%         objFn_flow = 1 - objFn_flow_NSE;         %1-NSE
%         objFn_flow = 1 - objFn_flow_NNSE;      %1-NNSE
%         objFn_flow = objFn_flow_RMSE;          %RMSE
%         objFn_flow = objFn_flow_SSE;           %SSE
%         objFn_flow = abs(objFn_flow_bias);     %BIAS
        objFn_flow = 1 - objFn_flow_KGE;      %1-KGE
        
        % Merging objFunctions for head and flow
        objFn_joint = [objFn_head, objFn_flow]
        
         % Calibrating only to FLOW using 2 flow obj-fun
%         objFn_joint = [objFn_flow, objFn_flow];
        
        % figure(15);
        % plot(obj.parameters.climateTransform_soilMoistureModels_2layer_v2.variables.SMS)
        % y = obj.parameters.climateTransform_soilMoistureModels_2layer_v2.SMSC;
% %         plot(obj.parameters.climateTransform_soilMoistureModels.variables.SMS)
% %         y = obj.parameters.climateTransform_soilMoistureModels.SMSC;
% %         plot(obj.parameters.climateTransform_soilMoistureModels_v2.variables.SMS)
% %         y = obj.parameters.climateTransform_soilMoistureModels_v2.SMSC;
        % line([0,68000],[10.^(y),10.^(y)])
        
        % figure(16);
        % xx = obj.parameters.climateTransform_soilMoistureModels_2layer_v2.variables.SMS ./ (10 .^ obj.parameters.climateTransform_soilMoistureModels_2layer_v2.SMSC);
% %         xx = obj.parameters.climateTransform_soilMoistureModels.variables.SMS ./ (10 .^ obj.parameters.climateTransform_soilMoistureModels.SMSC);
% %         xx = obj.parameters.climateTransform_soilMoistureModels_v2.variables.SMS ./ (10 .^ obj.parameters.climateTransform_soilMoistureModels_v2.SMSC);
        % plot(xx)
        % title('SMS / SMSC')
        % xlabel('Sub-daily time-steps')
        % ylabel('ratio')
        % ylim([0 1])

        
        
% %         Getting the Observed head/flow vs. Simulated head/flow plots 
%         figure(i+1)
%         scatter (obj.inputData.head(:,2), (h_star(:,2) +  drainage_elevation))
%         title(' Observed Vs. Simulated Head')
%         xlabel('Obs. Head (mAHD)')
%         ylabel('Sim. Head (mAHD)')
%         axis square
% %                 daspect([1 1 1])
%         myRefLine = refline(1);
%         myRefLine.Color = 'r';
%         myRefLine.LineStyle = '--';
% 
%         
%         figure(i+2)
%         plot (obj.inputData.head(:,1), obj.inputData.head(:,2))
%         title(' Observed and Simulated Head')
%         xlabel('Date')
%         ylabel('Head (mAHD)')
%         hold on
%         plot (h_star(:,1), (h_star(:,2) +  drainage_elevation))
%         legend('Obs. Head','Sim. Head')
%         datetick('x', 'dd/mm/yy', 'keepticks')
%         hold off

%         
%         figure(i+3)
%         scatter (obsFlow(:,2), totalFlow_sim(:,2))
%         title(' Observed Vs. Simulated Flow')
%         xlabel('Obs. Flow (mm/day)')
%         ylabel('Sim. Flow (mm/day)')
%         axis square
% %         daspect([1 1 1])
%         myRefLine = refline(1);
%         myRefLine.Color = 'r';
%         myRefLine.LineStyle = '--';
% 

%         figure(i+4)
%         plot (obsFlow(:,1), obsFlow(:,2))
%         title(' Observed and Simulated Flow')
%         xlabel('Date')
%         ylabel('Flow (mm/day)')
%         hold on
%         plot (totalFlow_sim(:,1), totalFlow_sim(:,2))
%         legend('Obs. Flow','Sim. Flow')
%         datetick('x', 'dd/mm/yy', 'keepticks')
%         hold off
%         
%        
%         plotting simulated total streamflow
        % figure(i+5)
        % plot(totalFlow_sim(:,1),totalFlow_sim(:,2))
        % title('observed and simulated streamflow')
        % xlabel('Date')
        % ylabel('mm/day')
        % ylim([0 (max(obsFlow(:,2))+10)])
        % grid on
        % ax = gca;
        % ax.FontSize = 11;
        % hold on
        % plot(totalFlow_sim(:,1),baseFlow)
        % hold on
        % plot(quickFlow(:,1),quickFlow(:,2))
        % hold on
        % plot (obsFlow(:,1), obsFlow(:,2))
        % datetick('x', 'dd/mm/yy', 'keepticks')
        % hold off
        % legend('totalFlow_sim','baseFlow','quickFlow','Observed_Flow')  

        % ploting obs total streamflow
%         figure(i+6)
%         plot( obsFlow(:,1), obsFlow(:,2))
%         title(' streamflow observations')
%         xlabel('Numeric Date ')
%         ylabel('mm/day')
%         grid on
%         ax = gca;
%         ax.FontSize = 13;

               
         obj.variables.doingCalibration = true; % true to allow the parfor loop in AMALGAM - TURN THIS OFF when not using AMALGAM 
    end
    
    % get quickFlow and baseFlow using simulated head and streamflow 
    function [totalFlow, baseFlow, quickFlow] = getStreamFlow(time_points_streamflow, obj, varargin, theta_est_indexes_min, theta_est_indexes_max, delta_time, params)
      
        
     % get simulated head at the streamflow time points        
     [head, colnames, noise] = solve(obj, time_points_streamflow); % just the deterministic . is it at the same time step (daily)? 
      obj.parameters.variables.doingCalibration = true;
           
      % Add model_TFN variables back that are cleared when the model_TFN
      % solve() is called. This is necessary for the next AMALGAM iteration
      obj.variables.theta_est_indexes_min = theta_est_indexes_min;
      obj.variables.theta_est_indexes_max = theta_est_indexes_max;
      obj.variables.delta_time = delta_time;
      clear theta_est_indexes_min theta_est_indexes_max delta_time
           
     % set head in "baseflow" object (using setForcingData)
     setForcingData(obj.parameters.baseflow, head, 'head');
     
     % calc. baseflow using setTransformedForcing in "baseflow" object
     setTransformedForcing(obj.parameters.baseflow, time_points_streamflow, true);
     
     % get calculated baseflow in baseflow
     baseFlow = getTransformedForcing(obj.parameters.baseflow, time_points_streamflow);
         
     
     % TODO: insert the convolution function here for the baseflow following
     % the steps from get_h_star? Add parameters A, b, n into baseflow
     % object so i can use doIRFconvolution of baseflow using
     % responseFunctionPearsons?
     
     
     
     
     
     % % ploting Baseflow vs. Sim. Head - daily time-step
     % figure(i+6)
     % plot (head(:,2), baseFlow)
     % title(' Baseflow vs. Simulated Head')
     % xlabel('Head (mAHD)')
     % ylabel('Baseflow (mm/day)')
     
     
     %--------------------------------------------------------------------------------------------------------------------------
     % EXAMPLE OF HOW TO EXTRACT FROM THE SOIL-MOISTURE MODEL THE RUNOFF ONLY FOR THE DAYS WITH OBSERVED FLOW, AS THE SOIL MOISTURE
     % WAS CALCULATED AS PER THE METHOD FOR HEAD THAT USES ALL FORCING DATA PRIOR TO OBS. HEAD.
     
     % Get the runoff from the forcing tranform function.
     quickFlow_all = getTransformedForcing(obj.parameters.climateTransform_soilMoistureModels_2layer_v2, 'runoff_total', 1, true); % set "true" if need daily data
     

     %--------------------------------------------------------------------------------------------------------------------------
     % TODO: insert the convolution function here for the runoff following
     % the steps from get_h_star? 
     
        
     
     
     
     
     
     % Create filter for the days with streamflow obs.
     [forcingData, forcingData_colnames] = getForcingData(obj);
     time_points_forcing = forcingData(:,1);
     filt =  time_points_forcing <= obj.variables.time_points_streamflow(end);
     time_points_forcing = time_points_forcing(filt);
     
          
     % Add the time steps for the runoff.
     quickFlow = [time_points_forcing quickFlow_all];
     
     % Filter the daily runoff data (without gaps) to the dates
     % having observed flow.
     % TO DO: The streamflow final obs is after the final head
     % obs. This is causing the runoff (from the soil model) to
     % be too short.
     filt =  quickFlow(:,1) >= time_points_streamflow(1) ...
         & quickFlow(:,1) <= time_points_streamflow(end);
     quickFlow = quickFlow(filt,:);
     %quickFlow = quickFlow(obj.variables.runoff_filt,:);
     %--------------------------------------------------------------------------------------------------------------------------
     
     
     
     
     
     
     
     
     
     % calc. runoff using setTransformedForcing in model_TFN - this is
     % needed to get the derived runoff from the
     % "climateTransform_soilMoistureModels" or "climateTransform_soilMoistureModels_2layer_v2" only for the dates with
     % streamflow observations 
     
     % USING 1-layer soil model
%      setTransformedForcing(obj.parameters.climateTransform_soilMoistureModels, time_points_streamflow, true) 
      % USING 1-layer soil model_v2
%      setTransformedForcing(obj.parameters.climateTransform_soilMoistureModels_v2, time_points_streamflow, true)
     % USING 2-layer soil model
%      setTransformedForcing(obj.parameters.climateTransform_soilMoistureModels_2layer_v2, time_points_streamflow, false);
%      setTransformedForcing(obj.parameters.climateTransform_soilMoistureModels_2layer_v2, time_points_streamflow, true);

     % USING 2-layer soil model with threshold behaviour of runoff
%      setTransformedForcing(obj.parameters.climateTransform_soilMoistureModels_2layer_v3, time_points_streamflow, true);

     
     
     % detect if there was parameter change for the soil model
%      detectParameterChange(obj.parameters.climateTransform_soilMoistureModels, params(1:2,:)) % didnt make difference..
%      detectParameterChange(obj.parameters.climateTransform_soilMoistureModels_2layer_v2,
%      params(1:2,:)) % didnt make difference, plus this is available in
%      climateTransform_soilMoistureModels and might not work with a climateTransform_soilMoistureModels_2layers_v2 object

     
     % getting the derived forcing data, which includes the quick flow
     % (runoff and interflow)
     [allDerivedForcingData, derivedForcingData_colnames] = getDerivedForcingData(obj, time_points_streamflow);  % maybe should be getTransformedForcing?
     
     % getting the forcing data (precip, ET) with the date column
%      [allForcingData, forcingData_colnames] = getForcingData(obj);
     
     % get 'infiltration_fractional_capacity', both daily and sub-daily time-steps to quality check
     % daily data
     [tf, column_number] = ismember('infiltration_fractional_capacity', derivedForcingData_colnames); 
     if ~tf
         error('infiltration_fractional_capacity is not one of the derived forcings variables. Check if using 2-layer v2 soil model or model_TFN_SW_GW')
     end
     infiltration_fractional_capacity = allDerivedForcingData(:,column_number);
     % sub-daily data
     SMSnumber=1;
     [infiltration_fractional_capacity_2, isDailyIntegralFlux] = getTransformedForcing(obj.parameters.climateTransform_soilMoistureModels_2layer_v2, 'infiltration_fractional_capacity', SMSnumber, false); % set "true" if need daily data
%     [infiltration_fractional_capacity_2, isDailyIntegralFlux] = getTransformedForcing(obj.parameters.climateTransform_soilMoistureModels, 'infiltration_fractional_capacity', SMSnumber, false); % set "true" if need daily data
%     [infiltration_fractional_capacity_2, isDailyIntegralFlux] = getTransformedForcing(obj.parameters.climateTransform_soilMoistureModels_v2, 'infiltration_fractional_capacity', SMSnumber, false); % set "true" if need daily data

     % ploting infiltration_fractional_capacity - sub-daily time-steps
     % figure(i+7)
     % plot(infiltration_fractional_capacity_2)
     % title('infiltration fractional capacity')
     % xlabel('Sub-daily time-steps')
     % ylabel('ratio')
     % ylim([0 1.20])
     % grid on
     % ax = gca;
     % ax.FontSize = 13;
     
     % ploting infiltration_fractional_capacity - daily time-steps
     % figure(i+8)
% %      plot( time_points_streamflow, infiltration_fractional_capacity)
     % plot( time_points_forcing, infiltration_fractional_capacity)
     % datetick('x', 'dd/mm/yy', 'keepticks');
     % title('infiltration fractional capacity')
     % xlabel('Date')
     % ylabel('ratio')
     % ylim([0 3.2])
     % grid on
     % ax = gca;
     % ax.FontSize = 13;
     
     
     
     % get 'mass_balance_error', both daily and sub-daily time-steps to quality check
     % daily data
     [tf, column_number] = ismember('mass_balance_error', derivedForcingData_colnames); 
     if ~tf
         error('mass_balance_error is not one of the derived forcings variables. Check if using 2-layer v2 soil model or model_TFN_SW_GW')
     end
     mass_balance_error_plot = allDerivedForcingData(:,column_number);
     
     % sub-daily data
     SMSnumber=1;
     [mass_balance_error_plot_2, isDailyIntegralFlux] = getTransformedForcing(obj.parameters.climateTransform_soilMoistureModels_2layer_v2, 'mass_balance_error', SMSnumber, false); % set "true" if need daily data
%      [mass_balance_error_plot_2, isDailyIntegralFlux] = getTransformedForcing(obj.parameters.climateTransform_soilMoistureModels_v2, 'mass_balance_error', SMSnumber, false); % set "true" if need daily data
%      [mass_balance_error_plot_2, isDailyIntegralFlux] = getTransformedForcing(obj.parameters.climateTransform_soilMoistureModels, 'mass_balance_error', SMSnumber, false); % set "true" if need daily data

     
     
     % ploting mass_balance error - daily time-steps
     % figure(i+9)
% %      plot( time_points_streamflow, mass_balance_error_plot)
     % plot( time_points_forcing, mass_balance_error_plot)
     % datetick('x', 'dd/mm/yy', 'keepticks');
     % title('mass balance error')
     % xlabel('Date')
     % ylabel('mm/day')
     % %      ylim([0 3.2])
     % grid on
     % ax = gca;
     % ax.FontSize = 13;
     
     % ploting mass_balance_error - sub-daily time-steps
     % figure(i+10)
     % plot(mass_balance_error_plot_2)
     % title('mass balance error')
     % xlabel('Sub-daily time-steps')
     % ylabel('mm/sub-day')
     % %      ylim([0 1.20])
     % grid on
     % ax = gca;
     % ax.FontSize = 13;
     
     
     
     % get 'infiltration', both daily and sub-daily time-steps to quality check
     % daily data
     [tf, column_number] = ismember('infiltration', derivedForcingData_colnames); 
     if ~tf
         error('infiltration is not one of the derived forcings variables. Check if using 2-layer v2 soil model or model_TFN_SW_GW')
     end
     infiltration = allDerivedForcingData(:,column_number);
     % sub-daily data
     SMSnumber=1;
     [infiltration_2, isDailyIntegralFlux] = getTransformedForcing(obj.parameters.climateTransform_soilMoistureModels_2layer_v2, 'infiltration', SMSnumber, false); % set "true" if need daily data
%      [infiltration_2, isDailyIntegralFlux] = getTransformedForcing(obj.parameters.climateTransform_soilMoistureModels_v2, 'infiltration', SMSnumber, false); % set "true" if need daily data
%      [infiltration_2, isDailyIntegralFlux] = getTransformedForcing(obj.parameters.climateTransform_soilMoistureModels, 'infiltration', SMSnumber, false); % set "true" if need daily data

     
      % get 'SMS' (soil moisture), both daily and sub-daily time-steps to quality check
     % daily data
     [tf, column_number] = ismember('SMS', derivedForcingData_colnames); 
     if ~tf
         error('SMS is not one of the derived forcings variables. Check if using 2-layer v2 soil model or model_TFN_SW_GW')
     end
     soil_moisture = allDerivedForcingData(:,column_number);
     % sub-daily data
     %      SMSnumber=1;
     %      [soil_moisture_2, isDailyIntegralFlux] = getTransformedForcing(obj.parameters.climateTransform_soilMoistureModels_2layer_v2, 'SMS', SMSnumber, false); % it doesnt work for SMS cause of the original MATLAB soilMoisture code.
     soil_moisture_2 = obj.parameters.climateTransform_soilMoistureModels_2layer_v2.variables.SMS ;   
%      soil_moisture_2 = obj.parameters.climateTransform_soilMoistureModels_v2.variables.SMS ;
%      soil_moisture_2 = obj.parameters.climateTransform_soilMoistureModels.variables.SMS ;


          
     %      ploting infiltration vs. soil moisture - daily time-steps
     % figure(i+11)
     % scatter(soil_moisture,infiltration )
     % title('infiltration vs. soil moisture')
     % xlabel('Soil moisture (mm)')
     % ylabel('infiltration (mm/day)')
     % %      ylim([0 1.20])
     % grid on
     % ax = gca;
     % ax.FontSize = 13;
     
     %      ploting infiltration vs. soil moisture - sub-daily time-steps
     % figure(i+12)
     % scatter(soil_moisture_2,infiltration_2 )
     % title('infiltration vs. soil moisture')
     % xlabel('Soil moisture (mm)')
     % ylabel('infiltration (mm/sub-day)')
     % %      ylim([0 1.20])
     % grid on
     % ax = gca;
     % ax.FontSize = 13;
             
          
     % Initialise total flow 
     obj.variables.totalFlow = [];
     
     % Get the runoff from the derived forcing output
     % USING 2-layer soil model
     [tf, column_number] = ismember('runoff_total', derivedForcingData_colnames); % shall we now use runoff_total??
     % USING 1-layer soil model
%      [tf, column_number] = ismember('runoff', derivedForcingData_colnames); % shall we now use runoff_total??
     
     if ~tf
         error('runoff_total is not one of the derivedForcingData variables. Check if using 2-layer v2 soil model')
     end

     quickFlow2 = allDerivedForcingData(:,column_number); % runoff in [mm/day], to get ML/day, mutiply by the catchmentArea - (quickflow from the runoff of the lumped 1-d soil moisture model)
     
     % sub-daily data
     SMSnumber=1;
     [quickFlow_22, isDailyIntegralFlux] = getTransformedForcing(obj.parameters.climateTransform_soilMoistureModels_2layer_v2, 'runoff_total', SMSnumber, false); % set "true" if need daily data
%      [quickFlow_2, isDailyIntegralFlux] = getTransformedForcing(obj.parameters.climateTransform_soilMoistureModels_v2, 'runoff', SMSnumber, false); % set "true" if need daily data
%      [quickFlow_2, isDailyIntegralFlux] = getTransformedForcing(obj.parameters.climateTransform_soilMoistureModels, 'runoff', SMSnumber, false); % set "true" if need daily data
     
     % TO DO:
     % CHECK IF GW HEAD OBS TIME-SERIES LENGTH IS LONGER OR EQUAL TO STREAMFLOW TIME-SERIES.. IT MAY BE CAUSING THE ERROR FOR FORD AND SUNDAY... 
    
     % THERE IS A ERROR THAT HAS BEEN CAUSED BY GAPS IN THE
     % STREAMFLOW TIMESERIES. THIS IS CAUSING THE FORCING TIMESERIES
     % TO BE LONGER THAN THE STREAMFLOW TIMESERIES, WHICH DATES ARE
     % USED TO GENERATE THE BASEFLOW OUTPUT...
            
     % calculate total flow 
     totalFlow = max(0, quickFlow(:,2) + baseFlow); % limit the total flow to be equal or above zero
     totalFlow = [quickFlow(:,1) totalFlow];
     
     % Storing total flow
     obj.variables.totalFlow = totalFlow;
     
     
     % ploting quickflow vs. soil moisture - daily time-steps
     % figure(i+13)
     % scatter(soil_moisture, quickFlow2 )
     % title('quick-flow vs. soil moisture')
     % xlabel('Soil moisture (mm)')
     % ylabel('quick-flow (mm/day)')
     % %      ylim([0 1.20])
     % grid on
     % ax = gca;
     % ax.FontSize = 13;
     
     % ploting baseflow vs. soil moisture - sub-daily time-steps
     % figure(i+14)
     % scatter(soil_moisture_2, quickFlow_22 )
     % title('quick-flow vs. soil moisture')
     % xlabel('Soil moisture (mm)')
     % ylabel('quick-flow (mm/sub-day)')
     % %      ylim([0 1.20])
     % grid on
     % ax = gca;
     % ax.FontSize = 13;
     
     % ploting baseflow vs. soil moisture - sub-daily time-steps
     % figure(i+41)
     % ratio_test= quickFlow_all - quickFlow2;
     % plot(ratio_test)
     % title('test - quick-flow call workflow')
     % ylabel('difference')
     % %      ylim([0 1.20])
     % grid on
     % ax = gca;
     % ax.FontSize = 13;
     
     
%      figure(i+40)
%      x = time_points_forcing; % time_points_streamflow;
%      y1 = soil_moisture;
%      y2 = quickFlow_all;
%      y3 = infiltration;
%      y4 = infiltration_fractional_capacity;
%      y5 = mass_balance_error_plot;
%      tiledlayout(5,1) % Requires R2019b or later
%         
%      % Top plot
%      nexttile
%      plot(x,y1)
%      title('Soil moisture time-series')
%      datetick('x', 'dd/mm/yy', 'keepticks');
%      xlabel('date')
%      ylabel('soil moisture - upper layer (mm)')
%      % Bottom plot
%      nexttile
%      plot(x,y2)
%      title('quick-flow time-series')
%      datetick('x', 'dd/mm/yy', 'keepticks');
%      xlabel('date')
%      ylabel('quick-flow (mm/day)')
%      % Bottom plot
%      nexttile
%      plot(x,y3)
%      title('infiltration time-series')
%      datetick('x', 'dd/mm/yy', 'keepticks');
%      xlabel('date')
%      ylabel('infiltration (mm/day)')
%      % Bottom plot
%      nexttile
%      plot(x,y4)
%      title('infiltration fractional capacity time-series')
%      datetick('x', 'dd/mm/yy', 'keepticks');
%      xlabel('date')
%      ylabel('infiltration_fractional_capacity (ratio)')
%      % Bottom plot
%      nexttile
%      plot(x,y5)
%      title('mass balance error time-series')
%      datetick('x', 'dd/mm/yy', 'keepticks');
%      xlabel('date')
%      ylabel('mass balance error (mm/day)')
     
     
     
     % figure(41);
     % xx = soil_moisture ./ (10 .^ obj.parameters.climateTransform_soilMoistureModels_2layer_v2.SMSC);
     % %         xx = obj.parameters.climateTransform_soilMoistureModels.variables.SMS ./ (10 .^ obj.parameters.climateTransform_soilMoistureModels.SMSC);
     % %         xx = obj.parameters.climateTransform_soilMoistureModels_v2.variables.SMS ./ (10 .^ obj.parameters.climateTransform_soilMoistureModels_v2.SMSC);
     % scatter(xx,infiltration_fractional_capacity)
     % title('infiltration capacity VS.(SMS/SMSC)')
     % xlabel('SMS/SMSC');
     % ylabel('Infilt cap.');
     % ylim([0 1])
     % xlim([0 1])

     

     
    % checking parameters used in the model            
     [params, param_names] = getParameters(obj);
     params(2:end), param_names(2:end,2)
     
    end
     
    % Get the observed streamflow
    function obsFlow = getObservedFlow(obj)
        obsFlow = obj.inputData.flow;
    end
      

    
    end
end
