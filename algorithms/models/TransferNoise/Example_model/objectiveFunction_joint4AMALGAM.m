function[newObjVals, Cg] = objectiveFunction_joint4AMALGAM(ParGen, AMALGAMPar,Measurement,ModelName,model_object)
%OBJECTIVEFUNCTION_JOINT4AMALGAM Summary of this function goes here
%   Detailed explanation goes here


ObjVals = repmat(inf, AMALGAMPar.N, 2); % initialize to speed up the parfor loop with the correct matrix of ObjVals


%     parfor ii = 1:AMALGAMPar.N % computing the Obj-functions using parallel computing 
    for ii = 1:AMALGAMPar.N % computing the Obj-functions using parallel computing 

        % calculate the obj-function for GW head and streamflow usin
        % sum-squared error, which is minimized by AMALGAM
        [ObjVals, objFn_head, objFn_flow2, totalFlow_sim, colnames, drainage_elevation] = objectiveFunction_joint(ParGen(ii,:), Measurement.time_points_head, Measurement.time_points_streamflow, model_object,{}); % using time points from calibration_initialise to avoid mismatch of dimensions in line 2803 of model_TFN
%         [ObjVals, objFn_head, objFn_flow2, totalFlow_sim, colnames, drainage_elevation] = objectiveFunction_joint@model_TFN_SW_GW(ParGen(ii,:), Measurement.time_points_head, Measurement.time_points_streamflow, model_object,{}); % using time points from calibration_initialise to avoid mismatch of dimensions in line 2803 of model_TFN

    
        % Store the objective function values for each point
        newObjVals(ii,1:AMALGAMPar.nobj) = ObjVals;
        
        % Define the contstraint violation
        newCg(ii,1) = 0;
        
    end
   
    
    
end

