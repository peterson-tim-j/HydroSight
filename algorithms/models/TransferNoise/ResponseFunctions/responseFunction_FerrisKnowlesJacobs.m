classdef  responseFunction_FerrisKnowlesJacobs < responseFunction_FerrisKnowles & responseFunction_JacobsCorrection
% Pearson's type III impulse response transfer function class. 

%%  STATIC METHODS        
% Static methods used by the Graphical User Interface to inform the
% user of the available model types. Any new models must be listed here
% in order to be accessable within the GUI.    
    methods(Static)    
        
        function modelDescription = modelDescription()
           modelDescription = {'Name: responseFunction_FerrisKnowlesJacobs', ...
                               '', ...                              
                               'Purpose: simulation of pumping drawdown using the Ferris Knowles instantaneous drawdown function with the Jacobs correction for unconfined aquifers.', ...
                               '', ...               
                               'Number of parameters: 3', ...
                               '', ...               
                               'Options: Recharge or no-flow boundary conditions.', ...
                               '', ...               
                               'References: ', ...
                               '1. Ferris JG, Knowles DB (1963) The slug-injection test for estimating the coefficient of transmissibility of an aquifer. ', ...
                               'In: Bentall R (ed) Methods of determining permeability, transmissibility, and drawdown. U.S.Geological Survey', ...
                               '2. Jacob CE (1944) Notes on determining permeability by pumping tests under water-table conditions. US Geological Survey Reston, VA', ...
                               '3. V. Shapoori, T. J. Peterson, A. W. Western, J. F. Costelloe, Top-down groundwater hydrograph time-series modeling for climate-pumping', ...
                               'decomposition, Hydrogeology Journal, 2015'};
        end           
    end

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
                setParameters@responseFunction_FerrisKnowles(obj, params(1:2,:));
                setParameters@responseFunction_JacobsCorrection(obj, params(3,:));
            elseif size(params,1)==2
                setParameters@responseFunction_FerrisKnowles(obj, params);
            elseif size(params,1)==1
                setParameters@responseFunction_JacobsCorrection(obj, params);
            end
        end
        
        % Get model parameters
        function [params, param_names] = getParameters(obj)            
            [params, param_names] = getParameters@responseFunction_FerrisKnowles(obj);
            [params(3,:), param_names(3,:)] = getParameters@responseFunction_JacobsCorrection(obj);            
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
        function [params, param_names] = getDerivedParameters(obj)            
            [params, param_names] = getDerivedParameters@responseFunction_FerrisKnowles(obj);
            Ksat = T./10.^obj.zeta;   
            
            params = [params(1,:); params(2,:); Ksat];
            param_names = {param_names{1}; param_names{2}; 'Lateral conductivity'};
        end
    end
end
