classdef model_TFN < model_abstract
% Class definition for Transfer Function Noise (TFN) model for use with HydroSight
%
% Description: 
%   The class defines a transfer function Noise (TFN) model for
%   simulating time series of groundwater head. The model should be
%   defined, calibrated and solved using HydroSight() or 
%   the graphical user interface.
%
%   This class uses an object-oriented structure to provide a highly flexible 
%   model structure and the efficient inclusion of new structural
%   componants. Currently, linear and nonlinear TFN model can be built.
%   The linear models are based upon von Asmuth et al. 2002 and von Asmuth et al. 
%   2008 and the nonlinear models use a nonlinear transform of the input
%   climate data to account for runoff and nonlinear free drainage (see
%   Peterson & Western, 2014) 
%
%   Additional key features of the model include:
%
%       - long term historic daily climate forcing is used to estimate the
%       groundwater head at each time point via use of continuous transfer
%       function. 
%
%       - the non-linear response of groundwater head to climate forcing
%       can be accounted for by transforming the input forcing data.
%       Currently, a simple 1-D vertically integrated soil model is
%       available (see climateTransform_soilMoistureModels), allowing the
%       construction of a soil model with between 1 and 7 parameters.
%
%       - Pumping drawdown can be simulated using the Ferris-Knowles 
%       response function for confined aquifers, the Ferris-
%       Knowles-Jacobs function for an unconfined aquifer
%       or the Hantush function for a leaky aquifer. Each of these
%       functions allow multiple production bores to be accounted for and
%       each can have recharge or no-flow boundary conditions.
%
%       - The influence of streamflow can be approximated using the Bruggeman 
%       reponse function. Importantly, this function is a prototype and
%       should be used with caution. It is likely that the covariance
%       between rainfall and streamflow complicates the estimation of the
%       impacts of streamflow.
%
%       - a model can be fit to irregularly sampled groundwater head
%       observations via use of an exponential noise function.
%
%       - new data transfer functions can easily be defined simply
%       by the creation of new response function class definitions.
%
%       - calibration of the model is not to the observed head, but to the
%       innovations between time steps. That is, the residual between the
%       observed and modelled head is derived and the innovation is
%       calculated as the prior residual minus the later residual
%       multiplied by the exponental noise function.
%
%       - the contribution of a given driver to the head is calculated as
%       the integral of the historic forcing times the weighting function.
%       This is undertaken by get_h_star() and the mex .c compiled function
%       doIRFconvolution(). If the forcing is instantaneous (for example a
%       flux a soil moisture model) then Simpon's integration is
%       undertaken. However, if the forcing is a daily integral (such as
%       precipitation or daily pumping volumes) then daily trapazoidal
%       integration of the weighting function is undertaken and then 
%       multiplied by the daily flux.
%
%   Below are links to the details of the public methods of this class. See
%   the 'model_TFN' constructor for details of how to build a model.
%
% See also:
%   HydroSight: time_series_model_calibration_and_construction;
%   model_TFN: model_construction;
%   calibration_finalise: initialisation_of_model_prior_to_calibration;
%   calibration_initialise: initialisation_of_model_prior_to_calibration;
%   get_h_star: main_method_for_calculating_the_head_contributions.
%   getParameters: returns_a_vector_of_parameter_values_and_names;
%   objectiveFunction: returns_a_vector_of_innovation_errors_for_calibration;
%   setParameters: sets_model_parameters_from_input_vector_of_parameter_values;
%   solve: solve_the_model_at_user_input_sime_points;
%
% Dependencies:
%   responseFunction_Pearsons.m
%   responseFunction_Hantush.m
%   responseFunction_Bruggeman.m
%   responseFunction_FerrisKnowles.m
%   responseFunction_Hantush.m
%   responseFunction_FerrisKnowlesJacobs.m
%   derivedweighting_PearsonsNegativeRescaled.m
%   derivedweighting_PearsonsPositiveRescaled.m
%   climateTransform_soilMoistureModels.m
%
% References:
%   von Asmuth J. R., Bierkens M. F. P., Mass K., 2002, Transfer
%   dunction-noise modeling in continuous time using predefined impulse
%   response functions.
%
%   von Asmuth J. R., Mass K., Bakker M., Peterson J., 2008, Modeling time
%   series of ground water head fluctuations subject to multiple stresses.
%   Groundwater, 46(1), pp30-40.
%
%   Peterson and Western (2014), Nonlinear time-series modeling of unconfined
%   groundwater head, Water Resources Research, DOI: 10.1002/2013WR014800
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure Engineering, 
%   The University of Melbourne.
%
% Date:
%   26 Sept 2014
       
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
           
            str = {['"model_TFN" is a highly flexible nonlinear transfer function noise time-series model. ', ...
                   'It allows the statistical modelling of irregular groundwater head observations by the weighting ', ...
                   'of observed forcing data (e.g. daily rainfall, pumping or landuse change).', ...
                   'The forcing data can also be transformed to account for non-linear processes such as runoff or free drainage.'], ...
                   '', ...
                   'The model has the following additional features:', ...
                   '   - time-series extrapolation and interpolation.', ...
                   '   - decomposition of the hydrograph to individual drivers ', ...
                   '     (e.g. seperation of climate and pumping impacts).', ...
                   '   - decomposition of the hydrograph over time ', ...
                   '     (i.e. decomposition to influence from 1, 2, 5 and 10 years ago).', ...
                   '   - estimation of hydraulic properties (if pumping is simulated).', ...
                   '', ...
                   'For further details of the algorithms use the help menu or see:', ...
                   '', ...
                   '   - Peterson, T. J., and A. W. Western (2014), Nonlinear time-series modeling of unconfined groundwater head, Water Resour. Res., 50, 8330–8355, doi:10.1002/2013WR014800.', ...
                   '', ...
                   '   - Shapoori V., Peterson T. J., Western A. W. and Costelloe J. F., (2015), Top-down groundwater hydrograph time series modeling for climate-pumping decomposition. Hydrogeology Journal'};                     
               
        end        
    end        
    
%%  PUBLIC METHODS              
    methods
        
%% Model constructor
        function obj = model_TFN(bore_ID, obsHead, forcingData_data,  forcingData_colnames, siteCoordinates, varargin)           
