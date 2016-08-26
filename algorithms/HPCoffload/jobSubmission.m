function [ userData, calibLabel ] = jobSubmission(obj, userData, projectPath, calibLabel, calibStartDate, calibEndDate, calibMethod,  calibMethodSetting)
% jobSubmission Steps for job submission to qsub


    if length(calibLabel)==0
        msgbox({'No models are selected for offload to a cluster.','Please select models and re-run.'}, 'No models selected','error');
        return;
    end
        

    % Add message explaing the HPC offloading
    h= msgbox({ 'This BETA feature of the toolbox allows calibration of the selected models', ...        
                'on a high performance cluster. To use this feature you must have an ', ...
                'account on a cluster.', ...  
                '', ...
                'After clicking OK, you will be prompted to input your user name and ', ...
                'password to the cluster plus the location of the cluster and various', ...
                'job submission settings.', ...
                '', ...
                'Importantly, cluster calibration and retrieval has only beed tested', ...
                'on a PBS queuing cluster using "mpiexec". Use on any other type of', ...
                'cluster will require monifications to the submission settings', ...
                '', ...
                'Additionally, the provided pre-job submission settings provided are', ...
                'for the University of Melbourne cluster. They specify loading matlab',...
                'and initiating the Xeon Phi coprocessors (requires Intel ICC >=2013).', ...
                'Please edit these settings for your cluster.'},'Offloading Calibration to a Cluster...','help') ;
    uiwait(h);


    % Get the following inputs: cluster URL, user name, folder name, max cores, qsub command (queue, wall time, matlab command)
    prompts = { 'URL to the cluster:', ...
                'User name for cluster:', ...
                'Password for cluster:', ...
                'Email address for updates (optional):', ...
                'Full path to folder for the jobs:', ...
                'Job name:', ...
                'Queue name (optional):', ...
                'Node name (optional) :', ...
                'Max. MPI jobs (optional):', ...
                'CPUs per node per model:', ...
                'Max. runtime per model:', ...                
                'Command for pre-job submission  (optional):'};
                
    dlg_title = 'Offload calibration to cluster';        
    num_lines = 1;
    if isempty(userData) || length(userData)~=12
        defaults = {'edward.hpc.unimelb.edu.au', ...
                    '', ...
                    '', ...
                    '', ...                    
                    '/USER_FOLDER/GroundwaterStatisticsToolkit', ...
                    'GST-MPI-ARRAY', ...
                    '', ...
                    '', ...
                    '', ...
                    '1', ...
                    '24:00:00', ...
                    'module load gcc; module load matlab/R2014a; source /usr/local/intel/2013.1/composer_xe_2013_sp1.2.144/bin/compilervars.sh intel64 '};
    else
        defaults=userData;
    end
    userData = inputdlg(prompts,dlg_title,num_lines,defaults);
    if isempty(userData)
        return;
    end
            
    % Disaggregate user data
    URL = userData{1};
    username = userData{2};
    password = userData{3};
    email = userData{4};
    folder = userData{5};
    jobName = userData{6};
    queue = userData{7};
    nodeName = userData{8};
    nJobs = userData{9};
    nCPUs= userData{10};
    walltime= userData{11};
    preCommands = userData{12};    
    userData{3} = '';
    
    
    if isempty(URL) || isempty(username) || isempty(password) || ...
    isempty(folder) ||  isempty(jobName) ||  isempty(nCPUs) ||    ...
    isempty(walltime)
        msgbox({'All non-optional inputs are required.','Please re-run with the required inputs.'}, 'Insufficient inputs','error');
        return;
    end
    
    %CD to project path 
    cd(fileparts(projectPath));    
    
    %Load Java SSH module
    %sshfrommatlabinstall();
    %sshfrommatlabinstall(1);
    
    % Check that a SSH channel can be opened and set to auto-reconnect
    sshChannel = ssh2_config(URL,username,password);    
    if isempty(sshChannel)
        
        errordlg({'An SSH connection to the cluster could not be established.','Please check the input URL, username and passord.'},'SSH connection failed.');
        return;
    end
    sshChannel.autoreconnect = 1;

    % Check if the foilder exists
    [sshChannel,SSHresult] = ssh2_command(sshChannel,['if test -d ',folder,' ; then echo "exist"; else echo "not exists"; fi']);
    if strcmp(SSHresult,'exist')

        
        ans = questdlg({'The input full path to folder for the jobs already exists.','All existing jobs within this folder will be deleted.','Do you want to continue?'},'Delete existing folders?','Continue','Cancel','Cancel');
        if strcmp(ans,'Cancel')
            return;
        end
        
        % Delete existing folders
        [sshChannel,SSHresult] = ssh2_command(sshChannel,['rm -r ',folder]);
    end
    
    % Create message box for status of offload
    msgStr=cell(1,8);
    h = msgbox(msgStr, 'HPC offload progress ...','help');
    set(findobj(h,'style','pushbutton'),'Visible','off')
    pos=get(h,'Position');
    pos(3) = 300;
    pos(4) = 150;
    set(h,'Position',pos);
    drawnow;

    try
        
        % Create project folder for latter copy to HPC        
        msgStr{1} = '   Making project folder on cluster...';
        set(findobj(h,'Tag','MessageBox'),'String',msgStr);
        drawnow;
        [sshChannel,SSHresult] = ssh2_command(sshChannel,['mkdir -p ',folder]);
        [sshChannel,SSHresult] = ssh2_command(sshChannel,['mkdir -p ',folder,'/models']);

        % Loop through each model to be calibrated, create a folder, save a text file for the
        % calib options and the model object    
        hasModelName = cellfun(@(x) ~isempty(x), calibLabel);
        calibLabel = calibLabel(hasModelName);
        nModels = length(calibLabel);
        nModelsUploadFailed=0;
        for i=1:nModels

           msgStr{2} = ['   Uploading ',num2str(i),' of ',num2str(nModels),' model data files ...'];           
           set(findobj(h,'Tag','MessageBox'),'String',msgStr);
           drawnow;
            
           % Create model folder
           calibLabel_orig = calibLabel{i};
           calibLabel{i} =  regexprep(calibLabel{i},'\W','_');                             
           calibLabel{i} =  regexprep(calibLabel{i},'____','_');                             
           calibLabel{i} =  regexprep(calibLabel{i},'___','_');                             
           calibLabel{i} =  regexprep(calibLabel{i},'__','_');                     
           try
               [sshChannel,SSHresult] = ssh2_command(sshChannel,['mkdir ',folder,'/models/',calibLabel{i}]);
                
               % Move into model folder
               [sshChannel,SSHresult] = ssh2_command(sshChannel,['cd models/',calibLabel{i}]);

               % Save calib options text file   
               [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "',datestr(calibStartDate{i}),' \n" >> ',folder,'/models/',calibLabel{i},'/options.txt']);
               [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "',datestr(calibEndDate{i}),' \n" >> ',folder,'/models/',calibLabel{i},'/options.txt']);
               [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "',calibMethod{i},' \n" >> ',folder,'/models/',calibLabel{i},'/options.txt']);
               [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "',num2str(calibMethodSetting{i}),' \n" >> ',folder,'/models/',calibLabel{i},'/options.txt']);

               % Save model object to .mat file
               % NOTE: Calibraton results are clearer to minimise upload time
               model = getModel(obj, calibLabel_orig);
               model.calibrationResults=[];
               model.evaluationResults=[];
               save(fullfile(projectPath,'HPCmodel.mat'), 'model');

               % Copy .mat to cluster
               scp_put(sshChannel, 'HPCmodel.mat', [folder,'/models/',calibLabel{i}], projectPath,'HPCmodel.mat');
               
           catch ME
               sshChannel  =  ssh2_close(sshChannel);
               sshChannel = ssh2_config(URL,username,password); 
               nModelsUploadFailed = nModelsUploadFailed +1;
               continue;
           end
           
           % Delete file
           delete(fullfile(projectPath,'HPCmodel.mat'));
           
        end

        %Copy .m algorithms folder to HPC
        msgStr{3} = '   Zipping and uploading GST algorithms ...';
        set(findobj(h,'Tag','MessageBox'),'String',msgStr);    
        drawnow;
        if ~isdeployed
            % Find path to alogorithsm folder
            algorithmsPath = fileparts(mfilename('fullpath'));
            algorithmsPath = algorithmsPath(1:end-11);

            % Zip algorithms folder (save nto project folder)

            zip(fullfile(projectPath,'algorithms.zip'),algorithmsPath);

            % Copy zipped file to cluster            
            scp_put(sshChannel, 'algorithms.zip', folder, projectPath, 'algorithms.zip');

            % Unzip the file
            [sshChannel,SSHresult] = ssh2_command(sshChannel,['cd ', folder,'; unzip algorithms.zip']);        

            % remove local zip file
            delete(fullfile(projectPath,'algorithms.zip'));
        else
            errordlg('HPC offloading for a deployed (i.e. standalone) application is not yet implemented')
            return;
        end

        % Set the number of MPI jobs
        if isempty(nJobs)
            nJobs = nModels;
        else
            nJobs=str2num(nJobs);
        end            
        
        % Calculate the number of models per job, and if theer are to be an 
        % unequal number per job then add blank model IDs
        if floor(nModels/nJobs) ~= nModels/nJobs            
            nModelsPerJob = ceil(nModels/nJobs);
            nBlankModels = nModelsPerJob*nJobs - nModels;
            blankModels = cellstr(repmat(' ',nBlankModels,1))';
            calibLabel = {calibLabel{:}, blankModels{:}};
        else
            nModelsPerJob = nModels/nJobs;
        end            
        
        % Reshape list of model names to allocate models to a job.
        calibLabel = reshape(calibLabel, nJobs, nModelsPerJob);
        
        % Write file of model names. Each 'mpirun' jobs will open this file and find the requred model name(s) it has 
        % been allocated to calibrate. If more than one model name is
        % listed in a row then the MPI job sequentially runs multiple
        % models. 
        msgStr{4} = '   Writing file of model names ...';
        set(findobj(h,'Tag','MessageBox'),'String',msgStr);         
        drawnow;
        for i=1:nJobs
           % Save calib options text file   
           [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "',strjoin(calibLabel(i,:),','),' \n" >> ',folder,'/ModelNames.csv']);
        end

        msgStr{5} = '   Writing mpiexec submission file ...';
        set(findobj(h,'Tag','MessageBox'),'String',msgStr);         
        drawnow;        

        [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "#! /bin/bash \n" >> ',folder,'/SubmitJobs.in']);
        [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "#PBS -N ',jobName,' \n" >> ',folder,'/SubmitJobs.in']);
        if ~isempty(queue)
           [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "#PBS -q ',queue,' \n" >> ',folder,'/SubmitJobs.in']);
        end
        if isempty(nodeName)
            [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "#PBS -l nodes=1:ppn=',num2str(nCPUs),' \n" >> ',folder,'/SubmitJobs.in']);
        else
            [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "#PBS -l nodes=',nodeName,':ppn=',num2str(nCPUs),' \n" >> ',folder,'/SubmitJobs.in']);
        end
        [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "#PBS -l walltime=',walltime,' \n" >> ',folder,'/SubmitJobs.in']);        
        [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "#PBS -t 1-',num2str(nJobs),' \n" >> ',folder,'/SubmitJobs.in']);
        if ~isempty(email)
           [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "#PBS -m bea \n" >> ',folder,'/SubmitJobs.in']);
           [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "#PBS -M ',email,' \n" >> ',folder,'/SubmitJobs.in']);
        end
        [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "',preCommands,' \n" >>',folder,'/SubmitJobs.in']);
        [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "cd ',folder,' \n" >>',folder,'/SubmitJobs.in']);
        [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "cd algorithms/calibration/Utilities \n" >>',folder,'/SubmitJobs.in']);        
        [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "mpiexec.hydra -np 1 matlab -nodesktop -nosplash -r ''iModel=''\${PBS_ARRAYID}\$'';calibrateOnCluster;'' \n" >>',folder,'/SubmitJobs.in']);
        
        % Submit qsub to call script of tasks.
        msgStr{6} = '   Submitting job to the HPC queue...';
        set(findobj(h,'Tag','MessageBox'),'String',msgStr);                   
        drawnow;
        [sshChannel,SSHresult] = ssh2_command(sshChannel,['cd ',folder, '&& qsub SubmitJobs.in']);

        % Closing connection
        sshChannel  =  ssh2_close(sshChannel);
        
    catch ME
        msgStr{7} = '   HPC offload failed with the following message:';
        msgStr{8} = ['     ', ME.message];
        set(findobj(h,'Tag','MessageBox'),'String',msgStr);                   
        set(findobj(h,'style','pushbutton'),'Visible','on')
        
        set(h, 'pointer', 'arrow'); 
        drawnow;
        
        return;        
    end
        
    msgStr{7} = '   HPC offload finished successfully.';  
    if nModelsUploadFailed>0
        msgStr{8} = ['   WARNING: Offload failed for ',num2str(nModelsUploadFailed),' models.'];
    end
    set(findobj(h,'Tag','MessageBox'),'String',msgStr);                   
    set(findobj(h,'style','pushbutton'),'Visible','on');
    
    set(h, 'pointer', 'arrow'); 
    drawnow;

end

