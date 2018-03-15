classdef climateTransform_soilMoistureModels < forcingTransform_abstract 
% Class definition for soil moisture transformation of climate forcing.
%
% Description        
%   climateTransform_soilMoistureModels is a generalised vertically lumped 1-D
%   soil moisture model. It is used to transform the daily climate data
%   for use in the transfer noise function groundwater time series model.
%   Importantly, a user of the groundwater time series model has no need to
%   run any of these soil moisture model methods. All of the methods are
%   automatically called by the function "model_TFN.m".
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
%                 be limited to a maximum infiltration rate "k_infilt". If
%                 this parameter is not defined then P_inf equals the input
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
%       interflow_frac - fraction of free drainage going to interflow.
%       PET     - is the input daily potential evapotranspiration [L T^-1].
%       gamma   - is a dimensionless parameter to transform the rate at
%                 which soil water evaporation occurs with filling of the 
%                 soil layer.
%       S_initialfrac - the initial soil moisture.
%
%	The soil moisture model can also be used to simulate the impacts from
%	different vegetation; for example, trees and pastures. This is achieved
%	by simulating a soil store for upto two land types and then weighting
%	required flux from each soil model by an input time series of the
%	fraction of the second land type. A challange with the input time series 
%	of land cover is, however, that while the fraction of, say, land
%	data clearing over time may be known the fraction of the catchment area
%	cleared that influences a bore hydrograph is unknown. To address this,
%	the modelling also include a parameter 'treeArea_frac' for the fraction
%	of the second land cover (notially trees) that is influencing the bore.
%	In summary, the simulation of tree cover requires the following two
%	parameters:
%
%       SMSC_trees - is a parameter for the soil moisture storage capacity [L]
%                  of the second soil model (notionaly trees). This is the
%                  only other parameter required for the simulation of a
%                  second soil layer (other parameters are taken from the
%                  first soil model). Also, the soil storage parameter has 
%                  the same units as the input precipitation.
%       treeArea_frac - is a parameter from 0 to 1 that simulates the
%                   weight to be applied to the tree cover soil model flux.       
%   
%   Additionally, in parametrizing the model, many of the parameters were
%   transformed to a parameter space more amenable to efficient
%   calibration. Details of the transformations are as follows:
%
%       SMSC          - log10(Soil moisture capacity as water depth).
%       SMSC_trees    - log10(Soil moisture capacity as water depth).
%       S_initialfrac - Initial soil moisture fraction (0-1).
%       k_infilt      - log10(Soil infiltration capacity as water depth).
%       k_sat         - log10(Maximum vertical infiltration rate).
%       bypass_frac   - Fraction of runoff to bypass drainage (0-1).
%       interflow_frac- Fraction of free drainage going to interflow (0-1).
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
%   Once the soil moisture model has been ran a range of fluxes can be
%   derived from it for input to the transfer function noise model in place
%   of, say, precipitation. These fluxes include standard fluxes such as
%   free drainage or actual ET but also derived fluxes such as the bypass 
%   drainage (runoff plus free drainage) and the groundwater potential
%   evaporation ( potential ET minus soil ET). For a full list see
%   getTransformedForcing().
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
        SMSC_trees      % Trees soil moisture capacity parameter (as water depth)       
        treeArea_frac   % Scaler for the tree fraction data (optional)
        S_initialfrac   % Initial soil moisture 
        k_infilt        % Maximum infiltration rate.
        k_sat           % Maximum vertical conductivity.
        bypass_frac     % Fraction of runoff that goes to bypass drainage
        interflow_frac  % Fraction of free drainage going to interflow (0-1).        
        alpha           % Power term for infiltration.        
        beta            % Power term for dainage rate (eg Brook-Corey pore index power term)
        gamma           % Power term for soil evaporation rate.        
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
            variable_names = {'drainage';'drainage_bypassFlow';'drainage_normalised';'infiltration';'evap_soil';'evap_gw_potential';'runoff';'SMS'; ...
                              'drainage_tree';'drainage_bypassFlow_tree';'drainage_normalised_tree';'infiltration_tree';'evap_soil_tree';'evap_gw_potential_tree';'runoff_tree';'SMS_tree'; ...
                              'drainage_nontree';'drainage_bypassFlow_nontree';'drainage_normalised_nontree';'infiltration_nontree';'evap_soil_nontree'; ...
                              'evap_gw_potential_nontree';'runoff_nontree';'SMS_nontree'};
        end
        
        function [options, colNames, colFormats, colEdits, toolTip] = modelOptions()
           
            options = { 'SMSC'          ,   2, 'Calib.';...
                        'SMSC_trees'    ,   2, 'Fixed';...
                        'treeArea_frac' , 0.5, 'Fixed'; ...
                        'S_initialfrac' , 0.5, 'Fixed'  ; ...
                        'k_infilt'      , inf,'Fixed'   ; ...
                        'k_sat'         ,   1, 'Calib.'   ; ...
                        'bypass_frac'   ,   0, 'Fixed'    ; ...
                        'interflow_frac',   0, 'Fixed'    ; ...
                        'alpha'         ,   0, 'Fixed'    ; ...
                        'beta'          , 0.5,'Calib.' ; ...
                        'gamma'         ,   0,  'Fixed'};

        
            colNames = {'Parameter', 'Initial Value','Fixed or Calibrated?'};
            colFormats = {'char', 'char', {'Calib.' 'Fixed'}};
            colEdits = logical([0 1 1]);

            toolTip = sprintf([ 'Use this table to define the type of soil moisture model. \n', ...
                                'Each parameter (except the soil moisture capacity) can be \n', ...
                                'set to a fixed value or calibrated. Below is a summary: \n \n' , ...
                                '   SMSC          : log10(Soil moisture capacity as water depth).\n', ...
                                '   SMSC_trees    : log10(Tree soil moisture capacity as water depth).\n', ...
                                '   treeArea_frac : Scaler applied to the tree fraction input data.\n', ...
                                '   S_initialfrac : Initial soil moisture fraction (0-1).\n', ...
                                '   k_infilt      : log10(Soil infiltration capacity as water depth).\n', ...
                                '   k_sat         : log10(Maximum vertical infiltration rate).\n', ...
                                '   bypass_frac   : Fraction of runoff to bypass drainage.\n', ...
                                '   interflow_frac: Fraction of free drainage going to interflow (0-1).', ...
                                '   alpha         : Power term for infiltration rate.\n', ...
                                '   beta          : log10(Power term for dainage rate).\n', ...
                                '   gamma         : log10(Power term for soil evap. rate).']);                               
            
        end
        
        function modelDescription = modelDescription()
           modelDescription = {'Name: climateTransform_soilMoistureModels', ...
                               '', ...
                               'Purpose: nonlinear transformation of rainfall and areal potential evaporation to a range of forcing data (eg free-drainage) ', ...
                               'using a highly flexible single layer soil moisture model. Two types of land cover can be simulated using two parrallel soil models.', ...
                               '', ...                               
                               'Number of parameters: 1 to 8', ...
                               '', ...                               
                               'Options: each model parameter (excluding the soil moisture capacity) can be set to a fixed value (ie not calibrated) or calibrated.', ...
                               'Also, the input forcing data field "TreeFraction" is optional and only required if the soil model is to simulate land cover change.', ...
                               '', ...                               
                               'Comments: Below is a summary of the model parameters:' , ...
                                'SMSC          : log10(Soil moisture capacity as water depth).', ...
                                'SMSC_trees    : log10(Tree soil moisture capacity as water depth).', ...
                                'treeArea_frac : Scaler applied to the tree fraction input data.', ...                                
                                'S_initialfrac : Initial soil moisture fraction (0-1).', ...
                                'k_infilt      : log10(Soil infiltration capacity as water depth).', ...
                                'k_sat         : log10(Maximum vertical infiltration rate).', ...
                                'bypass_frac   : Fraction of runoff to bypass drainage.', ...
                                'interflow_frac: Fraction of free drainage going to interflow (0-1).', ...
                                'alpha         : Power term for infiltration rate.', ...
                                'beta          : log10(Power term for dainage rate).', ...
                                'gamma         : log10(Power term for soil evap. rate).', ...
                               '', ...               
                               'References: ', ...
                               '1. Peterson & Western (2014), Nonlinear time-series modeling of unconfined groundwater head, Water Resour. Res., 50, 8330-8355'};
        end        
           
    end
        
    
    methods       
