classdef responseFunction_Hantush < responseFunction_FerrisKnowles
% Pearson's type III impulse response transfer function class. 

    properties(GetAccess=public, SetAccess=protected)
        gamma
    end

    methods(Static)    

        function modelDescription = modelDescription()
           modelDescription = {'Name: responseFunction_FerrisKnowles', ...
                               '', ...               
                               'Purpose: simulation of pumping drawdown using the Hantush instantaneous drawdown function for a leaky aquifer.', ...
                               '', ...                               
                               'Number of parameters: 3', ...
                               '', ...                               
                               'Options: Recharge or no-flow boundary conditions.', ...
                               '', ...                               
                               'References: ', ...
                               '1. Hantush MS (1956) Analysis of data from pumping tests in leaky aquifers. Transactions American Geophysical Union 37: 702-714', ...
                               '2. Shapoori V., Peterson T.J., Western A.W., Costelloe J.F, (in-review) Decomposing groundwater head variations', ...
                               'into climate and pumping components: a synthetic study, Hydrogeology Journal.'};

        end           
    end    

%%  PUBLIC METHODS     
    methods
        % Constructor
        function obj = responseFunction_Hantush(bore_ID, forcingDataSiteID, siteCoordinates, options, params)
            
            % Use inheritence to construct Ferris Knowles and Jacobs correction objects.
            obj = obj@responseFunction_FerrisKnowles(bore_ID, forcingDataSiteID, siteCoordinates, options);
            
            % Define default parameters 
            if nargin==4
                obj.gamma=0.1;
            end
                
            % Set parameters for transfer function.
            %setParameters(obj, params)                 
        end
       
        % Set parameters
        function setParameters(obj, params)
            if size(params,1)==3
                setParameters@responseFunction_FerrisKnowles(obj, params(1:2,:));                        
                obj.gamma = params(3,:);            
            elseif size(params,1)==2
                setParameters@responseFunction_FerrisKnowles(obj, params(1:2,:));                        
            end
        end
        
        % Get model parameters
        function [params, param_names] = getParameters(obj)
            [params, param_names] = getParameters@responseFunction_FerrisKnowles(obj);
            params(3,:) = obj.gamma;       
            param_names{3,1} = 'gamma';
        end        
        
        function isValidParameter = getParameterValidity(obj, params, param_names)
            % Initialise output.
            isValidParameter = true(size(params));
            
            alpha_filt =  strcmp('alpha',param_names);
            beta_filt =  strcmp('beta',param_names);
            gamma_filt =  strcmp('gamma',param_names);
            
            alpha = params(alpha_filt,:);
            beta = params(beta_filt,:);
            gamma = params(gamma_filt,:);
            
            % Calculate T, leakage and S.
            T= 1./(4.*pi.*10.^alpha);
            S= 4 .* 10.^beta .* T;    
            Leakage = 1./(S .* 10.^gamma);            
                        
            % Get physical bounds.
            [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj);

            % Check gamma is within bounds.
            isValidParameter = repmat(S >=0 & S <1 & T>= 0,size(params,1),1) & ...
            params >= params_lowerLimit(1:size(params,1),ones(1,size(params,2))) & ...
            params <= params_upperLimit(1:size(params,1),ones(1,size(params,2)));       

        end

        % Return fixed upper and lower bounds to the parameters.
        function [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj)
            [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit@responseFunction_FerrisKnowles(obj);
            params_upperLimit(3,1) = inf;
            params_lowerLimit(3,1) = -inf;
        end        
        
        % Return fixed upper and lower plausible parameter ranges. 
        % This is used to define reasonable range for the initial parameter sets
        % for the calibration. These parameter ranges are only used in the 
        % calibration if the user does not input parameter ranges.
        function [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(obj)
            [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit@responseFunction_FerrisKnowles(obj);
            params_upperLimit(3,1) = 10;
            params_lowerLimit(3,1) = -10;                        
        end        
        
        % Calculate impulse-response function.
        function result = theta(obj, t)           
            
            % Loop though each production bore and, if image wells exist,
            % account for them in the drawdown.
            result = zeros(size(t,1),size(obj.settings.pumpingBores,1));
            for i=1: size(obj.settings.pumpingBores,1)
                % Calc. distance to obs well.
                pumpDistancesSqr = (obj.settings.obsBore.Easting - obj.settings.pumpingBores{i,1}.Easting).^2 ...
                    + (obj.settings.obsBore.Northing - obj.settings.pumpingBores{i,1}.Northing).^2;
                
                if isfield(obj.settings.pumpingBores{i,1},'imageBoreID')

                    % Calculate the distance to each image bore.
                    imageDistancesSqr = (obj.settings.obsBore.Easting - obj.settings.pumpingBores{i,1}.imageBoreEasting).^2 ...
                    + (obj.settings.obsBore.Northing - obj.settings.pumpingBores{i,1}.imageBoreNorthing).^2;
                    
                    imageWellMultiplier=zeros(size(obj.settings.pumpingBores{i,1}.imageBoreType,1),1);
                    
                    % create filter for recharge image wells
                    filt =  cellfun(@(x)strcmp(x,'Recharge'),obj.settings.pumpingBores{i,1}.imageBoreType);
                    imageWellMultiplier(filt)= 1;
                    
                    % create filter for no flow image wells
                    filt =  cellfun(@(x)strcmp(x,'No flow'),obj.settings.pumpingBores{i,1}.imageBoreType);
                    imageWellMultiplier(filt)= -1;
    
                    % Calculate the drawdown from the production well plus
                    % the influence from each image well.
                    result(:,i) = bsxfun(@plus, - 10.^obj.alpha./t.*exp( -10.^obj.beta * (pumpDistancesSqr./t) - 10.^obj.gamma .* t ), ...
                        sum(bsxfun(@times, imageWellMultiplier' , bsxfun(@times, 10^obj.alpha./t , exp( bsxfun(@plus, -10^obj.beta * bsxfun(@rdivide,imageDistancesSqr',t),-10.^obj.gamma.*t)))),2));
                else                    
                    result(:,i) = - 10.^obj.alpha./t.*exp( -10.^obj.beta * (pumpDistancesSqr./t) - 10.^obj.gamma .* t );
                end
            end  
            
            % Set theta at first time point to zero. NOTE: the first time
            % point is more accuratly estimated by intTheta_lowerTail().
            result(t==0,:) = 0;     
            
        end    
        
        
        % Calculate integral of impulse-response function from t to inf.
        % This is used to minimise the impact from a finit forcign data
        % set.
        % TODO: IMPLEMENTED integral of theta
        function result = intTheta_upperTail2Inf(obj, t)                       
            result = zeros(size(obj.settings.pumpingBores,1),1); 
        end   

        % Nuemrical integration of impulse-response function from 0 to 1.
        % This is undertaken to ensure the first time step is accuratly
        % estimated. This was found to be important for highly transmissive aquifers.
        function result = intTheta_lowerTail(obj, t)     
            
            % Calculate Theta at 1 minute time steps.
            delta_t = 1/(60*24);
            t_0to1 = [eps():delta_t:t]';
            theta_0to1 = theta(obj, t_0to1);
            
            % Undertake Simpson's 3/8 composite integratraion for 1 minute
            % time steps.            
            result = 3*delta_t/8 .* (theta_0to1(1,:) + sum(3.*theta_0to1([2:3:end-3],:) +3.*theta_0to1([3:3:end-2],:) + 2.*theta_0to1([4:3:end-1],:),1) + theta_0to1(end,:));
            
        end
        
        % Extract the estimates of aquifer properties from the values of
        % alpha, beta and zeta.
        function [T,S, Leakage] = get_AquiferProperties(obj)    

            T= 1./(4.*pi.*10.^obj.alpha);
            S= 4 .* 10.^obj.beta .* T;    
            Leakage = 1./(S .* 10.^obj.gamma);            

        end   
        
        function [params, param_names] = getDerivedParameters(obj)            
            T= 1./(4.*pi.*10.^obj.alpha);
            S= 4 .* 10.^obj.beta .* T;    
            Leakage = 1./(S .* 10.^obj.gamma);       
            
            params = [T;S; Leakage];
            param_names = {'Transmissivity (Head units^2/day)'; 'Storativity'; 'Leakage Param.'};
        end             
        

        function derivedData_types = getDerivedDataTypes(obj)
            derivedData_types = cell(size(obj.settings.pumpingBores,1),1);
            for i=1:size(obj.settings.pumpingBores,1)
                derivedData_types{i,1} = [obj.settings.pumpingBores{i,1}.BoreID,' weighting'];
            end
        end        
        
        % Return the theta values for the GUI 
        function [derivedData, derivedData_names] = getDerivedData(obj,derivedData_variable,t,axisHandle)
           
            % Find which bore to extract data for.
            ind = [];
            for i=1:size(obj.settings.pumpingBores,1)
                if strcmp([obj.settings.pumpingBores{i,1}.BoreID,' weighting'], derivedData_variable)
                    ind = i;
                    break;
                end                
            end            
            if isempty(ind)
                error(['The following derived variable could not be found:',derivedData_variable]);
            end
            
            [params, param_names] = getParameters(obj);
            nparamSets = size(params,2);
            setParameters(obj,params(:,1));
            derivedData_tmp = theta(obj, t);
            if nparamSets >1
                derivedData = zeros(size(derivedData_tmp,1), nparamSets );                
                derivedData(:,1) = derivedData_tmp(:,ind);
                for i=2:nparamSets 
                    setParameters(obj,params(:,i));
                    derivedData_tmp = theta(obj, t);
                    derivedData(:,i) = derivedData_tmp(:,ind);
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
                
                ind = find(abs(derivedData_prctiles(:,4)) > max(abs(derivedData_prctiles(:,4)))*0.05,1,'last');
                if isempty(ind);
                    ind = length(t);
                end                
                xlim(axisHandle, [1, t(ind)]);
                                                
                % Add legend
                legend(axisHandle, '5-95th%ile','10-90th%ile','25-75th%ile','median','Location', 'northeastoutside');   
                
                % Add data column names
                derivedData_names = cell(nparamSets+1,1);
                derivedData_names{1,1}='Time lag (days)';
                derivedData_names(2:end,1) = strcat(repmat({'Weight-Parm. Set '},1,nparamSets )',num2str([1:nparamSets ]'));                
                
                derivedData =[t,derivedData];
            else
                plot(axisHandle, t,derivedData_tmp(:,ind),'-b');      
                t_ind = find(abs(derivedData_tmp(:,ind)) > max(abs(derivedData_tmp(:,ind)))*0.05,1,'last');
                if isempty(ind);
                    ind = length(t);
                end
                xlim(axisHandle, [1, t(ind)]);
                
                derivedData_names = {'Time lag (days)','Weight'};
                derivedData =[t,derivedData_tmp(:,ind) ];
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

