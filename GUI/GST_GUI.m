classdef GST_GUI < handle  
    %GST_GUI Summary of this class goes here
    %   Detailed explanation goes here
    
    %class properties - access is private so nothing else can access these
    %variables. Useful in different sitionations
    properties
        % Version number
        versionNumber = 0.1;
        
        % GUI properies for the overall figure.
        FigureSplash
        Figure;        
        figure_Menu
        figure_contextMenu
        figure_Prefs
        figure_Help
        figure_Layout 
        
        % GUI properties for the individual tabs.
        tab_Project
        tab_ModelConstruction;
        tab_ModelCalibration;        
        tab_ParamUncertainty;
        tab_ModelInterp;
        tab_ModelSimulation;
        
        % Store model data
        models
        
        % Copies data
        copiedData
        
        % File name for the current set of models
        project_fileName
    end
    
    methods
        
        function this = GST_GUI
            
            % Show splash (is code not deployed)
            %if ~isdeployed
               onAbout(this, [],[]);
            %end
           
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
            
            % Set window Size
            windowHeight = this.FigureSplash.Parent.ScreenSize(4);
            windowWidth = this.FigureSplash.Parent.ScreenSize(3);
            splashWidth = 0.8*windowWidth;
            splashHeight = 0.6*windowHeight;            
            this.Figure.Position = [(windowWidth - splashWidth)/2 (windowHeight - splashHeight)/2 splashWidth splashHeight];
            this.Figure.Visible = 'off';
            
            % Set default panel color
            warning('off');
            uiextras.set( this.Figure, 'DefaultBoxPanelTitleColor', [0.7 1.0 0.7] );
            warning('on');
            
            % + File menu
            this.figure_Menu = uimenu( this.Figure, 'Label', 'File' );
            uimenu( this.figure_Menu, 'Label', 'Open ...', 'Callback', @this.onOpen);
            uimenu( this.figure_Menu, 'Label', 'Save as ...', 'Callback', @this.onSaveAs );
            uimenu( this.figure_Menu, 'Label', 'Save', 'Callback', @this.onSave );
            uimenu(this.figure_Menu,'Separator','on');
            uimenu( this.figure_Menu, 'Label', 'Exit', 'Callback', @this.onExit );

            % + Preferences menu
            this.figure_Prefs = uimenu( this.Figure, 'Label', 'Preferences' );
            uimenu( this.figure_Prefs, 'Label', 'Cores', 'Callback', @onCores );

            % + Help menu
            this.figure_Help = uimenu( this.Figure, 'Label', 'Help' );
            uimenu(this.figure_Help, 'Label', 'Documentation', 'Callback', @this.onDocumentation);
            uimenu(this.figure_Help, 'Label', 'About', 'Callback', @this.onAbout );

            %Create Panels for different windows       
            this.figure_Layout = uiextras.TabPanel( 'Parent', this.Figure, 'Padding', ...
                5, 'TabSize',127,'FontSize',8);
            this.tab_Project.Panel = uiextras.Panel( 'Parent', this.figure_Layout, 'Padding', 5, ...
                'Title', 'Project Description', 'Tag','ProjectDescription');            
            this.tab_ModelConstruction.Panel = uiextras.Panel( 'Parent', this.figure_Layout, 'Padding', 5, ...
                'Title', 'Model Construction', 'Tag','ModelConstruction');
            this.tab_ModelCalibration.Panel = uiextras.Panel( 'Parent', this.figure_Layout, 'Padding', 5, ...
                'Title', 'Model Calibration', 'Tag','ModelCalibration');
%            this.tab_ParamUncertainty.Panel = uiextras.Panel( 'Parent', this.figure_Layout, 'Padding', 5, ...
%                'Title', 'Parameter Uncertainty', 'Tag','Tab4');
            this.tab_ModelInterp.Panel = uiextras.Panel( 'Parent', this.figure_Layout, 'Padding', 5,  ...
                'Title', 'Model Interpolation', 'Tag','ModelInterpolation');
            this.tab_ModelSimulation.Panel = uiextras.Panel( 'Parent', this.figure_Layout, 'Padding', 5, ...
                'Title', 'Model Simulation', 'Tag','ModelSimulation');
            this.figure_Layout.TabNames = {'Project Description', 'Model Construction', 'Model Calibration', ...
                'Model Interpolation','Model Simulation'};
            this.figure_Layout.SelectedChild = 1;
           
            % Create Default object for a model;
            %this.models{1} = GST_GUI_data();

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
            this.tab_Project.project_description = uicontrol( 'Parent', hbox1t1,'Style','edit','HorizontalAlignment','left', 'Units','normalized','Min',1,'Max',10,'TooltipString','Input an extended project description. This is an optional input to assist project management.');            
            
            % Set sizes
            set(hbox1t1, 'Sizes', [20 20 20 20 -1]);
                        
