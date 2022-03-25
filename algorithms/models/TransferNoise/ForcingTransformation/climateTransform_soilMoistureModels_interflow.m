classdef climateTransform_soilMoistureModels_interflow < climateTransform_soilMoistureModels_v2
% Class definition for building a time-series model of interflow
%
% Description
%   climateTransform_soilMoistureModels_interflow is a generalised and flexible 1-layer 1-D
%   soil moisture model. It is used to transform part of the daily free drainage from 
%   the shallow soil layer into interflow.
%   Hence, inflow to the interflow layer (which can have zero to infinite storage) 
%   occurs by free-drainage from the shallow soil layer.
%   Also, evapotranspiration from the interflow layer can be set to zero or as a complement to 
%   evapotranspiration not met by the shallow soil layer.
%
%   Importantly, a user of the groundwater time series model has no need to
%   run any of these soil moisture model methods. All of the methods are
%   automatically called by the function "model_IRF.m".
%    
%   The precipitation can be transformed into a daily infiltration rate
%   or daily free-draiage rate. The potential evapotranspiration can be
%   transformed into a daily actual evapotranspiration rate or a daily 
%   remaining potential evapotranspiration.
%   
%   The top soil moisture layer is defined by the following ordinary
%   diffenential equation (Kavetski et al. 2006):
%   
%   DS_1/dt = max(P, P(SMSC - S_1/(SMSC-e))^alpha) - k_sat(S_1/SMSC)^beta - PET(S_1/SMSC)^gamma
%
%   And the bottom interflow layer is defined by the following ordinary
%   diffenential equation:
%
%   DS_interflow/dt = I_1 (1- S_interflow/SMSC_interflow)^alpha_interflow - (PET- E_1)(S_interflow/SMSC_interflow)^gamma - k_interflow (S_interflow/SMSC_interflow)^beta_interflow, 
% 	
%	where: 
%			I_1 = (1- interflow_frac) k_sat (S_1/SMSC)^beta
%			E_1 = PET(S_1/SMSC)^gamma
%   
%       S_1     - is the top layer soil moisture storage state variable [L];
%       S_interflow     - is the bottom interflow layer soil moisture storage state variable [L];
%       t       - is time in units of days [T];
%       P_inf   - is the precipitation available for infiltration. This can
%                 be limited to a maximum infiltration rate "k_infilt". Of
%                 this parameteris not defined then P_inf equals the input
%                 daily precipitation rate.
%       SMSC    - is a parameter for the top layer soil moisture storage 
%                 capacity [L]. It is in same units as the input precipitation.
%       SMSC_interflow  - is a parameter for the bottom layer interflow soil moisture storage 
%                 capacity [L]. It is in same units as the input
%                 precipitation. Note, if equal to NULL, then SMSC_interflow is 
%                 set to SMSC.
%       alpha   - is a dimensionless parameter to transform the rate at which
%                 the soil storage fills and limits infiltration. This 
%                 allows simulation of a portion of the catchment saturating
%                 and not longer allowing infiltration.
%       k_sat   - is a parameter for the saturated vertical soil water
%                 conductivity from the top layer [L T^-1]. 
%       k_interflow -is a parameter for the saturated vertical soil water
%                 conductivity from the bottom interflow layer [L T^-1].   
%                 Note, if equal to NULL, then k_interflow is set to k_sat.
%       beta    - is a dimensionless parameter to transform the rate at
%                 which vertical free drainage occurs with filling of
%                 the top soil layer. 
%       beta_interflow - is a dimensionless parameter to transform the rate at
%                 which vertical free drainage occurs with filling of
%                 the bottom interflow soil layer. Note, if equal to NULL, then beta_interflow
%                 is set to k_sat.
%       PET     - is the input daily potential evapotranspiration [L T^-1].
%       gamma   - is a dimensionless parameter to transform the rate at
%                 which soil water evaporation occurs with filling of the 
%                 soil layer. This parameters is assumed as the same for both 
%				  shallow soil store and bottom interflow soil store. 
%   
%
%   Additionally, in parametrizing the model, many of the parameters were
%   transformed to a parameter space more amenable to efficient
%   calibration. Details of the transformations are as follows:
%
%       SMSC          - log10(Top layer soil moisture capacity as water depth).
%       SMSC_trees    - log10(Trees top layer soil moisture capacity as water depth).
%       SMSC_interflow  - log10(Bottom layer soil moisture capacity as water depth).
%       S_initialfrac - Initial soil moisture fraction (0-1).
%       k_infilt      - log10(Soil infiltration capacity as water depth).
%       k_sat         - log10(Maximum vertical infiltration rate).
%       k_inteflow    - log10(Maximum vertical interflow rate).
%       bypass_frac   - Fraction of runoff to bypass drainage (0-1).
%       interflow_frac- Fraction of free drainage going to interflow (0-1).
%       alpha         - log10(Power term for infiltration rate).
%       beta          - log10(Power term for drainage rate).
%       gamma         - log10(Power term for soil evap. rate).
%
%   The soil moisture model is an adaption of VIC Model (Wood et al. 1992)
%   by Kavetski et al. (2006). It is a soil moisture model that is without
%   any discontinuities (thus able to produce a first-order smooth
%   calibration response surface) and therefore amenable to gradient based
%   calibration. The model, as implemented here, is very flexible in that a
%   wide range of models can be implemented by simply turning componants of
%   the differential equation on or off. For example, a one parameter
%   model (comprising only of infiltration and evaporation) can be derived
%   by turning off the drainage term and fixing alpha and gamma to one. For
%   details on how to build various types of models see the documentation
%   for the class constructor (i.e. "climateTransform_soilMoistureModels"
%   below);
%   
%   Considerable effort has been put into efficiently solving the soil 
%   moisture model while producing a smooth response surface. The
%   differential equation is solved using a fixed-time step solver. For each
%   time step, an initial estimate is made using the explicit Huen
%   algorithm. This produces an O(h^2) error. The solution error is then
%   refined near to machine precision using an implicit Huen Newton's
%   algorithm. To achieve efficient computation, the differential equation
%   and solver are implemeneted within MatLab's C-MEX language. This
%   requires compilation of the file "forcingTransform_soilMoisture.c" and
%   can be achieved by executing the following command within MatLab: 
%   mex forcingTransform_soilMoisture.c
%
% See also
%   climateTransform_soilMoistureModels: model_construction;
%   setParameters: set_calibration_parameters_values;
%   getParameters: get_calibration_parameters_values;
%   detectParameterChange: assesst_if_parameters_have_changed_recently;
%   setTransformedForcing: run_model_and_store_simulation_results;
%   getTransformedForcing: get_outputs_for_timeseries_model.
%
% Dependencies
%   forcingTransform_soilMoisture.c
%   evapOptions.m
%   rechargeOptions.m
%
% References:
%   Kavetski, D., G. Kuczera, and S. W. Franks (2006), Bayesian analysis of
%   input uncertainty in hydrological modeling: 1. Theory, Water Resour. Res.,
%   42, W03407, doi:10.1029/2005WR004368. 
%
%   Wood, E. F., D. P. Lettenmaier, and V. G. Zartarian (1992), A
%   Land-Surface Hydrology Parameterization With Subgrid Variability for 
%   General Circulation Models, J. Geophys. Res., 97(D3), 2717–2728, 
%   doi:10.1029/91JD01786. 
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure Engineering, 
%   Giancarlo Bonotto, The Department of Infrastructure Engineering, 
%   The University of Melbourne.
%
% Date:
%   March 2022   
    
    properties
                        
        % Additional Model Parameters to that of sub-class.
        %----------------------------------------------------------------
        SMSC_interflow       % Interflow Layer 2 soil moisture capacity parameter
        S_initialfrac_interflow % Interflow Layer 2 Fractional initial  soil moisture
        k_sat_interflow      % Interflow Layer 2 maximum vertical conductivity.
        alpha_interflow       % Interflow Layer 2 power term for infiltration 
        beta_interflow       % Layer 2 power term for dainage rate (eg Brook-Corey pore index power term)  
        % gamma           % Power term for soil evaporation rate. Assumed as equal to the shallow soil moisture store.  
		%----------------------------------------------------------------
    end
        
 
