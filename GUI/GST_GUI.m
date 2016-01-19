classdef GST_GUI < handle  
    %GST_GUI Summary of this class goes here
    %   Detailed explanation goes here
    
    %class properties - access is private so nothing else can access these
    %variables. Useful in different sitionations
    properties
        % Version number
        versionNumber = 1.1;
        
        % Model types supported
        modelTypes = {'model_TFN', 'ExpSmooth'};
        
        % GUI properies for the overall figure.
        FigureSplash
        Figure;        
        figure_Menu
        figure_contextMenu
        figure_examples
        figure_Help
        figure_Layout 
        
        % GUI properties for the individual tabs.
        tab_Project
        tab_DataPrep;
        tab_ModelConstruction;
        tab_ModelCalibration;        
        tab_ModelSimulation;
        
        % Store model data
        models
        
        % Store the data preparation analysis results;
        dataPrep
        
        % Copies of data
        copiedData
        
        % File name for the current set of models
        project_fileName
    end
    
    methods
        
        function this = GST_GUI

%             % Check that the date is prior to end of 2015. If so, don't
%             % continue. This is required because university legal requested
%             % that the code not be distributed beyond the ARC POs until a
%             % legal statement is provided.
%             if now >= datenum(2015,10,1) && now <= datenum(2015,12,31)
%                 warndlg({'This beta version of the toolkit will expire on Jan. 1 2016.','','Contact Tim Peterson (timjp@unimelb.edu.au) for a new version.'},'Software soon to expire ...');
%             elseif now > datenum(2015,12,31)
%                 warndlg({'This beta version of the toolkit has expired.','','Contact Tim Peterson (timjp@unimelb.edu.au) for a new version.'},'Software soon to expire ...');
%                 return;
%             end
                            
            %--------------------------------------------------------------
            % Open a window and add some menus
            this.Figure = figure( ...
                'Name', 'The Groundwater Statistical Toolbox', ...
                'NumberTitle', 'off', ...
                'MenuBar', 'none', ...
                'Toolbar', 'none', ...
                'HandleVisibility', 'off', ...
                'Visible','off', ...
                'CloseRequestFcn',@this.onExit); 
            
            % Show splash (if code not deployed)
            if ~isdeployed
               onAbout(this, [],[]);
            end
            
            % Set window Size
            windowHeight = this.Figure.Parent.ScreenSize(4);
            windowWidth = this.Figure.Parent.ScreenSize(3);
            figWidth = 0.8*windowWidth;
            figHeight = 0.6*windowHeight;            
            this.Figure.Position = [(windowWidth - figWidth)/2 (windowHeight - figHeight)/2 figWidth figHeight];
            this.Figure.Visible = 'off';
            
            
            % Set default panel color
            warning('off');
            uiextras.set( this.Figure, 'DefaultBoxPanelTitleColor', [0.7 1.0 0.7] );
            warning('on');
            
            % + File menu
            this.figure_Menu = uimenu( this.Figure, 'Label', 'File' );
            uimenu( this.figure_Menu, 'Label', 'Set Project Folder ...', 'Callback', @this.onSetProjectFolder);
            uimenu( this.figure_Menu, 'Label', 'Open Project...', 'Callback', @this.onOpen);
            uimenu( this.figure_Menu, 'Label', 'Save Project as ...', 'Callback', @this.onSaveAs );
            uimenu( this.figure_Menu, 'Label', 'Save Project', 'Callback', @this.onSave);
            uimenu( this.figure_Menu, 'Label', 'Exit', 'Callback', @this.onExit,'Separator','on' );

            % + Examples menu
            this.figure_examples = uimenu( this.Figure, 'Label', 'Examples' );
            uimenu( this.figure_examples, 'Label', 'TFN model - Landuse change', 'Tag','TFN - LUC','Callback', @this.onExamples );
            uimenu( this.figure_examples, 'Label', 'TFN model - Pumping and climate', 'Tag','TFN - Pumping','Callback', @this.onExamples );

            % + Help menu
            this.figure_Help = uimenu( this.Figure, 'Label', 'Help' );
            uimenu(this.figure_Help, 'Label', 'Overview', 'Tag','doc_Overview','Callback', @this.onDocumentation);
            uimenu(this.figure_Help, 'Label', 'User Interface', 'Tag','doc_GUI','Callback', @this.onDocumentation);
            uimenu(this.figure_Help, 'Label', 'Programmatic Use', 'Tag','doc_Programmatically','Callback', @this.onDocumentation);            
            if isdeployed
                uimenu(this.figure_Help, 'Label', 'Calibration Fundementals','Tag','doc_Calibration','Callback', @this.onDocumentation);            
                uimenu(this.figure_Help, 'Label', 'Publications', 'Tag','doc_Publications','Callback', @this.onDocumentation);
            else
                uimenu(this.figure_Help, 'Label', 'Calibration Fundementals','Tag','doc_Calibration','Callback', @this.onDocumentation);
                uimenu(this.figure_Help, 'Label', 'Algorithm Documentation', 'Tag','Algorithms','Callback', @this.onDocumentation);                
                uimenu(this.figure_Help, 'Label', 'Publications', 'Tag','doc_Publications','Callback', @this.onDocumentation);                
            end
            
            uimenu(this.figure_Help, 'Label', 'Check for updates at GitHub', 'Tag','doc_GitHubUpdate','Callback', @this.onGitHub,'Separator','on');
            uimenu(this.figure_Help, 'Label', 'Submit bug report to GitHub', 'Tag','doc_GitHubIssue','Callback', @this.onGitHub);
            
            
            uimenu(this.figure_Help, 'Label', 'License and Disclaimer', 'Tag','doc_Publications','Callback', @this.onLicenseDisclaimer,'Separator','on');
            uimenu(this.figure_Help, 'Label', 'About', 'Callback', @this.onAbout );

            %Create Panels for different windows       
            this.figure_Layout = uiextras.TabPanel( 'Parent', this.Figure, 'Padding', ...
                5, 'TabSize',127,'FontSize',8);
            this.tab_Project.Panel = uiextras.Panel( 'Parent', this.figure_Layout, 'Padding', 5, ...
                'Title', 'Project Description', 'Tag','ProjectDescription');            
            this.tab_DataPrep.Panel = uiextras.Panel( 'Parent', this.figure_Layout, 'Padding', 5, ...
                'Title', 'Data Preparation', 'Tag','DataPreparation');
            this.tab_ModelConstruction.Panel = uiextras.Panel( 'Parent', this.figure_Layout, 'Padding', 5, ...
                'Title', 'Model Construction', 'Tag','ModelConstruction');
            this.tab_ModelCalibration.Panel = uiextras.Panel( 'Parent', this.figure_Layout, 'Padding', 5, ...
                'Title', 'Model Calibration', 'Tag','ModelCalibration');
            this.tab_ModelSimulation.Panel = uiextras.Panel( 'Parent', this.figure_Layout, 'Padding', 5, ...
                'Title', 'Model Simulation', 'Tag','ModelSimulation');
            this.figure_Layout.TabNames = {'Project Description', 'Data Preparation','Model Construction', 'Model Calibration','Model Simulation'};
            this.figure_Layout.SelectedChild = 1;
           
%%          Layout Tab1 - Project description
            %------------------------------------------------------------------
            % Project title
            hbox1t1 = uiextras.VBoxFlex('Parent', this.tab_Project.Panel,'Padding', 3, 'Spacing', 3);
            uicontrol( 'Parent', hbox1t1,'Style','text','String','Project Title: ','HorizontalAlignment','left', 'Units','normalized');            
            this.tab_Project.project_name = uicontrol( 'Parent', hbox1t1,'Style','edit','HorizontalAlignment','left', 'Units','normalized','TooltipString','Input a project title. This is an optional input to assist project management.');            
            
            % Empty row spacer
            uicontrol( 'Parent', hbox1t1,'Style','text','String','','Units','normalized');                      
                        
            % Project description
            uicontrol( 'Parent', hbox1t1,'Style','text','String','Project Description: ','HorizontalAlignment','left', 'Units','normalized');                      
            this.tab_Project.project_description = uicontrol( 'Parent', hbox1t1,'Style','edit','HorizontalAlignment','left', 'Units','normalized','Min',1,'Max',100,'TooltipString','Input an extended project description. This is an optional input to assist project management.');            
            
            % Set sizes
            set(hbox1t1, 'Sizes', [20 20 20 20 -1]);

%%          Layout Tab2 - Data Preparation
            % -----------------------------------------------------------------
            % Declare panels        
            hbox1t2 = uiextras.HBoxFlex('Parent', this.tab_DataPrep.Panel,'Padding', 3, 'Spacing', 3);
            vbox1t2 = uiextras.VBoxFlex('Parent',hbox1t2,'Padding', 3, 'Spacing', 3);
            vbox3t2 = uiextras.HButtonBox('Parent',vbox1t2,'Padding', 3, 'Spacing', 3);             
            
            % Create table for model construction
            cnames1t2 ={'<html><center>Select<br />Bore</center></html>', ...                                                 
                        '<html><center>Obs. Head<br />File</center></html>', ...   
                        '<html><center>Bore<br />ID</center></html>', ...   
                        '<html><center>Bore Depth<br />(Below Surface)</center></html>', ...   
                        '<html><center>Surface<br />Elevation</center></html>', ...   
                        '<html><center>Casing Length<br />(above surface)</center></html>', ...   
                        '<html><center>Construction<br />Date (dd/mm/yy)</center></html>', ...   
                        '<html><center>Check<br />Start Date?</center></html>', ...                           
                        '<html><center>Check<br />End Date?</center></html>', ...                                                   
                        '<html><center>Check Head<br />Above Bore Depth?</center></html>', ...                      
                        '<html><center>Check Head<br />Below Casing?</center></html>', ...                      
                        '<html><center>Threshold for Max. Daily abs(Head)<br />Change</center></html>', ...
                        '<html><center>Threshold Duration for<br />Constant Head (days)?</center></html>', ...
                        '<html><center>Auto-Outlier<br />Num. St. dev?</center></html>', ...                        
                        '<html><center>Analysis<br />Status</center></html>', ...
                        '<html><center>No. Erroneous<br />Obs.</center></html>', ...
                        '<html><center>No. Outlier<br />Obs.</center></html>', ...
                        };
            cformats1t2 = {'logical', 'char', 'char','numeric','numeric','numeric','char','logical','logical','logical','logical','numeric','numeric','numeric','char','char','char'};
            cedit1t2 = logical([1 1 1 1 1 1 1 1 1 1 1 1 1 1 0 0 0]);            
            rnames1t2 = {[1]};
            toolTipStr = ['<html>Use this table to detect and remove erroneous groundwater level observations. This step is provided to ensure <br>' ...
                  'groundwater time-series models are built using reliable data. However, it is not required for building time-series models and <br>', ...
                  'is independent from the model construction, calibaration and simulation steps.<br>', ...
                  'Below are tips for undertaking the analysis:<br>', ... 
                  '<ul type="bullet type">', ...
                  '<li>Observation resulting from known problems (eg pump tests, failed bores) must be removed from the input data prior to this analysis.<br>', ...
                  '<li>The observation start and end date can be check to be within the construction date and today''s date.<br>', ...
                  '<li>The water level can be checked to ensure it is above the bottom of the bore.<br>', ...
                  '<li>The water level can be checked to ensure it is below the bore casing.<br>', ...
                  '<li>The daily absolute rate of water level change can be checked to ensure it is below a user set threshold.<br>', ...
                  '<li>Periods of constant water level beyond a user set threshold can be identified.<br>', ...
                  '<li>Outlier observations can be identified using the double-exponential smoothing model.<br>', ...
                  '<li>The outlier analysis estimates the standard deviation of the noise & observations beyond a user set number of standard deviations are omitted.<br>', ...
                  '<li><b>Right-click</b> displays a menu for copying, pasting, inserting and deleting rows. Use the <br>', ...
                  'left tick-box to define the rows for copying, deleting etc.<br>', ...
                  '<li>Use the window to the right for selecting the bore ID and to view and edit results.<br>', ...
                  '<li>To view the analysis results place the cursor in any table grid-cell except the head file or bore ID cells.<br>', ...
                  '<li>Sort the rows by clicking on the column headings. Below are more complex sorting options:<ul>', ...
                  '      <li><b>Click</b> to sort in ascending order.<br>', ...
                  '      <li><b>Shift-click</b> to sort in descending order.<br>', ...    
                  '      <li><b>Ctrl-click</b> to sort secondary in ascending order.<b>Shift-Ctrl-click</b> for descending order.<br>', ...    
                  '      <li><b>Click again</b> again to change sort direction.<br>', ...
                  '      <li><b>Click a third time </b> to return to the unsorted view.', ...
                  ' </ul></ul>'];
            
            % Assign column headings to the top-left panel
            data = {false, '', '',0, 0, 0, '01/01/1900',true, true, true, true, 10, 120, 3, ...
                '<html><font color = "#FF0000">Bore not analysed.</font></html>', ...
                ['<html><font color = "#808080">','(NA)','</font></html>'], ...
                ['<html><font color = "#808080">','(NA)','</font></html>']};
            this.tab_DataPrep.Table = uitable('Parent',vbox1t2,'ColumnName',cnames1t2,...
                'ColumnEditable',cedit1t2,'ColumnFormat',cformats1t2,'RowName', rnames1t2, ...
                'CellSelectionCallback', @this.dataPrep_tableSelection,...
                'Data',data,'Tag','Data Preparation', ...
                'TooltipString', toolTipStr);

            % Find java sorting object in table
            try
                this.figure_Layout.Selection = 2;
                drawnow();
                jscrollpane = findjobj(this.tab_DataPrep.Table);
                jtable = jscrollpane.getViewport.getView;

                % Turn the JIDE sorting on
                jtable.setSortable(true);
                jtable.setAutoResort(true);
                jtable.setMultiColumnSortable(true);
                jtable.setPreserveSelectionsAfterSorting(true);            
            catch
                warndlg('Creating of the GUI row-sorting module failed for the data preparation table.');
            end
            
                        
            % Add buttons to top left panel               
            uicontrol('Parent',vbox3t2,'String','Append Table Data','Callback', @this.onImportTable, 'Tag','Data Preparation', 'TooltipString', sprintf('Append a .csv file of table data to the table below. \n Use this feature to efficiently analyse a large number of bores.') );
            uicontrol('Parent',vbox3t2,'String','Export Table Data','Callback', @this.onExportTable, 'Tag','Data Preparation', 'TooltipString', sprintf('Export a .csv file of the table below.') );
            uicontrol('Parent',vbox3t2,'String','Analyse Selected Bores','Callback', @this.onAnalyseBores, 'Tag','Data Preparation', 'TooltipString', sprintf('Use the tick-box below to select the models to analyse then click here. \n After analysing, the status is given in the right most column.') );            
            uicontrol('Parent',vbox3t2,'String','Export Results','Callback', @this.onExportResults, 'Tag','Data Preparation', 'TooltipString', sprintf('Export a .csv file of the analyses results. \n After analysing, the .csv file can be used in the time-series modelling.') );            
            vbox3t2.ButtonSize(1) = 225;            
            
            % Create vbox for the various model options
            this.tab_DataPrep.modelOptions.vbox = uiextras.VBoxFlex('Parent',hbox1t2,'Padding', 3, 'Spacing', 3, 'DividerMarkings','off');
            
            % Add model options panel for bore IDs
            dynList = [];
            vbox4t2 = uiextras.VBox('Parent',this.tab_DataPrep.modelOptions.vbox, 'Padding', 3, 'Spacing', 3, 'Visible','on');
            uicontrol( 'Parent', vbox4t2,'Style','text','String',sprintf('%s\n%s%s','Please select the Bore ID(s) for the analysis:'), 'Units','normalized');            
            this.tab_DataPrep.modelOptions.boreIDList = uicontrol('Parent',vbox4t2,'Style','list','BackgroundColor','w', ...
                'String',dynList(:),'Value',1,'Callback',...
                @this.dataPrep_optionsSelection, 'Units','normalized');     
            
             % Create vbox for showing a table of results and plotting hydrographs
            this.tab_DataPrep.modelOptions.resultsOptions.box = uiextras.VBoxFlex('Parent', this.tab_DataPrep.modelOptions.vbox,'Padding', 3, 'Spacing', 3, 'DividerMarkings','off');
            panelt2 = uipanel('Parent',this.tab_DataPrep.modelOptions.resultsOptions.box);
            this.tab_DataPrep.modelOptions.resultsOptions.plots = axes( 'Parent', panelt2); 
            
            this.tab_DataPrep.modelOptions.resultsOptions.table = uitable('Parent',this.tab_DataPrep.modelOptions.resultsOptions.box, ...
                'ColumnName',{'Year', 'Month', 'Day', 'Hour', 'Minute', 'Head', 'Date_Error', 'Duplicate_Date_Error', 'Min_Head_Error','Max_Head_Error','Rate_of_Change_Error','Const_Hear_Error','Outlier_Obs'}, ... 
                'ColumnFormat', {'numeric','numeric','numeric','numeric', 'numeric','numeric','logical','logical','logical','logical','logical','logical','logical'}, ...
                'ColumnEditable', [false(1,6) true(1,7)], ...
                'Tag','Data Preparation - results table', ...
                'CellEditCallback', @this.dataPrep_resultsTableEdit, ...,
                'TooltipString', 'Results data from the bore data analysis for erroneous observations and outliers.');
                        
            
            % Resize the panels            
            set(vbox1t2, 'Sizes', [30 -1]);
            set(vbox4t2, 'Sizes', [30 -1]);            
            set(this.tab_DataPrep.modelOptions.resultsOptions.box, 'Sizes',[-1 -1]);
            set(this.tab_DataPrep.modelOptions.vbox, 'Sizes',[0 0]);
            
            
            % Hide the panel for the analysis opens and results
            set(this.tab_DataPrep.modelOptions.vbox,'Heights',[0 0]);
            
%           Add context menu
            this.Figure.UIContextMenu = uicontextmenu(this.Figure,'Visible','on');
            
            % Add items
            uimenu(this.Figure.UIContextMenu,'Label','Copy selected row','Callback',@this.rowAddDelete);
            uimenu(this.Figure.UIContextMenu,'Label','Paste rows','Callback',@this.rowAddDelete,'Separator','on');
            uimenu(this.Figure.UIContextMenu,'Label','Insert row above selection','Callback',@this.rowAddDelete);
            uimenu(this.Figure.UIContextMenu,'Label','Insert row below selection','Callback',@this.rowAddDelete);            
            uimenu(this.Figure.UIContextMenu,'Label','Delete selected rows','Callback',@this.rowAddDelete,'Separator','on');
            uimenu(this.Figure.UIContextMenu,'Label','Select all','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Select none','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Invert selection','Callback',@this.rowSelection);

            % Attach menu to the construction table
            set(this.tab_DataPrep.Table,'UIContextMenu',this.Figure.UIContextMenu);
                        
            % Add table name to .UserData
            set(this.tab_DataPrep.Table.UIContextMenu,'UserData','this.tab_DataPrep.Table');            
            
%%          Layout Tab3 - Model Construction
            %------------------------------------------------------------------
            % Declare panels        
            hbox1t3 = uiextras.HBoxFlex('Parent', this.tab_ModelConstruction.Panel,'Padding', 3, 'Spacing', 3);
            vbox1t3 = uiextras.VBoxFlex('Parent',hbox1t3,'Padding', 3, 'Spacing', 3);
            vbox3t3 = uiextras.HButtonBox('Parent',vbox1t3,'Padding', 3, 'Spacing', 3);             
            
            % Create table for model construction
            cnames1t3 ={'<html><center>Select<br />Model</center></html>', ... 
                        '<html><center>Model<br />Label</center></html>', ...   
                        '<html><center>Obs. Head<br />File</center></html>', ...   
                        '<html><center>Forcing Data<br />File</center></html>', ...   
                        '<html><center>Coordinates<br />File</center></html>', ...   
                        '<html><center>Bore<br />ID</center></html>', ...   
                        '<html><center>Model<br />Type</center></html>', ...                           
                        '<html><center>Model<br />Options</center></html>', ...                           
                        '<html><center>Build<br />Status</center></html>'};
            cformats1t3 = {'logical', 'char', 'char','char','char','char',this.modelTypes,'char','char'};
            cedit1t3 = logical([1 1 1 1 1 1 1 1 0]);            
            rnames1t3 = {[1]};
            toolTipStr = ['<html>Use this table to define the model label, input data, bore ID and model structure for each model. <br> <br>' ...
                  'Once all inputs are defined, use the button above to build the model, after which the selected models can be calibrated.<br>', ...
                  'Below are tips for building models:<br>', ... 
                  '<ul type="bullet type">', ...
                  '<li>The model label must be unique.<br>', ...
                  '<li><b>Right-click</b> displays a menu for copying, pasting, inserting and deleting rows. Use the <br>', ...
                  'left tick-box to define the rows for copying, deleting etc.<br>', ...
                  '<li>Use the window to the right for selecting the bore ID and model options.<br>', ...
                  '<li>Sort the rows by clicking on the column headings. Below are more complex sorting options:<ul>', ...
                  '      <li><b>Click</b> to sort in ascending order.<br>', ...
                  '      <li><b>Shift-click</b> to sort in descending order.<br>', ...    
                  '      <li><b>Ctrl-click</b> to sort secondary in ascending order.<b>Shift-Ctrl-click</b> for descending order.<br>', ...    
                  '      <li><b>Click again</b> again to change sort direction.<br>', ...
                  '      <li><b>Click a third time </b> to return to the unsorted view.', ...
                  ' </ul></ul>'];
            
            % Assign column headings to the top-left panel
            data = cell(1,9);
            data{1,9} = '<html><font color = "#FF0000">Model not built.</font></html>';
            this.tab_ModelConstruction.Table = uitable('Parent',vbox1t3,'ColumnName',cnames1t3,...
                'ColumnEditable',cedit1t3,'ColumnFormat',cformats1t3,'RowName', rnames1t3, ...
                'CellSelectionCallback', @this.modelConstruction_tableSelection,...
                'CellEditCallback', @this.modelConstruction_tableEdit,...
                'Data',data,'Tag','Model Construction', ...
                'TooltipString', toolTipStr);

            % Find java sorting object in table
            try
                this.figure_Layout.Selection = 3;
                drawnow();
                jscrollpane = findjobj(this.tab_ModelConstruction.Table);
                jtable = jscrollpane.getViewport.getView;

                % Turn the JIDE sorting on
                jtable.setSortable(true);
                jtable.setAutoResort(true);
                jtable.setMultiColumnSortable(true);
                jtable.setPreserveSelectionsAfterSorting(true);            
            catch
                warndlg('Creating of the GUI row-sorting module failed for the model construction table.');
            end
                        
            % Add buttons to top left panel               
            uicontrol('Parent',vbox3t3,'String','Append Table Data','Callback', @this.onImportTable, 'Tag','Model Construction', 'TooltipString', sprintf('Append a .csv file of table data to the table below. \n Use this feature to efficiently build a large number of models.') );
            uicontrol('Parent',vbox3t3,'String','Export Table Data','Callback', @this.onExportTable, 'Tag','Model Construction', 'TooltipString', sprintf('Export a .csv file of the table below.') );
            uicontrol('Parent',vbox3t3,'String','Build Selected Models','Callback', @this.onBuildModels, 'Tag','Model Construction', 'TooltipString', sprintf('Use the tick-box below to select the models to build then click here. \n After building, the status is given in the right most column.') );                        
            vbox3t3.ButtonSize(1) = 225;
            
            % Create vbox for the various model options
            this.tab_ModelConstruction.modelOptions.vbox = uiextras.VBoxFlex('Parent',hbox1t3,'Padding', 3, 'Spacing', 3, 'DividerMarkings','off');
            
            % Add model options panel for bore IDs
            dynList = [];
            vbox4t3 = uiextras.VBox('Parent',this.tab_ModelConstruction.modelOptions.vbox, 'Padding', 3, 'Spacing', 3, 'Visible','on');
            uicontrol( 'Parent', vbox4t3,'Style','text','String',sprintf('%s\n%s%s','Please select the Bore ID(s) for the model:'), 'Units','normalized');            
            this.tab_ModelConstruction.boreIDList = uicontrol('Parent',vbox4t3,'Style','list','BackgroundColor','w', ...
                'String',dynList(:),'Value',1,'Callback',...
                @this.modelConstruction_optionsSelection, 'Units','normalized');            

            % Add model options panel for decriptions of each model type
            dynList = [];
            vbox5t3 = uiextras.VBox('Parent',this.tab_ModelConstruction.modelOptions.vbox, 'Padding', 3, 'Spacing', 3, 'Visible','on');
            uicontrol( 'Parent', vbox5t3,'Style','text','String',sprintf('%s\n%s%s','Below is a decsription of the selected model type:'), 'Units','normalized');            
            this.tab_ModelConstruction.modelDescriptions = uicontrol( 'Parent', vbox5t3,'Style','text','String','(No model type selected.)', 'HorizontalAlignment','left','Units','normalized');                        
            set(vbox5t3, 'Sizes', [30 -1]);
            
            % Resize the panels
            set(vbox1t3, 'Sizes', [30 -1]);
            set(hbox1t3, 'Sizes', [-3 -1]);
            set(vbox4t3, 'Sizes', [30 -1]);            
            
            % Build model options for each model type                
            includeModelOption = false(length(this.modelTypes),1);
            for i=1:length(this.modelTypes);
                switch this.modelTypes{i}
                    case 'model_TFN'
                        this.tab_ModelConstruction.modelTypes.model_TFN.hbox = uiextras.HBox('Parent',this.tab_ModelConstruction.modelOptions.vbox,'Padding', 3, 'Spacing', 3);
                        this.tab_ModelConstruction.modelTypes.model_TFN.buttons = uiextras.VButtonBox('Parent',this.tab_ModelConstruction.modelTypes.model_TFN.hbox,'Padding', 3, 'Spacing', 3);
                        uicontrol('Parent',this.tab_ModelConstruction.modelTypes.model_TFN.buttons,'String','<','Callback', @this.onApplyModelOptions, 'TooltipString','Copy model option to current model.');
                        uicontrol('Parent',this.tab_ModelConstruction.modelTypes.model_TFN.buttons,'String','<<','Callback', @this.onApplyModelOptions_selectedBores, 'TooltipString','Copy model option to selected models (of the current model type).');
                        this.tab_ModelConstruction.modelTypes.model_TFN.obj = model_TFN_gui( this.tab_ModelConstruction.modelTypes.model_TFN.hbox);
                        this.tab_ModelConstruction.modelTypes.model_TFN.hbox.Widths=[40 -1];
                        includeModelOption(i) = true;
                    case 'ExpSmooth'  
                        this.tab_ModelConstruction.modelTypes.ExpSmooth.hbox = uiextras.HBox('Parent',this.tab_ModelConstruction.modelOptions.vbox,'Padding', 3, 'Spacing', 3);                        
                        uicontrol( 'Parent', this.tab_ModelConstruction.modelTypes.ExpSmooth.hbox,'Style','text', ...
                        'String','The exponential smoothing model does not have any model option.','HorizontalAlignment','center', 'Units','normalized');            
                    
                        % Setup GUI.
                        this.tab_ModelConstruction.modelTypes.ExpSmooth.obj = ExpSmooth_gui( this.tab_ModelConstruction.modelTypes.ExpSmooth.hbox);
                        
                        includeModelOption(i) = true;
                        
                    otherwise
                        warndlg({['The following model type is not integrated into the user interface: ', this.modelTypes{i}], ...
                            '', 'It could not be included in the user interface.'},'Model type unavailable ...');
                        includeModelOption(i) = false;
                end                
            end
            
            % Redefine model options to include only those that are
            % established in the user interface.
            this.tab_ModelConstruction.Table.ColumnFormat{7} = this.modelTypes(includeModelOption);
            
            % Hide all modle option vboxes 
            this.tab_ModelConstruction.modelOptions.vbox.Heights = zeros(size(this.tab_ModelConstruction.modelOptions.vbox.Heights));

