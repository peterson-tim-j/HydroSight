/* doIRFconvolution - is a very computationally efficient numerical integration routine.
 * It can be compiled to use Intel Xeon Phi Coprocessors with the commands below.
 * Importantly, the paths have been defined. Edit for your versions of the intel compiler
 * (which must be >=2013.1) and mtalab.
 * 
 *
 * Load compiled (only required on a PBS cluster where code is to be compiled)
 * Also, edit for the required version of intel icc compiler
      module load intel/2013.1
   

 * Intel compiler commands for compiling with offload
      cp doIRFconvolution.c doIRFconvolutionPhi.c
      icc -c -offload -restrict -I/usr/local/matlab/R2014a/extern/include -I/usr/local/matlab/R2014a/simulink/include -DMATLAB_MEX_FILE -ansi -D_GNU_SOURCE  -fexceptions -fPIC -fno-omit-frame-pointer -pthread -std=c99 -fopenmp  -DMX_COMPAT_32 -O3 -DNDEBUG  "doIRFconvolutionPhi.c"
      icc -O3 -pthread -shared -Wl,--version-script,/usr/local/matlab/R2014a/extern/lib/glnxa64/mexFunction.map -Wl,--no-undefined -fopenmp -o  "doIRFconvolutionPhi.mexa64"  doIRFconvolutionPhi.o  -Wl,-rpath-link,/usr/local/matlab/R2014a/bin/glnxa64 -L/usr/local/matlab/R2014a/bin/glnxa64 -lmx -lmex -lmat -lm -lstdc++ -Wl,-rpath,/usr/local/intel/2013.1/composer_xe_2013_sp1.2.144/compiler/lib/intel64 -lintlc
      rm doIRFconvolutionPhi.c

 * Intel compiler commands for compiling with NO offload
      icc -c -no-offload -I/usr/local/matlab/R2014a/extern/include -I/usr/local/matlab/R2014a/simulink/include -DMATLAB_MEX_FILE -ansi -D_GNU_SOURCE  -fexceptions -fPIC -fno-omit-frame-pointer -pthread -std=c99 -fopenmp  -DMX_COMPAT_32 -O3 -DNDEBUG  "doIRFconvolution.c"
      icc -O3 -pthread -shared -static-intel -openmp-link=static -Wl,--version-script,/usr/local/matlab/R2014a/extern/lib/glnxa64/mexFunction.map -Wl,--no-undefined -fopenmp -o  "doIRFconvolution.mexa64"  doIRFconvolution.o  -Wl,-rpath-link,/usr/local/matlab/R2014a/bin/glnxa64 -L/usr/local/matlab/R2014a/bin/glnxa64 -lmx -lmex -lmat -lm -lstdc++ -Wl,-rpath,/usr/local/intel/2013.1/composer_xe_2013_sp1.2.144/compiler/lib/intel64 -lintlc -liomp5
   

 * Additionally, to run Xeon Phi jobs on a cluster the following commands
 * will most likely be required prior to running the job:
      source /usr/local/intel/2013.1/composer_xe_2013_sp1.2.144/bin/compilervars.sh intel64; 
      module load matlab/R2014a; 

 * To monitor Xeon Phi usage, the following command is also useful: micsmc
*/


#include "math.h"
#include "mex.h"
#include "time.h"
#if defined(__INTEL_COMPILER) && defined(__INTEL_OFFLOAD)
    #include "offload.h"
    #define ALLOC alloc_if(1)
    #define FREE free_if(1)
    #define RETAIN free_if(0)
    #define REUSE alloc_if(0)    
