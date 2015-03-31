classdef  responseFunction_FerrisKnowlesJacobs < responseFunction_FerrisKnowles & responseFunction_JacobsCorrection
% Pearson's type III impulse response transfer function class. 

%%  PUBLIC METHODS      
    methods
        % Constructor
        function obj = responseFunction_FerrisKnowlesJacobs(bore_ID, forcingDataSiteID, siteCoordinates, options, params)            
            % Use inheritence to construct Ferris Knowles and Jacobs correction objects.
            obj = obj@responseFunction_FerrisKnowles(bore_ID, forcingDataSiteID, siteCoordinates, options);
            obj = obj@responseFunction_JacobsCorrection();            
            
            if nargin==5
                setParameters(obj, params)
            end
        end
                  
        % Set parameters
        function setParameters(obj, params)
            if size(params,1)==3
                setParameters@responseFunction_FerrisKnowles(obj, params(1:2));
                setParameters@responseFunction_JacobsCorrection(obj, params(3));
            elseif size(params,1)==2
                setParameters@responseFunction_FerrisKnowles(obj, params);
            elseif size(params,1)==1
                setParameters@responseFunction_JacobsCorrection(obj, params);
            end
        end
        
        % Get model parameters
        function [params, param_names] = getParameters(obj)            
            [params, param_names] = getParameters@responseFunction_FerrisKnowles(obj);
            [params(3), param_names(3)] = getParameters@responseFunction_JacobsCorrection(obj);            
        end        
        
        function isValidParameter = getParameterValidity(obj, params, param_names)                        
            [isValidParameter] = getParameterValidity@responseFunction_FerrisKnowles(obj, params(1:2,:), param_names{1:2});
            [isValidParameter(3,:)] = getParameterValidity@responseFunction_JacobsCorrection(obj, params(3,:), param_names{3});                     
        end
        
        % Return fixed upper and lower bounds to the parameters.
        function [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj)
            [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit@responseFunction_FerrisKnowles(obj);
            [params_upperLimit(3), params_lowerLimit(3)] = getParameters_physicalLimit@responseFunction_JacobsCorrection(obj);
        end        
        
        % Return fixed upper and lower plausible parameter ranges. 
        % This is used to define reasonable range for the initial parameter sets
        % for the calibration. These parameter ranges are only used in the 
        % calibration if the user does not input parameter ranges.
        function [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(obj)
            [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit@responseFunction_FerrisKnowles(obj);
            [params_upperLimit(3), params_lowerLimit(3)] = getParameters_plausibleLimit@responseFunction_JacobsCorrection(obj);
        end    
        
        % Transform the estimate of the response function * the forcing.
        % This undertakes the Jacob's correction for an unconfined aquifer.
        % If, in solution to the quadratic equation, a complex number is
        % produced, then the input h_star value is returned. Peterson Feb
        % 2013.
        function result = transform_h_star(obj, h_star_est)           
           result = transform_h_star@responseFunction_JacobsCorrection(obj, h_star_est);
        end  
        
        % Extract the estimates of aquifer properties from the values of
        % alpha, beta and zeta.
        function [T,S, Ksat] = get_AquiferProperties(obj)            
            [T,S] = get_AquiferProperties@responseFunction_FerrisKnowles(obj);
            Ksat = T./10.^obj.zeta;          
        end
    end
end
