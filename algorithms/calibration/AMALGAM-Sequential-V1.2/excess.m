function [UT1,UT2,xn] = excess(x_loss,cmax,bexp,Pval,PETval);
% this function calculates excess precipitation and evaporation

xn_prev = x_loss;
ct_prev = cmax*(1-power((1-((bexp+1)*(xn_prev)/cmax)),(1/(bexp+1))));
UT1 = max((Pval-cmax+ct_prev),0.0);
Pval = Pval-UT1;
dummy = min(((ct_prev+Pval)/cmax),1);
xn = (cmax/(bexp+1))*(1-power((1-dummy),(bexp+1)));
UT2 = max(Pval-(xn-xn_prev),0);
evap = min(xn,PETval);
xn = xn-evap;