%%          Layout Tab2 - Model Construction
            %------------------------------------------------------------------
            % Declare panels        
            hbox1t2 = uiextras.HBoxFlex('Parent', this.tab_ModelConstruction.Panel,'Padding', 3, 'Spacing', 3);
            vbox1t2 = uiextras.VBoxFlex('Parent',hbox1t2,'Padding', 3, 'Spacing', 3);
            vbox3t2 = uiextras.HButtonBox('Parent',vbox1t2,'Padding', 3, 'Spacing', 3);  
            
        
            % Get the model types
            [modTypes,modRec] = GroundwaterStatisticsToolbox.model_types();
            modTypeCode = modTypes(:,1)';  
            this.tab_ModelConstruction.modelOptions.types.names = modTypes;
            this.tab_ModelConstruction.modelOptions.types.descriptions = modRec;
            
            % Create table for model construction
            cnames1t2 ={'<html><center>Select<br />Model</center></html>', ... 
                        '<html><center>Model<br />Label</center></html>', ...   
                        '<html><center>Obs. Head<br />File</center></html>', ...   
                        '<html><center>Forcing Data<br />File</center></html>', ...   
                        '<html><center>Coordinates<br />File</center></html>', ...   
                        '<html><center>Bore<br />ID</center></html>', ...   
                        '<html><center>Model<br />Type</center></html>', ...                           
                        '<html><center>Model<br />Options</center></html>', ...                           
                        '<html><center>Build<br />Status</center></html>'};
            cformats1t2 = {'logical', 'char', 'char','char','char','char',modTypeCode,'char','char'};
            cedit1t2 = logical([1 1 1 1 1 1 1 1 0]);            
            rnames1t2 = {[1]};
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
            this.tab_ModelConstruction.Table = uitable('Parent',vbox1t2,'ColumnName',cnames1t2,...
                'ColumnEditable',cedit1t2,'ColumnFormat',cformats1t2,'RowName', rnames1t2, ...
                'CellSelectionCallback', @this.modelConstruction_tableSelection,...
                'CellEditCallback', @this.modelConstruction_tableEdit,...
                'Data',data,'Tag','Model Construction', ...
                'TooltipString', toolTipStr);

            % Find java sorting object in table
            this.figure_Layout.Selection = 2;
            drawnow();
            jscrollpane = findjobj(this.tab_ModelConstruction.Table);
            jtable = jscrollpane.getViewport.getView;

            % Turn the JIDE sorting on
            jtable.setSortable(true);
            jtable.setAutoResort(true);
            jtable.setMultiColumnSortable(true);
            jtable.setPreserveSelectionsAfterSorting(true);            
                        
            % Add buttons to top left panel               
            uicontrol('Parent',vbox3t2,'String','Append Table Data','Callback', @this.onImportTable, 'Tag','Model Construction', 'TooltipString', sprintf('Append a .csv file of table data to the table below. \n Use this feature to efficiently build a large number of models.') );
            uicontrol('Parent',vbox3t2,'String','Export Table Data','Callback', @this.onExportTable, 'Tag','Model Construction', 'TooltipString', sprintf('Export a .csv file of the table below.') );
            uicontrol('Parent',vbox3t2,'String','Build Selected Models','Callback', @this.onBuildModels, 'Tag','Model Construction', 'TooltipString', sprintf('Use the tick-box below to select the models to build then click here. \n After building, the status is given in the right most column.') );            
            vbox3t2.ButtonSize(1) = 225;
            
            % Create vbox for the various model options
            this.tab_ModelConstruction.modelOptions.vbox = uiextras.VBoxFlex('Parent',hbox1t2,'Padding', 3, 'Spacing', 3, 'DividerMarkings','off');
            
            % Add model options panel for bore IDs
            dynList = [];
            vbox4t2 = uiextras.VBox('Parent',this.tab_ModelConstruction.modelOptions.vbox, 'Padding', 3, 'Spacing', 3, 'Visible','on');
            uicontrol( 'Parent', vbox4t2,'Style','text','String',sprintf('%s\n%s%s','Please Bore ID(s) for the model:'), 'Units','normalized');            
            this.tab_ModelConstruction.boreIDList = uicontrol('Parent',vbox4t2,'Style','list','BackgroundColor','w', ...
                'String',dynList(:),'Value',1,'Callback',...
                @this.modelConstruction_optionsSelection, 'Units','normalized');            

            % Add model options panel for decriptions of each model type
            dynList = [];
            vbox5t2 = uiextras.VBox('Parent',this.tab_ModelConstruction.modelOptions.vbox, 'Padding', 3, 'Spacing', 3, 'Visible','on');
            uicontrol( 'Parent', vbox5t2,'Style','text','String',sprintf('%s\n%s%s','Below is a decsription of the selected model type:'), 'Units','normalized');            
            this.tab_ModelConstruction.modelDescriptions = uicontrol( 'Parent', vbox5t2,'Style','text','String','(No model type selected.)', 'HorizontalAlignment','left','Units','normalized');                        
            set(vbox5t2, 'Sizes', [30 -1]);
            
            % Resize the panels
            set(vbox1t2, 'Sizes', [30 -1]);
            set(hbox1t2, 'Sizes', [-3 -1]);
            set(vbox4t2, 'Sizes', [30 -1]);            
            
            % Build model options for each model type                        
            this.tab_ModelConstruction.modelTypes.model_TFN.hbox = uiextras.HBox('Parent',this.tab_ModelConstruction.modelOptions.vbox,'Padding', 3, 'Spacing', 3);
            this.tab_ModelConstruction.modelTypes.model_TFN.buttons = uiextras.VButtonBox('Parent',this.tab_ModelConstruction.modelTypes.model_TFN.hbox,'Padding', 3, 'Spacing', 3);
            uicontrol('Parent',this.tab_ModelConstruction.modelTypes.model_TFN.buttons,'String','<','Callback', @this.onApplyModelOptions, 'TooltipString','Copy model option to current model.');
            uicontrol('Parent',this.tab_ModelConstruction.modelTypes.model_TFN.buttons,'String','<<','Callback', @this.onApplyModelOptions_selectedBores, 'TooltipString','Copy model option to selected models (of the current model type).');
            this.tab_ModelConstruction.modelTypes.model_TFN.obj = model_TFN_gui( this.tab_ModelConstruction.modelTypes.model_TFN.hbox);
            this.tab_ModelConstruction.modelTypes.model_TFN.hbox.Widths=[40 -1];
            
            % Hide all modle option vboxes 
            this.tab_ModelConstruction.modelOptions.vbox.Heights = zeros(size(this.tab_ModelConstruction.modelOptions.vbox.Heights));

%           Add context menu
            % Create menu
            this.Figure.UIContextMenu = uicontextmenu(this.Figure,'Visible','on');
            
            % Add items
            uimenu(this.Figure.UIContextMenu,'Label','Copy selected row','Callback',@this.rowAddDelete);
            uimenu(this.Figure.UIContextMenu,'Label','Paste rows','Callback',@this.rowAddDelete);
            uimenu(this.Figure.UIContextMenu,'Separator','on');
            uimenu(this.Figure.UIContextMenu,'Label','Insert row above selection','Callback',@this.rowAddDelete);
            uimenu(this.Figure.UIContextMenu,'Label','Insert row below selection','Callback',@this.rowAddDelete);            
            uimenu(this.Figure.UIContextMenu,'Label','Delete selected rows','Callback',@this.rowAddDelete);
            uimenu(this.Figure.UIContextMenu,'Separator','on');
            uimenu(this.Figure.UIContextMenu,'Label','Select all','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Select none','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Invert selection','Callback',@this.rowSelection);
            
            
            % Attach menu to the construction table
            set(this.tab_ModelConstruction.Table,'UIContextMenu',this.Figure.UIContextMenu);
                        
            % Add table name to .UserData
            set(this.tab_ModelConstruction.Table.UIContextMenu,'UserData','this.tab_ModelConstruction.Table');
            
            
