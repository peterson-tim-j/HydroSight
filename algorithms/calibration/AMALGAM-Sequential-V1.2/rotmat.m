function  R = rotmat(d,th);
% Rotational (unitary) matrix.

% Component pairs ..........................
C = combin(d,2);
n = size(C,1);
[i1,i2] = find(C');
i1 = fliplr(reshape(i1,2,n));

% Angles ....................
thr = ones(n,1) * th;
thr(1:length(th)) = th;

c = cos(thr);
s = sin(thr);

R = eye(d);
for jj = 1:n
    ii = i1(:,jj);
    cc = c(jj); ss = s(jj);
    A = eye(d);
    A(ii,ii) = [cc ss; -ss cc];
    R = R*A;
end