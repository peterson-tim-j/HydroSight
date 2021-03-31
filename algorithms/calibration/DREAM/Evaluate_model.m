function [fx] = Evaluate_model(x,DREAMPar,Meas_info,f_handle, varargin);
% This function computes the likelihood and log-likelihood of each d-vector
% of x values
%
% Code both for sequential and parallel evaluation of model ( = pdf )
%
% Written by Jasper A. Vrugt

global DREAM_dir EXAMPLE_dir;

% Check whether to store the output of each model evaluation (function call)
if ( strcmp(lower(DREAMPar.modout),'yes') ) && ( Meas_info.N > 0 ),
    
    % Create initial fx of size model output by DREAMPar.N
    fx = NaN(Meas_info.N,DREAMPar.N);
    
end;

% Now evaluate the model
if ( DREAMPar.CPU == 1 )         % Sequential evaluation
    
    % TJP Edit
    if ~isempty(EXAMPLE_dir)
        cd(EXAMPLE_dir)
    end
    
    % Loop over each d-vector of parameter values of x using 1 worker
    parfor ii = 1:DREAMPar.N,      
        
        % Execute the model and return the model simulation
        fx(:,ii) = f_handle(x(ii,:), varargin{:});
        
    end;

    if ~isempty(DREAM_dir)
        cd(DREAM_dir)
    end
    
elseif ( DREAMPar.CPU > 1 )      % Parallel evaluation
    
    % If IO writing with model --> worker needs to go to own directory
    if strcmp(lower(DREAMPar.IO),'yes'),
        % Minimise network traffic by checking in example dir is needed.
        % Tim Peterson 2016
        if ~isempty(EXAMPLE_dir)
        
            % Loop over each d-vector of parameter values of x using N workers
            parfor ii = 1:DREAMPar.N,

                % Determine work ID
                t = getCurrentTask();

                % Go to right directory (t.id is directory number)
                evalstr = strcat(EXAMPLE_dir,'\',num2str(t.id)); cd(evalstr)

                % Execute the model and return the model simulation
                fx(:,ii) = f_handle( [ x(ii,:) t.id ], varargin{:} );

            end;
        else
            % Loop over each d-vector of parameter values of x using N workers
            parfor ii = 1:DREAMPar.N,
                % Execute the model and return the model simulation
                fx(:,ii) = f_handle( [ x(ii,:) t.id ], varargin{:} );
            end;
            
        end
        
    else
        % TJP Edit
        if ~isempty(EXAMPLE_dir)
            cd(EXAMPLE_dir)
        end
        
        % Loop over each d-vector of parameter values of x using N workers    
        %parfor ii = 1:DREAMPar.N,
        %    
        %    % Execute the model and return the model simulation
        %    fx(:,ii) = f_handle(x(ii,:), varargin{:});
        %    
        %end;

        % Above for loop is redundant because
        % HydroSightModel.objectiveFunctionValue() is parallelised.
        % Edited by tjp
        fx = f_handle(x', varargin{:});


        if ~isempty(DREAM_dir)
            cd(DREAM_dir)
        end

    end;
    
end;
