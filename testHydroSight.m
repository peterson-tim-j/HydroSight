function results = testHydroSight(runTests)
% Setup test environment and run suite.
%
% Setup includes closig the parpool and ensuring it does not autostart. The
% GUI layout toolbox is also installed. If the setup is successful, and
% only the setup is being done, then result equals 0, else -1;
%
% If runTests==true, then the test suite is also built and run. If so, then
% result equals a cell array of the TestResult objects.
%

    % Initialise output    
    results = 0;

    % Check matlab is after 2022a
    if isMATLABReleaseOlderThan("R2022a")
        error('HydroSight testing requires Matllab 2022a or later.');
    end

    % Import testing plugins
    if nargin==0
        runTests=true;

        disp('Import testing plugins ...')
        import matlab.unittest.TestRunner; %#ok<SIMPT> 
        import matlab.unittest.plugins.CodeCoveragePlugin; %#ok<SIMPT> 
        import matlab.unittest.plugins.XMLPlugin; %#ok<SIMPT> 
        import matlab.unittest.plugins.codecoverage.CoberturaFormat; %#ok<SIMPT> 
    end

    % Add paths to unit tests
    disp('Adding testing to path ...')
    addpath('testing');
    currentPath = pwd();

    % Install GUI layout if not installed
    try            
        if isempty(ver('layout'))
            disp('Installing GUI Layout toolbox ...')
            matlab.addons.toolbox.installToolbox(fullfile(currentPath,'testing','GUI Layout Toolbox 2.3.5.mltbx'),true);
        end
    catch ME
        results = -1;
        disp(['Installation of GUI Layout toolbox failed with error: ',ME.message]);
    end

    if runTests
        disp('STARTING TESTS');
        disp('--------------------------')
        suite = testsuite(pwd, 'IncludeSubfolders', true);        
        
        runner = TestRunner.withTextOutput();
        runner.addPlugin(XMLPlugin.producingJUnitFormat('testing/results.xml'));
        runner.addPlugin(CodeCoveragePlugin.forFolder({'.'}, 'IncludingSubfolders', true, 'Producing', CoberturaFormat('testing/coverage.xml')));
        
        results = runner.run(suite);
        display(results);
        
        assertSuccess(results);

        disp('FINSIHED TESTS');
        disp('--------------------------')
        disp('')
        
        % Rest file paths.
        disp('Restoring paths ...')
        rmpath(fullfile(currentPath,'testing'));
        cd(currentPath);
    end
end