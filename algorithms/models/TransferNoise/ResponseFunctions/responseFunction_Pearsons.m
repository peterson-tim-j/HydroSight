classdef responseFunction_Pearsons < responseFunction_abstract
% Pearson's type III impulse response transfer function class. 

    properties(GetAccess=public, SetAccess=protected)
        A
        b
        n        
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
           modelDescription = {'Name: responseFunction_Pearsons', ...
                               '', ...               
                               'Purpose: simulation of recharge-like climate forcing (ie inputs of rainfall, free drainage etc).', ...
                               '', ...               
                               'Number of parameters: 3', ...
                               '', ...               
                               'Options: none', ...
                               '', ...               
                               'Comments: a highly flexible function that can range from a exponetial-like decay (no time lag) to a skew Gaussian-like function (with time lag)', ...
                               '', ...               
                               'References: ', ...
                               '1. Peterson & Western (2014), Nonlinear time-series modeling of unconfined groundwater head, Water Resour. Res., 50, 8330–8355'};
        end        
    end

%%    
    methods
        % Constructor
        function obj = responseFunction_Pearsons(bore_ID, forcingDataSiteID, siteCoordinates, options, params)
                        
            % Define default parameters 
            if nargin==4
                params=[log10(1); log10(0.01); log10(1.5)];
            end                
            
            % Set parameters for transfer function.
            setParameters(obj, params)     
            
            % Initialise the private property, t_limit, 
            % defining the lower limit to an exponetial 
            % repsonse function.
            obj.settings.t_limit = NaN;
            obj.settings.weight_at_limit = NaN;
        end
       
        % Set parameters
        function setParameters(obj, params)
            obj.A = params(1,:);
            obj.b = params(2,:);
            obj.n = params(3,:);            
        end
        
        % Get model parameters
        function [params, param_names] = getParameters(obj)
            params(1,:) = obj.A;
            params(2,:) = obj.b;
            params(3,:) = obj.n;       
            param_names = {'A';'b';'n'};        
        end        
        
        function isValidParameter = getParameterValidity(obj, params, param_names)
            isValidParameter = true(size(params));

            A_filt =  strcmp('A',param_names);
            b_filt =  strcmp('b',param_names);
            n_filt =  strcmp('n',param_names);
            
            A = params(A_filt,:);
            b = params(b_filt,:);
            n = params(n_filt,:);
                                    
            % Get physical bounds.
            [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj);

    	    % Check parameters are within bounds.
            isValidParameter = params >= params_lowerLimit(:,ones(1,size(params,2))) & ...
                    params <= params_upperLimit(:,ones(1,size(params,2)));
                 
            % Check the b and n parameters will not produce NaN or Inf
            % values when theta() is integrated to -inf (see intTheta()).
            isValidParameter(n_filt,gamma(10.^n)==inf) = false;
            isValidParameter(b_filt | n_filt, (10.^b).^(10.^n)<=0) = false;            

        end
        
        % Return fixed upper and lower bounds to the parameters.
        function [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj)
            % NOTE: The upper limit for 'b' is set to that at which
            % exp(-10^b * t) <= sqrt(eps()) where t = 1 day.
            params_upperLimit = [inf; log10(-log(sqrt(eps()))); inf];
            params_lowerLimit = [log10(sqrt(eps())); log10(sqrt(eps())); log10(sqrt(eps()))];
        end        
        
        % Return fixed upper and lower plausible parameter ranges. 
        % This is used to define reasonable range for the initial parameter sets
        % for the calibration. These parameter ranges are only used in the 
        % calibration if the user does not input parameter ranges.
        function [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(obj)
            params_upperLimit = [log10(1); log10(0.1);         log10(10)          ];
            %params_lowerLimit = [log10(sqrt(eps()))+2;    log10(sqrt(eps()))+2; log10(sqrt(eps()))+2 ];
            params_lowerLimit = [-5;    -5; -2 ];
        end
        
        % Calculate impulse-response function.
        function result = theta(obj, t)           

            % Back-transform parameter 'n' from natural log domain to
            % non-transformed domain. This transformation of n was
            % undertaken because ocassionally the optimal value of n was
            % very large eg 200. By transforming it as below, such large
            % values do not occur in the transformed domain and this allows
            % for a greater parameter range to be more easily accessed by
            % the gradient based calibration.
            n_backTrans = 10^(obj.n);
            
            % Back transform 'b'
            b_backTrans = 10^(obj.b);           
            
            % Back transform 'A'
            A_backTrans = 10^(obj.A);
            
            % If n>1, then theta will have a value of 't' at which the
            % gradient is zero. By putting this value of 't' into theta
            % the value at the peak can be determined. This substitution
            % is done inside the theta calculation to avoid problems of
            % theta=inf at time time point.
            %
            % Also, the original version of the theta function (as given within von Asmuthe 2005) 
            % can produce Inf values when n is large and b is also large. If
            % these are filter out then major discontinuities can be
            % produced in the response surface. If this occurs, then an
            % algabraically rearranged version is used that minimises the
            % emergence of inf.            
            % 
            % Lastly, the theta function below are a modified version of
            % von Asmuth 2005. The modification was undertaken to remove
            % the considerable covariance between 'b' and 'A' parameters
            if n_backTrans > 1
                
                t_peak = (n_backTrans - 1)/b_backTrans;                              
                         
                % Calculate Pearsons value.
                result = A_backTrans ./(t_peak.^(n_backTrans-1)*exp(-b_backTrans*t_peak)) .* t.^(n_backTrans-1) .* exp( -b_backTrans .* t);                
                                
                % New algebraic version to which minimise Inf and NaN. The
                % equation is identical to that above but rearranged to
                % minimise Inf values. This was found to be essential for reliable calibration when n is large.           
                % Importantly, the scaling by the peak value of theta is
                % undertaken below inside the bracketted term set to a power of
                % (n_backTrans-1). This was undertaken to reduce the liklihood that
                % any time point have a value of inf.
                if any(isnan(result) | isinf(result))            
                      result = A_backTrans .* ( t.* b_backTrans./(n_backTrans - 1) * exp(1) .* exp( -b_backTrans .* t./(n_backTrans-1) )).^(n_backTrans-1);                      
                end                
            else
                % If the lower limit to an exponential response function
                % has not been defined, the set it to 100 years prior to the start
                % of the forcing data record.
                if isnan(obj.settings.t_limit)                    
                    obj.settings.t_limit = max(t)+365*100;                                    
                end    
                obj.settings.weight_at_limit = obj.settings.t_limit.^(n_backTrans-1) .* exp( -b_backTrans .* obj.settings.t_limit );                               

                % Calculate the integral from t=0 to weight_at_limit. This
                % is used to normalise the weights by the integral. This is
                % undertaken to minimise the covariance of parameters b and
                % n with A.
                %integral0toInf = 1./(1-obj.settings.weight_at_limit) .* (gamma(n_backTrans)./(b_backTrans^n_backTrans) .* (gammainc(0 ,n_backTrans ,'upper') - gammainc(b_backTrans .* obj.settings.t_limit ,n_backTrans ,'upper')) - obj.settings.weight_at_limit.* obj.settings.t_limit);
                
                % Calculate the weighting function with the weight at the
                % limit subtracted and rescaled to between zero and one and
                % then multiplied by A.
                %result = A_backTrans./(integral0toInf.*(1-obj.settings.weight_at_limit)) .* ( t.^(n_backTrans-1) .* exp( -b_backTrans .* t ) - obj.settings.weight_at_limit);
                result = A_backTrans./(1-obj.settings.weight_at_limit) .* ( t.^(n_backTrans-1) .* exp( -b_backTrans .* t ) - obj.settings.weight_at_limit);
            end
            
            % Set theta at first time point to zero. NOTE: the first time
            % point is more accuratly estimated by intTheta_lowerTail().
            result(t==0,:) = 0;
        end   
        
        function [result, A_backTrans] = theta_normalised(obj, t)
            % Get non-normalised theta result
            result = theta(obj, t);
            
            % Back transform 'A'
            A_backTrans = 10^(obj.A);
            
            % Normalised result by dividing theta by A_backTrans (ir peak
            % value)
            result  = result ./ A_backTrans;
        end
            
        % Calculate integral of impulse-response function from t to inf.
        % This is used to minimise the impact from a finit forcign data
        % set.
        function result = intTheta_upperTail2Inf(obj, t)           

            % Back-transform parameter 'n' from natural log domain to
            % non-transformed domain. This transformation of n was
            % undertaken because ocassionally the optimal value of n was
            % very large eg 200. By transforming it as below, such large
            % values do not occur in the transformed domain and this allows
            % for a greater parameter range to be more easily accessed by
            % the gradient based calibration.
            n_backTrans = 10^(obj.n);    
            
            % Back transform 'b'
            b_backTrans = 10^(obj.b);
            
            % Back transform 'A'
            A_backTrans = 10^(obj.A);            
            
            % If n>1, then theta will have a value of 't' at which the
            % gradient is zero. By putting this value of 't' into theta
            % then value at the peak can be determined. 
            if n_backTrans>1
                t_peak = (n_backTrans - 1)/b_backTrans;
                theta_peak =  t_peak^(n_backTrans-1) * exp( -b_backTrans * t_peak );
                
                if any(isinf(theta_peak))
                      theta_peak = ( (n_backTrans - 1)/b_backTrans * exp(-1))^(n_backTrans-1);
                end                

                result = A_backTrans .* gamma(n_backTrans )./ ( b_backTrans^n_backTrans .* theta_peak) .* (gammainc(b_backTrans .* t ,n_backTrans ,'upper') - gammainc(b_backTrans .* inf ,n_backTrans ,'upper'));
                
            else
                
                % The lower limit to an exponential response function
                % should have been defined prior in a call to theta().
                if isnan(obj.settings.t_limit) || isnan(obj.settings.weight_at_limit)
                    error('When "exp(obj.n) - 1<1", the method "theta()" must be called prior to "intTheta()" so that the lower time limit can be set.')
                end                   
                delta_t_to_limit = obj.settings.t_limit - t;
                result = A_backTrans ./(1-obj.settings.weight_at_limit) .* (gamma(n_backTrans)./(b_backTrans^n_backTrans) .* (gammainc(b_backTrans .* t ,n_backTrans ,'upper') - gammainc(b_backTrans .* obj.settings.t_limit ,n_backTrans ,'upper')) - obj.settings.weight_at_limit.*delta_t_to_limit);
            end
            
            % Trials indicated that when tor (ie t herein) is very large,
            % result can equal NaN.            
            if any(isnan(result) | isinf(result))
                result(:)=NaN;                
            end                               
            
        end 
        
        % Numerical integration of impulse-response function from 0 to 1.
        % This is undertaken to ensure the first time step is accuratly
        % estimated.
        function result = intTheta_lowerTail(obj, t)           

            % Back-transform parameter 'n' from natural log domain to
            % non-transformed domain. This transformation of n was
            % undertaken because ocassionally the optimal value of n was
            % very large eg 200. By transforming it as below, such large
            % values do not occur in the transformed domain and this allows
            % for a greater parameter range to be more easily accessed by
            % the gradient based calibration.
            n_backTrans = 10^(obj.n);    
            
            % Back transform 'b'
            b_backTrans = 10^(obj.b);
            
            % Back transform 'A'
            A_backTrans = 10^(obj.A);            
            
            % If n>1, then theta will have a value of 't' at which the
            % gradient is zero. By putting this value of 't' into theta
            % then value at the peak can be determined. 
            if n_backTrans>1
                t_peak = (n_backTrans - 1)/b_backTrans;
                theta_peak =  t_peak^(n_backTrans-1) * exp( -b_backTrans * t_peak );
                
                % Recalculate theta_peak in a way to minimise rounding
                % errors.
                if any(isinf(theta_peak))
                      theta_peak = ( (n_backTrans - 1)/b_backTrans * exp(-1))^(n_backTrans-1);
                end                

                result = A_backTrans .* gamma(n_backTrans )./ ( b_backTrans^n_backTrans .* theta_peak) .* (gammainc(0 ,n_backTrans ,'upper') - gammainc(b_backTrans .* t ,n_backTrans ,'upper'));

                % If theta_peak still equals inf, then the integral from
                % 0-1 can be approximated as 0. To achieve this,                 
                if any(isnan(result))
                    filt = isinf(theta_peak);
                    result(filt) = 0;
                end
                
            else
                
                % The lower limit to an exponential response function
                % should have been defined prior in a call to theta().
                if isnan(obj.settings.t_limit) || isnan(obj.settings.weight_at_limit)
                    error('When "exp(obj.n) - 1<1", the method "theta()" must be called prior to "intTheta()" so that the lower time limit can be set.')
                end                   
                                
                % NOTE: As t -> 0, t^(n_backTrans-1) -> Inf. This can cause
                % the integral of the lower tail (it t from 0 to 1 day) to
                % be exceeding large when n_backTrans<0 (ie decaying
                % exponential like function).  This can cause the
                % contribution from climate to be implausible and (at least
                % for the Clydebank built in expamle) can cause the pumping
                % componant to produce S<=10-6. To address this weakness,
                % the following excludes the first 1 hour from the
                % integration of the lower tail and the rescales it to the 
                % duration of the input t.
                t_to_omit =  1/24;
                result_to_omit = A_backTrans./(1-obj.settings.weight_at_limit) .* (gamma(n_backTrans )./ ( b_backTrans^n_backTrans) .* (gammainc(0 ,n_backTrans ,'upper') - gammainc(b_backTrans .* t_to_omit ,n_backTrans ,'upper')) - obj.settings.weight_at_limit.*t_to_omit);
                result = A_backTrans./(1-obj.settings.weight_at_limit) .* (gamma(n_backTrans )./ ( b_backTrans^n_backTrans) .* (gammainc(0 ,n_backTrans ,'upper') - gammainc(b_backTrans .* t ,n_backTrans ,'upper')) - obj.settings.weight_at_limit.*t);
                result = (result - result_to_omit)./(t - t_to_omit);
                result = zeros(size(t));
            end
            
            % TEMP: CHECK integral using trapz
            % NOTE: As n approaches zero, theta(0) approaches inf. Trapz
            % integration of such a function produces a poor numerical estimate.
%              t_0to1 = 10.^([-100:0.0001:0])';
%              theta_0to1 = theta(obj, t_0to1);
%              result_trapz = trapz(t_0to1, theta_0to1);
%             if abs(result_trapz - result) > abs(0.05*result);
%                 display(['Pearsons tail integration error. Analytical est:', num2str(result),' Trapz:', num2str(result_trapz)]);
%             elseif( isnan(result) || isinf(abs(result)))
%                     display('Pearsons tail integration error (inf or NAN)');
%                 
%             end
            
        end
        
        % Transform the estimate of the response function * the forcing.
        function result = transform_h_star(obj, h_star_est)
           result = h_star_est(:,end);
        end   
        
        % Return the derived lag time (ie peak of function)
        function [params, param_names] = getDerivedParameters(obj)
        
            % Back-transform parameter 'n' from natural log domain to
            % non-transformed domain. This transformation of n was
            % undertaken because ocassionally the optimal value of n was
            % very large eg 200. By transforming it as below, such large
            % values do not occur in the transformed domain and this allows
            % for a greater parameter range to be more easily accessed by
            % the gradient based calibration.
            n_backTrans = 10.^(obj.n);    
            
            % Back transform 'b'
            b_backTrans = 10.^(obj.b);
                        
            % If n>1, then theta will have a value of 't' at which the
            % gradient is zero. By putting this value of 't' into theta
            % then value at the peak can be determined. 
            t_peak = zeros(size(n_backTrans));
            theta_peak = zeros(size(n_backTrans));
            filt = n_backTrans>1;
            t_peak(filt) = (n_backTrans(filt) - 1)./b_backTrans(filt);
            theta_peak(filt) =  t_peak(filt).^(n_backTrans(filt)-1) .* exp( -b_backTrans(filt) .* t_peak(filt) );
                        
            params = theta_peak;
            param_names = {'Lag time from input to head (days)'};
            
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