%% Construct the model
        function obj = climateTransform_soilMoistureModels(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates, forcingData_reqCols, modelOptions)            
% climateTransform_soilMoistureModels constructs the soil model object.
%
% Syntax:
%   soilModel = climateTransform_soilMoistureModels(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates, forcingData_reqCols, modelOptions)   
%
% Description:
%   Builds the form of the soil moisture differential equation for the user
%   input model options. This constructor also checks that the required 
%   compiled code exists (ie forcingTransform_soilMoisture.c)and that the input 
%   model options are two or three columns wide.
%
% Input:
%
%   bore_ID - string for the bore ID. The bore ID must be listed in the site
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
%   obj - climateTransform_soilMoistureModels class object 
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
                                '  - column 1 is the parameter name.', char(13), ...
                                '  - column 2 is the parameter value.', char(13), ...
                                'Note: A third column can be given. This column can contain the input "fixed".', char(13), ...
                                '      This will make the parameter a constant and it will not be adjusted in the calibration.'];
                error(errorMessage);
            end            
                               
            % Get a list of required forcing inputs and (again) check that
            % each of the required inputs is provided.
            %--------------------------------------------------------------
            obj.settings.simulateLandCover = false;
            requiredFocingInputs = climateTransform_soilMoistureModels.inputForcingData_required();
            for j=1:size(requiredFocingInputs,1)
                filt = strcmpi(forcingData_reqCols(:,1), requiredFocingInputs(j));                                    
                if ~any(filt) && ~strcmpi(requiredFocingInputs(j),'TreeFraction')
                    error(['An unexpected error occured. When transforming forcing data, the input cell array for the transformation must contain a row (in 1st column) labelled "forcingdata" that its self contains a cell array in which the forcing data column is defined for the input:', requiredFocingInputs{j}]);
                elseif any(filt) && strcmpi(requiredFocingInputs(j),'TreeFraction')                    
                    % Do land cover simulation if the data has any tree
                    % fraction > 0;
                    filt_LC = find(strcmpi(forcingData_reqCols(:,1), 'TreeFraction'))+1; 
                    if any(forcingData_data(:,filt_LC)<0) || any(forcingData_data(:,filt_LC)>1)
                       error('The tree fraction input data must be between 0 and 1.'); 
                    end
                    if sum(forcingData_data(:,filt_LC))>0
                        obj.settings.simulateLandCover = true;
                    end
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
                    obj.settings.fixedParameters.(all_parameter_names{i})=true;
                    obj.settings.activeParameters.(all_parameter_names{i})=false;                    
                    if strcmp(all_parameter_names{i}, 'alpha')         
                        obj.(all_parameter_names{i}) = 1;
                    elseif strcmp(all_parameter_names{i}, 'beta') || strcmp(all_parameter_names{i}, 'gamma')      
                        % Note, beta is transformed in the soil model to
                        % 10^beta.
                        obj.(all_parameter_names{i}) = 0;
                    elseif strcmp(all_parameter_names{i}, 'k_sat')
                        % Note, k_sat is transformed in the soil model to
                        % 10^k_sat = 0 m/d.
                        obj.(all_parameter_names{i}) = -inf;
                    elseif strcmp(all_parameter_names{i}, 'interflow_frac')
                        obj.(all_parameter_names{i}) = 0;                        
                    elseif strcmp(all_parameter_names{i}, 'S_initialfrac')
                        obj.(all_parameter_names{i}) = 0.5;  
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
            
            % Check the SMSM_trees parameter is active if and only if there
            % is land cover input data.
            if  isfield(obj.settings,'simulateLandCover') && obj.settings.simulateLandCover
               if ~obj.settings.activeParameters.SMSC_trees 
                   error('The trees soil moisture model options must include the soil moisture capacity parameter when land cover data is input.');
               end
            else
                obj.settings.activeParameters.SMSC_trees = false; 
                obj.settings.fixedParameters.SMSC_trees = true;
                obj.settings.fixedParameters.treeArea_frac = true;
                obj.settings.activeParameters.treeArea_frac = false;
            end
            
            % Set a constant for smoothing the soil moisture capacity
            % thresholds and infiltration excess threshold            
            obj.settings.lambda_p = 0.2;                        
            
            % Set parameters for transfer function.
            setParameters(obj, paramsInitial)                             

        end
        
