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


% List of bores in the study area 
list_bores = {'bore_WRK961324', 'bore_141234','bore_141243' ,'bore_WRK961325' , 'bore_WRK961326'} ; %  ----- Brucknell 
% list_bores = {'bore_118946', 'bore_118947'} ; %  ----------------------------------------------------------- Ford 
% list_bores = {'bore_2091', 'bore_WRK958154', 'bore_WRK958156', 'bore_WRK958155', 'bore_2092'} ; %  --------- Sunday 

for i=1:1
% for i=1:length(list_bores)

tic % start timer

catchment = 'Brucknell Creek';
% catchment = 'Ford Creek';
% catchment = 'Sunday Creek';

% read the observed head time-series 
bore_ID = list_bores(i); %  -------- CHANGE THE BORE ACCORDINGLY 

% change bore_ID to matrix to make it usable in the rest of the code
bore_ID = cell2mat(bore_ID) % print the bore_ID to check progress 

% bore_ID = 'bore_141243'; %  
LoadBoreDataWL = readtable('obsHead_all_bores_outliers_removed_Run2.csv');
boreDataWL = LoadBoreDataWL(strcmp(LoadBoreDataWL.BoreID, bore_ID), :);
boreDataWL = boreDataWL(:,2:end);
boreDataWL = table2array(boreDataWL);


% read the forcging data time-series   ---------------- CHANGE THE CACTHMENT ACCORDINGLY 
forcingData = readtable('climate_Brucknell_Catchment_ETMortonCRAE.csv');  % --- Brucknell 
% forcingData = readtable('climate_Ford_Catchment_ETMortonCRAE.csv'); % ------- Ford
% forcingData = readtable('climate_Sunday_Catchment_ETMortonCRAE.csv'); % ----- Sunday
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



% using 1-layer soil model "climateTransform_soilMoistureModels" allowing beta,
% ksat, beta_deep,ksat_deep be calibrated  
% forcingTransform_Precip = {'transformfunction', 'climateTransform_soilMoistureModels'; ...
%                'forcingdata', {'precip','PRECIP';'et','APET'}; ...
%                'outputdata', 'drainage'; ...
%                'options', {'SMSC',2,[];'beta',0,'';'k_sat',1,'';'alpha',0,'fixed'}};
           
% using 2-layer soil model "climateTransform_soilMoistureModels_2layer_v2" allowing beta,
% ksat, beta_deep,ksat_deep be calibrated 
forcingTransform_Precip = {'transformfunction', 'climateTransform_soilMoistureModels_2layer_v2'; ...
               'forcingdata', {'precip','PRECIP';'et','APET'}; ...
               'outputdata', 'drainage_deep'; ...
               'options', {'SMSC',2,[];'SMSC_deep',2,[];'beta',0,'';'k_sat',1,'';'alpha',1,'';'beta_deep',NaN,'fixed';'k_sat_deep',NaN,'fixed'}}; % had to set k_sat_deep and beta_deep as "fixed" to allow it to pass line 480 of climateTransform_soilMoistureModels_2layer_v2
           
           
           
% The transformation of the ET is then defined. However because we've already
% defined the soil model, we only need to specify the output we require.
% Here we're selecting  'evap_gw_potential', which is the potential ET -
% actual soil ET.

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

% using only the the transformed PRECIP from the chosen soil model
modelOptions_7params = { 'precip','weightingfunction','responseFunction_Pearsons'; ...
                        'precip','forcingdata',forcingTransform_Precip};


% using the transformed PRECIP and ET from the soil model
% modelOptions_7params = { 'precip','weightingfunction','responseFunction_Pearsons'; ...
%                         'precip','forcingdata',forcingTransform_Precip; ...
%                         'et','weightingfunction','derivedweighting_PearsonsNegativeRescaled'; ...
%                         'et','inputcomponent','precip'; ...
%                         'et','forcingdata',forcingTransform_ET};


% Set the maximum frequency of water level obs
maxObsFreq = 1;


% Define a model label
A1 = catchment;
A2 = '- using catchment average forcing,';
A3 = bore_ID;
A4 = ',daily flow, ';
A5 = modelOptions_7params{1,1}; 
A6 = 'weighting functions';
formatSpec = '%1$s %2$s %3$s %4$s %5$s %6$s';
% A6 = modelOptions_7params{3,1};
% A7 = 'weighting functions';
% formatSpec = '%1$s %2$s %3$s %4$s %5$s %6$s %7$s';

