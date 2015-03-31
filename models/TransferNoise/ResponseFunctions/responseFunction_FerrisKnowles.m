classdef  responseFunction_FerrisKnowles < responseFunction_abstract
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
        
        function [options, colNames, colFormats, colEdits] = modelOptions(bore_ID, forcingDataSiteID, siteCoordinates)

            % Get list of site IDs
            siteIDs = siteCoordinates{:,1}';
                        
            % Reshape to be one row.
            forcingDataSiteID = reshape(forcingDataSiteID, 1, length(forcingDataSiteID));            
            
            % No optins are pre-set
            options = {};
        
            % Assign format of table for GUI.
            colNames = {'Select' 'Pumping Bore ID', 'Image Bore ID', 'Image Bore Type'};
            colFormats = {'logical', forcingDataSiteID, siteIDs, {'Recharge','No flow'}};
            colEdits = logical([1 1 1 1]);
            
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

                % Check that the options is a cell object of Nx3
                if ~isempty(options) && (~iscell(options) || size(options,2) ~=3)
                    error('The input data for image wells but be a Nx3 cell array where for each row the left column contains a production bore ID, the centre column an image well ID and the right column the options "No flow" or "Recharge".');
                end                
                
                % Get the list of available options
                [columns, cellFormat] = responseFunction_FerrisKnowles.responseFunction_optionsFormat();

                % Extract the available types of image wells.
                availableImageTypes = cellFormat{end};
                
                % Check the image well type is valid.
                for i=1:nOptions
                    filt = cellfun(@(x)strcmp(x,options(i,3)),availableImageTypes);
                    if ~any(filt);
                        error('The image well types specified within the third column of the input options cell array can only be "Recharge" or "No flow".'); 
                    end
                end
                
                % Check the first column contains only production bore IDs and
                % the second column does not contain production bore IDs (or obs bore ID). 
                for i=1:nOptions
                    % Check the left column ID is a forcingDataSiteID
                    isSiteIDError = true;
                    for j=1: nForcingSites                    
                        if strcmp(forcingDataSiteID(j), options(i,1))
                            isSiteIDError = false;                        
                        elseif strcmp(bore_ID, options(i,1))
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
                        if strcmp(forcingDataSiteID(j), options(i,2)) ...
                        || strcmp(bore_ID, options(i,2))                            
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
                for j=1:size(obj.settings.pumpingBores,1);
                    
                    filt = cellfun(@(x)strcmp(x,obj.settings.pumpingBores{j,1}.BoreID),options(:,1));
                    if any(filt)
                        obj.settings.pumpingBores{j,1}.imageBoreID = options(filt,2);
                        obj.settings.pumpingBores{j,1}.imageBoreType =  options(filt,3);                    
                    end
                end
                
                % Now cycle though each production bore and get the
                % coordinates for each image well.
                for i=1:size(obj.settings.pumpingBores,1);                                                            
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
            
            % Define default parameters 
            if nargin==4
                params=[log10(1e-4); log10(0.01)];
            end
               
            % Set parameters for transfer function.
            setParameters(obj, params)                 
        end
        
         % Set parameters
        function setParameters(obj, params)
            obj.alpha = params(1);
            obj.beta = params(2);        
        end
        
        % Get model parameters
        function [params, param_names] = getParameters(obj)
            params(1,1) = obj.alpha;
            params(2,1) = obj.beta;    
            param_names = {'alpha';'beta'};
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
            isValidParameter = repmat(S >=0 & S <1 & T>= 0,size(params,1),1) & ...
            params >= params_lowerLimit(1:size(params,1),ones(1,size(params,2))) & ...
            params <= params_upperLimit(1:size(params,1),ones(1,size(params,2)));            
        end
        
        % Return fixed upper and lower bounds to the parameters.
        function [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj)
            params_upperLimit = inf(2,1);
            params_lowerLimit = [log10(sqrt(eps())); log10(eps())];
        end        
        
        % Return fixed upper and lower plausible parameter ranges. 
        % This is used to define reasonable range for the initial parameter sets
        % for the calibration. These parameter ranges are only used in the 
        % calibration if the user does not input parameter ranges.
        function [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(obj)
            params_upperLimit = [log10(0.01); log10(1)-5];
            params_lowerLimit = [log10(sqrt(eps())); log10(sqrt(eps()))-5];
        end
        
        % Calculate impulse-response function for each pumping bore.
        function result = theta(obj, t)     
            % Loop though each production bore and, if image wells exist,
            % account for them in the drawdown.
            result = zeros(size(t,1),size(obj.settings.pumpingBores,1));
            for i=1: size(obj.settings.pumpingBores,1)
                % Calc. distance to obs well.
                pumpDistances = sqrt((obj.settings.obsBore.Easting - obj.settings.pumpingBores{i,1}.Easting).^2 ...
                    + (obj.settings.obsBore.Northing - obj.settings.pumpingBores{i,1}.Northing).^2);
                
                if isfield(obj.settings.pumpingBores{i,1},'imageBoreID')

                    % Calculate the distance to each image bore.
                    imageDistances = sqrt((obj.settings.obsBore.Easting - obj.settings.pumpingBores{i,1}.imageBoreEasting).^2 ...
                    + (obj.settings.obsBore.Northing - obj.settings.pumpingBores{i,1}.imageBoreNorthing).^2);
                    
                    imageWellMultiplier=zeros(size(obj.settings.pumpingBores{i,1}.imageBoreType,1),1);
                    
                    % create filter for recharge image wells
                    filt =  cellfun(@(x)strcmp(x,'Recharge'),obj.settings.pumpingBores{i,1}.imageBoreType);
                    imageWellMultiplier(filt)= 1;
                    
                    % create filter for no flow image wells
                    filt =  cellfun(@(x)strcmp(x,'No flow'),obj.settings.pumpingBores{i,1}.imageBoreType);
                    imageWellMultiplier(filt)= -1;
    
                    % Calculate the drawdown from the production well plus
                    % the influence from each image well.
                    result(:,i) = bsxfun(@plus, - 10^obj.alpha./t.* exp(-10^obj.beta * (pumpDistances^2./t)), ...
                        sum(bsxfun(@times, imageWellMultiplier' , bsxfun(@times, 10^obj.alpha./t , exp(-10^obj.beta * bsxfun(@rdivide,imageDistances'.^2,t)))),2));
                else
                    result(:,i) = - 10^obj.alpha./t.* exp(-10^obj.beta * (pumpDistances^2 ./t));
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
                pumpDistances = sqrt((obj.settings.obsBore.Easting - obj.settings.pumpingBores{i,1}.Easting).^2 ...
                    + (obj.settings.obsBore.Northing - obj.settings.pumpingBores{i,1}.Northing).^2);
                
                if isfield(obj.settings.pumpingBores{i,1},'imageBoreID')

                    % Calculate the distance to each image bore.
                    imageDistances = sqrt((obj.settings.obsBore.Easting - obj.settings.pumpingBores{i,1}.imageBoreEasting).^2 ...
                    + (obj.settings.obsBore.Northing - obj.settings.pumpingBores{i,1}.imageBoreNorthing).^2);
                    
                    imageWellMultiplier=zeros(size(obj.settings.pumpingBores{i,1}.imageBoreType,1),1);
                    
                    % create filter for recharge image wells
                    filt =  cellfun(@(x)strcmp(x,'Recharge'),obj.settings.pumpingBores{i,1}.imageBoreType);
                    imageWellMultiplier(filt)= 1;
                    
                    % create filter for no flow image wells
                    filt =  cellfun(@(x)strcmp(x,'No flow'),obj.settings.pumpingBores{i,1}.imageBoreType);
                    imageWellMultiplier(filt)= -1;
    
                    % Calculate the drawdown from the production well plus
                    % the influence from each image well.
                    result(i) = - 10^obj.alpha * expint(10^obj.beta * (pumpDistances^2./t)) ...
                                 + sum( imageWellMultiplier' .* 10^obj.alpha.* expint(10^obj.beta * ((imageDistances').^2./t) ));
                else
                    result(i) = - 10^obj.alpha.* expint(10^obj.beta * (pumpDistances^2./t));
                end

            end              
        end
                
        % Transform the estimate of the response function * the forcing.
        function result = transform_h_star(obj, h_star_est)           
           result = h_star_est(:,2);           
        end   
        
        % Extract the estimates of aquifer properties from the values of
        % alpha, beta and gamma.
        function [T,S] = get_AquiferProperties(obj)
            T= 1/(4*pi*10^obj.alpha);
            S= 4 * 10^obj.beta * T;            
        end
    end
end