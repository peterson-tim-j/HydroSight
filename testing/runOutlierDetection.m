classdef (SharedTestFixtures = {loadHydroSightFixture()}) ...
        runOutlierDetection < matlab.unittest.TestCase
    
    properties
        irow = [];
        pname = '';
    end
    methods(TestClassSetup)
        % Load outlier detection example
        function loadExample(testCase)      
            % Get handle to GUI.
            GUI = getSharedTestFixtures(testCase).GUI;
            
            expSolution = 0;
            try
                % Load example
                testCase.pname = createTemporaryFolder(testCase);
                eventdata = struct('Source',[]);                
                eventdata.Source.Tag = GUI.figure_examples.Children(1).Tag;
                feval(GUI.figure_examples.Children(1).MenuSelectedFcn,[],eventdata, testCase.pname);                
                actSolution = 0;                

                % Set which model to test.
                testCase.irow = 4;
                msgStr = 'Example loaded successfully';   
            catch ME
                actSolution = -1;
                msgStr = ['Error: loading example failed. ',ME.message,' at ', ME.stack(1).name, ' on line ',num2str(ME.stack(1).line)];                
            end
            testCase.assertEqual(actSolution, expSolution, msgStr)            
        end        
    end

    methods(Test)
        % Test methods
        function doAnalysis(testCase)
            % Get handle to GUI.
            GUI = getSharedTestFixtures(testCase).GUI;

            % Run outlier detection
            try
                expSolution=0;

                % Get contect menu obj for 'Select none'
                obj = findobj(GUI.Figure.UIContextMenu,'Label','Select none');
                eventdata.Source.Parent.UserData = 'this.tab_DataPrep.Table';
                hObject.Label = 'Select none';
                feval(obj.MenuSelectedFcn, hObject, eventdata);

                % Select row two
                icol = 1;
                GUI.tab_DataPrep.Table.Data{testCase.irow,icol}= true;

                % Run analysis on bore.
                GUI.tab_DataPrep.Table.Data{testCase.irow,16} = '<html><font color = "#FF0000">Not analysed.</font></html>';
                onAnalyseBores(GUI, [],[]);

                % close msgbox
                h = findall(0,'Tag','Data prep msgbox summary');
                if ishandle(h)
                    close(h);
                end
            catch ME
                actSolution = -1;
                msgStr = ['Error: Analysis failed',ME.message,' at ', ME.stack(1).name, ' on line ',num2str(ME.stack(1).line)];
                testCase.assertEqual(actSolution,expSolution, msgStr);
            end

            % Check analysis was successful.
            testCase.assertSubstring(GUI.tab_DataPrep.Table.Data{testCase.irow,16},'Analysed.', 'Error: Bore analysis unsuccessful.');

            % Check analysis produced the expected number of
            % outliers and errors.
            nErrors =  str2double(HydroSight_GUI.removeHTMLTags(GUI.tab_DataPrep.Table.Data{testCase.irow,17}));
            nOutliers =  str2double(HydroSight_GUI.removeHTMLTags(GUI.tab_DataPrep.Table.Data{testCase.irow,18}));
            testCase.verifyEqual(nErrors,4, 'Error: Incorrect number of obs. errors idenified.');
            testCase.verifyEqual(nOutliers,2, 'Error: Incorrect number of outlier obs. idenified.');
        end

        function showBoreData(testCase)
            % Get handle to GUI.
            GUI = getSharedTestFixtures(testCase).GUI;

            try
                expSolution=0;

                % Build event object.
                hObject = GUI.tab_DataPrep.Table;
                eventdata.Source = GUI.tab_DataPrep.Table;

                % Show bore hydrograph.
                icol = 3;
                eventdata.Indices = [testCase.irow,icol];
                dataPrep_tableSelection(GUI, hObject, eventdata);

                actSolution = 0;
                msgStr = 'Hydrograph successfully shown.';
            catch ME
                actSolution = -1;
                msgStr = ['Error: Hydrograph plotting failed',ME.message,' at ', ME.stack(1).name, ' on line ',num2str(ME.stack(1).line)];
            end
            testCase.verifyEqual(actSolution,expSolution, msgStr);
        end

        function showModelStatus(testCase)
            % Get handle to GUI.
            GUI = getSharedTestFixtures(testCase).GUI;

            try
                expSolution=0;

                % Build event object.
                hObject = GUI.tab_DataPrep.Table;
                eventdata.Source = GUI.tab_DataPrep.Table;

                % Show calib status.
                icol = 16;
                eventdata.Indices = [testCase.irow,icol];
                dataPrep_tableSelection(GUI, hObject, eventdata);

                actSolution = 0;
                msgStr = 'Status results successfully shown.';
            catch ME
                actSolution = -1;
                msgStr = ['Error: Status results failed',ME.message,' at ', ME.stack(1).name, ' on line ',num2str(ME.stack(1).line)];
            end
            testCase.verifyEqual(actSolution,expSolution, msgStr);
        end

        function showModelResults(testCase)
            % Get handle to GUI.
            GUI = getSharedTestFixtures(testCase).GUI;

            try
                expSolution=0;

                % Build event object.
                hObject = GUI.tab_DataPrep.Table;
                eventdata.Source = GUI.tab_DataPrep.Table;

                % Show results plot.
                icol = 17;
                eventdata.Indices = [testCase.irow,icol];
                dataPrep_tableSelection(GUI, hObject, eventdata);

                actSolution = 0;
                msgStr = 'Model results successfully shown.';
            catch ME
                actSolution = -1;
                msgStr = ['Error: Model results failed',ME.message,' at ', ME.stack(1).name, ' on line ',num2str(ME.stack(1).line)];
            end
            testCase.verifyEqual(actSolution,expSolution, msgStr);
        end
    end
end