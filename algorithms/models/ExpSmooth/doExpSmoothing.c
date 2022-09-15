#include "math.h"
#include "mex.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) 
{
    /* Declare number of timesteps */
    const int nObs = mxGetScalar( prhs[0] );

    /* Declare vector input data */
    const double *time_points = mxGetPr( prhs[1] ); 
    const double *h_obs = mxGetPr( prhs[2] ); 
    const double *isObsTimePoint = mxGetPr( prhs[3] );
    
    /* Declare input model parameters and initial values*/
    const double  h_mean = mxGetScalar( prhs[4] ),
            alpha = mxGetScalar( prhs[5] ),
            gamma = mxGetScalar( prhs[6] ),
            q = mxGetScalar( prhs[7] ),
            initialHead = mxGetScalar( prhs[8] ),
            initialTrend = mxGetScalar( prhs[9] );
    
    /* Declare working variables */
    double alpha_i, gamma_i, gamma_weight, delta_t_prev, h_trend, delta_t;
    int i, indPrevObs, indPrevObsTimePoint;   
    const int TRUE = 1.0; 
    const int FALSE = 0.0; 

    /* Create a vectors for results */
    double *h_ar, *h_forecast;
    plhs[0] = mxCreateDoubleMatrix(nObs,1,mxREAL);         
    h_ar = mxGetPr(plhs[0]);
    plhs[1] = mxCreateDoubleMatrix(nObs,1,mxREAL);         
    h_forecast = mxGetPr(plhs[1]);    
    
  /* DOSMOOTHING Summary of this function goes here */
  /*  Undertake double exponential smoothing. */
  /*  Note: It is based on Cipra T. and Hanzák T. (2008). Exponential */
  /*  smoothing for irregular time series. Kybernetika,  44(3), 385-399. */
  /*  Importantly, this can be undertaken for time-points that have observed */
  /*  heads and those that are to be interpolated (or extrapolated). */
  /*  The for loop cycles though each time point to be simulated. */
  /*  If the time point is an observation then the alpha, gamma and */
  /*  h_trend are updates and an index is stored pointng to the last true obs
   * point. */
  /*  If the time point is not an observation then a forecast is */
  /*  undertaken using the most recent values of alpha, gamma and */
  /*  h_trend */
  /* --------------------------------------------------------------------------
   */
  /*  Setup time-varying weigting terms from input parameters */
  /*  and their values at t0 using ONLY the time points with */
  /*  observed head values! q = mean(delta_t); */
  alpha_i = 1.0 - pow(1.0 - alpha, q);
  gamma_i = 1.0 - pow(1.0 - gamma, q);

  /* Check inputs  
  mexPrintf("%s%d\n", "nObs:", nObs);
  mexPrintf("%s%f\n", "alpha:", alpha);
  mexPrintf("%s%f\n", "gamma:", gamma);                      
  mexPrintf("%s%f\n", "alpha_i:", alpha_i);
  mexPrintf("%s%f\n", "gamma_i:", gamma_i);
  mexPrintf("%s%f\n", "q:", q);
  mexPrintf("%s%f\n", "h_mean:", h_mean);       
  mexPrintf("%s%f\n", "initialTrend:", initialTrend);
  mexPrintf("%s%f\n", "h_obs[0]:", h_obs[0]);  
  mexPrintf("%s%f\n", "h_obs[1]:", h_obs[1]);  
  mexPrintf("%s%f\n", "h_obs[2]:", h_obs[2]);  
  mexPrintf("%s%f\n", "h_obs[3]:", h_obs[3]);          
  */


  /*  Assign linear regression estimate the initial slope and intercept. */
  /* h_trend(1) = obj.variables.initialTrend_calib; */
  /* h_trend = obj.variables.initialTrend_calib; */
  h_trend = initialTrend;
  h_ar[0] = initialHead - h_mean;
  h_forecast[0] = h_ar[0];

  /* Loop through each timestep */  
  indPrevObsTimePoint = 0;
  indPrevObs = 0;
  delta_t_prev = 0.0;
  for (i = 1; i < nObs; i++) {

    delta_t = (time_points[i] - time_points[indPrevObsTimePoint])/365.0;

    /* Check start of iteration  
    mexPrintf("%s%d\n", "i:", i);
    mexPrintf("%s%f\n", "delta_t:", delta_t);
    mexPrintf("%s%d\n", "isObsTimePoint[i]:", isObsTimePoint[i]);
    */

    /* Make a forecast of the current time point using the most recent update 
    /* of the trend and the most recent observation. Note, a forecast is made 
    at every time point, even when the time point is an observation, because 
    when this function is called by outlierDetection.m a forecast estimate is
    required for every observation. That is, is the forecast estimate is more 
    that a user defined number of standard deviations from the observed, then
    the observed value is deemed an outlier.*/
    h_forecast[i] = h_ar[indPrevObsTimePoint] + delta_t * h_trend;

    /*  If the current time point is an observation, then update smoothing 
    model using the observation and estimate the smoothed value (h_ar[]) 
    for the current time point. If the time point is not an observation,
    the forecast estimate is used */
    if (isObsTimePoint[i]==TRUE) {
        if (indPrevObs==0) {
            gamma_weight = pow(1.0 - gamma, delta_t);
        } else {
            gamma_weight = delta_t_prev / delta_t * pow(1.0 - gamma, delta_t);
        }

      alpha_i /= pow(1.0 - alpha, delta_t) + alpha_i;
      gamma_i /= gamma_weight + gamma_i;

      /* Check variable
      mexPrintf("%s%f\n", "alpha_i:", alpha_i);
      mexPrintf("%s%f\n", "gamma_i:", gamma_i);
      mexPrintf("%s%f\n", "delta_t:", delta_t);
      mexPrintf("%s%f\n", "h_trend:", h_trend);
      mexPrintf("%s%f\n", "h_obs[indPrevObs + 1]:", h_obs[indPrevObs + 1]);
      mexPrintf("%s%f\n", "h_ar[indPrevObsTimePoint]:", h_ar[indPrevObsTimePoint]);  
      */

      h_ar[i] = (1.0 - alpha_i) * (h_ar[indPrevObsTimePoint] + delta_t * h_trend) +
          alpha_i * (h_obs[indPrevObs + 1] - h_mean);
                
      h_trend = (1.0 - gamma_i) * h_trend + gamma_i * (h_ar[i]
                     - h_ar[indPrevObsTimePoint]) / delta_t;

      indPrevObsTimePoint = i;
      indPrevObs++;
      delta_t_prev = delta_t;

      /* Check results
      mexPrintf("%s%f\n", "h_ar[i]:", h_ar[i]);
      mexPrintf("%s%f\n", "h_forecast[i]:", h_forecast[i]);
      mexPrintf("%s%f\n", "h_trend new:", h_trend);
      */
    } else {
      /*  Set the estimate for the time point to the forecast estimate. */      
      h_ar[i] = h_forecast[i];
    }
  }

  /*  Add the mean head onto the smoothed estimate. */
  for (i = 0; i < nObs; i++) {
    h_ar[i] += h_mean;
    h_forecast[i] += h_mean;
  }
    
}
