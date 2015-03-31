classdef climateTransform_soilMoistureModels < forcingTransform_abstract 
% Class definition for building a time-series model of groundwater head.
%
% Description        
%   climateTransform_soilMoistureModels is a generalised vertically lumped 1-D
%   soil moisture model. It is used to transform the daily climate data
%   for use in the transfer noise function groundwater time series model.
%   Importantly, a user of the groundwater time series model has no need to
%   run any of these soil moisture model methods. All of the methods are
%   automatically called by the function "model_TFN.m".
%    
%   The precipitation can be transformed into a daily infiltration rate
%   or daily free-draiage rate. The potential evapotranspiration can be
%   transformed into a daily actual evapotranspiration rate or a daily 
%   remaining potential evapotranspiration.
%   
%   The soil moisture model is defined by the following ordinary
%   diffenential equation (Kavetski et al. 2006):
%   
%   DS/dt = P_inf (1 - S/SMSC)^alpha - k_sat (S/SMSC)^beta - PET (S/SMSC)^gamma
%
%   where:
%       S       - is the soil moisture storage state variable [L];
%       t       - is time in units of days [T];
%       P_inf   - is the precipitation available for infiltration. This can
%                 be limited to a maximum infiltration rate "k_infilt". Of
%                 this parameteris not defined then P_inf equals the input
%                 daily precipitation rate.
%       SMSC    - is a parameter for the soil moisture storage capacity [L].
%                 It is in same units as the input precipitation.
%       alpha   - is a dimensionless parameter to transform the rate at which
%                 the soil storage fills and limits infiltration. This 
%                 allows simulation of a portion of the catchment saturating
%                 and not longer allowing infiltration.
%       k_sat   - is a parameter for the saturated vertical soil water
%                 conductivity [L T^-1]. 
%       beta    - is a dimensionless parameter to transform the rate at
%                 which vertical free drainage occurs with filling of
%                 the soil layer.
%       PET     - is the input daily potential evapotranspiration [L T^-1].
%       gamma   - is a dimensionless parameter to transform the rate at
%                 which soil water evaporation occurs with filling of the 
%                 soil layer.
%       S_initialfrac - the initial soil moistire.
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
    
    properties(GetAccess=public, SetAccess=protected)
                        
        % Model Parameters
        %----------------------------------------------------------------
        SMSC            % Soil moisture capacity parameter (as water depth)
        S_initialfrac    % Initial soil moisture 
        k_infilt        % Maximum infiltration rate.
        k_sat           % Maximum vertical conductivity.
        bypass_frac     % Fraction of runoff that goes to bypass drainage
        alpha           % Power term for infiltration.        
        beta            % Power term for dainage rate (eg Brook-Corey pore index power term)
        gamma           % Power term for soil evaporation rate.        
        %----------------------------------------------------------------        
    end


    
%%  STATIC METHODS        
% Static methods used to inform the
% user of the available model types. 
    methods(Static)
        function [variable_names] = inputForcingData_required()
            variable_names = {'precip';'et'};
        end
        
        function [variable_names] = outputForcingdata_options()
            variable_names = {'drainage';'drainage_bypassFlow';'drainage_normalised';'infiltration';'evap_soil';'evap_gw_potential';'runoff';'SMS'};
        end
        
        function [options, colNames, colFormats, colEdits, toolTip] = modelOptions()
           
            options = {'SMSC'           ,    2, 'Calib.';...
                        'S_initialfrac' , 0.5, 'Fixed'  ; ...
                        'k_infilt'      , inf,'Fixed'   ; ...
                        'k_sat'         , 1, 'Calib.'   ; ...
                        'bypass_frac'   , 0, 'Fixed'    ; ...
                        'alpha'         , 0, 'Fixed'    ; ...
                        'beta'          ,  0.5,'Calib.' ; ...
                        'gamma'         ,  0,  'Fixed'};

        
            colNames = {'Parameter', 'Initial Value','Fixed or Calibrated?'};
            colFormats = {'char', 'char', {'Calib.' 'Fixed'}};
            colEdits = logical([0 1 1]);

            toolTip = sprintf([ 'Use this table to define the type of soil moisture model. \n', ...
                                'Each parameter (except the soil moisture capacity) can be \n', ...
                                'set to a fixed value or calibrated. Below is a summary: \n \n' , ...
                                '   SMSC         : log10(Soil moisture capacity as water depth).\n', ...
                                '   S_initialfrac: Initial soil moisture fraction (0-1).\n', ...
                                '   k_infilt     : log10(Soil moisture capacity as water depth).\n', ...
                                '   k_sat        : log10(Maximum vertical infiltration rate).\n', ...
                                '   bypass_frac  : Fraction of runoff to bypass drainage.\n', ...
                                '   alpha        : Power term for infiltration rate.\n', ...
                                '   beta         : log10(Power term for dainage rate).\n', ...
                                '   gamma        : log10(Power term for soil evap. rate).']);                               
            
        end
    end
        
    
    methods       
