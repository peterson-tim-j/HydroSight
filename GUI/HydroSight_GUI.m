classdef HydroSight_GUI < handle  
    %HydroSight_GUI Summary of this class goes here
    %   Detailed explanation goes here
    
    %class properties - access is private so nothing else can access these
    %variables. Useful in different sitionations
    properties
        % Version number
        versionNumber = '1.3.4';
        versionDate= '29 May 2019';
        
        % Model types supported
        %modelTypes = {'model_TFN','model_TFN_LOA', 'ExpSmooth'};
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
        models=[];
        
        % Store a record of the model lables (as row names in a tavle) and
        % if the models are calibrated.
        model_labels=[];
        
        % Store the data preparation analysis results;
        dataPrep
        
        % Copies of data
        copiedData = {};
        
        % Setting for off loading calibration to HPC cluster
        HPCoffload = {};
        
        % File name for the current set of models
        project_fileName = '';
        
        % Are the models to be stored on HDD
        modelsOnHDD = '';
    end
    
    % Events
    events
       quitModelCalibration 
    end
    
    methods
        
        function this = HydroSight_GUI
            
%             % Check the toolbox for GUIs exists
%             if ~isdeployed && isempty(ver('layout'))
%                 msgbox({'The following toolbox file must be installed within Matlab to use.', ...
%                     'HydroSight. Please download and install it and then re-start', ...
%                     'HydroSight. Also, a web browser will now open at the toolbox site.', ...
%                     '', ...
%                     'https://www.mathworks.com/matlabcentral/fileexchange/47982-gui-layout-toolbox'}, ...
%                 'Toolbox missing: gui-layout-toolbox', 'error');
%             
%                 web( 'https://www.mathworks.com/matlabcentral/fileexchange/47982-gui-layout-toolbox' ) 
%                 
%                 return
%             end

            
            %--------------------------------------------------------------
            % Open a window and add some menus
            this.Figure = figure( ...
                'Name', 'HydroSight', ...
                'NumberTitle', 'off', ...
                'MenuBar', 'none', ...
                'HandleVisibility', 'off', ...
                'Visible','off', ...
                'Toolbar','figure', ...
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
            %this.Figure.Visible = 'off';
            
            
            % Set default panel color
            %warning('off');
            %uiextras.set( this.Figure, 'DefaultBoxPanelTitleColor', [0.7 1.0 0.7] );
            %warning('on');
            
            % + File menu
            this.figure_Menu = uimenu( this.Figure, 'Label', 'File' );
            uimenu( this.figure_Menu, 'Label', 'New Project', 'Callback', @this.onNew);
            uimenu( this.figure_Menu, 'Label', 'Set Project Folder ...', 'Callback', @this.onSetProjectFolder);
            uimenu( this.figure_Menu, 'Label', 'Open Project...', 'Callback', @this.onOpen);
            uimenu( this.figure_Menu, 'Label', 'Import Model(s) ...', 'Callback', @this.onImportModel);
            uimenu( this.figure_Menu, 'Label', 'Save Project as ...', 'Callback', @this.onSaveAs );
            uimenu( this.figure_Menu, 'Label', 'Save Project', 'Callback', @this.onSave,'Enable','off');
            uimenu( this.figure_Menu, 'Label', 'Move models from RAM to HDD...', 'Callback', @this.onMoveModels,'Separator','on', 'Enable','off');
            uimenu( this.figure_Menu, 'Label', 'Exit', 'Callback', @this.onExit,'Separator','on' );

            % + Examples menu
            this.figure_examples = uimenu( this.Figure, 'Label', 'Examples' );
            uimenu( this.figure_examples, 'Label', 'TFN model - Landuse change', 'Tag','TFN - LUC','Callback', @this.onExamples );
            uimenu( this.figure_examples, 'Label', 'TFN model - Pumping and climate', 'Tag','TFN - Pumping','Callback', @this.onExamples );

            % + Help menu
            this.figure_Help = uimenu( this.Figure, 'Label', 'Help' );
            uimenu(this.figure_Help, 'Label', 'Overview', 'Tag','doc_Overview','Callback', @this.onDocumentation);
            uimenu(this.figure_Help, 'Label', 'User Interface', 'Tag','doc_GUI','Callback', @this.onDocumentation);
            uimenu(this.figure_Help, 'Label', 'Data requirements', 'Tag','doc_data_req','Callback', @this.onDocumentation);            
            uimenu(this.figure_Help, 'Label', 'Time-series algorithms', 'Tag','doc_timeseries_algorithms','Callback', @this.onDocumentation);                
            uimenu(this.figure_Help, 'Label', 'Tutorials', 'Tag','doc_tutes','Callback', @this.onDocumentation);                            
            uimenu(this.figure_Help, 'Label', 'Calibration Fundementals','Tag','doc_Calibration','Callback', @this.onDocumentation);            
            uimenu(this.figure_Help, 'Label', 'Support', 'Tag','doc_Support','Callback', @this.onDocumentation);                            
            uimenu(this.figure_Help, 'Label', 'Publications', 'Tag','doc_Publications','Callback', @this.onDocumentation);                
            
            uimenu(this.figure_Help, 'Label', 'Check for updates at GitHub', 'Tag','doc_GitHubUpdate','Callback', @this.onGitHub,'Separator','on');
            uimenu(this.figure_Help, 'Label', 'Submit bug report to GitHub', 'Tag','doc_GitHubIssue','Callback', @this.onGitHub);
            
            
            uimenu(this.figure_Help, 'Label', 'License and Disclaimer', 'Tag','doc_Publications','Callback', @this.onLicenseDisclaimer,'Separator','on');
            uimenu(this.figure_Help, 'Label', 'Version', 'Tag','doc_Version','Callback', @this.onVersion);
            uimenu(this.figure_Help, 'Label', 'About', 'Callback', @this.onAbout );
                        
            % Get toolbar object
            hToolbar = findall(this.Figure,'tag','FigureToolBar');
            
            % Hide toolbar button not used (2018B prior and after)
            hToolbutton = findall(hToolbar,'tag','Annotation.InsertLegend');            
            hToolbutton.Visible = 'off';
            hToolbutton.UserData = 'Never';
            hToolbutton.Separator = 'off';
            hToolbutton = findall(hToolbar,'tag','Annotation.InsertColorbar');            
            hToolbutton.Visible = 'off';
            hToolbutton.UserData = 'Never';
            hToolbutton.Separator = 'off';
            hToolbutton = findall(hToolbar,'tag','DataManager.Linking');            
            hToolbutton.Visible = 'off';
            hToolbutton.UserData = 'Never';	
            hToolbutton.Separator = 'off';      
            hToolbutton = findall(hToolbar,'tag','Standard.EditPlot');            
            hToolbutton.Visible = 'off';
            hToolbutton.UserData = 'Plot';
            hToolbutton.Separator = 'off';            
            
            % Redefine print button
            hToolbutton = findall(hToolbar,'tag','Standard.PrintFigure');            
            set(hToolbutton, 'ClickedCallback',@this.onPrint, 'TooltipString','Open the print preview window for the displayed plot ...');
            hToolbutton.Visible = 'off';
            hToolbutton.UserData = 'Plot';
            hToolbutton.Separator = 'off';
            icon = 'implay_export.gif';
            [cdata,map] = imread(icon);
            map(find(map(:,1)+map(:,2)+map(:,3)==3)) = NaN;
            cdata = ind2rgb(cdata,map);
            
            
            % Check if version is 2018b or later. From this point the
            % plot toolbar buttons moved into the plot.
            v=version();
            isBefore2018b = str2double(v(1:3))<9.5;           
            
            % Hide property inspector
            try 
                hToolbutton = findall(hToolbar,'tag','Standard.OpenInspector');            
                hToolbutton.Visible = 'off';
                hToolbutton.UserData = 'Plot';
                hToolbutton.Separator = 'off';            
            catch
                % do nothing
            end
                
            
            % Add tool bar          
            if isBefore2018b
                hToolbutton = findall(hToolbar,'tag','Plottools.PlottoolsOn');                        
                hToolbutton.Visible = 'off';
                hToolbutton.UserData = 'Plot';	
                hToolbutton.Separator = 'off';
                hToolbutton = findall(hToolbar,'tag','Plottools.PlottoolsOff');            
                hToolbutton.Visible = 'off';
                hToolbutton.UserData = 'Never';	
                hToolbutton.Separator = 'off';
                hToolbutton = findall(hToolbar,'tag','Exploration.Brushing');            
                hToolbutton.Visible = 'off';
                hToolbutton.UserData = 'Plot';
                hToolbutton.Separator = 'off';
                hToolbutton = findall(hToolbar,'tag','Exploration.DataCursor');            
                hToolbutton.Visible = 'off';
                hToolbutton.UserData = 'Plot';
                hToolbutton.Separator = 'off';
                hToolbutton = findall(hToolbar,'tag','Exploration.Rotate');            
                hToolbutton.Visible = 'off';
                hToolbutton.UserData = 'Never';
                hToolbutton.Separator = 'off';
                hToolbutton = findall(hToolbar,'tag','Exploration.Pan');            
                hToolbutton.Visible = 'off';
                hToolbutton.UserData = 'Plot';
                hToolbutton.Separator = 'off';
                hToolbutton = findall(hToolbar,'tag','Exploration.ZoomOut');            
                hToolbutton.Visible = 'off';
                hToolbutton.UserData = 'Plot';
                hToolbutton.Separator = 'off';
                hToolbutton = findall(hToolbar,'tag','Exploration.ZoomIn');            
                hToolbutton.Visible = 'off';
                hToolbutton.UserData = 'Plot';
                hToolbutton.Separator = 'off';
                uipushtool(hToolbar,'cdata',cdata, 'tooltip','Export displayed plot to PNG file ...', ...
                    'ClickedCallback',@this.onExportPlot, ...
                    'tag','Export.plot', 'Visible','off');
            end

            hToolbutton = findall(hToolbar,'tag','Standard.NewFigure');            
            hToolbutton.Visible = 'on';
            hToolbutton.UserData = 'Always';	                            
            set(hToolbutton, 'ClickedCallback',@this.onNew, 'TooltipString','Start a new project.');            
            
            hToolbutton = findall(hToolbar,'tag','Standard.FileOpen');            
            hToolbutton.Visible = 'on';
            hToolbutton.UserData = 'Always';	                            
            set(hToolbutton, 'ClickedCallback',@this.onOpen, 'TooltipString','Open a new project ...');

            hToolbutton = findall(hToolbar,'tag','Standard.SaveFigure');            
            hToolbutton.Visible = 'on';
            hToolbutton.UserData = 'Always';	                            
            set(hToolbutton, 'ClickedCallback',@this.onSave, 'TooltipString','Save current project ...');            
            
            % Get hidden state and show hidden children
            oldState = get(0,'ShowHiddenHandles');
            set(0,'ShowHiddenHandles','on')
            
            % Add new button for 'st folder and shift new button to the far left.
            icon = 'foldericon.gif';
            [cdata,map] = imread(icon);
            map(find(map(:,1)+map(:,2)+map(:,3)==3)) = NaN;
            cdata = ind2rgb(cdata,map);
            uipushtool(hToolbar,'cdata',cdata, 'tooltip','Set the project folder ...','Tag','Standard.SetFolder','ClickedCallback',@this.onSetProjectFolder);
            hToolbutton = findall(hToolbar);            
            set(hToolbar,'Children',hToolbutton([3:length(hToolbutton), 2]));            
                                    
            % Add new button for help.
            icon = 'helpicon.gif';
            [cdata,map] = imread(icon);
            map(find(map(:,1)+map(:,2)+map(:,3)==3)) = NaN;
            cdata = ind2rgb(cdata,map);
            uipushtool(hToolbar,'cdata',cdata, 'tooltip','Open help for the current tab ...', 'ClickedCallback',@this.onDocumentation);
            
            % Add separator.
            if isBefore2018b
                hToolbar.Children(13).Separator = 'on';
            end
            
            % Reset hidden state
            set(0,'ShowHiddenHandles',oldState);
            
            %Create Panels for different windows       
            this.figure_Layout = uiextras.TabPanel( 'Parent', this.Figure, 'Padding', ...
                5, 'TabSize',127,'FontSize',8);
            this.tab_Project.Panel = uiextras.Panel( 'Parent', this.figure_Layout, 'Padding', 5, 'Tag','ProjectDescription');            
            this.tab_DataPrep.Panel = uiextras.Panel( 'Parent', this.figure_Layout, 'Padding', 5, 'Tag','DataPreparation');
            this.tab_ModelConstruction.Panel = uiextras.Panel( 'Parent', this.figure_Layout, 'Padding', 5, 'Tag','ModelConstruction');
            this.tab_ModelCalibration.Panel = uiextras.Panel( 'Parent', this.figure_Layout, 'Padding', 5, 'Tag','ModelCalibration');
            this.tab_ModelSimulation.Panel = uiextras.Panel( 'Parent', this.figure_Layout, 'Padding', 5, 'Tag','ModelSimulation');
            this.figure_Layout.TabNames = {'Project Description', 'Outlier Removal','Model Construction', 'Model Calibration','Model Simulation'};
            this.figure_Layout.SelectedChild = 1;
           
%%          Layout Tab1 - Project description
            %------------------------------------------------------------------
            % Project title
            hbox1t1 = uiextras.VBoxFlex('Parent', this.tab_Project.Panel,'Padding', 3, 'Spacing', 3);
            uicontrol(hbox1t1,'Style','text','String','Project Title: ','HorizontalAlignment','left', 'Units','normalized');            
            this.tab_Project.project_name = uicontrol(hbox1t1,'Style','edit','HorizontalAlignment','left', 'Units','normalized',...
                'TooltipString','Input a project title. This is an optional input to assist project management.');            
            
            % Empty row spacer
            uicontrol(hbox1t1,'Style','text','String','','Units','normalized');                      
                        
            % Project description
            uicontrol(hbox1t1,'Style','text','String','Project Description: ','HorizontalAlignment','left', 'Units','normalized');                      
            this.tab_Project.project_description = uicontrol(hbox1t1,'Style','edit','HorizontalAlignment','left', 'Units','normalized', ...
                'Min',1,'Max',100,'TooltipString','Input an extended project description. This is an optional input to assist project management.');            
            
            % Set sizes
            set(hbox1t1, 'Sizes', [20 20 20 20 -1]);            
            
            

%%          Layout Tab2 - Data Preparation
            % -----------------------------------------------------------------
            % Declare panels        
            hbox1t2 = uiextras.HBoxFlex('Parent', this.tab_DataPrep.Panel,'Padding', 3, 'Spacing', 3,'Tag','Outlier detection outer hbox');
            vbox1t2 = uiextras.VBox('Parent',hbox1t2,'Padding', 3, 'Spacing', 3);
            %hbox3t2 = uiextras.HButtonBox('Parent',vbox1t2,'Padding', 3, 'Spacing', 3);                
            hbox3t2 = uiextras.HBox('Parent',vbox1t2,'Padding', 3, 'Spacing', 3);
            hboxBtn1 = uiextras.HButtonBox('Parent',hbox3t2 ,'Padding', 3, 'Spacing', 3);             
            hboxBtn2 = uiextras.HButtonBox('Parent',hbox3t2 ,'Padding', 3, 'Spacing', 3);              
            
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
                        '<html><center>Check Above<br />Bore Depth?</center></html>', ...                      
                        '<html><center>Check Below <br />Casing?</center></html>', ...                      
                        '<html><center>Threshold for Max. Daily abs(Head)<br />Change</center></html>', ...
                        '<html><center>Threshold Duration for<br />Constant Head (days)?</center></html>', ...
                        '<html><center>Auto-Outlier<br />Num. St. dev?</center></html>', ...                        
                        '<html><center>Auto-Outlier foward<br />backward analysis?</center></html>', ...                        
                        '<html><center>Analysis<br />Status</center></html>', ...
                        '<html><center>No. Erroneous<br />Obs.</center></html>', ...
                        '<html><center>No. Outlier<br />Obs.</center></html>', ...
                        };
            cformats1t2 = {'logical', 'char', 'char','numeric','numeric','numeric','char','logical','logical','logical','logical','numeric','numeric','numeric','logical','char','char','char'};
            cedit1t2 = logical([1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 0 0 0]);            
            rnames1t2 = {[1]};
            toolTipStr = ['<html>Optional detection and removal<br>' ...
                  'of erroneous groundwater level observations.</ul>'];
            
            % Initialise data.
            data = {false, '', '',0, 0, 0, '01/01/1900',true, true, true, true, 10, 120, 4, 1,...
                '<html><font color = "#FF0000">Bore not analysed.</font></html>', ...
                ['<html><font color = "#808080">','(NA)','</font></html>'], ...
                ['<html><font color = "#808080">','(NA)','</font></html>']};
            
            % Add table. Importantly, this is done using createTable, not
            % uitable. This was required to achieve acceptable perforamnce
            % for large tables.            
%             this.tab_DataPrep.Table = createTable(vbox1t2,cnames1t2,data, false, ...
%                 'ColumnEditable',cedit1t2,'ColumnFormat',cformats1t2,'RowName', rnames1t2, ...
%                 'CellSelectionCallback', @this.dataPrep_tableSelection,...
%                 'Tag','Data Preparation', 'TooltipString', toolTipStr);     

            this.tab_DataPrep.Table = uitable(vbox1t2 , 'ColumnName', cnames1t2,'Data', data, ...
                'ColumnEditable',cedit1t2,'ColumnFormat',cformats1t2,'RowName', rnames1t2, ...
                'CellSelectionCallback', @this.dataPrep_tableSelection,...
                'Tag','Data Preparation', 'TooltipString', toolTipStr);
                        
%             % Find java sorting object in table
%             try
%                 this.figure_Layout.Selection = 2;
%                 drawnow update;
%                 jscrollpane = findjobj(this.tab_DataPrep.Table);
%                 jtable = jscrollpane.getViewport.getView;
% 
%                 % Turn the JIDE sorting on
%                 jtable.setSortable(true);
%                 jtable.setAutoResort(true);
%                 jtable.setMultiColumnSortable(true);
%                 jtable.setPreserveSelectionsAfterSorting(true);            
%             catch
%                 warndlg('Creating of the GUI row-sorting module failed for the data preparation table.');
%             end            
                        
            % Add buttons to top left panel               
            uicontrol('Parent',hboxBtn2,'String','Append Table Data','Callback', @this.onImportTable, 'Tag','Data Preparation', 'TooltipString', sprintf('Append a .csv file of table data to the table below. \n Use this feature to efficiently analyse a large number of bores.') );
            uicontrol('Parent',hboxBtn2,'String','Export Table Data','Callback', @this.onExportTable, 'Tag','Data Preparation', 'TooltipString', sprintf('Export a .csv file of the table below.') );
            uicontrol('Parent',hboxBtn2,'String','Analyse Selected Bores','Callback', @this.onAnalyseBores, 'Tag','Data Preparation', 'TooltipString', sprintf('Use the tick-box below to select the models to analyse then click here. \n After analysing, the status is given in the right most column.') );            
            uicontrol('Parent',hboxBtn2,'String','Export Selected Results','Callback', @this.onExportResults, 'Tag','Data Preparation', 'TooltipString', sprintf('Export a .csv file of the analyses results. \n After analysing, the .csv file can be used in the time-series modelling.') );            
            uicontrol('Parent',hboxBtn1,'Style','slider','Min',0.05,'Max',0.95,'Value',0.5,'Tag','WidthofPanelConstruct', ...
                'Callback', {@this.onChangeTableWidth, 'Outlier detection outer hbox'} , 'TooltipString', 'Adjust table width');                                                     
            hboxBtn1.ButtonSize(1) = 225;
            hboxBtn2.ButtonSize(1) = 225;
            set(hbox3t2,'Sizes',[90 -1])  
            
            % Create vbox for the various model options
            this.tab_DataPrep.modelOptions.vbox = uiextras.VBoxFlex('Parent',hbox1t2,'Padding', 3, 'Spacing', 3, 'DividerMarkings','off');
            
            % Add model options panel for bore IDs
            dynList = [];
            vbox4t2 = uiextras.VBox('Parent',this.tab_DataPrep.modelOptions.vbox, 'Padding', 3, 'Spacing', 3, 'Visible','on');
            uicontrol( 'Parent', vbox4t2,'Style','text','String',sprintf('%s\n%s%s','Please select the Bore ID for the analysis:'), 'Units','normalized');            
            this.tab_DataPrep.modelOptions.boreIDList = uicontrol('Parent',vbox4t2,'Style','list','BackgroundColor','w', ...
                'String',dynList(:),'Value',1,'Callback',...
                @this.dataPrep_optionsSelection, 'Units','normalized');     
            
             % Create vbox for showing a table of results and plotting hydrographs
            this.tab_DataPrep.modelOptions.resultsOptions.box = uiextras.VBoxFlex('Parent', this.tab_DataPrep.modelOptions.vbox,'Padding', 3, 'Spacing', 3, 'DividerMarkings','off');
            panelt2 = uipanel('Parent',this.tab_DataPrep.modelOptions.resultsOptions.box);
            this.tab_DataPrep.modelOptions.resultsOptions.plots = axes( 'Parent', panelt2); 

            % Add table. Importantly, this is done using createTable, not
            % uitable. This was required to achieve acceptable perforamnce
            % for large tables.            
