classdef buildExampleModels < loadExampleModels
    properties (ClassSetupParameter)
        iExampleModel = {4,3,2};
    end
    
    methods(TestClassSetup)
        function setModelNumer(testCase)
            testCase.irow = 4;
        end
    end
    methods(Test)
        % Test methods
        function showBoreData(testCase)
            % Give user update on test being run.
            disp('TESTING: Showing hydrograph plot for example model...');

             % Get handle to GUI.
             GUI = getSharedTestFixtures(testCase,'loadHydroSightFixture').GUI;

            try
                expSolution=0;

                % Build event object.
                obj = GUI.tab_ModelConstruction.Table;

                % Show bore hydrograph.
                icol = 6;           
                eventdata.Indices = [testCase.irow,icol];
                eventdata.Source = obj;
                feval(obj.CellSelectionCallback, obj, eventdata);

                % Successful if no error thrown.
                actSolution = 0;
                msgStr = 'Hydrograph successfully shown.';
            catch ME
                actSolution = -1;
                msgStr = ['Error: Hydrograph plotting failed',ME.message,' at ', ME.stack(1).name, ' on line ',num2str(ME.stack(1).line)];
            end
            testCase.verifyEqual(actSolution,expSolution, msgStr);
        end

        function showModelOptions(testCase)
            % Give user update on test being run.
            disp('TESTING: Showing model options for example model...');
            
            % Get handle to GUI.
            GUI = getSharedTestFixtures(testCase,'loadHydroSightFixture').GUI;

            try
                expSolution=0;

                % Build event object.
                obj = GUI.tab_ModelConstruction.Table;

                % Show model options.
                icol = 9;
                eventdata.Indices = [testCase.irow,icol];
                eventdata.Source = obj;
                feval(obj.CellSelectionCallback, obj, eventdata);

                % Successful if no error thrown.
                actSolution = 0;
                msgStr = 'Model options successfully shown.';
            catch ME
                actSolution = -1;
                msgStr = ['Error: Model options display failed',ME.message,' at ', ME.stack(1).name, ' on line ',num2str(ME.stack(1).line)];
            end
            testCase.verifyEqual(actSolution,expSolution, msgStr);
        end

        function showBuildStatus(testCase)
            % Give user update on test being run.
            disp('TESTING: Showing model build status for example model...');

            % Get handle to GUI.
            GUI = getSharedTestFixtures(testCase,'loadHydroSightFixture').GUI;

            try
                expSolution=0;

                % Build event object.
                obj = GUI.tab_ModelConstruction.Table;

                % Show model status.
                icol = 10;
                eventdata.Indices = [testCase.irow,icol];
                eventdata.Source = obj;
                feval(obj.CellSelectionCallback, obj, eventdata);

                % Successful if no error thrown.
                actSolution = 0;
                msgStr = 'Model status successfully shown.';
            catch ME
                actSolution = -1;
                msgStr = ['Error: Model status failed',ME.message,' at ', ME.stack(1).name, ' on line ',num2str(ME.stack(1).line)];
            end
            testCase.verifyEqual(actSolution,expSolution, msgStr);
        end

        function buildModel(testCase)
            % Give user update on test being run.
            disp('TESTING: Building example models ...');

            GUI = getSharedTestFixtures(testCase,'loadHydroSightFixture').GUI;

            % Get contect menu obj for 'Select none'
            obj = findobj(GUI.Figure.UIContextMenu,'Label','Select none');
            eventdata.Source.Parent.UserData = 'this.tab_ModelConstruction.Table';
            hObject.Label = 'Select none';
            feval(obj.MenuSelectedFcn, hObject, eventdata);

            % Select row two
            hObject.Label = 'Select all';
            feval(obj.MenuSelectedFcn, hObject, eventdata);

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

        end

        function showPostBuildStatus(testCase)
            % Give user update on test being run.
            disp('TESTING: Showing post-build model status ...');

            % Get handle to GUI.
            GUI = getSharedTestFixtures(testCase,'loadHydroSightFixture').GUI;

            try
                expSolution=0;

                % Build event object.
                obj = GUI.tab_ModelConstruction.Table;

                % Show model status.
                icol = 10;
                eventdata.Indices = [testCase.irow,icol];
                eventdata.Source = obj;
                feval(obj.CellSelectionCallback, obj, eventdata);

                % Successful if no error thrown.
                actSolution = 0;
                msgStr = 'Model post-built status successfully shown.';
            catch ME
                actSolution = -1;
                msgStr = ['Error: Model post-built status failed',ME.message,' at ', ME.stack(1).name, ' on line ',num2str(ME.stack(1).line)];
            end
            testCase.verifyEqual(actSolution,expSolution, msgStr);
        end
    end
end