%%  STATIC METHODS        
% Static methods used to inform the
% user of the available model types. 
    methods(Static)
        function [variable_names, isOptionalInput] = inputForcingData_required(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates)
            variable_names = {'precip';'et'};
            isOptionalInput = [false; false];
        end
        
        function [variable_names] = outputForcingdata_options(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates)
            
            variable_names = climateTransform_soilMoistureModels.outputForcingdata_options(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates);
                
            variable_names_interflow = {'interflow_slow';'evap_soil_interflow'; 'evap_soil_total';'runoff_total';'SMS_interflow';'mass_balance_error'};
                
            variable_names = {variable_names{:}, variable_names_interflow{:}};
            variable_names = unique(variable_names);
        end
        
        function [options, colNames, colFormats, colEdits, toolTip] = modelOptions()
           
            options = { 'SMSC'           ,    2, 'Calib.';...
                        'SMSC_trees'    ,   2, 'Fixed';...
                        'treeArea_frac' , 0.5, 'Fixed'; ...
                        'S_initialfrac' , 0.5, 'Fixed'  ; ...
                        'k_infilt'      , inf,'Fixed'   ; ...
                        'k_sat'         , 1, 'Calib.'   ; ...
                        'bypass_frac'   , 0, 'Fixed'    ; ...
                        'alpha'         , 0, 'Fixed'    ; ...
                        'beta'          ,  0.5,'Calib.' ; ...
                        'gamma'         ,  0,  'Fixed'  ; ...
                        'eps'           ,   0,  'Fixed'; ...
                        'SMSC_interflow'     ,  2, 'Calib.'   ;...
                        'S_initialfrac_interflow', 0.5,'Fixed'; ...
                        'k_sat_interflow'     , 1, 'Calib.'   ;...
						'alpha_interflow'     , 0, 'Fixed'   ;...
                        'beta_interflow'     ,  0.5, 'Calib.'};

        
            colNames = {'Parameter', 'Initial Value','Fixed or Calibrated?'};
            colFormats = {'char', 'char', {'Calib.' 'Fixed'}};
            colEdits = logical([0 1 1]);

            toolTip = sprintf([ 'Use this table to define the type of soil moisture model. \n', ...
                                'Each parameter (except the soil moisture capacity) can be \n', ...
                                'set to a fixed value or calibrated. Below is a summary: \n \n' , ...
                                '   SMSC         : log10(Soil moisture capacity as water depth).\n', ...
                                '   SMSC_trees    : log10(Tree soil moisture capacity as water depth).\n', ...
                                '   treeArea_frac : Scaler applied to the tree fraction input data.\n', ...                                
                                '   S_initialfrac: Initial soil moisture fraction (0-1).\n', ...
                                '   k_infilt     : log10(Soil infiltration capacity as water depth).\n', ...
                                '   k_sat        : log10(Maximum vertical infiltration rate).\n', ...
                                '   bypass_frac  : Fraction of runoff to bypass drainage.\n', ...
                                '   alpha        : Power term for infiltration rate.\n', ...
                                '   beta         : log10(Power term for dainage rate).\n', ...
                                '   gamma        : log10(Power term for soil evap. rate).\n', ...
                                '   eps          : S_min/SMSC ratio. S_min is the minimum soil moisture threshold.',...
                                '   SMSC_interflow    : log10(Interflow layer soil moisture capacity as water depth).\n', ...
                                '   S_initialfrac_interflow: Initial interflow soil moisture fraction (0-1).\n', ...
                                '   k_sat_interflow   : log10(Interflow layer maximum vertical infiltration rate).\n', ...
								'   alpha_interflow   : log10(Power term for interflow layer infiltration rate).\n', ...
                                '   beta_interflow    : log10(Interflow layer power term for drainage rate).']);
            
        end
        
        function modelDescription = modelDescription()
           modelDescription = {'Name: climateTransform_soilMoistureModels_interflow', ...
                               '', ...
                               'Purpose: nonlinear transformation of rainfall and areal potential evaporation to a range of forcing data (eg free-drainage, runoff, interflow, baseflow) ', ...
                               'using a highly flexible two layer soil moisture model. Note, the top layer free-drains into to deeper layer or interflow layer.', ...
                               'Also, two types of land cover can be simulated using two parallel soil models (not when using interflow layer).', ...
                               '', ...                               
                               'Number of parameters: 2 to 10', ...
                               '', ...                               
                               'Options: each model parameter (excluding the soil moisture capacity) can be set to a fixed value (ie not calibrated) or calibrated.', ...
                               'Also, the input forcing data field "TreeFraction" is optional and only required if the soil model is to simulate land cover change.', ...                               
                               '', ...                               
                               'Comments: Below is a summary of the model parameters:' , ...
                                'SMSC         : log10(Soil moisture capacity as water depth).', ...
                                'SMSC_trees    : log10(Tree soil moisture capacity as water depth).', ...
                                'treeArea_frac : Scaler applied to the tree fraction input data.', ...                                                                
                                'S_initialfrac: Initial soil moisture fraction (0-1).', ...
                                'k_infilt     : log10(Soil infiltration capacity as water depth).', ...
                                'k_sat        : log10(Maximum vertical infiltration rate).', ...
                                'bypass_frac  : Fraction of runoff to bypass drainage.', ...
                                'alpha        : Power term for infiltration rate.', ...
                                'beta         : log10(Power term for dainage rate).', ...
                                'gamma        : log10(Power term for soil evap. rate).', ...
                                'eps           : S_min/SMSC ratio. S_min is the minimum soil moisture threshold.',...
                                'SMSC_interflow    : log10(Deep layer soil moisture capacity as water depth). ', ...
                                '               Input an empty value and "fixed" to for it to equal SMSC.', ...
                                'S_initialfrac_interflow: Initial interflow soil moisture fraction (0-1).\n', ...      
                                '               Input an empty value and "fixed" to for it to S_initialfrac', ...                                
                                'k_sat_interflow   : log10(interflow layer maximum vertical infiltration rate).', ...
                                '               Input an empty value and "fixed" to for it to equal k_sat.', ...
								'alpha_interflow       : Power term for interflow layer infiltration rate.', ...
                                'beta_interflow    : log10(interflow layer power term for dainage rate).', ...
                                '               Input an empty value and "fixed" to for it to beta.', ...                                
                               '', ...               
                               'References: ', ...
                               '1. Peterson & Western (2014), Nonlinear time-series modeling of unconfined groundwater head, Water Resour. Res., 50, 8330–8355', ...
							   '2. Bonotto, Peterson, Fowler, & Western (2022), HydroSight SW-GW: lumped rainfall-runoff model for the joint simulation of streamflow and groundwater in a drying climate, Geoscientific Model Development , , –', ...
							   '3. Bonotto, Peterson, Fowler, & Western (2022), Can the joint simulation of daily streamflow and groundwater head help to explain the Millennium Drought hydrology?, Water Resour. Res., , –\'};
        end        
           
    end
        
    
        
    
    methods       
%% Construct the model
        function obj = climateTransform_soilMoistureModels_interflow(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates, forcingData_reqCols, modelOptions)
% Model construction.
%
% Syntax:
%   soilModel = climateTransform_soilMoistureModels_2layer(modelOptions)   
%
% Description:
%   Builds the form of the soil moisture differential equations using user
%   input mSure, odel options. The way in which the soil moisture model is used
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
%       'SMSC_interflow'
%       This is for setting the bottom layer soil moisture storage capacity parameter.
%       The value for the second column is the initial value for this
%       parameter. This model option is required because all model variants
%       require this parameter to be set.
%
%       'k_sat'
%       This is for setting the drainage rate from the top layer. This 
%       model option is required to estimated drainage into the deep layer.
%
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
%       'beta_interflow'            - layer 2 parameter for the drainage rate power term.
%       'k_sat_interflow'           - layer 2 parameter for the maximum vertical saturated
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
            obj = obj@climateTransform_soilMoistureModels(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates, forcingData_reqCols, modelOptions);
            
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
                    if strcmp(all_parameter_names{i}, 'beta_interflow')
                        % Note, beta is transformed in the soil model to 10^beta.
                        obj.(all_parameter_names{i}) = 0;
                        
                    elseif strcmp(all_parameter_names{i}, 'k_sat_interflow')
                        % Note, k_sat is transformed in the soil model to
                        % 10^k_sat = 0 m/d.
                        obj.(all_parameter_names{i}) = -inf;                        
                        
                    elseif strcmp(all_parameter_names{i}, 'alpha_interflow')
                        obj.(all_parameter_names{i}) = 0;  
						
					elseif strcmp(all_parameter_names{i}, 'S_initialfrac_interflow')
                        obj.(all_parameter_names{i}) = 0.5; 
                        
                    else
                        obj.(all_parameter_names{i}) = 0;
                    end
                end
            end
                        
            % Check the SMSM_trees parameter is active if and only if there
            % is land cover input data.
            % if  isfield(obj.settings,'simulateLandCover') && obj.settings.simulateLandCover
               % if ~obj.settings.activeParameters.SMSC_interflow_trees 
                   % error('The trees deep soil moisture model options must include the soil moisture capacity parameter when land cover data is input.');
               % end
            % else
                % obj.settings.activeParameters.SMSC_interflow_trees = false; 
                % obj.settings.fixedParameters.SMSC_interflow_trees = true;
            % end
            
            % Check that deep parameters set to NaN are not active.
            if isnan(obj.beta_interflow) && obj.settings.activeParameters.beta_interflow
                error('"beta_interflow" can only be initialsied to Nan if it is "Fixed".');
            end                        
            if isnan(obj.k_sat_interflow) && obj.settings.activeParameters.k_sat_interflow
                error('"k_sat_interflow" can only be initialsied to Nan if it is "Fixed".');
            end                                    
			if isnan(obj.alpha_interflow) && obj.settings.activeParameters.alpha_interflow
                error('"alpha_interflow" can only be initialsied to Nan if it is "Fixed".');
            end  
            if isnan(obj.S_initialfrac_interflow) && obj.settings.activeParameters.S_initialfrac_interflow
                error('"S_initialfrac_interflow" can only be initialsied to Nan if it is "Fixed".');
            end                
            % if isnan(obj.SMSC_interflow_trees) && obj.settings.activeParameters.SMSC_interflow_trees
                % error('"SMSC_interflow_trees" can only be initialsied to Nan if it is "Fixed".');
            % end                
            if isnan(obj.SMSC_interflow) && obj.settings.activeParameters.SMSC_interflow
                error('"SMSC_interflow" can only be initialsied to Nan if it is "Fixed".');
            end     
		
		
            % Initialise interflow soil moisture variables
            obj.variables.SMS_interflow = [];           
            obj.variables.SMS_interflow_subdaily = [];
        end

%% Return fixed upper and lower bounds to the parameters.
        function [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj)
            
            % Get the parameter names.
            [params, param_names] = getParameters(obj);

            % Get the bounds from the original soil model
            [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit@climateTransform_soilMoistureModels(obj);
                        
            % Upper and lower bounds of SMSC.
            if obj.settings.activeParameters.SMSC_interflow
                ind = cellfun(@(x)(strcmp(x,'SMSC_interflow')),param_names);
                params_lowerLimit(ind,1) = log10(10);                    
                %params_upperLimit(ind,1) = Inf; 
                params_upperLimit(ind,1) = log10(1000);
            end           
            
            % Upper and lower bounds of SMSC_interflow_trees.
            % if obj.settings.activeParameters.SMSC_interflow_trees
                % ind = cellfun(@(x)(strcmp(x,'SMSC_interflow_trees')),param_names);
                % params_lowerLimit(ind,1) = log10(10);                    
                % %params_upperLimit(ind,1) = Inf; 
                % params_upperLimit(ind,1) = log10(2000);
            % end           
            
            % Upper and lower bounds of k_sat_interflow.
            if obj.settings.activeParameters.k_sat_interflow
                ind = cellfun(@(x)(strcmp(x,'k_sat_interflow')),param_names);
                % Upper and lower bounds taken from Rawls et al 1982 Estimation
                % of Soil Properties. The values are for sand loam and silty clay
                % respectively and transformed from units of cm/h to the assumed
                % input units of mm/d.            
                params_lowerLimit(ind,1) = floor(log10(0.06*24*10));
                params_upperLimit(ind,1) = ceil(log10(21*24*10));
            end                  
        
            % Upper and lower bounds of beta_interflow.
            if obj.settings.activeParameters.beta_interflow
                ind = cellfun(@(x)(strcmp(x,'beta_interflow')),param_names);
                % Note, To make the parameter range that is explored
                % more compact, the beta parameter was converted to the
                % log10 space. Prior to this transformation, the lower
                % and upper boundaries were 1 and 5. Calibration trials
                % for the Great Western Catchments, Victoria, Australia
                % found that very often this non-transformed value
                % would be >100.
                params_lowerLimit(ind,1) = 0;                    
                params_upperLimit(ind,1) = Inf; 
            end       

			% Upper and lower bounds of alpha_interflow.
            if obj.settings.activeParameters.alpha_interflow
                ind = cellfun(@(x)(strcmp(x,'alpha_interflow')),param_names);
                % Note, To make the parameter range that is explored
                % more compact, the alpha parameter was converted to the
                % log10 space. Prior to this transformation, the lower
                % and upper boundaries were 1 and 5. Calibration trials
                % for the Great Western Catchments, Victoria, Australia
                % found that very often this non-transformed value
                % would be >100.
                params_lowerLimit(ind,1) = 0; % TODO: reasonable??                    
                params_upperLimit(ind,1) = Inf; % TODO: reasonable??
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
            [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit@climateTransform_soilMoistureModels(obj);
                        
            % Upper and lower bounds of SMSC_interflow.
            if obj.settings.activeParameters.SMSC_interflow
                ind = cellfun(@(x)(strcmp(x,'SMSC_interflow')),param_names);
                params_lowerLimit(ind,1) = log10(50);
                params_upperLimit(ind,1) = log10(500);
            end           
            
            % Upper and lower bounds of SMSC_interflow_trees.
            % if obj.settings.activeParameters.SMSC_interflow_trees
                % ind = cellfun(@(x)(strcmp(x,'SMSC_interflow_trees')),param_names);
                % params_lowerLimit(ind,1) = log10(50);
                % params_upperLimit(ind,1) = log10(1000);
            % end           
            
            % Upper and lower bounds of k_sat_interflow.
            if obj.settings.activeParameters.k_sat_interflow
                ind = cellfun(@(x)(strcmp(x,'k_sat_interflow')),param_names);
                % Upper and lower bounds taken from Rawls et al 1982 Estimation
                % of Soil Properties. The values are for sand loam and silty clay
                % respectively and transformed from units of cm/h to the assumed
                % input units of mm/d.            
                params_lowerLimit(ind,1) = log10(0.09*24*10);
                params_upperLimit(ind,1) = log10(6.11*24*10);
            end                  
        
            % Upper and lower bounds of beta_interflow.
            if obj.settings.activeParameters.beta_interflow
                ind = cellfun(@(x)(strcmp(x,'beta_interflow')),param_names);
                % Note, To make the parameter range that is explored
                % more compact, the beta parameter was converted to the
                % log10 space. Prior to this transformation, the lower
                % and upper boundaries were 1 and 5. Calibration trials
                % for the Great Western Catchments, Victoria, Australia
                % found that very often this non-transformed value
                % would be >100.
                params_lowerLimit(ind,1) = log10(1);
                params_upperLimit(ind,1) = log10(5);
            end    
			
			% Upper and lower bounds of alpha_interflow.
            if obj.settings.activeParameters.alpha_interflow
                ind = cellfun(@(x)(strcmp(x,'alpha_interflow')),param_names);
                % Note, To make the parameter range that is explored
                % more compact, the beta parameter was converted to the
                % log10 space. Prior to this transformation, the lower
                % and upper boundaries were 1 and 5. Calibration trials
                % for the Great Western Catchments, Victoria, Australia
                % found that very often this non-transformed value
                % would be >100.
                params_lowerLimit(ind,1) = log10(0); % TODO: reasonable??
                params_upperLimit(ind,1) = log10(5); % TODO: reasonable??
            end   
			
        end
        
%% Solve the soil moisture differential equation
        function setTransformedForcing(obj, t, forceRecalculation)
% Syntax:
%   setTransformedForcing(obj, climateData, forceRecalculation)
%
% Description:  
%   This method solves the soil moisture differential equations for all time
%   points within the input daily climate data. The resulting soil moisture
%   fluxes are then transformed to the required form (as defined within the
%   input model options). The results from this are stored within the
%   object variables "obj.variables.evap_Forcing" and
%   "obj.variables.precip_Forcing".
%
%   Importantly, if the model parameters have not changed since the last
%   simulations, then a solution is not re-derived. Also, this method
%   requires prior compilation of the C-MEX function
%   "forcingTransform_soilMoisture.c".
%
% Input:
%   obj         - soil moisture model object.
%   climateData - a matrix (Nx3) of daily climate data where: column 1 is
%                 the date (as a floating point), column 2 is the daily 
%                 precipitation, and column 3 is the daily potential
%                 evaporation.
%   forceRecalculation - is a logical scalar input (i.e. true of false) to
%                 force re-calculation of the model and thus ingore if the
%                 parameters have or have not changed.
% Outputs:
%   (none)
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
%   Solve the differential equation:
%   >> setTransformedForcing(soilModel, climateData, true)
%
% See also:
%   climateTransform_soilMoistureModels_2layer: class_definition;
%   setParameters: set_calibration_parameters_values;
%   getParameters: get_calibration_parameters_values;
%   detectParameterChange: assesst_if_parameters_have_changed_recently;
%   getTransformedForcing: get_outputs_for_timeseries_model.
%
% Dependencies:
%   forcingTransform_soilMoisture.c
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure Engineering, 
%   The University of Melbourne.
%
% Date:
%   11 April 2012  
            if nargin==2
                forceRecalculation=false;
            end 
            if obj.variables.isNewParameters || forceRecalculation || ~isfield(obj.variables,'t') || ...
            (isfield(obj.variables,'t') && obj.variables.t(end) ~= t(end))

                % Run the top layer model
                setTransformedForcing@climateTransform_soilMoistureModels(obj, t, forceRecalculation);

                % Handle deep soil layer parameters taken from the shallow
                % layer.
                if isnan(obj.SMSC_interflow)
                    SMSC_interflow = 10^(obj.SMSC);
                else
                    SMSC_interflow = 10^obj.SMSC_interflow;
                end
                if isnan(obj.k_sat_interflow)
                    k_sat_interflow = 10^(obj.k_sat);
                else
                    k_sat_interflow = 10^(obj.k_sat_interflow);
                end
                if isnan(obj.beta_interflow)
                    beta_interflow = 10^(obj.beta);
                else
                    beta_interflow = 10^(obj.beta_interflow);
                end       
				if isnan(obj.alpha_interflow)
                    alpha_interflow = 10^(obj.alpha);
                else
                    alpha_interflow = 10^(obj.alpha_interflow);
                end    				
               
                % Set interflow initial soil moisture.
                if isnan(obj.S_initialfrac_interflow)
                    S_interflow_initial = obj.S_initialfrac.*SMSC_interflow;
                else
                    S_interflow_initial = obj.S_initialfrac_interflow.*SMSC_interflow;
                end                             
                
                % Call MEX function for DEEP soil moisture model.  
%                 if ~doSubDailyEst
                    % Get free drainage from the shallow layer
                    %drainage = getTransformedForcing(obj, 'drainage',1);
                    
                    % Calculate remaining PET after shallow ET
                    %PET = max(0,obj.variables.evap - getTransformedForcing(obj, 'evap_soil',1));
                    
                    % Calculate the interflow from the shallow layer to the interflow layer.
                    nDays = length(obj.variables.evap);
                    nDailySubSteps = getNumDailySubsteps(obj);
                    SMSC = 10^(obj.SMSC);
                    beta = 10.^(obj.beta);
                    gamma = 10.^(obj.gamma);
                    k_sat = 10.^obj.k_sat;
					% eps_interflow=0;
                    interflow_frac = obj.interflow_frac;
                    interflow = (interflow_frac) .* k_sat/obj.variables.nDailySubSteps .*(obj.variables.SMS/SMSC).^beta;                  
                    
                    % Expand input forcing data to have the required number of substeps.
                    evap = getSubDailyForcing(obj,obj.variables.evap);
                    
                    % Calc potential ET for interflow layer
                    PET = evap - getTransformedForcing(obj, 'evap_soil',1, false); 
                    
                    % Call MEX soil model
                    obj.variables.SMS_interflow = forcingTransform_soilMoisture(S_interflow_initial, interflow, PET, SMSC_interflow, k_sat_interflow/nDailySubSteps, ...
                        alpha_interflow, beta_interflow, 10.^obj.gamma, 0); % eps_interflow=0;
                    
                    % Run soil model again if tree cover is to be simulated
                    % if  isfield(obj.settings,'simulateLandCover') && obj.settings.simulateLandCover
                        
                        % if isempty(obj.SMSC_interflow_trees)
                            % SMSC_interflow_trees = 10^(obj.SMSC_trees);
                        % else
                            % SMSC_interflow_trees = obj.SMSC_interflow_trees;
                        % end
                        
                        % if isempty(obj.S_initialfrac)
                            % S_interflow_initial = obj.S_initialfrac.*SMSC_interflow_trees;
                        % else
                            % S_interflow_initial = obj.S_initialfrac_interflow * SMSC_interflow_trees;
                        % end
                        
                        % % Get free drainage from the shallow layer
                        % drainage = (1-interflow_frac) .* k_sat/obj.variables.nDailySubSteps .*(obj.variables.SMS_trees/SMSC_trees).^beta;                  
                        
                        % % Calculate remaining PET after shallow ET
                        % PET =  evap .*( 1 - (obj.variables.SMS_trees/SMSC_trees).^gamma);
                        
                        % % Call MEX function for DEEP soil moisture model.
                        % obj.variables.SMS_interflow_trees = forcingTransform_soilMoisture(S_interflow_initial, drainage, PET, SMSC_interflow_trees, ...
                            % k_sat_interflow, 0, beta_interflow, 10.^obj.gamma, 0);
                    % end
%                 else
%                     % Define the number of daily sub-steps.
%                     nSubSteps = obj.variables.nDailySubSteps;
%                     t_substeps = linspace(0,1,nSubSteps+1);
%                     
%                     % Get number of days
%                     nDays = length(effectivePrecip);
%                                         
%                     % Scale the forcing data by the number of time steps.
%                     effectivePrecip = effectivePrecip./nSubSteps;
%                     evap = obj.variables.evap./nSubSteps;
%                     
%                     % Scale ksat from units of 'per day' to 'per sub daily
%                     % time step'
%                     k_sat = k_sat./nSubSteps;
%                     
%                     % Expand input forcing data to have the required number of days.
%                     effectivePrecip = reshape(repmat(effectivePrecip,1,nSubSteps)',nDays * nSubSteps,1);
%                     evap = reshape(repmat(evap,1,nSubSteps)',nDays * nSubSteps,1);
%                     
%                     % Run the soil models using the sub-steps.
%                     obj.variables.SMS_subdaily = forcingTransform_soilMoisture(S_initial, effectivePrecip, evap, SMSC, k_sat, alpha, beta, gamma);
%                 end
                                
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
%             SMSC_interflow = params(end-4,:);
            SMSC_interflow = params(13,:);
%             SMSC_interflow_trees = params(end-3,:);
            SMSC_interflow_trees = params(14,:);
%             S_interflow_initial = params(end-2,:);
            S_interflow_initial = params(15,:);
%             k_sat_interflow = params(end-1,:);
            k_sat_interflow = params(16,:);
%             beta_interflow = params(end,:);
            beta_interflow = params(17,:);
            
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
                    if ~any(strcmp({'evap_soil_interflow','evap_soil_total', 'evap_gw_potential', ...
                    'interflow_slow','runoff_total','SMS_interflow','mass_balance_error'}, ...
                    variableName{i}))
                
                        if nargin==2
                            [forcingData(:,i), isDailyIntegralFlux(i)] = getTransformedForcing@climateTransform_soilMoistureModels(obj, variableName{i});   
                        else
                            [forcingData(:,i), isDailyIntegralFlux(i)] = getTransformedForcing@climateTransform_soilMoistureModels(obj, variableName{i}, SMSnumber, doSubstepIntegration);   
                        end
                        continue
                    end
                    
                    % Get the soil moisture store for the required soil unit
                    if nargin==2 || SMSnumber==1                               
                        SMS = obj.variables.SMS;
                        SMS_interflow = obj.variables.SMS_interflow;
                        SMSnumber = 1;
                    elseif SMSnumber==2
                        SMS = obj.variables.SMS_trees;
                        SMSC_interflow = SMSC_interflow_trees; 
                        SMS_interflow = obj.variables.SMS_interflow_trees;                    
                    else
                        error('The soil moisture unit number is unknown')
                    end                     

                    switch variableName{i}
                        case 'interflow_slow'
                            % runoff = 0;
                            % if bypass_frac~=0
                                % % Get runoff
                                % runoff = getTransformedForcing(obj, 'runoff',SMSnumber, false);
                                
                                % % Re-scale runoff from that going to the stream to that going to recharge plus the stream.
                                % runoff  = runoff ./ (1-bypass_frac);
                            % end                              
                            
                            interflow_slow =  k_sat_interflow/obj.variables.nDailySubSteps .*(SMS_interflow/SMSC_interflow).^beta_interflow;
                            % drainage = drainage + bypass_frac.*runoff;
                            if doSubstepIntegration
                                forcingData(:,i) = dailyIntegration(obj, interflow_slow);
                                isDailyIntegralFlux(i) = true;
                            else
                               forcingData(:,i) = interflow_slow;  
                               isDailyIntegralFlux(i) = false;
                            end                                                                                          
                            
                        case 'evap_soil_interflow'    
                            % Expand input forcing data to have the required number of substeps.
                            evap = getSubDailyForcing(obj,obj.variables.evap);
                            
                            %Subtract evap from shallow layer
                            evap = evap - getTransformedForcing(obj, 'evap_soil',SMSnumber, false);
                                                        
                            % Est ET
                            evap = evap .* (SMS_interflow/SMSC_interflow).^gamma;                            
                                                        
                            if doSubstepIntegration
                                forcingData(:,i) = dailyIntegration(obj, evap);
                                isDailyIntegralFlux(i) = true;
                            else
                               forcingData(:,i) = evap;  
                               isDailyIntegralFlux(i) = false;
                            end                           
                        case 'evap_soil_total'
                            evap = getTransformedForcing(obj, 'evap_soil',SMSnumber, false) + ...
                                   getTransformedForcing(obj, 'evap_soil_interflow',SMSnumber, false);
                            
                            if doSubstepIntegration
                                forcingData(:,i) = dailyIntegration(obj, evap);
                                isDailyIntegralFlux(i) = true;
                            else
                                forcingData(:,i) = evap;
                                isDailyIntegralFlux(i) = false;
                            end                            
                            
                        case 'evap_gw_potential'
                            evap = getSubDailyForcing(obj,obj.variables.evap) - getTransformedForcing(obj, 'evap_soil_total',SMSnumber, false);
                            
                            if doSubstepIntegration
                                forcingData(:,i) = dailyIntegration(obj, evap);
                                isDailyIntegralFlux(i) = true;
                            else
                                forcingData(:,i) = evap;
                                isDailyIntegralFlux(i) = false;
                            end                            
                             
                        case 'runoff_total'
                            %Calculate the runoff from the shallow layer
                            runoff = getTransformedForcing@climateTransform_soilMoistureModels(obj, 'runoff',SMSnumber, false);     
							% interflow = (interflow_frac) .* k_sat/obj.variables.nDailySubSteps .*(obj.variables.SMS/SMSC).^beta; 
							interflow = getTransformedForcing@climateTransform_soilMoistureModels(obj, 'interflow',SMSnumber, false);  							
                            runoff = runoff - interflow ;% TODO: Is it correct? subtract interflow from shallow runoff to avoid double-counting... 
							
                            % Calculate the runoff from the deep layer.
                            % Note, runoff can only occur via interflow or
                            % saturation of the interflow layer.
                            %---------------------
                            % Calculate max. infiltration assuming none
                            % goes to SATURATED runoff.
							
							if alpha_interflow==0
                                infiltration_interflow =  interflow;                                                             
                            else                                
								infiltration_interflow = interflow .* (1- SMS_interflow/SMSC_interflow).^alpha_interflow;
							end						
						
							
                            % Calc other losses.
                            evap_interflow = getTransformedForcing(obj, 'evap_soil_interflow',SMSnumber, false);       
                            % interflow_slow = k_sat_interflow/obj.variables.nDailySubSteps .*(SMS_interflow/SMSC_interflow).^beta_interflow;
							interflow_slow = getTransformedForcing(obj, 'interflow_slow',SMSnumber, false) + ...

                            
                            runoff_interflow = [0;(SMS_interflow(1:end-1) + infiltration_interflow(2:end) - evap_interflow(2:end) - interflow_slow(2:end)) - SMSC_interflow];
                            runoff_interflow(runoff_interflow<0) = 0;                            
                            %---------------------
                            
                            % Sum runoff from the top and deep layer (minus bypass runoiff to deep drainage).
                            % runoff  = runoff  + runoff_interflow * (1-bypass_frac);
                            runoff  = runoff  + runoff_interflow + (interflow - infiltration_interflow) ; % TODO: is it correct? Last term represent interflow that didn't infiltrate into interflow store
                            
                            % Integreate to daily.
                            if doSubstepIntegration
                                forcingData(:,i) = dailyIntegration(obj, runoff);
                                isDailyIntegralFlux(i) = true;
                            else
                                forcingData(:,i) = runoff;
                                isDailyIntegralFlux(i) = false;
                            end
                            
                        case'SMS_interflow'
                            forcingData(:,i) = SMS_interflow((1+obj.variables.nDailySubSteps):obj.variables.nDailySubSteps:end);
                            isDailyIntegralFlux(i) = true;

                        case 'mass_balance_error'
                            precip = getSubDailyForcing(obj,obj.variables.precip);
                            runoff = getTransformedForcing(obj, 'runoff_total',SMSnumber, false);
                            AET = getTransformedForcing(obj, 'evap_soil_total',SMSnumber, false);
                            interflow_slow = getTransformedForcing(obj, 'interflow_slow',SMSnumber, false);
                            
                            fluxEstError = [0;precip(2:end) - diff(SMS + SMS_interflow) -  runoff(2:end) - AET(2:end) - interflow_slow(2:end)];
                            
                            % Integreate to daily.
                            if doSubstepIntegration
                                forcingData(:,i) = dailyIntegration(obj, fluxEstError);
                                isDailyIntegralFlux(i) = true;
                            else
                                forcingData(:,i) = fluxEstError;
                                isDailyIntegralFlux(i) = false;
                            end
                            
                        otherwise
                            error('The requested transformed forcing variable is not known.');
                    end

                    % Get flixes for tree soil unit (if required) and weight the
                    % flux from the two units
                    % if  isfield(obj.settings,'simulateLandCover') && obj.settings.simulateLandCover && nargin==2
                        % % Get flux for tree SMS
                        % forcingData_trees = getTransformedForcing(obj, variableName{i}, 2) ;

                        % % Do weighting
                        % forcingData(:,i) = (1-treeArea_frac .* obj.variables.treeFrac) .* forcingData(:,i) + ...
                                      % treeArea_frac .* obj.variables.treeFrac .* forcingData_trees;
                    % end            
                end
            catch ME
                error(ME.message)
            end
            

            
        end
        
        function [params, param_names] = getDerivedParameters(obj)
            
            
            [params, param_names] = getDerivedParameters@climateTransform_soilMoistureModels(obj);   
            
            param_names(size(param_names,1)+1:size(param_names,1)+5) = {
                           'SMSC_interflow: back transformed soil moisture interflow layer storage capacity (in rainfall units)'; ...                  
                           % 'SMSC_interflow_trees: back transformed soil moisture interflow layer storage capacity in trees unit (in rainfall units)'; ...
                           'S_initialfrac_interflow: fractional initial interflow layer soil moisture (-)'; ... 
                           'k_sat_interflow : back transformed interflow layer maximum vertical conductivity (in rainfall units/day)'; ...
                           'beta_interflow : back transformed power term for drainage rate of interflow layer (eg approx. Brook-Corey pore index power term)'; ...
						   'alpha_interflow : back transformed power term for infiltration rate of interflow layer'};    
        
            % Handle interflow soil layer parameters taken from the shallow
            % layer.
            if isnan(obj.SMSC_interflow)
                SMSC_interflow = 10^(obj.SMSC);
            else
                SMSC_interflow = 10^obj.SMSC_interflow;
            end
            % if isnan(obj.SMSC_interflow_trees)
                % SMSC_interflow_trees = 10^(obj.SMSC_trees);
            % else
                % SMSC_interflow_trees = 10^obj.SMSC_interflow_trees;
            % end            
            if isnan(obj.k_sat_interflow)
                k_sat_interflow = 10^(obj.k_sat);
            else
                k_sat_interflow = 10^(obj.k_sat_interflow);
            end
            if isnan(obj.beta_interflow)
                beta_interflow = 10^(obj.beta);
            else
                beta_interflow = 10^(obj.beta_interflow);
            end    
			if isnan(obj.alpha_interflow)
                alpha_interflow = 10^(obj.alpha);
            else
                alpha_interflow = 10^(obj.alpha_interflow);
            end                  
            if isnan(obj.S_initialfrac_interflow)
                S_interflow_initial = obj.S_initialfrac.*SMSC_interflow;
            else
                S_interflow_initial = obj.S_initialfrac_interflow.*SMSC_interflow;
            end                         
                       
            params = [  params;  ...
                        SMSC_interflow; ...
                        % SMSC_interflow_trees; ...
                        S_interflow_initial; ...
                        k_sat_interflow; ...
                        beta_interflow; ...
						alpha_interflow];
        end        
    end

    
end

