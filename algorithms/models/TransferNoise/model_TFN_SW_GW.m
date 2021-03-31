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
        function obj = model_TFN_SW_GW(site_IDs, obsData, forcingData_data,  forcingData_colnames, siteCoordinates, varargin)           
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
            obj = obj@model_TFN(site_IDs, obsData, forcingData_data,  forcingData_colnames, siteCoordinates, varargin{1});

            %% Read in file with obs flow.
            % Note, eventually site_IDs needs to be chnaged from a single
            % string with the bore ID to a vector of stream and bore IDs.
            % Maybe the first could be the stream ID.
%             obsDataFlow = csvread('obsFlow_Brucknell.csv');
            obsDataFlow = readtable('obsFlow_Brucknell.csv');
            obsDataFlow = obsDataFlow(:,2:end);

            obsDataFlow = table2array(obsDataFlow);
            
            % Derive columns of year, month, day etc to matlab date value
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
            
            % including the flow data into the input data object
            obj.inputData.flow = obsDataFlow;

            
            %% check the SW and GW and how to separate them... 
            
            
            
            %% logical part of how to store the data in the object... 
            
            %% Set Obj parameters for the baseflow calculation
            %obj.parameters.streamflow.head_threshold = mean(obsData(:,end));
            %obj.parameters.streamflow.head_to_baseflow = 1;
            obj.parameters.baseflow = baseflow(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates, forcingData_reqCols, []);
   
    end
    
    function [objFn, flow_star, colnames, drainage_elevation] = objectiveFunction(params, time_points, obj, varargin)
    
    
        % Call objectiveFunction in model_TFN to get head objFn
        [objFn, h_star, colnames, drainage_elevation] = objectiveFunction@model_TFN(params, time_points, obj, varargin);
        
        % Call some method in model_TFN_SW_GW to return simulated flow
        % (using the simulated head - so call [head, colnames, noise] = solve@model_TFN(obj, time_points)
        [totalFlow, baseFlow, quickFlow] = getStreamFlow(time_points, obj, varargin);
        
        % Call some method in model_TFN_SW_GW to return obs flow
        
%         obsFlow = getObservedFlow(obj);
                
        % Calc. flow objFn
        
        
        % Have some way of merging objFn from head and objFn from flow
        
        
        % Rten combined objFun and other terms 
        
        
    end
    
    % get quickFlow and baseFlow using simulated head and streamflow 
    function [totalFlow, baseFlow, quickFlow] = getStreamFlow(time_points, obj, varargin)
     
     % get simulated head to use to estimate baseflow 
       
     [head, colnames, noise] = solve(obj, time_points); % just the deterministic . is it at the same time step (daily)? 
     
     % calculate the baseflow
     baseFlow = max(0,head - obj.parameters.streamflow.head_threshold) .* obj.parameters.streamflow.head_to_baseflow;
     
     % getting the derived forcing data, which includes the quick flow
     % (runoff and interflow)
     [allForcingData, forcingData_colnames] = getDerivedForcingData(obj, time_points);
     
     quickFlow = []; %catchmentArea * % get the quickflow from the runoff of the lumped 1-d soil moisture model 
     
     totalFlow = []; %baseFlow + quickFlow;
     
     % limit the total flow to above zero
     if totalFlow < 0 
        totalFlow = 0; 
     end
     
    end
     
    % Get the observed streamflow
    function flow = getObservedFlow(obj)
        flow = obj.inputData.flow;
    end
    
%     % alternative, copy the code from Model_TFN... 
%     function [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(obj)
%         [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit@model_TFN(obj);
%         params_lowerLimit = [params_lowerLimit; 250; 0.1];
%         params_upperLimit = [params_upperLimit; 300; 100];
%     end
    
% %         function [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(obj)
% % getParameters_plausibleLimit returns the plausible limits to each model parameter.
% %
% % Syntax:
% %   [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(obj)
% %
% % Description:
% %   Cycles though all model componants and parameters and returns a vector
% %   of the plausible upper and lower parameter range as defined by the
% %   weighting functions.
% %
% % Input:
% %   obj -  model object.
% %
% % Outputs:
% %   params_upperLimit - column vector of the upper parameter plausible bounds.
% %
% %   params_lowerLimit - column vector of the lower parameter plausible bounds
% %
% % Example:
% %   see HydroSight: time_series_model_calibration_and_construction;
% %
% % See also:
% %   HydroSight: time_series_model_calibration_and_construction;
% %   model_TFN: model_construction;
% %   calibration_finalise: initialisation_of_model_prior_to_calibration;
% %   calibration_initialise: initialisation_of_model_prior_to_calibration;
% %   get_h_star: main_method_for_calculating_the_head_contributions.
% %   objectiveFunction: returns_a_vector_of_innovation_errors_for_calibration;  
% %   setParameters: sets_model_parameters_from_input_vector_of_parameter_values;
% %   solve: solve_the_model_at_user_input_sime_points;
% %
% % Author: 
% %   Dr. Tim Peterson, The Department of Infrastructure
% %   Engineering, The University of Melbourne.
% %
% % Date:
% %   26 Sept 2014   
%                         
%         params_lowerLimit = [];
%         params_upperLimit = [];
%         companants = fieldnames(obj.parameters);            
%         for ii=1: size(companants,1)
%             currentField = char( companants(ii) ) ;
%             % Get model parameters for each componant.
%             % If the componant is an object, then call the objects
%             % getParameters_physicalLimit method for each parameter.
%             if isobject( obj.parameters.( currentField ) )
%                 % Call object method.
%                 [params_upperLimit_temp, params_lowerLimit_temp] = getParameters_plausibleLimit( obj.parameters.( currentField ) );
% 
%                 params_upperLimit = [params_upperLimit; params_upperLimit_temp];
%                 params_lowerLimit = [params_lowerLimit; params_lowerLimit_temp];
%             else
%                 companant_params = fieldnames( obj.parameters.( currentField ) );
%                 for j=1: size(companant_params,1)
%                    if ~strcmp( companant_params(j), 'type')
%                        if strcmp(currentField,'et') && strcmp( companant_params(j), 'k')
%                             % This parameter is assumed to be the ET
%                             % parameter scaling when the ET
%                             % uses the precipitation transformation
%                             % function.
%                             params_upperLimit = [params_upperLimit; 1];
%                             params_lowerLimit = [params_lowerLimit; 0];
%                        elseif strcmp(currentField,'landchange') && (strcmp( companant_params(j), 'precip_scalar') ...
%                        || strcmp(currentField,'landchange') && strcmp( companant_params(j), 'et_scalar'))  
%                            % This parameter is the scaling parameter
%                            % for either the ET or precip transformation
%                            % functions.
%                            params_upperLimit = [params_upperLimit; 1.0];
%                            params_lowerLimit = [params_lowerLimit; -1.0];
%                        else
%                             % This parameter is assumed to be the noise parameter 'alpha'.  
%                             alpha_upperLimit = 100; 
%                             while abs(sum( exp( -2.*alpha_upperLimit .* obj.variables.delta_time ) )) < eps() ...
%                             || exp(mean(log( 1- exp( -2.*alpha_upperLimit .* obj.variables.delta_time) ))) < eps()
%                                 alpha_upperLimit = alpha_upperLimit - 0.01;
%                                 if alpha_upperLimit <= eps()                                   
%                                     break;
%                                 end
%                             end
%                             if alpha_upperLimit <= eps()
%                                 alpha_upperLimit = inf;
%                             else
%                                 % Transform alpha log10 space.
%                                 alpha_upperLimit = log10(alpha_upperLimit);
%                             end                           
%                             
%                             params_upperLimit = [params_upperLimit; alpha_upperLimit];
%                             params_lowerLimit = [params_lowerLimit; log10(sqrt(eps()))+4];
% 
%                        end
%                    end
%                 end
%             end
%         end
% %         params_lowerLimit = [params_lowerLimit; 250; 0.1];
% %         params_upperLimit = [params_upperLimit; 300; 100];
%     end 

    
    
%     function [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj)
%         [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit@model_TFN(obj);
%         
%         params_lowerLimit = [params_lowerLimit; 0; 0];
%         params_upperLimit = [params_upperLimit; Inf; Inf];
%     end


%         function [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj)
% % getParameters_physicalLimit returns the physical limits to each model parameter.
% %
% % Syntax:
% %   [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj)
% %
% % Description:
% %   Cycles through all model componants and parameters and returns a vector
% %   of the physical upper and lower parameter bounds as defined by the
% %   weighting functions.
% %
% % Input:
% %   obj -  model object.
% %
% % Outputs:
% %   params_upperLimit - column vector of the upper parameter bounds.
% %
% %   params_lowerLimit - column vector of the lower parameter bounds
% %
% % Example:
% %   see HydroSight: time_series_model_calibration_and_construction;
% %
% % See also:
% %   HydroSight: time_series_model_calibration_and_construction;
% %   model_TFN: model_construction;
% %   calibration_finalise: initialisation_of_model_prior_to_calibration;
% %   calibration_initialise: initialisation_of_model_prior_to_calibration;
% %   get_h_star: main_method_for_calculating_the_head_contributions.
% %   objectiveFunction: returns_a_vector_of_innovation_errors_for_calibration;  
% %   setParameters: sets_model_parameters_from_input_vector_of_parameter_values;
% %   solve: solve_the_model_at_user_input_sime_points;
% %
% % Author: 
% %   Dr. Tim Peterson, The Department of Infrastructure
% %   Engineering, The University of Melbourne.
% %
% % Date:
% %   26 Sept 2014   
% 
%             params_lowerLimit = [];
%             params_upperLimit = [];
%             companants = fieldnames(obj.parameters);            
%             for ii=1: size(companants,1)
%                 currentField = char( companants(ii) ) ;
%                 % Get model parameters for each componant.
%                 % If the componant is an object, then call the objects
%                 % getParameters_physicalLimit method for each parameter.
%                 if isobject( obj.parameters.( currentField ) )
%                     % Call object method.
%                     [params_upperLimit_temp, params_lowerLimit_temp] = getParameters_physicalLimit( obj.parameters.( currentField ) );                
%                     
%                     params_upperLimit = [params_upperLimit; params_upperLimit_temp];
%                     params_lowerLimit = [params_lowerLimit; params_lowerLimit_temp];
%                                         
%                 else
% 
%                     [params_plausibleUpperLimit, params_plausibleLowerLimit] = getParameters_plausibleLimit(obj);
%                     
%                     % This parameter is assumed to be the noise parameter 'alpha'.  
%                     ind = length(params_upperLimit)+1;
%                     params_upperLimit = [params_upperLimit; params_plausibleUpperLimit(ind)];                                                        
%                     params_lowerLimit = [params_lowerLimit; params_plausibleLowerLimit(ind)];                                
%                 end
%             end 
%             
%             params_lowerLimit = [params_lowerLimit; 0; 0];
%             params_upperLimit = [params_upperLimit; Inf; Inf];
%         end        



    
    end
end
