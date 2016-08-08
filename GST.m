function GST()

    % Add Paths
    addpath(genpath(pwd));
    
    % Remove paths to .git folders
    rmpath(genpath( fullfile( pwd, '.git')));
    
    % Load GUI
     GST_GUI();


end

