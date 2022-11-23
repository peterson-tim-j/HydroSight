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
            fixture.GUI = HydroSight(true);         
            fixture.SetupDescription = sprintf('Loading HydroSight GUI.');

            % Turn on testing state. This allows HydroSight message boxes
            % to be programatically closed during testing.
            %fixture.GUI.doingUnitTesting = true;

            %fixture.verifyInstanceOf(fixture.GUI,?HydroSight_GUI,'Loading HydroSight GUI failed.')         
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