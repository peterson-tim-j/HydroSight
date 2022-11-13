classdef responseFunction_JacobsCorrection < handle
    %RESPONSEFUNCTION_JACOBSCORRECTION Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(GetAccess=public, SetAccess=protected)
        zeta
    end
    
    methods
        % Constructor
        function obj = responseFunction_JacobsCorrection(params)
           
            if nargin==0
                params = log10(1);
            end
            
            % Set parameters for transfer function.
            setParameters(obj, params)                 
        end
                  
        % Set parameters
        function setParameters(obj, params)
            obj.zeta = params(1,:);
        end
        
        % Get model parameters
        function [params, param_names] = getParameters(obj)
            params(1,:) = obj.zeta;
            param_names = {'zeta'};
        end
        
        % Return fixed upper and lower bounds to the parameters.
        function [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj)
            params_upperLimit = log10(1000);
            params_lowerLimit = log10(1);
        end        
        
        % Return fixed upper and lower plausible parameter ranges. 
        % This is used to define reasonable range for the initial parameter sets
        % for the calibration. These parameter ranges are only used in the 
        % calibration if the user does not input parameter ranges.
        function [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(obj)
            params_upperLimit = log10(50);
            params_lowerLimit = log10(10);
        end        
                
        function isValidParameter = getParameterValidity(obj, params, param_names)
                        
            zeta_filt =  strcmp('zeta',param_names);
            
            zeta = params(zeta_filt,:);
            
            % Back transform to get Sat. Thickness.
            SatThickness = 10.^zeta;

            % Get physical bounds.
            [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj);

            % Check parameters are within bounds and T>0 and 0<S<1.
            isValidParameter = SatThickness>0 & ...
            params >= params_lowerLimit(3,ones(1,size(params,2))) & ...
            params <= params_upperLimit(3,ones(1,size(params,2)));            
        end        
        
        % Transform the estimate of the response function * the forcing.
        % This undertakes the Jacob's correction for an unconfined aquifer.
        % If, in solution to the quadratic equation, a complex number is
        % produced, then the input h_star value is returned. Peterson Feb
        % 2013.
        function result = transform_h_star(obj, h_star_est)
           filt = (1-2.*h_star_est(:,2)./10.^obj.zeta)>=0;
           result = h_star_est(:,2);
           result(filt) = -10.^obj.zeta .* (-1 + sqrt(1-2.*h_star_est(filt,2)./10.^obj.zeta));           
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

