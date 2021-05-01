function b = binary(x)

% BINARY  Binary representation of decimal integers.
%	B=BINARY(X) Returns matrx B with rows
%	representing binary form of each element of
%	vector X.

%  Kirill K. Pankratov, kirill@plume.mit.edu
%  03/02/95

x = x(:);

m2 = nextpow2(max(x));
v2 = 2.^(0:m2);
b = zeros(length(x),m2);
af = x-floor(x);

for jj = m2:-1:1
    a = x>=v2(jj);
    x = x-a*v2(jj);
    b(:,m2-jj+1) = a+1/2*(af>1/v2(jj));
end