#endif

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) 
{    
    /* Declare constants for matrix size and index counter */
    const int nTheta  = (int)mxGetM(prhs[0] );
    const int nIndex = (int)mxGetN(prhs[1]);    
    int iIndex;
    
    /* Declare output data*/
    double *result;
    
    /* Declare impulse response fuction vector and input forcing*/
    double *theta  = mxGetPr( prhs[0] );
    
    /* Declare vector of starting rows for transforming theta to matrix for all start dates */
    double *theta_indexes_start = mxGetPr( prhs[1] );
            
    /* Declare vector of ending rows for transforming theta to matrix for all start dates */
    const int theta_indexes_end = (int)mxGetScalar(prhs[2]) + 1;        
     
    /* Declare input forcing*/    
    double *forcing = mxGetPr( prhs[3] );
    const int nForcing = (int)mxGetM(prhs[3] );
    
    /* Get the flag for the type of integration to undertake:
     * 0: Trapazoidal integration for focing that is an integral of the daily flux (eg pecip).
     * 1: Simpsons 3/8 composite integration for continuous forcing eg free-drainage from the soil model. */
    const int isForcingAnIntegral = (int)mxGetScalar(prhs[4]);    
   
    /* Get the high precision estimate of the integral of the theta function 
     * from 0 to 1. To derive this convolution with the forcing, the mean 
     * forcing over the first day is adopted. */
    const double inteTheta_0to1 = mxGetScalar(prhs[5]);    
    
#if defined(__INTEL_COMPILER) && defined(__INTEL_OFFLOAD)
   /* Delacre offloaded functions */
   __declspec(target(mic:coprocessorNum))  double trapazoidal(const int theta_index_start, const int theta_index_end, const double *dx, const double *dy, const double *intTheta);
   __declspec(target(mic:coprocessorNum))  double Simpsons_3_8(const int theta_index_start, const int theta_index_end, const double *dx, const double *dy, const double *intTheta);          
#else
   /* Delacre on CPU functions */   
    double trapazoidal(const int theta_index_start, const int theta_index_end, const double *dx, const double *dy, const double *intTheta);
    double Simpsons_3_8(const int theta_index_start, const int theta_index_end, const double *dx, const double *dy, const double *intTheta);      
#endif
    
    /* Declare output vectors for results*/
    plhs[0] = mxCreateDoubleMatrix(1,nIndex,mxREAL);
    result = mxGetPr(plhs[0]);
        
    /*Cycle though all theta tiem points and create matrix of theta values.   */      
#if defined(__INTEL_COMPILER) && defined(__INTEL_OFFLOAD)

   static int coprocessorNum=-999;
   static int isCoprocessorMemAlloc = 0;
   static int isCPUMemAlloc = 0;
   int debugOffload=0;
   
   if (coprocessorNum==-999) {
      /* Randomly select a coprocessor */
      time_t t;    
      srand((unsigned) time(&t));
      int coprocessorCount = _Offload_number_of_devices();      
      coprocessorNum = rand() % coprocessorCount;          
   }
     
    /* Static variables for pre-allocating arrays on coprocessor*/
    __declspec( target (mic:coprocessorNum)) static int nTheta_offload = 0, nIndex_offload = 0;
    __declspec( target (mic:coprocessorNum)) static int nForcing_offload = 0, theta_indexes_end_offload  = 0;
    __declspec( target (mic:coprocessorNum)) static double *result_offload, *theta_offload, *theta_indexes_start_offload, *forcing_offload, inteTheta_0to1_offload;
    
    /* Error handling */
    _Offload_status x;

    /* If the input vectors are of zero length then free the memory on 
     * the coprocessor and static variables and then return*/
   if (nTheta==0 && nIndex==0 && nForcing ==0) {    
      if (debugOffload==1)
         mexPrintf("Freeing memory on CPU and card %d. \n",coprocessorNum); 
            
      if (isCoprocessorMemAlloc==1) {
         #pragma offload target(mic:coprocessorNum) \
         nocopy(nIndex_offload : FREE REUSE) \
         nocopy(theta_indexes_start_offload : FREE REUSE) \
         nocopy(theta_indexes_end_offload : FREE REUSE) \
         nocopy(theta_offload : FREE REUSE) \
         nocopy(forcing_offload : FREE REUSE) \
         nocopy(inteTheta_0to1_offload : FREE REUSE) \
         nocopy(result_offload : FREE REUSE) status(x) optional
         {}  
         
         if (x.result == OFFLOAD_SUCCESS)
            isCoprocessorMemAlloc=0;   
      }
      
      if (isCPUMemAlloc==1) {
         mxFree(theta_offload);
         mxFree(result_offload);
         mxFree(theta_indexes_start_offload);
         mxFree(forcing_offload);
         isCPUMemAlloc=0;
      }
    
      nTheta_offload = 0;
      nIndex_offload = 0; 
      nForcing_offload = 0;            
      
      coprocessorNum==-999;
      
      return;
   }
    
   /* Allocate data on array if either the static variables have not yet 
    * been set (ie this is the first call to the function) or the input 
    * data appears to have changed since the prior call to the function */
   if (nTheta_offload==0 || nIndex_offload==0 || nForcing_offload ==0 
   || nTheta!=nTheta_offload || nIndex!=nIndex_offload || nForcing!=nForcing_offload) {
      if (debugOffload==1)
         mexPrintf("Offload Initialisation to card %d. \n",coprocessorNum); 
      
      /* Update static array size variables.*/
      nTheta_offload  = nTheta;
      nIndex_offload = nIndex;
      nForcing_offload = nForcing;
      theta_indexes_end_offload = theta_indexes_end;
      inteTheta_0to1_offload = inteTheta_0to1;
      
      /* Allocate variables on host*/
      if (debugOffload==1)
         mexPrintf("Allocating CPU offload variables. \n");               
         
      result_offload = (double *)mxCalloc(nIndex_offload,sizeof(double));
      theta_offload = (double *)mxCalloc(nTheta_offload,sizeof(double));
      theta_indexes_start_offload = (double *)mxCalloc(nIndex_offload,sizeof(double));
      forcing_offload = (double *)mxCalloc(nForcing_offload,sizeof(double));  
      isCPUMemAlloc = 1;
      
      
      mexMakeMemoryPersistent(result_offload);
      mexMakeMemoryPersistent(theta_offload);
      mexMakeMemoryPersistent(theta_indexes_start_offload);
      mexMakeMemoryPersistent(forcing_offload);
      
      /* Allocate variables on the coprocessor.*/
      if (debugOffload==1)
         mexPrintf("Allocating coprocessor memory. \n");               
      
      #pragma offload target(mic:coprocessorNum) \
      in(nIndex_offload : ALLOC RETAIN) \
      in(theta_indexes_start_offload : length(nIndex_offload) ALLOC RETAIN) \
      in(theta_indexes_end_offload : ALLOC RETAIN) \
      in(theta_offload: length(nTheta) ALLOC RETAIN) \
      in(forcing_offload : length(nForcing) ALLOC RETAIN) \
      in(inteTheta_0to1_offload : ALLOC RETAIN) \
      in(result_offload : length(nIndex) ALLOC RETAIN)  status(x) optional
      {}            
      
      if (x.result == OFFLOAD_SUCCESS)
         isCoprocessorMemAlloc=1;   
   }

   if (isForcingAnIntegral==0 ) {      
        if (debugOffload==1)
            mexPrintf("Offloading to card %d. \n",coprocessorNum); 
      
        #pragma offload target(mic:coprocessorNum) \
        in(nIndex: into (nIndex_offload) ) \
        in(theta_indexes_start:length(nIndex_offload) into (theta_indexes_start_offload)) \
        in(theta_indexes_end: into (theta_indexes_end_offload)) \
        in(theta: length(nTheta) into (theta_offload)) \
        in(forcing: length(nForcing) into(forcing_offload)) \
        in(inteTheta_0to1: into(inteTheta_0to1_offload)) \
        out(result_offload: length(nIndex) into(result)) \
        status(x) optional
        {       
            int iIndex;
            #pragma omp parallel for
            for(iIndex=0;iIndex<nIndex_offload; iIndex++) 
                result_offload[iIndex] = Simpsons_3_8((int)theta_indexes_start_offload[iIndex], theta_indexes_end_offload, theta_offload + (int)theta_indexes_start_offload[iIndex]- 1, forcing_offload, &inteTheta_0to1_offload);
        }        
        if (x.result != OFFLOAD_SUCCESS) {  
            if (debugOffload==1) 
               mexPrintf("Offload unsuccessful. Error type: %d. Falling back to CPU \n",x.result);

            if (isCoprocessorMemAlloc==1) {
               if (debugOffload==1)
                  mexPrintf("Freeing coprocessor memory. \n");               
               
               #pragma offload target(mic:coprocessorNum) \
               nocopy(nIndex_offload : FREE REUSE) \
               nocopy(theta_indexes_start_offload : FREE REUSE) \
               nocopy(theta_indexes_end_offload : FREE REUSE) \
               nocopy(theta_offload : FREE REUSE) \
               nocopy(forcing_offload : FREE REUSE) \
               nocopy(inteTheta_0to1_offload : FREE REUSE) \
               nocopy(result_offload : FREE REUSE) status(x) optional
               {}  
               
               if (x.result == OFFLOAD_SUCCESS)
                  isCoprocessorMemAlloc=0;   
            }
                     
            if (isCPUMemAlloc==1) {
               if (debugOffload==1)
                  mexPrintf("Freeing CPU memory. \n");
                              
               mxFree(theta_offload);
               mxFree(result_offload);
               mxFree(theta_indexes_start_offload);
               mxFree(forcing_offload);
               isCPUMemAlloc=0;
            }    
            
            nTheta_offload = 0;
            nIndex_offload = 0; 
            nForcing_offload = 0;            
            
            if (debugOffload==1)
               mexPrintf("Running CPU only calculation. \n");
            
            for(iIndex=0;iIndex<nIndex; iIndex++) 
                result[iIndex] = Simpsons_3_8((int)theta_indexes_start[iIndex], theta_indexes_end, theta + (int)theta_indexes_start[iIndex]- 1, forcing, &inteTheta_0to1);
        }
        else if (debugOffload==1)
            mexPrintf("Offload successful! \n");        
   }
   else {

        if (debugOffload==1) 
         mexPrintf("Offloading to card %d. \n",coprocessorNum); 
        
        #pragma offload target(mic:coprocessorNum) \
        in(nIndex: into (nIndex_offload) ) \
        in(theta_indexes_start:length(nIndex_offload) into (theta_indexes_start_offload)) \
        in(theta_indexes_end: into (theta_indexes_end_offload)) \
        in(theta: length(nTheta) into (theta_offload)) \
        in(forcing: length(nForcing) into(forcing_offload)) \
        in(inteTheta_0to1: into(inteTheta_0to1_offload)) \
        out(result_offload: length(nIndex) into(result)) \
        status(x) optional
        {       
            int iIndex;
            #pragma omp parallel for
            for(iIndex=0;iIndex<nIndex_offload; iIndex++) 
                result_offload[iIndex] = trapazoidal((int)theta_indexes_start_offload[iIndex], theta_indexes_end_offload, theta_offload + (int)theta_indexes_start_offload[iIndex]- 1, forcing_offload, &inteTheta_0to1_offload);        

        }
        if (x.result != OFFLOAD_SUCCESS) {      
            if (debugOffload==1) 
               mexPrintf("Offload unsuccessful. Error type: %d. Falling back to CPU \n",x.result);

            if (isCoprocessorMemAlloc==1) {
               if (debugOffload==1)
                  mexPrintf("Freeing coprocessor memory. \n");               
               
               #pragma offload target(mic:coprocessorNum) \
               nocopy(nIndex_offload : FREE REUSE) \
               nocopy(theta_indexes_start_offload : FREE REUSE) \
               nocopy(theta_indexes_end_offload : FREE REUSE) \
               nocopy(theta_offload : FREE REUSE) \
               nocopy(forcing_offload : FREE REUSE) \
               nocopy(inteTheta_0to1_offload : FREE REUSE) \
               nocopy(result_offload : FREE REUSE) status(x) optional
               {}  
               
               if (x.result == OFFLOAD_SUCCESS)
                  isCoprocessorMemAlloc=0;   
            }
         
            if (debugOffload==1)
               mexPrintf("Freeing CPU memory. \n");
            
            if (isCPUMemAlloc==1) {
               mxFree(theta_offload);
               mxFree(result_offload);
               mxFree(theta_indexes_start_offload);
               mxFree(forcing_offload);
               isCPUMemAlloc=0;
            }
               
            
            nTheta_offload = 0;
            nIndex_offload = 0; 
            nForcing_offload = 0;                       
            
            if (debugOffload==1)
               mexPrintf("Running CPU only calculation. \n");          
            
            for(iIndex=0;iIndex<nIndex; iIndex++) 
                result[iIndex] = trapazoidal((int)theta_indexes_start[iIndex], theta_indexes_end, theta + (int)theta_indexes_start[iIndex]- 1, forcing, &inteTheta_0to1);                 
        }
        else if (debugOffload==1)
            mexPrintf("Offload successful! \n");
        
   }
#else

    if (nTheta==0 && nIndex==0 && nForcing ==0) {    
      return;
    }

    if (isForcingAnIntegral==0 ) {      
        /*for(int iIndex=0;iIndex<nIndex; iIndex++) */
        for(iIndex=nIndex; iIndex--;) 
            result[iIndex] = Simpsons_3_8((int)theta_indexes_start[iIndex], theta_indexes_end, theta + (int)theta_indexes_start[iIndex]- 1, forcing, &inteTheta_0to1);
    }
    else {
        /*for(int iIndex=0;iIndex<nIndex; iIndex++) */
        for(iIndex=nIndex; iIndex--;)
            result[iIndex] = trapazoidal((int)theta_indexes_start[iIndex], theta_indexes_end, theta + (int)theta_indexes_start[iIndex]- 1, forcing, &inteTheta_0to1);        
                
    }
#endif       


}


