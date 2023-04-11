/* Compile using Intel oneAPI. To ensure vectorisation use the following compile command:
   mex -v COMPFLAGS='$COMPFLAGS /Qopenmp /Qopenmp-simd /Qopt-report-phase:vec /Qopt-report=5 /Qopt-report-file:stdout /Qrestrict' OPTIMFLAGS='/O3 /DNDEBUG' forcingTransform_soilMoisture_RK.c
*/

#ifdef __INTEL_COMPILER
#include "mathimf.h"
#else
#include "math.h"
#endif
#include "mex.h"
#include "omp.h"

#pragma omp declare simd 
double dSdt_fn(const double S, const double precip, const double et, const double S_cap, const double ksat,const double alpha, const double beta, const double gamma, const double eps) {    
    const double Sfrac = fmax(1.0e-6,fmin(S/S_cap,1.0));
    return (precip * fmin(1.0, powr( (1-Sfrac) * eps,alpha)) - ksat * powr(Sfrac,beta) - et * powr(Sfrac ,gamma));    
}
#pragma omp declare simd 
double dSdt_fn_alpha1_eps_gamma1(const double S, const double precip, const double et, const double S_cap, const double ksat, const double beta, const double eps) {    
    const double Sfrac = fmax(1.0e-6,fmin(S/S_cap,1.0));
    return (precip * fmin(1.0, (1-Sfrac) * eps) - ksat * powr(Sfrac,beta) - et * Sfrac);    
}
#pragma omp declare simd 
double dSdt_fn_alpha1_eps_gamma(const double S, const double precip, const double et, const double S_cap, const double ksat, const double beta, const double gamma, const double eps) {    
    const double Sfrac = fmax(1.0e-6,fmin(S/S_cap,1.0));
    return (precip * fmin(1.0, (1-Sfrac) * eps) - ksat * powr(Sfrac,beta) - et * powr(Sfrac,gamma));    
}
#pragma omp declare simd 
double dSdt_fn_alpha0_gamma1(const double S, const double precip, const double et, const double S_cap, const double ksat, const double beta) {    
    const double Sfrac = fmax(1.0e-6,fmin(S/S_cap,1.0));
    return (precip - ksat * powr(Sfrac,beta) - et * Sfrac);    
}
#pragma omp declare simd 
double dSdt_fn_alpha0_gamma(const double S, const double precip, const double et, const double S_cap, const double ksat, const double beta, const double gamma) {    
    const double Sfrac = fmax(1.0e-6,fmin(S/S_cap,1.0));
    return (precip - ksat * powr(Sfrac,beta) - et * powr(Sfrac,gamma) );    
}

