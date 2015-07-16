function GST()

    % Add Paths
    addpath(genpath(pwd));
    
    % Remove paths to .git folders
    rmpath(genpath( fullfile( pwd, '.git')));
    
    % Load GUI
%    try
         GST_GUI();
%     catch errorData
%         
%         warndlg({'An unexpected error occurred with the user interface.','','After clicking OK, you will be asked to save an error file.','Please email the error file and your model file to timjp@unimelb.edu.au'},'Unexpected Error ...')
%         
%         [fName,pName] = uiputfile({'*.mat'},'Save error file as...');    
%         if fName~=0;
%             fname = fullfile(pName, fName);
%             try
%                 save(fname, 'errorData');  
%             catch
%                 warndlg('The error file could not be saved.','Unexpected File Save Error ...')
%             end
%         end
%     end

end