%             this.tab_DataPrep.modelOptions.resultsOptions.table = createTable(this.tab_DataPrep.modelOptions.resultsOptions.box, ...
%                 {'Year', 'Month', 'Day', 'Hour', 'Minute', 'Head', 'Date_Error', 'Duplicate_Date_Error', 'Min_Head_Error','Max_Head_Error','Rate_of_Change_Error','Const_Hear_Error','Outlier_Obs'}, ... 
%                 cell(0,13), false, ...
%                 'ColumnFormat', {'numeric','numeric','numeric','numeric', 'numeric','numeric','logical','logical','logical','logical','logical','logical','logical'}, ...
%                 'ColumnEditable', [false(1,6) true(1,7)], ...
%                 'Tag','Data Preparation - results table', ...
%                 'CellEditCallback', @this.dataPrep_resultsTableEdit, ...,
%                 'TooltipString', 'Results data from the bore data analysis for erroneous observations and outliers.');   
%             
%             
            this.tab_DataPrep.modelOptions.resultsOptions.table = uitable(this.tab_DataPrep.modelOptions.resultsOptions.box, ...
                'ColumnName',{'Year', 'Month', 'Day', 'Hour', 'Minute', 'Head', 'Date_Error', 'Duplicate_Date_Error', 'Min_Head_Error','Max_Head_Error','Rate_of_Change_Error','Const_Hear_Error','Outlier_Obs'}, ... 
                'Data',cell(0,13), ...
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
            this.Figure.UIContextMenu = uicontextmenu(this.Figure,'Visible','off');
            
            % Add items
            uimenu(this.Figure.UIContextMenu,'Label','Copy selected row','Callback',@this.rowAddDelete);
            uimenu(this.Figure.UIContextMenu,'Label','Paste rows','Callback',@this.rowAddDelete,'Separator','on');
            uimenu(this.Figure.UIContextMenu,'Label','Insert row above selection','Callback',@this.rowAddDelete);
            uimenu(this.Figure.UIContextMenu,'Label','Insert row below selection','Callback',@this.rowAddDelete);            
            uimenu(this.Figure.UIContextMenu,'Label','Delete selected rows','Callback',@this.rowAddDelete,'Separator','on');
            uimenu(this.Figure.UIContextMenu,'Label','Select all','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Select none','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Invert selection','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Select row range ...','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Select by col. value ...','Callback',@this.rowSelection);
            
            % Attach menu to the construction table
            set(this.tab_DataPrep.Table,'UIContextMenu',this.Figure.UIContextMenu);
                        
            % Add table name to .UserData
            set(this.tab_DataPrep.Table.UIContextMenu,'UserData','this.tab_DataPrep.Table');            
            
%%          Layout Tab3 - Model Construction
            %------------------------------------------------------------------
            % Declare panels        
            hbox1t3 = uiextras.HBoxFlex('Parent', this.tab_ModelConstruction.Panel,'Padding', 3, 'Spacing', 3, 'Tag', 'Model Construction outer hbox');
            vbox1t3 = uiextras.VBox('Parent',hbox1t3,'Padding', 3, 'Spacing', 3);
            hbox1t4 = uiextras.HBox('Parent',vbox1t3,'Padding', 3, 'Spacing', 3);
            hboxBtn1 = uiextras.HButtonBox('Parent',hbox1t4 ,'Padding', 3, 'Spacing', 3);             
            hboxBtn2 = uiextras.HButtonBox('Parent',hbox1t4 ,'Padding', 3, 'Spacing', 3);             
            
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
            toolTipStr = 'Define the model label, input data, bore ID and model structure for each model.';
            
            
            % Initialise data
            data = cell(1,9);
            data{1,9} = '<html><font color = "#FF0000">Model not built.</font></html>';

            % Add table. Importantly, this is done using createTable, not
            % uitable. This was required to achieve acceptable perforamnce
            % for large tables.
%             this.tab_ModelConstruction.Table = createTable(vbox1t3,cnames1t3,data, false, ...
%                 'ColumnEditable',cedit1t3,'ColumnFormat',cformats1t3,'RowName', rnames1t3, ...
%                 'CellSelectionCallback', @this.modelConstruction_tableSelection,...
%                 'CellEditCallback', @this.modelConstruction_tableEdit,...
%                 'Tag','Model Construction', ...
%                 'TooltipString', toolTipStr);                        
%             
            this.tab_ModelConstruction.Table = uitable(vbox1t3,'ColumnName',cnames1t3,'Data',data,  ...
                'ColumnEditable',cedit1t3,'ColumnFormat',cformats1t3,'RowName', rnames1t3, ...
                'CellSelectionCallback', @this.modelConstruction_tableSelection,...
                'CellEditCallback', @this.modelConstruction_tableEdit,...
                'Tag','Model Construction', ...
                'TooltipString', toolTipStr);                        
                        
            
%             % Find java sorting object in table
%             try
%                 this.figure_Layout.Selection = 3;
%                 drawnow update;
%                 jscrollpane = findjobj(this.tab_ModelConstruction.Table);
%                 jtable = jscrollpane.getViewport.getView;
% 
%                 % Turn the JIDE sorting on
%                 jtable.setSortable(true);
%                 jtable.setAutoResort(true);
%                 jtable.setMultiColumnSortable(true);
%                 jtable.setPreserveSelectionsAfterSorting(true);            
%             catch
%                 warndlg('Creating of the GUI row-sorting module failed for the model construction table.');
%             end
                        
            % Add buttons to top left panel               
            uicontrol('Parent',hboxBtn2,'String','Append Table Data','Callback', @this.onImportTable, 'Tag','Model Construction', 'TooltipString', sprintf('Append a .csv file of table data to the table below. \n Use this feature to efficiently build a large number of models.') );
            uicontrol('Parent',hboxBtn2,'String','Export Table Data','Callback', @this.onExportTable, 'Tag','Model Construction', 'TooltipString', sprintf('Export a .csv file of the table below.') );
            uicontrol('Parent',hboxBtn2,'String','Build Selected Models','Callback', @this.onBuildModels, 'Tag','Model Construction', 'TooltipString', sprintf('Use the tick-box below to select the models to build then click here. \n After building, the status is given in the right most column.') );                        
            uicontrol('Parent',hboxBtn1,'Style','slider','Min',0.05,'Max',0.95,'Value',0.5,'Tag','WidthofPanelConstruct', ...
                'Callback', {@this.onChangeTableWidth, 'Model Construction outer hbox'} , 'TooltipString', 'Adjust table width');                                                     
            hboxBtn1.ButtonSize(1) = 225;
            hboxBtn2.ButtonSize(1) = 225;
            set(hbox1t4,'Sizes',[60 -1])
            
            % Create vbox for the various model options
            this.tab_ModelConstruction.modelOptions.vbox = uiextras.VBoxFlex('Parent',hbox1t3,'Padding', 3, 'Spacing', 3, 'DividerMarkings','off');
            
            % Add model options panel for bore IDs
            dynList = [];
            vbox4t3 = uiextras.VBox('Parent',this.tab_ModelConstruction.modelOptions.vbox, 'Padding', 3, 'Spacing', 3, 'Visible','on');
            uicontrol( 'Parent', vbox4t3,'Style','text','String',sprintf('%s\n%s%s','Please select the Bore ID for the model:'), 'Units','normalized');            
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
            set(hbox1t3, 'Sizes', [-2 -1]);
            set(vbox4t3, 'Sizes', [30 -1]);            
            
            % Build model options for each model type                
            includeModelOption = false(length(this.modelTypes),1);
            for i=1:length(this.modelTypes);
                switch this.modelTypes{i}
                    case 'model_TFN'
                        this.tab_ModelConstruction.modelTypes.(this.modelTypes{i}).hbox = uiextras.HBox('Parent',this.tab_ModelConstruction.modelOptions.vbox,'Padding', 3, 'Spacing', 3);
                        this.tab_ModelConstruction.modelTypes.(this.modelTypes{i}).buttons = uiextras.VButtonBox('Parent',this.tab_ModelConstruction.modelTypes.(this.modelTypes{i}).hbox,'Padding', 3, 'Spacing', 3);
                        uicontrol('Parent',this.tab_ModelConstruction.modelTypes.(this.modelTypes{i}).buttons,'String','<','Callback', @this.onApplyModelOptions, 'TooltipString','Copy model option to current model.');
                        uicontrol('Parent',this.tab_ModelConstruction.modelTypes.(this.modelTypes{i}).buttons,'String','<<','Callback', @this.onApplyModelOptions_selectedBores, 'TooltipString','Copy model option to selected models (of the current model type).');
                        this.tab_ModelConstruction.modelTypes.(this.modelTypes{i}).obj = model_TFN_gui( this.tab_ModelConstruction.modelTypes.model_TFN.hbox);
                        this.tab_ModelConstruction.modelTypes.(this.modelTypes{i}).hbox.Widths=[40 -1];
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
            this.Figure.UIContextMenu = uicontextmenu(this.Figure,'Visible','off');
            
            % Add items
            uimenu(this.Figure.UIContextMenu,'Label','Copy selected row','Callback',@this.rowAddDelete);
            uimenu(this.Figure.UIContextMenu,'Label','Paste rows','Callback',@this.rowAddDelete,'Separator','on');
            uimenu(this.Figure.UIContextMenu,'Label','Insert row above selection','Callback',@this.rowAddDelete);
            uimenu(this.Figure.UIContextMenu,'Label','Insert row below selection','Callback',@this.rowAddDelete);            
            uimenu(this.Figure.UIContextMenu,'Label','Delete selected rows','Callback',@this.rowAddDelete,'Separator','on');
            uimenu(this.Figure.UIContextMenu,'Label','Select all','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Select none','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Invert selection','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Select row range ...','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Select by col. value ...','Callback',@this.rowSelection);
                        
            % Attach menu to the construction table
            set(this.tab_ModelConstruction.Table,'UIContextMenu',this.Figure.UIContextMenu);
                        
            % Add table name to .UserData
            set(this.tab_ModelConstruction.Table.UIContextMenu,'UserData','this.tab_ModelConstruction.Table');
            
            
%%          Layout Tab4 - Calibrate models
            %------------------------------------------------------------------
            hbox1t4 = uiextras.HBoxFlex('Parent', this.tab_ModelCalibration.Panel,'Padding', 3, 'Spacing', 3,'Tag','Model Calibration outer hbox');
            vbox1t4 = uiextras.VBox('Parent',hbox1t4,'Padding', 3, 'Spacing', 3);
            hbox1t5 = uiextras.HBox('Parent',vbox1t4,'Padding', 3, 'Spacing', 3);
            hboxBtn1 = uiextras.HButtonBox('Parent',hbox1t5 ,'Padding', 3, 'Spacing', 3);             
            hboxBtn2 = uiextras.HButtonBox('Parent',hbox1t5 ,'Padding', 3, 'Spacing', 3);             
            
            
            % Add table
            cnames1t4 = {   '<html><center>Select<br />Model</center></html>', ...   
                            '<html><center>Model<br />Label</center></html>', ...   
                            '<html><center>Bore<br />ID</center></html>', ...   
                            '<html><center>Head<br />Start Date</center></html>', ...
                            '<html><center>Head<br />End Date</center></html>', ...
                            '<html><center>Calib.<br />Start Date</center></html>', ...
                            '<html><center>Calib.<br />End Date</center></html>', ...
                            '<html><center>Calib.<br />Method</center></html>', ...
                            '<html><center>Calib.<br />Status</center></html>', ...
                            '<html><center>Calib.<br />Period CoE</center></html>', ...
                            '<html><center>Eval. Period<br />Unbiased CoE</center></html>', ...
                            '<html><center>Calib.<br />Period AICc</center></html>', ...
                            '<html><center>Calib.<br />Period BIC</center></html>'};
            data = cell(0,14);            
            rnames1t4 = {[1]};
            cedit1t4 = logical([1 0 0 0 0 1 1 1 0 0 0 0 0]);            
            %cformats1t4 = {'logical', 'char', 'char','char','char','char','char', {'SP-UCI' 'CMA-ES' 'DREAM' 'Multi-model'},'char','char','char','char','char'};
            cformats1t4 = {'logical', 'char', 'char','char','char','char','char', {'SP-UCI' 'CMA-ES' 'DREAM' },'char','char','char','char','char'};
      
            toolTipStr = 'Calibration of models that have been successfully built.';              
            
            % Add table. Importantly, this is done using createTable, not
            % uitable. This was required to achieve acceptable perforamnce
            % for large tables.
            this.tab_ModelCalibration.resultsOptions.currentTab = [];
            this.tab_ModelCalibration.resultsOptions.currentPlot = [];                        
%             this.tab_ModelCalibration.Table = createTable(vbox1t4,cnames1t4, data, false, ...
%                 'ColumnFormat', cformats1t4, 'ColumnEditable', cedit1t4, ...
%                 'RowName', rnames1t4, 'Tag','Model Calibration', ...
%                 'CellSelectionCallback', @this.modelCalibration_tableSelection,...
%                 'TooltipString', toolTipStr, ...
%                 'Interruptible','off');              
            this.tab_ModelCalibration.Table = uitable(vbox1t4,'ColumnName',cnames1t4,'Data',data,  ...
                'ColumnFormat', cformats1t4, 'ColumnEditable', cedit1t4, ...
                'RowName', rnames1t4, 'Tag','Model Calibration', ...
                'CellSelectionCallback', @this.modelCalibration_tableSelection,...
                'TooltipString', toolTipStr, ...
                'Interruptible','off');   
            
%             % Find java sorting object in table
%             try
%                 this.figure_Layout.Selection = 4;
%                 drawnow update;
%                 jscrollpane = findjobj(this.tab_ModelCalibration.Table);
%                 jtable = jscrollpane.getViewport.getView;
% 
%                 % Turn the JIDE sorting on
%                 jtable.setSortable(true);
%                 jtable.setAutoResort(true);
%                 jtable.setMultiColumnSortable(true);
%                 jtable.setPreserveSelectionsAfterSorting(true);            
%             catch
%                 warndlg('Creating of the GUI row-sorting module failed for the model calibration table.');
%             end                
            
            % Add button for calibration
            uicontrol('Parent',hboxBtn2,'String','Import Table Data','Callback', @this.onImportTable, 'Tag','Model Calibration', 'TooltipString', sprintf('Import a .csv file of table data to the table below. \n Only rows with a model label and bore ID matching a row within the table will be imported.') );
            uicontrol('Parent',hboxBtn2,'String','Export Table Data','Callback', @this.onExportTable, 'Tag','Model Calibration', 'TooltipString', sprintf('Export a .csv file of the table below.') );            
            uicontrol('Parent',hboxBtn2,'String','Calibrate Selected Models','Callback', @this.onCalibModels,'Tag','useLocal', 'TooltipString', sprintf('Use the tick-box below to select the models to calibrate then click here. \n During and after calibration, the status is given in the 9th column.') );            
            uicontrol('Parent',hboxBtn2,'String','Export Selected Results','Callback', @this.onExportResults, 'Tag','Model Calibration', 'TooltipString', sprintf('Export a .csv file of the calibration results from all models.') );            
            uicontrol('Parent',hboxBtn1,'Style','slider','Min',0.05,'Max',0.95,'Value',0.5,'Tag','WidthofPanelConstruct', ...
                'Callback', {@this.onChangeTableWidth, 'Model Calibration outer hbox'} , 'TooltipString', 'Adjust table width');                                                     
            hboxBtn1.ButtonSize(1) = 225;
            hboxBtn2.ButtonSize(1) = 225;
            set(hbox1t5,'Sizes',[90 -1])                 
            
            % Size boxe
            set(vbox1t4, 'Sizes', [30 -1]);
                        
            % Create vbox for the various model options            
            resultsvbox = uiextras.VBoxFlex('Parent',hbox1t4,'Padding', 3, 'Spacing', 3, 'DividerMarkings','off');
                        
            % Add tabs for various types of results            
            this.tab_ModelCalibration.resultsTabs = uiextras.TabPanel( 'Parent',resultsvbox, 'Padding', 5, 'TabSize',127,'FontSize',8);
            this.tab_ModelCalibration.resultsOptions.calibPanel = uiextras.Panel( 'Parent', this.tab_ModelCalibration.resultsTabs, 'Padding', 5, ...
                'Tag','CalibrationResultsTab');            
            this.tab_ModelCalibration.resultsOptions.forcingPanel = uiextras.Panel( 'Parent', this.tab_ModelCalibration.resultsTabs, 'Padding', 5, ...
                'Tag','ForcingDataTab');          
            this.tab_ModelCalibration.resultsOptions.paramsPanel = uiextras.Panel( 'Parent', this.tab_ModelCalibration.resultsTabs, 'Padding', 5, ...
                'Tag','ParametersTab');
            this.tab_ModelCalibration.resultsOptions.derivedParamsPanel = uiextras.Panel( 'Parent', this.tab_ModelCalibration.resultsTabs, 'Padding', 5, ...
                'Tag','DerivedParametersTab');                         
            this.tab_ModelCalibration.resultsOptions.modelSpecificsPanel = uiextras.Panel( 'Parent', this.tab_ModelCalibration.resultsTabs, 'Padding', 5, ...
                'Tag','ModelSpecifics');                       
            this.tab_ModelCalibration.resultsTabs.TabNames = {'Calib. Results','Forcing Data','Parameters', ...
                'Derived Parameters','Model Specifics'};
            this.tab_ModelCalibration.resultsTabs.SelectedChild = 1;
                        
            % Build calibration results tab            
            resultsvbox= uiextras.VBoxFlex('Parent', this.tab_ModelCalibration.resultsOptions.calibPanel,'Padding', 3, 'Spacing', 3);
            resultsvboxTable = uiextras.Grid('Parent', resultsvbox ,'Padding', 3, 'Spacing', 3);            
            tbl = uitable(resultsvboxTable , 'ColumnName',{'Year','Month', 'Day','Hour','Minute', 'Obs. Head','Is Calib. Point?','Mod. Head','Model Err.','Noise Lower','Noise Upper'}, ... 
                'Data',cell(0,11), 'ColumnFormat', {'numeric','numeric','numeric','numeric', 'numeric','numeric','logical','numeric','numeric','numeric','numeric'}, ...
                'ColumnEditable', true(1,11), 'Tag','Model Calibration - results table', ...
                'TooltipString',['<html>This table shows the calibration & evaluation results. <br>', ... 
                'A range of plots can be used to explore aspects of the calibration.']);   

            % Build calibration results table contect menu
            contextMenu = uicontextmenu(this.Figure,'Visible','on');
            uimenu(contextMenu,'Label','Export table data ...','Tag','Model Calibration - results table export', 'Callback',@this.onExportResults);                 
            set(tbl,'UIContextMenu',contextMenu);
            set(tbl.UIContextMenu,'UserData','Model Calibration - results table');
            
            resultsvboxDropDown = uiextras.Grid('Parent', resultsvboxTable ,'Padding', 3, 'Spacing', 3);            
            uicontrol(resultsvboxDropDown,'Style','text','String','Select the plot type:','HorizontalAlignment','left' );
            uicontrol(resultsvboxDropDown,'Style','popupmenu', ...
                'String',{  'Time-series of Heads', ...
                            'Time-series of Residuals', ...
                            'Histogram of Calib. Residuals', ...
                            'Histogram of Eval. Residuals', ...
                            'Obs. Head vs Modelled Head', ...
                            'Obs. Head vs Residuals', ...
                            'Variogram of Residuals', ...
                            '(none)'}, ...
                'Value',1,'Callback', @this.modelCalibration_onUpdatePlotSetting);                                                
            set(resultsvboxTable, 'ColumnSizes', -1, 'RowSizes', [-1 20] );
            uiextras.Panel('Parent', resultsvbox,'BackgroundColor',[1 1 1], ...
                'Tag','Model Calibration - results plot');  
            set(resultsvbox, 'Sizes', [-1 -1]);
            
            % Building forcing data
            resultsvbox= uiextras.VBoxFlex('Parent', this.tab_ModelCalibration.resultsOptions.forcingPanel,'Padding', 3, 'Spacing', 3);
            resultsvboxOptions = uiextras.Grid('Parent', resultsvbox,'Padding', 3, 'Spacing', 3);
            uicontrol(resultsvboxOptions,'Style','text','String','Time step:','HorizontalAlignment','left' );
            uicontrol(resultsvboxOptions,'Style','popupmenu', 'String',{'daily','weekly','monthly','quarterly','annual','full-record'}, ...
                'Value',1, 'Callback', @this.modelCalibration_onUpdateForcingData, ...
                'TooltipString', ['<html>Select the time-scale for presentation of the forcing data.  <br>', ...
                'Note, all time-scales >daily are reported as daily mean.'],'HorizontalAlignment','right');    
            uicontrol(resultsvboxOptions,'Style','text','String','Time step metric:','HorizontalAlignment','left' );
            uicontrol(resultsvboxOptions,'Style','popupmenu', ...
                'String',{'sum','mean','st. dev.','variance','skew','min','5th %ile','10th %ile','25th %ile','50th %ile','75th %ile','90th %ile','95th %ile', 'max', ...
                'inter-quantile range', 'No. zero days', 'No. <0 days', 'No. >0 day'}, ...
                'Value',1, 'Callback', @this.modelCalibration_onUpdateForcingData, ...
                'TooltipString', ['<html>Select calculation to apply when aggregating the daily data.  <br>', ...
                'Note, all plots will use the resulting data.'],'HorizontalAlignment','right');    

            uicontrol(resultsvboxOptions,'Style','text','String','Start date:','HorizontalAlignment','left');
            uicontrol(resultsvboxOptions,'Style','edit','String','01/01/0001','TooltipString','Filter the data and plot to that above a data (as dd/mm/yyyy).', 'Callback', @this.modelCalibration_onUpdateForcingData );

            uicontrol(resultsvboxOptions,'Style','text','String','End date:','HorizontalAlignment','left');
            uicontrol(resultsvboxOptions,'Style','edit','String','31/12/9999','TooltipString','Filter the data and plot to that below a data (as dd/mm/yyyy).', 'Callback', @this.modelCalibration_onUpdateForcingData );
                   
            set(resultsvboxOptions, 'ColumnSizes', [-1 -1 -1 -1 -1 -1 -1 -1], 'RowSizes', [25] );
            
            tbl = uitable(resultsvbox, 'ColumnName',{'Year','Month', 'Day'}, ... 
                'Data',cell(0,3), 'ColumnFormat', {'numeric','numeric','numeric'}, ...
                'ColumnEditable', true(1,3), 'Tag','Model Calibration - forcing table', ...
                'TooltipString',['<html>This table allows exploration of the forcing data used for the calibration <br>', ... 
                     '& evaluation and forcing data derived from the model (e.g. from a soil moisture <br>', ... 
                     'transformation model). Use the table to explore forcing dynamics at a range of time-steps.']);  
            contextMenu = uicontextmenu(this.Figure,'Visible','on');
            uimenu(contextMenu,'Label','Export table data ...','Tag','Model Calibration - forcing table export', 'Callback',@this.onExportResults);                 
            set(tbl,'UIContextMenu',contextMenu);
            set(tbl.UIContextMenu,'UserData','Model Calibration - forcing table');
                 
                 
            resultsvboxOptions = uiextras.Grid('Parent', resultsvbox,'Padding', 3, 'Spacing', 3);
            uicontrol(resultsvboxOptions,'Style','text','String','Plot type:' );
            uicontrol(resultsvboxOptions,'Style','popupmenu', 'String',{'line','scatter','bar','histogram','cdf','box-plot (daily metric)', ...
                'box-plot (monthly metric)','box-plot (quarterly metric)','box-plot (annually metric)'}, 'Value',1,'HorizontalAlignment','right', ...
                'Callback',@this.modelCalibration_onUpdateForcingPlotType);    
            uicontrol(resultsvboxOptions,'Style','text','String','x-axis:' );
            uicontrol(resultsvboxOptions,'Style','popupmenu', 'String',{'Date', '(none)'}, 'Value',1,'HorizontalAlignment','right');    
            uicontrol(resultsvboxOptions,'Style','text','String','y-axis:' );
            uicontrol(resultsvboxOptions,'Style','popupmenu', 'String',{'Date', '(none)'}, 'Value',1,'HorizontalAlignment','right');                
            uicontrol(resultsvboxOptions,'Style','pushbutton','String','Build plot','Callback', @this.modelCalibration_onUpdateForcingPlot, ...
                'Tag','Model Calibration - forcing plot', 'TooltipString', 'Build the forcing plot.','ForegroundColor','blue');            
            set(resultsvboxOptions, 'ColumnSizes', [-1 -2 -1 -2 -1 -2 -2], 'RowSizes', [25] );
            %hbuttons = uiextras.HButtonBox('Parent',resultsvboxOptions,'Padding', 3, 'Spacing', 3);  
            %uicontrol('Parent',hbuttons,'String','Build plot','Callback', @this.modelCalibration_onUpdatePlotSetting, ...
            %    'Tag','Model Calibration - forcing plot', 'TooltipString', 'Build the forcing plot.','ForegroundColor','blue');            
            
            uiextras.Panel('Parent', resultsvbox,'BackgroundColor',[1 1 1] );             
            set(resultsvbox, 'Sizes', [30 -1 30 -1]);
            
            % set selected tab and plot to 
            this.tab_ModelCalibration.resultsOptions.currentTab = 1;
            this.tab_ModelCalibration.resultsOptions.currentPlot = 7;
            
            % Build parameters tab
            resultsvbox= uiextras.VBoxFlex('Parent', this.tab_ModelCalibration.resultsOptions.paramsPanel,'Padding', 3, 'Spacing', 3);  
            tbl = uitable(resultsvbox, ...
                'ColumnName',{'Component Name','Parameter Name','Value'}, ... 
                'ColumnFormat', {'char','char','numeric'}, ...
                'ColumnEditable', true(1,3), ...
                'Tag','Model Calibration - parameter table', ...
                'TooltipString',['<html>This table allows exploration of the calibrated model parameters. <br>', ... 
                 'Use this table to inform assessment of the validity of the model.']);            
             
            contextMenu = uicontextmenu(this.Figure,'Visible','on');
            uimenu(contextMenu,'Label','Export table data ...','Tag','Model Calibration - parameter table export', 'Callback',@this.onExportResults);                 
            set(tbl,'UIContextMenu',contextMenu);
            set(tbl.UIContextMenu,'UserData','Model Calibration - parameter table');                         

            uiextras.Panel('Parent', resultsvbox,'BackgroundColor',[1 1 1], ...
                'Tag','Model Calibration - parameter plot');  
            set(resultsvbox, 'Sizes', [-1 -2]);
            
            % Build derived parameters tab
            resultsvbox= uiextras.VBoxFlex('Parent', this.tab_ModelCalibration.resultsOptions.derivedParamsPanel,'Padding', 3, 'Spacing', 3);  
            tbl = uitable(resultsvbox, ...
                'ColumnName',{'Component Name','Parameter Name','Derived Value'}, ... 
                'ColumnFormat', {'char','char','numeric'}, ...
                'ColumnEditable', true(1,3), ...
                'Tag','Model Calibration - derived parameter table', ...
                'TooltipString',['<html>This table allows exploration of the parameters derived from the calibrated <br>', ... 
                 'parameters. The parameters shown are dependent upon the model structure. <br>', ...
                 'For example, TFN models having using, say, the Ferris Knowles weighting function <br>', ...
                 'will show the transmissivity and storativity.']); 
             
            contextMenu = uicontextmenu(this.Figure,'Visible','on');
            uimenu(contextMenu,'Label','Export table data ...','Tag','Model Calibration - derived parameter table export', 'Callback',@this.onExportResults);                 
            set(tbl,'UIContextMenu',contextMenu);
            set(tbl.UIContextMenu,'UserData','Model Calibration - derived parameter table');                         
             
            uiextras.Panel('Parent', resultsvbox,'BackgroundColor',[1 1 1], ...
                'Tag','Model Calibration - derived parameter plot');  
            set(resultsvbox, 'Sizes', [-1 -2]);
                        
            % Build model specific outputs tab.
            resultsvbox= uiextras.VBoxFlex('Parent', this.tab_ModelCalibration.resultsOptions.modelSpecificsPanel,'Padding', 3, 'Spacing', 3);                        
            resultsvboxOptions = uiextras.Grid('Parent', resultsvbox,'Padding', 3, 'Spacing', 3);            
            uicontrol(resultsvboxOptions,'Style','text','String','Select model specific output:' );
            uicontrol(resultsvboxOptions,'Style','popupmenu', 'String',{'(none)'},'Value',1, ...
                'Tag','Model Calibration - derived data dropdown', ...
                'Callback', @this.modelCalibration_onUpdateDerivedData);                         
            tbl = uitable(resultsvbox, ...
                'ColumnName',{'Variabe 1','Variabe 2'}, ... 
                'ColumnFormat', {'numeric','numeric'}, ...
                'ColumnEditable', true(1,2), ...
                'Tag','Model Calibration - derived data table', ...
                'TooltipString',['<html>This table allows exploration of the data derived from the calibrated. <br>', ... 
                 'The data shown are very dependent upon the model structure. <br>', ...
                 'For example, TFN models having using, say, the Pearsons weighting function <br>', ...
                 'will show the weighting data and a plot.']);     
            contextMenu = uicontextmenu(this.Figure,'Visible','on');
            uimenu(contextMenu,'Label','Export table data ...','Tag','Model Calibration - derived data table export', 'Callback',@this.onExportResults);                 
            set(tbl,'UIContextMenu',contextMenu);
            set(tbl.UIContextMenu,'UserData','Model Calibration - derived data table export');               
            uiextras.Panel('Parent', resultsvbox,'BackgroundColor',[1 1 1], ...
                'Tag','Model Calibration - derived data plot');             
            set(resultsvbox, 'Sizes', [30 -1 -2]);                                                            
                        
%           Add context menu
            this.Figure.UIContextMenu = uicontextmenu(this.Figure,'Visible','off');
            uimenu(this.Figure.UIContextMenu,'Label','Copy selected row','Callback',@this.rowAddDelete);
            uimenu(this.Figure.UIContextMenu,'Label','Paste rows','Callback',@this.rowAddDelete,'Separator','on');
            uimenu(this.Figure.UIContextMenu,'Label','Select all','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Select none','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Invert selection','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Select row range ...','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Select by col. value ...','Callback',@this.rowSelection);
            
            % Attach menu to the construction table
            set(this.tab_ModelCalibration.Table,'UIContextMenu',this.Figure.UIContextMenu);
                        
            % Add table name to .UserData
            set(this.tab_ModelCalibration.Table.UIContextMenu,'UserData','this.tab_ModelCalibration.Table');

            

%%          Layout Tab5 - Model Simulation
            %------------------------------------------------------------------            
            hbox1t5 = uiextras.HBoxFlex('Parent', this.tab_ModelSimulation.Panel,'Padding', 3, 'Spacing', 3, 'Tag','Model Simulation outer hbox');
            vbox1t5 = uiextras.VBox('Parent',hbox1t5,'Padding', 3, 'Spacing', 3);
            vbox2t5 = uiextras.VBox('Parent',hbox1t5,'Padding', 3, 'Spacing', 3);
            hbox1t6 = uiextras.HBox('Parent',vbox1t5,'Padding', 3, 'Spacing', 3);
            hboxBtn1 = uiextras.HButtonBox('Parent',hbox1t6 ,'Padding', 3, 'Spacing', 3);             
            hboxBtn2 = uiextras.HButtonBox('Parent',hbox1t6 ,'Padding', 3, 'Spacing', 3);                 
            
                        
            % Add button for calibration
            % Add buttons to top left panel               
            uicontrol(hboxBtn2,'String','Append Table Data','Callback', @this.onImportTable, 'Tag','Model Simulation', 'TooltipString', sprintf('Append a .csv file of table data to the table below. \n Only rows where the model label is for a model that have been calibrated will be imported.') );
            uicontrol(hboxBtn2,'String','Export Table Data','Callback', @this.onExportTable, 'Tag','Model Simulation', 'TooltipString', sprintf('Export a .csv file of the table below.') );                        
            uicontrol(hboxBtn2,'String','Simulate Selected Models','Callback', @this.onSimModels, 'TooltipString', sprintf('Use the tick-box below to select the models to simulate then click here. \n During and after simulation, the status is given in the 9th column.') );            
            uicontrol(hboxBtn2,'String','Export Selected Results','Callback', @this.onExportResults, 'Tag','Model Simulation', 'TooltipString', sprintf('Export a .csv file of the simulation results from all models.') );            
            uicontrol('Parent',hboxBtn1,'Style','slider','Min',0.05,'Max',0.95,'Value',0.5,'Tag','WidthofPanelConstruct', ...
                'Callback', {@this.onChangeTableWidth, 'Model Simulation outer hbox'} , 'TooltipString', 'Adjust table width');                                                     
            hboxBtn1.ButtonSize(1) = 225;
            hboxBtn2.ButtonSize(1) = 225;
            set(hbox1t6,'Sizes',[90 -1])              
            
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
            toolTipStr = 'Run simulations of calibrated models';
              
            % Add table. Importantly, this is done using createTable, not
            % uitable. This was required to achieve acceptable perforamnce
            % for large tables.
%             this.tab_ModelSimulation.Table = createTable(vbox1t5,cnames1t5, data, false, ...
%                 'ColumnFormat', cformats1t5, 'ColumnEditable', cedit1t5, ...
%                 'RowName', rnames1t5, 'Tag','Model Simulation', ...
%                 'CellSelectionCallback', @this.modelSimulation_tableSelection,...
%                 'CellEditCallback', @this.modelSimulation_tableEdit,...
%                 'TooltipString', toolTipStr);   

            this.tab_ModelSimulation.Table = uitable(vbox1t5, ...
                'ColumnName', cnames1t5, 'Data', data, ...
                'ColumnFormat', cformats1t5, 'ColumnEditable', cedit1t5, ...
                'RowName', rnames1t5, 'Tag','Model Simulation', ...
                'CellSelectionCallback', @this.modelSimulation_tableSelection,...
                'CellEditCallback', @this.modelSimulation_tableEdit,...
                'TooltipString', toolTipStr);            
                                 
            
%             % Find java sorting object in table
%             try
%                 this.figure_Layout.Selection = 5;
%                 drawnow update;
%                 jscrollpane = findjobj(this.tab_ModelSimulation.Table);
%                 jtable = jscrollpane.getViewport.getView;
% 
%                 % Turn the JIDE sorting on
%                 jtable.setSortable(true);
%                 jtable.setAutoResort(true);
%                 jtable.setMultiColumnSortable(true);
%                 jtable.setPreserveSelectionsAfterSorting(true);            
%             catch
%                 warndlg('Creating of the GUI row-sorting module failed for the model simulation table.');
%             end                         
                        
            % Add drop-down for the results box
            uicontrol(vbox2t5,'Style','text','String','Select simulation results to display:' );
            this.tab_ModelSimulation.resultsOptions.popup = uicontrol('Parent',vbox2t5,'Style','popupmenu', ...
                'String',{'Simulation data', 'Simulation & decomposition plots','(none)'}, ...
                'Value',3,'Callback', @this.modelSimulation_onResultsSelection);         
            
            this.tab_ModelSimulation.resultsOptions.dataTable.box = uiextras.Grid('Parent', vbox2t5,'Padding', 3, 'Spacing', 3);

            % Add results table. Importantly, this is done using createTable, not
            % uitable. This was required to achieve acceptable perforamnce
            % for large tables.
%             this.tab_ModelSimulation.resultsOptions.dataTable.table = createTable(this.tab_ModelSimulation.resultsOptions.dataTable.box, ...
%                 {'Year','Month', 'Day','Hour','Minute', 'Sim. Head','Noise Lower','Noise Upper'}, ...
%                 cell(0,8), false, ...
%                 'ColumnFormat', {'numeric','numeric','numeric','numeric', 'numeric','numeric','numeric','numeric'}, ...
%                 'ColumnEditable', true(1,8), ...
%                 'Tag','Model Simulation - results table', ...
%                 'TooltipString', 'Results data from the model simulation.');     
            this.tab_ModelSimulation.resultsOptions.dataTable.table = uitable(this.tab_ModelSimulation.resultsOptions.dataTable.box, ...
                'ColumnName',{'Year','Month', 'Day','Hour','Minute', 'Sim. Head','Noise Lower','Noise Upper'}, ...
                'Data',cell(0,8), ...
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
            this.Figure.UIContextMenu = uicontextmenu(this.Figure,'Visible','off');
            uimenu(this.Figure.UIContextMenu,'Label','Copy selected row','Callback',@this.rowAddDelete);
            uimenu(this.Figure.UIContextMenu,'Label','Paste rows','Callback',@this.rowAddDelete,'Separator','on');
            uimenu(this.Figure.UIContextMenu,'Label','Insert row above selection','Callback',@this.rowAddDelete);
            uimenu(this.Figure.UIContextMenu,'Label','Insert row below selection','Callback',@this.rowAddDelete);            
            uimenu(this.Figure.UIContextMenu,'Label','Delete selected rows','Callback',@this.rowAddDelete,'Separator','on');
            uimenu(this.Figure.UIContextMenu,'Label','Select all','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Select none','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Invert selection','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Select row range ...','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Select by col. value ...','Callback',@this.rowSelection);
            
            % Attach menu to the construction table
            set(this.tab_ModelSimulation.Table,'UIContextMenu',this.Figure.UIContextMenu);
                        
            % Add table name to .UserData
            set(this.tab_ModelSimulation.Table.UIContextMenu,'UserData','this.tab_ModelSimulation.Table');
            
%%          Store this.models on HDD
            %----------------------------------------------------
            this.modelsOnHDD = '';
            this.models = [];
            
%%          Close the splash window and show the app
            %----------------------------------------------------
            if ~isdeployed
               close(this.FigureSplash);
            end                        
            this.figure_Layout.Selection = 1;
            set(this.Figure,'Visible','on');
        end

        % Show show plotting icons
        function plotToolbarState(this,iconState)
            % Check if version is 2018b or later. From this point the
            % plot toolbar buttons moved into the plot.
            v=version();
            isBefore2018b = str2double(v(1:3))<9.5;

            if isBefore2018b 
                hToolbar = findall(this.Figure,'tag','FigureToolBar');
                hToolbutton = findall(hToolbar,'tag','Exploration.Brushing');            
                hToolbutton.Visible = 'off';
                hToolbutton = findall(hToolbar,'tag','Exploration.DataCursor');            
                hToolbutton.Visible = iconState;
                hToolbutton = findall(hToolbar,'tag','Exploration.Rotate');            
                hToolbutton.Visible = 'off';
                hToolbutton = findall(hToolbar,'tag','Exploration.Pan');            
                hToolbutton.Visible = iconState;
                hToolbutton = findall(hToolbar,'tag','Exploration.ZoomOut');            
                hToolbutton.Visible = iconState;
                hToolbutton = findall(hToolbar,'tag','Exploration.ZoomIn');            
                hToolbutton.Visible = iconState;
                hToolbutton = findall(hToolbar,'tag','Standard.PrintFigure');            
                hToolbutton.Visible = iconState;
                hToolbutton = findall(this.Figure,'tag','Export.plot');            
                hToolbutton.Visible = iconState;
                hToolbutton = findall(hToolbar,'tag','Standard.EditPlot');            
                hToolbutton.Visible = 'off';            
                hToolbutton = findall(hToolbar,'tag','Plottools.PlottoolsOn');            
                hToolbutton.Visible = 'off';                          
            end
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
                set(this.Figure,'Name',['HydroSight - ', this.project_fileName]);
                drawnow update;
            end            
            
        end
            
        function onMoveModels(this,hObject,eventdata)
            
            % The project must be saved to a file. Check the project file
            % is defined.
            if isempty(this.project_fileName) || isdir(this.project_fileName)
                warndlg({'The project must first be saved to a file.';'Please first save the project.'}, 'Project not saved...')
                return
            end
               
            % Tell the user what is going to be done.
            if ~isempty(this.modelsOnHDD)
                response = questdlg({'Moving the models to the RAM will shift all built, calibrated and '; ...
                                   'simulated models from the hard-drive of the project file to the RAM.'; ...
                                   ''; ...
                                   'This allows significantly fewer models to be analysed within one '; ...
                                   'project. However, any operation requiring access to the models '; ...
                                   'may be muxh faster. Such operations include changing settings or '; ...
                                   'plot and exporting results.'; ...
                                   ''; ...
                                   'Additionally, changes made to a model (e.g. rebuilting, calibrating'; ...
                                   'or simulating) will NOT be automatically saved to the project file.'; ...
                                   ''; ...
                                   'To move the models to RAM, click OK.'},'Move the project models to RAM ...','OK','Cancel','Cancel');                
            else
                response = questdlg({'Moving the models to the HDD will shift all built, calibrated and '; ...
                                   'simulated models from the RAM to the project file on the hard disk.'; ...
                                   ''; ...
                                   'This allows significantly more models to be analysed within one '; ...
                                   'project. However, any operation requiring access to the models '; ...
                                   'may be very slow. Such operations include changing settings or '; ...
                                   'plot and exporting results. Hence, it is highly advisable to '; ...
                                   'store the project file on a local hard-drive, and not a network'; ...
                                   'location.'; ...
                                   ''; ...
                                   'Additionally, changes made to a model (e.g. rebuilting, calibrating'; ...
                                   'or simulating) will be automatically saved to the project file. The'; ...
                                   'project data tables within each tab will however not be automatically'; ...
                                   'saved.'; ...
                                   ''; ...
                                   'To move the models to the hard-drive, click OK.'},'Move the project models to hard-drive ...','OK','Cancel','Cancel');
            end
                           
             if ~strcmp(response,'OK')
                 return
             end
             
             % Change cursor
             set(this.Figure, 'pointer', 'watch');                
             drawnow update;                    

             % Store original - in case of error
             modelsOnHDD_orig = this.modelsOnHDD;
             
             if ~isempty(this.modelsOnHDD)    
                 % Move models to RAM. The following loads each model
                 % object and then assigns si to the project.
                 try                      
                     model_labels = fieldnames(this.models);
                     nModels = length(model_labels);
                     for i=1:nModels
                        tmpModels.(model_labels{i}) = getModel(this, model_labels{i});
                     end
                     this.models = tmpModels;
                     this.modelsOnHDD = '';
                     
                     % Change file menu label
                     for i=1:size(this.figure_Menu.Children,1)
                        if strcmp(get(this.figure_Menu.Children(i),'Label'), 'Move models from RAM to HDD...') || ...
                        strcmp(get(this.figure_Menu.Children(i),'Label'), 'Move models from HDD to RAM...')
                            set(this.figure_Menu.Children(i),'Label','Move models from RAM to HDD...');
                        end       
                     end   

                     % Change cursor
                     set(this.Figure, 'pointer', 'arrow');                
                     drawnow update;                    
                                   
                     msgbox('Models were successfully moved to the RAM.','Successful model relocation','help');                     
                 catch ME
                     this.modelsOnHDD = modelsOnHDD_orig;
                     msgbox({'Models relocation failed!','','Check access to the project file and RAM availability.'},'Relcation of models failed.','error');
                 end
             else               % Move models to HDD
                try 
                    
                    % Get the folder for the project files
                    folderName = uigetdir(fileparts(this.project_fileName) ,'Select folder for the model files.');    
                    if isempty(folderName)
                        return;
                    end                                                        
                    
                    % remove project folder from file paths
                    [ind_start,ind_end]=regexp(folderName ,fileparts(this.project_fileName));
                    folderName = folderName(ind_end+2:end);
                    
                    % Store sub-folder to models in project
                    this.modelsOnHDD = folderName;
                    
                    % Move models to HDD
                    model_labels = fieldnames(this.models);
                    nModels = length(model_labels);
                    for i=1:nModels
                        model = this.models.(model_labels{i});                        
                        setModel( this, model_labels{i}, model);
                    end

                    % Change file menu label
                    for i=1:size(this.figure_Menu.Children,1)
                        if strcmp(get(this.figure_Menu.Children(i),'Label'), 'Move models from RAM to HDD...') || ...
                        strcmp(get(this.figure_Menu.Children(i),'Label'), 'Move models from HDD to RAM...')
                            set(this.figure_Menu.Children(i),'Label','Move models from HDD to RAM...');
                        end       
                    end                       

                    % Change cursor
                    set(this.Figure, 'pointer', 'arrow');                
                    drawnow update;                    
                    
                    msgbox('Models were successfully moved to the hard-drive.','Successful model relocation','help');
                catch ME
                    this.modelsOnHDD = modelsOnHDD_orig;
                    msgbox({'Models relocation failed!','','Check access to the project file and RAM availability.'},'Relcation of models failed.','error');
                end
             end
             
             % Change cursor
             set(this.Figure, 'pointer', 'arrow');                
             drawnow update;               
        end
        
        % Open saved model
        function onNew(this,hObject,eventdata)

            % Check if all of the GUI tables are empty. If not, warn the
            % user the opening the example will delete the existing data.
            if ~isempty(this.tab_Project.project_name.String) || ...
            ~isempty(this.tab_Project.project_description.String) || ...
            (size(this.tab_ModelConstruction.Table.Data,1)~=0 && any(~any(cellfun( @(x) isempty(x), this.tab_ModelConstruction.Table.Data(:,1:8))))) || ...
            (size(this.tab_ModelCalibration.Table.Data,1)~=0 && any(~any(cellfun( @(x) isempty(x), this.tab_ModelCalibration.Table.Data)))) || ...
            (size(this.tab_ModelSimulation.Table.Data,1)~=0 && any(~any(cellfun( @(x) isempty(x), this.tab_ModelSimulation.Table.Data))))
                response = questdlg({'Started a new project will close the current project.','','Do you want to continue?'}, ...
                 'Close the current project?','Yes','No','No');
             
                if strcmp(response,'No')
                    return;
                end
            end              
            
            % Initialise project data
            set(this.Figure, 'pointer', 'watch');
            drawnow update;              
            this.project_fileName ='';
            this.model_labels=[];
            this.models=[];              
            this.tab_Project.project_name.String = '';
            this.tab_Project.project_description.String = '';
            this.tab_DataPrep.Table.Data = {};
            this.tab_DataPrep.Table.RowName = {}; 
            this.tab_ModelConstruction.Table.Data = { [],[],[],[],[],[],[],[], '<html><font color = "#FF0000">Model not built.</font></html>'};
            this.tab_ModelConstruction.Table.RowName = {}; 
            this.tab_ModelCalibration.Table.Data = {};
            this.tab_ModelCalibration.Table.RowName = {};
            this.tab_ModelSimulation.Table.Data = {};
            this.tab_ModelSimulation.Table.RowName = {};
            this.dataPrep = [];
            this.copiedData={};
            this.HPCoffload={};
            this.modelsOnHDD='';
            set(this.Figure,'Name','HydroSight');
            drawnow update;   
                
            % Enable file menu items
            for i=1:size(this.figure_Menu.Children,1)
                if strcmp(get(this.figure_Menu.Children(i),'Label'), 'Save Project')
                    set(this.figure_Menu.Children(i),'Enable','on');
                elseif strcmp(get(this.figure_Menu.Children(i),'Label'), 'Move models from RAM to HDD...') || ...
                strcmp(get(this.figure_Menu.Children(i),'Label'), 'Move models from HDD to RAM...')
                    if this.modelsOnHDD
                        set(this.figure_Menu.Children(i),'Label', 'Move models from HDD to RAM...');
                    else
                        set(this.figure_Menu.Children(i),'Label', 'Move models from RAM to HDD...');
                    end
                    set(this.figure_Menu.Children(i),'Enable','on');
                end       
            end

            set(this.Figure, 'pointer', 'arrow');
            drawnow update;                               
        end
        
        % Open saved model
        function onOpen(this,hObject,eventdata)
            
            % Check if all of the GUI tables are empty. If not, warn the
            % user the opening the example will delete the existing data.
            if ~isempty(this.tab_Project.project_name.String) || ...
            ~isempty(this.tab_Project.project_description.String) || ...
            (size(this.tab_ModelConstruction.Table.Data,1)~=0 && any(~any(cellfun( @(x) isempty(x), this.tab_ModelConstruction.Table.Data(:,1:8))))) || ...
            (size(this.tab_ModelCalibration.Table.Data,1)~=0 && any(~any(cellfun( @(x) isempty(x), this.tab_ModelCalibration.Table.Data)))) || ...
            (size(this.tab_ModelSimulation.Table.Data,1)~=0 && any(~any(cellfun( @(x) isempty(x), this.tab_ModelSimulation.Table.Data))))
                response = questdlg({'Opening a new project will close the current project.','','Do you want to continue?'}, ...
                 'Close the current project?','Yes','No','No');
             
                if strcmp(response,'No')
                    return;
                end
            end            
            
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

                % Ask if the performance stats in the GUI calib table are
                % to be rebuilt
                doPerforamnceMeasureRestimation=false;
                if ~isdeployed
                    response = questdlg({'Would you like the calibration performance metrics to be re-calculated?','','Note, the calculations can be slow if there are 100''s of models'},'Re-calculate performance metrics?','Yes','No','Cancel','No');
                    if strcmp(response,'Cancel')
                        return;
                    elseif strcmp(response,'Yes')
                        doPerforamnceMeasureRestimation=true;
                    end
                end
                
                % Change cursor
                set(this.Figure, 'pointer', 'watch');                
                drawnow update;
                
                % Analyse the variables in the file
                %----------------------------------------------------------
                % Get variables in file
                try
                    vars= whos('-file',this.project_fileName);
                catch ME
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update;
                    errordlg(['The following project file could not be opened:',this.project_fileName],'Project file read error ...');
                    return;
                end

                % Filter out 'models' variable
                j=0;
                hasDataVar = false;
                hasModelsVar = false;
                for i=1:size(vars)
                   if ~strcmp(vars(i).name,'data') && ~strcmp(vars(i).name,'label') && ~strcmp(vars(i).name,'models') 
                       j=j+1;
                       varNames{j} = vars(i).name;
                   end
                   if strcmp(vars(i).name,'data')
                       hasDataVar = true;
                   end
                   if strcmp(vars(i).name,'models')
                       hasModelsVar = true;
                   end                   
                end                
                
                % GET MODEL DATA
                %----------------------------------------------------------                
                % Add HPC settings
                savedData = load(this.project_fileName, 'settings','-mat');
                try
                    this.HPCoffload = savedData.settings.HPCoffload;
                catch
                    this.HPCoffload = {};
                end
                
                % Add model on HDD setting
                try 
                    if islogical(savedData.settings.modelsOnHDD)
                        this.modelsOnHDD = '';
                    else
                        this.modelsOnHDD = savedData.settings.modelsOnHDD;
                    end
                catch
                    this.modelsOnHDD = '';
                end

                % Add model label settings
                try
                    savedData = load(this.project_fileName, 'model_labels','-mat');
                    if isempty(fieldnames(savedData))
                        this.model_labels=[];
                    else
                        this.model_labels=savedData.model_labels;                
                    end
                catch ME
                    this.model_labels=[];
                end
                
                % Clear models in project.                        
                this.models=[];                                
                
                % Assign built models.
                try
                    % Load data and labels assuming they are not in a
                    % field of 'models'.                        
                    if hasModelsVar
                        savedData = load(this.project_fileName, 'models','-mat');
                        savedData = savedData.models;                                                        
                    else
                        savedData = load(this.project_fileName, '-mat');                            

                        % Remove GUI data fields
                        try
                        	filt = strcmp(fieldnames(savedData),'dataPrep') | strcmp(fieldnames(savedData),'settings') |  strcmp(fieldnames(savedData),'tableData') |  strcmp(fieldnames(savedData),'model_labels');
                            removedFields = fieldnames(savedData);
                            removedFields = removedFields(filt);                            
                            savedData = rmfield(savedData,removedFields);
                        catch ME
                            % do nothing
                        end                            
                    end

                    if ~isempty(this.modelsOnHDD)
                        
                        % Setup matfile link to 'this'. NOTE: for
                        % offloadeed models setModel() can handle the third input being the 
                        % file name to the matfile link. 
                        % Note 2: The models only need to be loaded if
                        % this.model_labels does not contain calib. status.
                        model_labels = fieldnames(savedData);
                        nModels = length(model_labels);
                        nErr=0;
                        if isempty(this.model_labels) || size(this.model_labels,1)<nModels
                            this.model_labels=[];
                            h = waitbar(0,'Re-building list of calibrated models because of error. Please wait ...');                        
                            for i=1:nModels             
                                waitbar(i/nModels);
                                try                                
                                    setModel(this, model_labels{i,1}, savedData.(model_labels{i,1}));
                                catch ME
                                    nErr = nErr+1;
                                end                                
                            end
                            close(h);
                        else
                            % Update object hold the relative path to the .mat file                            
                            for i=1:nModels   
                                model_label_tmp = HydroSight_GUI.modelLabel2FieldName(model_labels{i,1});
                                this.models.(model_label_tmp) = fullfile(this.modelsOnHDD, [model_label_tmp,'.mat']);                                
                            end
                        end
                        
                        if nErr>0
                            warndlg(['The HDD stored .mat files could not be loaded for ', num2str(nErr), ' models. Check the .mat files exist for all calibrated models in the project'],'Model load errors...');
                        end
                    else
                        
                        if iscell(savedData)
                            nModels = size(savedData,1);
                            for i=1:nModels                                
                                setModel(this, savedData{i,1}.model_label, savedData{i,1});
                            end
                        else
                            model_labels = fieldnames(savedData);
                            nModels = length(model_labels);
                            for i=1:nModels
                                setModel(this, savedData.(model_labels{i,1}).model_label, savedData.(model_labels{i,1}));
                            end
                        end                 
                    end
                catch ME
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update;
                    warndlg('Loaded models could not be assigned to the user interface.','File model data error');
                    set(this.Figure, 'pointer', 'watch');
                    drawnow update;
                end                  
                
                % GET GUI TABLE DATA
                %----------------------------------------------------------
                % Load file (except 'model')
                try
                    savedData = load(this.project_fileName, varNames{:}, '-mat');
                catch ME
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update;
                    warndlg('Project file could not be loaded.','File error');
                    return;
                end
                
                % Assign loaded data to the tables and models.
                try
                    this.tab_Project.project_name.String = savedData.tableData.tab_Project.title;
                    this.tab_Project.project_description.String = savedData.tableData.tab_Project.description;
                catch ME
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update;
                    warndlg('Data could not be assigned to the user interface table: Project Description','File table data error');
                     set(this.Figure, 'pointer', 'watch');
                     drawnow update;
                end
                try
                    if size(savedData.tableData.tab_DataPrep,2)==17
                       savedData.tableData.tab_DataPrep = [ savedData.tableData.tab_DataPrep(:,1:14), ...
                                                            repmat(false,size(savedData.tableData.tab_DataPrep,1),1), ...
                                                            savedData.tableData.tab_DataPrep(:,15:17) ];
                    end
                    this.tab_DataPrep.Table.Data = savedData.tableData.tab_DataPrep;
                    
                    % Update row numbers
                    nrows = size(this.tab_DataPrep.Table.Data,1);
                    this.tab_DataPrep.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                    
                catch ME
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update;
                    warndlg('Data could not be assigned to the user interface table: Data Preparation','File table data error');
                     set(this.Figure, 'pointer', 'watch');
                     drawnow update;
                end               
                try

                    this.tab_ModelConstruction.Table.Data = savedData.tableData.tab_ModelConstruction;
                    
                    % Update row numbers
                    nrows = size(this.tab_ModelConstruction.Table.Data,1);
                    this.tab_ModelConstruction.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));     
                catch ME
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update;
                    warndlg('Data could not be assigned to the user interface table: Model Construction','File table data error');
                     set(this.Figure, 'pointer', 'watch');
                     drawnow update;
                end     
                
                try       
                    
                    % Check if the input calibration table has 14 columns.
                    % If so, then delete the calib settings column.
                    if size(savedData.tableData.tab_ModelCalibration,2)==14
                        savedData.tableData.tab_ModelCalibration = savedData.tableData.tab_ModelCalibration(:,[1:8,10:14]);
                    end
                    
                    % The following loop addresses a problem that first
                    % arose with the MCMC calibration (ie DREAM) whereby
                    % the calib perforamnce states were shown for posterior all
                    % parameter sets. The code eblow simple takes the coe
                    % values from the GUI table and recalculates the mean.
                    % Obviously if there is only one value listed then
                    % this code does not chnage the result.
                    if doPerforamnceMeasureRestimation
                        % This code allows the recalculation of the model
                        % performance statistics. Uncomment if required.
                        h = waitbar(0,'Recalculating performance metrics. Please wait ...');
                        for i=1:size(savedData.tableData.tab_ModelCalibration,1)
                            
                            % update progress bar
                            waitbar(i/size(savedData.tableData.tab_ModelCalibration,1));
                            
                            % Get model lable
                            model_Label = savedData.tableData.tab_ModelCalibration{i,2};
                            model_Label = HydroSight_GUI.removeHTMLTags(model_Label); 
                            model_Label = HydroSight_GUI.modelLabel2FieldName(model_Label);
                            try
                                tmpModel = getModel(this,model_Label);                        
                            catch ME
                                savedData.tableData.tab_ModelCalibration{i,10} = '<html><font color = "#808080">(NA)</font></html>';
                                savedData.tableData.tab_ModelCalibration{i,12} = '<html><font color = "#808080">(NA)</font></html>';
                                savedData.tableData.tab_ModelCalibration{i,13} = '<html><font color = "#808080">(NA)</font></html>';                            
                                continue;
                            end

                            if ~isempty(tmpModel.calibrationResults) && tmpModel.calibrationResults.isCalibrated
                                head_calib_resid = tmpModel.calibrationResults.data.modelledHead_residuals;
                                SSE = sum(head_calib_resid.^2);
                                RMSE = sqrt( 1/size(head_calib_resid,1) * SSE);
                                tmpModel.calibrationResults.performance.RMSE = RMSE;                        

                                % CoE
                                obsHead =  tmpModel.calibrationResults.data.obsHead;
                                tmpModel.calibrationResults.performance.CoeffOfEfficiency_mean.description = 'Coefficient of Efficiency (CoE) calculated using a base model of the mean observed head. If the CoE > 0 then the model produces an estimate better than the mean head.';
                                tmpModel.calibrationResults.performance.CoeffOfEfficiency_mean.base_estimate = mean(obsHead(:,2));            
                                tmpModel.calibrationResults.performance.CoeffOfEfficiency_mean.CoE  = 1 - SSE./sum( (obsHead(:,2) - mean(obsHead(:,2)) ).^2);            
                                                                
                                CoE_cal = median(tmpModel.calibrationResults.performance.CoeffOfEfficiency_mean.CoE);
                                AICc = median(tmpModel.calibrationResults.performance.AICc);
                                BIC = median(tmpModel.calibrationResults.performance.BIC);

                                savedData.tableData.tab_ModelCalibration{i,10} = ['<html><font color = "#808080">',num2str(CoE_cal),'</font></html>'];

                                savedData.tableData.tab_ModelCalibration{i,12} = ['<html><font color = "#808080">',num2str(AICc),'</font></html>'];
                                savedData.tableData.tab_ModelCalibration{i,13} = ['<html><font color = "#808080">',num2str(BIC),'</font></html>'];

                                if ~isempty(tmpModel.evaluationResults)
                                    
                                    head_eval_resid = tmpModel.evaluationResults.data.modelledHead_residuals;
                                    obsHead =  tmpModel.evaluationResults.data.obsHead;
                                    
                                    % Mean error
                                    tmpModel.evaluationResults.performance.mean_error = mean(head_eval_resid); 

                                    %RMSE
                                    SSE = sum(head_eval_resid.^2);
                                    tmpModel.evaluationResults.performance.RMSE = sqrt( 1/size(head_eval_resid,1) * SSE);                

                                    % Unbiased CoE
                                    residuals_unbiased = bsxfun(@minus,head_eval_resid, tmpModel.evaluationResults.performance.mean_error);
                                    SSE = sum(residuals_unbiased.^2);
                                    tmpModel.evaluationResults.performance.CoeffOfEfficiency_mean.CoE_unbias  = 1 - SSE./sum( (obsHead(:,2) - mean(obsHead(:,2)) ).^2);            
                                    
                                    CoE_eval = median(tmpModel.evaluationResults.performance.CoeffOfEfficiency_mean.CoE_unbias);
                                    savedData.tableData.tab_ModelCalibration{i,11} = ['<html><font color = "#808080">',num2str(CoE_eval),'</font></html>'];
                                else
                                    savedData.tableData.tab_ModelCalibration{i,11} = '<html><font color = "#808080">(NA)</font></html>';
                                end  
                                
                                % Save model
                                setModel(this,model_Label, tmpModel);                        
                            else
                                savedData.tableData.tab_ModelCalibration{i,10} = '<html><font color = "#808080">(NA)</font></html>';
                                savedData.tableData.tab_ModelCalibration{i,12} = '<html><font color = "#808080">(NA)</font></html>';
                                savedData.tableData.tab_ModelCalibration{i,13} = '<html><font color = "#808080">(NA)</font></html>';
                            end
                        end
                       close (h);
                    else
                        colInd=[10:13];
                        for i=colInd                    
                            performanceStat = HydroSight_GUI.removeHTMLTags(savedData.tableData.tab_ModelCalibration(:,i));
                            ind = cellfun(@(x) isempty(x) || strcmp(x,'(NA)'), performanceStat);
                            performanceStat(ind) = repmat({'<html><font color = "#808080">(NA)</font></html>'},sum(ind),1);
                            performanceStat(~ind) = cellfun( @(x) ['<html><font color = "#808080">',num2str(median(str2num(x))),'</font></html>'],performanceStat(~ind),'UniformOutput',false);
                            savedData.tableData.tab_ModelCalibration(:,i) = performanceStat;
                        end
                    end
                    this.tab_ModelCalibration.Table.Data = savedData.tableData.tab_ModelCalibration;
                    
                    % Update row numbers
                    nrows = size(this.tab_ModelCalibration.Table.Data,1);
                    this.tab_ModelCalibration.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));           
                catch ME
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update;
                    warndlg('Data could not be assigned to the user interface table: Model Calibration','File table data error');
                     set(this.Figure, 'pointer', 'watch');
                     drawnow update;
                end                
                try
                    this.tab_ModelSimulation.Table.Data = savedData.tableData.tab_ModelSimulation;
                    
                    % Update row numbers
                    nrows = size(this.tab_ModelSimulation.Table.Data,1);
                    this.tab_ModelSimulation.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                       
                catch ME
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update;
                    warndlg('Data could not be assigned to the user interface table: Model Simulation','File table data error');
                    set(this.Figure, 'pointer', 'watch');
                    drawnow update;
                end                              
                    
                % Assign analysed bores.
                try
                    this.dataPrep = savedData.dataPrep;
                catch ME
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update;
                    warndlg('Loaded data analysis results could not be assigned to the user interface.','File model data error');
                    set(this.Figure, 'pointer', 'watch');
                    drawnow update;
                end          
                
                % Update GUI title
                set(this.Figure,'Name',['HydroSight - ', this.project_fileName]);
                drawnow update;   
                
                % Enable file menu items
                for i=1:size(this.figure_Menu.Children,1)
                    if strcmp(get(this.figure_Menu.Children(i),'Label'), 'Save Project')
                        set(this.figure_Menu.Children(i),'Enable','on');
                    elseif strcmp(get(this.figure_Menu.Children(i),'Label'), 'Move models from RAM to HDD...') || ...
                    strcmp(get(this.figure_Menu.Children(i),'Label'), 'Move models from HDD to RAM...')
                        if this.modelsOnHDD
                            set(this.figure_Menu.Children(i),'Label', 'Move models from HDD to RAM...');
                        else
                            set(this.figure_Menu.Children(i),'Label', 'Move models from RAM to HDD...');
                        end
                        set(this.figure_Menu.Children(i),'Enable','on');
                    end       
                end

            end
            set(this.Figure, 'pointer', 'arrow');
            drawnow update;                    
        end

        function onImportModel(this,hObject,eventdata)

            % Get current project folder
            projectPath='';                
            if isdir(this.project_fileName)
                projectPath = this.project_fileName;
            else
                projectPath = fileparts(this.project_fileName);
            end
            
            % Show open file window
             if isempty(projectPath)
                [fName,pName] = uigetfile({'*.mat'},'Select project file for importing...'); 
            else
                [fName,pName] = uigetfile({'*.mat'},'Select project file for importing...', projectPath); 
            end            
            if fName~=0;
                % Assign file name to date cell array
                fName = fullfile(pName,fName);
            else
                return;
            end            
            
            set(this.Figure, 'pointer', 'watch');
            drawnow update;   
            
            % Check models are not stored off the HDD
            newProject = load(this.project_fileName, 'settings','-mat');
            if isfield(newProject.settings,'modelsOnHDD') && ~isempty(newProject.settings.modelsOnHDD)
                warndlg({'The new project has the models offloaded to the hard-drive..';''; ...
                         'Importing of such models s not yet supported.'},'Models cannot be imported...','modal');                
                return
            end    
            
            newProjectGUITables = load(fName, 'tableData','-mat');
            
            % Load models
            newProject = load(fName, '-mat');
            filt = strcmp(fieldnames(newProject),'dataPrep') | ...
                   strcmp(fieldnames(newProject),'settings') |  ...
                   strcmp(fieldnames(newProject),'tableData') |  ...
                   strcmp(fieldnames(newProject),'model_labels');
            removedFields = fieldnames(newProject);
            removedFields = removedFields(filt);                            
            newProject = rmfield(newProject,removedFields);
            
            set(this.Figure, 'pointer', 'arrow');
            drawnow update;               
            
            % Show list models
            newModelNames = fieldnames(newProject);
            [listSelection,ok] = listdlg('PromptString',{'Below is a list of the built models within the selected project.','Select the models(s) to import.'}, ...
                                    'ListString',newModelNames, ...
                                    'ListSize',[400,300], ...
                                    'Name','Select models to import ...');
            if ok~=1  
                return
            end
                
            set(this.Figure, 'pointer', 'watch');
            drawnow update;               
            
            % Import selected models  
            importedModels = cell(0,1);
            nModels = 0;
            for i=1:length(listSelection)
                
                % Build new model label                
                newModelLabel = newModelNames{listSelection(i)};
                ModelLabel = newModelLabel;
                nModels = nModels +1;
                importedModels{nModels,1} = newModelLabel;
                
                % Check if model exists
                if isfield(this.models,newModelLabel)
                    newModelLabel = [newModelLabel,'_imported'];
                end
                
                % Find the model within the GUI tables.
                filt = strcmp(newProjectGUITables.tableData.tab_ModelConstruction(:,2), ModelLabel);
                if ~isempty(filt)
                    newTableData = newProjectGUITables.tableData.tab_ModelConstruction(filt,:);
                    if size(newTableData,2) ~=size(this.tab_ModelConstruction.Table.Data,2)
                        importedModels{nModels,1} = [importedModels{nModels,1},': Error - construction table inconsistency'];
                        continue
                    end
                    newTableData{1,2} = strrep(newTableData{1,2}, ModelLabel, newModelLabel);
                    this.tab_ModelConstruction.Table.Data(end+1,:)=newTableData(1,:);
                    this.tab_ModelConstruction.Table.RowName{end+1} = num2str(str2num(this.tab_ModelConstruction.Table.RowName{end})+1);
                end
                newProjectTableLabels = HydroSight_GUI.removeHTMLTags(newProjectGUITables.tableData.tab_ModelCalibration(:,2));
                filt = strcmp(newProjectTableLabels, ModelLabel);
                if ~isempty(filt)
                    newTableData = newProjectGUITables.tableData.tab_ModelCalibration(filt,:);
                    if size(newTableData,2) ~=size(this.tab_ModelCalibration.Table.Data,2)
                        importedModels{nModels,1} = [importedModels{nModels,1},': Error - calib. table inconsistency'];
                        continue
                    end
                    newTableData{1,2} = strrep(newTableData{1,2}, ModelLabel, newModelLabel);
                    this.tab_ModelCalibration.Table.Data(end+1,:)=newTableData(1,:);
                    this.tab_ModelCalibration.Table.RowName{end+1} = num2str(str2num(this.tab_ModelCalibration.Table.RowName{end})+1);
                end
                newProjectTableLabels = HydroSight_GUI.removeHTMLTags(newProjectGUITables.tableData.tab_ModelSimulation(:,2));
                filt = strcmp(newProjectTableLabels, ModelLabel);                
                filt = find(strcmp(newProjectGUITables.tableData.tab_ModelSimulation, ModelLabel));
                if ~isempty(filt)
                    for j=filt
                        newTableData = newProjectGUITables.tableData.tab_ModelSimulation(j,:);
                        if size(newTableData,2) ~=size(this.tab_ModelSimulation.Table.Data,2)
                            importedModels{nModels,1} = [importedModels{nModels,1},': Warning - simulation table inconsistency'];
                            break
                        end
                        newTableData{1,2} = strrep(newTableData{1,2}, ModelLabel, newModelLabel);
                        this.tab_ModelSimulation.Table.Data(end+1,:)=newTableData(1,:);
                        this.tab_ModelSimulation.Table.RowName{end+1} = num2str(str2num(this.tab_ModelSimulation.Table.RowName{end})+1);
                    end              
                end
                
                % Add model object and label.
                try          
                    setModel(this, newModelLabel, newProject.(ModelLabel));
                catch ME
                    importedModels{nModels,1} = [importedModels{nModels,1},': Error - model import failure'];
                    continue
                end
                    
                % Record model was added
                importedModels{nModels,1} = [importedModels{nModels,1},': Successfully imported'];
            end
                
            set(this.Figure, 'pointer', 'arrow');
            drawnow update;               
            
            msgbox({'Below is a summary of the importation:','',importedModels{:}}, ...
                         'Model import summary...','modal');    
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
                                 'within the project folder or a sub-folder within it.'},'Input file name invalid.','modal');
                    end
                end

                % Change cursor
                set(this.Figure, 'pointer', 'watch');    
                drawnow update;
                
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
                
                % Get settings
                settings.HPCoffload = this.HPCoffload;
                settings.modelsOnHDD = this.modelsOnHDD;
                
                % Get model labels & calib. status
                model_labels = this.model_labels;                
                
                % Save the GUI tables to the file.
                save(this.project_fileName, 'tableData', 'dataPrep', 'model_labels','settings', '-v7.3');  
                
                % Save models. NOTE: If the models are offloaded to the
                % HDD, then only the file path to the individual model
                % needs to be saved.
                if ~isempty(this.models)
                    try
                        tmpModels = this.models;
                        save(this.project_fileName, '-struct', 'tmpModels', '-append');
                        clear tmpModels;                                       

                        % Enable file menu items
                        for i=1:size(this.figure_Menu.Children,1)
                            if strcmp(get(this.figure_Menu.Children(i),'Label'), 'Save Project')
                                set(this.figure_Menu.Children(i),'Enable','on');
                            elseif strcmp(get(this.figure_Menu.Children(i),'Label'), 'Move models from RAM to HDD...') || ...
                            strcmp(get(this.figure_Menu.Children(i),'Label'), 'Move models from HDD to RAM...')
                                set(this.figure_Menu.Children(i),'Enable','on');
                            end       
                        end

                    catch ME
                        set(this.Figure, 'pointer', 'arrow');
                        drawnow update;
                        warndlg('The project could not be saved. Please check you have write access to the directory.','Project not saved ...');
                        return;
                    end     
                end
                
                % Update GUI title
                set(this.Figure,'Name',['HydroSight - ', this.project_fileName]);                                        
                
            end
            
            % Change cursor
            set(this.Figure, 'pointer', 'arrow');
            drawnow update;
            
        end
        
        % Save model        
        function onSave(this,hObject,eventdata)
        
            if isempty(this.project_fileName) || exist(this.project_fileName,'file') ~= 2;
                onSaveAs(this,hObject,eventdata);
            else               
                % Change cursor
                set(this.Figure, 'pointer', 'watch');   
                drawnow update;
                
                % Collate the tables of data to a temp variable.
                tableData.tab_Project.title = this.tab_Project.project_name.String;
                tableData.tab_Project.description = this.tab_Project.project_description.String;
                tableData.tab_DataPrep = this.tab_DataPrep.Table.Data;
                tableData.tab_ModelConstruction = this.tab_ModelConstruction.Table.Data;
                tableData.tab_ModelCalibration = this.tab_ModelCalibration.Table.Data;
                tableData.tab_ModelSimulation = this.tab_ModelSimulation.Table.Data;
                                
                % Get the data preparation results
                dataPrep = this.dataPrep;
                
                % Get settings
                settings.HPCoffload = this.HPCoffload;
                settings.modelsOnHDD = this.modelsOnHDD;                               
                
                % Get model labels & calib. status
                model_labels = this.model_labels;
                
                % Save the GUI tables to the file.
                save(this.project_fileName, 'tableData', 'dataPrep', 'model_labels','settings', '-v7.3');  
                if ~isempty(this.models)
                    try
                        % Save each model as a single variable in file. If the
                        % models have been offloaded to HDD then only the paths
                        % to the files will be saved.
                        tmpModels = this.models;
                        save(this.project_fileName, '-struct', 'tmpModels', '-append');
                        clear tmpModels;
                    catch
                        set(this.Figure, 'pointer', 'arrow');
                        drawnow update;
                        warndlg('The project models could not be saved. Please check you have write access to the directory.','Project not saved ...');
                        return;                    
                    end
                end
            end            
            
            set(this.Figure, 'pointer', 'arrow');   
            drawnow update;
        end    
        
        % This function runs when the app is closed        
        function onExit(this,hObject,eventdata)    
            
            ans = questdlg('Do you want to save the project before exiting?','Save project?','Yes','No','Cancel','Yes');
            
            % Save project
            if strcmp(ans,'Yes')
                onSave(this,hObject,eventdata);
            end
            
            % Check that it was saved (ie if saveas was called from save() )
            if ~strcmp(ans,'No') && (isempty(this.project_fileName) || exist(this.project_fileName,'file') ~= 2);
                warndlg('HydroSight cannot exit because the project does not appear to have been saved.','Project save error ...');
                return
            end
            
            % Exit
            if strcmp(ans,'Yes') || strcmp(ans,'No')
                delete(this.Figure);
            end
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
                columnName = HydroSight_GUI.removeHTMLTags(eventdata.Source.ColumnName{icol});
                
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
                         if length(tbl.Properties.VariableNames) < 5 || length(tbl.Properties.VariableNames) >8
                            warndlg({'The observed head file must be in one of the following formats:', ...'
                                '  -boreID, year, month, day, head', ...
                                '  -boreID, year, month, day, hour, minute, head', ...
                                '  -boreID, year, month, day, hour, minute, second, head'});
                            return;
                         end
                             
                         % Check columns 2 to 6 are numeric.
                         if any(any(~isnumeric(tbl{:,2:end})))
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
                        modelStatus = HydroSight_GUI.removeHTMLTags(data{eventdata.Indices(1),16});
                        
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
                            %datetick(this.tab_DataPrep.modelOptions.resultsOptions.plots,'x','YY');
                            datetick(this.tab_DataPrep.modelOptions.resultsOptions.plots,'x');
                            xlabel(this.tab_DataPrep.modelOptions.resultsOptions.plots,'Year');
                            ylabel(this.tab_DataPrep.modelOptions.resultsOptions.plots,'Head');
                            hold(this.tab_DataPrep.modelOptions.resultsOptions.plots,'off');
                            box(this.tab_DataPrep.modelOptions.resultsOptions.plots,'on');
                            axis(this.tab_DataPrep.modelOptions.resultsOptions.plots,'tight');
                            legend(this.tab_DataPrep.modelOptions.resultsOptions.plots, legendstring,'Location','eastoutside');
                            
                            % SHow results
                            this.tab_DataPrep.modelOptions.resultsOptions.box.Heights = [-1 -1];
                            
                            % SHow plot icons
                            plotToolbarState(this,'on');
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
                return;
            end            
            
            % Get the current row from the main data preparation table.
            irow = this.tab_DataPrep.currentRow;
            boreID = this.tab_DataPrep.Table.Data{irow, 3};
                
            % Check the row was found.
            if isempty(boreID)
                warndlg('An unexpected system error has occured. Please try re-selecting a grid cell from the main to replot the results.','System error ...');
                return;
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
            this.tab_DataPrep.Table.Data{irow,17} = ['<html><font color = "#808080">',num2str(numErroneouObs),'</font></html>'];
            this.tab_DataPrep.Table.Data{irow,18} = ['<html><font color = "#808080">',num2str(numOutlierObs),'</font></html>'];            
            
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
                         
                         % Check the bore ID is a valid field name.
                         tmp=struct();
                         try 
                             tmp.(newBoreID{1}) = 1;
                         catch ME
                             warndlg('The bore ID is of an invalid format. It must not start with a number. Consider appending a non-numeric prefix, eg "Bore_"','Bore ID error...');
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
            
            % Hide plotting toolbars
            plotToolbarState(this, 'off');
            
            % Get table indexes
            icol=eventdata.Indices(:,2);
            irow=eventdata.Indices(:,1);                        
            
            % Undertake column specific operations.
            if isempty(icol) && isempty(irow)
                return
            end
            
            % Hide the adjacent panels
            this.tab_ModelConstruction.modelOptions.vbox.Heights = [0; 0; 0; 0];
                        
            % Remove HTML tags from the column name
            columnName = HydroSight_GUI.removeHTMLTags(eventdata.Source.ColumnName{icol});

            if ~(strcmp(columnName, 'Obs. Head File') || ...
            strcmp(columnName, 'Forcing Data File') || ...
            strcmp(columnName, 'Coordinates File') || ...
            strcmp(columnName, 'Bore ID') || ...
            strcmp(columnName, 'Model Type') || ...
            strcmp(columnName, 'Model Options'))
                return;
            end
            
            % Record the current row and column numbers
            this.tab_ModelConstruction.currentRow = irow;
            this.tab_ModelConstruction.currentCol = icol;
                        
            % Get the data cell array of the table            
            data=get(hObject,'Data'); 
            
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
                     if length(tbl.Properties.VariableNames) <5 || length(tbl.Properties.VariableNames) >8
                        warndlg({'The observed head file in one of the following structure:', ...
                            '- boreID, year, month, day, head', ...
                            '- boreID, year, month, day, hour, head', ...
                            '- boreID, year, month, day, hour, minute, head', ...
                            '- boreID, year, month, day, hour, minute, second, head', ...
                            });
                        return;
                     end

                     % Check columns 2 to 6 are numeric.
                     if any(any(~isnumeric(tbl{:,2:length(tbl.Properties.VariableNames)})))
                        warndlg(['Columns 2 to ',num2str(length(tbl.Properties.VariableNames)),' within the observed head file must contain only numeric data.']);
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
                        setBoreID(this.tab_ModelConstruction.modelTypes.(modelType).obj, data{irow,6});

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
                            this.tab_ModelConstruction.modelOptions.vbox.Heights = [0; 0;-1; 0];
                         case 'ExpSmooth'
                            this.tab_ModelConstruction.modelOptions.vbox.Heights = [0; 0; 0; 0];
                         otherwise
                             this.tab_ModelConstruction.modelOptions.vbox.Heights =[0; 0; 0; 0];
                     end

                otherwise
                     % Hide the panels.
                     this.tab_ModelConstruction.modelOptions.vbox.Heights = [0; 0 ; 0; 0];
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
            
            % Hide plotting toolbars
            plotToolbarState(this, 'off');            
            
            icol=eventdata.Indices(:,2);
            irow=eventdata.Indices(:,1);                        
            
            % Undertake column specific operations.
            if ~isempty(icol) && ~isempty(irow)

                % Record the current row and column numbers
                this.tab_ModelConstruction.currentRow = irow;
                this.tab_ModelConstruction.currentCol = icol;
            
                % Remove HTML tags from the column name
                columnName = HydroSight_GUI.removeHTMLTags(eventdata.Source.ColumnName{icol});                
                                
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
                    
                    
                    % Convert model label to field label.
                    model_labelAsField = HydroSight_GUI.modelLabel2FieldName(modelLabel);
                    
                    % Check if the model object exists                    
                    if any(strcmp(fieldnames(this.models), model_labelAsField))
                       
                        % Check if the model is calibrated
                        try
                            isCalibrated = this.model_labels{model_labelAsField,1};
                        catch
                            isCalibrated = false;
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
                            this.models = rmfield(this.models,model_labelAsField);
                        end
                                                                        
                        % Change status of the model object.
                        hObject.Data{irow,end} = '<html><font color = "#FF0000">Model not built.</font></html>';

                        % Delete model from calibration table.
                        modelLabels_calibTable =  this.tab_ModelCalibration.Table.Data(:,2);                            
                        modelLabels_calibTable = HydroSight_GUI.removeHTMLTags(modelLabels_calibTable);
                        ind = cellfun( @(x) strcmp(x,modelLabel), modelLabels_calibTable);
                        this.tab_ModelCalibration.Table.Data = this.tab_ModelCalibration.Table.Data(~ind,:);

                        % Update row numbers
                        nrows = size(this.tab_ModelCalibration.Table.Data,1);
                        this.tab_ModelCalibration.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                                     
                        
                        % Delete models from simulations table.
                        modelLabels_simTable =  this.tab_ModelSimulation.Table.Data(:,2);                            
                        modelLabels_simTable = HydroSight_GUI.removeHTMLTags(modelLabels_simTable);
                        ind = cellfun( @(x) strcmp(x,modelLabel), modelLabels_simTable);
                        this.tab_ModelSimulation.Table.Data = this.tab_ModelSimulation.Table.Data(~ind,:);                        
                        
                        % Update row numbers
                        nrows = size(this.tab_ModelSimulation.Table.Data,1);
                        this.tab_ModelSimulation.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                                     
                    end
                    
                end

                
                switch columnName;
                    
                    case 'Model Label'                    
                        % Get current and all modle labels
                        allLabels = hObject.Data(:,2);
                        newLabel = eventdata.NewData;
                        
                        % Check the model label can be converted to an
                        % appropriate field name (for saving)                        
                        if isempty(HydroSight_GUI.modelLabel2FieldName(newLabel))
                            return;
                        end
                        
                        % Check that the model label is unique.
                        newLabel = HydroSight_GUI.createUniqueLabel(allLabels, newLabel, irow);                          
                        
                        % Report error if required
                        if ~strcmp(newLabel, hObject.Data{irow,2})
                            warndlg('The model label must be unique! An extension has been added to the label.','Model label error ...');
                        end                        
                        
                        % Input model label to GUI
                        hObject.Data{irow,2} = newLabel;
                        
                    case 'Model Options'
                        if any(strcmp(hObject.Data{irow,7},{'model_TFN'}))
                            modelOptionsArray = getModelOptions(this.tab_ModelConstruction.modelTypes.(hObject.Data{irow,7}).obj);
                        elseif strcmp(hObject.Data{irow,7},'expSmooth') 
                            % do nothing
                        else
                            error('Model type unmkown.')
                        end
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
                             
                         
                         % Assign model decription to GUI string b8ox                         
                         this.tab_ModelConstruction.modelDescriptions.String = modelDecription; 
                         
                         % Show the description.
                         this.tab_ModelConstruction.modelOptions.vbox.Heights = [0; -1 ; 0; 0];                        
                    otherwise
                            % Do nothing                                             
                end
            end
        end
        
        function modelCalibration_tableSelection(this, hObject, eventdata)
                        
            % Get indexes to table data
            icol=eventdata.Indices(:,2);
            irow=eventdata.Indices(:,1);            
            data=get(hObject,'Data'); % get the data cell array of the table
            
            % Reset stored daily forcing data.
            this.tab_ModelCalibration.resultsOptions.forcingData.data_input = [];
            this.tab_ModelCalibration.resultsOptions.forcingData.data_derived = [];
            this.tab_ModelCalibration.resultsOptions.forcingData.colnames_input = {};
            this.tab_ModelCalibration.resultsOptions.forcingData.colnames_derived = {};
            this.tab_ModelCalibration.resultsOptions.forcingData.filt=[];
            
            % Exit if no cell is selected.
            if isempty(icol) && isempty(irow)
                return
            end
                
            % Record the current row and column numbers
            this.tab_ModelCalibration.currentRow = irow;
            this.tab_ModelCalibration.currentCol = icol;

            % Remove HTML tags from the column name
            columnName  = HydroSight_GUI.removeHTMLTags(eventdata.Source.ColumnName{icol});

            % Exit if no results are to be viewed and none of the following are to columns edits
            if ~(strcmp(columnName, 'Calib. Start Date') || strcmp(columnName, 'Calib. End Date'))                  
                if isfield(this.tab_ModelCalibration,'resultsOptions')
                    if isempty(this.tab_ModelCalibration.resultsOptions.currentTab) || ...
                    isempty(this.tab_ModelCalibration.resultsOptions.currentPlot)
                        return;                    
                    end
                else
                    return
                end
            end

            % Change cursor
            set(this.Figure, 'pointer', 'watch');   
            drawnow update;   

            switch columnName;
                case 'Calib. Start Date'
                    % Get start and end dates of the observed head
                    % data, remove HTML tags and then convert to a
                    % date number.
                    startDate = data{irow,4};
                    endDate = data{irow,5};
                    startDate = HydroSight_GUI.removeHTMLTags(startDate);
                    endDate = HydroSight_GUI.removeHTMLTags(endDate);                        
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
                    startDate = HydroSight_GUI.removeHTMLTags(startDate);
                    endDate = HydroSight_GUI.removeHTMLTags(endDate);
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
            
            % Check there is any table data
            if isempty(data)
                set(this.Figure, 'pointer', 'arrow');   
                drawnow update;                   
                return;
            end            
                         
                        
            % Find index to the calibrated model label within the
            % list of constructed models.
            if isempty(irow)
                set(this.Figure, 'pointer', 'arrow');   
                drawnow update;                                   
                return;
            end
            
            % Find the curretn model label
            calibLabel = HydroSight_GUI.removeHTMLTags(data{this.tab_ModelCalibration.currentRow,2});             
            this.tab_ModelCalibration.currentModel = calibLabel;
            
            % Get a copy of the model object. This is only done to
            % minimise HDD read when the models are off loaded to HDD using
            % matfile();
            tmpModel = getModel(this, calibLabel);
            
            
            % Update table of data
            %-------------------------------------------------------------
            % Display the requested calibration results if the model object
            % exists and there are calibration results.
            if ~isempty(tmpModel) ...
            && isfield(tmpModel.calibrationResults,'isCalibrated') ...
            && tmpModel.calibrationResults.isCalibrated        
        
                    % Show a table of calibration data
                    %---------------------------------
                    % Get the model calibration data.
                    tableData = tmpModel.calibrationResults.data.obsHead;
                    hasModelledDistn = false;
                    if size(tmpModel.calibrationResults.data.modelledHead,2)>2
                        hasModelledDistn = true;
                    end
                    if hasModelledDistn
                        tableData = [tableData, ones(size(tableData,1),1), tmpModel.calibrationResults.data.modelledHead(:,2), ...
                            tmpModel.calibrationResults.data.modelledHead(:,3),tmpModel.calibrationResults.data.modelledHead(:,4), ...                                
                            double(tmpModel.calibrationResults.data.modelledHead_residuals(:,2:4)), ...
                            tmpModel.calibrationResults.data.modelledNoiseBounds(:,end-1:end)];                            
                    else
                        tableData = [tableData, ones(size(tableData,1),1), tmpModel.calibrationResults.data.modelledHead(:,2), ...
                            double(tmpModel.calibrationResults.data.modelledHead_residuals(:,end)), ...
                            tmpModel.calibrationResults.data.modelledNoiseBounds(:,end-1:end)];
                    end
                    % Get evaluation data
                    if isfield(tmpModel.evaluationResults,'data')
                        % Get data
                        evalData = tmpModel.evaluationResults.data.obsHead;
                        if hasModelledDistn
                            evalData = [evalData, zeros(size(evalData,1),1), tmpModel.evaluationResults.data.modelledHead(:,2), ...
                                tmpModel.evaluationResults.data.modelledHead(:,3), tmpModel.evaluationResults.data.modelledHead(:,4), ...
                                double(tmpModel.evaluationResults.data.modelledHead_residuals(:,2:4)), ...
                                tmpModel.evaluationResults.data.modelledNoiseBounds(:,end-1:end)];

                        else
                            evalData = [evalData, zeros(size(evalData,1),1), tmpModel.evaluationResults.data.modelledHead(:,2), ...
                                double(tmpModel.evaluationResults.data.modelledHead_residuals(:,end)), ...
                                tmpModel.evaluationResults.data.modelledNoiseBounds(:,end-1:end)];
                        end
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
                    this.tab_ModelCalibration.resultsOptions.calibPanel.Children.Contents(1).Contents(1).Data = tableData;  

                    if hasModelledDistn
                        this.tab_ModelCalibration.resultsOptions.dataTable.table.ColumnName = {'Year','Month', 'Day','Hour','Minute', 'Obs. Head','Is Calib. Point?','Mod. Head (50th %ile)','Mod. Head (5th %ile)','Mod. Head (95th %ile)','Model Residual (50th %ile)','Model Residual (5th %ile)','Model Residual (95th %ile)','Total Err. (5th %ile)','Total Err. (95th %ile)'};
                    else
                        this.tab_ModelCalibration.resultsOptions.dataTable.table.ColumnName = {'Year','Month', 'Day','Hour','Minute', 'Obs. Head','Is Calib. Point?','Mod. Head','Model Residual','Total Err. (5th %ile)','Total Err. (95th %ile)'};
                    end
                    
                    % Add drop-down options for the derived data and update
                    % plot etc
                    %---------------------------------            
                    % Get index to the model specific outpus tab
                    tab_ind = strcmp(this.tab_ModelCalibration.resultsTabs.TabTitles,'Model Specifics');
                    
                    % Set the model derived drop-down options.
                    obj = findobj(this.tab_ModelCalibration.resultsOptions.modelSpecificsPanel, 'Tag','Model Calibration - derived data dropdown');                    
                    derivedData_types = getDerivedDataTypes(tmpModel);  
                    if isempty(derivedData_types)                        
                        obj.String = {'(none)'};
                        obj.Value = 1;
                        
                        % Disable tab
                        this.tab_ModelCalibration.resultsTabs.TabEnables{tab_ind}='off';                        
                    else
                        % Enable tab
                        this.tab_ModelCalibration.resultsTabs.TabEnables{tab_ind}='on';
                        
                        % Build drop-down data
                        derivedData_types = strcat(derivedData_types(:,1), ':', derivedData_types(:,2));

                        obj.String = derivedData_types;
                        if obj.Value>length(obj.String)
                            obj.Value = min(1,length(obj.String));
                        end   

                        modelCalibration_onUpdateDerivedData(this, hObject, eventdata)                
                    end
    
                    %---------------------------------
                    
                    % Update calibration plot
                    modelCalibration_onUpdatePlotSetting(this);
                    
                    % Show model parameter data
                    %---------------------------------
                    %Get parameters and names 
                    [paramValues, paramsNames] = getParameters(tmpModel.model);  

                    % Add to the table
                    obj = findobj(this.tab_ModelCalibration.resultsOptions.paramsPanel, 'Tag','Model Calibration - parameter table');
                    obj.Data = cell(size(paramValues,1),size(paramValues,2)+2);
                    obj.Data(:,1) = paramsNames(:,1);
                    obj.Data(:,2) = paramsNames(:,2);
                    obj.Data(:,3:end) = num2cell(paramValues);

                    nparams=size(paramValues,2);                        
                    colnames = cell(nparams+2,1);
                    colnames{1,1}='Component Name';
                    colnames{2,1}='Parameter Name';
                    colnames(3:end,1) = strcat(repmat({'Parm. Set '},1,nparams)',num2str([1:nparams]'));
                    obj.ColumnName = colnames;
                    %---------------------------------                    
                                        
                    % Show derived parameter data
                    %---------------------------------
                    % Get table
                    obj = findobj(this.tab_ModelCalibration.resultsOptions.derivedParamsPanel, 'Tag','Model Calibration - derived parameter table');
                    
                    %Get parameters and names 
                    [derivedParamValues, derivedParamsNames] = getDerivedParameters(tmpModel);        

                    % Get tab index for the forcing data tab.
                    tab_ind = strcmp(this.tab_ModelCalibration.resultsTabs.TabTitles,'Derived Parameters');                                        
                    
                    % Add to the table (if not empty)
                    if isempty(derivedParamValues)
                        obj.Data = [];
                        obj.ColumnName = {};
                        
                        % Disable tab if there is no data 
                        this.tab_ModelCalibration.resultsTabs.TabEnables{tab_ind} = 'off';  
                    else
                        % Enable tab if there is no data 
                        this.tab_ModelCalibration.resultsTabs.TabEnables{tab_ind} = 'on';
                        
                        obj.Data = cell(size(derivedParamValues,1),size(derivedParamValues,2)+2);
                        obj.Data(:,1) = derivedParamsNames(:,1);
                        obj.Data(:,2) = derivedParamsNames(:,2);
                        obj.Data(:,3:end) = num2cell(derivedParamValues);

                        nderivedParams=size(derivedParamValues,2);                        
                        colnames = cell(nderivedParams+2,1);
                        colnames{1,1}='Component Name';
                        colnames{2,1}='Parameter Name';
                        colnames(3:end,1) = strcat(repmat({'Parm. Set '},1,nderivedParams)',num2str([1:nderivedParams]'));
                        obj.ColumnName = colnames;
                    end
                    %---------------------------------                               
                    
                    % Show model forcing data
                    %---------------------------------                                        
                    % Get the input forcing data
                    [tableData, forcingData_colnames] = getForcingData(tmpModel);
                    
                    % Get tab index for the forcing data tab.
                    tab_ind = strcmp(this.tab_ModelCalibration.resultsTabs.TabTitles,'Forcing Data');                    
                    
                    % Get the model derived forcing data (if not empty)
                    if isempty(tableData)
                        tableData = [];
                        tableData_derived = [];
                        forcingData_colnames = {};
                        forcingData_colnames_derived= {};
                        this.tab_ModelCalibration.resultsOptions.forcingData.filt = [];
                        
                        % Disable tab if there is no data 
                        this.tab_ModelCalibration.resultsTabs.TabEnables{tab_ind} = 'off';
                    else
                        % Enable tab if there is no data 
                        this.tab_ModelCalibration.resultsTabs.TabEnables{tab_ind} = 'on';
                        
                        
                        if size(paramValues,2)>1
                            % Get forcing data from the first parameter set
                            setParameters(tmpModel.model,paramValues(:,1), paramsNames);  
                            [tableData_derived_tmp, forcingData_colnames_derived] = getDerivedForcingData(tmpModel,tableData(:,1));                                        

                            % Initialise derived forcing data matrix
                            tableData_derived = nan(size(tableData_derived_tmp,1),size(tableData_derived_tmp,2), size(paramValues,2));
                            tableData_derived(:,:,1) = tableData_derived_tmp;
                            clear tableData_derived_tmp;

                            % Change cursor
                            set(this.Figure, 'pointer', 'watch');   
                            drawnow update;                         

                            % Derive forcing using parfor. 
                            % Note, the use of a waitbar with parfor is adapted
                            % from http://au.mathworks.com/matlabcentral/newsreader/view_thread/166139                        
                            poolobj = gcp('nocreate');
                            matlabpoolsize = max(1,poolobj.NumWorkers);
                            nparamSets = size(paramValues,2);
                            nLoops = 10;
                            nparamSetsPerLoop =  ceil(nparamSets/nLoops);
                            startInd = 0;
                            h = waitbar(0, ['Calculating transformed forcing for ', num2str(size(paramValues,2)), ' parameter sets. Please wait ...']);
                            t = tableData(:,1);                        
                            % do a for loop that is big enough to do all necessary iterations

                            for n=1:nLoops ;
                                startInd = min(startInd + (n-1)*nparamSetsPerLoop+1,nparamSets);
                                endInd = min(startInd +nparamSetsPerLoop,nparamSets);
                                parfor z = startInd:endInd 
                                    setParameters(tmpModel.model,paramValues(:,z), paramsNames);  
                                    tableData_derived(:,:,z) = getDerivedForcingData(tmpModel,t);    
                                end
                                % update waitbar each "matlabpoolsize"th iteration
                                waitbar(n/nLoops);
                            end
                            close(h);                                                                    

                            % Change cursor
                            set(this.Figure, 'pointer', 'watch');   
                            drawnow update;                         

                            % Reset all parameters
                            setParameters(tmpModel.model,paramValues, paramsNames);  

                            % Clear model object
                            clear tmpModel

                        else
                            [tableData_derived, forcingData_colnames_derived] = getDerivedForcingData(tmpModel,tableData(:,1)); 
                        end

                        % Calculate year, month, day etc
                        t = datetime(tableData(:,1), 'ConvertFrom','datenum');
                        tableData = [year(t), quarter(t), month(t), week(t,'weekofyear'), day(t), tableData(:,2:end)];                    
                        forcingData_colnames = {'Year','Quarter','Month','Week','Day', forcingData_colnames{2:end}};                        
                    end

                    
                    % Store the daily forcing data. This is just done to
                    % avoid re-loading the model within updateForcingData()
                    % and updateForcinfPlot().
                    this.tab_ModelCalibration.resultsOptions.forcingData.data_input = tableData;
                    this.tab_ModelCalibration.resultsOptions.forcingData.data_derived = tableData_derived;
                    this.tab_ModelCalibration.resultsOptions.forcingData.colnames_input = forcingData_colnames;
                    this.tab_ModelCalibration.resultsOptions.forcingData.colnames_derived = forcingData_colnames_derived;
                    this.tab_ModelCalibration.resultsOptions.forcingData.filt=true(size(tableData,1),1);
                                  
                    % Free up RAM
                    clear tableData_derived tableData
                    
                    % Update table and plots
                    if ~isempty(this.tab_ModelCalibration.resultsOptions.forcingData.data_input)
                        modelCalibration_onUpdateForcingData(this)
                    end
                    %---------------------------------
            end
                           
            % Change cursor
            set(this.Figure, 'pointer', 'arrow');      
            drawnow update;
        end                
        
        function modelCalibration_onUpdatePlotSetting(this, hObject, eventdata)
            
            % Get selected popup menu item
            plotID = this.tab_ModelCalibration.resultsOptions.calibPanel.Children.Contents(1).Contents(2).Contents(2).Value;
            
            % Get a copy of the model object. This is only done to
            % minimise HDD read when the models are off loaded to HDD using
            % matfile();
            tmpModel = getModel(this, this.tab_ModelCalibration.currentModel);

            % Exit if model not found.
            if isempty(tmpModel)    
                % Turn off plot icons
                plotToolbarState(this,'off');  
                
                % Change cursor
                set(this.Figure, 'pointer', 'arrow');   
                drawnow update;                                                   
                return;
            end                                             
            
            % Display the requested calibration results if the model object
            % exists and there are calibration results.
            if ~isempty(tmpModel) ...
            && isfield(tmpModel.calibrationResults,'isCalibrated') ...
            && tmpModel.calibrationResults.isCalibrated        
                
                % Plot calibration result.
                %-----------------------
                % Create an axis handle for the figure.
                obj = findobj(this.tab_ModelCalibration.resultsOptions.calibPanel,'Tag','Model Calibration - results plot');
                delete( findobj(obj ,'type','axes'));
                delete( findobj(obj ,'type','legend'));     
                
                obj = uipanel('Parent', obj);
                axisHandle = axes( 'Parent', obj);
                % Show the calibration plots. NOTE: QQ plot type
                % fails so is skipped
                if plotID<=4
                    calibrateModelPlotResults(tmpModel, plotID, axisHandle);
                else
                    calibrateModelPlotResults(tmpModel, plotID+1, axisHandle);
                end                                
                
                % Plot parameters
                %-----------------------
                [paramValues, paramsNames] = getParameters(tmpModel.model);                          
                paramsNames  = strrep(paramsNames(:,2), '_',' ');

                % Create an axis handle for the figure.
                obj = findobj(this.tab_ModelCalibration.resultsOptions.paramsPanel, 'Tag','Model Calibration - parameter plot');
                delete( findobj(obj ,'type','axes'));
                %delete( findobj(this.tab_ModelCalibration.resultsOptions.paramsPanel.Children.Children(2),'type','legend'));     
                %delete( findobj(this.tab_ModelCalibration.resultsOptions.paramsPanel.Children.Children(2),'type','uipanel'));     
                %h = uipanel('Parent', this.tab_ModelCalibration.resultsOptions.paramsPanel.Children.Children(2));
                axisHandle = axes( 'Parent',obj);

                if size(paramValues,2)==1
                    bar(axisHandle,paramValues);
                    set(axisHandle, 'xTickLabel', paramsNames,'FontSize',8,'xTickLabelRotation',45);
                    ylabel(axisHandle,'Param. value');
                else
                    % A bug seems to occur when the builtin plotmatrix is ran to produce a plot inside a GUI 
                    % whereby the default fig menu items and icons
                    % appear. The version of plotmatrix below has a
                    % a few lines commented out to supress this
                    % proble,m (see lines 232-236)                            
                    [~, ax] = plotmatrix(axisHandle,paramValues', '.');      
                    for i=1:size(ax,1)
                        ylabel(ax(i,1), paramsNames(i),'FontSize',8);
                        xlabel(ax(end,i), paramsNames(i),'FontSize',8);
                    end
                end                
                
                % Plot derived parameters
                %-----------------------
                % Create an axis handle for the figure.
                obj = findobj(this.tab_ModelCalibration.resultsOptions.derivedParamsPanel, 'Tag','Model Calibration - derived parameter plot');
                delete( findobj(obj ,'type','axes'));
                axisHandle = axes( 'Parent',obj);

                % Get data and show
                [paramValues, paramsNames] = getDerivedParameters(tmpModel);                          
                if ~isempty(paramValues)
                    
                    paramsNames = paramsNames(:,2);
                    ind=strfind(paramsNames,':');
                    for i=1:length(ind)
                       if ~isempty(ind{i})
                           paramsNames{i} = paramsNames{i}(1:max(1,ind{i}-1));
                       end
                    end
                    paramsNames  = strrep(paramsNames, '_',' ');

                    if size(paramValues,2)==1
                        bar(axisHandle,paramValues);
                        set(axisHandle, 'xTick', 1:length(paramsNames));
                        set(axisHandle, 'xTickLabel', paramsNames,'FontSize',8,'xTickLabelRotation',45);
                        ylabel(axisHandle,'Derived param. value');
                    else
                        % A bug seems to occur when the builtin plotmatrix is ran to produce a plot inside a GUI 
                        % whereby the default fig menu items and icons
                        % appear. The version of plotmatrix below has a
                        % a few lines commented out to supress this
                        % proble,m (see lines 232-236)                            
                        [~, ax] = plotmatrix(axisHandle,paramValues', '.');      
                        for i=1:size(ax,1)
                            ylabel(ax(i,1), paramsNames(i),'FontSize',8);
                            xlabel(ax(end,i), paramsNames(i),'FontSize',8);
                        end
                    end                       
                    
                end                                           
                %-----------------------         
                                
                drawnow update;
            end
           
            % Turn on plot icons
            plotToolbarState(this,'on');            

            % Chane cursor
            set(this.Figure, 'pointer', 'arrow');   
            drawnow update;           
        end
        
        function modelCalibration_onUpdateForcingData(this, hObject, eventdata)
            
            % Get time step value
            timestepID = this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(1).Contents(2).Value;
            
            % Get the calculate for the time stepa aggregation
            calcID = this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(1).Contents(4).Value;
            calcString = this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(1).Contents(4).String;
            calcString = calcString{calcID};
            
            % check the start and end dates
            sdate = this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(1).Contents(6).String;
            edate = this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(1).Contents(8).String;
            try
                if isempty(sdate)
                    sdate = datetime('01/01/0001','InputFormat','dd/MM/yyyy');
                else
                    sdate=datetime(sdate,'InputFormat','dd/MM/yyyy');
                end
            catch me
               errordlg('The start date does not appear to be in the correct format of dd/mm/yyy.','Input date error ...');
               return;
            end
            try
                if isempty(edate)
                    edate= datetime('31/12/9999','InputFormat','dd/MM/yyyy');
                else                
                    edate = datetime(edate,'InputFormat','dd/MM/yyyy');
                end
            catch me
               errordlg('The end date does not appear to be in the correct format of dd/mm/yyy.','Input date error ...');
               return;
            end            
            if sdate > edate
               errordlg('The end date must be after the start date.','Input date error ...');
               return;                
            end            
                        
            % Get daily input forcing data.
            tableData = this.tab_ModelCalibration.resultsOptions.forcingData.data_input;
            forcingData_colnames = this.tab_ModelCalibration.resultsOptions.forcingData.colnames_input;
                       
            % Exit if no data
            if isempty(tableData)
                return;
            end
            
            % Change cursor
            set(this.Figure, 'pointer', 'watch');      
            drawnow update;
            
            % Get daily model derived forcing data.
            tableData_derived = this.tab_ModelCalibration.resultsOptions.forcingData.data_derived;
            forcingData_colnames_derived = this.tab_ModelCalibration.resultsOptions.forcingData.colnames_derived;            
                        
            % Filter the table data by the input dates
            t = datetime(tableData(:,1),tableData(:,2),tableData(:,3));
            filt = t>=sdate & t<=edate;
            tableData = tableData(filt,:);
            if length(size(tableData_derived))==3
                tableData_derived = tableData_derived(filt,:,:);
            else
                tableData_derived = tableData_derived(filt,:);
            end
            
            % Add filter to object for plotting            
            this.tab_ModelCalibration.resultsOptions.forcingData.filt = filt;                        
            
            % Build forcing data at requested time step
            switch timestepID
                case 1  %daily
                    ind = [1:size(tableData,1)]';
                case 2  % weekly
                     [~,~,ind] = unique(tableData(:,[1,4]),'rows');                           
                case 3  % monthly
                    [~,~,ind] = unique(tableData(:,[1,3]),'rows');                        
                case 4  % quarterly
                    [~,~,ind] = unique(tableData(:,[1,2]),'rows');                        
                case 5  % annually
                    [~,~,ind] = unique(tableData(:,1),'rows');                        
                case 6  % all data
                    ind = ones(size(tableData,1),1);
                otherwise
                    error('Unknown forcing data time ste.')
            end

            % Set function for aggregation equation
            switch calcID             
                case 1  % sum
                    fhandle = @sum;                    
                case 2
                    fhandle = @mean;
                case 3
                    fhandle = @std;
                case 4
                    fhandle = @var;
                case 5
                    fhandle = @skewness;
                case 6
                    fhandle = @min;
                case {7,8,9,10,11,12,13}
                    p = str2num(calcString(1:length(calcString)-7));
                    fhandle = @(x) prctile(x,p);
                case 14
                    fhandle = @max;
                case 15
                    fhandle = @iqr;                    
                case 16
                    fhandle = @(x) sum(x==0);
                case 17
                    fhandle = @(x) sum(x<0);
                case 18
                    fhandle = @(x) sum(x>0);
                otherwise
                    error('Equation for the aggregation of daily data is unkown.');
            end
            
            % Upscale input data
            %----------
            % Only upacale the data if the time step is greater than daily
            if timestepID>1            
                tableData_noDates = tableData(:,6:end);
                [rowidx, colidx] = ndgrid(ind, 1:size(tableData_noDates, 2)) ;
                upscaledData = accumarray([rowidx(:) colidx(:)], tableData_noDates(:), [], fhandle);                
            else
                upscaledData = tableData(:,6:end);
            end
            
            % Upscale derived data and compine with upscaled input data
            if length(size(tableData_derived))==3
                % Build colume names without %iles
                forcingData_colnames_yaxis = {forcingData_colnames{:}, forcingData_colnames_derived{:}};
                
                % Upscale derived data
                for i=1:1:size(tableData_derived, 2)
                    % Only upscale the data if the time step is greater than daily
                    if timestepID>1                                
                        [rowidx, colidx, depthidx] = ndgrid(ind, 1, 1:size(tableData_derived, 3));
                        upscaledData_derived_prctiles = tableData_derived(:,i,:);
                        upscaledData_derived_prctiles = accumarray([rowidx(:) colidx(:) depthidx(:)], upscaledData_derived_prctiles(:), [], fhandle);                
                    else
                        upscaledData_derived_prctiles = tableData_derived(:,i,:);
                    end
                
                    % Calculate percentiles for the upscaled data
                    upscaledData_derived_prctiles = prctile( upscaledData_derived_prctiles,[5 10 25 50 75 90 95],3);
                    upscaledData_derived_prctiles = permute(upscaledData_derived_prctiles,[1 3 2]);

                    % Merge input forcing and percentiles of upsaled derived
                    % forcing
                    upscaledData = [upscaledData, upscaledData_derived_prctiles];
                    
                    
                    % Build column names
                    forcingData_colnames = {forcingData_colnames{:}, ...
                                            [forcingData_colnames_derived{i},'-05th%ile'], ...
                                            [forcingData_colnames_derived{i},'-10th%ile'], ...
                                            [forcingData_colnames_derived{i},'-25th%ile'], ...
                                            [forcingData_colnames_derived{i},'-50th%ile'], ...
                                            [forcingData_colnames_derived{i},'-75th%ile'], ...
                                            [forcingData_colnames_derived{i},'-90th%ile'], ...
                                            [forcingData_colnames_derived{i},'-95th%ile']};                
                end
                                                            
            else    % Upscale derived data
                                
                % Only upscale the data if the time step is greater than daily
                if timestepID>1                                                
                    [rowidx, colidx] = ndgrid(ind, 1:size(tableData_derived, 2)) ;
                    upscaledData_derived = accumarray([rowidx(:) colidx(:)], tableData_derived(:), [], fhandle);                
                    upscaledData = [upscaledData, upscaledData_derived];
                else
                    upscaledData = [upscaledData, tableData_derived];
                end
                
                forcingData_colnames = {forcingData_colnames{:}, forcingData_colnames_derived{:}};
                forcingData_colnames_yaxis = forcingData_colnames;
            end
            
            % Build date column.
            tableData_year = accumarray(ind,tableData(:,1),[],@max);
            tableData_quarter = accumarray(ind,tableData(:,2),[],@max);
            tableData_month = accumarray(ind,tableData(:,3),[],@max);            
            tableData_week = accumarray(ind,tableData(:,4),[],@max);                            
            tableData_day = accumarray(ind,tableData(:,5),[],@(x) x(end));
            
            % Build new table
            tableData = [tableData_year, tableData_quarter, tableData_month, tableData_week, tableData_day, upscaledData];
            
            % Add to the table
            this.tab_ModelCalibration.resultsOptions.forcingPanel.Children.Children(3).Data = tableData;
            this.tab_ModelCalibration.resultsOptions.forcingPanel.Children.Children(3).ColumnName = forcingData_colnames;

            % Get the plotting type
            plotType_val = this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(3).Contents(2).Value;
            plotType = this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(3).Contents(2).String;
            plotType = plotType{plotType_val};            
            
            % Get the currently selected x and y axis options
            forcingData_colnames_xaxis_prior = this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(3).Contents(4).String;
            forcingData_colnames_yaxis_prior = this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(3).Contents(6).String;
            forcingData_value_xaxis_prior = this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(3).Contents(4).Value;
            forcingData_value_yaxis_prior = this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(3).Contents(6).Value;            
                        
            % Update the drop-down x and y axis options
            if any(strfind(plotType,'box-plot'))
                forcingData_colnames_xaxis = {'Date','(none)'};
            else
                %ind = strfind(forcingData_colnames,'th%ile');
                %forcingData_colnames(k>0)=forcingData_colnames(k>0){1:k-3};
                forcingData_colnames_xaxis = {'Date', forcingData_colnames_yaxis{6:end},'(none)'};
            end
            forcingData_colnames_yaxis = {'Date', forcingData_colnames_yaxis{6:end},'(none)'};
            this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(3).Contents(4).String = forcingData_colnames_xaxis;
            this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(3).Contents(6).String = forcingData_colnames_yaxis;

            % Update the selected x anbd y axis items. To do this, the
            % original item is selected, else reset to 1.
            if ~isempty(forcingData_value_xaxis_prior ) && forcingData_value_xaxis_prior >0
                ind = find(strcmp(forcingData_colnames_xaxis, forcingData_colnames_xaxis_prior{forcingData_value_xaxis_prior}));
                if ~isempty(ind)
                    this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(3).Contents(4).Value = ind;    
                else
                    this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(3).Contents(4).Value = 1;
                end                    
            else
                this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(3).Contents(4).Value = 1;
            end
            if ~isempty(forcingData_value_yaxis_prior ) && forcingData_value_yaxis_prior >0
                ind = find(strcmp(forcingData_colnames_yaxis, forcingData_colnames_yaxis_prior{forcingData_value_yaxis_prior}));
                if ~isempty(ind)
                    this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(3).Contents(6).Value = ind;    
                else
                    this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(3).Contents(6).Value = 1;
                end                    
            else
                this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(3).Contents(6).Value = 1;
            end            
            % Update forcing plot
            modelCalibration_onUpdateForcingPlot(this)
            
            % Change cursor
            set(this.Figure, 'pointer', 'arrow');      
            drawnow update;
            
        end

        function modelCalibration_onUpdateForcingPlotType(this, hObject, eventdata)
            
            % Get the forcing data columns
            forcingData_colnames = {this.tab_ModelCalibration.resultsOptions.forcingData.colnames_input{:}, ...
                this.tab_ModelCalibration.resultsOptions.forcingData.colnames_derived{:} };            
            
           % Remove those with %iles
           filt = cellfun(@(x) ~isempty(strfind(x,'-05th%ile')) || ...
                  ~isempty(strfind(x,'-10th%ile')) || ...
                  ~isempty(strfind(x,'-25th%ile')) || ...                                   
                  ~isempty(strfind(x,'-50th%ile')) || ...                                   
                  ~isempty(strfind(x,'-75th%ile')) || ...                                   
                  ~isempty(strfind(x,'-90th%ile')) || ...                                   
                  ~isempty(strfind(x,'-95th%ile')) ...                                   
                  ,forcingData_colnames);       
            if any(filt)
                forcingData_colnames_wpcntiles = forcingData_colnames(filt);  
                forcingData_colnames_wpcntiles = cellfun(@(x) x(1:length(x) - 9),forcingData_colnames_wpcntiles);
                forcingData_colnames_wpcntiles = unique(forcingData_colnames_wpcntiles );
                forcingData_colnames = {forcingData_colnames{~filt}, forcingData_colnames_wpcntiles{:}};
            end
              
              
            % Get the plotting type
            plotType_val = this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(3).Contents(2).Value;
            plotType = this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(3).Contents(2).String;
            plotType = plotType{plotType_val};
            
            % Update the drop-down x and y axis options
            if any(strfind(plotType,'box-plot'))
                this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(3).Contents(4).Value = 1;
                forcingData_colnames_xaxis = {'Date','(none)'};
            else
                forcingData_colnames_xaxis = {'Date', forcingData_colnames{6:end},'(none)'};
            end
            forcingData_colnames_yaxis = {'Date', forcingData_colnames{6:end},'(none)'};
            
            
            this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(3).Contents(4).String = forcingData_colnames_xaxis ;
            this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(3).Contents(6).String = forcingData_colnames_yaxis;
            
        end
        
        function modelCalibration_onUpdateForcingPlot(this, hObject, eventdata)
            
            % Change cursor
            set(this.Figure, 'pointer', 'watch');      
            drawnow update;
                        
            % Turn on plot icons
            plotToolbarState(this,'on');
            
            % Get the calculate for the time step aggregation
            calcID = this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(1).Contents(4).Value;
            calcString = this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(1).Contents(4).String;
            calcString = calcString{calcID};            
            
            % Get the user plotting settings
            plotType_options = this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(3).Contents(2).String;
            plotType_val = this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(3).Contents(2).Value;
            
            xaxis_options = this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(3).Contents(4).String;
            xaxis_val = min(this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(3).Contents(4).Value, ...
                        length(this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(3).Contents(4).String));
            
            yaxis_options = this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(3).Contents(6).String;
            yaxis_val = min(this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(3).Contents(6).Value, ...
                        length(this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(3).Contents(6).String));
                        
            % Get the data
            tableData = this.tab_ModelCalibration.resultsOptions.forcingPanel.Children.Children(3).Data;
            forcingData_colnames = this.tab_ModelCalibration.resultsOptions.forcingPanel.Children.Children(3).ColumnName;
            
            % Calc date
            if xaxis_val==1 || yaxis_val==1
                forcingDates = datetime(tableData(:,1), tableData(:,3), tableData(:,5));
            end
            
            %Check if a box plot is to be created
            plotType_isBoxPlot = false;
            if plotType_val>=6 && plotType_val<=9
                plotType_isBoxPlot = true;
            end
            
            % Get axis data
            xdataHasErrorVals =  false;
            ydataHasErrorVals =  false;
            if xaxis_val==1
                xdata = forcingDates;
                xdataLabel = 'Date';
            elseif xaxis_val~=length(xaxis_options)
                
               % Get the data type to plot
               xdataLabel = xaxis_options{xaxis_val};
                
               % Find the  data columns with the requsted name and extract
               % comulns of data.
               filt = cellfun(@(x) ~isempty(strfind(x,[xdataLabel,'-05th%ile'])) || ...
                      ~isempty(strfind(x,[xdataLabel,'-10th%ile'])) || ...
                      ~isempty(strfind(x,[xdataLabel,'-25th%ile'])) || ...                                   
                      ~isempty(strfind(x,[xdataLabel,'-50th%ile'])) || ...                                   
                      ~isempty(strfind(x,[xdataLabel,'-75th%ile'])) || ...                                   
                      ~isempty(strfind(x,[xdataLabel,'-90th%ile'])) || ...                                   
                      ~isempty(strfind(x,[xdataLabel,'-95th%ile'])) ...                                   
                      ,forcingData_colnames);   
               if ~any(filt)
                    filt =  strcmp(forcingData_colnames,xdataLabel);
               end                  
               xdata =  tableData(:,filt);
               xdataHasErrorVals = sum(filt)>1;
                               
               % Build the y-label
               xSeriesLabel = forcingData_colnames(filt);               
               xSeriesLabel = strrep(xSeriesLabel,'_',' ');
               xdataLabel = strrep(xdataLabel,'_',' ');
               if ~plotType_isBoxPlot 
                xdataLabel = [calcString,' of ',xaxis_options{xaxis_val}];
                xdataLabel = strrep(xdataLabel,'_',' ');
               end
            else
               xdata = [];
               xdataLabel = '(none)';
            end
            if yaxis_val==1
                ydata = forcingDates;
                ydataLabel = 'Date';
            elseif yaxis_val~=length(yaxis_options)
               % Get the data type to plot
               ydataLabel = yaxis_options{yaxis_val};
                
               % Find the  data columns with the requsted name and extract
               % comulns of data.
               filt = cellfun(@(x) ~isempty(strfind(x,[ydataLabel,'-05th%ile'])) || ...
                      ~isempty(strfind(x,[ydataLabel,'-10th%ile'])) || ...
                      ~isempty(strfind(x,[ydataLabel,'-25th%ile'])) || ...                                   
                      ~isempty(strfind(x,[ydataLabel,'-50th%ile'])) || ...                                   
                      ~isempty(strfind(x,[ydataLabel,'-75th%ile'])) || ...                                   
                      ~isempty(strfind(x,[ydataLabel,'-90th%ile'])) || ...                                   
                      ~isempty(strfind(x,[ydataLabel,'-95th%ile'])) ...                                   
                      ,forcingData_colnames);               
               if ~any(filt)
                    filt =  strcmp(forcingData_colnames,ydataLabel);
               end
               ydata =  tableData(:,filt);
               ydataHasErrorVals = sum(filt)>1;
               
               % Build the y-label and series label
               ySeriesLabel = forcingData_colnames(filt);               
               ySeriesLabel = strrep(ySeriesLabel,'_',' ');
               ydataLabel = strrep(ydataLabel,'_',' ');
               if ~plotType_isBoxPlot 
                ydataLabel = [calcString,' of ',ydataLabel];
               end
            else
               ydata = [];
               ydataLabel = '(none)';                
            end

            % Create an axis handle for the figure.
            delete( findobj(this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(4),'type','axes'));
            axisHandle = axes( 'Parent',this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(4));            
            
            % Exit of no data to plot (and not plotting a distrbution)
            if isempty(ydata) && plotType_val<4
                % Change cursor
                set(this.Figure, 'pointer', 'arrow');      
                drawnow update;       
                
                return
            end
            
            % Check if using date for either axis            
            xdata_isdate=false;
            ydata_isdate=false;
            if isdatetime(xdata)                        
                xdata_isdate=true;
            end
            if isdatetime(ydata)            
                ydata_isdate=true;
            end            
            
                        
            switch plotType_val
                case {1,2}     
                    plotSymbol = 'b.-';
                    if plotType_val==2
                        plotSymbol = 'b.';
                    end
                    if xdataHasErrorVals && ydataHasErrorVals
                        plot(axisHandle,xdata, ydata(:,4),plotSymbol);
                        hold(axisHandle,'on');
                        try
                            errorbar(axisHandle,xdata(:,4), ydata(:,4), abs(ydata(:,1)-ydata(:,4)), abs(ydata(:,7)-ydata(:,4)), ...
                            abs(xdata(:,1)-xdata(:,4)), abs(xdata(:,7)-xdata(:,4)),'linestyle','none','color',[0.6 0.6 0.6]);                        
                        catch
                            errorbar(axisHandle,xdata(:,4), ydata(:,4), abs(ydata(:,1)-ydata(:,4)), abs(ydata(:,7)-ydata(:,4)), ...
                                'linestyle','none','color',[0.6 0.6 0.6]);                                                    
                        end
                        legend(axisHandle, 'median','5-95th%ile','Location', 'northeastoutside');
                        hold(axisHandle,'off');
                    elseif ~xdataHasErrorVals && xdata_isdate && ydataHasErrorVals

                        if xdata_isdate
                            xdata = datenum(xdata);
                        end
                        XFill = [xdata' fliplr(xdata')];
                        YFill = [ydata(:,1)', fliplr(ydata(:,7)')];                   
                        fill(XFill, YFill,[0.8 0.8 0.8],'Parent',axisHandle);
                        hold(axisHandle,'on');                    
                        YFill = [ydata(:,2)', fliplr(ydata(:,6)')];                   
                        fill(XFill, YFill,[0.6 0.6 0.6],'Parent',axisHandle);                    
                        hold(axisHandle,'on');
                        YFill = [ydata(:,3)', fliplr(ydata(:,5)')];                   
                        fill(XFill, YFill,[0.4 0.4 0.4],'Parent',axisHandle);                    
                        hold(axisHandle,'on');
                        clear XFill YFill     

                        plot(axisHandle,xdata, ydata(:,4),plotSymbol);
                        hold(axisHandle,'off');
                        
                        % Date date axis. NOTE, code adopted from dateaxis.m.
                        % Pre-2016B dateaxis did not allow input of axis
                        % handle.                        
                        if xdata_isdate;
                            dateaxis_local(axisHandle,'x');
                        end
                        if ydata_isdate;
                            dateaxis_local(axisHandle,'y');
                        end                
                        legend(axisHandle, '5-95th%ile','10-90th%ile','25-75th%ile','median','Location', 'northeastoutside');
                    elseif ~xdataHasErrorVals && ~xdata_isdate && ydataHasErrorVals                        
                        plot(axisHandle,xdata, ydata(:,4),plotSymbol);
                        hold(axisHandle,'on');
                        errorbar(axisHandle,xdata, ydata(:,4), abs(ydata(:,1)-ydata(:,4)), abs(ydata(:,7)-ydata(:,4)),'linestyle','none','color',[0.6 0.6 0.6]);
                        legend(axisHandle, 'median','5-95th%ile','Location', 'northeastoutside');
                        hold(axisHandle,'off');                 
                    elseif xdataHasErrorVals && ~ydataHasErrorVals            
                        plot(axisHandle,xdata, ydata(:,4),plotSymbol);
                        try
                            hold(axisHandle,'on');
                            errorbar(axisHandle,xdata(:,4), ydata, ...
                            abs(xdata(:,1)-xdata(:,4)), abs(xdata(:,7)-xdata(:,4)), 'ornt','horizontal','linestyle','none','color',[0.6 0.6 0.6]);                                                
                        catch
                            % do nothing
                        end           
                        legend(axisHandle, 'median','5-95th%ile','Location', 'northeastoutside');
                        hold(axisHandle,'off');
                    else
                        plot(axisHandle,xdata, ydata,plotSymbol);
                        axis(axisHandle,'tight');                                                
                    end
                    xlabel(axisHandle,xdataLabel);  
                    ylabel(axisHandle,ydataLabel);             
                    
                case 3
                    if strcmp(xdataLabel,'(none)') || strcmp(ydataLabel,'(none)')
                        errordlg('A bar plot requires both x-axis and y-axis inputs.','Axis selection error...');
                        
                        % Change cursor
                        set(this.Figure, 'pointer', 'arrow');      
                        drawnow update;
                                                
                        return;
                    end
                    if xdata_isdate
                        xdata=datenum(xdata);
                        if ydataHasErrorVals
                            bar(axisHandle,xdata, ydata(:,4)); 
                        else
                            bar(axisHandle,xdata, ydata);
                        end
                    end
                    if ydata_isdate
                        ydata=datenum(ydata);
                        if xdataHasErrorVals
                            barh(axisHandle,ydata, xdata(:,4));
                        else
                            barh(axisHandle,ydata, xdata);
                        end
                    end                
                    if ~xdata_isdate && ~ydata_isdate
                        errordlg('A bar plot requires either the x-axis or y-axis to be "Date".','Axis selection error...');
                        
                        % Change cursor
                        set(this.Figure, 'pointer', 'arrow');      
                        drawnow update;                        
                        
                        return;
                    end
                    
                    if xdataHasErrorVals && ~xdata_isdate
                        try
                            hold(axisHandle,'on');
                            errorbar(axisHandle,xdata(:,4), ydata, ...
                            abs(xdata(:,1)-xdata(:,4)), abs(xdata(:,7)-xdata(:,4)), 'ornt','horizontal','linestyle','none','color',[0.6 0.6 0.6]);                                                
                            legend(axisHandle, 'median','5-95th%ile','Location', 'northeastoutside');
                        catch
                            % do nothing
                        end           
                        hold(axisHandle,'off');
                    elseif ydataHasErrorVals && ~ydata_isdate
                        hold(axisHandle,'on');
                        errorbar(axisHandle,xdata, ydata(:,4), ...
                        abs(ydata(:,1)-ydata(:,4)), abs(ydata(:,7)-ydata(:,4)),'linestyle','none','color',[0.6 0.6 0.6]);                                                
                        legend(axisHandle, 'median','5-95th%ile','Location', 'northeastoutside');
                        hold(axisHandle,'off');
                    end
                                                            
                    xlabel(axisHandle,xdataLabel);  
                    ylabel(axisHandle,ydataLabel);    
                    % Date date axis. NOTE, code adaopted from dateaxis.m.
                    % Pre-2016B dateaxis did not allow input of axis
                    % handle.
                    if xdata_isdate;
                        dateaxis_local(axisHandle,'x');
                    end
                    if ydata_isdate;
                        dateaxis_local(axisHandle,'y');
                    end
                    axis(axisHandle,'tight');
                case 4                    
                    if strcmp(ydataLabel,'(none)')
                        if xdataHasErrorVals
                            xdata=xdata(:,4);
                        end
                        histogram(axisHandle,xdata, floor(sqrt(length(xdata))),'Normalization','probability');
                        ylabel(axisHandle,'Probability');             
                        xlabel(axisHandle,xdataLabel);     
                        if xdataHasErrorVals
                            legend(axisHandle, 'Distribution of median','Location', 'northeastoutside');
                        end
                    elseif strcmp(xdataLabel,'(none)')
                        if ydataHasErrorVals
                            ydata=ydata(:,4);
                        end                        
                        histogram(axisHandle,ydata, floor(sqrt(length(ydata))),'Normalization','probability');
                        ylabel(axisHandle,'Probability');             
                        xlabel(axisHandle,ydataLabel);                  
                        if ydataHasErrorVals
                            legend(axisHandle, 'Distribution of median','Location', 'northeastoutside');
                        end                        
                    elseif ~strcmp(xdataLabel,'(none)') && ~strcmp(xdataLabel,'(none)')
                        % Plot median value
                        if xdataHasErrorVals
                            xdata=xdata(:,4);
                        end                        
                        if ydataHasErrorVals
                            ydata=ydata(:,4);
                        end                        
                                                
                        % Convert date is to be plotted
                        if xdata_isdate
                            xdata=datenum(xdata);
                        end
                        if ydata_isdate
                            ydata=datenum(ydata);
                        end
                        
                        % Make bivariate histogram
                        histogram2(axisHandle,xdata,ydata, floor(sqrt(length(xdata))), 'DisplayStyle','tile','ShowEmptyBins','on','Normalization','probability');
                        h = colorbar(axisHandle);
                        xlabel(axisHandle,xdataLabel);  
                        ylabel(axisHandle,ydataLabel);                  
                        ylabel(h,'Probability'); 
                        box(axisHandle,'on');
                        
                        % Date date axis. NOTE, code adaopted from dateaxis.m.
                        % Pre-2016B dateaxis did not allow input of axis
                        % handle.                        
                        if xdata_isdate;
                            dateaxis_local(axisHandle,'x');
                        end
                        if ydata_isdate;
                            dateaxis_local(axisHandle,'y');
                        end
                        if xdataHasErrorVals || ydataHasErrorVals
                            legend(axisHandle, 'Distribution of median','Location', 'northeastoutside');
                        end                        
                    end
                case 5
                    % Convert date is to be plotted
                    if xdata_isdate
                        xdata=datenum(xdata);
                    end
                    if ydata_isdate
                        ydata=datenum(ydata);
                    end

                    % Make CDF plot
                    if strcmp(ydataLabel,'(none)')
                        if xdataHasErrorVals
                            [f, xtmp] = ecdf(xdata(:,1));                            
                            plot(axisHandle, xtmp, f,'linestyle',':','color',[0.8 0.8 0.8]);                            
                            hold(axisHandle,'on');
                            [f, xtmp] = ecdf(xdata(:,2));                            
                            plot(axisHandle, xtmp, f,'linestyle','-.','color',[0.6 0.6 0.6]);                            
                            [f, xtmp] = ecdf(xdata(:,3));                            
                            plot(axisHandle, xtmp, f,'linestyle','--','color',[0.4 0.4 0.4]);                                                        
                            [f, xtmp] = ecdf(xdata(:,4));
                            plot(axisHandle, xtmp, f,'b.-');
                            [f, xtmp] = ecdf(xdata(:,5));                            
                            plot(axisHandle, xtmp, f,'linestyle','--','color',[0.4 0.4 0.4]);                            
                            [f, xtmp] = ecdf(xdata(:,6));                            
                            plot(axisHandle, xtmp, f,'linestyle','-.','color',[0.6 0.6 0.6]);                                                        
                            [f, xtmp] = ecdf(xdata(:,7));                            
                            plot(axisHandle, xtmp, f,'linestyle',':','color',[0.8 0.8 0.8]);                            
                            legend(axisHandle,' 5th%ile','10th%ile','25th%ile','50th%ile','75th%ile','90th%ile','95th%ile','Location', 'northeastoutside');
                            hold(axisHandle,'off');
                        else
                            [f, xdata] = ecdf(xdata);
                            stairs(axisHandle, xdata, f,'b.-');
                        end
                        ylabel(axisHandle,'Probability');             
                        xlabel(axisHandle,xdataLabel);                  
                    elseif strcmp(xdataLabel,'(none)')
                        [f, xdata] = ecdf(ydata);
                        stairs(axisHandle, xdata, f,'b.-');
                        ylabel(axisHandle,'Probability');  
                        xlabel(axisHandle,ydataLabel);                  
                    elseif ~strcmp(xdataLabel,'(none)') && ~strcmp(xdataLabel,'(none)')
                        % Plot median value
                        if xdataHasErrorVals
                            xdata=xdata(:,4);
                        end                        
                        if ydataHasErrorVals
                            ydata=ydata(:,4);
                        end                        
                                                
                        histogram2(axisHandle,xdata,ydata, floor(sqrt(length(xdata))), 'DisplayStyle','tile','ShowEmptyBins','on','Normalization','cdf');
                        h = colorbar(axisHandle);
                        xlabel(axisHandle,xdataLabel);                  
                        ylabel(axisHandle,ydataLabel);                  
                        ylabel(h,'Probability'); 
                        box(axisHandle,'on');
                        
                        if xdataHasErrorVals || ydataHasErrorVals
                            legend(axisHandle, 'Distribution of median','Location', 'northeastoutside');
                        end                            
                    end
                    
                    % Date date axis. NOTE, code adaopted from dateaxis.m.
                    % Pre-2016B dateaxis did not allow input of axis
                    % handle.                        
                    if xdata_isdate;
                        dateaxis_local(axisHandle,'x');
                    end
                    if ydata_isdate;
                        dateaxis_local(axisHandle,'y');
                    end                       
                case {6,7,8,9}      % Box plots at daily sum, monthly sum, 1/4 sum, annual sum
                    
                    if ydataHasErrorVals || xdataHasErrorVals
                        errordlg('HydroSight cannot create box plots of ensemble data (ie as derived from DREAM calibation).', 'Feature unavailable ...')
                        
                        % Change cursor
                        set(this.Figure, 'pointer', 'arrow');      
                        drawnow update;                        
                        
                        return
                    end
                    
                    % Check the x-axis is date
                    if xdata_isdate                  
                        xdata=datenum(xdata);
                    else
                        errordlg('The x-axis must plot the "Date" for box plots.','Axis selection error...');
                        
                        % Change cursor
                        set(this.Figure, 'pointer', 'arrow');      
                        drawnow update;                        
                        
                        return;
                    end
                    if isdatetime(ydata)
                        errordlg('Only the x-axis can set to "Date" for box plots.','Axis selection error...');

                        % Change cursor
                        set(this.Figure, 'pointer', 'arrow');      
                        drawnow update;                        
                        
                        return;
                    end

                    % Get the daily data and apply time filter
                    tableData = [this.tab_ModelCalibration.resultsOptions.forcingData.data_input, ...
                                 this.tab_ModelCalibration.resultsOptions.forcingData.data_derived];                    
                    forcingData_colnames = {this.tab_ModelCalibration.resultsOptions.forcingData.colnames_input{:}, ...
                                this.tab_ModelCalibration.resultsOptions.forcingData.colnames_derived{:} };            

                    filt  = this.tab_ModelCalibration.resultsOptions.forcingData.filt;
                    tableData = tableData(filt,:);
                    
                    % re-extract ydata
                    ydata = tableData(:,yaxis_val+4);
    
                    % Calculate time steps                    
                    tableData = [tableData(:,1:5),ydata];                    
                    forcingData_colnames = {forcingData_colnames{1:5}, ydataLabel};                    
                 
                    % Get the calculate for the time stepa aggregation
                    calcID = this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(1).Contents(4).Value;
                    calcString = this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(1).Contents(4).String;
                    calcString = calcString{calcID};                    
                    
                    % Set function for aggregation equation
                    switch calcID             
                        case 1  % sum
                            fhandle = @sum;                    
                        case 2
                            fhandle = @mean;
                        case 3
                            fhandle = @std;
                        case 4
                            fhandle = @var;
                        case 5
                            fhandle = @skewness;
                        case 6
                            fhandle = @min;
                        case {7,8,9,10,11,12,13}
                            p = str2num(calcString(1:length(calcString)-7));
                            fhandle = @(x) prctile(x,p);
                        case 14
                            fhandle = @max;
                        case 15
                            fhandle = @iqr;                    
                        otherwise
                            error('Equation for the aggregation of daily data is unkown.');
                    end

                    
                    % Sum the data to the required sum time step
                    switch plotType_val
                        case 6  %daily
                            ind = [1:size(tableData,1)]';
                            ydataLabel = [ydataLabel, ' (daily rate)'];
                        case 7  % monthly
                            [~,~,ind] = unique(tableData(:,[1,3]),'rows');
                            ydataLabel = [ydataLabel, ' (monthly ',calcString,')'];
                        case 8  % quarterly
                            [~,~,ind] = unique(tableData(:,[1,2]),'rows');   
                            ydataLabel = [ydataLabel, ' (quarterly ',calcString,')'];
                        case 9  % annually
                            [~,~,ind] = unique(tableData(:,1),'rows');                        
                            ydataLabel = [ydataLabel, ' (annual ',calcString,')'];
                        otherwise
                            error('Unknown type of box plot.')
                    end
                    tableData_sum = accumarray(ind,tableData(:,end),[],fhandle);

                    % Build date column and new tableData.
                    tableData_year = accumarray(ind,tableData(:,1),[],@max);
                    tableData_quarter = accumarray(ind,tableData(:,2),[],@max);
                    tableData_month = accumarray(ind,tableData(:,3),[],@max);            
                    tableData_week = accumarray(ind,tableData(:,4),[],@max);                            
                    tableData_day = accumarray(ind,tableData(:,5),[],@(x) x(end));
                    tableData = [tableData_year, tableData_quarter, tableData_month, tableData_week, tableData_day, tableData_sum];
                    
                    % Get time step value
                    timestepID = this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(1).Contents(2).Value;
                    
                    % Group the y-data to the next greatest time step
                    % Build foring data at requtested time step

                    % Build foring data at requtested time step
                    switch timestepID
                        case 1  %daily
                            ind = [1:size(tableData,1)]';                            
                        case 2  % weekly
                             [~,~,ind] = unique(tableData(:,[1,4]),'rows');                         
                             xdataTickLabels = 'dd/mm/yy'; 
                             xdataLabel = 'Date';
                        case 3  % monthly
                            [~,~,ind] = unique(tableData(:,[1,3]),'rows');                        
                            xdataTickLabels = 'mmyy';      
                            xdataLabel = 'Month-Year';
                        case 4  % quarterly
                            [~,~,ind] = unique(tableData(:,[1,2]),'rows');                            
                            xdataTickLabels = 'QQ-YY';
                            xdataLabel = 'Quarter-Year';
                        case 5  % annually
                            [~,~,ind] = unique(tableData(:,1),'rows');                              
                            xdataTickLabels = 'YY';
                            xdataLabel = 'Year';
                        case 6  % all data
                            ind = ones(size(tableData,1),1);
                            xdataTickLabels = '';
                            xdataLabel = '';
                        otherwise
                            error('Unknown forcing data time step.')
                    end                                        

                    % Build box plot
                    if plotType_val==6
                        boxplot(axisHandle,tableData(:,end), ind,'notch','on','ExtremeMode','clip','Jitter',0.75,'symbol','.');                    
                    else
                        boxplot(axisHandle,tableData(:,end), ind,'notch','off','ExtremeMode','clip','Jitter',0.75,'symbol','.');                    
                    end
                    
                    %Add x tick labels
                    if timestepID<6
                        tableData_year = accumarray(ind,tableData(:,1),[],@max);
                        tableData_month = accumarray(ind,tableData(:,3),[],@max);            
                        tableData_day = accumarray(ind,tableData(:,5),[],@(x) x(end));
                        t = unique(datenum(tableData_year, tableData_month, tableData_day));
                        xdataTickLabels = datestr(t,xdataTickLabels);
                        set(axisHandle, 'XTickLabel',xdataTickLabels);
                        xlabel(axisHandle,xdataLabel); 
                    else
                        set(axisHandle, 'XTickLabel',xdataTickLabels);
                        xlabel(axisHandle,xdataLabel);                         
                    end                   
                    ylabel(axisHandle,ydataLabel);                  
                    
                otherwise
                    error('Unknown forcing data plot type.')                    
            end                    
            
            box(axisHandle,'on');
            axis(axisHandle,'tight');            
            hold(axisHandle,'off');
            
            % Change cursor
            set(this.Figure, 'pointer', 'arrow');      
            drawnow update;            
            
            function dateaxis_local(ax, tickaxis)
                % Determine range of data and choose appropriate label format 
                Lim= get(ax, [tickaxis,'lim']);
                Cond = Lim(2)-Lim(1); 

                if Cond <= 14 % Range less than 15 days, day of week   
                    dateform = 7;  
                elseif Cond > 14 && Cond <= 31 % Range less than 32 days, day of month 
                    dateform = 6; 
                elseif Cond > 31 && Cond <= 180 % Range less than 181 days, month/day 
                    dateform = 5; 
                elseif Cond > 180 && Cond <= 365  % Range less than 366 days, 3 letter month 
                    dateform = 3; 
                elseif Cond > 365 && Cond <= 365*3 % Range less than 3 years, month year  
                    dateform = 11; 
                else % Range greater than 3 years, 2 digit year 
                    dateform = 10; 
                end 

                % Get axis tick values and add appropriate start date. 
                xl = get(ax,[tickaxis,'tick'])'; 
                set(ax,[tickaxis,'tickmode'],'manual',[tickaxis,'limmode'],'manual') 
                n = length(xl); 

                % Guarantee that the day, month, and year strings have the 
                % the same number of characters
                switch dateform
                  case {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16} 
                    dstr = datestr(xl,dateform);
                  case 17 % Year/Month/Day  (ISO format)    
                    dstr = datestr(xl,25);
                  otherwise
                    error(message('finance:calendar:dateAxis'))       
                end 

                % Set axis tick labels 
                set(ax,[tickaxis,'ticklabel'],dstr)                         
            end
        end       
        
        % Get derived data AND add data table and plot.
        function modelCalibration_onUpdateDerivedData(this, hObject, eventdata)
       
            % Record the current row and column numbers
            irow = this.tab_ModelCalibration.currentRow;
            icol = this.tab_ModelCalibration.currentCol;

            % Get the calibration table data
            obj = this.tab_ModelCalibration.Table;
            data = obj.Data;
            
            % Find index to the calibrated model label within the
            % list of constructed models.
            if isempty(irow)
                set(this.Figure, 'pointer', 'arrow');   
                drawnow update;                                   
                return;
            end
            
            % Find the curretn model label
            calibLabel = HydroSight_GUI.removeHTMLTags(data{irow,2});             
            this.tab_ModelCalibration.currentModel = calibLabel;
            
            % Get a copy of the model object. This is only done to
            % minimise HDD read when the models are off loaded to HDD using
            % matfile();
            tmpModel = getModel(this, calibLabel);            
            
            % Display the requested calibration results if the model object
            % exists and there are calibration results.
            if ~isempty(tmpModel) ...
            && isfield(tmpModel.calibrationResults,'isCalibrated') ...
            && tmpModel.calibrationResults.isCalibrated  
            
                % Get model specific derived data and plot etc
                %-----------------------             
                % Create an axis handle for the figure.
                obj = findobj(this.tab_ModelCalibration.resultsOptions.modelSpecificsPanel, 'Tag','Model Calibration - derived data plot'); 
                delete( findobj(obj ,'type','axes'));
                axisHandle = axes( 'Parent',obj);                

                % Get length of forcing data.
                t = getForcingData(tmpModel);
                t = [1:max(t(:,1))-min(t(1,1))]';

                obj = findobj(this.tab_ModelCalibration.resultsOptions.modelSpecificsPanel, 'Tag','Model Calibration - derived data dropdown');                    
                derivedData_type = obj.String;
                derivedData_type = derivedData_type{obj.Value};
                ind = strfind(derivedData_type,':');
                modelComponant = derivedData_type(1:ind(1)-1);
                derivedData_variable = derivedData_type(ind(1)+1:end);
                [derivedData, derivedData_names] = getDerivedData(tmpModel, modelComponant, derivedData_variable, t, axisHandle);

                obj = findobj(this.tab_ModelCalibration.resultsOptions.modelSpecificsPanel, 'Tag','Model Calibration - derived data table');                    
                obj.Data = derivedData;
                obj.ColumnName = derivedData_names;
                drawnow update;            
            else
                errordlg(['The following selected model must be calibrated to display the results:',calibLabel],'Model not calibrated ...');
            end            
        end
        
        function modelSimulation_tableEdit(this, hObject, eventdata)

            % Change cursor
            set(this.Figure, 'pointer', 'watch');                
            drawnow update;            
            
            % Get GUI table indexes
            icol=eventdata.Indices(:,2);
            irow=eventdata.Indices(:,1);            
            data=get(hObject,'Data'); % get the data cell array of the table
                        
            % Undertake column specific operations.
            if ~isempty(icol) && ~isempty(irow)
                
                % Record the current row and column numbers
                this.tab_ModelSimulation.currentRow = irow;
                this.tab_ModelSimulation.currentCol = icol;
            
                % Remove HTML tags from the column name
                columnName = HydroSight_GUI.removeHTMLTags(eventdata.Source.ColumnName{icol});
                
                switch columnName;
                    % Get the selected model.
                    case 'Model Label'
                        
                        % Get the selected model for simulation
                        calibLabel = eventdata.EditData;

                        % Check if any models are calibrated.
                        if strcmp(calibLabel,'(none calibrated)')
                            return;
                        end
                        
                        % Get a copy of the model object. This is only done to
                        % minimise HDD read when the models are off loaded to HDD using
                        % matfile();
                        tmpModel = getModel(this, calibLabel);

                        % Exit if model is model not found
                        if isempty(tmpModel) || ~tmpModel.calibrationResults.isCalibrated
                            set(this.Figure, 'pointer', 'arrow');
                            drawnow update;                            
                            return
                        end                        
                        
                        % Assign data from the calbration toable to the simulation
                        % table.
                        irow = eventdata.Indices(:,1);     
                        headData = getObservedHead(tmpModel);
                        obshead_start = floor(min(headData(:,1)));
                        obshead_end = max(headData(:,1));
                        boreID = tmpModel.bore_ID;
                        if size(hObject.Data,1)<irow
                            hObject.Data = [hObject.Data; cell(1,size(hObject.Data,2))];

                        end
                        hObject.Data{irow,1} = false;
                        hObject.Data{irow,2} = calibLabel;
                        hObject.Data{irow,3} = ['<html><font color = "#808080">',boreID,'</font></html>'];
                        hObject.Data{irow,4} = ['<html><font color = "#808080">',datestr(obshead_start,'dd-mmm-yyyy'),'</font></html>'];
                        hObject.Data{irow,5} = ['<html><font color = "#808080">',datestr(obshead_end,'dd-mmm-yyyy'),'</font></html>'];
                        hObject.Data{irow,6} = '';
                        hObject.Data{irow,7} = '';
                        hObject.Data{irow,8} = '';
                        hObject.Data{irow,9} = '';
                        hObject.Data{irow,10} = '';   
                        hObject.Data{irow,11} = false;   
                        hObject.Data{irow,12} = '<html><font color = "#FF0000">Not Simulated.</font></html>';
                        
                        % Update status in GUI
                        drawnow update                        
                        
                    % Check the input model simulation label is unique for the selected model.    
                    case 'Simulation Label'                        
                        %  Check if the new model label is unique and
                        %  create a new label if not.
                        allLabels = hObject.Data(:,[2,6]);
                        newLabel = {hObject.Data{irow, 2}, eventdata.EditData};
                        newLabel = HydroSight_GUI.createUniqueLabel(allLabels, newLabel, irow);                        
                        hObject.Data{irow,6} = newLabel{2};

                        % Warn user if the label has chnaged.
                        if ~strcmp(newLabel, eventdata.EditData)
                            warndlg('The model and simulation label pair must be unique. An modified label has been input','Error ...');
                        end                        
                end
            end
            
            set(this.Figure, 'pointer', 'arrow');
            drawnow update;                            

        end        
        
        function modelSimulation_tableSelection(this, hObject, eventdata)
            
            % Hide plotting toolbar
            plotToolbarState(this,'off');
                       
            % Get GUI table indexes            
            icol=eventdata.Indices(:,2);
            irow=eventdata.Indices(:,1);                        
            
            % Exit of no cells are selected
            if isempty(icol) && isempty(irow)
                return
            end

            % Remove HTML tags from the column name
            columnName = HydroSight_GUI.removeHTMLTags(eventdata.Source.ColumnName{icol});            
            
            % Exit if no cells edits are to be dealt with and no results
            % are to viewed.
            if ~(strcmp(columnName, 'Model Label') ||  strcmp(columnName, 'Forcing Data File') || ...
            strcmp(columnName, 'Simulation Start Date') || strcmp(columnName, 'Simulation End Date'))
        
                if isfield( this.tab_ModelSimulation,'resultsOptions')
                    if this.tab_ModelSimulation.resultsOptions.popup.Value==3
                        return
                    end
                else
                    return
                end
            end

            % Record the current row and column numbers
            this.tab_ModelSimulation.currentRow = irow;
            this.tab_ModelSimulation.currentCol = icol;            
            
            % Get table data
            data=get(hObject,'Data'); % get the data cell array of the table
            
            % Change cursor
            set(this.Figure, 'pointer', 'watch');                
            drawnow update;            

            switch columnName;
                case 'Model Label'
                    % Get list of models
                    model_label = fieldnames(this.models);
                    
                    % Get list of those that are calibrated
                    filt = false(length(model_label),1);
                    for i=1:length(model_label)                           
                        
                        % Convert model label to field label.
                        model_labelAsField = HydroSight_GUI.modelLabel2FieldName(model_label{i});
                        
                        % Check if model is calibrated
                        filt(i) = this.model_labels{model_labelAsField, 'isCalibrated'};
                    end                    
                    model_label = model_label(filt);

                    % Assign calib model labels to drop down
                    hObject.ColumnFormat{2} = model_label';   

                    % Update status in GUI
                    drawnow update

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

                    % Get calibrated model field name
                    calibLabel = HydroSight_GUI.modelLabel2FieldName(calibLabel);            

                    % Check the model is calibrated.
                    if ~this.model_labels{calibLabel, 'isCalibrated'};
                        set(this.Figure, 'pointer', 'arrow');
                        drawnow update;                            
                        warndlg('A calibrated model must be first selected from the "Model Label" column.', 'Error ...');
                        return;
                    end

                    % Get the forcing data for the model.
                    % If a new forcing data file is given, then open it
                    % up and get the start and end dates from it.
                    if isempty( data{irow,7}) || strcmp(data{irow,7},'');                            
                        % Get a copy of the model object. This is only done to
                        % minimise HDD read when the models are off loaded to HDD using
                        % matfile();
                        tmpModel = getModel(this, calibLabel);

                        % Get forcing data
                        forcingData = getForcingData(tmpModel);

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
                            set(this.Figure, 'pointer', 'arrow');
                            drawnow update;                                  
                            warndlg('The new forcing date file could not be open for examination of the start and end dates.', 'Error ...');
                            return;
                        end

                        % Read in the file.
                        try
                           forcingData = readtable(fname);
                        catch           
                            set(this.Figure, 'pointer', 'arrow');
                            drawnow update;                                  
                            warndlg('The new forcing date file could not be imported for extraction of the start and end dates. Please check its format.', 'Error ...');
                            return;
                        end    

                        % Calculate the start and end dates
                        try
                           forcingData_dates = datenum(forcingData{:,1}, forcingData{:,2}, forcingData{:,3});
                           startDate = min(forcingData_dates);
                           endDate = max(forcingData_dates);
                        catch
                            set(this.Figure, 'pointer', 'arrow');
                            drawnow update;                                  
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
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update;                          
                    selectedDate = uical(inputDate, 'English',startDate, endDate);

                    % Check if user cancelled uical
                    if isempty(selectedDate)
                        set(this.Figure, 'pointer', 'arrow');
                        drawnow update;                              
                        return;
                    end

                    set(this.Figure, 'pointer', 'watch');
                    drawnow update;                                                  

                    % Check the selected date
                    if strcmp(columnName, 'Simulation Start Date')
                        % Get the end date 
                        simEndDate=inf;
                        if ~isempty(data{irow,icol+1})
                            simEndDate = datenum( data{irow,icol+1},'dd-mmm-yyyy');
                        end

                        % Check date is between start and end date of obs
                        % head.
                        if selectedDate < startDate || selectedDate > endDate 
                            set(this.Figure, 'pointer', 'arrow');
                            drawnow update;                                                          
                            warndlg('The simulation start date must be within the range of the observed forcing data.');
                            return;
                        elseif selectedDate>=simEndDate
                            set(this.Figure, 'pointer', 'arrow');
                            drawnow update;                                                          
                            warndlg('The simulation start date must be less than the simulation end date.');
                            return;
                        else
                            data{irow,icol} = datestr(selectedDate,'dd-mmm-yyyy');
                            set(hObject,'Data',data);
                        end

                        set(this.Figure, 'pointer', 'watch');
                        drawnow update;                               

                    else
                        % Get the end date 
                        simStartDate = -inf;
                        if ~isempty(data{irow,icol-1})
                            simStartDate = datenum( data{irow,icol-1},'dd-mmm-yyyy');                        
                        end

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
                        
            % Check a row and column are selected.
            if isempty(irow) || isempty(icol)
                set(this.Figure, 'pointer', 'arrow');
                drawnow update;                 
                return
            end
            
            % Find index to the calibrated model label within the list of calibrated
            % models.
            modelLabel = data{irow,2};
            if isempty(modelLabel)
                set(this.Figure, 'pointer', 'arrow');
                drawnow update;                 
                return;
            end          
            modelLabel = HydroSight_GUI.modelLabel2FieldName(modelLabel);                 
            
            % Check if there is a simulation label within the
            % identified calibrated model.            
            simLabel = data{irow,6};
            if isempty(simLabel)
                set(this.Figure, 'pointer', 'arrow');
                drawnow update;                 
                return;
            end
            
            % Get a copy of the model object. This is only done to
            % minimise HDD read when the models are off loaded to HDD using
            % matfile();
            tmpModel = getModel(this, modelLabel);

            % Exit if model is model not found or model is empty
            if isempty(tmpModel) || isempty(tmpModel.simulationResults)
                set(this.Figure, 'pointer', 'arrow');
                drawnow update;                            
                return
            end                        
            
            % Find index to the simulation label within the
            % identified calibrated model.                        
            simInd = cellfun(@(x) strcmp(simLabel, x.simulationLabel), tmpModel.simulationResults);
            if all(~simInd)    % Exit if model not found.
                set(this.Figure, 'pointer', 'arrow');
                drawnow update; 
                return;
            end          
            simInd = find(simInd);
            
            set(this.Figure, 'pointer', 'watch');
            drawnow update; 
                                
            % Display the requested simulation results if the model object
            % exists and there are simulation results.
            if ~isempty(simInd) && isfield(tmpModel.simulationResults{simInd,1},'head') && ...
            ~isempty(tmpModel.simulationResults{simInd,1}.head )               
                
                % Get pop up menu item for the selection of results to
                % display.
                results_item = this.tab_ModelSimulation.resultsOptions.popup.Value;
                        
                switch results_item
                    case 1
                        % Show a table of calibration data
                        
                        % Get the model simulation data.
                        tableData = tmpModel.simulationResults{simInd,1}.head;                        

                        % Calculate year, month, day etc
                        tableData = [year(tableData(:,1)), month(tableData(:,1)), day(tableData(:,1)), hour(tableData(:,1)), minute(tableData(:,1)), tableData(:,2:end)];

                        % Convert to a table data type and add data to the table.
                        this.tab_ModelSimulation.resultsOptions.dataTable.table.Data = tableData;
                        
                        
                        if size(tmpModel.calibrationResults.parameters.params_final,2)==1
                            this.tab_ModelSimulation.resultsOptions.dataTable.table.ColumnName = {'Year','Month','Day','Hour','Minute',tmpModel.simulationResults{simInd,1}.colnames{2:end}};                            
                        else
                            % Create column names
                            colnames={};
                            for i=2:length(tmpModel.simulationResults{simInd,1}.colnames)
                                colnames = [colnames, [tmpModel.simulationResults{simInd,1}.colnames{i},'-50th %ile']];
                                colnames = [colnames, [tmpModel.simulationResults{simInd,1}.colnames{i},'-5th %ile']];
                                colnames = [colnames, [tmpModel.simulationResults{simInd,1}.colnames{i},'-95th %ile']];
                            end
                            
                            % Convert to a table data type and add data to the table.                            
                            this.tab_ModelSimulation.resultsOptions.dataTable.table.ColumnName = {'Year','Month','Day','Hour','Minute',colnames{:}};                            
                        end
                        

                    case 2
                       % Show plotting toolbar
                       plotToolbarState(this,'on');
                        
                       % Determine the number of plots to create.
                       if size(tmpModel.calibrationResults.parameters.params_final,2)==1
                            nsubPlots = size(tmpModel.simulationResults{simInd,1}.head,2) - 1;
                       else                            
                            nsubPlots = (size(tmpModel.simulationResults{simInd,1}.head,2)-1)/3 ;
                       end                        
                        
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
                        solveModelPlotResults(tmpModel, simLabel, axisHandles);
                        
                    case 3
                        % do nothing
                end
            else
                this.tab_ModelSimulation.resultsOptions.box.Heights = [30 20 0 0];
            end            
            
            set(this.Figure, 'pointer', 'arrow');
            drawnow update;             
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
            
            % Change cursor
            set(this.Figure, 'pointer', 'watch');   
            drawnow update;    
            
            try
                % get the new model options
                irow = this.tab_ModelConstruction.currentRow;
                modelType = this.tab_ModelConstruction.Table.Data{irow,7};
                modelOptionsArray = getModelOptions(this.tab_ModelConstruction.modelTypes.(modelType).obj);            

                % Warn the user if the model is already built and the
                % inputs are to change - reuiring the model object to be
                % removed.                            
                if ~isempty(this.tab_ModelConstruction.Table.Data{irow,8}) && ...
                ~strcmp(modelOptionsArray, this.tab_ModelConstruction.Table.Data{irow,8} )

                    % Get original model label
                    modelLabel = this.tab_ModelConstruction.Table.Data{irow,2};

                    % Check if the model object exists
                    modelLabel = HydroSight_GUI.modelLabel2FieldName(modelLabel);            
                    if ~isempty(this.models) && any(strcmp(fieldnames(this.models), modelLabel))
                        
                        % Get model
                        tmpModel = getModel(this, modelLabel);
                                               
                        % Check if the model is calibrated
                        isCalibrated =  isfield(tmpModel.calibrationResults,'isCalibrated') ... 
                            & tmpModel.calibrationResults.isCalibrated;

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
                        % Change cursor and show message
                        set(this.Figure, 'pointer', 'arrow');   
                        drawnow update;                                
                        response = questdlg(msg,'Overwrite exiting model?','Yes','No','No');

                        % Check if 'cancel, else delete the model object
                        if strcmp(response,'No')
                            return;
                        end

                        % Change status of the model object.
                        this.tab_ModelConstruction.Table.Data{irow,end} = '<html><font color = "#FF0000">Model not built.</font></html>';

                        % Delete model from calibration table.
                        modelLabels_calibTable =  this.tab_ModelCalibration.Table.Data(:,2);                            
                        modelLabels_calibTable = HydroSight_GUI.removeHTMLTags(modelLabels_calibTable);
                        ind = cellfun( @(x) strcmp(x,modelLabel), modelLabels_calibTable);
                        this.tab_ModelCalibration.Table.Data = this.tab_ModelCalibration.Table.Data(~ind,:);

                        % Update row numbers
                        nrows = size(this.tab_ModelCalibration.Table.Data,1);
                        this.tab_ModelCalibration.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                     

                        % Delete models from simulations table.
                        if ~isempty(this.tab_ModelSimulation.Table.Data)
                            modelLabels_simTable =  this.tab_ModelSimulation.Table.Data(:,2);
                            modelLabels_simTable = HydroSight_GUI.removeHTMLTags(modelLabels_simTable);
                            ind = cellfun( @(x) strcmp(x,modelLabel), modelLabels_simTable);
                            this.tab_ModelSimulation.Table.Data = this.tab_ModelSimulation.Table.Data(~ind,:);
                        end

                        % Update row numbers
                        nrows = size(this.tab_ModelSimulation.Table.Data,1);
                        this.tab_ModelSimulation.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                     
                    end
                end

                % Apply new model options.
                this.tab_ModelConstruction.Table.Data{this.tab_ModelConstruction.currentRow,8} = modelOptionsArray;
                
                % Change cursor
                set(this.Figure, 'pointer', 'arrow');   
                drawnow update                
            catch ME
                % Change cursor
                set(this.Figure, 'pointer', 'arrow');   
                drawnow update                
                
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
                modelOptionsArray = getModelOptions(this.tab_ModelConstruction.modelTypes.(currentModelType).obj);

                % Change cursor
                set(this.Figure, 'pointer', 'watch');   
                drawnow update;                                
                
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
                            
                            % Remove modle if exists                            
                            modelLabel4FieldNames = HydroSight_GUI.modelLabel2FieldName(modelLabel);            
                            if any(strcmp(fieldnames(this.models), modelLabel4FieldNames))
                                if strcmp(response, 'Yes - all models')
                                    this.models = rmfield(this.models,modelLabel4FieldNames);
                                else

                                    % Get model
                                    tmpModel = getModel(this, modelLabel);

                                    % Check if the model is calibrated
                                    isCalibrated =  isfield(tmpModel.calibrationResults,'isCalibrated') ... 
                                        & tmpModel.calibrationResults.isCalibrated;
                         
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
                                        % Remove built model
                                        this.models = rmfield(this.models,modelLabel4FieldNames);
                                    end
                                end

                                % Delete model from calibration table.
                                modelLabels_calibTable =  this.tab_ModelCalibration.Table.Data(:,2);                            
                                modelLabels_calibTable = HydroSight_GUI.removeHTMLTags(modelLabels_calibTable);
                                ind = cellfun( @(x) strcmp(x,modelLabel), modelLabels_calibTable);
                                this.tab_ModelCalibration.Table.Data = this.tab_ModelCalibration.Table.Data(~ind,:);

                                % Update row numbers
                                nrows = size(this.tab_ModelCalibration.Table.Data,1);
                                this.tab_ModelCalibration.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                                   

                                % Delete models from simulations table.
                                modelLabels_simTable =  this.tab_ModelSimulation.Table.Data(:,2);                            
                                modelLabels_simTable = HydroSight_GUI.removeHTMLTags(modelLabels_simTable);
                                ind = cellfun( @(x) strcmp(x,modelLabel), modelLabels_simTable);
                                this.tab_ModelSimulation.Table.Data = this.tab_ModelSimulation.Table.Data(~ind,:);

                                % Update row numbers
                                nrows = size(this.tab_ModelSimulation.Table.Data,1);
                                this.tab_ModelSimulation.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                              

                            end
                        end                    

                        % Apply model option.
                        this.tab_ModelConstruction.Table.Data{i,8} = modelOptionsArray;            
                        
                        % Change status of the model object.
                        this.tab_ModelConstruction.Table.Data{i,end} = '<html><font color = "#FF0000">Model not built.</font></html>';
                        
                        nOptionsCopied = nOptionsCopied + 1;
                    end
                end            

                % Change cursor
                set(this.Figure, 'pointer', 'arrow');   
                drawnow update;                
                
                msgbox(['The model options were copied to ',num2str(nOptionsCopied), ' "', currentModelType ,'" models.'], 'Summary of model options applied to bores...');
            catch ME
                
                % Change cursor
                set(this.Figure, 'pointer', 'arrow');   
                drawnow update;                
                
                errordlg('The model options could not be applied to the selected models. Please check the model options are sensible.');
            end

        end

        function onAnalyseBores(this, hObject, eventdata)
           
            % Hide the results window.
            this.tab_DataPrep.modelOptions.resultsOptions.box.Heights = [0 0];
                            
            % Hide plot icons
            plotToolbarState(this,'off');            
            
            % Get table data
            data = this.tab_DataPrep.Table.Data;
            
            % Get list of selected bores.
            selectedBores = data(:,1);

            % Change cursor to arrow
            set(this.Figure, 'pointer', 'watch');
            drawnow update

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
            
            
            % Count the number of models selected
            nModels=0;
            for i=1:length(selectedBores);                                
                if ~isempty(selectedBores{i}) && selectedBores{i}
                    nModels = nModels +1;
                end
            end
            
            % Add simulation bar
            minModels4Waitbar = 5;
            iModels=0;
            if nModels>=minModels4Waitbar
                h = waitbar(0, ['Analysing ', num2str(nModels), ' bores. Please wait ...']);
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
                this.tab_DataPrep.Table.Data{i, 16} = '<html><font color = "#FFA500">Analysing bore ...</font></html>';
                this.tab_DataPrep.Table.Data{i,17} = ['<html><font color = "#808080">','(NA)','</font></html>'];
                this.tab_DataPrep.Table.Data{i,18} = ['<html><font color = "#808080">','(NA)','</font></html>'];
                    
                % Update status in GUI
                drawnow;
                
                % Import head data
                %----------------------------------------------------------
                % Check the obs. head file is listed
                if isdir(this.project_fileName)                             
                    fname = fullfile(this.project_fileName,data{i,2}); 
                else
                    fname = fullfile(fileparts(this.project_fileName),data{i,2});  
                end                
                if isempty(fname)                    
                    this.tab_DataPrep.Table.Data{i, 16} = '<html><font color = "#FF0000">Head data file error - file name empty.</font></html>';
                    nAnalysisFailed = nAnalysisFailed + 1;
                    continue;
                end

                % Check the bore ID file exists.
                if exist(fname,'file') ~= 2;                    
                    this.tab_DataPrep.Table.Data{i, 16} = '<html><font color = "#FF0000">Head data file error - file does not exist.</font></html>';
                    nAnalysisFailed = nAnalysisFailed + 1;
                    continue;
                end

                % Read in the observed head file.
                try
                    tbl = readtable(fname);
                catch                    
                    this.tab_DataPrep.Table.Data{i, 16} = '<html><font color = "#FF0000">Head data file error -  read in failed.</font></html>';
                    nAnalysisFailed = nAnalysisFailed + 1;
                    continue;
                end                
                
                % Filter for the required bore.
                boreID = data{i,3};
                filt =  strcmp(tbl{:,1},boreID);
                if sum(filt)<=0
                    this.tab_DataPrep.Table.Data{i, 16} = '<html><font color = "#FF0000">Bore not found in head data file -  data error.</font></html>';
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
                    this.tab_DataPrep.Table.Data{i, 16} = ['<html><font color = "#FF0000">Input for column ', num2str(dataCol), ' must be a number. </font></html>'];
                    nBoreInputsError = nBoreInputsError +1;
                    continue
                end
                if ~isempty(this.tab_DataPrep.Table.Data{i, dataCol}) && this.tab_DataPrep.Table.Data{i, dataCol}>0
                    boreDepth = this.tab_DataPrep.Table.Data{i, dataCol};
                end
                
                surfaceElevation = inf;
                dataCol = 5;
                if ~isnumeric(this.tab_DataPrep.Table.Data{i, dataCol})
                    this.tab_DataPrep.Table.Data{i, 16} = ['<html><font color = "#FF0000">Input for column ', num2str(dataCol), ' must be a number. </font></html>'];
                    nBoreInputsError = nBoreInputsError +1;
                    continue
                end                
                if ~isempty(this.tab_DataPrep.Table.Data{i, dataCol})
                    surfaceElevation = this.tab_DataPrep.Table.Data{i, dataCol};
                end
                
                caseLength = inf;
                dataCol = 6;
                if ~isnumeric(this.tab_DataPrep.Table.Data{i, dataCol})
                    this.tab_DataPrep.Table.Data{i, 16} = ['<html><font color = "#FF0000">Input for column ', num2str(dataCol), ' must be a number. </font></html>'];
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
                        if constructionDate > now()+1 || constructionDate< datenum(1500,1,1)
                            nBoreInputsError = nBoreInputsError +1;
                            continue;
                        end
                    catch
                        this.tab_DataPrep.Table.Data{i, 16} = '<html><font color = "#FF0000">Bore not found in head data file -  data error.</font></html>';
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
                    this.tab_DataPrep.Table.Data{i, 16} = ['<html><font color = "#FF0000">Input for column ', num2str(dataCol), ' must be a number. </font></html>'];
                    nBoreInputsError = nBoreInputsError +1;
                    continue
                end                
                if ~isempty(this.tab_DataPrep.Table.Data{i, dataCol}) && this.tab_DataPrep.Table.Data{i, dataCol}>0
                    rateOfChangeThreshold = this.tab_DataPrep.Table.Data{i, dataCol};
                end      
                
                constHeadDuration = inf;
                dataCol = 13;
                if ~isnumeric(this.tab_DataPrep.Table.Data{i, dataCol})
                    this.tab_DataPrep.Table.Data{i, 16} = ['<html><font color = "#FF0000">Input for column ', num2str(dataCol), ' must be a number. </font></html>'];
                    nBoreInputsError = nBoreInputsError +1;
                    continue
                end                
                if ~isempty(this.tab_DataPrep.Table.Data{i, dataCol}) && this.tab_DataPrep.Table.Data{i, dataCol}>0
                    constHeadDuration = this.tab_DataPrep.Table.Data{i, dataCol};
                end
                
                numNoiseStdDev = inf;
                dataCol = 14;
                if ~isnumeric(this.tab_DataPrep.Table.Data{i, dataCol})
                    this.tab_DataPrep.Table.Data{i, 16} = ['<html><font color = "#FF0000">Input for column ', num2str(dataCol), ' must be a number. </font></html>'];
                    nBoreInputsError = nBoreInputsError +1;
                    continue
                end                
                if ~isempty(this.tab_DataPrep.Table.Data{i, dataCol}) && this.tab_DataPrep.Table.Data{i, dataCol}>0
                    numNoiseStdDev = this.tab_DataPrep.Table.Data{i, dataCol};
                end    
                
                
                outlierForwadBackward=true;
                dataCol = 15;               
                if ~isempty(this.tab_DataPrep.Table.Data{i, dataCol})
                    outlierForwadBackward = this.tab_DataPrep.Table.Data{i, dataCol};
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
                    this.tab_DataPrep.Table.Data{i, 16} = '<html><font color = "#FF0000">Bore ID label error - must start with letters and have only letters and numbers.</font></html>';
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
                    constHeadDuration, numNoiseStdDev, outlierForwadBackward );                                                       
                    
                    % Add summary stats
                    numErroneouObs = sum(any(table2array(this.dataPrep.(boreID)(:,7:12)),2));
                    numOutlierObs = sum(table2array(this.dataPrep.(boreID)(:,13)));                    
                    this.tab_DataPrep.Table.Data{i,17} = ['<html><font color = "#808080">',num2str(numErroneouObs),'</font></html>'];
                    this.tab_DataPrep.Table.Data{i,18} = ['<html><font color = "#808080">',num2str(numOutlierObs),'</font></html>'];
                                  
                    nBoresAnalysed = nBoresAnalysed +1;
                    
                    if saveModels
                        this.tab_DataPrep.Table.Data{i,16} = '<html><font color = "#FFA500">Saving project. </font></html>';

                        % Update status in GUI
                        drawnow;                        
                        
                        % Save project.
                        onSave(this,hObject,eventdata);
                    end
                    
                    this.tab_DataPrep.Table.Data{i, 16} = '<html><font color = "#008000">Bore analysed.</font></html>';
                    
                catch ME
                    this.tab_DataPrep.Table.Data{i, 16} = ['<html><font color = "#FF0000">Analysis failed - ', ME.message,'</font></html>'];   
                    this.tab_DataPrep.Table.Data{i,17} = ['<html><font color = "#808080">','(NA)','</font></html>'];
                    this.tab_DataPrep.Table.Data{i,18} = ['<html><font color = "#808080">','(NA)','</font></html>'];
                    
                    nAnalysisFailed = nAnalysisFailed +1;
                    continue                    
                end
          
                % Update status in GUI
                drawnow;
                
                % Update wait bar
                if nModels>=minModels4Waitbar            
                    iModels=iModels+1;
                    waitbar(iModels/nModels);                
                end
            end
            
            % Close wait bar
            if nModels>=minModels4Waitbar            
                close(h);
            end              
            % Change cursor to arrow
            set(this.Figure, 'pointer', 'arrow');
            drawnow update
            
            % Report Summary
            msgbox({['The data analysis was successfully for ',num2str(nBoresAnalysed), ' bores.'], ...
                    '', ...
                    ['Below is a summary of the failures:'], ...
                    ['   - Head data file errors: ', num2str(nBoreNotInHeadFile)] ...
                    ['   - Input table data errors: ', num2str(nBoreInputsError)] ...
                    ['   - Data analysis algorithm failures: ', num2str(nAnalysisFailed)] ...
                    ['   - Bore IDs not starting with a letter: ', num2str(nBoreIDLabelError)]}, ...                    
                    'Summary of data analysis ...');
                           
            
        end
        
        function onBuildModels(this, hObject, eventdata)

            % Hide plotting toolbars
            plotToolbarState(this, 'off');            
            
            % Change cursor to arrow
            set(this.Figure, 'pointer', 'watch');
            drawnow update            
            
            % Delete any empty model objects
            if ~isempty(this.models)
                modelFieldNames = fieldnames(this.models);
                for i=1:length(modelFieldNames)
                    if isempty(this.models.(modelFieldNames{i}))
                        this.models = rmfield(this.models,modelFieldNames{i});
                    end
                end
            end
                       
            % Get table data
            data = this.tab_ModelConstruction.Table.Data;
            
            % Get list of selected bores.
            selectedBores = data(:,1);
                        
            % Count the number of models selected
            nModels=0;
            for i=1:length(selectedBores);                                
                if ~isempty(selectedBores{i}) && selectedBores{i}
                    nModels = nModels +1;
                end
            end
            
            % Add wait bar
            minModels4Waitbar = 5;
            iModels=0;
            if nModels>=minModels4Waitbar
                h = waitbar(0, ['Building ', num2str(nModels), ' models. Please wait ...']);
            end               
            
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
                   this.tab_ModelConstruction.Table.Data{i, 9} = '<html><font color = "#FF0000">Forcing file error - file name empty.</font></html>';
                   nModelsBuiltFailed = nModelsBuiltFailed + 1;
                   continue;
                end

                % Read in the file.
                try
                   forcingData = readtable(fname);
                catch                   
                   this.tab_ModelConstruction.Table.Data{i, 9} = '<html><font color = "#FF0000">Forcing file error -  read in failed.</font></html>';
                   nModelsBuiltFailed = nModelsBuiltFailed + 1;
                   continue;
                end      
                if isempty(forcingData)
                   this.tab_ModelConstruction.Table.Data{i, 9} = '<html><font color = "#FF0000">Forcing file is empty or open elsewhere -  read in failed.</font></html>';
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
                
                % Check site names are unique
                if length(coordData(:,1)) ~= length(unique(coordData(:,1)))
                   nModelsBuiltFailed = nModelsBuiltFailed + 1;
                   this.tab_ModelConstruction.Table.Data{i, 9} = '<html><font color = "#FF0000">Coordinate site IDs not unique.</font></html>';
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
                
                % Build model
                try 
                    % Build model
                    maxHeadObsFreq_asDays = 1;
                    model_labelAsField = HydroSight_GUI.modelLabel2FieldName(model_label);
                    tmpModel = HydroSightModel(model_label, boreID, modelType , headData, maxHeadObsFreq_asDays, forcingData, coordData, modelOptions);
                    setModel(this, model_labelAsField, tmpModel);
                    
                    % Check if model is listed in calib table. if so get
                    % index
                    isModelListed=false;
                    if size(this.tab_ModelCalibration.Table.Data,1)>0
                        calibModelLabelsHTML = this.tab_ModelCalibration.Table.Data(:,2);
                        calibModelLabels = HydroSight_GUI.removeHTMLTags(calibModelLabelsHTML);
                        isModelListed = cellfun( @(x) strcmp( model_label, x), calibModelLabels);
                        isModelListed = find(isModelListed);
                        
                        % If multiple are listed, then take the top one
                        if length(isModelListed)>1
                            filt = true(length(calibModelLabels),1);
                            filt(isModelListed(2:end))=false;
                            isModelListed=isModelListed(1);
                            this.tab_ModelCalibration.Table.Data = this.tab_ModelCalibration.Table.Data(filt,:);
                            
                            % Update row numbers
                            nrows = size(this.tab_ModelCalibration.Table.Data,1);
                            this.tab_ModelCalibration.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));
                        end
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
                        this.tab_ModelCalibration.Table.Data{isModelListed,8} = 'SP-UCI';
                        
                        
                        % Update row numbers
                        nrows = size(this.tab_ModelCalibration.Table.Data,1);
                        this.tab_ModelCalibration.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                        
                        
                    else
                        this.tab_ModelCalibration.Table.Data{isModelListed,3} = ['<html><font color = "#808080">',boreID,'</font></html>'];
                        this.tab_ModelCalibration.Table.Data{isModelListed,4} = ['<html><font color = "#808080">',datestr(obshead_start,'dd-mmm-yyyy'),'</font></html>'];
                        this.tab_ModelCalibration.Table.Data{isModelListed,5} = ['<html><font color = "#808080">',datestr(obshead_end,'dd-mmm-yyyy'),'</font></html>'];                        
                    end
                    this.tab_ModelCalibration.Table.Data{isModelListed,9} = '<html><font color = "#FF0000">Not calibrated.</font></html>';                    
                    this.tab_ModelCalibration.Table.Data{isModelListed,10} = '(NA)';
                    this.tab_ModelCalibration.Table.Data{isModelListed,11} = '(NA)';
                    this.tab_ModelCalibration.Table.Data{isModelListed,12} = '(NA)';
                    this.tab_ModelCalibration.Table.Data{isModelListed,13} = '(NA)';                    
                    
                    
                    this.tab_ModelConstruction.Table.Data{i, 9} = '<html><font color = "#008000">Model built.</font></html>';
                    nModelsBuilt = nModelsBuilt + 1; 
                    
                catch ME
                    nModelsBuiltFailed = nModelsBuiltFailed + 1;
                    this.tab_ModelConstruction.Table.Data{i, 9} = ['<html><font color = "#FF0000">Model build failed - ', ME.message,'</font></html>'];
                end
                
                % Update status in GUI
                drawnow

               % Update wait bar
                if nModels>=minModels4Waitbar            
                    iModels=iModels+1;
                    waitbar(iModels/nModels);                
                end
            end
            
            % Close wait bar
            if nModels>=minModels4Waitbar            
                close(h);
            end            
            
            % Change cursor to arrow
            set(this.Figure, 'pointer', 'arrow');
            drawnow update
            
            % Enable file menu items for HDD offloading.
            if nModelsBuilt>0
                for i=1:size(this.figure_Menu.Children,1)
                    if strcmp(get(this.figure_Menu.Children(i),'Label'), 'Save Project')
                        set(this.figure_Menu.Children(i),'Enable','on');
                    elseif strcmp(get(this.figure_Menu.Children(i),'Label'), 'Move models from RAM to HDD...') || ...
                    strcmp(get(this.figure_Menu.Children(i),'Label'), 'Move models from HDD to RAM...')
                        set(this.figure_Menu.Children(i),'Enable','on');
                    end       
                end
            end
            
            % Report Summary
            msgbox(['The model was successfully built for ',num2str(nModelsBuilt), ' models and failed for ',num2str(nModelsBuiltFailed), ' models.'], 'Summary of model builds ...');
                        
        end
        
        function onCalibModels(this, hObject, eventdata)
                  
            % The project must be saved to a file. Check the project file
            % is defined.
            if isempty(this.project_fileName) || isdir(this.project_fileName)
                warndlg({'The project must be saved to a file before calibration can start.';'Please first save the project.'}, 'Project not saved...')
                return
            end            
            
            % Get table data
            data = this.tab_ModelCalibration.Table.Data;            
            
            % Get list of selected bores and check.
            selectedBores = data(:,1);
            isModelSelected=false;
            for i=1:length(selectedBores);                
                % Check if the model is to be calibrated.
                if ~isempty(selectedBores{i}) && selectedBores{i}
                    isModelSelected=true;
                    break;
                end                
            end                        
            
            if ~isModelSelected
                warndlg('No models have been selected for calibration.','Model Calibration Error ...')
                return;
            end                                
            
            % Delete any empty model objects
            if ~isempty(this.models)
                modelFieldNames = fieldnames(this.models);
                for i=1:length(modelFieldNames)
                    if isempty(this.models.(modelFieldNames{i}))
                        this.models = rmfield(this.models,modelFieldNames{i});
                    end
                end
            else
                warndlg('No models appear to have been built. Please build the models then calibrate them.','Model Calibration Error ...')
                return;
            end            

            % Change cursor to arrow
            set(this.Figure, 'pointer', 'watch');
            drawnow update            
            
            % Delete any models listed in the calibration table that are
            % not listed in the model construction table            
            if ~isempty(data)
                constructModelLabels = this.tab_ModelConstruction.Table.Data(:,2);
                % Get model label
                calibModelLabelsHTML = data(:,2);
                
                % Remove HTML tags
                calibModelLabels = HydroSight_GUI.removeHTMLTags(calibModelLabelsHTML);
                
                deleteCalibRow = false(size(data,1),1);
                for i=1:size(data,1)

                    % Add index for row if it is to be deleted                    
                    if ~any(cellfun( @(x) strcmp( calibModelLabels{i}, x), constructModelLabels))
                        deleteCalibRow(i) = true;
                        continue;
                    end
                    
                    % Check if there are duplicate bore IDs. If so, delete
                    % non-calibrated one
                    ind = find(cellfun( @(x) strcmp( calibModelLabels{i}, x), calibModelLabels))';
                    if length(ind)>1
                        nDubplicates2Remove = 0;
                        for j=ind
                           if contains(data{j, 10},'(NA)')
                               deleteCalibRow(j) = true;
                               nDubplicates2Remove  = nDubplicates2Remove  +1;
                           end
                        end
                        if nDubplicates2Remove == length(ind)
                            deleteCalibRow(ind(1)) = false;
                        end
                    end
                    
                end
                
                if any(deleteCalibRow)

                    % Change cursor to arrow
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update

                    warndlg('Some models listed in the calibration table are duplicated or not listed in the model construction table and will be deleted. Please re-run the calibration','Unexpected table error...');
                    this.tab_ModelCalibration.Table.Data = this.tab_ModelCalibration.Table.Data(~deleteCalibRow,:);
                    
                    % Update row numbers
                    nrows = size(this.tab_ModelCalibration.Table.Data,1);
                    this.tab_ModelCalibration.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                            
                    
                    return;
                end
                
            end            
            
            
            % CREATE CALIBRATION GUI
            %--------------------------------------------------------------
            % Open a window and add some menus
            this.tab_ModelCalibration.GUI = figure( ...
                'Name', 'HydroSight Model Calibration', ...
                'NumberTitle', 'off', ...
                'MenuBar', 'none', ...
                'HandleVisibility', 'off', ...
                'Visible','on', ...
                'Toolbar','none', ...
                'DockControls','off', ...
                'WindowStyle','modal' ...
                );
                %'CloseRequestFcn',@this.onExit); 
                        
            % Set window Size
            windowHeight = this.tab_ModelCalibration.GUI.Parent.ScreenSize(4);
            windowWidth = this.tab_ModelCalibration.GUI.Parent.ScreenSize(3);
            figWidth = 0.6*windowWidth;
            figHeight = 0.85*windowHeight;            
            this.tab_ModelCalibration.GUI.Position = [(windowWidth - figWidth)/2 (windowHeight - figHeight)/2 figWidth figHeight];
            
            % Set default panel color
            warning('off');
            uiextras.set( this.tab_ModelCalibration.GUI, 'DefaultBoxPanelTitleColor', [0.7 1.0 0.7] );
            warning('on');
 
            outerVbox= uiextras.VBoxFlex('Parent',this.tab_ModelCalibration.GUI,'Padding', 3, 'Spacing', 3);
            innerVbox_top= uiextras.VBox('Parent',outerVbox,'Padding', 3, 'Spacing', 3);
            innerVbox_bottom= uiextras.VBox('Parent',outerVbox,'Padding', 3, 'Spacing', 3);
 
            % Add label
            uicontrol(innerVbox_top,'Style','text','String','Calibration scheme settings: ','HorizontalAlignment','left', 'Units','normalized');
            
            %Create Panels for different windows       
            outerTabsPanel = uiextras.TabPanel( 'Parent', innerVbox_top, 'Padding', 5, 'TabSize',127,'FontSize',8);
            CMAES_tab = uiextras.Panel( 'Parent', outerTabsPanel, 'Padding', 5, 'Tag','CMA-ES tab');            
            SPUCI_tab = uiextras.Panel( 'Parent', outerTabsPanel, 'Padding', 5, 'Tag','SP-UCI tab');
            DREAM_tab = uiextras.Panel( 'Parent', outerTabsPanel, 'Padding', 5, 'Tag','DREAM tab');
            %MultiModel_tab = uiextras.Panel( 'Parent', outerTabsPanel, 'Padding', 5, 'Tag','Multi-Model tab');
            %outerTabsPanel.TabNames = {'CMA-ES', 'SP-UCI','DREAM', 'Multi-model'};
            outerTabsPanel.TabNames = {'CMA-ES', 'SP-UCI','DREAM'};
            outerTabsPanel.SelectedChild = 1;
                       
            % Add buttons.
            outerButtons = uiextras.HButtonBox('Parent',innerVbox_top,'Padding', 3, 'Spacing', 3);             
            uicontrol('Parent',outerButtons,'String','Start calibration','Callback', @this.startCalibration, 'Interruptible','on','Tag','Start calibration', 'TooltipString', sprintf('Calibrate all of the selected models.') );
            if ~isdeployed
                uicontrol('Parent',outerButtons,'String','HPC Offload','Callback', @this.startCalibration,'Tag','Start calibration - useHPC', 'TooltipString', sprintf('BETA version to export selected models for calibration on a High Performance Cluster.') );
                uicontrol('Parent',outerButtons,'String','HPC Retrieval','Callback', @this.onImportFromHPC, 'TooltipString', sprintf('BETA version to retrieve calibrated models from a High Performance Cluster.') );
            end            
            uicontrol('Parent',outerButtons,'String','Quit calibration','Callback', @this.quitCalibration, 'Enable','off','Tag','Quit calibration', 'TooltipString', sprintf('Stop calibrating the models at the end of the current iteration loop.') );
            outerButtons.ButtonSize(1) = 225;            
            
            % Count the number of models selected
            nModels=0;
            iModels=0;
            for i=1:length(selectedBores);                                
                if ~isempty(selectedBores{i}) && selectedBores{i}
                    nModels = nModels +1;
                end
            end            
            
            % Add progress bar
            bar_panel = uipanel('Parent',innerVbox_top, 'BorderType','none');
            ax = axes( 'Parent', bar_panel);            
            barh(ax, 0,'Tag','Calib_wait_bar');
            box(ax,'on');
            xlim(ax,[0,nModels]);
            ax.YTick = [];
            ax.XTick = [0:nModels];
            title(ax,'Model Calibration Progress','FontSize',10,'FontWeight','normal');
            
            % Add large box for calib. iterations
            uicontrol(innerVbox_bottom,'Style','edit','String','(calibration not started)','Tag','calibration command window', ...
                'HorizontalAlignment','left', 'Units','normalized','BackgroundColor','white');             
            
            set(outerVbox, 'Sizes', [-1 -1]);
            set(innerVbox_top, 'Sizes', [30 -1 30 50]);
            set(innerVbox_bottom, 'Sizes', [-1]);
           
            % Fill in CMA-ES panel               
            CMAES_tabVbox= uiextras.Grid('Parent',CMAES_tab,'Padding', 6, 'Spacing', 6);
            uicontrol(CMAES_tabVbox,'Style','text','String','Maximum number of model evaluations (MaxFunEvals):','HorizontalAlignment','left', 'Units','normalized');                        
            uicontrol(CMAES_tabVbox,'Style','text','String','Number of parameter sets searching for the optima (PopSize):','HorizontalAlignment','left', 'Units','normalized');                        
            uicontrol(CMAES_tabVbox,'Style','text','String','Absolute change in the objective function for convergency (TolFun):','HorizontalAlignment','left', 'Units','normalized');            
            uicontrol(CMAES_tabVbox,'Style','text','String','Largest absolute change in the parameters for convergency (TolX):','HorizontalAlignment','left', 'Units','normalized');                        
            uicontrol(CMAES_tabVbox,'Style','text','String','Number CMA-ES calibration restarts (Restarts):','HorizontalAlignment','left', 'Units','normalized');                        
            uicontrol(CMAES_tabVbox,'Style','text','String','Standard deviation for the initial parameter sampling, as fraction of plausible parameter bounds (insigmaFrac):','HorizontalAlignment','left', 'Units','normalized');            
            uicontrol(CMAES_tabVbox,'Style','text','String','Random seed number (only for repetetive testing purposes, an empty value uses a different seed per model):','HorizontalAlignment','left', 'Units','normalized');            
                  
            uicontrol(CMAES_tabVbox,'Style','edit','string','Inf','Max',1, 'Tag','CMAES MaxFunEvals','HorizontalAlignment','right');
            uicontrol(CMAES_tabVbox,'Style','edit','string','Inf','Max',1, 'Tag','CMAES popsize','HorizontalAlignment','right');
            uicontrol(CMAES_tabVbox,'Style','edit','string','1e-12','Max',1, 'Tag','CMAES TolFun','HorizontalAlignment','right');
            uicontrol(CMAES_tabVbox,'Style','edit','string','1e-11','Max',1, 'Tag','CMAES TolX','HorizontalAlignment','right');
            uicontrol(CMAES_tabVbox,'Style','edit','string','4','Max',1, 'Tag','CMAES Restarts','HorizontalAlignment','right');
            uicontrol(CMAES_tabVbox,'Style','edit','string','0.333','Max',1, 'Tag','CMAES insigmaFrac','HorizontalAlignment','right');
            uicontrol(CMAES_tabVbox,'Style','edit','string',num2str(floor(rand(1)*1e6)),'Max',1, 'Tag','CMAES iseed','HorizontalAlignment','right');
            
            set(CMAES_tabVbox, 'ColumnSizes', [-1 100], 'RowSizes', repmat(20,1,6));                        
            
            % Fill in SP-UCI panel   
            SPUCI_tabVbox= uiextras.Grid('Parent',SPUCI_tab,'Padding', 6, 'Spacing', 6);
            uicontrol(SPUCI_tabVbox,'Style','text','String','Maximum number of model evaluations (maxn):','HorizontalAlignment','left', 'Units','normalized');                        
            uicontrol(SPUCI_tabVbox,'Style','text','String','Number of evolution loops meeting convergence criteria for calbration (kstop):','HorizontalAlignment','left', 'Units','normalized');            
            uicontrol(SPUCI_tabVbox,'Style','text','String','Percentage change in the objective function allowed in kstop loops before convergency (pcento):','HorizontalAlignment','left', 'Units','normalized');            
            uicontrol(SPUCI_tabVbox,'Style','text','String','Normalized geometric range of the parameters before convergency (peps):','HorizontalAlignment','left', 'Units','normalized');                        
            uicontrol(SPUCI_tabVbox,'Style','text','String','Number of complexes (ngs) per model parameter:','HorizontalAlignment','left', 'Units','normalized');                        
            uicontrol(SPUCI_tabVbox,'Style','text','String','Minimum number of total complexes (ngs):','HorizontalAlignment','left', 'Units','normalized');                        
            uicontrol(SPUCI_tabVbox,'Style','text','String','Maximum number of total complexes (ngs):','HorizontalAlignment','left', 'Units','normalized');                        
            uicontrol(SPUCI_tabVbox,'Style','text','String','Random seed number (only for repetetive testing purposes, an empty value uses a different seed per model):','HorizontalAlignment','left', 'Units','normalized');            
      
            uicontrol(SPUCI_tabVbox,'Style','edit','string','Inf','Max',1, 'Tag','SP-UCI maxn','HorizontalAlignment','right');
            uicontrol(SPUCI_tabVbox,'Style','edit','string','10','Max',1, 'Tag','SP-UCI kstop','HorizontalAlignment','right');
            uicontrol(SPUCI_tabVbox,'Style','edit','string','1e-6','Max',1, 'Tag','SP-UCI pcento','HorizontalAlignment','right');
            uicontrol(SPUCI_tabVbox,'Style','edit','string','1e-6','Max',1, 'Tag','SP-UCI peps','HorizontalAlignment','right');
            uicontrol(SPUCI_tabVbox,'Style','edit','string','2','Max',1, 'Tag','SP-UCI ngs','HorizontalAlignment','right');
            uicontrol(SPUCI_tabVbox,'Style','edit','String','1','Max',1, 'Tag','SP-UCI ngs min','HorizontalAlignment','right');
            uicontrol(SPUCI_tabVbox,'Style','edit','String','inf','Max',1, 'Tag','SP-UCI ngs max','HorizontalAlignment','right');
            uicontrol(SPUCI_tabVbox,'Style','edit','string',num2str(floor(rand(1)*1e6)),'Max',1, 'Tag','SP-UCI iseed','HorizontalAlignment','right');
            
            set(SPUCI_tabVbox, 'ColumnSizes', [-1 100], 'RowSizes', repmat(20,1,8));
            
            
            % Fill in DREAM panel   
            DREAM_tabVbox= uiextras.Grid('Parent',DREAM_tab ,'Padding', 6, 'Spacing', 6);
            uicontrol(DREAM_tabVbox,'Style','text','String','Number of Markov chains per model parameter (N_per_param):','HorizontalAlignment','left', 'Units','normalized');                  
            uicontrol(DREAM_tabVbox,'Style','text','String','Number of 10,000s of model generations per chain (T):','HorizontalAlignment','left', 'Units','normalized');                  
            uicontrol(DREAM_tabVbox,'Style','text','String','Number of crossover values (nCR):','HorizontalAlignment','left', 'Units','normalized');                        
            uicontrol(DREAM_tabVbox,'Style','text','String','Number chain pairs for proposal (delta):','HorizontalAlignment','left', 'Units','normalized');            
            uicontrol(DREAM_tabVbox,'Style','text','String','Random error for ergodicity (lambda):','HorizontalAlignment','left', 'Units','normalized');            
            uicontrol(DREAM_tabVbox,'Style','text','String','Randomization (zeta):','HorizontalAlignment','left', 'Units','normalized');                        
            uicontrol(DREAM_tabVbox,'Style','text','String','Test function name for detecting outlier chains (outlier):','HorizontalAlignment','left', 'Units','normalized');                        
            uicontrol(DREAM_tabVbox,'Style','text','String','Probability of jumprate of 1 (pJumpRate_one):','HorizontalAlignment','left', 'Units','normalized');            
            
            uicontrol(DREAM_tabVbox,'Style','edit','string','1','Max',1, 'Tag','DREAM N','HorizontalAlignment','right');
            uicontrol(DREAM_tabVbox,'Style','edit','string','5','Max',1, 'Tag','DREAM T','HorizontalAlignment','right');
            uicontrol(DREAM_tabVbox,'Style','edit','string','3','Max',1, 'Tag','DREAM nCR','HorizontalAlignment','right');
            uicontrol(DREAM_tabVbox,'Style','edit','string','3','Max',1, 'Tag','DREAM delta','HorizontalAlignment','right');
            uicontrol(DREAM_tabVbox,'Style','edit','string','0.05','Max',1, 'Tag','DREAM lambda','HorizontalAlignment','right');
            uicontrol(DREAM_tabVbox,'Style','edit','string','0.05','Max',1, 'Tag','DREAM zeta','HorizontalAlignment','right');
            uicontrol(DREAM_tabVbox,'Style','edit','string','iqr','Max',1, 'Tag','DREAM outlier','HorizontalAlignment','right');
            uicontrol(DREAM_tabVbox,'Style','edit','string','0.2','Max',1, 'Tag','DREAM pJumpRate_one','HorizontalAlignment','right');
            
            set(DREAM_tabVbox, 'ColumnSizes', [-1 100], 'RowSizes', repmat(20,1,8));            
            
