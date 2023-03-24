classdef responseFunction_BarometricConfined < responseFunction_abstract
% Pearson's type III impulse response transfer function class. 

    properties(GetAccess=public, SetAccess=protected)
        b        
        settings 
    end

%%  STATIC METHODS        
% Static methods used by the Graphical User Interface to inform the
% user of the available model options and their input format.
    methods(Static)        
        function options = modelOptions(bore_ID, forcingDataSiteID, siteCoordinates)
            
            options{1} = modelOptions();
            
            % Assign format of table for GUI.
            options{1}.label = 'Parameter bounds';
            options{1}.colNames = {'Parameter Name', 'Lower Physical Bound', 'Upper Physical Bound'};
            options{1}.colFormats = {'char', 'numeric', 'numeric'};
            options{1}.colEdits = logical([0 1 1]);
            options{1}.TooltipString = ['<html>Use this table to set parameter bounds for the calibration. <br>', ...
                             'If weighting the drainage from a soil model and, say, the forcing and <br>', ...
                             'data are in SI units (mm and m respectively), then consider setting <br>', ...
                             'the bounds for parameter A to reflect plausible values of specific yield. <br>', ...
                             'For example, log10(1/(1000*0.1)) &le A &le log10(1/(1000*1e-4)) which equals <br>', ...
                             '-2 &le A &le 1, where 1e-4 &le S &l e0.1'];
                         
            % Default parameter bounds
            params_upperLimit = [inf];
            params_lowerLimit = [log10(sqrt(eps()))];    
            
            options{1}.options = {'b', params_lowerLimit(1), params_upperLimit(1)};
            
                   
        end 
        
        function modelDescription = modelDescription()
           modelDescription = {'Name: responseFunction_BarometricConfined', ...
                               '', ...               
                               'Purpose: simulation of delayed barometric effecst for confined aquifer (ie input of barometric pressure).', ...
                               '', ...               
                               'Number of parameters: 1', ...
                               '', ...               
                               'Options: none', ...
                               '', ...               
                               'References: ', ...
                               '1. Peterson & Western (2014), Nonlinear time-series modeling of unconfined groundwater head, Water Resour. Res., 50, 8330–8355'};
        end        
    end

