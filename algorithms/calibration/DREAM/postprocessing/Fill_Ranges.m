function [h] = Fill_Ranges(x,y_low,y_up,color);
% Fill the ranges with a given color
% 
% SYNOPSIS: bounds(x,ylow,yupper);
%           bounds(x,ylow,yupper,color);
%
% Input:    x = vector with "x" values
%           ylow = vector with lower range values
%           yupper = vector with upper range values
%           color = filling color
%

% Now create a vector x1
X = [x(:); flipud(x(:)); x(1)];

% And corresponding matrix y1
Y = [y_up(:); flipud(y_low(:)); y_up(1)];

% Now fill area with "fill" function 
h = fill(X,Y,color);

% Set color
set(h,'edgecolor',color);