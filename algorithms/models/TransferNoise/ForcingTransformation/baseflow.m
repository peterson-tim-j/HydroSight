classdef baseflow < forcingTransform_abstract
    % Defines the behaviour of baseflow according to the GW head. 
    
    %   Detailed explanation goes here
    
    properties (GetAccess=public, SetAccess=protected)
        
        % Model Parameters
        %----------------------------------------------------------------
        head_threshold   % GW head threshold that defines if have positive or negative baseflow. Below this threshold, baseflow recharges from the river.
        head_to_baseflow % controls the smoothening of the baseflow response due to the rise of GW head. 
        
        %----------------------------------------------------------------        
    end
    
    %% Constructor of the baseflow class
    
    methods
        function obj = baseflow(bore_ID, forcingData_data,  forcingData_colnames, siteCoordinates, forcingData_reqCols, modelOptions)            
            % Constructor of the Baseflow class 
            %   Detailed explanation goes here
            obj.head_threshold = 200;
            obj.head_to_baseflow = 1;
            
        end
        
        function [params, param_names] = getParameters(obj)            
           params = [ obj.head_threshold; obj.head_to_baseflow];
           param_names = {'head_threshold'; 'head_to_baseflow'};
        end
        
        
        function coordinates = getCoordinates(obj, variableName)        
           params = [ obj.head_threshold; obj.head_to_baseflow];
           param_names = {'head_threshold'; 'head_to_baseflow'};
        end
        
    end
end

