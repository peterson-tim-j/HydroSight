classdef GroundwaterStatisticsToolbox < handle
% Class definition for building a time-series model of groundwater head.
%
% Description
%   This class allows the building, calibration, simulation and interpolation
%   of a dynamic type of model. The model type is defined within a seperate
%   class object and must adhere to the structure as defined within the
%   abstract class 'model_abstract.m'. To date the following models have
%   been developed: 
%
%       - 'model_TFN': Transfer Function Noise model of Peterson and
%          Western (2014) and von Asmuth et al. (2005). To run this model,
%          the following MEX .c source-code file may need to be compiled:
%           - 'doIRFconvolution.c'
%           - 'forcingTransform_soilMoisture.c'            
% 
%   Below are links to the details of the public methods of this class. 
%   The example presented uses the 'model_TFN' model. 
% 
%   To open an example model, add the folder and sub-folders of 
%   'Model_Algorithms' to the MatLab path and then enter the following
%   command: 
%   open example_TFN_model()
%
%   Prior to running the example,  consider starting the matlab parrallel
%   processor: eg matlabpool 4.
%   
% See also
%   GroundwaterStatisticsToolbox: model_construction;
%   calibrateModel: model_calibration;
%   solveModel: solve_the_model;
%   interpolateData: - interpolate_and_extrapolate_observation_data;
%   model_TFN: - constructor_for_transfer_fuction_noise_models;
%
% Dependencies
%   model_TFN.m
%   variogram.m
%   variogramfit.m
%   lsqcurvefit.m
%   IPDM.m
%   trialData.mat
%
% References:
%   Peterson and Western (2014), Nonlinear time-series modeling of unconfined
%   groundwater head, Water Resources Research, DOI: 10.1002/2013WR014800
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure 
%   Engineering, The University of Melbourne, Australia
%
% Date:
%   26 Sept 2014
%
% Version:
%   3.30
%
% License:
%   GNU GPL3 or later.
%
    properties

        % Model Label
        model_label
        
        % Bore ID (string). Most model types require the bore ID to be listed within the coordinates file. 
        bore_ID;
        
        % Model class object.       
        model;
        
        % Calibration results structure.
        calibrationResults;
        % Evaluation results structure.
        evaluationResults;  
        % Simulation results structure.        
        simulationResults;
    end
    

%%  STATIC METHODS        
% Static methods used by the Graphical User Interface to inform the
% user of the available model types. Any new models must be listed here
% in order to be accessable within the GUI.
    methods(Static)
        function [types,recommendedType] = model_types()
            types = {'model_TFN','Transfer function noise model with nonlinear transformation of climate forcing' ; ...
                    'model_HARTT','Linear regression model usinf cumulative rainfall residual'};
            recommendedType = 1;    
        end
    end    

%%  PUBLIC METHODS     
    methods
%% Construct the model
        function obj = GroundwaterStatisticsToolbox(model_label, bore_ID, model_class_name, obsHead, obsHead_maxObsFreq, forcingData, siteCoordinates, varargin)
% Model construction.
%
% Syntax:
%   model = GroundwaterStatisticsToolbox(bore_ID, model_str , obsHead, obsHead_maxObsFreq, forcingData, modelOptions)
%
% Description:
%   Builds the model object, declares initial parameters and sets the
%   observation and forcing data. This is the method that must be called in
%   order to build a new model. The form of the model is entirely defined
%   by the specificied 'model_class_name'. This a highly flexible model
%   structure and the efficient inclusion of new model types.
%
%   For details of how to build a linear and nonlinear transfer function
%   noise model, see the documentation for model_TFN.m. To open an example 
%   model, add the folder and sub-folders of 'Model_Algorithms' to the
%   MatLab path and then enter the following command: 
%   open example_TFN_model()
%
% Input:
%   model_label - label for describing the model. This is only used to
%   inform the user of the model.
%   
%   bore_ID - string identified for the model, eg 'Bore_ID_1234'. This bore
%   ID must be listed within the cell array of 'siteCoordinates'.
%
%   model_class_name - string of the model type to be built. A class
%   definition must already have been written for the model type. To date
%   the following inputs are allows:
%       - 'model_TFN'
%
%   obsHead - Nx5 matrix of observed groundwater elevation data. The
%   matrix must comprise of the following columns: year, month, day, hour,
%   water level elevation. The data can be of a sub-daily frequency and
%   of an non-uniform frequency. However, the method will aggregate
%   sub-daily observations to daily observations by taling the last
%   observation of the day.
%
%   obsHead_maxObsFreq - scalar for the maximum frequency of observation
%   data. This input allows the upscaling of daily head data to, say,
%   monthly freqency data. This feature was included to overcome large
%   computational demands when calibrating the model to daily data.
%
%   forcingData - a variable data-type input containing the forcing data (e.g.
%   daily precipitation, potential evapo-transpiration, pumping at each site)
%   and column headings. The input can be of the following form:
%      - structure data-type with field named 'colnames' and 'data' where 
%        'data' contains only numeric data;
%      - cell array with the first row being the column names and lower
%        rows being numerical data.
%      - or a table data-type with the heading being the column names
%        (NOTE: this input form is only available for Matlab 2013b or later). 
%
%   The forcing data must comprise of the following columns: year, month,
%   day, observation data. The observation data must include precipitation
%   but may include other data as defined within the input model options. 
%   The record must be continuous (no skipped days) and cannot contain blank
%   observations and start prior to the first groundwater level
%   observation (ideally, it should start many years prior). Each forcing
%   data column name must be listed within the cell array 'siteCoordinates'
%
%   siteCoordinates - Mx3 cell matrix containing the following columns :
%   site ID, projected easting, projected northing. 
%
%   Importantly, the input 'bore_ID' must be listed and all columns within
%   the forcing data (excluding the year, month,day). Additionally, sites
%   (and coordinates) not listed in the input 'forcingData' can be input.
%   This provides a means for image wells to be input.
%   
%   modelOptions - cell matrix defining the model componants, ie how the
%   model should be constructed. The structure of the model options are
%   entirely dependent upon the model type. See the construction
%   documentation for the relevant model.
%
% Output:
%   model - GroundwaterStatisticsToolbox class object 
%
% Example: 
%   Load the input trial data:
%   >> load trialData
%
%   Create a cell matrix of the model options for model_TFN:
%   >> modelOptions_TFN = {'precip','weightingfunction','responseFunction_Pearsons' ;
%                          'precip','forcingdata',4}
%
%   Create bore coordinates cell array. NOTE: the coordinates below are
%   arbitrary.
%   siteCoordinates = {'124705', 100, 100; ...
%                      'precip', 100, 100 };
%
%   Build the model with a maximum frequency of observation data of 7 days:
%   >> model_124705 = GroundwaterStatisticsToolbox('Example TFN model', 'Bore 124705',  ...
%                     'model_TFN', ObsHead_BoreID_124705, 7, forcingData, ...
%                     siteCoordinates, modelOptions_TFN)
%
%                   
%   Inspect model:
%    >> open model_124705
%
% See also:
%   GroundwaterStatisticsToolbox: class_description;
%   calibrateModel: model_calibration;
%   solveModel: solve_the_model;
%   interpolateData: - interpolate_and_extrapolate_observation_data;
%   model_TFN: - constructor_for_transfer_fuction_noise_models;
%   climateTransform_soilMoistureModels: - constructor_for_soil_moisture_models;
%
% Dependencies
%   model_TFN.m
%   trialData.mat
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure
%   Engineering, The University of Melbourne.
%
% Date:
%   26 Sept 2014
%    

            % Check constructor inputs.
            if nargin < 7
                error('All seven inputs are required!');
            end            
            if size(obsHead,2) <4
                error('The input observed head must be at least four columns: year; month; day; head; which is assumed to be the last column.');
            end            
            if ~iscell(siteCoordinates)
                error('The input "siteCoordinates" must be a cell data type of >2 rows and following three columns: site ID, projected easting, projected northing');
            end
            
            % Check the form of the forcing data input
            if isnumeric(forcingData)
                error('The input forcing data cannot be a numerical array. It must be a structure data type, a cell array or a table object. Please see the model documentation.');
            elseif isstruct(forcingData)
                if isfield(forcingData,'colnames') && isfield(forcingData,'data')
                    forcingData_data = forcingData.data;
                    forcingData_colnames = forcingData.colnames;
                else
                    error('When the input forcing data is a structure data type the fields must be "colnames" and "data".');
                end                   
            elseif iscell(forcingData)
                try
                    forcingData_data = cell2mat(forcingData(2:end,:));
                    forcingData_colnames = forcingData(1,:);
                catch ME
                    error('An error occured when extracting the forcing data from the input cell array. The first row must be the column headings and all of the following rows the numeric data.');
                end
            elseif strcmp(class(forcingData),'table')
                % Assume the datatype is a table object
                forcingData_colnames = forcingData.Properties.VariableNames;
                forcingData_data = forcingData{:,:};
            else
                error('The must be a structure data type, a cell array or a table object. Please see the model documentation.');
            end
            % Check the size of the forcing data
            if size(forcingData_data,2) <4
                error('The input forcing data must be at least four columns: year, month, day, Precip');
            end
            % Check the first three columns are named year,month,day.
            forcingData_colnames(1:3) = lower(forcingData_colnames(1:3));
            if ~strcmp(forcingData_colnames(1),'year') || ~strcmp(forcingData_colnames(2),'month') || ~strcmp(forcingData_colnames(3),'day')
               error('The three left most forcing data column names must be the following and in the following order: "year,"month",day"');
            end
            
            % Derive columns of year, month, day etc to matlab date value
            forcingDates = datenum(forcingData_data(:,1), forcingData_data(:,2), forcingData_data(:,3));
            switch size(obsHead,2)-1
                case 3
                    obsDates = datenum(obsHead(:,1), obsHead(:,2), obsHead(:,3));
                case 4
                    obsDates = datenum(obsHead(:,1), obsHead(:,2), obsHead(:,3),obsHead(:,4), zeros(size(obsHead,1),1), zeros(size(obsHead,1),1));
                case 5
                    obsDates = datenum(obsHead(:,1), obsHead(:,2), obsHead(:,3),obsHead(:,4),obsHead(:,5), zeros(size(obsHead,1),1));
                case 6
                    obsDates = datenum(obsHead(:,1), obsHead(:,2), obsHead(:,3),obsHead(:,4),obsHead(:,5),obsHead(:,6));
                otherwise
                    error('The input observed head must be 4 to 7 columns with right hand column being the head and the left columns: year; month; day; hour (optional), minute (options), second (optional).');
            end
            
            % Check date limits of obs head and forcing data
            if max(diff(forcingDates)) > 1 || min(diff(forcingDates)) < 1
                error('The input forcing data must of a daily time step with no gaps!');
            end
            if strcmp(model_class_name,'')
                error('The model class name cannot be empty.');
            end           
            if max(obsDates) > max(forcingDates) || min(obsDates) < min(forcingDates) 
                error('The observed head records extend prior to and or after the forcing observations');
            end
                  
            % Check the form of the coordinate data and check that the bore
            % ID and all forcing date columns are listed within it.
            if iscell(siteCoordinates) 
               % Check the cell has 3 columsn and atleast 2 rows.
               if size(siteCoordinates,1) < 2 || size(siteCoordinates,2) ~= 3
                   error('The input "siteCoordinates" must be a cell array of three columns (site name, easting, northing) and atleast two rows (for bore ID and precipitation).');
               end
               
               % Check the bore ID coordinates are input.
               hasBoreIDCoordinates=false;
               for i=1:size(siteCoordinates,1);
                  if strcmp(siteCoordinates(i,1), bore_ID)
                      hasBoreIDCoordinates=true;
                      break;
                  end
               end
               if ~hasBoreIDCoordinates
                   error('The site coordinate cell array must list the coordinate for the input bore ID. Note, the site names are case-sensitive.');
               end               
               
               % Loop through each forcing data column.
               hasForcingCoordinate = false(1,length(forcingData_colnames)-3);
               for i=4:length(forcingData_colnames)
                   for j=1:size(siteCoordinates,1);                   
                      if strcmp(siteCoordinates(j,1), forcingData_colnames(i))
                          hasForcingCoordinate(i-3) = true;
                          break;
                      end
                   end
               end
               if any(~hasForcingCoordinate)
                   error('The site coordinate cell array must list the coordinates for all columns of the forcing data (excluding "year","month",day"). Note, the site names are case-sensitive.');
               end                              
            else
               error('The input "siteCoordinates" must be a cell array of three columns (site name, easting, northing) and atleast two rows (for bore ID and precipitation).'); 
            end
            
            % Ammend column 1-3 from year, month, day  to time.
            forcingData_data = [forcingDates, forcingData_data(:,4:end)];
            forcingData_colnames = {'time', forcingData_colnames{4:end}};
            
            % Thin out observed heads to a user defined maximum frequency.
            % This feature is included to overcome the considerable
            % computational burdon of calibrating the model to daily head
            % observations using 50+ years of prior daily climate data.
            if ~isempty(obsHead_maxObsFreq) && obsHead_maxObsFreq >0
                
                % Aggregate sub-daily observed groundwater to daily steps            
                j=1;
                ii=1;
                while ii  <= size(obsDates,1)
                    % Find last observation for the day
                    [iirow, junk] = find( obsDates == obsDates(ii,1), 1, 'last');

                    % Derive the date and time at the end of the day
                    date_time = datenum(obsHead(iirow,1), obsHead(iirow,2), obsHead(iirow,3), 23, 59, 59 );

                    % Add date and head to new matrix.
                    obsHead(j,1:2) = [ date_time , obsHead(iirow,end)];
                    j=j+1;
                    ii = iirow+1;
                end
                obsHead = obsHead(1:j-1,1:2);                
                
                % Now thin out to requested freq.
                obsHead_orig = obsHead;
                obsHead = zeros(size(obsHead));
                obsHead(1,:) = obsHead_orig(1,:);
                j=1;
                for ii = 2:size(obsHead_orig,1)
                    % Accept obs only when duration to prior accepted obs
                    % is >=  obsHead_maxObsFreq.
                    if obsHead_orig(ii,1) - obsHead(j,1) >= obsHead_maxObsFreq
                        j=j+1;
                        obsHead(j,:) = obsHead_orig(ii,:);
                    end
                end
                
                % Trim rows of zero value.
                obsHead = obsHead(1:j,:);
                
                clear obsHead_orig;
            else
                % Use all input data
                obsHead = [obsDates, obsHead(:,end)];
                
            end
            % Warn the user of the obs. date was aggregated.
            if size(obsHead,1) < size(obsHead,1)
                display([char(13), 'Warning: some input head observations were of a sub-daily frequency.', char(13), ...
                    'These have been aggregeated to a daily frequency by taking the last obseration of the day.', char(13), ...
                    'The aggregation process assumed that the input data was sorted by date and time.']);
            end
            
            % Add data to object.
            obj.model_label = model_label;            
            obj.bore_ID = bore_ID;            
            obj.model = feval(model_class_name, bore_ID, obsHead, forcingData_data, forcingData_colnames, siteCoordinates, varargin{1} );
            
            % Add flag to denote the calibration has not been undertaken.
            obj.calibrationResults.isCalibrated = false;
        end

