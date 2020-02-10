function [out] = MeasError(Y);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                                               %
% Function that estimates the measurement error of a given calibration data series              % 
%                                                                                               %
% SYNOPSIS:     [out] = MeasError(Y);                                                           %
%                                                                                               %
% Input:        Y = calibration data (single vector) of N by 1                                  %
%                                                                                               %
% Output:       out = N by 2 matrix with mean versus std of measurement error                   %
%                                                                                               %
% Details can be found in:                                                                      %
%                                                                                               %
% Vrugt, J.A., C.G.H. Diks, W. Bouten, H.V. Gupta, and J.M. Verstraten (2005),                  %  
%       Improved treatment of uncertainty in hydrologic modeling: Combining the strengths       %  
%       of global optimization and data assimilation, Water Resources Research, 41(1),          %   
%       W01017, doi:10.1029/2004WR003059.                                                       %
%                                                                                               %
% Assumption is that the calibration data, Y, is sufficiently smooth and with high enough       %
% temporal resolution                                                                           %
%                                                                                               %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Copy the measurement vector -- a trick
Ytot = [Y Y];

% Now difference the second column and average the first one
for zz = 1:3,
    
    % Difference the second column 
    Y2 = diff(Ytot(:,2));
    
    % Take the mean of the first column
    Y1_1 = Ytot(1:end-1,1); Y1_2 = Ytot(2:end,1);
    
    % Now average Y1_1 and Y1_2;
    Y1 = (Y1_1 + Y1_2)/2;
    
    % Create new Ytot 
    Ytot = [Y1 Y2];
    
end;
    
% How many possible combinations?
F = 6 * 5 * 4 / 6;

% Now calculate the measurement error
MeasError = sqrt( 1/F * Ytot(:,2).^2);

% Return vector
out = [Y1 MeasError];

% If line is horizontal --> homosocedastic (error independent on magnitude measured data);
% Otherwise heteroscedastic.