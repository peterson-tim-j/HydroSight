% example_TFN_SW_GW_model:


tic % start timer

% Add Paths
%    addpath(pwd);
addpath(genpath([pwd, filesep, 'algorithms']));
addpath(genpath([pwd, filesep, 'dataPreparationAnalysis']));
addpath(genpath([pwd, filesep, 'Examples']));
addpath(genpath([pwd, filesep, 'documentation']));
addpath(genpath([pwd, filesep, 'GUI']));


% Description
%   This example builds and calibrates a nonlinear transfer-function noise
%   model for the joint calibration and simulation of GW head and streamflow time-series.

%   The model requires the following three data files: obsHead_bore_WRK961324.csv,
%   obsFlow_Brucknell.csv, and climate_Brucknell_Catchment_ETMortonCRAE.csv.
%
%
% References:
%
%   Peterson and Western (2014), Nonlinear time-series modeling of unconfined
%   groundwater head, Water Resources Research, DOI: 10.1002/2013WR014800
%   - Bonotto, Peterson, Fowler, & Western (2022), HydroSight SW-GW: lumped rainfall-runoff model for the joint simulation of streamflow and groundwater in a drying climate, Geoscientific Model Development , , –', ...
%   - Bonotto, Peterson, Fowler, & Western (2022), Can the joint simulation of daily streamflow and groundwater head help to explain the Millennium Drought hydrology?, Water Resour. Res., , –\', ...
%
% Author:
%   Giancarlo Bonotto, The Department of Infrastructure Engineering,
%   Dr. Tim Peterson, The Department of Infrastructure Engineering,
%   The University of Melbourne.
%
% Date:
%   May 2022
%


testing_only = 0; % 1-flag so we run model in diagnosis mode


% Setting pos-processing and diagnostics parameters for model_TFN_SW_GW
if testing_only ==1
    % hydrograph diagnosis plots are generated but not saved for each AMALGAM iteration
    model_object.inputData.plot_hydrographs = true;
    model_object.inputData.save_output_data = false;
else
    % hydrograph diagnosis plots are not generated and not saved for each AMALGAM iteration
    model_object.inputData.plot_hydrographs = false;
    model_object.inputData.save_output_data = false;

end


% Example scenario to be run
scenario="S1"

% Scenario	Catchment	Bore_ID	        Baseflow method	  Interflow Hypothesis
% S1	    Brucknell	bore_WRK961324	baseflow_m9	      IF1

% Load the list of scenarios to run and their inputs
opts = spreadsheetImportOptions("NumVariables", 5);
opts.Sheet = "Sheet1";
opts.DataRange = "B6:F06";
opts.VariableNames = ["A1", "A2", "A3", "A4", "A5"];
list_of_scenarios = readtable("List of Scenarios.xlsx", opts, "UseExcel", false);


%find the scenario in the list of scenarios
index = list_of_scenarios.A1==scenario;

% check if scenario input is valid
check_scenario = list_of_scenarios.A1(index);
if check_scenario ~= scenario
    error('Scenario input is not valid... Check spelling or type of variable used as input..')
end

% get the parameter flags for the scenario
catchment = cell2mat(list_of_scenarios.A2(index));
bore_ID = cell2mat(list_of_scenarios.A3(index));
baseflow_method = cell2mat(list_of_scenarios.A4(index));
interflow_hypothesis = cell2mat(list_of_scenarios.A5(index));

A1 = scenario;
A2 = catchment;
A3 = bore_ID;
A4 = baseflow_method;
A5 = interflow_hypothesis;
formatSpec = '%1$s %2$s %3$s %4$s %5$s';
modelLabel = sprintf(formatSpec,A1,A2,A3,A4,A5)



%   -------- CHANGE THE CACTHMENT ACCORDINGLY  -----------

% Read in file with obs flow.
% Note, eventually site_IDs needs to be chnaged from a single
% string with the bore ID to a vector of stream and bore IDs.
% Maybe the first could be the stream ID.

if catchment=="Brucknell"
    obsDataFlow = readtable('obsFlow_Brucknell.csv'); % read in the obs flow data. Choose from obsFlow_"Catchment".csv
    obsDataFlow = obsDataFlow(:,[2:4 6]); % FLOW UNIT -> columns -> [5] = daily average [m3/s], [6] = [mm/day], [7] = [ML/day], [8] = [mm/day]^(1/5),
    obsDataFlow = table2array(obsDataFlow);
