function HydroSight()

    % Add Paths
    addpath(genpath(pwd));
    
    % Remove paths to .git folders
    rmpath(genpath( fullfile( pwd, '.git')));
    
    % Load GUI
     HydroSight_GUI();


end