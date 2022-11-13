classdef derivedweighting_PearsonsPumping < responseFunction_Pearsons & derivedResponseFunction_abstract
% Pearson's type III impulse response transfer function class. 

    properties(GetAccess=public, SetAccess=protected)         
    end
%%  STATIC METHODS        
% Static methods used by the Graphical User Interface to inform the
% user of the available model options and their input format.
    methods(Static)        
        function [options, colNames, colFormats, colEdits, tooltipString] = modelOptions(bore_ID, forcingDataSiteID, siteCoordinates)
            % Assign format of table for GUI.
            colNames = {'Parameter Name', 'Lower Physical Bound', 'Upper Physical Bound'};
            colFormats = {'char', 'numeric', 'numeric'};
            colEdits = logical([0 1 1]);
            tooltipString = ['Use this table to set parameter bounds for the calibration.'];
                         
            % Default parameter bounds
            params_upperLimit = [log10(-log(sqrt(eps()))); inf];
            params_lowerLimit = [log10(sqrt(eps())); log10(sqrt(eps()))];    
            
            options = {'b', params_lowerLimit(1), params_upperLimit(1); ...
                       'n', params_lowerLimit(2), params_upperLimit(2)};
            
                   
        end 
        function modelDescription = modelDescription()
           modelDescription = {'Name: responseFunction_PearsonsPumping', ...
                               '', ...               
                               'Purpose: simulation of recharge-like climate forcing (ie inputs of rainfall, free drainage etc) like', ...
                               'the Pearsons weighting dunction except that the parameter A is derived from a pumping drawdown', ...               
                               'weighting function', ...
                               'Number of parameters: 2', ...
                               '', ...               
                               'Options: none', ...
                               '', ...               
                               'Comments: a highly flexible function that can range from a exponetial-like decay (no time lag) to a skew Gaussian-like function (with time lag)'};
        end         
    end
%%    
    methods
        % Constructor
        function obj = derivedweighting_PearsonsPumping(bore_ID, forcingDataSiteID, siteCoordinates, sourceResponseFunctionObject, options, params)
            
                   
            % Use inheritence to construct Pearsons objects.
            obj = obj@responseFunction_Pearsons(bore_ID, forcingDataSiteID, siteCoordinates, options);
            
            % Define default parameters 
            if nargin==5
                params=[log10(0.01); log10(1.5)];
            end
                
            % Set parameters for transfer function.
            setParameters(obj, params)     
            
            % Assign the source object to settings.
            obj.settings.sourceObject = sourceResponseFunctionObject;
            
            % Check the source model can return a normalised theta value. 
            % The normalised theta results is rescaled within this function.
            % This is undertaken to reduce parameter covariance.            
            if any(strcmp(methods(obj.settings.sourceObject),'getDerivedParameters'))
                % Get 'A' from the S value from the pumping drawdown eqn
                [params, param_names] = getDerivedParameters(obj.settings.sourceObject);

                % Check the second parameter is 'S'
                filt = strcmp(param_names,'Storativity');
                if isempty(filt)
                    error('A source componant weighting function does not appear to be a pumping draw-down equation. This is required to estimate storativity');
                end
            else
                error('A source componant weighting function cannot provide derived parameters, i.e. storativity');
            end

        end
       
        % Set parameters
        function setParameters(obj, params)
            obj.b = params(1,:);
            obj.n = params(2,:);
        end
        
        % Get model parameters
        function [params, param_names] = getParameters(obj)
            params(1,:) = obj.b;
            params(2,:) = obj.n;
            param_names = {'b';'n'};        
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
            if isfield(obj.settings,'params_lowerPhysicalLimit')
                params_lowerLimit = obj.settings.params_lowerPhysicalLimit;
            else
                params_lowerLimit = [log10(sqrt(eps())); log10(sqrt(eps()))];         
            end
            
            if isfield(obj.settings,'params_upperPhysicalLimit')
                params_upperLimit = obj.settings.params_upperPhysicalLimit;
            else
                params_upperLimit = [log10(-log(sqrt(eps()))); inf];
            end
        end        
        
        % Return fixed upper and lower plausible parameter ranges. 
        % This is used to define reasonable range for the initial parameter sets
        % for the calibration. These parameter ranges are only used in the 
        % calibration if the user does not input parameter ranges.
        function [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(obj)
            params_upperLimit = [log10(0.1);         log10(10)          ];
            params_lowerLimit = [-5; -2 ];
        end
        
        % Calculate impulse-response function.
        function result = theta(obj, t)        
            % Set 'A' from the S value from the pumping drawdown eqn
            setA(obj);            
            
            % Call the Pearsonss model theta upper tail function
            result = theta@responseFunction_Pearsons(obj, t);              
        end   
        
        % Calculate integral of impulse-response function from t to inf.
        % This is used to minimise the impact from a finit forcign data
        % set.
        function result = intTheta_upperTail2Inf(obj, t)                                   
            % Set 'A' from the S value from the pumping drawdown eqn
            setA(obj);            
            
            % Call the Pearsonss model theta upper tail function
            result = intTheta_upperTail2Inf@responseFunction_Pearsons(obj, t);                        
        end   

        % Calculate integral of impulse-response function from 0 to 1.
        % This is used handle rapidly chnageing fucntion in the range from 0 to 1.        
        function result = intTheta_lowerTail(obj, t)  
            % Set 'A' from the S value from the pumping drawdown eqn
            setA(obj);            
            
            % Call the Pearsonss model theta upper tail function
            result = intTheta_lowerTail@responseFunction_Pearsons(obj, t);                                    
        end
                
        % Transform the estimate of the response function * the forcing.
        function result = transform_h_star(obj, h_star_est)
           result = h_star_est(:,end);
        end   
        
        % Return the derived variables.
        function [params, param_names] = getDerivedParameters(obj)
            % Get 'A' from the S value from the pumping drawdown eqn
            setA(obj);  
            params = obj.A;
            param_names = {'Pearsons amplitude parameter A'};
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

    
    methods(Access=private) 

        function A = setA(obj)
            % Get 'A' from the S value from the pumping drawdown eqn
            [params, param_names] = getDerivedParameters(obj.settings.sourceObject);
            
            % Check the second parameter is 'S'
            filt = endsWith(param_names,'Storativity');
            if isempty(filt)
                error('A source componant weighting function does not appear to be a pumping draw-down equation. This is requied to estimate Storativity');
            end                        
            S = params(filt);
            
            % Calculate the scaling parameter A
            A = log10(1/1000/S);
            obj.A=A;
        end
    end
end

