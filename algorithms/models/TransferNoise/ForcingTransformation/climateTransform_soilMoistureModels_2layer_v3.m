classdef climateTransform_soilMoistureModels_2layer_v3 < climateTransform_soilMoistureModels_2layer_v2  
% Class definition for soil moisture transformation of climate forcing.
%
% Description        
%   climateTransform_soilMoistureModels_2layer_v3 is a generalised vertically lumped 1-D
%   soil moisture model. It is identical to climateTransform_soilMoistureModels_2layer_v2 ()
%   except that it introduces a new runoff method that produces quick-flow after an active 
%   storage threshold is achieved, as per Kalma, J. D., Bates, B. C., Woods, R. A. 1995 (Predicting catchment?scale soil
%   moisture status with limited field measurements). This is achievd by rejecting parameter sets that produce actual 
%   ET values outsde these bounds.
%
% See also
%   climateTransform_soilMoistureModels_2layer_v2 : parent model;
%   climateTransform_soilMoistureModels_2layer_v3: model_construction;
%
% Dependencies
%   forcingTransform_soilMoisture.c
%
% Author: 
%   Giancarlo Bonotto, The Department of Infrastructure Engineering,
%   Dr. Tim Peterson, The Department of Infrastructure Engineering, 
%   The University of Melbourne.
%
% Date:
%   July 2021
    
    properties
        
        % Additional Model Parameters to that of sub-class.
        %----------------------------------------------------------------
        SMSC_threshold  % Layer 1 soil moisture capacity threshold that controls runoff (quickflow) generation       
        %----------------------------------------------------------------
        
    end


    
%%  STATIC METHODS        
% Static methods used to inform the
% user of the available model types. 
methods(Static)
        function [variable_names, isOptionalInput] = inputForcingData_required(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates)
            variable_names = {'precip';'et';'TreeFraction'};
            isOptionalInput = [false; false; true];
        end
        
        function [variable_names] = outputForcingdata_options(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates)
            
            variable_names = climateTransform_soilMoistureModels_2layer.outputForcingdata_options(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates);
                
%             variable_names_deep = { 'drainage_deep'         ;'evap_soil_deep';       'evap_soil_total';        'runoff_total';            'SMS_deep'; ...
%                                     'drainage_deep_tree'    ;'evap_soil_deep_tree';  'evap_soil_total_tree';   'runoff_total_tree'; 	'SMS_deep_tree'; ...
%                                     'drainage_deep_nontree' ;'evap_soil_deep_nontree';'evap_soil_total_nontree';'runoff_total_nontree';    'SMS_deep_nontree'; ...
%                                     'mass_balance_error'};
                