modelLabel = sprintf(formatSpec,A1,A2,A3,A4,A5,A6);
% modelLabel = sprintf(formatSpec,A1,A2,A3,A4,A5,A6,A7);


    
% directory = 'C:\Users\gbonotto\OneDrive - The University of Melbourne\1 - UNIMELB\5 - HydroSight\7 - HydroSight_SW_GW';
% viewClassTree(directory)

    % Build the 7 parameter model.
    model_7params_gw = HydroSightModel(modelLabel, bore_ID, 'model_TFN', boreDataWL, maxObsFreq, forcingDataStruct, siteCoordinates, modelOptions_7params);

    model_7params = HydroSightModel(modelLabel, bore_ID, 'model_TFN_SW_GW', boreDataWL, maxObsFreq, forcingDataStruct, siteCoordinates, modelOptions_7params);

    % getting the parameters necessary for running the transfer functions 
    [params, param_names] = getParameters(model_7params.model);
    t = datenum(boreDataWL(:,1),boreDataWL(:,2),boreDataWL(:,3));
    
    t_start = 0;
    t_end  = inf;
    
    %%%% Creating the model structure required to calculate ObjFun for head in model_TFN 
    [params_initial, time_points_head, time_points_streamflow] = calibration_initialise(model_7params.model, t_start, t_end); % put it outside of objectiveFunction to avoid initializing it again during the callinf of "solve" inside of "objectiveFunction"
 
    
    
    % ----------------------------------------------------------------------------------------- %
    % TO DO: BEST WAY TO INCLUDE AMALGAM? The script bellow is an example
    % from the manual using hymod 
    % SHOULD WE INCLUDE BEFORE THE CALIBRATION IN HYDROSIGHT, RIGHT?
    
    % BOTH OBJ-FUNC SHOULD BE MINIMIZED IN AMALGAM....... 
    % ----------------------------------------------------------------------------------------- %
    
    % Define which algorithms to use in AMALGAM
    Extra.Alg = {'GA','PSO','AMS','DE'};
    % Define the number of algorithms
    AMALGAMPar.q = size(Extra.Alg,2);
    
    % HydroSight using model_TFN_SW_GW - joint rainfall-runoff model
    
    AMALGAMPar.n = length(params_initial);  % Dimension of the problem    ----  run7paramModel now has 9 parameters? are we allowing head-threshoold and head_to_baseflow to be calibrated? 
    AMALGAMPar.N = 100;                     % Size of the population   - LENTGH OF OBS. TIMESERIES or just a calibration parameter?
    AMALGAMPar.nobj = 2;                    % Number of objectives
    AMALGAMPar.ndraw = 100000;               % Maximum number of function evaluations
    
    % Define the parameter ranges (minimum and maximum values)
    [params_upperLimit, params_lowerLimit] = getParameters_plausibleLimit(model_7params.model);
%     ParRange.minn = params_lowerLimit(1:end-1,1); % ignoring the last value cause it refers to "doingCalibration", which is not used in "objectiveFunction_joint"
%     ParRange.maxn = params_upperLimit(1:end-1,1); % ignoring the last value cause it refers to "doingCalibration", which is not used in "objectiveFunction_joint"
    ParRange.minn = params_lowerLimit'; % transpose params_upperLimi to meet expect format in AMALGAM 
    ParRange.maxn = params_upperLimit'; % transpose params_upperLimi to meet expect format in AMALGAM 
    
    % How is the initial sample created -- Latin Hypercube sampling
    Extra.InitPopulation = 'LHS';
    
   
    % Define the timepoints for the obs. head and streamflow data
    Measurement.time_points_head = time_points_head; Measurement.time_points_streamflow = time_points_streamflow;
    Measurement.Sigma = []; Measurement.N = size(Measurement.time_points_streamflow,1);
    
    % Define ModelName
    model_object = model_7params.model; % giving the hydrosight model as input 
    ModelName = 'objectiveFunction_joint'; % which part of hydrosight to input?
    
    % Define the boundary handling
    Extra.BoundHandling = 'Bound';
    
    % True Pareto front is not available -- real world problem
    Fpareto = [];
       
    
    % Store example number in structure Extra
    Extra.m = AMALGAMPar.n;
    
    % Run the AMALGAM code and obtain non-dominated solution set
    [output,ParGen,ObjVals,ParSet,allOriginalObjVals_Flow] = AMALGAM(AMALGAMPar,ModelName,ParRange,Measurement,Extra,Fpareto,model_object);

    
    
    % Store the figure showing Pareton Front of all generations of params