%           Add context menu
            % Create menu
            this.Figure.UIContextMenu = uicontextmenu(this.Figure,'Visible','on');
            
            % Add items
            uimenu(this.Figure.UIContextMenu,'Label','Copy selected row','Callback',@this.rowAddDelete);
            uimenu(this.Figure.UIContextMenu,'Label','Paste rows','Callback',@this.rowAddDelete,'Separator','on');
            uimenu(this.Figure.UIContextMenu,'Label','Insert row above selection','Callback',@this.rowAddDelete);
            uimenu(this.Figure.UIContextMenu,'Label','Insert row below selection','Callback',@this.rowAddDelete);            
            uimenu(this.Figure.UIContextMenu,'Label','Delete selected rows','Callback',@this.rowAddDelete,'Separator','on');
            uimenu(this.Figure.UIContextMenu,'Label','Select all','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Select none','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Invert selection','Callback',@this.rowSelection);
                        
            % Attach menu to the construction table
            set(this.tab_ModelConstruction.Table,'UIContextMenu',this.Figure.UIContextMenu);
                        
            % Add table name to .UserData
            set(this.tab_ModelConstruction.Table.UIContextMenu,'UserData','this.tab_ModelConstruction.Table');
            
            
%%          Layout Tab4 - Calibrate models
            %------------------------------------------------------------------
            hbox1t4 = uiextras.HBoxFlex('Parent', this.tab_ModelCalibration.Panel,'Padding', 3, 'Spacing', 3);
            vbox1t4 = uiextras.VBox('Parent',hbox1t4,'Padding', 3, 'Spacing', 3);
            vbox2t4 = uiextras.VBox('Parent',hbox1t4,'Padding', 3, 'Spacing', 3);
            hbox3t4 = uiextras.HButtonBox('Parent',vbox1t4,'Padding', 3, 'Spacing', 3);  
                        
            % Add button for calibration
            uicontrol('Parent',hbox3t4,'String','Import Table Data','Callback', @this.onImportTable, 'Tag','Model Calibration', 'TooltipString', sprintf('Import a .csv file of table data to the table below. \n Only rows with a model label and bore ID matching a row within the table will be imported.') );
            uicontrol('Parent',hbox3t4,'String','Export Table Data','Callback', @this.onExportTable, 'Tag','Model Calibration', 'TooltipString', sprintf('Export a .csv file of the table below.') );            
            %uicontrol('Parent',hbox3t4,'String','HPC Export','Callback', @this.onExport4HPC, 'TooltipString', sprintf('Export selected models for calibration on a High Performance Cluster.') );
            %uicontrol('Parent',hbox3t4,'String','HPC Import','Callback', @this.onImportFromHPC, 'TooltipString', sprintf('Import calibrated models from a High Performance Cluster.') );
            uicontrol('Parent',hbox3t4,'String','Calibrate Selected Models','Callback', @this.onCalibModels, 'TooltipString', sprintf('Use the tick-box below to select the models to calibrate then click here. \n During and after calibration, the status is given in the 9th column.') );            
            uicontrol('Parent',hbox3t4,'String','Export Results','Callback', @this.onExportResults, 'Tag','Model Calibration', 'TooltipString', sprintf('Export a .csv file of the calibration results from all models.') );            
            hbox3t4.ButtonSize(1) = 225;
            
            % Add table
            cnames1t4 = {   '<html><center>Select<br />Model</center></html>', ...   
                            '<html><center>Model<br />Label</center></html>', ...   
                            '<html><center>Bore<br />ID</center></html>', ...   
                            '<html><center>Head<br />Start Date</center></html>', ...
                            '<html><center>Head<br />End Date</center></html>', ...
                            '<html><center>Calib.<br />Start Date</center></html>', ...
                            '<html><center>Calib.<br />End Date</center></html>', ...
                            '<html><center>Calib.<br />Method</center></html>', ...
                            '<html><center>Method<br />Setting</center></html>', ...
                            '<html><center>Calib.<br />Status</center></html>', ...
                            '<html><center>Calib.<br />Period CoE</center></html>', ...
                            '<html><center>Eval. Period<br />Unbiased CoE</center></html>', ...
                            '<html><center>Calib.<br />Period AIC</center></html>', ...
                            '<html><center>Eval.<br />Period AIC</center></html>'};
            data = cell(0,14);            
            rnames1t4 = {[1]};
            cedit1t4 = logical([1 0 0 0 0 1 1 1 1 0 0 0 0 0]);            
            cformats1t4 = {'logical', 'char', 'char','char','char','char','char', {'SP-UCI' 'CMA-ES'},'numeric','char','numeric','numeric','numeric','numeric'};
            toolTipStr = ['<html>Use this table to calibrate the models that have been successfully built. <br>' ...
                  'To calibrate a model, first input the start and end dates for the calibration and then select <br>' ...
                  'a calibration method and a setting for the method. The available methods are: (i) Shuffled Complex <br>' ...
                  'Evolution with Principle Components Analysis and Gaussian Resampling (SP-UCI) and (ii)  Covariance <br>' ...
                  'Matrix Adaptation Evolution Strategy (CMA-ES). The default is  SP-UCI. For each method a setting can <br>' ...
                  'be input to increase the rebustness of the calibration. For SP-UCI the setting is the number of complexes <br>' ...
                  'per model parameters and must be >=1. For CMA-ES the setting is the number of times the approach is re-ran, <br>' ...
                  'each time with double the population size and a different mean multi-variate distribution for the sampling. <br>' ...
                  'Once all inputs are defined, use the button above to calibrate the models, after which the selected <br>' ... 
                  'models can be used in simulations.<br>', ...
                  '<br>' ...
                  'Below are tips for calibrating models:<br>', ... 
                  '<ul type="bullet type">', ...
                  '<li>The model calibration results are summarised in the right four columns. <br>', ...
                  '      <li><b>CoE</b> is the coefficient of efficiency where 1 is a perfect fit, <0 worse than using the mean.<br>' ...
                  '      <li><b>AIC</b> is the Akaike information criterion & is used to compare models of differing number of parameters. Lower is better.<br>' ,...                  
                  '<li>Sort the rows by clicking on the column headings. Below are more complex sorting options:<ul>', ...
                  '      <li><b>Click</b> to sort in ascending order.<br>', ...
                  '      <li><b>Shift-click</b> to sort in descending order.<br>', ...    
                  '      <li><b>Ctrl-click</b> to sort secondary in ascending order.<b>Shift-Ctrl-click</b> for descending order.<br>', ...    
                  '      <li><b>Click again</b> again to change sort direction.<br>', ...
                  '      <li><b>Click a third time </b> to return to the unsorted view.', ...
                  ' </ul></ul>'];
              
            this.tab_ModelCalibration.Table = uitable('Parent',vbox1t4,'ColumnName',cnames1t4, ... 
                'ColumnFormat', cformats1t4, 'ColumnEditable', cedit1t4, ...
                'RowName', rnames1t4, 'Tag','Model Calibration', ...
                'CellSelectionCallback', @this.modelCalibration_tableSelection,...
                'CellEditCallback', @this.modelCalibration_tableEdit,...
                'Data', data, ...
                'TooltipString', toolTipStr);

            % Find java sorting object in table
            try
                this.figure_Layout.Selection = 4;
                drawnow();
                jscrollpane = findjobj(this.tab_ModelCalibration.Table);
                jtable = jscrollpane.getViewport.getView;

                % Turn the JIDE sorting on
                jtable.setSortable(true);
                jtable.setAutoResort(true);
                jtable.setMultiColumnSortable(true);
                jtable.setPreserveSelectionsAfterSorting(true);            
            catch
                warndlg('Creating of the GUI row-sorting module failed for the model calibration table.');
            end                
            
            % Add drop-down for the results box
            uicontrol('Parent',vbox2t4,'Style','text','String','Select calibration results to display:' );
            this.tab_ModelCalibration.resultsOptions.popup = uicontrol('Parent',vbox2t4,'Style','popupmenu', ...
                'String',{'Data & residuals', 'Parameter values','Derived Variables', 'Simulation time series plot','Residuals time series plot','Histogram of calib. residuals','Histogram of eval. residuals','Scatter plot of obs. vs model','Scatter plot of residuals vs obs','Variogram of residuals','(none)'}, ...
                'Value',3,'Callback', @this.modelCalibration_onResultsSelection);         
            this.tab_ModelCalibration.resultsOptions.box = vbox2t4;
            this.tab_ModelCalibration.resultsOptions.plots.panel = uiextras.BoxPanel('Parent', vbox2t4 );            
            
            this.tab_ModelCalibration.resultsOptions.dataTable.box = uiextras.Grid('Parent', vbox2t4,'Padding', 3, 'Spacing', 3);
            this.tab_ModelCalibration.resultsOptions.dataTable.table = uitable('Parent',this.tab_ModelCalibration.resultsOptions.dataTable.box, ...
                'ColumnName',{'Year','Month', 'Day','Hour','Minute', 'Obs. Head','Is Calib. Point?','Calib. Head','Eval. Head','Model Err.','Noise Lower','Noise Upper'}, ... 
                'ColumnFormat', {'numeric','numeric','numeric','numeric', 'numeric','numeric','logical','numeric','numeric','numeric','numeric','numeric'}, ...
                'ColumnEditable', true(1,12), ...
                'Tag','Model Calibration - results table', ...
                'TooltipString', 'Results data from the model calibration and evaluation.');
            
            this.tab_ModelCalibration.resultsOptions.paramTable.box = uiextras.Grid('Parent', vbox2t4,'Padding', 3, 'Spacing', 3);
            this.tab_ModelCalibration.resultsOptions.paramTable.table = uitable('Parent',this.tab_ModelCalibration.resultsOptions.paramTable.box, ...
                'ColumnName',{'Component Name','Parameter Name','Value'}, ... 
                'ColumnFormat', {'char','char','numeric'}, ...
                'ColumnEditable', true(1,3), ...
                'Tag','Model Calibration - parameter table', ...
                'TooltipString', 'Model parameter estimates from the calibration.');            
            
            this.tab_ModelCalibration.resultsOptions.derivedVariableTable.box = uiextras.Grid('Parent', vbox2t4,'Padding', 3, 'Spacing', 3);
            this.tab_ModelCalibration.resultsOptions.derivedVariableTable.table = uitable('Parent',this.tab_ModelCalibration.resultsOptions.derivedVariableTable.box, ...
                'ColumnName',{'Component Name','Variable Name','Derived Value'}, ... 
                'ColumnFormat', {'char','char','numeric'}, ...
                'ColumnEditable', true(1,3), ...
                'Tag','Model Calibration - parameter table', ...
                'TooltipString', 'Derived variables from the calibrated model parameter.');                  

            % Set box sizes
            set(hbox1t4, 'Sizes', [-2 -1]);
            set(vbox1t4, 'Sizes', [30 -1]);
            set(vbox2t4, 'Sizes', [30 20 0 0 0 0]);
                        
%           Add context menu
            this.Figure.UIContextMenu = uicontextmenu(this.Figure,'Visible','on');
            uimenu(this.Figure.UIContextMenu,'Label','Copy selected row','Callback',@this.rowAddDelete);
            uimenu(this.Figure.UIContextMenu,'Label','Paste rows','Callback',@this.rowAddDelete,'Separator','on');
            uimenu(this.Figure.UIContextMenu,'Label','Select all','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Select none','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Invert selection','Callback',@this.rowSelection);
            
            % Attach menu to the construction table
            set(this.tab_ModelCalibration.Table,'UIContextMenu',this.Figure.UIContextMenu);
                        
            % Add table name to .UserData
            set(this.tab_ModelCalibration.Table.UIContextMenu,'UserData','this.tab_ModelCalibration.Table');

            

