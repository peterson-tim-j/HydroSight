function HydroSight()

    % Add Paths
%    addpath(pwd);
    addpath(genpath([pwd, filesep, 'algorithms']));
    addpath(genpath([pwd, filesep, 'dataPreparationAnalysis']));
    addpath(genpath([pwd, filesep, 'Examples']));
    addpath(genpath([pwd, filesep, 'GUI']));
    
%     addpath(genpath(pwd));
%     
%     % Remove paths to .git folders
%     if ~isdeployed
%         rmpath(genpath( fullfile( pwd, '.git')));
%     end toat 
%     
    % Load GUI
    try
        % Use GUI Layout Toolbox if it exists.
        if ~isdeployed && ~isempty(ver('layout'))           
            rmpath(genpath(fullfile( pwd, 'GUI','GUI Layout Toolbox 2.3.4')));
        end
        HydroSight_GUI();
    catch ME
        % Check the toolbox for GUIs exists
        if ~isdeployed && isempty(ver('layout')) 
            msgbox({'The GUI cannot be opened. This may be because the GUI Layout Toolbox is ', ...
                    'not installed within Matlab. Please download it using the URL below and', ...
                    'then install it and re-start HydroSight.', ...
                    '', ...
                    'https://www.mathworks.com/matlabcentral/fileexchange/47982-gui-layout-toolbox'}, ...
                    'Toolbox missing: gui-layout-toolbox', 'error');

        else
            if size(ME.stack,1)>0
                functionName = ME.stack(1,1).name;
                functionLine = num2str(ME.stack(1,1).line);
            else
                functionName='';
                functionLine ='';
            end
            msgbox({'An unexpected error occured. To help with fixing the issue please', ...
                    'copy the error message below and submit a bug report to:', ...
                    'https://github.com/peterson-tim-j/HydroSight/issues', ...
                    '', ...
                    ['Message:', ME.message], ...
                    '', ...
                    ['Function:', functionName], ...
                    '', ...
                    ['Line Number:', functionLine]}, ...
                    'Unknown error', 'error');
            
        end
    end


end