%             variable_names = {variable_names{:}, variable_names_deep{:}};
            variable_names = unique(variable_names);
        end
        
        function [options, colNames, colFormats, colEdits, toolTip] = modelOptions()
           
            options = { 'SMSC'           ,    2, 'Calib.';...
                        'SMSC_trees'    ,   2, 'Fixed';...
                        'SMSC_threshold',   2, 'Calib';...
                        'treeArea_frac' , 0.5, 'Fixed'; ...
                        'S_initialfrac' , 0.5, 'Fixed'  ; ...
                        'k_infilt'      , inf,'Fixed'   ; ...
                        'k_sat'         , 1, 'Calib.'   ; ...
                        'bypass_frac'   , 0, 'Fixed'    ; ...
                        'alpha'         , 0, 'Fixed'    ; ...
                        'beta'          ,  0.5,'Calib.' ; ...
                        'gamma'         ,  0,  'Fixed'  ; ...
                        'SMSC_deep'     ,  2, 'Calib.'   ;
                        'SMSC_deep_trees',   2, 'Fixed';...
                        'S_initialfrac_deep', 0.5,'Fixed'; ...
                        'k_sat_deep'     , 1, 'Calib.'   ;
                        'beta_deep'     ,  0.5, 'Calib.'};

        
            colNames = {'Parameter', 'Initial Value','Fixed or Calibrated?'};
            colFormats = {'char', 'char', {'Calib.' 'Fixed'}};
            colEdits = logical([0 1 1]);

            toolTip = sprintf([ 'Use this table to define the type of soil moisture model. \n', ...
                                'Each parameter (except the soil moisture capacity) can be \n', ...
                                'set to a fixed value or calibrated. Below is a summary: \n \n' , ...
                                '   SMSC         : log10(Soil moisture capacity as water depth).\n', ...
                                '   SMSC_threshold : log10(Soil moisture capacity threshold controling runoff (quickflow) generation).\n', ...
                                '   SMSC_trees    : log10(Tree soil moisture capacity as water depth).\n', ...
                                '   treeArea_frac : Scaler applied to the tree fraction input data.\n', ...                                
                                '   S_initialfrac: Initial soil moisture fraction (0-1).\n', ...
                                '   k_infilt     : log10(Soil infiltration capacity as water depth).\n', ...
                                '   k_sat        : log10(Maximum vertical infiltration rate).\n', ...
                                '   bypass_frac  : Fraction of runoff to bypass drainage.\n', ...
                                '   alpha        : Power term for infiltration rate.\n', ...
                                '   beta         : log10(Power term for dainage rate).\n', ...
                                '   gamma        : log10(Power term for soil evap. rate).\n', ...
                                '   SMSC_deep    : log10(Deep layer soil moisture capacity as water depth).\n', ...
                                '   SMSC_deep_trees: log10(Deep layer tree soil moisture capacity as water depth).\n', ...
                                '   S_initialfrac_deep: Initial deep soil moisture fraction (0-1).\n', ...
                                '   k_sat_deep   : log10(Deep layer maximum vertical infiltration rate).\n', ...
                                '   beta_deep    : log10(Deep layer power term for dainage rate).']);
            
        end
        
        function modelDescription = modelDescription()
           modelDescription = {'Name: climateTransform_soilMoistureModels_2layer_v3', ...
                               '', ...
                               'Purpose: nonlinear transformation of rainfall and areal potential evaporation to a range of forcing data (eg free-drainage) ', ...
                               'using a highly flexible two layer soil moisture model. Note, the top layer free-drains into to deeper layer.', ...
                               'Also, two types of land cover can be simulated using two parrallel soil models.', ...
                               '', ...                               
                               'Number of parameters: 2 to 11', ...
                               '', ...                               
                               'Options: each model parameter (excluding the soil moisture capacity) can be set to a fixed value (ie not calibrated) or calibrated.', ...
                               'Also, the input forcing data field "TreeFraction" is optional and only required if the soil model is to simulate land cover change.', ...                               
                               '', ...                               
                               'Comments: Below is a summary of the model parameters:' , ...
                                'SMSC         : log10(Soil moisture capacity as water depth).', ...
                                'SMSC_threshold : log10(Soil moisture capacity threshold controling runoff (quickflow) generation).\n', ...
                                'SMSC_trees    : log10(Tree soil moisture capacity as water depth).', ...
                                'treeArea_frac : Scaler applied to the tree fraction input data.', ...                                                                
                                'S_initialfrac: Initial soil moisture fraction (0-1).', ...
                                'k_infilt     : log10(Soil infiltration capacity as water depth).', ...
                                'k_sat        : log10(Maximum vertical infiltration rate).', ...
                                'bypass_frac  : Fraction of runoff to bypass drainage.', ...
                                'alpha        : Power term for infiltration rate.', ...
                                'beta         : log10(Power term for dainage rate).', ...
                                'gamma        : log10(Power term for soil evap. rate).', ...
                                'SMSC_deep    : log10(Deep layer soil moisture capacity as water depth). ', ...
                                '               Input an empty value and "fixed" to for it to equal SMSC.', ...
                                'SMSC_deep_tree : log10(Tree deep layer soil moisture capacity as water depth).', ... 
                                '               Input an empty value and "fixed" to for it to SMSC_tree', ...
                                'S_initialfrac_deep: Initial deep soil moisture fraction (0-1).\n', ...      
                                '               Input an empty value and "fixed" to for it to S_initialfrac', ...                                
                                'k_sat_deep   : log10(Deep layer maximum vertical infiltration rate).', ...
                                '               Input an empty value and "fixed" to for it to equal k_sat.', ...
                                'beta_deep    : log10(Deep layer power term for dainage rate).', ...
                                '               Input an empty value and "fixed" to for it to beta.', ...                                
                               '', ...               
                               'References: ', ...
                               '1. Peterson & Western (2014), Nonlinear time-series modeling of unconfined groundwater head, Water Resour. Res., 50, 8330–8355'};
        end        
           