%% Construct the model
        function obj = climateTransform_soilMoistureModels(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates, forcingData_reqCols, modelOptions)
            
% Model construction.
%
% Syntax:
%   soilModel = climateTransform_soilMoistureModels(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates, forcingData_reqCols, modelOptions)   
%
% Description:
%   Builds the form of the soil moisture differential equation using user
%   input model options. The way in which the soil moisture model is used
%   to transform the precipitation and potential evapotranspiration is also
%   defined within the model options.
%
%   This constructor also checks that the required compiled code exists (ie
%   forcingTransform_soilMoisture.c), the input model options are two or
%   three columns wide and that the way in which the transformations are to
%   be undertaken is specified.
%
%   Lastly, for calibration stability the following parameters are
%   transformed to log10 space: k_infilt, SMSC, K_sat, beta.
%
% Input:
%
%   bore_ID - string for the bore ID. The boe ID must be listed in the site
%   coordinates array.
%
%   forcingData_data - M x N numeric matrix of daily foring data. The matrix 
%   must comprise of the following columns: year, month, day and
%   observation data. The observation data must include precipitation &
%   PET. The record must be continuous (no skipped days) and cannot contain  
%   blank observations.
%
%   forcingData_colnames - 1 x N cell array of the column names within the
%   input numerical array "forcingData_data".  Importantly, each forcing 
%   data column name must be listed within the input "siteCoordinates". 
%
%   siteCoordinates - Mx3 cell matrix containing the following columns :
%   site ID, projected easting, projected northing. Importantly,
%   the input 'bore_ID' must be listed and all columns within
%   the forcing data (excluding the year, month,day). 
%
%   modelOptions - cell matrix defining the soil model componants, ie how the
%   model should be constructed. The cell matrix can be two or three
%   columns wide and at least three rows long (for the simplest of models).
%   The first column defines the model parameter name or user option name
%   to be defined. The second column defines the initial value for the
%   parameter or the setting for the user option. A third column can be
%   input if a parameter is to be fixed, and thus not modified during
%   calibration. This third column can contain the term 'fixed'. 
%
%
%
%   The optional user options are as follows. For the model parameter
%   options the second column defines the initial value. A third column can
%   also be input to make the parameter a constant:
%
%       'k_infilt'          - a parameter for the maximum infiltration rate. 
%       'alpha'             - a parameter for the infiltration rate power term.
%       'beta'              - a parameter for the drainage rate power term.
%       'k_sat'             - a parameter for the maximum vertical saturated
%                             conductivity.
%       'gamma'             - a parameter for the evaporation rate power term.
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
%       >> soilModelOptions = { 'SMSC', 100; ...
%                               'alpha', 1, 'fixed'};};
%       - 1 parameter WITHOUT scaling of infiltration by the soil moisture:
%       >> soilModelOptions = { 'SMSC', 100, '' ;
%                               'alpha', 0, 'fixed'};
%       - 2 parameter with linear scaling of infiltration by the soil 
%       moisture and linear vertical drainage:
%       >> soilModelOptions = { 'SMSC', 100 ; 
%                               'k_sat', 10 };
%       - 3 parameter with linear scaling of infiltration by the soil
%       moisture and non-linear vertical drainage:
%       >> soilModelOptions = {  'SMSC', 100 ; 
%                               'beta', 2 ;
%                               'k_sat', 10 };
%       - 4 parameter with non-linear scaling of infiltration by the soil 
%       moisture and non-linear vertical drainage:
%       >> soilModelOptions = { 'SMSC', 100 ; 
%                               'alpha', 0.5 ;
%                               'beta', 2 ;
%                               'k_sat', 10 };
%
% Output:
%   soilModel - climateTransform_soilMoistureModels class object 
%
% Example: 
%   Create a cell matrix of options for a two parameter soil model:
%   >> soilModelOptions = { 'lossingOption', 'evap_deficit' ;
%                           'gainingOption', 'soil_infiltration' ;
%                           'SMSC', 100 ; 
%                           'k_sat', 10 };
%   Build the soil model:
%   >> soilModel = climateTransform_soilMoistureModels(soilModelOptions);
%
% See also
%   climateTransform_soilMoistureModels: class_definition;
%   setParameters: set_calibration_parameters_values;
%   getParameters: get_calibration_parameters_values;
%   detectParameterChange: assesst_if_parameters_have_changed_recently;
%   setTransformedForcing: run_model_and_store_simulation_results;
%   getTransformedForcing: get_outputs_for_timeseries_model.
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure Engineering, 
%   The University of Melbourne.
%
% Date:
%   11 April 2012   

            % Check the MEX 'C' code for the soil moisture model is
            % compiled for the current operating system.                                                
            if exist(['forcingTransform_soilMoisture.',mexext()],'file')~=3
                errorMessage = ['The compiled code for the soil moisture could not be found.', char(13), ...
                                'This may be due to the MatLab search path not set to include', char(13), ...
                                'the required code or that the code may not have been compiled', char(13), ...
                                'for your operating system and version of MatLab. For your' , char(13), ...
                                'operating system and version of MatLab, the following file must exist: ', char(13), ...
                                '   - forcingTransform_soilMoisture.',mexext()];
                error(errorMessage);
            end            
            
            % Check there are at least two columns in the model options.
            ncols_modelOptions = size(modelOptions,2);
            if ncols_modelOptions < 2 || ncols_modelOptions > 3
                errorMessage = ['The soil moisture model options must be at least two columns, where:' char(13), ...
                                '  - column 1 is the parameter name or model option (i.e. "lossingOption" or "gainingOption"', char(13), ...
                                '  - column 2 is the parameter value or setting for the model option', char(13), ...
                                'Note: A third column can be given. This column can contain the input "fixed".', char(13), ...
                                '      This will make the parameter a constant and it will not be adjusted in the calibration.'];
                error(errorMessage);
            end            
                               
            % Get a list of required forcing inputs and (again) check that
            % each of the required inputs is provided.
            %--------------------------------------------------------------
            requiredFocingInputs = climateTransform_soilMoistureModels.inputForcingData_required();
            for j=1:size(requiredFocingInputs,1)
                filt = strcmpi(forcingData_reqCols(:,1), requiredFocingInputs(j));                    
                if ~any(filt)
                    error(['An unexpected error occured. When transforming forcing data, the input cell array for the transformation must contain a row (in 1st column) labelled "forcingdata" that its self contains a cell array in which the forcing data column is defined for the input:', requiredFocingInputs(j) ]);
                end
            end
             
            % Assign the input forcing data to obj.settings.
            obj.settings.forcingData = forcingData_data;
            obj.settings.forcingData_colnames = forcingData_colnames;
            obj.settings.forcingData_cols = forcingData_reqCols;
            obj.settings.siteCoordinates = siteCoordinates;
                              
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
            nparams = 0;
            
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
            
                % Record the parameter as 'Active'. That is, it can be
                % calibrated within the time series model,
                if ~isempty(ind)
                    if ncols_modelOptions ==3 && strcmp(lower(modelOptions{ind,3}),'fixed')
                        obj.settings.fixedParameters.(all_parameter_names{i})=true;
                        obj.settings.activeParameters.(all_parameter_names{i})=false;
                        obj.(all_parameter_names{i}) = modelOptions{ind,2};
                    else
                        nparams = nparams+1;
                        obj.settings.fixedParameters.(all_parameter_names{i})=false;
                        obj.settings.activeParameters.(all_parameter_names{i})=true;
                        paramsInitial(nparams,1) = modelOptions{ind,2};
                    end
                else
                    obj.settings.fixedParameters.(all_parameter_names{i})=false;
                    obj.settings.activeParameters.(all_parameter_names{i})=false;                    
                    if strcmp(all_parameter_names{i}, 'alpha') || strcmp(all_parameter_names{i}, 'gamma')                        
                        obj.(all_parameter_names{i}) = 1;
                    elseif strcmp(all_parameter_names{i}, 'beta')
                        % Note, beta is transformed in the soil model to
                        % 10^beta.
                        obj.(all_parameter_names{i}) = 0;
                    elseif strcmp(all_parameter_names{i}, 'k_sat')
                        % Note, k_sat is transformed in the soil model to
                        % 10^k_sat = 0 m/d.
                        obj.(all_parameter_names{i}) = -inf;
                    elseif strcmp(all_parameter_names{i}, 'S_initialfrac')
                        obj.(all_parameter_names{i}) = [];  
                    else
                        obj.(all_parameter_names{i}) = 0;
                    end
                end
            end
            
            % Check that the soil moisture capacity parameter is active.
            % This is the simplest model able to be simulated
            if ~obj.settings.activeParameters.SMSC
                error('The soil moisture model options must include the soil moisture capacity parameter.');
            end
            
            % Set a constant for smoothing the soil moisture capacity
            % thresholds and infiltration excess threshold            
            obj.settings.lambda_p = 0.2;                        
            
            % Set parameters for transfer function.
            setParameters(obj, paramsInitial)                             

        end
        
