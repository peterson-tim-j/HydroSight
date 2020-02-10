function [ userData, calibLabel ] = jobSubmission(userData, projectPath, HPCmodelData, calibGUI_interface_obj)
% jobSubmission Steps for job submission to qsub


    if isempty(HPCmodelData)
        msgbox({'No models are selected for offload to a cluster.','Please select models and re-run.'}, 'No models selected','error');
        return;
    end        

    % Determine the number of models to calibrate and their labels
    %hasModelName = cellfun(@(x) ~isempty(x), calibLabel);
    %calibLabel = calibLabel(hasModelName);
    nModels = size(HPCmodelData,1);    
    
    % Get the following inputs: cluster URL, user name, folder name, max cores, qsub command (queue, wall time, matlab command)
    prompts = getPrompts();
    
    inputFormat = {{'PBS','SLURM'},'char','char','char','char','char','char','char','char','numeric','numeric','char','char'};
    dlg_title = 'HydroSight Calibration: Offload calibration to cluster';        
    num_lines = 1;
    if isempty(userData) || length(userData)~=13
        defaults = {2, ...
                    'spartan.hpc.unimelb.edu.au', ...
                    '', ...
                    '', ...
                    '', ...                    
                    '~/HydroSight', ...
                    'HydroSight-MPI-ARRAY', ...
                    '', ...
                    '', ...
                    num2str(nModels), ...
                    '1', ...
                    '24:00:00', ...
                    'module load GCC; module load MATLAB; source /usr/local/Edward/local/intel/2013.1/composer_xe_2013_sp1.2.144/bin/compilervars.sh intel64 '};
    else
        defaults=userData;
    end
    
    % Build the figure
    calibOffloadGUI = figure( ...
        'Name', dlg_title , ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'HandleVisibility', 'off', ...
        'Visible','on', ...
        'Toolbar','none', ...
        'DockControls','off', ...        
        'WindowStyle','modal');
    
    % Set window Size
    windowHeight = calibOffloadGUI.Parent.ScreenSize(4);
    windowWidth = calibOffloadGUI.Parent.ScreenSize(3);
    figWidth = 600;
    figHeight = 0.6*windowHeight;            
    calibOffloadGUI.Position = [(windowWidth - figWidth)/2 (windowHeight - figHeight)/2 figWidth figHeight];    
    
    % Add outer most panel
    outerVbox= uiextras.VBox('Parent',calibOffloadGUI,'Padding', 3, 'Spacing', 3);    
    
    % Add intro text
    uicontrol(outerVbox, 'Style','text','String', ...
              { '', ...
                'This feature allows calibration of all of the selected models  on a high performance cluster. To use this feature you must have an account on a cluster and know the URL to the cluser.', ...
                '', ...
                'Importantly, cluster calibration and retrieval has only beed tested on a PBS and SLURM queuing cluster using "mpiexec". Use on any other type of cluster will require modifications to the submission settings.', ...
                '', ...
                'Additionally, the provided pre-job submission settings provided are for the University of Melbourne cluster. They specify loading Matlab and initiating the Xeon Phi coprocessors (requires Intel ICC >=2013). Please edit these settings for your cluster.',''}, ... 
                'HorizontalAlignment','left', 'Units','normalized');                
    
    % Fill in the elements of the GUI.
    vbox= uiextras.Grid('Parent',outerVbox,'Padding', 6, 'Spacing', 6);
    for i=1:length(prompts)
        uicontrol(vbox,'Style','text','String',prompts{i},'HorizontalAlignment','left', 'Units','normalized');                                
    end
    for i=1:length(prompts)
        if iscell(inputFormat{i})
            uicontrol(vbox,'Style','popup','string',inputFormat{i},'Max',1,'HorizontalAlignment','right','Tag',prompts{i});
        else
            uicontrol(vbox,'Style','edit','string',defaults{i},'HorizontalAlignment','right','Tag',prompts{i});
        end
    end
    set(vbox, 'ColumnSizes', [300 -1], 'RowSizes', repmat(20,1,length(prompts)));                        
    
    % Build cell array to hold input data. This is input 'start' button so
    % that the callback can access the modle data.
    inputData = {projectPath, HPCmodelData, calibGUI_interface_obj};
    
    % Add buttons
    buttonsBox = uiextras.HButtonBox('Parent',outerVbox,'Padding', 3, 'Spacing', 3);             
    uicontrol('Parent',buttonsBox,'String','Start offload calibration', 'TooltipString', sprintf('Start calibration on the cluster.'),'Callback', @startOffloadCalibration, ...
        'UserData',inputData);
    uicontrol('Parent',buttonsBox,'String','Close', 'TooltipString', sprintf('Exit set-up the cluster calibration.'),'Callback', @cancelOffloadCalibration );
    buttonsBox.ButtonSize(1) = 225;       
    
    % Set outte box size.
    set(outerVbox, 'Sizes', [225 -1 30]);
   
    % Wait until the figure closes.
    uiwait(calibOffloadGUI);
    
    function GUIprompts= getPrompts()
    GUIprompts = { 'Type of cluster system:', ...
                    'URL to the cluster:', ...
                    'User name for cluster:', ...
                    'Password for cluster:', ...
                    'Email address for updates (optional):', ...
                    'Full path to folder for the jobs:', ...
                    'Job name:', ...
                    'Queue name (optional):', ...
                    'Node name (optional) :', ...
                    ['Max. MPI jobs (ie total number of nodes):'], ...
                    'CPUs per node per model:', ...
                    'Max. runtime per model:', ...                
                    'Command for pre-job submission  (optional):'};
    end

    function [clusterType, URL, username, password, email, folder, jobName, queue, nodeName, nJobs, nCPUs, walltime, preCommands] = getUserInputData(fig)

        % get GUI prompts. These are used for finding the GUI input objects.
        prompts= getPrompts();

        % Disaggregate user data
        clusterType = findobj(fig, 'Tag',prompts{1});
        clusterTypeValue = clusterType.Value;
        clusterType = clusterType.String{clusterType.Value};

        URL = findobj(fig, 'Tag',prompts{2});
        URL = URL.String;

        username = findobj(fig, 'Tag',prompts{3});
        username = username.String;

        password = findobj(fig, 'Tag',prompts{4});
        password = password.String;

        email = findobj(fig, 'Tag',prompts{5});
        email = email.String;

        folder = findobj(fig, 'Tag',prompts{6});
        folder = folder.String;

        jobName = findobj(fig, 'Tag',prompts{7});
        jobName = jobName.String;

        queue = findobj(fig, 'Tag',prompts{8});
        queue = queue.String;

        nodeName = findobj(fig, 'Tag',prompts{9});
        nodeName = nodeName.String;

        nJobs = findobj(fig, 'Tag',prompts{10});
        nJobs = nJobs.String;

        nCPUs= findobj(fig, 'Tag',prompts{11});
        nCPUs = nCPUs.String;

        walltime= findobj(fig, 'Tag',prompts{12});
        walltime = walltime.String;

        preCommands = findobj(fig, 'Tag',prompts{13});
        preCommands = preCommands.String;

        userData = {clusterTypeValue, URL, username, '', email, folder, jobName, queue, nodeName, nJobs, nCPUs, walltime, preCommands};

    end

    function cancelOffloadCalibration(this,hObject,eventdata)
        close(hObject.Source.Parent.Parent.Parent)
    end

    function startOffloadCalibration(this,hObject,eventdata)

        set(hObject.Source.Parent.Parent.Parent,'Visible','off');

        % Get the input data
        projectPath = this.UserData{1};
        HPCmodelData = this.UserData{2};
        calibGUI_interface_obj = this.UserData{3};

        % Get GUI data
        [clusterType, URL, username, password, email, folder, jobName, queue, nodeName, nJobs, nCPUs, walltime, preCommands] = getUserInputData(hObject.Source.Parent.Parent);

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

        % Update progress
        display('HPC offload progress ...');
        if ~isempty(calibGUI_interface_obj)
            updatetextboxFromDiary(calibGUI_interface_obj);
        end 

        try

            % Create project folder for latter copy to HPC        
            display('   Making project folder on cluster...');
            if ~isempty(calibGUI_interface_obj)
                updatetextboxFromDiary(calibGUI_interface_obj);
            end 

            [sshChannel,SSHresult] = ssh2_command(sshChannel,['mkdir -p ',folder]);
            [sshChannel,SSHresult] = ssh2_command(sshChannel,['mkdir -p ',folder,'/models']);

            % Loop through each model to be calibrated, create a folder, save a text file for the
            % calib options and the model object    
            nModelsUploadFailed=0;
            nModels = size(HPCmodelData,1);
            for i=1:nModels

               display(['   Uploading ',num2str(i),' of ',num2str(nModels),' model data files ...']);           
                if ~isempty(calibGUI_interface_obj)
                    updatetextboxFromDiary(calibGUI_interface_obj);
                end 

               model = HPCmodelData{i,1};
               calibLabel = model.model_label;           
               calibStartDate = HPCmodelData{i,2};
               calibEndDate = HPCmodelData{i,3};
               calibMethod = HPCmodelData{i,4};
               calibMethodSetting = HPCmodelData{i,5};

               % Create model folder
               calibLabel_orig = calibLabel;
               calibLabelFolder{i} =  regexprep(calibLabel,'\W','_');                             
               calibLabelFolder{i} =  regexprep(calibLabelFolder{i},'____','_');                             
               calibLabelFolder{i} =  regexprep(calibLabelFolder{i},'___','_');                             
               calibLabelFolder{i} =  regexprep(calibLabelFolder{i},'__','_');                     
               try
                   [sshChannel,SSHresult] = ssh2_command(sshChannel,['mkdir ',folder,'/models/',calibLabelFolder{i}]);

                   % Move into model folder
                   [sshChannel,SSHresult] = ssh2_command(sshChannel,['cd models/',calibLabelFolder{i}]);

                   % Save calib options text file   
                   [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "',datestr(calibStartDate),' \n" >> ',folder,'/models/',calibLabelFolder{i},'/options.txt']);
                   [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "',datestr(calibEndDate),' \n" >> ',folder,'/models/',calibLabelFolder{i},'/options.txt']);
                   [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "',calibMethod,' \n" >> ',folder,'/models/',calibLabelFolder{i},'/options.txt']);
                   settingNames = fieldnames(calibMethodSetting);
                   for j=1:length(settingNames)
                    if isnumeric(calibMethodSetting.(settingNames{j}))
                        % Set random seed using clock time.
                        if strcmpi(settingNames{j},'iseed') && ~isfinite(calibMethodSetting.(settingNames{j}))                        
                            calibMethodSetting.(settingNames{j}) = floor(mod(datenum(now),1)*1000000);
                        end

                        [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "',settingNames{j},':',num2str(calibMethodSetting.(settingNames{j})),' \n" >> ',folder,'/models/',calibLabelFolder{i},'/options.txt']);
                    else
                        [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "',settingNames{j},':',calibMethodSetting.(settingNames{j}),' \n" >> ',folder,'/models/',calibLabelFolder{i},'/options.txt']);
                    end
                   end


                   % Save model object to .mat file
                   save(fullfile(projectPath,'HPCmodel.mat'), 'model');

                   % Copy .mat to cluster
                   scp_put(sshChannel, 'HPCmodel.mat', [folder,'/models/',calibLabelFolder{i}], projectPath,'HPCmodel.mat');

               catch ME
                   sshChannel  =  ssh2_close(sshChannel);
                   sshChannel = ssh2_config(URL,username,password); 
                   nModelsUploadFailed = nModelsUploadFailed +1;
                   display(['   Upload of model ',calibLabelFolder{i},' failed.']);           
                   display(['   Error message is:',ME.message]);           
                   continue;
               end

               % Delete file
               delete(fullfile(projectPath,'HPCmodel.mat'));

            end

            %Copy .m algorithms folder to HPC
            display('   Zipping and uploading HydroSight algorithms ...');
            if ~isempty(calibGUI_interface_obj)
                updatetextboxFromDiary(calibGUI_interface_obj);
            end
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
            calibLabelFolder = reshape(calibLabelFolder, nJobs, nModelsPerJob);

            % Write file of model names. Each 'mpirun' jobs will open this file and find the requred model name(s) it has 
            % been allocated to calibrate. If more than one model name is
            % listed in a row then the MPI job sequentially runs multiple
            % models. 
            display('   Writing file of model names ...');
            if ~isempty(calibGUI_interface_obj)
                updatetextboxFromDiary(calibGUI_interface_obj);
            end 
            for i=1:nJobs
               % Save calib options text file   
               [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "',strjoin(calibLabelFolder(i,:),','),' \n" >> ',folder,'/ModelNames.csv']);
            end

            display('   Writing mpiexec submission file ...');
            if ~isempty(calibGUI_interface_obj)
                updatetextboxFromDiary(calibGUI_interface_obj);
            end 

            switch clusterType
                case 'PBS'
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
                    display('   Submitting job to the HPC queue...');
                    if ~isempty(calibGUI_interface_obj)
                        updatetextboxFromDiary(calibGUI_interface_obj);
                    end 
                    [sshChannel,SSHresult] = ssh2_command(sshChannel,['cd ',folder, '&& qsub SubmitJobs.in']);
                case 'SLURM'
                    [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "#!/bin/bash \n" >> ',folder,'/SubmitJobs.in']);
                    [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "#SBATCH --job-name=',jobName,' \n" >> ',folder,'/SubmitJobs.in']);
                    if ~isempty(queue)
                       [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "#SBATCH -p ',queue,' \n" >> ',folder,'/SubmitJobs.in']);
                    end
                    [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "#SBATCH --cpus-per-task=',num2str(nCPUs),' \n" >> ',folder,'/SubmitJobs.in']);
                    [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "#SBATCH --time=',walltime,' \n" >> ',folder,'/SubmitJobs.in']);        
                    [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "#SBATCH --array=1-',num2str(nJobs),' \n" >> ',folder,'/SubmitJobs.in']);
                    if ~isempty(email)
                       [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "#SBATCH -mail-type=ALL \n" >> ',folder,'/SubmitJobs.in']);
                       [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "#SBATCH -mail-user=',email,' \n" >> ',folder,'/SubmitJobs.in']);
                    end
                    [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "',preCommands,' \n" >>',folder,'/SubmitJobs.in']);
                    [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "cd ',folder,' \n" >>',folder,'/SubmitJobs.in']);
                    [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "cd algorithms/calibration/Utilities \n" >>',folder,'/SubmitJobs.in']);        
                    [sshChannel,SSHresult] = ssh2_command(sshChannel,['printf "matlab -nodesktop -nosplash -r ''iModel=''\${SLURM_ARRAY_TASK_ID}\$'';calibrateOnCluster;'' \n" >>',folder,'/SubmitJobs.in']);

                    % Submit qsub to call script of tasks.
                    display('   Submitting job to the HPC queue...');
                    if ~isempty(calibGUI_interface_obj)
                        updatetextboxFromDiary(calibGUI_interface_obj);
                    end 
                    [sshChannel,SSHresult] = ssh2_command(sshChannel,['cd ',folder, '&& sbatch SubmitJobs.in']);                
            end

            % Closing connection
            sshChannel  =  ssh2_close(sshChannel);

        catch ME
            display({'   HPC offload failed with the following message:',['     ', ME.message]});
            if ~isempty(calibGUI_interface_obj)
                updatetextboxFromDiary(calibGUI_interface_obj);
            end 

            set(hObject.Source.Parent.Parent.Parent, 'pointer', 'arrow'); 
            drawnow;

            return;        
        end

        display('   HPC offload finished successfully.');  
        if nModelsUploadFailed>0
            display(['   WARNING: Offload failed for ',num2str(nModelsUploadFailed),' models.']);
        end
        if ~isempty(calibGUI_interface_obj)
            updatetextboxFromDiary(calibGUI_interface_obj);
        end 

        set(hObject.Source.Parent.Parent.Parent, 'pointer', 'arrow'); 
        drawnow;

        userData = {clusterType, URL, username, '', email, folder, jobName, queue, nodeName, nJobs, nCPUs, walltime, preCommands};
        
        close (hObject.Source.Parent.Parent.Parent);
    end

end