%             % Fill in MultiModel panel   
%             % MODEL STILL IN DEVELOPMENT
%             MultiModel_tabVbox= uiextras.Grid('Parent',MultiModel_tab ,'Padding', 6, 'Spacing', 6);
%             
%             uicontrol(MultiModel_tabVbox,'Style','text','String','Parameters to estimate as fixed-effect (component:parameter-model label):','HorizontalAlignment','left', 'Units','normalized');                        
%             multiModel_leftList = uicontrol(MultiModel_tabVbox,'Style','listbox','String',cell(0,1),'Min',1,'Max',100,'Tag','NLMEFIT paramsLeftList','HorizontalAlignment','left', 'Units','normalized');                        
%             
%             uicontrol(MultiModel_tabVbox,'Style','text','String','Number of randomly selected initial starts for gradient calibration (nStarts):','HorizontalAlignment','left', 'Units','normalized');                        
%             uicontrol(MultiModel_tabVbox,'Style','text','String','Maximum number of model evaluations (MaxIter):','HorizontalAlignment','left', 'Units','normalized');                        
%             uicontrol(MultiModel_tabVbox,'Style','text','String','Absolute change in the objective function allowed for convergency (TolFun):','HorizontalAlignment','left', 'Units','normalized');            
%             uicontrol(MultiModel_tabVbox,'Style','text','String','Maximum absolute change in the parameters allowed for convergency (TolX):','HorizontalAlignment','left', 'Units','normalized');                        
%             uicontrol(MultiModel_tabVbox,'Style','text','String','Relative difference for the finite difference gradient estimation (DerivStep):','HorizontalAlignment','left', 'Units','normalized');                        
% 
%             uicontrol(MultiModel_tabVbox,'Style','text','String','')
%             MultiModel_tabButtons = uiextras.VButtonBox('Parent',MultiModel_tabVbox,'Padding', 3, 'Spacing', 3);             
%             uicontrol('Parent',MultiModel_tabButtons,'String','>','Callback', @this.multimodel_moveRight, 'Tag','NLMEFIT paramsRight', 'TooltipString', 'Move the selected left-hand parameters to the right-hand box.' );
%             uicontrol('Parent',MultiModel_tabButtons,'String','<','Callback', @this.multimodel_moveLeft, 'Tag','NLMEFIT paramsLeft', 'TooltipString', 'Move the selected right-hand parameters to the left-hand box.' );            
%             MultiModel_tabButtons.ButtonSize(1) = 225;            
%             uicontrol(MultiModel_tabVbox,'Style','text','String','')
%             uicontrol(MultiModel_tabVbox,'Style','text','String','')
%             uicontrol(MultiModel_tabVbox,'Style','text','String','')
%             uicontrol(MultiModel_tabVbox,'Style','text','String','')
%             uicontrol(MultiModel_tabVbox,'Style','text','String','')            
%             
%             uicontrol(MultiModel_tabVbox,'Style','text','String','Parameters to jointly estimate as random-effect (component:parameter-model label):','HorizontalAlignment','left', 'Units','normalized');                        
%             multiModel_RightList = uicontrol(MultiModel_tabVbox,'Style','listbox','String',cell(0,1),'Min',1,'Max',100,'Tag','NLMEFIT paramsRightList','HorizontalAlignment','left', 'Units','normalized');                        
%                         
%             uicontrol(MultiModel_tabVbox,'Style','edit','string','10','Max',1, 'Tag','NLMEFIT nStarts','HorizontalAlignment','right');
%             uicontrol(MultiModel_tabVbox,'Style','edit','string','Inf','Max',1, 'Tag','NLMEFIT MaxIter','HorizontalAlignment','right');
%             uicontrol(MultiModel_tabVbox,'Style','edit','string','1e-8','Max',1, 'Tag','NLMEFIT TolFun','HorizontalAlignment','right');
%             uicontrol(MultiModel_tabVbox,'Style','edit','string','1e-6','Max',1, 'Tag','NLMEFIT TolX','HorizontalAlignment','right');
%             uicontrol(MultiModel_tabVbox,'Style','edit','string','1e-5','Max',1, 'Tag','NLMEFIT DerivStep','HorizontalAlignment','right');
% 
%                         
%             set(MultiModel_tabVbox, 'ColumnSizes', [-1 40 -1], 'RowSizes', [20, -1, 20, 20, 20, 20, 20]);            
                        
            % Loop through each model to be calibrated and disable the
            % calib. tabs that are not required.
            % Loop  through the list of selected bore and apply the model
            % options.
            initialTab = [];
            showCMAEStab =  false;
            showSPUCItab = false;
            showDREAMtab = false;
            showMultiModeltab = false;
            selectedBores = data(:,1);
            for i=1:length(selectedBores)
                
                % Check if the model is to be calibrated.
                if isempty(selectedBores{i}) || ~selectedBores{i}
                    continue;
                end

                % Get the selected model calibration method
                calibMethod = data{i,8};                
                 
                switch calibMethod
                    case 'CMA-ES'
                        showCMAEStab = true;
                        if isempty(initialTab)
                            initialTab=1;
                        end                    
                    case 'SP-UCI'
                        showSPUCItab =  true;
                        if isempty(initialTab)
                            initialTab=2;
                        end                        
                    case 'DREAM'
                        showDREAMtab = true;
                        if isempty(initialTab)
                            initialTab=3;
                        end                        
                    case 'Multi-model'
                        showMultiModeltab = true;
                        if isempty(initialTab)
                            initialTab=4;
                        end                        
                    otherwise
                        error('The input model type cannot be set-up.')
                end
                        
            end
                    
            % Show first active tab
            outerTabsPanel.SelectedChild = initialTab;
            
            if ~showCMAEStab
                outerTabsPanel.TabEnables{1} = 'off';
            end
            if ~showSPUCItab
                outerTabsPanel.TabEnables{2} = 'off';
            end            
            if ~showDREAMtab
                outerTabsPanel.TabEnables{3} = 'off';
            end            