elseif catchment=="Sunday"
    obsDataFlow = readtable('obsFlow_Sunday.csv'); % read in the obs flow data. Choose from obsFlow_"Catchment".csv
    obsDataFlow = obsDataFlow(:,[2:4 6]); % FLOW UNIT -> columns -> [5] = daily average [m3/s], [6] = [mm/day], [7] = [ML/day], [8] = [mm/day]^(1/5),
    obsDataFlow = table2array(obsDataFlow);
elseif catchment=="Ford"
    obsDataFlow = readtable('obsFlow_Ford.csv'); % read in the obs flow data. Choose from obsFlow_"Catchment".csv
    obsDataFlow = obsDataFlow(:,[2:4 6]); % FLOW UNIT -> columns -> [5] = daily average [m3/s], [6] = [mm/day], [7] = [ML/day], [8] = [mm/day]^(1/5),
    obsDataFlow = table2array(obsDataFlow);
end

% List of bores in the study area
if catchment=="Brucknell"
    list_bores = {'bore_WRK961324', 'bore_141234','bore_141243' ,'bore_WRK961325' , 'bore_WRK961326'} ; %  ----- Brucknell
elseif catchment=="Sunday"
    list_bores = {'bore_2091', 'bore_WRK958154', 'bore_WRK958156', 'bore_WRK958155', 'bore_2092'} ; %  --------- Sunday
elseif catchment=="Ford"
    list_bores = {'bore_118946', 'bore_118947'} ; %  ----------------------------------------------------------- Ford
end

% check if boreID is valid
index = find(strcmp(list_bores, bore_ID));
if index <= 0;
    error('bore_ID is not valid... Check spelling or type of variable used as input..')
end

% get the bore data to be used
LoadBoreDataWL = readtable('obsHead_bore_WRK961324.csv');
boreDataWL = LoadBoreDataWL(strcmp(LoadBoreDataWL.BoreID, bore_ID), :);
boreDataWL = boreDataWL(:,2:end);
boreDataWL = table2array(boreDataWL);


% baseflow options
baseflow_options = {'baseflow_v1'; 'baseflow_v2'; 'baseflow_m1';'baseflow_m2';
    'baseflow_m3'; 'baseflow_m4'; 'baseflow_m5'; 'baseflow_m6';
    'baseflow_m7'; 'baseflow_m8'; 'baseflow_m9'; 'baseflow_bi_1';
    'baseflow_bi_2'; 'baseflow_bi_3'; 'baseflow_bi_4'};

% check if baseflow_method is valid
index = find(strcmp(baseflow_options, baseflow_method));
if index <= 0;
    error('baseflow_method is not valid... Check spelling or type of variable used as input..')
end



% read the forcging data time-series in the study area
if catchment=="Brucknell"
    forcingData = readtable('climate_Brucknell_Catchment_ETMortonCRAE.csv');
elseif catchment=="Sunday"
    forcingData = readtable('climate_Sunday_Catchment_ETMortonCRAE.csv');
elseif catchment=="Ford"
    forcingData = readtable('climate_Ford_Catchment_ETMortonCRAE.csv');
end
forcingData = forcingData(:,[3:6 12]);
forcingData = table2array(forcingData);


% Reformat the matric of forcing data to a structure variable containing the column names.
forcingDataStruct.data = forcingData;
forcingDataStruct.colnames = {'YEAR','MONTH','DAY','PRECIP','APET'};

% To increase performance, we can reduce the length of the climate record.
% This may cause longer time scales to be less reliably estimated.
yearsOfPriorForcing = 50;
forcingData_thresholddate  = datenum( boreDataWL(1,1)- yearsOfPriorForcing, boreDataWL(1,2), boreDataWL(1,3));
filt = datenum(forcingDataStruct.data(:,1), forcingDataStruct.data(:,2), forcingDataStruct.data(:,3)) >= forcingData_thresholddate;
forcingDataStruct.data = forcingDataStruct.data(filt,:);

% Define the bore ID and create dummy site coordinates. This must be
% for the bore and each column in the forcing file.
siteCoordinates = {bore_ID, 100, 100;...
    'PRECIP', 100, 100;...
    'APET', 100, 100};

% Define the soil moisture model according to the ---- INTERFLOW Hypothesis ----

