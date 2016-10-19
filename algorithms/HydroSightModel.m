classdef HydroSightModel < handle
% Class definition for building a time-series model of groundwater head.
%
% Description:
%   This class allows the building, calibration, simulation and interpolation
%   of a dynamic type of groundwater head time-series model. The model type 
%   is defined within a seperate class object and must adhere to the structure
%   as defined within the abstract class 'model_abstract.m'. Currently, the
%   following models have been developed: 
%
%   * 'model_TFN': Transfer Function Noise model of Peterson and
%     Western (2014) and von Asmuth et al. (2005). To run this model,
%     the following MEX .c source-code file may need to be compiled:
%     * 'doIRFconvolution.c'
%     * 'forcingTransform_soilMoisture.c'            
%   * 'ExpSmooth': A double exponential smoothing filter where the 'double'
%     allows a trend to be accounted for in the smoothing.
% 
%   Below are links to the details of the public methods of this class. 
%   The example presented uses the 'model_TFN' model. 
% 
%   To open an example model, add the folder and sub-folders of 
%   'Model_Algorithms' to the MatLab path and then enter the following
%   command: 
%   open example_TFN_model()
%   
% See also
%   HydroSightModel: model_construction;
%   calibrateModel: model_calibration;
%   solveModel: solve_the_model;
%   model_TFN: - constructor_for_transfer_fuction_noise_models;
%
% Dependencies
%   model_TFN.m
%   ExpSmooth.m
%   variogram.m
%   variogramfit.m
%   lsqcurvefit.m
%   IPDM.m
%   SPUCI.m
%   cmaes.m
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
        function obj = HydroSightModel(model_label, bore_ID, model_class_name, obsHead, obsHead_maxObsFreq, forcingData, siteCoordinates, varargin)
% Model construction.
%
% Syntax:
%   model = HydroSightModel(model_label, bore_ID, model_class_name , obsHead, obsHead_maxObsFreq, forcingData, siteCoordinates, modelOptions)
%
% Description:
%   Builds the model object, declares initial parameters and sets the
%   observationc,coordinates and forcing data. This is the method that must be
%   called to build a new model. The form of the model is entirely defined
%   by the input 'model_class_name'. This is a highly flexible model
%   structure and allows the efficient inclusion of new model types.
%
%   For details of how to build a linear and nonlinear transfer function
%   noise model, see the documentation for model_TFN.m. To open an example 
%   model, add the folder and sub-folders of 'models' and 'calibration' to the
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
%   model - HydroSightModel class object 
%
% Example: 
%   Load the input head and forcing data:
%   >> load '124705_boreData.mat'
%   >> load '124705_forcingData.mat'
%
%   Create a cell matrix of the model options for model_TFN:
%   >> modelOptions_TFN = {'precip','weightingfunction','responseFunction_Pearsons' ;
%                          'precip','forcingdata',4}
%
%   Create bore coordinates cell array. NOTE: the coordinates below are
%   arbitrary. NOTE, The bote is at Longitude/Latitude of 142.924, -37.145 
%   (GDA94).
%   siteCoordinates = {'Bore_124705', 670870.5 , 5887258.8 ; ...
%                      'precip', 670870.5 , 5887258.8 ; ...
%                      'APET', 670870.5 , 5887258.8 ; ...
%                      'LandRevegFraction', 670870.5 , 5887258.8 };
%
%   Convert the forcing data to a table data type:
%   >> forcingData=array2table(forcingData,'VariableNames', ...
%                     {'Year','Month','Day','precip','APET','LandRevegFraction'});
%   
%   Build the model with a maximum frequency of observation data of 7 days:
%   >> model_124705 = HydroSightModel('Example TFN model', 'Bore_124705',  ...
%                     'model_TFN', boreDataWL, 7, forcingData, ...
%                     siteCoordinates, modelOptions_TFN)
%
%                   
%   Inspect model:
%    >> open model_124705
%
% See also:
%   HydroSightModel: class_description;
%   calibrateModel: model_calibration;
%   calibrateModelPlotResults: plot_model_calibration_results;
%   solveModel: run_model_simulations;
%   solveModelPlotResults: plot_model_simulation_results;
%   model_TFN: - constructor_for_transfer_fuction_noise_models;
%   ExpSmooth: - constructor_for_esponential_smoothing_models;
%   climateTransform_soilMoistureModels: - constructor_for_soil_moisture_models;
%
% Dependencies
%   model_TFN.m
%   ExpSmooth.m
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
        function h = solveModel(obj, time_points, forcingData, simulationLabel, doKrigingOnResiduals)
% Run simulations using a calibrated model.
%
% Syntax:
%   h = solveModel(obj, time_points)
%   h = solveModel(obj, time_points, forcingData)
%   h = solveModel(obj, time_points, forcingData, simulationLabel)
%   h = solveModel(obj, time_points, forcingData, simulationLabel, doKrigingOnResiduals)
%
% Description:
%   Solves the model using the calibrated parameters and, depending upon
%   the method's inputs, decomposes the groundwater head into the
%   contribution from various periods of climate forcing and plots the
%   results. The simulation results can also be adjusted to honour head
%   observations. This can only be done if the same forcing data is used in
%   the simulation as was used in the model calibration. After the
%   simulation, use 'solveModelPlotResults' to graph the results.
%
% Input:
%   obj -  model object
%
%   time_points - column vector of the time points to be simulated. This
%   can be prior to or after the first or last head observation. However,
%   forcing data must exist for each time point to be simulated.
%
%   forcingData - optional input for undertaking simulations with different
%   forcing data to that used in the model calibration. It must have
%   at least the same columns (and names) as used in the calibration but
%   can be of a different duration and values. Also, it can be of the 
%   following form:
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
%   observations and start prior to the first time point to be simulated
%   (ideally, it should start many years prior). Each forcing
%   data column name must be listed within the cell array 'siteCoordinates'
%
%   simulationLabel - optional string to label the simulation. This allows
%   multiple simulations to be stored within the model object. If the
%   provided string already exists then it is overwritten with the new
%   simulation results. If no string is provided, then the simulation is
%   labeled '(No label)'.
%
%   doKrigingOnResiduals - logical scaler to krige the model residuals so
%   that observaed head values equal obsevations. For more setails of the
%   interpolation see 'interpolateData'
%
% Output:
%   h - matrix of simulated head formatted as the following columns:
%   date/time; simulated head; contribution from model componant 1 to n
%   Note:  simulation results are output to obj.simulationResults{}.
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
%   >> solveModel(model_124705, time_points);
%
% See also:
%   HydroSightModel: class_description;
%   calibrateModel: model_calibration;
%   solveModelPlotResults: plot_model_simulation_results;
%   interpolateData: time-series_interpolation_algorithm.
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
           switch nargin
               case 2
                   forcingData = [];
                   simulationLabel = '(No label)';
                   doKrigingOnResiduals = false;
               case 3
                   simulationLabel = '(No label)';
                   doKrigingOnResiduals = false;
               case 4                   
                   doKrigingOnResiduals = false;
               case 5
                   % do nothing                   
               otherwise
                   error('Incorrect number of inputs for the model simulation.');   
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
                obj.simulationResults = cell(1,1);
                simInd =  1;
           end

           % Add the forcing data.
           if ~isempty(forcingData)
               % Get the forcing data used to build the model.
               [forcingData_modConstruc, forcingData_colnames_modConstruc] = getForcingData(obj);
               
               % Extract the forcing data and column names.
                if isstruct(forcingData)
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
                    error('The input forcing data must be a table, structure ot cell array variable. It cannot be double array.');
                    return;
                end

               % Check the column names for the new forcing data are identical
               for i=1:length(forcingData_colnames)
                  if ~any(cellfun( @(x) strcmp(x, forcingData_colnames{i}), forcingData_colnames_modConstruc))
                      error('New forcing dat must have identical column names to the original data.');
                  end
               end
               
               % Assign the new forcing data and keep a copy in the
               % simulation structure.
               setForcingData(obj, forcingData_data, forcingData_colnames);                  
           end
           
           % Add input data for the simulation to the structure.
           obj.simulationResults{simInd,1}.simulationLabel = simulationLabel;
           if ~isempty(forcingData)
                 obj.simulationResults{simInd,1}.forcingData = forcingData_data;
                 obj.simulationResults{simInd,1}.forcingData_colnames = forcingData_colnames;
           end
           
           
           % Undertake the simulation of the head                      
           try
              [obj.simulationResults{simInd,1}.head, obj.simulationResults{simInd,1}.colnames, obj.simulationResults{simInd,1}.noise] = solve(obj.model, time_points);
           catch ME
                         
              % Add the original forcing back into the model.
              if ~isempty(forcingData)
                  setForcingData(obj, forcingData_modConstruc, forcingData_colnames_modConstruc);
              end  
               
              error(ME.message); 
           end
              
           
           % Krige the residuals so that the simulation honours observation
           % points.
           krigingVariance=[];
           if doKrigingOnResiduals && isempty(forcingData)           
               nparams = size(obj.simulationResults{simInd,1}.head,3);
               head_estimates = zeros( size(obj.simulationResults{simInd,1}.head,1), 3, nparams);   
               modelResults = cell( size(head_estimates,3),1);
               for i=1:nparams
                  modelResults{i,1}.head_estimates = [obj.simulationResults{simInd,1}.head(:,1:2,i), ...
                      obj.simulationResults{simInd,1}.head(:,2,i) - obj.simulationResults{simInd,1}.noise(:,2,i),  ...
                      obj.simulationResults{simInd,1}.head(:,2,i) + obj.simulationResults{simInd,1}.noise(:,3,i)];
                  modelResults{i,1}.krigingData = [obj.calibrationResults.data.modelledHead(:,1), obj.calibrationResults.data.modelledHead_residuals(:,i)];
                  modelResults{i,1}.range = obj.calibrationResults.performance.variogram_residual.range(i);
                  modelResults{i,1}.sill = obj.calibrationResults.performance.variogram_residual.sill(i);
                  modelResults{i,1}.nugget = obj.calibrationResults.performance.variogram_residual.nugget(i);
                  
                  
                  if iscell(modelResults{i,1}.range)
                      modelResults{i,1}.range = modelResults{i,1}.range{1};
                  end
                  if iscell(modelResults{i,1}.sill)
                      modelResults{i,1}.sill = modelResults{i,1}.sill{1};
                  end
                  if iscell(modelResults{i,1}.nugget)
                      modelResults{i,1}.nugget = modelResults{i,1}.nugget{1};
                  end          
               end
               
              % Set constant for the kriging
              maxKrigingObs = min(24,length(getObservedHead(obj)));
              useModel = true;
              
              % Remove the simulation results. This is done to minimise the
              % size of obj in the following parfor loop, which if nparams
              % >>1 then the RAM requirements can be huge.
              simulationResults = obj.simulationResults;
              obj.simulationResults=[];
              
              % Call model interpolation
              parfor i=1:nparams
                  head_estimates(:,:,i) = interpolateData(obj, time_points, maxKrigingObs, useModel,modelResults{i});                 
              end

              % Add simulation results back onto the object.
              obj.simulationResults = simulationResults;
              clear simulationResults;
              
              % Calculate the contribution from interpolation
              kriging_contribution = head_estimates(:,2,:) - obj.simulationResults{simInd,1}.head(:,2,:);

              % Add interpolated head into the simulation results.
              obj.simulationResults{simInd,1}.head(:,2,:) = head_estimates(:,2,:);

              % Store the kriging variance.
              krigingVariance = head_estimates(:,end,:);              
               
           end
           
           % Add columns to output for the noise componant.
           if ~isempty(obj.simulationResults{simInd,1}.noise)
               h = [obj.simulationResults{simInd,1}.head(:,1:2,:), obj.simulationResults{simInd,1}.head(:,2,:) - obj.simulationResults{simInd,1}.noise(:,2,:), obj.simulationResults{simInd,1}.head(:,2,:) + obj.simulationResults{simInd,1}.noise(:,3,:)];
           else
               h = [obj.simulationResults{simInd,1}.head(:,1:2), zeros(size(obj.simulationResults{simInd,1}.head(:,2),1),2)];
           end

           % Add contribution from kriging plus the variance
           if ~isempty(krigingVariance);               
               obj.simulationResults{simInd,1}.head = [obj.simulationResults{simInd,1}.head, kriging_contribution, krigingVariance];
               obj.simulationResults{simInd,1}.colnames = {obj.simulationResults{simInd,1}.colnames{:}, 'Kriging Adjustment','Kriging Variance'};
               h = obj.simulationResults{simInd,1}.head;
           end           
           
           % Post-proess the stored simulation results to just percentiles
           if size(obj.simulationResults{simInd,1}.head,3)>1                
               head_tmp=obj.simulationResults{simInd,1}.head(:,1,1);
                for i=2:size(obj.simulationResults{simInd,1}.head,2)
                     head_tmp = [head_tmp, permute(prctile( obj.simulationResults{simInd,1}.head(:, i,:),[50 5 95],3),[1,3,2])];
                end
                obj.simulationResults{simInd,1}.head = head_tmp;
                obj.simulationResults{simInd,1}.noise = [obj.simulationResults{simInd,1}.head(:,1,1), prctile( obj.simulationResults{simInd,1}.noise(:, 2,:),5,3), prctile( obj.simulationResults{simInd,1}.noise(:, 2,:),95,3)];
           end
           
           % Add the original forcing back into the model.
           if ~isempty(forcingData)
               setForcingData(obj, forcingData_modConstruc, forcingData_colnames_modConstruc);
           end
           
           % TO DO: shift code for temporal decomposition to model_TFN.m
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
    
        function solveModelPlotResults(obj, simulationLabel, axisHandle)        