end
    
    methods       
%% Construct the model
        function obj = climateTransform_soilMoistureModels_2layer_v3(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates, forcingData_reqCols, modelOptions)            
% Model construction.
%
% Syntax:
%   soilModel = climateTransform_soilMoistureModels_2layer_v3(modelOptions)   
%
% Description:
%   Builds the form of the soil moisture differential equations using user
%   input model options. The way in which the soil moisture model is used
%   to transform the precipitation and potential evapotranspiration is also
%   defined within the model options.
%
%   Importantly, the parameters for the deep layer do not need to be
%   specified within the model options input. If they are not specified,
%   then their initial values are taken from those for the top soil layer.
%
%   This constructor also checks that the required compiled code exists (ie
%   forcingTransform_soilMoisture.c), the input model options are two or
%   three columns wide and that the way in which the transformations are to
%   be undertaken is specified.
%
% Input:
%   modelOptions - cell matrix defining the soil model componants, ie how the
%   model should be constructed. The cell matrix can be two or three
%   columns wide and at least three rows long (for the simplest of models).
%   The first column defines the model parameter name or user option name
%   to be defined. The second column defines the initial value for the
%   parameter or the setting for the user option. A third column can be
%   input if a parameter is to be fixed, and thus not modified during
%   calibration. This third column can contain the term 'fixed'. 
%
%   The required user options, and option choices, are as follows:
%       'SMSC_deep'
%       This is for setting the bottom layer soil moisture storage capacity parameter.
%       The value for the second column is the initial value for this
%       parameter. This model option is required because all model variants
%       require this parameter to be set.
%
%       'k_sat'
%       This is for setting the drainage rate from the top layer. This 
%       model option is required to estimated drainage into the deep layer.


%       'SMSC_threshold'
%       This is for setting the layer 1 soil moisture threshold that controls runoff (quickflow) generation. 
%       is assumed that Layer 2 generates runoff (quickflow) only if
%       (SMSdeep/SMSCdeep)>1. By default, SMSC_threshold is initiated as
%       zero and allowed to be calibrated [1 <= SMSC_threshold <= SMSC]

%   The optional user options are as follows. For the model parameter
%   options the second column defines the initial value. A third column can
%   also be input to make the parameter a constant:
%
%       'k_infilt'          - layer 1 parameter for the maximum infiltration rate. 
%       'alpha'             - layer 1 parameter for the infiltration rate power term.
%       'beta'            - layer 1 parameter for the drainage rate power term.
%       'k_sat'           - layer 1 parameter for the maximum vertical saturated
%                             conductivity.
%       'gamma'             - layer 1 parameter for the evaporation rate power term.
%       'SMSC_threshold'    - layer 1 parameter for the runoff threshold term.