%     f = figure(1);
%     set(f, 'Color', 'w');
%     A1 = 'Pareto Front_All Generations_';
%     A3 = bore_ID;
%     A4 = catchment;
%     A5 = 'Weighting';
%     weighting_forces = unique(modelOptions_7params(:,1));
%     A6= weighting_forces(1);
%     A6 = cell2mat(A6);
%     A7 = datestr(now,'mm-dd-yyyy HH-MM');
%     formatSpec = '%1$s %2$s %3$s %4$s %5$s %6$s';
%     Filename = sprintf(formatSpec,A1,A3,A4,A5,A6,A7);
% %     A7 = weighting_forces(2);
% %     A7 = cell2mat(A7);
% %     A8 = datestr(now,'mm-dd-yyyy HH-MM');
% %     formatSpec = '%1$s %2$s %3$s %4$s %5$s %6$s %7$s';
% %     Filename = sprintf(formatSpec,A1,A3,A4,A5,A6,A7,A8);
%     folder = 'C:\Users\gbonotto\OneDrive - The University of Melbourne\1 - UNIMELB\5 - HydroSight\10 - Run Results';
%     savefig(f,fullfile(folder, Filename))

    
           
    %Storing the model object "model_7params" to show the configuration used for model_TFN_SW_GW
    A1 = 'Configuration_model_TFN_SW_GW_';
    A2 = bore_ID;
    A3 = catchment;
    A4 = datestr(now,'mm-dd-yyyy HH-MM');
    A5 = '.mat';
    formatSpec = '%1$s %2$s %3$s %4$s %5$s';
    Filename = sprintf(formatSpec,A1,A2,A3,A4,A5);
    folder = 'C:\Users\gbonotto\OneDrive - The University of Melbourne\1 - UNIMELB\5 - HydroSight\10 - Run Results';
    path =fullfile(folder, Filename);
    save(path,'model_7params')  % Save model object
             
    %Storing all generation of parameters, including the Obj-Function Value
    %for each parameter set
    A1 = 'Amalgam_Params_ObjFun_All Generations_';
    A2 = bore_ID;
    A3 = catchment;
    A4 = datestr(now,'mm-dd-yyyy HH-MM');
    A5 = '.csv';
    formatSpec = '%1$s %2$s %3$s %4$s %5$s';
    Filename = sprintf(formatSpec,A1,A2,A3,A4,A5);
    folder = 'C:\Users\gbonotto\OneDrive - The University of Melbourne\1 - UNIMELB\5 - HydroSight\10 - Run Results';
    path =fullfile(folder, Filename);
    csvwrite(path,ParSet)
    
    %Storing last generation of parameters
    A1 = 'Amalgam_Params_Final Generation_';
    A2 = bore_ID;
    A3 = catchment;
    A4 = datestr(now,'mm-dd-yyyy HH-MM');
    A5 = '.csv';
    formatSpec = '%1$s %2$s %3$s %4$s %5$s';
    Filename = sprintf(formatSpec,A1,A2,A3,A4,A5);
    folder = 'C:\Users\gbonotto\OneDrive - The University of Melbourne\1 - UNIMELB\5 - HydroSight\10 - Run Results';
    path =fullfile(folder, Filename);
    csvwrite(path,ParGen)
        
    %Storing the all original Obj-Func for flow (NSE, NNSE, RMSE, SSE) for all generations of parameter sets  
    A1 = 'Amalgam_Flow_All_ObjFun_All Generations_';
    A2 = bore_ID;
    A3 = catchment;
    A4 = datestr(now,'mm-dd-yyyy HH-MM');
    A5 = '.csv';
    formatSpec = '%1$s %2$s %3$s %4$s %5$s';
    Filename = sprintf(formatSpec,A1,A2,A3,A4,A5);
    folder = 'C:\Users\gbonotto\OneDrive - The University of Melbourne\1 - UNIMELB\5 - HydroSight\10 - Run Results';
    path =fullfile(folder, Filename);
    csvwrite(path,allOriginalObjVals_Flow)
    
         
    %Storing the Pareto front matrix for the last generation of parameters
    A1 = 'Amalgam_Pareto_ObjFun_Final_Generation';
    A2 = bore_ID;
    A3 = catchment;
    A4 = datestr(now,'mm-dd-yyyy HH-MM');
    A5 = '.csv';
    formatSpec = '%1$s %2$s %3$s %4$s %5$s';
    Filename = sprintf(formatSpec,A1,A2,A3,A4,A5);
    folder = 'C:\Users\gbonotto\OneDrive - The University of Melbourne\1 - UNIMELB\5 - HydroSight\10 - Run Results';
    path =fullfile(folder, Filename);
    csvwrite(path,ObjVals)
    
    % Plot the Pareto Front of the last generation
    figure(1)