% Plot the simulation results
%
% Syntax:
%   solveModelPlotResults(obj, simulationLabel)
%   solveModelPlotResults(obj, simulationLabel, handle)
%
% Description:
%   Creates a summary plot of the simulation results. The plot presents
%   the fit with the observed data and, if the model types 
%   provides an appropriate output, a decomposition of the head to 
%   individual drivers and over various time lags.
%
% Input:
%   obj -  model object
%
%   simulationLabel - string for the model simulation labelto plot.
%
%   handle - Matlab figure handle to a pre-existing figure window in which
%   the plot is to be created (optional).
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
%   HydroSightModel: class_description;
%   solveModel: model_simulations;
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
%
            
           % Create the figure. If varargin is empty then a new figure
           % window is created. If varagin equals a figure handle, h, then
           % the calibration results are plotted into 'h'.            
           if nargin==2 || isempty(axisHandle)
               % Create new figure window.
               figHandle = figure('Name',['Soln. ',strrep(obj.bore_ID,'_',' ')]);
           elseif ~iscell(axisHandle)    
                error('Input handle is not a valid figure handle.');
           else
                h = axisHandle;                
           end
            
           % Find simulation label
           if isempty(simulationLabel)
               error('The simulation label must be specified.');
           end
           simInd = cellfun( @(x) strcmp(x.simulationLabel , simulationLabel), obj.simulationResults);               

            % Assess if the data is from a population of simlations (eg
            % from DREAM calibration)
            hasModelledDistn = false;
            if size(obj.calibrationResults.data.modelledHead,2)>2   
                hasModelledDistn = true;                
            end
            
            hasNoiseComponant=false;
            if ~isempty(obj.simulationResults{simInd,1}.noise)
                hasNoiseComponant=true;
            end           
           
           % Get number of model componant (ie forcing types).
           if hasModelledDistn
                nModelComponants = (size(obj.simulationResults{simInd,1}.head,2)-1)/3 - 1;    
           else
                nModelComponants = size(obj.simulationResults{simInd,1}.head,2)-2;
           end

           % Check if there is data for the climate lags
           doClimateLagCalcuations = false;
           if isfield(obj.simulationResults,'head_lag')
               doClimateLagCalcuations = true;
           end
           
           % Plot observed and modelled time series.
           %-------
           if ~isempty(axisHandle)
              h = axisHandle{1}; 
           elseif nModelComponants>0
              h = subplot(2+nModelComponants+doClimateLagCalcuations,1,1:2, 'Parent',figHandle);  
              h_legend = [];
           end
            
            % Plot time series of heads.                        
            %-------
            % Plot bounds for noise component.
            if hasNoiseComponant
               XFill = [obj.simulationResults{simInd,1}.head(:,1)' fliplr(obj.simulationResults{simInd,1}.head(:,1)')];
               YFill = [[obj.simulationResults{simInd,1}.head(:,2) + obj.simulationResults{simInd,1}.noise(:,3)]', fliplr([obj.simulationResults{simInd,1}.head(:,2) - obj.simulationResults{simInd,1}.noise(:,2)]')];

               fill(XFill, YFill,[0.8 0.8 0.8],'Parent',h);
               clear XFill YFill               
               hold(h,'on');
            end

            if hasModelledDistn

               XFill = [obj.simulationResults{simInd,1}.head(:,1)' ...
                        fliplr(obj.simulationResults{simInd,1}.head(:,1)')];
               YFill = [obj.simulationResults{simInd,1}.head(:,4)', ...
                        fliplr(obj.simulationResults{simInd,1}.head(:,3)')];
                    
               fill(XFill, YFill,[0.6 0.6 0.6],'Parent',h);
               clear XFill YFill               
               hold(h,'on');                    
            end
            
           % Plot modelled deterministic componant.
           plot(h, obj.simulationResults{simInd,1}.head(:,1), obj.simulationResults{simInd,1}.head(:,2),'-b' );
           hold(h,'on');         
           
           % Plot observed head
           head = getObservedHead(obj);
           plot(h, head(:,1), head(:,2),'.-k' );
           
           % Calculate and set the date limits from the simulation period
           dateLimits = [floor(min(obj.simulationResults{simInd,1}.head(:,1))), ceil(max(obj.simulationResults{simInd,1}.head(:,1)))];
           dateRange = dateLimits(2) - dateLimits(1);
           dateLimits(1) = floor(dateLimits(1) - (dateRange * 0.05));
           dateLimits(2) = ceil(dateLimits(2) + (dateRange * 0.05));
           
           % Set axis labels,  title and x axis limits
           datetick(h, 'x','yy');
           ylabel(h, 'Head (m)');           
           title(h, ['Bore ', strrep(obj.bore_ID,'_',' ') , ' - Simulated head']); 
           xlim(h,dateLimits);
           
            % Create legend strings  
            i=1;
            if hasNoiseComponant
                if hasModelledDistn
                    legendstr{i}='Total Err. (5th-95th)';
                else
                    legendstr{i}='Total Err.';
                end
                i=i+1;
            end
            if hasModelledDistn
                legendstr{i}='Param. Err. (5th-95th)';            
                i=i+1;
            end
            if hasModelledDistn
                legendstr{i}='Sim. (median)';
            else
                legendstr{i}='Sim.';
            end            
            i=i+1;                                
            legendstr{i}='Observed';
            i=i+1;            
            legend(h,legendstr, 'Location','NorthWest' );
           

           hold(h,'off');
           %-------
            
           % Plot contributions to head
           %-------
           if nModelComponants>0
               for ii=1:nModelComponants
                   if ~isempty(axisHandle)
                       h = axisHandle{ii+1}; 
                   else
                        h = subplot(2+nModelComponants+doClimateLagCalcuations,1, 2+ii, 'Parent',figHandle );
                   end
                   if hasModelledDistn
                       
                       XFill = [obj.simulationResults{simInd,1}.head(:,1)' ...
                                fliplr(obj.simulationResults{simInd,1}.head(:,1)')];
                       YFill = [obj.simulationResults{simInd,1}.head(:,3*(ii+1)+1)', ...
                                fliplr(obj.simulationResults{simInd,1}.head(:, 3*(ii+1))')];

                       fill(XFill, YFill,[0.6 0.6 0.6],'Parent',h);
                       clear XFill YFill               
                       hold(h,'on');                    
                       plot(h, obj.simulationResults{simInd,1}.head(:,1), obj.simulationResults{simInd,1}.head(:,3*(ii+1)-1),'-b' );
                       
                   else
                       plot(h, obj.simulationResults{simInd,1}.head(:,1), obj.simulationResults{simInd,1}.head(:,ii+2),'-b' );
                   end
                        
                   
                   % Set axis labels and title
                   datetick(h, 'x','yy');                   
                   ylabel(h, 'Head rise(m)');
                   title(h, ['Head contribution from: ', strrep(obj.simulationResults{simInd,1}.colnames{ii+2},'_',' ') ]);
                   xlim(h,dateLimits);                   
                   
               end
           end       
        end

%% Interpolate and extrapolate observation data        
        function head_estimates = interpolateData(obj, targetDates, maxKrigingObs, useModel, modelResults)
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
%   HydroSightModel: class_description;
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
                if nargin==4 || isempty(modelResults) 
                    head_estimates= solveModel(obj, targetDates, [], '', false);
                    krigingData = obj.calibrationResults.data.modelledHead_residuals;
                    
                    range = obj.calibrationResults.performance.variogram_residual.range;
                    sill = obj.calibrationResults.performance.variogram_residual.sill;
                    nugget = obj.calibrationResults.performance.variogram_residual.nugget;                

                else 
                    head_estimates = modelResults.head_estimates;
                    krigingData = modelResults.krigingData;
                    range = modelResults.range;
                    sill = modelResults.sill;
                    nugget = modelResults.nugget;
                    clear modelResults;
                end
                %head_estimates = head_estimates(:,2:4);
                %krigingData = obj.calibrationResults.data.modelledHead_residuals;

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
            
            % Convert kriging data to double (if saved as single)
            if isa(krigingData,'single')
                krigingData = double(krigingData);
            end
            
            % Undertake universal kriging. 
            % If 'useModel'==true then the krigin is undertaken on the
            % simulation residuals. Else, it is undertaken using entire 
            % record of the the observed head.
            % Adapted from :
            % Martin H. Trauth, Robin Gebbers, Norbert Marwan, MATLAB
            % recipes for earth sciences.
            %----------------------------
            
            % Calculate distance (1-D in units of days) between all obs.
            dist_allObs = ipdm( krigingData(:,1));
                        
            warning off;
            for ii=1: length(targetDates)

                % Get pre-calc distance (1-D in units of days) between the closest
                % 'maxObs'
                dist_to_target =  krigingData(:,1) - targetDates(ii);
                
                indNegDuration = find(dist_to_target<0, maxKrigingObs, 'last');
                indPosDuration = find(dist_to_target>=0, maxKrigingObs, 'first');
                indNegClosestQuaterObObs = 1:length(indNegDuration)<=ceil(maxKrigingObs/4);
                indPosClosestQuaterObObs = 1:length(indPosDuration)<=ceil(maxKrigingObs/4);
                ind = [indNegDuration(indNegClosestQuaterObObs) ; indPosDuration(indPosClosestQuaterObObs); ...
                        indNegDuration(~indNegClosestQuaterObObs) ; indPosDuration(~indPosClosestQuaterObObs)]; 
                ind = ind(1: min(length(ind), maxKrigingObs));    
                
                dist = dist_allObs(ind, ind);
                dist_to_target = dist_to_target(ind);
                nobs = length(ind);
                
                % Create LHS matrix with fixes 0/1
                G_mod = zeros(nobs+2, nobs+2); 
                G_mod(: , nobs+1) = 1;
                G_mod(nobs+1, :) = 1;
                G_mod(nobs+1:end, nobs+1:end) = 0;
                G_target = zeros(nobs+2,1);
                                
                % Calculate kriging matrix for obs data from avriogram, then
                % expand g_mod matrix for kriging and finally invert.
                G_mod(1:nobs,1:nobs) = nugget + sill*(1-exp(-3.*abs(dist)./range));
                G_mod(nobs+2 , 1:nobs) = krigingData(ind,1)-targetDates(ii);
                G_mod(1:nobs,nobs+2) = krigingData(ind,1)-targetDates(ii);
                
                % Calculate the distance from the cloest maxObs to the
                % target obs.
                
                G_target(1:nobs) = nugget + sill*(1-exp(-3.*abs(dist_to_target)./range));
                G_target(nobs+1) = 1;
                G_target(nobs+2) = 0;
                kriging_weights = G_mod \ G_target;
                
                % Estimate residual at target date
                head_estimates(ii,5) = sum( kriging_weights(1:nobs,1) .* krigingData(ind,2)) ...
                    + (1-sum(kriging_weights(1:end-1,1))) .* mean(krigingData(ind,2) );                    
                
                % Estimate kriging variance of the residual at target date.
                head_estimates(ii,6) = sum( kriging_weights(1:nobs,1) .* G_target(1:nobs,1)) + kriging_weights(end,1);
            end
            warning on;                   
            %----------------------------

           % Adjust head estimate by kriging residual (ie the bias in the
           % estimate).
           head_estimates(:,5) = head_estimates(:,2) + head_estimates(:,5);
            
           % Normalise kriging weights to between zero and one.
           head_estimates(:,6) = head_estimates(:,6)./ (sill + nugget);
           
           % Estimate prediction error with weighting by normalised kriging
           % variance.
           if useModel
                head_estimates(:,6) = head_estimates(:,6) .* 0.5.*(head_estimates(:,4) - head_estimates(:,3));
           end

           % Remove the columns of working data and return prediction and
           % the error estimate.
           head_estimates = [targetDates, head_estimates(:,5), head_estimates(:,6)];
            
        end
        
%% Calibrate the model        
        function calibrateModel(obj, t_start, t_end, calibrationSchemeName, SchemeSetting , params_upperBound, params_lowerBound)

% Calibrate the model
%
% Syntax:
%   calibrateModel(obj, t_start, t_end, calibrationSchemeName, SchemeSetting)
%   calibrateModel(obj, t_start, t_end, calibrationSchemeName, SchemeSetting, params_upperBound, params_lowerBound)
%
% Description:
%   Global calibration of the time-series model and derivation of the following: 
%       1) simulation of the groundwater heads; 
%       2) evalution of the calibration to the remaining observation data;
%       3) calculation of various performance statistics and and a variogram
%          of the residuals.
% 
%   Importantly, the time-series models can be very challenging to
%   calibrate to the global optima, particularly for the nonlinear TFN models.
%   To assist in identifying the global optima, a range of calibration schemes
%   are available (see below for details of the schemes). This allows
%   the reliability of a calibration result to be assessed by re-running
%   the calibration with a different scheme and comparing the results. If
%   each scheme gives near identical results then this supports the
%   conclusion that the gloabl optima has been idenified. Additionally, the 
%   reliability of the calibration solution can be assessed by re-running
%   the same calibration scheme multiple times, ideally with increasingly
%   stringent settings. If the very best solution is repeatedly obtained
%   then it is good evidence that the global optima has been located.
%   
%   1.  Covariance Matrix Adaptation Evolution Strategy (CMA-ES) (Hansen, 2006)
%   from https://www.lri.fr/~hansen/cmaes_inmatlab.html#matlab. Note, the 
%   code was modified to account for complex parameter
%   boundaries and efficient sampling of parameter sets within the
%   boundaries.
%
%   2. Shuffled complex evolution with principal components analysis–University 
%   of California at Irvine (SP-UCI) method is a global optimization algorithm 
%   designed for high-dimensional and complex problems. It is based on the 
%   Shuffled Complex Evolution (SCE-UA) Method (Qingyun Duan et al.), but solves
%   a serious problem in searching over high-dimensional spaces - population
%   degeneration. The population degeneration problem refers to the phenomenon
%   that, when searching over the high-dimensional parameter spaces, the 
%   population of the searching particles is very likely to collapse into a
%   subspace of the parameter space, therefore losing the capability of 
%   exploring the entire parameter space. In addition, the SP-UCI method also
%   combines the strength of shuffled complex, the Nelder-Mead simplex, and
%   mutinormal resampling to achieve efficient and effective high-dimensional 
%   optimization. (Code and above description from http://www.mathworks.com
%   /matlabcentral/fileexchange/37949-shuffled-complex-evolution-with-pca--sp-uci--method)
%   Note, the SP-CUI code has been edited by Tim Peterson to allow the inclusion of
%   parameter constraints and parrallel calculation of each complex. For
%   details of the algorithm see Chu et al. (2010).
%
% Input:
%   obj -  model object
%
%   t_start - scalar start time, eg datenum(1995,1,1);
%
%   t_end - scalar end time, eg datenum(2005,1,1);
%
%   calibrationSchemeName - string for the name of the calibration scheme to 
%   use. The options are 'SP-UCI' and 'CMA-ES'.
%
%   SchemeSetting - scalar rational integer defining the rigor of the input
%   calibration scheme. For 'SP-UCI' it defines the number of complexes per
%   model parameter and must be >=1. For 'CAM-ES' it defines the number of
%   re-runs undertaken with each re-run having double the population size as
%   the previous run and must be >=0;
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
%   >> calibrateModel(model_124705, start_date, end_date, 'SPUCI', 2);
%
% See also:
%   HydroSightModel: class_description;
%   calibrateModelPlotResults: plot_model_calibration_results;
%   SPUCI: SP-UCI_calibration_algorithm;
%   cmaes: CMA-ES_calibration_algorithm;
%
% Dependencies
%   model_TFN.m
%   ExpSmooth.m
%   SPUCI.m
%   cmaes.m
%   variogram.m
%   variogramfit.m
%   lsqcurvefit.m
%   IPDM.m
%
% References:
%   Chu, W., X. Gao, and S. Sorooshian (2010), Improving the shuffled complex 
%   evolution scheme for optimization of complex nonlinear hydrological systems:
%   Application to the calibration of the Sacramento soil-moisture accounting 
%   model, Water Resour. Res., 46, W09530, doi:10.1029/2010WR009224.
%
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
%

            % Check the input scheme is known.
            calibrationSchemeName = upper(calibrationSchemeName);
            switch calibrationSchemeName
                case {'CMA ES','CMA_ES','CMAES','CMA-ES'}
                    if ~isscalar(SchemeSetting) || (isscalar(SchemeSetting) && (SchemeSetting<0 || floor(SchemeSetting)~=ceil(SchemeSetting)))
                        error('The CMA-ES calibration scheme requires an input integer scalar >=0 for the number of restarts.');
                    end
                case {'SP UCI','SP_UCI','SPUCI','SP-UCI'}                    
                    if ~isscalar(SchemeSetting) || (isscalar(SchemeSetting) && (SchemeSetting<1 || floor(SchemeSetting)~=ceil(SchemeSetting) ))
                        error('The SP-UCI calibration scheme requires an input scalar integer >=1 for the number of complexes per model parameter.');
                    end
                case {'DREAM', 'dream','Dream'}
                    if ~isscalar(SchemeSetting) || (isscalar(SchemeSetting) && (SchemeSetting<1 || floor(SchemeSetting)~=ceil(SchemeSetting) ))
                        error('The DREAM calibration scheme requires an input scalar integer >=1 for the number of Markov cahins per model parameter.');
                    end                    
                otherwise
                    error('The requested calibration scheme is unknown.');
            end
            
            
            % Set general constants.
            obj.calibrationResults = [];
            obj.evaluationResults = [];            
            seed = sum(100*clock);                          % Seed value for random number generation.

            % Add flag to denote the calibration is not complete.
            obj.calibrationResults.isCalibrated = false;
            
            % Check the number of inputs.            
            if nargin < 5
                error('Calibration of the model requires input of at least the following: model object, start date and end date, calibration scheme name, calibration setting');
            end                
            
            % Check the input options
            if max(size(t_start))~=1 || max(size(t_end))~=1 || t_start >= t_end
                error('The input start date must be less than the input end data and both must be scalar integers!');
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
            params =  median(params,2);
            if any(isnan(params))
                error('At least one model parameter value equals NaN. Please input a correct value to the model');
            end
            nparams = size(params,1); 
                            
            % Construct and output parameter boundaries.
            %------------
            if nargin ==7 ...
            && (size(params_upperBound,1) ~= size(params,1) || size(params_lowerBound,1) ~= size(params,1))
                error(['The column vectors of parameter bounds "params_upperBound" and "params_lowerBound" ', char(13), ...
                      'must be of the same size as the parameter vector, that is 1 column and ', num2str(nparams), ' rows.']);            
            end            
            [params_upperPhysBound, params_lowerPhysBound] = getParameters_physicalLimit(obj.model);
            if any(isnan(params_upperPhysBound)) || any(isnan(params_lowerPhysBound)) || ...
               any(~isreal(params_upperPhysBound)) || any(~isreal(params_lowerPhysBound))
                error('The physical parameter boundaries must be a real number between (and including) -inf and inf.')
            end                      
            
            if nargin ==5

                [params_upperBound, params_lowerBound] = getParameters_plausibleLimit(obj.model);
                if any(isnan(params_upperBound)) || any(isnan(params_upperBound)) || ...
                any(~isreal(params_lowerBound)) || any(~isreal(params_lowerBound))
                    error('The plausible parameter boundaries must be a real number between (and including) -inf and inf.')
                end                
            else
                params_upperBound = min(params_upperBound,  params_upperPhysBound);
                params_lowerBound = max(params_lowerBound,  params_lowerPhysBound);
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
            
            % Output user set options.
            display( char(13) );           
            display('Global calibration scheme is to be undertaken using the following settings');
             switch calibrationSchemeName
                case {'CMA ES','CMA_ES','CMAES','CMA-ES'}
                    cmaes_options.PopSize = (4 + floor(3*log(nparams)));  
                    display( '      - Calibration scheme: Covariance Matrix Adaptation Evolution Strategy (CMA-ES)');
                    display(['      - Number of initial CMA-ES parameter sets  = ',num2str(cmaes_options.PopSize)]);  
                    display(['      - Number of CMA-ES calibration restarts = ',num2str(SchemeSetting)]);
                    
                case {'SP UCI','SP_UCI','SPUCI','SP-UCI'}
                    display( '      - Calibration scheme: Shuffled complex evolution with principal components analysis–University of California at Irvine (SP-UCI)');                    
                    display(['      - Number of complexes per parameter = ',num2str(SchemeSetting)]);  
                case {'DREAM', 'Dream','dream'}
                    display( '      - Calibration scheme: DiffeRential Evolution Adaptive Metropolis algorithm (DREAM)');                    
                    display(['      - Number of generations per parameter = ',num2str(10000*SchemeSetting)]);  
                    
             end             
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

            % Initial the random seed and some variables.
            rand('seed',seed);
            
            %--------------------------------------------------------------

            % Do SCE calibration using the objective function SSE.m
            log_L=[];
            switch calibrationSchemeName
                case {'CMA ES','CMA_ES','CMAES','CMA-ES'}
                    
                    cmaes_options.LBounds = params_lowerPhysBound;
                    cmaes_options.UBounds = params_upperPhysBound;
                    cmaes_options.Restarts = SchemeSetting;
                    cmaes_options.LogFilenamePrefix = ['CMAES_',obj.bore_ID];
                    cmaes_options.LogPlot = 'off';
                    cmaes_options.CMA.active = 1;
                    
                    cmaes_options.EvalParallel = 'yes';     % Undertake parrallel function evaluation
                    cmaes_options.SaveVariables = 'off';    % Do not save .mat file of results.
                    
                    useLikelihood = false;
                    
                    % Define bounds and initial standard dev of params
                    insigma = 1/3*(params_upperBound - params_lowerBound);
                    params_start = params_lowerBound + 1/2.*(params_upperBound - params_lowerBound);
                    params_start = [mat2str(params_start) '+ insigma .* (2 * rand(',num2str(nparams),',1) -1)'];                    
                    
                    % Do calibration
                    doParamTranspose = false;
                    [params_finalEvol, fmin_finalEvol, numFunctionEvals, exitflag, evolutions, params_bestever] ...            
                     = cmaes( 'calibrationObjectiveFunction', params_start, insigma, cmaes_options, obj, time_points, doParamTranspose, useLikelihood );

                    % Assign best every solution to params variable
                    params = params_bestever.x;
                    fmin = params_bestever.f;          
                    
                    % Extract exit flag message.
                    if iscell(exitflag)
                        exitflag = exitflag{1};
                    end                    
                    
                    % Store exit status
                    if any( strcmp(exitflag, 'maxfunevals'))
                        exitFlag = 1;
                        existStatus = 'Insufficient maximum number of model evaluations for convergence.';
                    elseif any( strcmp(exitflag, 'maxiter'))
                        exitFlag = 1;
                        existStatus = 'Insufficient maximum number of iterations for convergence.';
                    elseif any( strcmp(exitflag, 'maxiter'))
                        exitFlag = 1;
                        existStatus = 'Insufficient maximum number of iterations for convergence.';                    
                    elseif any( strcmp(exitflag, 'tolx')) && ~any( strcmp(exitflag, 'tolfun'))
                        exitFlag=1;
                        exitStatus = ['Only parameter convergence (not obj. function convergence) achieved in ', num2str(numFunctionEvals),' function evaluations.'];
                    elseif ~any( strcmp(exitflag, 'tolx')) && any( strcmp(exitflag, 'tolfun'))
                        exitFlag=1;
                        exitStatus = ['Only objective function convergence achieved (not param. convergence) in ', num2str(numFunctionEvals),' function evaluations.'];
                    elseif  any( strcmp(exitflag, 'maxfunevals')) || ...
                    any( strcmp(exitflag, 'maxiter')) || ...    
                    any( strcmp(exitflag, 'stoptoresume')) || ...    
                    any( strcmp(exitflag, 'manual')) || ...    
                    any( strcmp(exitflag, 'stagnation')) || ...    
                    any( strcmp(exitflag, 'warnconditioncov')) || ...    
                    any( strcmp(exitflag, 'warnnoeffectcoord')) || ...    
                    any( strcmp(exitflag, 'warnnoeffectaxis')) || ...    
                    any( strcmp(exitflag, 'warnequalfunvals')) || ...    
                    any( strcmp(exitflag, 'warnequalfunvalhist')) ...
                    any( strcmp(exitflag, 'bug'))
                                                
                        exitStatus = ['Calibration warning encountered:', exitflag,' See CMA-ES scheme documentation for details.'];                        
                        exitFlag=1;
                    elseif any( strcmp(exitflag, 'tolx')) && any( strcmp(exitflag, 'tolfun'))
                        exitFlag=2;
                        exitStatus = ['Parameter and objective function convergence achieved in ', num2str(numFunctionEvals),' function evaluations.'];
                    else
                        exitFlag=0;
                        exitStatus = ['Unhandled non-convergence issues. Total model evaluations undertaken = ', num2str(numFunctionEvals)];
                        
                        obj.calibrationResults.exitFlag = exitFlag;
                        obj.calibrationResults.exitStatus = exitStatus;
                        
                        ME = MException('HydroSightModel:CalibrationFailure',exitStatus);
                        throw(ME);                        
                    end                        
                        
                case {'SP UCI','SP_UCI','SPUCI','SP-UCI'}
                    maxn = inf;
                    kstop = 10;    
                    pcento = 1e-10;    
                    peps = 1e-6;
                    ngs = SchemeSetting*nparams;
                    iseed = floor(rand(1)*100000);
                    iniflg =  1;                
                    useLikelihood=false;

                    % Do calibration                                        
                    doParamTranspose = false;
                    [params, fmin,numFunctionEvals, exitFlag, exitStatus] = SPUCI(@calibrationObjectiveFunction, @calibrationValidParameters, ...
                        params', params_lowerBound', params_upperBound', params_lowerPhysBound', params_upperPhysBound', maxn, ...
                        kstop, pcento, peps, ngs, iseed, iniflg, obj, time_points, doParamTranspose, useLikelihood); 
                        params = params';
                    
                    if exitFlag==0
                        obj.calibrationResults.exitFlag = exitFlag;
                        obj.calibrationResults.exitStatus = exitStatus;
                        
                        ME = MException('HydroSightModel:CalibrationFailure',exitStatus);
                        throw(ME);
                    end

                    
                case {'DREAM', 'Dream','dream'}
              
                    % Application specific settings.
                    % -------------------------------------------------------------------------
                    % Set the approx. number of samples required for
                    % reliable inferance. Col 1: the number of parameters,
                    % Col 2: number of samples. (source Vrugt, 2016, http://dx.doi.org/10.1016/j.envsoft.2015.08.013 p 293).                    
                    reqMinParamSamples = [ 1 500; 2 1000; 5 5000; 10 10000; 25 50000; 50 200000; 100 1000000; 250 5000000];
                    
                    %Interpolate above matrix to number of parameters for
                    %this model.
                    reqMinParamSamples = floor(interp1( reqMinParamSamples(:,1), reqMinParamSamples(:,2), nparams, 'linear'));
                    
                    % -------------------------------------------------------------------------
                    %                           DEFAULT VALUES
                    % -------------------------------------------------------------------------
                    DREAMPar.nCR = 3;                 % Number of crossover values 
                    DREAMPar.delta = 3;               % Number chain pairs for proposal
                    DREAMPar.lambda = 0.05;           % Random error for ergodicity
                    DREAMPar.zeta = 0.05;             % Randomization
                    DREAMPar.outlier = 'iqr';         % Test to detect outlier chains
                    DREAMPar.pJumpRate_one = 0.2;     % Probability of jumprate of 1
                    DREAMPar.pCR = 'yes';             % Adaptive tuning crossover values
                    DREAMPar.thinning = 1;            % Each Tth sample is stored         
                    % -------------------------------------------------------------------------
                    %                           MODEL SPECIFIC VALUES
                    % -------------------------------------------------------------------------                    
                    DREAMPar.d = nparams;             % Dimensionality target distribution
                    DREAMPar.N =max(nparams, 2*DREAMPar.delta+1);   % Number of Markov chains
                    DREAMPar.T = 10000*SchemeSetting;  % Number of generations
                    DREAMPar.lik=2;                   % Choice of likelihood function
                    useLikelihood = true;
                    DREAMPar.restart = 'no';
                    DREAMPar.modout='no';
                    DREAMPar.save='no';
                    % -------------------------------------------------------------------------
                    %                      OPTIONAL (DEFAULT = 'no'  / not used )
                    % -------------------------------------------------------------------------
                    % Multi-core computation chains? Turn on if there are
                    % >1 cores available.
                    if feature('numCores')>1
                        DREAMPar.parallel = 'yes';        
                    else
                        DREAMPar.parallel = 'no';
                    end
                    % Set parameter bounds
                    Par_info.prior ='latin';
                    Par_info.min = params_lowerBound'; % If 'latin', min parameter values
                    Par_info.max = params_upperBound'; % If 'latin', max parameter values                    
                    Par_info.boundhandling ='reflect';% Explicit boundary handling

                    % Do calibration 
                    doParamTranspose = true;
                    [params,output,fx,log_L] = DREAM(@calibrationObjectiveFunction,DREAMPar,Par_info,[], obj, time_points, doParamTranspose,useLikelihood);
                              
                    % Extract the R_statistic values and dilter for those
                    % where R_statistic<1.2 for all parameters in the set.
                    r_stat_threshold = 1.2;
                    r_stat_acceptable = all(output.R_stat(1: end, 2: DREAMPar.d + 1)<r_stat_threshold,2);
                    
                    % Find the threshold generations where R-stat criteria is first met.
                    convergedParamSamplesThreshold = min(output.R_stat(r_stat_acceptable,1));
                    
                    % Find the total number of samples
                    nParamSamples = output.R_stat(end, 1);
                    
                    % Find the number of viable parameter sets                    
                    convergedParamSamples = max(1,nParamSamples - convergedParamSamplesThreshold);

                    % To minimise RAM, only save a maximum of
                    % 2*convergedGenerations parameter sets.
                    if convergedParamSamples>=  2*reqMinParamSamples                        
                        convergedParamSamples = 2*reqMinParamSamples;
                        convergedParamSamplesThreshold = nParamSamples - convergedParamSamples;
                    end
                    
                    if isempty(convergedParamSamples) || convergedParamSamples < 0.1*reqMinParamSamples
                        if isempty(convergedParamSamples)
                            convergedParamSamples = 0;
                        end                    
                        exitFlag=1;
                        exitStatus = ['Insufficient DREAM generations for reliable calibration-selected lesser of last 10,000 samples of 10% of no. samples. Number of reliable param. sets is ', num2str(convergedParamSamples), ...
                            ' and recommended is at least ',num2str(reqMinParamSamples),'. Increase method number to greater than ',num2str(SchemeSetting)];
                        
                        obj.calibrationResults.exitFlag = exitFlag;
                        obj.calibrationResults.exitStatus = exitStatus;
                        
                        convergedParamSamples = min(floor(nParamSamples*0.1), 10000);
                        convergedParamSamplesThreshold = nParamSamples - convergedParamSamples;
                        
                    elseif convergedParamSamples < reqMinParamSamples
                        exitFlag=1;
                        exitStatus = ['Possible insufficient DREAM generations. Number of reliable param. sets is ', num2str(convergedParamSamples), ...
                            ' and recommended is at least ',num2str(reqMinParamSamples),'. Increase method number to greater than ',num2str(SchemeSetting)];
                    else
                        exitFlag=2;
                        exitStatus = ['Sufficient DREAM iterations. Number of reliable param. sets is ', num2str(convergedParamSamples), ...
                            ' and recommended is at least ',num2str(reqMinParamSamples)];                        
                    end

                    convergedParamSamplesThreshold = floor(convergedParamSamplesThreshold/nparams);
                    params = params(convergedParamSamplesThreshold:end,:,:);
                    params = genparset(params);
                    paramsTmp = params(:,1:nparams)';
                    log_L = params(:,end)';
                    params=paramsTmp;    
                    
                    % Filt out any inf likiloof values (just in case)
                    filt = ~isinf(log_L);
                    if any(~filt)
                        exitStatus = [exitStatus, ' WARNING: ', num2str(sum(~filt)), ' parameter sets with liklihood value of inf were removed.'];
                        params = params(filt,:);                    
                        log_L = log_L(filt);
                    end;                    
                    
                    clear paramsTmp
                otherwise
                    error('The requested calibration scheme is unknown.');
            end            
            
            display('--------------------------------------------');             

            %--------------------------------------------------------------
           
            % Finalise model for calibration
            %--------------------------------------------------------------            
            % Get likelihood est (for latter AICc estimate).
            useLikelihood=true;
            if isempty(log_L)
                log_L = objectiveFunction(params, time_points, obj.model, useLikelihood);
            end    
            
            % Get observed head during calib. periods            
            obsHead = obj.model.inputData.head;            
            
            % Call model objects to finalise calibration.
            calibration_initialise(obj.model, t_start, t_end);
            calibration_finalise(obj.model, params, false );            
                       
            % Add final parameters
            [obj.calibrationResults.parameters.params_final, ...
                obj.calibrationResults.parameters.params_name] = getParameters(obj.model);  

            % Add exist status
            obj.calibrationResults.exitFlag = exitFlag;
            obj.calibrationResults.exitStatus = exitStatus;            
            
            % Calculate calibration and evaluation heads
            %--------------------------------------------------------------            
            try                
                head_est = solveModel(obj, obsHead(:,1), [], '', false );
            catch
                head_est = solveModel(obj, obsHead(:,1));
            end
                
            % Convert to real (just n case errors in pram est arose)
            head_est = real(head_est);

            % Eval. residuals.            
            neval = sum(~t_filt);        
            if neval>0
                
                if size(head_est,3)>1
                    obj.evaluationResults.data.modelledHead = [head_est(~t_filt,1,1), permute(prctile( head_est(~t_filt, 2,:),[50 5 95],3),[1,3,2])];
                    obj.evaluationResults.data.modelledNoiseBounds = [head_est(~t_filt,1,1), prctile( head_est(~t_filt, 3,:),5,3), prctile( head_est(~t_filt, 4,:),95,3)];
                    obj.evaluationResults.data.modelledHead_residuals = permute(bsxfun(@minus, obsHead(~t_filt,2), head_est(~t_filt, 2,:)),[ 1 3 2]);
                    head_eval_resid = obj.evaluationResults.data.modelledHead_residuals;
                else
                    obj.evaluationResults.data.modelledHead = head_est(~t_filt,1:2);
                    obj.evaluationResults.data.modelledNoiseBounds = head_est(~t_filt,[1,3,4]);
                    obj.evaluationResults.data.modelledHead_residuals = obsHead(~t_filt,2) -obj.evaluationResults.data.modelledHead(:,2);
                    head_eval_resid = obj.evaluationResults.data.modelledHead_residuals;
                end
                obj.evaluationResults.data.modelledHead_residuals = single(obj.evaluationResults.data.modelledHead_residuals);
            else
                obj.evaluationResults =[];
            end
            
            % Add calib. obs data and residuals
            if size(head_est,3)>1
                obj.calibrationResults.data.modelledHead = [head_est(t_filt,1,1), permute(prctile( head_est(t_filt, 2,:),[50 5 95],3),[1,3,2])];                
                obj.calibrationResults.data.modelledNoiseBounds = [head_est(t_filt,1,1), prctile( head_est(t_filt, 3,:),5,3), prctile( head_est(t_filt, 4,:),95,3)];
                obj.calibrationResults.data.modelledHead_residuals = permute( bsxfun(@minus, obsHead(t_filt,2), head_est(t_filt, 2,:)),[1 3 2]);
                head_calib_resid = obj.calibrationResults.data.modelledHead_residuals;
            else
                obj.calibrationResults.data.modelledHead = head_est(t_filt,1:2);
                obj.calibrationResults.data.modelledNoiseBounds = head_est(t_filt,[1,3,4]);
                obj.calibrationResults.data.modelledHead_residuals = obsHead(t_filt,2) -obj.calibrationResults.data.modelledHead(:,2);
                head_calib_resid = obj.calibrationResults.data.modelledHead_residuals;
            end
            obj.calibrationResults.data.modelledHead_residuals = single(obj.calibrationResults.data.modelledHead_residuals);  % to reduce RAM from DREAM runs
                                                
            nparams = size(params,1);
            nobs = size(obj.calibrationResults.data.modelledHead,1);            
            %--------------------------------------------------------------
            
                        
            % Calc. various performance measures including the coefficient of efficiency using the mean observed head
            %------------------
            % Mean error
            obj.calibrationResults.performance.mean_error =  mean(head_calib_resid);
            
            %RMSE
            SSE = sum(head_calib_resid.^2);
            RMSE = sqrt( 1/size(head_calib_resid,1) * SSE);
            obj.calibrationResults.performance.RMSE = RMSE;                        
            
            % CoE
            obj.calibrationResults.performance.CoeffOfEfficiency_mean.description = 'Coefficient of Efficiency (CoE) calculated using a base model of the mean observed head. If the CoE > 0 then the model produces an estimate better than the mean head.';
            obj.calibrationResults.performance.CoeffOfEfficiency_mean.base_estimate = mean(obsHead(t_filt,2));            
            obj.calibrationResults.performance.CoeffOfEfficiency_mean.CoE  = 1 - SSE./sum( (obsHead(t_filt,2) - mean(obsHead(t_filt,2)) ).^2);            
            
            % Unbiased CoE
            residuals_unbiased = bsxfun(@minus,head_calib_resid, obj.calibrationResults.performance.mean_error);
            SSE_unbiased = sum(residuals_unbiased.^2);
            obj.calibrationResults.performance.CoeffOfEfficiency_mean.CoE_unbias  = 1 - SSE_unbiased./sum( (obsHead(t_filt,2) - mean(obsHead(t_filt,2)) ).^2);            
            
            if neval > 0;                                   
                % Mean error
                obj.evaluationResults.performance.mean_error = mean(head_eval_resid); 
                
                %RMSE
                SSE = sum(head_eval_resid.^2);
                obj.evaluationResults.performance.RMSE = sqrt( 1/size(head_eval_resid,1) * SSE);                
                
                % CoE
                obj.evaluationResults.performance.CoeffOfEfficiency_mean.description = 'Coefficient of Efficiency (CoE) calculated using a base model of the mean observed head. If the CoE > 0 then the model produces an estimate better than the mean head.';
                obj.evaluationResults.performance.CoeffOfEfficiency_mean.base_estimate = mean(obsHead(~t_filt,2));            
                obj.evaluationResults.performance.CoeffOfEfficiency_mean.CoE  = 1 - SSE./sum( (obsHead(~t_filt,2) - mean(obsHead(~t_filt,2)) ).^2);            

                % Unbiased CoE
                residuals_unbiased = bsxfun(@minus,head_eval_resid, obj.evaluationResults.performance.mean_error);
                SSE_unbiased = sum(residuals_unbiased.^2);
                obj.evaluationResults.performance.CoeffOfEfficiency_mean.CoE_unbias  = 1 - SSE_unbiased./sum( (obsHead(~t_filt,2) - mean(obsHead(~t_filt,2)) ).^2);            
            end
            %------------------
                                    
            % Calc. F-test and P(F>F_critical)  
            if size(head_est,3)>1
                meanObsHead = mean(obj.calibrationResults.data.obsHead(:,2));
                for i=1:size(head_est,3)
                    RSS(:,i) = norm( head_est(t_filt, 2,i) - meanObsHead).^2;
                    s2(:,i) = (norm(head_calib_resid(:,i))/sqrt(nobs - nparams)).^2;
                end
            else
                RSS = norm( obj.calibrationResults.data.modelledHead(:,2)  - mean(obj.calibrationResults.data.obsHead(:,2))).^2;            
                s2 = (norm(head_calib_resid)/sqrt(nobs - nparams)).^2;
            end                        
            obj.calibrationResults.performance.F_test = (RSS/(nparams-1))./s2;      % F statistic for regression
            if size(head_est,3)>1
                for i=1:size(head_est,3)
                    obj.calibrationResults.performance.F_prob(:,i) = fcdf(1./obj.calibrationResults.performance.F_test(:,i),nobs - nparams, nparams-1); % Significance probability for regression
                end
            else
                obj.calibrationResults.performance.F_prob = fcdf(1./obj.calibrationResults.performance.F_test,nobs - nparams, nparams-1); % Significance probability for regression
            end
            
            if neval > 0;   
                if size(head_est,3)>1
                    meanObsHead = mean(obj.evaluationResults.data.obsHead(:,2));
                    for i=1:size(head_est,3)
                        RSS(:,i) = norm( head_est(~t_filt, 2,i) - meanObsHead).^2;
                        s2(:,i) = (norm(head_eval_resid(:,i))/sqrt(neval - nparams)).^2;
                    end
                else
                    RSS = norm( obj.evaluationResults.data.modelledHead(:,2)  - mean(obj.evaluationResults.data.obsHead(:,2))).^2;            
                    s2 = (norm(head_eval_resid)/sqrt(neval - nparams)).^2;
                end                        
                obj.evaluationResults.performance.F_test = (RSS/(nparams-1))./s2;      % F statistic for regression
                if size(head_est,3)>1
                    for i=1:size(head_est,3)
                        obj.evaluationResults.performance.F_prob(:,i) = fcdf(1./obj.evaluationResults.performance.F_test(:,i),neval - nparams, nparams-1); % Significance probability for regression
                    end
                else
                    obj.evaluationResults.performance.F_prob = fcdf(1./obj.evaluationResults.performance.F_test,neval - nparams, nparams-1); % Significance probability for regression
                end
            end
            
            % Add BIC and Akaike information criterion                                 
            obj.calibrationResults.performance.AICc = 2*nparams - 2*log_L;
            obj.calibrationResults.performance.AICc = obj.calibrationResults.performance.AICc + 2*nparams*(nparams+1)/(nobs-nparams-1);
            obj.calibrationResults.performance.BIC = nparams*log(nobs) -2*log_L;
            
            % Calculate experimental variogram of residuals and fit an
            % exponential model
            for i=1:size(head_est,3)   
                try
                    resid = [obsHead(t_filt,1), obsHead(t_filt,2) - head_est(t_filt, 2,i)];
                    calib_var = variogram([resid(:,1), zeros( size(resid(:,1))) ] ...
                        , resid(:,2) , 'maxdist', min(365,max(resid(:,1))-min(resid(:,1))), 'nrbins', min(size(resid,1),12));

                    [obj.calibrationResults.performance.variogram_residual.range(i,1), obj.calibrationResults.performance.variogram_residual.sill(i,1), ...
                        obj.calibrationResults.performance.variogram_residual.nugget(i,1), varmodel] ...
                        = variogramfit(calib_var.distance, ...                
                        calib_var.val, 365/4, 0.75.*var( resid(:,2)), calib_var.num, [], ...
                        'model', 'exponential', 'nugget', 0.25.*var( resid(:,2)) ,'plotit',false );

                    obj.calibrationResults.performance.variogram_residual.h(:,i) = varmodel.h;
                    obj.calibrationResults.performance.variogram_residual.gamma(:,i) = varmodel.gamma;
                    obj.calibrationResults.performance.variogram_residual.gammahat(:,i) = varmodel.gammahat;
                catch ME
                    continue;
                end
                    
            end 
            if neval > 0;                
                for i=1:size(head_est,3)      
                    try
                        resid = [obsHead(~t_filt,1), obsHead(~t_filt,2) - head_est(~t_filt, 2,i)];
                        eval_var = variogram([resid(:,1), zeros( size(resid(:,1))) ] ...
                            , resid(:,2) , 'maxdist', min(365,max(resid(:,1))-min(resid(:,1))), 'nrbins', min(size(resid,1),12));

                        [obj.evaluationResults.performance.variogram_residual.range(i,1), obj.evaluationResults.performance.variogram_residual.sill(i,1), ...
                            obj.evaluationResults.performance.variogram_residual.nugget(i,1), varmodel] ...
                            = variogramfit(eval_var.distance, ...                
                            eval_var.val, 365/4, 0.75.*var( resid(:,2)), eval_var.num, [], ...
                            'model', 'exponential', 'nugget', 0.25.*var( resid(:,2)) ,'plotit',false );

                        obj.evaluationResults.performance.variogram_residual.h(:,i) = varmodel.h;
                        obj.evaluationResults.performance.variogram_residual.gamma(:,i) = varmodel.gamma;
                        obj.evaluationResults.performance.variogram_residual.gammahat(:,i) = varmodel.gammahat;
                    catch ME
                        continue;
                    end                    
                end                                 
            end                        
                                   
            % Update flag to denote the calibration completed successfully.
            obj.calibrationResults.isCalibrated = true;            
        end

        function handle = calibrateModelPlotResults(obj, plotNumber, figHandle)
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
%   HydroSightModel: class_description;
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
%

            % Create the figure. If varargin is empty then a new figure
            % window is created. If varagin equals a figure handle, h, then
            % the calibration results are plotted into 'h'.            
            if nargin<3 || isempty(figHandle)
                % Create new figure window.
                figHandle = figure('Name',['Calib. ',obj.bore_ID]);
            elseif ~ishandle(figHandle)    
                error('Input handle is not a valid figure handle.');
            else
                h = figHandle;
            end
            
            % Define the dimensions of the subplots
            if isempty(plotNumber) || nargin==1
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
            
            % Assess if the data is from a population of simlations (eg
            % from DREAM calibration)
            hasModelledDistn = false;
            if size(obj.calibrationResults.data.modelledHead,2)>2   
                hasModelledDistn = true;
                %hasNoiseComponant = false;
            end
            
            % Plot time series of heads.                        
            %-------
            if isempty(plotNumber)
                iplot = 1;
                nplots = ncol_plots;
                h=subplot(nrow_plots,ncol_plots , 1 :ncol_plots,'Parent',figHandle);
                iplot = iplot + nplots;
            end
            
            % Plot bounds for noise component.
            if isempty(plotNumber) || plotNumber==1 
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

                if hasModelledDistn
                   if neval > 0; 
                       XFill = [obj.calibrationResults.data.modelledHead(:,1)' ...
                                obj.evaluationResults.data.modelledHead(:,1)' ...
                                fliplr([obj.calibrationResults.data.modelledHead(:,1); ...
                                        obj.evaluationResults.data.modelledHead(:,1)]')];
                       YFill = [obj.calibrationResults.data.modelledHead(:,4)', ...
                                obj.evaluationResults.data.modelledHead(:,4)', ...
                                fliplr([obj.calibrationResults.data.modelledHead(:,3); ...
                                obj.evaluationResults.data.modelledHead(:,3)]')];
                   else
                       XFill = [obj.calibrationResults.data.modelledHead(:,1)' ...
                                fliplr(obj.calibrationResults.data.modelledHead(:,1)')];
                       YFill = [obj.calibrationResults.data.modelledHead(:,4)', ...
                                fliplr(obj.calibrationResults.data.modelledHead(:,3)')];
                   end
                   fill(XFill, YFill,[0.6 0.6 0.6],'Parent',h);
                   clear XFill YFill               
                   hold(h,'on');                    
                end
                % Plot the observed head
                plot(h,obj.model.inputData.head(:,1), obj.model.inputData.head(:,2),'.-k');
                hold(h,'on');

                % Plot model results
                h_plot = plot(h,obj.calibrationResults.data.modelledHead(:,1), obj.calibrationResults.data.modelledHead(:,2),'.-b' );
                if neval > 0;
                    plot(h,obj.evaluationResults.data.modelledHead(:,1), obj.evaluationResults.data.modelledHead(:,2),'.-r' );
                end
                datetick(h, 'x','yy');
                xlabel(h, 'Date');
                ylabel(h, 'Head (m)');           
                if isempty(plotNumber)
                    title(h, ['Bore ', obj.bore_ID, ' - Observed and modelled head']);
                else
                    title(h, 'Observed and modelled head');
                end

                % Create legend strings  
                i=1;
                if hasNoiseComponant
                    if hasModelledDistn
                        legendstr{i}='Total Err. (5th-95th)';
                    else
                        legendstr{i}='Total Err.';
                    end
                    i=i+1;
                end
                if hasModelledDistn
                    legendstr{i}='Param. Err. (5th-95th)';
                    i=i+1;
                end
                legendstr{i}='Observed';
                i=i+1;
                if hasModelledDistn
                    legendstr{i}='Calib. (median)';
                else
                    legendstr{i}='Calib.';
                end
                i=i+1;                                
                if neval > 0;
                    if hasModelledDistn
                        legendstr{i}='Eval. (median)';
                    else
                        legendstr{i}='Eval.';
                    end
                end                

                % Finish the first plot!
                legend(h, legendstr,'Location','best');
                hold(h,'off');               
            end
            
            % Time series of residuals  
            %-------
            if isempty(plotNumber)
                nplots = ncol_plots;
                h = subplot(nrow_plots,ncol_plots,iplot:iplot+nplots-1,'Parent',figHandle);
                iplot = iplot + nplots;
            end
            if isempty(plotNumber) || plotNumber==2
                if hasModelledDistn
                    residuals = [obj.calibrationResults.data.modelledHead(:,1), prctile( obj.calibrationResults.data.modelledHead_residuals,[50 5 95],2)];
                    ax=errorbar(h, residuals(:,1), residuals(:,2), residuals(:,2)-residuals(:,3), residuals(:,4)-residuals(:,2), '.b' );
                    set(ax,'Color',[0.6 0.6 0.6]);
                    set(ax,'MarkerEdgeColor','b');
                else
                    scatter(h, obj.calibrationResults.data.modelledHead(:,1), obj.calibrationResults.data.modelledHead_residuals, '.b' );
                end
                hold(h,'on');
                if neval > 0;
                    if hasModelledDistn
                        residuals = [obj.evaluationResults.data.modelledHead(:,1), prctile( obj.evaluationResults.data.modelledHead_residuals,[50 5 95],2)];
                        ax=errorbar(h, residuals(:,1), residuals(:,2), residuals(:,2)-residuals(:,3), residuals(:,4)-residuals(:,2), '.r' );
                        set(ax,'Color',[0.6 0.6 0.6]);
                        set(ax,'MarkerEdgeColor','r');
                    else
                        scatter( h, obj.evaluationResults.data.modelledHead(:,1),  obj.evaluationResults.data.modelledHead_residuals, '.r'  );                
                    end
                    legend(h,'Calibration','Evaluation','Location','best');                
                end
                xlabel(h, 'Date');
                ylabel(h, 'Residuals (obs-est) (m)');
                if hasModelledDistn
                    title(h, 'Time series of residuals with parameter uncertainty (5th-95th) bars.');
                else
                    title(h, 'Time series of residuals');
                end
                datetick(h, 'x','yy');
            end
            
            % Histograms of calibration data
            if isempty(plotNumber)
                nplots = 0;
                h = subplot(nrow_plots,ncol_plots,iplot:iplot+nplots,'Parent',figHandle);
                iplot = iplot + nplots + 1;                        
            end
            if isempty(plotNumber) || plotNumber==3
                residuals = [obj.calibrationResults.data.modelledHead(:,1), prctile( obj.calibrationResults.data.modelledHead_residuals,50,2)];
                hist(h, residuals(:,2) , 0.5*size(residuals,1) );            
                ylabel(h, 'Freq.');
                xlabel(h, 'Calib. residuals (obs-est) (m)');
                axis(h, 'tight');
                title(h, 'Histogram of calib. residuals');
            end
            
            % Histograms of evaluation data
            if isempty(plotNumber)
                nplots = 0;
                h = subplot(nrow_plots,ncol_plots,iplot:iplot+nplots,'Parent',figHandle);
                iplot = iplot + nplots + 1;                        
            end
            if isempty(plotNumber) || plotNumber==4
                if neval > 0;            
                    residuals = [obj.evaluationResults.data.modelledHead(:,1), prctile( obj.evaluationResults.data.modelledHead_residuals,50,2)];
                    hist(h, residuals(:,2) , 0.5*size(residuals,1) );                                
                end           
                ylabel(h, 'Freq.');
                xlabel(h, 'Eval. residuals (obs-est) (m)');
                axis(h, 'tight');
                title(h, 'Histogram of eval. residuals');            
            end
            
            % QQ plot
            if isempty(plotNumber)
                nplots = 0;
                h = subplot(nrow_plots,ncol_plots,iplot:iplot+nplots,'Parent',figHandle);
                iplot = iplot + nplots + 1;
            end
            if isempty(plotNumber) || plotNumber==5
                residuals_cal = prctile( obj.calibrationResults.data.modelledHead_residuals,50,2);
                if neval > 0;                              
                    residuals_eval = prctile( obj.evaluationResults.data.modelledHead_residuals,50,2);
                    QQdata = NaN(size(residuals_cal,1),2);
                    QQdata(:,1) = residuals_cal;
                    QQdata(1:neval,2) = residuals_eval;
                    qqplot(QQdata);
                    legend('Calibration','Evaluation','Location','best');                
                else
                    qqplot(residuals_cal );
                end            
                title(h, 'Quantile-quantile plot of residuals');
            end
            
            % Scatter plot of obs versus modelled
            if isempty(plotNumber)
                nplots = 0;
                h = subplot(nrow_plots,ncol_plots,iplot:iplot+nplots,'Parent',figHandle);
                iplot = iplot + nplots + 1;
            end
            if isempty(plotNumber) || plotNumber==6
                if hasModelledDistn                    
                    residuals = [obj.calibrationResults.data.obsHead(:,2), prctile( obj.calibrationResults.data.modelledHead_residuals,[50 5 95],2)];
                    ax=errorbar(h, residuals(:,1), residuals(:,2), residuals(:,2)-residuals(:,3), residuals(:,4)-residuals(:,2), '.b' );
                    set(ax,'Color',[0.6 0.6 0.6]);
                    set(ax,'MarkerEdgeColor','b');
                else
                    scatter(h, obj.calibrationResults.data.obsHead(:,2),  obj.calibrationResults.data.modelledHead(:,2),'.b');
                end
                hold(h,'on');
                if neval > 0;    
                    if hasModelledDistn                        
                        residuals = [obj.evaluationResults.data.obsHead(:,2), prctile( obj.evaluationResults.data.modelledHead_residuals,[50 5 95],2)];
                        ax=errorbar(h, residuals(:,1), residuals(:,2), residuals(:,2)-residuals(:,3), residuals(:,4)-residuals(:,2), '.r' );
                        set(ax,'Color',[0.6 0.6 0.6]);
                        set(ax,'MarkerEdgeColor','r');
                    else
                        scatter(h, obj.evaluationResults.data.obsHead(:,2),  obj.evaluationResults.data.modelledHead(:,2),'.r');
                    end
                    legend(h,'Calibration','Evaluation','Location','best');                
                    head_min = min([obj.model.inputData.head(:,2);  obj.calibrationResults.data.modelledHead(:,2); obj.evaluationResults.data.modelledHead(:,2)] );
                    head_max = max([obj.model.inputData.head(:,2);  obj.calibrationResults.data.modelledHead(:,2); obj.evaluationResults.data.modelledHead(:,2)] );
                else
                    head_min = min([obj.model.inputData.head(:,2);  obj.calibrationResults.data.modelledHead(:,2)] );
                    head_max = max([obj.model.inputData.head(:,2);  obj.calibrationResults.data.modelledHead(:,2)] );
                end            
                xlabel(h, 'Obs. head (m)');
                ylabel(h, 'Modelled. head (m)');
                if hasModelledDistn
                    title(h, 'Observed vs. modelled heads with with parameter uncertainty (5th-95th) bars.');
                else
                    title(h, 'Observed vs. modelled heads');
                end
                xlim(h, [head_min , head_max] );
                ylim(h, [head_min , head_max] );
                plot(h, [head_min, head_max] , [head_min, head_max],'--k');
                hold(h,'off');
            end
            
            % Scatter plot of residuals versus observed head
            if isempty(plotNumber)
                nplots = 0;
                h = subplot(nrow_plots,ncol_plots,iplot:iplot+nplots,'Parent',figHandle);
                iplot = iplot + nplots + 1;
            end
            if isempty(plotNumber) || plotNumber==7
                if hasModelledDistn
                    residuals = [obj.calibrationResults.data.obsHead(:,2), prctile( obj.calibrationResults.data.modelledHead_residuals,[50 5 95],2)];
                    ax=errorbar(h, residuals(:,1), residuals(:,2), residuals(:,2)-residuals(:,3), residuals(:,4)-residuals(:,2), '.b' );
                    set(ax,'Color',[0.6 0.6 0.6]);
                    set(ax,'MarkerEdgeColor','b');
                else
                    scatter(h, obj.calibrationResults.data.obsHead(:,2), obj.calibrationResults.data.modelledHead_residuals,'.b');
                end
                hold(h,'on');
                if neval > 0;                
                    if hasModelledDistn
                        residuals = [obj.evaluationResults.data.obsHead(:,2), prctile( obj.evaluationResults.data.modelledHead_residuals,[50 5 95],2)];
                        ax=errorbar(h, residuals(:,1), residuals(:,2), residuals(:,2)-residuals(:,3), residuals(:,4)-residuals(:,2), '.r' );
                        set(ax,'Color',[0.6 0.6 0.6]);
                        set(ax,'MarkerEdgeColor','r');
                    else                    
                        scatter(h, obj.evaluationResults.data.obsHead(:,2),  obj.evaluationResults.data.modelledHead_residuals,'.r');
                    end
                    legend(h,'Calibration','Evaluation','Location','best');                
                end            
                xlabel(h, 'Obs. head (m)');
                ylabel(h, 'Residuals (obs-est) (m)'); 
                if hasModelledDistn
                    title(h, 'Observed vs. residuals with parameter uncertainty (5th-95th) bars.');
                else                
                    title(h, 'Observed vs. residuals');
                end
                hold(h,'off');        
            end
            
            % Semi-variogram of residuals
            if isempty(plotNumber)
                nplots = 0;
                h = subplot(nrow_plots,ncol_plots,iplot:iplot+nplots,'Parent',figHandle);
                iplot = iplot + nplots + 1;
            end
            if isempty(plotNumber) || plotNumber==8
                if hasModelledDistn
                    % Extract data from cell arrays
                    deltaTime=[];
                    gamma=[];
                    gammaHat=[];
                    if isfield(obj.calibrationResults.performance.variogram_residual,'h')                        
                        deltaTime = obj.calibrationResults.performance.variogram_residual.h;
                        gamma = obj.calibrationResults.performance.variogram_residual.gamma;
                        gammaHat = obj.calibrationResults.performance.variogram_residual.gammahat;                        
                    else
                        for i=1:size(obj.calibrationResults.performance.variogram_residual.range,1)
                            deltaTime = [deltaTime,obj.calibrationResults.performance.variogram_residual.model{i}.h];
                            gamma = [gamma,obj.calibrationResults.performance.variogram_residual.model{i}.gamma];
                            gammaHat = [gammaHat,obj.calibrationResults.performance.variogram_residual.model{i}.gammahat];
                        end
                    end
                    
                    %Plot data
                    ax = errorbar(h, median(deltaTime,2) , median(gamma,2), median(gamma,2)-prctile(gamma,5 ,2),prctile(gamma,95 ,2)-median(gamma,2), '.b');
                    set(ax,'Color',[0.6 0.6 0.6]);
                    set(ax,'MarkerEdgeColor','b');
                    hold(h,'on');
                    plot(h, median(deltaTime,2) , median(gammaHat,2), '-b');
                    plot(h, prctile(deltaTime,5,2) , prctile(gammaHat,5,2), '--b');
                    plot(h, prctile(deltaTime,95,2) , prctile(gammaHat,95,2), '--b');                    
                    
                    if neval > 0;                                
                        % Extract data from cell arrays
                        deltaTime=[];
                        gamma=[];
                        gammaHat=[];
                        if isfield(obj.evaluationResults.performance.variogram_residual,'h')                        
                            deltaTime = obj.evaluationResults.performance.variogram_residual.h;
                            gamma = obj.evaluationResults.performance.variogram_residual.gamma;
                            gammaHat = obj.evaluationResults.performance.variogram_residual.gammahat;                        
                        else
                            for i=1:size(obj.evaluationResults.performance.variogram_residual.range,1)
                                deltaTime = [deltaTime,obj.evaluationResults.performance.variogram_residual.model{i}.h];
                                gamma = [gamma,obj.evaluationResults.performance.variogram_residual.model{i}.gamma];
                                gammaHat = [gammaHat,obj.evaluationResults.performance.variogram_residual.model{i}.gammahat];
                            end
                        end                        

                        %Plot data
                        ax = errorbar(h, median(deltaTime,2) , median(gamma,2), median(gamma,2)-prctile(gamma,5 ,2),prctile(gamma,95 ,2)-median(gamma,2), '.r');
                        set(ax,'Color',[0.6 0.6 0.6]);
                        set(ax,'MarkerEdgeColor','r');                                        
                        plot(h, median(deltaTime,2) , median(gammaHat,2), '-r');
                        plot(h, prctile(deltaTime,5,2) , prctile(gammaHat,5,2), '--r');
                        plot(h, prctile(deltaTime,95,2) , prctile(gammaHat,95,2), '--r');                    
                    
                        legend(h, 'Calib.(5-50-95th %ile)', 'Calib. model-50th %ile','Calib. model-5th %ile','Calib. model-95th %ile', ...
                            'Eval.(5-50-95th %ile)','Eval. model-50th %ile','Eval. model-5th %ile','Eval. model-95th %ile','Location','best');                
                    else
                        legend(h, 'Calib.(5-50-95th %ile)','Calib. model-50th %ile','Calib. model-5th %ile','Calib. model-95th %ile','Location','best');                        
                    end
                else
                    if isfield(obj.calibrationResults.performance.variogram_residual,'h')
                        deltaTime = obj.calibrationResults.performance.variogram_residual.h;
                        gamma = obj.calibrationResults.performance.variogram_residual.gamma;
                        gammaHat = obj.calibrationResults.performance.variogram_residual.gammahat;                          
                    else
                        deltaTime=[];
                        gamma=[];
                        gammaHat=[];
                        for i=1:size(obj.calibrationResults.performance.variogram_residual.range,1)
                            deltaTime = [deltaTime,obj.calibrationResults.performance.variogram_residual.model{i}.h];
                            gamma = [gamma,obj.calibrationResults.performance.variogram_residual.model{i}.gamma];
                            gammaHat = [gammaHat,obj.calibrationResults.performance.variogram_residual.model{i}.gammahat];
                        end                        
                    end
                    scatter(h, deltaTime, gamma, 'ob');            
                    hold(h,'on');
                    plot(h, deltaTime, gammaHat, '-b');                        
                    if neval > 0;     
                        if isfield(obj.evaluationResults.performance.variogram_residual,'h')
                            deltaTime = obj.evaluationResults.performance.variogram_residual.h;
                            gamma = obj.evaluationResults.performance.variogram_residual.gamma;
                            gammaHat = obj.evaluationResults.performance.variogram_residual.gammahat;                          
                        else
                            deltaTime=[];
                            gamma=[];
                            gammaHat=[];
                            for i=1:size(obj.evaluationResults.performance.variogram_residual.range,1)
                                deltaTime = [deltaTime,obj.evaluationResults.performance.variogram_residual.model{i}.h];
                                gamma = [gamma,obj.evaluationResults.performance.variogram_residual.model{i}.gamma];
                                gammaHat = [gammaHat,obj.evaluationResults.performance.variogram_residual.model{i}.gammahat];
                            end                                                    
                        end                        
                        
                        scatter(h, deltaTime, gamma, 'or');
                        plot(h, deltaTime,  gammaHat, '-r');                
                        legend(h, 'Calib.','Calib model','Eval. experimental','Eval. model','Location','best');                
                    else
                        legend(h, 'Calib.','Calib model','Location','best');                
                    end
                end
                xlabel(h, 'Separation distance (days)' );
                ylabel(h, 'Semi-variance (m^2)' );
                title(h, 'Semi-variogram of residuals');
                hold(h,'off');               
            end
        end

        %% Calculate the sum of squared errors and model residuals for CAM-ES.
        function objectiveFunctionValue = calibrationObjectiveFunction(params, obj, time_points, doParamTranspose, getLikelihood)
% Calculate the model objective function value for the input parameter set
%
% Syntax:
%   objectiveFunctionValue = calibrationObjectiveFunction(params, obj, time_points)
%
% Description:
%   The objective function value is calculated for each parameter set by
%   calling the model's own method called objectiveFunction(). For each
%   parameter set a scaler number is returned. It is intended that this 
%   function is only be called from the calibration scheme via
%   calibrateModel(). Importantly, the calculation of the objective
%   function for each parameter set is undertaken in parallel to reduce the
%   calibration time.
%
% Input:
%   params - nxm numerical array of m parameter sets where each parameter
%   set contains n parameters.
%
%   obj -  model object.
%
%   time_points - column vector of the time points over which the model is 
%   to be calibrated.
%
% Output:  
%   objectiveFunctionValue - 1xm numerical vector of the obecjtive function
%   values.
%
% See also:
%   HydroSightModel: class_description;
%   calibrateModel: model_calibration;
%   calibrationValidParameters: model_parameter_set_validity_check
%
% Dependencies
%   model_TFN.m
%   ExpSmooth.m
%   calibrationValidParameters.m
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure Engineering, 
%   The University of Melbourne.
%
% Date:
%   30 June 2015
%
            if doParamTranspose
                params = params';
            end

            objectiveFunctionValue = inf(1,size(params,2));
            parfor i=1: size(params,2)
                %Calculate the residuals
                try
                    % Calcule sume of squared errors
                    objectiveFunctionValue(i) =  objectiveFunction( params(:,i), time_points, obj.model, getLikelihood );
                catch ME
                    objectiveFunctionValue(i) = NaN;
                end
            end
        end        
        
        %% Check validity of parameter set.
        function validParams = calibrationValidParameters(params, obj, time_points,  doParamTranspose, varargin)
% Checks if the parameter set is valid
%
% Syntax:
%   function validParams = calibrationValidParameters(params, obj, time_points)
%
% Description:
%   Each parameter is assessed to dermine if it is valid. That is, if it is
%   within a valid region of the possible parameter space. For each
%   parameter set a scaler logical value is returned. It is intended that this 
%   function is only be called from the calibration scheme via
%   calibrateModel() and the assessment of the parameters is undertaken
%   within the model's method getParameterValidity().
%
% Input:
%   params - nxm numerical array of m parameter sets where each parameter
%   set contains n parameters.
%
%   obj -  model object.
%
%   time_points - column vector of the time points over which the model is 
%   to be calibrated.
%
% Output:  
%   validParams - 1xm logical vector denoting if the parameter set is valid
%   (true) or invalid (false).
%
% See also:
%   HydroSightModel: class_description;
%   calibrateModel: model_calibration;
%
% Dependencies
%   model_TFN.m
%   ExpSmooth.m
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure Engineering, 
%   The University of Melbourne.
%
% Date:
%   30 June 2015
%           
    
            if doParamTranspose
                params = params';
            end
            
            try
                validParams = getParameterValidity(obj.model, params, time_points);
            catch ME
                validParams = false;
            end
        end        
        
        %% Get observed Head.
        function head = getObservedHead(obj)
% Gets the observed head data used to build the model
%
% Syntax:
%   head = getObservedHead(obj)
%
% Description:
%   Returns the observed head data input when the model was constructed.
%
% Input:
%   obj -  model object.
%
% Output:  
%   head - nx2 numerical array of n rows of observed head values. The
%   columns are date, head where the date is as a matlab date number.
%
% See also:
%   HydroSightModel: class_description;
%
% Dependencies
%   model_TFN.m
%   ExpSmooth.m
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure Engineering, 
%   The University of Melbourne.
%
% Date:
%   30 June 2015
%              
            head = getObservedHead(obj.model);
        end
        
        %% Get the forcing data from the model
        function [forcingData, forcingData_colnames] = getForcingData(obj)
% Gets the forcing data for the model.
%
% Syntax:
%   [forcingData, forcingData_colnames] = getForcingData(obj)
%
% Description:
%   Returns the input forcing data input to the model and the column names.
%
% Input:
%   obj -  model object.
%
% Output:  
%   forcingData - nxm numerical array of n rows of forcing data. The
%   columns are the date followed by the forcing values for each type of forcing.
%
%   forcingData_colnames - cells array of column name string associated with the
%   focring data.
%
% See also:
%   HydroSightModel: class_description;
%   setForcingData: assign_forcing_data;
%
% Dependencies
%   model_TFN.m
%   ExpSmooth.m
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure Engineering, 
%   The University of Melbourne.
%
% Date:
%   30 June 2015
%             
            [forcingData, forcingData_colnames] = getForcingData(obj.model);
        end
        
        %% Get the forcing data from the model
        function setForcingData(obj, forcingData, forcingData_colnames)
% Sets the forcing data for the model.
%
% Syntax:
%   setForcingData(obj, forcingData, forcingData_colnames)
%
% Description:
%   Returns the input forcing data input to the model and the column names.
%
% Input:
%   obj -  model object.
%
%   forcingData - nxm numerical array of n rows of forcing data. The
%   columns are the date followed by the forcing values for each type of forcing.
%
%   forcingData_colnames - cells array of column name string associated with the
%   focring data.
%
% Output:  
%   (none)
%
% See also:
%   HydroSightModel: class_description;
%   getForcingData: get_model_forcing_data;
%
% Dependencies
%   model_TFN.m
%   ExpSmooth.m
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure Engineering, 
%   The University of Melbourne.
%
% Date:
%   30 June 2015
%             
            setForcingData(obj.model, forcingData, forcingData_colnames);
        end
       
        function delete(obj)
            % Clear object properties
            obj.model_label=[];
            obj.bore_ID=[];
            obj.calibrationResults=[];
            obj.evaluationResults=[];  
            obj.simulationResults=[];

            % Delete model object.       
            if ~isempty(obj.model)
                delete(obj.model);
            end

        end        
        
    end    
end

