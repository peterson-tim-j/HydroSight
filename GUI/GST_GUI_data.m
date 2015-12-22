classdef GST_GUI_data< handle  
    %GST_GUI_DATA Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        boreID;
        forcingDataFile;
        obsHeadDataFile;
        coordinatesDataFile;
        modelType
        isModelBuilt
        
        calibStartDate
        calibEndDate
        CMAESRestarts
        isModelCalib
        calibPeriodCoE
        evalPeriodCoE
        calibPeriodAIC
        evalPeriodAIC
    end
    
    methods
        function this = GST_GUI_data()
           
            % Initialise properties
            boreID = '';
            forcingDataFile = '';
            obsHeadDataFile = '';
            coordinatesDataFile = '';
            modelType =  '';
            isModelBuilt = false;

            calibStartDate = datetime(0,0,0);
            calibEndDate = now();
            CMAESRestarts = 4;
            isModelCalib = false;
            calibPeriodCoE = -inf;
            evalPeriodCoE = - inf;
            calibPeriodAIC = inf;
            evalPeriodAIC  = inf;          
            
        end
    end
    
end

