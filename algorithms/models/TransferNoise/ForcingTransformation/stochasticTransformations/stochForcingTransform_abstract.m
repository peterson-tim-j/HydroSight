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
        % The input 'refineStochForcingMethod' provides the flexibility to
        % reduce the down-scaling time step at the end of calibration
        % iterations.
        stochDerivedForcingData = updateStochForcingData(obj, stochDerivedForcingData, refineStochForcingMethod)
        
        % Set if model calibration is being undertaken or not. This was
        % required to all for model simulations without undertaking chnages
        % to the stochastic forcing data. The method can also be used to
        % set the start and end dates for calibrtion.
        setStochForcingState(obj,doingCalibration, t_start_calib, t_end_calib);
        
        % Update the the model parameters. 
        % This function should be called at the end of a, say, SP-UCI, evolutionary loop to
        % avoid the parameters converging to a local minimum
        updateStochForcingParameters(obj, forcingData);
    end
    
end

