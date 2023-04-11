% Set sample model parameters
nParamSets=100;
SMSC = sort(linspace(50,500,nParamSets),'descend');
ksat = 10;
alpha = 0.25;
beta = 5;
gamma = 0.5;
eps = 0.5;
S_initial = SMSC.*0.25;

% Get precip and PET data
forcingData  = load('C:\Users\tpet0008\Documents\HydroSight\algorithms\models\TransferNoise\Example_model\124705_forcingData.mat');
forcingData = forcingData.forcingData;
precip = forcingData(:,4);
evap = forcingData(:,5);

% Solve the soil model using both the
tic;
for i=1:nParamSets
    SMS_implicitSolver =forcingTransform_soilMoisture(S_initial(i), precip, evap, [], SMSC(i), ksat, alpha, beta, gamma, eps, Inf, Inf, 0.0);
end
t_implicit=toc;

tic;
SMS_RKSolverVec =forcingTransform_soilMoisture_RK(S_initial, precip, evap, [], SMSC, repmat(ksat,1,nParamSets), repmat(alpha,1,nParamSets), repmat(beta,1,nParamSets), repmat(gamma,1,nParamSets), repmat(eps,1,nParamSets), Inf, Inf);
t_RKVec=toc;
SMS_RKSolverVec = SMS_RKSolverVec(:,end);

disp(['Run time for implicit solver:',num2str(t_implicit),' sec.']);
disp(['Run time for RK solver vectorised:',num2str(t_RKVec),' sec.']);
disp(['Run time ratio (Implicit/RK_vec):',num2str(t_implicit/t_RKVec)]);

%% Test vectorisation of all params vs some as scalers
tic;
forcingTransform_soilMoisture_RK(S_initial, precip, evap, [], SMSC, repmat(ksat,1,nParamSets), repmat(alpha,1,nParamSets), repmat(beta,1,nParamSets), repmat(gamma,1,nParamSets), repmat(eps,1,nParamSets), Inf, Inf);
t_RK_ParamVec=toc;

tic;
forcingTransform_soilMoisture_RK(S_initial, precip, evap, [], SMSC, repmat(ksat,1,nParamSets), 0.0, repmat(beta,1,nParamSets), 1.0, 0.0, Inf, Inf);
t_RK_ParamVec_alpha0_eps0_gamma1=toc;

tic;
forcingTransform_soilMoisture_RK(S_initial, precip, evap, [], SMSC, repmat(ksat,1,nParamSets), 1.0, repmat(beta,1,nParamSets), 1.0, 0.0, Inf, Inf);
t_RK_ParamVec_alpha1_eps0_gamma1=toc;

disp(['Run time for RK solver vector of all params:',num2str(t_RK_ParamVec),' sec.']);
disp(['Run time for RK solver alpha0 and vector SMSC, Ksat, beta:',num2str(t_RK_ParamVec_alpha0_eps0_gamma1),' sec.']);
disp(['Run time for RK solver alpha1 and vector SMSC, Ksat, beta:',num2str(t_RK_ParamVec_alpha1_eps0_gamma1),' sec.']);
disp(['Run time ratio (vec. all params / vec of 3 params alpha0):',num2str(t_RK_ParamVec/t_RK_ParamVec_alpha0_eps0_gamma1)]);
disp(['Run time ratio (vec. all params / vec of 3 params alpha1):',num2str(t_RK_ParamVec/t_RK_ParamVec_alpha1_eps0_gamma1)]);
disp(['Run time ratio (implicit solver / vec of 3 params alpha0):',num2str(t_implicit/t_RK_ParamVec_alpha0_eps0_gamma1)]);
disp(['Run time ratio (implicit solver / vec of 3 params alpha1):',num2str(t_implicit/t_RK_ParamVec_alpha1_eps0_gamma1)]);

alpha = 0.0;
gamma=1.0;
eps = 1.0;
% Check against implicit soln
for i=1:nParamSets
    SMS_implicitSolver =forcingTransform_soilMoisture(S_initial(i), precip, evap, [], SMSC(i), ksat, alpha, beta, gamma, eps, Inf, Inf, 0.0);
end

%SMS_RKSolver = forcingTransform_soilMoisture_RK(S_initial(end), precip, evap, [], SMSC(end), ksat, alpha, beta, gamma, eps, Inf, Inf);
SMS_RKSolver = forcingTransform_soilMoisture_RK(S_initial, precip, evap, [], SMSC, repmat(ksat,1,nParamSets), alpha, repmat(beta,1,nParamSets), gamma, eps, Inf, Inf);
%SMS_RKSolverVec =forcingTransform_soilMoisture_RK(S_initial, precip, evap, [], SMSC, repmat(ksat,1,nParamSets), repmat(alpha,1,nParamSets), repmat(beta,1,nParamSets), repmat(gamma,1,nParamSets), repmat(eps,1,nParamSets), Inf, Inf);
SMS_RKSolver = SMS_RKSolver';

subplot(1,3,1);
plot(1:size(SMS_RKSolver,1),SMS_implicitSolver ,'-b');
hold on;
plot(1:size(SMS_RKSolver,1),SMS_RKSolver(:,end) ,'-r');
hold off;
subplot(1,3,2);
plot(SMS_implicitSolver,SMS_RKSolver(:,end) ,'.b');
subplot(1,3,3);
plot(1:size(SMS_RKSolver,1),SMS_implicitSolver-SMS_RKSolver(:,end) ,'.b');