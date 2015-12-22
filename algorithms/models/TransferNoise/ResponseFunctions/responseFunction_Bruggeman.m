classdef responseFunction_Bruggeman < responseFunction_abstract
% Pearson's type III impulse response transfer function class. 

    properties(GetAccess=public, SetAccess=protected)          
        alpha
        beta
        gamma  
        settings
    end

%%  STATIC METHODS        
% Static methods used by the Graphical User Interface to inform the
% user of the available model options and their input format.
    methods(Static)        
        function [modelSettings, colNames, colFormats, colEdits] = modelOptions(bore_ID, forcingDataSiteID, siteCoordinates)
           modelSettings = {};
           colNames = {};
           colFormats = {};
           colEdits = [];           
        end
        function modelDescription = modelDescription()
           modelDescription = {'Name: responseFunction_Bruggeman', ...
                               '', ...               
                               'Purpose: simulation of streamflow lateral flow influence on groundwater head.', ...
                               '', ...               
                               'Number of parameters: 3', ...
                               '', ...               
                               'Options: none', ...
                               '', ...               
                               'Comments: This function has not been rigerouslt tested within the framework. Use with caution!.', ...
                               '', ...               
                               'References: ', ...
                               '1. von Asmuth J.R., Maas K., Bakker M., Petersen J.,(2008), Modeling time series of ground water', ...
                               'head fluctuations subjected to multiple stresses, Ground Water, Jan-Feb;46(1):30-40'};
        end                
    end
    
%%  PUBLIC METHODS     
    methods
        % Constructor
        function obj = responseFunction_Bruggeman(bore_ID, forcingDataSiteID, siteCoordinates, options, params)
            
            % Define default parameters 
            if nargin==4
                params=[10; 10; 10];
            end
                
            % Set parameters for transfer function.
            setParameters(obj, params);                 
            
            % No settings are required.
            obj.settings=[];
        end
       
         % Set parameters
        function setParameters(obj, params)
            obj.alpha = params(1);
            obj.beta = params(2);
            obj.gamma = params(3);            
        end
        
        % Get model parameters
        function [params, param_names] = getParameters(obj)
            params(1,1) = obj.alpha;
            params(2,1) = obj.beta;
            params(3,1) = obj.gamma;       
            param_names = {'alpha';'beta';'gamma'};
        end        
        
        function isValidParameter = getParameterValidity(obj, params, param_names)
            
            % Get physical bounds.
            [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj);

            % Check parameters are within bounds and T>0 and 0<S<1.
                isValidParameter = params >= params_lowerLimit(:,ones(1,size(params,2))) & ...
            params <= params_upperLimit(:,ones(1,size(params,2)));   

        end

        % Return fixed upper and lower bounds to the parameters.
        function [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj)
            params_upperLimit = inf(3,1);
            params_lowerLimit = zeros(3,1);
        end        
        
        % Return fixed upper and lower plausible parameter ranges. 
        % This is used to define reasonable range for the initial parameter sets
        % for the calibration. These parameter ranges are only used in the 
        % calibration if the user does not input parameter ranges.
        function [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(obj)
            params_upperLimit = [100; 100; 100];
            params_lowerLimit = [ 0; 0; 0];
        end        
        
        % Calculate impulse-response function.
        function result = theta(obj, t)        
           
            result = - obj.gamma ./ sqrt( pi()*obj.beta^2/obj.alpha^2 .* t.^3 ).* exp( -obj.alpha^2 ./(obj.beta.^2 .* t)- obj.beta.^2.*t );
            
            % Trials indicated that when tor (ie t herein) is very large,
            % result can equal NaN.
            if any(isnan(result) | isinf(result))
                error('NaN or Inf within the integral of the theta function.');
            end  
        end    
        
        % Calculate integral of impulse-response function from t to inf.
        % This is used to minimise the impact from a finit forcign data
        % set.
        % TODO: IMPLEMENTED integral of theta
        function result = intTheta_upperTail2Inf(obj, t)           
            
            result = 0; 
        end   

        % Calculate integral of impulse-response function from t to inf.
        % This is used to minimise the impact from a finit forcign data set.
        % TODO: IMPLEMENTED integral of theta
        function result = intTheta_lowerTail(obj, t)          
            result = 0; 
        end
        
        % Transform the estimate of the response function * the forcing.
        function result = transform_h_star(obj, h_star_est)
           result = h_star_est;
        end     
        
        % Return the derived variables.
        function [params, param_names] = getDerivedParameters(obj)
            params = [];
            param_names = cell(0,2);
        end
        
    end
end