%% Set parameters
        function setParameters(obj, params)
% Syntax:
%   setParameters(obj, params)  
%
% Description:  
%   This method sets the soil moisture model parameters to user input values.
%   Only parameters that are to be calibrated (i.e. non-fixed parameters)
%   can be set. Also the vector of input parameter values must be in the
%   same order as the parameter names returned by the method
%   'getParameters'.
%
% Input:
%   obj     - soil moisture model object.
%   params  - vector (Nx1) of parameter values.
%
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
%   >> soilModel = climateTransform_soilMoistureModels(soilModelOptions);
%
%   Get the list of non-fixed parameter names:
%   >> [params, param_names] = getParameters(soilModel);
%
%   Assign new vales for the parameters SMSC and k_sat:
%   >> setParameters(soilModel, [101; 11]);
%
% See also:
%   climateTransform_soilMoistureModels: class_definition;
%   getParameters: get_calibration_parameters_values;
%   detectParameterChange: assesst_if_parameters_have_changed_recently;
%   setTransformedForcing: run_model_and_store_simulation_results;
%   getTransformedForcing: get_outputs_for_timeseries_model.
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

            % Get the active parameter names
            param_names = getActiveParameters(obj);
            
            % Cycle through each parameter and assign the parameter value.
            for i=1: length(param_names)
               obj.(param_names{i}) = params(i,:); 
            end
            
            % Check if the parameters have changed since the last call to
            % setTransformedForcing.
            detectParameterChange(obj, params);            
        end
        
