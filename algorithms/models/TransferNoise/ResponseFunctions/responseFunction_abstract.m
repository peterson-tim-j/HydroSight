classdef responseFunction_abstract < handle
    %RESPONSEFUNCTION_ABSTRACT Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    % Static methods
    methods(Static, Abstract=true)
        % Options for GUI table. modelOptions must be a modelOptions data
        % dype object or cell array of modelOptions         
        modelOptions = modelOptions(bore_ID, forcingDataSiteID, siteCoordinates)
    end
    
    methods(Abstract=true)
        % Static methods
        %[types] = responseFunction_optionsFormat()  
                
        % Set parameters
        setParameters(obj, params)
        
        % Get model parameters
        [params, param_names] = getParameters(obj)
        
        % Check if each parameters is valid. This is primarily used to 
        % check parameters are within the physical bounds and sensible (eg 0<specific yield<1)
        isValidParameter = getParameterValidity(obj, params, param_names)

        % Calculate impulse-response function.
        result = theta(obj, t)
        
        % Calculate integral of impulse-response function from t to inf.
        % This is used to minimise the impact from a finit forcign data set.
        result = intTheta_upperTail2Inf(obj, t)           

        % Calculate integral of impulse-response function from t to inf.
        % This is used to minimise the impact from a finit forcign data set.
        result = intTheta_lowerTail(obj, t)           
                
        % Return pre-set physical limits to the function parameters.
        [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj, param_name)
        
        % Transform the result of the response function multiplied by the
        % forcing. This method was included so that the groundwater pumping 
        % transfer function of Shapoori, Peterson, Western and Costelleo
        % 2013 could be corrected from a confined aquifer to an unconfined
        % aquifer. The method is called from model_IRF.get_h_star
        % Peterson Feb 2013
        result = transform_h_star(obj, h_star_est)
        
    end
    
end

