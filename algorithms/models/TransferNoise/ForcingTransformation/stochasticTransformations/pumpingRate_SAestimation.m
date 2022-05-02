classdef pumpingRate_SAestimation < stochForcingTransform_abstract & dynamicprops
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
        function [variable_names, isOptionalInput] = inputForcingData_required(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates)
            %variable_names = cell(75,1);
            %variable_names(1:75) = strrep(strrep(strcat({'Pump '},num2str([1:75]')),' ','_'),'__','_');            
            %isOptionalInput = true(75,1);
            [variable_names] = pumpingRate_SAestimation.outputForcingdata_options(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates);
            isOptionalInput = true(length(variable_names),1);     
            
            global pumpingRate_SAestimation_wizardResults
            pumpingRate_SAestimation_wizardResults={};
        end
        
        function [variable_names, isOptionalInput] = dataWizard(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates)
            
            dlg_title = 'Data Wizard: Set criteria for pumping selection ...';
            prompt = {'Maximum radius of selected pumps from the obs. bore (in units of coordinates):', ...
                      'Maximum number of selected pumps:'};            
            num_lines = 1;
            defaultans = {'5000','10'};
            answer = inputdlg(prompt,dlg_title,num_lines,defaultans);
            
            if isempty(answer) 
                global pumpingRate_SAestimation_wizardResults
                pumpingRate_SAestimation_wizardResults = {};
                [variable_names, isOptionalInput] = pumpingRate_SAestimation.inputForcingData_required(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates);
            else
                % Check inputs
                try 
                    maxDist = str2double(answer{1});
                    if maxDist <0
                        warndlg('The maximum distance must be >>0. It will be set to Inf.','Input data error ...')
                        maxDist = Inf;
                    end
                    maxNum = str2double(answer{2});
                    if maxNum<0
                        warndlg('The maximum number of pumps must be >0. It will be set to Inf.','Input data error ...')
                        maxNum = Inf;
                    end                    
                catch
                    warndlg('Both inputs must be scalar numbers >0. Both will be set to Inf.','Input data error ...')
                    maxDist = Inf;
                    maxNum = Inf;
                end
                
                % Get coordinate of the obs bore
                filt = cellfun(@(x) strcmp(x, bore_ID),table2cell(siteCoordinates(:,1)));
                boreEN = table2array(siteCoordinates(filt,2:3));
                
                % Find those forcing data columns with any infilling. These
                % are most likely pumping bores.
                filt = false(size(forcingData_data,2),1);
                for i=1:size(forcingData_data,2)
                    filt(i) = any(forcingData_data{:,i} == -999);
                end
                forcingData_colnames = forcingData_colnames(filt);
                
                % Find the coordinates for the identified pumping bores.
                filt = cellfun(@(x) any(strcmp(forcingData_colnames,x)), table2cell(siteCoordinates(:,1)));
                pumpEN = table2array(siteCoordinates(filt,2:3));
                pumpEN = bsxfun(@minus, pumpEN, boreEN);
                
                % Calculate distance to pump
                dist = sqrt(pumpEN(:,1).^2 + pumpEN(:,2).^2);
                
                % Create table of pump IDs and diatances
                pumpTable = table(siteCoordinates{filt,1},dist);
                pumpTable = sortrows(pumpTable,2);
                
                % Filter data based on user input criteria.
                filt = table2array(pumpTable(:,2)) <= maxDist;
                pumpTable = pumpTable(filt,1:2);
                if size(pumpTable,1)>maxNum                    
                    pumpTable = pumpTable(1:maxNum,:);
                end
                
                nrows = size(pumpTable,1);
                variable_names = cell(nrows ,2);
                %variable_names(1:nrows ,1) = strrep(strrep(strcat({'Pump '},num2str([1:nrows]')),' ','_'),'__','_');            
                variable_names(1:nrows ,1) = strcat(table2cell(pumpTable(:,1)),'_infilled');
                variable_names(1:size(pumpTable,1),2) = table2cell(pumpTable(:,1));
                isOptionalInput = true(nrows ,1);
                
                % Set a global variable that stores the wizard results.
                % This is an unfortunate requirement to allow the efficient
                % selection of input data within the GUI TFN weighting
                % function box.
                global pumpingRate_SAestimation_wizardResults
                pumpingRate_SAestimation_wizardResults = variable_names(1:nrows ,1);
                
                
            end
        end        
        
        function [variable_names] = outputForcingdata_options(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates)
            %variable_names = strrep(strrep(strcat({'Pump '},num2str([1:75]')),' ','_'),'__','_');
            
            global pumpingRate_SAestimation_wizardResults
            if ~isempty(pumpingRate_SAestimation_wizardResults)
                variable_names = pumpingRate_SAestimation_wizardResults;
            else            
                % Find those forcing data columns with any infilling. These
                % are most likely pumping bores.
                filt = false(size(forcingData_data,2),1);
                if iscell(forcingData_data) || istable(forcingData_data)
                    for i=1:size(forcingData_data,2)
                        filt(i) = any(forcingData_data{:,i} == -999);
                    end                
                else
                    for i=1:size(forcingData_data,2)
                        filt(i) = any(forcingData_data(:,i) == -999);
                    end                
                end
                variable_names = strcat(forcingData_colnames(filt),'_infilled');
                variable_names = variable_names';
            end
        end
        
        function [options, colNames, colFormats, colEdits, toolTip] = modelOptions()
            
            options = cell(3,2);
            colNames = {'Setting name','Setting value'};
            colFormats = {'char','numeric'};
            colEdits = logical([0 1]);

            options{1,1} = 'Downscaling time-step (none=0, monthly=1, weekly=2, daily=3):';
            options{1,2} = 3;

            options{2,1} = 'Minimum number of bore meter readings:';
            options{2,2} = 2;
                     
            options{3,1} = 'Minimum days to downscale:';
            options{3,2} = 7;
                                                
            toolTip = sprintf([ 'Use this table to define the method for downscaling time-step. \n', ...
                                'Note, pumps have less than the min. number of meter readings \n', ...
                                'will be omitted from analysis.']);
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

            % Clear the global variable for the required forcing columns.
            global pumpingRate_SAestimation_wizardResults
            clear pumpingRate_SAestimation_wizardResults
            
            % Set the calibration state as false
            obj.variables.doingCalibration = false;
            
            % Get a list of required forcing inputs and (again) check that
            % each of the required inputs is provided.
            %--------------------------------------------------------------
            [requiredFocingInputs, isOptionalInput] = pumpingRate_SAestimation.inputForcingData_required(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates);
            requiredFocingInputs = requiredFocingInputs(~isOptionalInput);
            for j=1:numel(requiredFocingInputs)
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
            obj.settings.downscalingTimeStepFinal = modelOptions{1,1};
            switch modelOptions{1,2}
                case 0
                   obj.settings.downscalingTimeStepFinal = '(none)';
                case 1
                   obj.settings.downscalingTimeStepFinal = 'monthly';
                case 2
                   obj.settings.downscalingTimeStepFinal = 'weekly'; 
                case 3
                   obj.settings.downscalingTimeStepFinal = 'daily';
                otherwise
                    error('pumpingRate_SAestimation: unknown timestep setting.')
            end
            obj.settings.downscalingTimeStepCurrent = '(none)';
            obj.settings.minObsPeriodsPerPump = max(0,modelOptions{2,2});                     
            obj.settings.minDays2Downscale = max(0,modelOptions{3,2}); 
                        
            % Get the forcing data time points
            obsTime = obj.settings.forcingData(:, 1);            
            
            % Initialise the calibration period
            obj.variables.t_start_calib = -inf;
            obj.variables.t_end_calib = inf;
            
            % Loop through each pumping bore. Any observation that
            % is preceeded by -999 is assumed to be the total pumping for
            % the preceeding period of -999 values. An period that ends in
            % -999 is assumed to be a non-metered period. Any observations
            % that are not preceeded by -999 and daily obs.
            nonObsPeriods=[];
            nNonObsPeriod=0;
            obsDays=nan(0,3);
            nObsDays=0;
            pumpIDs_insufficientMetering=[];
            for i = 1:size(obj.settings.forcingData_cols,1)
                
                % Get pumping data
                pumpingColName = obj.settings.forcingData_cols{i,1};
                pumpingColInd = obj.settings.forcingData_cols{i,2};                
                pumping = obj.settings.forcingData(:,pumpingColInd);                
                
                % Initialise the  number of meter readings
                nMeterReadings = 0;

                % Add calibration parameter for the pump and
                % initialise to 0.5.
                parName = [pumpingColName, '_position'];                        
                dynPropMetaData{i} = addprop(obj,parName);                
                obj.(parName)=-0.5;
                
                % Loop through each time point
                for j=1: size(pumping,1)    

                    % Find the start and end dates of each non-obs period.
                    % ie -999 periods ending with zero. Below, for each period 
                    % of no observations add instance property and initialised using
                    % the regression relationship and period's evap deficit.
                    if pumping(j)==-999 && (j==1 || pumping(j-1)>=0)
                        % First day of -999 periods.
                        nNonObsPeriod = nNonObsPeriod+1;
                        nonObsPeriods{nNonObsPeriod,1} = i;
                        nonObsPeriods{nNonObsPeriod,2} = pumpingColName;
                        nonObsPeriods{nNonObsPeriod,3} = obsTime(j);
                        nonObsPeriods{nNonObsPeriod,4} = obsTime(j);
                        nonObsPeriods{nNonObsPeriod,5} = NaN;
                        nonObsPeriods{nNonObsPeriod,6} = obj.settings.downscalingTimeStepCurrent;
                    elseif pumping(j)==-999 && (j==size(pumping,1) || pumping(j+1)>=0)
                        % End day of -999 periods.
                        if j>=length(pumping) || pumping(j+1)==0
                            % Unmetered period because the -999 period ends
                            % with a zero.
                            nonObsPeriods{nNonObsPeriod,4} = obsTime(j);
                            nonObsPeriods{nNonObsPeriod,5} = NaN;
                        else
                            % Unmetred period endds with a recorded total
                            % volume.
                            nonObsPeriods{nNonObsPeriod,4} = obsTime(j)+1;
                            nonObsPeriods{nNonObsPeriod,5} = pumping(j+1);
                            nMeterReadings = nMeterReadings + 1;
                        end
                        
                        % Store time-step for stochastic forcing generation.
                        nonObsPeriods{nNonObsPeriod,6} = obj.settings.downscalingTimeStepCurrent;
                    elseif (j==1 && pumping(j)>0) || (pumping(j)>0 && pumping(j-1)~=-999)
                        nObsDays = nObsDays +1;
                        obsDays(nObsDays, :) = [i,  obsTime(j), pumping(j)];
                        nMeterReadings = nMeterReadings + 1;
                    end
                end
                
                % Check there are at least the user set minimum number of metered periods for the pump.
                if nMeterReadings < obj.settings.minObsPeriodsPerPump
                    pumpIDs_insufficientMetering=[pumpIDs_insufficientMetering, i];
                    %error(['Pump ',forcingData_colnames{pumpingColInd}, ' must have >=',num2str(obj.settings.minObsPeriodsPerPump),' periods of metered total extractions.']);
                end
                
            end
            
            % Remove pumps with insufficient metering.
            for i=1:length(pumpIDs_insufficientMetering)
                filt = cell2mat(nonObsPeriods(:,1)) ~= pumpIDs_insufficientMetering(i);
                nonObsPeriods = nonObsPeriods(filt,:);
                delete(dynPropMetaData{pumpIDs_insufficientMetering(i)})
            end
            
            % Remove unmetered periods that are less than the user set
            % minimum duration.
            filt= true(size(nonObsPeriods,1),1);
            for i=1:size(nonObsPeriods,1)
                if isnan(nonObsPeriods{i,5}) && ...
                nonObsPeriods{i,4}-nonObsPeriods{i,3}<obj.settings.minDays2Downscale
            
                    filt(i) = false;
            
                     % Set period in forcing data to zero
                    pumpingColInd = obj.settings.forcingData_cols{nonObsPeriods{i,1},2};                
                    filt_time = obj.settings.forcingData(:,1) >= nonObsPeriods{i,3} & obj.settings.forcingData(:,1) <= nonObsPeriods{i,4};
                    obj.settings.forcingData(filt_time ,pumpingColInd) = 0;
                end
            end
            nonObsPeriods = nonObsPeriods(filt,:);
            
            % Add observed and non-obs periods to object
            obj.variables.nonObsPeriods = nonObsPeriods;                       
            obj.variables.obsDays = obsDays;                       
                        
            % Set the indexes to the unmetered data. The indexes are used
            % to efficiently find the forcing date time points for a given
            % time point of a given time-step.
            setTimestepIndexes(obj,obj.settings.downscalingTimeStepCurrent)
            
            % Set the pump usage data. The following should be identical to
            % updateStochForcingData(obj) but without the change to the
            % pump state.
            %----------            
            % Get the mean daily pumping rate during the metered periods.
            dailyRate = getDailyAveragePumpingRates(obj, -inf, inf);

            % Filter out periods for which the daily rate could not be calculated.
            dailyRate = dailyRate(isfinite(dailyRate(:,end)),:);

            % Build a table of pump numbers and names
            if isfield(obj.variables,'pumpNumTable')
                obj.variables = rmfield(obj.variables,'pumpNumTable');
            end
            getPumpNumTable(obj);
                   
            % Update pumping rates based on new pump states
            for i=1:size(obj.variables.pumpNumTable ,1)

                % Get the current pump name and number.
                pumpNum = obj.variables.pumpNumTable.pumpNum(i);
                pumpName = obj.variables.pumpNumTable.pumpName{i};
                
                % Initialise daily pump rate to mean
                filt = dailyRate(:,1) == obj.variables.pumpNumTable{i,1};
                dailyRate_median = median(dailyRate(filt ,5));
                obj.variables.(pumpName)(:,7)=dailyRate_median;

                % Initialise daily pump volume to nan
                obj.variables.(pumpName)(:,8)=nan;

                % Assign the average daily pumping rate during each metered period
                filt = find(dailyRate(:,1) ==pumpNum)';
                for j=filt                        
                    filt_obsPeriods =  obj.variables.(pumpName)(:,1) >= dailyRate(j,2) & obj.variables.(pumpName)(:,1) <= dailyRate(j,3); 
                    obj.variables.(pumpName)(filt_obsPeriods,7)=dailyRate(j,5);
                end

                % Multiple pump state by daily rate to create down-scaled pumping rate
                obj.variables.(pumpName)(:,8)=obj.variables.(pumpName)(:,6).*obj.variables.(pumpName)(:,7);
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


            % Get the parameter names
            param_names = properties(obj);
            filt = cellfun( @(x) ~strcmp(x,'settings') && ~strcmp(x,'variables'), param_names);
            param_names = param_names(filt);
            
            % Cycle through each parameter and assign the parameter value.
            for i=1: length(param_names)
               obj.(param_names{i}) = params(i,:); 
            end
            
            % Check if the parameters have changed since the last call to
            % setTransformedForcing.
            detectParameterChange(obj, params);   
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


            % Store only the columns listed in obj.settings.forcingData_colnames
            % ie those needed and index within obj.settings.forcingData_cols
            if length(forcingData_colnames) < length(obj.settings.forcingData_colnames)
                error('The number of column name to be set is less than that used to build the object.');
            end
            forcingDataNew = nan(size(forcingData,1),length(obj.settings.forcingData_colnames));
            for i=1:length(forcingData_colnames)               
                filt  = strcmp(obj.settings.forcingData_colnames, forcingData_colnames{i});
                if ~isempty(filt)
                    forcingDataNew(:,filt) = forcingData(:,i);
                end
            end
            obj.settings.forcingData = forcingDataNew;
                        
        end                

        function forcingData = getStochForcingData(obj)        
           
            % Get pump names and numbers
            getPumpNumTable(obj);    

            % Check if there are sufficient metereed usage observations
            % WITHIN the calibration at each bore. If there are not any
            % metered usage values then an error should be thrown.
            updateStochForcingData(obj);
            
            % Get pump states from each bore.
            for i=1:size(obj.variables.pumpNumTable ,1)
                pumpName = obj.variables.pumpNumTable.pumpName{i};
                forcingData.(pumpName) = logical(obj.variables.(pumpName)(:,6));                                                            
            end                
        end
        
        function setStochForcingState(obj,doingCalibration, t_start_calib, t_end_calib)
            obj.variables.doingCalibration = doingCalibration;

            % Update the calibration period
            obj.variables.t_start_calib = t_start_calib;
            obj.variables.t_end_calib = t_end_calib;              
            
            % Build downscaling indexes using t_start_calib and
            % t_end_calib.
            if doingCalibration
                % Re-initialise downscaling time stwp
                obj.settings.downscalingTimeStepCurrent = '(none)';
                
                % Re-build lookup indexes for the starting downscaling time step.
                setTimestepIndexes(obj, obj.settings.downscalingTimeStepCurrent, t_start_calib, t_end_calib)                
            end
            
        end
                
        function finishedStochForcing = updateStochForcingData(obj, forcingData, refineStochForcingMethod)
            
            % Only update stochastic forcing if doing calibration
            if isfield(obj.variables,'doingCalibration') && ~obj.variables.doingCalibration
                finishedStochForcing = true;
            else
                % Initilaise output
                finishedStochForcing = false;

                % Estimate the mean daily pumping rate during the metered
                % periods.
                [dailyRate, ind_dailyRate] = getDailyAveragePumpingRates(obj,obj.variables.t_start_calib, obj.variables.t_end_calib);

                % Filter out periods for which the daily rate could not be
                % calculated.
                dailyRate = dailyRate(isfinite(dailyRate(:,end)),:);

                % Get pump names and numbers
                pumpNumTable=getPumpNumTable(obj);

                % Update the pump state if input.
                if nargin>=2

                    % Get names of pumps within the input forcing data.
                    pumpsNames_input =  fieldnames(forcingData);

                    % Loop through each input names and assign the forcing data
                    % to the object.
                    for i=1:length(pumpsNames_input)

                        
                        % Check the input field name is within the object
                        % already.
                        if ~any(strcmp(obj.variables.pumpNumTable.pumpName, pumpsNames_input{i}))
                            error('A fieldname within the input "forcingData" is not listed within the pumpingRate_SAestimation object.');
                        end

                        % Check the input number of days is as expected.
                        if size(forcingData.(pumpsNames_input{i}),1) ~= size(obj.variables.(pumpsNames_input{i}),1)
                            error(['The number of rows within forcingData.',pumpsNames_input{i},' does not equal that within the corresponding  pumpingRate_SAestimation variable.']);
                        end 

                        % Assess if each metered period with pump rate >0 has >0 periods with
                        % the pump on. That is, if a metered period to be downscaled has usage
                        % >0 then the days when the pump is on must be >0.
                        % In doing this assessment, periods of daily
                        % metered usage are not assessed because they are
                        % not to be downscaled.
                        %-------------

                        % Find the pump number for the cirrent value of i.
                        filt = find(strcmp(obj.variables.pumpNumTable.pumpName, pumpsNames_input{i}));
                        pumpNum = obj.variables.pumpNumTable.pumpNum(filt);
                        pumpName = obj.variables.pumpNumTable.pumpName{filt};
                        
                        
                        % Filter for any metered periods.
                        filt = [find(dailyRate(:,1)==pumpNum)]';

                        isValidPumpState = true;
                        for j=filt                            
                           filt_obsPeriods =  obj.variables.(pumpName)(:,1) >= dailyRate(j,2) ...
                                              & obj.variables.(pumpName)(:,1) <= dailyRate(j,3); 
                           if  sum(filt_obsPeriods)>0 && sum(forcingData.(pumpName)(filt_obsPeriods)) <=0
                               isValidPumpState = false;
                           end
                        end
                        %-------------

                        % Assign input forcing
                        if isValidPumpState
                            obj.variables.(pumpName)(:,6) = double(forcingData.(pumpName));
                        end

                    end
                end

                % Redefine the downscaling time step if the new AND if
                % different to the current time step
                if nargin==3 && refineStochForcingMethod

                    % Check if the bore downscaling is already at the user specified
                    % time-step. If so, exit if() and return that the time step
                    % was not refined.
                    if strcmp(lower(obj.settings.downscalingTimeStepCurrent), lower(obj.settings.downscalingTimeStepFinal))
                        finishedStochForcing = true;
                    else 
                        switch lower(obj.settings.downscalingTimeStepCurrent)
                            case 'daily'
                                finishedStochForcing  = true;
                            case 'weekly'
                                obj.settings.downscalingTimeStepCurrent = 'daily';
                                finishedStochForcing  = false;
                            case 'monthly'
                                obj.settings.downscalingTimeStepCurrent = 'weekly';
                                finishedStochForcing  = false;
                            case '(none)'
                                obj.settings.downscalingTimeStepCurrent = 'monthly';
                                finishedStochForcing  = false;
                            otherwise
                                error(['The following time-step for generation of forcing data is not recognised:',obj.settings.downscalingTimeStepCurrent])
                        end                
                    end                        

                    % If the downscaling time step is not yet at the final
                    % user set resolution, then re-build the time-step
                    % indexes for the new time step size. Importantly,
                    % setTimestepIndexes() preserves the pump states from
                    % the prior time step and copies them to the new time
                    % step.
                    if ~finishedStochForcing
                        setTimestepIndexes(obj, obj.settings.downscalingTimeStepCurrent)
                    end

                end

                % Reculate the pump rates if the forcing state was input.
                if nargin>1
                    % Update the mean daily pumping rate during the metered
                    % periods because the pump state changed.
                    [dailyRate, ind_dailyRate] = getDailyAveragePumpingRates(obj,obj.variables.t_start_calib, obj.variables.t_end_calib);
                    
                    % Filter out periods for which the daily rate could not be
                    % calculated.
                    dailyRate = dailyRate(isfinite(dailyRate(:,end)),:);
                end
                % Update pumping rates based on new pump states
                for i=1:size(pumpNumTable,1)

                    % Get the current pump name and number.
                    pumpNum = obj.variables.pumpNumTable.pumpNum(i);
                    pumpName = obj.variables.pumpNumTable.pumpName{i};
                    
                    % Get indexes to the current pump number.
                    filt = find(dailyRate(:,1) == pumpNum)';
                    
                    % If there are no metered usage rates within the calib 
                    % period AND there are dates where the pumping needs to
                    % be estimated (but not downscaled), then an estimate 
                    % can not be made because the median rate cannot be
                    % estimated.
                    filt_calibPeriod = obj.variables.(pumpName)(:,1)<=obj.variables.t_end_calib;
                    if isempty(filt) && any(~isfinite(obj.variables.(pumpName)(filt_calibPeriod ,4)))
                        error(['Pump ',pumpName,' has no metered usage in calib. period.'])
                    end
                    
                    % Calculate the median metered pump rate. 
                    dailyRate_median = median(dailyRate(filt ,5));
                    
                    % Assign the average daily pumping rate during each
                    % metered period. NOTE, this task was the most
                    % computationally intesive steps in the evaluation of
                    % the objective function. Initially, this was addressed
                    % by using bsxfun commands for situations when there
                    % are >5 periods to assign downscaled pumping. However
                    % in trials for the Warrion management area (Victoria, Australia)
                    % the bsxfun steps still used ~60% of CPU time. After
                    % some trials, the computational demand was
                    % significantly reduced by having getDailyAveragePumpingRates()
                    % return indexes to each row of obj.variables.(pumpName)
                    % and the associated downscaled pumping for the row.
                    % This approach eliminated the need for the bsxfun
                    % commands!!!
                    %------------------------------------
%                     filt=find(dailyRate(:,1) == pumpNum & (dailyRate(:,3)-dailyRate(:,2))>1)';
%                     if length(filt)>5                           
%                         filt_obsPeriods=bsxfun(@ge, obj.variables.(pumpName)(:,1), dailyRate(filt,2)') & bsxfun(@le, obj.variables.(pumpName)(:,1), dailyRate(filt,3)');
%                         obj.variables.(pumpName)(:,7) = sum(bsxfun(@times, filt_obsPeriods, dailyRate(filt,5)'),2) + all(~filt_obsPeriods,2) * dailyRate_median;                        
%                     else
%                         obj.variables.(pumpName)(:,7)=dailyRate_median;
%                         for j=filt                        
%                             filt_obsPeriods = bsxfun(@ge, obj.variables.(pumpName)(:,1), dailyRate(j,2)') & bsxfun(@le, obj.variables.(pumpName)(:,1), dailyRate(j,3)');
%                             obj.variables.(pumpName)(ind_obsPeriods,7)=dailyRate(j,5);
%                         end                    
%                     end
                    % Add median pump rate to all time points.
                    obj.variables.(pumpName)(:,7)=dailyRate_median;                   
                    % Add metered pump rate (is any exists).
                    if ~isempty(ind_dailyRate.(pumpName))
                        obj.variables.(pumpName)(ind_dailyRate.(pumpName)(:,1),7)  = ind_dailyRate.(pumpName)(:,2);
                    end
                    %------------------------------------
                    
                    % Multiple pump state by daily rate to create down-scaled pumping rate
                    obj.variables.(pumpName)(:,8)=obj.variables.(pumpName)(:,6).*obj.variables.(pumpName)(:,7);
                end
            end
        end
        
%% Randomise the model parameters. 
%  This function should be called at the end of an evolutionary loop to
%  avoid the parameters converging to a local minimum
        function updateStochForcingParameters(obj, forcingData)

            % Get the parameter bounds
            [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(obj);
                        
            % Cycle through each parameter and randoly assign the parameter value.
            newparams = params_lowerLimit + (params_upperLimit - params_lowerLimit) .* rand(size(params_lowerLimit));
            
            % Set the new parameter 
            setParameters(obj, newparams );            
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
            % Get the parameter names
            param_names = properties(obj);
            filt = cellfun( @(x) ~strcmp(x,'settings') && ~strcmp(x,'variables'), param_names);
            param_names = param_names(filt);
            
            % Cycle through each parameter and assign the parameter value.
            params=[];
            for i=1: length(param_names)
               params(i,:) = obj.(param_names{i}); 
            end
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

            [params, param_names] = getParameters(obj);            
            params_lowerLimit = -1.*ones(size(params));
            params_upperLimit = ones(size(params));
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
            [params, param_names] = getParameters(obj);            
            params_lowerLimit = -1.*ones(size(params));
            params_upperLimit = ones(size(params));
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

            % Only change the stochatsic forcing if doing calibration.
            if ~isfield(obj.variables,'doingCalibration') || obj.variables.doingCalibration

                % Filter the forcing data to input t.
                filt_time = obj.settings.forcingData(:,1) >= t(1) & obj.settings.forcingData(:,1) <= t(end);

                % Store the time points
                obj.variables.t = t(filt_time);

                % Get the start and end date for downscaled periods for
                % each pump.
                %------------                
                % Build vector of from non-obs periods 'nonObsPeriods' of bore number, 
                % start and end date of non-metered periods.
                dailyRate = cell2mat(obj.variables.nonObsPeriods(:,[1,3,4]));
                
                % Filter out periods that do not have a metered reading
                filt = isfinite(cell2mat(obj.variables.nonObsPeriods(:,5)));
                dailyRate = dailyRate(filt,:);
                
                % Add the daily metered volumes. Since these readings are for a
                % single day, the the start and end dates are equal.
                dailyRate = [dailyRate; [obj.variables.obsDays(:,1), obj.variables.obsDays(:,2), obj.variables.obsDays(:,2)]];
                %------------
                
                % Get the object parameters.
                [params, param_names] = getParameters(obj);

                % Get the table of pump numbers and names if it exists,
                % else built it
                pumpNumTable = getPumpNumTable(obj);
                
                % Loop through each PARAMETER, find the date to edit pumping state and 
                % then update the state. Once updated, calculate the median
                % pumping rate for each period using ONLY the periods with
                % a metered total extraction volume. Then, apply the
                % average pumping rate to all periods without metered total
                % extractions.                
                for i=1:size(params,1)

                    % Get bore names.
                    pumpName = param_names{i}(1:end-9);

                    % Get pump number 
                    pumpNum = pumpNumTable.pumpNum(strcmp(pumpNumTable.pumpName,pumpName));

                    % Find the number of discrete time steps possible
                    ind_calibDays = obj.variables.(pumpName)(:,3)>0;
                    timestepMax = length((unique(obj.variables.(pumpName)(ind_calibDays,3))));

                    % Find normalised time-period from all periods of non-daily pumping.                    
                    timestepValNormalised = ceil(abs(params(i)) * timestepMax)/timestepMax;
                    filt = obj.variables.(pumpName)(:,5)==timestepValNormalised;

                    % Calc number of pumping days to change.
                    nDaysToChange = sum(filt);                   

                    % Find if the current time point is a metered period.
                    filt_dailyRate = find(dailyRate(:,1) == pumpNum)';
                    date2Chnage = obj.variables.(pumpName)(filt,1);
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
                    if isfinite(dailyRate_index) && max(obj.variables.(pumpName)(filt,6))==1 && params(i)<sqrt(eps())

                        filt_periodPumpingDays = obj.variables.(pumpName)(:,1) >=dailyRate(dailyRate_index,2) ...
                        & obj.variables.(pumpName)(:,1) <= dailyRate(dailyRate_index,3);

                        nPeriodPumpingDays = sum(obj.variables.(pumpName)(filt_periodPumpingDays,6));

                        if nPeriodPumpingDays <= nDaysToChange
                            changePumpState = false;
                            isValidPumpState=false;
                        end
                    end                                        
                    if changePumpState 
                        %obj.variables.(pumpName{i})(filt,6) = double(newPumpState);
                        if params(i)>sqrt(eps())
                            obj.variables.(pumpName)(filt,6) = 1;
                        elseif params(i)<-sqrt(eps())
                            obj.variables.(pumpName)(filt,6) = 0;
                        end    
                    else
                        % do nothing
                        changePumpState = false;
                    end
                end  
                
                % Update the average daily pump date over each time step
                % and bore and then multiple by the pump state.
                updateStochForcingData(obj);
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
                    colForcingData_filt = strcmp(obj.settings.forcingData_cols(:,1), variableName{i});
                    colForcingData = obj.settings.forcingData_cols{colForcingData_filt,2};
                    if i==1
                        forcingData = obj.settings.forcingData(:,colForcingData);
                    else
                        forcingData(:,i) = obj.settings.forcingData(:,colForcingData);
                    end
                    
                    % Skip if the pump was removed because if could not be
                    % downscaled
                    if (~isfield(obj.variables,variableName{i}))
                        continue;
                    end
                    
                    % Add stochastically generated forcing data
                    filt_calibPeriod = obj.variables.(variableName{i})(:,2)>0;
                    forcingData(obj.variables.(variableName{i})(filt_calibPeriod,2),i) = obj.variables.(variableName{i})(filt_calibPeriod ,8);                                                         
                    
                    % If there are any remaining -999s, then these should
                    % be in evaluation periods. To handle this, the mean daily
                    % extractions is calculated for each day of the year.
                    % Also the mean pump state (on or off) is calculated. 
                    % Importantly, the averages are calculated using only
                    % data from the first non-zero value ie once the pump
                    % was active. The former is then used for periods of
                    % -999 without a metered volume for the period. The
                    % latter is used for the metered periods and is used to
                    % weight the metered volume to the -999 days.
                    if ~obj.variables.doingCalibration
                        
                        % Find remaining periods of-999s.
                        ind_999s = find(forcingData(:,i) == -999);

                        % If there are any -999s then, firstly, calculate the
                        % probability of the pumping being on for each calendar
                        % day. This is done using data from the first >0 value
                        % up to end of the calibration period?
                        if ~isempty(ind_999s)

                            % Build indexes to the start of pumping and the end
                            % of the calibration period.
                            obsTime = obj.settings.forcingData(:, 1);
                            ind_startOfPumping = find(forcingData(:,i)>0,1,'first');                        
                            if isfield(obj.variables,'t_end_calib') && isfinite(obj.variables.t_end_calib)
                                ind_endOfCalib = find(obsTime>=obj.variables.t_end_calib,1,'first');
                            else
                                ind_endOfCalib = size(obsTime,1);
                            end
                            filt_obsTimes = obsTime>=obsTime(ind_startOfPumping) & obsTime<=obsTime(ind_endOfCalib) & forcingData(:,i)~=-999;

                            % Calculate the probability that the pump is on
                            % during each calander day.                        
                            [monthsDays,~,ind] = unique(month(obsTime(filt_obsTimes))*100+day(obsTime(filt_obsTimes)),'rows');
                            meanUsagePerDay = accumarray(ind, forcingData(filt_obsTimes,i), [], @mean);                
                            meanUsagePerDay = [monthsDays, meanUsagePerDay];

                            % Calculate the mean probability that the pump is on for
                            % each day day of the year.
                            meanProbPumpOn = accumarray(ind, forcingData(filt_obsTimes,i)>0, [], @mean);
                            meanProbPumpOn = [monthsDays, meanProbPumpOn];                        

                            % Find the periods of -999s with a meter reading
                            % >0 immediatly after a -999.
                            ind_999s_metered = ind_999s(forcingData(min(ind_999s+1,size(forcingData,1)),i)>0);

                            % Loop through the -999 metered periods and
                            % downscale the metered volume using the mean
                            % probability of the pump being on.
                            for j=1:length(ind_999s_metered)

                                % Find the metered volume for the period.
                                pumpingVol = forcingData(min(size(forcingData,1),ind_999s_metered(j)+1),i);                            

                                % Find the first -999 for the metered period.
                                k = ind_999s_metered(j);
                                while forcingData(k,i) == -999
                                    k = k-1;
                                end
                                k=k+1;

                                % Set indexes to the -999s for the metered 
                                % period. Note, the period includes the first 
                                % day after the -999s because it to is to
                                % be downscaled because the value
                                % represents the total metered volume over the
                                % preceeding period of -999s.
                                ind_999s_metered_period  = k:(ind_999s_metered(j)+1);

                                % Build index to the days and months for the period of
                                % -999s.
                                ind_monthsDays = zeros(length(ind_999s_metered_period),1);
                                monthDay_period = month(obsTime(ind_999s_metered_period))*100+day(obsTime(ind_999s_metered_period));
                                for el=1:length(ind_999s_metered_period)
                                    ind_monthsDays(el,1) = find(monthsDays == monthDay_period(el),1,'first');    
                                end
                                    
                                % Get the average pump state for the period.
                                downscalingWeights = meanProbPumpOn(ind_monthsDays,2);
                                downscalingWeights = downscalingWeights./sum(downscalingWeights);

                                % Replace non-finite values by 0. 
                                downscalingWeights(~isfinite(downscalingWeights))=0;
                                
                                % Down scale using the weighting.
                                if sum(downscalingWeights)==0
                                    pumpingVol = pumpingVol./(length(downscalingWeights).*ones(size(downscalingWeights)));
                                else
                                    pumpingVol = pumpingVol.*downscalingWeights;
                                end

                                % Assign downscaled weights to the forcing
                                % data.
                                forcingData(ind_999s_metered_period,i) = pumpingVol;
                            end

                            % Find the remaining -999s.
                            ind_999s = find(forcingData(:,i) == -999);

                            % Find the day and month of each -999 day
                            monthDay_period = month(obsTime(ind_999s))*100+day(obsTime(ind_999s));

                            % Loop though each periods of -999s and apply the
                            % average usage for each day of the year.                         
                            for j=1:length(monthDay_period)                           
                                ind_monthsDays = find(monthsDays == monthDay_period(j),1,'first');
                                forcingData(ind_999s(j),i) = meanUsagePerDay(ind_monthsDays ,2);
                            end

                        end     
                    end
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
                
            % Check each requested variable is within forcingData_cols
            for i=1:length(variableName)
                if ~any(strcmp(variableName{i}, obj.settings.forcingData_cols(:,1)))
                    error(['pumpingRate_SAestiation: Inconsistency between selected downscaled pumps and weighting function input data. See ',variableName{i}])
                end
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
                
        % Get/build a table of of pump numes and numbers
        function pumpNumTable=getPumpNumTable(obj)            
            if isfield(obj.variables,'pumpNumTable')
                % Get the table of pump numbers and names if it exists.
                pumpNumTable = obj.variables.pumpNumTable;
            else
                % Build table.
                pumpNumTable = unique(cell2table(obj.variables.nonObsPeriods(:,1:2),'VariableNames',{'pumpNum','pumpName'}),'rows');
                obj.variables.pumpNumTable = pumpNumTable;
            end
        end
        
        % Calculate the mean daily pumping rate for each period with metered volume. 
        % Returns matrix of size(obj.variables.nonObsPeriods,1) with
        % pump number, start date for period, end date for period, average
        % daily pumping rate for the period.
        function [dailyRate,ind_dailyRate] = getDailyAveragePumpingRates(obj, t_start_calib, t_end_calib)
                  
            % Get list of non-obs periods nonObsPeriods.
            nonObsPeriods = obj.variables.nonObsPeriods;

            pumpName_all = unique(nonObsPeriods(:,2));
            for i=1:length(pumpName_all)
                ind_dailyRate.(pumpName_all{i}) = [];
            end
            
            % For each bore, calculate the average daily pumping rate
            % during each petered period.
            dailyRate = nan(size(nonObsPeriods,1),5);
            for i=1:size(nonObsPeriods,1)
                
                dailyRate(i,1) = nonObsPeriods{i,1};
                dailyRate(i,2) = nonObsPeriods{i,3};
                dailyRate(i,3) = nonObsPeriods{i,4};
                                                
                % Check if the pumping was metered for the period.
                if ~isfinite(nonObsPeriods{i,5})
                    continue
                end
                
                % Check the period of metered total extractions is within
                % the calcibration time range t. That is, if the end
                % date of the metered period is after the end calib period
                % then do not use the metered rate.
                if dailyRate(i,3) > t_end_calib
                    continue
                end
                                
                % get the pump names
                pumpName = nonObsPeriods{i,2};
                
                % Find the number of days the pump is recorded as 'on'. 
                [~,ind_from] = ismember(dailyRate(i,2),obj.variables.(pumpName)(:,1));
                [~,ind_to] = ismember(dailyRate(i,3),obj.variables.(pumpName)(:,1));
                ind = ind_from:ind_to;
                
                %filt_obsPeriods =  obj.variables.(pumpName)(:,1) >= dailyRate(i,2) & obj.variables.(pumpName)(:,1) <= dailyRate(i,3); 
                dailyRate(i,4) = sum(obj.variables.(pumpName)(ind,6));
                
                % Calculate average daily pumping rate for the period.
                dailyRate(i,5) = nonObsPeriods{i,5}/dailyRate(i,4);                            
                
                ind_dailyRate.(pumpName) = [ind_dailyRate.(pumpName); [ind', repmat(dailyRate(i,5), length(ind),1)]];
            end        
            
            % Add the daily metered volumes. Since these readings are for a
            % single day, the the start and end dates are equal.
            % Importantly, ONLY daily metered usage before the calibration
            % end date is added.
            filt = obj.variables.obsDays(:,2)<=t_end_calib;
            if sum(filt)>0
                dailyRate = [dailyRate; [obj.variables.obsDays(filt ,1), ...
                    obj.variables.obsDays(filt ,2), obj.variables.obsDays(filt ,2), ones(sum(filt),1), obj.variables.obsDays(filt ,3)]];           
            end
        end
        
        function setTimestepIndexes(obj, updateTimeStep, t_start_calib, t_end_calib)
           
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

                        % Create a lookup conversion table for each production bore to
                        % transform the date to alter pumping (propName) and the true
                        % date. Each production bore has one numeric matrix
                        % with the following format.
                        %   - date (from obj.settings.forcingData) for each period without daily metering
                        %   - row index to input forcing data
                        %   - time-step integer for user-set downscaled time-step
                        %   - time-step for only periods with metering normalised from 0 to 1.                        
                        %   - time-step all periods without daily metering normalised from 0 to 1.                        
                        %   - 0/1 for the pumping being on or off over the user set time period.
                        %   - The pumping rate for the period (assigned in
                        %   updateStochasticForcingData()).
                        %   - The daily extraction rate (pump state * pump rate).
                        %
                        if isfield(obj.variables,pumpName) && size(obj.variables.(pumpName),1)>0
                            updateExistingTable = true;
                        else
                            updateExistingTable = false;
                            obj.variables.(pumpName) = zeros(0,8);
                        end
                        for j=filt
                            
                            % Get dates for non-obs period
                            sDate = obj.variables.nonObsPeriods{j,3};
                            eDate = obj.variables.nonObsPeriods{j,4};                                                        
                                                        
                            % Setup non-obs days
                            nonObsDays = [sDate:eDate]';
                            
                            % Get index to non obs days
                            nonObsDaysIndex = find(obj.settings.forcingData(:,1) >=sDate & obj.settings.forcingData(:,1) <=eDate);
                            
                            % Convert non-obs days increments for user set time-step
                            switch lower(updateTimeStep)
                                case 'daily'
                                    nonObsSteps = year(nonObsDays) *1000 + day(datetime(nonObsDays,'ConvertFrom','datenum'), 'dayofyear');
                                case 'weekly'
                                    nonObsSteps = year(nonObsDays) *1000 + week(datetime(nonObsDays,'ConvertFrom','datenum'));
                                case 'monthly'
                                    nonObsSteps = year(nonObsDays) *1000 + month(nonObsDays);
                                case '(none)'
                                    nonObsSteps = ones(length(nonObsDays),1) * j;                                    
                                otherwise
                                    error(['The following time-step for generation of forcing data is not recognised:',updateTimeStep])
                            end
                            
                            % Set junk data for normalised time-step value.
                            nonObsStepsNormalised = zeros(size(nonObsSteps));
                            
                            % Build temporary vector to denote if the
                            % total extractions for the periods were
                            % metered.
                            if isfinite(obj.variables.nonObsPeriods{j,5})
                                isMeteredPeriod = ones(size(nonObsSteps));
                            else
                                isMeteredPeriod = zeros(size(nonObsSteps));
                            end
                            
                            % Limit dates to only calibration periods.
                            if nargin==4 && any(nonObsDays > t_end_calib)
                                
                                % If part of the period without daily metering is 
                                % less than the end date of the
                                % calibration then, for the
                                % calibration, set the dates
                                % <=t_end_calib to be unmetered.                                
                                filt_calibDays = nonObsDays <= t_end_calib;
                                if any(filt_calibDays)
                                    isMeteredPeriod(filt_calibDays) = 0;                                    
                                end
                                
                                % Change the nonObsSteps to dates to zero.
                                % Below, nonObsSteps==0 are filtered from
                                % the normalisation and so calibration will
                                % not change the pump state after
                                % t_end_calib.
                                nonObsSteps(nonObsDays > t_end_calib) = 0;
                                
                                % Also, change the indexes to zero. This is
                                % required so that within getTransformed
                                % Forcing() only the transformted data for the 
                                % calibration period is added to input
                                % forcing data.
                                nonObsDaysIndex(nonObsDays > t_end_calib) = 0;
                            end
                            
                            
                            % Set pump to 'on' for each time step
                            nonObsPumpState = ones(size(nonObsSteps));
                            
                            if updateExistingTable
                                % Find rows to be updated within existing
                                % table.
                                filt_existingTable = find(obj.variables.(pumpName)(:,1) >=sDate & obj.variables.(pumpName)(:,1) <=eDate);

                                % Create matrix of new lookup data.
                                newLookupTableRows = [nonObsDays nonObsDaysIndex nonObsSteps isMeteredPeriod nonObsStepsNormalised];
                                                                
                                % Update table rows BUT NOT THE PUMPING STATE.
                                obj.variables.(pumpName)(filt_existingTable ,1:5) = newLookupTableRows;
                            else                                
                                % Create matrix of new lookup data.
                                newLookupTableRows = [nonObsDays nonObsDaysIndex nonObsSteps isMeteredPeriod nonObsStepsNormalised nonObsPumpState];
                                
                                if isempty(obj.variables.(pumpName))
                                    obj.variables.(pumpName) = newLookupTableRows;
                                else
                                    obj.variables.(pumpName) = [obj.variables.(pumpName); newLookupTableRows];
                                end
                            end
                        end            
                        
                        % Normalise 'nonObsSteps' during periods a metered total volume
                        % so that required time step at which the pump state to be changed can
                        % be located from the pumping bore class parameter.
                        ind_metered = find(obj.variables.(pumpName)(:,4)==1 & obj.variables.(pumpName)(:,3)>0);
                        ind_notMetered = find(obj.variables.(pumpName)(:,4)==0 & obj.variables.(pumpName)(:,3)>0);
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
                        ind_calibDays = find(obj.variables.(pumpName)(:,3)>0);
                        nonObsStepsUnique = sort(unique(obj.variables.(pumpName)(ind_calibDays,3)));
                        for k=1:length(nonObsStepsUnique)
                            filt_timesteps = obj.variables.(pumpName)(:,3) == nonObsStepsUnique(k);
                            obj.variables.(pumpName)(filt_timesteps ,5) = k;
                        end                        
                        obj.variables.(pumpName)(:,5) = obj.variables.(pumpName)(:,5)/length(nonObsStepsUnique);
                    end                                                    
                    
                end                
            end
            
            
        end
    end
    
end


