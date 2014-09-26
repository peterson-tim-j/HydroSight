classdef derivedweighting_PearsonsNegativeRescaled < derivedweighting_PearsonsPositiveRescaled
% Pearson's type III impulse response transfer function class. 

%%  STATIC METHODS        
% Static methods used by the Graphical User Interface to inform the
% user of the available model options and their input format.
    methods(Static)        
        function [columns, cellFormat] = responseFunction_optionsFormat()
            columns = {};
            cellFormat = {};
        end        
    end

%%    
    methods
        % Constructor
        function obj = derivedweighting_PearsonsNegativeRescaled(bore_ID, forcingDataSiteID, siteCoordinates, sourceResponseFunctionObject, options, params)            
            % Call inherited model constructor.
            obj = obj@derivedweighting_PearsonsPositiveRescaled(bore_ID, forcingDataSiteID, siteCoordinates, sourceResponseFunctionObject, options);
    
            % Assign model parameters if input.
            if nargin>5
                setParameters(obj, params);
            end
        end
        
        % Calculate impulse-response function.
        function result = theta(obj, t)           
            % Call the source model theta function and change the sign of
            % the output.
            result = -theta@derivedweighting_PearsonsPositiveRescaled(obj, t);          
        end   
        
        % Calculate integral of impulse-response function from t to inf.
        % This is used to minimise the impact from a finit forcign data
        % set.
        function result = intTheta_upperTail2Inf(obj, t)           
            % Call the source model intTheta function and change the sign of
            % the output.
            result = -intTheta_upperTail2Inf@derivedweighting_PearsonsPositiveRescaled(obj, t);                              
        end   

        % Calculate integral of impulse-response function from 0 to 1.
        % This is used handle rapidly chnageing fucntion in the range from 0 to 1.        
        function result = intTheta_lowerTail(obj, t)  
            result = -intTheta_lowerTail@derivedweighting_PearsonsPositiveRescaled(obj, t);
        end
        
    end

end

