classdef  responseFunction_FerrisKnowles < responseFunction_abstract & dynamicprops
% Pearson's type III impulse response transfer function class. 

    properties(GetAccess=public, SetAccess=protected)          
        alpha
        beta
        settings
    end

%%  STATIC METHODS        
% Static methods used by the Graphical User Interface to inform the
% user of the available model types. Any new models must be listed here
% in order to be accessable within the GUI.    
    methods(Static)    
        
        function options = modelOptions(bore_ID, forcingDataSiteID, siteCoordinates)

            % Build model options
            options{1} = modelOptions();
            options{2} = modelOptions();
            
            % Get list of site IDs
            if istable(siteCoordinates)
                siteIDs = siteCoordinates{:,1}';
            else
                siteIDs = siteCoordinates(:,1)';
            end
                        
            % Reshape to be one row.
            forcingDataSiteID = reshape(forcingDataSiteID, 1, length(forcingDataSiteID));            
        
            % Assign format of table for GUI.
            options{1}.label = 'Image wells';
            options{1}.colNames ={'Select' 'Pumping Bore ID', 'Image Bore ID', 'Image Bore Type'};
            options{1}.colFormats = {'logical', forcingDataSiteID, siteIDs, {'Recharge','No flow'}};
            options{1}.colEdits = logical([1 1 1 1]);  
            options{1}.options = {false,'','',''};
            options{1}.TooltipString = ['<html>Use this table to set image wells. Note, the coordinate. <br>', ...
                             'of the boundary must listed within the coordinates input file.'];            

            options{2}.label = 'Radius of influence';
            options{2}.colNames = {'Setting name','Setting value'};
            options{2}.colFormats = {'char', {'true','false'}};
            options{2}.colEdits = logical([0 1]);            
            options{2}.options = {'Calibrated radius of influence?','false';'Calibrate anisotropic ratio?','false'};
            options{2}.TooltipString =['<html>Use this table to calibrate the radius of influence. Note,  <br>', ...
                             'pumps outside of the radus will produce zero drawdown at the obs. bore.'];            
                         
        end    
        
        function modelDescription = modelDescription()
           modelDescription = {'Name: responseFunction_FerrisKnowles', ...
                               '', ...               
                               'Purpose: simulation of pumping drawdown using the Ferris Knowles instantaneous drawdown function (ie Theis drawdown for a confined aquifer).', ...
                               '', ...               
                               'Number of parameters: 2', ...
                               '', ...               
                               'Options: Recharge or no-flow boundary conditions.', ...
                               '', ...               
                               'References: ', ...
                               '1. Ferris JG, Knowles DB (1963) The slug-injection test for estimating the coefficient of transmissibility of an aquifer. ', ...
                               'In: Bentall R (ed) Methods of determining permeability, transmissibility, and drawdown. U.S.Geological Survey', ...
                               '2. Shapoori V., Peterson T.J., Western A.W., Costelloe J.F, (in-review) Decomposing groundwater head variations', ...
                               'into climate and pumping components: a synthetic study, Hydrogeology Journal.'};

        end           
    end

