function [SimRR] = hymod(x,Extra); 
% Runs the HYMOD model

% Define the rainfall
PET = Extra.PET; Precip = Extra.Precip; MaxT = Extra.MaxT;
% Define the parameters
cmax = x(1); bexp = x(2); alpha = x(3); Rs = x(4); Rq = x(5);
% HYMOD PROGRAM IS SIMPLE RAINFALL RUNOFF MODEL
x_loss = 0.0;
% Initialize slow tank state
x_slow = 2.3503/(Rs*22.5);
% Initialize state(s) of quick tank(s)
x_quick(1:3,1) = 0; t=1; outflow = [];
% START PROGRAMMING LOOP WITH DETERMINING RAINFALL - RUNOFF AMOUNTS
while t < MaxT+1,
   Pval = Precip(t,1); PETval = PET(t,1);
   % Compute excess precipitation and evaporation
   [UT1,UT2,x_loss] = excess(x_loss,cmax,bexp,Pval,PETval);
   % Partition UT1 and UT2 into quick and slow flow component
   UQ = alpha*UT2 + UT1; US = (1-alpha)*UT2;
   % Route slow flow component with single linear reservoir
   inflow = US; [x_slow,outflow] = linres(x_slow,inflow,outflow,Rs); QS = outflow;
   % Route quick flow component with linear reservoirs
   inflow = UQ; k = 1; 
   while k < 4,
      [x_quick(k),outflow] = linres(x_quick(k),inflow,outflow,Rq); inflow = outflow; 
      k = k+1;
   end;
   % Compute total flow for timestep
   output(t,1) = (QS + outflow)*22.5;
   % Update the time
   t = t+1;   
end;
% Define the output using spin up period of 65 days
SimRR = output(65:MaxT,1);