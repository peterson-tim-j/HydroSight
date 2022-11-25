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

% Install GUI layout if not installed
if isempty(ver('layout'))  
    installedToolbox = matlab.addons.toolbox.installToolbox(fullfile(currentPath,'testing','GUI Layout Toolbox 2.3.5.mltbx'),true);
end

% Run tests
suite = testsuite({'runOutlierDetection','buildExampleModels','simulateExampleModels','calibrateNewModel'});
%suite = testsuite({'calibrateNewModel'});
import matlab.unittest.plugins.CodeCoveragePlugin
runner = testrunner("textoutput");

% Get coverage report
runner.addPlugin(CodeCoveragePlugin.forFolder({'GUI','algorithms'},'IncludeSubfolders',true));
results = runner.run(suite);

% Rest file paths.
rmpath(fullfile(currentPath,'testing'));
cd(currentPath);

% Restore parpool settings
ps.Pool.AutoCreate = ps_Auto;