if interflow_hypothesis=="IF1"

    %---- Hypothesis 1 ---- NO INTERFLOW ----%
    % using 1-layer soil model "climateTransform_soilMoistureModels_v2"
    %----- Alpha, beta, gamma, EPS are calibrated  ----%
    forcingTransform_Precip = {'transformfunction', 'climateTransform_soilMoistureModels_v2'; ...
        'forcingdata', {'precip','PRECIP';'et','APET'}; ...
        'outputdata', 'drainage'; ...
        'options', {'SMSC',2,[];'k_infilt',Inf,'fixed';'beta',0,'';'k_sat',1,'';'alpha',0,'';'eps',0.0,'';'gamma',0.0,'';...
        'interflow_frac',0.0,'fixed'}}; % withouth ('k_infilt',inf,'fixed') k_infilt is set to 1 automatically..

elseif interflow_hypothesis=="IF2"

    %---- Hypothesis 2 ---- INTERFLOW, NO STORAGE ----%
    % using 1-layer soil model "climateTransform_soilMoistureModels_v2"
    % ---- Alpha, beta, gamma, EPS, inteflow_frac are calibrated  ----%
    forcingTransform_Precip = {'transformfunction', 'climateTransform_soilMoistureModels_v2'; ...
        'forcingdata', {'precip','PRECIP';'et','APET'}; ...
        'outputdata', 'drainage'; ...
        'options', {'SMSC',2,[];'k_infilt',Inf,'fixed'; 'beta',0,'';'k_sat',1,'';'alpha',0,'';'eps',0.0,'';'gamma',0.0,'';...
        'interflow_frac',0.5,''}}; % withouth ('k_infilt',inf,'fixed') k_infilt is set to 1 automatically..

elseif interflow_hypothesis=="IF3"

    %---- Hypothesis 3 ---- INTERFLOW, INFINITE STORAGE ----%
    % using 2-layer soil model "climateTransform_soilMoistureModels_interflow"
    %-----  Alpha, beta, gamma, EPS, inteflow_frac are calibrated. alpha_interflow=0 and beta_sat_interflow=1 fixed ----%
    forcingTransform_Precip = {'transformfunction', 'climateTransform_soilMoistureModels_interflow'; ...
        'forcingdata', {'precip','PRECIP';'et','APET'}; ...
        'outputdata', 'drainage'; ...
        'options', {'SMSC',2,[];'k_infilt',Inf,'fixed';'beta',0,'';'k_sat',1,'';'alpha',0,'';'eps',0.0,'';'gamma',0.0,'';...
        'interflow_frac',0.5,'';'SMSC_interflow',1,'fixed';'alpha_interflow',0,'fixed';'eps_interflow',0,'fixed';...
        'beta_interflow',1,'fixed';'k_sat_interflow',1,'';...
        'PET_scaler_interflow',0,'fixed'; 'gamma_interflow',0,'fixed'}};

elseif interflow_hypothesis=="IF4"
    %---- Hypothesis 4 ---- INTERFLOW, FINITE STORAGE, NO ET LOSSES ----%
    %using 2-layer soil model "climateTransform_soilMoistureModels_interflow"
    %---- Alpha, beta, gamma, EPS, inteflow_frac, alpha_interflow, beta_sat_interflow are calibrated. gamma_interflow= -999999999 fixed ----%
    forcingTransform_Precip = {'transformfunction', 'climateTransform_soilMoistureModels_interflow'; ...
        'forcingdata', {'precip','PRECIP';'et','APET'}; ...
        'outputdata', 'drainage'; ...
        'options', {'SMSC',2,[];'k_infilt',Inf,'fixed';'beta',0,'';'k_sat',1,'';'alpha',0,'';'eps',0.0,'';'gamma',0.0,'';...
        'interflow_frac',0.5,'';'SMSC_interflow',2,'';'alpha_interflow',1,'';'eps_interflow',0,'fixed';...
        'beta_interflow',1,'';'k_sat_interflow',1,'';...
        'PET_scaler_interflow',0,'fixed'; 'gamma_interflow',0,'fixed'}};

elseif interflow_hypothesis=="IF5"

    %---- Hypothesis 5 ---- INTERFLOW, FINITE STORAGE WITH ET LOSSES ----%
    %using 2-layer soil model "climateTransform_soilMoistureModels_interflow"
    %---- Alpha, beta, gamma, EPS, inteflow_frac are calibrated  ----%
    forcingTransform_Precip = {'transformfunction', 'climateTransform_soilMoistureModels_interflow'; ...
        'forcingdata', {'precip','PRECIP';'et','APET'}; ...
        'outputdata', 'drainage'; ...
        'options', {'SMSC',2,[];'k_infilt',Inf,'fixed';'beta',0,'';'k_sat',1,'';'alpha',0,'';'eps',0.0,'';'gamma',0.0,'';...
        'interflow_frac',0.5,'';'SMSC_interflow',2,'';'alpha_interflow',1,'';'eps_interflow',0,'fixed';...
        'beta_interflow',1,'';'k_sat_interflow',1,'';...
        'PET_scaler_interflow',1,'fixed'; 'gamma_interflow',NaN,'fixed'}};