%     figure(2)
    scatter( ObjVals(:,1), ObjVals(:,2))
    title({['Pareto Front - GW head vs. Streamflow Obj-Functions' ] 
                        [bore_ID ' - ' catchment ]});
    xlabel('SWSI (GW head)')
    % SWSI = sum of weighted squared innovations
%     xlabel('(1-NSE) (Flow)')
    ylabel('(1-KGE) (Flow)')
    grid on
    ax = gca;
    ax.FontSize = 13;
    
    % Save the Pareto Front of the last generation
    f = figure(1);
%     f = figure(2);
    set(f, 'Color', 'w');
    A1 = 'Pareto Front_Final Generation_';
    A3 = bore_ID;
    A4 = catchment;
    A5 = 'Weighting';
    weighting_forces = unique(modelOptions_7params(:,1));
    A6= weighting_forces(1);
    A6 = cell2mat(A6);
    A7 = datestr(now,'mm-dd-yyyy HH-MM');
    formatSpec = '%1$s %2$s %3$s %4$s %5$s %6$s';
    Filename = sprintf(formatSpec,A1,A3,A4,A5,A6,A7);
%     A7 = weighting_forces(2);
%     A7 = cell2mat(A7);
%     A8 = datestr(now,'mm-dd-yyyy HH-MM');
%     formatSpec = '%1$s %2$s %3$s %4$s %5$s %6$s %7$s';
%     Filename = sprintf(formatSpec,A1,A3,A4,A5,A6,A7,A8);    
    folder = 'C:\Users\gbonotto\OneDrive - The University of Melbourne\1 - UNIMELB\5 - HydroSight\10 - Run Results';
    saveas(f, fullfile(folder, Filename), 'png');
    
    
    
    
    figure(2)
%     figure(3)
    Iter = AMALGAMPar.N;
    scatter( ParSet(1:Iter,end-1), ParSet(1:Iter,end))
        
    while (Iter < AMALGAMPar.ndraw)
    scatter( ParSet(Iter+1:Iter+AMALGAMPar.N,end-1), ParSet(Iter+1:Iter+AMALGAMPar.N,end))
    hold on
    Iter =Iter+AMALGAMPar.N;
    end
    
    title({['Evolution of the Pareto Fronts - GW head vs. Streamflow Obj-Function' ] 
                        [bore_ID ' - ' catchment ]});
    xlabel('SWSI (GW head)')
    xlabel('SWSI (GW head)')
    % SWSI = sum of weighted squared innovations
%     xlabel('(1-NSE) (Flow)')
    ylabel('(1-KGE) (Flow)')
    ylim([.3 1])
    xlim([0 10])
    grid on
    ax = gca;
    ax.FontSize = 13;
    hold off
    
    % Save the Pareto Front of the last generation
    f = figure(2);
%     f = figure(3);
    set(f, 'Color', 'w');
    f.Units = 'inches';
    f.OuterPosition = [.5 .5 8 8]; % adjusting the size of the figure
    set(f, 'Color', 'w');
    A1 = 'Evolution of Pareto Fronts_';
    A3 = bore_ID;
    A4 = catchment;
    A5 = 'Weighting';
    weighting_forces = unique(modelOptions_7params(:,1));
    A6= weighting_forces(1);
    A6 = cell2mat(A6);
    A7 = datestr(now,'mm-dd-yyyy HH-MM');
    formatSpec = '%1$s %2$s %3$s %4$s %5$s %6$s';
    Filename = sprintf(formatSpec,A1,A3,A4,A5,A6,A7);
%     A7 = weighting_forces(2);
%     A7 = cell2mat(A7);
%     A8 = datestr(now,'mm-dd-yyyy HH-MM');
%     formatSpec = '%1$s %2$s %3$s %4$s %5$s %6$s %7$s';
%     Filename = sprintf(formatSpec,A1,A3,A4,A5,A6,A7,A8);    
    folder = 'C:\Users\gbonotto\OneDrive - The University of Melbourne\1 - UNIMELB\5 - HydroSight\10 - Run Results';
    saveas(f, fullfile(folder, Filename), 'png');
    
    
    
    
    
    %%%%% Analysing some parameter sets along the pre-calculated Pareto
    %%%%% Front to analyse model sensitivity and performance
    
