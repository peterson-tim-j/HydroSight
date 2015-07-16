#include "math.h"
#include "mex.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) 
{    
    /* Declare cbonstants for matrix size */
    const unsigned int nTheta  = (unsigned int)mxGetM(prhs[0] ), nIndex = (unsigned int)mxGetN(prhs[1]);    
       
    /* Declare output data*/
    double *result;
    
    /* Declare impulse response fuction vector and input forcing*/
    double *theta  = mxGetPr( prhs[0] );
    
    /* Declare vector of starting rows for transforming theta to matrix for all start dates */
    const double *theta_indexes_start = mxGetPr( prhs[1] );
            
    /* Declare vector of ending rows for transforming theta to matrix for all start dates */
    const unsigned int theta_indexes_end = (unsigned int)mxGetScalar(prhs[2]) + 1;        
     
    /* Declare input forcing*/    
    double *forcing = mxGetPr( prhs[3] );
    
    /* Get the flag for the type of integration to undertake:
     * 0: Trapazoidal integration for focing that is an integral of the daily flux (eg pecip).
     * 1: Simpsons 3/8 composite integration for continuous forcing eg free-drainage from the soil model. */
    const unsigned int isForcingAnIntegral = (unsigned int)mxGetScalar(prhs[4]);    
   
    /* Get the high precision estimate of the integral of the theta function 
     * from 0 to 1. To derive this convolution with the forcing, the mean 
     * forcing over the first day is adopted. */
    const double inteTheta_0to1 = mxGetScalar(prhs[5]);    
    
    /* Decalre some working variables */
    unsigned int iIndex;
    int nTheta_tmp;

    /* Declare integration functions */
    double trapazoidal(const int *n, const double *dx, const double *dy, const double *intTheta);
    double Simpsons_3_8(const int *n, const double *dx, const double *dy, const double *intTheta);
   
    /* Declare output vectors for results*/
    plhs[0] = mxCreateDoubleMatrix(1,nIndex,mxREAL);
    result = mxGetPr(plhs[0]);
    
    /*Cycle though all theta tiem points and create matrix of theta values.   */  
    
    if (isForcingAnIntegral==1 )     
        for(iIndex=nIndex; iIndex--;) {
            nTheta_tmp = (int)(theta_indexes_end - theta_indexes_start[iIndex]);
            result[iIndex] = trapazoidal(&nTheta_tmp, theta + (int)theta_indexes_start[iIndex]- 1, forcing, &inteTheta_0to1);        
        }  
    else 
        for(iIndex=nIndex; iIndex--;) {
            nTheta_tmp = (int)(theta_indexes_end - theta_indexes_start[iIndex]);
            result[iIndex] = Simpsons_3_8(&nTheta_tmp, theta + (int)theta_indexes_start[iIndex]- 1, forcing, &inteTheta_0to1);
        }  

}


/* Integration using the Trapazoidal rule under the assumption that the
 * forcing is the integral over the day.
 * NOTE: Adapted from BLAS ddot function written by Jan Simon and obtained from 
 * http://www.mathworks.com/matlabcentral/answers/29678-fastest-way-to-dot-product-all-columns-of-two-matricies-of-same-size
*/
double trapazoidal(const int *n, const double *dx, const double *dy, const double *intTheta)
{
    #define EPSILON 2.2204460492503131e-16

            
    int i, m, mp1, endIndex;
    double ret_val, dtemp, delta;

    /* Set the index to the last element */
    endIndex = *n - 1;
    
    /* Use high precision estimate over the first time step */
    /*dtemp =  0;*/
    dtemp =  2 * *intTheta * dy[endIndex];
    
    for (i = 1; i <= *n; i++)
        dtemp = dtemp + (dx[endIndex-i] + dx[endIndex-i-1]) * dy[endIndex-i];
        /*dtemp = dtemp + dx[endIndex-i] * dy[endIndex-i];*/
            
    
    /*ret_val = dtemp;*/
    ret_val = 0.5*dtemp;
    return ret_val;
} /* ddot_ */


/* Integration using Simpson's 3.8 rule
*/
double Simpsons_3_8(const int *n, const double *dx, const double *dy, const double *intTheta)
{
    #define EPSILON 2.2204460492503131e-16
            
    int i, m, mp1, endIndex;
    double ret_val, dtemp, delta;
    
    /* Set the index to the last element */
    endIndex = *n - 1;

    /* Integrate first term of Simpson's 3/8 compiste rule
     NOTE: This is from t=1. The integration from 0 to 1 is
     undertaken after the Simpson's integration. */
    dtemp = dx[endIndex-1] * dy[endIndex-1];
    
    /* Check if the "number of rows -2" are multiplire of 3 */
    m = (endIndex-1) % 3;
        
    /* Calculate internal triples repeating sequance for Simpon's 3/8 composire rule */
    for (i = 2; i < *n - 3 - m; i += 3)
        dtemp = dtemp + 3. * dx[endIndex-i]* dy[endIndex-i] + 
                3. * dx[endIndex-i-1] * dy[endIndex-i-1] + 
                2. * dx[endIndex-i-2] * dy[endIndex-i-2];

    /* Calculate last term of Simpson's 3/8 compiste rule*/
    i = i + 3;
    dtemp = 3./8.*(dtemp + dx[endIndex-i] * dy[endIndex-i]);
    
    /* Use high precision estimate over the first time step */
    dtemp =  dtemp + *intTheta * 0.5 * (dy[endIndex] + dy[endIndex-1]);
            
    /* Calculate integration for any remaining points */
    if (i == *n - 3 - m && m!=0) {
        if (m==1)  /* Do trapazoidal integration on last point */      
            dtemp = dtemp + dx[endIndex-i] * dy[endIndex-i] +  dx[endIndex-i-1]* dy[endIndex-i-1];
        else /* Do standard Simpson's integration on last 2 points */
            dtemp = dtemp + 1./.3 * ( dx[endIndex-i] * dy[endIndex-i] +  4. * dx[endIndex-i-1] * dy[endIndex-i-1] + dx[endIndex-i-2] * dy[endIndex-i-2]);
    }

    ret_val = dtemp;
    return ret_val;
} /* Simpsons_3_8 */

