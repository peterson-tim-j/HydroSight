classdef model_gui_abstract < handle
    %MODEL_GUI_ABSTRACT Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        Figure
        Figure_icon
        boreID
        siteData
        forcingData
    end
    
    methods (Abstract)
        
        initialise(this);
        
        setForcingData(this, fname);
        
        setCoordinatesData(this, fname);
        
        setBoreID(this, fname);
        
        setModelOptions(this, modelOptionsStr);
        
        modelOptionsArray = getModelOptions(this);

    end
    
end

