function x = LHS(minn,maxn,N)
% Latin Hypercube sampling

% Initialize array ran with random numbers
y = rand(N,size(minn,2));

% Initialize x with zeros
x = zeros(N,size(minn,2));

% Create x values
for j = 1: size(minn,2)
    
    % Random permutation of N samples
    idx = randperm(N);
    
    % Create P
    P =(idx' - y(:,j))/N;
    
    % Now create x values
    x(:,j) = minn(j) + P.* (maxn(j) - minn(j));

end