classdef derivedweighting_PearsonsUnscaled < derivedResponseFunction_abstract
% Pearson's type III impulse response transfer function class. 

    properties(GetAccess=public, SetAccess=protected)
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
           modelDescription = {'Name: derivedweighting_PearsonsUnscaled', ...
                               '', ...
                               'Purpose: simulation of recharge-like climate forcing (ie inputs of rainfall, free drainage etc) using previously created', ...
                               'responseFunction_Pearsons weighting function. Source weighting function is not rescaled.', ...
                               '', ...                               
                               'Number of parameters: 0', ...
                               '', ...                               
                               'Options: none', ...
                               '', ...                               
                               'Comments: TO DO.', ...
                               '', ...                               
                               'References: (none)'};
        end        
    end
%%    
    methods
        % Constructor
        function obj = derivedweighting_PearsonsUnscaled(bore_ID, forcingDataSiteID, siteCoordinates, sourceResponseFunctionObject, options, params)
                        
            % Define default parameters 
            if nargin==5
                params=0.01;
            end
                
            % Set parameters for transfer function.
            setParameters(obj, params)     
            
            % Assign the source object to settings.
            obj.settings.sourceObject = sourceResponseFunctionObject;
            
            % Check the source model can return a normalised theta value. 
            % The normalised theta results is rescaled within this function.
            % This is undertaken to reduce parameter covariance.            
            if ~any(strcmp(methods(obj.settings.sourceObject),'theta_normalised'))
                error('This weighting function normalises and rescales the Pearsons weigthing function. However, the following expected method within the source function could not be found: "theta_normalised"');
            end

        end
       
        % Set parameters
        function setParameters(obj, params)
            % Do Nothing
        end
        
        % Get model parameters
        function [params, param_names] = getParameters(obj)
            params = [];
            param_names = {};        
        end        
        
        function isValidParameter = getParameterValidity(obj, params, param_names)                                                
            isValidParameter = true;
        end
        
        % Return fixed upper and lower bounds to the parameters.
        function [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj)
            params_upperLimit = [];
            params_lowerLimit = [];
        end        
        
        % Return fixed upper and lower plausible parameter ranges. 
        % This is used to define reasonable range for the initial parameter sets
        % for the calibration. These parameter ranges are only used in the 
        % calibration if the user does not input parameter ranges.
        function [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(obj)
            params_upperLimit = [];
            params_lowerLimit = [];
        end
        
        % Return the derived variables.
        function [params, param_names] = getDerivedParameters(obj)
            params = [];
            param_names = {};                
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