%% Solve the model        
%        function h = solveModel(obj, time_points, doClimateLagCalcuations)
        function h = solveModel(obj, time_points, forcingData, forcingData_colnames, simulationLabel)
% Solve the model and plot modelled and observed heads.
%
% Syntax:
%   h = solveModel(obj, time_points, doClimateLagCalcuations)
%
% Description:
%   Solves the model using the calibrated parameters and, depending upon
%   the method's inputs, decomposes the groundwater head into the
%   contribution from various periods of climate forcing and plots the
%   results.
%
% Input:
%   obj -  model object
%
%   time_points - column vector of the time points to be simulated.
%
%   doClimateLagCalcuations - logical option for undertaking simulation to
%   decompose the grounwater heads into the contribution from various
%   periods historic climate forcing.
%
% Output:
%   h - matrix of simulated head formatted as the following columns:
%   date/time; simulated head; contribution from model componant 1 to n
%   Note:  simulation results are output to obj.simulationResults.
%
% Example:
%   Define the start date for simulation:
%   >> start_date = datenum(1995, 1, 1);
%
%   Define the end date for simulation:
%   >> end_date = datenum(2002, 1, 1);
%
%   Define the time points for simulation as from start_date to end_date at 
%   steps of 28 days:
%   >> time_points = [start_date : 28 : end_date]';
%
%   Solve the model object 'model_124705', with the climate decomposition.
%   >> solveModel(model_124705, time_points, true);
%
% See also:
%   GroundwaterStatisticsToolbox: class_description;
%   calibrateModel: model_calibration;
%   interpolateData: - interpolate_and_extrapolate_observation_data;
%
% Dependencies
%   model_TFN.m
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure
%   Engineering, The University of Melbourne.
%
% Date:
%   26 Sept 2014

           % Find out if the simulation label already exists. If not, add a new simulation. Else, replace it.
           if isempty(simulationLabel)
               simulationLabel = '(No label)';
           end
           if iscell(obj.simulationResults)
               
               % Find simulation label
               simInd = cellfun( @(x) strcmp(x.simulationLabel , simulationLabel), obj.simulationResults);               
               
               % Check there is only one simulation with the given label,
               % If the simulations does not exist then add a new
               % simulation. 
               if sum(simInd)>1
                   error('The input simulation label is not unique. Multiple simulations exist with this label.');                   
               elseif sum(simInd)==0                   
                   if isempty(obj.simulationResults)
                       simInd =  1;
                   else
                       simInd =  size(obj.simulationResults,1)+1;
                   end                   
               end                   
           else
                simInd =  1;
           end

           % Add the forcing data.
           if ~isempty(forcingData)
               % Get the forcing data used to build the model.
               [forcingData_modConstruc, forcingData_colnames_modConstruc] = getForcingData(obj);
               
               % Check the column names for the new forcing data are identical
               for i=1:length(forcingData_colnames)
                  if ~any(cellarray( @(x) strcmp(x, forcingData_colnames{i}), forcingData_colnames_modConstruc))
                      error('New forcing dat must have identical column names to the original data.');
                  end
               end
               
               % Assign the new forcing data and keep a copy in the
               % simulation structure.
               setForcingData(obj, forcingData, forcingData_colnames);                  
           end
           
           % Add input data for the simulation to the structure.
           obj.simulationResults{simInd,1}.simulationLabel = simulationLabel;
           if ~isempty(forcingData)
                 obj.simulationResults{simInd,1}.forcingData = forcingData;
                 obj.simulationResults{simInd,1}.forcingData_colnames = forcingData_colnames;
           end
           
           
           % Undertake the simulation of the head                      
           try
              [obj.simulationResults{simInd,1}.head, obj.simulationResults{simInd,1}.colnames, obj.simulationResults{simInd,1}.noise] = solve(obj.model, time_points, -inf, inf);
           catch ME
                         
              % Add the original forcing back into the model.
              if ~isempty(forcingData)
                  setForcingData(obj, forcingData_modConstruc, forcingData_colnames_modConstruc);
              end  
               
              error(ME.message); 
           end
                      
           % Add columns to output for the noise componant.
           if ~isempty(obj.simulationResults{simInd,1}.noise)
               h = [obj.simulationResults{simInd,1}.head(:,1:2), obj.simulationResults{simInd,1}.head(:,2) - obj.simulationResults{simInd,1}.noise(:,2), obj.simulationResults{simInd,1}.head(:,2) + obj.simulationResults{simInd,1}.noise(:,3)];
           else
               h = [obj.simulationResults{simInd,1}.head(:,1:2), zeros(size(obj.simulationResults{simInd,1}.head(:,2),1),2)];
           end
           
           % Add the original forcing back into the model.
           if ~isempty(forcingData)
               setForcingData(obj, forcingData_modConstruc, forcingData_colnames_modConstruc);
           end
           
           % Calculate contribution from past climate
           %---------------------
