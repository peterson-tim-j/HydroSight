% example_TFN_model:
%
% Description
%   This example builds and calibrates a nonlinear transfer-function noise
%   model. The example is taken from Peterson & Western (2014). The model
%   requires the following three data files: 124705_boreData.mat,
%   124676_boreData.mat and 124705_forcingData.mat.
%
%   By default the example models bore 124676. By commenting out line 29
%   and un-commenting line 28, bore 124705 can be modelled.
%
%   Also, logical variables at line 112 and 113 also define which of 
%   two model structures are to be calibrated.
%
% References:
%
%   Peterson and Western (2014), Nonlinear time-series modeling of unconfined
%   groundwater head, Water Resources Research, DOI: 10.1002/2013WR014800
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure Engineering, 
%   The University of Melbourne.
%
% Date:
%   26 Sept 2014
%

%clear all

% Comment out the one bore ID that you DO NOT want to model.
% bore_ID = 'ID124705';
% 
% if strcmp(bore_ID,'ID124705')
%     load('124705_boreData.mat');
% else
%     load('124676_boreData.mat');
% end
% 
% load('124705_forcingData.mat');


% % read the observed flow time-series 
% obsDataFlow = readtable('obsFlow_Brucknell_up to 2009.csv');
% obsDataFlow = obsDataFlow(:,2:end);
% obsDataFlow = table2array(obsDataFlow);

% read the observed head time-series 
bore_ID = 'bore_WRK961326'; %  -------- CHANGE THE BORE ACCORDINGLY 
LoadBoreDataWL = readtable('obsHead_all_bores_outliers_removed_Run2.csv');
boreDataWL = LoadBoreDataWL(strcmp(LoadBoreDataWL.BoreID, bore_ID), :);
boreDataWL = boreDataWL(:,2:end);
boreDataWL = table2array(boreDataWL);


% read the forcging data time-series   -------- CHANGE THE CACTHMENT ACCORDINGLY 
forcingData = readtable('climate_Brucknell_Catchment_ETMortonCRAE.csv');  
% forcingData = readtable('climate_Ford_Catchment_ETMortonCRAE.csv');
% forcingData = readtable('climate_Sunday_Catchment_ETMortonCRAE.csv');
forcingData = forcingData(:,[3:6 12]);
forcingData = table2array(forcingData);

% CHECK IF GW HEAD OBS TIME-SERIES LENGTH IS LONGER OR EQUAL TO STREAMFLOW TIME-SERIES.. IT MAY BE CAUSING THE ERROR FOR FORD AND SUNDAY... 

% Reformat the matric of forcing data to a sturctire variable containing
% the column names.
forcingDataStruct.data = forcingData;
% forcingDataStruct.colnames = {'YEAR','MONTH','DAY','PRECIP','APET','RevegFrac'};
forcingDataStruct.colnames = {'YEAR','MONTH','DAY','PRECIP','APET'};

% To increase performance, we can reduce the length of the climate record.
% This may cause longer time scales to be less reliably estimated.
yearsOfPriorForcing = 100;
forcingData_thresholddate  = datenum( boreDataWL(1,1)- yearsOfPriorForcing, boreDataWL(1,2), boreDataWL(1,3)); 
filt = datenum(forcingDataStruct.data(:,1), forcingDataStruct.data(:,2), forcingDataStruct.data(:,3)) >= forcingData_thresholddate;
forcingDataStruct.data = forcingDataStruct.data(filt,:);

% Define the bore ID and create sume dummy site coordinates. This must be
% for the bore and each column in the forcing file.
% siteCoordinates = {bore_ID, 100, 100;...
%                     'PRECIP', 100, 100;...
%                     'APET', 100, 100;...
%                     'RevegFrac',602, 100};
               
siteCoordinates = {bore_ID, 100, 100;...
                    'PRECIP', 100, 100;...
                    'APET', 100, 100};
                

% Define the way in which the precipitation is transformed. In this case it
% is transformed using the 'climateTransform_soilMoistureModels' soil
% model. 
% Next, the soil ODE needs inputs data 'precip' and 'et' and the forcing
% data input columns are 'PRECIP' and 'ET'.
% Next, the 'outputdata' that is to be taken from the soil model is
% defined. Each model has fixed options and here we're taking
% 'drainage_normalised'.
% Lastly, we can set 'options' for the soil model. In this case we are
% defining the initial values for three parameters (SMSC, beta, ksat) and
% fixing alpha to zero.
forcingTransform_Precip = {'transformfunction', 'climateTransform_soilMoistureModels'; ...
               'forcingdata', {'precip','PRECIP';'et','APET'}; ...
               'outputdata', 'drainage'; ...
               'options', {'SMSC',2,[];'beta',0,'';'k_sat',-inf,'fixed';'alpha',0,'fixed'}};
           
