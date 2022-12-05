classdef loadHydroSightFixture < ...
        matlab.unittest.fixtures.Fixture
    
    properties (SetAccess = private)
        GUI = [];
        parpool_defaultSetting = [];
    end
    
    methods
        function fixture = loadHydroSightFixture()
            fixture.GUI = [];
        end
        
        function setup(fixture)
            import matlab.unittest.fixtures.SuppressedWarningsFixture

            % Suppress dialog warning if doing testing with -nodisplay
            %if ~ispc && ~usejava('desktop')
                fixture.applyFixture(SuppressedWarningsFixture('MATLAB:hg:NoDisplayNoFigureSupportSeeReleaseNotes'));
            %end

            % Load HydroSight GUI
            disp('TESTING: Building GUI fixture ...')
            fixture.GUI = HydroSight(true);         
            fixture.SetupDescription = sprintf('Loading HydroSight GUI.');

            % Check GUI loaded
            fixture.assertInstanceOf(fixture.GUI,'HydroSight_GUI','HydroSight GUI not loaded.');

            % Close parallel pool. This is done to ensure code within a parfor is
            % included in code coverage report
            disp('TESTING: Closing parpool...')
            poolobj = gcp('nocreate');
            delete(poolobj);

            % Ensure parpool does not auto-start
            disp('TESTING: Ensure parpool is not automatically started ...')
            ps = parallel.Settings;
            fixture.parpool_defaultSetting = ps.Pool.AutoCreate;
            ps.Pool.AutoCreate = false;

            % Setup teardown of GUI      
            %fixture.addTeardown(@onExit, fixture.GUI,[],[],'No')
            fixture.addTeardown(@fixture.teardown);
            fixture.TeardownDescription = sprintf('Closing HydroSight GUI');
        end

        function teardown(fixture)
            % Close HydroSight GUI
            onExit(fixture.GUI,[],[],'No');

            % Restore parpool settings
            disp('TESTING: Restoring parpool settings ...')
            ps = parallel.Settings;
            ps.Pool.AutoCreate = fixture.parpool_defaultSetting;
        end
    end
    
    methods (Access = protected)
        function bool = isCompatible(fixture, ~) %#ok<INUSD> 
            bool = true; 
        end
    end
end