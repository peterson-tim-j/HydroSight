classdef responseFunction_PearsonsNegative < responseFunction_Pearsons
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
        function obj = responseFunction_PearsonsNegative(bore_ID, forcingDataSiteID, siteCoordinates, options, params)            
            % Call inherited model constructor.
            obj = obj@responseFunction_Pearsons(bore_ID, forcingDataSiteID, siteCoordinates, options);
    
            % Assign model parameters if input.
            if nargin>5
                setParameters(obj, params);
            end
        end
        
        % Calculate impulse-response function.
        function result = theta(obj, t)           
            % Call the source model theta function and change the sign of
            % the output.
            result = -theta@responseFunction_Pearsons(obj, t);          
        end   

        % Calculate integral of impulse-response function from 0 to 1.
        function result = intTheta_lowerTail(obj, t)           
            % Call the source model intTheta function and change the sign of
            % the output.
            result = -intTheta_lowerTail@responseFunction_Pearsons(obj, t);                              
        end           
        
        % Calculate integral of impulse-response function from t to inf.
        % This is used to minimise the impact from a finit forcign data
        % set.
        function result = intTheta_upperTail2Inf(obj, t)           
            % Call the source model intTheta function and change the sign of
            % the output.
            result = -intTheta_upperTail2Inf@responseFunction_Pearsons(obj, t);                              
        end   
               
        
    end

end

