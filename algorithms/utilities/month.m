function m = month(date_asNum)
%MONTH Summary of this function goes here

if ischar(date_asNum) 
  error('date_asNum must be a date vector, not character.');
end 
 
% Get date vectors
c = datevec(date_asNum(:));
    
% Get month and reformat to the same shape as input data.
m = reshape(c(:,2),size(date_asNum)); 

end