%%    
    methods
        % Constructor
        function obj = responseFunction_BarometricConfined(bore_ID, forcingDataSiteID, siteCoordinates, options, params)
                        
            % Define default parameters 
            if nargin==4
                params=[log10(1)];
            end                
            
            % Set parameters for transfer function.
            setParameters(obj, params)     
                        
            if ~isempty(options) && iscell(options)  
                obj.settings.params_lowerPhysicalLimit = cell2mat(options(:,2));
                obj.settings.params_upperPhysicalLimit = cell2mat(options(:,3));
            end
        end
       
        % Set parameters
        function setParameters(obj, params)
            obj.b = params(1,:);
        end
        
        % Get model parameters
        function [params, param_names] = getParameters(obj)
            params(1,:) = obj.b;
            param_names = {'b'};        
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
            % NOTE: The upper limit for 'b' is set to that at which
            % exp(-10^b * t) <= sqrt(eps()) where t = 1 day.
                params_lowerLimit = log10(sqrt(eps()));
                params_upperLimit =  log10(10);
        end        
        
        % Return fixed upper and lower plausible parameter ranges. 
        % This is used to define reasonable range for the initial parameter sets
        % for the calibration. These parameter ranges are only used in the 
        % calibration if the user does not input parameter ranges.
        function [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(obj)
            params_upperLimit = log10(1);
            params_lowerLimit = log10(0.001);
        end
        
        % Calculate impulse-response function.
        function result = theta(obj, t)           

            % Calculate well storage effect             
            result = exp( -10.^(obj.b) .* t);                
            
            % Set theta at first time point to zero. NOTE: the first time
            % point is more accuratly estimated by intTheta_lowerTail().
            result(t==0,:) = 0;
        end   
                    
        % Calculate integral of impulse-response function from t to inf.
        % This is used to minimise the impact from a finit forcign data
        % set.
        function result = intTheta_upperTail2Inf(obj, t)           
            result = -theta(obj, t)./10.^(obj.b);
            
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

           result = 1 -theta(obj, t)./10.^(obj.b) ;
            
            % Trials indicated that when tor (ie t herein) is very large,
            % result can equal NaN.            
            if any(isnan(result) | isinf(result))
                result(:)=NaN;                
            end   
        end
        
        % Transform the estimate of the response function * the forcing.
        function result = transform_h_star(obj, h_star_est)
           result = h_star_est(:,end);
        end   
        
        % Return the derived lag time (ie peak of function)
        function [params, param_names] = getDerivedParameters(obj)
            params= 10.^(obj.b);                        
            param_names = {'Bore Storage effect decay rate {L/day]'};            
        end

        function derivedData_types = getDerivedDataTypes(obj)           
            derivedData_types = 'weighting';            
        end
        
        % Return the theta values for the GUI 
        function [derivedData, derivedData_names] = getDerivedData(obj,derivedData_variable,t,axisHandle)
           
            params = getParameters(obj);
            nparamSets = size(params,2);
            setParameters(obj,params(:,1));
            derivedData_tmp = theta(obj, t);            
            if nparamSets >1
                derivedData = zeros(size(derivedData_tmp,1), nparamSets );
                derivedData(:,1) = derivedData_tmp;            
                parfor i=2:nparamSets 
                    setParameters(obj,params(:,i));
                    derivedData(:,i) = theta(obj, t);
                end
                setParameters(obj,params);
                
                % Calculate percentiles
                derivedData_prctiles = prctile( derivedData,[5 10 25 50 75 90 95],2);
                
                % Plot percentiles
                XFill = [t' fliplr(t')];
                YFill = [derivedData_prctiles(:,1)', fliplr(derivedData_prctiles(:,7)')];                   
                fill(XFill, YFill,[0.8 0.8 0.8],'Parent',axisHandle);
                hold(axisHandle,'on');                    
                YFill = [derivedData_prctiles(:,2)', fliplr(derivedData_prctiles(:,6)')];                   
                fill(XFill, YFill,[0.6 0.6 0.6],'Parent',axisHandle);                    
                hold(axisHandle,'on');
                YFill = [derivedData_prctiles(:,3)', fliplr(derivedData_prctiles(:,5)')];                   
                fill(XFill, YFill,[0.4 0.4 0.4],'Parent',axisHandle);                    
                hold(axisHandle,'on');
                clear XFill YFill     

                % Plot median
                plot(axisHandle,t, derivedData_prctiles(:,4),'-b');
                hold(axisHandle,'off');                
                
                ind = find(abs(derivedData_prctiles(:,4)) > max(abs(derivedData_prctiles(:,4)))*0.1,1,'last');
                if isempty(ind) || ind==1
                    ind = length(t);
                end                
                xlim(axisHandle, [1, t(ind)]);
                
                % Add legend
                legend(axisHandle, '5-95th%ile','10-90th%ile','25-75th%ile','median','Location', 'northeastoutside');   
                
                % Add data column names
                derivedData =[t,derivedData];
                derivedData_names = cell(nparamSets+1,1);
                derivedData_names{1,1}='Time lag (days)';
                derivedData_names(2:end,1) = strcat(repmat({'Weight-Parm. Set'},1,nparamSets )',num2str(transpose(1:nparamSets)));                
            else
                plot(axisHandle, t,derivedData_tmp,'-b');                                   
                ind = find(abs(derivedData_tmp) > max(abs(derivedData_tmp))*0.05,1,'last');
                if isempty(ind)
                    ind = length(t);
                elseif ind==1
                    ind = ceil(length(t)*0.05);
                end
                xlim(axisHandle, [1, t(ind)]);
                
                derivedData_names = {'Time lag (days)','Weight'};                
                derivedData =[t,derivedData_tmp ];
            end

            xlabel(axisHandle,'Time lag (days)');
            ylabel(axisHandle,'Weight');            
            box(axisHandle,'on');
            
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