%% Set parameters
        function setParameters(obj, params)
% setParameters returns the soil model parameters.
%
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
        
        function setForcingData(obj, forcingData, forcingData_colnames)
% setForcingData sets the forcing data.
%
% Syntax:
%   setForcingData(obj, forcingData, forcingData_colnames)
%
% Description:  
%   This method set the climate forcing data. It is used to update the
%   forcing data for model simulations (primarily from the GUI).
%
% Input:
%   obj         - soil moisture model object.
%
%   forcingData - nxm matrix of focrinf data with column 1 being the
%                 date/time.
%
%   forcingData_colnames - 1xm cell array of column names within the above
%                 data.
%
% Outputs:
%   (none)
%
% Dependencies:
%   (none)
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure Engineering, 
%   The University of Melbourne.
%
% Date:
%   21 Dec 2015              
            
            %obj.settings.forcingData_colnames = forcingData_colnames;
            %obj.settings.forcingData = forcingData;
            if length(forcingData_colnames) < length(obj.settings.forcingData_colnames)
                error('The number of column name to be set is less than that used to build the object.');
            end
            forcingDataNew = nan(size(forcingData,1),length(obj.settings.forcingData_colnames));
            for i=1:length(forcingData_colnames)               
                filt  = strcmp(obj.settings.forcingData_colnames, forcingData_colnames{i});
                if ~isempty(filt)
                    forcingDataNew(:,filt) = forcingData(:,i);
                end
            end
            obj.settings.forcingData = forcingDataNew;
        end                
        
