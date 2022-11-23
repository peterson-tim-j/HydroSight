% Close parallel pool. This is done to ensure code within a parfor is 
% included in code coverage report
poolobj = gcp('nocreate');
delete(poolobj);

% Ensure parpool does not auto-start
ps = parallel.Settings;
ps_Auto = ps.Pool.AutoCreate;
ps.Pool.AutoCreate = false;

% Add paths to unit tests
addpath('testing');
currentPath = pwd();

% Run tests
suite = testsuite({'runOutlierDetection','buildExampleModels','simulateExampleModels','calibrateNewModel'});
%suite = testsuite({'calibrateNewModel'});
import matlab.unittest.plugins.CodeCoveragePlugin
runner = testrunner("textoutput");

% Get coverage report
runner.addPlugin(CodeCoveragePlugin.forFolder({'GUI','algorithms','dataPreparationAnalysis'},'IncludeSubfolders',true));
results = runner.run(suite);

% Rest file paths.
rmpath(fullfile(currentPath,'testing'));
cd(currentPath);

% Restore parpool settings
ps.Pool.AutoCreate = ps_Auto;