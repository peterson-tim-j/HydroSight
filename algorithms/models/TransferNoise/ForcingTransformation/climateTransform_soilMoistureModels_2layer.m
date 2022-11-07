classdef climateTransform_soilMoistureModels_2layer < climateTransform_soilMoistureModels
% Class definition for building a time-series model of groundwater head.
%
% Description
%   climateTransform_soilMoistureModels_2layer is a generalised 2 layer 1-D
%   soil moisture model. It is used to transform the daily climate data
%   for use in the transfer noise function groundwater time series model.
%   The two soil layers have unique parametyer values (unlike the simpler
%   version 'climateTransform_soilMoistureModels_Simple2layer') and inflow 
%   to the bottom later occurs by free-drainage from the shallow layer.
%   Also, no evaporation occurs from the bottom layer.
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
%   DS_1/dt = P_inf (1 - S_1/SMSC)^alpha - k_sat (S_1/SMSC)^beta - PET (S_1/SMSC)^gamma
%
%   And the bototm layet is defined the following ordinary
%   diffenential equation:
%
%   DS_2/dt = k_sat (S_1/SMSC)^beta - k_sat_deep (S_2/SMSC_deep)^beta_deep
%
%   where:
%       S_1     - is the top layer soil moisture storage state variable [L];
%       S_2     - is the top layer soil moisture storage state variable [L];
%       t       - is time in units of days [T];
%       P_inf   - is the precipitation available for infiltration. This can
%                 be limited to a maximum infiltration rate "k_infilt". Of
%                 this parameteris not defined then P_inf equals the input
%                 daily precipitation rate.
%       SMSC    - is a parameter for the top layer soil moisture storage 
%                 capacity [L]. It is in same units as the input precipitation.
%       SMSC_deep   - is a parameter for the bottom layer soil moisture storage 
%                 capacity [L]. It is in same units as the input
%                 precipitation. Note, if equal to NULL, then SMSC_deep is 
%                 set to SMSC.
%       alpha   - is a dimensionless parameter to transform the rate at which
%                 the soil storage fills and limits infiltration. This 
%                 allows simulation of a portion of the catchment saturating
%                 and not longer allowing infiltration.
%       k_sat   - is a parameter for the saturated vertical soil water
%                 conductivity from the top layer [L T^-1]. 
%       k_sat_deep-is a parameter for the saturated vertical soil water
%                 conductivity from the bottom layer [L T^-1].   
%                 Note, if equal to NULL, then k_sat_deep is set to k_sat.
%       beta    - is a dimensionless parameter to transform the rate at
%                 which vertical free drainage occurs with filling of
%                 the top soil layer. 
%       beta_deep- is a dimensionless parameter to transform the rate at
%                 which vertical free drainage occurs with filling of
%                 the bottom soil layer. Note, if equal to NULL, then beta_deep
%                 is set to k_sat.
%       PET     - is the input daily potential evapotranspiration [L T^-1].
%       gamma   - is a dimensionless parameter to transform the rate at
%                 which soil water evaporation occurs with filling of the 
%                 soil layer.
%   
%	The 2 layer soil moisture model can also be used to simulate the impacts from
%	different vegetation; for example, trees and pastures. This is achieved
%	by simulating a soil model for upto two land types and then weighting
%	required flux from each soil model by an input time series of the
%	fraction of the second land type. A chllange with the input time series 
%	of land cover is, however, that while the fraction of, say, land
%	data clearing over time may be known the fraction of the catchment area
%	cleared that influences a bore hydrograph is unknown. To address this,
%	the modelling also include a parameter 'treeArea_frac' for the fraction
%	of the second land cover (notially trees) that is influencing the bore.
%	In summary, the simulation of tree cover requires the following two
%	parameters:
%
%       SMSC_trees - is a parameter for the shallow soil storage capacity [L]
%                  of the second soil model (notionaly trees). This is the
%                  only other parameter required for the simulation of a
%                  second soil layer (other parameters are taken from the
%                  first soil model). Also, the soil storage parameter has 
%                  the same units as the input precipitation.
%       SMSC_deep_trees - as per 'SMSC_trees' but for the bottom soil layer
%                  for the trees model.
%       treeArea_frac - is a parameter from 0 to 1 that simulates the
%                  weight to be applied to the tree cover soil model flux.
%
%   Additionally, in parametrizing the model, many of the parameters were
%   transformed to a parameter space more amenable to efficient
%   calibration. Details of the transformations are as follows:
%
%       SMSC          - log10(Top layer soil moisture capacity as water depth).
%       SMSC_deep     - log10(Bottom layer soil moisture capacity as water depth).
%       SMSC_trees    - log10(Trees top layer soil moisture capacity as water depth).
%       SMSC_deep_trees- log10(Trees bottom layer soil moisture capacity as water depth).
%       SMSC_trees    - log10(Soil moisture capacity as water depth).
%       S_initialfrac_deep - Initial soil moisture scaler (0-inf) to steady state deep S.
%       k_infilt      - log10(Soil infiltration capacity as water depth).
%       k_sat         - log10(Maximum vertical infiltration rate).
%       bypass_frac   - Fraction of runoff from shallow layer to bypass drainage (0-1).
%       interflow_frac- Fraction of free drainage from shallow layer going to interflow (0-1).
%       beta          - log10(Power term for dainage rate).
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
%   The University of Melbourne.
%
% Date:
%   11 April 2012   
    
    properties
                        
        % Additional Model Parameters to that of sub-class.
        %----------------------------------------------------------------
        SMSC_deep       % Layer 2 soil moisture capacity parameter
        SMSC_deep_trees % Layer 2 Trees soil moisture capacity parameter (as water depth)       
        S_initialfrac_deep % Layer 2 Fractional initial soil moisture
        k_sat_deep      % Layer 2  maximum vertical conductivity.
        beta_deep       % Layer 2 power term for dainage rate (eg Brook-Corey pore index power term)        
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
            
            if nargin==0
                variable_names = climateTransform_soilMoistureModels.outputForcingdata_options();
            else
                variable_names = climateTransform_soilMoistureModels.outputForcingdata_options(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates);
            end
                
            variable_names_deep = { ...
                'infiltration_deep';         'drainage_deep'         ;'evap_soil_deep';        'evap_soil_total';        'evap_gw_potential_deep';         'evap_gw_potential_total';   'runoff_deep';        'runoff_total';         'SMS_deep'; 'SMS_deep_pcnt'; ...
                'infiltration_deep_tree';    'drainage_deep_tree'    ;'evap_soil_deep_tree';   'evap_soil_total_tree';   'evap_gw_potential_deep_tree';    'evap_gw_potential_total_tree';    'runoff_deep_tree';   'runoff_total_tree'; 	 'SMS_deep_tree'; 'SMS_deep_tree_pcnt'; ...
                'infiltration_deep_nontree'; 'drainage_deep_nontree' ;'evap_soil_deep_nontree';'evap_soil_total_nontree';'evap_gw_potential_deep_nontree'; 'evap_gw_potential_total_nontree'; 'runoff_deep_nontree';'runoff_total_nontree'; 'SMS_deep_nontree'; 'SMS_deep_nontree_pcnt'; ...
                'mass_balance_error_deep'; 'mass_balance_error_deep_tree'; 'mass_balance_error_deep_nontree'; ...
                'mass_balance_error_total';'mass_balance_error_total_tree'; 'mass_balance_error_total_nontree'};

                
            variable_names = [variable_names; variable_names_deep];
            variable_names = sort(unique(variable_names));
        end
        
        function [options, colNames, colFormats, colEdits, toolTip] = modelOptions()
           
            options = { 'SMSC'           ,    2, 'Calib.';...
                        'SMSC_trees'    ,   2, 'Fixed';...
                        'treeArea_frac' , 0.5, 'Fixed'; ...
                        'S_initialfrac' , 1, 'Fixed'  ; ...
                        'k_infilt'      , inf,'Fixed'   ; ...
                        'k_sat'         , 1, 'Calib.'   ; ...
                        'bypass_frac'   , 0, 'Fixed'    ; ...
                        'alpha'         , 1, 'Fixed'    ; ...
                        'beta'          ,  0.5,'Calib.' ; ...
                        'gamma'         ,  0,  'Calib.'  ; ...
                        'eps'           ,   0,  'Fixed'; ...
                        'SMSC_deep'     ,  2, 'Calib.'   ;
                        'SMSC_deep_trees',   2, 'Fixed';...
                        'S_initialfrac_deep', 1,'Fixed'; ...
                        'k_sat_deep'     , 1, 'Calib.'   ;
                        'beta_deep'     ,  0.5, 'Calib.'};

        
            colNames = {'Parameter', 'Initial Value','Fixed or Calibrated?'};
            colFormats = {'char', 'char', {'Calib.' 'Fixed'}};
            colEdits = logical([0 1 1]);

            toolTip = sprintf([ 'SMSC         : log10(Soil moisture capacity).\n', ...
                                'SMSC_trees   : log10(Tree SMSC).\n', ...
                                'treeArea_frac: Tree fraction scalar.\n', ...                                
                                'S_initialfrac: Initial soil moisture scaler.\n', ...
                                'k_infilt     : log10(Max. infilt. capacity).\n', ...
                                'k_sat        : log10(Max. drainage rate).\n', ...
                                'bypass_frac  : Frac. runoff to bypass drainage.\n', ...
                                'interflow_frac: Frac. drainage to interflow.\n', ...
                                'alpha        : Power term for infilt. rate.\n', ...
                                'beta         : log10(Power term for dainage).\n', ...
                                'gamma        : log10(Power term for soil evap.).\n', ...
                                'eps          : Threshold SMSC frac. for runoff.\n', ...
                                'SMSC_deep    : log10(Deep SMSC).\n', ...
                                'SMSC_deep_trees: log10(Deep tree SMSC).\n', ...
                                'S_initialfrac_deep: Initial deep soil moisture scaler\n', ...
                                'k_sat_deep   : log10(Deep max. drainage rate).\n', ...
                                'beta_deep    : log10(Deep power term for dainage).']);
            
        end
        
        function modelDescription = modelDescription()
           modelDescription = {'Name: climateTransform_soilMoistureModels_2layer', ...
                               '', ...
                               'Purpose: nonlinear transformation of rainfall and areal potential evaporation to a range of forcing data (eg free-drainage) ', ...
                               'using a highly flexible two layer soil moisture model. Note, the top layer free-drains into to deeper layer.', ...
                               'Also, two types of land cover can be simulated using two parrallel soil models.', ...
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
                                'S_initialfrac: Initial soil moisture scaler of steady state soln (0-10).', ...
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
                                'S_initialfrac_deep: Initial soil moisture scaler of steady state soln (0-10).', ...      
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
        function obj = climateTransform_soilMoistureModels_2layer(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates, forcingData_reqCols, modelOptions)
% Model construction.
%
% Syntax:
%   soilModel = climateTransform_soilMoistureModels_2layer(modelOptions)   
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
                    if strcmp(all_parameter_names{i}, 'beta_deep')
                        % Note, beta is transformed in the soil model to 10^beta.
                        obj.(all_parameter_names{i}) = 0;
                        
                    elseif strcmp(all_parameter_names{i}, 'k_sat_deep')
                        % Note, k_sat is transformed in the soil model to
                        % 10^k_sat = 0 m/d.
                        obj.(all_parameter_names{i}) = -inf;                        
                        
                    elseif strcmp(all_parameter_names{i}, 'S_initialfrac_deep')
                        obj.(all_parameter_names{i}) = 1;  
                        
                    else
                        obj.(all_parameter_names{i}) = 0;
                    end
                end
            end
                        
            % Check the SMSM_trees parameter is active if and only if there
            % is land cover input data.
            if  isfield(obj.settings,'simulateLandCover') && obj.settings.simulateLandCover
               if ~obj.settings.activeParameters.SMSC_deep_trees 
                   error('The trees deep soil moisture model options must include the soil moisture capacity parameter when land cover data is input.');
               end
            else
                obj.settings.activeParameters.SMSC_deep_trees = false; 
                obj.settings.fixedParameters.SMSC_deep_trees = true;
            end
            
            % Check that deep parameters set to NaN are not active.
            if isnan(obj.beta_deep) && obj.settings.activeParameters.beta_deep
                error('"beta_deep" can only be initialsied to Nan if it is "Fixed".');
            end                        
            if isnan(obj.k_sat_deep) && obj.settings.activeParameters.k_sat_deep
                error('"k_sat_deep" can only be initialsied to Nan if it is "Fixed".');
            end                                    
            if isnan(obj.S_initialfrac_deep) 
                error('"S_initialfrac_deep" can only be initialsied to Nan if it is "Fixed".');
            end                
            if isnan(obj.SMSC_deep_trees) && obj.settings.activeParameters.SMSC_deep_trees
                error('"SMSC_deep_trees" can only be initialsied to Nan if it is "Fixed".');
            end                
            if isnan(obj.SMSC_deep) && obj.settings.activeParameters.SMSC_deep_trees
                error('"SMSC_deep" can only be initialsied to Nan if it is "Fixed".');
            end                
                     
            % Initialise soil moisture variables
            obj.variables.SMS_deep = [];           
            obj.variables.SMS_deep_subdaily = [];
        end

%% Return fixed upper and lower bounds to the parameters.
        function [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj)
            
            % Get the parameter names.
            [params, param_names] = getParameters(obj);

            % Get the bounds from the original soil model
            [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit@climateTransform_soilMoistureModels(obj);
                        
            % Upper and lower bounds of SMSC.
            if obj.settings.activeParameters.SMSC_deep
                ind = cellfun(@(x)(strcmp(x,'SMSC_deep')),param_names);
                params_lowerLimit(ind,1) = log10(25);                    
                %params_upperLimit(ind,1) = Inf; 
                params_upperLimit(ind,1) = log10(1000);
            end           
            
            % Upper and lower bounds of SMSC_deep_trees.
            if obj.settings.activeParameters.SMSC_deep_trees
                ind = cellfun(@(x)(strcmp(x,'SMSC_deep_trees')),param_names);
                params_lowerLimit(ind,1) = log10(25);                    
                %params_upperLimit(ind,1) = Inf; 
                params_upperLimit(ind,1) = log10(2000);
            end           
            
            if obj.settings.activeParameters.S_initialfrac_deep
                ind = cellfun(@(x)(strcmp(x,'S_initialfrac_deep')),param_names);
                params_lowerLimit(ind,1) = 0;                                    
                params_upperLimit(ind,1) = 10;                                    
            end    

            % Upper and lower bounds of k_sat_deep.
            if obj.settings.activeParameters.k_sat_deep
                ind = cellfun(@(x)(strcmp(x,'k_sat_deep')),param_names);
                % Upper and lower bounds taken from Rawls et al 1982 Estimation
                % of Soil Properties. The values are for sand loam and silty clay
                % respectively and transformed from units of cm/h to the assumed
                % input units of mm/d.            
                params_lowerLimit(ind,1) = floor(log10(0.06*24*10));
                params_upperLimit(ind,1) = ceil(log10(21*24*10));
            end                  
        
            % Upper and lower bounds of beta_deep.
            if obj.settings.activeParameters.beta_deep
                ind = cellfun(@(x)(strcmp(x,'beta_deep')),param_names);
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
                        
            % Upper and lower bounds of SMSC.
            if obj.settings.activeParameters.SMSC_deep
                ind = cellfun(@(x)(strcmp(x,'SMSC_deep')),param_names);
                params_lowerLimit(ind,1) = log10(50);
                params_upperLimit(ind,1) = log10(500);
            end           
            
            % Upper and lower bounds of SMSC_deep_trees.
            if obj.settings.activeParameters.SMSC_deep_trees
                ind = cellfun(@(x)(strcmp(x,'SMSC_deep_trees')),param_names);
                params_lowerLimit(ind,1) = log10(50);
                params_upperLimit(ind,1) = log10(1000);
            end           
            
            if obj.settings.activeParameters.S_initialfrac_deep
                ind = cellfun(@(x)(strcmp(x,'S_initialfrac_deep')),param_names);
                params_lowerLimit(ind,1) = 0;                                    
                params_upperLimit(ind,1) = 2;                                    
            end    

            % Upper and lower bounds of k_sat_deep.
            if obj.settings.activeParameters.k_sat_deep
                ind = cellfun(@(x)(strcmp(x,'k_sat_deep')),param_names);
                % Upper and lower bounds taken from Rawls et al 1982 Estimation
                % of Soil Properties. The values are for sand loam and silty clay
                % respectively and transformed from units of cm/h to the assumed
                % input units of mm/d.            
                params_lowerLimit(ind,1) = log10(0.09*24*10);
                params_upperLimit(ind,1) = log10(6.11*24*10);
            end                  
        
            % Upper and lower bounds of beta_deep.
            if obj.settings.activeParameters.beta_deep
                ind = cellfun(@(x)(strcmp(x,'beta_deep')),param_names);
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

                % Get number of subdailys steps
                nDailySubSteps = getNumDailySubsteps(obj);

                % Handle deep soil layer parameters taken from the shallow
                % layer.
                if isnan(obj.SMSC_deep)
                    SMSC_deep = 10^(obj.SMSC);
                else
                    SMSC_deep = 10^obj.SMSC_deep;
                end
                if isnan(obj.k_sat_deep)
                    k_sat_deep = 10^(obj.k_sat)/nDailySubSteps;
                else
                    k_sat_deep = 10^(obj.k_sat_deep)/nDailySubSteps;
                end
                if isnan(obj.beta_deep)
                    beta_deep = 10^(obj.beta);
                else
                    beta_deep = 10^(obj.beta_deep);
                end    
                if isnan(obj.S_initialfrac_deep)
                    S_initialfrac = obj.S_initialfrac;
                else
                    S_initialfrac = obj.S_initialfrac_deep;
                end                    
                gamma = 10.^obj.gamma;
               
                % Ensure all infiltration to the deep layer infiltrates 
                eps = 0;
                alpha = 0;
                
                % Call MEX function for DEEP soil moisture model.
                %-------------------
                % Get required fluxes from the shallow layer.
                doSubstepIntegration = false;
                if  isfield(obj.settings,'simulateLandCover') && obj.settings.simulateLandCover
                    fluxes = getTransformedForcing(obj, {'evap_soil_nontree','drainage_nontree'}, doSubstepIntegration);
                    evap_soil = subDailyMatrix2Vector(obj,fluxes.evap_soil_nontree);
                    drainage = subDailyMatrix2Vector(obj,fluxes.drainage_nontree);                    
                else
                    fluxes = getTransformedForcing(obj, {'evap_soil','drainage'}, doSubstepIntegration);
                    evap_soil = subDailyMatrix2Vector(obj,fluxes.evap_soil);
                    drainage = subDailyMatrix2Vector(obj,fluxes.drainage);
                end


                % Expand input forcing data to have the required number of substeps.
                PET = getSubDailyForcing(obj,obj.variables.evap);

                % Calc potential ET for deep layer
                PET = PET - evap_soil;

                % Set the initial soil moisture as the steady state soln
                % and then multiply by the scaling fraction (S_initialfrac_deep)
                fun = @(S) mean(drainage)*((SMSC_deep-S)/(SMSC_deep*(1-eps)))^alpha - k_sat_deep*(S/SMSC_deep)^beta_deep - mean(PET)*(S/SMSC_deep)^gamma;
                S_deep_initial=fzero(fun,[0, SMSC_deep]);
                S_deep_initial = min(max(0, S_deep_initial.* S_initialfrac), SMSC_deep);
                
                % Call MEX soil model
                obj.variables.SMS_deep = forcingTransform_soilMoisture(S_deep_initial, drainage, PET, SMSC_deep, k_sat_deep, ...
                    alpha, beta_deep, gamma, eps);

                % Run soil model again if tree cover is to be simulated
                if  isfield(obj.settings,'simulateLandCover') && obj.settings.simulateLandCover

                    if isempty(obj.SMSC_deep_trees)
                        SMSC_deep_trees = 10^(obj.SMSC_trees);
                    else
                        SMSC_deep_trees = obj.SMSC_deep_trees;
                    end

                    % Get required fluxes from the shallow layer.                    
                    fluxes = getTransformedForcing(obj, {'evap_soil_tree','drainage_tree'},doSubstepIntegration);
                    evap_soil = subDailyMatrix2Vector(obj,fluxes.evap_soil_tree);
                    drainage = subDailyMatrix2Vector(obj,fluxes.drainage_tree);

                    % Expand input forcing data to have the required number of substeps.
                    PET = getSubDailyForcing(obj,obj.variables.evap);

                    % Calc potential ET for deep layer
                    PET = PET - evap_soil;

                    % Set the initial soil moisture as the steady state soln
                    % and then multiply by the scaling fraction (S_initialfrac)
                    fun = @(S) mean(drainage)*((SMSC_deep_trees-S)/(SMSC_deep_trees*(1-eps)))^alpha - k_sat_deep*(S/SMSC_deep_trees)^beta_deep - mean(PET)*(S/SMSC_deep_trees)^gamma;
                    S_deep_initial=fzero(fun,[0, SMSC_deep_trees]);
                    S_deep_initial = min(max(0, S_deep_initial.* S_initialfrac), SMSC_deep_trees);

                    % Call MEX function for DEEP soil moisture model.
                    obj.variables.SMS_deep_trees = forcingTransform_soilMoisture(S_deep_initial, drainage, PET, SMSC_deep_trees, ...
                        k_sat_deep, alpha, beta_deep, 10.^obj.gamma, eps);
                end
            end
        end
        
%% Return the transformed forcing data
        function [forcingData, isDailyIntegralFlux] = getTransformedForcing(obj, variableName, doSubstepIntegration) 
% getTransformedForcing returns the required flux from the soil model.
%
% Syntax:
%   [precip_Forcing, et_Forcing] = getTransformedForcing(obj, variableName)
%   [precip_Forcing, et_Forcing] = getTransformedForcing(obj, variableName, doSubstepIntegration)
%
% Description:  
%   This method returns the requested flux/data from the soil moisture 
%   differential equation. A subset of the available fluxes/data are as
%   follows. Note, when obj.settings.simulateLandCover==true and
%   VariableName does not include the extension '_tree' or '_nontree' then
%   the flux is derived for both the non-tree and tree soil stores and
%   weighted to produce a combined estimate.
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
%   doSubstepIntegration - numerically integrate the user-defined number of
%   subdaily timesteps to daily.
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
            beta = params(10,:);
            gamma = params(11,:); 
            SMSC_deep = params(end-4,:);
            SMSC_deep_trees = params(end-3,:);
            S_deep_initial = params(end-2,:);
            k_sat_deep = params(end-1,:);
            beta_deep = params(end,:);
            
            % Set if the subdaily steps should be integrated.      
            if nargin < 3
                doSubstepIntegration = true;
            end
            
            % Define list of fluxes able to be calc. within the 2-layer
            % class def.
            variableName_2layerOptions = { ...
                'infiltration_deep';         'drainage_deep'         ;'evap_soil_deep';        'evap_soil_total';        'evap_gw_potential_deep';         'evap_gw_potential_total';   'runoff_deep';        'runoff_total';         'SMS_deep'; 'SMS_deep_pcnt'; ...
                'infiltration_deep_tree';    'drainage_deep_tree'    ;'evap_soil_deep_tree';   'evap_soil_total_tree';   'evap_gw_potential_deep_tree';    'evap_gw_potential_total_tree';    'runoff_deep_tree';   'runoff_total_tree'; 	 'SMS_deep_tree'; 'SMS_deep_tree_pcnt'; ...
                'infiltration_deep_nontree'; 'drainage_deep_nontree' ;'evap_soil_deep_nontree';'evap_soil_total_nontree';'evap_gw_potential_deep_nontree'; 'evap_gw_potential_total_nontree'; 'runoff_deep_nontree';'runoff_total_nontree'; 'SMS_deep_nontree'; 'SMS_deep_nontree_pcnt'; ...
                'mass_balance_error_deep'; 'mass_balance_error_deep_tree'; 'mass_balance_error_deep_nontree'; ...
                'mass_balance_error_total';'mass_balance_error_total_tree'; 'mass_balance_error_total_nontree'};

            % Get fluxes for top layer.
            ind = cellfun(@(x) ~any(strcmp(x,variableName_2layerOptions)), variableName);
            isDailyIntegralFlux = false(length(variableName),1);
            if any(ind)
                if nargin==2
                    [forcingData, isDailyIntegralFlux] = getTransformedForcing@climateTransform_soilMoistureModels(obj, variableName(ind), true);
                else
                    [forcingData, isDailyIntegralFlux] = getTransformedForcing@climateTransform_soilMoistureModels(obj, variableName(ind), doSubstepIntegration);
                end
            end

            % Get index to fields not yet calculated.
            ind = ~ind;

            % Return of no fluxes from deep layer are to be calculated.
            if ~any(ind)
                return
            end            
            for i=find(ind)
                try
                    % Get the soil moisture store for the required soil unit
                    if contains(variableName{i}, '_nontree')
                        SMS_deep = obj.variables.SMS_deep;
                        variabName_suffix = '_nontree';
                    elseif contains(variableName{i}, '_tree')
                        SMSC_deep = SMSC_deep_trees;
                        SMS_deep = obj.variables.SMS_deep_trees;
                        variabName_suffix = '_tree';
                    else
                        SMS_deep = obj.variables.SMS_deep;
                        variabName_suffix = '';
                    end

                    % Convert subdaily soil moisture to a matrix, if not done by
                    % setTransformedForcing().
                    SMS_deep = subDailyVector2Matrix(obj, SMS_deep, false);

                    % Get flixes for tree soil unit (if required) and weight the
                    % flux from the two units, else get the deep fluxes
                    % without the tree/nontree status.
                    if  isfield(obj.settings,'simulateLandCover') && obj.settings.simulateLandCover && isempty(variabName_suffix)
                        % Get flux for tree SMS
                        [fluxes_nontree, isDailyIntegralFlux(i)] = getTransformedForcing(obj, strcat(variableName{i},'_nontree'), doSubstepIntegration);
                        fluxes_tree = getTransformedForcing(obj, strcat(variableName{i},'_tree'), doSubstepIntegration);

                        % Do weighting
                        forcingData.(variableName{i}) = (1-treeArea_frac .* obj.variables.treeFrac) .* fluxes_nontree.(strcat(variableName{i},'_nontree')) + ...
                            treeArea_frac .* obj.variables.treeFrac .* fluxes_tree.(strcat(variableName{i},'_tree'));
                    else
                        switch variableName{i}
                            case {'drainage_deep', 'drainage_deep_tree', 'drainage_deep_nontree'}
                                nDailySubSteps = getNumDailySubsteps(obj);
                                drainage = k_sat_deep/nDailySubSteps .*(SMS_deep/SMSC_deep).^beta_deep;
                                if doSubstepIntegration
                                    forcingData.(variableName{i}) = dailyIntegration(obj, drainage);
                                    isDailyIntegralFlux(i) = true;
                                else
                                    forcingData.(variableName{i}) = drainage;
                                    isDailyIntegralFlux(i) = false;
                                end

                            case {'evap_soil_deep', 'evap_soil_deep_tree', 'evap_soil_deep_nontree'}
                                % Expand input forcing data to have the required number of substeps.
                                evap = getSubDailyForcing(obj,obj.variables.evap);
                                evap = subDailyVector2Matrix(obj, evap, true);

                                %Subtract evap from shallow layer
                                fluxes = getTransformedForcing(obj, strcat('evap_soil',variabName_suffix), false);
                                evap = evap - fluxes.(strcat('evap_soil',variabName_suffix));

                                % Est ET
                                evap = evap .* (SMS_deep/SMSC_deep).^gamma;                            %#ok<PROPLC>

                                if doSubstepIntegration
                                    forcingData.(variableName{i}) = dailyIntegration(obj, evap);
                                    isDailyIntegralFlux(i) = true;
                                else
                                    forcingData.(variableName{i}) = evap;
                                    isDailyIntegralFlux(i) = false;
                                end
                            case {'infiltration_deep', 'infiltration_deep_tree', 'infiltration_deep_nontree'}
                                % Calculate max. infiltration assuming none
                                % goes to SATURATED runoff.
                                if doSubstepIntegration
                                    fluxes = getTransformedForcing(obj, strcat({'drainage_deep','drainage','evap_soil_deep'},variabName_suffix), true);

                                    infiltration =  fluxes.(strcat('drainage',variabName_suffix));

                                    % Calculatre when the soil is probably saturated.
                                    Infilt2Runoff = (SMS_deep(:,1) + infiltration - fluxes.(strcat('evap_soil_deep',variabName_suffix)) - ...
                                        fluxes.(strcat('drainage_deep',variabName_suffix))) - SMSC_deep; %#ok<PROPLC>
                                    Infilt2Runoff(Infilt2Runoff<0) = 0;

                                    % Subtract estimated satruated excess runoff
                                    % from the infiltration and then integrate.
                                    infiltration = infiltration - Infilt2Runoff;

                                    % Subtract from precip.
                                    forcingData.(variableName{i}) = infiltration;
                                    isDailyIntegralFlux(i) = true;
                                else
                                    error('Infiltration can only be calculated at a daily timestep.')
                                end
                            case {'evap_soil_total', 'evap_soil_total_tree', 'evap_soil_total_nontree'}
                                fluxes = getTransformedForcing(obj, strcat({'evap_soil','evap_soil_deep'},variabName_suffix), false);
                                evap = fluxes.(strcat('evap_soil',variabName_suffix)) + fluxes.(strcat('evap_soil_deep',variabName_suffix));

                                if doSubstepIntegration
                                    forcingData.(variableName{i}) = dailyIntegration(obj, evap);
                                    isDailyIntegralFlux(i) = true;
                                else
                                    forcingData.(variableName{i}) = evap;
                                    isDailyIntegralFlux(i) = false;
                                end

                            case {'evap_gw_potential_total', 'evap_gw_potential_total_tree', 'evap_gw_potential_total_nontree'}
                                % Expand input forcing data to have the required number of substeps.
                                PET = getSubDailyForcing(obj,obj.variables.evap);
                                PET = subDailyVector2Matrix(obj, PET, true);

                                % Get soil ET
                                fluxes = getTransformedForcing(obj, strcat('evap_soil_total',variabName_suffix), false);

                                % Calc groundwater PET
                                evap = PET - fluxes.(strcat('evap_soil_total',variabName_suffix));

                                if doSubstepIntegration
                                    forcingData.(variableName{i}) = dailyIntegration(obj, evap);
                                    isDailyIntegralFlux(i) = true;
                                else
                                    forcingData.(variableName{i}) = evap;
                                    isDailyIntegralFlux(i) = false;
                                end

                            case {'evap_gw_potential_deep', 'evap_gw_potential_deep_tree', 'evap_gw_potential_deep_nontree'}
                                % Expand input forcing data to have the required number of substeps.
                                PET = getSubDailyForcing(obj,obj.variables.evap);
                                PET = subDailyVector2Matrix(obj, PET, true);

                                % Get soil ET
                                fluxes = getTransformedForcing(obj, strcat('evap_soil_deep',variabName_suffix), false);

                                % Calc groundwater PET
                                evap = PET - fluxes.(strcat('evap_soil_deep',variabName_suffix));

                                if doSubstepIntegration
                                    forcingData.(variableName{i}) = dailyIntegration(obj, evap);
                                    isDailyIntegralFlux(i) = true;
                                else
                                    forcingData.(variableName{i}) = evap;
                                    isDailyIntegralFlux(i) = false;
                                end
                                
                            case {'runoff_deep', 'runoff_deep_tree', 'runoff_deep_nontree'}
                                %Calculate the influxes into and out of the deep layer.
                                if doSubstepIntegration
                                    fluxes = getTransformedForcing(obj, strcat({'infiltration_deep','drainage'},variabName_suffix), true);

                                    forcingData.(variableName{i}) = max(0, fluxes.(strcat('drainage',variabName_suffix)) - fluxes.(strcat('infiltration_deep',variabName_suffix)));
                                    isDailyIntegralFlux(i) = true;
                                else
                                    error('Runoff can only be calculated at a daily timestep.')
                                end
                            case {'runoff_total', 'runoff_total_tree', 'runoff_total_nontree'}
                                %Calculate the runoff from the shallow and deep
                                %layers and sum
                                if doSubstepIntegration
                                    fluxes = getTransformedForcing(obj, strcat({'runoff', 'runoff_deep'},variabName_suffix), true);
                                    forcingData.(variableName{i}) = fluxes.(strcat('runoff',variabName_suffix))  + fluxes.(strcat('runoff_deep',variabName_suffix));
                                    isDailyIntegralFlux(i) = true;
                                else
                                    error('Runoff can only be calculated at a daily timestep.')
                                end
                            case {'SMS_deep', 'SMS_deep_tree', 'SMS_deep_nontree'}
                                if doSubstepIntegration
                                    forcingData.(variableName{i}) = SMS_deep(:,1);   % Returns value at the start of each day.
                                else
                                    forcingData.(variableName{i}) = SMS_deep;
                                end
                                isDailyIntegralFlux(i) = false;

                            case {'SMS_deep_pcnt', 'SMS_deep_tree_pcnt', 'SMS_deep_nontree_pcnt'}
                                if doSubstepIntegration
                                    forcingData.(variableName{i}) = 100.*SMS_deep(:,1)./SMSC_deep;   % Returns value at the start of each day.
                                else
                                    forcingData.(variableName{i}) = 100.*SMS_deep./SMSC_deep;
                                end
                                isDailyIntegralFlux(i) = false;
                                
                            case {'mass_balance_error_deep', 'mass_balance_error_deep_tree', 'mass_balance_error_deep_nontree'}
                                % Calculate fluxes at daily or subdaily time
                                % step and then calc. mass balance error
                                if doSubstepIntegration
                                    % Get fluxes
                                    fluxes = getTransformedForcing(obj, strcat({'drainage','runoff_deep','evap_soil_deep', 'drainage_deep','SMS_deep'},variabName_suffix), true);

                                    % Calc mass balance error
                                    fluxEstError = [fluxes.(strcat('drainage',variabName_suffix))(1:(end-1),1) - diff(fluxes.SMS_deep) - ...
                                        fluxes.(strcat('runoff_deep',variabName_suffix))(1:(end-1),1) - ...
                                        fluxes.(strcat('evap_soil_deep',variabName_suffix))(1:(end-1),1) - fluxes.(strcat('drainage_deep',variabName_suffix))(1:(end-1),1);0];

                                    isDailyIntegralFlux(i) = true;
                                else
                                    error('Mass balance can only be calculated at a daily timestep.')
                                end

                                forcingData.(variableName{i}) = fluxEstError;

                            case {'mass_balance_error_total', 'mass_balance_error_total_tree', 'mass_balance_error_total_nontree'}
                                % Calculate fluxes at daily or subdaily time
                                % step and then calc. mass balance error
                                if doSubstepIntegration
                                    % Get daily fluxes
                                    precip = obj.variables.precip;
                                    fluxes = getTransformedForcing(obj, strcat({'runoff_total','evap_soil_total','drainage_deep','SMS','SMS_deep'},variabName_suffix), true);

                                    % Calc mass balance error
                                    fluxEstError = [precip(1:(end-1),1) - diff(fluxes.SMS) - diff(fluxes.SMS_deep) -  fluxes.(strcat('runoff_total',variabName_suffix))(1:(end-1),1) - ...
                                        fluxes.(strcat('evap_soil_total',variabName_suffix))(1:(end-1),1) - fluxes.(strcat('drainage_deep',variabName_suffix))(1:(end-1),1);0];

                                    isDailyIntegralFlux(i) = true;
                                else
                                    error('Mass balance can only be calculated at a daily timestep.')
                                end

                                forcingData.(variableName{i}) = fluxEstError;
                            otherwise
                                error('The requested transformed forcing variable is not known.');
                        end
                    end
                catch ME
                    error(ME.message)
                end
            end
        end
        
        function [params, param_names] = getDerivedParameters(obj)
            
            
            [params, param_names] = getDerivedParameters@climateTransform_soilMoistureModels(obj);   
            
            param_names(size(param_names,1)+1:size(param_names,1)+5) = {
                           'SMSC_deep: back transformed soil moisture deep layer storage capacity (in rainfall units)'; ...                  
                           'SMSC_deep_trees: back transformed soil moisture deep layer storage capacity in trees unit (in rainfall units)'; ...
                           'S_initialfrac_deep: initial deep layer soil moisture scaler (-)'; ... 
                           'k_sat_deep : back transformed deep layer maximum vertical conductivity (in rainfall units/day)'; ...
                           'beta_deep : back transformed power term for dainage rate of deep layer (eg approx. Brook-Corey pore index power term)'};    
        
            % Handle deep soil layer parameters taken from the shallow
            % layer.
            if isnan(obj.SMSC_deep)
                SMSC_deep = 10^(obj.SMSC);
            else
                SMSC_deep = 10^obj.SMSC_deep;
            end
            if isnan(obj.SMSC_deep_trees)
                SMSC_deep_trees = 10^(obj.SMSC_trees);
            else
                SMSC_deep_trees = 10^obj.SMSC_deep_trees;
            end            
            if isnan(obj.k_sat_deep)
                k_sat_deep = 10^(obj.k_sat);
            else
                k_sat_deep = 10^(obj.k_sat_deep);
            end
            if isnan(obj.beta_deep)
                beta_deep = 10^(obj.beta);
            else
                beta_deep = 10^(obj.beta_deep);
            end                
            if isnan(obj.S_initialfrac_deep)
                S_deep_initial = obj.S_initialfrac;
            else
                S_deep_initial = obj.S_initialfrac_deep;
            end                         
                       
            params = [  params;  ...
                        SMSC_deep; ...
                        SMSC_deep_trees; ...
                        S_deep_initial; ...
                        k_sat_deep; ...
                        beta_deep];
        end        
    end

    
end