% model_TFN constructs for linear and nonlinear Transfer Function Noise model
%
% Syntax:
%   model = model_TFN(bore_ID, obsHead, forcingData_data, ...
%           forcingData_colnames, siteCoordinates, modelOptions)
%
% Description:
%   Builds the model_TFN object, declares initial parameters and sets the
%   observation and forcing data within the object. This method should be 
%   called from HydroSight.
%
%   A wide range of models can be built within this method. See the inputs
%   section below for details of the model components that can be built and 
%   Peterson and Western (2014).
%
% Inputs:
%   obsHead_input - matrix of observed groundwater elevation data. The
%   matrix must comprise of two columns: date (as a double data type) 
%   and water level elevation. The data must be of a daily time-step or 
%   larger and can be non-uniform.
%
%   forcingData_data - M x N numeric matrix of daily foring data. The matrix 
%   must comprise of the following columns: year, month, day and
%   observation data. The observation data must include precipitation but
%   may include other data as defined within the input model options. 
%   The record must be continuous (no skipped days) and cannot contain blank 
%   observations.
%
%   forcingData_colnames - 1 x N cell array of the column names within the
%   input numerical array "forcingData_data". The first three columns must
%   be: year month, day. The latter columns must define the forcing data
%   column names. Imprtantly, each forcing data column name must be listed
%   within the input "siteCoordinates". 
%
%   siteCoordinates - Mx3 cell matrix containing the following columns :
%   site ID, projected easting, projected northing. Importantly,
%   the input 'bore_ID' must be listed and all columns within
%   the forcing data (excluding the year, month,day). When each response 
%   function is created, the coordinates for the observation bore and the 
%   corresponding forcing are are passed to the response function. This is
%   required for simulating the impacts of pumping. Additionally,
%   coordinates not listed in the input 'forcingData' can be input.
%   This provides a means for image wells to be input (via the input 
%   modelOptions).
%
%   modelOptions - cell matrix defining the model components, ie how the
%   model should be constructed. The cell matrix must be three columns,
%   where the first, second and third columns define the model component
%   type to be set, the component property to be set, and the value to be
%   set to the component property. Each model componant can have the following
%   property inputs ((i.e. 2nd column):
%
%       - 'weightingfunction': Property value is to define the component type.
%       Available component types include:
%           - 'responseFunction_Pearsons' (for climate forcing)
%           - 'responseFunction_Hantush' (for groundwater pumping)
%           - 'responseFunction_FerrisKnowles' (for groundwater pumping)
%           - 'responseFunction_Hantush' (for groundwater pumping)
%           - 'responseFunction_FerrisKnowlesJacobs' (for groundwater pumping)
%           - 'responseFunction_Bruggeman' (for streamflow)
%           - 'derivedweighting_PearsonsNegativeRescaled' (see below)
%           - 'derivedweighting_PearsonsPositiveRescaled' (see below)
%            
%       - 'forcingdata': Property value is the column number, column name 
%       within forcingData (as input to HydroSight) or a cell 
%       array containing the options for a forcing transformation
%       object. The forcing transformation input must be a Nx2 cell array  
%       with the following property (left column) and value (right column) 
%       settings:
%           - 'transformfunction' property and the transformation class name 
%           e.g. 'climateTransform_soilMoistureModels'
%
%           - 'forcingdata' property and a Nx2 cell array declaring the 
%           input forcing variable required by the transformation function
%           (left column) and the name of the input forcing data or column
%           number. eg   {'precip',3;'et',4}.
%
%           -  'outputdata' property and the output flux to be output from
%           the forcing transformation function. 
%
%           - 'options' propert and an input entirely dependent upon the
%           forcing transformation function. For
%           'climateTransform_soilMoistureModels' this is used to define
%           the form of the soil moisture model i.e. which ODE parameters
%           to fix and which to calibrate. See the documenttation for each
%           transformation function for details.
%
%       - 'inputcomponent': Property value is the name of another model
%       component (i.e.  the first column value). This option allows,
%       for example, the parameterised Pearson's weighting function for 
%       a precipitation componant to also be used for, say, an ET
%       componant. When building such a model, the weighting function
%       should be a derived function such as
%       'derivedweighting_PearsonsNegativeRescaled'
%
%       - 'options': cell array options specific for a weighting function.
%       The structure of the weighting function options are entirely
%       dependent upon the weighting function. Currently, only the
%       groundwater pumping weighting functions allow the input of options.
%       These pumping options allow the simulation of multiple recharge or
%       no-flow image wells per pumping bore. These options must be a Nx3 cell
%       array. The first column must be a string for the site ID of a
%       production bore. The second column must be the site of an image
%       well. Coordinate for both the production bore ID and the image
%       well must be listed within the input coordinated cell array.
%       The third column gives the type of image well. The availabes
%       type are: "recharge" for say a river; and "no flow" for say a
%       aquifer no-flow boundary.
%
% Outputs:
%   model - model_TFN class object 
%
% Example:
%   see HydroSight: time_series_model_calibration_and_construction;
%
% See also:
%   HydroSight: time_series_model_calibration_and_construction;
%   calibration_finalise: initialisation_of_model_prior_to_calibration;
%   calibration_initialise: initialisation_of_model_prior_to_calibration;
%   get_h_star: main_method_for_calculating_the_head_contributions.
%   getParameters: returns_a_vector_of_parameter_values_and_names;
%   objectiveFunction: returns_a_vector_of_innovation_errors_for_calibration;
%   setParameters: sets_model_parameters_from_input_vector_of_parameter_values;
%   solve: solve_the_model_at_user_input_sime_points;
%
% References:
%   Peterson and Western (2014), Nonlinear time-series modeling of unconfined
%   groundwater head, Water Resources Research, DOI: 10.1002/2013WR014800
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure
%   Engineering, The University of Melbourne.
%
% Date:
%   26 Sept 2014
            
            % Expand cell structure within varargin. It is required to
            % contain the model options
            varargin = varargin{1};
            
            % Check there are an even number model type options, ie for
            % option option type there is an option value.
            if length(varargin) <= 0 
               display('Default model of only precipitation forcing has been adopted because no model components were input');
            elseif size( varargin , 2) ~=3
               error('Invalid model options. The inputs must of three columns in the following order: model_component, property, property_value');
            end            
            
            % Check the forcing data does not contain nan or infs
            if any(any( isnan(forcingData_data) | isinf(forcingData_data)))
                error('The input forcing data to model_TFN cannot contain any nan or inf values.')
            end            
            
            % Check that forcing data exists before the first head
            % observation.
            if floor(min(forcingData_data(:,1))) >= floor(min(obsHead(:,1)))
                error('Forcing data must be input prior to the first water level observation. Ideally, the forcing data should start some years prior to the head.'); 
            end
                            
            % Set observed head and forcing data
            setForcingData(obj, forcingData_data, forcingData_colnames);
            obj.inputData.head = obsHead;            
            
            % Cycle though the model components and their option and
            % declare instances of objects were appropriate.
            valid_properties = {'weightingfunction','forcingdata','options', 'inputcomponent'};            
            valid_transformProperties = {'transformfunction','forcingdata','outputdata','options', 'inputcomponent'};
            
            % Check the model options.
            for ii=1: size(varargin,1)                
            
                modelComponent = varargin{ii,1};
                propertyType = varargin{ii,2};                
                propertyValue = varargin{ii,3};
                

                % Check the component properties is valid.
                ind = find(strncmpi(propertyType, valid_properties, length(propertyType)));
                if (length(ind)~=1)                    
                    error(['Invalid component property type: ',char(propertyType) ]);
                end

                % Check the component properties are valid.
                %----------------------------------------------------------
                if strcmp(propertyType, valid_properties{1})        
                    % If the propertyType is weightingfunction, check it is
                    % a valid object.
                    if isempty(meta.class.fromName(propertyValue)) 
                        % Report error if the input is not a class definition.
                        error(['The following weighting function name does not appear to be a class object:',propertyValue]);
                    end 
                elseif strcmp(propertyType, valid_properties{2})   
                    % If the propertyType is forcingdata, check if the
                    % input is cell, character (ie forcing site name) or an
                    % integer(s) (ie forcing data column number). If the
                    % input is a cell, then check if it is a list of
                    % forcing site names or a function name and inputs to
                    % transform forcing data (eg using a soil moisture
                    % model).
                    if iscell(propertyValue)
                        % If 'propertyValue' is a vector then it should be
                        % a list of forcing sites.
                        if isvector(propertyValue)
                            % Check each forcing site name is valid.
                            for j=1:length(propertyValue)                            
                                if isnumeric(propertyValue{j}) && ( propertyValue{j}<0 || propertyValue{j}+2>size(forcingData_data,2))
                                    error(['Invalid forcing column number for component:', modelComponent,'. It must be an intereger >0 and <= the number of forcing data columns.' ]);
                                elseif ischar(propertyValue{j})
                                    % Check the forcing column name is valid.
                                    filt = cellfun(@(x)(strcmp(x,propertyValue{j})),forcingData_colnames);                                
                                    if isempty(find(filt))
                                        error(['Invalid forcing column name for component:', modelComponent,'. Each forcing name must be listed within the input forcing data column names.' ]);
                                    end
                                end
                            end
                        else
                            % Check that the input is of the expected
                            % format for creating a class to derive the
                            % forcing data. The Expected format is an Nx2
                            % matrix (where N<=5) and the first colum
                            % should have rows for 'tranformationfunction'
                            % and 'outputvariable'.
                            if size(propertyValue,2) ~= 2 || size(propertyValue,1) < 2 || size(propertyValue,1) > length(valid_transformProperties)
                                error(['Invalid inputs for transforming the forcing data for component:', modelComponent,'. The input cell array must have >=2 and <=5 rows and 2 columns.' ]);
                            end
                            
                            % Check it has the required minimum inputs to
                            % the first columns.
                            if sum( strcmp(propertyValue(:,1), valid_transformProperties{1}))~=1 || ...
                            sum( strcmp(propertyValue(:,1), valid_transformProperties{3}))~=1    
                                error(['Invalid inputs for transforming the forcing data for component:', modelComponent,'. The first column of the input cell array must have rows for "transformfunction" and "outputdata".' ]);
                            end
                            
                            % Check that the first column only contains
                            % inputs that are acceptable.
                            for j=1:size(propertyValue,1)                                                                
                                if sum( strcmp(valid_transformProperties, propertyValue{j,1}))~=1    
                                    error(['Invalid inputs for transforming the forcing data for component:', modelComponent,'. Read the help for "model_TFN" to see the accepted values.' ]);
                                end
                            end
                            
                            % Check that the transformation function name
                            % is a valid class definition name.
                            filt  =  strcmp(propertyValue(:,1), valid_transformProperties{1});
                            if isempty(meta.class.fromName(propertyValue{filt,2})) 
                                error(['The following forcing transform function name is not accessible:',propertyValue{filt,2}]);
                            end   
                            
                            % Check that the forcing transformation
                            % function name is consistent with the abstract
                            % 'forcingTransform_abstract'.
                            try
                                if ~any(strcmp(findAbstractName( propertyValue{filt,2}),'forcingTransform_abstract')) && ~any(strcmp(findAbstractName( propertyValue{filt,2}),'derivedForcingTransform_abstract'))
                                    error(['The following forcing transform function class definition is not derived from the "forcingTransform_abstract.m" abstract:',propertyValue{filt,2}]);
                                end
                            catch ME
                                display('... Warning: Checking that the required abstract for the forcing transform class definition was used failed. This is may be because the version of matlab is pre-2014a.');
                            end
                            
                            % Get a list of required forcing inputs.
                            [requiredFocingInputs, isOptionalInput] = eval([propertyValue{filt,2},'.inputForcingData_required()']);
                                                        
                            % Check that the input forcing cell array has
                            % the correct dimensions.
                            filt  =  strcmp(propertyValue(:,1), valid_transformProperties{2});                            
                            if any(filt)
                                if size(propertyValue{filt,2},2) ~=2 || ...
                                (size(propertyValue{filt,2},1) ~= length(requiredFocingInputs(~isOptionalInput)) && size(propertyValue{filt,2},1) ~= length(requiredFocingInputs))
                                    error(['Invalid forcing data for the forcing transform function name for component:', modelComponent,'. It must be a cell array of two columns and ',num2str(length(requiredFocingInputs)), ' rows (one row for each required input forcing).']);
                                end
                            
                                % Check that the required inputs are specified.
                                for j=1:length(requiredFocingInputs)
                                    if isOptionalInput(j)
                                        continue
                                    end
                                    if ~any( strcmp(propertyValue{filt,2}, requiredFocingInputs{j}))
                                        error(['Invalid inputs for transforming the forcing data for component:', modelComponent,'. A forcing data site name must be specified for the following transform function input:',requiredFocingInputs{j} ]);
                                    end
                                end
                            end
                            
                            % Get a list of valid output forcing variable names.
                            filt  =  strcmp(propertyValue(:,1), valid_transformProperties{1});
                            [optionalFocingOutputs] = feval([propertyValue{filt,2},'.outputForcingdata_options'],forcingData_colnames);
                                                        
                            % Check that the output variable a char or cell vector.
                            filt  =  strcmp(propertyValue(:,1), valid_transformProperties{3});                              
                            if isnumeric(propertyValue{filt,2}) || (iscell(propertyValue{filt,2}) && ~isvector(propertyValue{filt,2}))
                                error(['Invalid output forcing variable for the forcing transform function name for component:', modelComponent,' . It must be a string or a cell vector of strings of valid output variable names.']);
                            end
                            
                            % Check each output variable name is valid.
                            if ischar(propertyValue{filt,2})
                                if ~any(strcmp(optionalFocingOutputs, propertyValue{filt,2}))
                                    error(['Invalid output forcing variable for the forcing transform function name for component:', modelComponent,' . The output variable name must be equal to one of the listed output variables for the transformaion function.']);
                                end
                            else                                
                                for j=1:length(propertyValue{filt,2})
                                    if ~any(strcmp(optionalFocingOutputs, propertyValue{filt,2}{j}))
                                        error(['Invalid output forcing variable for the forcing transform function name for component:', modelComponent,' . Each output variable name must be equal to one of the listed output variables for the transformaion function.']);
                                    end
                                end
                            end
                            
                            % Get a list of unique model components that have transformed forcing data
                            % and the transformation model does not require
                            % the input of another component.
                            k=0;
                            for j=1: size(varargin,1)
                                if  strcmp( varargin{j,2}, valid_properties{2}) ...
                                && iscell(varargin{j,3}) & ~isvector(varargin{j,3})
                            
                                    % Check if the transformation model
                                    % input as the required inputs and does
                                    % not require the input of another
                                    % component.                                    
                                    if  any(strcmp(varargin{j,3}(:,1), valid_transformProperties{1})) ...
                                    &&  any(strcmp(varargin{j,3}(:,1), valid_transformProperties{2})) ...
                                    &&  any(strcmp(varargin{j,3}(:,1), valid_transformProperties{3})) ...
                                    && ~any(strcmp(varargin{j,3}(:,1), valid_transformProperties{5}))
                                        k = k+1;
                                        % Record the component name.
                                        modelComponets_transformed{k,1} =  varargin{j,1};
                                        
                                        % Add the transformation model
                                        % name.
                                        filt = strcmp(varargin{j,3}(:,1), valid_transformProperties{1});
                                        modelComponets_transformed{k,2} =  varargin{j,3}{filt,2};
                                    end
                                end
                            end

                            % Check that each complete transforamtion model
                            % is unique.
                            if size( unique(modelComponets_transformed(:,2)),1) ...
                            ~= size( modelComponets_transformed(:,2),1)
                                error('Non-unique complete transformation models. Each complete transformation model must be input for only one model component. A complete model is that having at least the following inputs: transformfunction, forcingdata, outputdata');
                            end
                            
                            % Get a unique list of model components with
                            % complete transforamtion models and a list of
                            % unieq tranformation functions
                            modelComponets_transformed_uniqueComponents = unique(modelComponets_transformed(:,1));
                            modelComponets_transformed_uniqueTransFunc = unique(modelComponets_transformed(:,2));
                            
                            % Check the inputcomponent is a valid
                            % component.
                            filt  =  strcmp(propertyValue(:,1), valid_transformProperties{5});
                            if any(filt) && ischar(propertyValue{filt,2})
                                if ~any(strcmp(modelComponets_transformed_uniqueTransFunc(:,1), propertyValue{filt,2}))
                                    error(['Invalid source function for the forcing transform function name for component:', modelComponent,' . The input function must be a tranformation function name that is listed within the model.']);
                                end
                            elseif any(filt) && iscell(propertyValue{filt,2})   
                                for j=1:length(propertyValue{filt,2})
                                    if ~any(strcmp(modelComponets_transformed_uniqueTransFunc(:,1), propertyValue{filt,2}{j}))
                                        error(['Invalid source function for the forcing transform function name for component:', modelComponent,' . The input function must be a tranformation function name that is listed within the model.']);                                        
                                    end
                                end
                            elseif any(filt)
                                error(['Invalid source function for the forcing transform function name for component:', modelComponent,' . The input component must be a a tranformation function name (string or cell vector of strings) that is listed within the model input options and it must also have a function transformation.']);                                
                            end
                        end
                        
                    elseif ~isnumeric( propertyValue ) &&  (isnumeric(propertyValue) && any(propertyValue<0)) ...
                    && ~ischar(propertyValue)                                
                        error(['Invalid property value for property type ', valid_properties{2},'. It must be a forcing data site name or column number intereger >0 (scalar or vector)' ]);
                    end
                                            
                elseif strcmp(propertyType, valid_properties{4})    % If the propertyType is inputcomponent, check the input is a string and a valid component name.
                
                    if ischar(propertyValue)
                        % Check that it is valid component name.
                        filt = cellfun(@(x)(strcmp(x,propertyValue)), varargin(:,1));
                        if isempty(filt)
                            error(['Invalid input component name for component:', modelComponent,'. The named input componant must be a component within the model.' ]);
                        end
                    else
                        error(['Invalid input component name for component:', modelComponent,'. It must be a string defining a componant type.' ]);
                    end
                    
                end
                
            end

            % Record the source data column for each component or the
            % transformation model and output variables and input transformation component.
            filt = find(strcmpi(varargin(:,2),'forcingdata'));
            transformFunctionIndexes_noInputComponents = [];
            transformFunctionIndexes_inputComponents = [];
            for ii=filt'
               modelComponent = varargin{ii,1};
               if isnumeric(varargin{ii,3})
                  obj.inputData.componentData.(modelComponent).dataColumn = varargin{ii,3}-2;
               elseif ischar(varargin{ii,3})
                  filt_forcingCols = cellfun(@(x,y)(strcmp(x,varargin{ii,3})), forcingData_colnames);
                  obj.inputData.componentData.(modelComponent).dataColumn  = find(filt_forcingCols);
               elseif iscell(varargin{ii,3})
                  % If it is a cell vector, then get the column number for
                  % each element. Else, if it is a Nx2 cell array with the
                  % required format, the componant uses transformed forcing
                  % data so store the transformation object name and the
                  % required output variable names.
                  if isvector(varargin{ii,3})
                    for j=1:size(varargin{ii,3},1)
                        filt_forcingCols = cellfun(@(x,y)(strcmp(x,varargin{ii,3}{j})), forcingData_colnames);
                        obj.inputData.componentData.(modelComponent).dataColumn(j,1) = find(filt_forcingCols);                                    
                    end
                  elseif size(varargin{ii,3},2) == 2 ...
                  && any(strcmp(varargin{ii,3}(:,1), valid_transformProperties{1})) ...
                  && any(strcmp(varargin{ii,3}(:,1), valid_transformProperties{3}))
                    % Record the transformation model name and required
                    % output forcing data from the transformation model for
                    % input to the model component.
                    filt = strcmp(varargin{ii,3}(:,1), valid_transformProperties{1});
                    obj.inputData.componentData.(modelComponent).forcing_object = varargin{ii,3}{filt,2};
                    filt = strcmp(varargin{ii,3}(:,1), valid_transformProperties{3});
                    obj.inputData.componentData.(modelComponent).outputVariable = varargin{ii,3}{filt,2};
                    
                    % Record the input forcing data columns for the 
                    % transforamtion model if provided. Else, seach the other
                    % transforamtion componants for the forcing data
                    % columns.
                    filt = strcmp(varargin{ii,3}(:,1), valid_transformProperties{2});                    
                    if any(filt)
                        obj.inputData.componentData.(modelComponent).inputForcing = varargin{ii,3}{filt,2};
                    else
                        
                        % Get the name of the source transforamtion
                        % model.
                        filt_transf = strcmp(varargin{ii,3}(:,1), valid_transformProperties{1});
                        sourceTransformModel = varargin{ii,3}(filt_transf,2);

                        % Create a filter for the forcingData property.
                        filt_transf = find(strcmp(varargin(:,2), valid_properties{2}));
                        
                        % Loop through all forcingData inputs to find the
                        % transformationModel that is the source to the
                        % current transformation model.
                        for j=filt_transf'
                           if size(varargin{j,3},2) == 2 ...
                           && iscell(varargin{j,3}) ...        
                           && any(strcmp(varargin{j,3}(:,1), valid_transformProperties{1})) ...
                           && any(strcmp(varargin{j,3}(:,1), valid_transformProperties{2})) ...
                           && any(strcmp(varargin{j,3}(:,1), valid_transformProperties{3})) ...
                           && any(strcmp(varargin{j,3}(:,2), sourceTransformModel))
                               % Get the row containing the input forcing data
                               filt = strcmp(varargin{j,3}(:,1), valid_transformProperties{2});
                               
                               % Assign source forcing names to the current
                               % model component.
                               obj.inputData.componentData.(modelComponent).inputForcing = varargin{j,3}{filt,2};                               
                           end
                        end
                        
                    end
                    
                    % Check that forcing data was identified for the
                    % current component.
                    if ~isfield(obj.inputData.componentData.(modelComponent),'inputForcing')
                        error(['Invalid forcing data for component:', modelComponent,'. No forcing data names or column numbers were input or found by searching for complete transformation models of the same name as input for this component.' ]);
                    end
                    

                    % Subtract '2' from the column numbers (if
                    % not a string). This is done because when
                    % the user inputs the column number the
                    % first three columns are year,month,day.
                    % However, when passed to model_TFN(), the
                    % first three columns are replaced by a
                    % single column of the date number.
                    for j=1:size(obj.inputData.componentData.(modelComponent).inputForcing,1)
                        if isnumeric(obj.inputData.componentData.(modelComponent).inputForcing{j,2})
                            obj.inputData.componentData.(modelComponent).inputForcing{j,2} = ...
                            obj.inputData.componentData.(modelComponent).inputForcing{j,2} - 2;
                        end
                    end
                    
                    % Record indexes to each component with a
                    % transformation model and the type of model.
                    % Additionally, if the transformation model uses inputs
                    % from a transformation model, then also record this data.
                    filt = strcmp(varargin{ii,3}(:,1), valid_transformProperties{5});
                    if any(filt)
                        
                        % Only add an index for the creation the
                        % transformation object if input and output forcing
                        % is defined. If only output is defined, then the 
                        % transforamtion is assumed to be simply calling
                        % a transformation object created for another
                        % component.
                        filt_inputForcing = strcmp(varargin{ii,3}(:,1), valid_transformProperties{2});
                        filt_outputForcing = strcmp(varargin{ii,3}(:,1), valid_transformProperties{3});
                        if any(filt_inputForcing) && any(filt_outputForcing)
                            obj.inputData.componentData.(modelComponent).isForcingModel2BeRun = true;
                            obj.inputData.componentData.(modelComponent).inputForcingComponent = varargin{ii,3}{filt,2};
                            transformFunctionIndexes_inputComponents = [transformFunctionIndexes_inputComponents; ii];
                        else
                            error(['Invalid forcing transformation for component:', modelComponent,'. When a transformation model uses another transformation model as an input then the forcing data and the output variable must be specified.' ]);
                        end
                    else
                        
                        % Only add an index for the creation of the
                        % transformation object if input and output forcing
                        % is defined. If only output is defined, then the 
                        % transforamtion is assumed to be simply calling
                        % a transformation object created for another
                        % component.
                        filt_inputForcing = strcmp(varargin{ii,3}(:,1), valid_transformProperties{2});
                        filt_outputForcing = strcmp(varargin{ii,3}(:,1), valid_transformProperties{3});
                        if any(filt_inputForcing) && any(filt_outputForcing)
                            obj.inputData.componentData.(modelComponent).isForcingModel2BeRun = true;
                            transformFunctionIndexes_noInputComponents = [transformFunctionIndexes_noInputComponents; ii];                            
                        elseif ~any(filt_inputForcing) && any(filt_outputForcing)
                            obj.inputData.componentData.(modelComponent).isForcingModel2BeRun = false;
                        end
                    end
                  else
                    error(['An unexpected error occured for component :', modelComponent,'. The input for "forcingdata" should be either a forcing data site name(s) or number(s) or a cell array for an input transformation model.' ]);
                  end
               else
                  error('The data colum for each model component must be either the column number within the forcing data matrix or a string of the forcing site name.'); 
               end                   
            end
            
            % Check that each component has a forcing column or a forcing 
            % transformation defined.
            modelComponent = unique(varargin(:,1));
            for i=1:length(modelComponent)                
                if ~isfield(obj.inputData.componentData,modelComponent{i})                    
                    error(['The input model options must specify a forcing data column or forcing transformation model for each model components. The following component has no such input:', modelComponent{i}]);                    
                end
            end
            
            % Get a list of rows in varargin defining the weighting
            % function names.
            weightingFunctionIndexes = find(strcmpi(varargin(:,2), valid_properties{1}));
                                   
            % Build the component weighting object for each component that DO NOT require an input weighting function object
            for ii = weightingFunctionIndexes'
            
                modelComponent = varargin{ii,1};
                propertyValue = varargin{ii,3};

                % Check if the current model object requires input of
                % another weighting function object.
                inputWeightingFunctionIndex = find( strcmpi(varargin(:,1),modelComponent) & strcmpi(varargin(:,2),valid_properties{4}));
                
                % Build weighting function for those NOT requiring the
                % input of other weighting function objects.
                if isempty(inputWeightingFunctionIndex)
                    try                       
                        % Get the column number for forcing data
                        colNum = 1;
                        if isfield(obj.inputData.componentData.(modelComponent),'dataColumn')
                            colNum = obj.inputData.componentData.(modelComponent).dataColumn;
                        elseif isfield(obj.inputData.componentData.(modelComponent),'inputForcing')

                            % Get the names (or column numbers) of the input forcing data. 
                            forcingData_inputs = obj.inputData.componentData.(modelComponent).inputForcing(:,2);
                            
                            for j=1:size(forcingData_inputs,1)
                                % Skip if optional forcing input
                                if strcmp(forcingData_inputs{j,1},'(none)')
                                    continue
                                end
                                if isnumeric(forcingData_inputs{j,1})
                                    colNum = [colNum; forcingData_inputs{j,1}];             
                                elseif ischar(forcingData_inputs{j,1})
                                    filt = find(strcmpi(forcingData_colnames, forcingData_inputs{j,1}));
                                    if sum(filt)==0
                                        error(['An unexpected error occured for component :', modelComponent,'. Within the input cell array for "forcingdata", the second column contains a forcing site name that is not listed within the input forcing data column names.' ]);
                                    end
                                    colNum = [colNum; filt];                                
                                else
                                    error(['An unexpected error occured for component :', modelComponent,'. Within the input cell array for "forcingdata", the second column contains a forcing data column number or site name that is listed within the input forcing data column names.' ]);
                                end
                            end
                        end

                        % Check that the response 
                        % function name is consistent with the abstract
                        % 'responseFunction_abstract'.
                        try
                            if ~strcmp(findAbstractName( propertyValue),'responseFunction_abstract')
                                error(['The following response function function class definition is not derived from the "responseFunction_abstract.m" anstract:',propertyValue]);
                            end
                        catch
                            display('... Warning: Checking that the required abstract for the response function transform class definition was used failed. This is may be because the version of matlab is pre-2014a.');
                        end                        

                        % Filter for options.
                        filt = find( strcmpi(varargin(:,1),modelComponent) & strcmpi(varargin(:,2),valid_properties{3}));                       
                        
                        % Call the object 
                        if any(filt)
                            obj.parameters.(modelComponent) = feval(propertyValue, bore_ID, forcingData_colnames(colNum), siteCoordinates, varargin{filt,3} ); 
                        else
                            obj.parameters.(modelComponent) = feval(propertyValue, bore_ID, forcingData_colnames(colNum), siteCoordinates, {}); 
                        end
                    catch exception
                         display(['ERROR: Invalid weighting function class object name: ',char(propertyValue),'. The weighting function object could not be created.']);
                         rethrow(exception);
                    end                            
                end
            end
            
            % Build the component weighting object for each component that DO require an input weighting function object
            for ii = weightingFunctionIndexes'
            
                modelComponent = varargin{ii,1};
                propertyValue = varargin{ii,3};

                % Check if the current model object requires input of
                % another weighting function object.
                inputWeightingFunctionIndex = find( strcmpi(varargin(:,1),modelComponent) & strcmpi(varargin(:,2),valid_properties{4}));
                
                % Build weighting function for those that DO require the
                % input of other weighting function objects.
                if ~isempty(inputWeightingFunctionIndex)
                    
                    % Get the name of the component to be input to the
                    % weighting function.
                    inputWeightingFunctionName = varargin{inputWeightingFunctionIndex,3};                    
                    
                    % Add input component name to input data fields
                    obj.inputData.componentData.(modelComponent).inputWeightingComponent = inputWeightingFunctionName;
                    
                    % Check that the input weighting function has been
                    % created.
                    if ~isfield(obj.parameters,inputWeightingFunctionName)
                        error(['The input component name for component "', modelComponent,'" must be a component that itself is not derived from another componant.' ]);
                    end
                    
                    try
                        % Get the column number for forcing data
                        colNum = 1;
                        if isfield(obj.inputData.componentData.(modelComponent),'dataColumn')
                            colNum = obj.inputData.componentData.(modelComponent).dataColumn;
                        elseif isfield(obj.inputData.componentData.(modelComponent),'inputForcing')

                            % Get the names (or column numbers) of the input forcing data. 
                            forcingData_inputs = obj.inputData.componentData.(modelComponent).inputForcing(:,2);
                            
                            for j=1:size(forcingData_inputs,1)
                                if isnumeric(forcingData_inputs{j,1})
                                    colNum = [colNum; forcingData_inputs{j,1}];             
                                elseif ischar(forcingData_inputs{j,1})
                                    filt = find(strcmpi(forcingData_colnames, forcingData_inputs{j,1}));
                                    if sum(filt)==0
                                        error(['An unexpected error occured for component :', modelComponent,'. Within the input cell array for "forcingdata", the second column contains a forcing site name that is not listed within the input forcing data column names.' ]);
                                    end
                                    colNum = [colNum; filt];                                
                                else
                                    error(['An unexpected error occured for component :', modelComponent,'. Within the input cell array for "forcingdata", the second column contains a forcing data column number or site name that is listed within the input forcing data column names.' ]);
                                end
                            end
                        end                    

                        % Filter for options.
                        filt = find( strcmpi(varargin(:,1),modelComponent) & strcmpi(varargin(:,2),valid_properties{3}));
                        
                        % Call the object. 
                        % NOTE: these objects have an additional input
                        % (compared to those created above) for the input
                        % of a previously build model weighting function
                        % object.
                        obj.parameters.(modelComponent) = feval(propertyValue, bore_ID,forcingData_colnames(colNum), siteCoordinates, obj.parameters.(inputWeightingFunctionName), varargin(filt,3)); 
                    catch exception
                         display(['ERROR: Invalid weighting function class object name: ',char(propertyValue),'. The weighting function object could not be created.']);
                         rethrow(exception);
                    end                            
                end
            end                        

            % Build the objects for forcing transformations that DO NOT
            % require an input weighting function object.            
            for ii = transformFunctionIndexes_noInputComponents'
                
                modelComponent = varargin{ii,1};
                propertyValue = varargin{ii,3};

                % Get the following inputs to build the model object:
                % transformation function name, input data column names,
                % the variables to which the input data is to be assigned
                % too, and additional transformation model options.
                filt = strcmp(varargin{ii,3}(:,1), valid_transformProperties{1});
                transformObject_name = varargin{ii,3}{filt,2};
                filt = strcmp(varargin{ii,3}(:,1), valid_transformProperties{2});
                transformObject_inputs = varargin{ii,3}{filt,2};
                filt = strcmp(varargin{ii,3}(:,1), valid_transformProperties{4});
                if any(filt)
                    transformObject_options = varargin{ii,3}{filt,2};
                else
                    transformObject_options ={};
                end
                
                % Find the required columns in forcing data so that only the
                % required data is input.
                colNum=1;
                rowFilt = true( size(transformObject_inputs,1),1);
                for j=1:size(transformObject_inputs,1)
                    % Skip if optional forcing input
                    if strcmp(transformObject_inputs{j,2},'(none)')
                        rowFilt(j) = false;
                        continue                        
                    end                    
                    if isnumeric(transformObject_inputs{j,2})
                        colNum = [colNum; transformObject_inputs{j,2}-2];                        
                    elseif ischar(transformObject_inputs{j,2})
                        filt = find(strcmpi(forcingData_colnames, transformObject_inputs{j,2}));
                        if sum(filt)==0
                            error(['An unexpected error occured for component :', modelComponent,'. Within the input cell array for "forcingdata", the second column contains a forcing site name that is not listed within the input forcing data column names.' ]);
                        end
                        colNum = [colNum; filt];          
                        
                    else
                        error(['An unexpected error occured for component :', modelComponent,'. Within the input cell array for "forcingdata", the second column contains a forcing data column number or site name that is listed within the input forcing data column names.' ]);
                    end
                    transformObject_inputs{j,2} = j+1;
                end
                
                % Filter transformed object input rows to remove those that
                % are input as options ie '(none)'.
                transformObject_inputs = transformObject_inputs(rowFilt,:);
                
                try
                    colNum_extras = true(length(forcingData_colnames),1);
                    colNum_extras(colNum) = false;
                    colNum_extras = find(colNum_extras);
                    forcingData_colnamesTmp = forcingData_colnames([colNum;colNum_extras]);
                    forcingData_dataTmp = forcingData_data(:,[colNum;colNum_extras]);
                    obj.parameters.(transformObject_name) = feval(transformObject_name, bore_ID, forcingData_dataTmp, forcingData_colnamesTmp, siteCoordinates, transformObject_inputs, transformObject_options);
                                                                                                
                catch exception
                    display(['ERROR: Invalid model component class object for forcing transform: ', transformObject_name ]);
                    rethrow(exception);
                end                     
            end            
                        
            % Build the objects for forcing transformations that DO
            % require an input weighting function object.
            % NOTE: if the component is derived from another componant
            % object, then like the construction of the weighting function
            % object, the forcing for the source component is input in the
            % construction of the forcing transformation. If the source
            % component forcing is also a transformation, then the
            % transformtion object is passed. If not, then the input
            % forcing data is passed.            
            for ii = transformFunctionIndexes_inputComponents'
                
                modelComponent = varargin{ii,1};
                propertyValue = varargin{ii,3};

                % Get the following inputs to build the model object:
                % transformation function name, input data column names,
                % the variables to which the input data is to be assigned
                % too, and additional transformation model options.
                filt = strcmp(varargin{ii,3}(:,1), valid_transformProperties{1});
                transformObject_name = varargin{ii,3}{filt,2};
                filt = strcmp(varargin{ii,3}(:,1), valid_transformProperties{2});
                transformObject_inputs = varargin{ii,3}{filt,2};
                filt = strcmp(varargin{ii,3}(:,1), valid_transformProperties{4});
                if any(filt)
                    transformObject_options = varargin{ii,3}{filt,2};
                else
                    transformObject_options = {};
                end
                filt = strcmp(varargin{ii,3}(:,1), valid_transformProperties{5});
                transformObject_sourceName = varargin{ii,3}{filt,2};
                
%                 % Find the name of the input transformation object for the
%                 % specified input component name.
%                 transformObject_inputComponentName = obj.inputData.componentData.(transformObject_inputComponentName).forcing_object;
                
                % Find the required columns in forcing data so that only the
                % required data is input.
                colNum=1;
                for j=1:size(forcingData_inputs,1)
                    if isnumeric(forcingData_inputs{j,1})
                        colNum = [colNum; forcingData_inputs{j,1}];             
                    elseif ischar(forcingData_inputs{j,1})
                        filt = find(strcmpi(forcingData_colnames, forcingData_inputs{j,1}));
                        if sum(filt)==0
                            error(['An unexpected error occured for component :', modelComponent,'. Within the input cell array for "forcingdata", the second column contains a forcing site name that is not listed within the input forcing data column names.' ]);
                        end
                        colNum = [colNum; filt];                                
                    else
                        error(['An unexpected error occured for component :', modelComponent,'. Within the input cell array for "forcingdata", the second column contains a forcing data column number or site name that is listed within the input forcing data column names.' ]);
                    end
                end
                
                try                
                    colNum_extras = true(length(forcingData_colnames),1);
                    colNum_extras(colNum) = false;
                    colNum_extras = find(colNum_extras);
                    forcingData_colnamesTmp = forcingData_colnames([colNum;colNum_extras]);
                    forcingData_dataTmp = forcingData_data(:,[colNum;colNum_extras]);
                                                                                    
                    obj.parameters.(transformObject_name) = feval(transformObject_name, bore_ID, forcingData_dataTmp, forcingData_colnamesTmp, siteCoordinates, transformObject_inputs, obj.parameters.(transformObject_sourceName), transformObject_options);
                catch exception
                    display(['ERROR: Invalid model component class object for forcing transform: ', transformObject_name ]);
                    rethrow(exception);
                end                     
            end
                        
            % Add noise component
            obj.parameters.noise.type = 'transferfunction';
            obj.parameters.noise.alpha = log10(0.1);    
            
            % Set the parameter names variable.   
            [junk, obj.variables.param_names] = getParameters(obj);            

            % Set variable declarign that calibration is not being
            % undertaken.
            obj.variables.doingCalibration = false;
        end
        
        % Get the observed head
        function head = getObservedHead(obj)
            head = obj.inputData.head;
        end
        
        %% Get the forcing data from the model
        function [forcingData, forcingData_colnames] = getForcingData(obj)
            forcingData = obj.inputData.forcingData;
            forcingData_colnames = obj.inputData.forcingData_colnames;            
        end
        
        %% Set the forcing data from the model
        function setForcingData(obj, forcingData, forcingData_colnames)
            obj.inputData.forcingData = forcingData;
            obj.inputData.forcingData_colnames = forcingData_colnames;
            
            % Update forcing data in the sub-model objects
            if ~isempty(obj.parameters)
                modelnames = fieldnames(obj.parameters);
                for i=1:length(modelnames)
                    if isobject(obj.parameters.(modelnames{i}))
                        try
                            setForcingData(obj.parameters.(modelnames{i}), forcingData, forcingData_colnames)
                        catch
                            % do nothing
                        end
                    end
                end
            end
            
        end        
        
%% Solve the model for the input time points
        function [head, colnames, noise] = solve(obj, time_points)
% solve solves the model for the input time points.
%
% Syntax:
%   [head, colnames, noise] = solve(obj, time_points)
%
% Description:
%   Solves the model using the model parameters and, depending upon
%   the method's inputs, limits the groundwater head to the
%   contribution from various periods of climate forcing and plots the
%   results. The latter is achieved by inputting min and max values for
%   tor but to date is not incorporated into the HydroSight()
%   callign methods.
%
% Input:
%   obj -  model object
%
%   time_points - column vector of the time points to be simulated.
%
% Outputs:
%   head - MxN matrix of simulated head with the following columns: date/time,
%   head, head due to model component i.
%
%   colnames - Nx1 column names for matrix 'head'.
%
%   noise - Mx3 matrix of the estimated upper and lower magnitude of the
%   time-series noise componat at M time steps.
%
% Example:
%   see HydroSight: time_series_model_calibration_and_construction;
%
% See also:
%   HydroSight: time_series_model_calibration_and_construction;
%   model_TFN: model_construction;
%   calibration_finalise: initialisation_of_model_prior_to_calibration;
%   calibration_initialise: initialisation_of_model_prior_to_calibration;
%   get_h_star: main_method_for_calculating_the_head_contributions.
%   getParameters: returns_a_vector_of_parameter_values_and_names;
%   objectiveFunction: returns_a_vector_of_innovation_errors_for_calibration;
%   setParameters: sets_model_parameters_from_input_vector_of_parameter_values;
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure
%   Engineering, The University of Melbourne.
%
% Date:
%   26 Sept 2014

            % Check that the model has first been calibrated.
            if ~isfield(obj.variables, 'd')
                error('The model does not appear to have first been calibrated. Please calibrate the model before running a simulation.');
            end
                        
            % Clear obj.variables of temporary variables.
            if isfield(obj.variables, 'theta_est_indexes_min'), obj.variables = rmfield(obj.variables, 'theta_est_indexes_min'); end
            if isfield(obj.variables, 'theta_est_indexes_max'), obj.variables = rmfield(obj.variables, 'theta_est_indexes_max'); end
            if isfield(obj.variables, 'SMS_frac'), obj.variables = rmfield(obj.variables, 'SMS_frac'); end            
            if isfield(obj.variables, 'recharge'), obj.variables = rmfield(obj.variables, 'recharge'); end            
            if isfield(obj.variables, 'SMSC'), obj.variables = rmfield(obj.variables, 'SMSC'); end            
            if isfield(obj.variables, 'SMSC_1'), obj.variables = rmfield(obj.variables, 'SMSC_1'); end            
            if isfield(obj.variables, 'SMSC_2'), obj.variables = rmfield(obj.variables, 'SMSC_2'); end            
            if isfield(obj.variables, 'f'), obj.variables = rmfield(obj.variables, 'f'); end            
            if isfield(obj.variables, 'b'), obj.variables = rmfield(obj.variables, 'b'); end                                    
            if isfield(obj.variables, 'ksat'), obj.variables = rmfield(obj.variables, 'ksat'); end
            if isfield(obj.variables, 'ksat_1'), obj.variables = rmfield(obj.variables, 'ksat_1'); end
            if isfield(obj.variables, 'ksat_2'), obj.variables = rmfield(obj.variables, 'ksat_2'); end
            
            % Set a flag to indicate that calibration is NOT being undertaken.
            % obj.variables.doingCalibration = getInnovations;
            
            % Setup matrix of indexes for tor at each time_points
            filt = obj.inputData.forcingData ( : ,1) <= ceil(time_points(end));
            tor = flipud([0:time_points(end)  - obj.inputData.forcingData(filt,1)+1]');
            ntor =  size( tor, 1);                                                     
            clear tor;            
            
            obj.variables.theta_est_indexes_min = zeros(1,length(time_points) );
            obj.variables.theta_est_indexes_max = zeros(1,length(time_points) );
                        
            for ii= 1:length(time_points)              
                ntheta = sum( obj.inputData.forcingData ( : ,1) <= time_points(ii) );                                
                obj.variables.theta_est_indexes_min(ii) = ntor-ntheta;
                obj.variables.theta_est_indexes_max(ii) = max(1,ntor);
            end  
            
            % Free memory within mex function (just in case there'se been a
            % prior calibration that crashed prior to clearing the MEX
            % sttaic variables)
            % Free memory within mex function
            try
                junk=doIRFconvolutionPhi([], [], [], [], false, 0);            
            catch ME
                % continue               
            end          
            
            % Get the parameter sets (for use in resetting if >sets)
            [params, param_names] = getParameters(obj);
            
            % If the number of parameter sets is >1 then temporarily apply 
            % only the first parameter set. This is done only to reduce the
            % RAM requirements for the broadcasting of the obj variable in
            % the following parfor.
            if size(params,2)>1
                setParameters(obj, params(:,1), param_names);
            end
            
            % Set percentile for noise 
            Pnoise = 0.95;
            
            % Solve the modle using each parameter set.
            obj.variables.delta_time = diff(time_points);
            headtmp=cell(1,size(params,2));
            noisetmp=cell(1,size(params,2));
            companants = fieldnames(obj.inputData.componentData);
            nCompanants = size(companants,1);                             
            for ii=1:size(params,2)
                % Get the calibration estimate of the mean forcing for the
                % current parameter set. This is a bit of a work around to
                % handle the issue of each parameter set having a unique
                % mean forcing (if a forcing transform is undertaken). The
                % workaround was required when DREAM was addded.
                for j=1:nCompanants                    
                    calibData(ii,1).mean_forcing.(companants{j}) = obj.variables.(companants{j}).forcingMean(:,ii);
                end                
                              
                % Add drainage elevation to the varargin variable sent to
                % objectiveFunction.                
                calibData(ii,1).drainage_elevation = obj.variables.d(ii);
                
                % Add noise std dev
                if isfield(obj.variables,'sigma_n');
                    calibData(ii,1).sigma_n = obj.variables.sigma_n(ii);
                else
                    calibData(ii,1).sigma_n = 0;
                end
                
            end
            
            % Solve model and add drainage constants
            [~, headtmp{1}, colnames] = objectiveFunction(params(:,1), time_points, obj, calibData(1));                        
            if size(params,2)>1
                parfor jj=2:size(params,2)
                    [~, headtmp{jj}] = objectiveFunction(params(:,jj), time_points, obj, calibData(jj));                        
                end              
            end
            
            % Add drainage constants and calculate total error bounds.
            for ii=1:size(params,2)
                headtmp{ii}(:,2) = headtmp{ii}(:,2) + calibData(ii).drainage_elevation;
            
                noisetmp{ii} = [headtmp{ii}(:,1), ones(size(headtmp{ii},1),2) .* norminv(Pnoise,0,1) .* calibData(ii).sigma_n];
            end                            
            head = zeros(size(headtmp{1},1),size(headtmp{1},2), size(params,2));
            noise = zeros(size(headtmp{1},1),3, size(params,2));            
            for ii=1:size(params,2)
                head(:,:,ii) = headtmp{ii};
                noise(:,:,ii) = noisetmp{ii};
            end
            %colnames = colnames{1};
            clear headtmp noisetmp
                             
            % Set the parameters if >1 parameter sets
            if size(params,2)>1
                setParameters(obj,params, param_names);
            end
            
            % Clear matrix of indexes for tor at each time_points
            obj.variables = rmfield(obj.variables, 'theta_est_indexes_min');
            obj.variables = rmfield(obj.variables, 'theta_est_indexes_max');
            
        end
        
%% Initialise the model prior to calibration.
        function [params_initial, time_points] = calibration_initialise(obj, t_start, t_end)
% calibration_initialise initialises the model prior to calibration.
%
% Syntax:
%   [params_initial, time_points] = calibration_initialise(obj, t_start, t_end)
%
% Description:
%   Sets up model variables required for calibration. Most imporantly, it
%   calculates the mean observed head, h_bar, and row indexes, 
%   theta_est_indexes,  for efficient calculation of the response
%   functions. The calibration also requires the method to return a column 
%   vector of the initial parameters and a column vector of time points for
%   which observation data exists.
%
% Input:
%   obj -  model object
%
%   t_start - scaler start time, eg datenum(1995,1,1);
%
%   t_end - scaler end time, eg datenum(2005,1,1);
%
% Outputs:
%   params_initial - column vector of the initial parameters.
%
%   time_points - column vector of time points forwhich observation data
%   exists.
%
% Example:
%   see HydroSight: time_series_model_calibration_and_construction;
%
% See also:
%   HydroSight: time_series_model_calibration_and_construction;
%   model_TFN: model_construction;
%   calibration_finalise: initialisation_of_model_prior_to_calibration;
%   get_h_star: main_method_for_calculating_the_head_contributions.
%   getParameters: returns_a_vector_of_parameter_values_and_names;
%   objectiveFunction: returns_a_vector_of_innovation_errors_for_calibration;
%   setParameters: sets_model_parameters_from_input_vector_of_parameter_values;
%   solve: solve_the_model_at_user_input_sime_points;
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure
%   Engineering, The University of Melbourne.
%
% Date:
%   26 Sept 2014

            % clear old variables
            obj.variables = [];

            % Set a flag to indicate that calibration is being undertaken.
            obj.variables.doingCalibration = true;
            
            % Free memory within mex function (just in case there'se been a
            % prior calibration that crashed prior to clearing the MEX
            % sttaic variables)
            % Free memory within mex function
            try
                junk=doIRFconvolutionPhi([], [], [], [], false, 0);            
            catch ME
                % continue               
            end            
            
            % Get parameter names and initial values
            [params_initial, obj.variables.param_names] = getParameters(obj);
            
            % Extract time steps
            t_filt = find( obj.inputData.head(:,1) >=t_start  ...
                & obj.inputData.head(:,1) <= t_end );   
            time_points = obj.inputData.head(t_filt,1);
            obj.variables.time_points = time_points;
            
            % Set initial time for trend term
            obj.variables.trend_startTime = obj.variables.time_points(1);
            
            % Calc time step sizes. 
            obj.variables.delta_time = diff( obj.variables.time_points  );
            
            % Calcaulte mean head.
            obj.variables.h_bar = mean(obj.inputData.head( t_filt,2 ));                            
            
            % Setup matrix of indexes for tor at each time_points
            filt = obj.inputData.forcingData ( : ,1) <= ceil(time_points(end));
            tor = flipud([0:time_points(end)  - obj.inputData.forcingData(filt,1)+1]');
            ntor =  size(tor, 1);                                                     
            clear tor;
            
            obj.variables.theta_est_indexes_min = zeros(1,length(time_points) );
            obj.variables.theta_est_indexes_max = zeros(1,length(time_points) );
                        
            for ii= 1:length(time_points)              
                ntheta = sum( obj.inputData.forcingData ( : ,1) <= time_points(ii) );                                
                obj.variables.theta_est_indexes_min(ii) = ntor-ntheta;
                obj.variables.theta_est_indexes_max(ii) = max(1,ntor);
            end  

            obj.variables.nobjectiveFunction_calls=0;
            
        end        
        
%% Finalise the model following calibration.
        function calibration_finalise(obj, params, useLikelihood)            
% calibration_finalise finalises the model following calibration.
%
% Syntax:
%   calibration_finalise(obj, params)   
%
% Description:
%   Finalises the model following calibration and assigns the final 
%   parameters and additional variables to the object for later simulation. 
%   Of the variables calculated, the most essential for the model 
%   is the scalar drainage, obj.variables.d. Other variables that are also 
%   important include: 
%       - a vector of innovations,  obj.variables.innov, for detection 
%         of serial correlation in the model errors; 
%       - the noise standard deviation, obj.variables.sigma_n.
%
% Input:
%   obj -  model object
%
%   params - column vector of the optima parameters derived from
%   calibration.
%
% Outputs:
%   (none, the results are output to obj.variables)
%
% Example:
%   see HydroSight: time_series_model_calibration_and_construction;
%
% See also:
%   HydroSight: time_series_model_calibration_and_construction;
%   model_TFN: model_construction;
%   calibration_initialise: initialisation_of_model_prior_to_calibration;
%   get_h_star: main_method_for_calculating_the_head_contributions.
%   getParameters: returns_a_vector_of_parameter_values_and_names;
%   objectiveFunction: returns_a_vector_of_innovation_errors_for_calibration;
%   setParameters: sets_model_parameters_from_input_vector_of_parameter_values;
%   solve: solve_the_model_at_user_input_sime_points;
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure
%   Engineering, The University of Melbourne.
%
% Date:
%   26 Sept 2014            
            for j=1:size(params,2)
                % Re-calc objective function and deterministic component of the head and innocations.
                % Importantly, the drainage elevation (ie the constant term for
                % the regression) is calculated within 'objectiveFunction' and
                % assigned to the object. When the calibrated model is solved
                % for a different time period (or climate data) then this
                % drainage value will be used by 'objectiveFunction'.
                try
                    [obj.variables.objFn(:,j), h_star, ~ , obj.variables.d(j)] = objectiveFunction(params(:,j), obj.variables.time_points, obj,useLikelihood);                        
                catch ME
                    if size(params,2)>1
                        continue
                    else
                        error('Model crashed -  this may be due to the parameter values.');
                    end
                end

                % Calculate the mean forcing rates. These mean rates are used
                % to calculate the contribution from the tail of the theta
                % weighting beyond the last observation. That is, the theta
                % function is integrated from the last time point of the
                % forcing to negative infinity. This integral is then
                % multiplied by the mean forcing rate. To ensure future
                % simulations use an identical mean forcing rate, the means are
                % calculated here and used in all future simulations.
                companants = fieldnames(obj.inputData.componentData);
                nCompanants = size(companants,1);
                for i=1:nCompanants
                    obj.variables.(companants{i}).forcingMean(:,j) = mean(obj.variables.(companants{i}).forcingData)';
                end

                t_filt = find( obj.inputData.head(:,1) >=obj.variables.time_points(1)  ...
                    & obj.inputData.head(:,1) <= obj.variables.time_points(end) );               
                obj.variables.resid(:,j) = obj.inputData.head(t_filt,2)  -  (h_star(:,2) + obj.variables.d(j));

                % Calculate mean of noise. This should be zero +- eps()
                % because the drainage value is approximated assuming n-bar = 0.
                obj.variables.n_bar(j) = real(mean( obj.variables.resid(:,j) ));

                % Calculate drainage level.
                %obj.variables.d = obj.variables.h_bar - mean(real(obj.variables.h_star(:,2))) - obj.variables.n_bar;

                % Calculate noise standard deviation.
                obj.variables.sigma_n(j) = sqrt(mean( obj.variables.resid(1:end-1,j).^2 ./ (1 - exp( -2 .* 10.^obj.parameters.noise.alpha .* obj.variables.delta_time ))));
            end
            
            % Set a flag to indicate that calibration is complete.
            obj.variables.doingCalibration = false;
            
            % Set model parameters (if params are multiple sets)
            if size(params,2)>1
                setParameters(obj, params, obj.variables.param_names);            
            end
            
            % Free memory within mex function
            try
                junk=doIRFconvolutionPhi([], [], [], [], false, 0);            
            catch ME
                % continue               
            end
        end        

%% Calculate objective function vector. 
        function [objFn, h_star, colnames, drainage_elevation] = objectiveFunction(params, time_points, obj, varargin)
% objectiveFunction calculates the objective function vector. 
%
% Syntax:
%   [objFn, h_star, colnames, drainage_elevation] = objectiveFunction(params,time_points, obj)
%
% Description:
%   Solves the model for the input parameters and calculates the objective
%   function vector. Importantly, the objective function vector is not
%   simply the difference between the observed and modelled heads. Because
%   the model uses a noise model, the residual between the observed 
%   and modelled head is first derived and then the innovation
%   is calculated as the prior residual minus the later residual multiplied
%   by the exponental noise function. Finally, the objective function
%   weights this vector according to the time-step between observations.
%
%   Imporantly, the numerator of the weighting equation from von Asmuth et al 2002
%   rounds to zero when the number of samples is very large. This occurs
%   because it is effecively a geometric mean and its product term for n
%   (where n is the number of observation for calibration minus 1) rounds
%   to zero as a result of machine precision. This was overcome by adoption
%   of a restructuring of the geometric meazn in term of exp and log terms. 
%
% Inputs:
%   params - column vector of the optima parameters derived from
%   calibration.
%
%   time_points - column vector of the time points to be simulated.  
%
%   obj -  model object
%
% Outputs:
%   objFn - scalar objective function value.
%
%   h_star - matrix of the contribution from various model components and
%   their summed influence. The matrix columns are in the order of:
%   date/time, summed contribution to the head, contribution from
%   component i.
%
%   colnames - column names for matrix 'head'.
%
%   drainage_elevation - drainage elevation constant.
%
% Example:
%   see HydroSight: time_series_model_calibration_and_construction;
%
% See also:
%   HydroSight: time_series_model_calibration_and_construction;
%   model_TFN: model_construction;
%   calibration_finalise: initialisation_of_model_prior_to_calibration;
%   calibration_initialise: initialisation_of_model_prior_to_calibration;
%   get_h_star: main_method_for_calculating_the_head_contributions.
%   getParameters: returns_a_vector_of_parameter_values_and_names;
%   setParameters: sets_model_parameters_from_input_vector_of_parameter_values;
%   solve: solve_the_model_at_user_input_sime_points;
%
% References:
%   von Asmuth J. R., Bierkens M. F. P., Mass K., 2002, Transfer
%   dunction-noise modeling in continuous time using predefined impulse
%   response functions.
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure
%   Engineering, The University of Melbourne.
%
% Date:
%   26 Sept 2014    
            
            % Set model parameters
            setParameters(obj, params, obj.variables.param_names);
            
            % If varargin is a structural variable then the model
            % simulation is to use predefined values of the drainage
            % elevation and the mean forcing. Note, these inputs are only
            % to be provided if not doing simulation.
            getLikelihood = false;
            drainage_elevation=[];
            mean_forcing=[];
            if ~isempty(varargin)
                if isstruct(varargin{1})
                    drainage_elevation=varargin{1}.drainage_elevation;
                    mean_forcing=varargin{1}.mean_forcing;
                elseif islogical(varargin{1})
                    getLikelihood=varargin{1};
                else
                    error('The input varargin must be either a logical or a structural variable.');
                end
            end
            
            % Calc deterministic component of the head.
            if isempty(mean_forcing)
                [h_star, colnames] = get_h_star(obj, time_points);                 
            else
                [h_star, colnames] = get_h_star(obj, time_points,mean_forcing);                 
            end
            
            % Return of there are nan or inf value
            if any(isnan(h_star(:,2)) | isinf(h_star(:,2)));
                objFn = nan(size(h_star,1)-1,1);
                return;
            end
                            
            % If the results from this method call are not to be used for
            % summarising calibration results, then exit here. This is
            % required because the innovations can only be calculated at
            % time points for which there are observations. 
            if ~obj.variables.doingCalibration
                objFn = [];
                return;
            end
            
            % Calculate residual between observed and modelled.
            % Importantly, an approximation of the drainage level,d, is
            % required here to calculate the residuals. To achieve this
            % requires an assumption that the mean noise, n_bar, equals
            % zero. If this is not the case, then d_bar calculated below
            % may differ from d calculated within 'calibration_finalise'.
            t_filt = find( obj.inputData.head(:,1) >=time_points(1)  ...
                & obj.inputData.head(:,1) <= time_points(end) );          
            if isempty(drainage_elevation)
                drainage_elevation = obj.variables.h_bar - mean(h_star(:,2));      
            end
            resid= obj.inputData.head(t_filt,2)  - (h_star(:,2) +  drainage_elevation);                 
            
            % Calculate innovations using residuals from the deterministic components.            
            innov = resid(2:end) - resid(1:end-1).*exp( -10.^obj.parameters.noise.alpha .* obj.variables.delta_time );
            
            % Calculate objective function
            objFn = sum( exp(mean(log( 1- exp( -2.*10.^obj.parameters.noise.alpha .* obj.variables.delta_time) ))) ...
                    ./(1- exp( -2.*10.^obj.parameters.noise.alpha .* obj.variables.delta_time )) .* innov.^2);
  

            % Calculate log liklihood    
            if getLikelihood
                N = size(resid,1);
                objFn = -0.5 * N * ( log(2*pi) + log(objFn./N)+1); 
            end
            % Increment count of function calls
            obj.variables.nobjectiveFunction_calls = obj.variables.nobjectiveFunction_calls +  size(params,2);
            
        end
           
%% Set the model parameters to the model object from a vector.
        function setParameters(obj, params, param_names)
% setParameters set the model parameters to the model object from a vector.
%
% Syntax:
%   setParameters(obj, params, param_names)
%
% Description:
%   Assigns a vector of parameter values to the model object using the
%   input component and parameter names. This method is predominately used
%   by the model calibration.
%
% Input:
%   obj -  model object
%
%   params - column vector of the parameter values.
%
%   param_names - two column n-row (for n parameters) cell matrix of
%   compnant name (column 1) and parameter name (column 2).
%
% Outputs:
%   params_initial - column vector of the initial parameters.
%
%   time_points - column vector of time points forwhich observation data
%   exists.
%
% Example:
%   see HydroSight: time_series_model_calibration_and_construction;
%
% See also:
%   HydroSight: time_series_model_calibration_and_construction;
%   model_TFN: model_construction;
%   calibration_finalise: initialisation_of_model_prior_to_calibration;
%   calibration_initialise: initialisation_of_model_prior_to_calibration;
%   get_h_star: main_method_for_calculating_the_head_contributions.
%   getParameters: returns_a_vector_of_parameter_values_and_names;
%   objectiveFunction: returns_a_vector_of_innovation_errors_for_calibration;  
%   solve: solve_the_model_at_user_input_sime_points;
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure
%   Engineering, The University of Melbourne.
%
% Date:
%   26 Sept 2014            
            
            % Get unique component names and count the number of parameters
            % for this component.
            nCompanants = 1;
            companants{nCompanants ,1} =  param_names{1,1};
            companants{nCompanants ,2} = 1;
            if size(param_names,1) >1
                for ii=2: size(param_names,1)
                    if ~strcmp( param_names{ii,1} , param_names{ii-1,1} )
                        nCompanants  = nCompanants +1;
                        companants{nCompanants ,1} =  param_names{ii,1};
                        companants{nCompanants ,2} =  1;
                    elseif ~strcmp( param_names{ii,2} , 'type' )
                        companants{nCompanants ,2} =  companants{nCompanants ,2} + 1;
                    end
                end
            end
                        
            params_index=0;
            for ii=1: size(companants,1)
                currentField = char( companants{ii,1} ) ;
                
                % Get parameter names for this component
                if isobject( obj.parameters.( currentField ) )
                    [param_values, companant_params] = getParameters(obj.parameters.( currentField ));
                    clear param_values;
                else
                     companant_params = fieldnames( obj.parameters.( currentField ) ) ;
                end

                % Scan though and remove those that are called 'type'
                param_index = 1:size(companant_params,1) ;
                for j = 1: size(companant_params,1)
                    if strcmp( companant_params{j}, 'type') || strcmp( companant_params{j}, 'variables')
                        param_index(j)=0;
                    end
                end
                companant_params = companant_params(param_index>0);
                
                % Check all parameters for this component are to be set
                % with new valeus.
                if companants{ii ,2} ~= size(companant_params,1)
                    error(['The number of parameters to be set for the following model', ...
                    'component must equal the total number of parameters for the component: ,',currentField]);
                end
                
                % Get input parameter values for this component.
                component_param_vals = zeros(size(companant_params,1),size(params,2));
                for j=1: size(companant_params,1)
                    params_index = params_index + 1;
                    component_param_vals(j,:) =  params(params_index,:);
                end
                
                % Get model parameters for each componant.
                % If the componant is an object, then call the objects
                % getParameters method.
                if isobject( obj.parameters.( currentField ) )                    
                    % Call object method to set parameter values.
                    setParameters( obj.parameters.( currentField ), component_param_vals );                   
                else
                    % Non-object componant.
                    for j=1:size(companant_params,1)               
                        obj.parameters.( currentField ).( char(companant_params{j}) ) = component_param_vals(j,:);
                    end 
                end
            end
            
            
        end
        
%% Returns the model parameters from the model object.
        function [params, param_names] = getParameters(obj)
% getParameters returns the model parameters from the model object.
%
% Syntax:
%   [params, param_names] = getParameters(obj)
%
% Description:
%   Cycles through all model components and parameters and returns a vector
%   of parameter values and a cell matrix of their espective componant
%   and parameter names.
%
% Input:
%   obj -  model object.
%
% Outputs:
%   params - column vector of the parameter values.
%
%   param_names - two column n-row (for n parameters) cell matrix of
%   compnant name (column 1) and parameter name (column 2).
%
% Example:
%   see HydroSight: time_series_model_calibration_and_construction;
%
% See also:
%   HydroSight: time_series_model_calibration_and_construction;
%   model_TFN: model_construction;
%   calibration_finalise: initialisation_of_model_prior_to_calibration;
%   calibration_initialise: initialisation_of_model_prior_to_calibration;
%   get_h_star: main_method_for_calculating_the_head_contributions.
%   objectiveFunction: returns_a_vector_of_innovation_errors_for_calibration;  
%   setParameters: sets_model_parameters_from_input_vector_of_parameter_values;
%   solve: solve_the_model_at_user_input_sime_points;
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure
%   Engineering, The University of Melbourne.
%
% Date:
%   26 Sept 2014            
            
            param_names = {};
            params = [];
            nparams=0;
            % Get model componants
            companants = fieldnames(obj.parameters);
            
            for ii=1: size(companants,1)
                currentField = char( companants(ii) ) ;
                % Get model parameters for each componant.
                % If the componant is an object, then call the objects
                % getParameters method.
                if isobject( obj.parameters.( currentField ) )
                    % Call object method.
                    [params_temp, param_names_temp] = getParameters( obj.parameters.( currentField ) );
                    
                    for j=1: size(param_names_temp,1)
                        nparams = nparams + 1;
                        param_names{ nparams , 1} = currentField;
                        param_names{ nparams , 2} = param_names_temp{j};
                        params( nparams,: ) = params_temp(j,:);                        
                    end
                    
                else
                    % Non-object componant.
                    companant_params = fieldnames( obj.parameters.( currentField ) );
                    for j=1: size(companant_params,1)
                       if ~strcmp( companant_params(j), 'type')
                          nparams = nparams + 1;
                          param_names{nparams,1} =  currentField;
                          param_names{nparams,2} =  char(companant_params(j));
                          params(nparams,:) = obj.parameters.( currentField ).( char(companant_params(j)) );
                       end
                    end
                end
            end
        end
        
        
%% Returns the model parameters from the model object.
        function [params, param_names] = getDerivedParameters(obj)
% getDerivedParameters returns the derived parameters from the model object.
%
% Syntax:
%   [params, param_names] = getDerivedParameters(obj)
%
% Description:
%   Cycles through all model componants and parameters and returns a vector
%   of derived parameter values and a cell matrix of their respective componant
%   and parameter names. The derived parameters are calibrated parameters
%   or constants in the componants but variables derived from the
%   calibrated parameters. For example, the drawdown response function
%   (e.g. responseFunction_FerrisKnowles) can calculate the T and S from
%   the calibrated parameters.
%
% Input:
%   obj -  model object.
%
% Outputs:
%   params - column vector of the parameter values.
%
%   param_names - two column n-row (for n parameters) cell matrix of
%   compnant name (column 1) and parameter name (column 2).
%
% Example:
%   see HydroSight: time_series_model_calibration_and_construction;
%
% See also:
%   HydroSight: time_series_model_calibration_and_construction;
%   model_TFN: model_construction;
%   calibration_finalise: initialisation_of_model_prior_to_calibration;
%   calibration_initialise: initialisation_of_model_prior_to_calibration;
%   get_h_star: main_method_for_calculating_the_head_contributions.
%   objectiveFunction: returns_a_vector_of_innovation_errors_for_calibration;  
%   setParameters: sets_model_parameters_from_input_vector_of_parameter_values;
%   solve: solve_the_model_at_user_input_sime_points;
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure
%   Engineering, The University of Melbourne.
%
% Date:
%   26 Sept 2014            
            
            param_names = {};
            params = [];
            nparams=0;
            % Get model componants
            companants = fieldnames(obj.parameters);
            
            for ii=1: size(companants,1)
                currentField = char( companants(ii) ) ;
                % Get model parameters for each componant.
                % If the componant is an object, then call the objects
                % getParameters method.
                if isobject( obj.parameters.( currentField ) )
                    % Call object method.
                    [params_temp, param_names_temp] = getDerivedParameters( obj.parameters.( currentField ) );
                    
                    for j=1: size(param_names_temp,1)
                        nparams = nparams + 1;
                        param_names{ nparams , 1} = currentField;
                        param_names{ nparams , 2} = param_names_temp{j};
                        params( nparams,: ) = params_temp(j,:);                        
                    end
                end
            end
        end
                
        
        function [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj)
% getParameters_physicalLimit returns the physical limits to each model parameter.
%
% Syntax:
%   [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj)
%
% Description:
%   Cycles through all model componants and parameters and returns a vector
%   of the physical upper and lower parameter bounds as defined by the
%   weighting functions.
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
%   HydroSight: time_series_model_calibration_and_construction;
%   model_TFN: model_construction;
%   calibration_finalise: initialisation_of_model_prior_to_calibration;
%   calibration_initialise: initialisation_of_model_prior_to_calibration;
%   get_h_star: main_method_for_calculating_the_head_contributions.
%   objectiveFunction: returns_a_vector_of_innovation_errors_for_calibration;  
%   setParameters: sets_model_parameters_from_input_vector_of_parameter_values;
%   solve: solve_the_model_at_user_input_sime_points;
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure
%   Engineering, The University of Melbourne.
%
% Date:
%   26 Sept 2014   

            params_lowerLimit = [];
            params_upperLimit = [];
            companants = fieldnames(obj.parameters);            
            for ii=1: size(companants,1)
                currentField = char( companants(ii) ) ;
                % Get model parameters for each componant.
                % If the componant is an object, then call the objects
                % getParameters_physicalLimit method for each parameter.
                if isobject( obj.parameters.( currentField ) )
                    % Call object method.
                    [params_upperLimit_temp, params_lowerLimit_temp] = getParameters_physicalLimit( obj.parameters.( currentField ) );                
                    
                    params_upperLimit = [params_upperLimit; params_upperLimit_temp];
                    params_lowerLimit = [params_lowerLimit; params_lowerLimit_temp];
                                        
                else

                    [params_plausibleUpperLimit, params_plausibleLowerLimit] = getParameters_plausibleLimit(obj);
                    
                    % This parameter is assumed to be the noise parameter 'alpha'.  
                    ind = length(params_upperLimit)+1;
                    params_upperLimit = [params_upperLimit; params_plausibleUpperLimit(ind)];                                                        
                    params_lowerLimit = [params_lowerLimit; params_plausibleLowerLimit(ind)];                                
                end
            end            
        end        
        
    function [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(obj)
% getParameters_plausibleLimit returns the plausible limits to each model parameter.
%
% Syntax:
%   [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(obj)
%
% Description:
%   Cycles though all model componants and parameters and returns a vector
%   of the plausible upper and lower parameter range as defined by the
%   weighting functions.
%
% Input:
%   obj -  model object.
%
% Outputs:
%   params_upperLimit - column vector of the upper parameter plausible bounds.
%
%   params_lowerLimit - column vector of the lower parameter plausible bounds
%
% Example:
%   see HydroSight: time_series_model_calibration_and_construction;
%
% See also:
%   HydroSight: time_series_model_calibration_and_construction;
%   model_TFN: model_construction;
%   calibration_finalise: initialisation_of_model_prior_to_calibration;
%   calibration_initialise: initialisation_of_model_prior_to_calibration;
%   get_h_star: main_method_for_calculating_the_head_contributions.
%   objectiveFunction: returns_a_vector_of_innovation_errors_for_calibration;  
%   setParameters: sets_model_parameters_from_input_vector_of_parameter_values;
%   solve: solve_the_model_at_user_input_sime_points;
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure
%   Engineering, The University of Melbourne.
%
% Date:
%   26 Sept 2014   
                        
        params_lowerLimit = [];
        params_upperLimit = [];
        companants = fieldnames(obj.parameters);            
        for ii=1: size(companants,1)
            currentField = char( companants(ii) ) ;
            % Get model parameters for each componant.
            % If the componant is an object, then call the objects
            % getParameters_physicalLimit method for each parameter.
            if isobject( obj.parameters.( currentField ) )
                % Call object method.
                [params_upperLimit_temp, params_lowerLimit_temp] = getParameters_plausibleLimit( obj.parameters.( currentField ) );

                params_upperLimit = [params_upperLimit; params_upperLimit_temp];
                params_lowerLimit = [params_lowerLimit; params_lowerLimit_temp];
            else
                companant_params = fieldnames( obj.parameters.( currentField ) );
                for j=1: size(companant_params,1)
                   if ~strcmp( companant_params(j), 'type')
                       if strcmp(currentField,'et') && strcmp( companant_params(j), 'k')
                            % This parameter is assumed to be the ET
                            % parameter scaling when the ET
                            % uses the precipitation transformation
                            % function.
                            params_upperLimit = [params_upperLimit; 1];
                            params_lowerLimit = [params_lowerLimit; 0];
                       elseif strcmp(currentField,'landchange') && (strcmp( companant_params(j), 'precip_scalar') ...
                       || strcmp(currentField,'landchange') && strcmp( companant_params(j), 'et_scalar'))  
                           % This parameter is the scaling parameter
                           % for either the ET or precip transformation
                           % functions.
                           params_upperLimit = [params_upperLimit; 1.0];
                           params_lowerLimit = [params_lowerLimit; -1.0];
                       else
                            % This parameter is assumed to be the noise parameter 'alpha'.  
                            alpha_upperLimit = 100; 
                            while abs(sum( exp( -2.*alpha_upperLimit .* obj.variables.delta_time ) )) < eps() ...
                            || exp(mean(log( 1- exp( -2.*alpha_upperLimit .* obj.variables.delta_time) ))) < eps()
                                alpha_upperLimit = alpha_upperLimit - 0.01;
                                if alpha_upperLimit <= eps()                                   
                                    break;
                                end
                            end
                            if alpha_upperLimit <= eps()
                                alpha_upperLimit = inf;
                            else
                                % Transform alpha log10 space.
                                alpha_upperLimit = log10(alpha_upperLimit);
                            end                           
                            
                            params_upperLimit = [params_upperLimit; alpha_upperLimit];
                            params_lowerLimit = [params_lowerLimit; log10(sqrt(eps()))+4];

                       end
                   end
                end
            end
        end
    end 
        
    function isValidParameter = getParameterValidity(obj, params, time_points)
% isValidParameter returns a logical vector for the validity or each parameter.
%
% Syntax:
%   isValidParameter = getParameterValidity(obj, params, time_points)
%
% Description:
%   Cycles though all model components and parameters and returns a logical 
%   vector denoting if each parameter is valid as defined by each weighting
%   function.
%
% Input:
%   obj -  model object.
%
%   params - vector of model parameters
%
%   time_points - vector of simulation time points
%
% Outputs:
%   isValidParameter - column vector of the parameter validity.
%
% Example:
%   see HydroSight: time_series_model_calibration_and_construction;
%
% See also:
%   HydroSight: time_series_model_calibration_and_construction;
%   model_TFN: model_construction;
%   calibration_finalise: initialisation_of_model_prior_to_calibration;
%   calibration_initialise: initialisation_of_model_prior_to_calibration;
%   get_h_star: main_method_for_calculating_the_head_contributions.
%   objectiveFunction: returns_a_vector_of_innovation_errors_for_calibration;  
%   setParameters: sets_model_parameters_from_input_vector_of_parameter_values;
%   solve: solve_the_model_at_user_input_sime_points;
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure
%   Engineering, The University of Melbourne.
%
% Date:
%   26 Sept 2014   
          
        
        isValidParameter = true(size(params));
        companants = fieldnames(obj.parameters);            
        
        [junk, param_names] = getParameters(obj);
        
        for ii=1: size(companants,1)
            currentField = char( companants(ii) ) ;
            
            % Find parameters for the component
            filt = strcmp(companants(ii), param_names(:,1));

            % Get model parameters for each componant.
            % If the componant is an object, then call the objects
            % getParameterValidity method for each parameter.
            if isobject( obj.parameters.( currentField ) )
                
                
                % Call object method and pass it the parameter vector and
                % parameter names.
                % NOTE: the parameters are not set within the componant
                % object. This was done to avoid a call to
                % setParameters().
                isValidParameter(filt,:) = getParameterValidity( obj.parameters.( currentField ), params(filt,:), param_names(filt,2) );
             
            % Check the alphanoise parameter is large enough not to cause numerical
            % problems in the calcuation of the objective function.
            elseif strcmp('noise',currentField);                
                alpha = params(filt,:); 
                filt_noiseErr = exp(mean(log( 1- exp( bsxfun(@times,-2.*10.^alpha , obj.variables.delta_time) )),1)) <= eps() ...
                             | abs(sum( exp( bsxfun(@times,-2.*10.^alpha , obj.variables.delta_time) ),1)) < eps();                
                isValidParameter(filt,filt_noiseErr)= false;                
                
            else
                isValidParameter(filt,:) = true;
            end
            
            % Break if any parameter sets are invalid!
            if size(params,2)==1 && any(any(~isValidParameter));
                return;
            end
        end
    end
    
    function plot_transferfunctions(obj, t_max)
% plot_transferfunctions plot the weighting functions
%
% Syntax:
%   plot_transferfunctions(obj, t_max)
%
% Description:
%   Creates a plot of each weighting function. 
%
% Input:
%   obj -  model object
%
%   t_max - scaler number of the maximum duration to plot (in days)
%
% Output:  
%   (none)
%
% See also:
%   HydroSight: time_series_model_calibration_and_construction;
%   model_TFN: model_construction;
%
% Dependencies
%   model_TFN.m
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure Engineering, 
%   The University of Melbourne.
%
% Date:
%   7 May 2012
%%        
        % Get componants of the model.
        companants = fieldnames(obj.parameters);

        % Derive filter for componants with linear contribution to
        % head, eg remove index to soil moisture componant.
        componant_indexes = true( size(companants) );
        componant_indexes( strcmp(companants,'soilmoisture') ) = false;
        componant_indexes( end ) = false;
        componant_indexes = find(componant_indexes)'; 

        % Calculate componants with transfer function.
        nTranfterFunctions = 0;
        tor = (1:t_max)';
        for ii=componant_indexes

            % Get model parameters for each componant.
            % If the componant is an object, then call the objects
            % getParameters method.
            if isobject( obj.parameters.( char(companants(ii))) )
                                
                
                % Calcule theta for each time point of forcing data.
                try
                    tmp = theta(obj.parameters.( char(companants(ii))), tor );
                    nTranfterFunctions =  nTranfterFunctions + 1;
                    if size(tmp,2)>1
                        theta_est(:,nTranfterFunctions) = sum(tmp,2);
                    else
                        theta_est(:,nTranfterFunctions) = tmp;
                    end
                catch
                    % do nothing
                end
            end
        end
        
        figure();
        for ii=1:nTranfterFunctions
            subplot(nTranfterFunctions,1,ii);
            plot( tor,  theta_est(:,ii));
            xlabel('Duration into the past (days)');
            ylabel('Tranfer function weight');
            title(['Tranfer function for: ', char(companants(ii))]);
            box on;
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
           if isobject(obj.(propNames{i}))
            delete(obj.(propNames{i}));
           else               
            obj.(propNames{i}) = []; 
           end
        end
    end
    
    end
%%  END PUBLIC METHODS    

%%  PRIVATE METHODS    
    methods(Access=private)
       
%% Main method calculating the contribution to the head from each model componant.
        function [h_star, colnames] = get_h_star(obj, time_points, varargin)
% get_h_star private method calculating the contribution to the head from each model componant.
%
% Syntax:
%   [h_star, colnames] = get_h_star(obj, time_points)
%
% Description:
%   This method performs the main calculates of the model. The method 
%   is private and is called by either solve() or objectiveFunction() public
%   methods. The method is highly flexible, allowing any number of model
%   components and forcing transformations. The numerical integration of
%   the convolution function is also using a highly efficient MEX .c
%   'doIRFconvolution.c', which undertakes trapazoidal integration for
%   integrated forcing (eg daily precipitation) or Simpson's 3/8 composite
%   inegration for instantaneous fluxes.

%   Depending upon the user set model componants, this method 
%   undertakes the following seqential steps:
%
%   1) Transform the forcing data. This is undertaken using for the nonlinear
%   TFN models of Peterson and Westenr (2014). 
%
%   2) If model componant 'i' is an impulse response function (IRF), the 
%   componant method 'theta' is called with all daily step time points less
%   than or equal to the latest date head for simulation. Theta and the
%   forcing data are then passed to doIRFconvolution() for the integration at
%   each water level observation time point.
%   
%   3) If the componant is not an IRF, then a user specified
%   IRF matrix from step 2 (which is often precipitation or ET) is scaled 
%   by an appropriate parameter and daily forcing data and then integrated
%   using doIRFconvolution().
%
%   4) Finally, the contribution from all componants are summed to produce
%   h* (as per von Asmuth et al 2002).
%
% Inputs:
%   obj -  model object
%
%   time_points - column vector of the time points to be simulated.  
%
% Outputs:
%
%   h_star - matrix of the contribution from various model componants and
%   their summed influence. The matrix columns are in the order of:
%   date/time, summed contribution to the head, contribution frolm
%   componant i.
%
%   colnames - column names for matrix 'head'.
%
% Example:
%   see HydroSight: time_series_model_calibration_and_construction;
%
% See also:
%   HydroSight: time_series_model_calibration_and_construction;
%   model_TFN: model_construction;
%   calibration_finalise: initialisation_of_model_prior_to_calibration;
%   calibration_initialise: initialisation_of_model_prior_to_calibration;
%   getParameters: returns_a_vector_of_parameter_values_and_names;
%   setParameters: sets_model_parameters_from_input_vector_of_parameter_values;
%   solve: solve_the_model_at_user_input_sime_points;
%
% References:
%   von Asmuth J. R., Bierkens M. F. P., Mass K., 2002, Transfer
%   dunction-noise modeling in continuous time using predefined impulse
%   response functions.
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure
%   Engineering, The University of Melbourne.
%
% Date:
%   26 Sept 2014    

            % Get componants of the model.
            companants = fieldnames(obj.inputData.componentData);
            nCompanants = size(companants,1);  

            % Calc theta_t for max time to initial time (NOTE: min tor = 0).                        
            filt = obj.inputData.forcingData ( : ,1) <= ceil(time_points(end));
            tor = flipud([0:time_points(end)  - obj.inputData.forcingData(1,1)+1]');
            tor_end = tor( obj.variables.theta_est_indexes_min(1,:) )';            
            t = obj.inputData.forcingData( filt ,1);

            % Calculate the transformation models that DO NOT require the
            % input of a forcing model and the forcing model is denoted as the
            % complete model to be ran (ie not also used by another
            % component).
            for i=1:nCompanants
                if isfield(obj.inputData.componentData.(companants{i}),'forcing_object') ...
                && ~isfield(obj.inputData.componentData.(companants{i}),'inputForcingComponent') ...
                && isfield(obj.inputData.componentData.(companants{i}),'isForcingModel2BeRun') ...
                && obj.inputData.componentData.(companants{i}).isForcingModel2BeRun
                    setTransformedForcing(obj.parameters.(obj.inputData.componentData.(companants{i}).forcing_object), t, false)                    
                end
            end
            
            % Calculate the transformation models that DO require the
            % input of a forcing model  and the forcing model is denoted as the
            % complete model to be ran (ie not also used by another
            % component).
            for i=1:nCompanants
                if isfield(obj.inputData.componentData.(companants{i}),'forcing_object') ...
                && isfield(obj.inputData.componentData.(companants{i}),'inputForcingComponent') ...
                && isfield(obj.inputData.componentData.(companants{i}),'isForcingModel2BeRun') ...
                && obj.inputData.componentData.(companants{i}).isForcingModel2BeRun            
                    setTransformedForcing(obj.parameters.(obj.inputData.componentData.(companants{i}).forcing_object), t, false)
                end
            end            
            
            % Assign the forcing data for each model componant.
            % Also, if the model is being calibrated, then also
            % calculate the mean forcing. The later is essential to reduce
            % the calibration error when using a forcing series
            % significantly shorter than the point back in time (ie tor) at
            % which the transfer function is approx. zero.
            nOutputColumns=0;
            isForcingADailyIntegral = false(nCompanants,1);
            for i=1:nCompanants
               
                if isfield(obj.inputData.componentData.(companants{i}),'forcing_object') ...
                && isfield(obj.inputData.componentData.(companants{i}),'outputVariable')                    

                    % Get te transformed forcing. 
                    % NOTE: getTransformedForcing() must return a boolean
                    % scaler deonting if the forcing is an instantaneous flux
                    % or an integral over the day. For the former, Simpson's
                    % 3/8 integration is used for the convolution while for
                    % the latter trapzoidal integration of theta is undertaken and then 
                    % the daily integration result multiplied by the integrated daily forcing.
                    [obj.variables.(companants{i}).forcingData, isForcingADailyIntegral(i)] = ...
                    getTransformedForcing( obj.parameters.(obj.inputData.componentData.(companants{i}).forcing_object), ...
                    obj.inputData.componentData.(companants{i}).outputVariable);
                
                    obj.variables.(companants{i}).forcingData_colnames = obj.inputData.componentData.(companants{i}).outputVariable;
                                        
                else
                    
                    % Non-transformed forcing is assumed to be a daily
                    % integral. Hence, doIRFconvolution() undertakes daily
                    % trapzoidal integration of theta and multiplies it by
                    % the integrated daily forcing.
                    isForcingADailyIntegral(i) = true;
                    
                    obj.variables.(companants{i}).forcingData = obj.inputData.forcingData(filt, ...
                    obj.inputData.componentData.(companants{i}).dataColumn);

                
                    obj.variables.(companants{i}).forcingData_colnames =  ...
                    obj.inputData.forcingData_colnames(obj.inputData.componentData.(companants{i}).dataColumn);
                end
                % Increase the number of output columns for method.
                nOutputColumns = nOutputColumns + size(obj.variables.(companants{i}).forcingData,2);
            end            
            
            % Initialise ouput vector.
            h_star = zeros( size(time_points,1),  nOutputColumns);       
            iOutputColumns = 0;
            % Calculate each transfer function.
            for i=1:nCompanants
                                
                % Calcule theta for each time point of forcing data.
                theta_est_temp = theta(obj.parameters.( char(companants(i))), tor);                

                % Get analytical esitmates of lower and upper theta tails
                integralTheta_upperTail = intTheta_upperTail2Inf(obj.parameters.( char(companants(i))), tor_end);                           
                integralTheta_lowerTail = intTheta_lowerTail(obj.parameters.( char(companants(i))), 1);

                % Get the mean forcing.
                if ~isempty(varargin) && isfield(varargin{1},companants{i})
                    %forcingMean = obj.variables.(companants{i}).forcingMean                    
                    forcingMean = varargin{1}.(companants{i});
                else
                    forcingMean = mean(obj.variables.(companants{i}).forcingData);
                end                
                
                % Integrate transfer function over tor.
                for j=1: size(theta_est_temp,2)
                    % Increment the output volumn index.
                    iOutputColumns = iOutputColumns + 1;

                    % Try to call doIRFconvolution using Xeon Phi
                    % Offload coprocessors. This will only work if the
                    % computer has (1) the intel compiler >2013.1 and (2)
                    % xeon phi cards. The code first tried to call the
                    % mex function. 
                    if ~isfield(obj.variables,'useXeonPhiCard')
                        obj.variables.useXeonPhiCard = true;
                    end
                    
                    try
                        if obj.variables.useXeonPhiCard
                            %display('Offloading convolution algorithm to Xeon Phi coprocessor!');
                            h_star(:,iOutputColumns) = doIRFconvolutionPhi(theta_est_temp(:,j), obj.variables.theta_est_indexes_min, obj.variables.theta_est_indexes_max(1), ...
                                obj.variables.(companants{i}).forcingData(:,j), isForcingADailyIntegral(i), integralTheta_lowerTail(j))' ...
                                + integralTheta_upperTail(j,:)' .* forcingMean(j);
                        else                            
                            h_star(:,iOutputColumns) = doIRFconvolution(theta_est_temp(:,j), obj.variables.theta_est_indexes_min, obj.variables.theta_est_indexes_max(1), ...
                                obj.variables.(companants{i}).forcingData(:,j), isForcingADailyIntegral(i), integralTheta_lowerTail(j))' ...
                                + integralTheta_upperTail(j,:)' .* forcingMean(j);
                        end
                            
                    catch
                        %display('Offloading convolution algorithm to Xeon Phi coprocessor failed - falling back to CPU!');
                        obj.variables.useXeonPhiCard = false;
                        h_star(:,iOutputColumns) = doIRFconvolution(theta_est_temp(:,j), obj.variables.theta_est_indexes_min, obj.variables.theta_est_indexes_max(1), ...
                                obj.variables.(companants{i}).forcingData(:,j), isForcingADailyIntegral(i), integralTheta_lowerTail(j))' ...
                                + integralTheta_upperTail(j,:)' .* forcingMean(j);
                    end                    
                    % Transform the h_star estimate for the current
                    % componant. This feature was included so that h_star
                    % estimate fro groundwater pumping could be corrected 
                    % for an unconfined aquifer using Jacobs correction.
                    % Peterson Feb 2013.
                    h_star(:,iOutputColumns) = transform_h_star(obj.parameters.( char(companants(i))), [time_points, h_star(:,iOutputColumns)]);
                        
                    % Add output name to the cell array
                    if ischar(obj.variables.(companants{i}).forcingData_colnames)
                        colnames{iOutputColumns} = companants{i};
                    else
                        colnames{iOutputColumns} = [companants{i}, ' - ',obj.variables.(companants{i}).forcingData_colnames{j}];
                    end
                end
            end
            
            % Sum all componants (excluding soil moisture) and add time
            % vector.
            if size(h_star,2)>1
                h_star = [time_points , sum(h_star,2), h_star];
                colnames = {'time','Head',colnames{:}};
            else
                h_star = [ time_points, h_star];
                colnames = {'time','Head'};               
            end
                                
        end
    end
    

end