% The transformation of the ET is then defined. However because we've already 
% defined the soil model, we only need to specify the output we require.
% Here we're selecting  'evap_gw_potential', which is the potential ET -
% actual soil ET.
forcingTransform_ET = {'transformfunction', 'climateTransform_soilMoistureModels'; ...
               'outputdata', 'evap_gw_potential'};

% Next we create a cell array for all of the model options. The column format is:            
% the forcing name (can be anything), the setting we want to define (ie
% 'weightingfunction' or 'forcingdata'); and the setting we want to apply.
% Note 'responseFunction_Pearsons' is the name of a function.
modelOptions_9params = { 'precip','weightingfunction','responseFunction_Pearsons'; ...
                        'precip','forcingdata',forcingTransform_Precip; ...
                        'et','weightingfunction','responseFunction_PearsonsNegative'; ...
                        'et','forcingdata',forcingTransform_ET};

% Alternatively, we can create a cell array for the model options where the
% ET weighting function inherits the shape from the precipitation. The column format is:            
% the forcing name (can be anything), the setting we want to define (ie
% 'weightingfunction' or 'forcingdata'); and the setting we want to apply.
% Note 'responseFunction_Pearsons' is the name of a function.
modelOptions_7params = { 'precip','weightingfunction','responseFunction_Pearsons'; ...
                        'precip','forcingdata',forcingTransform_Precip; ...
                        'et','weightingfunction','derivedweighting_PearsonsNegativeRescaled'; ...
                        'et','inputcomponent','precip'; ...
                        'et','forcingdata',forcingTransform_ET};                    
                    
% Set the maximum frequency of water level obs
maxObsFreq = 1;

% Select which model structures to build and calibrate.
run7paramModel = true;
run9paramModel = false;

% Define a model lable
% modelLabel = 'Great Western Catchment - no landuse change';
modelLabel = 'Brucknell Catchment - using catchhment average forcing, bore_141234, daily flow';

% directory = 'C:\Users\gbonotto\OneDrive - The University of Melbourne\1 - UNIMELB\5 - HydroSight\7 - HydroSight_SW_GW';
% viewClassTree(directory)

if run7paramModel
    % Build the 7 parameter model.
    model_7params = HydroSightModel(modelLabel, bore_ID, 'model_TFN_SW_GW', boreDataWL, maxObsFreq, forcingDataStruct, siteCoordinates, modelOptions_7params);

    
    
    [params, param_names] = getParameters(model_7params.model);
    t = datenum(boreDataWL(:,1),boreDataWL(:,2),boreDataWL(:,3));
    
    t_start = 0;
    t_end  = inf;
    %%%% dont i need to first do this to then get the objective function?
    [params_initial, time_points_head, time_points_streamflow] = calibration_initialise(model_7params.model, t_start, t_end); % put it outside of objectiveFunction to avoid initializing it again during the callinf of "solve" inside of "objectiveFunction"
 
    
    % call amalgam 
    
    
%     [objFn, flow_star, colnames, drainage_elevation] = objectiveFunction(params, t, model_7params.model,{});
%     [objFn_joint, objFn_head, objFn_flow, flow_star, colnames, drainage_elevation] = objectiveFunction_joint(params_initial, time_points_head, time_points_streamflow, model_7params.model,{}); % using time points from calibration_initialise to avoid mismatch of dimensions in line 2803 of model_TFN
%     objFn_joint

    
    % ----------------------------------------------------------------------------------------- %
    
    % TO DO: BEST WAY TO INCLUDE AMALGAM? The script bellow is an example
    % from the manual using hymod 
    % SHOULD WE INCLUDE BEFORE THE CALIBRATION IN HYDROSIGHT, RIGHT?
    % ----------------------------------------------------------------------------------------- %
    
    % BOTH OBJ-FUNC SHOULD BE MINIMIZED IN AMALGAM....... 
    
    % Define which algorithms to use in AMALGAM
    Extra.Alg = {'GA','PSO','AMS','DE'};
    % Define the number of algorithms
    AMALGAMPar.q = size(Extra.Alg,2);
    
    % HydroSight using model_TFN_SW_GW - joint rainfall-runoff model
    