%        % bore WRK931624 - precip only
          % point 1
%         Params_ParetoPoints = [2.5916, 1.699, 3.1663, 0.76482, -1.3454, -3.0466, -0.41238, -2.027, 37.317, 2.2904]'; % Alpha = zero, NSE, 890k iterations, 14/Jun/2021  
%         Params_ParetoPoints = [2.5683, 1.699, 3.1663,	0.67665, -1.1342, -3.0921, -0.45796, -1.9979, 209.7, 836.68]' % Alpha = 1, NSE, 300k iterations, 17/Jun/2021       
%         Params_ParetoPoints = [2.5171, 1.699,	3.1656,	0.048855, 0.77607, -1.4026, -2.8757, -0.34583, -2.0055, 391.13, 96.234]' % Alpha = calibrated, NSE, 300k iterations, 18/Jun/2021       
%         Params_ParetoPoints = [2.5988, 1.699, 3.1662, 0.075225, 0.75174, -1.3121, -3.0728, -0.42817, -2.027, 553.63, 164.89]' % Alpha = calibrated, RMSE, 300k iterations, 21/Jun/2021       

%         % point 2
%         Params_ParetoPoints = [1.6992, 1.75, 1.335, 0.78923, -1.4669, -2.535, -0.31971, -2.1195, 36.973, 1.4036]'; % Alpha = zero, NSE, 890k iterations, 14/Jun/2021 
%         Params_ParetoPoints = [1.699,	2.699, 3.1663, 0.63863, -1.325, -2.8724, -0.30827, -1.71, 892.39, 831.05]' %  Alpha = 1, NSE, 300k iterations, 17/Jun/2021                
%         Params_ParetoPoints = [1.699,	1.9516,	1.3375,	0.064356, 0.85547, -1.5002, -2.5998, -0.23659, -2.185, 357.2, 236.39]' % Alpha = calibrated, NSE, 300k iterations, 18/Jun/2021              
%         Params_ParetoPoints = [1.7019, 1.9448, 1.3345, 0.1121, 0.53938, -1.4862, -2.8445, -0.23923, -1.8488, 849.92, 277.39]' % Alpha = calibrated, RMSE, 300k iterations, 21/Jun/2021             

% 
%         % point 3
%         Params_ParetoPoints = [1.6991, 1.699, 3.1662, 0.61752, -1.6414, -3.0587, -0.5182, -2.0636, 37.232, 9.353]'; % Alpha = zero, NSE, 890k iterations, 14/Jun/2021 
%         Params_ParetoPoints = [1.699,	2.699, 1.5087, 0, -1.3699, -2.7822, -0.31574, -1.8051, 871.26, 970.71]' % Alpha = 1, NSE, 300k iterations, 17/Jun/2021  
%         Params_ParetoPoints = [1.699, 2.428, 1.3345, 0.089784, 1, -1.0041, -3.5064, -1.4233, -2.2622, 909.55, 110.35]' % Alpha = calibrated, NSE, 300k iterations, 18/Jun/2021 
%         Params_ParetoPoints = [1.699, 2.428, 1.3345, 0.089747, 1, -1.0367, -3.4925, -1.1446, -2.2434, 469.51, 177.8]' % Alpha = calibrated, RMSE, 300k iterations, 21/Jun/2021   

%                            SMSC_deep, SMSC, k_sat,   alpha, beta,    A,      b,     n,     alpha,   head_threshold,  head_to_baseflow   
%         
% 
%        [ObjVals_prime, ~, ~, objFn_flow_NSE, objFn_flow_NNSE, objFn_flow_RMSE, objFn_flow_SSE, objFn_flow_bias, ~, ~,~] = objectiveFunction_joint(Params_ParetoPoints, time_points_head, time_points_streamflow, model_7params.model,{}); 
        
  


