classdef climateTransform_Threshold < forcingTransform_abstract 
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
%   diffenential equation (Kavetski et al. 2003, 2006):
%   
%   DS/dt = P_inf (1 - S/SMSC)^alpha - k_sat (S/SMSC)^beta - PET (S/SMSC)^gamma -- (Kavestki 2006)
%
%   DS/dt = P_inf [(SMSC-S)/(SMSC(1-eps))]^alpha - k_sat (S/SMSC)^beta - PET (S/SMSC)^gamma  -- (Kavestki 2003, 2006)
%
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
%       eps      - ratio of S_min/SMSC. If eps=0, S_min=zero
%       bypass_frac   - Fraction of runoff to bypass drainage (0-1).
%       interflow_frac- Fraction of free drainage going to interflow (0-1).
%       S_initialfrac - Initial soil moisture scaler (0-10) to steady state S.
%       DDF     - Degree-Day snow melt factor [L\C\T}.
%       melt_threshold - Temperature threshold for snow melt [C].
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
%       k_infilt      - log10(Soil infiltration capacity as water depth).
%       k_sat         - log10(Maximum vertical infiltration rate).
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
%   The current infiltration term of the soil moisture model is an adaption of VIC Model (Wood et al. 1992) with a 
%   S_min threshold as per Kalma et al. (1995) and Kavestki et al. (2003).
%   This S_min term adds discontinuity to the infiltration term but the
%   evapotranspiration and drainage terms are kept as in Kavetski et al.
%   (2006), so the model has limited discontinuities (thus able to produce a first-order smooth
%   calibration response surface) and therefore amenable to gradient based
%   calibration. The S_min term is included as a ration of S_min/SMSC =
%   eps, thus if eps = 0 we have the original soil moisture model given by
%   Kavetski et al. (2006) 
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
        threshold  % Temperature threshold for snow melt [C].
        %----------------------------------------------------------------        
    end


    
%%  STATIC METHODS        
% Static methods used to inform the
% user of the available model types. 
    methods(Static)
        function [variable_names, isOptionalInput] = inputForcingData_required(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates)
            variable_names = {'climateVariable'};
            isOptionalInput = false;
        end
        
        function [variable_names] = outputForcingdata_options(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates)
            variable_names = {'aboveThreshold'; 'belowThreshold'};
        end
        
        function [options, colNames, colFormats, colEdits, toolTip] = modelOptions()
           
            options = { 'threshold'     ,   0, 'Calib.'};

            colNames = {'Parameter', 'Initial Value','Fixed or Calibrated?'};
            colFormats = {'char', 'char', {'Calib.' 'Fixed'}};
            colEdits = logical([0 1 1]);

            toolTip = sprintf('threshold    : Threshold value.');                               

        end
        
        function modelDescription = modelDescription()
           modelDescription = {'Name: climateTransform_Threshold', ...
                               '', ...
                               'Purpose: nonlinear transformation of rainfall and areal potential evaporation to a range of forcing data (eg free-drainage) ', ...
                               'using a highly flexible single layer soil moisture model. Two types of land cover can be simulated using two parrallel soil models.', ...
                               '', ...                               
                               'Number of parameters: 0', ...
                               '', ...                               
                               'Options: each model parameter (excluding the soil moisture capacity) can be set to a fixed value (ie not calibrated) or calibrated.', ...
                               'Also, the input forcing data field "TreeFraction" is optional and only required if the soil model is to simulate land cover change.', ...
                               '', ...                               
                               'Comments: Below is a summary of the model parameters:' , ...
                                'threshold     : threshold climate value.'};
        end        
           
    end
        
    
    methods       