%     AMALGAMPar.n = 5;                       % Dimension of the problem    
    AMALGAMPar.n = length(params_initial);  % Dimension of the problem    ----  run7paramModel now has 9 parameters? are we allowing head-threshoold and head_to_baseflow to be calibrated? 
    AMALGAMPar.N = 100;                     % Size of the population   - LENTGH OF OBS. TIMESERIES or just a calibration parameter?
    AMALGAMPar.nobj = 2;                    % Number of objectives
    AMALGAMPar.ndraw = 10000;               % Maximum number of function evaluations
    
    % Define the parameter ranges (minimum and maximum values)
    [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(model_7params.model);
%     ParRange.minn = params_lowerLimit(1:end-1,1); % ignoring the last value cause it refers to "doingCalibration", which is not used in "objectiveFunction_joint"
%     ParRange.maxn = params_upperLimit(1:end-1,1); % ignoring the last value cause it refers to "doingCalibration", which is not used in "objectiveFunction_joint"
    ParRange.minn = params_lowerLimit; % ignoring the last value cause it refers to "doingCalibration", which is not used in "objectiveFunction_joint"
    ParRange.maxn = params_upperLimit; % ignoring the last value cause it refers to "doingCalibration", which is not used in "objectiveFunction_joint"
    
    % How is the initial sample created -- Latin Hypercube sampling
    Extra.InitPopulation = 'LHS';
    
    % Load the Leaf River data
%     load bound.txt;
    
    % Then read the boundary conditions -- use entire obs. time-series
% %     Extra.MaxT = inf;
    
    % Define the PET, Measured Streamflow and Precipitation.
%     Extra.PET = bound(1:Extra.MaxT,5); Extra.Precip = sum(bound(1:Extra.MaxT,6:9),2);
    
    % Define the measured streamflow data
    %     Measurement.MeasData = bound(65:Extra.MaxT,4); Measurement.Sigma = []; Measurement.N = size(Measurement.MeasData,1);
    Measurement.time_points_head = time_points_head; Measurement.time_points_streamflow = time_points_streamflow;
    Measurement.Sigma = []; Measurement.N = size(Measurement.time_points_streamflow,1);
    
    % Define ModelName
    %     ModelName = 'hymod';
    model_object = model_7params.model;
%     Measurement = [];
    ModelName = 'objectiveFunction_joint4AMALGAM'; % which part of hydrosight to input?
    
    % Define the boundary handling
    Extra.BoundHandling = 'Bound';
    
    % True Pareto front is not available -- real world problem
    Fpareto = [];
       
    
    % Store example number in structure Extra
%     Extra.example = example; 
    Extra.m = AMALGAMPar.n;
    
    % Run the AMALGAM code and obtain non-dominated solution set
    [output,ParGen,ObjVals,ParSet] = AMALGAM(AMALGAMPar,ModelName,ParRange,Measurement,Extra,Fpareto,model_object);



% ---------------------------------------------------------------------------------------------------%
    
    
    
    
    
    
    % Set the number of SP-UCI calibration clusters per parameter
    SchemeSetting.ngs = 7;    
    
    % Calibrate the 7 parameter model.
    calibrateModel(model_7params, [], 0, inf, 'SP-UCI', SchemeSetting);
    
    % Plot the calibration results.    
    calibrateModelPlotResults(model_7params,[]);
   
    % Plot the simulation results. 
    time_points = model_7params.model.variables.time_points;
    newForcingData = [];
    simulationLabel = 'default simulation';
    doKrigingOnResiduals = false;    
    solveModel(model_7params, time_points, newForcingData, simulationLabel, doKrigingOnResiduals);    
    solveModelPlotResults(model_7params, simulationLabel, []);    
end

if run9paramModel
    % Build the 9 parameter model.
    model_9params = HydroSightModel(modelLabel, bore_ID, 'model_TFN', boreDataWL, maxObsFreq, forcingDataStruct, siteCoordinates, modelOptions_9params);


    % Set the number of SP-UCI calibration clusters per parameter
    SchemeSetting.ngs = 4*9;    
    
    % Calibrate the 7 parameter model.
    calibrateModel(model_9params, [],  0, inf, 'SP-UCI', SchemeSetting);
    
    % Plot the calibration results.
    sTime = tic;
    calibrateModelPlotResults(model_9params,[]);
    eTime = tic;
    eTime = toc(eTime);
    display(['Calibration time = ',num2str(eTime-sTime),'  sec']); 
   
    % Plot the simulation results. 
    time_points = model_9params.model.variables.time_points;
    newForcingData = [];
    simulationLabel = 'default simulation';
    doKrigingOnResiduals = false;    
    solveModel(model_9params, time_points, newForcingData, simulationLabel, doKrigingOnResiduals);    
    solveModelPlotResults(model_9params, simulationLabel, []);    
end
