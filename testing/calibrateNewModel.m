classdef calibrateNewModel < loadExampleModels

    properties (ClassSetupParameter)
        iExampleModel = {4};
        calibrationMethodSettings = { ...
                                        struct('method','CMA-ES','CalibEndDate','31-Dec-2010','MaxFunEvals','2000','popsize','2','Sigma','0.05','iseed','1234', ...
                                               'parameterPerturbationMultiplier', 1.01, 'objFuncSolutionReTol', 1.01, 'parameterSolutionReTol', 0.005), ...
                                        struct('method','SP-UCI','CalibEndDate','31-Dec-2010','maxn','2000','ngs','2','kstop','5', 'iseed','1234', ...
                                               'parameterPerturbationMultiplier', 1, 'objFuncSolutionReTol', 1.01, 'parameterSolutionReTol', 0.005), ...
                                        struct('method','DREAM', 'CalibEndDate','31-Dec-2010','prior','normal','sigma','0.01', 'T','2000','Tmin','100','N','1.2','iseed','1234', ...
                                                'parameterPerturbationMultiplier', 1.05,'objFuncSolutionReTol', 0.975, 'parameterSolutionReTol', 0.1), ...
                                     };
    end
    properties
        ParameterNames;
        expectedParameterValues;        
        expectedObjFunc;
    end
    properties(Constant=true)
        modelName = 'Test_nonlinear_TFNmodel';
    end

    methods(TestClassSetup)
        function getCalibrationExpectedSolution(testCase,calibrationMethodSettings)
            % Give user update on test being run.
            disp('TESTING: Getting prior calibration solution for example model...');

            % call callback for new project
            GUI = getSharedTestFixtures(testCase,'loadHydroSightFixture').GUI;
            
            % Get simple model object and test that it is a HydroSight model.
            obj = GUI.models.Control_Catchment_1Layer_no_GW_ET;
            testCase.assertClass(obj,'HydroSightModel');

            % Get model parameters.
            [testCase.expectedParameterValues,testCase.ParameterNames]=getParameters(obj.model);
            if strcmp(calibrationMethodSettings.method,'DREAM')
                % Get likelihood form of solution from example calibration
                getLikelihood = true;
                doParamTranspose = false;
                [~, time_points] = calibration_initialise(obj.model, obj.model.variables.t_start, obj.model.variables.t_end);
                testCase.expectedObjFunc = calibrationObjectiveFunction(testCase.expectedParameterValues, obj, time_points, doParamTranspose, getLikelihood);
            else
                % Get solution from example calibration 
                testCase.expectedObjFunc = obj.calibrationResults.performance.objectiveFunction;
            end
        end

        function deleteModels(testCase)       
            % Give user update on test being run.
            disp('TESTING: Deleting all example models ...');
            
            GUI = getSharedTestFixtures(testCase,'loadHydroSightFixture').GUI;
            
            % Select all models
            obj = findobj(GUI.Figure.UIContextMenu,'Label','Select all');
            eventdata.Source.Parent.UserData = 'this.tab_ModelConstruction.Table';
            hObject.Label = 'Select all';
            feval(obj.MenuSelectedFcn, hObject, eventdata);

            % Delete all models
            obj = findobj(GUI.Figure.UIContextMenu,'Label','Delete selected rows');
            hObject.Label = 'Delete selected rows';
            feval(obj.MenuSelectedFcn, hObject, eventdata);

            % Check tables are empty
            actSolution = size(GUI.tab_DataPrep.Table.Data,1) + size(GUI.tab_ModelConstruction.Table.Data,1) ...
                + size(GUI.tab_ModelCalibration.Table.Data,1) + size(GUI.tab_ModelSimulation.Table.Data,1);
            expSolution = 0;
            testCase.assertEqual(actSolution, expSolution, 'GUI tables not empty.');
        end

        function buildModel(testCase)
            % Give user update on test being run.
            disp('TESTING: Inputting model construction options and building model ...');

            GUI = getSharedTestFixtures(testCase,'loadHydroSightFixture').GUI;

            % Show build model tab
            GUI.figure_Layout.SelectedChild = 3;            

            % Insert new row
            obj = findobj(GUI.Figure.UIContextMenu,'Label','Insert row below selection');
            hObject.Label = 'Insert row below selection';
            eventdata.Source.Parent.UserData = 'this.tab_ModelConstruction.Table';
            feval(obj.MenuSelectedFcn, hObject, eventdata);
            testCase.irow = 1;

            % Select row 
            GUI.tab_ModelConstruction.Table.Data{testCase.irow,1}= true;

            % Input model Name
            GUI.tab_ModelConstruction.Table.Data{testCase.irow,2}= testCase.modelName;

            % Input obs data files
            GUI.tab_ModelConstruction.Table.Data{testCase.irow,3}= 'obsHead.csv';
            GUI.tab_ModelConstruction.Table.Data{testCase.irow,4}= 'forcing.csv';
            GUI.tab_ModelConstruction.Table.Data{testCase.irow,5}= 'coordinates.csv';

            % Show hydrographs.
            icol = 6;
            eventdata.Indices = [testCase.irow,icol];
            eventdata.Source = GUI.tab_ModelConstruction.Table;
            feval(GUI.tab_ModelConstruction.Table.CellSelectionCallback, GUI.tab_ModelConstruction.Table, eventdata);

            % Select bore ID
            obj = GUI.tab_ModelConstruction.boreIDList;
            ind = find(strcmp(obj.String, 'Bore_6416'));
            obj.Value = ind;

            % Update hydrograph for selected bore.
            modelConstruction_onBoreListSelection(GUI, GUI.tab_ModelConstruction.boreIDList, []);    

            % Push selected bore to model.
            obj=findobj(GUI.tab_ModelConstruction.modelOptions.vbox,'TooltipString','Copy the Site IDs to current model.');
            feval(obj.Callback, obj, []);

            % Input min head freq
            GUI.tab_ModelConstruction.Table.Data{testCase.irow,7}= 7;

            % Input model type
            newModelType = 'model_TFN';
            GUI.tab_ModelConstruction.Table.Data{testCase.irow,8}= newModelType;

            % Check model type summary can be shown.
            icol = 8;
            eventdata.Indices = [testCase.irow,icol];
            eventdata.Source = GUI.tab_ModelConstruction.Table;
            feval(GUI.tab_ModelConstruction.Table.CellSelectionCallback, GUI.tab_ModelConstruction.Table, eventdata);

            % Show model_TFN options window
            icol = 9;
            eventdata.Indices = [testCase.irow,icol];
            eventdata.Source = GUI.tab_ModelConstruction.Table;
            feval(GUI.tab_ModelConstruction.Table.CellSelectionCallback, GUI.tab_ModelConstruction.Table, eventdata);

            % Input model forcing transform details
            obj = GUI.tab_ModelConstruction.modelTypes.(newModelType).obj;
            obj.forcingTranforms.tbl.Data{1,2} = 'climateTransform_soilMoistureModels';

            % Show forcing data inputs panel
            icol = 3;
            eventdata.Indices = [1,icol];
            eventdata.Source = obj.forcingTranforms.tbl;
            feval(obj.forcingTranforms.tbl.CellSelectionCallback, obj.forcingTranforms.tbl, eventdata);

            % Input forcing data inputs                        
            obj.modelOptions.options{1,1}.tbl.Data = { 'precip', 'Rain_mm' ; 'et', 'FAO56_PET_mm' ; 'TreeFraction', '(none)' ;};
            eventdata.Source = obj.modelOptions.options{1,1}.tbl;
            feval(obj.modelOptions.options{1,1}.tbl.CellEditCallback, obj.modelOptions.options{1,1}.tbl,eventdata);

            % Show forcing data parameters panel
            icol = 4;
            eventdata.Indices = [1,icol];
            eventdata.Source = obj.forcingTranforms.tbl;
            feval(obj.forcingTranforms.tbl.CellSelectionCallback, obj.forcingTranforms.tbl, eventdata);
            
            % Edit soil model parameters
            obj.modelOptions.options{2,1}.tbl.Data = {  'SMSC', 2, 'Calib.'; ...
                                                        'SMSC_trees', 2, 'Fixed'; ...
                                                        'treeArea_frac', 0.5000, 'Fixed'; ...
                                                        'S_initialfrac', 1.0000, 'Fixed'; ...
                                                        'k_infilt', Inf, 'Fixed'; ...
                                                        'k_sat', 1, 'Calib.'; ...
                                                        'bypass_frac', 0, 'Fixed'; ...
                                                        'interflow_frac', 0, 'Fixed'; ...
                                                        'alpha', 1, 'Fixed'; ...
                                                        'beta', 0.5000, 'Calib.'; ...
                                                        'gamma', 0, 'Fixed'; ...
                                                        'eps', 0, 'Fixed'};

            % Push soil parames to forcing transform table
            eventdata.Source = obj.modelOptions.options{2,1}.tbl;
            feval(obj.modelOptions.options{2,1}.tbl.CellEditCallback, obj.modelOptions.options{2,1}.tbl,eventdata);

            % Input weighting function component name and weighting
            % function
            obj.weightingFunctions.tbl.Data{1,2} = 'Recharge';
            obj.weightingFunctions.tbl.Data{1,3} = 'responseFunction_Pearsons';

            % Show input selection list
            icol = 4;
            eventdata.Indices = [1,icol];
            eventdata.Source = obj.weightingFunctions.tbl;
            feval(obj.weightingFunctions.tbl.CellSelectionCallback, obj.weightingFunctions.tbl, eventdata);
            ind  = find(strcmp(obj.modelOptions.options{3,1}.lst.String,'climateTransform_soilMoistureModels : drainage'),1);
            obj.modelOptions.options{3,1}.lst.Value = ind;
            eventdata.Source = obj.modelOptions.options{3,1}.lst;
            feval(obj.modelOptions.options{3,1}.lst.Callback, obj.modelOptions.options{3,1}.lst,eventdata);

            % Push model options to model
            obj = findobj(GUI.tab_ModelConstruction.modelTypes.(newModelType).buttons, 'TooltipString','Copy model options to current model.');
            feval(obj.Callback, [],[]);

            % Build model
            GUI.tab_ModelConstruction.Table.Data(:,10) = {'<html><font color = "#FF0000">Not built.</font></html>'};
            onBuildModels(GUI, [],[]);

            % close msgbox
            h = findall(0,'Tag','Model construction msgbox summary');
            if ishandle(h)
                close(h);
            end

            % Check analysis was successful.
            testCase.assertSubstring(GUI.tab_ModelConstruction.Table.Data{testCase.irow,10}, ...
                '<html><font color = "#008000">Model built.</font></html>', 'Error: Model unsuccessfully built.');            

            % Check parameter names are the same as the exmple model
            [~,ParameterNamesInitial]=getParameters(GUI.models.(testCase.modelName).model);
            testCase.assertEqual(ParameterNamesInitial, testCase.ParameterNames, 'Incorrect parameter names for calibration testing.');
        end

        function setInitialParameterValues(testCase, calibrationMethodSettings)
            % Give user update on test being run.
            disp('TESTING: Setting initial parameters for model calibration ...');

            % Get model object already built
            GUI = getSharedTestFixtures(testCase,'loadHydroSightFixture').GUI;
            obj = GUI.models.(testCase.modelName);

            % Perturb parameters from known initial soluttion
            initialParameterValues = testCase.expectedParameterValues * calibrationMethodSettings.parameterPerturbationMultiplier;

            % Set initial parameters such that they are close to the
            % solution.
            setParameters(obj.model, initialParameterValues, testCase.ParameterNames);
        end
        function saveModel(testCase)
            % Give user update on test being run.
            disp('TESTING: Saving project ...');
            currentfolder = pwd();
            GUI = getSharedTestFixtures(testCase,'loadHydroSightFixture').GUI;
            testCase.fname = 'simpleModelTesting.mat';
            actSolution = onSaveAs(GUI,[],[], testCase.fname, [testCase.pname,filesep()]);
            expSolution = 0;
            testCase.assertEqual(actSolution, expSolution, 'Model could not be saved.')
            cd(currentfolder);
        end          

        function calibrateModel(testCase,  calibrationMethodSettings)            
            % Give user update on test being run.
            disp(['TESTING: Calibrating the built model using ',calibrationMethodSettings.method,' ...']);

            GUI = getSharedTestFixtures(testCase,'loadHydroSightFixture').GUI;

            % Show calib tab
            GUI.figure_Layout.SelectedChild = 4;
            
            % Get contect menu obj for 'Select none'
            obj = findobj(GUI.Figure.UIContextMenu,'Label','Select none');
            eventdata.Source.Parent.UserData = 'this.tab_ModelCalibration.Table';
            hObject.Label = 'Select none';
            feval(obj.MenuSelectedFcn, hObject, eventdata);

            % Select model to calibrate
            icol = 1;
            GUI.tab_ModelCalibration.Table.Data{testCase.irow,icol}= true;

            % Set calibration end date - to test split sampling
            GUI.tab_ModelCalibration.Table.Data{testCase.irow,7} = calibrationMethodSettings.CalibEndDate;

            % Set calibration end period
            GUI.tab_ModelCalibration.Table.Data{testCase.irow,7} = '31-Dec-2009';

            % Setup calibration scheme in GUI table
            GUI.tab_ModelCalibration.Table.Data{testCase.irow,8} = calibrationMethodSettings.method;
            GUI.tab_ModelCalibration.Table.Data{testCase.irow,9} = '<html><font color = "#FF0000">Not calibrated.</font></html>';
            GUI.tab_ModelCalibration.Table.Data{testCase.irow,10} = '(NA)';
            GUI.tab_ModelCalibration.Table.Data{testCase.irow,11} = '(NA)';
            GUI.tab_ModelCalibration.Table.Data{testCase.irow,12} = '(NA)';

            % Open calibration GUI
            onCalibModels(GUI, [],[]);
            set(GUI.tab_ModelCalibration.GUI,'WindowStyle','normal');
            
            % Set calib settings
            switch calibrationMethodSettings.method
                case 'CMA-ES'
                    obj = findobj(GUI.tab_ModelCalibration.GUI, 'Tag','CMAES MaxFunEvals');
                    obj.String = calibrationMethodSettings.MaxFunEvals;
                    obj = findobj(GUI.tab_ModelCalibration.GUI, 'Tag','CMAES popsize');
                    obj.String = calibrationMethodSettings.popsize;
                    obj = findobj(GUI.tab_ModelCalibration.GUI, 'Tag','CMAES Sigma');
                    obj.String = calibrationMethodSettings.Sigma;                    
                    obj = findobj(GUI.tab_ModelCalibration.GUI, 'Tag','CMAES iseed');
                    obj.String = calibrationMethodSettings.iseed;
                case 'SP-UCI'
                    obj = findobj(GUI.tab_ModelCalibration.GUI, 'Tag','SP-UCI maxn');
                    obj.String = calibrationMethodSettings.maxn;
                    obj = findobj(GUI.tab_ModelCalibration.GUI, 'Tag','SP-UCI ngs');
                    obj.String = calibrationMethodSettings.ngs;
                    obj = findobj(GUI.tab_ModelCalibration.GUI, 'Tag','SP-UCI kstop');
                    obj.String = calibrationMethodSettings.kstop;                    
                    obj = findobj(GUI.tab_ModelCalibration.GUI, 'Tag','SP-UCI iseed');
                    obj.String = calibrationMethodSettings.iseed;
                case 'DREAM'
                    obj = findobj(GUI.tab_ModelCalibration.GUI, 'Tag','DREAM prior');
                    obj.Value = find(strcmp(obj.String,calibrationMethodSettings.prior));
                    obj = findobj(GUI.tab_ModelCalibration.GUI, 'Tag','DREAM sigma');
                    obj.String = calibrationMethodSettings.sigma;
                    obj = findobj(GUI.tab_ModelCalibration.GUI, 'Tag','DREAM Tmin');
                    obj.String = calibrationMethodSettings.Tmin;
                    obj = findobj(GUI.tab_ModelCalibration.GUI, 'Tag','DREAM T');
                    obj.String = calibrationMethodSettings.T;
                    obj = findobj(GUI.tab_ModelCalibration.GUI, 'Tag','DREAM N');
                    obj.String = calibrationMethodSettings.N; 
                    obj = findobj(GUI.tab_ModelCalibration.GUI, 'Tag','DREAM iseed');
                    obj.String = calibrationMethodSettings.iseed;                    
            end

            % Supress dialog warning messages
            warningStateChanged = false;
            warningState = warning('query','MATLAB:hg:NoDisplayNoFigureSupportSeeReleaseNotes');
            if ~usejava('desktop') && strcmp(warningState.state,'on')
                warning('off','MATLAB:hg:NoDisplayNoFigureSupportSeeReleaseNotes')
                warningStateChanged = true;
            end

            % Start Calib.
            obj = findobj(GUI.tab_ModelCalibration.GUI,'Tag','Start calibration');
            hobject.Tag = 'Start calibration - noparpool'; % 'noparpool' ensures parpool not started.
             feval(get(obj,'Callback'), hobject, []);

            % Close calibration summary msgbox
            h = findall(0,'Tag','Model calibration msgbox summary');
            if ishandle(h)
                close(h);
            end

            % Close Calib GUI
            feval(get(GUI.tab_ModelCalibration.GUI,'CloseRequestFcn'), GUI.tab_ModelCalibration.GUI);

            % Get calibrated object and check 'isCalibrated' flag
            obj = GUI.models.(testCase.modelName);
            actSolution = obj.calibrationResults.isCalibrated;
            testCase.assertTrue(actSolution, 'Model calibration failed. isCalibrated==false');            

            % Get objective function solution and test.
            if strcmp(calibrationMethodSettings.method,'DREAM')
                testCase.verifyGreaterThanOrEqual(obj.calibrationResults.performance.objectiveFunction(1), testCase.expectedObjFunc * calibrationMethodSettings.objFuncSolutionReTol, ...
                    ['Model calibration objective function overly differs from expected solution. Method used:',calibrationMethodSettings.method]);
            else
                testCase.verifyLessThanOrEqual(obj.calibrationResults.performance.objectiveFunction(1), testCase.expectedObjFunc * calibrationMethodSettings.objFuncSolutionReTol, ...
                    ['Model calibration objective function overly differs from expected solution. Method used:',calibrationMethodSettings.method]);
            end
            % Get solution and test.
            actParameterValues = getParameters(obj.model);
            testCase.verifyEqual(actParameterValues(:,1), testCase.expectedParameterValues, ...
                ['Model calibration parameters overly differ from expected solution. Method used:',calibrationMethodSettings.method],'RelTol',calibrationMethodSettings.parameterSolutionReTol);

            % Restore dialog warning messages
            if warningStateChanged
                warning('on','MATLAB:hg:NoDisplayNoFigureSupportSeeReleaseNotes')
            end
            
        end
    end

    methods(Test)
        function showCalibResults(testCase)
            % Give user update on test being run.
            disp('TESTING: Showing the calibration status results ...');

            % Get handle to GUI.
            GUI = getSharedTestFixtures(testCase,'loadHydroSightFixture').GUI;

            % Show calib forcing results tab
            GUI.figure_Layout.SelectedChild = 4;
            GUI.tab_ModelCalibration.resultsTabs.SelectedChild = 1;
            
            try
                expSolution=0;

                % Build event object.
                obj = GUI.tab_ModelCalibration.Table;

                % Show model status.
                icol = 9;
                eventdata.Indices = [testCase.irow,icol];
                eventdata.Source = obj;
                feval(obj.CellSelectionCallback, obj, eventdata);

                % Successful if no error thrown.
                actSolution = 0;
                msgStr = 'Model calib. status successfully shown.';
            catch ME
                actSolution = -1;
                msgStr = ['Error: Model calib. status failed',ME.message,' at ', ME.stack(1).name, ' on line ',num2str(ME.stack(1).line)];
            end
            testCase.verifyEqual(actSolution,expSolution, msgStr);
        end

        function showCalibResultsHead(testCase)
            % Give user update on test being run.
            disp('TESTING: Showing the calibration results plots ...');
            
            % Get handle to GUI.
            GUI = getSharedTestFixtures(testCase,'loadHydroSightFixture').GUI;

            % Show calib results tab
            GUI.figure_Layout.SelectedChild = 4;
            GUI.tab_ModelCalibration.resultsTabs.SelectedChild = 2;

            % Get calibration results drop down obj
            obj = findobj(GUI.tab_ModelCalibration.resultsOptions.calibPanel, 'Tag','Model Calibration - results plot dropdown');

            % Loop through list of plot types
            for i=1:length(obj.String)
                obj.Value = i;       
                try
                    feval(obj.Callback);
                    hassNoErrors=true;
                catch
                    hassNoErrors = false;
                end
                testCase.verifyEqual(hassNoErrors, true, ['Plotting of the following calib. result failed: ', obj.String{obj.Value}]);               
            end                
        end      
        
        function showCalibResultsForcing(testCase)
            % Give user update on test being run.
            disp('TESTING: Showing the calibration forcing plots ...');

            % Get handle to GUI.
            GUI = getSharedTestFixtures(testCase,'loadHydroSightFixture').GUI;
           
            % Show calib forcing results tab
            GUI.figure_Layout.SelectedChild = 4;
            GUI.tab_ModelCalibration.resultsTabs.SelectedChild = 3;

            % Get calibration forcing results drop down objects
            objTimeStep = findobj(GUI.tab_ModelCalibration.resultsOptions.forcingPanel, 'Tag','Forcing plot calc timestep');
            objTimeStepMetric = findobj(GUI.tab_ModelCalibration.resultsOptions.forcingPanel, 'Tag','Forcing plot calc type');
            objTimeStart = findobj(GUI.tab_ModelCalibration.resultsOptions.forcingPanel, 'Tag','Forcing plot calc start date');            
            objTimeEnd = findobj(GUI.tab_ModelCalibration.resultsOptions.forcingPanel, 'Tag','Forcing plot calc end date');            
            objPlotType = findobj(GUI.tab_ModelCalibration.resultsOptions.forcingPanel, 'Tag','Forcing plot type');
            objPlotXAxisUpper = findobj(GUI.tab_ModelCalibration.resultsOptions.forcingPanel, 'Tag','Forcing plot x-axis');
            objPlotYAxisUpper = findobj(GUI.tab_ModelCalibration.resultsOptions.forcingPanel, 'Tag','Forcing plot y-axis');
            objBuildPlot = findobj(GUI.tab_ModelCalibration.resultsOptions.forcingPanel, 'Tag','Forcing plot build plot');
            
            % Loop through each time step and build eachh type of plot
            for i=1:length(objTimeStep.String)
                % Set start data later than default to reduced the testing
                % time of box plots
                objTimeStart.String = '1/1/2000';
                objTimeEnd.String = '1/1/2002';

                % Update time step
                objTimeStep.Value = i;     

                % Reset plot type ans axis
                objPlotType.Value = 1;
                objPlotXAxisUpper.Value = 2;
                objPlotYAxisUpper.Value = 2; 

                % Update data table
                try
                    feval(objTimeStep.Callback);
                    hassNoErrors=true;
                catch
                    hassNoErrors = false;
                end
                testCase.verifyEqual(hassNoErrors, true, ['Updating calib. forcing data to the following timestep failed: ', objTimeStep.String{objTimeStep.Value}]);               

                if strcmp(objTimeStepMetric.Enable,'off')
                    indCalcMetrics =1;
                else
                    % Find the IDs for the selected metrics to test
                    indCalcMetrics = cellfun(@(x) find(strcmp(objTimeStepMetric.String,x)),{'sum','variance','skew','25th %ile','No. zero days','No. >0 days'},'UniformOutput',false);
                    indCalcMetrics  = cell2mat(indCalcMetrics);
                    %indCalcMetrics  = 1:length(objTimeStepMetric.String);
                end

                for j=indCalcMetrics


                    objTimeStepMetric.Value = j;

                    % Reset plot type ans axis
                    objPlotType.Value = 1;
                    objPlotXAxisUpper.Value = 2;
                    objPlotYAxisUpper.Value = 2;

                    % Update data table for different types of summary
                    % statistics
                    try
                        feval(objTimeStepMetric.Callback);
                        hassNoErrors=true;
                    catch
                        hassNoErrors = false;
                    end
                    testCase.verifyEqual(hassNoErrors, true, ['Updating calib. forcing data using the following statistic failed: ', objTimeStepMetric.String{objTimeStepMetric.Value}]);

                    % Loop through each plot type
                    for k=1:length(objPlotType.String)
                        objPlotType.Value = k;
                    
                        % Loop through each forcing variable and finally do
                        % the plotting
                        if length(objPlotYAxisUpper.String)>2
                            if i==1 % daily data
                                indVariable = 3:length(objPlotYAxisUpper.String);
                            else
                                indVariable = find(strcmp(objPlotYAxisUpper.String,'drainage'));
                            end
                            for el=indVariable                               
                                switch objPlotType.String{k}
                                    case {'line','scatter','bar'}
                                        objPlotXAxisUpper.Value = 2; % date x axis
                                        objPlotYAxisUpper.Value = el; % date x axis
                                    case {'box-plot (daily metric)', 'box-plot (monthly metric)','box-plot (quarterly metric)','box-plot (annually metric)'}
                                        objPlotXAxisUpper.Value = 2; % date x axis
                                        objPlotYAxisUpper.Value = el; % date x axis
                                        if strcmp(objTimeStep.String{objTimeStep.Value},'daily')
                                            continue;
                                        end
                                    case {'histogram','cdf'}
                                        objPlotXAxisUpper.Value = el; % date x axis
                                        objPlotYAxisUpper.Value = 1; % (none)
                                end
                                try
                                    feval(objBuildPlot.Callback);
                                    hassNoErrors=true;
                                catch
                                    hassNoErrors = false;
                                end
                                testCase.verifyEqual(hassNoErrors, true, ['Plotting of the following calib. forcing variable and plot type failed: ', ...
                                    objPlotYAxisUpper.String{objPlotYAxisUpper.Value},', ',objPlotType.String{objPlotType.Value}]);
                            end
                        end

                    end

                    % Break loop if doing daily, ie time step stats don't
                    % do anything for daily data.
                    if strcmp(objTimeStep.String{objTimeStep.Value},'daily')
                        break;
                    end
                end        
            end    
            disp('');
        end      
    end

    methods(TestClassTeardown)
        function closeCalibGUI(testCase)
            % Get handle to GUI.
            GUI = getSharedTestFixtures(testCase,'loadHydroSightFixture').GUI;

            % Close Calib GUI
            if isfield(GUI.tab_ModelCalibration,'GUI') && ishghandle(GUI.tab_ModelCalibration.GUI)
                feval(get(GUI.tab_ModelCalibration.GUI,'CloseRequestFcn'), GUI.tab_ModelCalibration.GUI);
            end
        end
    end
end