%%          Layout Tab5 - Model Simulation
            %------------------------------------------------------------------            
            hbox1t5 = uiextras.HBoxFlex('Parent', this.tab_ModelSimulation.Panel,'Padding', 3, 'Spacing', 3);
            vbox1t5 = uiextras.VBox('Parent',hbox1t5,'Padding', 3, 'Spacing', 3);
            vbox2t5 = uiextras.VBox('Parent',hbox1t5,'Padding', 3, 'Spacing', 3);
            hbox3t5 = uiextras.HButtonBox('Parent',vbox1t5,'Padding', 3, 'Spacing', 3);  
                        
            % Add button for calibration
            % Add buttons to top left panel               
            uicontrol('Parent',hbox3t5,'String','Append Table Data','Callback', @this.onImportTable, 'Tag','Model Simulation', 'TooltipString', sprintf('Append a .csv file of table data to the table below. \n Only rows where the model label is for a model that have been calibrated will be imported.') );
            uicontrol('Parent',hbox3t5,'String','Export Table Data','Callback', @this.onExportTable, 'Tag','Model Simulation', 'TooltipString', sprintf('Export a .csv file of the table below.') );                        
            uicontrol('Parent',hbox3t5,'String','Simulate Selected Models','Callback', @this.onSimModels, 'TooltipString', sprintf('Use the tick-box below to select the models to simulate then click here. \n During and after simulation, the status is given in the 9th column.') );            
            uicontrol('Parent',hbox3t5,'String','Export Results','Callback', @this.onExportResults, 'Tag','Model Simulation', 'TooltipString', sprintf('Export a .csv file of the simulation results from all models.') );            
            hbox3t5.ButtonSize(1) = 225;
            
            % Add table
            cnames1t5 = {   '<html><center>Select<br />Model</center></html>', ...   
                            '<html><center>Model<br />Label</center></html>', ...                               
                            '<html><center>Bore<br />ID</center></html>', ...   
                            '<html><center>Head<br />Start Date</center></html>', ...
                            '<html><center>Head<br />End Date</center></html>', ...
                            '<html><center>Simulation<br />Label</center></html>', ...   
                            '<html><center>Forcing Data<br />File</center></html>', ...
                            '<html><center>Simulation<br />Start Date</center></html>', ...
                            '<html><center>Simulation<br />End Date</center></html>', ...
                            '<html><center>Simulation<br />Time step</center></html>', ...                            
                            '<html><center>Krig<br />Sim. Residuals?</center></html>', ... 
                            '<html><center>Simulation<br />Status</center></html>'};
            data = cell(1,12);            
            rnames1t5 = {[1]};
            cedit1t5 = logical([1 1 0 0 0 1 1 1 1 1 1 0]);            
            cformats1t5 = {'logical', {'(none calibrated)'}', 'char','char','char','char','char','char', 'char',{'Daily' 'Weekly' 'Monthly' 'Yearly'}, 'logical','char' };
            toolTipStr = ['<html>Use this table to undertake simulation using the models that have been calibrated. <br>' ...
                  'Below are tips for undertaking simulations:<br>', ... 
                  '<ul type="bullet type">', ...
                  '<li>Select a calibrated model for simulation using the drop-down menu in the column "Model Label". <br>', ...
                  '<li>Scenarios investigations, such as a change of rainfall or pumping, can be explore by inputting a new forcing data file (OPTIONAL). <br>', ...
                  '<li>Simulation time points can be input using the simulation start, end date and time-step columns (OPTIONAL). <br>', ...
                  '<li>Simulation can be undertaken using new forcing data by inputing a file name to new forcing data (OPTIONAL). <br>', ...
                  '<li>Kriging of the simulation residuals can be undertaken (if original forcing is used) to ensure simulations honour the observations (OPTIONAL). <br>', ...
                  '<li>Sort the rows by clicking on the column headings. Below are more complex sorting options:<ul>', ...
                  '      <li><b>Click</b> to sort in ascending order.<br>', ...
                  '      <li><b>Shift-click</b> to sort in descending order.<br>', ...    
                  '      <li><b>Ctrl-click</b> to sort secondary in ascending order.<b>Shift-Ctrl-click</b> for descending order.<br>', ...    
                  '      <li><b>Click again</b> again to change sort direction.<br>', ...
                  '      <li><b>Click a third time </b> to return to the unsorted view.', ...
                  ' </ul></ul>'];
              
            this.tab_ModelSimulation.Table = uitable('Parent',vbox1t5,'ColumnName',cnames1t5, ... 
                'ColumnFormat', cformats1t5, 'ColumnEditable', cedit1t5, ...
                'RowName', rnames1t5, 'Tag','Model Simulation', ...
                'Data', data, ...
                'CellSelectionCallback', @this.modelSimulation_tableSelection,...
                'CellEditCallback', @this.modelSimulation_tableEdit,...
                'TooltipString', toolTipStr);


            % Find java sorting object in table
            try
                this.figure_Layout.Selection = 5;
                drawnow();
                jscrollpane = findjobj(this.tab_ModelSimulation.Table);
                jtable = jscrollpane.getViewport.getView;

                % Turn the JIDE sorting on
                jtable.setSortable(true);
                jtable.setAutoResort(true);
                jtable.setMultiColumnSortable(true);
                jtable.setPreserveSelectionsAfterSorting(true);            
            catch
                warndlg('Creating of the GUI row-sorting module failed for the model simulation table.');
            end                         
                        
            % Add drop-down for the results box
            uicontrol('Parent',vbox2t5,'Style','text','String','Select simulation results to display:' );
            this.tab_ModelSimulation.resultsOptions.popup = uicontrol('Parent',vbox2t5,'Style','popupmenu', ...
                'String',{'Simulation data', 'Simulation & decomposition plots','(none)'}, ...
                'Value',3,'Callback', @this.modelSimulation_onResultsSelection);         
            
            this.tab_ModelSimulation.resultsOptions.dataTable.box = uiextras.Grid('Parent', vbox2t5,'Padding', 3, 'Spacing', 3);
            this.tab_ModelSimulation.resultsOptions.dataTable.table = uitable('Parent',this.tab_ModelSimulation.resultsOptions.dataTable.box, ...
                'ColumnName',{'Year','Month', 'Day','Hour','Minute', 'Sim. Head','Noise Lower','Noise Upper'}, ... 
                'ColumnFormat', {'numeric','numeric','numeric','numeric', 'numeric','numeric','numeric','numeric'}, ...
                'ColumnEditable', true(1,8), ...
                'Tag','Model Simulation - results table', ...
                'TooltipString', 'Results data from the model simulation.');  
            
            this.tab_ModelSimulation.resultsOptions.box = vbox2t5;
            this.tab_ModelSimulation.resultsOptions.plots.panel = uiextras.BoxPanel('Parent', vbox2t5);                                              
            
            % Set box sizes
            set(hbox1t5, 'Sizes', [-2 -1]);
            set(vbox1t5, 'Sizes', [30 -1]);
            set(vbox2t5, 'Sizes', [30 20 0 0]);
                        
%           Add context menu
            this.Figure.UIContextMenu = uicontextmenu(this.Figure,'Visible','on');
            uimenu(this.Figure.UIContextMenu,'Label','Copy selected row','Callback',@this.rowAddDelete);
            uimenu(this.Figure.UIContextMenu,'Label','Paste rows','Callback',@this.rowAddDelete,'Separator','on');
            uimenu(this.Figure.UIContextMenu,'Label','Insert row above selection','Callback',@this.rowAddDelete);
            uimenu(this.Figure.UIContextMenu,'Label','Insert row below selection','Callback',@this.rowAddDelete);            
            uimenu(this.Figure.UIContextMenu,'Label','Delete selected rows','Callback',@this.rowAddDelete,'Separator','on');
            uimenu(this.Figure.UIContextMenu,'Label','Select all','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Select none','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Invert selection','Callback',@this.rowSelection);
            
            % Attach menu to the construction table
            set(this.tab_ModelSimulation.Table,'UIContextMenu',this.Figure.UIContextMenu);
                        
            % Add table name to .UserData
            set(this.tab_ModelSimulation.Table.UIContextMenu,'UserData','this.tab_ModelSimulation.Table');
                        
%%          Close the splash window and show the app
            %----------------------------------------------------
            if ~isdeployed
               close(this.FigureSplash);
            end                        
            this.figure_Layout.Selection = 1;
            set(this.Figure,'Visible','on');
        end
        
        % Set project folder
        function onSetProjectFolder(this,hObject,eventdata)

            % Initialise project names
            projectName = '';
            projectExt = '';
            
            % Get project folder
            if isempty(this.project_fileName)
                projectPath = uigetdir('Select project folder.');    
            else
                % Get project folder and file name (if a dir)
                if isdir(this.project_fileName)
                    projectPath = this.project_fileName;
                else
                    [projectPath,projectName,projectExt] = fileparts(this.project_fileName);
                end
                                
                if isempty(projectPath)
                    projectPath = uigetdir('Select project folder.'); 
                else
                    projectPath = uigetdir(projectPath, 'Select project folder.'); 
                end
                
            end

            if projectPath~=0;

                % Get the current project folder. If the project folder has
                % changed then warn the user that all infput file names
                % must be within the new project folder.
                if ~isempty(this.project_fileName)
                    currentProjectFolder = fileparts(this.project_fileName);
                    
                    if ~strcmp(currentProjectFolder, projectPath)
                        warndlg({'The project folder is different to that already set.';''; ...
                                 'Importantly, all file names in the project are relative'; ...
                                 'to the project folder and so all input .csv files must be'; ...
                                 'within the project folder or a sub-folder within it.'},'Input file name validity.','modal');
                    end
                end
                
                % Update project folder
                this.project_fileName = projectPath;
                                
                % Update GUI title
                set(this.Figure,'Name',['The Groundwater Statistical Toolbox - ', this.project_fileName]);
                drawnow;
            end            
            
        end
            
        % Open saved model
        function onOpen(this,hObject,eventdata)
            
            % Set initial folder to the project folder (if set)
            currentProjectFolder='';
            if ~isempty(this.project_fileName)                                
                try    
                    if isdir(this.project_fileName)
                        currentProjectFolder = this.project_fileName;
                    else
                        currentProjectFolder = fileparts(this.project_fileName);
                    end 
                    
                    currentProjectFolder = [currentProjectFolder,filesep];
                    cd(currentProjectFolder);
                catch
                    % do nothing
                end
            end
            
            % Show folder selection dialog
            [fName,pName] = uigetfile({'*.mat'},'Select project to open.');    

            if fName~=0;
                % Assign the file name 
                this.project_fileName = fullfile(pName,fName);

                % Change cursor
                set(this.Figure, 'pointer', 'watch');                
                drawnow;
                
                % Load file
                try
                    savedData = load(this.project_fileName,'-mat');
                catch ME
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow;
                    warndlg('Project file could not be loaded.','File error');
                    return;
                end
                
                % Assign loaded data to the tables and models.
                try
                    this.tab_Project.project_name.String = savedData.tableData.tab_Project.title;
                    this.tab_Project.project_description.String = savedData.tableData.tab_Project.description;
                catch ME
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow;
                    warndlg('Data could not be assigned to the user interface table: Project Description','File table data error');
                     set(this.Figure, 'pointer', 'watch');
                     drawnow;
                end
                try
                    this.tab_DataPrep.Table.Data = savedData.tableData.tab_DataPrep;
                    
                    % Update row numbers
                    nrows = size(this.tab_DataPrep.Table.Data,1);
                    this.tab_DataPrep.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                    
                catch ME
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow;
                    warndlg('Data could not be assigned to the user interface table: Data Preparation','File table data error');
                     set(this.Figure, 'pointer', 'watch');
                     drawnow;
                end               
                try

                    this.tab_ModelConstruction.Table.Data = savedData.tableData.tab_ModelConstruction;
                    
                    % Update row numbers
                    nrows = size(this.tab_ModelConstruction.Table.Data,1);
                    this.tab_ModelConstruction.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));     
                catch ME
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow;
                    warndlg('Data could not be assigned to the user interface table: Model Construction','File table data error');
                     set(this.Figure, 'pointer', 'watch');
                     drawnow;
                end                
                try                    
                    this.tab_ModelCalibration.Table.Data = savedData.tableData.tab_ModelCalibration;

                    % Update row numbers
                    nrows = size(this.tab_ModelCalibration.Table.Data,1);
                    this.tab_ModelCalibration.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                      
                catch ME
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow;
                    warndlg('Data could not be assigned to the user interface table: Model Calibration','File table data error');
                     set(this.Figure, 'pointer', 'watch');
                     drawnow;
                end                
                try
                    this.tab_ModelSimulation.Table.Data = savedData.tableData.tab_ModelSimulation;
                    
                    % Update row numbers
                    nrows = size(this.tab_ModelSimulation.Table.Data,1);
                    this.tab_ModelSimulation.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                       
                catch ME
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow;
                    warndlg('Data could not be assigned to the user interface table: Model Simulation','File table data error');
                    set(this.Figure, 'pointer', 'watch');
                    drawnow;
                end                

                                
                % Assign built models.
                try
                    this.models = savedData.models;
                catch ME
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow;
                    warndlg('Loaded models could not be assigned to the user interface.','File model data error');
                    set(this.Figure, 'pointer', 'watch');
                    drawnow;
                end  
                
                % Assign analysed bores.
                try
                    this.dataPrep = savedData.dataPrep;
                catch ME
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow;
                    warndlg('Loaded data analysis results could not be assigned to the user interface.','File model data error');
                    set(this.Figure, 'pointer', 'watch');
                    drawnow;
                end  
                set(this.Figure, 'pointer', 'arrow');
                drawnow;
                
                % Update GUI title
                set(this.Figure,'Name',['The Groundwater Statistical Toolbox - ', this.project_fileName]);
                drawnow;                
            end
        end
        
        % Save as current model        
        function onSaveAs(this,hObject,eventdata)
            
            % set current folder to the project folder (if set)
            currentProjectFolder='';
            if ~isempty(this.project_fileName)                                
                try    
                    if isdir(this.project_fileName)
                        currentProjectFolder = this.project_fileName;
                    else
                        currentProjectFolder = fileparts(this.project_fileName);
                    end 
                    
                    currentProjectFolder = [currentProjectFolder,filesep];
                    cd(currentProjectFolder);
                catch
                    % do nothing
                end
            end
            
            [fName,pName] = uiputfile({'*.mat'},'Save models as ...');    
            if fName~=0;
                
                % Get the current project folder. If the project folder has
                % changed then warn the user that all infput file names
                % must be within the new project folder.
                if ~isempty(currentProjectFolder)                    
                    if ~strcmp(currentProjectFolder, pName)
                        warndlg({'The project folder is different to that already set.';''; ...
                                 'Importantly, all file names in the project are relative'; ...
                                 'to the project folder and so all input .csv files must be'; ...
                                 'within the project folder or a sub-folder within it.'},'Input file name validity.','modal');
                    end
                end

                % Change cursor
                set(this.Figure, 'pointer', 'watch');    
                drawnow;
                
                % Assign file name to date cell array
                this.project_fileName = fullfile(pName,fName);
                
                % Collate the tables of data to a temp variable.
                tableData.tab_Project.title = this.tab_Project.project_name.String;
                tableData.tab_Project.description = this.tab_Project.project_description.String;
                tableData.tab_DataPrep = this.tab_DataPrep.Table.Data;
                tableData.tab_ModelConstruction = this.tab_ModelConstruction.Table.Data;
                tableData.tab_ModelCalibration = this.tab_ModelCalibration.Table.Data;
                tableData.tab_ModelSimulation = this.tab_ModelSimulation.Table.Data;
                                
                % Get the data preparation results
                dataPrep = this.dataPrep;
                
                % Get built models.
                models = this.models;
                
                % Save the GUI tables to the file.
                try
                    save(this.project_fileName, 'tableData',  'models', 'dataPrep', '-v7.3');  

                    % Update GUI title
                    set(this.Figure,'Name',['The Groundwater Statistical Toolbox - ', this.project_fileName]);                                        
                catch ME
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow;
                    warndlg('The project could not be saved. Please check you have write access to the directory.','Project not saved ...');
                    return;
                end                      
            end
            
            % Change cursor
            set(this.Figure, 'pointer', 'arrow');
            drawnow;
            
        end
        
        % Save model        
        function onSave(this,hObject,eventdata)
        
            if isempty(this.project_fileName) || exist(this.project_fileName,'file') ~= 2;
                onSaveAs(this,hObject,eventdata);
            else               
                % Change cursor
                set(this.Figure, 'pointer', 'watch');   
                drawnow;
                
                % Collate the tables of data to a temp variable.
                tableData.tab_Project.title = this.tab_Project.project_name.String;
                tableData.tab_Project.description = this.tab_Project.project_description.String;
                tableData.tab_DataPrep = this.tab_DataPrep.Table.Data;
                tableData.tab_ModelConstruction = this.tab_ModelConstruction.Table.Data;
                tableData.tab_ModelCalibration = this.tab_ModelCalibration.Table.Data;
                tableData.tab_ModelSimulation = this.tab_ModelSimulation.Table.Data;
                                
                % Get the data preparation results
                dataPrep = this.dataPrep;
                
                % Get built models.
                models = this.models;
                
                % Save the GUI tables to the file.
                try
                    save(this.project_fileName, 'tableData',  'models', 'dataPrep', '-v7.3');         
                    % Change cursor
                    set(this.Figure, 'pointer', 'arrow');   
                    drawnow;
                catch ME
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow;
                    warndlg('The project could not be saved. Please check you have write access to the directory.','Project not saved ...');
                    return;
                end                  
            end            
            
        end    
        
        % This function runs when the app is closed        
        function onExit(this,hObject,eventdata)        
            delete(this.Figure);
        end

        function dataPrep_tableSelection(this, hObject, eventdata)
            icol=eventdata.Indices(:,2);
            irow=eventdata.Indices(:,1);            
            data=get(hObject,'Data'); % get the data cell array of the table
            
            % Undertake column specific operations.
            if ~isempty(icol) && ~isempty(irow)
                
                % Record the current row and column numbers
                this.tab_DataPrep.currentRow = irow;
                this.tab_DataPrep.currentCol = icol;
            
                % Remove HTML tags from the column name
                columnName = GST_GUI.removeHTMLTags(eventdata.Source.ColumnName{icol});
                
                switch columnName;
                    case 'Obs. Head File'
                        this.tab_DataPrep.modelOptions.vbox.Heights = [0; 0];

                        % Get file name and remove project folder from
                        % preceeding full path.
                        fName = getFileName(this, 'Select the Observed Head file.');                                                
                        if fName~=0;
                            % Assign file name to date cell array
                            data{eventdata.Indices(1),eventdata.Indices(2)} = fName;
                            
                            % Input file name to the table
                            set(hObject,'Data',data);
                        end                        
                        
                    case 'Bore ID'
                         % Check the obs. head file is listed
                         fname = data{eventdata.Indices(1),2};
                         if isempty(fname)
                            warndlg('The observed head file name must be input before selecting the bore ID');
                            return;
                         end
                         
                         % Construct full file path name
                         if isdir(this.project_fileName)                             
                            fname = fullfile(this.project_fileName,fname); 
                         else
                            fname = fullfile(fileparts(this.project_fileName),fname);  
                         end                         
                         
                         % Check the bore ID file exists.
                         if exist(fname,'file') ~= 2;
                            warndlg('The observed head file does not exist.');
                            return;
                         end
                         
                         % Read in the observed head file.
                         try                            
                            tbl = readtable(fname);
                         catch
                            warndlg('The observed head file could not be read in. It must a .csv file of 6 columns');
                            return;
                         end
                        
                         % Check there are the correct number of columns
                         if length(tbl.Properties.VariableNames) ~= 6
                            warndlg('The observed head file must contain 6 columns in the following order: boreID, year, month, day, hour, head');
                            return;
                         end
                             
                         % Check columns 2 to 6 are numeric.
                         if any(any(~isnumeric(tbl{:,2:6})))
                            warndlg('Columns 2 to 6 within the observed head file must contain only numeric data.');
                            return;
                         end
                            
                         % Find the unique bore IDs   
                         boreIDs = unique(tbl{:,1});
                         
                         % Free up memory
                         clear tbl;
                         
                         % Input the unique bore IDs to the list box.
                         set(this.tab_DataPrep.modelOptions.boreIDList,'String',boreIDs);  
                         
                         % Show the list box.
                         this.tab_DataPrep.modelOptions.vbox.Heights = [-1; 0];                        
                    otherwise
                        % Show the results if the bore has been analysed.
                        
                        boreID = data{eventdata.Indices(1),3};
                        modelStatus = GST_GUI.removeHTMLTags(data{eventdata.Indices(1),15});
                        
                        if ~isempty(this.dataPrep) && ~isempty(boreID) && ...
                        isfield(this.dataPrep,boreID) && ~isempty(this.dataPrep.(boreID)) && ...
                        strcmp(modelStatus,'Bore analysed.')
                            this.tab_DataPrep.modelOptions.vbox.Heights = [0; -1];                    
                            set(this.tab_DataPrep.modelOptions.resultsOptions.box, 'Sizes',[-1 -1]);
                            
                            % Get the analysis results.
                            headData = this.dataPrep.(boreID);
                            
                            % Add head data to the uitable                            
                            nrows = size(headData,1);
                            ncols = size(headData,2);
                            this.tab_DataPrep.modelOptions.resultsOptions.table.Data = table2cell(headData);

                            % Convert to a matrix
                            headData = table2array(headData);                            
                            
                            % Create a time vector form head data.
                            dateVec = datenum(headData(:,1),headData(:,2),headData(:,3),headData(:,4),headData(:,5),zeros(size(headData,1),1));
                            
                            % Plot the hydrograph and the errors and outliers
                            isError = any(headData(:,7:end)==1,2);
                            h= plot(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(~isError), headData(~isError,6),'b.-');
                            legendstring{1} = 'Obs. head';
                            hold(this.tab_DataPrep.modelOptions.resultsOptions.plots,'on');
                            
                            % Date errors
                            col = 7;
                            isError = headData(:,col)==1;
                            if any(isError)
                                scatter(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(isError), headData(isError,6),'o');
                                legendstring = {legendstring{:} 'Date error'};
                            end
                            
                            col = 8;
                            isError = headData(:,col)==1;
                            if any(isError)
                                scatter(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(isError), headData(isError,6),'o');
                                legendstring = {legendstring{:} 'Duplicate error'};
                            end

                            col = 9;
                            isError = headData(:,col)==1;
                            if any(isError)
                                scatter(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(isError), headData(isError,6),'o');
                                legendstring = {legendstring{:} 'Min head error'};
                            end   
                            
                            col = 10;
                            isError = headData(:,col)==1;
                            if any(isError)
                                scatter(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(isError), headData(isError,6),'o');
                                legendstring = {legendstring{:} 'Max head error'};
                            end  
                            
                            col = 11;
                            isError = headData(:,col)==1;
                            if any(isError)
                                scatter(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(isError), headData(isError,6),'o');
                                legendstring = {legendstring{:} '|dh/dt| error'};
                            end                              
                            
                            col = 12;
                            isError = headData(:,col)==1;
                            if any(isError)
                                scatter(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(isError), headData(isError,6),'o');
                                legendstring = {legendstring{:} 'dh/dt=0 error'};
                            end                              
                            
                            col = 13;
                            isError = headData(:,col)==1;
                            if any(isError)
                                scatter(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(isError), headData(isError,6),'o');
                                legendstring = {legendstring{:} 'Outlier obs.'};
                            end  
                            
                            % Format plot
                            datetick(this.tab_DataPrep.modelOptions.resultsOptions.plots,'x','YY');
                            xlabel(this.tab_DataPrep.modelOptions.resultsOptions.plots,'Year');
                            ylabel(this.tab_DataPrep.modelOptions.resultsOptions.plots,'Head');
                            hold(this.tab_DataPrep.modelOptions.resultsOptions.plots,'off');
                            box(this.tab_DataPrep.modelOptions.resultsOptions.plots,'on');
                            axis(this.tab_DataPrep.modelOptions.resultsOptions.plots,'tight');
                            legend(this.tab_DataPrep.modelOptions.resultsOptions.plots, legendstring,'Location','eastoutside');
                            
                            % SHow results
                            this.tab_DataPrep.modelOptions.resultsOptions.box.Heights = [-1 -1];
                        else
                            this.tab_DataPrep.modelOptions.vbox.Heights = [0; 0];
                        end
                end
            end
        end
        
        % Data preparation results table edit.
        function dataPrep_resultsTableEdit(this, hObject, eventdata)

            % Check the row was found.
            if ~isfield(this.tab_DataPrep,'currentRow') || isempty(this.tab_DataPrep.currentRow)
                warndlg('An unexpected system error has occured. Please try re-selecting a grid cell from the main to replot the results.','System error ...');
                returnd;
            end            
            
            % Get the current row from the main data preparation table.
            irow = this.tab_DataPrep.currentRow;
            boreID = this.tab_DataPrep.Table.Data{irow, 3};
                
            % Check the row was found.
            if isempty(boreID)
                warndlg('An unexpected system error has occured. Please try re-selecting a grid cell from the main to replot the results.','System error ...');
                returnd;
            end

            % Get the new table of data.
            headData=get(hObject,'Data');            
            
            % Check the number of rows in the data strcuture equal that of
            % the results table.
            if size(this.dataPrep.(boreID),1) ~= size(headData,1)
                warndlg('An unexpected system error has occured. Please try re-selecting a grid cell from the main to replot the results.','System error ...');
                return;
            end
                        
            % Update the data analysis data structure.
            this.dataPrep.(boreID)(:,:) = headData;
            
            %Convert to matrix.
            headData = table2array(this.dataPrep.(boreID)(:,:));
            
            % Update table statistics
            numErroneouObs = sum(any(headData(:,7:12),2));
            numOutlierObs = sum(headData(:,13));                    
            this.tab_DataPrep.Table.Data{irow,16} = ['<html><font color = "#808080">',num2str(numErroneouObs),'</font></html>'];
            this.tab_DataPrep.Table.Data{irow,17} = ['<html><font color = "#808080">',num2str(numOutlierObs),'</font></html>'];            
            
            % Redraw the plot.
            %--------------------------------------------------------------

            
            % Create a time vector form head data.
            dateVec = datenum(headData(:,1),headData(:,2),headData(:,3),headData(:,4),headData(:,5),zeros(size(headData,1),1));

            % Plot the hydrograph and the errors and outliers
            isError = any(headData(:,7:end)==1,2);
            h= plot(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(~isError), headData(~isError,6),'b.-');
            legendstring{1} = 'Obs. head';
            hold(this.tab_DataPrep.modelOptions.resultsOptions.plots,'on');

            % Date errors
            col = 7;
            isError = headData(:,col)==1;
            if any(isError)
                scatter(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(isError), headData(isError,6),'o');
                legendstring = {legendstring{:} 'Date error'};
            end

            col = 8;
            isError = headData(:,col)==1;
            if any(isError)
                scatter(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(isError), headData(isError,6),'o');
                legendstring = {legendstring{:} 'Duplicate error'};
            end

            col = 9;
            isError = headData(:,col)==1;
            if any(isError)
                scatter(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(isError), headData(isError,6),'o');
                legendstring = {legendstring{:} 'Min head error'};
            end   

            col = 10;
            isError = headData(:,col)==1;
            if any(isError)
                scatter(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(isError), headData(isError,6),'o');
                legendstring = {legendstring{:} 'Max head error'};
            end  

            col = 11;
            isError = headData(:,col)==1;
            if any(isError)
                scatter(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(isError), headData(isError,6),'o');
                legendstring = {legendstring{:} '|dh/dt| error'};
            end                              

            col = 12;
            isError = headData(:,col)==1;
            if any(isError)
                scatter(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(isError), headData(isError,6),'o');
                legendstring = {legendstring{:} 'dh/dt=0 error'};
            end                              

            col = 13;
            isError = headData(:,col)==1;
            if any(isError)
                scatter(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(isError), headData(isError,6),'o');
                legendstring = {legendstring{:} 'Outlier obs.'};
            end  

            % Format plot
            datetick(this.tab_DataPrep.modelOptions.resultsOptions.plots,'x','YY');
            xlabel(this.tab_DataPrep.modelOptions.resultsOptions.plots,'Year');
            ylabel(this.tab_DataPrep.modelOptions.resultsOptions.plots,'Head');
            hold(this.tab_DataPrep.modelOptions.resultsOptions.plots,'off');
            box(this.tab_DataPrep.modelOptions.resultsOptions.plots,'on');
            axis(this.tab_DataPrep.modelOptions.resultsOptions.plots,'tight');
            legend(this.tab_DataPrep.modelOptions.resultsOptions.plots, legendstring,'Location','eastoutside');            
            
            
            
        end
        
        function dataPrep_optionsSelection(this, hObject, eventdata)
            try                         
                switch this.tab_DataPrep.currentCol
                    case 3 % Bore ID column
                        
                         % Get selected bores
                         listSelection = get(hObject,'Value');

                         % Get data from model construction table
                         data=get(this.tab_DataPrep.Table,'Data'); 

                         % Get the selected bore row index.
                         index_selected = this.tab_DataPrep.currentRow;

                         % Check if the nwe bore ID is unique.
                         newBoreID = hObject.String(listSelection,1);
                         if any(strcmp( data(:,3) , newBoreID) & index_selected~=[1:size(data,1)]')
                             warndlg('The bore ID must be unique.','Bore ID error...');
                             return;
                         end
                         
                         % Add selected bore ID is cell array at the currently
                         % selected bore.
                         data(index_selected,3) =  hObject.String(listSelection,1);

                         % Set bore ID 
                         set(this.tab_DataPrep.Table,'Data', data); 
                end
            catch ME
                return;
            end        
        end        
        
        %Cell selection response for tab 1 - model construction
        function modelConstruction_tableSelection(this, hObject, eventdata)
            icol=eventdata.Indices(:,2);
            irow=eventdata.Indices(:,1);            
            data=get(hObject,'Data'); % get the data cell array of the table
            
            % Undertake column specific operations.
            if ~isempty(icol) && ~isempty(irow)
                
                % Record the current row and column numbers
                this.tab_ModelConstruction.currentRow = irow;
                this.tab_ModelConstruction.currentCol = icol;
            
                % Remove HTML tags from the column name
                columnName = GST_GUI.removeHTMLTags(eventdata.Source.ColumnName{icol});
                
                switch columnName;
                    case 'Obs. Head File'
                        % Get file name and remove project folder from
                        % preceeding full path.
                        fName = getFileName(this, 'Select the Observed Head file.');                        
                        if fName~=0;
                            % Assign file name to date cell array
                            data{eventdata.Indices(1),eventdata.Indices(2)} = fName;
                            
                            % Input file name to the table
                            set(hObject,'Data',data);
                        end
                        
                         % Hide the panels.
                         this.tab_ModelConstruction.modelOptions.vbox.Heights = [0; 0 ; 0; 0];                        
                        
                    case 'Forcing Data File'

                        % Get file name and remove project folder from
                        % preceeding full path.
                        fName = getFileName(this, 'Select the Forcing Data file.');                                                
                        if fName~=0;
                            % Assign file name to date cell array
                            data{eventdata.Indices(1),eventdata.Indices(2)} = fName;
                            
                            % Input file name to the table
                            set(hObject,'Data',data);
                        end
                        % Hide the panels.
                        this.tab_ModelConstruction.modelOptions.vbox.Heights = [0; 0 ; 0; 0];                        
                        
                    case 'Coordinates File'
                        % Get file name and remove project folder from
                        % preceeding full path.
                        fName = getFileName(this, 'Select the Coordinates file.');                                                
                        if fName~=0;
                            % Assign file name to date cell array
                            data{eventdata.Indices(1),eventdata.Indices(2)} = fName;
                            
                            % Input file name to the table
                            set(hObject,'Data',data);
                        end
                                                
                        % Hide the panels.
                        this.tab_ModelConstruction.modelOptions.vbox.Heights = [0; 0 ; 0; 0];
                        
                    case 'Bore ID'
                         % Check the obs. head file is listed
                         fname = data{eventdata.Indices(1),3};
                         if isempty(fname)
                            warndlg('The observed head file name must be input before selecting the bore ID');
                            return;
                         end

                         % Construct full file name.
                         if isdir(this.project_fileName)                             
                            fname = fullfile(this.project_fileName,fname); 
                         else
                            fname = fullfile(fileparts(this.project_fileName),fname);  
                         end
                         
                         % Check the bore ID file exists.
                         if exist(fname,'file') ~= 2;
                            warndlg('The observed head file does not exist.');
                            return;
                         end
                         
                         % Read in the observed head file.
                         try
                            tbl = readtable(fname);
                         catch
                            warndlg('The observed head file could not be read in. It must a .csv file of 6 columns');
                            return;
                         end
                        
                         % Check there are the correct number of columns
                         if length(tbl.Properties.VariableNames) ~= 6
                            warndlg('The observed head file must contain 6 columns in the following order: boreID, year, month, day, hour, head');
                            return;
                         end
                             
                         % Check columns 2 to 6 are numeric.
                         if any(any(~isnumeric(tbl{:,2:6})))
                            warndlg('Columns 2 to 6 within the observed head file must contain only numeric data.');
                            return;
                         end
                            
                         % Find the unique bore IDs   
                         boreIDs = unique(tbl{:,1});
                         
                         % Free up memory
                         clear tbl;
                         
                         % Input the unique bore IDs to the list box.
                         set(this.tab_ModelConstruction.boreIDList,'String',boreIDs);  
                         
                         % Show the list box.
                         this.tab_ModelConstruction.modelOptions.vbox.Heights = [-1; 0 ; 0; 0];
                    case 'Model Type'                        
                         % Get the current model type.
                         modelType = data{irow,7};
                         
                         % Get description for the current model type
                         try                         
                            modelDecription  =eval([modelType,'.description()']);                          
                         catch
                         	modelDecription = 'No decription is available for the selected model.';
                         end
                                                                           
                         % Assign model decription to GUI string box                         
                         this.tab_ModelConstruction.modelDescriptions.String = modelDecription; 
                         
                         % Show the description.
                         this.tab_ModelConstruction.modelOptions.vbox.Heights = [0; -1 ; 0; 0];
                         
                    case 'Model Options'
                        % Check the preceeding inputs have been defined.
                        if  any(cellfun(@(x) isempty(x), data(irow,3:7)))
                            warndlg('The observed head data file, forcing data file, coordinates file, bore ID and model type must be input before the model option can be set.');
                            return;
                        end
                                                
                        % Set the forcing data, bore ID, coordinates and options
                        % for the given model type.
                        try          
                            modelType = eventdata.Source.Data{irow,7};
                            
                            if isempty(this.project_fileName)
                                warningdlg('The project folder must be set before the model options can be viewed or edited.')
                                return
                            end
                            if isdir(this.project_fileName)
                                dirname = this.project_fileName;
                            else
                                dirname = fileparts(this.project_fileName);
                            end                            
                            
                            fname = fullfile(dirname,data{irow,4}); 
                            setForcingData(this.tab_ModelConstruction.modelTypes.(modelType).obj, fname);
                            fname = fullfile(dirname,data{irow,5});
                            setCoordinatesData(this.tab_ModelConstruction.modelTypes.(modelType).obj, fname);
                            fname = fullfile(dirname,data{irow,6});
                            setBoreID(this.tab_ModelConstruction.modelTypes.(modelType).obj, fname);
                            
                            % If the model options are empty, then add a
                            % default empty cell, else set the existing
                            % options into the model type GUI RHS panel.
                            if isempty(eventdata.Source.Data{irow,8}) || strcmp(eventdata.Source.Data{irow,8},'{}')
                                %eventdata.Source.Data{irow,8} = [];
                                data{irow,8} = [];
                            end
                            setModelOptions(this.tab_ModelConstruction.modelTypes.(modelType).obj, data{irow,8})
                                
                        catch ME
                            warndlg('Unknown model type selected or the GUI for the selected model crashed.');
                            this.tab_ModelConstruction.modelOptions.vbox.Heights = [0; 0;  0; 0];
                        end
                        
                         % Show model type options.
                         switch modelType
                             case 'model_TFN'
                                this.tab_ModelConstruction.modelOptions.vbox.Heights = [0; 0;  -1; 0];
                             case 'ExpSmooth'
                                this.tab_ModelConstruction.modelOptions.vbox.Heights = [0; 0;  0; -1];
                             otherwise
                                 this.tab_ModelConstruction.modelOptions.vbox.Heights = [0; 0;  0; 0];
                         end
                         
                    otherwise
                         % Hide the panels.
                         this.tab_ModelConstruction.modelOptions.vbox.Heights = [0; 0 ; 0; 0];
                    end
                end
        end
            
        function modelConstruction_optionsSelection(this, hObject, eventdata)
            try                         
                switch this.tab_ModelConstruction.currentCol
                    case 6
                         % Get selected bores
                         listSelection = get(hObject,'Value');

                         % Get data from model construction table
                         data=get(this.tab_ModelConstruction.Table,'Data'); 

                         % Get the selected bore row index.
                         index_selected = this.tab_ModelConstruction.currentRow;

                         % Add selected bore ID is cell array at the currently
                         % selected bore.
                         data(index_selected,6) =  hObject.String(listSelection,1);

                         % Set bore ID 
                         set(this.tab_ModelConstruction.Table,'Data', data); 
                end
            catch ME
                return;
            end        
        end
        
        function modelConstruction_tableEdit(this, hObject, eventdata)
            icol=eventdata.Indices(:,2);
            irow=eventdata.Indices(:,1);                        
            
            % Undertake column specific operations.
            if ~isempty(icol) && ~isempty(irow)

                % Record the current row and column numbers
                this.tab_ModelConstruction.currentRow = irow;
                this.tab_ModelConstruction.currentCol = icol;
            
                % Remove HTML tags from the column name
                columnName = GST_GUI.removeHTMLTags(eventdata.Source.ColumnName{icol});                
                                
                % Warn the user if the model is already built and the
                % inputs are to change - reuiring the model object to be
                % removed.
                if ~isempty(this.models) && ~strcmp(eventdata.PreviousData, eventdata.NewData) && icol~=1 && ~isempty(eventdata.PreviousData)
                    
                    % Get original model label
                    if strcmp(columnName, 'Model Label')
                        modelLabel=eventdata.PreviousData;
                    else
                        modelLabel = hObject.Data{irow,2};
                    end
                    
                    % Check if the model object exists
                    ind = cellfun( @(x) strcmp(x.model_label,modelLabel), this.models);
                    if any(ind)
                       
                        % Check if the model is calibrated
                        isCalibrated = false;
                        if ~isempty(this.models{ind}.calibrationResults) && this.models{ind}.calibrationResults.isCalibrated
                            isCalibrated = true;
                        end
                        
                        % Create warnign message and display
                        if isCalibrated
                            msg = {['Model ',modelLabel, ' has already been built and calibrated. If you change the model construction all calibration and simulation results will be deleted.'], ...
                                    '', ...                                
                                   'Do you want to continue with the changes to the model construction?'};
                        else
                            msg = {['Model ',modelLabel, ' has already been built (but not calibrated). If you change the model construction you will need to rebuild the model.'], ...
                                    '', ...
                                   'Do you want to continue with the changes to the model construction?'};
                        end                            
                               
                        response = questdlg(msg,'Overwrite exiting model?','Yes','No','No');
                        
                        % Check if 'cancel, else delete the model object
                        if strcmp(response,'No')
                            return
                        else
                            filt = true(length(this.models),1);
                            filt(ind) = false;
                            this.models = this.models(filt);
                        end
                                                                        
                        % Change status of the model object.
                        hObject.Data{irow,end} = '<html><font color = "#FF0000">Model not built.</font></html>';

                        % Delete model from calibration table.
                        modelLabels_calibTable =  this.tab_ModelCalibration.Table.Data(:,2);                            
                        modelLabels_calibTable = GST_GUI.removeHTMLTags(modelLabels_calibTable);
                        ind = cellfun( @(x) strcmp(x,modelLabel), modelLabels_calibTable);
                        this.tab_ModelCalibration.Table.Data = this.tab_ModelCalibration.Table.Data(~ind,:);

                        % Update row numbers
                        nrows = size(this.tab_ModelCalibration.Table.Data,1);
                        this.tab_ModelCalibration.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                                     
                        
                        % Delete models from simulations table.
                        modelLabels_simTable =  this.tab_ModelSimulation.Table.Data(:,2);                            
                        modelLabels_simTable = GST_GUI.removeHTMLTags(modelLabels_simTable);
                        ind = cellfun( @(x) strcmp(x,modelLabel), modelLabels_simTable);
                        this.tab_ModelSimulation.Table.Data = this.tab_ModelSimulation.Table.Data(~ind,:);                        
                        
                        % Update row numbers
                        nrows = size(this.tab_ModelSimulation.Table.Data,1);
                        this.tab_ModelSimulation.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                                     
                    end
                    
                end

                
                switch columnName;
                    
                    case 'Model Label'                    
                        % Check that the model label is unique.
                        allLabels = hObject.Data(:,2);
                        newLabel = eventdata.NewData;
                        hObject.Data{irow,2} = GST_GUI.createUniqueLabel(allLabels, newLabel, irow);                          
                        
                        % Report error if required
                        if ~strcmp(newLabel, hObject.Data{irow,2})
                            warndlg('The model label must be unique! An extension has been added to the label.','Model label error ...');                            
                        end
                        
                    case 'Model Options'
                        modelOptionsArray = getModelOptions(this.tab_ModelConstruction.modelTypes.model_TFN.obj);
                        hObject.Data(irow,icol) = modelOptionsArray;

                    case 'Model Type'                        
                         % Get the current model type.
                         modelType = hObject.Data{irow,7};
                         
                         % Get description for the current model type
                         try                         
                            modelDecription  =eval([modelType,'.description()']);                          
                         catch
                         	modelDecription = 'No decription is available for the selected model.';
                         end
                             
                         
                         % Assign model decription to GUI string box                         
                         this.tab_ModelConstruction.modelDescriptions.String = modelDecription; 
                         
                         % Show the description.
                         this.tab_ModelConstruction.modelOptions.vbox.Heights = [0; -1 ; 0; 0];                        
                    otherwise
                            % Do nothing                                             
                end
            end
        end
        
        function modelCalibration_tableSelection(this, hObject, eventdata)
            icol=eventdata.Indices(:,2);
            irow=eventdata.Indices(:,1);            
            data=get(hObject,'Data'); % get the data cell array of the table
            
            % Undertake column specific operations.
            if ~isempty(icol) && ~isempty(irow)
                
                % Record the current row and column numbers
                this.tab_ModelConstruction.currentRow = irow;
                this.tab_ModelConstruction.currentCol = icol;
            
                % Remove HTML tags from the column name
                columnName  = GST_GUI.removeHTMLTags(eventdata.Source.ColumnName{icol});
                
                switch columnName;
                    case 'Calib. Start Date'
                        % Get start and end dates of the observed head
                        % data, remove HTML tags and then convert to a
                        % date number.
                        startDate = data{irow,4};
                        endDate = data{irow,5};
                        startDate = GST_GUI.removeHTMLTags(startDate);
                        endDate = GST_GUI.removeHTMLTags(endDate);                        
                        startDate = datenum(startDate,'dd-mmm-yyyy');
                        endDate = datenum(endDate,'dd-mmm-yyyy');
                                                                        
                        % Open the calander with the already input date,
                        % else use the start date of the obs. head.
                        if isempty(data{irow,icol})
                            inputDate = startDate;                            
                        else
                            inputDate = datenum( data{irow,icol},'dd-mmm-yyyy');
                        end
                        selectedDate = uical(inputDate, 'English',startDate, endDate);
                        
                        % Get the calibration end date 
                        calibEndDate = datenum( data{irow,icol+1},'dd-mmm-yyyy');                        
                        
                        % Check date is between start and end date of obs
                        % head.
                        if selectedDate < startDate || selectedDate > endDate    
                            warndlg('The calibration start date must be within the range of the observed head data.');
                        elseif calibEndDate<=selectedDate
                            warndlg('The calibration start date must be less than the calibration end date.');
                        else
                            data{eventdata.Indices(1),eventdata.Indices(2)} = datestr(selectedDate,'dd-mmm-yyyy');
                        end
                        set(hObject,'Data',data);
                    case 'Calib. End Date'
                        % Get start and end dates of the observed head
                        % data, remove HTML tags and then convert to a
                        % date number.
                        startDate = data{irow,4};
                        endDate = data{irow,5};
                        startDate = GST_GUI.removeHTMLTags(startDate);
                        endDate = GST_GUI.removeHTMLTags(endDate);
                        startDate = datenum(startDate,'dd-mmm-yyyy');
                        endDate = datenum(endDate,'dd-mmm-yyyy');
                                                                        
                        % Open the calander with the already input date,
                        % else use the start date of the obs. head.
                        if isempty(data{irow,icol})
                            inputDate = endDate;                            
                        else
                            inputDate = datenum( data{irow,icol},'dd-mmm-yyyy');
                        end
                        selectedDate = uical(inputDate, 'English',startDate, endDate);
                        
                        % Get the calibration start date 
                        calibStartDate = datenum( data{irow,icol-1},'dd-mmm-yyyy');                        
                        
                        % Check date is between start and end date of obs
                        % head.
                        if selectedDate < startDate || selectedDate > endDate    
                            warndlg('The calibration end date must be within the range of the observed head data.');
                        elseif calibStartDate>=selectedDate
                            warndlg('The calibration end date must be greater than the calibration start date.');
                        else
                            data{eventdata.Indices(1),eventdata.Indices(2)} = datestr(selectedDate,'dd-mmm-yyyy');
                        end
                        set(hObject,'Data',data);                        
                    otherwise
                        % Do nothing
                end
            end
            
            % Check there is any table data
            if isempty(data)
                return;
            end            
            
            % Find index to the calibrated model label within the
            % list of constructed models.
            if isempty(irow)
                return;
            end
            calibLabel = GST_GUI.removeHTMLTags(data{irow,2});
            modelInd = cellfun(@(x) strcmp(calibLabel, x.model_label), this.models);
            if all(~modelInd)    % Exit if model not found.
                return;
            end          
            modelInd = find(modelInd);
                        
            % Display the requested calibration results if the model object
            % exists and there are calibration results.
            if ~isempty(modelInd) && ~isempty(this.models{modelInd,1}) ...
            && this.models{modelInd,1}.calibrationResults.isCalibrated        
                
                % Get pop up menu item for the selection of results to
                % display.
                results_item = this.tab_ModelCalibration.resultsOptions.popup.Value;
                
        
                switch results_item
                    case 1
                        % Show a table of calibration data
                        
                        % Get the model calibration data.
                        tableData = this.models{modelInd,1}.calibrationResults.data.obsHead;
                        tableData = [tableData, ones(size(tableData,1),1), this.models{modelInd,1}.calibrationResults.data.modelledHead(:,2), ...
                            nan(size(tableData,1),1), this.models{modelInd,1}.calibrationResults.data.modelledHead_residuals(:,end), ...
                            this.models{modelInd,1}.calibrationResults.data.modelledNoiseBounds(:,end-1:end)];
                        
                        % Get evaluation data
                        if isfield(this.models{modelInd,1}.evaluationResults,'data')
                            % Get data
                            evalData = this.models{modelInd,1}.evaluationResults.data.obsHead;
                            evalData = [evalData, zeros(size(evalData,1),1), nan(size(evalData,1),1), this.models{modelInd,1}.evaluationResults.data.modelledHead(:,2), ...
                                this.models{modelInd,1}.evaluationResults.data.modelledHead_residuals(:,end), ...
                                this.models{modelInd,1}.evaluationResults.data.modelledNoiseBounds(:,end-1:end)];
                            
                            % Append to table of calibration data and sort
                            % by time.
                            tableData = [tableData; evalData];
                            tableData = sortrows(tableData, 1);
                        end
                        
                        % Calculate year, month, day etc
                        tableData = [year(tableData(:,1)), month(tableData(:,1)), day(tableData(:,1)), hour(tableData(:,1)), minute(tableData(:,1)), tableData(:,2:end)];
                        
                        % COnvert table to a cell array so that the logical
                        % variables can be displayed.
                        tableData = [num2cell(tableData(:,1:6)), num2cell( tableData(:,7)==true), num2cell(tableData(:,8:end))];
                        
                        % Add data to the table.
                        this.tab_ModelCalibration.resultsOptions.dataTable.table.Data = tableData;                    
                    case 2
                        % Show model parameters
                        
                        %Get parameters and names 
                        [paramValues, paramsNames] = getParameters(this.models{modelInd,1}.model);  
                        
                        % Add to the table
                        this.tab_ModelCalibration.resultsOptions.paramTable.table.Data = cell(length(paramValues),3);
                        this.tab_ModelCalibration.resultsOptions.paramTable.table.Data(:,1) = paramsNames(:,1);
                        this.tab_ModelCalibration.resultsOptions.paramTable.table.Data(:,2) = paramsNames(:,2);
                        this.tab_ModelCalibration.resultsOptions.paramTable.table.Data(:,3) = num2cell(paramValues);
                        
                    case 3
                        % Show derived model variables
                        
                        %Get parameters and names 
                        [paramValues, paramsNames] = getDerivedParameters(this.models{modelInd,1}.model);  
                        
                        % Add to the table
                        this.tab_ModelCalibration.resultsOptions.derivedVariableTable.table.Data = cell(length(paramValues),3);
                        this.tab_ModelCalibration.resultsOptions.derivedVariableTable.table.Data(:,1) = paramsNames(:,1);
                        this.tab_ModelCalibration.resultsOptions.derivedVariableTable.table.Data(:,2) = paramsNames(:,2);
                        this.tab_ModelCalibration.resultsOptions.derivedVariableTable.table.Data(:,3) = num2cell(paramValues);                        
                        
                    case {4, 5, 6, 7, 8, 9, 10}
                        % Create an axis handle for the figure.
                        delete( findobj(this.tab_ModelCalibration.resultsOptions.plots.panel.Children,'type','axes'));
                        delete( findobj(this.tab_ModelCalibration.resultsOptions.plots.panel.Children,'type','legend'));     
                        delete( findobj(this.tab_ModelCalibration.resultsOptions.plots.panel.Children,'type','uipanel'));     
                        h = uipanel('Parent', this.tab_ModelCalibration.resultsOptions.plots.panel );
                        axisHandle = axes( 'Parent', h);
                        % Show the calibration plots. NOTE: QQ plot type
                        % fails so is skipped
                        if results_item<=7
                            calibrateModelPlotResults(this.models{modelInd,1}, results_item-3, axisHandle);
                        else
                            calibrateModelPlotResults(this.models{modelInd,1}, results_item-2, axisHandle);
                        end

                    case 11
                        % do nothing
                end
            else
                this.tab_ModelCalibration.resultsOptions.box.Heights = [30 20 0 0 0 0];
            end
        end                
        
        function modelCalibration_onResultsSelection(this, hObject, eventdata)
            
            % Get selected popup menu item
            listSelection = get(hObject,'Value');
                         
            switch listSelection
                case 1 %Data & residuals
                    this.tab_ModelCalibration.resultsOptions.box.Heights = [30 20 0 -1 0 0];
                case 2 %Parameters
                    this.tab_ModelCalibration.resultsOptions.box.Heights = [30 20 0 0 -1 0];                    
                case 3 %Derived variables
                    this.tab_ModelCalibration.resultsOptions.box.Heights = [30 20 0 0 0 -1];                                                           
                case {4, 5, 6, 7, 8, 9, 10} %Summary plots
                    this.tab_ModelCalibration.resultsOptions.box.Heights = [30 20 -1 0 0 0];
                otherwise %None
                    this.tab_ModelCalibration.resultsOptions.box.Heights = [30 20 0 0 0 0];
            end

        end
        
        function modelCalibration_tableEdit(this, hObject, eventdata)
            % Do nothing
        end        
        
        function tab_ModelCalibration_Dock(this, hObject, eventdata)
            % Do nothing
        end
                
        function modelSimulation_tableEdit(this, hObject, eventdata)

            icol=eventdata.Indices(:,2);
            irow=eventdata.Indices(:,1);            
            data=get(hObject,'Data'); % get the data cell array of the table
                        
            % Undertake column specific operations.
            if ~isempty(icol) && ~isempty(irow)
                
                % Record the current row and column numbers
                this.tab_ModelSimulation.currentRow = irow;
                this.tab_ModelSimulation.currentCol = icol;
            
                % Remove HTML tags from the column name
                columnName = GST_GUI.removeHTMLTags(eventdata.Source.ColumnName{icol});
                
                switch columnName;
                    % Get the selected model.
                    case 'Model Label'
                        
                        % Get the selected model for simulation
                        calibLabel = eventdata.EditData;

                        % Get list of calibrated model
                        model_label = cell(1,0);
                        j=0;
                        for i=1:size(this.models,1)
                           if isfield(this.models{i,1}.calibrationResults,'isCalibrated') && ...
                           this.models{i,1}.calibrationResults.isCalibrated
                                j=j+1;
                                calibLabel_all{j,1} = this.models{i,1}.model_label;
                           end
                        end
                        
                        % Find index to the calibrated model label within the list of calibrated
                        % models.                        
                        ind = cellfun(@(x) strcmp(calibLabel, x), calibLabel_all);
                        if all(~ind)
                            return
                        end

                        % Assign data from the calbration toable to the simulation
                        % table.
                        irow = eventdata.Indices(:,1);     
                        headData = getObservedHead(this.models{ind,1});
                        obshead_start = floor(min(headData(:,1)));
                        obshead_end = max(headData(:,1));            
                        boreID= this.tab_ModelCalibration.Table.Data{ind,3};
                        if size(hObject.Data,1)<irow
                            hObject.Data = [hObject.Data; cell(1,size(hObject.Data,2))];

                        end
                        hObject.Data{irow,1} = false;
                        hObject.Data{irow,2} = calibLabel;
                        hObject.Data{irow,3} = boreID;
                        hObject.Data{irow,4} = ['<html><font color = "#808080">',datestr(obshead_start,'dd-mmm-yyyy'),'</font></html>'];
                        hObject.Data{irow,5} = ['<html><font color = "#808080">',datestr(obshead_end,'dd-mmm-yyyy'),'</font></html>'];
                        hObject.Data{irow,6} = '';
                        hObject.Data{irow,7} = '';
                        hObject.Data{irow,8} = '';
                        hObject.Data{irow,9} = '';
                        hObject.Data{irow,10} = '';   
                        hObject.Data{irow,11} = false;   
                        hObject.Data{irow,12} = '<html><font color = "#FF0000">Not Simulated.</font></html>';
                        
                    % Check the input model simulation label is unique for the selected model.    
                    case 'Simulation Label'                        
                        %  Check if the new model label is unique and
                        %  create a new label if not.
                        allLabels = hObject.Data(:,[2,6]);
                        newLabel = {hObject.Data{irow, 2}, eventdata.EditData};
                        newLabel = GST_GUI.createUniqueLabel(allLabels, newLabel, irow);                        
                        hObject.Data{irow,6} = newLabel{2};

                        % Warn user if the label has chnaged.
                        if ~strcmp(newLabel, eventdata.EditData)
                            warndlg('The model and simulation label pair must be unique. An modified label has been input','Error ...');
                        end                        
                end
            end
        end        
        
        function modelSimulation_tableSelection(this, hObject, eventdata)
            icol=eventdata.Indices(:,2);
            irow=eventdata.Indices(:,1);            
            data=get(hObject,'Data'); % get the data cell array of the table
            
            % Undertake column specific operations.
            if ~isempty(icol) && ~isempty(irow)
                
                % Record the current row and column numbers
                this.tab_ModelSimulation.currentRow = irow;
                this.tab_ModelSimulation.currentCol = icol;
            
                % Remove HTML tags from the column name
                columnName = GST_GUI.removeHTMLTags(eventdata.Source.ColumnName{icol});
                
                switch columnName;
                    case 'Model Label'
                        % Get list of calibrated models
                        calibModels = cellfun( @(x) x.calibrationResults.isCalibrated, this.models);

                        % Get list of model labels
                        calibLabels = cell(size(this.models,1),1);
                        for i=1:size(this.models,1)
                            props = properties(this.models{i});
                            if any(strcmp(props,'model_label'))
                                calibLabels{i,1} = this.models{i}.model_label;
                            end
                        end
                        calibLabels = calibLabels(calibModels);

                        % Remove HTML tags from each model label
                        calibLabels = GST_GUI.removeHTMLTags(calibLabels);

                        % Assign calib model labels to drop down
                        hObject.ColumnFormat{2} = calibLabels';   
                        
                        % Update status in GUI
                        drawnow
                                                
                    case 'Forcing Data File'
                        
                        % Get file name and remove project folder from
                        % preceeding full path.
                        fName = getFileName(this, 'Select the Forcing Data file.');
                        if fName~=0;
                            % Assign file name to date cell array
                            data{irow,icol} = fName;
                            
                            % Input file name to the table
                            set(hObject,'Data',data);
                        end
                        
                    case {'Simulation Start Date', 'Simulation End Date'}
                        % Get the selected model for simulation
                        calibLabel = data{irow,2};

                        % Find index to the calibrated model label within the list of calibrated
                        % models.
                        calibLabel_all = GST_GUI.removeHTMLTags(this.tab_ModelCalibration.Table.Data(:,2));
                        ind = cellfun(@(x) strcmp(calibLabel, x), calibLabel_all);
                        if all(~ind)
                            warndlg('A calibrated model must be first selected from the "Model Label" column.', 'Error ...');
                            return;
                        end

                        % Get the forcing data for the model.
                        % If a new forcing data file is given, then open it
                        % up and get the start and end dates from it.
                        if isempty( data{irow,7}) || strcmp(data{irow,7},'');                            
                            forcingData = getForcingData(this.models{ind,1});

                            % Get start and end dates of the forcing
                            % data, remove HTML tags and then convert to a
                            % date number.
                            startDate = min(forcingData(:,1));
                            endDate = max(forcingData(:,1));                            
                        else
                            % Import forcing data
                            % Check fname file exists.
                            fname = data{irow,7};
                            if exist(fname,'file') ~= 2;                   
                                warndlg('The new forcing date file could not be open for examination of the start and end dates.', 'Error ...');
                                return;
                            end

                            % Read in the file.
                            try
                               forcingData = readtable(fname);
                            catch                   
                                warndlg('The new forcing date file could not be imported for extraction of the start and end dates. Please check its format.', 'Error ...');
                                return;
                            end    
                            
                            % Calculate the start and end dates
                            try
                               forcingData_dates = datenum(forcingData{:,1}, forcingData{:,2}, forcingData{:,3});
                               startDate = min(forcingData_dates);
                               endDate = max(forcingData_dates);
                            catch
                                warndlg('The dates from the new forcing data file could not be calculated. Please check its format.', 'Error ...');
                                return;                                
                            end
                        end
                                                                        
                        % Open the calander with the already input date,
                        % else use the start date of the obs. head.
                        if isempty(data{irow,icol})
                            inputDate = startDate;                            
                        else
                            inputDate = datenum( data{irow,icol},'dd-mmm-yyyy');
                        end
                        selectedDate = uical(inputDate, 'English',startDate, endDate);
                        
                        % Check the selected date
                        if strcmp(columnName, 'Simulation Start Date')
                            % Get the end date 
                            simEndDate = datenum( data{irow,icol+1},'dd-mmm-yyyy');                        
                            
                            % Check date is between start and end date of obs
                            % head.
                            if selectedDate < startDate || selectedDate > endDate    
                                warndlg('The simulation start date must be within the range of the observed forcing data.');
                            elseif selectedDate>=simEndDate
                                warndlg('The simulation start date must be less than the simulation end date.');
                            else
                                data{irow,icol} = datestr(selectedDate,'dd-mmm-yyyy');
                                set(hObject,'Data',data);
                            end
                            
                        else
                            % Get the end date 
                            simStartDate = datenum( data{irow,icol-1},'dd-mmm-yyyy');                        
                            
                            % Check date is between start and end date of obs
                            % head.
                            if selectedDate < startDate || selectedDate > endDate    
                                warndlg('The simulation end date must be within the range of the observed forcing data.');
                            elseif selectedDate<=simStartDate
                                warndlg('The simulation end date must be less than the simulation end date.');
                            else
                                data{irow,icol} = datestr(selectedDate,'dd-mmm-yyyy');
                                set(hObject,'Data',data);
                            end
                            
                        end
                    
                    otherwise
                        % Do nothing
                end
            end
                        
            % Check a row and column are selected.
            if isempty(irow) || isempty(icol)
                return
            end
            
            % Find index to the calibrated model label within the
            % list of constructed models.            
            modelLabel = data{irow,2};
            if isempty(modelLabel)
                return;
            end
            modelInd = cellfun(@(x) strcmp(modelLabel, x.model_label), this.models);
            if all(~modelInd)    % Exit if model not found.
                return;
            end          
            modelInd = find(modelInd);
            
            % Find index to the simulation label within the
            % identified calibrated model.            
            simLabel = data{irow,6};
            if isempty(simLabel)
                return;
            end
            simInd = cellfun(@(x) strcmp(simLabel, x.simulationLabel), this.models{modelInd,1}.simulationResults);
            if all(~simInd)    % Exit if model not found.
                return;
            end          
            simInd = find(simInd);
            
            
            % Display the requested simulation results if the model object
            % exists and there are simulation results.
            if ~isempty(simInd) && isfield(this.models{modelInd,1}.simulationResults{simInd,1},'head') && ...
            ~isempty(this.models{modelInd,1}.simulationResults{simInd,1}.head )               
                
                % Get pop up menu item for the selection of results to
                % display.
                results_item = this.tab_ModelSimulation.resultsOptions.popup.Value;
                        
                switch results_item
                    case 1
                        % Show a table of calibration data
                        
                        % Get the model simulation data.
                        tableData = this.models{modelInd,1}.simulationResults{simInd,1}.head;                        
                        
                        % Calculate year, month, day etc
                        tableData = [year(tableData(:,1)), month(tableData(:,1)), day(tableData(:,1)), hour(tableData(:,1)), minute(tableData(:,1)), tableData(:,2:end)];
                        
                        % Convert to a table data type and add data to the table.
                        this.tab_ModelSimulation.resultsOptions.dataTable.table.Data = tableData;
                        this.tab_ModelSimulation.resultsOptions.dataTable.table.ColumnName = {'Year','Month','Day','Hour','Minute',this.models{modelInd,1}.simulationResults{simInd,1}.colnames{2:end}};

                    case 2
                        % Determine the number of plots to create.
                        nsubPlots = size(this.models{modelInd,1}.simulationResults{simInd,1}.head,2) - 1;
                        
                        % Delete existing panels
                        delete( findobj(this.tab_ModelSimulation.resultsOptions.plots.panel.Children,'type','panel'));
                        delete(findobj(this.tab_ModelSimulation.resultsOptions.plots.panel.Children,'type','uipanel'))
                                                
                        % Add uipanel and axes for each plot
                        for i=1:nsubPlots
                            h = uipanel('Parent',this.tab_ModelSimulation.resultsOptions.plots.panel, 'Visible','off');
                            axisHandles{i} = axes( 'Parent',h);
                        end
                        
                        % Edit position and visibility of each panel
                        for i=1:nsubPlots                            
                            set(this.tab_ModelSimulation.resultsOptions.plots.panel.Children(nsubPlots-i+1), 'BorderType','none');
                            set(this.tab_ModelSimulation.resultsOptions.plots.panel.Children(nsubPlots-i+1), 'Units','normalized');
                            set(this.tab_ModelSimulation.resultsOptions.plots.panel.Children(nsubPlots-i+1), 'Position',[0.01, 1-i/nsubPlots, 0.99, 1/nsubPlots - 0.01]);
                            set(this.tab_ModelSimulation.resultsOptions.plots.panel.Children(nsubPlots-i+1), 'Visible','on');
                        end
                            
                        % Plot the simulation data using the axis handles
                        solveModelPlotResults(this.models{modelInd,1}, simLabel, axisHandles);
                        
                    case 3
                        % do nothing
                end
            else
                this.tab_ModelSimulation.resultsOptions.box.Heights = [30 20 0 0];
            end            
            
            
        end        
        
        function modelSimulation_onResultsSelection(this, hObject, eventdata)
            % Get selected popup menu item
            listSelection = get(hObject,'Value');
                         
            switch listSelection
                case 1 %Data 
                    this.tab_ModelSimulation.resultsOptions.box.Heights = [30 20 -1 0];
                case 2 %Summary plots
                    this.tab_ModelSimulation.resultsOptions.box.Heights = [30 20 0 -1];
                case 3 %None
                    this.tab_ModelSimulation.resultsOptions.box.Heights = [30 20 0 0];
            end
        end
        
        % Get the model options cell array (as a string).
        function onApplyModelOptions(this, hObject, eventdata)
            try
                % get the new model options
                modelOptionsArray = getModelOptions(this.tab_ModelConstruction.modelTypes.model_TFN.obj);            

                % Warn the user if the model is already built and the
                % inputs are to change - reuiring the model object to be
                % removed.            
                irow = this.tab_ModelConstruction.currentRow;
                if ~isempty(this.tab_ModelConstruction.Table.Data{irow,8}) && ...
                ~strcmp(modelOptionsArray, this.tab_ModelConstruction.Table.Data{irow,8} )

                    % Get original model label
                    modelLabel = this.tab_ModelConstruction.Table.Data{irow,2};

                    % Check if the model object exists
                    ind=[];
                    if size(this.models,1)>0 && isfield(this.models{1},'model_label')
                        ind = cellfun( @(x) strcmp(x.model_label,modelLabel), this.models);
                    end
                    if ~isempty(ind)

                        % Check if the model is calibrated
                        isCalibrated = false;
                        if ~isempty(this.models{ind}.calibrationResults) && this.models{ind}.calibrationResults.isCalibrated
                            isCalibrated = true;
                        end

                        % Create warnign message and display
                        if isCalibrated
                            msg = {['Model ',modelLabel, ' has already been built and calibrated. If you change the model construction all calibration and simulation results will be deleted.'], ...
                                    '', ...                                
                                   'Do you want to continue with the changes to the model construction?'};
                        else
                            msg = {['Model ',modelLabel, ' has already been built (but not calibrated). If you change the model construction you will need to rebuild the model.'], ...
                                    '', ...
                                   'Do you want to continue with the changes to the model construction?'};
                        end                            

                        response = questdlg(msg,'Overwrite exiting model?','Yes','No','No');

                        % Check if 'cancel, else delete the model object
                        if strcmp(response,'No')
                            return;
                        else
                            filt = true(length(this.models),1);
                            filt(ind) = false;
                            this.models = this.models(filt);
                        end

                        % Change status of the model object.
                        this.tab_ModelConstruction.Table.Data{irow,end} = '<html><font color = "#FF0000">Model not built.</font></html>';

                        % Delete model from calibration table.
                        modelLabels_calibTable =  this.tab_ModelCalibration.Table.Data(:,2);                            
                        modelLabels_calibTable = GST_GUI.removeHTMLTags(modelLabels_calibTable);
                        ind = cellfun( @(x) strcmp(x,modelLabel), modelLabels_calibTable);
                        this.tab_ModelCalibration.Table.Data = this.tab_ModelCalibration.Table.Data(~ind,:);

                        % Update row numbers
                        nrows = size(this.tab_ModelCalibration.Table.Data,1);
                        this.tab_ModelCalibration.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                     

                        % Delete models from simulations table.
                        modelLabels_simTable =  this.tab_ModelSimulation.Table.Data(:,2);                            
                        modelLabels_simTable = GST_GUI.removeHTMLTags(modelLabels_simTable);
                        ind = cellfun( @(x) strcmp(x,modelLabel), modelLabels_simTable);
                        this.tab_ModelSimulation.Table.Data = this.tab_ModelSimulation.Table.Data(~ind,:);   

                        % Update row numbers
                        nrows = size(this.tab_ModelSimulation.Table.Data,1);
                        this.tab_ModelSimulation.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                     
                    end
                end

                % Apply new model options.
                this.tab_ModelConstruction.Table.Data{this.tab_ModelConstruction.currentRow,8} = modelOptionsArray;
            catch
                errordlg('The model options could not be applied to the model. Please check the model options are sensible.');
            end

        end
        
        % Get the model options cell array (as a string).
        function onApplyModelOptions_selectedBores(this, hObject, eventdata)
            
            try
                % Get the current model type.
                currentModelType = this.tab_ModelConstruction.Table.Data{this.tab_ModelConstruction.currentRow, 7};

                % Get list of selected bores.
                selectedBores = this.tab_ModelConstruction.Table.Data(:,1);

                % Check some bores have been selected.
                if ~any(cellfun(@(x) x, selectedBores))
                    warndlg('No models are selected.', 'Summary of model options applied to bores...');
                    return;
                end

                % Get the model options.
                modelOptionsArray = getModelOptions(this.tab_ModelConstruction.modelTypes.model_TFN.obj);

                % Loop  through the list of selected bore and apply the modle
                % options.
                nOptionsCopied = 0;
                response = '';
                for i=1:length(selectedBores);
                    if selectedBores{i} && strcmp(this.tab_ModelConstruction.Table.Data{i,7}, currentModelType)

                        % Warn the user if the model is already built and the
                        % inputs are to change - reuiring the model object to be
                        % removed.            
                        if ~isempty(this.tab_ModelConstruction.Table.Data{i,8}) && ...
                        ~strcmp(modelOptionsArray, this.tab_ModelConstruction.Table.Data{i,8} )

                            % Get original model label
                            modelLabel = this.tab_ModelConstruction.Table.Data{i,2};

                            % Check if the model object exists
                            ind = cellfun( @(x) strcmp(x.model_label,modelLabel), this.models);
                            if ~isempty(ind) 

                                if strcmp(response, 'Yes - all models')
                                    filt = true(length(this.models),1);
                                    filt(ind) = false;
                                    this.models = this.models(filt);                                
                                else

                                    % Check if the model is calibrated
                                    isCalibrated = false;
                                    if ~isempty(this.models{ind}.calibrationResults) && this.models{ind}.calibrationResults.isCalibrated
                                        isCalibrated = true;
                                    end

                                    % Create warnign message and display
                                    if isCalibrated
                                        msg = {['Model ',modelLabel, ' has already been built and calibrated. If you change the model construction all calibration and simulation results will be deleted.'], ...
                                                '', ...                                
                                               'Do you want to continue with the changes to the model construction?'};
                                    else
                                        msg = {['Model ',modelLabel, ' has already been built (but not calibrated). If you change the model construction you will need to rebuild the model.'], ...
                                                '', ...
                                               'Do you want to continue with the changes to the model construction?'};
                                    end                            

                                    response = questdlg(msg,'Overwrite exiting model?','Yes','Yes - all models','No','No');

                                    % Check if 'cancel, else delete the model object
                                    if strcmp(response,'No')
                                        continue;
                                    else
                                        filt = true(length(this.models),1);
                                        filt(ind) = false;
                                        this.models = this.models(filt);
                                    end
                                end

                                % Change status of the model object.
                                this.tab_ModelConstruction.Table.Data{i,end} = '<html><font color = "#FF0000">Model not built.</font></html>';

                                % Delete model from calibration table.
                                modelLabels_calibTable =  this.tab_ModelCalibration.Table.Data(:,2);                            
                                modelLabels_calibTable = GST_GUI.removeHTMLTags(modelLabels_calibTable);
                                ind = cellfun( @(x) strcmp(x,modelLabel), modelLabels_calibTable);
                                this.tab_ModelCalibration.Table.Data = this.tab_ModelCalibration.Table.Data(~ind,:);

                                % Update row numbers
                                nrows = size(this.tab_ModelCalibration.Table.Data,1);
                                this.tab_ModelCalibration.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                                   

                                % Delete models from simulations table.
                                modelLabels_simTable =  this.tab_ModelSimulation.Table.Data(:,2);                            
                                modelLabels_simTable = GST_GUI.removeHTMLTags(modelLabels_simTable);
                                ind = cellfun( @(x) strcmp(x,modelLabel), modelLabels_simTable);
                                this.tab_ModelSimulation.Table.Data = this.tab_ModelSimulation.Table.Data(~ind,:);

                                % Update row numbers
                                nrows = size(this.tab_ModelSimulation.Table.Data,1);
                                this.tab_ModelSimulation.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                              

                            end
                        end                    

                        % Apply model option.
                        this.tab_ModelConstruction.Table.Data{i,8} = modelOptionsArray;            
                        nOptionsCopied = nOptionsCopied + 1;
                    end
                end            

                msgbox(['The model options were copied to ',num2str(nOptionsCopied), ' "', currentModelType ,'" models.'], 'Summary of model options applied to bores...');
            catch
                errordlg('The model options could not be applied to the selected models. Please check the model options are sensible.');
            end

        end

        function onAnalyseBores(this, hObject, eventdata)
           
                        % Get table data
            data = this.tab_DataPrep.Table.Data;
            
            % Get list of selected bores.
            selectedBores = data(:,1);

            % Change cursor to arrow
            set(this.Figure, 'pointer', 'watch');
            drawnow

            % Check that the user wants to save the projct after each
            % calib.
            response = questdlg('Do you want to save the project after each bore is analysed?','Auto-save analysis results?','Yes','No','Cancel','Yes');
            if strcmp(response,'Cancel')
                return;
            end
            if strcmp(response,'Yes') && (isempty(this.project_fileName) || exist(this.project_fileName,'file') ~= 2);
                msgbox('The project has not yet been saved. Please save it and re-run the analysis.','Project not yet saved ...','error');
                return;
            end
            saveModels=false;
            if strcmp(response,'Yes')
                saveModels=true;
            end            
            
            % Loop  through the list of selected bore and apply the modle
            % options.
            nBoresAnalysed = 0;
            nAnalysisFailed = 0;
            nBoreNotInHeadFile=0;
            nBoreInputsError = 0;
            nBoreIDLabelError = 0;
            for i=1:length(selectedBores);
                % Check if the model is to be built.
                if isempty(selectedBores{i}) ||  ~selectedBores{i}
                    continue;
                end

                % Update table with progress'
                this.tab_DataPrep.Table.Data{i, 15} = '<html><font color = "#FFA500">Analysing bore ...</font></html>';
                this.tab_DataPrep.Table.Data{i,16} = ['<html><font color = "#808080">','(NA)','</font></html>'];
                this.tab_DataPrep.Table.Data{i,17} = ['<html><font color = "#808080">','(NA)','</font></html>'];
                    
                % Update status in GUI
                drawnow
                
                % Import head data
                %----------------------------------------------------------
                % Check the obs. head file is listed
                if isdir(this.project_fileName)                             
                    fname = fullfile(this.project_fileName,data{i,2}); 
                else
                    fname = fullfile(fileparts(this.project_fileName),data{i,2});  
                end                
                if isempty(fname)                    
                    this.tab_DataPrep.Table.Data{i, 15} = '<html><font color = "#FF0000">Head data file error - file name empty.</font></html>';
                    nAnalysisFailed = nAnalysisFailed + 1;
                    continue;
                end

                % Check the bore ID file exists.
                if exist(fname,'file') ~= 2;                    
                    this.tab_DataPrep.Table.Data{i, 15} = '<html><font color = "#FF0000">Head data file error - file does not exist.</font></html>';
                    nAnalysisFailed = nAnalysisFailed + 1;
                    continue;
                end

                % Read in the observed head file.
                try
                    tbl = readtable(fname);
                catch                    
                    this.tab_DataPrep.Table.Data{i, 15} = '<html><font color = "#FF0000">Head data file error -  read in failed.</font></html>';
                    nAnalysisFailed = nAnalysisFailed + 1;
                    continue;
                end                
                
                % Filter for the required bore.
                boreID = data{i,3};
                filt =  strcmp(tbl{:,1},boreID);
                if sum(filt)<=0
                    this.tab_DataPrep.Table.Data{i, 15} = '<html><font color = "#FF0000">Bore not found in head data file -  data error.</font></html>';
                    nBoreNotInHeadFile = nBoreNotInHeadFile +1;
                    continue
                end
                headData = tbl(filt,2:end);
                headData = headData{:,:};                
                %----------------------------------------------------------
                                
                % Get required inputs for analysis
                %----------------------------------------------------------
                boreDepth = inf;
                dataCol=4;
                if ~isnumeric(this.tab_DataPrep.Table.Data{i, dataCol})
                    this.tab_DataPrep.Table.Data{i, 15} = ['<html><font color = "#FF0000">Input for column ', num2str(dataCol), ' must be a number. </font></html>'];
                    nBoreInputsError = nBoreInputsError +1;
                    continue
                end
                if ~isempty(this.tab_DataPrep.Table.Data{i, dataCol}) && this.tab_DataPrep.Table.Data{i, dataCol}>0
                    boreDepth = this.tab_DataPrep.Table.Data{i, dataCol};
                end
                
                surfaceElevation = inf;
                dataCol = 5;
                if ~isnumeric(this.tab_DataPrep.Table.Data{i, dataCol})
                    this.tab_DataPrep.Table.Data{i, 15} = ['<html><font color = "#FF0000">Input for column ', num2str(dataCol), ' must be a number. </font></html>'];
                    nBoreInputsError = nBoreInputsError +1;
                    continue
                end                
                if ~isempty(this.tab_DataPrep.Table.Data{i, dataCol})
                    surfaceElevation = this.tab_DataPrep.Table.Data{i, dataCol};
                end
                
                caseLength = inf;
                dataCol = 6;
                if ~isnumeric(this.tab_DataPrep.Table.Data{i, dataCol})
                    this.tab_DataPrep.Table.Data{i, 15} = ['<html><font color = "#FF0000">Input for column ', num2str(dataCol), ' must be a number. </font></html>'];
                    nBoreInputsError = nBoreInputsError +1;
                    continue
                end                
                if ~isempty(this.tab_DataPrep.Table.Data{i, dataCol}) && this.tab_DataPrep.Table.Data{i, dataCol}>0
                    caseLength = this.tab_DataPrep.Table.Data{i, dataCol};
                end
                
                constructionDate = datenum(0,0,0);
                dataCol = 7;
                if ~isempty(this.tab_DataPrep.Table.Data{i, dataCol})
                    try
                        constructionDate = datenum(this.tab_DataPrep.Table.Data{i, dataCol});
                    catch
                        this.tab_DataPrep.Table.Data{i, 15} = '<html><font color = "#FF0000">Bore not found in head data file -  data error.</font></html>';
                        nBoreInputsError = nBoreInputsError +1;
                        continue
                    end
                end   
                
                checkStartDate = false;
                dataCol = 8;               
                if ~isempty(this.tab_DataPrep.Table.Data{i, dataCol})
                    checkStartDate = this.tab_DataPrep.Table.Data{i, dataCol};
                end                
                
                checkEndDate = false;
                dataCol = 9;               
                if ~isempty(this.tab_DataPrep.Table.Data{i, dataCol})
                    checkEndDate = this.tab_DataPrep.Table.Data{i, dataCol};
                end       
                
                checkMinHead = false;
                dataCol = 10;               
                if ~isempty(this.tab_DataPrep.Table.Data{i, dataCol})
                    checkMinHead = this.tab_DataPrep.Table.Data{i, dataCol};
                end       

                
                checkMaxHead = false;
                dataCol = 11;               
                if ~isempty(this.tab_DataPrep.Table.Data{i, dataCol})
                    checkMaxHead = this.tab_DataPrep.Table.Data{i, dataCol};
                end         
                
                
                rateOfChangeThreshold = inf;
                dataCol = 12;
                if ~isnumeric(this.tab_DataPrep.Table.Data{i, dataCol})
                    this.tab_DataPrep.Table.Data{i, 15} = ['<html><font color = "#FF0000">Input for column ', num2str(dataCol), ' must be a number. </font></html>'];
                    nBoreInputsError = nBoreInputsError +1;
                    continue
                end                
                if ~isempty(this.tab_DataPrep.Table.Data{i, dataCol}) && this.tab_DataPrep.Table.Data{i, dataCol}>0
                    rateOfChangeThreshold = this.tab_DataPrep.Table.Data{i, dataCol};
                end      
                
                constHeadDuration = inf;
                dataCol = 13;
                if ~isnumeric(this.tab_DataPrep.Table.Data{i, dataCol})
                    this.tab_DataPrep.Table.Data{i, 15} = ['<html><font color = "#FF0000">Input for column ', num2str(dataCol), ' must be a number. </font></html>'];
                    nBoreInputsError = nBoreInputsError +1;
                    continue
                end                
                if ~isempty(this.tab_DataPrep.Table.Data{i, dataCol}) && this.tab_DataPrep.Table.Data{i, dataCol}>0
                    constHeadDuration = this.tab_DataPrep.Table.Data{i, dataCol};
                end
                
                numNoiseStdDev = inf;
                dataCol = 14;
                if ~isnumeric(this.tab_DataPrep.Table.Data{i, dataCol})
                    this.tab_DataPrep.Table.Data{i, 15} = ['<html><font color = "#FF0000">Input for column ', num2str(dataCol), ' must be a number. </font></html>'];
                    nBoreInputsError = nBoreInputsError +1;
                    continue
                end                
                if ~isempty(this.tab_DataPrep.Table.Data{i, dataCol}) && this.tab_DataPrep.Table.Data{i, dataCol}>0
                    numNoiseStdDev = this.tab_DataPrep.Table.Data{i, dataCol};
                end                      
                %----------------------------------------------------------
                                
                % Convert boreID string to appropriate field name and test
                % if is can be converted to a field name
                boreID = strrep(boreID,' ','_');
                boreID = strrep(boreID,'-','_');
                boreID = strrep(boreID,'?','');
                boreID = strrep(boreID,'\','_');
                boreID = strrep(boreID,'/','_');
                try 
                    tmp.(boreID) = [1 2 3];
                    clear tmp;
                catch ME
                    this.tab_DataPrep.Table.Data{i, 15} = '<html><font color = "#FF0000">Bore ID label error - must start with letters and have only letters and numbers.</font></html>';
                    nBoreIDLabelError = nBoreIDLabelError+1;
                end
                    
                % Convert head date/time columns to a vector.
                switch size(headData,2)-1
                    case 3
                        dateVec = datenum(headData(:,1), headData(:,2), headData(:,3));
                    case 4
                        dateVec = datenum(headData(:,1), headData(:,2), headData(:,3),headData(:,4), zeros(size(headData,1),1), zeros(size(headData,1),1));
                    case 5
                        dateVec = datenum(headData(:,1), headData(:,2), headData(:,3),headData(:,4),headData(:,5), zeros(size(headData,1),1));
                    case 6
                        dateVec = datenum(headData(:,1), headData(:,2), headData(:,3),headData(:,4),headData(:,5),headData(:,6));
                    otherwise
                        error('The input observed head must be 4 to 7 columns with right hand column being the head and the left columns: year; month; day; hour (optional), minute (options), second (optional).');
                end                
                
                % Call analysis function                
                try
                    % Do the analysis and add to the object
                    chechDuplicateDates = true;
                    this.dataPrep.(boreID) = doDataQualityAnalysis( [dateVec, headData(:,end)], boreDepth, surfaceElevation, caseLength, constructionDate, ...
                    checkStartDate, checkEndDate, chechDuplicateDates, checkMinHead, checkMaxHead, rateOfChangeThreshold, ...
                    constHeadDuration, numNoiseStdDev );                                                       
                    
                    % Add summary stats
                    numErroneouObs = sum(any(table2array(this.dataPrep.(boreID)(:,7:12)),2));
                    numOutlierObs = sum(table2array(this.dataPrep.(boreID)(:,13)));                    
                    this.tab_DataPrep.Table.Data{i,16} = ['<html><font color = "#808080">',num2str(numErroneouObs),'</font></html>'];
                    this.tab_DataPrep.Table.Data{i,17} = ['<html><font color = "#808080">',num2str(numOutlierObs),'</font></html>'];
                                  
                    nBoresAnalysed = nBoresAnalysed +1;
                    
                    if saveModels
                        this.tab_DataPrep.Table.Data{i,15} = '<html><font color = "#FFA500">Saving project. </font></html>';

                        % Update status in GUI
                        drawnow                        
                        
                        % Save project.
                        onSave(this,hObject,eventdata);
                    end
                    
                    this.tab_DataPrep.Table.Data{i, 15} = '<html><font color = "#008000">Bore analysed.</font></html>';
                    
                catch ME
                    this.tab_DataPrep.Table.Data{i, 15} = ['<html><font color = "#FF0000">Analysis failed - ', ME.message,'</font></html>'];   
                    this.tab_DataPrep.Table.Data{i,16} = ['<html><font color = "#808080">','(NA)','</font></html>'];
                    this.tab_DataPrep.Table.Data{i,17} = ['<html><font color = "#808080">','(NA)','</font></html>'];
                    
                    nAnalysisFailed = nAnalysisFailed +1;
                    continue                    
                end
          
                % Update status in GUI
                drawnow
            end
            
            % Change cursor to arrow
            set(this.Figure, 'pointer', 'arrow');
            drawnow
            
            % Report Summary
            msgbox({['The data analysis was successfully for ',num2str(nBoresAnalysed), ' bores.'], ...
                    '', ...
                    ['Below is a summary of the failures:'], ...
                    ['   - Head data file errors: ', num2str(nBoreNotInHeadFile)] ...
                    ['   - Input table data errors: ', num2str(nBoreInputsError)] ...
                    ['   - Data analysis algorithm failures: ', num2str(nAnalysisFailed)] ...
                    ['   - Bore IDs not starting with a letter and having only letters & numbers: ', num2str(nBoreIDLabelError)]}, ...                    
                    'Summary of data analysis ...');
                           
            
        end
        
        function onBuildModels(this, hObject, eventdata)
            
            % Delete any empty model objects
            if ~isempty(this.models)
                keepModelObject = true(size(this.models,1),1);
                for i=1:size(this.models,1)
                    if isempty(this.models{i})
                        keepModelObject(i,1) = false;
                    end
                end
                this.models = this.models(keepModelObject,1);
            end
            
            % Get table data
            data = this.tab_ModelConstruction.Table.Data;
            
            % Get list of selected bores.
            selectedBores = data(:,1);

            % Change cursor to arrow
            set(this.Figure, 'pointer', 'watch');
            drawnow
                        
            % Loop  through the list of selected bore and apply the modle
            % options.
            nModelsBuilt = 0;
            nModelsBuiltFailed = 0;
            for i=1:length(selectedBores);
                % Check if the model is to be built.
                if isempty(selectedBores{i}) || ~selectedBores{i}
                    continue;
                end

                % Update table with progress'
                this.tab_ModelConstruction.Table.Data{i, 9} = '<html><font color = "#FFA500">Building model ...</font></html>';

                % Update status in GUI
                drawnow
                                
                % Import head data
                %----------------------------------------------------------
                % Check the obs. head file is listed
                if isdir(this.project_fileName)
                    fname = fullfile(this.project_fileName,data{i,3});
                else
                    fname = fullfile(fileparts(this.project_fileName),data{i,3});
                end
                if isempty(fname)                    
                    this.tab_ModelConstruction.Table.Data{i, 9} = '<html><font color = "#FF0000">Head data file error - file name empty.</font></html>';
                    nModelsBuiltFailed = nModelsBuiltFailed + 1;
                    continue;
                end

                % Check the bore ID file exists.
                if exist(fname,'file') ~= 2;                    
                    this.tab_ModelConstruction.Table.Data{i, 9} = '<html><font color = "#FF0000">Head data file error - file does not exist.</font></html>';
                    nModelsBuiltFailed = nModelsBuiltFailed + 1;
                    continue;
                end

                % Read in the observed head file.
                try
                    tbl = readtable(fname);
                catch                    
                    this.tab_ModelConstruction.Table.Data{i, 9} = '<html><font color = "#FF0000">Head data file error -  read in failed.</font></html>';
                    nModelsBuiltFailed = nModelsBuiltFailed + 1;
                    continue;
                end                
                
                % Filter for the required bore.
                filt =  strcmp(tbl{:,1},data{i,6});
                headData = tbl(filt,2:end);
                headData = headData{:,:};
                
                % Check theer is some obs data
                if size(headData,1)<=1
                    this.tab_ModelConstruction.Table.Data{i, 9} = '<html><font color = "#FF0000">Head data file error - <=1 observation.</font></html>';
                    nModelsBuiltFailed = nModelsBuiltFailed + 1;
                    continue;
                end
                
                %----------------------------------------------------------
                
                % Import forcing data
                %----------------------------------------------------------
                % Check fname file exists.
                if isdir(this.project_fileName)
                    fname = fullfile(this.project_fileName,data{i,4});
                else
                    fname = fullfile(fileparts(this.project_fileName),data{i,4});
                end
                if exist(fname,'file') ~= 2;                   
                   this.tab_ModelConstruction.Table.Data{i, 9} = '<html><font color = "#FF0000">Forcing data file error - file name empty.</font></html>';
                   nModelsBuiltFailed = nModelsBuiltFailed + 1;
                   continue;
                end

                % Read in the file.
                try
                   forcingData = readtable(fname);
                catch                   
                   this.tab_ModelConstruction.Table.Data{i, 9} = '<html><font color = "#FF0000">Forcing data file error -  read in failed.</font></html>';
                   nModelsBuiltFailed = nModelsBuiltFailed + 1;
                   continue;
                end                
                %----------------------------------------------------------
                
                
                % Import coordintate data
                %----------------------------------------------------------
                % Check fname file exists.
                if isdir(this.project_fileName)
                    fname = fullfile(this.project_fileName,data{i,5});
                else
                    fname = fullfile(fileparts(this.project_fileName),data{i,5});
                end
                if exist(fname,'file') ~= 2;                   
                   nModelsBuiltFailed = nModelsBuiltFailed + 1;
                   this.tab_ModelConstruction.Table.Data{i, 9} = '<html><font color = "#FF0000">Coordinate file error - file name empty.</font></html>';
                   continue;
                end

                % Read in the file.
                try
                   coordData = readtable(fname);
                   coordData = table2cell(coordData);
                catch              
                   nModelsBuiltFailed = nModelsBuiltFailed + 1;
                   this.tab_ModelConstruction.Table.Data{i, 9} = '<html><font color = "#FF0000">Coordinate file error -  read in failed.</font></html>';
                   continue;
                end
                %----------------------------------------------------------

                % Get model label
                model_label = data{i,2};
                
                % Get bore IDs
                boreID= data{i,6};
                
                % Get model type
                modelType = data{i,7};
                
                % If the modle options are empty, try and add an empty cell
                % in case the model does not need options.
                if isempty(data{i,8})
                    data{i,8} = '{}';
                end
                
                % Get model options
                try
                    modelOptions= eval(data{i,8});
                catch
                    nModelsBuiltFailed = nModelsBuiltFailed + 1;
                    this.tab_ModelConstruction.Table.Data{i, 9} = '<html><font color = "#FF0000">Syntax error in model options - string not convertable to cell array.</font></html>';
                    continue;
                end
                
                % Find index to the model to be built has already been
                % built. If so, find the index. Else increment the index.
                if isempty(this.models) || (size(this.models,1)==1 && isfield(this.models{1},'model_label'))
                    this.models = cell(1,1);
                    ind = 1;                    
                elseif iscell(this.models)
                    ind = false(size(this.models));
                    for j=1: length(this.models)   
                        try
                            ind(j,1) = strcmp(model_label, this.models{j}.model_label);
                        catch
                            % do nothing
                        end
                    end
                    if all(~ind)
                        ind = size(this.models,1)+1;
                    end    
                end

                
                % Build model
                try
                    this.models{ind,1} = GroundwaterStatisticsToolbox(model_label, boreID, modelType , headData, 1, forcingData, coordData, modelOptions);
                    
                    % Check if the model is listed in the calibration date.
                    isModelListed  = []; 
                    if ~isempty(this.tab_ModelCalibration.Table.Data)
                        % Get model label
                        calibModelLabelsHTML = this.tab_ModelCalibration.Table.Data(:,2);
                        % Remove HTML tags
                        calibModelLabels = GST_GUI.removeHTMLTags(calibModelLabelsHTML);

                        % Find index to calb. models
                        isModelListed = cellfun( @(x) strcmp( model_label, x), calibModelLabels);
                    end
                    
                    % Get model start and end dates
                    obshead_start = min(datenum(headData(:,1),headData(:,2),headData(:,3) ));
                    obshead_end = max(datenum(headData(:,1),headData(:,2),headData(:,3) ));
                    
                    % Add the model to the calibration table.
                    if ~any(isModelListed)
                        this.tab_ModelCalibration.Table.Data = [this.tab_ModelCalibration.Table.Data; ...
                        cell(1,14)];
                        isModelListed = size(this.tab_ModelCalibration.Table.Data,1);
                        
                        this.tab_ModelCalibration.Table.Data{isModelListed,2} = ['<html><font color = "#808080">',model_label,'</font></html>'];
                        this.tab_ModelCalibration.Table.Data{isModelListed,3} = ['<html><font color = "#808080">',boreID,'</font></html>'];
                        this.tab_ModelCalibration.Table.Data{isModelListed,4} = ['<html><font color = "#808080">',datestr(obshead_start,'dd-mmm-yyyy'),'</font></html>'];
                        this.tab_ModelCalibration.Table.Data{isModelListed,5} = ['<html><font color = "#808080">',datestr(obshead_end,'dd-mmm-yyyy'),'</font></html>'];
                        this.tab_ModelCalibration.Table.Data{isModelListed,6} = datestr(obshead_start,'dd-mmm-yyyy');
                        this.tab_ModelCalibration.Table.Data{isModelListed,7} = datestr(obshead_end,'dd-mmm-yyyy');
                        this.tab_ModelCalibration.Table.Data{isModelListed,8} = 'SP-UCI';
                        this.tab_ModelCalibration.Table.Data{isModelListed,9} = 2;
                        
                        % Update row numbers
                        nrows = size(this.tab_ModelCalibration.Table.Data,1);
                        this.tab_ModelCalibration.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                        
                        
                    else
                        this.tab_ModelCalibration.Table.Data{isModelListed,3} = ['<html><font color = "#808080">',boreID,'</font></html>'];
                        this.tab_ModelCalibration.Table.Data{isModelListed,4} = ['<html><font color = "#808080">',datestr(obshead_start,'dd-mmm-yyyy'),'</font></html>'];
                        this.tab_ModelCalibration.Table.Data{isModelListed,5} = ['<html><font color = "#808080">',datestr(obshead_end,'dd-mmm-yyyy'),'</font></html>'];
                    end
                    this.tab_ModelCalibration.Table.Data{isModelListed,10} = '<html><font color = "#FF0000">Not calibrated.</font></html>';
                    
                    
                    this.tab_ModelConstruction.Table.Data{i, 9} = '<html><font color = "#008000">Model built.</font></html>';
                    nModelsBuilt = nModelsBuilt + 1; 
                    
                catch ME
                    nModelsBuiltFailed = nModelsBuiltFailed + 1;
                    this.tab_ModelConstruction.Table.Data{i, 9} = ['<html><font color = "#FF0000">Model build failed - ', ME.message,'</font></html>'];
                end
                
                % Update status in GUI
                drawnow

            end
            
            % Change cursor to arrow
            set(this.Figure, 'pointer', 'arrow');
            drawnow
                        
            % Report Summary
            msgbox(['The model was successfully built for ',num2str(nModelsBuilt), ' models and failed for ',num2str(nModelsBuiltFailed), ' models.'], 'Summary of model builds ...');
                        
        end
        
        function onCalibModels(this, hObject, eventdata)
            
            % Delete any empty modle objects
            if ~isempty(this.models)
                keepModelObject = true(size(this.models,1),1);
                for i=1:size(this.models,1)
                    if isempty(this.models{i})
                        keepModelObject(i,1) = false;
                    end
                end
                this.models = this.models(keepModelObject,1);            
            else
                warndlg('Not models appear to have been built. Please build the models then calibrate them.','Model Calibration Error ...')
                return;
            end
            
            % Get table data
            data = this.tab_ModelCalibration.Table.Data;
            
            % Delete any models listed in the calibration table that are
            % not listed in the model construction table            
            if ~isempty(data)
                constructModelLabels = this.tab_ModelConstruction.Table.Data(:,2);
                deleteCalibRow = false(size(data,1),1);
                for i=1:size(data,1)
                    % Get model label
                    calibModelLabelsHTML = data(i,2);
                    % Remove HTML tags
                    calibModelLabels = GST_GUI.removeHTMLTags(calibModelLabelsHTML);

                    % Add index for row if it is to be deleted                    
                    if ~any(cellfun( @(x) strcmp( calibModelLabels, x), constructModelLabels))
                        deleteCalibRow(i) = true;
                    end
                end
                
                if any(deleteCalibRow)
                    warndlg('Some models listed in the calibration table are not listed in the model construction table and will be deleted. Please re-run the calibration','Unexpected table error...');
                    this.tab_ModelCalibration.Table.Data = this.tab_ModelCalibration.Table.Data(~deleteCalibRow,:);
                    

                    % Update row numbers
                    nrows = size(this.tab_ModelCalibration.Table.Data,1);
                    this.tab_ModelCalibration.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                            
                    
                    return;
                end
                
            end            
            
            % Check that the user wants to save the projct after each
            % calib.
            response = questdlg('Do you want to save the project after each model is calibrated?','Auto-save models?','Yes','No','Cancel','Yes');
            if strcmp(response,'Cancel')
                return;
            end
            if strcmp(response,'Yes') && (isempty(this.project_fileName) || exist(this.project_fileName,'file') ~= 2);
                msgbox('The project has not yet been saved. Please save it and re-run the calibration.','Project not yet saved ...','error');
                return;
            end
            saveModels=false;
            if strcmp(response,'Yes')
                saveModels=true;
            end            
            
            % Get list of selected bores.
            selectedBores = data(:,1);

            % Change cursor
            set(this.Figure, 'pointer', 'watch');
            drawnow
            
            % Open parrallel engine for calibration
            try
                %nCores=str2double(getenv('NUMBER_OF_PROCESSORS'));
                parpool('local');
            catch ME
                % Do nothing. An error is probably that parpool is already
                % open
            end
                
            
            % Loop  through the list of selected bore and apply the modle
            % options.
            nModelsCalib = 0;
            nModelsCalibFailed = 0;
            for i=1:length(selectedBores);
                
                % Check if the model is to be calibrated.
                if isempty(selectedBores{i}) || ~selectedBores{i}
                    continue;
                end

                % Get the selected model for simulation
                calibLabel = data{i,2};

                % Find index to the calibrated model label within the
                % list of constructed models.
                calibLabel = GST_GUI.removeHTMLTags(calibLabel);
                ind = cellfun(@(x) strcmp(calibLabel, x.model_label), this.models);
                if all(~ind)
                    nModelsCalibFailed = nModelsCalibFailed +1;
                    this.tab_ModelCalibration.Table.Data{i,10} = '<html><font color = "#FF0000">Calib. failed - Model appears not to have been built.</font></html>';
                    continue;
                end    
                               
                % Update status to starting calib.
                this.tab_ModelCalibration.Table.Data{i,10} = '<html><font color = "#FFA500">Calibrating ... </font></html>';

                % Update status in GUI
                drawnow
                
                % Get start and end date. Note, start date is at the start
                % of the day and end date is shifted to the end of the day.
                calibStartDate = datenum( data{i,6},'dd-mmm-yyyy');
                calibEndDate = datenum( data{i,7},'dd-mmm-yyyy') + datenum(0,0,0,23,59,59);
                calibMethod = data{i,8};
                calibMethodSetting = data{i,9};
                try
                    calibrateModel( this.models{ind,1}, calibStartDate, calibEndDate, calibMethod,  calibMethodSetting);
                    
                    if saveModels
                        this.tab_ModelCalibration.Table.Data{i,10} = '<html><font color = "#FFA500">Saving project. </font></html>';

                        % Update status in GUI
                        drawnow                        
                        
                        % Save project.
                        onSave(this,hObject,eventdata);
                    end
                    
                    % Delete CMAES working files
                    switch calibMethod
                        case {'CMA ES','CMA_ES','CMAES','CMA-ES'}
                            delete('*.dat');
                        otherwise
                            % do nothing
                    end
                    
                    this.tab_ModelCalibration.Table.Data{i,10} = '<html><font color = "#008000">Calibrated. </font></html>';

                    % Update status in GUI
                    drawnow
                
                    % Set calib performance stats.
                    calibAIC = this.models{ind, 1}.calibrationResults.performance.AIC;
                    calibCoE = this.models{ind, 1}.calibrationResults.performance.CoeffOfEfficiency_mean.CoE;
                    this.tab_ModelCalibration.Table.Data{i,11} = ['<html><font color = "#808080">',num2str(calibCoE),'</font></html>'];
                    this.tab_ModelCalibration.Table.Data{i,13} = ['<html><font color = "#808080">',num2str(calibAIC),'</font></html>'];

                    % Set eval performance stats
                    if isfield(this.models{ind, 1}.evaluationResults,'performance')
                        evalAIC = this.models{ind, 1}.evaluationResults.performance.AIC;
                        evalCoE = this.models{ind, 1}.evaluationResults.performance.CoeffOfEfficiency_mean.CoE_unbias;                    
                        
                        this.tab_ModelCalibration.Table.Data{i,12} = ['<html><font color = "#808080">',num2str(evalCoE),'</font></html>'];
                        this.tab_ModelCalibration.Table.Data{i,14} = ['<html><font color = "#808080">',num2str(evalAIC),'</font></html>'];
                    else
                        evalCoE = '(NA)';
                        evalAIC = '(NA)';
                        
                        this.tab_ModelCalibration.Table.Data{i,12} = ['<html><font color = "#808080">',evalCoE,'</font></html>'];
                        this.tab_ModelCalibration.Table.Data{i,14} = ['<html><font color = "#808080">',evalAIC,'</font></html>'];
                    end
                    nModelsCalib = nModelsCalib +1;
                    
                catch ME
                    
                    warndlg( getReport(ME));
                    
                    nModelsCalibFailed = nModelsCalibFailed +1;
                    this.tab_ModelCalibration.Table.Data{i,10} = ['<html><font color = "#FF0000">Calib. failed - ', ME.message,'</font></html>'];
                end
                
                % Update status in GUI
                drawnow
                
            end
            
            % Change cursor to arrow
            set(this.Figure, 'pointer', 'arrow');
            drawnow
            
            % Report Summary
            msgbox(['The model was successfully calibrated for ',num2str(nModelsCalib), ' models and failed for ',num2str(nModelsCalibFailed), ' models.'], 'Summary of model calibration ...');

        end
        
        function onSimModels(this, hObject, eventdata)
           
            % Get table data
            data = this.tab_ModelSimulation.Table.Data;
            
            % Get list of selected bores.
            selectedBores = data(:,1);            
            if length(selectedBores)==0
                warndlg('No models selected for simulation.');
            end

            % Change cursor
            set(this.Figure, 'pointer', 'watch');
            drawnow            
            
            % Loop  through the list of selected bore and apply the model
            % options.
            nModelsSim = 0;
            nModelsSimFailed = 0;
            for i=1:length(selectedBores);                                
                
                % Check if the model is to be simulated.
                if isempty(selectedBores{i}) || ~selectedBores{i}
                    continue;
                end
                
                this.tab_ModelSimulation.Table.Data{i,end} = '<html><font color = "#FFA500">Simulating ... </font></html>';
                        
                % Update status in GUI
                drawnow
        
                % Get the selected model for simulation
                calibLabel = data{i,2};

                % Find index to the calibrated model label within the list of calibrated
                % models.
                model_label = cell(1,0);
                j=0;
                for ind=1:size(this.models,1)
                   if isfield(this.models{ind,1}.calibrationResults,'isCalibrated') && ...
                   this.models{ind,1}.calibrationResults.isCalibrated
                        j=j+1;
                        calibLabel_all{j,1} = this.models{ind,1}.model_label;
                   end
                end

                % Find index to the calibrated model label within the list of calibrated
                % models.                        
                ind = cellfun(@(x) strcmp(calibLabel, x), calibLabel_all);
                if all(~ind)
                   nModelsSimFailed = nModelsSimFailed +1;
                   this.tab_ModelSimulation.Table.Data{i,end} = ['<html><font color = "#FF0000">Sim. failed - Model could not be found. Please rebuild and calibrate it.</font></html>'];
                   continue;
                end                
                
                % Get the exact start and end dates of the obs head.
                obsHead = getObservedHead(this.models{ind});
                
                % Get the simulation options
                obsHeadStartDate = min(obsHead(:,1));
                obsHeadEndDate = max(obsHead(:,1));               
                simLabel = data{i,6};
                forcingdata_fname = data{i,7};      
                simTimeStep = data{i,10};
                
                % Check there is a simulation label.
                if isempty(simLabel)
                   nModelsSimFailed = nModelsSimFailed +1;
                   this.tab_ModelSimulation.Table.Data{i,end} = ['<html><font color = "#FF0000">Sim. failed - No simulation label.</font></html>'];
                   continue;
                end                      
                
                % Get the forcing data.
                if ~isempty(forcingdata_fname)

                    % Import forcing data
                    %-----------------------
                    % Check fname file exists.
                    if isdir(this.project_fileName)
                        forcingdata_fname = fullfile(this.project_fileName,forcingdata_fname);
                    else
                        forcingdata_fname = fullfile(fileparts(this.project_fileName),forcingdata_fname);
                    end
                    
                    if exist(forcingdata_fname,'file') ~= 2;                   
                        this.tab_ModelSimulation.Table.Data{i,end} = '<html><font color = "#FF0000">Sim. failed - The new forcing date file could not be open.</font></html>';
                        nModelsSimFailed = nModelsSimFailed +1;
                        continue;
                    end

                    % Read in the file.
                    try
                       forcingData= readtable(forcingdata_fname);
                    catch                   
                        this.tab_ModelSimulation.Table.Data{i,end} = '<html><font color = "#FF0000">Sim. failed - The new forcing date file could not be imported.</font></html>';
                        nModelsSimFailed = nModelsSimFailed +1;
                        continue;                        
                    end                    
                   
                    % Convert year, month, day to date vector
                    forcingData_data = table2array(forcingData);
                    forcingDates = datenum(forcingData_data(:,1), forcingData_data(:,2), forcingData_data(:,3));
                    forcingData_data = [forcingDates, forcingData_data(:,4:end)];
                    forcingData_colnames = forcingData.Properties.VariableNames(4:end);
                    forcingData_colnames = {'time', forcingData_colnames{:}};
                    forcingData = array2table(forcingData_data,'VariableNames',forcingData_colnames);
                    clear forcingData_data forcingDates
                else
                    % Set forcing used to empty. This will cause the
                    % calibration data to be used.
                    forcingData = [];
                end
                                    
               % Get the start and end dates for the simulation.                               
               if isempty(data{i,8})
                   simStartDate = obsHeadStartDate;
               else
                   simStartDate = datenum( data{i,8},'dd-mmm-yyyy'); 
               end
               if isempty( data{i,9})
                   simEndDate = obsHeadEndDate;
               else
                   simEndDate = datenum( data{i,9},'dd-mmm-yyyy') + datenum(0,0,0,23,59,59);                         
               end

               % Check the date timestep
               if isempty(simTimeStep) && (simStartDate <obsHeadStartDate || simEndDate > obsHeadEndDate)
                    this.tab_ModelSimulation.Table.Data{i,end} = '<html><font color = "#FF0000">Sim. failed - The time step must be specified when the simulation dates are outside of the observed head period.</font></html>';
                    nModelsSimFailed = nModelsSimFailed +1;
                    continue;                        
               end               
               
               % Create a vector of simulation time points 
               switch  simTimeStep
                   case 'Daily'
                       simTimePoints = [simStartDate:1:simEndDate]';
                   case 'Weekly'
                       simTimePoints = [simStartDate:7:simEndDate]';
                   case 'Monthly'
                       startYear = year(simStartDate);
                       startMonth= month(simStartDate);
                       startDay= day(simStartDate);
                       endYear = year(simEndDate);
                       endMonth = month(simEndDate);
                       endDay = day(simEndDate);
                       iyear = startYear;
                       imonth = startMonth;
                       iday = startDay;
                       j=1;
                       simTimePoints(j,1:3) = [iyear, imonth, iday];
                       while datenum(iyear,imonth,iday) < simEndDate
                          
                           if imonth == 12
                               imonth = 1;
                               iyear = iyear + 1;
                           else
                               imonth = imonth + 1;
                           end
                           j=j+1;
                           simTimePoints(j,1:3) = [iyear, imonth, iday];                           
                       end
                       if iyear ~= endYear && imonth ~= endMonth && iday ~= endDay
                           simTimePoints(i+1,1:3) = [endYear, endMonth, endDay];
                       end
                       
                       simTimePoints = datenum(simTimePoints);
                   case 'Yearly'
                       simTimePoints = [simStartDate:365:simEndDate]';
                   otherwise
                       % Get the observed head dates.
                       obsTimePoints = getObservedHead(this.models{ind});
                       obsTimePoints = obsTimePoints(:,1);
                       
                       % Filter observed head time points to between the
                       % simulation dates.
                       filt = obsTimePoints >= simStartDate & obsTimePoints<=simEndDate;
                       simTimePoints = obsTimePoints(filt);
                       
               end
               
               % Get the flag for kriging the residuals.
               doKrigingOfResiduals = false;
               if this.tab_ModelSimulation.Table.Data{i,end-1} && isempty(forcingData)
                    doKrigingOfResiduals = true;
               elseif this.tab_ModelSimulation.Table.Data{i,end-1} && ~isempty(forcingData)
                    this.tab_ModelSimulation.Table.Data{i,end} = '<html><font color = "#FF0000">Sim. failed - Kriging of residuals can only be undertaken if new forcing data is not input.</font></html>';
                    nModelsSimFailed = nModelsSimFailed +1;                    
                    continue;                        
               end                 
               
               % Undertake the simulation.
               try                   
                   
                   solveModel(this.models{ind}, simTimePoints, forcingData, simLabel, doKrigingOfResiduals);                   
                            
                   this.tab_ModelSimulation.Table.Data{i,end} = '<html><font color = "#008000">Simulated. </font></html>';
                   
                   nModelsSim = nModelsSim + 1;
                                      
               catch ME
                   nModelsSimFailed = nModelsSimFailed +1;
                   this.tab_ModelSimulation.Table.Data{i,end} = ['<html><font color = "#FF0000">Sim. failed - ', ME.message,'</font></html>']; '<html><font color = "#FF0000">Failed. </font></html>';                       
               end
                       
               
            end
            
            % Change cursor
            set(this.Figure, 'pointer', 'arrow');
            drawnow            
            
            % Report Summary
            msgbox(['The simulations were successfull for ',num2str(nModelsSim), ' models and failed for ',num2str(nModelsSimFailed), ' models.'], 'Summary of model simulaions...');

        end
        
        function onExport4HPC(this, hObject, eventdata)
           msgbox('This feature is not yet implemented.'); 
        end

        function onImportFromHPC(this, hObject, eventdata)
           msgbox('This feature is not yet implemented.'); 
        end
        
        
        function onImportTable(this, hObject, eventdata)
        
            
            % Create the label for each type of inport
            switch hObject.Tag
                case 'Data Preparation'
                    windowString = 'Select a .csv file containing the data for the data preparation table.';                                    
                case 'Model Construction'
                    windowString = 'Select a .csv file containing the data for the model construction.';                    
                case 'Model Calibration'
                    windowString = 'Select a .csv file containing the data for model calibration settings.';
                case 'Model Simulation'
                    windowString = 'Select a .csv file containing the data for the model simulation.';
                otherwise
                    warndlg('Unexpected Error: GUI table type unknown.');
                    return                    
            end

            % Show open file window
            [fName,pName] = uigetfile({'*.csv'},windowString); 
            if fName~=0;
                % Assign file name to date cell array
                filename = fullfile(pName,fName);
            else
                return;
            end         
            
            % Read in the table.
            try
                tbl = readtable(filename);
            catch ME
                warndlg('The table datafile could not be read in. Please check it is a CSV file with column headings in the first row.');
                return;
            end            

            % Check the table format and append to the required table
            switch hObject.Tag
                case 'Data Preparation'
                    if size(tbl,2) ~=17
                        warndlg('The table datafile must have 17 columns. That is, all columns shown in the model construction table.');
                        return;
                    end                    
                    
                    % Get column formats
                    colFormat = this.tab_DataPrep.Table.ColumnFormat;                    

                    % Convert table to cell array
                    tableAsCell = table2cell(tbl);                    
                    
                    % Loop through each row in tbl, check the data and add
                    % the user data to the columns of the row.
                    nRowsNotImported= 0;
                    nImportedRows = 0;
                    for i=1: size(tbl,1)
                        
                        try                                      

                            % Convert any columns of string data to '' if read
                            % in as NaN.
                            for j=1:length(colFormat)                       
                                if ischar(colFormat{j}) && strcmp(colFormat{j},'char') && ...
                                isnumeric( tableAsCell{i,j} ) && isnan( tableAsCell{i,j} )
                                    tableAsCell{i,j} = '';
                                elseif iscell(colFormat{j}) && ~ischar(tableAsCell{i,j}) && isnan( tableAsCell{i,j} )
                                    tableAsCell{i,j} = '';
                                end
                            end

                            % Add results text.
                            tableAsCell{i,15} = '<html><font color = "#FF0000">Bore not analysed.</font></html>'; 
                            tableAsCell{i,16} = ['<html><font color = "#808080">','(NA)','</font></html>'];
                            tableAsCell{i,17} = ['<html><font color = "#808080">','(NA)','</font></html>'];
                            
                            % Convert integer 0/1 to logicals
                            for j=find(strcmp(colFormat,'logical'))
                               if tableAsCell{i,j}==1;
                                   tableAsCell{i,j} = true;
                               else
                                   tableAsCell{i,j} = false;
                               end                                       
                            end
                            
                            % Append data
                            this.tab_DataPrep.Table.Data = [this.tab_DataPrep.Table.Data; tableAsCell];
                            
                            nImportedRows = nImportedRows + 1;
                        catch ME
                            nRowsNotImported = nRowsNotImported + 1;
                        end
                        
                    end
                    

                    % Update row numbers.
                    nrows = size(this.tab_DataPrep.Table.Data,1);
                    this.tab_DataPrep.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                           
                    
                    % Output Summary.
                    msgbox({['Data preparation table data was imported to ',num2str(nImportedRows), ' rows.'], ...
                            '', ...
                            ['Number of rows not imported because of data format errors: ',num2str(nRowsNotImported) ]}, 'Summary of data preparation table importing ...');
                    
                    
                case 'Model Construction'
                    if size(tbl,2) ~=9
                        warndlg('The table datafile must have 9 columns. That is, all columns shown in the model construction table.');
                        return;
                    end
                        
                    % Loop through each row in tbl and find the
                    % corresponding model within the GUI table and the add
                    % the user data to the columns of the row.
                    nModelsNotUnique = 0;
                    nImportedRows = 0;
                    for i=1: size(tbl,1)

                        % Get model label
                        modelLabel_src = tbl{i,2};

                        % Check if model label is unique.
                        ind = find(strcmp(this.tab_ModelConstruction.Table.Data(:,2), modelLabel_src));                        

                        % Check if the model is found
                        if ~isempty(ind)
                            nModelsNotUnique = nModelsNotUnique + 1;
                            continue;
                        end

                        % Append table. Note: the select column is input as a logical 
                        tbl{i,end} = {'<html><font color = "#FF0000">Model not built.</font></html>'}; 
                        if tbl{i,1}==1
                            this.tab_ModelConstruction.Table.Data = [this.tab_ModelConstruction.Table.Data; true, table2cell(tbl(i,2:end))];
                        else
                            this.tab_ModelConstruction.Table.Data = [this.tab_ModelConstruction.Table.Data; false, table2cell(tbl(i,2:end))];
                        end
                        nImportedRows = nImportedRows + 1;
                    end

                    % Update row numbers.
                    nrows = size(this.tab_ModelConstruction.Table.Data,1);
                    this.tab_ModelConstruction.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                        

                    % Output Summary.
                    msgbox({['Construction data was imported to ',num2str(nImportedRows), ' rows.'], ...
                            '', ...
                            ['Number of rows not imported because the model label is not unique: ',num2str(nModelsNotUnique) ]}, 'Summary of model calibration importing ...');

                    
                case 'Model Calibration'
                    
                    if size(tbl,2) ~=13
                        warndlg('The table datafile must have 13 columns. That is, all columns shown in the table.');
                        return;
                    end

                    
                    % Loop through each row in tbl and find the
                    % corresponding model within the GUI table and the add
                    % the user data to the columns of the row.
                    nModelsNotFound = 0;
                    nBoresNotMatching = 0;
                    nCalibBoresDeleted = 0;
                    nImportedRows = 0;
                    for i=1: size(tbl,1)
                                               
                        % Get model lablel and bore ID
                        modelLabel_src = tbl{i,2};
                        boreID_src = tbl{i,3};
                        
                        % Find model within the table.
                        modelLabel_dest = GST_GUI.removeHTMLTags(this.tab_ModelCalibration.Table.Data(:,2));
                        ind = find(strcmp(modelLabel_dest, modelLabel_src));                        
                        
                        % Check if the model is found
                        if isempty(ind)
                            nModelsNotFound = nModelsNotFound + 1;
                            continue;
                        end
                        
                        % Check the bore IDs are equal.
                        boreID_dest = GST_GUI.removeHTMLTags(this.tab_ModelCalibration.Table.Data{ind,3});
                        if ~strcmp(boreID_dest, boreID_src)
                            nBoresNotMatching = nBoresNotMatching + 1;
                            continue;                            
                        end
                        
                        % Record if the model is already built. To do this,
                        % the model is first locasted with this.models{}
                        if ~isempty(this.models)
                            indModel = false(size(this.models));
                            for j=1: length(this.models)   
                                try
                                    if strcmp(modelLabel_src, this.models{j}.model_label) &&  this.models{j,1}.calibrationResults.isCalibrated 
                                        indModel(j,1)= true;
                                    end
                                catch
                                    % do nothing
                                end
                            end
                            indModel = find(indModel);
                            
                            if ~isempty(indModel)                            
                                % remove calibration results.
                                this.models{indModel,1}.calibrationResults = [];

                                % Record that the calib results were overwritten
                                nCalibBoresDeleted = nCalibBoresDeleted + 1;
                            end
                        end                     
                        
                        % Add data from columns 1,5-7.
                        if tbl{i,1}==1
                            this.tab_ModelCalibration.Table.Data{ind,1} = true;
                        else
                            this.tab_ModelCalibration.Table.Data{ind,1} = false;
                        end
                        this.tab_ModelCalibration.Table.Data{ind,6} = tbl{i,6}{1};
                        this.tab_ModelCalibration.Table.Data{ind,7} = tbl{i,7}{1};
                        this.tab_ModelCalibration.Table.Data{ind,8} = tbl{i,8};
                        
                        % Input the calibration status.
                        this.tab_ModelCalibration.Table.Data{ind,9} = '<html><font color = "#FF0000">Not calibrated.</font></html>';
                        this.tab_ModelCalibration.Table.Data{ind,10} = [];
                        this.tab_ModelCalibration.Table.Data{ind,11} = [];
                        this.tab_ModelCalibration.Table.Data{ind,12} = [];
                        this.tab_ModelCalibration.Table.Data{ind,13} = [];
                        
                        nImportedRows = nImportedRows +1;
                    end

                    % Update row numbers.
                    nrows = size(this.tab_ModelCalibration.Table.Data,1);
                    this.tab_ModelCalibration.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                            
                                            
                    
                    % Output Summary.
                    msgbox({['Calibration data was imported to ',num2str(nImportedRows), ' rows.'], ...
                            ['   Number of model labels not found in the calibration table: ',num2str(nModelsNotFound) ], ...
                            ['   Number of rows were the bore IDs did not match: ',num2str(nBoresNotMatching) ], ...
                            ['   Number of rows were existing calibration results were deleted: ',num2str(nCalibBoresDeleted) ]}, 'Summary of model calibration importing ...');
                    
                case 'Model Simulation'
                    
                    % Check the number of columns
                    if size(tbl,2) ~=12
                        warndlg('The table datafile must have 12 columns. That is, all columns shown in the table.');
                        return;
                    end
                    
                    % Get column formats
                    colFormat = this.tab_ModelSimulation.Table.ColumnFormat;

                    % Convert table to cell array
                    tableAsCell = table2cell(tbl);                    
                    
                    % Loop through each row in tbl and find the
                    % corresponding model within the GUI table and the add
                    % the user data to the columns of the row.
                    nSimLabelsNotUnique = 0;
                    nImportedRows = 0;
                    for i=1: size(tbl,1)
                                               
                        % Get model lablel and bore ID
                        modelLabel_src = tbl{i,2};
                        simLabel_src = tbl{i,6};
                        
                        % Check that the model ID and simulation label are
                        % unique
                        modelLabel_dest = GST_GUI.removeHTMLTags(this.tab_ModelCalibration.Table.Data(:,2));
                        simLabel_dest = GST_GUI.removeHTMLTags(this.tab_ModelCalibration.Table.Data(:,6));
                        ind = find(strcmp(modelLabel_dest, modelLabel_src) & strcmp(simLabel_dest, simLabel_src));
                        
                        % Skip if the model and label are not unique
                        if ~isempty(ind)
                            nSimLabelsNotUnique = nSimLabelsNotUnique + 1;
                            continue;                        
                        end

                        
                        % Convert any columns of string data to '' if read
                        % in as NaN.
                        for j=1:length(colFormat)                       
                            if ischar(colFormat{j}) && strcmp(colFormat{j},'char')&& ...
                            isnumeric( tableAsCell{i,j} ) && isnan( tableAsCell{i,j} )
                                tableAsCell{i,j} = '';
                            elseif iscell(colFormat{j}) && ~ischar(tableAsCell{i,j}) && isnan( tableAsCell{i,j} )
                                tableAsCell{i,j} = '';
                            end
                        end
                        
                        % Append table. Note: the select column is input as a logical 
                        tbl{i,end} = {'<html><font color = "#FF0000">Not simulated.</font></html>'};   
                        if size(this.tab_ModelSimulation.Table.Data,1)==0
                            if tbl{i,1}==1
                                this.tab_ModelSimulation.Table.Data = [true, tableAsCell(i,2:end)];
                            else
                                this.tab_ModelSimulation.Table.Data = [false, tableAsCell(i,2:end)];
                            end                            
                        else                            
                            if tbl{i,1}==1
                                this.tab_ModelSimulation.Table.Data = [this.tab_ModelSimulation.Table.Data; true, tableAsCell(i,2:end)];
                            else
                                this.tab_ModelSimulation.Table.Data = [this.tab_ModelSimulation.Table.Data; false, tableAsCell(i,2:end)];
                            end
                        end
                        nImportedRows = nImportedRows + 1;
                    end

                    % Update row numbers.
                    nrows = size(this.tab_ModelSimulation.Table.Data,1);
                    this.tab_ModelSimulation.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                            
                                  
                    
                    % Output Summary.
                    msgbox({['Simulation data was imported to ',num2str(nImportedRows), ' rows.'], ...
                            '', ...
                            ['Number of rows not imported because the model label is not unique: ',num2str(nModelsNotUnique) ]}, ...
                            'Summary of model calibration importing ...');
                                   
            end
        end
        
        function onExportTable(this, hObject, eventdata)
            % Create the label for each type of inport
            switch hObject.Tag
                case 'Data Preparation'
                    windowString = 'Input the .csv file name for exporting the data preparation table.';
                    tbl = this.tab_DataPrep.Table.Data;
                    colnames = this.tab_DataPrep.Table.ColumnName;
                    colFormat = this.tab_DataPrep.Table.ColumnFormat;
                    
                case 'Model Construction'
                    windowString = 'Input the .csv file name for exporting the model construction table.';
                    tbl = this.tab_ModelConstruction.Table.Data;
                    colnames = this.tab_ModelConstruction.Table.ColumnName;
                    colFormat = this.tab_ModelConstruction.Table.ColumnFormat;
                case 'Model Calibration'
                    windowString = 'Input the .csv file name for exporting the model calibration table.';
                    tbl = this.tab_ModelCalibration.Table.Data;
                    colnames = this.tab_ModelCalibration.Table.ColumnName;
                    colFormat = this.tab_ModelCalibration.Table.ColumnFormat;
                case 'Model Simulation'
                    windowString = 'Input the .csv file name for exporting the model simulation table.';
                    tbl = this.tab_ModelSimulation.Table.Data;
                    colnames = this.tab_ModelSimulation.Table.ColumnName;
                    colFormat = this.tab_ModelSimulation.Table.ColumnFormat;
                otherwise
                    warndlg('Unexpected Error: GUI table type unknown.');
                    return                    
            end

            % Show open file window
            [fName,pName] = uiputfile({'*.csv'},windowString); 
            if fName~=0;
                % Assign file name to date cell array
                filename = fullfile(pName,fName);
            else
                return;
            end         
            
            % Remove HTML tags from the column names
            colnames = GST_GUI.removeHTMLTags(colnames);
            
            % Replace spaces within column names with "_"
            colnames = strrep(colnames,' ','_');
            colnames = strrep(colnames,'.','');
            colnames = strrep(colnames,'?','');
            colnames = strrep(colnames,'(','');
            colnames = strrep(colnames,')','');
            colnames = strrep(colnames,'/','_');
            colnames = strrep(colnames,'-','_');
            colnames = strrep(colnames,'__','_');
            
            %If the model constuction table, then remove possible ',' from
            %the bore ID and model options columns.
            if strcmp(hObject.Tag,'Model Construction')
                tbl(:,6) = strrep(tbl(:,6),',',' ');
                tbl(:,8) = strrep(tbl(:,8),',',' ');   
            end
            
            % Remove HTML tags from each row
            for i=find(strcmp(colFormat, 'char'))
                tbl(:,i) = GST_GUI.removeHTMLTags(tbl(:,i));
            end           
            
            % Convert cell array to table            
            tbl = cell2table(tbl);
            tbl.Properties.VariableNames = colnames;
            
            % Write the table.
            try
                writetable(tbl, filename);
            catch ME
                warndlg('The table could not be written. Please check you have write permissions to the destination folder.');
                return;
            end            
        end        
        
        function onExportResults(this, hObject, eventdata)
            
            % Set initial folder to the project folder (if set)
            if ~isempty(this.project_fileName)                                
                try    
                    if isdir(this.project_fileName)
                        currentProjectFolder = this.project_fileName;
                    else
                        currentProjectFolder = fileparts(this.project_fileName);
                    end 

                    currentProjectFolder = [currentProjectFolder,filesep];
                    cd(currentProjectFolder);
                catch
                    % do nothing
                end
            end      

            % Export results
            switch hObject.Tag                                           
                case 'Data Preparation'

                    % Check there is data to export.
                    if isempty(this.dataPrep) || size(this.dataPrep,1)<1;
                        warndlg('There is no data analysis results to export.','No data.');
                        return;
                    end
                                            
                    % Ask the user if they want to export all analysis data
                    % (ie logical data reporting on the analysis
                    % undertaken) or just the data not assessed an errerous
                    % or an outlier.
                    response = questdlg('Do you want to export the analysis results or just the observations not assessed as being erroneous or outliers?','Data to export?','Export Analysis Results','Export non-erroneous obs.','Cancel','Export non-erroneous obs.');
                    
                    if strcmp(response,'Cancel')
                        return;
                    end
                    
                    if strcmp(response, 'Export Analysis Results')
                        exportAllData = true;
                    else
                        exportAllData = false;
                    end
                    
                    % Get output file name
                    [fName,pName] = uiputfile({'*.csv'},'Input the .csv file name for results file.'); 
                    if fName~=0;
                        % Assign file name to date cell array
                        filename = fullfile(pName,fName);
                    else
                        return;
                    end                     
                    
                    % Open file and write headers
                    fileID = fopen(filename,'w');
                    if exportAllData
                        fprintf(fileID,'BoreID,Year,Month,Day,Hour,Minute,Head,Date_Error,Duplicate_Date_Error,Min_Head_Error,Max_Head_Error,Rate_of_Change_Error,Const_Hear_Error,Outlier_Obs \n');
                    else
                        fprintf(fileID,'BoreID,Year,Month,Day,Hour,Minute,Obs_Head \n');                    
                    end                    
                    
                    % Get a list of bore IDs
                    boreIDs = fieldnames(this.dataPrep);
                    
                    % Export each bore analysed.
                    nResultsWritten = 0;
                    nResultsNotWritten = 0;
                    for i = 1:size(boreIDs,1)
                       
                        % Get the analysis results.
                        tableData = this.dataPrep.(boreIDs{i});

                        % Check there is some data
                        if isempty(tableData) || size(tableData,1)==0
                            nResultsNotWritten = nResultsNotWritten +1;
                            continue;                                
                        end

                        % Convert to matrix.
                        tableData = table2array(tableData);

                        % Export data
                        try
                            if exportAllData                                                   
    
                                %Write each row.
                                for j=1:size(tableData,1)
                                    fprintf(fileID,'%s,%i,%i,%i,%i,%i,%12.3f,%i,%i,%i,%i,%i,%i,%i \n', boreIDs{i} , tableData(j,:));                                    
                                end
                            
                                nResultsWritten = nResultsWritten + 1;
                            else

                                isError = any(tableData(:,7:end)==1,2);
                                if size(tableData,1) > sum(isError)
    
                                    % Filter data
                                    tableData = tableData(~isError,:);
                                                                        
                                    %Write each row.
                                    for j=1:size(tableData,1)
                                        fprintf(fileID,'%s,%i,%i,%i,%i,%i,%12.3f \n', boreIDs{i} , tableData(j,1:6));
                                    end
                                
                                    nResultsWritten = nResultsWritten + 1;
                                else
                                    nResultsNotWritten = nResultsNotWritten +1;
                                end
                            end
                        catch
                            nResultsNotWritten = nResultsNotWritten +1;
                        end
                    end
                    fclose(fileID);
                    
                    % Show summary
                    msgbox({'Export of results finished.','', ...
                           ['Number of bore results exported =',num2str(nResultsWritten)], ...
                           ['Number of bore results not exported =',num2str(nResultsNotWritten)]}, ...
                           'Export Summary');

                    
                case 'Model Calibration'
                    
                    % Get output file name
                    [fName,pName] = uiputfile({'*.csv'},'Input the .csv file name for results file.'); 
                    if fName~=0;
                        % Assign file name to date cell array
                        filename = fullfile(pName,fName);
                    else
                        return;
                    end 
                    
                    % Open file and write headers
                    fileID = fopen(filename,'w');
                    fprintf(fileID,'Model_Label,BoreID,Year,Month,Day,Hour,Minute,Obs_Head,Is_Calib_Point?,Calib_Head,Eval_Head,Model_Err,Noise_Lower,Noise_Upper \n');
                    
                    % Loop through each row of the calibration table and
                    % export the calibration results (if calibrated)
                    nrows = size(this.tab_ModelConstruction.Table.Data,1);
                    nResultsWritten=0;
                    for i=1:nrows
                       
                        % get model label.
                        modelLabel = this.tab_ModelConstruction.Table.Data{i,2};
                        boreID = this.tab_ModelConstruction.Table.Data{i,6};
                        
                        % Find object for the model.
                        modelInd = cellfun( @(x) strcmp(x.model_label,modelLabel), this.models);
                        if ~isempty(modelInd) && ...
                        ~isempty(this.models{modelInd}.calibrationResults) && ...
                        this.models{modelInd}.calibrationResults.isCalibrated                        
                                                   
                            % Get the model calibration data.
                            tableData = this.models{modelInd,1}.calibrationResults.data.obsHead;
                            tableData = [tableData, ones(size(tableData,1),1), this.models{modelInd,1}.calibrationResults.data.modelledHead(:,2), ...
                                nan(size(tableData,1),1), this.models{modelInd,1}.calibrationResults.data.modelledHead_residuals(:,end), ...
                                this.models{modelInd,1}.calibrationResults.data.modelledNoiseBounds(:,end-1:end)];

                            % Get evaluation data
                            if isfield(this.models{modelInd,1}.evaluationResults,'data')
                                % Get data
                                evalData = this.models{modelInd,1}.evaluationResults.data.obsHead;
                                evalData = [evalData, zeros(size(evalData,1),1), nan(size(evalData,1),1), this.models{modelInd,1}.evaluationResults.data.modelledHead(:,2), ...
                                    this.models{modelInd,1}.evaluationResults.data.modelledHead_residuals(:,end), ...
                                    this.models{modelInd,1}.evaluationResults.data.modelledNoiseBounds(:,end-1:end)];

                                % Append to table of calibration data and sort
                                % by time.
                                tableData = [tableData; evalData];
                                tableData = sortrows(tableData, 1);
                            end

                            % Calculate year, month, day etc
                            tableData = [year(tableData(:,1)), month(tableData(:,1)), day(tableData(:,1)), hour(tableData(:,1)), minute(tableData(:,1)), tableData(:,2:end)];                    
                   
                            % Build write format string
                            fmt = '%s,%s,%i,%i,%i,%i,%i,%12.3f';
                            for j=1:size(tableData,2)-6
                               fmt = strcat(fmt,',%12.3f'); 
                            end
                            fmt = strcat(fmt,'  \n'); 
                            
                            %Write each row.
                            for j=1:size(tableData,1)
                                fprintf(fileID,fmt, modelLabel, boreID, tableData(j,:));
                            end
                            
                            % write data to the file
                            %dlmwrite(filename,tableData,'-append');          
                            nResultsWritten = nResultsWritten + 1;
                            
                        end        
                    end
                    fclose(fileID);
                    
                    % Show summary
                    msgbox({'Export of results finished.','',['Number of model results exported =',num2str(nResultsWritten)]},'Export Summary');
                    
                    
                case 'Model Simulation'
                    % Get output file name
                    folderName = uigetdir('' ,'Select where the .csv simulation files saved (one file per simulation).');    
                    if isempty(folderName)
                        return;
                    end
                    
                    % Loop through each row of the simulation table and
                    % export the calibration results (if calibrated)
                    nrows = size(this.tab_ModelSimulation.Table.Data,1);
                    nResultsWritten=0;
                    nModelsNotFound=0;
                    nSimsNotUndertaken = 0;
                    nSimsNotUnique = 0;
                    nTableConstFailed = 0;
                    nWritteError = 0;
                    for i=1:nrows
                        
                        % get model label and simulation label.
                        modelLabel = this.tab_ModelSimulation.Table.Data{i,2};
                        simLabel = this.tab_ModelSimulation.Table.Data{i,6};
                        
                        % Find object for the model.
                        ind = cellfun( @(x) strcmp(x.model_label,modelLabel), this.models);
                        if isempty(ind) || isempty(this.models{ind}.simulationResults)                       
                            nModelsNotFound = nModelsNotFound +1;
                            continue;
                        end
                        
                        % Check if any simulations have been undertaken.
                        if isempty(this.models{ind,1}.simulationResults)
                            nSimsNotUndertaken = nSimsNotUndertaken +1;
                            continue;
                        end
                        
                        % Find the simulation.    
                        if isempty(simLabel)
                            nSimsNotUndertaken = nSimsNotUndertaken +1;
                            continue;
                        end
                        simInd = cellfun(@(x) strcmp(simLabel, x.simulationLabel), this.models{ind,1}.simulationResults);
                        if all(~simInd)    % Exit if model not found.
                            nSimsNotUndertaken = nSimsNotUndertaken +1;
                            continue;
                        end          
                        simInd = find(simInd);
            
                        % Check only one simulation found
                        if length(simInd)>1
                            nSimsNotUnique = nSimsNotUnique +1;
                            continue;
                        end
                        

                        % Get the simulation data and create the output
                        % table.
                        try
                            % Get the model simulation data.
                            tableData = this.models{ind,1}.simulationResults{simInd,1}.head;                        
                            
                            % Calculate year, month, day etc
                            tableData = [year(tableData(:,1)), month(tableData(:,1)), day(tableData(:,1)), hour(tableData(:,1)), minute(tableData(:,1)), tableData(:,2:end)];

                            % Create column names.                        
                            columnName = {'Year','Month','Day','Hour','Minute',this.models{ind,1}.simulationResults{simInd,1}.colnames{2:end}};

                            % Create table and add variable names
                            tableData = array2table(tableData);
                            tableData.Properties.VariableNames = columnName;
                        catch
                            nTableConstFailed = nTableConstFailed + 1;
                        end
                        
                        % Create file name
                        filename_tmp = fullfile(folderName,[modelLabel,'_',simLabel,'.csv']);
                                                
                        % write data to the file
                        try
                            writetable(tableData,filename_tmp);          
                            nResultsWritten = nResultsWritten + 1;
                        catch
                            nWritteError = nWritteError + 1;
                        end
                                                    
                    end
                    
                    % Show summary
                    nResultsWritten=0;
                    nModelsNotFound=0;
                    nSimsNotUndertaken = 0;
                    nSimsNotUnique = 0;
                    nTableConstFailed = 0;
                    nWritteError = 0;                    
                    msgbox({'Export of results finished.','', ...
                           ['Number of simulations exported =',num2str(nResultsWritten)], ...
                           ['Number of models not found =',num2str(nModelsNotFound)], ...
                           ['Number of simulations not undertaken =',num2str(nSimsNotUndertaken)], ...
                           ['Number of simulations labels not unique =',num2str(nSimsNotUnique)], ...
                           ['Number of simulations where the construction of results table failed=',num2str(nTableConstFailed)], ...
                           ['Number of simulations where the file could not be written =',num2str(nWritteError)]}, ...
                           'Export Summary');                    

                    
                    
                otherwise
                    warndlg('Unexpected Error: GUI table type unknown.');
                    return                    
            end
            
            
        end
        
        function onDocumentation(this, hObject, eventdata)
           if strcmp(hObject.Tag,'Algorithms') 
                doc GroundwaterStatisticsToolbox
           else
               web([hObject.Tag,'.html']);
           end
        end       
               
        function onGitHub(this, hObject, eventdata)
           if strcmp(hObject.Tag,'doc_GitHubUpdate') 
               web('https://github.com/peterson-tim-j/Groundwater-Statistics-Toolbox/releases');
           elseif strcmp(hObject.Tag,'doc_GitHubIssue') 
               web('https://github.com/peterson-tim-j/Groundwater-Statistics-Toolbox/issues');
           end            
                       
        end
        
        function onLicenseDisclaimer(this, hObject, eventdata)
           web('doc_License_Disclaimer.html');
        end               
        
        
        % Show splash 
        function onAbout(this, hObject, eventdata)
             % Create opening window while the GUI is being built.
            %--------------------------------------------------------------
            % Create figure
            this.FigureSplash = figure( ...
                'NumberTitle', 'off', ...
                'MenuBar', 'none', ...
                'Toolbar', 'none', ...
                'HandleVisibility', 'off', ...
                'Visible','off', ...
                'WindowStyle', 'modal');

            % Get window size and set figure to middle
            splashWidth =  1200;
            splashHeight = splashWidth/3;
            windowHeight = this.FigureSplash.Parent.ScreenSize(4);
            windowWidth = this.FigureSplash.Parent.ScreenSize(3);
            this.FigureSplash.Position = [(windowWidth - splashWidth)/2 (windowHeight - splashHeight)/2 splashWidth splashHeight];
            this.FigureSplash.Visible = 'on';
            
            % Load icons
            h = axes('Parent',this.FigureSplash, 'Position', [0 0 1 1] );
            img = imread(fullfile('icons','splash.png'));
            image(img,'Parent',h);
            axis(h,'off');
            axis(h,'image');  
            axis(h,'tight');
             
        end        
        
        % Load example models
        function onExamples(this, hObject, eventdata)
            
            % Check if all of the GUI tables are empty. If not, warn the
            % user the opening the example will delete the existing data.
            if ~isempty(this.tab_Project.project_name.String) || ...
            ~isempty(this.tab_Project.project_description.String) || ...
            (size(this.tab_ModelCalibration.Table.Data,1)~=0 && any(~any(cellfun( @(x) isempty(x), this.tab_ModelConstruction.Table.Data(:,1:8))))) || ...
            (size(this.tab_ModelCalibration.Table.Data,1)~=0 && any(~any(cellfun( @(x) isempty(x), this.tab_ModelCalibration.Table.Data)))) || ...
            (size(this.tab_ModelSimulation.Table.Data,1)~=0 && any(~any(cellfun( @(x) isempty(x), this.tab_ModelSimulation.Table.Data))))
                response = questdlg({'Opening an example project will overwrite the existing project.','','Do you want to continue?'}, ...
                 'Overwrite the existing project?','Yes','No','No');
             
                if strcmp(response,'No')
                    return;
                end
            end
            
            % Ask user the locations where the input data is to be saved.          
            if ~isempty(this.project_fileName)
                folderName = fileparts(this.project_fileName);
            else
                folderName = fileparts(pwd); 
            end
            folderName = uigetdir(folderName ,'Select folder for example .csv files.');    
            if isempty(folderName)
                return;
            end
            this.project_fileName = folderName;
            
            % Change cursor
            set(this.Figure, 'pointer', 'watch');      
            drawnow;
            
            % Build .csv file names and add to the GUI construction table.
            display('Saving .csv files ...');
            forcingFileName = fullfile(folderName,'forcing.csv');
            coordsFileName = fullfile(folderName,'coordinates.csv');
            headFileName = fullfile(folderName,'obsHead.csv');
                        
            % Open example .mat data file for the required example.
            display('Opening data files ...');
            switch eventdata.Source.Tag
                case 'TFN - LUC'
                    exampleData = load('BourkesFlat_data.mat');
                case 'TFN - Pumping'
                    exampleData = load('Clydebank_data.mat');
                otherwise
                    set(this.Figure, 'pointer', 'arrow');   
                    drawnow;
                    warndlg('The requested example model could not be found.','Example Model Error ...');
                    return;
            end
            
            % Check there is the required data
            if ~isfield(exampleData,'forcing') || ~isfield(exampleData,'coordinates') || ~isfield(exampleData,'obsHead')
                set(this.Figure, 'pointer', 'arrow');   
                drawnow;
                warndlg('The example data for the model does not exist. It must contain the following Matlab tables: forcing, coordinates, obsHead.','Example Model Data Error ...');                
                return;                
            end
            
            % Check that the data is a table. 
            if ~istable(exampleData.forcing) || ~istable(exampleData.coordinates) || ~istable(exampleData.obsHead) 
                set(this.Figure, 'pointer', 'arrow');   
                drawnow;
                warndlg('The example models could not be loaded because the source data is not of the correct format. It must be a Matlab table variable.','Example Model Error ...');                
                return;
            end
            
            % Export the csv file names.
            display('Saving .csv files ...');
            writetable(exampleData.forcing,forcingFileName);
            writetable(exampleData.coordinates,coordsFileName);
            writetable(exampleData.obsHead,headFileName);
            
            
            % Load the GUI table data and model.
            display('Opening model files ...');
            try                
                switch eventdata.Source.Tag
                    case 'TFN - LUC'                    
                        exampleModel = load('BourkesFlat_model.mat');
                    case 'TFN - Pumping'
                        exampleModel = load('Clydebank_model.mat');
                    otherwise
                        set(this.Figure, 'pointer', 'arrow');             
                        drawnow;
                        warndlg('The requested example model could not be found.','Example Model Error ...');
                        return;
                end            
                
            catch ME
                set(this.Figure, 'pointer', 'arrow');
                drawnow;
                warndlg('Project file could not be loaded.','File error');                
                return;
            end
            
            
            % Assign data to the GUI
            %------------------------------          
            display('Updating file names in GUI ...');
            % Assign loaded data to the tables and models.
            this.tab_Project.project_name.String = exampleModel.tableData.tab_Project.title;
            this.tab_Project.project_description.String = exampleModel.tableData.tab_Project.description;

            % Data prep data.
            this.tab_DataPrep.Table.Data = exampleModel.tableData.tab_DataPrep;
            nrows = size(this.tab_DataPrep.Table.Data,1);
            this.tab_DataPrep.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                    

            % Model constrcuion data
            this.tab_ModelConstruction.Table.Data = exampleModel.tableData.tab_ModelConstruction;
            nrows = size(this.tab_ModelConstruction.Table.Data,1);
            this.tab_ModelConstruction.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));     

            % Model Calib data
            this.tab_ModelCalibration.Table.Data = exampleModel.tableData.tab_ModelCalibration;
            nrows = size(this.tab_ModelCalibration.Table.Data,1);
            this.tab_ModelCalibration.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                      

            % Model Simulation
            this.tab_ModelSimulation.Table.Data = exampleModel.tableData.tab_ModelSimulation;
            nrows = size(this.tab_ModelSimulation.Table.Data,1);
            this.tab_ModelSimulation.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                       

            % Assign built models.
            this.models = exampleModel.models;

            % Assign analysed bores.
            this.dataPrep = exampleModel.dataPrep;            
        
            % Updating project location with title bar
            set(this.Figure,'Name',['The Groundwater Statistical Toolbox - ', this.project_fileName]);
            drawnow;                

            
            % Change pointer
            set(this.Figure, 'pointer', 'arrow');  
            drawnow;
            
        end
        
        
        function rowAddDelete(this, hObject, eventdata)
           
            % Get the table object from UserData
            tableObj = eval(eventdata.Source.Parent.UserData);            
            
            % Get selected rows
            selectedRows = cell2mat(tableObj.Data(:,1));

            % Check if any rows are selected. Note, if not then
            % rows will be added (for all but the calibration
            % table).
            anySelected = any(selectedRows);
            indSelected = find(selectedRows)';
            
            if size(tableObj.Data(:,1),1)>0 &&  ~anySelected && ~strcmp(hObject.Label,'Paste rows')
                warndlg('No rows are selected for the requested operation.');
                return;
            elseif size(tableObj.Data(:,1),1)==0 ...
            &&  (strcmp(hObject.Label, 'Copy selected row') || strcmp(hObject.Label, 'Delete selected rows'))                
                return;
            end               
            
            % Define the input for the status column and default data for
            % inserting new rows.
            defaultData = cell(1,size(tableObj.Data,2));
            switch tableObj.Tag
                case 'Data Preparation'
                    modelStatus = '<html><font color = "#FF0000">Bore not analysed.</font></html>';
                    modelStatus_col = 15;
                    defaultData = {false, '', '',0, 0, 0, '01/01/1900',true, true, true, true, 10, 120, 3,modelStatus, ...
                    '<html><font color = "#808080">','(NA)','</font></html>', ...
                    '<html><font color = "#808080">','(NA)','</font></html>'};
                case 'Model Construction'
                    modelStatus = '<html><font color = "#FF0000">Model not built.</font></html>';
                    modelStatus_col = 9;
                case 'Model Calibration'
                    modelStatus = '<html><font color = "#FF0000">Model not calibrated.</font></html>';
                    modelStatus_col = 9;
                case 'Model Simulation'
                    modelStatus = '<html><font color = "#FF0000">Not simulated.</font></html>';                    
                    modelStatus_col = 12;
            end
            
            % Do the selected action            
            switch hObject.Label
                case 'Copy selected row'
                    this.copiedData.tableName = tableObj.Tag;
                    this.copiedData.data = tableObj.Data(selectedRows,:);
                    
                case 'Paste rows'    
                    % Check that name of the table is same as that from the
                    % copied data. 
                    if ~strcmp(this.copiedData.tableName, tableObj.Tag)
                        warndlg('The copied row data was sourced from a different table.');
                        return;
                    end    
                    
                    % Paste data and update model build status
                    switch this.copiedData.tableName
                        case 'Data Preparation'
                            if anySelected
                                j=1;
                                for i=indSelected
                                    
                                    % Paste data
                                    tableObj.Data{i,2} = this.copiedData.data{1,2};
                                    tableObj.Data{i,3} = this.copiedData.data{1,3};
                                    tableObj.Data{i,4} = this.copiedData.data{1,4};
                                    tableObj.Data{i,5} = this.copiedData.data{1,5};
                                    tableObj.Data{i,6} = this.copiedData.data{1,6};
                                    tableObj.Data{i,7} = this.copiedData.data{1,7};
                                    tableObj.Data{i,8} = this.copiedData.data{1,8};
                                    this.copiedData.data{i,modelStatus_col} = modelStatus;
                                    j=j+1;
                                end
                            else
                                for i=1: size(this.copiedData.data,1)
                                   
                                    % Add a row
                                    tableObj.Data = [tableObj.Data; this.copiedData.data(i,:)];
                                
                                    % Add data to the new row.
                                    tableObj.Data{irow,modelStatus_col} = modelStatus;                                    
                                end
                                % Update row numbers.
                                nrows = size(tableObj.Data,1);
                                tableObj.RowName = mat2cell([1:nrows]',ones(1, nrows));                                
                            end                        
                        case 'Model Construction'
                            if anySelected
                                j=1;
                                for i=indSelected
                                    
                                    % Get a unique model label. 
                                    newModelLabel = GST_GUI.createUniqueLabel(tableObj.Data(:,2), this.copiedData.data{1,2}, i);
                                    
                                    % Paste data
                                    tableObj.Data{i,2} = newModelLabel;
                                    tableObj.Data{i,3} = this.copiedData.data{1,3};
                                    tableObj.Data{i,4} = this.copiedData.data{1,4};
                                    tableObj.Data{i,5} = this.copiedData.data{1,5};
                                    tableObj.Data{i,6} = this.copiedData.data{1,6};
                                    tableObj.Data{i,7} = this.copiedData.data{1,7};
                                    tableObj.Data{i,8} = this.copiedData.data{1,8};
                                    this.copiedData.data{i,9} = modelStatus;
                                    j=j+1;
                                end
                            else
                                for i=1: size(this.copiedData.data,1)
                                   
                                    % Add a row
                                    tableObj.Data = [tableObj.Data; this.copiedData.data(i,:)];
                                
                                    % Get a unique model label.
                                    irow = size(tableObj.Data,1);
                                    newModLabel = this.copiedData.data(i,2);
                                    newModLabel = GST_GUI.createUniqueLabel(tableObj.Data(:,2), newModLabel, irow);

                                    % Add data to the new row.
                                    tableObj.Data{irow,2} = newModLabel;
                                    tableObj.Data{irow,9} = modelStatus;                                    
                                end
                                % Update row numbers.
                                nrows = size(tableObj.Data,1);
                                tableObj.RowName = mat2cell([1:nrows]',ones(1, nrows));                                           
                            end
                        case 'Model Calibration'
                            for i=indSelected
                                tableObj.Data{i,6} = this.copiedData.data{1,6};
                                tableObj.Data{i,7} = this.copiedData.data{1,7};
                                tableObj.Data{i,8} = this.copiedData.data{1,8};
                                tableObj.Data(i,9) =  modelStatus;
                                tableObj.Data{i,10} = '';
                                tableObj.Data{i,11} = '';
                                tableObj.Data{i,12} = '';
                                tableObj.Data{i,13} = '';
                            end
                            % Update row numbers.
                            nrows = size(tableObj.Data,1);
                            tableObj.RowName = mat2cell([1:nrows]',ones(1, nrows));                                        
                        case 'Model Simulation'
                            if anySelected
                                j=1;
                                for i=indSelected
                                    
                                    % Get a unique model label.
                                    newSimLabel = {this.copiedData.data{1,2}, this.copiedData.data{1,6}};
                                    newSimLabel = GST_GUI.createUniqueLabel(tableObj.Data(:,[2,6]), newSimLabel, i);
                                    
                                    tableObj.Data{i,2} = this.copiedData.data{1,2};                                    
                                    tableObj.Data{i,3} = this.copiedData.data{1,3};
                                    tableObj.Data{i,4} = this.copiedData.data{1,4};
                                    tableObj.Data{i,5} = this.copiedData.data{1,5};
                                    tableObj.Data{i,6} = newSimLabel{2};
                                    tableObj.Data{i,7} = this.copiedData.data{1,7};
                                    tableObj.Data{i,8} = this.copiedData.data{1,8};
                                    tableObj.Data{i,9} = this.copiedData.data{1,9};
                                    tableObj.Data{i,10} = this.copiedData.data{1,10};
                                    tableObj.Data{i,11} = this.copiedData.data{1,11};
                                    this.copiedData.data{i,modelStatus_col} = modelStatus;
                                    j=j+1;
                                end
                            else
                                for i=1: size(this.copiedData.data,1)
                                   
                                    % Add a row
                                    tableObj.Data = [tableObj.Data; this.copiedData.data(i,:)];
                                    
                                    % Edit simulation label and model
                                    % status.
                                    irow = size(tableObj.Data,1);
                                    newSimLabel = {this.copiedData.data{i,2}, this.copiedData.data{i,6}};
                                    newSimLabel = GST_GUI.createUniqueLabel(tableObj.Data(:,[2,6]), newSimLabel, irow );
                                    tableObj.Data{irow,6} = newSimLabel{2};
                                    tableObj.Data{irow,modelStatus_col} = modelStatus;                                    
                                end
                                % Update row numbers.
                                nrows = size(tableObj.Data,1);
                                tableObj.RowName = mat2cell([1:nrows]',ones(1, nrows));                                            
                            end                            
                    end
                    
                    % Update row numbers.
                    nrows = size(tableObj.Data,1);
                    tableObj.RowName = mat2cell([1:nrows]',ones(1, nrows));
                    
                case 'Insert row above selection'
                    if size(tableObj.Data,1)==0
                        tableObj.Data = cell(1,size(tableObj.Data,2));
                    else
                        selectedRows= find(selectedRows);
                        for i=1:length(selectedRows)

                            ind = max(0,selectedRows(i) + i-1);

                            tableObj.Data = [tableObj.Data(1:ind-1,:); ...
                                             defaultData; ...
                                             tableObj.Data(ind:end,:)];
                            tableObj.Data{ind,1} = false; 
                            
                            % Update model build status
                            tableObj.Data{ind,modelStatus_col} = modelStatus;

                        end
                    end
                    % Update row numbers.
                    nrows = size(tableObj.Data,1);
                    tableObj.RowName = mat2cell([1:nrows]',ones(1, nrows));
                        
                case 'Insert row below selection'    
                    if size(tableObj.Data,1)==0
                        tableObj.Data = cell(1,size(tableObj.Data,2));
                    else
                        selectedRows= find(selectedRows);
                        for i=1:length(selectedRows)

                            ind = selectedRows(i) + i;

                            tableObj.Data = [tableObj.Data(1:ind-1,:); ...
                                             defaultData; ...
                                             tableObj.Data(ind:end,:)];
                            tableObj.Data{ind,1} = false;                                                              
                            
                            % Update model build status
                            tableObj.Data{ind,modelStatus_col} = modelStatus;
                            
                        end
                    end
                    % Update row numbers.
                    nrows = size(tableObj.Data,1);
                    tableObj.RowName = mat2cell([1:nrows]',ones(1, nrows));

                case 'Delete selected rows'    
                    
                    % Delete the model objects if within the model
                    % construction table
                    if strcmp(tableObj.Tag,'Model Construction')                        
                        for i=indSelected
                            % Use the model lable to find model object
                            ind = cellfun( @(x) strcmp( x.model_label, this.tab_ModelConstruction.Table.Data{i,2}), this.models);
                            
                            % Delete build models
                            this.models = this.models(~ind,1);
                        end
                    end
                    
                    % Delete table data
                    tableObj.Data = tableObj.Data(~selectedRows,:);
                    
                    % Update row numbers.
                    nrows = size(tableObj.Data,1);
                    tableObj.RowName = mat2cell([1:nrows]',ones(1, nrows));
                    
            end
        end
        
        function rowSelection(this, hObject, eventdata)

            % Get the table object from UserData
            tableObj = eval(eventdata.Source.Parent.UserData);            
                                    
            % Get selected rows
            selectedRows = false(size(tableObj.Data,1),1);
            for i=1:size(tableObj.Data,1)
                if ~isempty(tableObj.Data{i,1}) && tableObj.Data{i,1};
                    selectedRows(i) = true;
                end
            end
            
            % Do the selected action            
            switch hObject.Label
                case 'Select all'
                    tableObj.Data(:,1) = mat2cell(true(size(selectedRows,1),1),ones(1, size(selectedRows,1)));
                case 'Select none'
                    tableObj.Data(:,1) = mat2cell(false(size(selectedRows,1),1),ones(1, size(selectedRows,1)));
                case 'Invert selection'
                    tableObj.Data(:,1) = mat2cell(~selectedRows,ones(1, size(selectedRows,1)));
            end
                        
        end
        
        
        function fName = getFileName(this, dialogString)
           
            % If project folder is not set, exit
            if isempty(this.project_fileName)
                errordlg('The project folder must be set before files can be input.')
                return
            end                        

            % Get the project path
            if isdir(this.project_fileName)
                projectPath = this.project_fileName;
            else
                [projectPath,projectName,projectExt] = fileparts(this.project_fileName);
            end

            % Set the current folder to the project folder
            try
                cd(projectPath);
            catch
                errordlg({'The project folder could not be opened. Try re-inputting the', ...
                        'project folder and/or check your network access to the folder.'}, 'Project folder access error.');
                return;
            end
            
            % Get file name
            [fName,pName] = uigetfile({'*.*'},dialogString); 
            if fName~=0;
                % Check if the file name is the same as the
                % project path.
                if isempty(strfind(pName,projectPath))
                    errordlg('The selected file path must be a within the project folder or a sub-folder of it.')
                    return;
                end

                % Get the extra part of the file path not
                % within the project path.
                fName = fullfile(pName,fName); 
                fName = fName(length(projectPath)+2:end);
            end                        
        end
    end
    
    methods(Static=true)
       
        % Remove HTML tags from each model label
        function str = removeHTMLTags(str)
            if iscell(str)
               for i=1:length(str)
                    if ~isempty(strfind(upper(str{i}),'HTML'))
                        str{i} = regexp(str{i},'>.*?<','match');
                        str{i} = strrep(str{i}, '<', '');
                        str{i} = strrep(str{i}, '>', '');
                        str{i} = strtrim(strjoin(str{i}));
                    end
               end
            else
                if ~isempty(strfind(upper(str),'HTML'))
                    str = regexp(str,'>.*?<','match');
                    str = strrep(str, '<', '');
                    str = strrep(str, '>', '');
                    str = strtrim(strjoin(str));            
                end
            end
        end
        
        % Create a unique model or simulation label. This is used in the
        % copy/paste of table rows to ensure each row is unique
        function newLabel = createUniqueLabel(allLabels, newLabel, currentRow)
           
            % Check if the proposed label is unique.
            if size(allLabels,2)==1
                ind = cellfun( @(x,y) strcmp( newLabel, x) , allLabels);
            elseif size(allLabels,2)==2
                ind = cellfun( @(x,y) strcmp( newLabel{1}, x) &&  strcmp( newLabel{2}, y) , allLabels(:,1), allLabels(:,2));
            else
                error('A maximum of two columns of model / simulation labels can be evaluated for uniqueness.');
            end
            ind = find(ind);                        
            if length(ind)==1 && ind(1) == currentRow % Return if only the current row has the proposed new label.
                return;
            end            
            
            % If not unique, then add an integer to the label so that it is
            % unique.
            origLabel = newLabel;
            label_extension = 1;      
            if size(allLabels,2)==1

                if ischar(origLabel)
                    origLabel_tmp{1} = origLabel;
                    origLabel = origLabel_tmp;
                    clear origLabel_tmp
                end
                
                newLabel = [origLabel{1}, ' copy ',num2str(label_extension)];
                while  any(find(cellfun( @(x,y) strcmp( newLabel, x) , allLabels))~=currentRow)
                    label_extension = label_extension + 1;
                    newLabel = [origLabel, ' copy ',num2str(label_extension)];    
                end
            elseif size(allLabels,2)==2
                newLabel = {origLabel{1}, [origLabel{2}, ' copy ',num2str(label_extension)]};
                while any(find(cellfun( @(x,y) strcmp( newLabel{1}, x) &&  strcmp( newLabel{2}, y) , allLabels(:,1), allLabels(:,2)))~=currentRow)
                    label_extension = label_extension + 1;
                    newLabel = {origLabel{1}, [origLabel{2}, ' copy ',num2str(label_extension)]};
                end                    
            end
        end
        
    end
end

