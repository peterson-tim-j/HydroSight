function HydroSight()

    % Add Paths
    addpath(genpath(pwd));
    
    % Remove paths to .git folders
    rmpath(genpath( fullfile( pwd, '.git')));
    
    % Load GUI
    try
        % Use GUI Layout Toolbox if it exists.
        if ~isdeployed && ~isempty(ver('layout'))            
            rmpath(genpath(fullfile( pwd, 'GUI','GUI Layout Toolbox 2.3.4')));
        end
        
        HydroSight_GUI();
    catch 
        % Check the toolbox for GUIs exists
        if ~isdeployed && isempty(ver('layout')) && ispc
            msgbox({'The GUI cannot be opened. This may be because the GUI Layout Toolbox is ', ...
                    'not installed within Matlab. Please download it using the URL below and', ...
                    'then install it and re-start HydroSight.', ...
                    '', ...
                    'https://www.mathworks.com/matlabcentral/fileexchange/47982-gui-layout-toolbox'}, ...
                    'Toolbox missing: gui-layout-toolbox', 'error');

        end
    end


end