%%          Layout Tab3 - Calibrate models
            %------------------------------------------------------------------
            hbox1t3 = uiextras.HBoxFlex('Parent', this.tab_ModelCalibration.Panel,'Padding', 3, 'Spacing', 3);
            vbox1t3 = uiextras.VBox('Parent',hbox1t3,'Padding', 3, 'Spacing', 3);
            vbox2t3 = uiextras.VBox('Parent',hbox1t3,'Padding', 3, 'Spacing', 3);
            hbox3t3 = uiextras.HButtonBox('Parent',vbox1t3,'Padding', 3, 'Spacing', 3);  
                        
            % Add button for calibration
            uicontrol('Parent',hbox3t3,'String','Import Table Data','Callback', @this.onImportTable, 'Tag','Model Calibration', 'TooltipString', sprintf('Import a .csv file of table data to the table below. \n Only rows with a model label and bore ID matching a row within the table will be imported.') );
            uicontrol('Parent',hbox3t3,'String','Export Table Data','Callback', @this.onExportTable, 'Tag','Model Calibration', 'TooltipString', sprintf('Export a .csv file of the table below.') );            
            uicontrol('Parent',hbox3t3,'String','Calibrate Selected Models','Callback', @this.onCalibModels, 'TooltipString', sprintf('Use the tick-box below to select the models to calibrate then click here. \n During and after calibration, the status is given in the 9th column.') );            
            uicontrol('Parent',hbox3t3,'String','Export Results','Callback', @this.onExportResults, 'Tag','Model Calibration', 'TooltipString', sprintf('Export a .csv file of the calibration results from all models.') );            
            hbox3t3.ButtonSize(1) = 225;
            
            % Add table
            cnames1t3 = {   '<html><center>Select<br />Model</center></html>', ...   
                            '<html><center>Model<br />Label</center></html>', ...   
                            '<html><center>Bore<br />ID</center></html>', ...   
                            '<html><center>Head<br />Start Date</center></html>', ...
                            '<html><center>Head<br />End Date</center></html>', ...
                            '<html><center>Calib.<br />Start Date</center></html>', ...
                            '<html><center>Calib.<br />End Date</center></html>', ...
                            '<html><center>No. Calib.<br />Restarts</center></html>', ...
                            '<html><center>Calib.<br />Status</center></html>', ...
                            '<html><center>Calib.<br />Period CoE</center></html>', ...
                            '<html><center>Eval. Period<br />Unbiased CoE</center></html>', ...
                            '<html><center>Calib.<br />Period AIC</center></html>', ...
                            '<html><center>Eval.<br />Period AIC</center></html>'};
            data = cell(0,13);            
            rnames1t3 = {[1]};
            cedit1t3 = logical([1 0 0 0 0 1 1 1 0 0 0 0 0]);            
            cformats1t3 = {'logical', 'char', 'char','char','char','char','char', 'numeric','char','numeric','numeric','numeric','numeric'};
            toolTipStr = ['<html>Use this table to calibrate the models that have been successfully built. <br>' ...
                  'To calibrate a model, first input the start and end dates for the calibration and the <br>' ...
                  'number of CMA-ES re-starts. Note, more restarts result in a more robust estimate of the <br>' ...
                  'global optima. Once all inputs are defined, use the button above to calibrate the model, ' ... 
                  'after which the selected models can be calibrated.<br>', ...
                  'Below are tips for calibrating models:<br>', ... 
                  '<ul type="bullet type">', ...
                  '<li>The model calibration results are summarised in the right four columns. <br>', ...
                  '      <li><b>CoE</b> is the coefficient of efficiency where 1 is a perfect fit, <0 worse then using the mean.<br>' ...
                  '      <li><b>AIC</b> is the Akaike information criterion & is used to compare models of differing number of parameters. Lower is better.<br>' ,...                  
                  '<li>Sort the rows by clicking on the column headings. Below are more complex sorting options:<ul>', ...
                  '      <li><b>Click</b> to sort in ascending order.<br>', ...
                  '      <li><b>Shift-click</b> to sort in descending order.<br>', ...    
                  '      <li><b>Ctrl-click</b> to sort secondary in ascending order.<b>Shift-Ctrl-click</b> for descending order.<br>', ...    
                  '      <li><b>Click again</b> again to change sort direction.<br>', ...
                  '      <li><b>Click a third time </b> to return to the unsorted view.', ...
                  ' </ul></ul>'];
              
            this.tab_ModelCalibration.Table = uitable('Parent',vbox1t3,'ColumnName',cnames1t3, ... 
                'ColumnFormat', cformats1t3, 'ColumnEditable', cedit1t3, ...
                'RowName', rnames1t3, 'Tag','Model Calibration', ...
                'CellSelectionCallback', @this.modelCalibration_tableSelection,...
                'CellEditCallback', @this.modelCalibration_tableEdit,...
                'Data', data, ...
                'TooltipString', toolTipStr);

            % Add drop-down for the results box
            uicontrol('Parent',vbox2t3,'Style','text','String','Select calibration results to display:' );
            this.tab_ModelCalibration.resultsOptions.popup = uicontrol('Parent',vbox2t3,'Style','popupmenu', ...
                'String',{'Data & residuals', 'Parameter values','Simulation time series plot','Residuals time series plot','Histogram of calib. residuals','Histogram of eval. residuals','Scatter plot of obs. vs model','Scatter plot of residuals vs obs','Variogram of residuals','(none)'}, ...
                'Value',3,'Callback', @this.modelCalibration_onResultsSelection);         
            this.tab_ModelCalibration.resultsOptions.box = vbox2t3;
            this.tab_ModelCalibration.resultsOptions.plots.panel = uiextras.BoxPanel('Parent', vbox2t3 );            
            
            this.tab_ModelCalibration.resultsOptions.dataTable.box = uiextras.Grid('Parent', vbox2t3,'Padding', 3, 'Spacing', 3);
            this.tab_ModelCalibration.resultsOptions.dataTable.table = uitable('Parent',this.tab_ModelCalibration.resultsOptions.dataTable.box, ...
                'ColumnName',{'Year','Month', 'Day','Hour','Minute', 'Obs. Head','Is Calib. Point?','Calib. Head','Eval. Head','Model Err.','Noise Lower','Noise Upper'}, ... 
                'ColumnFormat', {'numeric','numeric','numeric','numeric', 'numeric','numeric','logical','numeric','numeric','numeric','numeric','numeric'}, ...
                'ColumnEditable', true(1,12), ...
                'Tag','Model Calibration - results table', ...
                'TooltipString', 'Results data from the model calibration and evaluation.');
            this.tab_ModelCalibration.resultsOptions.paramTable.box = uiextras.Grid('Parent', vbox2t3,'Padding', 3, 'Spacing', 3);
            this.tab_ModelCalibration.resultsOptions.paramTable.table = uitable('Parent',this.tab_ModelCalibration.resultsOptions.paramTable.box, ...
                'ColumnName',{'Component Name','Parameter Name','Value'}, ... 
                'ColumnFormat', {'char','char','numeric'}, ...
                'ColumnEditable', true(1,3), ...
                'Tag','Model Calibration - parameter table', ...
                'TooltipString', 'Model parameter estimates from the calibration.');            

            % Set box sizes
            set(hbox1t3, 'Sizes', [-2 -1]);
            set(vbox1t3, 'Sizes', [30 -1]);
            set(vbox2t3, 'Sizes', [30 20 0 0 0]);
                        
%           Add context menu
            this.Figure.UIContextMenu = uicontextmenu(this.Figure,'Visible','on');
            uimenu(this.Figure.UIContextMenu,'Label','Copy selected row','Callback',@this.rowAddDelete);
            uimenu(this.Figure.UIContextMenu,'Label','Paste rows','Callback',@this.rowAddDelete);
            uimenu(this.Figure.UIContextMenu,'Separator','on');
            uimenu(this.Figure.UIContextMenu,'Label','Select all','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Select none','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Invert selection','Callback',@this.rowSelection);
            
            % Attach menu to the construction table
            set(this.tab_ModelCalibration.Table,'UIContextMenu',this.Figure.UIContextMenu);
                        
            % Add table name to .UserData
            set(this.tab_ModelCalibration.Table.UIContextMenu,'UserData','this.tab_ModelCalibration.Table');

            

