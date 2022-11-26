function makeStandaloneHydroSight()
%BUILD_DEPLOYED Build deployed stand alone hydrosight

    % Clear everything so that .mex files can be moved
    clear all force

    % Add Paths
    addpath(genpath([pwd, filesep, 'algorithms']));
    addpath(genpath([pwd, filesep, 'GUI']));    

    % Check compiler is installed.
    allAddOns =  matlab.addons.installedAddons;
    if ~any(cellfun( @(x) strcmp('MATLAB Compiler' , x),allAddOns.Name))
        errordlg('The add-on "MATLAB Compiler" must be installed before deployment.','Add-on not installed')
        return
    end

    try
        % Build C code
        Build_C_code()
    catch ME
        error(['Compiling C-code failed: ',ME.message]);        
    end

    % Check for required addons   
    if ~any(cellfun( @(x) strcmp("GUI Layout Toolbox" , x),allAddOns.Name))
        errordlg('The add-on "GUI Layout Toolbox" must be installed before deployment.','Add-on not installed')
        return
    end
        
    
    % Get all folders
    parentFolders = dir();
    parentFolders(~[parentFolders.isdir]) = [];  %remove non-directories
    
    % Look through each folder and get files
    allFiles = {};
    for i=1:size(parentFolders,1)
        if strcmp(parentFolders(i).name,'.') || strcmp(parentFolders(i).name,'..') ... 
        || strcmp(parentFolders(i).name,'documentation') || strcmp(parentFolders(i).name,'.git') ...
        || strcmp(parentFolders(i).name,'testing') || strcmp(parentFolders(i).name,'resources') ...
        || strcmp(parentFolders(i).name,'.github') || strcmp(parentFolders(i).name,'HydroSight_installer')
            continue
        end
        cd(parentFolders(i).name);
        files =  dir('**/*.*');
        files([files.isdir]) = [];  %remove directories
        for j=1:size(files,1)
            [~,~,ext] = fileparts(files(j).name);
            if ispc
                if strcmp(ext,'.m') || strcmp(ext,'.mexw64') || strcmp(ext,'.mat') 
                    allFiles = [allFiles; fullfile(files(j).folder, files(j).name)]; %#ok<AGROW>
                end
            else
                if strcmp(ext,'.m') || strcmp(ext,'.mexa64') || strcmp(ext,'.mat')
                    allFiles = [allFiles; fullfile(files(j).folder, files(j).name)]; %#ok<AGROW>
                end
            end
        end
        cd ..
    end

    % Remove folder with examples
    ind = contains(allFiles, fullfile('HydroSight','algorithms','models','TransferNoise','Example_model'));
    allFiles = allFiles(~ind);

    % Create folder for files
    fname = 'HydroSight_installer';
    status = mkdir(fname);
    if status~=1
        error('Folder could not be created. Check the user has rights to create folders within the current folder.');
    end

    % Get current version.
    versionNumber = getHydroSightVersion();

    % Get path to GUI layout addon
    % Code from: https://au.mathworks.com/matlabcentral/answers/460153-how-to-find-installation-folder-for-matlab-add-ons-via-command-line#answer_598560
    mngr        = com.mathworks.addons_toolbox.ToolboxManagerForAddOns();
    installed   = cell(mngr.getInstalled());
    myTb        = installed{find(cellfun(@(tb) strcmp(tb.getName(), 'GUI Layout Toolbox'), installed), 1)};
    identifier  = char(myTb.getInstallationIdentifier());
    AddonsFolder   = extractBefore(identifier, '|');
    AddonsFolder = fullfile(AddonsFolder,'layout','+uix','Resources');
    allFiles = [allFiles; AddonsFolder];

    % Build options variable for deployment.
    appName = 'HydroSight';
    opts = compiler.build.StandaloneApplicationOptions('HydroSight.m');
    opts.AdditionalFiles = allFiles;
    opts.Verbose = 'on';
    opts.AppFile = 'HydroSight.m';
    opts.OutputDir = ['.',filesep,fname];
    opts.ExecutableName = appName;
    opts.ExecutableVersion = versionNumber;
    opts.ExecutableSplashScreen = fullfile('GUI', 'icons','splash.png');
    opts.ExecutableIcon  = fullfile('GUI', 'icons','icon.png');
    opts.AutoDetectDataFiles = 'off';    
    
    % Build executable
    if ispc
        results = compiler.build.standaloneWindowsApplication(opts);
    else
        results = compiler.build.standaloneApplication(opts);
    end

    % Create installer options
    opts = compiler.package.InstallerOptions(results);
    opts.ApplicationName = appName;
    opts.InstallerName = ['install_',appName];
    opts.AuthorCompany = 'Monash University';
    opts.AuthorName = 'Dr Tim Peterson';
    opts.AuthorEmail = 'tim.peterson@monash.edu';
    opts.Description = ['HydroSight is a highly flexible statistical toolbox for getting ', ...
                        'more quantitiative insights from groundwater monitoring data.', ...
                        'Currently, it contains a groundwater hydrograph time-series ', ...
                        'modeling package that facilitates the following:', char  newline, ...
                        '  1. Decomposition of hydrographs into individual drivers, such as climate and pumping.', char  newline, ...
                        '  2. Prediction groundwater level forward and backward in time for a given pump and climate scenario.', char  newline, ...
                        '  3. Interpolation of a observed hydrograph to a fixed time-step.', char  newline, ...
                        '  4. Identification of data errors and outliers.', char  newline, ...
                        '  5. Estimation of recharge, and other fluxes, over time.'];
    opts.Summary = 'HydroSight is a statistical toolbox for data-driven hydrogeological insights.';
    opts.OutputDir = ['.',filesep,fname];
    if ispc
        opts.Shortcut = ['.',filesep,fname,filesep,appName,'.exe'];
        opts.InstallerIcon = fullfile('GUI', 'icons','icon.png');
        opts.InstallerSplash = fullfile('GUI','icons', 'splash.png');        
    end
    opts.Version = versionNumber;
    opts.InstallerLogo  =  fullfile('GUI','icons', 'splashInstaller.png');
    
    % Create installer
    compiler.package.installer(results,'Options',opts);

end


