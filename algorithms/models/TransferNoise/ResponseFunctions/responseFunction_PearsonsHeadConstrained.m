classdef responseFunction_PearsonsHeadConstrained < responseFunction_Pearsons
% Pearson's type III impulse response transfer function class. 

properties(GetAccess=public, SetAccess=protected)
        k;
        threshold;
end

%%  STATIC METHODS        
% Static methods used by the Graphical User Interface to inform the
% user of the available model options and their input format.
    methods(Static)        
        function modelDescription = modelDescription()
           modelDescription = {'Name: responseFunction_PearsonsHeadConstrained', ...
                               '', ...                                              
                               'Purpose: simulation of recharge-like climate forcing but with an upper constraint eg a drain.', ...
                               '', ...                                                              
                               'Number of parameters: 5', ...
                               '', ...                                                              
                               'Options: none', ...
                               '', ...                                                              
                               'Comments: a highly flexible function that can range from a exponetial-like decay (no time lag) to a skew Gaussian-like function (with time lag).', ...
                               'Also, the function is derived from the responseFunction_Pearsons function.', ...
                               '', ...                                                              
                               'References: Peterson & Western (2014), Nonlinear time-series modeling of unconfined groundwater head, Water Resour. Res., 50, 8330–8355'};
        end                
    end

%%    
    methods
        % Constructor
        function obj = responseFunction_PearsonsHeadConstrained(bore_ID, forcingDataSiteID, siteCoordinates, options, params)            
            % Call inherited model constructor.
            obj = obj@responseFunction_Pearsons(bore_ID, forcingDataSiteID, siteCoordinates, options);
    
            % Assign model parameters if input
            obj.k = log10(0.01);
            obj.threshold = log10(5);
            if nargin>5
                setParameters(obj, params);
            end
        end
        
        % Set parameters
        function setParameters(obj, params)
                setParameters@responseFunction_Pearsons(obj, params(1:3,:));
                if size(params,1)>3
                    obj.k = params(4,:);
                    obj.threshold = params(5,:);
                end
        end
        
        % Get model parameters
        function [params, param_names] = getParameters(obj)            
            [params, param_names] = getParameters@responseFunction_Pearsons(obj);
            params(4,:) = obj.k;
            param_names{4} = 'k';
            params(5,:) = obj.threshold;
            param_names{5} = 'threshold';

        end        
              
        % Return fixed upper and lower bounds to the parameters.
        function [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj)
            [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit@responseFunction_Pearsons(obj);
            params_upperLimit(4) = log10(100);
            params_lowerLimit(4) = log10(eps());
            params_upperLimit(5) = log10(1000);
            params_lowerLimit(5) = log10(eps());            
        end        
        
        % Return fixed upper and lower plausible parameter ranges. 
        % This is used to define reasonable range for the initial parameter sets
        % for the calibration. These parameter ranges are only used in the 
        % calibration if the user does not input parameter ranges.
        function [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(obj)
            [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit@responseFunction_Pearsons(obj);
            params_upperLimit(4) = log10(5);
            params_lowerLimit(4) = log10(sqrt(eps()));            
            params_upperLimit(5) = log10(100);
            params_lowerLimit(5) = log10(sqrt(eps()));             
        end    
               

        % Reduce h_star (when above threshold) by a rate if k
        function result = transform_h_star(obj, h_star_est)
            delta_t = [0;diff(h_star_est(:,1))];
            result = h_star_est(:,end) - max(0,h_star_est(:,end) - 10.^obj.threshold).*10.^(obj.k).*delta_t;
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

