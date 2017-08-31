classdef derivedResponseFunction_abstract < handle
    %RESPONSEFUNCTION_ABSTRACT Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
        
    methods(Static, Abstract=true)
        [modelSettings, colNames, colFormats, colEdits,tooltipString] = modelOptions(bore_ID, forcingDataSiteID, siteCoordinates)
        modelDescription = modelDescription()         
    end
    
    methods(Abstract=true)
                
        % Set parameters
        setParameters(obj, params)
        
        % Get model parameters
        [params, param_names] = getParameters(obj)

        % Return pre-set physical limits to the function parameters.
        [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj, param_name)

        % Return pre-set physical limits to the function parameters.
        [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(obj, param_name)
       
        % Check if each parameters is valid. This is primarily used to 
        % check parameters are within the physical bounds and sensible (eg 0<specific yield<1)
        isValidParameter = getParameterValidity(obj, params, param_names)

        % Calculate impulse-response function.
        result = theta(obj, t)
        
        % Calculate integral of impulse-response function from t to inf.
        % This is used to minimise the impact from a finit forcign data set.
        result = intTheta_upperTail2Inf(obj, t)           
        
        % Calculate integral of impulse-response function from 0 to 1.
        % This is used handle rapidly chnageing fucntion in the range from 0 to 1.
        result = intTheta_lowerTail(obj, t)     
        
        
        % Transform the result of the response function multiplied by the
        % forcing. This method was included so that the groundwater pumping 
        % transfer function of Shapoori, Peterson, Western and Costelleo
        % 2013 could be corrected from a confined aquifer to an unconfined
        % aquifer. The method is called from model_IRF.get_h_star
        % Peterson Feb 2013
        result = transform_h_star(obj, h_star_est)
        
    end
    
end

