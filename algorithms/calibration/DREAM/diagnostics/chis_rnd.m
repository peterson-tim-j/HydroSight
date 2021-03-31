function rn=chis_rnd(nn,v)
% PURPOSE: generates random chi-squared deviates
%---------------------------------------------------
% USAGE:   rchi = chis_rnd(n,v)
% where:   n = a scalar for the size of the vector to be generated
%              or n(1) = nrows, n(2) = ncols for a matrix to be generated
%          v = the degrees of freedom
% RETURNS: n-vector with mean=v, variance=2*v
%          or matrix nrows x ncols if n(1) and n(2) input arguments used
% --------------------------------------------------
% SEE ALSO: chis_d, chis_inv, chis_cdf, chis_pdf
% --------------------------------------------------

% This is hack of code by
%	Gordon K Smyth, University of Queensland, gks@maths.uq.edu.au
%   to make the routine compatible with the needs of the
%   Econometrics Toolbox
% documentation modified by LeSage to
% match the format of the econometrics toolbox

%	Gordon K Smyth, University of Queensland, gks@maths.uq.edu.au
%	9 Dec 1999

%	Reference:  Johnson and Kotz (1970). Continuous Univariate
%	Distributions, Volume I. Wiley, New York.

rn = zeros(nn,1);
for i=1:nn,
    rn(i,1) = 2*gammar1(v/2);
end


function gam=gammar1(a);
%GAMMAR1 Generates a gamma random deviate.
%	GAMMAR(A) is a random deviate from the standard gamma
%	distribution with shape parameter A.  A must be a scalar.
%
%	B*GAMMAR(A) is a random deviate from the gamma distribution
%	with shape parameter A and scale parameter B.  The distribution
%	then has mean A*B and variance A*B^2.
%
%	See GAMMAP, GAMMAQ, RAND.

% GKS 31 July 93

% Algorithm for A >= 1 is Best's rejection algorithm XG
% Adapted from L. Devroye, "Non-uniform random variate
% generation", Springer-Verlag, New York, 1986, p. 410.

% Algorithm for A < 1 is rejection algorithm GS from
% Ahrens, J.H. and Dieter, U. Computer methods for sampling
% from gamma, beta, Poisson and binomial distributions.
% Computing, 12 (1974), 223 - 246.  Adapted from Netlib
% Fortran routine.

a = a(1);
if a < 0,
    gam = NaN;
elseif a == 0,
    gam = 0;
elseif a >= 1,
    b = a-1;
    c = 3*a-0.75;
    accept = 0;
    while accept == 0,
        u = rand(2,1);
        w = u(1)*(1-u(1));
        y = sqrt(c/w)*(u(1)-0.5);
        gam = b+y;
        if gam >= 0,
            z = 64*w^3*u(2)^2;
            accept = ( z<=1-2*y^2/gam );
            if accept == 0,
                if b == 0,
                    accept = ( log(z)<=-2*y );
                else
                    accept = ( log(z)<=2*(b*log(gam/b)-y) );
                end;
            end;
        end;
    end;
else
    aa = 0;
    b = 1 + .3678794*a;
    accept = 0;
    while accept == 0,
        p = b*rand(1);
        if p < 1,
            gam = exp(log(p)/a);
            accept = (-log(rand(1)) >= gam);
        else
            gam = -log((b-p)/a);
            accept = (-log(rand(1)) >= (1-a)*log(gam));
        end;
    end;
end;