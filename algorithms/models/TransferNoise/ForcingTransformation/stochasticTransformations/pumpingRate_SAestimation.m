classdef pumpingRate_SAestimation < forcingTransform_abstract 
% Class definition for downscaling groundwater pumping rates.
%
% Description          
%   This class allows the downscaling of infrequent (>daily) groundwater pumping
%   data to daily, weeekly or monthly rates. The downscaling is required when
%   pumping is metered, say, only annually. The downscaling is undertaken by
%   simulating the pump as being either on or off for each user-set downscaling
%   time step. When the period is metered then the number of days pumping is
%   used to estimate the average daily pumping rate. The average of all
%   metered periods is then applied to non-metered periods. This approach 
%   requires no assumption of the behaviour of groudnwater users or their 
%   response to climatic conditions.
%
%   Importantly, the number of combinations of pump state over, say, a decade
%   to assess against the observed head far exceeds the largest number possible
%   on a 64 bit machine. The implications are that the calibration cannot 
%   assess all combinations and that if an identical model is re-calibrated
%   an alternate optima may be identified. To manage this challenge the approach
%   uses simulated annealing (SA); note SA comes from annealing in metallurgy,
%   a technique involving heating and controlled cooling of a material to 
%   increase the size of its crystals and reduce their defects. Further
%   details are availabe in Peterson & Fulton (in-prep).
%   
%   The class allows the downscaling of infrequently metered periods and
%   also the estimation of pumping during periods that were not metered. It
%   is important the >=1 period is however metered so that the
%   calibration can constrain the draw-down parameters (eg T and S). The
%   different metering scenarios are defined from the TFN input forcing
%   data file. Any period that was infrequently metered is defined by -999
%   values in the forcind ata file followed by the total extraction volume
%   over the preceeding perids of -999. Within the same file, and period
%   with no metering is defined by a period of -999 values ending with a
%   zero pumping rate.
%
%   Lastly, the class development of this class required a number of
%   chnages to HydroSight. Please note the following:
%      1. pumpingRate_SAestimation() required considerable changes to the 
%         calibration scheme and is only operational with the SP-UCI. Other
%         calibration schemes will be edited in the future.
%      2. Calibration with an evaluation period required downscaling will 
%         crash when using this componant. Future releases will use the 
%         stochastically derived forcing tiem-series to build a predictive 
%         model for the estimation during evaluation periods.
%      3. This extension to HydroSight was funded by the Department of 
%         Environment, Land, Water and Planning, Victoria.
%         https://delwp.vic.gov.au/
%               
%References: 
%   Peterson & Fulton (in-prep), Estimating aquifer hydraulic properties 
%   from existing groundwater monitoring data.};  
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure Engineering, 
%   The University of Melbourne.
%
% Date:
%   July 2017
%
 
    properties(GetAccess=public, SetAccess=protected)                        
        % NOTE: All parameters are dynamically added
    end