%% Get model parameters
        function [params, param_names] = getParameters(obj)            
% Syntax:
%   setParameters(obj, params)  
%
% Description:  
%   This method gets the soil moisture model parameters. Only parameters 
%   that are to be calibrated (i.e. non-fixed parameters) are returned. The
%   method also returns the parameter names and the order of the parameter
%   names correspondes to the returned order of the parameter values.
%
% Input:
%   obj         - soil moisture model object.
%
% Outputs:
%   params      - a vector (Nx1) of soil moisture model parameter values.
%   param_names - a vector (Nx1) of parameter names.   
%
% Example:
%   Create a cell matrix of options for a two parameter soil model:
%   >> soilModelOptions = { 'lossingOption', 'evap_deficit' ;
%                           'gainingOption', 'soil_infiltration' ;
%                           'SMSC', 100 ; 
%                           'k_sat', 10 };
%   Build the soil model:
%   >> soilModel = climateTransform_soilMoistureModels(soilModelOptions);
%
%   Get the list of non-fixed parameter names:
%   >> [params, param_names] = getParameters(soilModel);
%
% See also:
%   climateTransform_soilMoistureModels: class_definition;
%   setParameters: set_calibration_parameters_values;
%   detectParameterChange: assesst_if_parameters_have_changed_recently;
%   setTransformedForcing: run_model_and_store_simulation_results;
%   getTransformedForcing: get_outputs_for_timeseries_model.
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
            
            % Get the active parameter names
            param_names = getActiveParameters(obj);
            
            % Cycle through each parameter and get the parameter value.
            params = zeros(length(param_names),size( obj.(param_names{1}),2));
            for i=1: length(param_names)
               params(i,:) = obj.(param_names{i}); 
            end
        end   
        
