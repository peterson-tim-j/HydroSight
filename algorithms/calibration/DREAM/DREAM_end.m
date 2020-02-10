function [ chain , output , fx ] = DREAM_end(DREAMPar,Meas_info,chain,output,iteration,iloc,fid_2);
% Finalize return arguments, file writing, and setup calculation

global DREAM_dir EXAMPLE_dir

% Start with CR
output.CR = output.CR(1:iteration-1,1:DREAMPar.nCR+1);
% Then R_stat
output.R_stat = output.R_stat(1:iteration-1,1:DREAMPar.d+1);
% Then AR
output.AR = output.AR(1:iteration-1,1:2);
% Then chain
chain = chain(1:iloc,1:DREAMPar.d+2,1:DREAMPar.N);

% Now calculate the convergence diagnostics for individual chains using the CODA toolbox
fid = fopen('DREAM_diagnostics.txt','w');
% Now loop over each chain
for j = 1:DREAMPar.N,
    % First calculate diagnostics
    diagnostic{j} = coda(chain(floor(0.5*iloc):iloc,1:DREAMPar.d,j));
    % Now write to file DREAM.out
    diagnostic{j}(1).chain_number = j; prt_coda(diagnostic{j},[],fid);
end;
% Now close the file again
fclose(fid);

% Check whether output simulations are requested
switch DREAMPar.modout
    case 'no'
        % Return an empty matrix
        fx = [];
    case 'yes'
        if Meas_info.N > 0,
            % Open the binary file with model simulations
            fid_fx = fopen('fx.bin','r','n');
            % Now read the binary file
            fx = fread(fid_fx, [ Meas_info.N, floor(DREAMPar.T*DREAMPar.N/DREAMPar.thinning)+1 ],'double')';
            % Now close the file again
            fclose(fid_fx);
        else
            fx = [];
        end;
end;

% Close MATLAB pool (if CPU > 1) and remove file if
if DREAMPar.CPU > 1,
    % Close the matlab pool
    % TJP Edits
    [ver verdate] = version;
    if year(verdate)<2015      
        matlabpool('close');
    end
    % If input output writing, then remove directories
    if strcmp(DREAMPar.IO,'yes');
        % Go to directory with problem files
        cd(EXAMPLE_dir)
        % Remove the directories
        for ii = 1:min(DREAMPar.CPU,DREAMPar.N),
            % Remove each worker directory
            rmdir(strcat(num2str(ii)),'s');
        end;
        cd(DREAM_dir)
    end;
end;

% Write final line of warning file
fprintf(fid_2,'----------- End of DREAM warning file ----------\n');
% Close the warning file
fclose('all');
% TJP Edit to check for graphical enviro
if usejava('desktop')
    % Open the warning file
    edit warning_file.txt
    % Open the MCMC diagnostic file
    edit DREAM_diagnostics.txt
end

% Remove path of dream
% TJP Edit
if ~isempty(DREAM_dir)
    rmpath(DREAM_dir);
end