%       'beta_deep'            - layer 2 parameter for the drainage rate power term.
%       'k_sat_deep'           - layer 2 parameter for the maximum vertical saturated
%                             conductivity.
%       'numDailySubsteps'  - a user option to define the number of
%                             sub-daily time steps when solving the
%                             differential equation. Having more than one
%                             step per day will not notably improve the 
%                             estimate of soil moisture. It will however 
%                             result in better estimation of infiltration 
%                             when the soil layer saturates.
%
%   Below are some examples of model options for various types of models:
%
%       - 1 parameter with linear scaling of infiltration by the soil moisture:
%       >> soilModelOptions = { 'lossingOption', 'evap_deficit' ;
%                               'gainingOption', 'soil_infiltration' ;
%                               'SMSC', 100};
%       - 1 parameter WITHOUT scaling of infiltration by the soil moisture:
%       >> soilModelOptions = { 'lossingOption', 'evap_deficit', '' ;
%                               'gainingOption', 'soil_infiltration', '' ;
%                               'SMSC', 100, '' ;
%                               'alpha', 0, 'fixed'};
%       - 2 parameter with linear scaling of infiltration by the soil 
%       moisture and linear vertical drainage:
%       >> soilModelOptions = { 'lossingOption', 'evap_deficit' ;
%                               'gainingOption', 'soil_infiltration' ;
%                               'SMSC', 100 ; 
%                               'k_sat', 10 };
%       - 3 parameter with linear scaling of infiltration by the soil
%       moisture and non-linear vertical drainage:
%       >> soilModelOptions = { 'lossingOption', 'evap_deficit' ;
%                               'gainingOption', 'soil_infiltration' ;
%                               'SMSC', 100 ; 
%                               'beta', 2 ;
%                               'k_sat', 10 };
%       - 4 parameter with non-linear scaling of infiltration by the soil 
%       moisture and non-linear vertical drainage:
%       >> soilModelOptions = { 'lossingOption', 'evap_deficit' ;
%                               'gainingOption', 'soil_infiltration' ;
%                               'SMSC', 100 ; 
%                               'alpha', 0.5 ;
%                               'beta', 2 ;
%                               'k_sat', 10 };
%
% Output:
%   soilModel - climateTransform_soilMoistureModels_2layer class object 
%
% Example: 
%   Create a cell matrix of options for a two parameter soil model:
%   >> soilModelOptions = { 'lossingOption', 'evap_deficit' ;
%                           'gainingOption', 'soil_infiltration' ;
%                           'SMSC', 100 ; 
%                           'k_sat', 10 };
%   Build the soil model:
%   >> soilModel = climateTransform_soilMoistureModels_2layer(soilModelOptions);
%
% See also
%   climateTransform_soilMoistureModels_2layer: class_definition;
%   setParameters: set_calibration_parameters_values;
%   getParameters: get_calibration_parameters_values;
%   detectParameterChange: assesst_if_parameters_have_changed_recently;
%   setTransformedForcing: run_model_and_store_simulation_results;
%   getTransformedForcing: get_outputs_for_timeseries_model.
%
% Dependencies
%   evapOptions.m
%   rechargeOptions.m
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure Engineering, 
%   The University of Melbourne.
%
% Date:
%   11 April 2012   

            % Use sub-class constructor.
            obj = obj@climateTransform_soilMoistureModels_2layer_v2(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates, forcingData_reqCols, modelOptions);
            
            % Get list of model parameters and exclude settings, variables
            % and the model 'type';
            all_parameter_names = properties(obj);
            ind = true(length(all_parameter_names),1);
            for i=1:length(all_parameter_names)
                switch all_parameter_names{i,1}
                    case {'settings', 'variables'}
                        ind(i) = false;                    
                end
            end
            all_parameter_names = all_parameter_names(ind);
                        
            % Assign model parameters.
            % Importantly, if the parameter is not listed then that 
            % feature of the soil moisture model is turned off.
            %--------------------------------------------------------------
            for i=1:length(all_parameter_names)
                
                % Find the required parameter within the input model
                % options.
                ind = [];
                for j=1:length(modelOptions(:,1))
                    if strcmp(modelOptions(j,1), all_parameter_names{i} )                        
                        ind = j;
                        break;
                    end
                end
            
                % Record the deep parameters not listed as 'Fixed'.
                if isempty(ind)
                    obj.settings.fixedParameters.(all_parameter_names{i})=false;
                    obj.settings.activeParameters.(all_parameter_names{i})=false;                    
                    if strcmp(all_parameter_names{i}, 'SMSC_threshold')
                        % Note, SMSC_threshold is transformed in the soil model to 10^SMSC_threshold.
                        obj.(all_parameter_names{i}) = 1; % Initiate SMSC_threshold as equal to zero -> (log10(1)=0)
                        
                    end
                end
            end
                        