/* Integration using the Trapazoidal rule under the assumption that the
 * forcing is the integral over the day. 
 */
double trapazoidal(const int theta_index_start, const int theta_index_end, const double *dx, const double *dy, const double *intTheta)
{           
    int i;
    const int n = (int)(theta_index_end - theta_index_start);      /*number of elements*/
    const int endIndex = n - 1;                                   /*index to the last element*/
    double ret_val;
     
    /* Use high precision estimate over the first time step */
    ret_val =  2 * *intTheta * dy[endIndex];

    /* Integrate remaining points*/
    for (i = 1; i <= n; i++)
        ret_val += (dx[endIndex-i] + dx[endIndex-i-1]) * dy[endIndex-i];
            
    
    return 0.5*ret_val;
} /* trapazoidal_ */


/* Integration using Simpson's 3.8 rule
*/
double Simpsons_3_8(const int theta_index_start, const int theta_index_end, const double *dx, const double *dy, const double *intTheta)
{
    int i,j, k, el, m, endIndex_endLoop;
    const int n =  (int)(theta_index_end - theta_index_start);     /*number of elements*/
    const int endIndex = n - 1;                                   /*index to the last element*/
    double ret_val;
    const double twoThirds = 2./3.;
    
    /* Integrate first term of Simpson's 3/8 composite rule
     NOTE: This is from t=1. The integration from 0 to 1 is
     undertaken after the Simpson's integration. */
    ret_val = 1./3. * dx[endIndex-1] * dy[endIndex-1];
    
    /* Check if the "number of rows -2" are multiplire of 3  and set end of for loop*/
    m = (endIndex-1) % 3;        
    endIndex_endLoop = n - 3 - m;
    
    /* Calculate internal triples repeating sequance for Simpon's 3/8 composire rule */
    for (i = 2; i < endIndex_endLoop; i += 3) {
        j = endIndex-i;
        k = j-1;
        el=k-1;
        ret_val +=  dx[j]* dy[j] + 
                dx[k] * dy[k] + 
                twoThirds * dx[el] * dy[el];
    }

    /* Calculate last term of Simpson's 3/8 compiste rule*/
    i = i + 3;
    ret_val += 1./3. * dx[endIndex-i] * dy[endIndex-i];
    ret_val = 3. * 3./8.*ret_val;
    
    /* Use high precision estimate over the first time step */
    ret_val +=  *intTheta * 0.5 * (dy[endIndex] + dy[endIndex-1]);
            
    /* Calculate integration for any remaining points */
    if (i == endIndex_endLoop && m!=0) {
        if (m==1)  /* Do trapazoidal integration on last point */      
            ret_val +=  dx[endIndex-i] * dy[endIndex-i] +  dx[endIndex-i-1]* dy[endIndex-i-1];
        else /* Do standard Simpson's integration on last 2 points */
            ret_val +=  1./.3 * ( dx[endIndex-i] * dy[endIndex-i] +  4. * dx[endIndex-i-1] * dy[endIndex-i-1] + dx[endIndex-i-2] * dy[endIndex-i-2]);
    }

    return ret_val;
} /* Simpsons_3_8 */