/*
void snowStore(double *snow, double *precip, double temp, double melt_threshold, double DDF) {
    double melt;
    if (temp <= melt_threshold) {
        *snow = *snow + *precip;
        *precip = 0.0;
    } else {
        melt = DDF*(temp - melt_threshold);
        *precip = *precip + MIN(*snow, melt);
        *snow = MAX(*snow - melt,0.0);        
    }
}
*/
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) 
{
    
    /* Declare input model parameters and the number of sub-daily timesteps*/
    const double  *restrict S0 = mxGetPr( prhs[0] ), 
                  *restrict S_cap = mxGetPr( prhs[4] ),
                  *restrict Ksat = mxGetPr( prhs[5] ),
                  *restrict alpha = mxGetPr( prhs[6] ),
                  *restrict beta = mxGetPr( prhs[7] ),
                  *restrict gamma = mxGetPr( prhs[8] ),				   
                  DDF = mxGetScalar( prhs[10] ),
                  melt_threshold = mxGetScalar( prhs[11] );
    double *restrict eps = mxGetPr( prhs[9] );

    /* Declare input data */
    double *restrict precip= mxGetPr( prhs[1] );
    const double *restrict et= mxGetPr( prhs[2] ), *temp= mxGetPr( prhs[3] );
     
    /* Declare output data */    
    double *restrict soilMoisture;
        
    /* Declare ODE variables */
    //double snow, k1, k2;
    int iParam;
            
    /* Declare general ODE solver variables */    
    const int nDays = (int)mxGetM(prhs[1] );
    const int nParam = (int)mxGetN(prhs[4] );
    const bool isS_capScaler = (int)mxGetN(prhs[4])==1;
    const bool isKsatScaler = (int)mxGetN(prhs[5])==1;
    const bool isAlphaScaler = (int)mxGetN(prhs[6])==1;
    const bool isBetaScaler = (int)mxGetN(prhs[7])==1;
    const bool isGammaScaler = (int)mxGetN(prhs[8])==1;
    const bool isEpsScaler = (int)mxGetN(prhs[9])==1;   
    int hasSnow;;

    /* Create a vectors for results */
    plhs[0] = mxCreateDoubleMatrix((mwSize)nParam,(mwSize)nDays,mxREAL);         
    soilMoisture = mxGetPr(plhs[0]);
    __assume_aligned(soilMoisture, sizeof(double));
    memcpy(soilMoisture, S0, sizeof(double)*nParam);

    hasSnow = 0;
    if (isfinite(DDF) && isfinite(melt_threshold)) {
        hasSnow = 1;
    } 

    // Reformulate eps to eliminate a division within inner loop.
    if (isEpsScaler) {
        *eps = 1.0/(1.0 - *eps);
    } else {
        for (iParam=0;iParam<nParam;iParam++) {
            eps[iParam] = 1.0/(1.0 - eps[iParam]);
        }
    }

    if (isAlphaScaler && isGammaScaler && isEpsScaler && !isBetaScaler && !isS_capScaler && !isKsatScaler) {
        if (*alpha==1.0) {
            if (*gamma==1.0) {
                //mexPrintf("Testing alpha=1, gamma=1\n");
                for(int iDay=1;iDay<nDays;iDay++) {
                    const double P = precip[iDay], PET = et[iDay];

                    #pragma vector aligned
                    #pragma omp simd
                    for (iParam=0;iParam<nParam;iParam++) {
                        const int ind = (iDay-1)*nParam + iParam;
                        const double k1 = dSdt_fn_alpha1_eps_gamma1(soilMoisture[ind], P , PET, S_cap[iParam], Ksat[iParam], beta[iParam], *eps);
                        const double k2 = dSdt_fn_alpha1_eps_gamma1(soilMoisture[ind]+k1*0.66666666, P, PET, S_cap[iParam], Ksat[iParam], beta[iParam], *eps);
                        soilMoisture[iDay*nParam + iParam] = fmax(1.0e-6,fmin(S_cap[iParam], soilMoisture[ind] + (0.25*k1 + 0.75*k2)));
                    }
                }
            } else {
               // mexPrintf("Testing alpha=1, gamma!=1\n");
                for(int iDay=1;iDay<nDays;iDay++) {
                    const double P = precip[iDay], PET = et[iDay];

                    #pragma vector aligned
                    #pragma omp simd
                    for (iParam=0;iParam<nParam;iParam++) {
                        const int ind = (iDay-1)*nParam + iParam;
                        const double k1 = dSdt_fn_alpha1_eps_gamma(soilMoisture[ind], P , PET, S_cap[iParam], Ksat[iParam], beta[iParam], *gamma, *eps);
                        const double k2 = dSdt_fn_alpha1_eps_gamma(soilMoisture[ind]+k1*0.66666666, P, PET, S_cap[iParam], Ksat[iParam], beta[iParam], *gamma, *eps);
                        soilMoisture[iDay*nParam + iParam] = fmax(1.0e-6,fmin(S_cap[iParam], soilMoisture[ind] + (0.25*k1 + 0.75*k2)));
                    }
                }
            }
        } else if (*alpha==0.0) {  
            if (*gamma==1.0) {
                //mexPrintf("Testing alpha=0, gamma=1\n");
                for(int iDay=1;iDay<nDays;iDay++) {
                    const double P = precip[iDay], PET = et[iDay];

                    #pragma vector aligned
                    #pragma omp simd
                    for (iParam=0;iParam<nParam;iParam++) {
                        const int ind = (iDay-1)*nParam + iParam;
                        const double k1 = dSdt_fn_alpha0_gamma1(soilMoisture[ind], P , PET, S_cap[iParam], Ksat[iParam], beta[iParam]);
                        const double k2 = dSdt_fn_alpha0_gamma1(soilMoisture[ind]+k1*0.66666666, P, PET, S_cap[iParam], Ksat[iParam], beta[iParam]);
                        soilMoisture[iDay*nParam + iParam] = fmax(1.0e-6,fmin(S_cap[iParam], soilMoisture[ind] + (0.25*k1 + 0.75*k2)));
                    }
                }
            } else {
                //mexPrintf("Testing alpha=0, gamma!=1\n");
                for(int iDay=1;iDay<nDays;iDay++) {
                    const double P = precip[iDay], PET = et[iDay];

                    #pragma vector aligned
                    #pragma omp simd
                    for (iParam=0;iParam<nParam;iParam++) {
                        const int ind = (iDay-1)*nParam + iParam;
                        const double k1 = dSdt_fn_alpha0_gamma(soilMoisture[ind], P , PET, S_cap[iParam], Ksat[iParam], beta[iParam], *gamma);
                        const double k2 = dSdt_fn_alpha0_gamma(soilMoisture[ind]+k1*0.66666666, P, PET, S_cap[iParam], Ksat[iParam], beta[iParam], *gamma);
                        soilMoisture[iDay*nParam + iParam] = fmax(1.0e-6,fmin(S_cap[iParam], soilMoisture[ind] + (0.25*k1 + 0.75*k2)));
                    }
                }
            }
        } else {
            //mexPrintf("Testing alpha!=1, gamma!=1\n");
            for(int iDay=1;iDay<nDays;iDay++) {
                const double P = precip[iDay], PET = et[iDay];

                #pragma vector aligned
                #pragma omp simd
                for (iParam=0;iParam<nParam;iParam++) {
                    const int ind = (iDay-1)*nParam + iParam;
                    const double k1 = dSdt_fn(soilMoisture[ind], P , PET, S_cap[iParam], Ksat[iParam], *alpha, beta[iParam], *gamma, *eps);
                    const double k2 = dSdt_fn(soilMoisture[ind]+k1*0.66666666, P, PET, S_cap[iParam], Ksat[iParam], *alpha, beta[iParam], *gamma, *eps);
                    soilMoisture[iDay*nParam + iParam] = fmax(1.0e-6,fmin(S_cap[iParam], soilMoisture[ind] + (0.25*k1 + 0.75*k2)));
                }
            }
        }
    } else if (isAlphaScaler && isGammaScaler && isEpsScaler && isBetaScaler && isS_capScaler && isKsatScaler) {
        for(int iDay=1;iDay<nDays;iDay++) {
            const double k1 = dSdt_fn(soilMoisture[iDay-1], precip[iDay] , et[iDay], *S_cap, *Ksat, *alpha, *beta, *gamma, *eps);
            const double k2 = dSdt_fn(soilMoisture[iDay-1]+k1*0.66666666, precip[iDay] , et[iDay], *S_cap, *Ksat, *alpha, *beta, *gamma, *eps);
            soilMoisture[iDay] = fmax(1.0e-6,fmin(*S_cap, soilMoisture[iDay-1] + (0.25*k1 + 0.75*k2)));
        }
    } else if (!isAlphaScaler && !isGammaScaler && !isEpsScaler && !isBetaScaler && !isS_capScaler && !isKsatScaler) {

        for(int iDay=1;iDay<nDays;iDay++) {
            const double P = precip[iDay], PET = et[iDay];

            #pragma vector aligned
            #pragma omp simd
            for (iParam=0;iParam<nParam;iParam++) {
                const int ind = (iDay-1)*nParam + iParam;
                const double k1 = dSdt_fn(soilMoisture[ind], P , PET, S_cap[iParam], Ksat[iParam], alpha[iParam], beta[iParam], gamma[iParam], eps[iParam]);
                const double k2 = dSdt_fn(soilMoisture[ind]+k1*0.66666666, P, PET, S_cap[iParam], Ksat[iParam], alpha[iParam], beta[iParam], gamma[iParam], eps[iParam]);
                soilMoisture[iDay*nParam + iParam] = fmax(1.0e-6,fmin(S_cap[iParam], soilMoisture[ind] + (0.25*k1 + 0.75*k2)));
            }
        }
    } else {
        mexErrMsgIdAndTxt("forcingTransform_soilMoisture:InputDataError","Incompatible set of vector and scaler model parameters.");
    }
    

     plhs[1] = mxCreateDoubleScalar(nDays);
     plhs[2] = mxCreateDoubleScalar(0);
}