%             % Check the SMSM_trees parameter is active if and only if there
%             % is land cover input data.
%             if  isfield(obj.settings,'simulateLandCover') && obj.settings.simulateLandCover
%                if ~obj.settings.activeParameters.SMSC_deep_trees 
%                    error('The trees deep soil moisture model options must include the soil moisture capacity parameter when land cover data is input.');
%                end
%             else
%                 obj.settings.activeParameters.SMSC_deep_trees = false; 
%                 obj.settings.fixedParameters.SMSC_deep_trees = true;
%             end
%             
%             % Check that deep parameters set to NaN are not active.
%             if isnan(obj.beta_deep) && obj.settings.activeParameters.beta_deep
%                 error('"beta_deep" can only be initialsied to Nan if it is "Fixed".');
%             end                        
%             if isnan(obj.k_sat_deep) && obj.settings.activeParameters.k_sat_deep
%                 error('"k_sat_deep" can only be initialsied to Nan if it is "Fixed".');
%             end                                    
%             if isnan(obj.S_initialfrac_deep) && obj.settings.activeParameters.S_initialfrac_deep
%                 error('"S_initialfrac_deep" can only be initialsied to Nan if it is "Fixed".');
%             end                
%             if isnan(obj.SMSC_deep_trees) && obj.settings.activeParameters.SMSC_deep_trees
%                 error('"SMSC_deep_trees" can only be initialsied to Nan if it is "Fixed".');
%             end                
%             if isnan(obj.SMSC_deep) && obj.settings.activeParameters.SMSC_deep_trees
%                 error('"SMSC_deep" can only be initialsied to Nan if it is "Fixed".');
%             end                
            
            % Initialise soil moisture variables
%             obj.variables.SMS_deep = [];           
%             obj.variables.SMS_deep_subdaily = [];
        end

        
