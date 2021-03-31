classdef ExpSmooth_gui  < model_gui_abstract
    %EXPSMOOTH_GUI Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        
        function this = ExpSmooth_gui(parent_handle)
            
            % Initialise properties not initialised below
            this.boreID = [];
            this.siteData = [];
            this.forcingData = [];  
        end            
        
        function initialise(this)
            % do nothing
        end
        
        function setForcingData(this, fname)
            % do nothing            
        end
        
        function setCoordinatesData(this, fname)
            % do nothing            
        end
        
        function setBoreID(this, fname)
            % do nothing        
        end
        function setModelOptions(this, modelOptionsStr)
            % do nothing            
        end
        
        function modelOptionsArray = getModelOptions(this)
            modelOptionsArray = '{}';  
        end

    end
    
end