%% Assess if matrix of parameters is valid.
        function isValidParameter = getParameterValidity(obj, params, param_names)

            % Get physical bounds.
            [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj);

            % Check parameters are within bounds.
            isValidParameter = params >= params_lowerLimit(:,ones(1,size(params,2))) & ...
    		params <= params_upperLimit(:,ones(1,size(params,2)));   
        end   

%% Return fixed upper and lower bounds to the parameters.
        function [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj)            
            [params, param_names] = getParameters(obj);
            
            params_lowerLimit = repmat(0,size(params,1),1);
            params_upperLimit = repmat(inf,size(params,1),1);         

            if obj.settings.activeParameters.k_infilt
                ind = cellfun(@(x)(strcmp(x,'k_infilt')),param_names);
                params_lowerLimit(ind,1) = -inf;                    
            end       
            
            if obj.settings.activeParameters.k_sat
                ind = cellfun(@(x)(strcmp(x,'k_sat')),param_names);
                params_lowerLimit(ind,1) = -inf;                                    
            end    

            if obj.settings.activeParameters.bypass_frac
                ind = cellfun(@(x)(strcmp(x,'bypass_frac')),param_names);
                params_lowerLimit(ind,1) = 0;         
                params_upperLimit(ind,1) = 1;
            end    
            
            
            if obj.settings.activeParameters.S_initialfrac
                ind = cellfun(@(x)(strcmp(x,'S_initialfrac')),param_names);
                params_lowerLimit(ind,1) = 0;                                    
                params_upperLimit(ind,1) = 1;                                    
            end    
            
       
        end  
        