%            try
%                if doClimateLagCalcuations 
%                    % Set the year past for which the focing contribution is to be
%                    % derived.
%                    obj.simulationResults.tor_min = [0; 1; 2; 5;  10;  20; 50; 75;  100];
%                    obj.simulationResults.tor_max = [1; 2; 5; 10; 20; 50; 75;  100; inf];
% 
%                    % Limit the maximum climate lag to be <= the length of the
%                    % climate record.
%                    forcingData = getForcingData(obj);
%                    filt = forcingData( : ,1) < ceil(time_points(end));
%                    tor_max =  max(time_points(1)  - forcingData( filt ,1));
%                    filt = obj.simulationResults.tor_max*365 < tor_max;
%                    obj.simulationResults.tor_min = obj.simulationResults.tor_min(filt);
%                    obj.simulationResults.tor_max = obj.simulationResults.tor_max(filt);
% 
%                    % Calc the head forcing for each period.
%                    for ii=1: size(obj.simulationResults.tor_min,1)                    
%                         head_lag_temp = solve(obj.model, time_points, ...
%                             obj.simulationResults.tor_min(ii)*365.25, obj.simulationResults.tor_max(ii)*365.25 );
% 
%                         obj.simulationResults.head_lag(:,ii) = head_lag_temp(:,2);                    
%                    end               
% 
%                    % Add time column.
%                    obj.simulationResults.head_lag = [time_points, obj.simulationResults.head_lag];                              
%                else
%                    obj.simulationResults.tor_min = [];
%                    obj.simulationResults.tor_max = [];
%                    obj.simulationResults.head_lag = [];               
%                end
%            catch
               obj.simulationResults{simInd,1}.tor_min = [];
               obj.simulationResults{simInd,1}.tor_max = [];
               obj.simulationResults{simInd,1}.head_lag = [];         
           %end
        end
    
        function solveModelPlotResults(obj, handle)        
% Plot the simulation results
%
% Syntax:
%   solveModelPlotResults(obj)
%   solveModelPlotResults(obj, handle)
%
% Description:
%   Creates a summary plot of the simulation results. The plot presents
%   the fit with the observed data and , if the model types 
%   provides an appropriate output, a decomposition of the head to 
%   individual drivers and over various time lags.
%
% Input:
%   obj -  model object
%
%   handle - Matlab figure handle to a pre-existing figure window in which
%   the plot is to be created.
%
% Output:  
%   (none)
%
% Example:
%
%   % Plot the simulation results for object 'model_124705':
%   >> solveModelPlotResults(model_124705);
%
% See also:
%   GroundwaterStatisticsToolbox: class_description;
%   solveModel: model_calibration;
%
% Dependencies
%   model_TFN.m
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure Engineering, 
%   The University of Melbourne.
%
% Date:
%   7 May 2012
%%
            
            % Create the figure. If varargin is empty then a new figure
            % window is created. If varagin equals a figure handle, h, then
            % the calibration results are plotted into 'h'.            
            if nargin==1 || isempty(handle)
                % Create new figure window.
                handle = figure('Name',['Soln. ',strrep(obj.bore_ID,'_',' ')]);
            elseif ~ishandle(handle)    
                error('Input handle is not a valid figure handle.');
            else
                % Create figure in figure 'h'
                figure(handle, 'Name',['Calib. ',strrep(obj.bore_ID,'_',' ')]);
            end

           % Get number of model componant (ie forcing types).
           nModelComponants = size(obj.simulationResults.head,2)-2;

           % Check if there is data for the climate lags
           doClimateLagCalcuations = false;
           if isfield(obj.simulationResults,'head_lag')
               doClimateLagCalcuations = true;
           end
           
           % Plot observed and modelled time series.
           %-------
           if doClimateLagCalcuations || nModelComponants>0
              subplot(2+nModelComponants+doClimateLagCalcuations,1,1:2)        
           end
           
           % Plot bounds for noise component.
           if ~isempty(obj.simulationResults.noise)
               XFill = [obj.simulationResults.head(:,1)' fliplr(obj.simulationResults.head(:,1)')];
               YFill = [[obj.simulationResults.head(:,2) + obj.simulationResults.noise(:,3)]', fliplr([obj.simulationResults.head(:,2) - obj.simulationResults.noise(:,2)]')];
               fill(XFill, YFill,[0.8 0.8 0.8]);
               clear XFill YFill
               hold on;
           end
           
           % Plot modelled deterministic componant.
           plot(obj.simulationResults.head(:,1), obj.simulationResults.head(:,2),'-b' );
           hold on;           
           
           % Plot observed head
           head = getObservedHead(obj);
           plot(head(:,1), head(:,2),'.-k' );
           
           % Set axis labels and title
           datetick('x','mmm-yy');
           ylabel('Head (m)');           
           title(['Bore ', strrep(obj.bore_ID,'_',' ') , ' - Observed and modelled head']);                           
           
           if ~isempty(obj.simulationResults.noise)
                legend('Noise','Modelled','Observed', 'Location','NorthWest' );
           else
               legend('Observed','Modelled', 'Location','NorthWest' );
           end
           hold off;
           %-------
            
           % Plot contributions to head
           %-------
           if nModelComponants>0
               for ii=1:nModelComponants
                   subplot(2+nModelComponants+doClimateLagCalcuations,1, 2+ii );

                   plot(obj.simulationResults.head(:,1), obj.simulationResults.head(:,ii+2),'.-b' );
                   
                   % Set axis labels and title
                   datetick('x','mmm-yy');                   
                   ylabel('Head rise(m)');
                   title(['Head contribution from: ', strrep(obj.simulationResults.colnames{ii+2},'_',' ') ]);
                   
                   
               end
           end

           % Plot climate forcing contributions.     
           %-------
           if doClimateLagCalcuations
               subplot(2+nModelComponants+doClimateLagCalcuations,1, nModelComponants+3)        

               plot(obj.simulationResults.head_lag(:,1), obj.simulationResults.head_lag(:,2:end) );

               % Set axis labels and title
               datetick('x','mmm-yy');                    
               xlabel('Date');
               ylabel('Head rise (m)');
               title(['Modelled head decomposed to the contibution from climate forcing at various temporal lags']);                               
               set(gca,'YGrid','on');

               % Add legend 
               legendstr={};
               for ii=1: size(obj.simulationResults.tor_min,1)
                   legendstr{ii} = ['Lag: ', num2str(obj.simulationResults.tor_min(ii) ), ' to ', num2str(obj.simulationResults.tor_max(ii) ), ' yrs'];                       
               end

               legend( legendstr,'Location','NorthWest' );
           end            
        end

%% Interpolate and extrapolate observation data        
        function head_estimates = interpolateData(obj, targetDates, maxKrigingObs, useModel)
