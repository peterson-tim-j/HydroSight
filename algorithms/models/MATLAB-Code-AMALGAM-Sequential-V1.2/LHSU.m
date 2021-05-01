function x = LHSU(xmin,xmax,nsample)
% Latin Hypercube sampling

% Define the size of xmin
nvar = length(xmin);
% Initialize array ran with random numbers
ran = rand(nsample,nvar);
% Initialize array s with zeros
x = zeros(nsample,nvar);
% Now fill s
for j= 1:nvar,
    % Random permutation
    idx = randperm(nsample);
    %
    P =(idx'-ran(:,j))/nsample;
    %
    x(:,j) = xmin(j) + P.* (xmax(j)-xmin(j));
end