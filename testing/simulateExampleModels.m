classdef simulateExampleModels < loadExampleModels
    properties (ClassSetupParameter)
        iExampleModel = {4,3,2};
    end
    
    methods(Test)
        % Test methods
        function doSimulations(testCase)
            % Give user update on test being run.
            disp('TESTING: Simulating example models ...');

            % Get handle to GUI.
            GUI = getSharedTestFixtures(testCase,'loadHydroSightFixture').GUI;

            % Do simulations
            expectSolution = 0;
            try
                % Get contect menu obj for 'Select all'
                obj = findobj(GUI.Figure.UIContextMenu,'Label','Select all');
                eventdata.Source.Parent.UserData = 'this.tab_ModelSimulation.Table';
                hObject.Label = 'Select all';
                feval(obj.MenuSelectedFcn, hObject, eventdata);

                % initialise simulation status    
                nModels = size(GUI.tab_ModelSimulation.Table.Data,1);
                GUI.tab_ModelSimulation.Table.Data(:,end) = {'<html><font color = "#FF0000">Not simulated.</font></html>'};

                % Do simulation
                onSimModels(GUI);

                % close msgbox
                h = findall(0,'Tag','Model simulation msgbox summary');
                if ishandle(h)
                    close(h);
                end
                msgStr = 'Models simulated.';
                actSolution = 0;
            catch ME
                actSolution = -1;
                msgStr = ['Error: Model simulations crashed. ',ME.message,' at ', ME.stack(1).name, ' on line ',num2str(ME.stack(1).line)];
            end

            if actSolution<0
                % Error thrown if simulations crashed.
                testCase.verifyEqual(actSolution, expectSolution, msgStr);
            else
                % Check simulation was successful.
                for i=1:nModels
                    testCase.assertSubstring(GUI.tab_ModelSimulation.Table.Data{i,end}, ...
                        '<html><font color = "#008000">Simulated. </font></html>', ['Error: Failed simulation of model:',num2str(i)]);
                end
            end
        end
  
        function showSimulationStatus(testCase)
            % Give user update on test being run.
            disp('TESTING: Showing model simulation status results ...');


            % Get handle to GUI.
            GUI = getSharedTestFixtures(testCase,'loadHydroSightFixture').GUI;

            try
                expSolution=0;

                % Build event object.
                obj = GUI.tab_ModelSimulation.Table;

                % Show model status.
                icol = 12;
                eventdata.Indices = [1,icol];
                eventdata.Source = obj;
                feval(obj.CellSelectionCallback, obj, eventdata);

                % Successful if no error thrown.
                actSolution = 0;
                msgStr = 'Model simulation status successfully shown.';
            catch ME
                actSolution = -1;
                msgStr = ['Error: Model simulation status failed',ME.message,' at ', ME.stack(1).name, ' on line ',num2str(ME.stack(1).line)];
            end
            testCase.verifyEqual(actSolution,expSolution, msgStr);
            disp('');
        end


%         function showPostBuildStatus(testCase)
%             % Get handle to GUI.
%             GUI = getSharedTestFixtures(testCase,'loadHydroSightFixture').GUI;
% 
%             try
%                 expSolution=0;
% 
%                 % Build event object.
%                 obj = GUI.tab_ModelConstruction.Table;
% 
%                 % Show model status.
%                 icol = 10;
%                 eventdata.Indices = [testCase.irow,icol];
%                 eventdata.Source = obj;
%                 feval(obj.CellSelectionCallback, obj, eventdata);
% 
%                 % Successful if no error thrown.
%                 actSolution = 0;
%                 msgStr = 'Model post-built status successfully shown.';
%             catch ME
%                 actSolution = -1;
%                 msgStr = ['Error: Model post-built status failed',ME.message,' at ', ME.stack(1).name, ' on line ',num2str(ME.stack(1).line)];
%             end
%             testCase.verifyEqual(actSolution,expSolution, msgStr);
%         end
    end
end