%% Construct the model
        function obj = climateTransform_Threshold(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates, forcingData_reqCols, modelOptions)            
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

             
            % Assign the input forcing data to obj.settings.
            obj.settings.forcingData = forcingData_data;
            obj.settings.forcingData_colnames = forcingData_colnames;
            obj.settings.forcingData_cols = forcingData_reqCols;
            obj.settings.siteCoordinates = siteCoordinates;                             
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
               obj.threshold = params;                       
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
                if any(filt)
                    forcingDataNew(:,filt) = forcingData(:,i);
                end
            end
            obj.settings.forcingData = forcingDataNew;
            obj.variables.isNewParameters = true;
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
            
            param_names = 'threshold';
            params = obj.threshold;            
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

            params_lowerLimit = -Inf;
            params_upperLimit = Inf;
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
            
            
            params_lowerLimit = -30;
            params_upperLimit = 0;             
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
%   * mass_balance: daily mass balance error.
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
%   Guancarlo Boniotto, The University of Melbourne (extension of eps term
%   for runoff)
%
% Date:
%   11 April 2012  
        
            % Initialise output
            forcingData = struct();

            % back transform the parameters
            params = getDerivedParameters(obj);
            
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
            eps = params(12,:);
            DDF = params(13,:);
            melt_threshold = params(14,:);

            % Set if the subdaily steps should be integrated.
            if nargin < 3
                doSubstepIntegration = true;
            end
            
            % Calc. effective precip first. This is because it can be done
            % prior to the SMS being estimated, which is required for the
            % first call to setTranformForcing().
            ii=1;
            if any(strcmp(variableName,'effectivePrecip'))
                % Limit precip to the maxim soil infiltration rate.
                effectivePrecip = obj.variables.precip;
                if k_infilt < inf && (obj.settings.activeParameters.k_infilt || obj.settings.fixedParameters.k_infilt)
                    lambda_p = obj.settings.lambda_p .* k_infilt;
                    effectivePrecip= (effectivePrecip>0).*(effectivePrecip+ lambda_p * log( 1./(1 + exp( (effectivePrecip - k_infilt)./lambda_p))));
                    effectivePrecip(isinf(effectivePrecip)) = k_infilt;
                end

                % Integreate to daily.
                if doSubstepIntegration
                    forcingData.(variableName{ii}) = effectivePrecip;
                    isDailyIntegralFlux(ii) = true;
                else
                    % Dissaggregate to subdaily
                    effectivePrecip = getSubDailyForcing(obj,effectivePrecip);
                    effectivePrecip = subDailyVector2Matrix(obj, effectivePrecip, true);

                    forcingData.(variableName{ii}) = effectivePrecip;
                    isDailyIntegralFlux(ii) = false;
                end
                ii=ii+1;

                % Return if only effective precip to be calculated.
                if length(variableName)==1
                    return
                end
            end

            % Calculate the required fluxes.
            for i=ii:length(variableName)
                try
                    % Get the soil moisture store for the required soil unit
                    if contains(variableName{i}, '_nontree')
                        SMS = obj.variables.SMS;
                        variabName_suffix = '_nontree';
                    elseif contains(variableName{i}, '_tree')
                        SMS = obj.variables.SMS_trees;
                        SMSC = SMSC_trees;
                        variabName_suffix = '_tree';
                    else
                        SMS = obj.variables.SMS;
                        variabName_suffix = '';
                    end

                    % Convert subdaily soil moisture to a matrix, if not done by
                    % setTransformedForcing().
                    SMS = subDailyVector2Matrix(obj, SMS, false);

                    if isfield(obj.settings,'simulateLandCover') && obj.settings.simulateLandCover && isempty(variabName_suffix)
                        % Get flux for combined non-tree and tree componants and weight.

                        % Get flux for tree SMS
                        [fluxes_nontree, isDailyIntegralFlux(i)] = getTransformedForcing(obj, strcat(variableName{i},'_nontree'), doSubstepIntegration);
                        fluxes_tree = getTransformedForcing(obj, strcat(variableName{i},'_tree'), doSubstepIntegration);

                        % Do weighting
                        forcingData.(variableName{i}) = (1-treeArea_frac .* obj.variables.treeFrac) .* fluxes_nontree.(strcat(variableName{i},'_nontree')) + ...
                            treeArea_frac .* obj.variables.treeFrac .* fluxes_tree.(strcat(variableName{i},'_tree'));
                    else
                        switch variableName{i}                            
                            case {'drainage', 'drainage_tree', 'drainage_nontree'}

                                % Cal.c bypass frainage (ie % runoff)
                                runoff = 0;
                                if bypass_frac~=0
                                    % Get runoff
                                    runoff = getTransformedForcing(obj, strcat('runoff',variabName_suffix), false);

                                    % Re-scale runoff from that going to the stream to that going to recharge plus the stream.
                                    runoff  = strcat('runoff',variabName_suffix) ./ (1-bypass_frac);
                                end
                                nDailySubSteps = getNumDailySubsteps(obj);
                                drainage = (1-interflow_frac) .* k_sat/nDailySubSteps .*(SMS/SMSC).^beta;
                                drainage  = drainage + bypass_frac.*runoff;
                                if doSubstepIntegration
                                    forcingData.(variableName{i}) = dailyIntegration(obj, drainage);
                                    isDailyIntegralFlux(i) = true;
                                else
                                    forcingData.(variableName{i}) = drainage;
                                    isDailyIntegralFlux(i) = false;
                                end
                            case {'interflow','interflow_tree', 'interflow_nontree'}
                                nDailySubSteps = getNumDailySubsteps(obj);
                                interflow = interflow_frac .* k_sat/nDailySubSteps .*(SMS/SMSC).^beta;

                                if doSubstepIntegration
                                    forcingData.(variableName{i}) = dailyIntegration(obj, interflow);
                                    isDailyIntegralFlux(i) = true;
                                else
                                    forcingData.(variableName{i}) = interflow;
                                    isDailyIntegralFlux(i) = false;
                                end
                            case {'evap_soil', 'evap_soil_tree', 'evap_soil_nontree'}
                                % Expand input forcing data to have the required number of substeps.
                                evap = getSubDailyForcing(obj,obj.variables.evap);
                                evap = subDailyVector2Matrix(obj, evap, true);

                                % Est ET
                                evap = evap .* (SMS/SMSC).^gamma;
                                if doSubstepIntegration
                                    forcingData.(variableName{i}) = dailyIntegration(obj, evap);
                                    isDailyIntegralFlux(i) = true;
                                else
                                    forcingData.(variableName{i}) = evap;
                                    isDailyIntegralFlux(i) = false;
                                end

                            case {'infiltration_fracCapacity', 'infiltration_fracCapacity_tree', 'infiltration_fracCapacity_nontree'}

                                % Calculate infiltration fractional capacity, representing the fraction of rainfall that is infiltrated
                                nDailySubSteps = getNumDailySubsteps(obj);
                                infiltration_fractional_capacity = min(1, ((SMSC - SMS)/(SMSC*(1-eps))).^alpha);

                                if doSubstepIntegration
                                    forcingData.(variableName{i}) = 1./nDailySubSteps.*dailyIntegration(obj, infiltration_fractional_capacity);
                                    isDailyIntegralFlux(i) = true;
                                else
                                    forcingData.(variableName{i}) = infiltration_fractional_capacity;
                                    isDailyIntegralFlux(i) = false;
                                end

                            case {'infiltration', 'infiltration_tree', 'infiltration_nontree'}
                                % Calculate max. infiltration assuming none
                                % goes to SATURATED runoff.

                                if doSubstepIntegration
                                    if alpha==0
                                        fluxes = getTransformedForcing(obj, ['liquidWater', strcat({'drainage','evap_soil','interflow'},variabName_suffix)], true);
                                        infiltration =  fluxes.liquidWater;
                                    else
                                        fluxes = getTransformedForcing(obj, ['liquidWater', strcat({'drainage','evap_soil','interflow','infiltration_fracCapacity'},variabName_suffix)], true);
                                        infiltration =  fluxes.liquidWater .* fluxes.(strcat('infiltration_fracCapacity',variabName_suffix));
                                    end

                                    % Calculatre when the soil is probably saturated.
                                    Infilt2Runoff = (SMS(:,1) + infiltration - fluxes.(strcat('evap_soil',variabName_suffix)) - ...
                                        fluxes.(strcat('drainage',variabName_suffix)) - ...
                                        fluxes.(strcat('interflow',variabName_suffix)) ) - SMSC;
                                    Infilt2Runoff(Infilt2Runoff<0) = 0;

                                    % Subtract estimated satruated excess runoff
                                    % from the infiltration and then integrate.
                                    infiltration = infiltration - Infilt2Runoff;

                                    forcingData.(variableName{i}) = infiltration;
                                    isDailyIntegralFlux(i) = true;
                                else
                                    error('Infiltration can only be calculated at a daily timestep.')
                                end
                            case {'evap_gw_potential', 'evap_gw_potential_tree', 'evap_gw_potential_nontree'}
                                % Expand input forcing data to have the required number of substeps.
                                PET = getSubDailyForcing(obj,obj.variables.evap);
                                PET = subDailyVector2Matrix(obj, PET, true);

                                % Get soil ET
                                fluxes = getTransformedForcing(obj, strcat('evap_soil',variabName_suffix), false);

                                % Calc groundwater PET
                                evap = PET - fluxes.(strcat('evap_soil',variabName_suffix));
                                if doSubstepIntegration
                                    forcingData.(variableName{i}) = dailyIntegration(obj, evap);
                                    isDailyIntegralFlux(i) = true;
                                else
                                    forcingData.(variableName{i}) = evap;
                                    isDailyIntegralFlux(i) = false;
                                end

                            case {'runoff', 'runoff_tree', 'runoff_nontree'}
                                if doSubstepIntegration
                                    % Calculate infiltration.
                                    fluxes = getTransformedForcing(obj, strcat({'infiltration','interflow'},variabName_suffix), true);

                                    % Get subdaily precip
                                    precip = obj.variables.precip;

                                    % Calc sub daily runoff
                                    runoff = max(0, precip - fluxes.(strcat('infiltration',variabName_suffix)));
                                    runoff = runoff * (1-bypass_frac) + fluxes.(strcat('interflow',variabName_suffix));

                                    forcingData.(variableName{i}) = runoff;
                                    isDailyIntegralFlux(i) = true;
                                else
                                    error('Runoff can only be calculated at a daily timestep.')
                                end

                            case {'SMS', 'SMS_tree', 'SMS_nontree'}
                                if doSubstepIntegration
                                    forcingData.(variableName{i}) = SMS(:,1);   % Returns value at the start of each day.
                                else
                                    forcingData.(variableName{i}) = SMS;
                                end
                                isDailyIntegralFlux(i) = false;
                            case {'SMS_pcnt', 'SMS_tree_pcnt', 'SMS_nontree_pcnt'}
                                if doSubstepIntegration
                                    forcingData.(variableName{i}) = 100.*SMS(:,1)./SMSC;   % Returns value at the start of each day.
                                else
                                    forcingData.(variableName{i}) = 100.*SMS./SMSC;
                                end
                                isDailyIntegralFlux(i) = false;

                            case {'snow', 'snow_tree', 'snow_nontree', 'melt', 'melt_tree', 'melt_nontree', 'liquidWater', 'liquidWater_tree', 'liquidWater_nontree'}
                                liquidWater = getSubDailyForcing(obj,obj.variables.precip);                                
                                nsteps = length(liquidWater);
                                snow = zeros(nsteps,1);
                                melt = zeros(nsteps,1);
                                
                                nDailySubSteps = getNumDailySubsteps(obj);
                                
                                if ~isempty(obj.variables.temp)
                                    temp = getSubDailyForcing(obj,obj.variables.temp);                               
                                    DDF = DDF./nDailySubSteps;
                                    for j=2:nsteps

                                        if (temp(j) <= melt_threshold)
                                            melt(j) = 0.0;
                                            snow(j) = snow(j-1) + liquidWater(j);
                                            liquidWater(j) = 0.0;
                                        else
                                            melt(j) = DDF*(temp(j) - melt_threshold);
                                            snow(j) = max(snow(j-1) - melt(j),0.0);
                                            liquidWater(j) = liquidWater(j) + min(snow(j-1), melt(j));
                                        end
                                    end
                                end
                                
                                if contains(variableName{i},'liquidWater')
                                    result = liquidWater;
                                elseif contains(variableName{i},'melt')
                                    result = melt;
                                else
                                    result = snow;
                                end
                                result = subDailyVector2Matrix(obj, result, true);

                                if doSubstepIntegration
                                    forcingData.(variableName{i}) = dailyIntegration(obj, result);
                                    isDailyIntegralFlux(i) = true;
                                else
                                    forcingData.(variableName{i}) = result;
                                    isDailyIntegralFlux(i) = false;
                                end

                            case {'mass_balance_error', 'mass_balance_error_tree', 'mass_balance_error_nontree'}
                                % Calculate fluxes at daily or subdaily time
                                % step and then calc. mass balance error
                                if doSubstepIntegration
                                    % Get fluxes
                                    precip = obj.variables.precip;
                                    fluxes = getTransformedForcing(obj, strcat({'runoff','evap_soil', 'drainage','SMS'},variabName_suffix), true);

                                    % Calc mass balance error
                                    fluxEstError = [precip(1:(end-1),1) - diff(fluxes.(strcat('SMS',variabName_suffix))) -  ...
                                        fluxes.(strcat('runoff',variabName_suffix))(1:(end-1),1) - ...
                                        fluxes.(strcat('evap_soil',variabName_suffix))(1:(end-1),1) - fluxes.(strcat('drainage',variabName_suffix))(1:(end-1),1);0];

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

        
        % Return the derived variables. This is used by this class to get
        % the back transformed parameters.
        function [params, param_names] = getDerivedParameters(obj)
         
            param_names = {'SMSC: back transformed soil moisture storage capacity (in rainfall units)'; ...                  
                           'SMSC_trees: back transformed soil moisture storage capacity in trees unit (in rainfall units)'; ...
                           'treeArea_frac: fractional area of the tree units (-)'; ...
                           'S_initialfrac: initial soil moisture scaler (-)'; ... 
                           'k_infilt : back transformed maximum soil infiltration rate (in rainfall units)'; ...
                           'k_sat : back transformed maximum vertical conductivity (in rainfall units/day)'; ...
                           'bypass_frac : fraction of runoff that goes to bypass drainage (-)'; ...
                           'interflow_frac : fraction of free drainage going to interflow (-)'; ...        
                           'alpha : power term for infiltration rate (-)'; ...       
                           'beta : back transformed power term for dainage rate (eg approx. Brook-Corey pore index power term)'; ...
                           'gamma : back transformed power term for soil evaporation rate (-)'; ...
                           'eps : fraction of SMSC, below which all precip. infiltrates.'; ...
                           'DDF : Snow melt degree-day factor.'; ...
                           'melt_threshold: Temp. threshold for snow melt.'};    
 
            param_names_trim = {'SMSC'; ...                  
                           'SMSC_trees'; ...
                           'treeArea_frac'; ...
                           'S_initialfrac'; ... 
                           'k_infilt'; ...
                           'k_sat'; ...
                           'bypass_frac'; ...
                           'interflow_frac'; ...        
                           'alpha'; ...       
                           'beta'; ...
                           'gamma'; ...
                           'eps'; ...
                           'DDF'; ...
                           'melt_threshold'};    
                         
            if ~isempty(obj.eps)
                params = [  10.^(obj.SMSC(1)); ...
                    10.^(obj.SMSC_trees(1)); ...
                    obj.treeArea_frac(1); ...
                    obj.S_initialfrac(1); ...
                    10.^obj.k_infilt(1); ...
                    10.^obj.k_sat(1); ...
                    obj.bypass_frac(1); ...
                    obj.interflow_frac(1); ...
                    obj.alpha(1); ...
                    10.^(obj.beta(1)); ...
                    10.^(obj.gamma(1)); ...
                    obj.eps(1)];
            else
                params = [  10.^(obj.SMSC(1)); ...
                    10.^(obj.SMSC_trees(1)); ...
                    obj.treeArea_frac(1); ...
                    obj.S_initialfrac(1); ...
                    10.^obj.k_infilt(1); ...
                    10.^obj.k_sat(1); ...
                    obj.bypass_frac(1); ...
                    obj.interflow_frac(1); ...
                    obj.alpha(1); ...
                    10.^(obj.beta(1)); ...
                    10.^(obj.gamma(1)); ...
                    0];
            end
            if isempty(obj.DDF) || isempty(obj.melt_threshold)
                params = [params; inf;inf];
            else
                params = [params; obj.DDF; obj.melt_threshold];                
            end

            % Expand vector of params to matrix - if obj has multiple
            % parameter sets.
            calibParamNames = getActiveParameters(obj);
            if length(obj.(calibParamNames{1}))>1
                params = repmat(params, 1, length(obj.(calibParamNames{1})));
                for i=1:length(param_names_trim)
                    if length(obj.(param_names_trim{i}))>1
                        if any(strcmp(param_names_trim{i}, {'SMSC','SMSC_trees','k_infilt','k_sat','beta','gamma'}))
                            params(i,:) = 10.^(obj.(param_names_trim{i}));
                        elseif strcmp(param_names_trim{i}, 'eps') && isempty(obj.eps)
                            params(i,:) = 0;
                        else
                            params(i,:) = obj.(param_names_trim{i});
                        end
                    end
                end   
            end           
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
        
        function data_daily = dailyIntegration(obj, data)
            % Note, this function numerically integrates sub-daily soil fluxes
            % to a daily time step. The soil moisture ODE C-code is used
            % to simulate sub-daily dynamics by inputting data
            % dissaggregated to sub-daily - ie the daily total precip is
            % divided by the number of sub-daily timesteps (eg 30 mm/day
            % becomes three steps of 10mm per 8 hours) and K_sat is similar scaled
            % down. Also, the ODE predicts the SMS at time t using the
            % forcing data at time t, not the prior forcing.
            
            % Get number of daily steps     
            nSubSteps = obj.variables.nDailySubSteps;

            % Get number of days
            nDays = length(obj.variables.precip);

            % check dimenions of data correspond to the expected format of subdaily
            % data.
            if size(data,1)~= nDays
                error('Input data has a different number of rows than the number of days of forcing data.')
            elseif size(data,2)~= (nSubSteps+1)
                error('Input data has a different number of columns than the number of sub-daily timesteps + 1.')
            end
            
            % integrate to daily
            if nSubSteps==2
                % Use Simpson's quadratic rule
                data_daily = nSubSteps/6*(data(:,1) + 4*data(:,2) + data(:,3));
            elseif nSubSteps==3
                % Use Simpson's 3/8 rule
                data_daily = nSubSteps/8*(data(:,1) + 3*(data(:,2) + data(:,3)) + data(:,4));
            else
                % Use trapazoidal method
                data_daily = trapz(0:nSubSteps, data, 2);
            end
        end
        
        function nDailySubSteps = getNumDailySubsteps(obj)
            if isfield(obj.variables,'nDailySubSteps')
                nDailySubSteps = obj.variables.nDailySubSteps;
            else
                nDailySubSteps = 3;
                obj.variables.nDailySubSteps = nDailySubSteps;
            end
        end
        
        function data = getSubDailyForcing(obj,data)
            % Get subset size
            nSubSteps = getNumDailySubsteps(obj);
            
            % Get number of days
            nDays = length(obj.variables.precip);
            
            % Get the forcing rate PER substep.
            data = data./nSubSteps;
            
            % Build daily subseteps
            data = reshape(repmat(data,1,nSubSteps)',nDays * nSubSteps,1);
            
            % Add dummy row of data to account for the initial
            % condition being added to to t.
            data = [0;data];
        end

        function data = subDailyVector2Matrix(obj, data, isClimateData)
            % Get subset size
            nSubSteps = getNumDailySubsteps(obj);
            
            % Get number of days
            nDays = length(obj.variables.precip);

            % Check if the data is alreadt in matrix form. If so, do
            % nothing.
            if size(data,1)==nDays && size(data,2)==nSubSteps
                return
            end

            % Check input vector is sub-daily
            if length(data) ~= (nDays*nSubSteps+1)
                data=[];
                error('Input data must be a vector of subdaily data.');
            end

            % Reshape subdaily vector into a matrix of ndays rows by
            % (nSubSteps+1) columns, where the value at column nSubSteps+1 is the
            % value for the end of the day. This is done to allow integration
            % across the whole day.
            if isClimateData %  The value for the last time step of the day is
                % the that for the current day, and not that at the start
                % of the next day, as done for soil moistire.
                data = reshape(data(2:end), nSubSteps, nDays)';
                data = [data, data(:,end)];
            else % This option should be soil moisture, where the RHS column should be
                 % the valu at the end of the current day.
                data_end = data(end);
                data = reshape(data(1:end-1), nSubSteps, nDays)'; 
                data = [data, [data(2:end,1);data_end]];
            end
        end

        function data = subDailyMatrix2Vector(obj, data)
            % Get subset size
            nSubSteps = getNumDailySubsteps(obj);
            
            % Get number of days
            nDays = length(obj.variables.precip);

            % Check if the data is already in vector form. If so, do
            % nothing.
            if size(data,1)==nDays*nSubSteps+1 || size(data,2)==1
                return
            end

            % Check input matrix has each day as a row.
            if size(data,1) ~= nDays
                data=[];
                error('Input data must be a matrix with each row being a different day.');
            end

            % Check input matrix has each column as subdaily steps
            if size(data,2)-1 ~= nSubSteps
                data=[];
                error('Input data must be a matrix with each column being equal to the numebr of subdaily steps+1.');
            end
            
            % Reshape subdaily mastrix into a vector of ndays * nSubSteps
            % where the value of the end colum is ignored, since it's equal 
            % to the value at the start of the next day.
            data = [reshape(data(:,1:end-1)',1,nDays*nSubSteps)'; data(end,end)];
        end        
    end
    
end


