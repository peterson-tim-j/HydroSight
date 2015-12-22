#include "math.h"
#include "mex.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) 
{    
       
    /* Declare output data*/
    double *h_ar, *h_forecast, *junk;
    
    /* Declare input time steps */
    const double *t = mxGetPr( prhs[0] );

    /* Declare input obs head */
    double *h_obs = mxGetPr( prhs[1] );

    /* Declare input vector indicating if time step is an observed head obs */
    const double *isObsTimePoints = mxGetPr( prhs[2] );

    /* Declare mean obs head */
    const double mean_h_obs = mxGetScalar(prhs[3]);    

    /* Declare mean obs head */
    const double mean_delta_t = mxGetScalar(prhs[4]);    

    /* Declare input parameters */
    const double alpha = mxGetScalar(prhs[5]);    
    const double gamma = mxGetScalar(prhs[6]);
    const double zeta = mxGetScalar(prhs[7]);
    const double initialTrend = mxGetScalar(prhs[8]);
    const double initialHead = mxGetScalar(prhs[9]);

    /* Decalre some working variables */
    int i, nTimePoints, indPrevObsTimePoint, indPrevObs;
    double q, alpha_i, gamma_i, h_trend,  delta_t, alpha_weight, gamma_weight, trend_damping, trend_damping_prev, h_ar_prev, h_obs_prev;

    nTimePoints = mxGetM(prhs[0]);
    
    /* Declare output vectors for results*/
    plhs[0] = mxCreateDoubleMatrix(nTimePoints,1,mxREAL);
    plhs[1] = mxCreateDoubleMatrix(nTimePoints,1,mxREAL);
    h_ar = mxGetPr(plhs[0]);
    h_forecast = mxGetPr(plhs[1]);

    /* Undertake smoothing */
    /* ---------------------------------------*/

    /* Initialise dynamic alpha and beta*/
    alpha_i = 1 - pow(1 - alpha,mean_delta_t);
    gamma_i = 1 - pow(1 - gamma,mean_delta_t);
            
    /* Subract the mean from the observed */
    for (i=0; i<nTimePoints; i++) {
    	h_obs[i] -= mean_h_obs;            
    }
    
    /* Assign initial tredn values */
    h_trend = initialTrend;
    h_ar[0] = initialHead;
    h_forecast[0]= h_ar[0];
    h_ar_prev = h_ar[0];             
    /* Initialise counts */
    indPrevObsTimePoint = 0;
    indPrevObs = 0;
         
    /* Undertake double exponential smoothing.
       Importantly, this can be undertaken for time-points that have observed 
       heads and those that are to be interpolated (or extrapolated). 
       The for loop cycles though each time point to be simulated.
       If the time point is an observation then the alpha, gamma and
       h_trend are updates and an index is stored pointng to the last true obs point. 
       If the time point is not an observation then a forecast is
       undertaken using the most recent values of alpha, gamma and
       h_trend */
     for(i=1; i<nTimePoints; i++) {
               
     	delta_t = (t[i]-t[indPrevObsTimePoint])/365.0;
                
        if (isObsTimePoints[i]>0.0) {
           /* Update smoothing model using the observation at the current time point.*/
           if (indPrevObs>0) {
               trend_damping_prev = trend_damping;                       
               trend_damping = zeta*(1-pow(zeta,delta_t))/(1 - zeta);
               gamma_weight = trend_damping_prev/trend_damping * pow(1-gamma,delta_t);                           
           }	
           else {                       
               gamma_weight = pow(1-gamma,delta_t);
               trend_damping = zeta*(1-pow(zeta,delta_t))/(1 - zeta);
           } 
           alpha_weight = pow(1-alpha,delta_t);
           
           alpha_i = alpha_i / (alpha_weight + alpha_i); 
           gamma_i = gamma_i / (gamma_weight + gamma_i);
           
           
           h_ar[i] = (1-alpha_i) * (h_ar_prev + delta_t * h_trend) + alpha_i * h_obs[indPrevObs+1];
           h_forecast[i] = h_ar_prev + delta_t * h_trend;
           h_trend = (1-gamma_i) * h_trend + gamma_i * (h_ar[i] - h_ar_prev) / delta_t;
                    
           h_ar_prev = h_ar[i];
           
           
           indPrevObsTimePoint = i;
           indPrevObs++;           
           
        } 
        else {
            
           h_forecast[i] = h_ar_prev + delta_t * h_trend;
           h_ar[i] = h_forecast[i];
        }
        
        
    }
               

    /* Add the mean to the outputs */
    for (i=0; i<nTimePoints; i++) {
            h_ar[i] += mean_h_obs;
            h_forecast[i] += mean_h_obs;                        
    }    
    

}