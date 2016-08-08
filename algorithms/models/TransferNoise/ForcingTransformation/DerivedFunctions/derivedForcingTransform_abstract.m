classdef derivedForcingTransform_abstract < handle
    %RESPONSEFUNCTION_ABSTRACT Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        
        % Vectors for the tranformed forcings and model state variable(s)
        settings
        variables
        
    end
    
    methods(Static, Abstract=true)
        [variable_names, isOptionalInput] = inputForcingData_required()
        [variable_names] = outputForcingdata_options(inputForcingDataColNames)
        [options, colNames, colFormats, colEdits, toolTip] = modelOptions(sourceForcingTransformName)
        modelDescription = modelDescription()
    end
    
    methods(Abstract)
        % Set parameters
        setParameters(obj, params)
        
        % Get model parameters
        [params, param_names] = getParameters(obj)
        
        % Return pre-set physical limits to the function parameters.
        [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj)
        
        % Return pre-set plausible limits to the function parameters.
        [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(obj)        
        
        % Assess if matrix of parameters is valid. This is used by the calibration ansl allows for 
        % complex parameter constraints to be met.
        isValidParameter = getParameterValidity(obj, params, param_names)

        % Check if the model parameters have chnaged since the last
        % estimation of the transformed forcing calculation
        isNewParameters = detectParameterChange(obj, params)
        
        % Calculate and set tranformed forcing from input climate data
        setTransformedForcing(obj, t, forceRecalculation)        
        
        % Get tranformed forcing data
        [forcingData, isDailyIntegralFlux] = getTransformedForcing(obj, outputVariableName)        

        
    end
    
end