elseif interflow_hypothesis=="IF6"

    %---- Hypothesis 6 ---- INTERFLOW, FINITE STORAGE AND ET LOSSES ----- INTERFLOW STORE SAME PARAMETERS AS SHALLOW SOIL STORE ----%
    %using 2-layer soil model "climateTransform_soilMoistureModels_interflow"
    %---- Alpha, beta, gamma, EPS, inteflow_frac are calibrated  ----%
    forcingTransform_Precip = {'transformfunction', 'climateTransform_soilMoistureModels_interflow'; ...
        'forcingdata', {'precip','PRECIP';'et','APET'}; ...
        'outputdata', 'drainage'; ...
        'options', {'SMSC',2,[];'k_infilt',Inf,'fixed';'beta',0,'';'k_sat',1,'';'alpha',0,'';'eps',0.0,'';'gamma',0.0,'';...
        'interflow_frac',0.5,'';'SMSC_interflow',2,'';'alpha_interflow',NaN,'fixed';'eps_interflow',0,'fixed';...
        'beta_interflow',NaN,'fixed';'k_sat_interflow',NaN,'fixed';...
        'PET_scaler_interflow',1,'fixed'; 'gamma_interflow',NaN,'fixed'}};
end


% using only the the transformed PRECIP from the chosen soil model
modelOptions_7params = { 'precip','weightingfunction','responseFunction_Pearsons'; ...
    'precip','forcingdata',forcingTransform_Precip};


% If using ET for the GW convolution, set the transformation of the ET.
% However because we've already defined the soil model, we only need to specify the output we require.
% Here we're selecting  'evap_gw_potential', which is the potential ET - actual soil ET.

% % using 1-layer soil model "climateTransform_soilMoistureModels"
% forcingTransform_ET = {'transformfunction', 'climateTransform_soilMoistureModels'; ...
%                'outputdata', 'evap_gw_potential'};

% using 2-layer soil model "climateTransform_soilMoistureModels_2layer_v2"
% forcingTransform_ET = {'transformfunction', 'climateTransform_soilMoistureModels_2layer_v2'; ...
%                'outputdata', 'evap_gw_potential'};


% Next we create a cell array for all of the model options. The column format is:
% the forcing name (can be anything), the setting we want to define (ie
% 'weightingfunction' or 'forcingdata'); and the setting we want to apply.
% Note 'responseFunction_Pearsons' is the name of a function.


% using the transformed PRECIP and ET from the soil model
% modelOptions_7params = { 'precip','weightingfunction','responseFunction_Pearsons'; ...
%                         'precip','forcingdata',forcingTransform_Precip; ...
%                         'et','weightingfunction','derivedweighting_PearsonsNegativeRescaled'; ...
%                         'et','inputcomponent','precip'; ...
%                         'et','forcingdata',forcingTransform_ET};


% Set the maximum frequency of water level obs
maxObsFreq = 1;


% Build the 7 parameter model for model_TFN_SW_GW.
model_7params = HydroSightModel(modelLabel, bore_ID, 'model_TFN_SW_GW', boreDataWL, obsDataFlow, maxObsFreq, forcingDataStruct, siteCoordinates, modelOptions_7params);

% getting the parameters necessary for running the transfer functions
[params, param_names] = getParameters(model_7params.model);
t = datenum(boreDataWL(:,1),boreDataWL(:,2),boreDataWL(:,3));

t_start = 0;
t_end  = inf;

%%%% Creating the model structure required to calculate ObjFun for head in model_TFN
[params_initial, time_points_head, time_points_streamflow] = calibration_initialise_joint(model_7params.model, t_start, t_end);


% ----------------------------------------------------------------------------------------- %
% ADJUSTING AND CALLING AMALGAM FOR THE JOINT CALIBRATION
% ----------------------------------------------------------------------------------------- %

% Define which algorithms to use in AMALGAM
Extra.Alg = {'GA','PSO','AMS','DE'};
% Define the number of algorithms
AMALGAMPar.q = size(Extra.Alg,2);

AMALGAMPar.n = length(params_initial);  % Dimension of the problem
AMALGAMPar.N = 20;                     % Size of the population
AMALGAMPar.nobj = 2;                    % Number of objectives
AMALGAMPar.ndraw = 60;               % Maximum number of function evaluations

