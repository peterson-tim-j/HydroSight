function s = second(date_asNum)
%DAY Summary of this function goes here

if ischar(date_asNum) 
  error('date_asNum must be a date vector, not character.');
end 
 
% Get date vectors
c = datevec(date_asNum(:));
    
% Get year and reformat to the same shape as input data.
s = reshape(c(:,6),size(date_asNum)); 

% from finance toolbox second.m
s = round(1000.*s)./1000;

end

