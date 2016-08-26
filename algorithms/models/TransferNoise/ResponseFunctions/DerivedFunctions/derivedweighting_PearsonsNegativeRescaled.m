classdef derivedweighting_PearsonsNegativeRescaled < derivedweighting_PearsonsPositiveRescaled
% Pearson's type III impulse response transfer function class. 

    methods(Static)        
        function [modelSettings, colNames, colFormats, colEdits] = modelOptions(bore_ID, forcingDataSiteID, siteCoordinates)
           modelSettings = {};
           colNames = {};
           colFormats = {};
           colEdits = [];           
        end
        function modelDescription = modelDescription()
           modelDescription = {'Name: derivedweighting_PearsonsNegativeRescaled', ...
                               '', ...
                               'Purpose: simulation of discharge-like climate forcing (ie groundwater evap.) using previously created', ...
                               'responseFunction_Pearsons weighting function. ', ...
                               '', ...                               
                               'Number of parameters: 1', ...
                               '', ...                               
                               'Options: none', ...
                               '', ...                               
                               'Comments: In combination with the derived forcing function derivedForcing_linearUnconstrainedScaling, this function can be used ', ...
                               'to estimate the impact of revegetation on discharge by weighting a discharge output from the aformentioned function (which needs an', ...
                               'input for the landuse change).', ...
                               '', ...                               
                               'References: (none)'};
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
               if isempty(obj.(propNames{i}))
                   continue;
               end                
               if isobject(obj.(propNames{i}))
                delete(obj.(propNames{i}));
               else               
                obj.(propNames{i}) = []; 
               end
            end
        end            
    end

end