% Getting the parameter ranges (minimum and maximum values)
[params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(model_7params.model);

% set baseflow head_threshold parameter bounds to be +5m within
% observed GW head data.
params_upperLimit(end,:) = max(boreDataWL(:,6)) + 5;
params_lowerLimit(end,:) = min(boreDataWL(:,6)) - 5;

% Setting the parameter ranges (minimum and maximum values)
ParRange.minn = params_lowerLimit';
ParRange.maxn = params_upperLimit';

% Initial Sample of Parameters Created with Latin Hypercube sampling
Extra.InitPopulation = 'LHS';

% Define the timepoints for the obs. head and streamflow data
Measurement.time_points_head = time_points_head; Measurement.time_points_streamflow = time_points_streamflow;
Measurement.Sigma = []; Measurement.N = size(Measurement.time_points_streamflow,1);

% Define ModelName
model_object = model_7params.model; % hydrosight model as input
ModelName = modelLabel; % Scenario that is running

% Define the boundary handling
Extra.BoundHandling = 'Bound';

% True Pareto front is not available -- real world problem
Fpareto = [];

% Store example number in structure Extra
Extra.m = AMALGAMPar.n;


% Run the AMALGAM calibration and obtain the solution set
[output,ParGen,ObjVals,ParSet,allOriginalObjVals_Flow] = AMALGAM(AMALGAMPar,ModelName,ParRange,Measurement,Extra,Fpareto,model_object);



if testing_only ==1
    % continue

    % Don't save any data from the AMALGAM Run

else

    % Path used to store the hydrographs
    folder = 'C:\Users\bonottog\OneDrive - The University of Melbourne (1)\1 - UNIMELB\5 - HydroSight\10 - Run Results\Interflow_Scenarios\500k';


    %--------------AUTOMATICALLY GENERATE HYDROGRAPH PLOTS FOR THE SWEET-SPOT IN THE LAST PARETO FRONT -------------------------------- %

    % find the parameter set that represents the sweet-stop in the last Pareto Front
    final_pareto_points = ParSet(end-AMALGAMPar.N+1:end,end-1:end);
    sweet_spot = [min(final_pareto_points(:,1)) min(final_pareto_points(:,2))];
    [k,dist] = dsearchn(final_pareto_points,sweet_spot);
    final_pareto_params_points = ParSet(end-AMALGAMPar.N+1:end,:);
    optimal_parameters = final_pareto_params_points(k, 1:end-3);
    optimal_parameters_ObjFun = final_pareto_params_points(k, :);

    % diagnosis plot to find the sweet-spot in the pareto front
    figure(1);
    scatter(final_pareto_points(:,1),final_pareto_points(:,2))
    %xlim([0 5])
    %ylim([0 5])
    hold on
    scatter(optimal_parameters_ObjFun(:,end-1),optimal_parameters_ObjFun(:,end),'red')
    scatter(sweet_spot(:,end-1),sweet_spot(:,end),'red')
    plot( [sweet_spot(:,end-1);optimal_parameters_ObjFun(:,end-1)], [sweet_spot(:,end);optimal_parameters_ObjFun(:,end)] )

    % Save the Pareto Front diagnosis plot
    f = figure(1);
    %     f = figure(2);
    set(f, 'Color', 'w');
    A1 = 'DIAGNOSIS_Pareto_Front_Final Generation';
    A2 = ModelName;
    formatSpec = '%1$s %2$s';
    Filename = sprintf(formatSpec,A2,A1);
    saveas(f, fullfile(folder, Filename), 'png');


    % save the parameter set and objfun sweet-spot as a separate
    % CSV file
    A1 = ModelName;
    A2 = 'ParetoFront_Optimal_Point';
    A3 = '.csv';
    formatSpec = '%1$s %2$s %3$s';
    Filename = sprintf(formatSpec,A1,A2,A3);
    path =fullfile(folder, Filename);
    csvwrite(path,optimal_parameters_ObjFun)

    % set model_TFN_SW_GW to plot and save the plots
    model_object.inputData.plot_hydrographs = true;
    model_7params.model.inputData.save_output_data = true;

    % run model_TFN_SW_GW, plotting and saving hydrographs for optimal
    % point in the Pareto Front
    [ObjVals_prime, ~, ~, objFn_flow_NSE, objFn_flow_NNSE, objFn_flow_RMSE, objFn_flow_SSE, objFn_flow_bias, ~, ~,~] = objectiveFunction_joint(optimal_parameters', time_points_head, time_points_streamflow, model_7params.model,{});

end

toc % stop timer


