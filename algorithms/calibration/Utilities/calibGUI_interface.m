classdef calibGUI_interface < handle  

properties
    filename='';
    fid=0;
    textboxHandle = '';    
    status='off';
    quitCalibration = false;
    jEdit=[];
end
methods
    function this = calibGUI_interface(textboxHandle, filename)
        % Check the inputs
%         if ~ischar(filename)
%             error('The input for "filename" must be a string for a file name.');
%         end
        if ~isvalid(textboxHandle)
            error('The following input for "textboxHandle" must be a valid graphics handle.');
        end

        % Assign properties
        this.filename = filename;
        this.textboxHandle = textboxHandle;
        
        % Set status
        this.status = 'initialised';
        
        % Open the file
        this.fid = fopen(this.filename,'wt+');
        
        % Empty text box.
        this.textboxHandle.String= {};
        
        this.quitCalibration = false;
    end
    
    function startDiary(this)
       % Start the diary.
        %diary(this.filename);
        this.status = 'on';
        
        % Write initial statement
        display(' Starting HydroSight model calibration ........');
        display(' ');
        
        % Load the existing diary.
        frewind(this.fid);
        updatetextboxFromDiary(this)
                
    end
    
    function updatetextboxFromDiary(this, bestf, bestx, worstf, worstx)



%         % Turn diary off so that the command window is written to the file.
%         diary off;
%         this.status = 'off';        
%         
%         % Read the diary until end-of-file and add each line to the GUI tet
%         % box.
%         while 1
%             
%             % Read line and add line form file to the textbox.
%             try
%                 txt = fgetl(this.fid);
%                 if ischar(txt)
%                     this.textboxHandle.String{length(this.textboxHandle.String)+1} = txt;
%                 else
%                     break;
%                 end
%             catch ME
%                 return
%             end
% 
%         end 
% 
%         % Move the vertical scroll bar to the end        
%         %if isempty(this.jEdit)
%         %    this.jEdit = findjobj(this.textboxHandle,'persist');            
%         %end
%         %jEdit = findjobj(this.textboxHandle,'persist');
%         
%         try
%             %
%             %jEdit = this.jEdit;
%             jEdit = jEdit.getComponent(0).getComponent(0);
%             jEdit.setCaretPosition(jEdit.getDocument.getLength);
%         catch ME
%             % do nothing
%         end
%         
%         diary(this.filename);
%         this.status = 'on';        
    end
    
    function endDiary(this)
        % Close file connection to diary file.
        fclose(this.fid);
        
       % Stop the diary.
        diary off;
        this.status = 'off';        
    end    
    
    function quitCalibrationListener(this,src,evnt)   
        this.quitCalibration =  true;
    end
    
    function [doQuit, existFlag, exitStatus] = getCalibrationQuitState(this)   
        doQuit = this.quitCalibration;
        existFlag = 0;
        exitStatus = '';        
        if doQuit 
            existFlag = -1;
            exitStatus = 'User quit';
            msgbox('The calibration algorithm has now been quit. Model simulations for the last parameter set are now to be undertaken. Click OK and please wait.','Quiting calibration...','warn');
        end
    end
    
end
end
