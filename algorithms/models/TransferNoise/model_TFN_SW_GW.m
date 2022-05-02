classdef model_TFN_SW_GW < model_TFN & model_abstract
    % Class definition for Transfer Function Noise (TFN) model for use with
    % HydroSight to jointly calibrate and simulate Stremflow and GW head. 

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
				'   - Bonotto, Peterson, Fowler, & Western (2022), HydroSight SW-GW: lumped rainfall-runoff model for the joint simulation of streamflow and groundwater in a drying climate, Geoscientific Model Development , , –', ...
			    '', ...
				'   - Bonotto, Peterson, Fowler, & Western (2022), Can the joint simulation of daily streamflow and groundwater head help to explain the Millennium Drought hydrology?, Water Resour. Res., , –\', ...
                '', ...
                '   - Peterson, T. J., and A. W. Western (2014), Nonlinear time-series modeling of unconfined groundwater head, Water Resour. Res., 50, 8330–8355, doi:10.1002/2013WR014800.', ...
                '', ...
                '   - Shapoori V., Peterson T. J., Western A. W. and Costelloe J. F., (2015), Top-down groundwater hydrograph time series modeling for climate-pumping decomposition. Hydrogeology Journal'};

        end
    end



    %%  PUBLIC METHODS

    methods


        %% Model constructor
        function obj = model_TFN_SW_GW(model_label, bore_ID, obsData, obsDataFlow, forcingData_data,  forcingData_colnames, siteCoordinates, varargin)
            % model_TFN_SW_GW constructs for linear and nonlinear Transfer Function Noise model for the joint calibration and simulation of GW head and streamflow
            
            
            % Use sub-class constructor to inherit properties from model_TFN.
            obj = obj@model_TFN(bore_ID, obsData, forcingData_data,  forcingData_colnames, siteCoordinates, varargin{1});

            % including the model_name into the model object
            obj.inputData.model_name = model_label;

            % including the plot_hydrographs flag into the model object.
            % This is used if user wants to see the simulated and observed
            % GW and SW hydrographs during each model iteration. 
			% By default, it is set as false.
            obj.inputData.plot_hydrographs = false;

            % including the save_output_data flag into the model object.
            % This is used if user wants to save the simulated and observed
            % GW and SW hydrographs.
			% By default, it is set as false.
            obj.inputData.save_output_data = false;
            
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


            % Use all streamflow input data
            obsDataFlow = [obsDates, obsDataFlow(:,end)];
          

            % Trim streamflow data to be <= GW head end date
            endDate  = min(obsData(end,1), obsDataFlow(end,1));
            filt = obsDataFlow(:,1)<=endDate;
            obsDataFlow = obsDataFlow(filt,:);
            
            % Check streamflow for Nans
            filt = isnan(obsDataFlow(:,2));
            obsDataFlow = obsDataFlow(~filt,:);

            % including the flow data into the input data object
            obj.inputData.flow = obsDataFlow;


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

            obj.parameters.baseflow % print the baseflow object to see if indeed it is using the one assigned
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
         

            % Derive time steps for streamflow data matching the period
            % with gw head obs. data
            t_filt = find( obj.inputData.flow(:,1) >=time_points_head(1)  ...
                & obj.inputData.flow(:,1) <= time_points_head(end) );
            time_points_streamflow = obj.inputData.flow(t_filt,1);
            obj.variables.time_points_streamflow = time_points_streamflow;

            
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
         

            % Call objectiveFunction in model_TFN to get GW head objFn
            [objFn_head, h_star, colnames, drainage_elevation] = objectiveFunction(params, time_points_head, obj, false);  
            
            % Add the drainage elevation to the object. This
            % is just done because the model needs to be solved for the
            % streamflow time steps, and to do so model_TFN assumes the
            % calibration has assigned obj.variables.d.            
            obj.variables.d = drainage_elevation;
            obj.variables.doingCalibration = false; 

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

            % trim obs. flow data to match the period used for calibration
            t_filt = find( obsFlow(:,1) >=time_points_streamflow(1)  ...
                & obsFlow(:,1) <= time_points_streamflow(end) );
            obsFlow = obsFlow(t_filt,:);


            % Calc. stremflow objFunctions:

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
            w = [1,1,1];                                        % no weights specified, use defaults
            c(1) = corr(obsFlow(:,2),totalFlow_sim(:,2));       % r: linear correlation
            c(2) = std(totalFlow_sim(:,2))/std(obsFlow(:,2));   % alpha: ratio of standard deviations
            c(3) = mean(totalFlow_sim(:,2))/mean(obsFlow(:,2)); % beta: bias
            objFn_flow_KGE = 1-sqrt((w(1)*(c(1)-1))^2 + (w(2)*(c(2)-1))^2 + (w(3)*(c(3)-1))^2); % weighted KGE
            if isnan(objFn_flow_KGE)
                objFn_flow_KGE = -9998;
            end

            % Choosing the streamflow objective function for AMALGAM. 
			% IMPORTANT: in AMALGAM we want to minize the obj-func!
            %         objFn_flow = 1 - objFn_flow_NSE;       %1-NSE
            %         objFn_flow = 1 - objFn_flow_NNSE;      %1-NNSE
            %         objFn_flow = objFn_flow_RMSE;          %RMSE
            %         objFn_flow = objFn_flow_SSE;           %SSE
            %         objFn_flow = abs(objFn_flow_bias);     %BIAS
            objFn_flow = 1 - objFn_flow_KGE;               %1-KGE


            % Get the parameter names for the soil moisture component
            if sum(strcmp(fieldnames(obj.parameters), "climateTransform_soilMoistureModels_v2"))>0
                [params, param_names] = getParameters(obj.parameters.climateTransform_soilMoistureModels_v2);

            elseif sum(strcmp(fieldnames(obj.parameters), "climateTransform_soilMoistureModels_interflow"))>0
                [params, param_names] = getParameters(obj.parameters.climateTransform_soilMoistureModels_interflow);
            end

            % check if parameters are valid according to physical bounds and Budyko criteria
            if sum(strcmp(fieldnames(obj.parameters), "climateTransform_soilMoistureModels_v2"))>0
                validParams = getParameterValidity(obj.parameters.climateTransform_soilMoistureModels_v2, params, time_points_streamflow);

            elseif sum(strcmp(fieldnames(obj.parameters), "climateTransform_soilMoistureModels_interflow"))>0
                validParams = getParameterValidity(obj.parameters.climateTransform_soilMoistureModels_interflow, params, time_points_streamflow);
            end

            % Checking if parameter are valid according to the mass-balance criteria between total GW-recharge
            % (free-drainage) and total baseflow. It has to be done here as it uses both soilMoisture and baseflow components
            % Get the parameter names for all model components
            validParams2 = getMassBalanceValidity(obj,time_points_streamflow);

            %  if parameters are not valid, set ObjFun to large values so AMALGAM don't propagate them in the evolutionary optmization.
            if any(~validParams) | any(~validParams2)
                % Merging objFunctions for head and flow
                objFn_joint = [99999, 99999]
            else                
                objFn_joint = [objFn_head, objFn_flow]
            end


            if obj.inputData.plot_hydrographs == false
                % no hydrograph diagnosis plot is generated
            else
                
				% Creating the Observed head/flow vs. Simulated head/flow plots

                %  plotting scatter_obs_sim_daily_GWhead
                figure(1)
                scatter (obj.inputData.head(:,2), (h_star(:,2) +  drainage_elevation))
                title(' Observed Vs. Simulated Head')
                xlabel('Obs. Head (mAHD)')
                ylabel('Sim. Head (mAHD)')
                axis square
                %                 daspect([1 1 1])
                myRefLine = refline(1);
                myRefLine.Color = 'r';
                myRefLine.LineStyle = '--';

                %  plotting obs_sim_daily_head
                figure(2)
                plot (obj.inputData.head(:,1), obj.inputData.head(:,2))
                title(' Observed and Simulated Head')
                xlabel('Date')
                ylabel('Head (mAHD)')
                hold on
                plot (h_star(:,1), (h_star(:,2) +  drainage_elevation))
                legend('Obs. Head','Sim. Head')
                % datetick('x', 'dd/mm/yy', 'keepticks')
                dynamicDateTicks()
                hold off

                %  plotting scatter_obs_sim_daily_runoff
                figure(3)
                scatter (obsFlow(:,2), totalFlow_sim(:,2))
                title(' Observed Vs. Simulated Flow')
                xlabel('Obs. Flow (mm/day)')
                ylabel('Sim. Flow (mm/day)')
                axis square
                %         daspect([1 1 1])
                myRefLine = refline(1);
                myRefLine.Color = 'r';
                myRefLine.LineStyle = '--';

                %  plotting obs_sim_daily_runoff
                figure(4) 
                plot (obsFlow(:,1), obsFlow(:,2))
                title(' Observed and Simulated Flow')
                xlabel('Date')
                ylabel('Flow (mm/day)')
                hold on
                plot (totalFlow_sim(:,1), totalFlow_sim(:,2))
                legend('Obs. Flow','Sim. Flow')
                % datetick('x', 'dd/mm/yy', 'keepticks')
                dynamicDateTicks()
                hold off


                %  plotting obs_sim_daily_baseflow_runoff
                figure(5)
                plot(totalFlow_sim(:,1),totalFlow_sim(:,2))
                title('observed and simulated streamflow')
                xlabel('Date')
                ylabel('mm/day')
                ylim([0 (max(obsFlow(:,2))+10)])
                grid on
                ax = gca;
                ax.FontSize = 11;
                hold on
                plot(totalFlow_sim(:,1),baseFlow)
                hold on
                plot(quickFlow(:,1),quickFlow(:,2))
                hold on
                plot (obsFlow(:,1), obsFlow(:,2))
                % datetick('x', 'dd/mm/yy', 'keepticks')
                dynamicDateTicks()
                hold off
                legend('totalFlow_sim','baseFlow','quickFlow','Observed_Flow')

                % ploting obs_daily_runoff
                figure(6)
                plot( obsFlow(:,1), obsFlow(:,2))
                title(' streamflow observations')
                xlabel('Date ')
                ylabel('mm/day')
                grid on
                ax = gca;
                ax.FontSize = 13;
                % datetick('x', 'dd/mm/yy', 'keepticks')
                dynamicDateTicks()

                % ploting daily_baseflow
                figure(7)
                plot(totalFlow_sim(:,1),baseFlow)
                title(' baseflow simulated')
                xlabel('Date ')
                ylabel('mm/day')
                % datetick('x', 'dd/mm/yy', 'keepticks')
                dynamicDateTicks()
                grid on
                ax = gca;
                ax.FontSize = 13;
                legend('baseFlow')


                figure(8); % subdaily_SMS_SMSC
                if sum(strcmp(fieldnames(obj.parameters), "climateTransform_soilMoistureModels_v2"))>0
                    plot(obj.parameters.climateTransform_soilMoistureModels_v2.variables.SMS, 'g')
                    y = obj.parameters.climateTransform_soilMoistureModels_v2.SMSC;
                elseif sum(strcmp(fieldnames(obj.parameters), "climateTransform_soilMoistureModels_interflow"))>0
                    plot(obj.parameters.climateTransform_soilMoistureModels_interflow.variables.SMS, 'g')
                    y = obj.parameters.climateTransform_soilMoistureModels_interflow.SMSC;
                end
                line([0,68000],[10.^(y),10.^(y)])
                xlabel('Sub-daily time-steps')
                ylabel('Soil Moisture')
                % datetick('x', 'dd/mm/yy', 'keepticks')
                legend('SMS', 'SMSC')


                figure(9); % subdaily_EPS                
                if sum(strcmp(fieldnames(obj.parameters), "climateTransform_soilMoistureModels_v2"))>0
                    xx = obj.parameters.climateTransform_soilMoistureModels_v2.variables.SMS ./ (10 .^ obj.parameters.climateTransform_soilMoistureModels_v2.SMSC);
                elseif sum(strcmp(fieldnames(obj.parameters), "climateTransform_soilMoistureModels_interflow"))>0
                    xx = obj.parameters.climateTransform_soilMoistureModels_interflow.variables.SMS ./ (10 .^ obj.parameters.climateTransform_soilMoistureModels_interflow.SMSC);
                end
                plot(xx)
                title('SMS / SMSC')
                xlabel('Sub-daily time-steps')
                ylabel('ratio')
                ylim([0 1])
                % datetick('x', 'dd/mm/yy', 'keepticks')
                legend('(SMS / SMSC)')


                %  plotting ZOOM_obs_sim_daily_baseflow_runoff 
                %  choosing the ZOOM PERIOD
                zoom_min = datenum(2007, 03, 01);
                zoom_max = datenum(2008, 03, 01);
                t_filt = find( totalFlow_sim(:,1) >=zoom_min  ...
                    & totalFlow_sim(:,1) <= zoom_max );                
                figure(10)
                plot(totalFlow_sim(t_filt,1),totalFlow_sim(t_filt,2))
                title('observed and simulated streamflow')
                xlabel('Date')
                ylabel('mm/day')
                ylim([0 (max(obsFlow(t_filt,2))+2.5)])
                grid on
                ax = gca;
                ax.FontSize = 11;
                hold on
                plot(totalFlow_sim(t_filt,1),baseFlow(t_filt,1))
                hold on
                plot(quickFlow(t_filt,1),quickFlow(t_filt,2))
                hold on
                plot (obsFlow(t_filt,1), obsFlow(t_filt,2))
                datetick('x', 'dd/mm/yy', 'keepticks')
