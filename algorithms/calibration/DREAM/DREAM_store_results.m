function DREAM_store_results ( DREAMPar , fx , Meas_info , id );
% Stores the results of DREAM to binary files

% Append current model simulations of X to file "fx.bin"
if ( strcmp(DREAMPar.modout,'yes') ) && ( Meas_info.N > 0 )
    % Now open the file to append new simulations
    evalstr = strcat('fid_fx = fopen(''fx.bin'',''',num2str(id),''',''n'');'); eval(evalstr);
    % Now append
    fwrite(fid_fx,fx,'double');
    % Now close file
    fclose(fid_fx);
end;