%%  PUBLIC METHODS      
    methods
        % Constructor
        function obj = responseFunction_FerrisKnowles(bore_ID, forcingDataSiteID, siteCoordinates, options, params)
            
            % Get the obs bore easting and northing.
            filt = cellfun(@(x)strcmp(x,bore_ID),siteCoordinates(:,1));
            obj.settings.obsBore.BoreID = bore_ID;
            obj.settings.obsBore.Easting = siteCoordinates{filt,2};
            obj.settings.obsBore.Northing = siteCoordinates{filt,3};
                                          
            % Get the number of pumping bores and loop through each to get
            % their easting and northing.               
            if iscell(forcingDataSiteID)
                nForcingSites = length(forcingDataSiteID);
            else
                nForcingSites=1;
                forcingDataSiteID = {forcingDataSiteID};
            end
            for j=1:nForcingSites;
                
              filt = cellfun(@(x)strcmp(x,forcingDataSiteID(j)),siteCoordinates(:,1));
              obj.settings.pumpingBores{j,1}.BoreID = siteCoordinates{filt,1};
              obj.settings.pumpingBores{j,1}.Easting = siteCoordinates{filt,2};
              obj.settings.pumpingBores{j,1}.Northing = siteCoordinates{filt,3};
            end
                        
            % Set the image well options.
            nOptions = size(options,1);
            if nOptions>0
                
                % Get the list of available options
                defaultOptions = responseFunction_FerrisKnowles.modelOptions(bore_ID, forcingDataSiteID, siteCoordinates);                

                % Check that the options is a cell object of Nx3
                if ~isempty(options) && (length(options) ~= length(defaultOptions))
                    error('The input options is inconsistent with that for responseFunction_FerrisKnowles.');
                end                
                                                
                % Extract the available types of image wells.
                availableImageTypes = defaultOptions{1}.colFormats{end};
                
                % Check the image well type is valid.
                for i=1:size(options{1},1)
                    filt = cellfun(@(x)strcmp(x,options{1}(i,3)),availableImageTypes);
                    if ~any(filt)
                        error('The image well types specified within the third column of the input options cell array can only be "Recharge" or "No flow".'); 
                    end
                end
                
                % Check the first column contains only production bore IDs and
                % the second column does not contain production bore IDs (or obs bore ID). 
                for i=1:size(options{1},1)
                    % Check the left column ID is a forcingDataSiteID
                    isSiteIDError = true;
                    for j=1: nForcingSites                    
                        if strcmp(forcingDataSiteID(j), options{1}(i,1))
                            isSiteIDError = false;                        
                        elseif strcmp(bore_ID, options{1}(i,1))
                            isSiteIDError = true;
                            break;
                        end
                    end
                    if isSiteIDError 
                        error('The left column of the input data for image wells must contain only production bore IDs and cannot contain the obs. bore ID.');
                    end

                    % Check the right column ID is a forcingDataSiteID
                    isSiteIDError = false;
                    for j=1: nForcingSites                    
                        if strcmp(forcingDataSiteID(j), options{1}(i,2)) ...
                        || strcmp(bore_ID, options{1}(i,2))                            
                            isSiteIDError = true;
                            break
                        end
                    end
                    if isSiteIDError 
                        error('The right column of the input data for image wells cannot contain production bore IDs or the observation bore ID.');
                    end            
                end
                
                % Cycle through each production bore and get the image well
                % site IDs for the production bore.
                for j=1:size(obj.settings.pumpingBores,1)
                    if ~isempty(options{1})
                        filt = cellfun(@(x)strcmp(x,obj.settings.pumpingBores{j,1}.BoreID),options{1}(:,1));
                        if any(filt)
                            obj.settings.pumpingBores{j,1}.imageBoreID = options{1}(filt,2);
                            obj.settings.pumpingBores{j,1}.imageBoreType =  options{1}(filt,3);
                        end
                    end
                end
                
                % Now cycle though each production bore and get the
                % coordinates for each image well.
                for i=1:size(obj.settings.pumpingBores,1)                                                            
                    if isfield(obj.settings.pumpingBores{i,1},'imageBoreID')
                        % Cycle though each image bore for current production bore and 
                        % find the coordinates.                        
                        nImageBores = size( obj.settings.pumpingBores{i,1}.imageBoreID,1);
                        for j=1:nImageBores                         
                            % Get the image bore easting and northing.
                            filt = cellfun(@(x)(strcmp(x,obj.settings.pumpingBores{i,1}.imageBoreID(j,1))),siteCoordinates(:,1));
                            obj.settings.pumpingBores{i,1}.imageBoreEasting(j,1) = siteCoordinates{filt,2};
                            obj.settings.pumpingBores{i,1}.imageBoreNorthing(j,1) = siteCoordinates{filt,3}; 
                        end
                    end                    
                end
            end
            
            % Set the search radius option
            if ~isempty(options)
                if strcmp(options{2}(1,2),'true')
                    dynPropMetaData{1} = addprop(obj,'searchRadiusFrac');                
                    obj.searchRadiusFrac=0.5;     


                    % Find the maximum distance to pumps 
                    for i=1: size(obj.settings.pumpingBores,1)
                        % Calc. distance to obs well.
                        pumpDistances(i) = sqrt((obj.settings.obsBore.Easting - obj.settings.pumpingBores{i,1}.Easting).^2 ...
                            + (obj.settings.obsBore.Northing - obj.settings.pumpingBores{i,1}.Northing).^2);                
                    end                
                    obj.settings.pumpingBoresMaxDistance = max(pumpDistances);
                end
                if strcmp(options{2}(2,2),'true')
                    dynPropMetaData{2} = addprop(obj,'searchRadiusIsotropicRatio');                
                    obj.searchRadiusIsotropicRatio=0.5;                
                end
            else
                obj.settings.pumpingBoresMaxDistance = inf;                
            end
            
            % Define default parameters 
            if nargin==4
                params=[log10(1e-4); log10(0.01)];
                
                if isprop(obj,'searchRadiusFrac')
                    params=[params; 0.5];
                end
                if isprop(obj,'searchRadiusIsotropicRatio')
                    params=[params; 0.5];
                end
                
            end
               
            % Set parameters for transfer function.
            setParameters(obj, params)                 
        end
        
         % Set parameters
        function setParameters(obj, params)
            obj.alpha = params(1,:);
            obj.beta = params(2,:);        
            if isprop(obj,'searchRadiusFrac')
                obj.searchRadiusFrac = params(3);
            end
            if isprop(obj,'searchRadiusIsotropicRatio')
                obj.searchRadiusIsotropicRatio = params(4);
            end           
        end
        
        % Get model parameters
        function [params, param_names] = getParameters(obj)
            params(1,:) = obj.alpha;
            params(2,:) = obj.beta;    
            param_names = {'alpha';'beta'};

            if isprop(obj,'searchRadiusFrac')
                params(3,:) = obj.searchRadiusFrac; 
                param_names{3} = 'searchRadiusFrac';
            end
            if isprop(obj,'searchRadiusIsotropicRatio')
                params(4,:) = obj.searchRadiusIsotropicRatio; 
                param_names{4} = 'searchRadiusIsotropicRatio';
            end            
        end        
        
        function isValidParameter = getParameterValidity(obj, params, param_names)
            alpha_filt =  strcmp('alpha',param_names);
            beta_filt =  strcmp('beta',param_names);
            
            alpha = params(alpha_filt,:);
            beta = params(beta_filt,:);
            
            % Calculate hydraulic transmissivity and S.
            T= 1./(4.*pi.*10.^alpha);
            S= 4 .* 10.^beta .* T;    
            
            % Get physical bounds.
            [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj);

            % Check parameters are within bounds and T>0 and 0<S<1.
            isValidParameter = repmat(S >=1e-6 & S <1 & T> 0,size(params,1),1) & ...
            params >= params_lowerLimit(1:size(params,1),ones(1,size(params,2))) & ...
            params <= params_upperLimit(1:size(params,1),ones(1,size(params,2)));            
        end
        
        % Return fixed upper and lower bounds to the parameters.
        function [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj)
            params_upperLimit = inf(2,1);
            params_lowerLimit = [log10(sqrt(eps())); log10(eps())];            
            
            if isprop(obj,'searchRadiusFrac')
                params_upperLimit = [params_upperLimit; 1];
                params_lowerLimit = [params_lowerLimit; 0];
            end
            if isprop(obj,'searchRadiusIsotropicRatio')
                params_upperLimit = [params_upperLimit; 1];
                params_lowerLimit = [params_lowerLimit; 0];
            end         
        end        
        
        % Return fixed upper and lower plausible parameter ranges. 
        % This is used to define reasonable range for the initial parameter sets
        % for the calibration. These parameter ranges are only used in the 
        % calibration if the user does not input parameter ranges.
        function [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(obj)
            params_upperLimit = [1; -1];
            params_lowerLimit = [-5; -7];            

            if isprop(obj,'searchRadiusFrac')
                params_upperLimit = [params_upperLimit; 1];
                params_lowerLimit = [params_lowerLimit; 0];
            end
            if isprop(obj,'searchRadiusIsotropicRatio')
                params_upperLimit = [params_upperLimit; 1];
                params_lowerLimit = [params_lowerLimit; 0];
            end                     
        end
        
        % Calculate impulse-response function for each pumping bore.
        function result = theta(obj, t)     
            % Loop though each production bore and, if image wells exist,
            % account for them in the drawdown.
            result = zeros(size(t,1),size(obj.settings.pumpingBores,1));
            for i=1: size(obj.settings.pumpingBores,1)
                % Calc. distance to obs well.
                pumpDistancesSqr = (obj.settings.obsBore.Easting - obj.settings.pumpingBores{i,1}.Easting).^2 ...
                    + (obj.settings.obsBore.Northing - obj.settings.pumpingBores{i,1}.Northing).^2;
                
                if isprop(obj,'searchRadiusFrac')
                   if sqrt(pumpDistancesSqr) > (obj.searchRadiusFrac * obj.settings.pumpingBoresMaxDistance)
                       result(:,i) = 0;
                       continue;
                   end
                end
                
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
                    result(:,i) = 10^obj.alpha./t .* bsxfun(@plus, -exp(-10^obj.beta * (pumpDistancesSqr./t)), ...
                        sum(bsxfun(@times, imageWellMultiplier' , exp(-10^obj.beta * bsxfun(@rdivide,imageDistancesSqr',t))),2));
                else
                    result(:,i) = - 10^obj.alpha./t.* exp(-10^obj.beta * (pumpDistancesSqr ./t));
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
                    result(:,i) = - 10^obj.alpha * expint(10^obj.beta * (pumpDistancesSqr./t)) ...
                                 + sum( imageWellMultiplier' .* 10^obj.alpha.* expint(10^obj.beta * ((imageDistancesSqr')./t) ));
                else
                    result(:,i) = - 10^obj.alpha.* expint(10^obj.beta * (pumpDistancesSqr./t));
                end
                
                % TEMP: CHECK integral using trapz
                % NOTE: As n approaches zero, theta(0) approaches inf. Trapz
                % integration of such a function produces a poor numerical estimate.
                %t_0to1 = 10.^([-10:0.0001:0])';
                %theta_0to1 = theta(obj, t_0to1);
                %result_trapz = trapz(t_0to1, theta_0to1);                
            end              
        end
                
        % Transform the estimate of the response function * the forcing.
        function result = transform_h_star(obj, h_star_est)           
           result = h_star_est(:,2);           
        end   
        
        % Extract the estimates of aquifer properties from the values of
        % alpha, beta and gamma.
        function [params, param_names] = getDerivedParameters(obj)
            T= 1./(4.*pi.*10.^obj.alpha);
            S= 4 .* 10.^obj.beta .* T;            
            
            params = [T;S];
            param_names = {'T : Transmissivity (Head units^2/day)'; 'S : Storativity'};
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
                if isempty(t_ind );
                    t_ind  = length(t);
                end
                xlim(axisHandle, [1, t(t_ind )]);
                
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
