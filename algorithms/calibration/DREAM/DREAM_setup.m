function [DREAMPar,Par_info,Meas_info,chain,output,log_L,Table_gamma,iloc,iteration,...
        gen] = DREAM_setup(DREAMPar,Par_info,Meas_info)
% Initializes the main variables used in DREAM

% Generate new seed
%randn('state', sum(100*clock));     % random number generator state
iseed = num2str( sum(100*clock));

% Which fields has the use specified?
field_names = fieldnames(DREAMPar);

% Now make sure that all strings are lower case
for i = 1 : numel(field_names)
    evalstr = strcat('DREAMPar.',field_names(i),' = lower(DREAMPar.',field_names(i),');');
    % Now evaluate
    eval(char(evalstr));
end

% Set default values algorithmic variables DREAM - if not specified
value = {'3','3',num2str(max(max(floor(DREAMPar.T/50),1),50)),'0.05','1e-12','''iqr''','0.2','''yes''','1','0.025', '1.2', '1500', iseed};
% Name variable. TJP: 'iseed', 'r2_threshold', 'Tmin' added 2022.
name = {'nCR','delta','steps','lambda','zeta','outlier','p_unit_gamma','adapt_pCR','thinning','epsilon', 'r2_threshold', 'Tmin', 'iseed'};

% Now check
for j = 1 : numel(name)
    if ~isfield(DREAMPar,name(j))
        % Set variable of DREAMPar to "No"
        evalstr = strcat('DREAMPar.',char(name(j)),'=',value(j),';'); 
        eval(char(evalstr));
    end
end

% Set default value to 'No' if not specified
default = {'ABC','parallel','IO','modout','restart','save'};
% Set to "No" those that are not specified
for j = 1 : numel(default)
    if ~isfield(DREAMPar,default(j))
        % Set variable of DREAMPar to "No"
        evalstr = strcat('DREAMPar.',char(default(j)),'=''no''',';'); 
        eval(evalstr);
    end
end

% Matrix DREAMPar.R: Store for each chain (as row) the index of all other chains available for DE
for i = 1:DREAMPar.N
    DREAMPar.R(i,1:DREAMPar.N-1) = setdiff(1:DREAMPar.N,i); 
end

% Check whether parameter ranges have been defined or not
if ~isfield(Par_info,'min')
    % Specify very large initial parameter ranges (minimum and maximum values)
    Par_info.min = -Inf * ones ( 1 , DREAMPar.d ); 
    Par_info.max = Inf * ones ( 1 , DREAMPar.d );
end

% Initialize output information -- Outlier chains
output.outlier = [];

% Initialize matrix with log_likelihood of each chain
log_L = NaN(DREAMPar.T,DREAMPar.N+1);

% Initialize vector with acceptance rates
output.AR = NaN(floor(DREAMPar.T/DREAMPar.steps),2); output.AR(1,1) = DREAMPar.N;

% Initialize matrix with potential scale reduction convergence diagnostic
output.R_stat = NaN(floor(DREAMPar.T/DREAMPar.steps),DREAMPar.d+1);

% Initialize matix with crossover values
output.CR = NaN(floor(DREAMPar.T/DREAMPar.steps),DREAMPar.nCR+1);

% Initialize array (3D-matrix) of chain trajectories
chain = NaN(DREAMPar.T/DREAMPar.thinning,DREAMPar.d+2,DREAMPar.N);

% Generate Table with jump rates (dependent on DREAMPar.d and DREAMPar.delta)
% More efficient to read from Table
for zz = 1:DREAMPar.delta
    Table_gamma(:,zz) = 2.38./sqrt(2 * zz * transpose(1:DREAMPar.d));
end

% First calculate the number of calibration data measurements
Meas_info.N = size(Meas_info.Y,1);

% Initialize few important counters
iloc = 1; iteration = 2; gen = 2;