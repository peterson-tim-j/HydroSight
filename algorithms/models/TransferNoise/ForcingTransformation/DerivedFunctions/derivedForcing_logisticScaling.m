classdef derivedForcing_logisticScaling < derivedForcingTransform_abstract
% Pearson's type III impulse response transfer function class. 

    properties(GetAccess=public, SetAccess=protected)    
      logisticWeight
    end
%%  STATIC METHODS        
% Static methods used by the Graphical User Interface to inform the
% user of the available model types. Any new models must be listed here
% in order to be accessable within the GUI.
    methods(Static)
       
        function [variable_names,isOptionalInput] = inputForcingData_required()
            variable_names = {'scalingData'};
            isOptionalInput = false;
        end
        
        function [variable_names] = outputForcingdata_options(inputForcingDataColNames)
            variable_names = {'scaledForcing'};
        end
        
        function [options, colNames, colFormats, colEdits, toolTip] = modelOptions(sourceForcingTransformName)            
            
            % Get output options.
            transformOutoutOptions = feval(strcat(sourceForcingTransformName,'.outputForcingdata_options'));

            % Reshape to row vector            
            transformOutoutOptions = reshape(transformOutoutOptions, 1, length(transformOutoutOptions));
            
            % Insert source function name.
            transformOutoutOptions = transformOutoutOptions;
            
            % Assign setting for GUI table
            options = cell(1,1);
            colNames={'Source Transform Function Output'};
            colFormats={transformOutoutOptions};
            colEdits=true;
            toolTip='Select an output from the source transform function for input to this function.';            
        end

        function modelDescription = modelDescription()
           modelDescription = {'Name: derivedForcing_logisticScaling', ...
                               '', ...
                               'Purpose: scaling of an input or previously derived forcing time-series by another input time-series. This allows the', ...
                               'estimation of landuse change impact by allowing the scaling of, say, free drainage by a landuse chnage fraction.', ...
                               'Unlike the linear scaling function, this function applies a logistic curve to scaling data. This allows for the', ...                               
                               'situation where, say, the duration of land claring is not known but the mid-point of clearign is known.', ...                               
                               '', ...                               
                               'Number of parameters: 1', ...
                               '', ...                               
                               'Options: none', ...
                               '', ...                               
                               'Comments: combine with the derived weighting functions derivedweighting_PearsonsPositiveRescaled or ', ...
                               'derivedweighting_PearsonsNegativeRescaled to minimise the number of additional parameters required for the estimation.', ...
                               'of landuse impacts.', ...
                               '', ...                               
                               'References: (none)'};
        end          
    end
    
    methods       
%% Construct the model       
        % Constructor
        function obj = derivedForcing_logisticScaling(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates, forcingData_reqCols, sourceForcingTransformObject, options)
            
            % Check that the source transformation model is a class object
            if ~isobject(sourceForcingTransformObject)
                error('The input source transformation model must be a matlab object.');
            end
                        
            % Check there are at least two columns in the model options.
            if ~ischar(options) && ~ischar(options{1})
                error('The model options must be string or 1x1 cell of a string giving the output variable name from the source transformation model to transform');
            end            
                                           
            % Check that the source object variable name is valid.
            [optionalFocingOutputs] = sourceForcingTransformObject.outputForcingdata_options();
            % Check if the requested output from the transformation model is a
            % valid output.
            if ~any(strcmp(optionalFocingOutputs,  options))
                error(['In the options for a derived transformation model, the following transformation model output variable name is not a valid output variable for the source model:',modelOptions]);
            end
                                    
            % Get a list of required forcing inputs and (again) check that
            % each of the required inputs is provided.
            %--------------------------------------------------------------
            requiredFocingInputs = derivedForcing_linearUnconstrainedScaling.inputForcingData_required();
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
                           
            % Determine the date of the threshold (eg from 0 to 1) 
            ind = find( diff(forcingData_data(:,2:end))~=0);
            if isempty(ind) || size(ind,1)>1 
               error('The input forcing data to this function must have a single step change for each column of data.');
            else               
               obj.settings.thresholdDates = forcingData_data(ind,1);
            end
                           
            % Detrmine the range in scaling data
            obj.settings.forcingDataRange = range(forcingData_data(:,2:end));
            
            % Assign the source objects to settings.
            obj.settings.sourceObject = sourceForcingTransformObject;
            obj.settings.sourceObject_outputvariable = options;
            
            % set initial param value
            params_initial = log10(0.01);
            
            % Initialise parameter.
            setParameters(obj, params_initial)
        end
       
        % Set parameters
        function setParameters(obj, params)   
            obj.logisticWeight = params(1,:);
        end
        
        % Get model parameters
        function [params, param_names] = getParameters(obj)
            params = obj.logisticWeight;
            param_names = {'derivedForcing_logisticScaling', 'logisticWeight'};        
        end        
        
        % Return fixed upper and lower bounds to the parameters.
        function [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj)
            params_upperLimit = 0.0;
            params_lowerLimit = -inf;
        end        
        
        % Return fixed upper and lower plausible parameter ranges. 
        % This is used to define reasonable range for the initial parameter sets
        % for the calibration. These parameter ranges are only used in the 
        % calibration if the user does not input parameter ranges.
        function [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(obj)
            params_upperLimit = -1;
            params_lowerLimit = -3;
        end

        function isValidParameter = getParameterValidity(obj, params, param_names)                                    
            isValidParameter = true(size(params));
        end        
        
        % Check if the model parameters have chnaged since the last
        % estimation of the transformed forcing calculation
        function isNewParameters = detectParameterChange(obj, params)
            isNewParameters = true;
        end
        
        % Calculate and set tranformed forcing from input climate data
        function setTransformedForcing(obj, t, forceRecalculation)
            % Get the source model transformation calculation.
            [forcingData, obj.variables.isDailyIntegralFlux] = getTransformedForcing(obj.settings.sourceObject, obj.settings.sourceObject_outputvariable{1});
            
            % Filter the forcing data to input t.
            filt_time = obj.settings.forcingData(:,1) >= t(1) & obj.settings.forcingData(:,1) <= t(end);
                                        
            % Find the columns for the required forcing.
            colnum=1;
            for i=1:size(obj.settings.forcingData_cols,1)
               colnum= [colnum; find(strcmp( obj.settings.forcingData_colnames, obj.settings.forcingData_cols(i,2)))];               
            end
            
            % Get the additional forcing data specific to this model.
            % NOTE: if multiple columns are input, then the product is
            % calculated.
            scalingData = obj.settings.forcingData(filt_time,colnum);
            scalingData_time = bsxfun(@plus, scalingData(:,1), -obj.settings.thresholdDates) ;
            scalingData = prod( obj.settings.forcingDataRange./(1 + exp(-10^(obj.logisticWeight).*scalingData_time )), 2);
                        
            % Scale the source forcing by the input scalingData;
            obj.variables.scaledForcing = scalingData .* forcingData;
        end
        
        % Get tranformed forcing data
        function [forcingData, isDailyIntegralFlux] = getTransformedForcing(obj, outputVariableName)                
            if isfield(obj.variables,outputVariableName)
                forcingData = obj.variables.(outputVariableName);
                isDailyIntegralFlux = obj.variables.isDailyIntegralFlux;
            else
                error(['The following output variable was requested from this transformation model but the variable has not yet been set. Call "setTransformedForcing()" first: ',outputVariableName]);
            end
        end
        
        % Return the derived variables.
        function [params, param_names] = getDerivedParameters(obj)
            params = [];
            param_names = cell(0,2);
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

end

