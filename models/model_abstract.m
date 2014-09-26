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
        
        head = solve(obj, time_points)
            
        params_initial = calibration_initialise(obj, t_start, t_end)
            
        calibration_finalise(obj, params)
            
        [objFn, h_star] = objectiveFunction(params, time_points, obj)                
        
        setParameters(obj, params)
        
        [params, param_names] = getParameters(obj)
        
        [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj)
        
    end
    
end

