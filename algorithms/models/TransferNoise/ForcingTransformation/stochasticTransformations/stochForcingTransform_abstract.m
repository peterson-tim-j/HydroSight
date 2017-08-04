classdef stochForcingTransform_abstract < forcingTransform_abstract
% stochForcingTransform_abstract abstract for stochastic forcing.
%
% Description: 
%   This abstract is for forcing data that is stochastically derived. Each
%   of the additional methods listed below (relative to
%   forcingTransform_abstract() are required by the calibration schemes.
    
    properties
    end
        
    methods(Abstract)
        
        % Get a data structure (forcingData) containing the stochastic forcing data.
        stochDerivedForcingData = getStochForcingData(obj)   
        
        % Update the stochasticlly derived forcing data. The inputs should
        % be in the same format at returned by getStochForcingData().
        updateStochForcingData(obj, stochDerivedForcingData, objFuncVal, objFuncVal_prior)
        
        % Assess if the current objtive function solution (objFuncVal and associated
        % parameter set) should be accepted. objFuncVal_prior should be the prior best solution. 
        % If objFuncVal_prior<objFuncVal, then the method may update each
        % element of stochDerivedForcingData and return an updated
        % stochastic derived data.
        [stochDerivedForcingData_new, accepted] = acceptSolution(obj, objFuncVal, objFuncVal_prior, stochDerivedForcingData)
    end
    
end

