classdef loadHydroSightFixture < ...
        matlab.unittest.fixtures.Fixture
    
    properties (SetAccess = private)
        GUI = [];
    end
    
    methods
        function fixture = loadHydroSightFixture()
            fixture.GUI = [];
        end
        
        function setup(fixture)
            % Suppress dialog warning if doing testing with -nodisplay
            if ~ispc && ~usejava('desktop')
                warning('off','MATLAB:hg:NoDisplayNoFigureSupportSeeReleaseNotes')
            end

            % Load HydroSight GUI
            fixture.GUI = HydroSight(true);         
            fixture.SetupDescription = sprintf('Loading HydroSight GUI.');

            % Check GUI loaded
            fixture.assertInstanceOf(fixture.GUI,'HydroSight_GUI','HydroSight GUI not loaded.');

            % Setup teardown of GUI      
            fixture.addTeardown(@onExit, fixture.GUI,[],[],'No')
            fixture.TeardownDescription = sprintf('Closing HydroSight GUI');
        end
    end
    
    methods (Access = protected)
        function bool = isCompatible(fixture, other)
            bool = true; %strcmp(fixture.GUI, other.GUI);
        end
    end
end