% %        [params, param_names] = getParameters(model_7params)
% %        [params, param_names] = getParameters(model_object)
% %        setParameters(obj, params, param_names)
%        
% 
%        
%         % Getting the Observed head/flow vs. Simulated head/flow plots 
%         figure(i+1)
%         scatter (model_object.inputData.head(:,2), (h_star(:,2) +  drainage_elevation))
%         title(' Observed Vs. Simulated Head')
%         xlabel('Obs. Head (mAHD)')
%         ylabel('Sim. Head (mAHD)')
%         
%         figure(i+2)
%         plot (model_object.inputData.head(:,1), model_object.inputData.head(:,2))
%         title(' Observed and Simulated Head')
%         xlabel('Date (Numeric Date)')
%         ylabel('Head (mAHD)')
%         hold on
%         plot (h_star(:,1), (h_star(:,2) +  drainage_elevation))
%         legend('Obs. Head','Sim. Head')
%         hold off
%         
%         figure(i+3)
%         scatter (obsFlow(:,2), totalFlow_sim)
%         title(' Observed Vs. Simulated Flow')
%         xlabel('Obs. Flow (mm/day)')
%         ylabel('Sim. Flow (mm/day)')
%         
%         figure(i+4)
%         plot (obsFlow(:,1), obsFlow(:,2))
%         title(' Observed and Simulated Flow')
%         xlabel('Date (Numeric Date)')
%         ylabel('Flow (mm/day)')
%         hold on
%         plot (obsFlow(:,1), totalFlow_sim)
%         legend('Obs. Flow','Sim. Flow')
%         hold off
            
     
    
    
    
    
    % For the last generation, Plot the Pareto front displaying 3 Flow Obj-Funs and 1 Head Obj-Fun, where only the 1st Flow Obj-Fun was
    % optimized in the AMALGAM algorithm. 
    
    % allOriginalObjVals_Flow(1:AMALGAMPar.ndraw,ObjFuns): [1] (NSE), [2](NNSE), [3] RMSE, [4] SSE, [5] Bias , [6] KGE
    Final_ParSet_FlowObjFunctionVals = allOriginalObjVals_Flow((AMALGAMPar.ndraw-AMALGAMPar.N)+1:AMALGAMPar.ndraw,:);
    
    % trying to use plotyyy
%     All_Pareto_Fronts_lines = plotyyy(ObjVals(:,1), 1-Final_ParSet_FlowObjFunctionVals(:,6) , ObjVals(:,1), 1-Final_ParSet_FlowObjFunctionVals(:,1), ObjVals(:,1), abs(Final_ParSet_FlowObjFunctionVals(:,5)), {'(1-KGE)', '1-NSE', '|Bias|'});
%     All_Pareto_Fronts_scatter = plotyyy_GB(ObjVals(:,1), Final_ParSet_FlowObjFunctionVals(:,6) , ObjVals(:,1), 1-Final_ParSet_FlowObjFunctionVals(:,1), ObjVals(:,1), abs(Final_ParSet_FlowObjFunctionVals(:,5)), {'(1-KGE)', '1-NSE', '|Bias|'}, 'scatter');
    % Checking if the values in ObjVals and Final_ParSet_FlowObjFunctionVals match 
    % values were previously not matching cause of the ranking/mixing that occurs in AMALGAM after calculating the ObjFun with "objectiveFunction_joint"
    check_diff = ObjVals(:,2) - (1-Final_ParSet_FlowObjFunctionVals(:,6))
%     if cumsum(check_diff)~= 0 
%         error('Flow Obj-Function that was used in AMALGAM is different than the one you are plotting as optimized, or there is a NaN')
%     end
    
    % YYY-plot with the Pareto Front of the final generation for the optimized ObjFun and respective ObjFuns   
    x = ObjVals(:,1); 
    y1 = 1-Final_ParSet_FlowObjFunctionVals(:,6); 
    y2 = 1-Final_ParSet_FlowObjFunctionVals(:,1); 
    y3 = abs(Final_ParSet_FlowObjFunctionVals(:,5)); 
    ylabels = {'(1-KGE)', '(1-NSE)', '|BIAS|'};
    
    % Scatter Plot on the left and right y axes
    figure(3)
