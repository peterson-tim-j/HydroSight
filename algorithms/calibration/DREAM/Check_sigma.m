function Meas_info = Check_sigma(Meas_info);
% Now check how the measurement sigma is arranged (estimated or defined)

% Check whether the measurement error is estimated jointly with the parameters
if isfield(Meas_info,'Sigma'),
    % Now check whether Sigma is estimated or whether user has defined Sigma
    if isfield(Meas_info,'n'),
        % Set initial part of string
        str_sigma = strcat('Sigma = Meas_info.Sigma('); 
        % Loop over n
        for j = 1:Meas_info.n,
            % Define the input variables of the inline function in text
            evalstr = strcat('Meas_info.a',num2str(j-1),'=','''x(ii,DREAMPar.d - ',num2str(j)-1,' )'';'); 
            % Now evaluate the text
            eval(evalstr); 
            % Now add to str_sigma
            str_sigma = strcat(str_sigma,'eval(Meas_info.a',num2str(j-1),'),');
        end;
        % If Meas_info.n > 1 --> Measured data is used
        if Meas_info.n > 1,
            % Now finish the function call
            Meas_info.str_sigma = strcat(str_sigma,'Meas_info.Y);'); 
        else
            str_sigma = str_sigma(1:end-1); Meas_info.str_sigma = strcat(str_sigma,');'); 
        end;
    end;
else
    % Sigma not estimated
end;