%                 dynamicDateTicks()
                hold off
                legend('totalFlow_sim','baseFlow','quickFlow','Observed_Flow')

            end


            % Save diagnosis plot if not running in testing_only mode
            if obj.inputData.save_output_data == true

                model_label = obj.inputData.model_name;

				% Path used to store the hydrographs
				folder = 'C:\Users\bonottog\OneDrive - The University of Melbourne (1)\1 - UNIMELB\5 - HydroSight\10 - Run Results\Interflow_Scenarios\500k';

                f = figure(1);
                set(f, 'Color', 'w');
                A1 = model_label;
                A2 = 'scatter_obs_sim_daily_GWhead';
                formatSpec = '%1$s %2$s';
                Filename = sprintf(formatSpec,A1,A2);                
                saveas(f, fullfile(folder, Filename), 'png');

                f = figure(2);
                set(f, 'Color', 'w');
                A1 = model_label;
                A2 = 'obs_sim_daily_head';
                formatSpec = '%1$s %2$s';
                Filename = sprintf(formatSpec,A1,A2);                
                saveas(f, fullfile(folder, Filename), 'png');

                f = figure(3);
                set(f, 'Color', 'w');
                A1 = model_label;
                A2 = 'scatter_obs_sim_daily_runoff';
                formatSpec = '%1$s %2$s';
                Filename = sprintf(formatSpec,A1,A2);
                saveas(f, fullfile(folder, Filename), 'png');

                f = figure(4);
                set(f, 'Color', 'w');
                A1 = model_label;
                A2 = 'obs_sim_daily_runoff';
                formatSpec = '%1$s %2$s';
                Filename = sprintf(formatSpec,A1,A2);
                saveas(f, fullfile(folder, Filename), 'png');

                f = figure(5);
                set(f, 'Color', 'w');
                A1 = model_label;
                A2 = 'obs_sim_daily_baseflow_runoff';
                formatSpec = '%1$s %2$s';
                Filename = sprintf(formatSpec,A1,A2);
                saveas(f, fullfile(folder, Filename), 'png');

                f = figure(6);
                set(f, 'Color', 'w');
                A1 = model_label;
                A2 = 'obs_daily_runoff';
                formatSpec = '%1$s %2$s';
                Filename = sprintf(formatSpec,A1,A2);
                saveas(f, fullfile(folder, Filename), 'png');

                f = figure(7);
                set(f, 'Color', 'w');
                A1 = model_label;
                A2 = 'daily_baseflow';
                formatSpec = '%1$s %2$s';
                Filename = sprintf(formatSpec,A1,A2);
                saveas(f, fullfile(folder, Filename), 'png');

                f = figure(8);
                set(f, 'Color', 'w');
                A1 = model_label;
                A2 = 'subdaily_SMS_SMSC';
                formatSpec = '%1$s %2$s';
                Filename = sprintf(formatSpec,A1,A2);
                saveas(f, fullfile(folder, Filename), 'png');

                f = figure(9);
                set(f, 'Color', 'w');
                A1 = model_label;
                A2 = 'subdaily_EPS';
                formatSpec = '%1$s %2$s';
                Filename = sprintf(formatSpec,A1,A2);
                saveas(f, fullfile(folder, Filename), 'png');

                f = figure(10);
                set(f, 'Color', 'w');
                A1 = model_label;
                A2 = 'ZOOM_obs_sim_daily_baseflow_runoff';
                formatSpec = '%1$s %2$s';
                Filename = sprintf(formatSpec,A1,A2);
                saveas(f, fullfile(folder, Filename), 'png');


            else
                % continue without saving the hydrograph plots.
            end

            obj.variables.doingCalibration = true; % true to allow the parfor loop in AMALGAM - TURN THIS OFF when not using AMALGAM

        end

        % get quickFlow and baseFlow using simulated head and streamflow
        function [totalFlow, baseFlow, quickFlow] = getStreamFlow(time_points_streamflow, obj, varargin, theta_est_indexes_min, theta_est_indexes_max, delta_time, params)


            % get simulated head at the streamflow time points
            [head, colnames, noise] = solve(obj, time_points_streamflow); 
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

            % Get the runoff from the forcing tranform function.
            if sum(strcmp(fieldnames(obj.parameters), "climateTransform_soilMoistureModels_v2"))>0
                quickFlow_all = getTransformedForcing(obj.parameters.climateTransform_soilMoistureModels_v2, 'runoff', 1, true); % set "true" to get daily data
            elseif sum(strcmp(fieldnames(obj.parameters), "climateTransform_soilMoistureModels_interflow"))>0
                quickFlow_all = getTransformedForcing(obj.parameters.climateTransform_soilMoistureModels_interflow, 'runoff_total', 1, true); 
            elseif sum(strcmp(fieldnames(obj.parameters), "climateTransform_soilMoistureModels_2layer_v2"))>0
                quickFlow_all = getTransformedForcing(obj.parameters.climateTransform_soilMoistureModels_2layer_v2, 'runoff_total', 1, true); 
            end

            % Create filter for the days with streamflow obs.
            [forcingData, forcingData_colnames] = getForcingData(obj);
            time_points_forcing = forcingData(:,1);
            filt =  time_points_forcing <= obj.variables.time_points_streamflow(end); % cause forcing data goes beyond more recent observed flow.
            time_points_forcing = time_points_forcing(filt);

            % Add the time steps for the runoff.
            quickFlow = [time_points_forcing quickFlow_all];

            % Filter the daily runoff data (without gaps) to the dates
            % having observed flow.
            filt =  quickFlow(:,1) >= time_points_streamflow(1) ...
                & quickFlow(:,1) <= time_points_streamflow(end);
            quickFlow = quickFlow(filt,:);
            
            
            % getting the derived forcing data, which includes the quick flow
            % (runoff and interflow)
            [allDerivedForcingData, derivedForcingData_colnames] = getDerivedForcingData(obj, time_points_streamflow);  
            

            % get 'infiltration_fractional_capacity', both daily and sub-daily time-steps to quality check
            % daily data
            [tf, column_number] = ismember('infiltration_fractional_capacity', derivedForcingData_colnames);
            if ~tf
                error('infiltration_fractional_capacity is not one of the derived forcings variables. Check if using new soil models or model_TFN_SW_GW')
            end
            infiltration_fractional_capacity = allDerivedForcingData(:,column_number);
            
            % sub-daily data
            SMSnumber=1;
            if sum(strcmp(fieldnames(obj.parameters), "climateTransform_soilMoistureModels_v2"))>0
                [infiltration_fractional_capacity_2, isDailyIntegralFlux] = getTransformedForcing(obj.parameters.climateTransform_soilMoistureModels_v2, 'infiltration_fractional_capacity', SMSnumber, false); % set "true" if need daily data
            elseif sum(strcmp(fieldnames(obj.parameters), "climateTransform_soilMoistureModels_interflow"))>0
                [infiltration_fractional_capacity_2, isDailyIntegralFlux] = getTransformedForcing(obj.parameters.climateTransform_soilMoistureModels_interflow, 'infiltration_fractional_capacity', SMSnumber, false); % set "true" if need daily data
            elseif sum(strcmp(fieldnames(obj.parameters), "climateTransform_soilMoistureModels_2layer_v2"))>0
                [infiltration_fractional_capacity_2, isDailyIntegralFlux] = getTransformedForcing(obj.parameters.climateTransform_soilMoistureModels_2layer_v2, 'infiltration_fractional_capacity', SMSnumber, false); % set "true" if need daily data
            end


            % get 'mass_balance_error', both daily and sub-daily time-steps to quality check
            % daily data
            [tf, column_number] = ismember('mass_balance_error', derivedForcingData_colnames);
            if ~tf
                error('mass_balance_error is not one of the derived forcings variables. Check if using new soil models or model_TFN_SW_GW')
            end
            mass_balance_error_plot = allDerivedForcingData(:,column_number);

            % sub-daily data
            SMSnumber=1;

            if sum(strcmp(fieldnames(obj.parameters), "climateTransform_soilMoistureModels_v2"))>0
                [mass_balance_error_plot_2, isDailyIntegralFlux] = getTransformedForcing(obj.parameters.climateTransform_soilMoistureModels_v2, 'mass_balance_error', SMSnumber, false); % set "true" if need daily data
            elseif sum(strcmp(fieldnames(obj.parameters), "climateTransform_soilMoistureModels_interflow"))>0
                [mass_balance_error_plot_2, isDailyIntegralFlux] = getTransformedForcing(obj.parameters.climateTransform_soilMoistureModels_interflow, 'mass_balance_error', SMSnumber, false); % set "true" if need daily data
            elseif sum(strcmp(fieldnames(obj.parameters), "climateTransform_soilMoistureModels_2layer_v2"))>0
                [mass_balance_error_plot_2, isDailyIntegralFlux] = getTransformedForcing(obj.parameters.climateTransform_soilMoistureModels_2layer_v2, 'mass_balance_error', SMSnumber, false); % set "true" if need daily data
            end


            % get 'infiltration', both daily and sub-daily time-steps to quality check
            % daily data
            [tf, column_number] = ismember('infiltration', derivedForcingData_colnames);
            if ~tf
                error('infiltration is not one of the derived forcings variables. Check if using 2-layer v2 soil model or model_TFN_SW_GW')
            end
            infiltration = allDerivedForcingData(:,column_number);
            % sub-daily data
            SMSnumber=1;
            
            if sum(strcmp(fieldnames(obj.parameters), "climateTransform_soilMoistureModels_v2"))>0
                [infiltration_2, isDailyIntegralFlux] = getTransformedForcing(obj.parameters.climateTransform_soilMoistureModels_v2, 'infiltration', SMSnumber, false); % set "true" if need daily data
            elseif sum(strcmp(fieldnames(obj.parameters), "climateTransform_soilMoistureModels_interflow"))>0
                [infiltration_2, isDailyIntegralFlux] = getTransformedForcing(obj.parameters.climateTransform_soilMoistureModels_interflow, 'infiltration', SMSnumber, false); % set "true" if need daily data
            elseif sum(strcmp(fieldnames(obj.parameters), "climateTransform_soilMoistureModels_2layer_v2"))>0
                [infiltration_2, isDailyIntegralFlux] = getTransformedForcing(obj.parameters.climateTransform_soilMoistureModels_2layer_v2, 'infiltration', SMSnumber, false); % set "true" if need daily data
            end

            % get 'SMS' (soil moisture), both daily and sub-daily time-steps to quality check
            % daily data
            [tf, column_number] = ismember('SMS', derivedForcingData_colnames);
            if ~tf
                error('SMS is not one of the derived forcings variables. Check if using 2-layer v2 soil model or model_TFN_SW_GW')
            end
            soil_moisture = allDerivedForcingData(:,column_number);
            
            % sub-daily data                       
            if sum(strcmp(fieldnames(obj.parameters), "climateTransform_soilMoistureModels_v2"))>0
                soil_moisture_2 = obj.parameters.climateTransform_soilMoistureModels_v2.variables.SMS ;
            elseif sum(strcmp(fieldnames(obj.parameters), "climateTransform_soilMoistureModels_interflow"))>0
                soil_moisture_2 = obj.parameters.climateTransform_soilMoistureModels_interflow.variables.SMS ;
            elseif sum(strcmp(fieldnames(obj.parameters), "climateTransform_soilMoistureModels_2layer_v2"))>0
                soil_moisture_2 = obj.parameters.climateTransform_soilMoistureModels_2layer_v2.variables.SMS ;
            end


            % Initialise total flow
            obj.variables.totalFlow = [];

            % Get the runoff from the derived forcing output            
            [tf, column_number] = ismember('runoff', derivedForcingData_colnames); % shall we now use runoff_total??

            if ~tf
                error('runoff_total is not one of the derivedForcingData variables. Check if using 2-layer_v2 soil model')
            end

                       
            % calculate total flow
            totalFlow = max(0, quickFlow(:,2) + baseFlow); % limiting the total flow to be equal or above zero
            totalFlow = [quickFlow(:,1) totalFlow];

            % Storing total flow
            obj.variables.totalFlow = totalFlow;
            
            
            % checking parameters used in the model
            [params, param_names] = getParameters(obj);
            check_parameters = {};
            check_parameters(:,1) = param_names(1:end,2);
            check_parameters(:,2)= num2cell(params(1:end));
            
            if obj.inputData.plot_hydrographs == false
                % dont print check_parameters if not plotting hydrographs.
            else
                check_parameters
            end

        end

        % Get the observed streamflow
        function obsFlow = getObservedFlow(obj)
            obsFlow = obj.inputData.flow;
        end

        function isValidParameter = getMassBalanceValidity(obj,time_points_streamflow)
            % Checking if parameters are valid according to the mass-balance criteria between total GW-recharge
            % (free-drainage) and total baseflow. It has to be done here as it uses both soilMoisture and baseflow components
            
			% Get the parameter names for all model components
            [params, param_names] = getParameters(obj);

            % Initialise output
            isValidParameter = true(size(params));

            for i=1:size(params,1)
                % Calculate total total GW-recharge (free-drainage)
				
				[allDerivedForcingData, derivedForcingData_colnames] = getDerivedForcingData(obj,time_points_streamflow);  

                [tf, column_number] = ismember('drainage', derivedForcingData_colnames); 

                if ~tf
                    error('drainage is not one of the derivedForcingData variables...')
                end

                free_drainage = allDerivedForcingData(:,column_number);

                % Create filter for the days with streamflow obs.
                [forcingData, forcingData_colnames] = getForcingData(obj);
                time_points_forcing = forcingData(:,1);
                filt =  time_points_forcing <= obj.variables.time_points_streamflow(end); % cause forcing data goes beyond more recent observed flow.
                time_points_forcing = time_points_forcing(filt);

                % Add the time steps for the runoff.
                free_drainage = [time_points_forcing free_drainage];

                % Filter the daily runoff data (without gaps) to the dates
                % having observed flow.
                filt =  free_drainage(:,1) >= time_points_streamflow(1) ...
                    & free_drainage(:,1) <= time_points_streamflow(end);
                free_drainage = free_drainage(filt,:);

                % integral of the free_drainage from soil moisture into groundwater
                total_free_drainage =sum(free_drainage(:,2));

                % Get baseflow
                baseflow = obj.parameters.baseflow.variables.baseFlow;
                
				% integral of the baseflow from groundwater into streamflow
                total_baseflow =sum(baseflow);

                % Check if the baseflow is within the recharge bounds
                if total_baseflow >= total_free_drainage
                    isValidParameter(i,:) = false;
                end
            end
        end

    end
end
