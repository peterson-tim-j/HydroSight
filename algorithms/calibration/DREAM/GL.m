function [logL,a,fa,ExpY,SimY] = GL(iflag,statpar,ModY,ObsY)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Log-likelihood and simulation of regression models with correlated, heteroscedastic and non-Gaussian errors
%
%Regression model:
%1. Expected values: simulated using an external function (name specified by modname), with optional bias correction
%2. Residual standard deviations: modeled as a linear function of expected values
%3. Residual higher-order moments: modeled by Skew Exponential Power (SEP) distribution
%4. Residual correlations: modeled by autoregressive (AR) time-series model (implemented up to order 4)
%
%Reference: Schoups, G. and J.A. Vrugt (2010), A Formal Likelihood Function for Parameter and Predictive Inference 
%                of Hydrologic Models with Correlated, Heteroscedastic and Non-Gaussian Errors, WRR, in press.
%
%INPUT
%iflag      flag for estimation ('est') or simulation ('sim')
%statpar    column vector of statistical model parameters
%ModY       column vector of modeled response variables from deterministic model
%ObsY       column vector of observed response values
%
%OUTPUT
%logL       log-likelihood function value
%a          column vector of i.i.d. errors distributed as SEP(0,1,xi,beta)
%fa         column vector with density values of errors a
%ExpY       column vector of expected values of response variables (after optional bias correction)
%SimY       column vector of simulated values of response variables (incl. simulated residuals)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Separate deterministic and statistical parameters
%detpar = par(1:end-11);
%statpar = par(end-10:end);
std0 = statpar(1);      %intercept of linear heteroscedastic model
std1 = statpar(2);      %slope of linear heteroscedastic model
beta = statpar(3);      %kurtosis parameter (-1: uniform, 0: normal; 1: Laplace)
xi = statpar(4);        %skewness parameter (1: symmetric; <1: negative skew; >1: positive skew)
mu1 = statpar(5);       %parameter for bias correction
phi1 = statpar(6);      %first-order autoregressive coefficient
phi2 = statpar(7);      %second-order autoregressive coefficient
phi3 = statpar(8);      %third-order autoregressive coefficient
phi4 = statpar(9);      %fourth-order autoregressive coefficient
K = statpar(10);        %Box-Cox transformation parameter (skewness)
lambda = statpar(11);   %Box-Cox transformation parameter (heteroscedasticity)

%EXPECTED VALUES
%evalstr = ['[States_out,ModY] = ',modname,'(States_in,detpar,BC,specs);']; eval(evalstr);
%ModY = ModY(idx);
N = size(ModY,1);
ExpY = ModY.*min(10,exp(mu1.*ModY));    %bias

%STANDARD DEVIATIONS
std_e = max(1e-6,std1.*ExpY + std0);

%KURTOSIS AND SKEWNESS (SEP parameters)
A1 = gamma(3*(1+beta)/2);
A2 = gamma((1+beta)/2);
Cb = (A1/A2)^(1/(1+beta));
Wb = sqrt(A1)/((1+beta)*(A2^(1.5)));
M1 = gamma(1+beta)/sqrt(A1*A2);
M2 = 1; mu_xi = M1*(xi-1/xi);
sig_xi = sqrt((M2-M1^2)*(xi^2 + 1/xi^2) + 2*M1^2 - M2);

%CORRELATION
phi_p = [1 -phi1 -phi2 -phi3 -phi4];     %coefficients of AR polynomial

%ESTIMATION: compute log-likelihood (always do this)
SimY = [];
%Residuals (e)
e = ((ObsY+K).^lambda - 1)./lambda - ((ExpY+K).^lambda - 1)./lambda;
%i.i.d. errors (a)
a = filter(phi_p,1,e);
a = a./std_e;
%Log-likelihood
a_xi = (mu_xi + sig_xi.*a)./(xi.^sign(mu_xi + sig_xi.*a));
logL = N.*log(Wb*2*sig_xi/(xi+1/xi)) - sum(log(std_e)) - Cb.*(sum(abs(a_xi).^(2./(1+beta))));
logL = logL + (lambda-1)*sum(ObsY+K);
%Density of a
fa = (2*sig_xi/(xi + 1/xi))*Wb.*exp(-Cb.*(abs(a_xi).^(2/(1+beta))));

%SIMULATION: generate response variables (SimY)
switch iflag
    case 'sim'
        rand('seed',sum(100*clock));    %initialize random number generators
        %Generate N i.i.d. errors (a) from skew exponential power distribution, SEP(0,1,xi,beta)
        %Step 1 - Generate N random variates from gamma distribution with shape parameter 1/p and scale parameter 1
        p = 2/(1+beta);
        grnd = gamrnd(1/p,ones(N,1));
        %Step 2 - Generate N random signs (+1 or -1) with equal probability
        signrnd = sign(rand(N,1)-0.5);
        %Step 3 - Compute N random variates from EP(0,1,beta)
        EP_rnd = signrnd.*(abs(grnd).^(1/p)).*sqrt(gamma(1/p))./sqrt(gamma(3/p));
        %Step 4 - Generate N random signs (+1 or -1) with probability 1-w and w
        w = xi/(xi+1/xi);
        signrndw = sign(rand(N,1)-w);
        %Step 5 - Compute N random variates from SEP(mu_xi,sig_xi,xi,beta)
        SEP_rnd = -signrndw.*abs(EP_rnd)./(xi.^signrndw);
        %Step 6 - Normalize to obtain N random variates from SEP(0,1,xi,beta)
        a = (SEP_rnd-mu_xi)./sig_xi;
        %Residuals (e)
        e = filter(1,phi_p,std_e.*a);
        %Simulated values, assumption: E[g^-1(Y)] = g^-1(E[Y]) where g = Box-Cox transformation
        SimY = (lambda.*(((ExpY+K).^lambda - 1)./lambda + e) + 1).^(1/lambda) - K;
end

end