%             if ~showMultiModeltab
%                 outerTabsPanel.TabEnables{4} = 'off';
%             end                       
%             
%             % Loop through each model that is part of the multi-model and
%             % get the parameters. Add these to the multi-modle list box.
%             multiModel_leftList.String={};
%             multiModel_rightList.String={};
%             if showMultiModeltab
%                 for i=1:length(selectedBores)
% 
%                     % Check if the model is to be calibrated.
%                     if isempty(selectedBores{i}) || ~selectedBores{i} || ~strcmp(data{i,8},'Multi-model')
%                         continue;
%                     end
% 
%                     % Get the selected model for simulation
%                     calibLabel = data{i,2};
%                     calibLabel = HydroSight_GUI.removeHTMLTags(calibLabel);                    
%                     
%                     tmpModel = getModel(this, calibLabel);
%  
%                     % Get the model parameters and add to the list box
%                     if ~isempty(tmpModel)
% 
%                          [params, paramNames] = getParameters(tmpModel.model);
%                          paramNames = strcat(paramNames(:,1),':',paramNames(:,2),['-',calibLabel]);
%                          multiModel_leftList.String = {multiModel_leftList.String{:}, paramNames{:}};
%                     end
%                     
%                 end                
%                 multiModel_leftList.String = sort(multiModel_leftList.String);
%             end
% 
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
            drawnow update            

            % Count the number of models selected
            nModels=0;
            for i=1:length(selectedBores);                                
                if ~isempty(selectedBores{i}) && selectedBores{i}
                    nModels = nModels +1;
                end
            end
            
            % Add simulation bar
            minModels4Waitbar = 5;
            iModels=0;
            if nModels>=minModels4Waitbar
                h = waitbar(0, ['Simulating ', num2str(nModels), ' models. Please wait ...']);
            end            
            
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
        
                % Get model label
                calibLabel = data{i,2};
                
                % Get a copy of the model object. This is only done to
                % minimise HDD read when the models are off loaded to HDD using
                % matfile();
                tmpModel = getModel(this, calibLabel);

                % Exit if model not found or not calibrated.
                if isempty(tmpModel) || ~tmpModel.calibrationResults.isCalibrated
                   nModelsSimFailed = nModelsSimFailed +1;
                   this.tab_ModelSimulation.Table.Data{i,end} = ['<html><font color = "#FF0000">Sim. failed - Model could not be found. Please rebuild and calibrate it.</font></html>'];
                   continue;
                end                                  
                
                % Get the exact start and end dates of the obs head.
                obsHead = getObservedHead(tmpModel);
                
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
                       simTimePoints = zeros(0,3);
                       startYear = year(simStartDate);
                       startMonth= month(simStartDate);
                       startDay= 1;
                       endYear = year(simEndDate);
                       endMonth = month(simEndDate);
                       endDay = day(simEndDate);
                       iyear = startYear;
                       imonth = startMonth;
                       iday = startDay;
                       j=1;
                       simTimePoints(j,1:3) = [iyear, imonth, iday];
                       while datenum(iyear,imonth,iday) <= simEndDate
                          
                           if imonth == 12
                               imonth = 1;
                               iyear = iyear + 1;
                           else
                               imonth = imonth + 1;
                           end
                           if datenum(iyear, imonth, iday) >= simStartDate && datenum(iyear, imonth, iday) <= simEndDate
                               j=j+1;
                               simTimePoints(j,1:3) = [iyear, imonth, iday];
                           end
                       end
                       
                       simTimePoints = datenum(simTimePoints);
                   case 'Yearly'
                       simTimePoints = [simStartDate:365:simEndDate]';
                   otherwise
                       % Get the observed head dates.
                       obsTimePoints = getObservedHead(tmpModel);
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
                   solveModel(tmpModel, simTimePoints, forcingData, simLabel, doKrigingOfResiduals);                   
                   setModel(this, calibLabel, tmpModel);        

                   % Update GUI table
                   this.tab_ModelSimulation.Table.Data{i,end} = '<html><font color = "#008000">Simulated. </font></html>';
                   
                   nModelsSim = nModelsSim + 1;
                                      
               catch ME
                   nModelsSimFailed = nModelsSimFailed +1;
                   this.tab_ModelSimulation.Table.Data{i,end} = ['<html><font color = "#FF0000">Sim. failed - ', ME.message,'</font></html>']; '<html><font color = "#FF0000">Failed. </font></html>';                       
               end
               
               % Update wait bar
               if nModels>=minModels4Waitbar            
                    iModels=iModels+1;
                    waitbar(iModels/nModels);                
               end
            end
            
            % Close wait bar
            if nModels>=minModels4Waitbar            
                close(h);
            end
            
            % Change cursor
            set(this.Figure, 'pointer', 'arrow');
            drawnow update            
            
            % Report Summary
            msgbox(['The simulations were successful for ',num2str(nModelsSim), ' models and failed for ',num2str(nModelsSimFailed), ' models.'], 'Summary of model simulaions...');

        end
        
        
        function onImportFromHPC(this, hObject, eventdata)
           % Get SSH details
            prompts = { 'URL to the cluster:', ...
                        'User name for cluster:', ...
                        'Password for cluster:', ...
                        'Full path to folder for the jobs:', ...
                        'Temporary local working folder:'};
            dlg_title = 'Commands for retrieving HPC cluster model calibration.';        
            num_lines = 1;
            if isempty(this.HPCoffload)
                defaults = {'edward.hpc.unimelb.edu.au', ...
                            '', ...
                            '', ...
                            '', ...
                            ''};
            else
                defaults{1}=this.HPCoffload{2};
                defaults{2}=this.HPCoffload{3};
                defaults{4}=this.HPCoffload{6};
                defaults{3}='';
                if length(this.HPCoffload)>=14
                    defaults{5}=this.HPCoffload{14};
                else
                    defaults{5}='';                    
                end
                for i=1:length(defaults)
                    if isempty(defaults{i})
                        defaults{i}='';
                    end
                end
            end
            userData = inputdlg(prompts,dlg_title,num_lines,defaults);
            if isempty(userData)
                return;
            end
            
            % Disaggregate user data
            URL = userData{1};
            username = userData{2};
            password = userData{3};
            folder = userData{4};
            workingFolder = userData{5};
            this.HPCoffload{2} = URL;
            this.HPCoffload{3} = username;
            this.HPCoffload{5} = folder;
            this.HPCoffload{14} = workingFolder;
            
            % Get project folder
            if isempty(this.project_fileName)
                errordlg('The project folder must be set prior to retrieval of results.','Projct folder not set.');
                return;
            else
                % Get project folder and file name (if a dir)
                if isdir(this.project_fileName)
                    projectPath = this.project_fileName;
                else
                    [projectPath,projectName,projectExt] = fileparts(this.project_fileName);
                end
            end            

            % Start the diary and copying of the command window outputs to
            % the GUI.
            commandwindowBox = findobj(this.tab_ModelCalibration.GUI, 'Tag','calibration command window');
            commandwindowBox.Max=Inf;
            commandwindowBox.Min=0;
            diaryFilename = strrep(this.project_fileName,'.mat',['_calibOutputs_',strrep(strrep(datestr(now),':','-'),' ','_'),'.txt']);
            this.tab_ModelCalibration.QuitObj = calibGUI_interface(commandwindowBox,diaryFilename);
            startDiary(this.tab_ModelCalibration.QuitObj);                  
            
            % Display update
            display('HPC retrieval progress ...');
            
            % Update the diary file
            if ~isempty(this.tab_ModelCalibration.QuitObj)
                updatetextboxFromDiary(this.tab_ModelCalibration.QuitObj);
            end  
                        
            % Check the local workin folder exists. If not, create it.
            if ~exist(workingFolder,'dir')
                % Display update
                display(['   Making local working folder at:',workingFolder]);
                
                % Update the diary file
                if ~isempty(this.tab_ModelCalibration.QuitObj)
                    updatetextboxFromDiary(this.tab_ModelCalibration.QuitObj);
                end
                
                mkdir(workingFolder);
            end
            cd(workingFolder);
            
            % Check that a SSH channel can be opened           
            display('   Checking SSH connection to cluster ...');
            if ~isempty(this.tab_ModelCalibration.QuitObj)
                updatetextboxFromDiary(this.tab_ModelCalibration.QuitObj);
            end            
            sshChannel = ssh2_config(URL,username,password); 
            if isempty(sshChannel)
                errordlg({'An SSH connection to the cluster could not be established.','Please check the input URL, username and passord.'},'SSH connection failed.');
                return;
            end
                      
            % Get list of selected bores.            
            data = this.tab_ModelCalibration.Table.Data;
            selectedBores = data(:,1);

            % Change cursor
            set(this.Figure, 'pointer', 'watch');
            drawnow update;
              
            % Get model indexes
            imodels=[];
            for i=1:length(selectedBores);
                % Check if the model is to be calibrated.
                if isempty(selectedBores{i}) || ~selectedBores{i}
                    continue;
                else
                    imodels = [imodels,i];
                end            
            end
            nSelectedModels = length(imodels);
            
            % Get a list of .mat files on remote cluster
            display('   Getting list of results files on cluster ...');
            if ~isempty(this.tab_ModelCalibration.QuitObj)
                updatetextboxFromDiary(this.tab_ModelCalibration.QuitObj);
            end        
            try
                [~,allMatFiles] = ssh2_command(sshChannel,['cd ',folder,'/models ; find -name \*.mat -print']);
            catch ME
                errordlg({'An SSH connection to the cluster could not be established.','Please check the input URL, username and passord.'},'SSH connection failed.');
                return;
            end
            
            % Filter out the input data files
            ind = find(cellfun( @(x) isempty(strfind(x, 'HPCmodel.mat')), allMatFiles));
            allMatFiles = allMatFiles(ind);
            
            % Build list of mat files results to download
            display('   Building list of results files to retieve ...');
            if ~isempty(this.tab_ModelCalibration.QuitObj)
                updatetextboxFromDiary(this.tab_ModelCalibration.QuitObj);
            end            
            resultsToDownload=cell(0,1);
            j=0;
            imodel_filt=[];            
            nModelsNoResult=0;
            nModelsNamesToChange=0;
            SSH_commands = '';
            for i=imodels
                % Get the selected model label.
                calibLabel = data{i,2};                
                calibLabel = HydroSight_GUI.removeHTMLTags(calibLabel);
  
                % Remove special characters from label (as per jobSubmission.m)
                calibLabel =  regexprep(calibLabel,'\W','_');                             
                calibLabel =  regexprep(calibLabel,'____','_');                             
                calibLabel =  regexprep(calibLabel,'___','_');                             
                calibLabel =  regexprep(calibLabel,'__','_');                      
                
                indResultsFileName = find(cellfun( @(x) ~isempty(strfind(x, ['/',calibLabel,'/results.mat'])), allMatFiles));                
                if ~isempty(indResultsFileName)
                    changefilename=true;
                else
                    indResultsFileName = find(cellfun( @(x) ~isempty(strfind(x, ['/',calibLabel,'/',calibLabel,'.mat'])), allMatFiles));
                    changefilename=false;
                end
                    
                if ~isempty(indResultsFileName)
                    % Build SSH command string for chnaging results file
                    % names form results.mat to bore label
                    if changefilename
                        nModelsNamesToChange=nModelsNamesToChange+1;
                        SSH_commands = strcat(SSH_commands, [' cd ',folder,'/models/',calibLabel '; mv results.mat ', calibLabel,'.mat ;']);
                    end
                    
                    % Add file name to list of files to download
                    j=j+1;
                    resultsToDownload{j,1}=['./',calibLabel,'/',calibLabel,'.mat'];
                    imodel_filt =  [imodel_filt,true];
                else
                    imodel_filt =  [imodel_filt,false];
                    nModelsNoResult=nModelsNoResult+1;
                end
            end

            % Change file names from results.mat
            if length(SSH_commands)>0
                display(['   Changing file from results.mat to model label .mat at ', num2str(nModelsNamesToChange), ' models...']);
                if ~isempty(this.tab_ModelCalibration.QuitObj)
                    updatetextboxFromDiary(this.tab_ModelCalibration.QuitObj);
                end                
                try
                    [~,status] = ssh2_command(sshChannel,SSH_commands);
                catch ME
                    warndlg({'Some results.mat files could not be changed to the model label.' ,'These models will not be imported.'},'SSH file name change failed.');
                end
            end
            
            % Download .mat files
            display(['   Downloading ', num2str(length(resultsToDownload)), ' completed models to working folder ...']);
            if ~isempty(this.tab_ModelCalibration.QuitObj)
                updatetextboxFromDiary(this.tab_ModelCalibration.QuitObj);
            end
            imodels = imodels(logical(imodel_filt));            
            try
                ssh2_struct = scp_get(sshChannel,resultsToDownload, workingFolder, [folder,'/models/']);
            catch ME
                sshChannel  =  ssh2_close(sshChannel);        
            end

            display('   Closing SSH connection to cluster ...');
            if ~isempty(this.tab_ModelCalibration.QuitObj)
                updatetextboxFromDiary(this.tab_ModelCalibration.QuitObj);
            end
            
            % Closing connection
            try
                sshChannel  =  ssh2_close(sshChannel);        
            catch
                % do nothing
            end            
            
            % Loop  through the list of selected bore and apply the model
            % options.
            nModels=length(imodels);
            nModelsResultFileErr=0;
            nModelsRetieved=0;
            k=0;
            for i=imodels
                k=k+1;
                display(['   Importing model ',num2str(k),' of ',num2str(nModels) ' into the project ...']);
                if ~isempty(this.tab_ModelCalibration.QuitObj)
                    updatetextboxFromDiary(this.tab_ModelCalibration.QuitObj);
                end

                % get the original tabel text
                tableRowData = this.tab_ModelCalibration.Table.Data(i,:); 
                
                % Get the selected model label.
                calibLabel = data{i,2};                
                calibLabel = HydroSight_GUI.removeHTMLTags(calibLabel);
  
                % Remove special characters from label (as per jobSubmission.m)
                calibLabel = HydroSight_GUI.modelLabel2FieldName(calibLabel);
                                                        
                % Load model
                try
                    cd(workingFolder);
                    importedModel = load([calibLabel,'.mat']);

                    % Convert double precision residuals to single
                    % to reduce RAM
                    if isfield(importedModel.model.evaluationResults,'data')
                        importedModel.model.evaluationResults.data.modelledHead_residuals = single(importedModel.model.evaluationResults.data.modelledHead_residuals);
                    end
                    importedModel.model.calibrationResults.data.modelledHead_residuals = single(importedModel.model.calibrationResults.data.modelledHead_residuals);

                    % Clear the residuals from the model.model.variables. This is only done to minimise RAM.
                    try
                        if isfield(importedModel.model.model.variables,'resid');
                            importedModel.model.model.variables = rmfield(importedModel.model.model.variables, 'resid');
                        end
                    catch ME                                
                        % do nothing
                    end

                    % IF an old version of the HydroSight had been used,
                    % then remove the cell array of variogram
                    % values and just keep the relevant data. This
                    % is done only to reduce RAM.
                    if isfield(importedModel.model.evaluationResults,'performance')                        
                        if isfield(importedModel.model.evaluationResults.performance.variogram_residual,'model')                        
                            nvariograms=size(importedModel.model.evaluationResults.performance.variogram_residual.range,1);
                            nBins  = length(importedModel.model.calibrationResults.performance.variogram_residual.model{1}.h);
                            deltaTime=zeros(nBins ,nvariograms);
                            gamma=zeros(nBins ,nvariograms);
                            gammaHat=zeros(nBins ,nvariograms);
                            parfor j=1:nvariograms
                                deltaTime(:,j) = importedModel.model.evaluationResults.performance.variogram_residual.model{j}.h;
                                gamma(:,j) = importedModel.model.evaluationResults.performance.variogram_residual.model{j}.gamma;
                                gammaHat(:,j) = importedModel.model.evaluationResults.performance.variogram_residual.model{j}.gammahat;
                            end
                            importedModel.model.evaluationResults.performance.variogram_residual.h = deltaTime;
                            importedModel.model.evaluationResults.performance.variogram_residual.gamma = gamma;
                            importedModel.model.evaluationResults.performance.variogram_residual.gammaHat = gammaHat;
                        end
                    end                              
                    if isfield(importedModel.model.calibrationResults.performance.variogram_residual,'model')                        
                        nvariograms=size(importedModel.model.calibrationResults.performance.variogram_residual.range,1);
                        nBins  = length(importedModel.model.calibrationResults.performance.variogram_residual.model{1}.h);
                        deltaTime=zeros(nBins ,nvariograms);
                        gamma=zeros(nBins ,nvariograms);
                        gammaHat=zeros(nBins ,nvariograms);
                        parfor j=1:nvariograms
                            deltaTime(:,j) = importedModel.model.calibrationResults.performance.variogram_residual.model{j}.h;
                            gamma(:,j) = importedModel.model.calibrationResults.performance.variogram_residual.model{j}.gamma;
                            gammaHat(:,j) = importedModel.model.calibrationResults.performance.variogram_residual.model{j}.gammahat;
                        end
                        importedModel.model.calibrationResults.performance.variogram_residual.h = deltaTime;
                        importedModel.model.calibrationResults.performance.variogram_residual.gamma = gamma;
                        importedModel.model.calibrationResults.performance.variogram_residual.gammaHat = gammaHat;
                    end
                    % Assign calib status
                    tableRowData{1,9} = '<html><font color = "#008000">Calibrated. </font></html>';

                    % Get calib status and set into table.
                    exitFlag = importedModel.model.calibrationResults.exitFlag;
                    exitStatus = importedModel.model.calibrationResults.exitStatus;                            
                    if exitFlag ==0 
                        this.tab_ModelCalibration.Table.Data{i,9} = ['<html><font color = "#FF0000">Calib. failed - ', ME.message,'</font></html>'];

                        % Update status in GUI
                        %drawnow update

                        continue

                    elseif exitFlag ==1
                        tableRowData{1,9} = ['<html><font color = "#FFA500">Partially calibrated: ',exitStatus,' </font></html>'];
                    elseif exitFlag ==2
                        tableRowData{1,9} = ['<html><font color = "#008000">Calibrated: ',exitStatus,' </font></html>'];
                    end

                    % Update status in GUI
                    drawnow update;

                    % Recalculate performance stats
                    %------------------
                    head_calib_resid = importedModel.model.calibrationResults.data.modelledHead_residuals;
                    SSE = sum(head_calib_resid.^2);
                    RMSE = sqrt( 1/size(head_calib_resid,1) * SSE);
                    importedModel.model.calibrationResults.performance.RMSE = RMSE;                        

                    % CoE
                    obsHead =  importedModel.model.calibrationResults.data.obsHead;
                    importedModel.model.calibrationResults.performance.CoeffOfEfficiency_mean.description = 'Coefficient of Efficiency (CoE) calculated using a base model of the mean observed head. If the CoE > 0 then the model produces an estimate better than the mean head.';
                    importedModel.model.calibrationResults.performance.CoeffOfEfficiency_mean.base_estimate = mean(obsHead(:,2));            
                    importedModel.model.calibrationResults.performance.CoeffOfEfficiency_mean.CoE  = 1 - SSE./sum( (obsHead(:,2) - mean(obsHead(:,2)) ).^2);            

                    if ~isempty(importedModel.model.evaluationResults)

                        head_eval_resid = importedModel.model.evaluationResults.data.modelledHead_residuals;
                        obsHead =  importedModel.model.evaluationResults.data.obsHead;

                        % Mean error
                        importedModel.model.evaluationResults.performance.mean_error = mean(head_eval_resid); 

                        %RMSE
                        SSE = sum(head_eval_resid.^2);
                        importedModel.model.evaluationResults.performance.RMSE = sqrt( 1/size(head_eval_resid,1) * SSE);                

                        % Unbiased CoE
                        residuals_unbiased = bsxfun(@minus,head_eval_resid, importedModel.model.evaluationResults.performance.mean_error);
                        SSE = sum(residuals_unbiased.^2);
                        importedModel.model.evaluationResults.performance.CoeffOfEfficiency_mean.CoE_unbias  = 1 - SSE./sum( (obsHead(:,2) - mean(obsHead(:,2)) ).^2);            
                    end                              
                    %--------------

                    % Set calib performance stats.
                    calibAICc = median(importedModel.model.calibrationResults.performance.AICc);
                    calibBIC = median(importedModel.model.calibrationResults.performance.BIC);
                    calibCoE = median(importedModel.model.calibrationResults.performance.CoeffOfEfficiency_mean.CoE);
                    tableRowData{1,10} = ['<html><font color = "#808080">',num2str(calibCoE),'</font></html>'];
                    tableRowData{1,12} = ['<html><font color = "#808080">',num2str(calibAICc),'</font></html>'];
                    tableRowData{1,13} = ['<html><font color = "#808080">',num2str(calibBIC),'</font></html>'];

                    % Set eval performance stats
                    if isfield(importedModel.model.evaluationResults,'performance')
                        evalCoE = median(importedModel.model.evaluationResults.performance.CoeffOfEfficiency_mean.CoE_unbias);
                        tableRowData{1,11} = ['<html><font color = "#808080">',num2str(evalCoE),'</font></html>'];
                    else
                        evalCoE = '(NA)';
                        tableRowData{1,11} = ['<html><font color = "#808080">',evalCoE,'</font></html>'];
                    end

                    %vars=whos('-file','tmp2.mat'); for i=1:6;vars2{i}=vars(i).name;end; for i=1:6; loadedVars=load('tmp2.mat',vars2{i}); if i==1; save('tmp4.mat','-Struct','loadedVars');else;save('tmp4.mat','-Struct','loadedVars','-append');end; end
                    % Update project with imported model.
                    setModel(this, calibLabel, importedModel.model);
                    clear importedModel;

                    nModelsRetieved = nModelsRetieved + 1;

                catch ME
                    nModelsResultFileErr = nModelsResultFileErr +1;
                end
                
                % Update GUI labels
                this.tab_ModelCalibration.Table.Data(i,:) = tableRowData;

            end                                  
            
            % Change cursor
            set(this.Figure, 'pointer', 'arrow');
            drawnow update;
            
            % Output Summary.
            msgStr = {};
            msgStr{length(msgStr)+1} = 'Finished Retrieval of Models.';
            msgStr{length(msgStr)+1} = 'Summary of Retrieval:';
            msgStr{length(msgStr)+1} = ['   No. models sucessfully imported to project: ',num2str(nModelsRetieved)];            
            msgStr{length(msgStr)+1} = ['   No. selected models to retrieve: ',num2str(nSelectedModels )];
            msgStr{length(msgStr)+1} = ['   No. selected models not yet complete: ',num2str(nModelsNoResult) ];
            msgStr{length(msgStr)+1} = ['   No. selected models complete: ',num2str(nModels) ];                        
            msgStr{length(msgStr)+1} = ['   No. models files that could not be imported to project: ',num2str(nModelsResultFileErr) ];     
            
            for i=1:length(msgStr)
                display(msgStr{i});
            end
            if ~isempty(this.tab_ModelCalibration.QuitObj)
                updatetextboxFromDiary(this.tab_ModelCalibration.QuitObj);
            end
                                   
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
                
            % Get project folder
            projectPath='';                
            if isdir(this.project_fileName)
                projectPath = this.project_fileName;
            else
                projectPath = fileparts(this.project_fileName);
            end
            
            % Show open file window
             if isempty(projectPath)
                [fName,pName] = uigetfile({'*.csv'},windowString); 
            else
                [fName,pName] = uigetfile({'*.csv'},windowString, projectPath); 
            end            
            if fName~=0;
                % Assign file name to date cell array
                filename = fullfile(pName,fName);
            else
                return;
            end         
            
            % Read in the table.
            try
                tbl = readtable(filename,'Delimiter',',');
            catch ME
                warndlg('The table datafile could not be read in. Please check it is a CSV file with column headings in the first row.');
                return;
            end            

            % Change cursor
            set(this.Figure, 'pointer', 'watch');
            drawnow update;            
            
            % Check the table format and append to the required table
            switch hObject.Tag
                case 'Data Preparation'
                    if size(tbl,2) ~=18
                        set(this.Figure, 'pointer', 'arrow');
                        drawnow update;                        
                        warndlg('The table datafile must have 18 columns. That is, all columns shown in the model construction table.');
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
                                elseif isdatetime(tableAsCell{i,j})
                                    tableAsCell{i,j} = datestr(tableAsCell{i,j});
                                end
                            end

                            % Add results text.
                            tableAsCell{i,16} = '<html><font color = "#FF0000">Bore not analysed.</font></html>'; 
                            tableAsCell{i,17} = ['<html><font color = "#808080">','(NA)','</font></html>'];
                            tableAsCell{i,18} = ['<html><font color = "#808080">','(NA)','</font></html>'];
                            
                            % Convert integer 0/1 to logicals
                            for j=find(strcmp(colFormat,'logical'))
                               if tableAsCell{i,j}==1;
                                   tableAsCell{i,j} = true;
                               else
                                   tableAsCell{i,j} = false;
                               end                                       
                            end
                            
                            % Append data
                            this.tab_DataPrep.Table.Data = [this.tab_DataPrep.Table.Data; tableAsCell(i,:)];
                            
                            nImportedRows = nImportedRows + 1;
                        catch ME
                            nRowsNotImported = nRowsNotImported + 1;
                        end
                        
                    end
                    

                    % Update row numbers.
                    nrows = size(this.tab_DataPrep.Table.Data,1);
                    this.tab_DataPrep.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                           
                    
                    % Change cursor
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update;                                
                    
                    % Output Summary.
                    msgbox({['Data preparation table data was imported to ',num2str(nImportedRows), ' rows.'], ...
                            '', ...
                            ['Number of rows not imported because of data format errors: ',num2str(nRowsNotImported) ]}, 'Summary of data preparation table importing ...');
                    
                    
                case 'Model Construction'
                    if size(tbl,2) ~=9
                        set(this.Figure, 'pointer', 'arrow');
                        drawnow update;                        
                        warndlg('The table datafile must have 9 columns. That is, all columns shown in the model construction table.');
                        return;
                    end
                        
                    % Set the Model Status column to a cells array (if
                    % empty matlab assumes its NaN)
                    tbl.Select_Model=false(size(tbl,1));
                    tbl.Build_Status = cell(size(tbl,1),1);
                    tbl.Build_Status(:) = {'<html><font color = "#FF0000">Model not built.</font></html>'};
                    tbl = table(tbl.Select_Model,tbl.Model_Label,tbl.Obs_Head_File,tbl.Forcing_Data_File,tbl.Coordinates_File,tbl.Bore_ID,tbl.Model_Type,tbl.Model_Options,tbl.Build_Status);

                    % Loop through each row in tbl and find the
                    % corresponding model within the GUI table and the add
                    % the user data to the columns of the row.
                    nModelsNotUnique = 0;
                    nImportedRows = 0;
                    for i=1: size(tbl,1)

                        % Get model label
                        modelLabel_src = tbl{i,2};

                        % Check if model label is unique.
                        if size(this.tab_ModelConstruction.Table.Data,1)>0
                            ind = find(strcmp(this.tab_ModelConstruction.Table.Data(:,2), modelLabel_src));                        

                            % Check if the model is found
                            if ~isempty(ind)
                                nModelsNotUnique = nModelsNotUnique + 1;
                                continue;
                            end
                        end

                        % Append table. Note: the select column is input as a logical 
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

                    % Change cursor
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update;                                                    
                    
                    % Output Summary.
                    msgbox({['Construction data was imported to ',num2str(nImportedRows), ' rows.'], ...
                            '', ...
                            ['Number of rows not imported because the model label is not unique: ',num2str(nModelsNotUnique) ]}, 'Summary of model calibration importing ...');

                    
                case 'Model Calibration'
                    
                    if size(tbl,2) ~=13
                        set(this.Figure, 'pointer', 'arrow');
                        drawnow update;                        
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
                        modelLabel_dest = HydroSight_GUI.removeHTMLTags(this.tab_ModelCalibration.Table.Data(:,2));
                        ind = find(strcmp(modelLabel_dest, modelLabel_src));                        
                        
                        % Check if the model is found
                        if isempty(ind)
                            nModelsNotFound = nModelsNotFound + 1;
                            continue;
                        end
                        
                        % Check the bore IDs are equal.
                        boreID_dest = HydroSight_GUI.removeHTMLTags(this.tab_ModelCalibration.Table.Data{ind,3});
                        if ~strcmp(boreID_dest, boreID_src{1})
                            nBoresNotMatching = nBoresNotMatching + 1;
                            continue;                            
                        end
                        
                        % Record if the model is already built. To do this,
                        % the model is first locasted with this.models.data{}
                        if ~isempty(this.models)
                            
                            tmpModel = getModel(this,modelLabel_src{1});                                                        
                            
                            if ~isempty(tmpModel) && ~isempty(tmpModel.calibrationResults)
                                % remove calibration results.
                                tmpModel.calibrationResults = [];

                                % Record that the calib results were overwritten
                                nCalibBoresDeleted = nCalibBoresDeleted + 1;
                            end
                            
                            setModel(this,modelLabel_src{1},tmpModel);                                                        
                        end                     
                        
                        % Add data from columns 1,5-7.
                        if tbl{i,1}==1
                            this.tab_ModelCalibration.Table.Data{ind,1} = true;
                        else
                            this.tab_ModelCalibration.Table.Data{ind,1} = false;
                        end
                        this.tab_ModelCalibration.Table.Data{ind,6} = datestr(tbl{i,6},'dd-mmm-yyyy');
                        this.tab_ModelCalibration.Table.Data{ind,7} = datestr(tbl{i,7},'dd-mmm-yyyy');
                        this.tab_ModelCalibration.Table.Data{ind,8} = tbl{i,8}{1};
                        
                        % Input the calibration status.
                        %this.tab_ModelCalibration.Table.Data{ind,9} = '<html><font color = "#FF0000">Not calibrated.</font></html>';
                        %this.tab_ModelCalibration.Table.Data{ind,10} = [];                        
                        %this.tab_ModelCalibration.Table.Data{ind,11} = [];
                        %this.tab_ModelCalibration.Table.Data{ind,12} = [];
                        %this.tab_ModelCalibration.Table.Data{ind,13} = [];
                        
                        nImportedRows = nImportedRows +1;
                    end

                    % Update row numbers.
                    nrows = size(this.tab_ModelCalibration.Table.Data,1);
                    this.tab_ModelCalibration.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                            

                    % Change cursor
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update;                                
                                        
                    % Output Summary.
                    msgbox({['Calibration data was imported to ',num2str(nImportedRows), ' rows.'], ...
                            ['   Number of model labels not found in the calibration table: ',num2str(nModelsNotFound) ], ...
                            ['   Number of rows were the bore IDs did not match: ',num2str(nBoresNotMatching) ], ...
                            ['   Number of rows were existing calibration results were deleted: ',num2str(nCalibBoresDeleted) ]}, 'Summary of model calibration importing ...');
                    
                case 'Model Simulation'
                    
                    % Check the number of columns
                    if size(tbl,2) ~=12
                        set(this.Figure, 'pointer', 'arrow');
                        drawnow update;                        
                        warndlg('The table datafile must have 12 columns. That is, all columns shown in the table.');
                        return;
                    end
                    
                    % Get column formats
                    colFormat = this.tab_ModelSimulation.Table.ColumnFormat;

                    % Convert table to cell array
                    tableAsCell = table2cell(tbl);                    
                    tableAsCell(:,12)=repmat({'(empty)'},size(tbl,1),1);
                    
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
                        modelLabel_dest = HydroSight_GUI.removeHTMLTags(this.tab_ModelCalibration.Table.Data(:,2));
                        simLabel_dest = HydroSight_GUI.removeHTMLTags(this.tab_ModelCalibration.Table.Data(:,6));
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
                        tableAsCell{i,12} = '<html><font color = "#FF0000">Not simulated.</font></html>';   
                        if tbl{i,1}==1
                            rowData = [true, tableAsCell(i,2:end)];
                        else
                            rowData = [false, tableAsCell(i,2:end)];
                        end     
                        if tbl{i,11}==1
                            rowData{11} = true;
                        else
                            rowData{11} = false;
                        end                        
                        if size(this.tab_ModelSimulation.Table.Data,1)==0
                            this.tab_ModelSimulation.Table.Data = rowData;
                        else                            
                            this.tab_ModelSimulation.Table.Data = [this.tab_ModelSimulation.Table.Data; rowData];
                        end

                        nImportedRows = nImportedRows + 1;
                    end

                    % Update row numbers.
                    nrows = size(this.tab_ModelSimulation.Table.Data,1);
                    this.tab_ModelSimulation.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                            
                                  
                    % Change cursor
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update;
                    
                    % Output Summary.
                    msgbox({['Simulation data was imported to ',num2str(nImportedRows), ' rows.'], ...
                            '', ...
                            ['Number of rows not imported because the model label is not unique: ',num2str(nSimLabelsNotUnique) ]}, ...
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
            colnames = HydroSight_GUI.removeHTMLTags(colnames);
            
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
                tbl(:,i) = HydroSight_GUI.removeHTMLTags(tbl(:,i));
            end           
            
            % Convert cell array to table            
            tbl = cell2table(tbl);
            tbl.Properties.VariableNames = colnames;
            
            % Write the table.
            try
                writetable(tbl, filename,'Delimiter',',');
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
                                  
                     % Check if there are any rows selected for export
                     if ~any( cellfun(@(x) x==1, this.tab_DataPrep.Table.Data(:,1)))
                         warndlg({'No rows are selected for export.','Please select the models to export using the left-hand tick boxes.'},'No rows selected for export ...')
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
                    
                    % Change cursor
                    set(this.Figure, 'pointer', 'watch');
                    drawnow update;                    
                    
                    % Get a list of bore IDs
                    boreIDs = fieldnames(this.dataPrep);
                    
                    % Setup wait box
                    h = waitbar(0,'Exporting results. Please wait ...');                        
                                   
                    % Export each bore analysed.
                    nResultsWritten = 0;
                    nResultsNotWritten = 0;
                    nResultToExport=0;
                    for i = 1:size(boreIDs,1)

                        % update wait bar
                        waitbar(i/size(boreIDs,1));             
                        
                        % Find the model bore ID is within the GUI
                        % table and then check if the row is to be
                        % exported.
                        tableInd = cellfun( @(x) strcmp( x,boreIDs{i}),  this.tab_DataPrep.Table.Data(:,3));
                        if ~this.tab_DataPrep.Table.Data{tableInd,1}
                            continue
                        end                        
                        
                        % Get the analysis results.
                        tableData = this.dataPrep.(boreIDs{i});

                        % Check there is some data
                        if isempty(tableData) || size(tableData,1)==0
                            nResultsNotWritten = nResultsNotWritten +1;
                            continue;                                
                        end
                        nResultToExport = nResultToExport + 1;
                        
                        % Convert to matrix.
                        tableData = table2array(tableData);

                        % Convert table to real (if previously set to
                        % single for memeory issues)
                        tableData = double(tableData);                        
                        
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
                    
                    % Close wait bar
                    close(h);                      
                    
                    % Change cursor
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update;                    
                    
                    % Show summary
                    msgbox({'Export of results finished.','', ...
                           ['Number of bore results exported =',num2str(nResultsWritten)], ...
                           ['Number of rows selected for export =',num2str(nResultToExport)], ...
                           ['Number of bore results not exported =',num2str(nResultsNotWritten)]}, ...
                           'Export Summary');

                    
                case 'Model Calibration'
                    
                    % Check if there are any rows selected for export
                    if ~any( cellfun(@(x) x==1, this.tab_ModelCalibration.Table.Data(:,1)))
                        warndlg({'No rows are selected for export.','Please select the models to export using the left-hand tick boxes.'},'No rows selected for export ...')
                        return;
                    end                    
                    
                    % Get output file name
                    [fName,pName] = uiputfile({'*.csv'},'Input the .csv file name for results file.'); 
                    if fName~=0;
                        % Assign file name to date cell array
                        filename = fullfile(pName,fName);
                    else
                        return;
                    end 
                    
                    % Change cursor
                    set(this.Figure, 'pointer', 'watch');
                    drawnow update;                    
                    
                    % Open file and write headers
                    fileID = fopen(filename,'w');
                    fprintf(fileID,'Model_Label,BoreID,Year,Month,Day,Hour,Minute,Obs_Head,Is_Calib_Point?,Calib_Head,Eval_Head,Model_Err,Noise_Lower,Noise_Upper \n');
                    
                    % Setup wait box
                    h = waitbar(0,'Exporting results. Please wait ...');                                            
                    
                    % Loop through each row of the calibration table and
                    % export the calibration results (if calibrated)
                    nrows = size(this.tab_ModelCalibration.Table.Data,1);
                    nResultsWritten=0;
                    nModelsToExport=0;
                    nModelsNotCalib=0;
                    for i=1:nrows

                        % update wait bar
                        waitbar(i/nrows);    
                        
                        % Skip if not selected
                        if ~this.tab_ModelCalibration.Table.Data{i,1}
                            continue
                        end                        
                        
                        % Get model label.
                        modelLabel = this.tab_ModelCalibration.Table.Data{i,2};
                        modelLabel = HydroSight_GUI.removeHTMLTags(modelLabel);
                        modelLabel = HydroSight_GUI.modelLabel2FieldName(modelLabel);
                        
                        % Incrment number of models selected for export
                        nModelsToExport = nModelsToExport+1;
                                                
                        % Skip if not calibrated
                        if ~this.model_labels{modelLabel,'isCalibrated'}
                            nModelsNotCalib= nModelsNotCalib+1;
                            continue
                        end
                        
                        % Get a copy of the model object. This is only done to
                        % minimise HDD read when the models are off loaded to HDD using
                        % matfile();
                        tmpModel = getModel(this, modelLabel);

                        % Exit if model not found.
                        if isempty(tmpModel)    
                            continue;
                        end                        
                        
                        % Get model results
                        if isstruct(tmpModel.calibrationResults) && tmpModel.calibrationResults.isCalibrated                    
                                                   
                            % Get the model calibration data.
                            tableData = tmpModel.calibrationResults.data.obsHead;
                            tableData = [tableData, ones(size(tableData,1),1), tmpModel.calibrationResults.data.modelledHead(:,2), ...
                                nan(size(tableData,1),1), tmpModel.calibrationResults.data.modelledHead_residuals(:,end), ...
                                tmpModel.calibrationResults.data.modelledNoiseBounds(:,end-1:end)];

                            % Get evaluation data
                            if isfield(tmpModel.evaluationResults,'data')
                                % Get data
                                evalData = tmpModel.evaluationResults.data.obsHead;
                                evalData = [evalData, zeros(size(evalData,1),1), nan(size(evalData,1),1), tmpModel.evaluationResults.data.modelledHead(:,2), ...
                                    tmpModel.evaluationResults.data.modelledHead_residuals(:,end), ...
                                    tmpModel.evaluationResults.data.modelledNoiseBounds(:,end-1:end)];

                                % Append to table of calibration data and sort
                                % by time.
                                tableData = [tableData; evalData];
                                tableData = sortrows(tableData, 1);
                            end

                            % Convert table to real (if previously set to
                            % single for memeory issues)
                            tableData = double(tableData);
                            
                            % Calculate year, month, day etc
                            tableData = [year(tableData(:,1)), month(tableData(:,1)), day(tableData(:,1)), hour(tableData(:,1)), minute(tableData(:,1)), tableData(:,2:end)];                    
                   
                            % Build write format string
                            fmt = '%s,%s,%i,%i,%i,%i,%i,%12.3f';
                            for j=1:size(tableData,2)-6
                               fmt = strcat(fmt,',%12.3f'); 
                            end
                            fmt = strcat(fmt,'  \n'); 
                            
                            % Get Bore ID
                            boreID = tmpModel.bore_ID;
                            
                            %Write each row.
                            for j=1:size(tableData,1)
                                fprintf(fileID,fmt, modelLabel, boreID, tableData(j,:));
                            end
                            
                            % write data to the file
                            %dlmwrite(filename,tableData,'-append');          
                            nResultsWritten = nResultsWritten + 1;
                        else
                            nModelsNotCalib = nModelsNotCalib + 1;
                        end        
                    end
                    fclose(fileID);
                    
                    % Close wait bar
                    close(h);                      
                    
                    % Change cursor
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update;                    
                    
                    % Show summary
                    msgbox({'Export of results finished.','',['Number of model results exported =',num2str(nResultsWritten)],['Number of models selected for export =',num2str(nModelsToExport)],['Number of selected models not calibrated =',num2str(nModelsNotCalib)]},'Export Summary');
                    
                    
                case 'Model Simulation'
                    % Check if there are any rows selected for export
                    if ~any( cellfun(@(x) x==1, this.tab_ModelSimulation.Table.Data(:,1)))
                        warndlg({'No rows are selected for export.','Please select the models to export using the left-hand tick boxes.'},'No rows selected for export ...')
                        return;
                    end
                      
                    % Ask the user if they want to export one file per bore (with decomposition)
                    % or all results in one file.
                    response = questdlg({'Do you want to export all simulations into one file, or as one file per simulation?','','NOTE: The forcing decomposition results will only be exported using the multi-file option.'},'Export options.','One File','Multiple Files','Cancel','One File');
                    
                    if strcmp(response,'Cancel')
                        return;
                    end
                    
                    if strcmp(response, 'Multiple Files')
                        useMultipleFiles = true;
                        folderName = uigetdir('' ,'Select where to save the .csv simulation files (one file per simulation).');    
                        if isempty(folderName)
                            return;
                        end
                    else
                        useMultipleFiles = false;
                        fileName = uiputfile({'*.csv','*.*'} ,'Input the file name for the .csv simulation file (all simulations in one file).');    
                        if isempty(fileName)
                            return;
                        end   
                        
                        fileID = fopen(fileName,'w');
                        fprintf(fileID,'Simulation_Label,Model_Label,BoreID,Year,Month,Day,Hour,Minute,Sim_Head \n');
    
                    
                    end
                                           
                    % Change cursor
                    set(this.Figure, 'pointer', 'watch');
                    drawnow update;                   
                    
                    % Setup wait box
                    h = waitbar(0,'Exporting results. Please wait ...');                                            
                    
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
                        
                        % update wait bar
                        waitbar(i/nrows);                   
                        
                        % Skip if the model is not sleected for export
                        if ~this.tab_ModelSimulation.Table.Data{i,1}
                            continue
                        end
                        
                        % get model label and simulation label.
                        modelLabel = this.tab_ModelSimulation.Table.Data{i,2};
                        simLabel = this.tab_ModelSimulation.Table.Data{i,6};
                        boreID = this.tab_ModelSimulation.Table.Data{i,3};

                        % Get a copy of the model object. This is only done to
                        % minimise HDD read when the models are off loaded to HDD using
                        % matfile();
                        tmpModel = getModel(this, modelLabel);

                        % Check model exists.
                        if isempty(tmpModel) 
                            nModelsNotFound = nModelsNotFound +1;
                            continue;                            
                        end
                        
                        % Check simulations exists.
                        if isempty(tmpModel.simulationResults)    
                            nSimsNotUndertaken = nSimsNotUndertaken +1;
                            continue;
                        end                        
                                                                                                
                        % Find the simulation.    
                        if isempty(simLabel)
                            nSimsNotUndertaken = nSimsNotUndertaken +1;
                            continue;
                        end
                        simInd = cellfun(@(x) strcmp(simLabel, x.simulationLabel), tmpModel.simulationResults);
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
                            if useMultipleFiles
                                tableData = tmpModel.simulationResults{simInd,1}.head;
                            else
                                tableData = tmpModel.simulationResults{simInd,1}.head(:,1:2);
                            end
                                                        
                            % Calculate year, month, day etc
                            tableData = [year(tableData(:,1)), month(tableData(:,1)), day(tableData(:,1)), hour(tableData(:,1)), minute(tableData(:,1)), tableData(:,2:end)];

                            % Create column names.                        
                            if useMultipleFiles
                                columnName = {'Year','Month','Day','Hour','Minute',tmpModel.simulationResults{simInd,1}.colnames{2:end}};
                                
                                % Check if there are any invalid column names
                                columnName = regexprep(columnName,'\W','_');                            
                                
                                % Create table and add variable names
                                tableData = array2table(tableData);
                                tableData.Properties.VariableNames = columnName;

                            end
                            
                        catch ME
                            nTableConstFailed = nTableConstFailed + 1;
                        end
                        
                        % write data to the file
                        if useMultipleFiles
                            filename_tmp = fullfile(folderName,[modelLabel,'_',simLabel,'.csv']);
                            
                            try
                                writetable(tableData,filename_tmp);          
                                nResultsWritten = nResultsWritten + 1;
                            catch
                                nWritteError = nWritteError + 1;
                            end
                            
                        else
                            % Build write format string
                            fmt = '%s,%s,%s,%i,%i,%i,%i,%i,%12.3f \n';
                            
                            % Remove HTML from bore ID
                            boreID = HydroSight_GUI.removeHTMLTags(boreID);
                            
                            %Write each row.
                            try
                                for j=1:size(tableData,1)
                                    fprintf(fileID,fmt, simLabel, modelLabel, boreID, tableData(j,:));
                                end
                                nResultsWritten = nResultsWritten + 1;
                            catch ME
                                nWritteError = nWritteError + 1;
                            end
                            
                        end
                        
                                                    
                    end
                    
                    % Close wait bar
                    close(h);                         
                    
                    % Change cursor
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update;                    
                    
                    % Show summary                
                    msgbox({'Export of results finished.','', ...
                           ['Number of simulations exported =',num2str(nResultsWritten)], ...
                           ['Number of models not found =',num2str(nModelsNotFound)], ...
                           ['Number of simulations not undertaken =',num2str(nSimsNotUndertaken)], ...
                           ['Number of simulations labels not unique =',num2str(nSimsNotUnique)], ...
                           ['Number of simulations where the construction of results table failed=',num2str(nTableConstFailed)], ...
                           ['Number of simulations where the file could not be written =',num2str(nWritteError)]}, ...
                           'Export Summary');                    

                case {'Model Calibration - results table export', ...
                      'Model Calibration - forcing table export', ...
                      'Model Calibration - parameter table export', ...
                      'Model Calibration - derived parameter table export', ...
                      'Model Calibration - derived data table export'}
                    
                    % Get model label.
                    modelLabel = this.tab_ModelCalibration.Table.Data{this.tab_ModelCalibration.currentRow,2};
                    modelLabel = HydroSight_GUI.removeHTMLTags(modelLabel);
                    modelLabel = HydroSight_GUI.modelLabel2FieldName(modelLabel);
                                    
                    % Build a default file name.
                    fName = strrep(hObject.Tag, 'Model Calibration - ','');
                    fName = strrep(fName, ' export','');
                    fName = [modelLabel,'_',fName,'.csv'];
                  
                    % Get output file name                    
                    [fName,pName] = uiputfile({'*.csv'},'Input the .csv file name for results file.',fName); 
                    if fName~=0;
                        % Assign file name to date cell array
                        filename = fullfile(pName,fName);
                    else
                        return;
                    end 
                    
                    % Change cursor
                    set(this.Figure, 'pointer', 'watch');
                    drawnow update;                    
                    
                    % Find table object
                    tablObj = findobj(this.tab_ModelCalibration.resultsTabs,'Tag',strrep(hObject.Tag,' export',''));
                    
                    % Convert cell array to table            
                    if iscell(tablObj.Data)
                        tbl = cell2table(tablObj.Data);
                    else
                        tbl = array2table(tablObj.Data);
                    end
                    columnName = tablObj.ColumnName;
                    columnName = regexprep(columnName,'\W','_');                            
                    tbl.Properties.VariableNames =  columnName;

                    % Write the table.
                    try
                        writetable(tbl, filename,'Delimiter',',');
                        
                        % Change cursor
                        set(this.Figure, 'pointer', 'arrow');
                        drawnow update;                            
                    catch ME
                        % Change cursor
                        set(this.Figure, 'pointer', 'arrow');
                        drawnow update;                            
                        
                        warndlg('The table could not be written. Please check you have write permissions to the destination folder.');
                        return;
                    end

                otherwise
                    warndlg('Unexpected Error: GUI table type unknown.');
                    return                    
            end
            
            
        end
        
        function onDocumentation(this, hObject, eventdata)
            if isempty(hObject.Tag)  % Open the help on the curretn tab
                switch this.figure_Layout.Selection
                    case 1
                        web('https://github.com/peterson-tim-j/HydroSight/wiki/Project-description','-browser');
                    case 2
                        web('https://github.com/peterson-tim-j/HydroSight/wiki/Date-preparation','-browser');
                    case 3
                        web('https://github.com/peterson-tim-j/HydroSight/wiki/Model-Construction','-browser');
                    case 4
                        web('https://github.com/peterson-tim-j/HydroSight/wiki/Model-Calibration','-browser');
                    case 5
                        web('https://github.com/peterson-tim-j/HydroSight/wiki/Model-simulation','-browser');
                    otherwise
                        web('https://github.com/peterson-tim-j/HydroSight/wiki/Graphical-interface','-browser');
                end
            else
                switch hObject.Tag
                    case 'doc_Overview'
                        web('https://github.com/peterson-tim-j/HydroSight/wiki','-browser');
                    case 'doc_GUI'
                        web('https://github.com/peterson-tim-j/HydroSight/wiki/Graphical-interface','-browser');
                    case 'doc_Calibration'
                        web('https://github.com/peterson-tim-j/HydroSight/wiki/What-is-Calibration%3F','-browser');
                    case 'doc_Publications'
                        web('https://github.com/peterson-tim-j/HydroSight/wiki/Publications','-browser');
                    case 'doc_timeseries_algorithms'
                        web('https://github.com/peterson-tim-j/HydroSight/wiki/Time-series-models','-browser');
                    case 'doc_data_req'
                        web('https://github.com/peterson-tim-j/HydroSight/wiki/Data-Requirements','-browser');
                    case 'doc_data_req'
                        web('https://github.com/peterson-tim-j/HydroSight/wiki/Data-Requirements','-browser');
                    case 'doc_tutes'
                        web('https://github.com/peterson-tim-j/HydroSight/wiki/Tutorials','-browser');
                    case 'doc_Support'
                        web('https://github.com/peterson-tim-j/HydroSight/wiki/Support','-browser');
                end
                
                
            end
            
        end       
               
        function onGitHub(this, hObject, eventdata)
           if strcmp(hObject.Tag,'doc_GitHubUpdate') 
               web('https://github.com/peterson-tim-j/HydroSight/releases','-browser');
           elseif strcmp(hObject.Tag,'doc_GitHubIssue') 
               web('https://github.com/peterson-tim-j/HydroSight/issues','-browser');
           end            
                       
        end
        
        function onVersion(this, hObject, eventdata)           
            msgbox({['This is version ',this.versionNumber, ' of HydroSight GUI.'],'',['It was released on ',this.versionDate]},'HydroSight GUI version ...');
        end
        
        function onLicenseDisclaimer(this, hObject, eventdata)
           web('https://github.com/peterson-tim-j/HydroSight/wiki/Disclaimer-and-Licenses','-browser');
        end                       
        
        function onPrint(this, hObject, eventdata)
            switch this.figure_Layout.Selection
                case {1,3}
                    errordlg('No plot is displayed within the current tab.');
                    return;
                case 2      % Data prep.
                    f=figure('Visible','off');
                    copyobj(this.tab_DataPrep.modelOptions.resultsOptions.plots,f);
                    printpreview(f);
                    close(f);                    
                case 4      % Model Calib.
                    f=figure('Visible','off');
                    switch this.tab_ModelCalibration.resultsTabs.SelectedChild
                        case 1
                            copyobj(this.tab_ModelCalibration.resultsOptions.calibPanel.Children.Children(1).Children.Children(2),f);
                        case 2
                            copyobj(this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(4).Children(end),f);
                        case 3
                            copyobj(this.tab_ModelCalibration.resultsOptions.paramsPanel.Children.Children(1).Children,f);                             
                        case 4
                            
                    end
                    printpreview(f);
                    close(f);
                case 5      % Model Simulation.    
                    f=figure('Visible','off');
                    nplots = length(this.tab_ModelSimulation.resultsOptions.plots.panel.Children);
                    copyobj(this.tab_ModelSimulation.resultsOptions.plots.panel.Children(1:nplots),f);
                    printpreview(f);
                    close(f);                    
                otherwise
                    return;
            end            
        end
        
        function onExportPlot(this, hObject, eventdata)
            set(this.Figure, 'pointer', 'watch');
            switch this.figure_Layout.Selection
                case {1,3}
                    errordlg('No plot is displayed within the current tab.');
                    return;
                case 2      % Data prep.
                    pos = get(this.tab_DataPrep.modelOptions.resultsOptions.box.Children(2),'Position'); 
                    legendObj = this.tab_DataPrep.modelOptions.resultsOptions.plots.Legend;
                    
                    f=figure('Visible','off');
                    copyobj(this.tab_DataPrep.modelOptions.resultsOptions.plots,f);
                    
                    % Format figure                    
                    set(f, 'Color', 'w');
                    set(f, 'PaperType', 'A4');
                    set(f, 'PaperOrientation', 'landscape');
                    set(f, 'Position', pos);
                case 4      % Model Calib.
                    f=figure('Visible','off');
                    switch this.tab_ModelCalibration.resultsTabs.SelectedChild
                        case 1
                            pos = get(this.tab_ModelCalibration.resultsOptions.calibPanel.Children.Children(1).Children(1),'Position');
                            if length(this.tab_ModelCalibration.resultsOptions.calibPanel.Children.Children(1).Children(1))==1
                                legendObj = [];
                                copyobj(this.tab_ModelCalibration.resultsOptions.calibPanel.Children.Children(1).Children(1).Children,f);
                            else
                                copyobj(this.tab_ModelCalibration.resultsOptions.calibPanel.Children.Children(1).Children(1).Children(2),f);
                                legendObj = this.tab_ModelCalibration.resultsOptions.calibPanel.Children.Children(1).Children(1).Children(1);
                            end
                        case 2
                            pos = get(this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(4),'Position');
                            if length(this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(4)==1)
                                copyobj(this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(4).Children,f);
                                legendObj = [];
                            else
                                copyobj(this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(4).Children(end),f);
                                legendObj = this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(4).Children(end-1);                                
                            end
                        case 3
                            pos = get(this.tab_ModelCalibration.resultsOptions.paramsPanel.Children.Children(1),'Position');
                            copyobj(this.tab_ModelCalibration.resultsOptions.paramsPanel.Children.Children(1).Children,f);                             
                            legendObj = [];
                        case 4
                            pos = get(this.tab_ModelCalibration.resultsOptions.derivedParamsPanel.Children.Children(1),'Position');
                            copyobj(this.tab_ModelCalibration.resultsOptions.derivedParamsPanel.Children.Children(1).Children,f);                             
                            legendObj = [];
                            
                        case 5
                            pos = get(this.tab_ModelCalibration.resultsOptions.modelSpecificsPanel.Children.Children(1),'Position');
                            copyobj(this.tab_ModelCalibration.resultsOptions.modelSpecificsPanel.Children.Children(1).Children,f);                             
                            legendObj = [];                            
                    end

                    % Format figure
                    set(f, 'Color', 'w');
                    set(f, 'PaperType', 'A4');
                    set(f, 'PaperOrientation', 'landscape');
                    set(f, 'Position', pos);
                    
                case 5      % Model Simulation.    
                    f=figure('Visible','off');
                    nplots = length(this.tab_ModelSimulation.resultsOptions.plots.panel.Children);
                    pos = get(this.tab_ModelSimulation.resultsOptions.plots.panel,'Position');
                    copyobj(this.tab_ModelSimulation.resultsOptions.plots.panel.Children(1:nplots),f);  
                    legendObj = [];
                    
                    % Format each axes
                    ax =  findall(f,'type','axes');
                    for i=1:nplots
                        set(ax(i), 'Color', 'w');
                    end
                    
                    % Format figure
                    set(f, 'Color', 'w');
                    set(f, 'PaperType', 'A4');
                    set(f, 'PaperOrientation', 'landscape');
                    set(f, 'Position', pos);                    
                otherwise
                    return;
            end
                        
            % set current folder to the project folder (if set)
            set(this.Figure, 'pointer', 'arrow');
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
            [fName,pName] = uiputfile({'*.png'},'Save plot PNG image as ...','plot.png');    
            if fName~=0    
                set(this.Figure, 'pointer', 'watch');
                
                % Export image
                if ~isempty(legendObj)
                    legend(gca,legendObj.String,'Location',legendObj.Location)
                end
                export_fig(f, fName);
            end
            close(f);
            set(this.Figure, 'pointer', 'arrow');
            
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
                'Visible','off');

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
            drawnow update; 
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
                response = questdlg({'Opening an example project will close the current project.','','Do you want to continue?'}, ...
                 'Close the current project?','Yes','No','No');
             
                if strcmp(response,'No')
                    return;
                end
            end
            
            % Add message explaing the model examples.
            h= msgbox({'The example models provide an overview of some of the features of the', ...
                    'toolbox plus example input data files.', ...
                    '', ...
                    'To open an example, you will first be asked to specify a folder in which', ...
                    'the .csv file are to be generated by the toolbox.', ...
                    '', ...
                    'Once the files are created, the toolbox will contain a series of', ...
                    'calibrated time-series models. You can use these models to undertake', ...
                    'simulations, or alternatively you can rebuild and calibrate, or edit,', ...
                    'the models.'},'Opening Example Models ...','help') ;
            uiwait(h);
                
            % Ask user the locations where the input data is to be saved.          
            if isnumeric(this.project_fileName)
                this.project_fileName='';
            end
            if ~isempty(this.project_fileName)
                folderName = fileparts(this.project_fileName);
            else
                folderName = fileparts(pwd); 
            end
            folderName = uigetdir(folderName ,'Select folder in which to save the example .csv files.');    
            if isempty(folderName)
                return;
            end
            this.project_fileName = folderName;
            
            % Change cursor
            set(this.Figure, 'pointer', 'watch');      
            drawnow update;
            
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
                    drawnow update;
                    warndlg('The requested example model could not be found.','Example Model Error ...');
                    return;
            end
            
            % Check there is the required data
            if ~isfield(exampleData,'forcing') || ~isfield(exampleData,'coordinates') || ~isfield(exampleData,'obsHead')
                set(this.Figure, 'pointer', 'arrow');   
                drawnow update;
                warndlg('The example data for the model does not exist. It must contain the following Matlab tables: forcing, coordinates, obsHead.','Example Model Data Error ...');                
                return;                
            end
            
            % Check that the data is a table. 
            if ~istable(exampleData.forcing) || ~istable(exampleData.coordinates) || ~istable(exampleData.obsHead) 
                set(this.Figure, 'pointer', 'arrow');   
                drawnow update;
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
                        drawnow update;
                        warndlg('The requested example model could not be found.','Example Model Error ...');
                        return;
                end            
                
            catch ME
                set(this.Figure, 'pointer', 'arrow');
                drawnow update;
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
            if size(exampleModel.tableData.tab_ModelCalibration,2)==14
                this.tab_ModelCalibration.Table.Data =  exampleModel.tableData.tab_ModelCalibration(:,[1:8,10:14]);
            else
                this.tab_ModelCalibration.Table.Data = exampleModel.tableData.tab_ModelCalibration;
            end
            nrows = size(this.tab_ModelCalibration.Table.Data,1);
            this.tab_ModelCalibration.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                      

            % Model Simulation
            this.tab_ModelSimulation.Table.Data = exampleModel.tableData.tab_ModelSimulation;
            nrows = size(this.tab_ModelSimulation.Table.Data,1);
            this.tab_ModelSimulation.Table.RowName = mat2cell([1:nrows]',ones(1, nrows));                       

            % Set flag denoting models are on RAM.            
            this.modelsOnHDD =  '';

            % Load modle objects 
            %-------------
            % CLear models in preject.                        
            this.models=[];

            % Determine number of models
            filt = strcmp(fieldnames(exampleModel),'dataPrep') | strcmp(fieldnames(exampleModel),'settings') |  strcmp(fieldnames(exampleModel),'tableData');
            modelLabels = fieldnames(exampleModel);
            modelLabels = modelLabels(~filt);
            nModels = length(modelLabels);

            % Create object array
            %this.models.data(nModels,1) = [HydroSight];

            % Set model
            for i=1:nModels
                modelLabeltmp = HydroSight_GUI.modelLabel2FieldName(modelLabels{i});
                setModel(this, modelLabeltmp , exampleModel.(modelLabeltmp));
            end
            %-------------
            
            % Assign analysed bores.
            this.dataPrep = exampleModel.dataPrep;            
        
            % Updating project location with title bar
            set(this.Figure,'Name',['HydroSight - ', this.project_fileName]);
            drawnow update;                            
            
            % Disable file menu items
            for i=1:size(this.figure_Menu.Children,1)
                if strcmp(get(this.figure_Menu.Children(i),'Label'), 'Save Project')
                    set(this.figure_Menu.Children(i),'Enable','off');
                elseif strcmp(get(this.figure_Menu.Children(i),'Label'), 'Move models from RAM to HDD...') || ...
                strcmp(get(this.figure_Menu.Children(i),'Label'), 'Move models from HDD to RAM...')
                    set(this.figure_Menu.Children(i),'Enable','off');
                    set(this.figure_Menu.Children(i),'Label','Move models from RAM to HDD...');
                end       
            end   
            
            % Change pointer
            set(this.Figure, 'pointer', 'arrow');  
            drawnow update;
            
        end
        
        
        function onChangeTableWidth(this, hObject, eventdata, tableTag)
            
           % Get current table panel
           h = findobj(this.figure_Layout, 'Tag',tableTag);
                      
           % Get Current width
           w = get(h,'Widths');
           
           % Set the widths abovethe current panel to -1
           w(2:end) = -1;
           sumW = sum(w(2:end));
           
           % Solve the implict problem defining the relative width of the
           % current panel.
           targetWidthRatio = hObject.Value;
           fun = @(x) x/(x+sumW)-targetWidthRatio;
           newWidth=fzero(fun,[-1000, -0.01]);
           set(h,'Widths',[newWidth, w(2:end)]);
                     
        end
        
        function rowAddDelete(this, hObject, eventdata)
           
            % Get the table object from UserData
            tableObj = eval(eventdata.Source.Parent.UserData);            
            
            % Get selected rows
            if isempty(tableObj.Data)
                selectedRows = [];
            else
                for i=1:size(tableObj.Data,1)
                   if isempty(tableObj.Data{i,1}) 
                       tableObj.Data{i,1}=false;
                   end
                end
                selectedRows = cell2mat(tableObj.Data(:,1));
            end

            % Check if any rows are selected. Note, if not then
            % rows will be added (for all but the calibration
            % table).
            anySelected = any(selectedRows);
            indSelected = find(selectedRows)';
            
            if ~isempty(tableObj.Data)
                if size(tableObj.Data(:,1),1)>0 &&  ~anySelected && ~strcmp(hObject.Label,'Paste rows')
                    warndlg('No rows are selected for the requested operation.');
                    return;
                elseif size(tableObj.Data(:,1),1)==0 ...
                &&  (strcmp(hObject.Label, 'Copy selected row') || strcmp(hObject.Label, 'Delete selected rows'))                
                    return;
                end               
            end
            
            % Get column widths
            colWidths = tableObj.ColumnWidth;
            
            % Define the input for the status column and default data for
            % inserting new rows.
            defaultData = cell(1,size(tableObj.Data,2));
            switch tableObj.Tag
                case 'Data Preparation'
                    modelStatus = '<html><font color = "#FF0000">Bore not analysed.</font></html>';
                    modelStatus_col = 16;
                    defaultData = {false, '', '',0, 0, 0, '01/01/1900',true, true, true, true, 10, 120, 4,false, modelStatus, ...
                    '<html><font color = "#808080">(NA)</font></html>', ...
                    '<html><font color = "#808080">(NA)</font></html>'};
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
            
            % Change pointer
            set(this.Figure, 'pointer', 'watch');  
            
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
                                    newModelLabel = HydroSight_GUI.createUniqueLabel(tableObj.Data(:,2), this.copiedData.data{1,2}, i);
                                    
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
                                    newModLabel = HydroSight_GUI.createUniqueLabel(tableObj.Data(:,2), newModLabel, irow);

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
                                    newSimLabel = HydroSight_GUI.createUniqueLabel(tableObj.Data(:,[2,6]), newSimLabel, i);
                                    
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
                                    newSimLabel = HydroSight_GUI.createUniqueLabel(tableObj.Data(:,[2,6]), newSimLabel, irow );
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
                    if isempty(tableObj.Data)
                        tableObj.Data = defaultData;
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
                    if isempty(tableObj.Data)
                        tableObj.Data = defaultData;
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
                            % Delete the model object
                            try
                                deleteModel(this, this.tab_ModelConstruction.Table.Data{i,2});
                            catch ME
                                % do nothing
                            end
                        end
                    elseif strcmp(tableObj.Tag,'Data Preparation')                        
                        for i=indSelected
                            
                            % Get model label
                            boreID= tableObj.Data{i,3};
                            
                            % Remove model object
                            if isfield(this.dataPrep,boreID)
                                this.dataPrep = rmfield(this.dataPrep,boreID);
                            end
                        end                        
                    end
                    
                    % Delete table data
                    tableObj.Data = tableObj.Data(~selectedRows,:);
                    
                    % Update row numbers.
                    nrows = size(tableObj.Data,1);
                    tableObj.RowName = mat2cell([1:nrows]',ones(1, nrows));
                    
            end
            
            % Reset column widths
            tableObj.ColumnWidth = colWidths;            
            
             % Change pointer
            set(this.Figure, 'pointer', 'arrow');  
        end
        
        function rowSelection(this, hObject, eventdata)

            % Get the table object from UserData
            tableObj = eval(eventdata.Source.Parent.UserData);            
                                    
            % Get selected rows
            selectedRows = cellfun(@(x) ~isempty(x) && islogical(x) && x, tableObj.Data(:,1));
            
            % Do the selected action            
            switch hObject.Label
                case 'Select all'
                    tableObj.Data(:,1) = mat2cell(true(size(selectedRows,1),1),ones(1, size(selectedRows,1)));
                case 'Select none'
                    tableObj.Data(:,1) = mat2cell(false(size(selectedRows,1),1),ones(1, size(selectedRows,1)));
                case 'Invert selection'
                    tableObj.Data(:,1) = mat2cell(~selectedRows,ones(1, size(selectedRows,1)));
                case 'Select row range ...'
                    rowRange = inputdlg( {'First row number:', 'Last row number:'}, 'Input row range for selection.',1,{'1','2'});
                    if isempty(rowRange)
                        return;
                    end
                    irows = [1:size(tableObj.Data,1)]';
                    try
                        startRow=str2num(rowRange{1});
                        endRow=str2num(rowRange{2});
                    catch ME
                        warndlg('The first and last row inputs must be numbers','Input Error')
                        return;
                    end
                    if startRow>= endRow
                        warndlg('The first row must be less than the last row.','Input Error')
                        return;                        
                    end
                    filt =  (irows >=startRow &  irows <=endRow) | selectedRows;
                    tableObj.Data(:,1) =  mat2cell(filt,ones(1, size(selectedRows,1)));
                    
                case 'Select by col. value ...'
                    colNames = HydroSight_GUI.removeHTMLTags(tableObj.ColumnName);
                    
                    [selectedCol,ok] = listdlg('PromptString', 'Select column:', 'Name', 'Select by col. value ...', ...
                        'ListString', colNames,'SelectionMode','single');                                        

                    if ok==1
                        colNames_str = inputdlg('Input the string to be found within the selected column:',  'Select by col. value ...',1);
                        
                        if isempty(colNames_str)
                            return;
                        end
                        
                        % Find rows within table
                        filt = cellfun(@(x) ~isempty(strfind(upper(x),upper(colNames_str{1}))) , tableObj.Data(:,selectedCol));
                        filt = filt | selectedRows;
                        
                        % Select rows
                        tableObj.Data(:,1) =  mat2cell(filt,ones(1, size(selectedRows,1)));
                    end

            end
                        
        end
        
        
        function fName = getFileName(this, dialogString)
           
            % If project folder is not set, exit
            if isempty(this.project_fileName)
                errordlg('The project folder must be set before files can be input.');
                fName=0;
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

        function [model, errmsg] = getModel(this, modelLabel)
            % Convert model label to a valid field name
            modelLabel = HydroSight_GUI.modelLabel2FieldName(modelLabel);
            
            model = [];
            if isempty(modelLabel)
                    errmsg = 'Model label is empty.';
                    return;
            end
            
            % Get model            
            if isempty(this.modelsOnHDD) || (islogical(this.modelsOnHDD) && ~this.modelsOnHDD)
                if isa(this.models.(modelLabel),'HydroSightModel')                    
                    model = this.models.(modelLabel);
                else
                    errmsg = ['The following model is not a HydroSight object and could not be loaded:',modelLabel];
                end
            elseif ~isempty(this.modelsOnHDD)
                try                    
                    % Build file path to model .mat file
                    filepath = fullfile(fileparts(this.project_fileName), this.modelsOnHDD, [modelLabel,'.mat']);

                    % Change file seperator fro OS
                    filepath = strrep(filepath, '/',filesep);
                    filepath = strrep(filepath, '\',filesep);
                                        
                    % Check the file exists
                    if exist(filepath, 'file')==0
                        errmsg = ['The following HydroSight .mat file could not be found:',modelLabel];
                        return;
                    end                   
                           
                    % Load model and check.
                    savedData = load(filepath,'model');
                    model = savedData.model;
                    if ~isa(model,'HydroSightModel');
                        errmsg = ['The following model is not a HydroSight object and could not be loaded:',modelLabel];    
                        model=[];
                    end
                catch
                    errmsg = ['The following model is not a HydroSight object and could not be loaded:',modelLabel];
                end
            else
                errmsg = ['The following model could not be loaded:',modelLabel];
            end            
        end
        
        function errmsg = setModel(this, modelLabel, model)
            % Convert model label to a valid field name
            modelLabel = HydroSight_GUI.modelLabel2FieldName(modelLabel);
           
            isCalibrated=false;
            
            % Set model
            if isempty(this.modelsOnHDD)
                if isa(model,'HydroSightModel')                    
                    % Add model object
                    this.models.(modelLabel) = model;
                    
                    % Check if calibrated                    
                    if isfield(this.models.(modelLabel).calibrationResults,'isCalibrated')
                        isCalibrated = this.models.(modelLabel).calibrationResults.isCalibrated;
                    end

                else
                    errmsg = ['The following model is not a HydroSight object and could not be set:',modelLabel];
                    return;
                end
            elseif ~isempty(this.modelsOnHDD)
                if isa(model,'HydroSightModel')   
                    % Build file path to model .mat file
                    filepath = fullfile(fileparts(this.project_fileName), this.modelsOnHDD, [modelLabel,'.mat']);

                    % Change file seperator fro OS
                    filepath = strrep(filepath, '/',filesep);
                    filepath = strrep(filepath, '\',filesep);                
                           
                    % Delete file it if exists
                    if exist(filepath,'file')>0
                        delete(filepath);
                    end
                    
                    % Save model object                          
                    save(filepath,'model');
                    
                    % Update object hold the relative path to the .mat file
                    this.models.(modelLabel) = fullfile(this.modelsOnHDD, [modelLabel,'.mat']);
                    
                    % Check if calibrated                    
                    if isfield(model.calibrationResults,'isCalibrated')
                        isCalibrated = model.calibrationResults.isCalibrated;
                    end
                elseif ischar(model);
                    % Build file path to model .mat file
                    filepath = fullfile(fileparts(this.project_fileName), this.modelsOnHDD, [modelLabel,'.mat']);
                    
                    % Change file seperator fro OS
                    filepath = strrep(filepath, '/',filesep);
                    filepath = strrep(filepath, '\',filesep);
                    
                    % Check the file exists
                    if exist(filepath, 'file')==0
                        errmsg = ['The following model is not a HydroSight object and could not be set:',modelLabel];
                        return;
                    end
                    
                    % Load model to assess if calibrated.
                    savedData= load(filepath);
                    model = savedData.model;
                    
                    % Update object hold the relative path to the .mat file
                    this.models.(modelLabel) = fullfile(this.modelsOnHDD, [modelLabel,'.mat']);
                    
                    % Check if calibrated                    
                    if isfield(model.calibrationResults,'isCalibrated')
                        isCalibrated = model.calibrationResults.isCalibrated;
                    end                    
                else
                    errmsg = ['The following model is not a HydroSight object and could not be set:',modelLabel];
                    return;
                end
            else
                errmsg = ['The following model could not be set:',modelLabel];
                return;
            end            
            
            % Update or add model lable to list
            if ~isempty(this.model_labels) && any(strcmp(this.model_labels.Properties.RowNames,modelLabel))
                this.model_labels{modelLabel,1} = isCalibrated;
            else           
                % Add model label to object. This is done to elimnate the need
                % to open all models, which can be slow if they're on the HDD.
                modelLabelasCell{1} = modelLabel;
                tbleRow = table(isCalibrated,'RowNames',modelLabelasCell);
                if isempty(this.model_labels);
                    this.model_labels = tbleRow;
                else
                    this.model_labels = [this.model_labels;tbleRow];
                end
            end
            
        end
        
        function [model, errmsg] = deleteModel(this, modelLabel)
            % Convert model label to a valid field name
            modelLabel = HydroSight_GUI.modelLabel2FieldName(modelLabel);
            
            model = [];
            if isempty(modelLabel)
                    errmsg = 'Model label is empty.';
                    return;
            end
            
            % Delete model            
            if isempty(this.modelsOnHDD) || ~this.modelsOnHDD
                if isa(this.models.(modelLabel),'HydroSightModel')                    
                    this.models = rmfield(this.models, modelLabel);
                else
                    errmsg = ['The following model is not a HydroSight object and could not be deleted:',modelLabel];
                end
                
                % Remove from model label list
                filt = ~strcmp(this.model_labels.Properties.RowNames,modelLabel);
                this.model_labels = this.model_labels(filt,:);
                                
            elseif ~isempty(this.modelsOnHDD)
                try                    
                    % Build file path to model .mat file
                    filepath = fullfile(fileparts(this.project_fileName), this.modelsOnHDD, [modelLabel,'.mat']);

                    % Change file seperator fro OS
                    filepath = strrep(filepath, '/',filesep);
                    filepath = strrep(filepath, '\',filesep);
                                        
                    % Check the file exists
                    if exist(filepath, 'file')==0
                        errmsg = ['The following HydroSight .mat file could not be found:',modelLabel];
                        return;
                    end                   
                           
                    % Delete model file.                    
                    delete(filepath);
                    this.models = rmfield(this.models, modelLabel);

                    % Remove from model label list
                    filt = ~strcmp(this.model_labels.Properties.RowNames,modelLabel);
                    this.model_labels = this.model_labels(filt,:);                    
                    
                catch
                    errmsg = ['The following model is not a HydroSight object and could not be deleted:',modelLabel];
                end
            else
                errmsg = ['The following model could not be deleted:',modelLabel];
            end            
        end        
        
    end
    
    methods (Access=private)
        function this = calibGUI(this, calibTable)
           
            
        end
                
        
        function startCalibration(this,hObject,eventdata)
            
            % Get table data
            data = this.tab_ModelCalibration.Table.Data;            
            
            % Get list of selected bores and check.
            selectedBores = data(:,1);
            isModelSelected=false;
            for i=1:length(selectedBores);                
                % Check if the model is to be calibrated.
                if ~isempty(selectedBores{i}) && selectedBores{i}
                    isModelSelected=true;
                    break;
                end                
            end                        
                                    
            % Check that the user wants to save the projct after each
            % calib.
            saveModels=false;
            if ~strcmp(hObject.Tag,'Start calibration - useHPC')
                set(this.Figure, 'pointer', 'arrow');
                drawnow update
                
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
            end

            % Change label of button to quit
            obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','Start calibration');
            obj.Enable = 'off';
            obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','Quit calibration');
            obj.Enable = 'on';            
            
            % Change cursor
            set(this.Figure, 'pointer', 'watch');
            drawnow update
            
            % Open parrallel engine for calibration
            if ~strcmp(hObject.Tag,'Start calibration - useHPC')
                try
                    %nCores=str2double(getenv('NUMBER_OF_PROCESSORS'));
                    parpool('local');
                catch ME
                    % Do nothing. An error is probably that parpool is already
                    % open
                end
            end
            
            % Count the number of models selected
            nModels=0;
            iModels=0;
            for i=1:length(selectedBores);                                
                if ~isempty(selectedBores{i}) && selectedBores{i}
                    nModels = nModels +1;
                end
            end
            
            % Setup wait bar
            waitBarPlot = findobj(this.tab_ModelCalibration.GUI, 'Tag','Calib_wait_bar');
            waitBarPlot.YData=0;
                                    
            % Setup inputs for the GUI diary file.
            commandwindowBox = findobj(this.tab_ModelCalibration.GUI, 'Tag','calibration command window');
            commandwindowBox.Max=Inf;
            commandwindowBox.Min=0;
                        
            %% Start calibration                             
            % Loop  through the list of selected bore and apply the model
            % options.
            nModelsCalib = 0;
            nModelsCalibFailed = 0;
            nHPCmodels = 0;
            for i=1:length(selectedBores)
                
                % Check if the model is to be calibrated.
                if isempty(selectedBores{i}) || ~selectedBores{i}
                    continue;
                end
                
                % Get the selected model for simulation
                calibLabel = data{i,2};
                calibLabel = HydroSight_GUI.removeHTMLTags(calibLabel);
                
                % Get start and end date. Note, start date is at the start
                % of the day and end date is shifted to the end of the day.
                calibStartDate = datenum( data{i,6},'dd-mmm-yyyy');
                calibEndDate = datenum( data{i,7},'dd-mmm-yyyy') + datenum(0,0,0,23,59,59);
                calibMethod = data{i,8};

                % Get a copy of the model object. This is only done to
                % minimise HDD read when the models are off loaded to HDD using
                % matfile();                
                tmpModel = getModel(this, calibLabel);

                % Exit if model is model not found
                if isempty(tmpModel)
                    nModelsCalibFailed = nModelsCalibFailed +1;
                    this.tab_ModelCalibration.Table.Data{i,9} = '<html><font color = "#FF0000">Fail-Model appears not to have been built.</font></html>';
                    continue;
                end  

                % Start the diary and copying of the command window outputs to
                % the GUI. Unfortunately a new diary file needs to be
                % created per model because the updating can be very slow
                % when multiple models outputs are within one diary file
                % (eg 12 seconds per update!)
                diaryFilename = strrep(this.project_fileName,'.mat',['_',calibLabel,'_calibOutputs_',strrep(strrep(datestr(now),':','-'),' ','_'),'.txt']);
                this.tab_ModelCalibration.QuitObj = calibGUI_interface(commandwindowBox,diaryFilename);
                startDiary(this.tab_ModelCalibration.QuitObj);   

                obj = this.tab_ModelCalibration.QuitObj;
                lh = addlistener(this,'quitModelCalibration',@obj.quitCalibrationListener);
                
                % Update status to starting calib.
                this.tab_ModelCalibration.Table.Data{i,9} = '<html><font color = "#FFA500">Calibrating ... </font></html>';

                % Update status in GUI
                drawnow

                % Collate calibration settings
                calibMethodSetting=struct();
                switch calibMethod                    
                    case 'CMAES'
                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','CMAES MaxFunEvals');
                        calibMethodSetting.MaxFunEvals= str2double(obj.String);

                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','CMAES TolFun');
                        calibMethodSetting.TolFun= str2double(obj.String);

                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','CMAES TolX');
                        calibMethodSetting.TolX= str2double(obj.String);

                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','CMAES Restarts');
                        calibMethodSetting.Restarts= str2double(obj.String);

                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','CMAES insigmaFrac');
                        calibMethodSetting.insigmaFrac= str2double(obj.String);

                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','CMAES Seed');
                        calibMethodSetting.Seed= str2double(obj.String);

                    case 'SP-UCI'
                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','SP-UCI maxn');
                        calibMethodSetting.maxn = str2double(obj.String);

                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','SP-UCI kstop');
                        calibMethodSetting.kstop = str2double(obj.String);

                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','SP-UCI pcento');
                        calibMethodSetting.pcento = str2double(obj.String);

                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','SP-UCI peps');
                        calibMethodSetting.peps = str2double(obj.String);

                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','SP-UCI ngs');
                        ngs_per_param = str2double(obj.String);

                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','SP-UCI ngs min');
                        ngs_min = str2double(obj.String);

                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','SP-UCI ngs max');
                        ngs_max = str2double(obj.String);                                                        

                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','SP-UCI iseed');
                        calibMethodSetting.iseed = str2double(obj.String);


                        % Get the number of parameters.
                        [params, param_names] = getParameters(tmpModel.model);
                        nparams = size(param_names,1);

                        % Calculate the number of complexes for this model.
                        calibMethodSetting.ngs = max(ngs_min, min(ngs_max, ngs_per_param*nparams));

                    case 'DREAM'
                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','DREAM N');
                        calibMethodSetting.N = str2double(obj.String);

                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','DREAM T');
                        calibMethodSetting.T = str2double(obj.String);

                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','DREAM nCR');
                        calibMethodSetting.nCR = str2double(obj.String);

                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','DREAM delta');
                        calibMethodSetting.delta = str2double(obj.String);

                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','DREAM lambda');
                        calibMethodSetting.lambda = str2double(obj.String);

                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','DREAM zeta');
                        calibMethodSetting.zeta = str2double(obj.String);

                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','DREAM outlier');
                        calibMethodSetting.outlier = str2double(obj.String);

                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','DREAM pJumpRate_one');
                        calibMethodSetting.pJumpRate_one = str2double(obj.String);                            
                end
                        
                % Start calib.
                try                    
                    if strcmp(hObject.Tag,'Start calibration - useHPC')
                        display(['BUILDING OFFLOAD DATA FOR MODEL: ',calibLabel]);
                        display('  ');
                        % Update the diary file
                        if ~isempty(this.tab_ModelCalibration.QuitObj)
                            updatetextboxFromDiary(this.tab_ModelCalibration.QuitObj);
                        end
                        
                        nHPCmodels = nHPCmodels +1;
                        HPCmodelData{nHPCmodels,1} = tmpModel;
                        HPCmodelData{nHPCmodels,2} = calibStartDate;
                        HPCmodelData{nHPCmodels,3} = calibEndDate;
                        HPCmodelData{nHPCmodels,4} = calibMethod;
                        HPCmodelData{nHPCmodels,5} = calibMethodSetting;                        
                        this.tab_ModelCalibration.Table.Data{i,9} = '<html><font color = "#FFA500">Calib. on HPC... </font></html>';
                    else
                        display(['CALIBRATING MODEL: ',calibLabel]);
                        display( '--------------------------------------------------------------------------------');
                        % Update the diary file
                        if ~isempty(this.tab_ModelCalibration.QuitObj)
                            updatetextboxFromDiary(this.tab_ModelCalibration.QuitObj);
                        end   
                    
                        calibrateModel( tmpModel, this.tab_ModelCalibration.QuitObj, calibStartDate, calibEndDate, calibMethod,  calibMethodSetting);

                        % Delete CMAES working filescopl                        
                        switch calibMethod
                            case {'CMA ES','CMA_ES','CMAES','CMA-ES'}
                                delete('*.dat');
                            otherwise
                                % do nothing
                        end

                        % Get calib exit status
                        exitFlag = tmpModel.calibrationResults.exitFlag;
                        exitStatus = tmpModel.calibrationResults.exitStatus;                          

                        % Set calib performance stats.
                        calibAICc = median(tmpModel.calibrationResults.performance.AICc);
                        calibBIC =median( tmpModel.calibrationResults.performance.BIC);
                        calibCoE = median(tmpModel.calibrationResults.performance.CoeffOfEfficiency_mean.CoE);
                        this.tab_ModelCalibration.Table.Data{i,10} = ['<html><font color = "#808080">',num2str(calibCoE),'</font></html>'];
                        this.tab_ModelCalibration.Table.Data{i,12} = ['<html><font color = "#808080">',num2str(calibAICc),'</font></html>'];
                        this.tab_ModelCalibration.Table.Data{i,13} = ['<html><font color = "#808080">',num2str(calibBIC),'</font></html>'];

                        % Set eval performance stats
                        if isfield(tmpModel.evaluationResults,'performance')
                            %evalAIC = this.models.data{ind, 1}.evaluationResults.performance.AIC;
                            evalCoE = mean(tmpModel.evaluationResults.performance.CoeffOfEfficiency_mean.CoE_unbias);

                            this.tab_ModelCalibration.Table.Data{i,11} = ['<html><font color = "#808080">',num2str(evalCoE),'</font></html>'];                            
                        else
                            evalCoE = '(NA)';
                            %evalAIC = '(NA)';

                            this.tab_ModelCalibration.Table.Data{i,11} = ['<html><font color = "#808080">',evalCoE,'</font></html>'];                            
                        end
                        nModelsCalib = nModelsCalib +1;

                        % Add updated tmpModel back to data structure of
                        % all models
                        setModel(this, calibLabel, tmpModel)

                        if saveModels
                            this.tab_ModelCalibration.Table.Data{i,9} = '<html><font color = "#FFA500">Saving project. </font></html>';

                            % Update status in GUI
                            drawnow                        

                            % Save project.
                            onSave(this,hObject,eventdata);
                        end                        

                        % Update calibr status                          
                        if exitFlag ==0 
                            this.tab_ModelCalibration.Table.Data{i,9} = ['<html><font color = "#FF0000">Fail-', ME.message,'</font></html>'];
                        elseif exitFlag ==1
                            this.tab_ModelCalibration.Table.Data{i,9} = ['<html><font color = "#FFA500">Partially calibrated: ',exitStatus,' </font></html>'];
                        elseif exitFlag ==2
                            this.tab_ModelCalibration.Table.Data{i,9} = ['<html><font color = "#008000">Calibrated: ',exitStatus,' </font></html>'];
                        end                      
                        
                    end


                    % Check if the user quit the calibration.
                    [doQuit, exitFlagQuit, exitStatusQuit] = getCalibrationQuitState(this.tab_ModelCalibration.QuitObj);                        
                    if doQuit
                        exitFlag = exitFlagQuit;
                        exitStatus = exitStatusQuit;
                        this.tab_ModelCalibration.Table.Data{i,9} = ['<html><font color = "#FF0000">Fail-', exitStatus,'</font></html>'];                            
                        break;
                    end


                catch ME
                    nModelsCalibFailed = nModelsCalibFailed +1;
                    this.tab_ModelCalibration.Table.Data{i,9} = ['<html><font color = "#FF0000">Fail-', ME.message,'</font></html>'];
                end
                
                % Update wait bar
                waitBarPlot.YData = waitBarPlot.YData+1;
                
                % Update status in GUI
                drawnow
                                
            end
            
            % Close wait bar
            %if ~strcmp(hObject.Tag,'useHPC') && nModels>=minModels4Waitbar            
            %    close(h);
            %end
            
            % Change label of button to quit
            obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','Start calibration');
            obj.Enable = 'on';
            obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','Quit calibration');
            obj.Enable = 'off';            
            
            % Change cursor to arrow
            set(this.Figure, 'pointer', 'arrow');
            drawnow update
            if strcmp(hObject.Tag,'Start calibration - useHPC')
               project_fileName = this.project_fileName;
               if ~isdir(this.project_fileName)
                   project_fileName = fileparts(project_fileName);
               end
               
               userData = jobSubmission(this.HPCoffload, project_fileName, HPCmodelData, this.tab_ModelCalibration.QuitObj) ; 
               if ~isempty(userData)
                   this.HPCoffload = userData;
               end

                % Update status in GUI
                drawnow update
                    
            else
                % Report Summary
                msgbox(['The model was successfully calibrated for ',num2str(nModelsCalib), ' models and failed for ',num2str(nModelsCalibFailed), ' models.'], 'Summary of model calibration ...');
            end        
        end
        
        function quitCalibration(this,hObject,eventdata)
            % Notify event that the user is quiting the calibration. The
            % listener in class "calibGUI_interface" should then be called.
            notify(this,'quitModelCalibration');
        end
        

        function multimodel_moveLeft(this,hObject,eventdata)
            % Find the RH list object
            leftlistBox = findobj(this.tab_ModelCalibration.GUI, 'Tag','NLMEFIT paramsLeftList');
            rightlistBox = findobj(this.tab_ModelCalibration.GUI, 'Tag','NLMEFIT paramsRightList');
            
            % Add selected params to LH box
            leftlistBox.String = {leftlistBox.String{:}, rightlistBox.String{rightlistBox.Value}};
            leftlistBox.String = sort(leftlistBox.String);
            
            % Remove from RH box.
            ind  = true(size(rightlistBox.String));
            ind(rightlistBox.Value)=false;
            rightlistBox.String = rightlistBox.String(ind);
            rightlistBox.String = sort(rightlistBox.String);
        
        end
        
        function multimodel_moveRight(this,hObject,eventdata)                    
            % Find the RH list object
            leftlistBox = findobj(this.tab_ModelCalibration.GUI, 'Tag','NLMEFIT paramsLeftList');
            rightlistBox = findobj(this.tab_ModelCalibration.GUI, 'Tag','NLMEFIT paramsRightList');
            
            % Add selected params to RH box
            rightlistBox.String = {rightlistBox.String{:}, leftlistBox.String{leftlistBox.Value}};
            rightlistBox.String = sort(rightlistBox.String);
            
            % Remove from LH box.
            ind  = true(size(leftlistBox.String));
            ind(leftlistBox.Value)=false;
            leftlistBox.String = leftlistBox.String(ind);
            leftlistBox.String = sort(leftlistBox.String);
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
                    newLabel = [origLabel{1}, ' copy ',num2str(label_extension)];    
                end
            elseif size(allLabels,2)==2
                newLabel = {origLabel{1}, [origLabel{2}, ' copy ',num2str(label_extension)]};
                while any(find(cellfun( @(x,y) strcmp( newLabel{1}, x) &&  strcmp( newLabel{2}, y) , allLabels(:,1), allLabels(:,2)))~=currentRow)
                    label_extension = label_extension + 1;
                    newLabel = {origLabel{1}, [origLabel{2}, ' copy ',num2str(label_extension)]};
                end                    
            end
        end
        
        
        function newLabel = modelLabel2FieldName(inputLabel)
           
            % Remove characeters that are not able to be included in a
            % field name.
            inputLabel = strrep(inputLabel,' ','_');
            inputLabel = strrep(inputLabel,'-','_');
            inputLabel = strrep(inputLabel,'?','');
            inputLabel = strrep(inputLabel,'\','_');
            inputLabel = strrep(inputLabel,'/','_');
            inputLabel = strrep(inputLabel,'___','_');
            inputLabel = strrep(inputLabel,'__','_');
                       
            % Check if any reserved labels are used. The reserved labels
            % are GUI variables to saved within a project .mat file.
            if strcmp(inputLabel, {'tableData'; 'dataPrep';'settings'})
                warndlg('Model label cannot be one of the following reserved labels "tableData", "dataPrep", "settings".','Model label error ...');
                newLabel='';
                return;
            end                
            
            % Check if a field name can be created with the model label
            try 
                tmp.(inputLabel) = [1 2 3];
                clear tmp;
                newLabel = inputLabel;
            catch ME
                warndlg('Model label must start with letters and have only letters and numbers.','Model label error ...');
                newLabel='';
                return;
            end
            
        end
    end
end

