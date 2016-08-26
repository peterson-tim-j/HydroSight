classdef responseFunction_PearsonsNegative < responseFunction_Pearsons
% Pearson's type III impulse response transfer function class. 

%%  STATIC METHODS        
% Static methods used by the Graphical User Interface to inform the
% user of the available model options and their input format.
    methods(Static)        
        function [modelSettings, colNames, colFormats, colEdits] = modelOptions(bore_ID, forcingDataSiteID, siteCoordinates)
           modelSettings = {};
           colNames = {};
           colFormats = {};
           colEdits = [];           
        end
        function modelDescription = modelDescription()
           modelDescription = {'Name: responseFunction_PearsonsNegative', ...
                               '', ...                                              
                               'Purpose: simulation of discharge-like climate forcing (i.e. groundwater evaporation).', ...
                               '', ...                                                              
                               'Number of parameters: 3', ...
                               '', ...                                                              
                               'Options: none', ...
                               '', ...                                                              
                               'Comments: a highly flexible function that can range from a exponetial-like decay (no time lag) to a skew Gaussian-like function (with time lag).', ...
                               'Also, the function is derived from the responseFunction_Pearsons function.', ...
                               '', ...                                                              
                               'References: Peterson & Western (2014), Nonlinear time-series modeling of unconfined groundwater head, Water Resour. Res., 50, 8330–8355'};
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
               
        function delete(obj)
% delete class destructor
%
% Syntax:
%   delete(obj)
%
% Description:
%   Loops through parameters and, if not an object, empties them. Else, calls
%   the sub-object's destructor.
%
% Input:
%   obj -  model object
%
% Output:  
%   (none)
%
% Author: 
%   Dr. Tim Peterson, The Department of Infrastructure Engineering, 
%   The University of Melbourne.
%
% Date:
%   24 Aug 2016
%%            
            propNames = properties(obj);
            for i=1:length(propNames)
               if isobject(obj.(propNames{i}))
                delete(obj.(propNames{i}));
               else               
                obj.(propNames{i}) = []; 
               end
            end
        end            
    end

end

