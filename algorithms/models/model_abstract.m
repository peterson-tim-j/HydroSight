classdef model_abstract < handle
% Abstract class for creating univariate time series models
    
    properties
        
        % Model parameters structure
        parameters 
        
        % Observation data
        inputData
        
        % Calculation variables
        variables
        
        % Results
        results
    end    
    
    methods (Abstract)
        
        [head, colnames, noise] = solve(obj, time_points)
            
        [params_initial, time_points] = calibration_initialise(obj, t_start, t_end)
            
        h_star = calibration_finalise(obj, params, useLikelihood)
            
        [objFn, h_star] = objectiveFunction(params, time_points, obj)                
        
        setParameters(obj, params, param_names)
        
        [params, param_names] = getParameters(obj)
        
        [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj)
        
        [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(obj)
        
        isValidParameter = getParameterValidity(obj, params, time_points)
        
    end
    
end

