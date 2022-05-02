function OF = CalcOF(ModPred,Measurement,Extra);
% Calculate the objective function

% Zitzler and Thiele function 4
if (Extra.example == 1),
    OF(1) = ModPred.f; OF(2) = ModPred.g * ModPred.h;
end;

% Zitzler and Thiele function 6
if (Extra.example == 2),
    OF(1) = ModPred.f; OF(2) = ModPred.g * ModPred.h;
end;

% Rotated problem
if (Extra.example == 3),
    OF(1) = ModPred.y(1); OF(2) = ModPred.g * exp(-ModPred.y(1)./ModPred.g);
    % Put in this check
    if abs(ModPred.y(1)) > 0.3,
        OF(1) = OF(1) + 1000; OF(2) = OF(2) + 1000;
    end;
end;

% HYMOD rainfall - runoff model
if (Extra.example == 4),
    % Find nondriven part of hydrograph
    ND = find(Extra.Precip(65:Extra.MaxT,1) == 0);
    % Find driven part of hydrograph
    D = find(Extra.Precip(65:Extra.MaxT,1) > 0);
    % Calculate the RMSE for ND part
    OF(1) = sqrt(sum((ModPred(ND) - Measurement.MeasData(ND)).^2)/size(ND,1));
    % Calculate the RMSE for D part
    OF(2) = sqrt(sum((ModPred(D) - Measurement.MeasData(D)).^2)/size(D,1));
end;