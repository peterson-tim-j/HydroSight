
%copy and rename your objective function as functn.m
!copy objectivefunction.m functn.m
%Define the lower bounds of parameters of theobjective function
bl=;
%Define the upper bounds of parameters of theobjective function
bu=;
%Assign an intitial guess point. This optional and you can assign a random
%point in the fesible space.
x0=;

%set values of algorithmic parameters, Definitions of paramters can be found
%in the header of SPUCI.m 
maxn=1e6;
kstop=50;
pcento=0.1;
peps=1e-6;
ngs=2;
iniflg=0;
%set the random seed
iseed=sum(100*clock);
%call SPUCI
[bestx,bestf] = SPUCI(x0,bl,bu,maxn,kstop,pcento,peps,ngs,iseed,iniflg);
