function m = minute(date_asNum)
%DAY Summary of this function goes here

if ischar(date_asNum) 
  error('date_asNum must be a date vector, not character.');
end 
 
% Get date vectors
c = datevec(date_asNum(:));
    
% Get year and reformat to the same shape as input data.
m = reshape(c(:,5),size(date_asNum)); 

end

