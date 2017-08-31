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
        function [modelSettings, colNames, colFormats, colEdits,tooltipString] = modelOptions(bore_ID, forcingDataSiteID, siteCoordinates)
           modelSettings = {};
           colNames = {};
           colFormats = {};
           colEdits = [];       
           tooltipString='';
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
            obj.alpha = params(1,:);
            obj.beta = params(2,:);
            obj.gamma = params(3,:);            
        end
        
        % Get model parameters
        function [params, param_names] = getParameters(obj)
            params(1,:) = obj.alpha;
            params(2,:) = obj.beta;
            params(3,:) = obj.gamma;       
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
            
            % Set theta at first time point to zero. NOTE: the first time
            % point is more accuratly estimated by intTheta_lowerTail().
            result(t==0,:) = 0;
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
           result = h_star_est(:,end);
        end     
        
        % Return the derived variables.
        function [params, param_names] = getDerivedParameters(obj)
            params = [];
            param_names = cell(0,2);
        end
      

        function derivedData_types = getDerivedDataTypes(obj)
           
            derivedData_types = 'weighting';
            
        end
        
        % Return the theta values for the GUI 
        function [derivedData, derivedData_names] = getDerivedData(obj,derivedData_variable,t,axisHandle)
           
            [params, param_names] = getParameters(obj);
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
                
                ind = find(abs(derivedData_prctiles(:,4)) > max(abs(derivedData_prctiles(:,4)))*0.01,1,'last');
                if isempty(ind);
                    ind = length(t);
                end                
                xlim(axisHandle, [1, t(ind)]);
                
                % Add legend
                legend(axisHandle, '5-95th%ile','10-90th%ile','25-75th%ile','median','Location', 'northeastoutside');   
                
                % Add data column names
                derivedData =[t,derivedData];
                derivedData_names = cell(nparamSets+1,1);
                derivedData_names{1,1}='Time lag (days)';
                derivedData_names(2:end,1) = strcat(repmat({'Weight-Parm. Set'},1,nparamSets )',num2str([1:nparamSets ]'));                
            else
                plot(axisHandle, t,derivedData_tmp,'-b');                                   
                ind = find(abs(derivedData_tmp) > max(abs(derivedData_tmp))*0.05,1,'last');
                if isempty(ind);
                    ind = length(t);
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