%     figure(4)
    ax1 = axes; 
    yyaxis left                 % see [1]
    scatter(x,y1)
    pause(0.1)                  % see [3]
    set(get(ax1(1),'ylabel'),'string',ylabels{1})
    f = figure(3);
    set(f, 'Color', 'w');
    f.Units = 'inches';
    f.OuterPosition = [.5 .5 14 10]; % adjusting the size of the figure
  
    % set the y(left) and x tick values, make them permanent 
    % This is the tricky part and shoudl receive a lot of thought when 
    % you adapt this to your code...
    ax1.XTickMode = 'manual'; 
    ax1.YTickMode = 'manual'; 
    ax1.YLim = [min(ax1.YTick), max(ax1.YTick)];  % see [4]
    ax1.XLimMode = 'manual'; 
    grid(ax1,'on')
    ytick = ax1.YTick;  
    yyaxis right                % see [1]
    scatter(x,y2)
    set(get(ax1(1),'ylabel'),'string',ylabels{2}) % set the axis label

    % create 2nd, transparent axes
    ax2 = axes('position', ax1.Position);
    scatter(ax2,x,y3, 'k')
    pause(0.1)                 % see [3]
    ax2.Color = 'none'; 
    grid(ax2, 'on')
    % Horizontally scale the y axis to alight the grid (again, be careful!)
    ax2.XLim = ax1.XLim; 
    ax2.XTick = ax1.XTick; 
    ax2.YLimMode = 'manual'; 
    yl = ax2.YLim; 
    ax2.YTick = linspace(yl(1), yl(2), length(ytick));      % see [2]
    set(get(ax2(1),'ylabel'),'string',ylabels{3}) % set the axis label
    % horzontally offset y tick labels
    ax2.YTickLabel = strcat(ax2.YTickLabel, {'                        '});
    title({['Pareto Front - GW head vs. Streamflow Obj-Functions' ] 
            ['Optimized for ' ylabels{1} ', respective ' ylabels{2} ', ' ylabels{3}]
            [bore_ID ' - ' catchment ]});
    xlabel(' Head Objective Function (SWSI)')
      hold off
        
    % [1] https://www.mathworks.com/help/matlab/ref/yyaxis.html
    % [2] this is the critical step to align the grids. It assumes both 
    %       axes contain ticks at the start and end of the y axis
    % [3] For some reason when I step through the code, the plots appear
    %       as they should but when I run the code at it's natural speed
    %       there are graphics issues.  It's as if code execution is 
    %       ahead of the graphics which is annoying.  A brief pause 
    %       fixes this (r2019a)
    % [4] Scaling is easier if the ticks begin and end at the axis limits

    
    % Save the YYY-plot with the Pareto Front of the final generation for the optimized ObjFun and respective ObjFuns 
    f = figure(3);
%     f = figure(4);
        A1 = 'YYY plot_Pareto Front_Final Generation_';
    A3 = bore_ID;
    A4 = catchment;
    A5 = 'Weighting';
    weighting_forces = unique(modelOptions_7params(:,1));
    A6= weighting_forces(1);
    A6 = cell2mat(A6);
    A7 = datestr(now,'mm-dd-yyyy HH-MM');
    formatSpec = '%1$s %2$s %3$s %4$s %5$s %6$s';
    Filename = sprintf(formatSpec,A1,A3,A4,A5,A6,A7);
%     A7 = weighting_forces(2);
%     A7 = cell2mat(A7);
%     A8 = datestr(now,'mm-dd-yyyy HH-MM');
%     formatSpec = '%1$s %2$s %3$s %4$s %5$s %6$s %7$s';
%     Filename = sprintf(formatSpec,A1,A3,A4,A5,A6,A7,A8);  
    folder = 'C:\Users\gbonotto\OneDrive - The University of Melbourne\1 - UNIMELB\5 - HydroSight\10 - Run Results';
    saveas(f, fullfile(folder, Filename), 'png');
    
    
    
        
    % Scatter plot with the Pareto Front of the final generation for the optimized ObjFun and respective ObjFuns 
    figure(4)
%     figure(5)
    scatter(x,y1)
    xlabel(' Head Objective Function (SWSI)')
    % SWSI = sum of weighted squared innovations
    ylabel('Flow Objective Function')
    hold on
    scatter(x,y2)
    scatter(x,y3)
    legend('(1-KGE)', '(1-NSE)', '|BIAS|')
    title({['Pareto Front - GW head vs. Streamflow Obj-Functions' ]
        ['Optimized for ' ylabels{1} ', respective ' ylabels{2} ', ' ylabels{3}]
        [bore_ID ' - ' catchment ]});
    ax = gca;
    ax.FontSize = 13;
    hold off
    
    
    % Save the Scatter plot with the Pareto Front of the final generation for the optimized ObjFun and respective ObjFuns 
    f = figure(4);
%     f = figure(5);
    set(f, 'Color', 'w');
