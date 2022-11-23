classdef (Abstract, SharedTestFixtures = {loadHydroSightFixture()}) ...
        loadExampleModels < matlab.unittest.TestCase

    properties
        irow = [];
        fname = '';
        pname = '';
    end
    methods(TestClassSetup)
        % Load outlier detection example
        function loadExample(testCase, iExampleModel)      
            % Get handle to GUI.
            GUI = getSharedTestFixtures(testCase).GUI;
           
            % Load example
            expSolution = 0;
            try
                testCase.pname = createTemporaryFolder(testCase);
                eventdata = struct('Source',[]);
                eventdata.Source.Tag = GUI.figure_examples.Children(iExampleModel).Tag;
                feval(GUI.figure_examples.Children(iExampleModel).MenuSelectedFcn,[],eventdata, testCase.pname);
                actSolution = 0;

                % Set which model to test.
                msgStr = 'Example loaded successfully';
            catch ME
                actSolution = -1;
                msgStr = ['Error: loading example failed. ',ME.message,' at ', ME.stack(1).name, ' on line ',num2str(ME.stack(1).line)];
            end
            testCase.assertEqual(actSolution, expSolution, msgStr)    
        end
    end

end