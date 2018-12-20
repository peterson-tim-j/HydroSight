function y = year(date_asNum)
%YEAR Summary of this function goes here
%   Detailed explanation goes here

if ischar(date_asNum) 
  error('date_asNum must be a date vector, not character.');
end 
 
% Get date vectors
c = datevec(date_asNum(:));
    
% Get year and reformat to the same shape as input data.
y = reshape(c(:,1),size(date_asNum)); 

end

