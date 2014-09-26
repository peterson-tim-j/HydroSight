#include "math.h"
#include "mex.h"
#define MIN(x,y) (x <= y ? x : y)
#define MAX(x,y) (x <= y ? y : x)

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) 
{
    
    /* Declare input model parameters and the number of sub-daily timesteps*/
    const double  S0 = mxGetScalar( prhs[0] ), 
                  S_cap = mxGetScalar( prhs[3] ),
                  Ksat = mxGetScalar( prhs[4] ),
                  alpha = mxGetScalar( prhs[5] ),
                  beta = mxGetScalar( prhs[6] ),
                  gamma = mxGetScalar( prhs[7] );        
    
    /* Declare input data */
    const double *precip= mxGetPr( prhs[1] ), *et= mxGetPr( prhs[2] );
    
    /* Declare output data */    
    double *soilMoisture;
        
    /* Declare ODE variables */
    double soilMoisture_frac, 
           dSdt_precip, d2Sdt2_precip, dSdt_et, dSdt_drain,
           dSdt, dSdt_iprevDay;
            
    /* Declare general ODE solver variables */    
    double f_delta, f, df, relerr, abserr, funcerr;
    const double dt=1;
    const unsigned int nDays = (int)mxGetM(prhs[1] );
    unsigned int iDay;
    unsigned short its, useNewtonsMethod=1, noPrecip = 1;
    unsigned int nIterations = 0, nIterations_bisect = 0;

    /* Declare bisection solver variables */
    double fa, fb, f_prev, soilMoisture_iDay_lower, soilMoisture_iDay_upper; 

    /* Declare variables for sub-daily time step fluxes */
    double runoff_iday, actualET_iday, drainage_iday, infiltration_iday;

    /* Set constants for Newtons solver*/    
    double const absTol = 1.0e-10;
    double const funcTol = 1.0e-10;
    unsigned short const maxIts = 100;
    
    /* Create a vectors for results */
    plhs[0] = mxCreateDoubleMatrix(nDays,1,mxREAL);         
    soilMoisture = mxGetPr(plhs[0]);

    
    /*Cycle though all days within ClimateData to approximate the soil 
    moisture ode via fixed time-step explicit solver. */    
    soilMoisture[0] = S0;    
    for(iDay=1;iDay<nDays;iDay++) 
    {        
        if (precip[iDay]>0) 
            noPrecip =  0;
        else
            noPrecip = 1;

        /*Get a 1st order estimate using the explicit Euler method */	
        soilMoisture_frac = soilMoisture[iDay-1]/S_cap;
        if (noPrecip == 1) 
            dSdt_precip = 0;
        else     
            if (alpha == 1) 
                dSdt_precip = precip[iDay] * (1 - soilMoisture_frac);                
            else if (alpha == 0) 
                dSdt_precip = precip[iDay];
            else
                dSdt_precip = precip[iDay] * pow(1 - soilMoisture_frac,alpha);

        if (beta == 0 || Ksat==0 )
            dSdt_drain = 0;
        else if (beta==1)
            dSdt_drain = - Ksat * soilMoisture_frac;
        else
            dSdt_drain = - Ksat * pow(soilMoisture_frac, beta);

        if (gamma == 1)
            dSdt_et = - et[iDay] * soilMoisture_frac;            
        else if (gamma == 0)
            dSdt_et = 0;
        else
            dSdt_et = - et[iDay] * pow(soilMoisture_frac, gamma); 

        dSdt_iprevDay = dSdt_precip + dSdt_drain + dSdt_et;            
        soilMoisture[iDay] = soilMoisture[iDay-1] + dSdt_iprevDay * dt;            

        /* Limit soil moisture to >=0 and <= SMSC without use of thresholds. */
        soilMoisture[iDay] = MAX(1e-6,MIN(S_cap,soilMoisture[iDay]));

        /*Refine solution using a Newtons method */
        its = 0;
        abserr = 1.0e16;	            
        funcerr = 1.0e16;
        f = 1.0e16;

        /* Use Newton's method for the substep */
        useNewtonsMethod=1; 

        while ((abserr > absTol || funcerr > funcTol) && its<maxIts) {

            soilMoisture_frac = soilMoisture[iDay]/S_cap;

            /* Update dSdt */
            if (noPrecip == 1) 
                dSdt_precip = 0;
            else          
                if (alpha == 1) 
                    dSdt_precip = precip[iDay] * (1 - soilMoisture_frac);                
                else if (alpha == 0) 
                    dSdt_precip = precip[iDay];
                else
                    dSdt_precip = precip[iDay] * pow(1 - soilMoisture_frac,alpha);                    

            if (beta == 0  || Ksat==0 )
                dSdt_drain = 0;
            else if (beta == 1)
                dSdt_drain = - Ksat * soilMoisture_frac;
            else
                dSdt_drain = - Ksat * pow(soilMoisture_frac, beta);

            if (gamma == 1)
                dSdt_et = - et[iDay] * soilMoisture_frac;            
            else if (gamma == 0)
                dSdt_et = 0;
            else
                dSdt_et = - et[iDay] * pow(soilMoisture_frac, gamma); 

            /* Calculate numerator for Newton Raphson */
            f_prev = f;                
            f = soilMoisture[iDay] - soilMoisture[iDay-1] 
               - dt * 0.5*(dSdt_precip + dSdt_drain + dSdt_et + dSdt_iprevDay);                                                        

            /* Calculate demoninator for Newton Raphson */
            if (noPrecip == 1) 
                df = 1-dt * 0.5 * (beta * dSdt_drain + gamma * dSdt_et)/soilMoisture[iDay];                        
            else 
                if (alpha == 1)
                    d2Sdt2_precip = -precip[iDay] / S_cap;
                else if (alpha == 0) 
                    d2Sdt2_precip = 0;
                else if (alpha == 2)
                    d2Sdt2_precip = -precip[iDay] * alpha / S_cap * (1 - soilMoisture_frac);
                else
                    d2Sdt2_precip = -precip[iDay] * alpha / S_cap * pow(1 - soilMoisture_frac,alpha-1);

            df = 1-dt * 0.5 * (d2Sdt2_precip + (beta * dSdt_drain + gamma * dSdt_et)/soilMoisture[iDay]);                        


            /* Undertake Newton-Raphson iteration*/
            f_delta =  f/df;
            soilMoisture[iDay] = soilMoisture[iDay] - f_delta;

            /* Calculate errors*/                
            abserr = abs(f_delta);
            funcerr = abs(f - f_prev);      
            its++;

            /* Check if constraints have been violated. 
             * If so, prepare for switching to bosection solution */
            if (soilMoisture[iDay] >= S_cap || soilMoisture[iDay]<=0.0 ) { 

                useNewtonsMethod = 0;
                if (noPrecip==1) {
                    soilMoisture[iDay] = 0.5*S_cap;                                                                                                
                    dSdt = 0.5*(- Ksat * pow(0.5, beta) - et[iDay] * pow(0.5, gamma) +
                                dSdt_iprevDay);
                    f = soilMoisture[iDay] - soilMoisture[iDay-1] - dt*dSdt;

                    soilMoisture_iDay_lower = 0.0;
                    dSdt = 0.5 * dSdt_iprevDay;
                    fa = soilMoisture_iDay_lower - soilMoisture[iDay-1] - dt*dSdt;

                    soilMoisture_iDay_upper = S_cap;                        
                    dSdt = 0.5*(dSdt_iprevDay - Ksat - et[iDay] );
                    fb = soilMoisture_iDay_upper - soilMoisture[iDay-1] - dt*dSdt;
                }
                else {
                    soilMoisture[iDay] = 0.5*S_cap;                                                                                                
                    dSdt = 0.5*(precip[iDay] * pow(0.5,alpha)- Ksat * pow(0.5, beta) - et[iDay] * pow(0.5, gamma) +
                                dSdt_iprevDay);
                    f = soilMoisture[iDay] - soilMoisture[iDay-1] - dt*dSdt;

                    soilMoisture_iDay_lower = 0.0;
                    dSdt = 0.5*(precip[iDay] + dSdt_iprevDay);
                    fa = soilMoisture_iDay_lower - soilMoisture[iDay-1] - dt*dSdt;

                    soilMoisture_iDay_upper = S_cap;                        
                    dSdt = 0.5*(precip[iDay] * pow(0,alpha)- Ksat - et[iDay] + dSdt_iprevDay);
                    fb = soilMoisture_iDay_upper - soilMoisture[iDay-1] - dt*dSdt;                            
                }

                /* Reset error ests.*/
                abserr = 1.0e16;	
                funcerr = 1.0e16;                    

                /* Break Newton=Raphson while loop*/
                break;
            }  
        }

        if (useNewtonsMethod==0) {
            while ((abserr > absTol || funcerr > funcTol) && its<maxIts) {
            /* Undertake iteration using Bisection method*/                 
                if ( fa*f < 0.0) {
                    soilMoisture_iDay_upper = soilMoisture[iDay];                        
                    f_prev = f;
                    fb = f;
                }
                else {
                    soilMoisture_iDay_lower = soilMoisture[iDay];                        
                    f_prev = f;
                    fa =f;
                }                            
                f_delta = soilMoisture[iDay] - 0.5*(soilMoisture_iDay_upper + soilMoisture_iDay_lower);
                soilMoisture[iDay] = 0.5*(soilMoisture_iDay_upper + soilMoisture_iDay_lower);
                abserr = abs(f_delta);
                funcerr = abs(f - f_prev);

                nIterations_bisect++;

            }
            its++;                                
        }
        nIterations = nIterations + its;                     
     }
    
     plhs[1] = mxCreateDoubleScalar(nIterations);
     plhs[2] = mxCreateDoubleScalar(nIterations_bisect);
}
