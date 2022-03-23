function [ChildGen,Vnew] = Swarm_ChildGen(ParGen,Vold,pBest,nBest,SCEMPar,Extra);
% Performs particle swarm optimization

% Determine the size of the Swarm
[SwarmSize, Dim] = size(ParGen);
% Determine the value of intertia and weights
w =  0.5 + (rand/2); c1 = 1.5; c2 = c1; Chi = 1; % => Did all my tests like this
%w = 0.5 + (rand/2); c1 = 0.5; c2 = c1; Chi = 1;
% Generate Random Numbers
R1 = rand(SwarmSize, Dim); R2 = rand(SwarmSize, Dim);
% Calculate Velocity
Vnew = w*Vold + c1*R1.*(pBest-ParGen) + c2*R2.*(nBest-ParGen);
% Update the position of the particles
ChildGen = ParGen + Chi * Vnew;
% Now do random change
U = unifrnd(-1,1,SwarmSize,1);
% Do loop
for qq = 1:SwarmSize,
    ChildGen(qq,1:SCEMPar.n) = ChildGen(qq,1:SCEMPar.n) + U(qq,1).*ChildGen(qq,1:SCEMPar.n);
end;