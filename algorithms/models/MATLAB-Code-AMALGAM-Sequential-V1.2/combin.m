function  C = combin(n,m)
% COMBIN  Combinations of N choose M.
%	C=COMBIN(M,N) where N>=M, M and N are
%	positive integers returns a matrix C of the
%	size N!/(M!*(N-M)!) by N with rows containing
%	all possible combinations of N choose M.

%  Kirill K. Pankratov,  kirill@plume.mit.edu
%  03/19/95

% Handle input ..........................
if nargin<2,
    error('  Not enough input arguments.')
end
m = fix(m(1));
n = fix(n(1));
if n<0 | m<0
    error(' In COMBIN(N,M) N and M must be positive integers')
end
if m>n
    error(' In COMBIN(N,M) N must be greater than M')
end

% Take care of simple cases .............
if m==0,   C = zeros(1,m); return, end
if m==n,   C = ones(1,m);  return, end
if m==1,   C = eye(n);     return, end
if m==n-1, C = ~eye(n);    return, end

% Calculate sizes and limits ............
n2 = 2^n-1;
m2 = 2^m-1;
mn2 = 2^(m-n)-1;

% Binary representation .................
C = binary(m2:n2-mn2);

% Now choose only those with sum equal m
s = sum(C');
C = C(find(s==m),:);