%%  STATIC METHODS        
% Static methods used to inform the
% user of the available model types. 
    methods(Static)
        function [variable_names, isOptionalInput] = inputForcingData_required()
            variable_names = cell(50,1);
            variable_names(1:50) = strrep(strrep(strcat({'Pump '},num2str([1:50]')),' ','_'),'__','_');            
            isOptionalInput = false(50,1);
        end
        
        function [variable_names] = outputForcingdata_options(inputForcingDataColNames)
            variable_names = strrep(strrep(strcat({'Pump '},num2str([1:50]')),' ','_'),'__','_');
        end
        
        function [options, colNames, colFormats, colEdits, toolTip] = modelOptions()
            options = cell(50,4);
            options(:,1) = strrep(strrep(strcat({'Pump '},num2str([1:50]')),' ','_'),'__','_');
            options(:,2) = repmat({'Monthly'},50,1);
            options(:,3) = repmat({1},50,1);
            options(:,4) = repmat({0.95},50,1);
            %options(:,3) = repmat({'Monthly'},50,1);
                    
            colNames = {'Output Pumping Data','Downscaling time-step','Initial Temperature','Cooling rate multipler'};
            colFormats = {'char', {'Daily','Weekly','Fortnightly','Monthly'},'numeric','numeric'};
            colEdits = logical([0 1 1 1]);

            toolTip = sprintf([ 'Use this table to define the method for downscaling time-step \n', ...
                                'and simulated annealing initial temperature and cooling rate.']);
        end
        
        function modelDescription = modelDescription()
           modelDescription = {'Name: pumpingRate_SAestimation', ...
                               '', ...
                               'Purpose: downscaling of infrequent (>daily) groundwater pumping data to daily, weeekly or monthly rates. The downscaling', ...
                               'is required when pumping is metered, say, only annually. The downscaling is undertaken by simulating the pump as being', ...
                               'either on or off for each user-set downscaling time step. When the period is metered then the number of days pumping is', ...
                               'used to estimate the average daily pumping rate. The average of all metered periods is then applied to non-metered periods.', ...
                               'This approach requires no assumption of the behaviour of groudnwater users or their response to climatic conditions', ...
                               '', ...
                               'Importantly, the number of combinations of pump state over, say, a decade to assess against the observed head far exceeds', ...
                               'the largest number possible on a 64 bit machine. The implications are that the calibration cannot assess all combinations', ...
                               'and that if an identical model is re-calibrated an alternate optima may be identified. To manage this challenge the approach', ...
                               'uses simulated annealing (SA); note SA comes from annealing in metallurgy, a technique involving heating and controlled ', ...
                               'cooling of a material to increase the size of its crystals and reduce their defects. For details see the help documentation.', ...
                               '', ...                               
                               'Number of parameters: 0', ...
                               '', ...                               
                               'Options: For each pump the user can set the "Downscaling time-step","Initial Temperature","Cooling rate multipler". Note, a',  ...
                               'daily time step can require >1M model runs. Also, the probability of the claibration findings the best down-scaled forcing', ...
                               'increases as the SA initial temperature is increased and the SA cooling rate is decreased.', ...
                               '', ...                               
                               'Comments: ', ...
                               '1. pumpingRate_SAestimation() required considerable changes to the calibration scheme and is only operational with the' , ...
                               'SP-UCI. Other calibration schemes will be edited in the future.', ...
                               '2. Calibration with an evaluation period required downscaling will crash when using this componant. Future releases will', ...
                               'use the stochastically derived forcing tiem-series to build a predictive model for the estimation during evaluation periods.', ...
                               '3. This extension to HydroSight was funded by the Department of Environment, Land, Water and Planning, Victoria.', ...
                               'https://delwp.vic.gov.au/', ...
                               '', ...               
                               'References: ', ...
                               '1. Peterson & Fulton (in-prep), Estimating aquifer hydraulic properties from existing groundwater monitoring data.'};
        end        
           
    end
        
    
    methods       
%% Construct the model
        function obj = pumpingRate_SAestimation(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates, forcingData_reqCols, modelOptions)                        
            % Set constants.
            minObsPeriodsPerPump = 2;

            % Get a list of required forcing inputs and (again) check that
            % each of the required inputs is provided.
            %--------------------------------------------------------------
            [requiredFocingInputs, isRequired] = pumpingRate_SAestimation.inputForcingData_required();
            requiredFocingInputs = requiredFocingInputs(isRequired);
            for j=1:size(requiredFocingInputs,1)
                filt = strcmpi(forcingData_reqCols(:,1), requiredFocingInputs(j));                                    
                if ~any(filt)
                    error(['An unexpected error occured. When transforming forcing data, the input cell array for the transformation must contain a row (in 1st column) labelled "forcingdata" that its self contains a cell array in which the forcing data column is defined for the input:', requiredFocingInputs{j}]);
                end
            end
             
            % Assign the input forcing data to obj.settings.
            obj.settings.forcingData = forcingData_data;
            obj.settings.forcingData_colnames = forcingData_colnames;
            obj.settings.forcingData_cols = forcingData_reqCols;
            obj.settings.siteCoordinates = siteCoordinates;
            
            % Get the forcing data time points
            obsTime = obj.settings.forcingData(:, 1);            
            
            % Loop through each pumping bore. Any observation that
            % is preceeded by -999 is assumed to be the total pumping for
            % the preceeding period of -999 values. 
            nonObsPeriods=[];
            nNonObsPeriod=0;
            obsPumpingData=nan(0,6);
            for i = 1:size(obj.settings.forcingData_cols,1)
                
                % Get pumping data
                pumpingColName = obj.settings.forcingData_cols{i,1};
                pumpingColInd = obj.settings.forcingData_cols{i,2};                
                pumping = obj.settings.forcingData(:,pumpingColInd);
                
                % Loop through each time point
                nDays=0;
                
                for j=1: size(pumping,1)    

                    % Find the start and end dates of each non-obs period.
                    % ie -999 periods ending with zero. Below, for each period 
                    % of no observations add instance property and initialised using
                    % the regression relationship and period's evap deficit.
                    if pumping(j)==-999 && (j==1 || pumping(j-1)>=0)
                        nNonObsPeriod = nNonObsPeriod+1;
                        nonObsPeriods{nNonObsPeriod,1} = i;
                        nonObsPeriods{nNonObsPeriod,2} = pumpingColName;
                        nonObsPeriods{nNonObsPeriod,3} = obsTime(j);
                    elseif pumping(j)==-999 && (j==size(pumping,1) || pumping(j+1)>=0)
                        nonObsPeriods{nNonObsPeriod,4} = obsTime(j)+1;

                        % Store TOTAL period pumping volume if observed.
                        if j+1<size(pumping,1) && pumping(j+1)>0
                            nonObsPeriods{nNonObsPeriod,5} = pumping(j+1);
                        else
                            nonObsPeriods{nNonObsPeriod,5} = NaN;
                        end
                        
                        % Find pump in input options
                        filt = find(strcmp(modelOptions(:,1),pumpingColName),1,'first');    
                        
                        % Store time-step for stochastic forcing
                        % generation.
                        nonObsPeriods{nNonObsPeriod,6} = modelOptions{filt,2};
                    end
                end
                
                % Check there are at least two periods of metered pumping.
                if sum(cell2mat(nonObsPeriods(:,1)) == i & isnan(cell2mat(nonObsPeriods(:,5)))) < minObsPeriodsPerPump
                    error(['Pump ',forcingData_colnames{pumpingColInd}, ' must have >=',num2str(minObsPeriodsPerPump),' periods of metered total extractions.']);
                end
                
            end
            
            % Add non-obs periods to object
            obj.variables.nonObsPeriods = nonObsPeriods;                       
            
            % Loop through each pump bore and add one property time point at which the 
            % forcing should be changed from zero to one, or vise versa.
            if ~isempty(obj.variables.nonObsPeriods)
                for i=1:size(obj.settings.forcingData_cols,1)
                    % Get unobserved periods for the current bore
                    filt = find(cellfun(@(x) x == i, obj.variables.nonObsPeriods(:,1)))';
                    nNonObsPeriod = length(filt);

                    % Add properties (ie parameters) for annual pumping data. For each
                    % year without pumping data a parameter is added.
                    if nNonObsPeriod>0

                        % Get name of pumping bore
                        pumpName = obj.settings.forcingData_cols{i,1};

                        % Find bore number in model options
                        filt_pump = find(strcmp(modelOptions(:,1),pumpName),1,'first');                        
                        
                        % Add variable for the simulated annealing position
                        varName = [pumpName, '_SAposition'];                        
                        obj.variables.(varName) = rand(1);
                        
                        % Add variable for the simulated annealing cooling
                        % rate
                        varName = [pumpName, '_SAtemperature'];                        
                        obj.variables.(varName ) = modelOptions{filt_pump,3};
                        
                        % Add variable for cooling rate
                        varName = [pumpName, '_SAcooling'];                        
                        obj.variables.(varName ) = modelOptions{filt_pump,4};
                                                
                        % Create a lookup conversion table for each production bore to
                        % transform the date to alter pumping (propName) and the true
                        % date. Each production bore has one numeric matrix
                        % with the following format.
                        %   - date (from obj.settings.forcingData) for each period without daily metering
                        %   - row index to input forcing data
                        %   - time-step integer for user-set downscaled time-step
                        %   - time-step for only periods with metering normalised from 0 to 1.                        
                        %   - time-step all periods without daily metering normalised from 0 to 1.                        
                        %   - 0/1 for the pumping being on or off over the
                        %   user set time period.
                        obj.variables.(pumpName) = zeros(0,6);
                        for j=filt
                            
                            % Get dates for non-obs period
                            sDate = obj.variables.nonObsPeriods{j,3};
                            eDate = obj.variables.nonObsPeriods{j,4};                                                        
                            
                            % Setup non-obs days
                            nonObsDays = [sDate:eDate]';
                            
                            % Get index to non obs days
                            nonObsDaysIndex = find(obj.settings.forcingData(:,1) >=sDate & obj.settings.forcingData(:,1) <=eDate);
                            
                            % Convert non-obs days increments for user set time-step
                            switch lower(obj.variables.nonObsPeriods{nNonObsPeriod,6})
                                case 'daily'
                                    nonObsSteps = year(nonObsDays) *1000 + day(datetime(nonObsDays,'ConvertFrom','datenum'), 'dayofyear');
                                case 'weekly'
                                    nonObsSteps = year(nonObsDays) *1000 + week(datetime(nonObsDays,'ConvertFrom','datenum'));
                                case 'monthly'
                                    nonObsSteps = year(nonObsDays) *1000 + month(nonObsDays);
                                    
                                otherwise
                                    error(['The following time-step for generation of forcing data is not recognised:',obj.variables.nonObsPeriods{nNonObsPeriod,6}])
                            end
                            
                            % Set junk data for normalised time-step value
                            nonObsStepsNormalised = zeros(size(nonObsSteps));
                            
                            % Build temporary vector to denote of the
                            % total extractions for the periods were
                            % metered.
                            if isfinite(obj.variables.nonObsPeriods{j,5});
                                isMeteredPeriod = ones(size(nonObsSteps));
                            else
                                isMeteredPeriod = zeros(size(nonObsSteps));
                            end
                            
                            % Set pump to 'on' for each time step
                            nonObsPumpState = ones(size(nonObsSteps));

                            obj.variables.(pumpName) = [obj.variables.(pumpName); ...
                                                        nonObsDays nonObsDaysIndex nonObsSteps isMeteredPeriod nonObsStepsNormalised nonObsPumpState];
                        end                           

                        % Normalise 'nonObsSteps' during periods with total metered 
                        % so that required time step at which the pump state to be changed can
                        % be located from the pumping bore class parameter.
                        ind_metered = find(obj.variables.(pumpName)(:,4)==1);
                        ind_notMetered = find(obj.variables.(pumpName)(:,4)==0);
                        nonObsStepsUnique = sort(unique(obj.variables.(pumpName)(ind_metered ,3)));
                        for k=1:length(nonObsStepsUnique)
                            filt = find(obj.variables.(pumpName)(ind_metered,3) == nonObsStepsUnique(k));
                            obj.variables.(pumpName)(ind_metered(filt) ,4) = k;
                        end                        
                        obj.variables.(pumpName)(ind_metered,4) = obj.variables.(pumpName)(ind_metered,4)/length(nonObsStepsUnique);
                        obj.variables.(pumpName)(ind_notMetered,4) = NaN;                        
                        
                        % Normalise 'nonObsSteps' during all periods
                        % without daily metering so that required time
                        % step at which the pump state to be changed can
                        % be located from the pumping bore class parameter.
                        nonObsStepsUnique = sort(unique(obj.variables.(pumpName)(:,3)));
                        for k=1:length(nonObsStepsUnique)
                            filt_timesteps = obj.variables.(pumpName)(:,3) == nonObsStepsUnique(k);
                            obj.variables.(pumpName)(filt_timesteps ,5) = k;
                        end                        
                        obj.variables.(pumpName)(:,5) = obj.variables.(pumpName)(:,5)/length(nonObsStepsUnique);
                    end                                                    
                    
                end                
            end
            
            % Set the pump usage data. The following should be identical to
            % updateStochForcingData(obj) but without the change to the
            % pump state.
            %----------
            % Get the list of simulated annealing positions.
            SApositionVariables = fieldnames(obj.variables);
            filt = cellfun(@(x) ~isempty(strfind(x,'_SAposition')), SApositionVariables);
            SApositionVariables = SApositionVariables(filt);
            
            % Get the mean daily pumping rate during the metered periods.
            dailyRate = getDailyAveragePumpingRates(obj);

            % Filter out periods for which the daily rate could not be calculated.
            dailyRate = dailyRate(isfinite(dailyRate(:,end)),:);

            % Get pump names and numbers
            pumpName = cell(size(SApositionVariables,1),1);
            pumpNum = pumpName;
            for i=1:size(SApositionVariables,1)

                % Get bore names.
                pumpName{i,1} = SApositionVariables{i}(1:end-11);

                % Get pump number 
                pumpNum{i,1} = str2double(pumpName{i}(6:end));

            end            
            
            % Update pumping rates based on new pump states
            for i=1:size(SApositionVariables,1)

                % Initialise daily pump rate to mean
                filt = dailyRate(:,1) == pumpNum{i};
                dailyRate_mean = mean(dailyRate(filt ,5));
                obj.variables.(pumpName{i})(:,7)=dailyRate_mean;

                % Initialise daily pump volume to nan
                obj.variables.(pumpName{i})(:,8)=nan;

                % Assign the average daily pumping rate during each metered period
                filt = find(dailyRate(:,1) == pumpNum{i})';
                for j=filt                        
                    filt_obsPeriods =  obj.variables.(pumpName{i})(:,1) >= dailyRate(j,2) & obj.variables.(pumpName{i})(:,1) <= dailyRate(j,3); 
                    obj.variables.(pumpName{i})(filt_obsPeriods,7)=dailyRate(j,5);
                end

                % Multiple pump state by daily rate to create down-scaled pumping rate
                obj.variables.(pumpName{i})(:,8)=obj.variables.(pumpName{i})(:,6).*obj.variables.(pumpName{i})(:,7);
            end            
            %----------
                        
            
        end
        
%% Set parameters
        function setParameters(obj, params)
% setParameters returns the soil model parameters.
%
% Syntax:
%   setParameters(obj, params)  
%
% Description:  
%   This method sets the soil moisture model parameters to user input values.
%   Only parameters that are to be calibrated (i.e. non-fixed parameters)
%   can be set. Also the vector of input parameter values must be in the
%   same order as the parameter names returned by the method
%   'getParameters'.
%
% Input:
%   obj     - soil moisture model object.
%   params  - vector (Nx1) of parameter values.
%
% Outputs:
%   (none)
%
% See also:
%   climateTransform_soilMoistureModels: class_definition;
%   getParameters: get_calibration_parameters_values;
%   detectParameterChange: assesst_if_parameters_have_changed_recently;
%   setTransformedForcing: run_model_and_store_simulation_results;
%   getTransformedForcing: get_outputs_for_timeseries_model.
%
% Dependencies:
%   (none)
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure Engineering, 
%   The University of Melbourne.
%
% Date:
%   11 April 2012  

% 
%             % Get the parameter names
%             param_names = '';
%             properties(obj);
%             filt = cellfun( @(x) ~strcmp(x,'settings') && ~strcmp(x,'variables'), param_names);
%             param_names = param_names(filt);
%             
%             % Cycle through each parameter and assign the parameter value.
%             for i=1: length(param_names)
%                obj.(param_names{i}) = params(i,:); 
%             end
%             
%             % Check if the parameters have changed since the last call to
%             % setTransformedForcing.
%             detectParameterChange(obj, params);   


        end
        
        function setForcingData(obj, forcingData, forcingData_colnames)
% setForcingData sets the forcing data.
%
% Syntax:
%   setForcingData(obj, forcingData, forcingData_colnames)
%
% Description:  
%   This method set the climate forcing data. It is used to update the
%   forcing data for model simulations (primarily from the GUI).
%
% Input:
%   obj         - soil moisture model object.
%
%   forcingData - nxm matrix of focrinf data with column 1 being the
%                 date/time.
%
%   forcingData_colnames - 1xm cell array of column names within the above
%                 data.
%
% Outputs:
%   (none)
%
% Dependencies:
%   (none)
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure Engineering, 
%   The University of Melbourne.
%
% Date:
%   21 Dec 2015              
            
            obj.settings.forcingData_colnames = forcingData_colnames;
            obj.settings.forcingData = forcingData;
        end                

        function forcingData = getStochForcingData(obj)        
           
                % Get list of SA position variables
                SApositionVariables = fieldnames(obj.variables);
                filt = cellfun(@(x) ~isempty(strfind(x,'_SAposition')), SApositionVariables);
                SApositionVariables = SApositionVariables(filt);                

                % Get pump states from each bore.
                for i=1:size(SApositionVariables ,1)
                    % Get bore names.
                    pumpName = SApositionVariables{i}(1:end-11);        
                     
                    % Get pump state.
                    forcingData.(pumpName) = logical(obj.variables.(pumpName)(:,6));                                                            
                end                
        end
                
        function updateStochForcingData(obj, forcingData, objFuncVal, objFuncVal_prior)
            
            % Get the list of simulated annealing positions.
            SApositionVariables = fieldnames(obj.variables);
            filt = cellfun(@(x) ~isempty(strfind(x,'_SAposition')), SApositionVariables);
            SApositionVariables = SApositionVariables(filt);

            % Estimate the mean daily pumping rate during the metered
            % periods.
            dailyRate = getDailyAveragePumpingRates(obj);

            % Filter out periods for which the daily rate could not be
            % calculated.
            dailyRate = dailyRate(isfinite(dailyRate(:,end)),:);
            
            % Get pump names and numbers
            pumpName = cell(size(SApositionVariables,1),1);
            pumpNum = pumpName;
            for i=1:size(SApositionVariables,1)

                % Get bore names.
                pumpName{i,1} = SApositionVariables{i}(1:end-11);

                % Get pump number 
                pumpNum{i,1} = str2double(pumpName{i}(6:end));

            end
            
            if nargin==1

                % Loop through each PARAMETER, find the date to edit pumping state and 
                % then update the state. Once updated, calculate the mean
                % pumping rate for each period using ONLY the periods with
                % a metered total extraction volume. Then, apply the
                % average pumping rate to all periods without metered total
                % extractions.                
                for i=1:size(SApositionVariables,1)

                    % Get bore names.
                    pumpName{i} = SApositionVariables{i}(1:end-11);

                    % Get pump number 
                    pumpNum{i} = str2double(pumpName{i}(6:end));

                    % Find the number of discrete time steps possible
                    timestepMax = length((unique(obj.variables.(pumpName{i})(:,3))));

                    % Find the step size increments.
                    timestepInc = 1/timestepMax;

                    % Randomly update the position to one increment above of below current locaton.
                    if rand(1)>=0.5
                        obj.variables.(SApositionVariables{i}) = obj.variables.(SApositionVariables{i})+ timestepInc;

                        if obj.variables.(SApositionVariables{i}) >1
                            obj.variables.(SApositionVariables{i}) = 0;
                        end
                    else
                        obj.variables.(SApositionVariables{i}) = obj.variables.(SApositionVariables{i})- timestepInc;

                        if obj.variables.(SApositionVariables{i}) < 0
                            obj.variables.(SApositionVariables{i}) = 1;
                        end
                    end

                    % Find normalised time-period from all periods of non-daily pumping.
                    timestepMax = length((unique(obj.variables.(pumpName{i})(:,3))));
                    timestepValNormalised = ceil(abs(obj.variables.(SApositionVariables{i})) * timestepMax)/timestepMax;
                    filt = obj.variables.(pumpName{i})(:,5)==timestepValNormalised;

                    % Calc number of pumping days to change.
                    nDaysToChnage = sum(filt);                   

                    % Find if the current time point is a metered period.
                    % If so, then get the number of days when the pump is
                    % on. If the proposed chnage to the pump state is <=
                    % the number of days pumping then do not turn pump off.
                    filt_dailyRate = find(dailyRate(:,1) == pumpNum{i})';
                    date2Chnage = obj.variables.(pumpName{i})(filt,1);
                    dailyRate_index = nan;
                    for j=filt_dailyRate                        
                        if any(dailyRate(j,2) <= date2Chnage) && any(dailyRate(j,3) >=date2Chnage)
                            dailyRate_index = j;
                            break
                        end
                    end

                    % Change state of pumping only if, over a metered period,
                    % the number of days with pumping is greater than those
                    % to be turned off.                        
                    changePumpState = true;
                    isValidPumpState = true;
                    if isfinite(dailyRate_index) && max(obj.variables.(pumpName{i})(filt,6))==1                        

                       filt_periodPumpingDays = obj.variables.(pumpName{i})(:,1) >=dailyRate(dailyRate_index,2) ...
                       & obj.variables.(pumpName{i})(:,1) <= dailyRate(dailyRate_index,3);

                        nPeriodPumpingDays = sum(obj.variables.(pumpName{i})(filt_periodPumpingDays,6));

                        if nPeriodPumpingDays <= nDaysToChnage
                            changePumpState = false;
                            isValidPumpState=false;
                        end
                    end                                        
                    if changePumpState 
                        %obj.variables.(pumpName{i})(filt,6) = double(newPumpState);
                        if max(obj.variables.(pumpName{i})(filt,6)) == 1
                            obj.variables.(pumpName{i})(filt,6) = 0;
                        else
                            obj.variables.(pumpName{i})(filt,6) = 1;
                        end                            
                    end
                end                    
            elseif nargin>1

                % Get names of pumps within the input forcing data.
                pumpsNames_input =  fieldnames(forcingData);
                
                % Loop through each input names and assign the forcing data
                % to the object.
                for i=1:length(pumpsNames_input)
                   
                    % Check the input field name is within the object
                    % already.
                    if ~any(strcmp(pumpName, pumpsNames_input{i}))
                        error('An fieldname within the input "forcingData" is not listed within the pumpingRate_SAestimation object.');
                    end
                    
                    % Check the input number of days is as per expected.
                    if size(forcingData.(pumpsNames_input{i}),1) ~= size(obj.variables.(pumpsNames_input{i}),1)
                        error(['The number of rows within forcingData.',pumpsNames_input{i},' does not equal that within the corresponding  pumpingRate_SAestimation variable.']);
                    end 

                    % Assess if each metered period with pump rate >0 has >0 periods with
                    % the pump on.                    
                    %-------------
                    
                    % Filter for any metered periods.
                    filt = [find(dailyRate(:,1)==pumpNum{i})]';

                    isValidPumpState = true;
                    for j=filt                            
                       filt_obsPeriods =  obj.variables.(pumpsNames_input{i})(:,1) >= dailyRate(j,2) & obj.variables.(pumpsNames_input{i})(:,1) <= dailyRate(j,3); 
                       if  sum(forcingData.(pumpsNames_input{i})(filt_obsPeriods)) <=0
                           isValidPumpState = false;
                       end
                    end
                    %-------------
                    
                    % Assign input forcing
                    if isValidPumpState
                        obj.variables.(pumpsNames_input{i})(:,6) = double(forcingData.(pumpsNames_input{i}));
                    end

                end
            end

            % Update the mean daily pumping rate during the metered
            % periods because the pump state changed.
            dailyRate = getDailyAveragePumpingRates(obj);

            % Filter out periods for which the daily rate could not be
            % calculated.
            dailyRate = dailyRate(isfinite(dailyRate(:,end)),:);


            % Update pumping rates based on new pump states
            for i=1:size(SApositionVariables,1)

                % Initialise daily pump rate to mean
                filt = dailyRate(:,1) == pumpNum{i};
                dailyRate_mean = mean(dailyRate(filt ,5));
                obj.variables.(pumpName{i})(:,7)=dailyRate_mean;

                % Initialise daily pump volume to nan
                obj.variables.(pumpName{i})(:,8)=nan;

                % Assign the average daily pumping rate during each metered period
                filt = find(dailyRate(:,1) == pumpNum{i})';
                for j=filt                        
                    filt_obsPeriods =  obj.variables.(pumpName{i})(:,1) >= dailyRate(j,2) & obj.variables.(pumpName{i})(:,1) <= dailyRate(j,3); 
                    obj.variables.(pumpName{i})(filt_obsPeriods,7)=dailyRate(j,5);
                end

                % Multiple pump state by daily rate to create down-scaled pumping rate
                obj.variables.(pumpName{i})(:,8)=obj.variables.(pumpName{i})(:,6).*obj.variables.(pumpName{i})(:,7);
            end
            
            % Lastly cool the simulated annealing scheme. This can only be
            % done if the last two inputs are scalar objective function
            % values.
            if nargin==4               
                if isscalar(objFuncVal) && isscalar(objFuncVal_prior)
                    coolTemperature(obj,objFuncVal, objFuncVal_prior);
                else
                    error('Inputs 3 and 4 must be scalar objective function values.');
                end
            end
        end
        
%% Get model parameters
        function [params, param_names] = getParameters(obj)            
% getParameters sets the soil model parameters.
%
% Syntax:
%   setParameters(obj, params)  
%
% Description:  
%   This method gets model parameters. For this class, mno parameters are
%   every returned.
%
% Input:
%   obj         - model object.
%
% Outputs:
%   params      - an empty vector.
%
%   param_names - an empry vector (Nx1) of parameter names.   
%%
% Dependencies:
%   (none)
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure Engineering, 
%   The University of Melbourne.
%
% Date:
%   June 2017
            param_names={};
            params=[];
        end   
        
%% Assess if matrix of parameters is valid.
        function isValidParameter = getParameterValidity(obj, params, param_names)
% getParameterValidity returns a logical vector for the validity or each parameter.
%
% Syntax:
%   isValidParameter = getParameterValidity(obj, params, param_names)
%
% Description:
%   Returns a logical vector denoting if each parameter is valid.
%
% Input:
%   obj -  model object.
%
%   params - vector of model parameters
%
%   param_names - cell array of the parameter names.
%
% Outputs:
%   isValidParameter - column vector of the parameter validity.
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure
%   Engineering, The University of Melbourne.
%
% Date:
%   June 2017

            % Get physical bounds.
            isValidParameter = true(size(params));   
        end   

        function isNewParameters = detectParameterChange(obj, params)
           
            isNewParameters = true(size(params));
            
        end
        
%% Return fixed upper and lower bounds to the parameters.
        function [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj)  
% getParameters_physicalLimit returns the physical limits to each model parameter.
%
% Syntax:
%   [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj)  
%
% Description:
%   Cycles through all active soil model componants and parameters and returns
%    a vector of the physical upper and lower parameter bounds.
%
% Input:
%   obj -  model object.
%
% Outputs:
%   params_upperLimit - column vector of the upper parameter bounds.
%
%   params_lowerLimit - column vector of the lower parameter bounds
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure
%   Engineering, The University of Melbourne.
%
% Date:
%   June 2017

            params_lowerLimit = [];
            params_upperLimit = [];
        end  
        
%% Return fixed upper and lower plausible parameter ranges. 
        function [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(obj)
% getParameters_plausibleLimit returns the plausible limits to each model parameter.
%
% Syntax:
%   [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(obj)
%
% Description:
%   Cycles through all active soil model componants and parameters and returns
%    a vector of the plausible upper and lower parameter bounds.
%
% Input:
%   obj -  model object.
%
% Outputs:
%   params_upperLimit - column vector of the upper parameter bounds.
%
%   params_lowerLimit - column vector of the lower parameter bounds
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure
%   Engineering, The University of Melbourne.
%
% Date:
%   June 2017

            params_lowerLimit = [];
            params_upperLimit = [];
        end        
        
%% Solve the soil moisture differential equation
        function setTransformedForcing(obj, t, forceRecalculation)
% setTransformedForcing does nothing.
%
% Syntax:
%   setTransformedForcing(obj, climateData, forceRecalculation)
%
% Description:  
%   This function does nothing. Handling of the focring data is undertaken
%   by updateStochForcingData().
%
% Input:
%   obj         - model object.
%
%   t           - a vector (Nx1) of time points for simulation.
%
%   forceRecalculation - is a logical scalar input (i.e. true of false) to
%                 force re-calculation of the model and thus ingore if the
%                 parameters have or have not changed.
% Outputs:
%   (none)
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure Engineering, 
%   The University of Melbourne.
%
% Date:
%   June 2017

            % Filter the forcing data to input t.
            filt_time = obj.settings.forcingData(:,1) >= t(1) & obj.settings.forcingData(:,1) <= t(end);

            % Store the time points
            obj.variables.t = t(filt_time);

        end

%% Simulated annealing assessment to accept or reject a calibration iteration.       
        function [stochForcingData_new, accepted] = acceptStochForcingSolution(obj, objFuncVal, objFuncVal_prior, stochForcingData)
% acceptSolution assesses if a worse calibration iteration solution should be accepted.
%
% Syntax:
%   accepted = acceptSolution(obj, objFuncVal, objFuncVal_prior, derivedForcingData, derivedForcingData_colnames)
%
% Description:  
%   Assesses if the stochastic forcing from a calibration iteration
%   solution should be accepted even if the objective function degraded to
%   a greater value. When the objective function has degraded, the
%   stochastic forcing for a pumping bore, j, is accepted if a random number
%   is less than exp(-(objFuncVal-objFuncVal_prior)./tempurature_ij), where
%   the temperature of the simulated annuealing schemee at iteration i and 
%   bore j is tempurature_ij.
%
% Input:
%   obj                 - model object.
%
%   objFuncVal          - a scaler of the latest objective function value.
%
%   objFuncVal-prior    - a scaler of the prior iteration objective function value.
%
%   stochForcingData_prior- stochastic forcing to input to the object if the 
%                         calibration solution is not accepted. This should
%                         be of the same format as returned by
%                         getStochForcingData.
%
%   stochForcingData_colnames - column name for the stochastic forcing
%   data.
% Outputs:
%   (none)
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure Engineering, 
%   The University of Melbourne.
%
% Date:
%   June 2017
        
            SAtemperatureVariables = fieldnames(obj.variables);
            filt = cellfun(@(x) ~isempty(strfind(x,'_SAtemperature')), SAtemperatureVariables);
            SAtemperatureVariables  = SAtemperatureVariables (filt);
            
            % Get the object's current stochastic derived forcing.
            stochForcingData_new = getStochForcingData(obj);
            
            % Accept stochastic forcing if the objective function is
            % improved.
            accepted = false;
            if objFuncVal <= objFuncVal_prior
                accepted = true;
                
                % Do nothing else. The model object already contains the 'new'
                % stochastic derived forcing, which is in 'stochForcingData_new'.
                
                return;
            end
            
            % This following loop assess if the stochastic forcing for each
            % pump (as is within the class object) should be accepted or else
            % replaced by the input stochastic forcing. 
            if nargin>3
                accepted = true;            
                for i=1:size(SAtemperatureVariables ,1)                                
                    acceptanceProb =  exp(-(objFuncVal-objFuncVal_prior)./obj.variables.(SAtemperatureVariables{i}));
                    if rand(1) < acceptanceProb
                        % Do nothing. The model object already contains the 'new'
                        % stochastic derived forcing, which is in 'stochForcingData_new'.
                    else
                        % Stochastic forcing for pump i within the object is
                        % rejected, so replace pump i with the input stochastuc
                        % forcing.
                        accepted = false;
                        pumpName = SAtemperatureVariables{i}(1:end-14);
                        stochForcingData_new.(pumpName) = stochForcingData.(pumpName);
                    end
                end

                % Update stochastic forcing for the accepted pumps. 
                if ~accepted
                    updateStochForcingData(obj, stochForcingData_new);                
                end
            end
        end
           
        
%% Return the transformed forcing data
        function [forcingData, isDailyIntegralFlux] = getTransformedForcing(obj, variableName) 
% getTransformedForcing returns the required flux from the soil model.
%
% Syntax:
%   [forcingData, isDailyIntegralFlux] = getTransformedForcing(obj, variableName)
%
% Description:  
%   This method returns the requested flux/data from the apporiate pump.
%
% Input:
%   obj - model object.
%
%   variableName - a string for the variable name to return.
%
% Outputs:
%   forcingData  - a vector (Nx1) of the forcing data output to
%                     be input to the groundwater time series model.
%
%   isDailyIntegralFlux - logical scaler denoting if the flux is a daily
%   integral or an instantaneous value. This is used to inform the type of
%   numerical integration within modelTFN.get_h_star().
%
% Dependencies:
%   (none)
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure Engineering, 
%   The University of Melbourne.
%
% Date:
%   July 2017 


            if ischar(variableName)
                variableNametmp{1}=variableName;
                variableName = variableNametmp;
                clear variableNametmp;
            end

            isDailyIntegralFlux=true;
            try 
                for i=1:length(variableName)
                    % Initialise to input forcing data.
                    forcingVariableName = obj.settings.forcingData_cols{:,1};
                    colForcingData_filt = strcmp(obj.settings.forcingData_cols(:,1), variableName{i});
                    colForcingData = obj.settings.forcingData_cols{colForcingData_filt,2};
                    if i==1
                        forcingData = obj.settings.forcingData(:,colForcingData);
                    else
                        forcingData(:,i) = obj.settings.forcingData(:,colForcingData);
                    end
                    
                    % Add generated forcing data
                    forcingData(obj.variables.(variableName{i})(:,2),i) = obj.variables.(variableName{i})(:,8);
                    
                end
            catch ME
                error('The requested transformed forcing variable is not known.');
            end
        end
        
        % Return the derived variables.
        function [params, param_names] = getDerivedParameters(obj)
            params = [];
            param_names = cell(0,2);
        end

        % Return coordinates for forcing variable
        function coordinates = getCoordinates(obj, variableName)

            if ~iscell(variableName)
                variableNameTmp{1}=variableName;
                variableName = variableNameTmp;
                clear variableNameTmp;
            end
                
            coordinates = cell(length(variableName),3);
            for i=1:length(variableName)
                % Find row within the list of required containing variabeName
                filt = strcmp(obj.settings.forcingData_cols(:,1), variableName{i});

                % Find input bore for requested output
                sourceBoreColNumber = obj.settings.forcingData_cols{filt,2};
                sourceBoreColName = obj.settings.forcingData_colnames{sourceBoreColNumber};

                % Get coordinates
                filt = strcmp(obj.settings.siteCoordinates(:,1), sourceBoreColName);
                coordinates(i,:) = obj.settings.siteCoordinates(filt,:);
                coordinates{i,1} = variableName{i};
            end
        end
    end
    
    methods(Access=protected, Hidden=true)
                
        % Calculate the mean daily pumping rate for each period with metered volume. 
        % Returns matrix of size(obj.variables.nonObsPeriods,1) with
        % pump number, start date for period, end date for period, average
        % daily pumping rate for the period.
        function dailyRate = getDailyAveragePumpingRates(obj, t)
                
            % Get list of non-obs periods nonObsPeriods.
            nonObsPeriods = obj.variables.nonObsPeriods;

            % For each bore, calculate the average daily pumping rate
            % during each petered period.
            dailyRate = nan(size(nonObsPeriods,1),5);
            for i=1:size(nonObsPeriods,1)
                
                dailyRate(i,1) = nonObsPeriods{i,1};
                dailyRate(i,2) = nonObsPeriods{i,3};
                dailyRate(i,3) = nonObsPeriods{i,4};
                
                % Check the period of meterewd total extractions is within
                % the calcibration time range t. That is, if the end
                % date of the period is before the start date, t(1), or
                % the start date of the period is after the end time,
                % t(end).
                if nargin==2 && (dailyRate(i,3) < t(1) || dailyRate(i,2) > t(end))
                    continue
                end
                                
                % Check if the pumping was metered for the period.
                if ~isfinite(nonObsPeriods{i,5})
                    continue
                end
                
                % get the pump names
                pumpName = nonObsPeriods{i,2};
                
                % Find the number of days the pump is recorded as 'on'. 
                filt_obsPeriods =  obj.variables.(pumpName)(:,1) >= dailyRate(i,2) & obj.variables.(pumpName)(:,1) <= dailyRate(i,3); 
                dailyRate(i,4) = sum(obj.variables.(pumpName)(filt_obsPeriods,6));
                
                % Calculate average daily pumping rate for the period.
                dailyRate(i,5) = nonObsPeriods{i,5}/dailyRate(i,4);                            
                
            end                    
        end
        
        function coolTemperature(obj,objFuncVal, objFuncVal_prior)
           
            SAtemperatureVariables = fieldnames(obj.variables);
            filt = cellfun(@(x) ~isempty(strfind(x,'_SAtemperature')), SAtemperatureVariables);
            SAtemperatureVariables  = SAtemperatureVariables (filt);
            
            % Cool the saimulated annealing scheme if the temperature
            % reduced. Else, randomly choose a new position.
            if objFuncVal <= objFuncVal_prior
                for i=1:length(SAtemperatureVariables)

                    pumpName = SAtemperatureVariables{i}(1:end-14);
                    coolingVarName = [pumpName, '_SAcooling'];                        
                    obj.variables.(SAtemperatureVariables{i}) = obj.variables.(SAtemperatureVariables{i})*(1-obj.variables.(coolingVarName));
                    obj.variables.(SAtemperatureVariables{i});
                end
             else
                 for i=1:length(SAtemperatureVariables)
                        
                        pumpName = SAtemperatureVariables{i}(1:end-14);
                        positionVarName = [pumpName, '_SAposition'];                        
                        obj.variables.(positionVarName ) = rand(1);
                 end
                
            end
        end
        
        
    end
    
end