%% Return fixed upper and lower bounds to the parameters.
        function [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj)
            
            % Get the parameter names.
            [params, param_names] = getParameters(obj);

            % Get the bounds from the original soil model
            [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit@climateTransform_soilMoistureModels_2layers_v2(obj);
                        
            % Upper and lower bounds of SMSC_threshold.
            if obj.settings.activeParameters.SMSC_threshold
                ind = cellfun(@(x)(strcmp(x,'SMSC_threshold')),param_names);
                params_lowerLimit(ind,1) = log10(10);                    
                %params_upperLimit(ind,1) = Inf; 
                params_upperLimit(ind,1) = log10(1000);
            end           
            
                          
        end  
 
        
%% Return fixed upper and lower plausible parameter ranges. 
        function [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(obj)
        % Return fixed upper and lower plausible parameter ranges. 
        % This is used to define reasonable range for the initial parameter sets
        % for the calibration. These parameter ranges are only used in the 
        % calibration if the user does not input parameter ranges.
            
            % Get the parameter names.
            [params, param_names] = getParameters(obj);

            % Get the bounds from the original soil model
            [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit@climateTransform_soilMoistureModels_2layer_v2(obj);
                        
            % Upper and lower bounds of SMSC.
            if obj.settings.activeParameters.SMSC_threshold
                ind = cellfun(@(x)(strcmp(x,'SMSC_threshold')),param_names);
                params_lowerLimit(ind,1) = log10(50); % Initiate SMSC_threshold as equal to zero -> (log10(1)=0)
                params_upperLimit(ind,1) = log10(500);
            end           
                                       
        end
        
        
%% Return the transformed forcing data
        function [forcingData, isDailyIntegralFlux] = getTransformedForcing(obj, variableName, SMSnumber, doSubstepIntegration) 
% getTransformedForcing returns the required flux from the soil model.
%
% Syntax:
%   [precip_Forcing, et_Forcing] = getTransformedForcing(obj, variableName)
%
% Description:  
%   This method returns the requested flux/data from the soil moisture 
%   differential equation. The available fluxes/data are as follows:
%
%   * drainage: soil free drainage ranging (0 to k_sat) at the end of the day.
%   * drainage_bypassFlow: free drainage plus a parameter set fraction of runoff;
%   * drainage_normalised: normalised free drainage (0 to 1) at the end of the day.
%   * evap_soil: actual soil ET at the end of the day.    
%   * infiltration: daily total infiltration rate.
%   * evap_gw_potential: groundwater evaporative potential (PET - soil ET)
%   * runoff: daily total runoff.
%   * SMS: soil moisture storage at the end of each day.
%
% Input:
%   obj - soil moisture model object.
%
%   variableName - a string for the variable name to return.
%
% Outputs:
%   forcingData  - a vector (Nx1) of the forcing data output to
%                     be input to the groundwater time series model.
%
%   isDailyIntegralFlux - logical scaler denoting if the flux is a daily
%   integral or an instantaneous value. This is used to inform the type of
%   numerical integration within modelTFN.get_h_star().
%
% See also:
%   climateTransform_soilMoistureModels_2layer: class_definition;
%   setParameters: set_calibration_parameters_values;
%   getParameters: get_calibration_parameters_values;
%   detectParameterChange: assesst_if_parameters_have_changed_recently;
%   setTransformedForcing: set_outputs_for_timeseries_model.
%
% Dependencies:
%   (none)
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure Engineering, 
%   The University of Melbourne.
%
% Date:
%   11 April 2012  

            if ischar(variableName)
                variableNametmp{1}=variableName;
                variableName = variableNametmp;
                clear variableNametmp;
            end
                
            % Get back transformed parameters and assign each param to a variable for efficient access.            
            [params, param_names] = getDerivedParameters(obj);
            SMSC = params(1,:);
            SMSC_trees = params(2,:);
            treeArea_frac = params(3,:);
            k_sat = params(6,:);
            bypass_frac = params(7,:);
            interflow_frac = params(8,:);
            beta = params(10,:);
            gamma = params(11,:);             
            SMSC_deep = params(end-5,:);
            SMSC_deep_trees = params(end-4,:);
            S_deep_initial = params(end-3,:);
            k_sat_deep = params(end-2,:);
            beta_deep = params(end-1,:);
            SMSC_threshold = params(end,:);
            
            % Set if the subdaily steps should be integrated.
            if nargin < 4
                doSubstepIntegration = true;
            end
            
            try 
                if doSubstepIntegration
                    nrows = size(obj.variables.precip,1);
                else
                    nrows = size(getSubDailyForcing(obj,obj.variables.precip),1);
                end
                forcingData = zeros(nrows , length(variableName));
                for i=1:length(variableName)
                    % Test if the flux can be derived from the parent class.
%                     if ~any(strcmp({'evap_soil_deep','evap_soil_total', 'evap_gw_potential', ...
%                     'drainage_deep','runoff_total','SMS_deep','mass_balance_error'}, ...
%                     variableName{i}))
                    
                    if ~any(strcmp({'infiltration'}, ...
                    variableName{i}))
                
                        if nargin==2
                            [forcingData(:,i), isDailyIntegralFlux(i)] = getTransformedForcing@climateTransform_soilMoistureModels_2layer(obj, variableName{i});   
                        else
                            [forcingData(:,i), isDailyIntegralFlux(i)] = getTransformedForcing@climateTransform_soilMoistureModels_2layer(obj, variableName{i}, SMSnumber, doSubstepIntegration);   
                        end
                        continue
                    end
                    
                    % Get the soil moisture store for the required soil unit
                    if nargin==2 || SMSnumber==1                               
                        SMS = obj.variables.SMS;
                        SMS_deep = obj.variables.SMS_deep;
                        SMSnumber = 1;
                    elseif SMSnumber==2
                        SMS = obj.variables.SMS_trees;
                        SMSC_deep = SMSC_deep_trees; 
                        SMS_deep = obj.variables.SMS_deep_trees;                    
                    else
                        error('The soil moisture unit number is unknown')
                    end                     

                    switch variableName{i}
                            
                            case 'infiltration'                       
                            % Calculate max. infiltration assuming none
                            % goes to SATURATED runoff.
                            effectivePrecip_daily = getTransformedForcing(obj, 'effectivePrecip',SMSnumber); 
                            effectivePrecip = getSubDailyForcing(obj,effectivePrecip_daily);
                            if alpha==0
                                infiltration_daily =  effectivePrecip_daily;
                                infiltration =  effectivePrecip;                                
                            else
                                infiltration =  effectivePrecip .* (1-((SMS-SMSC_threshold)/SMSC)).^alpha;
                            end
                            
                            % Calculatre when the soil is probably
                            % saturated. 
                            drainage = getTransformedForcing(obj, 'drainage',SMSnumber, false);
                            evap = getTransformedForcing(obj, 'evap_soil',SMSnumber, false);
                            Infilt2Runoff = [0;(SMS(1:end-1) + infiltration(2:end) - evap(2:end) - drainage(2:end)) - SMSC];
                            Infilt2Runoff(Infilt2Runoff<0) = 0;
                            
                            % Subtract estimated satruated excess runoff
                            % from the infiltration and then integrate.
                            if alpha==0
                                % Integrate ONLY saturated runoff
                                if doSubstepIntegration
                                    Infilt2Runoff = dailyIntegration(obj, Infilt2Runoff);
                                    
                                    % Subtract from precip.
                                    forcingData(:,i) = infiltration_daily - Infilt2Runoff;
                                else
                                    forcingData(:,i) = infiltration - Infilt2Runoff;
                                end
                            else
                                infiltration = infiltration - Infilt2Runoff;
                                if doSubstepIntegration
                                    forcingData(:,i) = dailyIntegration(obj, infiltration);
                                else
                                    forcingData(:,i) = infiltration;
                                end                                
                            end
                            
                            if doSubstepIntegration
                                isDailyIntegralFlux(i) = true;
                            else
                                isDailyIntegralFlux(i) = false;
                            end
                            
                            
                            

%                         case 'mass_balance_error'
%                             precip = getSubDailyForcing(obj,obj.variables.precip);
%                             runoff = getTransformedForcing(obj, 'runoff_total',SMSnumber, false);
%                             AET = getTransformedForcing(obj, 'evap_soil_total',SMSnumber, false);
%                             drainage = getTransformedForcing(obj, 'drainage_deep',SMSnumber, false);
%                             
%                             fluxEstError = [0;precip(2:end) - diff(SMS + SMS_deep) -  runoff(2:end) - AET(2:end) - drainage(2:end)];
%                             
%                             % Integreate to daily.
%                             if doSubstepIntegration
%                                 forcingData(:,i) = dailyIntegration(obj, fluxEstError);
%                                 isDailyIntegralFlux(i) = true;
%                             else
%                                 forcingData(:,i) = fluxEstError;
%                                 isDailyIntegralFlux(i) = false;
%                             end
                            
                        otherwise
                            error('The requested transformed forcing variable is not known.');
                    end

                    % Get flixes for tree soil unit (if required) and weight the
                    % flux from the two units
                    if  isfield(obj.settings,'simulateLandCover') && obj.settings.simulateLandCover && nargin==2
                        % Get flux for tree SMS
                        forcingData_trees = getTransformedForcing(obj, variableName{i}, 2) ;

                        % Do weighting
                        forcingData(:,i) = (1-treeArea_frac .* obj.variables.treeFrac) .* forcingData(:,i) + ...
                                      treeArea_frac .* obj.variables.treeFrac .* forcingData_trees;
                    end            
                end
            catch ME
                error(ME.message)
            end
            

            
        end
        
 %% gets the derived forcing data 
        function [params, param_names] = getDerivedParameters(obj)
            
            
            [params, param_names] = getDerivedParameters@climateTransform_soilMoistureModels_2layer_v2(obj);   
            
            param_names(size(param_names,1)+1:size(param_names,1)+1) = {
                           'SMSC_threshold: back transformed soil moisture shallow layer threshold storage capacity for generating runoff-quickflow (in rainfall units)'; ...                  
                           };    
        
            % Handle deep soil layer parameters taken from the shallow
            % layer.
                      
            if isnan(obj.SMSC_threshold)
                SMSC_threshold = 10^(obj.SMSC); % or should we set it here as 10^0
            else
                SMSC_threshold = 10^obj.SMSC_threshold;
            end
            
            params = [  params;  ...
                        SMSC_threshold; ...
                        ];
        end        
        
        
    end
    
end