% Interpolate and extrapolate observation data.
%
% Syntax:
%   interpolateData(obj, targetDates, maxKrigingObs, useModel)
%
% Description:
%   Interpolates or extrapolates observed heads of a calibrated model and
%   provides a linear estimate of the prediction uncertainty to a user set
%   probability.
%
%   Importantly, if interpolation is to a date very close to an observed
%   value then the uncertainty should be less than that estimated by the 
%   linear prediction error. To achieve this, this method implements simple
%   kriging on the simulation residuals to weight the linear prediction
%   errror.
%
% Input:
%   obj -  calibrated model object.
%
%   time_points - column vector of the time points to be interpolated 
%   and or extrapolated.
%
%   maxKrigingObs - scalar integer for the maximum number of observation
%   points to use in the kriging. The default is inf.
%   
%   useModel - logical scalar indicating if the kriging is to be
%   undertaken using the model residuals or the observed data. The default is
%   true.
%
% Output:
%   head_estimates - matrix of simulated head formatted as the following columns:
%   date/time; simulated head; uncertainity estimate.
%
% Example:
%   Define the start date for simulation:
%   >> start_date = datenum(2000, 1, 1);
%
%   Define the end date for simulation:
%   >> end_date = datenum(2010, 1, 1);
%
%   Define the time points for simulation as from start_date to end_date at 
%   steps of 365 days:
%   >> time_points = [start_date : 365: end_date]';
%
%   Interpolate the model object 'model_124705' to time_points with the 
%   error estimate defined for a 95% prediction interval:
%   >> head_estimates = interpolateData(model_124705, time_points, 20, true)
%
% See also:
%   GroundwaterStatisticsToolbox: class_description;
%   solveModel: solve_the_model;
%   calibrateModel: model_calibration;
%
% Dependencies
%   model_TFN.m
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure
%   Engineering, The University of Melbourne.
%
% Date:
%   26 Sept 2014
           
            % Check format of target dates
            if ~isnumeric(targetDates)
               error('The taget date(s) for interpolation must be an array with the following columns: year, month, day, hour (optional), minute (options)');
            end
            if size(targetDates,2) ~= 1 && size(targetDates,2) ~= 3 && size(targetDates,2) ~= 6
                error('The taget date(s) must be either a matlab date number or have the following columns: year, month, day, hour (optional), minute (options)');
            end
            
            % Assign defaults for 3rd and 4th inputs. 
            if nargin==2
                maxKrigingObs = inf;
                useModel = true;
            end
                
            % Check if any target dates are beyond the end of the climate
            % record.
            forcingData = getForcingData(obj);
            if useModel && ~isempty(forcingData) && (max(forcingData(:,1)) < max(targetDates))
                error('The maximum date for interpolation is greater than the maximum date of the input forcing data');
            end
            clear forcingData
            
            % Convert target dates
            targetDates = sort(datenum(targetDates), 'ascend');                                    
            
            % Call model at target date and remove the first column
            % containing the date (it is added back later)
            if useModel                
                head_estimates= solveModel(obj, targetDates, [], [],'');
                head_estimates = head_estimates(:,2);
                krigingData = obj.calibrationResults.data.modelledHead_residuals;

                range = obj.calibrationResults.performance.variogram_residual.range;
                sill = obj.calibrationResults.performance.variogram_residual.sill;
                nugget = obj.calibrationResults.performance.variogram_residual.nugget;                
            else
                head_estimates = zeros(length(targetDates),5);
                krigingData = getObservedHead(obj.model);
                
                % Set variogram fitting calibration options.
                variogramOptions = optimset('fminsearch');
                variogramOptions.MaxIter = 1200;
                variogramOptions.MaxFunEvals = 1000000;
                
                % Derive model variogram from the observed data.
                expVariogram = variogram([krigingData(:,1), zeros( size(krigingData(:,1))) ] ...
                , krigingData(:,2) , 'maxdist', min(365*10, krigingData(end,1) - krigingData(1,1) ), 'nrbins', 10);
            
                [range, sill, nugget, variogram_model] ...
                    = variogramfit(expVariogram.distance, expVariogram.val, 365/4, 0.75.*var( krigingData(:,2)), expVariogram.num, variogramOptions,...
                    'model', 'exponential', 'nugget', 0.25.*var( krigingData(:,2)) ,'plotit',false );          
                
            end
            
            % Undertake unievral kriging. 
            % If 'useModel'==true then the krigin is undertaken on the
            % simulation residuals. Else, it is undertaken using entire 
            % record of the the observed head.
            % Adapted from :
            % Martin H. Trauth, Robin Gebbers, Norbert Marwan, MATLAB
            % recipes for earth sciences.
            %----------------------------            
            for ii=1: length(targetDates)
                
                % Find  'maxKrigingObs' cloest to the target obs.
                [~, ind] = sort(abs(krigingData(:,1) - targetDates(ii)));
                ind = ind(1: min(length(ind),maxKrigingObs));
                nobs = length(ind);
                
                % Calculate distance (1-D in units of days) between the closest
                % 'maxObs'
                dist = ipdm( krigingData(ind,1));

                % Calculate kriging matrix for obs data from avriogram, then
                % expand g_mod matrix for kriging and finally invert.
                G_mod = nan(nobs+1, nobs+1);    
                G_mod(1:nobs,1:nobs) = nugget + sill*(1-exp(-3.*abs(dist)./range));
                %G_mod(: , nobs+1) = 1;
                %G_mod(nobs+1 , :) = 1;
                %G_mod(nobs+1,nobs+1) = 0;
                G_mod(: , nobs+1) = 1;
                G_mod(nobs+1 , 1:nobs) = krigingData(ind,1) ;
                G_mod(nobs+1,nobs+1) = 0;
                
                % Calculate the distance from the cloest maxObs to the
                % target obs.
                dist_to_target =  abs(krigingData(ind,1) - targetDates(ii));
                G_target = nugget + sill*(1-exp(-3.*abs(dist_to_target)./range));
                G_target(nobs+1) = targetDates(ii);
                kriging_weights = G_mod \ G_target;
                
                % Estimate residual at target date
                head_estimates(ii,4) = sum( kriging_weights(1:nobs,1) .* krigingData(ind,2)) ...
                    + (1-sum(kriging_weights(1:end-1,1))) .* mean(krigingData(ind,2) );                    
                
                % Estimate kriging variance of the residual at target date.
                head_estimates(ii,5) = sum( kriging_weights(1:nobs,1) .* G_target(1:nobs,1)) + kriging_weights(end,1);
            end
            %----------------------------

           % Adjust head estimate by kriging residual (ie the bias in the
           % estimate).
           head_estimates(:,4) = head_estimates(:,1) + head_estimates(:,4);
            
           % Normalise kriging weights to between zero and one.
           head_estimates(:,5) = head_estimates(:,5)./ (sill + nugget);
           
           % Estimate prediction error with weighting by normalised kriging
           % variance.
           if useModel
                head_estimates(:,5) = head_estimates(:,5) .* 0.5.*(head_estimates(:,3) - head_estimates(:,2));
           end

           % Remove the columns of working data and return prediction and
           % the error estimate.
           head_estimates = [targetDates, head_estimates(:,4), head_estimates(:,5)];
            
        end
        
%% Calibrate the model        
        function calibrateModel(obj, t_start, t_end, numRestarts , params_upperBound, params_lowerBound)