%% Get model parameters
        function [params, param_names] = getParameters(obj)            
% getParameters sets the soil model parameters.
%
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
%
%   param_names - a vector (Nx1) of parameter names.   
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
% getParameterValidity returns a logical vector for the validity or each parameter.
%
% Syntax:
%   isValidParameter = getParameterValidity(obj, params, param_names)
%
% Description:
%   Cycles though all active soil model parameters and returns a logical 
%   vector denoting if each parameter is valid ie within the physical 
%   parameter bounds.
%
% Input:
%   obj -  model object.
%
%   params - vector of model parameters
%
%   param_names - cell array of the parameter names.
%
% Outputs:
%   isValidParameter - column vector of the parameter validity.
%
% Example:
%   see HydroSight: time_series_model_calibration_and_construction;
%
% See also:
%   model_TFN: model_construction;
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure
%   Engineering, The University of Melbourne.
%
% Date:
%   26 Sept 2014   

            % Get physical bounds.
            [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj);

            % Check parameters are within bounds.
            isValidParameter = params >= params_lowerLimit(:,ones(1,size(params,2))) & ...
    		params <= params_upperLimit(:,ones(1,size(params,2)));   
        end   

%% Return fixed upper and lower bounds to the parameters.
        function [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj)  
% getParameters_physicalLimit returns the physical limits to each soil model parameter.
%
% Syntax:
%   [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj)  
%
% Description:
%   Cycles through all active soil model componants and parameters and returns
%    a vector of the physical upper and lower parameter bounds.
%
% Input:
%   obj -  model object.
%
% Outputs:
%   params_upperLimit - column vector of the upper parameter bounds.
%
%   params_lowerLimit - column vector of the lower parameter bounds
%
% Example:
%   see HydroSight: time_series_model_calibration_and_construction;
%
% See also:
%   model_TFN: model_construction;
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure
%   Engineering, The University of Melbourne.
%
% Date:
%   26 Sept 2014   

            [params, param_names] = getParameters(obj);
            
            params_lowerLimit = repmat(0,size(params,1),1);
            params_upperLimit = repmat(inf,size(params,1),1);         

            if obj.settings.activeParameters.k_infilt
                ind = cellfun(@(x)(strcmp(x,'k_infilt')),param_names);
                params_lowerLimit(ind,1) = -inf;                    
            end       
            
            % Upper and lower bounds taken from Rawls et al 1982 Estimation
            % of Soil Properties. The values are for sand and clay
            % respectively and transformed from units of cm/h to the assumed
            % input units of mm/d.
            if obj.settings.activeParameters.k_sat
                ind = cellfun(@(x)(strcmp(x,'k_sat')),param_names);
                %params_lowerLimit(ind,1) = log10(10);                    
                %params_upperLimit(ind,1) = log10(100);
                params_lowerLimit(ind,1) = floor(log10(0.06*24*10));
                params_upperLimit(ind,1) = ceil(log10(21*24*10));
            end             
            
            if obj.settings.activeParameters.bypass_frac
                ind = cellfun(@(x)(strcmp(x,'bypass_frac')),param_names);
                params_lowerLimit(ind,1) = 0;         
                params_upperLimit(ind,1) = 1;
            end    
            
            if isfield(obj.settings.activeParameters,'treeArea_frac') && obj.settings.activeParameters.treeArea_frac
                ind = cellfun(@(x)(strcmp(x,'treeArea_frac')),param_names);
                params_lowerLimit(ind,1) = 0;         
                params_upperLimit(ind,1) = 1;
            end            
            
            if isfield(obj.settings.activeParameters,'interflow_frac') && obj.settings.activeParameters.interflow_frac
                ind = cellfun(@(x)(strcmp(x,'interflow_frac')),param_names);
                params_lowerLimit(ind,1) = 0;         
                params_upperLimit(ind,1) = 1;
            end                
            
            if obj.settings.activeParameters.S_initialfrac
                ind = cellfun(@(x)(strcmp(x,'S_initialfrac')),param_names);
                params_lowerLimit(ind,1) = 0;                                    
                params_upperLimit(ind,1) = 1;                                    
            end    
                   
            if obj.settings.activeParameters.beta
                ind = cellfun(@(x)(strcmp(x,'gamma')),param_names);
                params_lowerLimit(ind,1) = log10(0.01);
                params_upperLimit(ind,1) = log10(100);
            end                  
            
            if obj.settings.activeParameters.SMSC
                ind = cellfun(@(x)(strcmp(x,'SMSC')),param_names);
                params_lowerLimit(ind,1) = log10(50);
                params_upperLimit(ind,1) = Inf;
            end            
            
        end  
        
