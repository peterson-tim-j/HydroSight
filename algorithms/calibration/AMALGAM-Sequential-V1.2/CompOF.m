function [newOF,newCg] = CompOF(x,AMALGAMPar,Measurement,ModelName,Extra)
% This function computes the objective function for each x value

% Evaluate each parameter combination and compute the objective functions
for ii = 1:AMALGAMPar.N,

    % Call model to generate simulated data
    evalstr = ['ModPred = ',ModelName,'(x(ii,:),Extra);']; eval(evalstr);

    % Calculate the objective functions by comparing model predictions with
    OF = CalcOF(ModPred,Measurement,Extra);
    
    % Store the objective function values for each point
    newOF(ii,1:AMALGAMPar.nobj) = OF;

    % Define the contstraint violation
    newCg(ii,1) = 0;
    
end;
