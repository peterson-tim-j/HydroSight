classdef GroundwaterStatisticsToolbox < HydroSightModel
    %GROUNDWATERSTATISICALTOOLBOX Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        function obj = GroundwaterStatisticsToolbox(model_label, bore_ID, model_class_name, obsHead, obsHead_maxObsFreq, forcingData, siteCoordinates, varargin)
            % Call constructor for hydroSight model,
            obj@HydroSightModel(model_label, bore_ID, model_class_name, obsHead, obsHead_maxObsFreq, forcingData, siteCoordinates, varargin{1})            
        end
    end
    
end