%% Return fixed upper and lower plausible parameter ranges. 
        function [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(obj)
% getParameters_plausibleLimit returns the plausible limits to each soil model parameter.
%
% Syntax:
%   [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(obj)
%
% Description:
%   Cycles through all active soil model componants and parameters and returns
%    a vector of the plausible upper and lower parameter bounds.
%
% Input:
%   obj -  model object.
%
% Outputs:
%   params_upperLimit - column vector of the upper parameter bounds.
%
%   params_lowerLimit - column vector of the lower parameter bounds
%
% Example:
%   see HydroSight: time_series_model_calibration_and_construction;
%
% See also:
%   model_TFN: model_construction;
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure
%   Engineering, The University of Melbourne.
%
% Date:
%   26 Sept 2014              
            
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
            
            if isfield(obj.settings.activeParameters,'treeArea_frac') && obj.settings.activeParameters.treeArea_frac
                ind = cellfun(@(x)(strcmp(x,'treeArea_frac')),param_names);                
                params_lowerLimit(ind,1) = 0;
                params_upperLimit(ind,1) = 1;
            end                                                  
            
            if  isfield(obj.settings.activeParameters,'interflow_frac') && obj.settings.activeParameters.interflow_frac
                ind = cellfun(@(x)(strcmp(x,'interflow_frac')),param_names);                
                params_lowerLimit(ind,1) = 0;
                params_upperLimit(ind,1) = 1;
            end                
            
%             if obj.settings.activeParameters.SMSC
%                 ind = cellfun(@(x)(strcmp(x,'SMSC')),param_names);
%                 params_lowerLimit(ind,1) = log10(10);
%                 params_upperLimit(ind,1) = log10(1000);
%             end  
            if obj.settings.activeParameters.SMSC
                ind = cellfun(@(x)(strcmp(x,'SMSC')),param_names);
                params_lowerLimit(ind,1) = log10(50);
                params_upperLimit(ind,1) = log10(500);
            end

            if obj.settings.activeParameters.SMSC_trees
                ind = cellfun(@(x)(strcmp(x,'SMSC_trees')),param_names);
                params_lowerLimit(ind,1) = log10(10);
                params_upperLimit(ind,1) = log10(1000);
            end  
                        
            if obj.settings.activeParameters.k_infilt
                ind = cellfun(@(x)(strcmp(x,'k_infilt')),param_names);
                params_lowerLimit(ind,1) = log10(10);                    
                params_upperLimit(ind,1) = log10(100);
            end  
            
            % Upper and lower bounds taken from Rawls et al 1982 Estimation
            % of Soil Properties. The values are for sand loam and silty clay
            % respectively and transformed from units of cm/h to the assumed
            % input units of mm/d.
            if obj.settings.activeParameters.k_sat
                ind = cellfun(@(x)(strcmp(x,'k_sat')),param_names);
                params_lowerLimit(ind,1) = log10(0.09*24*10);
                params_upperLimit(ind,1) = log10(6.11*24*10);
            end 
            
            if obj.settings.activeParameters.beta
                ind = cellfun(@(x)(strcmp(x,'beta')),param_names);
                params_lowerLimit(ind,1) = log10(1);
                params_upperLimit(ind,1) = log10(5);
            end      
            
            if obj.settings.activeParameters.beta
                ind = cellfun(@(x)(strcmp(x,'gamma')),param_names);
                params_lowerLimit(ind,1) = log10(0.1);
                params_upperLimit(ind,1) = log10(10);
            end                  
        end        
        
%% Check if the model parameters have chanaged since the last calculated.
        function detectParameterChange(obj, params)
% detectParameterChange detects if the soil model parameters have changed.            
%
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
% setTransformedForcing solves the soil moisture ODE model
%
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
%
%   t           - a vector (Nx1) of time points for simulation.
%
%   forceRecalculation - is a logical scalar input (i.e. true of false) to
%                 force re-calculation of the model and thus ingore if the
%                 parameters have or have not changed.
% Outputs:
%   (none)
%
% See also:
%   climateTransform_soilMoistureModels: class_definition;
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

                % back transform the parameters
                [params, param_names] = getDerivedParameters(obj);

                % Assign each param to a variable for efficient access.
                SMSC = params(1,:);
                SMSC_trees = params(2,:);
                treeArea_frac = params(3,:);
                S_initialfrac = params(4,:);
                k_infilt = params(5,:);
                k_sat = params(6,:);
                bypass_frac = params(7,:);            
                interflow_frac = params(8,:);
                alpha = params(9,:);
                beta = params(10,:);
                gamma = params(11,:);                 
                
                % Filter the forcing data to input t.
                filt_time = obj.settings.forcingData(:,1) >= t(1) & obj.settings.forcingData(:,1) <= t(end);
                
                % Get the required forcing data
                filt = strcmp(obj.settings.forcingData_cols(:,1),'precip');
                precip_col = obj.settings.forcingData_cols{filt,2};
                obj.variables.precip = obj.settings.forcingData(filt_time, precip_col );

                filt = strcmp(obj.settings.forcingData_cols(:,1),'et');
                evap_col = obj.settings.forcingData_cols{filt,2};
                obj.variables.evap = obj.settings.forcingData(filt_time, evap_col );
                
                % Store the time points
                obj.variables.t = t;
                 
                if isfield(obj.settings,'simulateLandCover') && obj.settings.simulateLandCover
                    filt = strcmp(obj.settings.forcingData_cols(:,1),'TreeFraction');
                    tree_col = obj.settings.forcingData_cols{filt,2};
                    obj.variables.treeFrac = obj.settings.forcingData(filt_time, tree_col );                    
                end
                
                % Filter percip by max infiltration rate, k_infilt.  
                effectivePrecip = obj.variables.precip;
                if k_infilt < inf && (obj.settings.activeParameters.k_infilt || obj.settings.fixedParameters.k_infilt)
                    lambda_p = obj.settings.lambda_p .* k_infilt;
                    effectivePrecip= (effectivePrecip>0).*(effectivePrecip+ lambda_p * log( 1./(1 + exp( (effectivePrecip - k_infilt)./lambda_p))));
                    effectivePrecip(isinf(effectivePrecip)) = k_infilt;
                end

                % Set the initial soil moisture.
                if isempty(S_initialfrac)
                    S_initial = 0.5.*SMSC;
                else
                    S_initial = S_initialfrac * SMSC;
                end
                
                % Store the time points
                obj.variables.t = t(filt_time);
                
                % Call MEX function containing soil moisture model.
                obj.variables.SMS = forcingTransform_soilMoisture(S_initial, effectivePrecip, obj.variables.evap, ...
                        SMSC, k_sat, alpha, beta, gamma);                                
                
                % Run soil model again if tree cover is to be simulated
                if  isfield(obj.settings,'simulateLandCover') && obj.settings.simulateLandCover
                    if isempty(S_initialfrac)
                        S_initial = 0.5.*SMSC_trees;
                    else
                        S_initial = S_initialfrac * SMSC_trees;
                    end
                    
                    obj.variables.SMS_trees = forcingTransform_soilMoisture(S_initial, effectivePrecip, obj.variables.evap, ...
                            SMSC_trees, k_sat, alpha, beta, gamma);                                                                        
                end
                    
            end
        end
        
%% Return the transformed forcing data
        function [forcingData, isDailyIntegralFlux] = getTransformedForcing(obj, variableName, SMSnumber) 
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
        
            % back transform the parameters
            [params, param_names] = getDerivedParameters(obj);
            
            if ischar(variableName)
                variableNametmp{1}=variableName;
                variableName = variableNametmp;
                clear variableNametmp;
            end            
            
            % Assign each param to a variable for efficient access.
            SMSC = params(1,:);
            SMSC_trees = params(2,:);
            treeArea_frac = params(3,:);
            S_initialfrac = params(4,:);
            k_infilt = params(5,:);
            k_sat = params(6,:);
            bypass_frac = params(7,:);            
            interflow_frac = params(8,:);
            alpha = params(9,:);
            beta = params(10,:);
            gamma = params(11,:);            

            % Get the soil moisture store for the required soil unit
            if nargin==2 || SMSnumber==1
                SMS = obj.variables.SMS;
                SMSnumber = 1;
            elseif SMSnumber==2
                SMS = obj.variables.SMS_trees;
                SMSC = SMSC_trees;
            else
                error('The soil moisture unit number is unknown')
            end
             
            try 
                for i=1:length(variableName)
                    switch variableName{i}
                        case 'drainage'
                            forcingData(:,i) = (1-interflow_frac) .* k_sat .* getTransformedForcing(obj, 'drainage_normalised',SMSnumber);
                            isDailyIntegralFlux(i) = false;
                        case 'drainage_bypassFlow'
                            drainage = getTransformedForcing(obj, 'drainage',SMSnumber);
                            runoff = getTransformedForcing(obj, 'runoff',SMSnumber);
                            forcingData(:,i) = drainage + bypass_frac.*runoff;

                            isDailyIntegralFlux(i) = true;

                        case 'drainage_normalised'
                            forcingData(:,i) = (SMS/SMSC).^beta;
                            isDailyIntegralFlux(i) = false;

                        case 'evap_soil'    
                            forcingData(:,i) = obj.variables.evap .* (SMS/SMSC).^gamma;
                            isDailyIntegralFlux(i) = false;

                        case 'infiltration'                       
                            drainage = getTransformedForcing(obj, 'drainage',SMSnumber);
                            actualET = getTransformedForcing(obj, 'evap_soil',SMSnumber);                        
                            drainage =  0.5 .* (drainage(1:end-1) + drainage(2:end));
                            actualET = 0.5 .* (actualET(1:end-1) + actualET(2:end));                    
                            forcingData(:,i) = [0 ; min(obj.variables.precip(2:end,1),max(0,(obj.variables.precip(2:end,1)>0) .* (diff(SMS) + drainage + actualET)))];
                            isDailyIntegralFlux(i) = true;

                        case 'evap_gw_potential'
                            forcingData(:,i) = obj.variables.evap .* (1-(SMS/SMSC).^gamma);
                            isDailyIntegralFlux(i) = false;

                        case 'interflow'
                            forcingData(:,i) = interflow_frac .* k_sat .* getTransformedForcing(obj, 'drainage_normalised',SMSnumber);
                            isDailyIntegralFlux(i) = false;

                        case 'runoff'
                            infiltration = getTransformedForcing(obj, 'infiltration',SMSnumber);
                            interflow = getTransformedForcing(obj, 'interflow',SMSnumber);
                            forcingData(:,i) = max(0,obj.variables.precip - infiltration) + interflow;
                            isDailyIntegralFlux(i) = true;

                        case'SMS'
                            forcingData(:,i) = SMS;
                            isDailyIntegralFlux(i) = false;

                        otherwise
                            if  isfield(obj.settings,'simulateLandCover') && obj.settings.simulateLandCover && nargin==2 
                                if isempty(strfind(variableName{i}, '_nontree')) && isempty(strfind(variableName{i}, '_tree'))
                                    error('The requested transformed forcing variable is not known.');
                                end
                            else                            
                                error('The requested transformed forcing variable is not known.');
                            end
                    end

                    % Get flixes for tree soil unit (if required) and weight the
                    % flux from the two units
                    if  isfield(obj.settings,'simulateLandCover') && obj.settings.simulateLandCover && nargin==2
                        if ~isempty(strfind(variableName{i}, '_nontree'))
                            % Get flux for non-tree componant
                            ind = strfind(variableName{i}, '_nontree');
                            variableName{i} = variableName{i}(1:ind-1);
                            [forcingData(:,i),isDailyIntegralFlux(i)]  = getTransformedForcing(obj, variableName{i}, 1) ;
                            forcingData(:,i) =  (1-treeArea_frac .* obj.variables.treeFrac) .* forcingData(:,i);
                        elseif ~isempty(strfind(variableName{i}, '_tree'))
                            % Get flux for non-tree componant
                            ind = strfind(variableName{i}, '_tree');
                            variableName{i} = variableName{i}(1:ind-1);
                            [forcingData(:,i),isDailyIntegralFlux(i)] = getTransformedForcing(obj, variableName{i}, 2);                
                            forcingData(:,i) = treeArea_frac .* obj.variables.treeFrac .* forcingData(:,i);
                        else
                            % Get flux for tree SMS
                            forcingData_trees = getTransformedForcing(obj, variableName{i}, 2);                    

                            % Do weighting
                            forcingData(:,i) = (1-treeArea_frac .* obj.variables.treeFrac) .* forcingData(:,i) + ...
                                          treeArea_frac .* obj.variables.treeFrac .* forcingData_trees;
                        end
                    end                    
                end
            catch ME
                
            end
            

        end

        
        % Return the derived variables. This is used by this class to get
        % the back transformed parameters.
        function [params, param_names] = getDerivedParameters(obj)
            
            param_names = {'SMSC: back transformed soil moisture storage capacity (in rainfall units)'; ...                  
                           'SMSC_trees: back transformed soil moisture storage capacity in trees unit (in rainfall units)'; ...
                           'treeArea_frac: fractional area of the tree units (-)'; ...
                           'S_initialfrac: fractional initial soil moisture (-)'; ... 
                           'k_infilt : back transformed maximum soil infiltration rate (in rainfall units)'; ...
                           'k_sat : back transformed maximum vertical conductivity (in rainfall units/day)'; ...
                           'bypass_frac : fraction of runoff that goes to bypass drainage (-)'; ...
                           'interflow_frac : fraction of free drainage going to interflow (-)'; ...        
                           'alpha : power term for infiltration rate (-)'; ...       
                           'beta : back transformed power term for dainage rate (eg approx. Brook-Corey pore index power term)'; ...
                           'gamma : back transformed power term for soil evaporation rate (-)'};    
        
            params = [  10.^(obj.SMSC); ...
                        10.^(obj.SMSC_trees); ...
                        obj.treeArea_frac; ...
                        obj.S_initialfrac; ...
                        10.^obj.k_infilt; ...
                        10.^obj.k_sat; ...
                        obj.bypass_frac; ...
                        obj.interflow_frac; ...
                        obj.alpha; ...
                        10.^(obj.beta); ...
                        10.^(obj.gamma)];
        end

        % Return coordinates for forcing variable
        function coordinates = getCoordinates(obj, variableName)

            if ~iscell(variableName)
                variableNameTmp{1}=variableName;
                variableName = variableNameTmp;
                clear variableNameTmp;
            end
                
            coordinates = cell(length(variableName),3);
            for i=1:length(variableName)
                % Find row within the list of required containing variabeName
                filt = strcmp(obj.settings.forcingData_cols(:,1), variableName{i});

                % If empty, then it is likely to be a model output variable os use the precip coordinate.
                if ~any(filt)
                    filt = strcmp(obj.settings.forcingData_cols(:,1), 'precip');
                end
                sourceColNumber = obj.settings.forcingData_cols{filt,2};
                sourceColName = obj.settings.forcingData_colnames{sourceColNumber};

                % Get coordinates
                filt = strcmp(obj.settings.siteCoordinates(:,1), sourceColName);
                coordinates(i,:) = obj.settings.siteCoordinates(filt,:);
                coordinates{i,1} = variableName{i};
            end    
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