%%          Layout Tab4 - Model Simulation
            %------------------------------------------------------------------            
            hbox1t4 = uiextras.HBoxFlex('Parent', this.tab_ModelSimulation.Panel,'Padding', 3, 'Spacing', 3);
            vbox1t4 = uiextras.VBox('Parent',hbox1t4,'Padding', 3, 'Spacing', 3);
            vbox2t4 = uiextras.VBox('Parent',hbox1t4,'Padding', 3, 'Spacing', 3);
            hbox3t4 = uiextras.HButtonBox('Parent',vbox1t4,'Padding', 3, 'Spacing', 3);  
                        
            % Add button for calibration
            % Add buttons to top left panel               
            uicontrol('Parent',hbox3t4,'String','Append Table Data','Callback', @this.onImportTable, 'Tag','Model Simulation', 'TooltipString', sprintf('Append a .csv file of table data to the table below. \n Only rows where the model label is for a model that have been calibrated will be imported.') );
            uicontrol('Parent',hbox3t4,'String','Export Table Data','Callback', @this.onExportTable, 'Tag','Model Simulation', 'TooltipString', sprintf('Export a .csv file of the table below.') );                        
            uicontrol('Parent',hbox3t4,'String','Simulate Selected Models','Callback', @this.onSimModels, 'TooltipString', sprintf('Use the tick-box below to select the models to simulate then click here. \n During and after simulation, the status is given in the 9th column.') );            
            uicontrol('Parent',hbox3t4,'String','Export Results','Callback', @this.onExportResults, 'Tag','Model Simulation', 'TooltipString', sprintf('Export a .csv file of the simulation results from all models.') );            
            hbox3t4.ButtonSize(1) = 225;
            
            % Add table
            cnames1t4 = {   '<html><center>Select<br />Model</center></html>', ...   
                            '<html><center>Model<br />Label</center></html>', ...                               
                            '<html><center>Bore<br />ID</center></html>', ...   
                            '<html><center>Head<br />Start Date</center></html>', ...
                            '<html><center>Head<br />End Date</center></html>', ...
                            '<html><center>Simulation<br />Label</center></html>', ...   
                            '<html><center>Forcing Data<br />File</center></html>', ...
                            '<html><center>Simulation<br />Start Date</center></html>', ...
                            '<html><center>Simulation<br />End Date</center></html>', ...
                            '<html><center>Simulation<br />Time step</center></html>', ...                            
                            '<html><center>Krig<br />Sim. Residual?</center></html>', ... 
                            '<html><center>Simulation<br />Status</center></html>'};
            data = cell(1,12);            
            rnames1t4 = {[1]};
            cedit1t4 = logical([1 1 0 0 0 1 1 1 1 1 1 0]);            
            cformats1t4 = {'logical', {'(none calibrated)'}', 'char','char','char','char','char','char', 'char',{'Daily' 'Weekly' 'Monthly' 'Yearly'}, 'logical','char' };
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
              
            this.tab_ModelSimulation.Table = uitable('Parent',vbox1t4,'ColumnName',cnames1t4, ... 
                'ColumnFormat', cformats1t4, 'ColumnEditable', cedit1t4, ...
                'RowName', rnames1t4, 'Tag','Model Simulation', ...
                'Data', data, ...
                'CellSelectionCallback', @this.modelSimulation_tableSelection,...
                'CellEditCallback', @this.modelSimulation_tableEdit,...
                'TooltipString', toolTipStr);


            % Add drop-down for the results box
            uicontrol('Parent',vbox2t4,'Style','text','String','Select simulation results to display:' );
            this.tab_ModelSimulation.resultsOptions.popup = uicontrol('Parent',vbox2t4,'Style','popupmenu', ...
                'String',{'Simulation data', 'Simulation & decomposition plots','(none)'}, ...
                'Value',3,'Callback', @this.modelSimulation_onResultsSelection);         
            
            this.tab_ModelSimulation.resultsOptions.dataTable.box = uiextras.Grid('Parent', vbox2t4,'Padding', 3, 'Spacing', 3);
            this.tab_ModelSimulation.resultsOptions.dataTable.table = uitable('Parent',this.tab_ModelSimulation.resultsOptions.dataTable.box, ...
                'ColumnName',{'Year','Month', 'Day','Hour','Minute', 'Sim. Head','Noise Lower','Noise Upper'}, ... 
                'ColumnFormat', {'numeric','numeric','numeric','numeric', 'numeric','numeric','numeric','numeric'}, ...
                'ColumnEditable', true(1,8), ...
                'Tag','Model Simulation - results table', ...
                'TooltipString', 'Results data from the model simulation.');  
            
            this.tab_ModelSimulation.resultsOptions.box = vbox2t4;
            this.tab_ModelSimulation.resultsOptions.plots.panel = uiextras.BoxPanel('Parent', vbox2t4);                                              
            
            % Set box sizes
            set(hbox1t4, 'Sizes', [-2 -1]);
            set(vbox1t4, 'Sizes', [30 -1]);
            set(vbox2t4, 'Sizes', [30 20 0 0]);
                        
%           Add context menu
            this.Figure.UIContextMenu = uicontextmenu(this.Figure,'Visible','on');
            uimenu(this.Figure.UIContextMenu,'Label','Copy selected row','Callback',@this.rowAddDelete);
            uimenu(this.Figure.UIContextMenu,'Label','Paste rows','Callback',@this.rowAddDelete);
            uimenu(this.Figure.UIContextMenu,'Separator','on');
            uimenu(this.Figure.UIContextMenu,'Label','Insert row above selection','Callback',@this.rowAddDelete);
            uimenu(this.Figure.UIContextMenu,'Label','Insert row below selection','Callback',@this.rowAddDelete);            
            uimenu(this.Figure.UIContextMenu,'Label','Delete selected rows','Callback',@this.rowAddDelete);
            uimenu(this.Figure.UIContextMenu,'Separator','on');            
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
            set(this.Figure,'Visible','on');
        end
        
%Callbacks ~~~~~~~~~~~~~~~~~~~~~~~~~
        % Open saved model
        function onOpen(this,hObject,eventdata)
            [fName,pName] = uigetfile({'*.mat'},'Select saved groundwater statistical model.');    
            if fName~=0;
                % Assign the file name 
                this.project_fileName = fullfile(pName,fName);
                
                % Load file
                try
                    savedData = load(this.project_fileName,'-mat');
                catch ME
                    warndlg('File could not be loaded','File error');
                end
                
                % Assign loaded data to the tables and models.
                try
                    this.tab_Project.project_name.String = savedData.tableData.tab_Project.title;
                    this.tab_Project.project_description.String = savedData.tableData.tab_Project.description;
                    this.tab_ModelConstruction.Table.Data = savedData.tableData.tab_ModelConstruction;
                    this.tab_ModelCalibration.Table.Data = savedData.tableData.tab_ModelCalibration;
                    %this.tab_ParamUncertainty.Table.Data = savedData.tableData.tab_ParamUncertainty;
                    %this.tab_ModelInterp.Table.Data = savedData.tableData.tab_ModelInterp;
                    %this.tab_ModelSimulation.Table.Data = savedData.tableData.tab_ModelSimulation;
                catch ME
                    warndlg('Loaded data could not be assigned to the user interface tables.','File table data error');
                end
                
                % Assign built models.
                try
                    this.models = savedData.models;
                catch ME
                    warndlg('Loaded models could not be assigned to the user interface.','File model data error');
                end   
            end
        end
        
        % Save as current model        
        function onSaveAs(this,hObject,eventdata)
            [fName,pName] = uiputfile({'*.mat'},'Save models as...');    
            if fName~=0;
                % Assign file name to date cell array
                this.project_fileName = fullfile(pName,fName);
                
                % Collate the tables of data to a temp variable.
                tableData.tab_Project.title = this.tab_Project.project_name.String;
                tableData.tab_Project.description = this.tab_Project.project_description.String;
                tableData.tab_ModelConstruction = this.tab_ModelConstruction.Table.Data;
                tableData.tab_ModelCalibration = this.tab_ModelCalibration.Table.Data;
                %tableData.tab_ParamUncertainty = this.tab_ParamUncertainty.Table.Data;
                %tableData.tab_ModelInterp = this.tab_ModelInterp.Table.Data;
                %tableData.tab_ModelSimulation = this.tab_ModelSimulation.Table.Data;
                                
                % Get built models.
                models = this.models;
                
                % Save the GUI tables to the file.
                save(this.project_fileName, 'tableData',  'models','-v7.3');
            end
        end
        
        % Save model        
        function onSave(this,hObject,eventdata)
        
            if isempty(this.project_fileName) || exist(this.project_fileName,'file') ~= 2;
                onSaveAs(this,hObject,eventdata);
            else               
                % Collate the tables of data to a temp variable.
                tableData.tab_Project.title = this.tab_Project.project_name.String;
                tableData.tab_Project.description = this.tab_Project.project_description.String;
                tableData.tab_ModelConstruction = this.tab_ModelConstruction.Table.Data;
                tableData.tab_ModelCalibration = this.tab_ModelCalibration.Table.Data;
                %tableData.tab_ParamUncertainty = this.tab_ParamUncertainty.Table.Data;
                %tableData.tab_ModelInterp = this.tab_ModelInterp.Table.Data;
                %tableData.tab_ModelSimulation = this.tab_ModelSimulation.Table.Data;
                                
                % Get built models.
                models = this.models;
                
                % Save the GUI tables to the file.
                save(this.project_fileName, 'tableData',  'models','-v7.3');                
            end
            
        end    
        
        % This function runs when the app is closed        
        function onExit(this,hObject,eventdata)        
            delete(this.Figure);
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
                        [fName,pName] = uigetfile({'*.*'},'Select the Observed Head file'); 
                        if fName~=0;
                            % Assign file name to date cell array
                            data{eventdata.Indices(1),eventdata.Indices(2)} = fullfile(pName,fName);
                            % Input file name to the table
                            set(hObject,'Data',data);
                        end
                        
                    case 'Forcing Data File'
                        [fName,pName] = uigetfile({'*.*'},'Select the Forcing Data file');
                        if fName~=0;
                            % Assign file name to date cell array
                            data{eventdata.Indices(1),eventdata.Indices(2)} = fullfile(pName,fName);
                            % Input file name to the table
                            set(hObject,'Data',data);
                        end
                    case 'Coordinates File'
                        [fName,pName] = uigetfile({'*.*'},'Select the Coordinates file');    
                        if fName~=0;
                            % Assign file name to date cell array
                            data{eventdata.Indices(1),eventdata.Indices(2)} = fullfile(pName,fName);
                            % Input file name to the table
                            set(hObject,'Data',data);
                        end
                    case 'Bore ID'
                         % Check the obs. head file is listed
                         fname = data{eventdata.Indices(1),3};
                         if isempty(fname)
                            warndlg('The observed head file name bust be input before selecting the bore ID');
                            return;
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
                         this.tab_ModelConstruction.modelOptions.vbox.Heights = [-1; 0 ; 0];
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
                         this.tab_ModelConstruction.modelOptions.vbox.Heights = [0; -1 ; 0];
                         
                    case 'Model Options'
                        % Check the preceeding inputs have been defined.
                        if  any(cellfun(@(x) isempty(x), data(irow,3:7)))
                            warndlg('The observed head data file, forcing data file, coordinates file, bore ID and model type must be input before the model option can be set.');
                            return;
                        end
                                                
                        % Set the forcing data, bore ID, coordinates for
                        % the given model type.
                        switch eventdata.Source.Data{irow,7};
                            case 'model_TFN'
                                
                                setForcingData(this.tab_ModelConstruction.modelTypes.model_TFN.obj, data{irow,4});
                                setCoordinatesData(this.tab_ModelConstruction.modelTypes.model_TFN.obj, data{irow,5});
                                setBoreID(this.tab_ModelConstruction.modelTypes.model_TFN.obj, data{irow,6});
                                
                            otherwise
                                warndlg('Unknown model type selected.');
                        end

                        % Set the previouslt input model oprions
                        setModelOptions(this.tab_ModelConstruction.modelTypes.model_TFN.obj, data{irow,8})
                        
                         % Show model type options.
                         this.tab_ModelConstruction.modelOptions.vbox.Heights = [0; 0;  -1];
                    otherwise
                            % Do nothing
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
                if ~strcmp(eventdata.PreviousData, eventdata.NewData) && icol~=1
                    
                    % Get original model label
                    if strcmp(columnName, 'Model Label')
                        modelLabel=eventdata.PreviousData;
                    else
                        modelLabel = hObject.Data{irow,2};
                    end
                    
                    % Check if the model object exists
                    ind = cellfun( @(x) strcmp(x.model_label,modelLabel), this.models);
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

                        % Delete models from simulations table.
                        modelLabels_simTable =  this.tab_ModelSimulation.Table.Data(:,2);                            
                        modelLabels_simTable = GST_GUI.removeHTMLTags(modelLabels_simTable);
                        ind = cellfun( @(x) strcmp(x,modelLabel), modelLabels_simTable);
                        this.tab_ModelSimulation.Table.Data = this.tab_ModelSimulation.Table.Data(~ind,:);                        
                        
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
                         this.tab_ModelConstruction.modelOptions.vbox.Heights = [0; -1 ; 0];                        
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
                        
                        % Combine names and values into a cell array;
                        %tableData = {paramsNames(:,1), paramsNames(:,2), paramValues};
                        
                        % Add to the table
                        this.tab_ModelCalibration.resultsOptions.paramTable.table.Data = cell(length(paramValues),3);
                        this.tab_ModelCalibration.resultsOptions.paramTable.table.Data(:,1) = paramsNames(:,1);
                        this.tab_ModelCalibration.resultsOptions.paramTable.table.Data(:,2) = paramsNames(:,2);
                        this.tab_ModelCalibration.resultsOptions.paramTable.table.Data(:,3) = num2cell(paramValues);
                                    
                    case {3, 4, 5, 6, 7, 8, 9}
                        % Create an axis handle for the figure.
                        delete( findobj(this.tab_ModelCalibration.resultsOptions.plots.panel.Children,'type','axes'));
                        delete( findobj(this.tab_ModelCalibration.resultsOptions.plots.panel.Children,'type','legend'));     
                        delete( findobj(this.tab_ModelCalibration.resultsOptions.plots.panel.Children,'type','uipanel'));     
                        h = uipanel('Parent', this.tab_ModelCalibration.resultsOptions.plots.panel );
                        axisHandle = axes( 'Parent', h);
                        % Show the calibration plots. NOTE: QQ plot type
                        % fails so is skipped
                        if results_item<=5
                            calibrateModelPlotResults(this.models{modelInd,1}, results_item-2, axisHandle);
                        else
                            calibrateModelPlotResults(this.models{modelInd,1}, results_item-1, axisHandle);
                        end

                    case 9
                        % do nothing
                end
            else
                this.tab_ModelCalibration.resultsOptions.box.Heights = [30 20 0 0];
            end
        end
        
        function modelCalibration_onResultsSelection(this, hObject, eventdata)
            
            % Get selected popup menu item
            listSelection = get(hObject,'Value');
                         
            switch listSelection
                case 1 %Data & residuals
                    this.tab_ModelCalibration.resultsOptions.box.Heights = [30 20 0 -1 0];
                case 2 %Parameters
                    this.tab_ModelCalibration.resultsOptions.box.Heights = [30 20 0 0 -1];                    
                case { 3, 4, 5, 6, 7, 8, 9} %Summary plots
                    this.tab_ModelCalibration.resultsOptions.box.Heights = [30 20 -1 0 0];
                otherwise %None
                    this.tab_ModelCalibration.resultsOptions.box.Heights = [30 20 0 0];
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

                        % Find index to the calibrated model label within the list of calibrated
                        % models.
                        calibLabel_all = GST_GUI.removeHTMLTags(this.tab_ModelCalibration.Table.Data(:,2));
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
                        calibLabels = this.tab_ModelCalibration.Table.Data(calibModels,2);

                        % Remove HTML tags from each model label
                        calibLabels = GST_GUI.removeHTMLTags(calibLabels);

                        % Assign calib model labels to drop down
                        hObject.ColumnFormat{2} = calibLabels;   
                        
                    case 'Forcing Data File'
                        [fName,pName] = uigetfile({'*.*'},'Select the Forcing Data file');
                        if fName~=0;
                            % Assign file name to date cell array
                            data{irow,icol} = fullfile(pName,fName);
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
            if ~isempty(simInd) && ~isempty(this.models{modelInd,1}.simulationResults{simInd,1}.head )               
                
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
                        solveModelPlotResults(this.models{modelInd,1}, simLabel, axisHandles, []);
                        
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
            
            % get the new model options
            modelOptionsArray = getModelOptions(this.tab_ModelConstruction.modelTypes.model_TFN.obj);            
            
            % Warn the user if the model is already built and the
            % inputs are to change - reuiring the model object to be
            % removed.            
            irow = this.tab_ModelConstruction.currentRow;
            if ~strcmp(modelOptionsArray, this.tab_ModelConstruction.Table.Data{irow,8} )

                % Get original model label
                modelLabel = this.tab_ModelConstruction.Table.Data{irow,2};

                % Check if the model object exists
                ind = cellfun( @(x) strcmp(x.model_label,modelLabel), this.models);
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

                    % Delete models from simulations table.
                    modelLabels_simTable =  this.tab_ModelSimulation.Table.Data(:,2);                            
                    modelLabels_simTable = GST_GUI.removeHTMLTags(modelLabels_simTable);
                    ind = cellfun( @(x) strcmp(x,modelLabel), modelLabels_simTable);
                    this.tab_ModelSimulation.Table.Data = this.tab_ModelSimulation.Table.Data(~ind,:);                    
                end
            end
            
            % Apply new model options.
            this.tab_ModelConstruction.Table.Data{this.tab_ModelConstruction.currentRow,8} = modelOptionsArray;

        end
        
        % Get the model options cell array (as a string).
        function onApplyModelOptions_selectedBores(this, hObject, eventdata)
            
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
                    if ~strcmp(modelOptionsArray, this.tab_ModelConstruction.Table.Data{i,8} )

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

                            % Delete models from simulations table.
                            modelLabels_simTable =  this.tab_ModelSimulation.Table.Data(:,2);                            
                            modelLabels_simTable = GST_GUI.removeHTMLTags(modelLabels_simTable);
                            ind = cellfun( @(x) strcmp(x,modelLabel), modelLabels_simTable);
                            this.tab_ModelSimulation.Table.Data = this.tab_ModelSimulation.Table.Data(~ind,:);
                            
                        end
                    end                    
                    
                    % Apply model option.
                    this.tab_ModelConstruction.Table.Data{i,8} = modelOptionsArray;            
                    nOptionsCopied = nOptionsCopied + 1;
                end
            end            
            
            msgbox(['The model options were copied to ',num2str(nOptionsCopied), ' "', currentModelType ,'" models.'], 'Summary of model options applied to bores...');
        end

        
        function onBuildModels(this, hObject, eventdata)
            
            % Get table data
            data = this.tab_ModelConstruction.Table.Data;
            
            % Get list of selected bores.
            selectedBores = data(:,1);
                                        
            % Loop  through the list of selected bore and apply the modle
            % options.
            nModelsBuilt = 0;
            nModelsBuiltFailed = 0;
            for i=1:length(selectedBores);
                % Check if the model is to be built.
                if ~selectedBores{i}
                    continue;
                end

                % Update table with progress'
                this.tab_ModelConstruction.Table.Data{i, 9} = '<html><font color = "#FFA500">Building model ...</font></html>';
                
                % Import head data
                %----------------------------------------------------------
                % Check the obs. head file is listed
                fname = data{i,3};
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
                
                %----------------------------------------------------------
                
                % Import forcing data
                %----------------------------------------------------------
                % Check fname file exists.
                fname = data{i,4};
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
                fname = data{i,5};
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
                if isempty(this.models)
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
                        cell(1,13)];
                        isModelListed = size(this.tab_ModelCalibration.Table.Data,1);
                        
                        this.tab_ModelCalibration.Table.Data{isModelListed,2} = ['<html><font color = "#808080">',model_label,'</font></html>'];
                        this.tab_ModelCalibration.Table.Data{isModelListed,3} = ['<html><font color = "#808080">',boreID,'</font></html>'];
                        this.tab_ModelCalibration.Table.Data{isModelListed,4} = ['<html><font color = "#808080">',datestr(obshead_start,'dd-mmm-yyyy'),'</font></html>'];
                        this.tab_ModelCalibration.Table.Data{isModelListed,5} = ['<html><font color = "#808080">',datestr(obshead_end,'dd-mmm-yyyy'),'</font></html>'];
                        this.tab_ModelCalibration.Table.Data{isModelListed,6} = datestr(obshead_start,'dd-mmm-yyyy');
                        this.tab_ModelCalibration.Table.Data{isModelListed,7} = datestr(obshead_end,'dd-mmm-yyyy');
                        this.tab_ModelCalibration.Table.Data{isModelListed,8} = 1;
                    else
                        this.tab_ModelCalibration.Table.Data{isModelListed,3} = ['<html><font color = "#808080">',boreID,'</font></html>'];
                        this.tab_ModelCalibration.Table.Data{isModelListed,4} = ['<html><font color = "#808080">',datestr(obshead_start,'dd-mmm-yyyy'),'</font></html>'];
                        this.tab_ModelCalibration.Table.Data{isModelListed,5} = ['<html><font color = "#808080">',datestr(obshead_end,'dd-mmm-yyyy'),'</font></html>'];
                    end
                    this.tab_ModelCalibration.Table.Data{isModelListed,9} = '<html><font color = "#FF0000">Not calibrated.</font></html>';
                    
                    
                    this.tab_ModelConstruction.Table.Data{i, 9} = '<html><font color = "#008000">Model built.</font></html>';
                    nModelsBuilt = nModelsBuilt + 1; 
                    
                catch ME
                    nModelsBuiltFailed = nModelsBuiltFailed + 1;
                    this.tab_ModelConstruction.Table.Data{i, 9} = ['<html><font color = "#FF0000">Model build failed - ', ME.message,'</font></html>'];
                end
            end
            
            % Report Summary
            msgbox(['The model was successfully built for ',num2str(nModelsBuilt), ' models and failed for ',num2str(nModelsBuiltFailed), ' models.'], 'Summary of model builds ...');
            
        end
        
        function onCalibModels(this, hObject, eventdata)
            
            % Get table data
            data = this.tab_ModelCalibration.Table.Data;
            
            % Get list of selected bores.
            selectedBores = data(:,1);
                                        
            % Loop  through the list of selected bore and apply the modle
            % options.
            nModelsCalib = 0;
            nModelsCalibFailed = 0;
            for i=1:length(selectedBores);
                
                % Check if the model is to be calibrated.
                if ~selectedBores{i}
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
                    this.tab_ModelCalibration.Table.Data{i,9} = '<html><font color = "#FF0000">Calib. failed - Model appears not to have been built.</font></html>';
                    continue;
                end    

                
                % Get start and end date. Note, start date is at the start
                % of the day and end date is shifted to the end of the day.
                calibStartDate = datenum( data{i,6},'dd-mmm-yyyy');
                calibEndDate = datenum( data{i,7},'dd-mmm-yyyy') + datenum(0,0,0,23,59,59);
                CMAES_restarts = data{i,8};
                try
                    
                    this.tab_ModelCalibration.Table.Data{i,9} = '<html><font color = "#FFA500">Calibrating ... </font></html>';
                    
                    % Update status in GUI
                    drawnow
                    
                    calibrateModel( this.models{ind,1}, calibStartDate, calibEndDate, CMAES_restarts);
                    
                    this.tab_ModelCalibration.Table.Data{i,9} = '<html><font color = "#008000">Calibrated. </font></html>';

                    % Set calib performance stats.
                    calibAIC = this.models{ind, 1}.calibrationResults.performance.AIC;
                    calibCoE = this.models{ind, 1}.calibrationResults.performance.CoeffOfEfficiency_mean.CoE;
                    this.tab_ModelCalibration.Table.Data{i,10} = ['<html><font color = "#808080">',num2str(calibCoE),'</font></html>'];
                    this.tab_ModelCalibration.Table.Data{i,12} = ['<html><font color = "#808080">',num2str(calibAIC),'</font></html>'];

                    % Set eval performance stats
                    if isfield(this.models{1, 1}.evaluationResults,'performance')
                        evalAIC = this.models{ind, 1}.evaluationResults.performance.AIC;
                        evalCoE = this.models{ind, 1}.evaluationResults.performance.CoeffOfEfficiency_mean.CoE_unbias;                    
                        
                        this.tab_ModelCalibration.Table.Data{i,11} = ['<html><font color = "#808080">',num2str(evalCoE),'</font></html>'];
                        this.tab_ModelCalibration.Table.Data{i,13} = ['<html><font color = "#808080">',num2str(evalAIC),'</font></html>'];
                    else
                        evalCoE = '(NA)';
                        evalAIC = '(NA)';
                        
                        this.tab_ModelCalibration.Table.Data{i,11} = ['<html><font color = "#808080">',evalCoE,'</font></html>'];
                        this.tab_ModelCalibration.Table.Data{i,13} = ['<html><font color = "#808080">',evalAIC,'</font></html>'];
                    end
                    nModelsCalib = nModelsCalib +1;
                    
                    % Update status in GUI
                    drawnow
                    
                catch ME
                    nModelsCalibFailed = nModelsCalibFailed +1;
                    this.tab_ModelCalibration.Table.Data{i,9} = ['<html><font color = "#FF0000">Calib. failed - ', ME.message,'</font></html>'];
                end
            end
            
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
            
            % Loop  through the list of selected bore and apply the model
            % options.
            nModelsSim = 0;
            nModelsSimFailed = 0;
            for i=1:length(selectedBores);                                
                
                % Check if the model is to be simulated.
                if ~selectedBores{i}
                    continue;
                end
                
                this.tab_ModelSimulation.Table.Data{i,end} = '<html><font color = "#FFA500">Simulating ... </font></html>';
                
                % Get the simulation options
                obsHeadStartDate = GST_GUI.removeHTMLTags( data{i,4} );
                obsHeadStartDate = datenum( obsHeadStartDate,'dd-mmm-yyyy');
                obsHeadEndDate = GST_GUI.removeHTMLTags( data{i,5} );
                obsHeadEndDate = datenum( obsHeadEndDate,'dd-mmm-yyyy') + datenum(0,0,0,23,59,59);                
                simLabel = data{i,6};
                forcingdata_fname = data{i,7};
                simStartDate = datenum( data{i,8},'dd-mmm-yyyy');
                simEndDate = datenum( data{i,9},'dd-mmm-yyyy') + datenum(0,0,0,23,59,59);
                simTimeStep = data{i,10};

                % Get the selected model for simulation
                calibLabel = data{i,2};

                % Find index to the calibrated model label within the list of calibrated
                % models.
                calibLabel_all = GST_GUI.removeHTMLTags(this.tab_ModelCalibration.Table.Data(:,2));
                ind = cellfun(@(x) strcmp(calibLabel, x), calibLabel_all);
                if all(~ind)
                   nModelsSimFailed = nModelsSimFailed +1;
                   this.tab_ModelSimulation.Table.Data{i,end} = ['<html><font color = "#FF0000">Sim. failed - Model could not be found. Please rebuild and calibrate it.</font></html>'];
                   continue;
                end                
                
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
                    if exist(forcingdata_fname,'file') ~= 2;                   
                        this.tab_ModelSimulation.Table.Data{i,end} = '<html><font color = "#FF0000">Sim. failed - The new forcing date file could not be open.</font></html>';
                        nModelsSimFailed = nModelsSimFailed +1;
                        continue;
                    end

                    % Read in the file.
                    try
                       forcingData = readtable(forcingdata_fname);
                    catch                   
                        this.tab_ModelSimulation.Table.Data{i,end} = '<html><font color = "#FF0000">Sim. failed - The new forcing date file could not be imported.</font></html>';
                        nModelsSimFailed = nModelsSimFailed +1;
                        continue;                        
                    end                    
                    
                    % Convert data to matrix
                    forcingData_colnames = forcingData.Properties.VariableNames;
                    forcingData = table2array(forcingData);
                else
                    % Set forcing used to empty. This will cause the
                    % calibration data to be used.
                    forcingData = [];
                    forcingData_colnames = [];
                end
                                    
               % Get the start and end dates for the simulation.
               if isempty(simStartDate)
                   simStartDate = obsHeadStartDate;
               end
               if isempty(simEndDate)
                   simEndDate = obsHeadEndDate;
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
                       i=1;
                       simTimePoints(i,1:3) = [iyear, imonth, iday];
                       while iyear <= endYear || imonth <= endMonth || iday <= endDay
                          
                           if imonth == 12
                               imonth = 1;
                               iyear = iyear + 1;
                           else
                               imonth = imonth + 1;
                           end
                           i=i+1;
                           simTimePoints(i,1:3) = [iyear, imonth, iday];                           
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
                   
                   solveModel(this.models{ind}, simTimePoints, forcingData, forcingData_colnames, simLabel, doKrigingOfResiduals);                   
                    
                   this.tab_ModelSimulation.Table.Data{i,end} = '<html><font color = "#008000">Simulated. </font></html>';
                   
                   nModelsSim = nModelsSim + 1;
                                      
               catch ME
                   nModelsSimFailed = nModelsSimFailed +1;
                   this.tab_ModelSimulation.Table.Data{i,end} = ['<html><font color = "#FF0000">Sim. failed - ', ME.message,'</font></html>']; '<html><font color = "#FF0000">Failed. </font></html>';                       
               end
                       
               
            end
            
            % Report Summary
            msgbox(['The simulations were successfull for ',num2str(nModelsSim), ' models and failed for ',num2str(nModelsSimFailed), ' models.'], 'Summary of model simulaions...');

        end
        
        function onImportTable(this, hObject, eventdata)
        
            
            % Create the label for each type of inport
            switch hObject.Tag
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
                    
                    % Output Summary.
                    msgbox({['Calibration data was imported to ',num2str(nImportedRows), ' rows.'], ...
                            ['   Number of model labels not found in the calibration table: ',num2str(nModelsNotFound) ], ...
                            ['   Number of rows were the bore IDs did not match: ',num2str(nBoresNotMatching) ], ...
                            ['   Number of rows were existing calibration results were deleted: ',num2str(nCalibBoresDeleted) ]}, 'Summary of model calibration importing ...');
                    
                case 'Model Simulation'
                    

                    if size(tbl,2) ~=11
                        warndlg('The table datafile must have 11 columns. That is, all columns shown in the table.');
                        return;
                    end
                    
                    % Loop through each row in tbl and find the
                    % corresponding model within the GUI table and the add
                    % the user data to the columns of the row.
                    nModelsNotCalib = 0;
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
                        
                        % Append table. Note: the select column is input as a logical 
                        tbl{i,end} = {'<html><font color = "#FF0000">Not simulated.</font></html>'};   
                        if tbl{i,1}==1
                            this.tab_ModelSimulation.Table.Data = [this.tab_ModelSimulation.Table.Data; true, table2cell(tbl(i,2:end))];
                        else
                            this.tab_ModelSimulation.Table.Data = [this.tab_ModelSimulation.Table.Data; false, table2cell(tbl(i,2:end))];
                        end
                        nImportedRows = nImportedRows + 1;
                    end

                    % Update row numbers.
                    nrows = size(this.tab_ModelSimulation.Table.Data,1);
                    this.tab_ModelSimulation.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                            
                                            
            end
             

                    
        end
        
        function onExportTable(this, hObject, eventdata)
            % Create the label for each type of inport
            switch hObject.Tag
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

            % Get output file name
            'Input the .csv file name for results file.';
            [fName,pName] = uiputfile({'*.csv'},windowString); 
            if fName~=0;
                % Assign file name to date cell array
                filename = fullfile(pName,fName);
            else
                return;
            end                       
            

            % Export results
            switch hObject.Tag
                case 'Model Calibration'

                    % Open file and write headers
                    fileID = fopen(filename,'w');
                    fprintf(fileID,'Year,Month,Day,Hour,Minute,Obs_Head,Is_Calib_Point?,Calib_Head,Eval_Head,Model_Err,Noise_Lower,Noise_Upper');                    
                    fclose(fileID);
                    
                    % Loop through each row of the calibration table and
                    % export the calibration results (if calibrated)
                    nrows = size(this.tab_ModelConstruction.Table.Data,1);
                    nResultsWritten=0;
                    for i=1:nrows
                       
                        % get model label.
                        modelLabel = this.tab_ModelConstruction.Table.Data{i,2};
                        
                        % Find object for the model.
                        ind = cellfun( @(x) strcmp(x.model_label,modelLabel), this.models);
                        if ~isempty(ind) && ...
                        ~isempty(this.models{ind}.calibrationResults) && ...
                        this.models{ind}.calibrationResults.isCalibrated                        
                                                   
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
                   
                            % write data to the file
                            dlmwrite(filename,tableData,'-append');          
                            nResultsWritten = nResultsWritten + 1;
                            
                        end        
                    end
                    
                    % Show summary
                    msgbox({'Export of results finished.','',['Number of model resulted exported =',num2str(nResultsWritten)]},'Export Summary');
                    
                    
                case 'Model Simulation'

                    
                    
                otherwise
                    warndlg('Unexpected Error: GUI table type unknown.');
                    return                    
            end
            
            
        end
        
        function onDocumentation(this, hObject, eventdata)
           doc model_TFN 
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
        
        function rowAddDelete(this, hObject, eventdata)
           
            % Get the table object from UserData
            tableObj = eval(eventdata.Source.Parent.UserData);            
            
            % Get selected rows
            selectedRows = cell2mat(tableObj.Data(:,1));

            % Check if any rows are selected. Note, if not then
            % rows will be added (for all but the calibration
            % table).
            anySelected = any(selectedRows);
            indSelected = find(selectedRows);
            
            if size(tableObj.Data(:,1),1)>0 &&  ~anySelected && ~strcmp(hObject.Label,'Paste rows')
                warning('No rows are selected for the requested operation.');
                return;
            elseif size(tableObj.Data(:,1),1)==0 ...
            &&  (strcmp(hObject.Label, 'Copy selected row') || strcmp(hObject.Label, 'Delete selected rows'))                
                return;
            end               
            
            % Define the input for the status column
            switch tableObj.Tag
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
                        warning('The copied row data was sourced from a different table.');
                        return;
                    end    
                    
                    if sum(selectedRows)>1
                        warning('When pasting to selected rows, only one row can be copied.');
                        return;
                    end
                    
                    % Paste data and update model build status
                    switch this.copiedData.tableName
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
                                    this.copiedData.data{i,11} = modelStatus;
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
                                    tableObj.Data{irow,11} = modelStatus;                                    
                                end
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
                                             cell(1,size(tableObj.Data,2)); ...
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
                                             cell(1,size(tableObj.Data,2)); ...
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
            selectedRows = cell2mat(tableObj.Data(:,1));
            
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

