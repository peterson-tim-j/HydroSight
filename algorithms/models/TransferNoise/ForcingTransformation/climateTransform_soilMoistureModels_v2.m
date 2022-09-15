classdef climateTransform_soilMoistureModels_v2 < climateTransform_soilMoistureModels
% Class definition for soil moisture transformation of climate forcing.
%
% Description        
%   climateTransform_soilMoistureModels_v2 is a generalised vertically lumped 1-D
%   soil moisture model. It is identical to climateTransform_soilMoistureModels()
%   except that the simulated average actual soil evaporation is constrained to be 
%   between the 5th and 95th perceililes of the actual ET as defined from Greve et 
%   al. 2015. This is achievd by rejecting parameter sets that produce actual 
%   ET values outsde these bounds.
%
% See also
%   climateTransform_soilMoistureModels: parent model;
%   climateTransform_soilMoistureModels_v2: model_construction;
%
% Dependencies
%   forcingTransform_soilMoisture.c
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure Engineering, 
%   The University of Melbourne.
%
% Date:
%   1 September 2017
    
    properties(GetAccess=public, SetAccess=protected)
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
            variable_names = climateTransform_soilMoistureModels.outputForcingdata_options(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates);
        end
        
        function [options, colNames, colFormats, colEdits, toolTip] = modelOptions()
           
            options = { 'SMSC'          ,   2, 'Calib.';...
                        'SMSC_trees'    ,   2, 'Fixed';...
                        'treeArea_frac' , 0.5, 'Fixed'; ...
                        'S_initialfrac' , 0.5, 'Fixed'  ; ...
                        'k_infilt'      , inf,'Fixed'   ; ...
                        'k_sat'         ,   0.5, 'Calib.'   ; ...
                        'bypass_frac'   ,   0, 'Fixed'    ; ...
                        'interflow_frac',   0, 'Fixed'    ; ...
                        'alpha'         ,   0, 'Fixed'    ; ...
                        'beta'          , 0.5,'Calib.' ; ...
                        'gamma'         ,   0,  'Fixed'; ...
                        'eps'           ,   0,  'Fixed'};

        
            colNames = {'Parameter', 'Initial Value','Fixed or Calibrated?'};
            colFormats = {'char', 'char', {'Calib.' 'Fixed'}};
            colEdits = logical([0 1 1]);

            toolTip = sprintf([ 'SMSC         : log10(Soil moisture capacity).\n', ...
                                'SMSC_trees   : log10(Tree SMSC).\n', ...
                                'treeArea_frac: Tree fraction scalar.\n', ...                                
                                'S_initialfrac: Initial soil moisture frac.\n', ...
                                'k_infilt     : log10(Max. infilt. capacity).\n', ...
                                'k_sat        : log10(Max. drainage rate).\n', ...
                                'bypass_frac  : Frac. runoff to bypass drainage.\n', ...
                                'interflow_frac: Frac. drainage to interflow.\n', ...
                                'alpha        : Power term for infilt. rate.\n', ...
                                'beta         : log10(Power term for dainage).\n', ...
                                'gamma        : log10(Power term for soil evap.).\n', ...
                                'eps          : Threshold SMSC frac. for runoff.']);                                         
            
        end
        
        function modelDescription = modelDescription()
           modelDescription = {'Name: climateTransform_soilMoistureModels_v2', ...
                               '', ...
                               'Purpose: nonlinear transformation of rainfall and areal potential evaporation to a range of forcing data (eg free-drainage). ', ...
                               'It is identical to climateTransform_soilMoistureModels() except that the simulated average actual soil evaporation is', ...
                               'constrained to be between the 5th and 95th percentiles of the actual ET as defined from Greve et al. 2015. This is achievd by', ...
                               'rejecting parameter sets that produce actual ET values outsde these bounds.', ...                                                              
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
                                'eps           : Fraction of SMSC, below which all precip. infiltrates.',...
                               '', ...
                               'References:', ...
                               'Greve, P., L. Gudmundsson, B. Orlowsky, and S. I. Seneviratne (2015), Introducing a probabilistic Budyko ', ...
                               'framework. Geophys. Res. Lett., 42, 2261–2269. doi: 10.1002/2015GL063449', };
        end        
           
    end
        
    
    methods       
%% Construct the model
        function obj = climateTransform_soilMoistureModels_v2(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates, forcingData_reqCols, modelOptions)            
% climateTransform_soilMoistureModels_v2 constructs the soil model object.
%
% Syntax:
%   soilModel = climateTransform_soilMoistureModels_v2(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates, forcingData_reqCols, modelOptions)   
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
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure Engineering, 
%   The University of Melbourne.
%
% Date:
%   1 September 2017

            % Build soil model
            obj = obj@climateTransform_soilMoistureModels(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates, forcingData_reqCols, modelOptions);                     

            
            % Sample Buyko w values. Approach taken from
            % reve, P., L. Gudmundsson, B. Orlowsky, and S. I. Seneviratne
            % (2015), Introducing a probabilistic Budyko framework. Geophys. 
            % Res. Lett., 42, 2261–2269. doi: 10.1002/2015GL063449. 
            %-----------------
            
            % build gamma distribution.
            pd = makedist('Gamma','a',4.54,'b',0.37);
            
            % Sample w values from distribution and add one (Bufyko must be >=1)
            nsamples = 10000;
            obj.settings.Budyko_omega = random(pd,nsamples,1)+1;            
            
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

            % Get the filetred P and potential ET is already stored in the
            % model object.
            if isfield(obj.variables,'precip') && isfield(obj.variables,'evap')
                P = obj.variables.precip;
                PET = obj.variables.evap;
                t = obj.variables.t;
            else
                filt = strcmp(obj.settings.forcingData_cols(:,1),'precip');
                precip_col = obj.settings.forcingData_cols{filt,2};
                P = obj.settings.forcingData(:, precip_col );

                filt = strcmp(obj.settings.forcingData_cols(:,1),'et');
                evap_col = obj.settings.forcingData_cols{filt,2};
                PET = obj.settings.forcingData(:, evap_col );                
                
                t = obj.settings.forcingData(:, 1);
            end

            % Calculate mean aridity index
            P = mean(P);
            PET = mean(PET);
            PET_on_P = PET/P;
            
            % Calculate Budyko samples of E/P using prior sampled values of 
            % omega at PET_on_P.
            AET_on_P = 1 + PET_on_P -(1+PET_on_P.^obj.settings.Budyko_omega).^(1./obj.settings.Budyko_omega);
            
            % Calculate the 1st and 99th percentiles
            AET_on_P = prctile(AET_on_P, [10 90],1);
            
            % Initialise output
            isValidParameter = true(size(params));
            
            % Calculate the soil moisture estimate of actual ET.
            for i=1:size(params,2)
                setParameters(obj, params(:,i));
                setTransformedForcing(obj, t, true);
                AET = mean(getTransformedForcing(obj, 'evap_soil').evap_soil,1);

                % Ceck if the AET is within the Budyko bounds
                if AET/P < AET_on_P(1) || AET/P > AET_on_P(2)
                    isValidParameter(:,i) = false;
                end
            end
            setParameters(obj, params);

            % Check parameters are within bounds.
            isValidParameter = isValidParameter & params >= params_lowerLimit(:,ones(1,size(params,2))) & ...
    		params <= params_upperLimit(:,ones(1,size(params,2)));   
        end             
    end
    
end