%% Return fixed upper and lower plausible parameter ranges. 
        function [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(obj)
        % Return fixed upper and lower plausible parameter ranges. 
        % This is used to define reasonable range for the initial parameter sets
        % for the calibration. These parameter ranges are only used in the 
        % calibration if the user does not input parameter ranges.
            
            % get parameyer names
            [params, param_names] = getParameters(obj);
            
            % Set default plausible parameter range
            params_lowerLimit = zeros(length(param_names),1);  
            params_upperLimit = 5.*ones(length(param_names),1);  
            
            % Modify plausible range for specific parameters
            if obj.settings.activeParameters.S_initialfrac
                ind = cellfun(@(x)(strcmp(x,'S_initialfrac')),param_names);
                params_lowerLimit(ind,1) = 0;
                params_upperLimit(ind,1) = 1;
            end  

            if obj.settings.activeParameters.bypass_frac
                ind = cellfun(@(x)(strcmp(x,'bypass_frac')),param_names);
                params_lowerLimit(ind,1) = 0;
                params_upperLimit(ind,1) = 1;
            end              
            
            
            if obj.settings.activeParameters.SMSC
                ind = cellfun(@(x)(strcmp(x,'SMSC')),param_names);
                params_lowerLimit(ind,1) = log10(10);
                params_upperLimit(ind,1) = log10(1000);
            end  
            
            if obj.settings.activeParameters.k_infilt
                ind = cellfun(@(x)(strcmp(x,'k_infilt')),param_names);
                params_lowerLimit(ind,1) = log10(10);                    
                params_upperLimit(ind,1) = log10(100);
            end  
            
            if obj.settings.activeParameters.k_sat
                ind = cellfun(@(x)(strcmp(x,'k_sat')),param_names);
                params_lowerLimit(ind,1) = log10(10);                    
                params_upperLimit(ind,1) = log10(100);
            end 
            
            if obj.settings.activeParameters.beta
                ind = cellfun(@(x)(strcmp(x,'beta')),param_names);
                params_lowerLimit(ind,1) = log10(1);
                params_upperLimit(ind,1) = log10(10);
            end                         
        end        
        
%% Check if the model parameters have chanaged since the last calculated.
        function detectParameterChange(obj, params)
% Syntax:
%   detectParameterChange(obj, params)  
%
% Description:  
%   This method assesses if the user input parameters are different from
%   those used in the most recent solution to the soil moisture model. This
%   method allows the differential equation to be only solved when
%   required. The result of this assessment is stored within the object
%   variable: obj.variables.isNewParameters .
%
% Input:
%   obj         - soil moisture model object.
%   params      - a vector (Nx1) of new soil moisture model parameter values.
%
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
%   >> soilModel = climateTransform_soilMoistureModels(soilModelOptions);
%
%   Check if the new parameter values are different from those already in 
%   the model. This would set obj.variables.isNewParameters = false:
%   >> detectParameterChange(soilModel, [100; 10])
%
% See also:
%   climateTransform_soilMoistureModels: class_definition;
%   setParameters: set_calibration_parameters_values;
%   getParameters: get_calibration_parameters_values;
%   setTransformedForcing: run_model_and_store_simulation_results;
%   getTransformedForcing: get_outputs_for_timeseries_model.
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

            % Get current parameters
            set_params = getParameters(obj);

            % Check if there are any changes to the parameters.
            if max(abs(set_params - params)) ~= 0            
                obj.variables.isNewParameters = true;
            else
                obj.variables.isNewParameters = true;
            end                        
            
        end
                    
%% Solve the soil moisture differential equation
        function setTransformedForcing(obj, t, forceRecalculation)
% Syntax:
%   setTransformedForcing(obj, climateData, forceRecalculation)
%
% Description:  
%   This method solves the soil moisture differential equation for all time
%   points within the input daily climate data. 
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
%   >> soilModelOptions = { 'SMSC', 100 ; 
%                           'k_sat', 10 };
%   Build the soil model:
%   >> soilModel = climateTransform_soilMoistureModels(soilModelOptions);
%
%   Solve the differential equation:
%   >> setTransformedForcing(soilModel, climateData, true)
%
% See also:
%   climateTransform_soilMoistureModels: class_definition;
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
            
            if obj.variables.isNewParameters || forceRecalculation

                % Filter the forcing data to input t.
                filt_time = obj.settings.forcingData(:,1) >= t(1) & obj.settings.forcingData(:,1) <= t(end);
                
                % Get the required forcing data
                filt = strcmp(obj.settings.forcingData_cols(:,1),'precip');
                precip_col = obj.settings.forcingData_cols{filt,2};
                obj.variables.precip = obj.settings.forcingData(filt_time, precip_col );

                filt = strcmp(obj.settings.forcingData_cols(:,1),'et');
                evap_col = obj.settings.forcingData_cols{filt,2};
                obj.variables.evap = obj.settings.forcingData(filt_time, evap_col );
                
                % Filter percip by max infiltration rate, k_infilt.  
                if obj.settings.activeParameters.k_infilt || obj.settings.fixedParameters.k_infilt
                    lambda_p = obj.settings.lambda_p .* 10.^obj.k_infilt;
                    obj.variables.precip = (obj.variables.precip>0).*(obj.variables.precip + lambda_p * log( 1./(1 + exp( (obj.variables.precip - 10.^obj.k_infilt)./lambda_p))));
                    obj.variables.precip(isinf(obj.variables.precip)) = 10.^obj.k_infilt;
                end

                % Set the initial soil moisture.
                if isempty(obj.S_initialfrac)
                    S_initial = 0.5.*10^(obj.SMSC);
                else
                    S_initial = obj.S_initialfrac * 10^(obj.SMSC);
                end
                
                % Call MEX function containing soil moisture model.
                obj.variables.SMS = forcingTransform_soilMoisture(S_initial, obj.variables.precip, obj.variables.evap, ...
                        10^(obj.SMSC), 10.^obj.k_sat, obj.alpha, 10.^obj.beta, obj.gamma);                                
                
            end
        end
        
%% Return the transformed forcing data
        function [forcingData, isDailyIntegralFlux] = getTransformedForcing(obj, variableName) 
% Syntax:
%   [precip_Forcing, et_Forcing] = getTransformedForcing(obj, variableName)
%
% Description:  
%   This method returns the solutions from solving the soil moisture 
%   differential equation. The returned values are dependent upon 
%   the required transformations.
%
% Input:
%   obj - soil moisture model object.
%
%   variableName - a string for the variable name to return.
%
% Outputs:
%   forcingData  - a vector (Nx1) of the forcing data output to
%                     be input to the groundwater time series model.
% Example:
%   Create a cell matrix of options for a two parameter soil model:
%   >> soilModelOptions = { 'SMSC', 100 ; 
%                           'k_sat', 10 };
%   Build the soil model:
%   >> soilModel = climateTransform_soilMoistureModels(soilModelOptions);
%
%   Solve the differential equation:
%   >> setTransformedForcing(soilModel, climateData, true)
%
%   Get the solution from the diffential equations:
%   >> t = climateData(:,1);
%   >> [precip_Forcing, et_Forcing] = getTransformedForcing(soilModel t);
%
% See also:
%   climateTransform_soilMoistureModels: class_definition;
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


            switch variableName
                case 'drainage'
                    forcingData = 10.^obj.k_sat .* (obj.variables.SMS/10^(obj.SMSC)).^(10.^obj.beta);
                    isDailyIntegralFlux = false;
                case 'drainage_bypassFlow'
                    drainage = 10.^obj.k_sat .* (obj.variables.SMS/10^(obj.SMSC)).^(10.^obj.beta);                                        
                    runoff = getTransformedForcing(obj, 'runoff');
                    forcingData = drainage + obj.bypass_frac.*runoff;
                    
                    isDailyIntegralFlux = true;
                    
                case 'drainage_normalised'
                    forcingData = (obj.variables.SMS/10^(obj.SMSC)).^(10.^obj.beta);
                    isDailyIntegralFlux = false;
                    
                case 'evap_soil'    
                    forcingData = obj.variables.evap .* (obj.variables.SMS/10^(obj.SMSC)).^obj.gamma;                    
                    isDailyIntegralFlux = false;

                case 'infiltration'                       
                    drainage = getTransformedForcing(obj, 'drainage');
                    actualET = getTransformedForcing(obj, 'evap_soil');                        
                    drainage =  0.5 .* (drainage(1:end-1) + drainage(2:end));
                    actualET = 0.5 .* (actualET(1:end-1) + actualET(2:end));                    
                    forcingData = [0 ; max(0,(obj.variables.precip(2:end,1)>0) .* (diff(obj.variables.SMS) + drainage + actualET))];
                    isDailyIntegralFlux = true;
                    
                case 'evap_gw_potential'
                    forcingData = obj.variables.evap .* (1-(obj.variables.SMS/10^(obj.SMSC)).^obj.gamma);                    
                    isDailyIntegralFlux = false;
                    
                case 'runoff'
                    infiltration = getTransformedForcing(obj, 'infiltration');
                    forcingData = max(0,obj.variables.precip - infiltration);
                    isDailyIntegralFlux = true;
                    
                case'SMS'
                    forcingData = obj.variables.SMS;
                    isDailyIntegralFlux = false;
                    
                otherwise
                    error('The requested transformed forcing variable is not known.');
            end

        end
        
    end
    
    methods(Access=protected, Hidden=true)
        
        % Get the names of the active parameters
        function param_names = getActiveParameters(obj)
            
            % Get field array value for if the parameter is active.
            ind=structfun(@(x) (x),  obj.settings.activeParameters);
            
            % Get list of all parameter names.
            all_parameter_names = fieldnames(obj.settings.activeParameters);
            
            % Return only those parameter names that are active
            param_names=all_parameter_names(ind,1);
            
        end 
    end
    
end