% Calibrate the model
%
% Syntax:
%   calibrateModel(obj, t_start, t_end)
%   calibrateModel(obj, t_start, t_end, numRestarts)
%   calibrateModel(obj, t_start, t_end, numRestarts, params_upperBound, params_lowerBound)
%
% Description:
%   Global calibration of the time-series model and derivation of the following: 
%       a) simulation of the groundwater heads; 
%       b) evalution of the calibration to the remaining observation data;
%       c) calculation of various linear statistics such as parameter 
%          and simulation confidence intervals, Cook's D leverage statistcs
%          and a variogram of the residuals.
%
%   The global calibration is undertaken using the Covariance Matrix Adaptation
%   Evolution Strategy (CMA) (Hansen, 2006). The CMA-ES source code was
%   obtained from https://www.lri.fr/~hansen/cmaes_inmatlab.html#matlab.
%   This code was modified to account for complex parameter
%   boundaries and efficient sampling of parameter sets within the
%   boundaries.
%
%   When the calibration has finished, a summary plot of the calibration
%   can be produced using the method 'calibrateModelPlotResults'. A plot of
%   the simulation results can also be produced using the method
%   'solveModelPlotResults'.
%
% Input:
%   obj -  model object
%
%   t_start - scalar start time, eg datenum(1995,1,1);
%
%   t_end - scalar end time, eg datenum(2005,1,1);
%
%   numRestarts - scalar rational integer for the number of CMA-ES retarts.
%   Peterson & Western (2014) found that 4 restarts produced an acceptable
%   reproducible calibration.%   
%   Default value is 0.
%
%   params_upperBound - column vector of the upper bound to the parameters.
%   Care must be taken to ensure the parameter bound is of the same
%   dimesnions as the parameter vector passed to the optimisation method
%   and in the same order. If this vector is not input, a defualt upper
%   bound will be assigned. This default bound is a scalar multiplier of 
%   each parameter value. 
%
%   params_lowerBound - column vector of the lower bound to the parameters.
%   See additional notes for 'params_upperBound'. 
%
% Output:  
%   (none, the calibration and simulation results are output to 
%   obj.calibrationResults, obj.evaluationResults and obj.simulationResults
%   respectively)
%
% Example:
%   Define the start date for simulation:
%   >> start_date = datenum(1995, 1, 1);
%
%   Define the end date for simulation:
%   >> end_date = datenum(2002, 1, 1);
%
%   Calibrate the model object 'model_124705' with 20 iterations and
%   between 2 and 10 clusters:
%   >> calibrateModel(model_124705, start_date, end_date, 1);
%
% See also:
%   GroundwaterStatisticsToolbox: class_description;
%   solveModel: solve_the_model;
%   calibrationLevenbergMarquardt: model_calibration;
%   interpolateData: - interpolate_and_extrapolate_observation_data;
%
% Dependencies
%   model_TFN.m
%   variogram.m
%   variogramfit.m
%   lsqcurvefit.m
%   IPDM.m
%
% References:
%   Hansen (2006). The CMA Evolution Strategy: A Comparing Review. In 
%   J.A. Lozano, P. Larrañaga, I. Inza and E. Bengoetxea (Eds.). Towards a 
%   new evolutionary computation. Advances in estimation of distribution 
%   algorithms. Springer, pp. 75-102.
%
%   Peterson and Western (2014), Nonlinear time-series modeling of unconfined
%   groundwater head, Water Resources Research, DOI: 10.1002/2013WR014800
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure Engineering, 
%   The University of Melbourne.
%
% Date:
%   7 May 2012
%%
            % Set general constants.
            obj.calibrationResults = [];
            obj.evaluationResults = [];            
            seed = sum(100*clock);                          % Seed value for random number generation.

            % Add flag to denote the calibration is not complete.
            obj.calibrationResults.isCalibrated = false;
            
            % Check the number of inputs.            
            if nargin < 3
                error('Calibration of the model requires input of at least the following: model object, start date and end date');
            elseif nargin == 3    
                numRestarts = 0;
            end                
            
            % Check the input options
            if max(size(t_start))~=1 || max(size(t_end))~=1 || t_start >= t_end
                error('The input start date must be less than the input end data and both must be scalar integers!');
            elseif ~isempty(numRestarts) && (max(size(numRestarts))~=1 || numRestarts<0)
                %error('The input maximum of samples per parameter must be a scaler integer >= 1!');
                error('The number of calibration restarts must be a scaler integer >= 0!');
            end
            
            % Initialsise model calibration and evaluation outputs.
            t_filt = obj.model.inputData.head(:,1) >=t_start  & obj.model.inputData.head(:,1) <= t_end;  
            time_points = obj.model.inputData.head(t_filt,1);
            obj.calibrationResults.time_start =  t_start;
            obj.calibrationResults.time_end =  t_end;
            obj.calibrationResults.data.obsHead =  obj.model.inputData.head(t_filt , :);
            
            % If evaluation is to be undertakes, check atleast 2 obs remain
            % for the evaluation.
            if size(obj.model.inputData.head(~t_filt,1),1)>0 && size(obj.model.inputData.head(~t_filt,1),1)<2
                error(['The input calibration dates are such that observations remain for model evaluation.', char(13) ...
                    'However, model evaluation requires >=2 observations!', char(13), ...
                    'Please modify the dates to either:', char(13), ...
                    '  (i) extent the calibration dates to eliminate any observation data for evaluation; or', char(13), ...
                    '  (ii) contact the calibration dates to increase the observation data for evaluation.']);
            end                            
            
            if obj.model.inputData.head(~t_filt,1)>0
                % Add data to evaluation structure
                obj.evaluationResults.time_lessThan =  t_start;
                obj.evaluationResults.time_greaterThan =  t_end;
                obj.evaluationResults.data.obsHead =  obj.model.inputData.head(~t_filt , :);
            elseif isfield(obj,'evaluationResults')
                obj = rmfield(obj,'evaluationResults');                
            end
            
            % Initialsie model for calibration and check params
            [params, time_points] = calibration_initialise(obj.model, t_start, t_end);             
            if any(isnan(params))
                error('At least one model parameter value equals NaN. Please input a correct value to the model');
            end
            nparams = size(params,1); 
                            
            % Construct and output parameter boundaries.
            %------------
            if nargin ==10 ...
            && (size(params_upperBound,1) ~= size(params,1) || size(params_lowerBound,1) ~= size(params,1))
                error(['The column vectors of parameter bounds "params_upperBound" and "params_lowerBound" ', char(13), ...
                      'must be of the same size as the parameter vector, that is 1 column and ', num2str(nparams), ' rows.']);            
            end            
            [params_upperPhysBound, params_lowerPhysBound] = getParameters_physicalLimit(obj.model);
            if any(isnan(params_upperPhysBound)) || any(isnan(params_lowerPhysBound)) || ...
               any(~isreal(params_upperPhysBound)) || any(~isreal(params_lowerPhysBound))
                error('The physical parameter boundaries must be a real number between (and including) -inf and inf.')
            end                      
            
            if nargin <=8

                [params_upperBound, params_lowerBound] = getParameters_plausibleLimit(obj.model);
                if any(isnan(params_upperBound)) || any(isnan(params_upperBound)) || ...
                any(~isreal(params_lowerBound)) || any(~isreal(params_lowerBound))
                    error('The plausible parameter boundaries must be a real number between (and including) -inf and inf.')
                end                
            else
                params_upperBound = min(params_upperBound,  params_upperPhysBound);
                params_lowerBound = min(params_lowerBound,  params_lowerPhysBound);
            end
            
            % Check the plausible boundaries are consistant with the
            % physical boundaries.
            if any( params_upperBound > params_upperPhysBound) 
                params_upperBound = min(params_upperBound, params_upperPhysBound);    
                display('WARNING: At least one upper parameter boundary exceeds the upper lower physical boundary.');
                display('         They have been shifted to equal the upper physical boundary.');                
                display( char(13) );            
            end
            if any( params_lowerBound < params_lowerPhysBound)               
                params_lowerBound = max(params_lowerBound, params_lowerPhysBound);                
                display('WARNING: At least one lower parameter boundary exceeds the lower physical boundary.');
                display('         They have been shifted to equal the lower physical boundary.');
                display( char(13) );            
            end            
            
            % Check the upper bound is greater than the lower parameter
            % bound. 
            if any(params_lowerBound >= params_upperBound - sqrt(eps()) )
                disp(sprintf('          %s \t %s \t  %s \t %s \t \t %s \t \t %s', 'Model','Param.','Lower', 'Upper'));
                disp(sprintf('          %s \t %s \t \t %s \t %s \t %s \t %s', 'Componant','Name'));            
                for ii=1:nparams
                    if length(obj.model.variables.param_names{ii,1}) < 5
                        params_str = sprintf('          %s \t \t %s \t \t %8.4g \t %8.4g \t %8.4g \t %8.4g', obj.model.variables.param_names{ii,1}, obj.model.variables.param_names{ii,2}, params_lowerBound(ii), params_upperBound(ii) );
                    else
                        params_str = sprintf('          %s \t %s \t \t %8.4g \t %8.4g \t %8.4g \t %8.4g', obj.model.variables.param_names{ii,1}, obj.model.variables.param_names{ii,2}, params_lowerBound(ii), params_upperBound(ii) );
                    end
                    disp([params_str]);    
                end 

                error('The parameter lower bounds must be less than the parameter upper bounds and the difference must be greater than sqrt(eps()).');
            end    
            
            % Check the initial parameter values are within the upper and 
            % lower parameter boundaries. If not adjust the violating
            % parameter to the closest boundary.
            if any(params < params_lowerBound)
                display(  'WARNING: Some of the initial parameter values have been shifted to the lower');
                display(  '         boundary because they violoate the lower parameter boundary.');
                display( char(13) );
                params = max(params, params_lowerBound);
            elseif any(params > params_upperBound)
                display(  'WARNING: Some of the initial parameter values have been shifted to the upper');
                display(  '         boundary because they violoate the upper parameter boundary.');
                display( char(13) );
                params = min(params, params_upperBound);                
            end            
            %------------
            
            % Set CMA-ES calibration the population size.  
            cmaes_options.PopSize = 4*(4 + floor(3*log(nparams)));

            % Output user set options.
            display( char(13) );           
            display('Covariance Matrix Adaptation Evolution Strategy (CMA)');
            display('global calibration will be undertaken using the following.');
            display('settings:');            
            display(['      - Number of initial CMA-ES parameter sets  = ',num2str(cmaes_options.PopSize)]);
            display(['      - Number of CMA-ES calibration restarts = ',num2str(numRestarts)]);
            display( '      - Summary of parameters for calibration and their bounds: ');
            display( '      - Param. componant and name, lower and upper boundary value: ');
            disp(sprintf('          %s \t %s \t  %s \t %s \t \t %s \t \t %s', 'Model','Param.','Lower', 'Upper', 'Lower', 'Upper'));
            disp(sprintf('          %s \t %s \t \t %s \t %s \t %s \t %s', 'Componant','Name','(Plausible)', '(Plausible)','(Physical)', '(Physical)'));            
            for ii=1:nparams
                if length(obj.model.variables.param_names{ii,1}) < 5
                    params_str = sprintf('          %s \t \t %s \t \t %8.4g \t %8.4g \t %8.4g \t %8.4g', obj.model.variables.param_names{ii,1}, obj.model.variables.param_names{ii,2}, params_lowerBound(ii), params_upperBound(ii), params_lowerPhysBound(ii), params_upperPhysBound(ii) );
                else
                    params_str = sprintf('          %s \t %s \t \t %8.4g \t %8.4g \t %8.4g \t %8.4g', obj.model.variables.param_names{ii,1}, obj.model.variables.param_names{ii,2}, params_lowerBound(ii), params_upperBound(ii), params_lowerPhysBound(ii), params_upperPhysBound(ii) );
                end
                disp([params_str]);    
            end 

            if matlabpool('size') == 0                                   
                display(  'WARNING: The matlab parrallel processing engine is not operating. For multi-start');
                display(  'optimisation, it can significantly increase performance. To open the engine, enter');
                display(  'the following at the matlab terminal (where 4 is for four computer cores): ');
                display(  'matlabpool 4');
                display( char(13) );
            end
            
            % Call objective function to find determine the number rows
            % in the output.
            h_forcing = objectiveFunction(params, time_points, obj.model);
            nObjRows = size( h_forcing ,1);
            clear h_forcing;
            
            % Initial the random seed and some variables.
            rand('seed',seed);
            
            % Set initial standard deviation for CMA-ES parameter sampling
            for j=1: nparams
                if ~isinf(params_upperPhysBound(j)) && ~isinf(params_lowerPhysBound(j))
                    insigma(j,1) = 0.5.*(params_upperPhysBound(j)-params_lowerPhysBound(j));                    
                    params_start(j,1) = params_lowerPhysBound(j) + insigma(j,1);
                elseif isinf(params_upperPhysBound(j)) && ~isinf(params_lowerPhysBound(j))
                    insigma(j,1) = 0.5.*(params_upperBound(j)-params_lowerPhysBound(j));
                    params_start(j,1) = params_lowerPhysBound(j) + insigma(j,1);
                elseif ~isinf(params_upperPhysBound(j)) && isinf(params_lowerPhysBound(j))                    
                    insigma(j,1) = 0.5.*(params_upperPhysBound(j)-params_lowerBound(j));
                    params_start(j,1) = params_lowerBound(j) + insigma(j,1);
                elseif isinf(params_upperPhysBound(j)) && isinf(params_lowerPhysBound(j))
                    insigma(j,1) = 0.5.*(params_upperBound(j)-params_lowerBound(j));
                    params_start(j,1) = params_lowerBound(j) + insigma(j,1);
                end
            end
                        
            % Set options for CMA-ES global evolutionary calibration and
            % run.
            %--------------------------------------------------------------
            % Add lower and upper bounds physical
            cmaes_options.LBounds = params_lowerPhysBound;
            cmaes_options.UBounds = params_upperPhysBound;
            cmaes_options.Restarts = numRestarts;
            cmaes_options.LogFilenamePrefix = ['CMAES_',obj.bore_ID];
            cmaes_options.LogPlot = 'off';
            
            % Undertake parrallel function evaluation
            cmaes_options.EvalParallel = 'yes';
            % Do not save .mat file of results.            
            cmaes_options.SaveVariables = 'off';
            
            display('... Starting CMA-ES global calibration.');             
            display('--------------------------------------------');             
            [params_finalEvol, fmin_finalEvol, funcount, exitflag, evolutions, params_bestever] ...            
                = cmaes( 'calibrationObjectiveFunction', params_start, insigma, cmaes_options, obj, time_points );
            
            
            display('--------------------------------------------');             
            % Assign best every solution to params variable
            params = params_bestever.x;
            fmin = params_bestever.f;
            %--------------------------------------------------------------
           
            % Finalise model for calibration
            %--------------------------------------------------------------            
            % Get observed head during calib. periods            
            obsHead = obj.model.inputData.head;            
            
            % Call model objects to finalise calibration.
            calibration_initialise(obj.model, t_start, t_end);
            calibration_finalise(obj.model, params );            
                       
            % Add final parameters
            [obj.calibrationResults.parameters.params_final, ...
                obj.calibrationResults.parameters.params_name] = getParameters(obj.model);  
                        
            % Calculate calibration and evaluation heads
            %--------------------------------------------------------------            
            try                
                head_est = solveModel(obj, obsHead(:,1), [], [] '' );
            catch
                head_est = solveModel(obj, obsHead(:,1), [], [] '');
            end
                
            % Calib residuals.
            head_est = real(head_est);
            head_calib = head_est( t_filt, :);
            head_calib_resid = [obsHead(t_filt,1), obsHead(t_filt,2) - head_calib(:,2)];
            
            % Eval. residuals.
            head_eval = head_est( ~t_filt, :);
            neval = size(head_eval,1);        
            if neval>0
                head_eval_resid = [obsHead(~t_filt,1),  obsHead(~t_filt,2) - head_eval(:,2)];
                obj.evaluationResults.data.modelledHead = head_eval(:,1:2);
                obj.evaluationResults.data.modelledNoiseBounds = head_eval(:,[1,3,4]);
                obj.evaluationResults.data.modelledHead_residuals = head_eval_resid;
                obj.evaluationResults.data.modelledHead_residuals_linFit = polyfit(head_eval_resid(:,1), head_eval_resid(:,2),1);
            else
                obj.evaluationResults =[];
            end
            
            % Add calib. obs data and residuals
            obj.calibrationResults.data.modelledHead = head_calib(:,1:2);
            obj.calibrationResults.data.modelledNoiseBounds = head_calib(:,[1,3,4]);
            obj.calibrationResults.data.modelledHead_residuals = head_calib_resid;    
            obj.calibrationResults.data.modelledHead_residuals_linFit = polyfit(head_calib_resid(:,1), head_calib_resid(:,2),1);            
                                                
            nparams = size(params,1);
            nobs = size(head_calib,1);
            %--------------------------------------------------------------
            
                        
            % Calc. various performance measures including the coefficient of efficiency using the mean observed head
            %------------------
            % Mean error
            obj.calibrationResults.performance.mean_error =  mean( head_calib_resid(:,2) );
            %RMSE
            RMSE = sqrt( 1/numel(head_calib_resid(:,2)) * (head_calib_resid(:,2)' * head_calib_resid(:,2)));
            obj.calibrationResults.performance.RMSE = RMSE;             
            % Objective function error
            obj.calibrationResults.performance.objectiveFunction = fmin;
            
            
            obj.calibrationResults.performance.CoeffOfEfficiency_mean.description = 'Coefficient of Efficiency (CoE) calculated using a base model of the mean observed head. If the CoE > 0 then the model produces an estimate better than the mean head.';
            obj.calibrationResults.performance.CoeffOfEfficiency_mean.base_estimate = mean(obsHead(t_filt,2));            
            obj.calibrationResults.performance.CoeffOfEfficiency_mean.CoE  = 1 - sum( head_calib_resid(:,2).^2) ...
                ./sum( (obsHead(t_filt,2) - mean(obsHead(t_filt,2)) ).^2);            
            obj.calibrationResults.performance.CoeffOfEfficiency_mean.CoE_unbias  = 1 - sum( (head_calib_resid(:,2)-obj.calibrationResults.performance.mean_error).^2) ...
                ./sum( (obsHead(t_filt,2) - mean(obsHead(t_filt,2)) ).^2);            
            
            if neval > 0;                                   
                obj.evaluationResults.performance.mean_error = mean( head_eval_resid(:,2) ); 
                obj.evaluationResults.performance.RMSE = sqrt( 1/numel(head_eval_resid(:,2)) * (head_eval_resid(:,2)' * head_eval_resid(:,2)));;                             
                obj.evaluationResults.performance.CoeffOfEfficiency_mean.description = 'Coefficient of Efficiency (CoE) calculated using a base model of the mean observed head. If the CoE > 0 then the model produces an estimate better than the mean head.';
                obj.evaluationResults.performance.CoeffOfEfficiency_mean.base_estimate = mean(obsHead(~t_filt,2));            
            
                obj.evaluationResults.performance.CoeffOfEfficiency_mean.CoE  =  1 - sum( head_eval_resid(:,2).^2) ...
                ./sum( (obsHead(~t_filt,2) - mean(obsHead(~t_filt,2)) ).^2);           

                obj.evaluationResults.performance.CoeffOfEfficiency_mean.CoE_unbias  =  1 - sum( (head_eval_resid(:,2)-obj.evaluationResults.performance.mean_error).^2) ...
                ./sum( (obsHead(~t_filt,2) - mean(obsHead(~t_filt,2)) ).^2);                
            end
            %------------------

            % Calc. coefficient of efficiency using a robust LOWESS  moving
            % average of the head. This measure of model performance is
            % better suited to non-stationary groundwater hydrographs.
            %------------------            
            % Calculate robust LOWESS moving average across all of the
            % observed data. Note, the window size for the smoothing is set
            % to two years. This is input to the smooth function by
            % defining the fraction that two years is of the observation
            % data.
            try
                smooth_weight = 730/(obsHead(end,1)-obsHead(1,1));
                obsHead_movingAvg = smooth(obsHead(:,1), obsHead(:,2), smooth_weight ,'rlowess');

                obj.calibrationResults.performance.CoeffOfEfficiency_movingAvg.description = 'Coefficient of Efficiency (CoE) calculated using a base model of the 2-year moving average head (using robust LOWESS). If the CoE > 0 then the model produces an estimate better than the moving average.';
                obj.calibrationResults.performance.CoeffOfEfficiency_movingAvg.base_estimate = [obsHead(t_filt,1), obsHead_movingAvg(t_filt,1)];
                obj.calibrationResults.performance.CoeffOfEfficiency_movingAvg.CoE  = 1 - sum( head_calib_resid(:,2).^2) ...
                    ./sum( (obsHead(t_filt,2) - obj.calibrationResults.performance.CoeffOfEfficiency_movingAvg.base_estimate(:,2) ).^2);

                if neval > 0;                   
                    obj.evaluationResults.performance.CoeffOfEfficiency_movingAvg.description = 'Coefficient of Efficiency (CoE) calculated using a base model of the 2-year moving average head (using robust LOWESS). If the CoE > 0 then the model produces an estimate better than the moving average.';
                    obj.evaluationResults.performance.CoeffOfEfficiency_movingAvg.base_estimate = [obsHead(~t_filt,1), obsHead_movingAvg(~t_filt,1)];

                    obj.evaluationResults.performance.CoeffOfEfficiency_movingAvg.CoE  =  1 - sum( head_eval_resid(:,2).^2) ...
                    ./sum( (obsHead(~t_filt,2) - obj.evaluationResults.performance.CoeffOfEfficiency_movingAvg.base_estimate(:,2) ).^2);                           
                end
            catch
               % Do nothing. The curve fitting toolbox (for smooth()) does not seem to be
               % installed.                              
            end
            %------------------            
            
                                    
            % Calc. F-test and P(F>F_critical)          
            RSS = norm( obj.calibrationResults.data.modelledHead(:,2) ...
                - mean(obj.calibrationResults.data.obsHead(:,2))).^2;            
            s2 = (norm(head_calib_resid(:,2))/sqrt(nobs - nparams)).^2;
            obj.calibrationResults.performance.F_test = (RSS/(nparams-1))/s2;      % F statistic for regression
            obj.calibrationResults.performance.F_prob = fcdf(1./obj.calibrationResults.performance.F_test,nobs - nparams, nparams-1); % Significance probability for regression
            
            if neval > 0;   
                RSS = norm( obj.evaluationResults.data.modelledHead(:,2) ...
                    - mean(obj.evaluationResults.data.obsHead(:,2))).^2;            
                s2 = (norm(head_calib_resid(:,2))/sqrt(nobs - nparams)).^2;                
                obj.evaluationResults.performance.F_test = (RSS/(nparams-1))/s2;      % F statistic for regression
                obj.evaluationResults.performance.F_prob = fcdf(1./obj.evaluationResults.performance.F_test,neval - nparams, nparams-1); % Significance probability for regression
            end
            
            % Add BIC and Akaike information criterion            
            err_variance = 1/(nobs-1)*(head_calib_resid(:,2)' * head_calib_resid(:,2));

            obj.calibrationResults.performance.AIC = 2*nparams/nobs + log(err_variance);
            obj.calibrationResults.performance.BIC = nparams/nobs*log(nobs) + log(err_variance);
            if neval>1
                err_variance = 1/(neval-1)*(head_eval_resid(:,2)' * head_eval_resid(:,2));
                obj.evaluationResults.performance.AIC = 2*nparams/neval + log(err_variance);
                obj.evaluationResults.performance.BIC = nparams/neval*log(nobs) + log(err_variance);
            end
            
            % Calculate experimental variogram of residuals and fit an
            % exponential model
            calib_var = variogram([head_calib_resid(:,1), zeros( size(head_calib_resid(:,1))) ] ...
                , head_calib_resid(:,2) , 'maxdist', 365, 'nrbins', 12);
            
            [obj.calibrationResults.performance.variogram_residual.range, obj.calibrationResults.performance.variogram_residual.sill, ...
                obj.calibrationResults.performance.variogram_residual.nugget, obj.calibrationResults.performance.variogram_residual.model] ...
                = variogramfit(calib_var.distance, ...                
                calib_var.val, 365/4, 0.75.*var( head_calib_resid(:,2)), calib_var.num, [], ...
                'model', 'exponential', 'nugget', 0.25.*var( head_calib_resid(:,2)) ,'plotit',false );
             
            if neval > 0;                
                eval_var = variogram([head_eval_resid(:,1), zeros( size(head_eval_resid(:,1)))] ...
                    , head_eval_resid(:,2) , 'maxdist', 365, 'nrbins', 12);
                
                [obj.evaluationResults.performance.variogram_residual.range, obj.evaluationResults.performance.variogram_residual.sill, ...
                    obj.evaluationResults.performance.variogram_residual.nugget, obj.evaluationResults.performance.variogram_residual.model] ...
                    = variogramfit(eval_var.distance, ...
                    eval_var.val, 365/4, 0.5.*var( head_eval_resid(:,2)), eval_var.num , ...
                    'model', 'exponential', 'nugget', 0.25.*var( head_calib_resid(:,2)), 'plotit',false  );
            end                        
                                   
            % Update flag to denote the calibration completed successfully.
            obj.calibrationResults.isCalibrated = true;
            
            % Store the settings for calibration scheme.
            obj.calibrationResults.algorithm_stats = evolutions;
	end

        function handle = calibrateModelPlotResults(obj, h, plotNumber)
% Plot the calibration results
%
% Syntax:
%   calibrateModelPlotResults(obj)
%   calibrateModelPlotResults(obj, handle)
%
% Description:
%   Creates a summary plot of the calibration results. The plot presents
%   the fit with the observed data and the model noise estimate; time
%   series of the residuals and various diagnotic plots.
%
% Input:
%   obj -  model object
%
%   handle - Matlab figure handle to a pre-existing figure window in which
%   the plot is to be created.
%
% Output:  
%   (none)
%
% Example:
%
%   % Plot the calibrate results for object 'model_124705':
%   >> calibrateModelPlotResults(model_124705);
%
% See also:
%   GroundwaterStatisticsToolbox: class_description;
%   calibrateModel: model_calibration;
%
% Dependencies
%   model_TFN.m
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure Engineering, 
%   The University of Melbourne.
%
% Date:
%   7 May 2012
%%

            % Create the figure. If varargin is empty then a new figure
            % window is created. If varagin equals a figure handle, h, then
            % the calibration results are plotted into 'h'.            
            if nargin<2 || isempty(h)
                % Create new figure window.
                h = figure('Name',['Calib. ',obj.bore_ID]);
            elseif ~ishandle(h)    
                error('Input handle is not a valid figure handle.');
            %else
            %    % Create figure in figure 'h'
            %    figure('Parent',handle, 'Name',['Calib. ',obj.bore_ID]);
            %    
            end
            
            % Define the dimensions of the subplots
            if isempty(plotNumber)
                ncol_plots = 3;
                nrow_plots = 4;
            end
            
            % Calc. number of evaluation points.
            neval=0;
            if isfield(obj.evaluationResults,'data')
                if isfield(obj.evaluationResults.data,'modelledHead')
                    neval = size(obj.evaluationResults.data.modelledHead,1);
                end
            end
                    
            % Assess if theer is data on the noise componant.
            hasNoiseComponant = false;
            if max(max(abs(obj.calibrationResults.data.modelledNoiseBounds)))>0   
                hasNoiseComponant = true;
            end
            
            % Plot time series of heads.                        
            %-------
            if isempty(plotNumber)
                iplot = 1;
                nplots = ncol_plots;
                h=subplot(nrow_plots,ncol_plots , 1 :ncol_plots,'Parent',handle);
                iplot = iplot + nplots;
            end
            
            % Plot bounds for noise component.
            if plotNumber==1 || isempty(plotNumber)
                if hasNoiseComponant
                   if neval > 0; 
                       XFill = [obj.calibrationResults.data.modelledNoiseBounds(:,1)' ...
                                obj.evaluationResults.data.modelledNoiseBounds(:,1)' ...
                                fliplr([obj.calibrationResults.data.modelledNoiseBounds(:,1); ...
                                        obj.evaluationResults.data.modelledNoiseBounds(:,1)]')];
                       YFill = [obj.calibrationResults.data.modelledNoiseBounds(:,3)', ...
                                obj.evaluationResults.data.modelledNoiseBounds(:,3)', ...
                                fliplr([obj.calibrationResults.data.modelledNoiseBounds(:,2); ...
                                obj.evaluationResults.data.modelledNoiseBounds(:,2)]')];
                   else
                       XFill = [obj.calibrationResults.data.modelledNoiseBounds(:,1)' ...
                                fliplr(obj.calibrationResults.data.modelledHead(:,1)')];
                       YFill = [obj.calibrationResults.data.modelledNoiseBounds(:,3)', ...
                                fliplr(obj.calibrationResults.data.modelledNoiseBounds(:,2)')];
                   end
                   fill(XFill, YFill,[0.8 0.8 0.8],'Parent',h);
                   clear XFill YFill               
                   hold(h,'on');
                end

                % Plot the observed head
                plot(h,obj.model.inputData.head(:,1), obj.model.inputData.head(:,2),'.-k');
                hold(h,'on');

                % Plot model results
                plot(h,obj.calibrationResults.data.modelledHead(:,1), obj.calibrationResults.data.modelledHead(:,2),'.-b' );
                if neval > 0;
                    plot(h,obj.evaluationResults.data.modelledHead(:,1), obj.evaluationResults.data.modelledHead(:,2),'.-r' );
                end
                datetick(h, 'x','mmm-yy');
                xlabel(h, 'Date');
                ylabel(h, 'Head (m)');           
                if isempty(plotNumber)
                    title(h, ['Bore ', obj.bore_ID, ' - Observed and modelled head']);
                else
                    title(h, 'Observed and modelled head');
                end

                % Create legend strings              
                if neval > 0;
                    if hasNoiseComponant
                        legendstr={'Noise';'Observed';'Calibration';'Evaluation'};
                    else
                        legendstr={'Observed';'Calibration';'Evaluation'};
                    end
                else
                    if hasNoiseComponant
                        legendstr={'Noise';'Observed';'Calibration'};
                    else
                        legendstr={'Observed';'Calibration'};
                    end
                end

                % Finish the first plot!
                legend(legendstr);
                hold(h,'off');               
            end
            
            % Time series of residuals  
            %-------
            if isempty(plotNumber)
                nplots = ncol_plots;
                h = subplot(nrow_plots,ncol_plots,iplot:iplot+nplots-1,'Parent',handle);
                iplot = iplot + nplots;
            end
            if plotNumber==2 || isempty(plotNumber)
                scatter(h, obj.calibrationResults.data.modelledHead_residuals(:,1), obj.calibrationResults.data.modelledHead_residuals(:,2), '.b' );
                hold(h,'on');
                if neval > 0;
                    scatter( h, obj.evaluationResults.data.modelledHead_residuals(:,1),  obj.evaluationResults.data.modelledHead_residuals(:,2), '.r'  );                
                    legend('Calibration','Evaluation');                
                end
                xlabel(h, 'Date');
                ylabel(h, 'Residuals (obs-est) (m)');
                title(h, 'Time series of residuals');
                datetick(h, 'x','mmm-yy');
            end
            
            % Histograms of calibration data
            if isempty(plotNumber)
                nplots = 0;
                h = subplot(nrow_plots,ncol_plots,iplot:iplot+nplots,'Parent',handle);
                iplot = iplot + nplots + 1;                        
            end
            if plotNumber==3 || isempty(plotNumber)
                hist(h, obj.calibrationResults.data.modelledHead_residuals(:,2) , 0.5*size(obj.calibrationResults.data.modelledHead_residuals,1) );            
                ylabel(h, 'Freq.');
                xlabel(h, 'Calib. residuals (obs-est) (m)');
                axis(h, 'tight');
                title(h, 'Histogram of calib. residuals');
            end
            
            % Histograms of evaluation data
            if isempty(plotNumber)
                nplots = 0;
                h = subplot(nrow_plots,ncol_plots,iplot:iplot+nplots,'Parent',handle);
                iplot = iplot + nplots + 1;                        
            end
            if plotNumber==4 || isempty(plotNumber)
                if neval > 0;            
                    hist(h, obj.evaluationResults.data.modelledHead_residuals(:,2) ,  0.5*size(obj.evaluationResults.data.modelledHead_residuals,1) );            
                end           
                ylabel(h, 'Freq.');
                xlabel(h, 'Eval. residuals (obs-est) (m)');
                axis(h, 'tight');
                title(h, 'Histogram of eval. residuals');            
            end
            
            % QQ plot
            if isempty(plotNumber)
                nplots = 0;
                h = subplot(nrow_plots,ncol_plots,iplot:iplot+nplots,'Parent',handle);
                iplot = iplot + nplots + 1;
            end
            if plotNumber==5 || isempty(plotNumber)
                if neval > 0;                
                    QQdata = NaN(size(obj.calibrationResults.data.modelledHead_residuals,1),2);
                    QQdata(:,1) = obj.calibrationResults.data.modelledHead_residuals(:,2);
                    QQdata(1:neval,2) = obj.evaluationResults.data.modelledHead_residuals(:,2);
                    qqplot(h, QQdata);
                    legend('Calibration','Evaluation','Location','NorthWest');                
                else
                    qqplot(h, obj.calibrationResults.data.modelledHead_residuals(:,2) );
                end            
                title(h, 'Quantile-quantile plot of residuals');
            end
            
            % Scatter plot of obs versus modelled
            if isempty(plotNumber)
                nplots = 0;
                h = subplot(nrow_plots,ncol_plots,iplot:iplot+nplots,'Parent',handle);
                iplot = iplot + nplots + 1;
            end
            if plotNumber==6 || isempty(plotNumber)
                scatter(h, obj.calibrationResults.data.obsHead(:,2),  obj.calibrationResults.data.modelledHead(:,2),'.b');
                hold(h,'on');
                if neval > 0;                
                    scatter(h, obj.evaluationResults.data.obsHead(:,2),  obj.evaluationResults.data.modelledHead(:,2),'.r');
                    legend('Calibration','Evaluation','Location','NorthWest');                
                    head_min = min([obj.model.inputData.head(:,2);  obj.calibrationResults.data.modelledHead(:,2); obj.evaluationResults.data.modelledHead(:,2)] );
                    head_max = max([obj.model.inputData.head(:,2);  obj.calibrationResults.data.modelledHead(:,2); obj.evaluationResults.data.modelledHead(:,2)] );
                else
                    head_min = min([obj.model.inputData.head(:,2);  obj.calibrationResults.data.modelledHead(:,2)] );
                    head_max = max([obj.model.inputData.head(:,2);  obj.calibrationResults.data.modelledHead(:,2)] );
                end            
                xlabel(h, 'Obs. head (m)');
                ylabel(h, 'Modelled. head (m)');
                title(h, 'Observed vs. modellled heads');
                xlim(h, [head_min , head_max] );
                ylim(h, [head_min , head_max] );
                plot(h, [head_min, head_max] , [head_min, head_max],'--k');
                hold(h,'off');
            end
            
            % Scatter plot of residuals versus observed head
            if isempty(plotNumber)
                nplots = 0;
                h = subplot(nrow_plots,ncol_plots,iplot:iplot+nplots,'Parent',handle);
                iplot = iplot + nplots + 1;
            end
            if plotNumber==7 || isempty(plotNumber)
                scatter(h, obj.calibrationResults.data.obsHead(:,2), obj.calibrationResults.data.modelledHead_residuals(:,2),'.b');
                hold(h,'on');
                if neval > 0;                
                    scatter(h, obj.evaluationResults.data.obsHead(:,2),  obj.evaluationResults.data.modelledHead_residuals(:,2),'.r');
                    legend('Calibration','Evaluation','Location','NorthWest');                
                end            
                xlabel(h, 'Obs. head (m)');
                ylabel(h, 'Residuals (obs-est) (m)'); 
                title(h, 'Observed vs. residuals');
                hold(h,'off');        
            end
            
            % Semi-variogram of residuals
            if isempty(plotNumber)
                nplots = 0;
                h = subplot(nrow_plots,ncol_plots,iplot:iplot+nplots,'Parent',handle);
                iplot = iplot + nplots + 1;
            end
            if plotNumber==8 || isempty(plotNumber)
                scatter(h, obj.calibrationResults.performance.variogram_residual.model.h , obj.calibrationResults.performance.variogram_residual.model.gamma, 'ob');            
                hold(h,'on');
                plot(h, obj.calibrationResults.performance.variogram_residual.model.h , obj.calibrationResults.performance.variogram_residual.model.gammahat, '-b');                        
                if neval > 0;                                
                    scatter(h, obj.evaluationResults.performance.variogram_residual.model.h,  obj.evaluationResults.performance.variogram_residual.model.gamma, 'or');
                    plot(h, obj.evaluationResults.performance.variogram_residual.model.h,  obj.evaluationResults.performance.variogram_residual.model.gammahat, '-r');                
                    legend('Calib. experimental','Calib model','Eval. experimental','Eval. model','Location','NorthWest');                
                end
                xlabel(h, 'Separation distance (days)' );
                ylabel(h, 'Semi-variance (m^2)' );
                title(h, 'Semi-variogram of residuals');
                hold(h,'off');               
            end
        end

        %% Calculate the sum of squared errors and model residuals for CAM-ES.
        function objectiveFunctionValue = calibrationObjectiveFunction(params, obj, time_points)

            parfor i=1: size(params,2)
                %Calculate the residuals
                try
                    % Calcule sume of squared errors
                    residuals = objectiveFunction( params(:,i), time_points, obj.model );

                    objectiveFunctionValue(i) = residuals' * residuals;  

                catch ME
                    objectiveFunctionValue(i) = NaN;
                end
            end
        end        
        
        %% Check validity of parameter set.
        function validParams = calibrationValidParameters(params, obj, time_points)           
            try
                validParams = getParameterValidity(obj.model, params, time_points);
            catch ME
                validParams = false;
            end
        end        
        
        %% Get observed Head.
        function head = getObservedHead(obj)
            head = getObservedHead(obj.model);
        end
        
        %% Get the forcing data from the model
        function [forcingData, forcingData_colnames] = getForcingData(obj)
            [forcingData, forcingData_colnames] = getForcingData(obj.model);
        end
        
        %% Get the forcing data from the model
        function setForcingData(obj, forcingData, forcingData_colnames)
            setForcingData(obj.model, forcingData, forcingData_colnames);
        end
        
    end
end

