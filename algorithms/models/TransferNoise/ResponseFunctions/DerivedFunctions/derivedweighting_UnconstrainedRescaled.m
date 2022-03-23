classdef derivedweighting_UnconstrainedRescaled < derivedResponseFunction_abstract
% Pearson's type III impulse response transfer function class. 

    properties(GetAccess=public, SetAccess=protected)
        k
        settings 
    end
%%  STATIC METHODS        
% Static methods used by the Graphical User Interface to inform the
% user of the available model options and their input format.
    methods(Static)        
        function [modelSettings, colNames, colFormats, colEdits,tooltipString] = modelOptions(bore_ID, forcingDataSiteID, siteCoordinates)
           modelSettings = {};
           colNames = {};
           colFormats = {};
           colEdits = [];           
           tooltipString='';
        end
        function modelDescription = modelDescription()
           modelDescription = {'Name: derivedweighting_UnconstrainedRescaled', ...
                               '', ...
                               'Purpose: simulation of recharge-like climate forcing (ie inputs of rainfall, free drainage etc) using any previously created', ...
                               'weighting functions. The previously created function is rescaled a rescaling parameter that can be positive or negative. ', ...
                               '', ...                               
                               'Number of parameters: 1', ...
                               '', ...                               
                               'Options: none', ...
                               '', ...                               
                               'Comments: In combination with the derived forcing function derivedForcing_linearUnconstrainedScaling, this function can be used ', ...
                               'to estimate the impact of revegetation on recharge by weighting the output from say the Pearson''s function (which needs an', ...
                               'input for the landuse change). Also, the fractional change is initially assumed to be +- 20%.', ...
                               '', ...                               
                               'References: (none)'};
        end        
    end
%%    
    methods
        % Constructor
        function obj = derivedweighting_UnconstrainedRescaled(bore_ID, forcingDataSiteID, siteCoordinates, sourceResponseFunctionObject, options, params)
                        
            % Define default parameters 
            if nargin==5
                params=0;
            end
                
            % Set parameters for transfer function.
            setParameters(obj, params)     
            
            % Assign the source object to settings.
            obj.settings.sourceObject = sourceResponseFunctionObject;
            
        end
       
        % Set parameters
        function setParameters(obj, params)
            obj.k = params(1,:);
        end
        
        % Get model parameters
        function [params, param_names] = getParameters(obj)
            params(1,:) = obj.k;
            param_names = {'k'};        
        end        
        
        function isValidParameter = getParameterValidity(obj, params, param_names)                                    
            % Get physical bounds.
            [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj);

    	    % Check parameters are within bounds.
            isValidParameter = params >= params_lowerLimit(:,ones(1,size(params,2))) & ...
                    params <= params_upperLimit(:,ones(1,size(params,2)));
        end
        
        % Return fixed upper and lower bounds to the parameters.
        function [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj)
            params_upperLimit = 2;
            params_lowerLimit = -2;
        end        
        
        % Return fixed upper and lower plausible parameter ranges. 
        % This is used to define reasonable range for the initial parameter sets
        % for the calibration. These parameter ranges are only used in the 
        % calibration if the user does not input parameter ranges.
        function [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(obj)
            params_upperLimit = 0.2;
            params_lowerLimit = -0.2;
        end
        
        % Calculate impulse-response function.
        function result = theta(obj, t)           
            % Call the source model theta function
            result = theta(obj.settings.sourceObject, t);
            
            % Scale the result by back transformed 'A'.
            result = obj.k .* result;            
        end   
        
        % Calculate integral of impulse-response function from t to inf.
        % This is used to minimise the impact from a finit forcign data
        % set.
        function result = intTheta_upperTail2Inf(obj, t)                       
            
            % Call the source model theta function
            result = intTheta_upperTail2Inf(obj.settings.sourceObject, t);            
            
            % Rescale the result.
            result = obj.k .* result;
        end   

        % Calculate integral of impulse-response function from 0 to 1.
        % This is used handle rapidly chnageing fucntion in the range from 0 to 1.        
        function result = intTheta_lowerTail(obj, t)  

            % Call the source model theta function
            result = intTheta_lowerTail(obj.settings.sourceObject, t);
            
            % Rescale the result.
            result = obj.k .* result;
        end
                
        % Transform the estimate of the response function * the forcing.
        function result = transform_h_star(obj, h_star_est)
           result = h_star_est(:,end);
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
               if isempty(obj.(propNames{i}))
                   continue;
               end                
               if isobject(obj.(propNames{i}))
                delete(obj.(propNames{i}));
               else               
                obj.(propNames{i}) = []; 
               end
            end
        end            
        
    end

end