%     f.Units = 'inches';
%     f.OuterPosition = [.5 .5 15 10]; % adjusting the size of the figure
    A1 = 'YYY Scatter_Pareto Front_Final Generation_';
    A3 = bore_ID;
    A4 = catchment;
    A5 = 'Weighting';
    weighting_forces = unique(modelOptions_7params(:,1));
    A6= weighting_forces(1);
    A6 = cell2mat(A6);
    A7 = datestr(now,'mm-dd-yyyy HH-MM');
    formatSpec = '%1$s %2$s %3$s %4$s %5$s %6$s';
    Filename = sprintf(formatSpec,A1,A3,A4,A5,A6,A7);
%     A7 = weighting_forces(2);
%     A7 = cell2mat(A7);
%     A8 = datestr(now,'mm-dd-yyyy HH-MM');
%     formatSpec = '%1$s %2$s %3$s %4$s %5$s %6$s %7$s';
%     Filename = sprintf(formatSpec,A1,A3,A4,A5,A6,A7,A8);    
    folder = 'C:\Users\gbonotto\OneDrive - The University of Melbourne\1 - UNIMELB\5 - HydroSight\10 - Run Results';
    saveas(f, fullfile(folder, Filename), 'png');

    


    
    
% ---------------------------------------------------------------------------------------------------%
% HydroSight built-in calibration scheme only for GW head 
    
    % Set the number of SP-UCI calibration clusters per parameter
    SchemeSetting.ngs = 7;    
    
    % Calibrate the 7 parameter model.
    calibrateModel(model_7params_gw, [], 0, inf, 'SP-UCI', SchemeSetting);
    
    % Plot the calibration results.    
    calibrateModelPlotResults(model_7params_gw,[]);
    
    % Store the figure showing results when calibrated GW only
    f = figure(i+3);
%     f = figure(i+2);
    set(f, 'Color', 'w');
    f.Units = 'inches';
    f.OuterPosition = [.5 .5 13 10];
    A1 = 'Calibration_Diagnostic_Plots_Calib_only_GW';
    A2 = bore_ID; 
    A3 = datestr(now,'mm-dd-yyyy HH-MM');
    formatSpec = '%1$s %2$s %3$s';
    Filename = sprintf(formatSpec,A1,A2,A3);
    folder = 'C:\Users\gbonotto\OneDrive - The University of Melbourne\1 - UNIMELB\5 - HydroSight\10 - Run Results';
    saveas(f, fullfile(folder, Filename), 'png'); 
    
    
    %Storing the model object "model_7params_gw" to show the performance metrics the model only calibrated to GW
    A1 = 'Configuration_&_Performance_model_TFN_';
    A2 = bore_ID;
    A3 = catchment;
    A4 = datestr(now,'mm-dd-yyyy HH-MM');
    A5 = '.mat';
    formatSpec = '%1$s %2$s %3$s %4$s %5$s';
    Filename = sprintf(formatSpec,A1,A2,A3,A4,A5);
    folder = 'C:\Users\gbonotto\OneDrive - The University of Melbourne\1 - UNIMELB\5 - HydroSight\10 - Run Results';
    path =fullfile(folder, Filename);
    save(path,'model_7params_gw')  % Save model object 

    
    % Plot the simulation results. ----------This guy is not working.....
%     time_points = model_7params_gw.model.variables.time_points;
%     newForcingData = [];
%     simulationLabel = 'default simulation';
%     doKrigingOnResiduals = false;    
%     solveModel(model_7params, time_points, newForcingData, simulationLabel, doKrigingOnResiduals);    
%     solveModelPlotResults(model_7params, simulationLabel, []);    

    clear all % clear all variables to avoid inheriting parameters from the previous run 

    % Restating the List of bores in the study area to keep the loop going
    list_bores = {'bore_WRK961324', 'bore_141234','bore_141243' ,'bore_WRK961325' , 'bore_WRK961326'} ; %  ----- Brucknell
    % list_bores = {'bore_141234','bore_141243' ,'bore_WRK961325' , 'bore_WRK961326'} ; %  ----- Brucknell
    % list_bores = {'bore_118946', 'bore_118947'} ; %  ----------------------------------------------------------- Ford
    % list_bores = {'bore_2091', 'bore_WRK958154', 'bore_WRK958156', 'bore_WRK958155', 'bore_2092'} ; %  --------- Sunday
    
    toc % stop timer
end

clear all; % to avoid errors in the new loop

