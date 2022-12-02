classdef HydroSight_GUI < handle  
    %HydroSight_GUI Build and controls HydroSight GUI
    %   Detailed explanation goes here
    
    % class properties - Public properties are those where is accees is
    % required for unit testing (ie callbacks and input of data) and the
    % models (for user access via the .mat project file). Private are those
    % only required for intyernal control of GUI.
    properties(Access=public)
        %doingUnitTesting = false;

        % GUI properies for the overall figure.
        Figure;        
        figure_Menu
        figure_contextMenu
        figure_examples
        figure_Help
        figure_Layout 
        figure_icon
        
        % GUI properties for the individual tabs.
        tab_Project
        tab_DataPrep;
        tab_ModelConstruction;
        tab_ModelCalibration;        
        tab_ModelSimulation;
        
        % Store model data
        models=[];        
    end
    properties(Access=private)        
        % Model types supported
        modelTypes = {'model_TFN', 'ExpSmooth'};
                
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
       skipModelCalibration
    end
    
    methods
        
        function this = HydroSight_GUI     

            % Test if HydroSight started with -nodisplay.
            noDesktop = true;
            if usejava('desktop')
                noDesktop = false;
            end

            if noDesktop; disp('Starting to creating GUI figure.'); end

            % Get icon            
            try                 
                if noDesktop; disp('Getting data for GUI icon ...'); end
                iconData = load("appIcon.mat");
                this.figure_icon = iconData.iconData;
            catch
                this.figure_icon = [];
            end

            % Get version number
            if noDesktop; disp('Getting version number ...'); end
            [vernum,verdate]=getHydroSightVersion();

            % Show splash (suppress if deployed or if nodisplay startup used)
            if ~noDesktop && (~isdeployed || ~ispc) 
               if noDesktop; disp('Showing splash screen ...'); end 
               splashObj = SplashScreen( 'HydroSightSpalsh', fullfile('icons','splash.png'));               
               addText( splashObj, 190, 394, ['Version ',vernum,' (',verdate,')'], 'FontSize',12,'Color',[1,1,1],'FontName','ArielBold','Shadow','off');
               pause(2);
            end
            
            % Open a window and add some menus
            if noDesktop; disp('Creating GUI figure ...'); end
            this.Figure = figure( ...
                'Name', ['HydroSight ', vernum], ...
                'NumberTitle', 'off', ...
                'MenuBar', 'none', ...
                'HandleVisibility', 'off', ...
                'Visible','on', ...
                'Toolbar','figure', ...
                'CloseRequestFcn',@this.onExit, ...
                'DockControls','off');                             

            % Change icon
            if noDesktop; disp('Setting GUI icon ...'); end
            setIcon(this, this.Figure);

            % Set window Size
            if noDesktop; disp('Setting GUI size ...'); end
            windowHeight = this.Figure.Parent.ScreenSize(4);
            windowWidth = this.Figure.Parent.ScreenSize(3);
            figWidth = 0.8*windowWidth;
            figHeight = 0.6*windowHeight;            
            this.Figure.Position = [(windowWidth - figWidth)/2 (windowHeight - figHeight)/2 figWidth figHeight];
            this.Figure.Visible = 'off';
                                   
            % + File menu
            if noDesktop; disp('Creating GUI menus ...'); end
            this.figure_Menu = uimenu( this.Figure, 'Label', 'File' );
            uimenu( this.figure_Menu, 'Label', 'New Project', 'Callback', @this.onNew);
            uimenu( this.figure_Menu, 'Label', 'Set Project Folder ...', 'Callback', @this.onSetProjectFolder);
            uimenu( this.figure_Menu, 'Label', 'Open Project...', 'Callback', @this.onOpen);            
            uimenu( this.figure_Menu, 'Label', 'Save Project as ...', 'Callback', @this.onSaveAs );
            uimenu( this.figure_Menu, 'Label', 'Save Project', 'Callback', @this.onSave,'Enable','off');
            uimenu( this.figure_Menu, 'Label', 'Cite Project ...', 'Tag','Cite Project','Callback', @this.onCiteProject);
            uimenu( this.figure_Menu, 'Label', 'Import Model(s) ...', 'Callback', @this.onImportModel, 'Separator','on');
            uimenu( this.figure_Menu, 'Label', 'Move models from RAM to HDD...', 'Callback', @this.onMoveModels, 'Enable','off');
            uimenu( this.figure_Menu, 'Label', 'Exit', 'Callback', @this.onExit,'Separator','on' );

            % + Examples menu
            this.figure_examples = uimenu( this.Figure, 'Label', 'Examples' );
            uimenu( this.figure_examples, 'Label', 'TFN model - Landuse change', 'Tag','TFN - LUC','Callback', @this.onExamples );
            uimenu( this.figure_examples, 'Label', 'TFN model - Climate and pumping', 'Tag','TFN - Pumping','Callback', @this.onExamples );
            uimenu( this.figure_examples, 'Label', 'TFN model - Climate and incomplete pumping', 'Tag','TFN - Incomplete pumping record','Callback', @this.onExamples );            
            uimenu( this.figure_examples, 'Label', 'Outlier analysis - Telemetered data', 'Tag','Outlier - Telemetered','Callback', @this.onExamples );

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
            
            uimenu(this.figure_Help, 'Label', 'Cite project', 'Tag','Cite Project','Callback', @this.onCiteProject,'Separator','on');

            uimenu(this.figure_Help, 'Label', 'Check for updates at GitHub', 'Tag','doc_GitHubUpdate','Callback', @this.onGitHub,'Separator','on');
            uimenu(this.figure_Help, 'Label', 'Submit bug report to GitHub', 'Tag','doc_GitHubIssue','Callback', @this.onGitHub);
                        
            uimenu(this.figure_Help, 'Label', 'License and Disclaimer', 'Tag','doc_Publications','Callback', @this.onLicenseDisclaimer,'Separator','on');
            uimenu(this.figure_Help, 'Label', 'Version', 'Tag','doc_Version','Callback', @this.onVersion);
                        
            % Get toolbar object
            if noDesktop; disp('Creating GUI buttons ...'); end
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
            
            % load icon data
            iconData = load("iconData.mat");
            iconData = iconData.iconData;
            
            % Redefine print button
            hToolbutton = findall(hToolbar,'tag','Standard.PrintFigure');            
            set(hToolbutton, 'ClickedCallback',@this.onPrint, 'TooltipString','Open the print preview window for the displayed plot ...');
            hToolbutton.Visible = 'off';
            hToolbutton.UserData = 'Plot';
            hToolbutton.Separator = 'off';
                        
            % Check if version is 2018b or later. From this point the
            % plot toolbar buttons moved into the plot.
            v=version();
            ind = strfind(v,'.');
            v_major = str2double(v(1:(ind(1)-1)));
            v_minor = str2double(v((ind(1)+1):(ind(2)-1)));
            isBefore2018b = v_major<10 & v_minor<5; %ie is version <9.5;           
            
            % Hide property inspector
            try 
                hToolbutton = findall(hToolbar,'tag','Standard.OpenInspector');            
                hToolbutton.Visible = 'off';
                hToolbutton.UserData = 'Plot';
                hToolbutton.Separator = 'off';            
            catch
                % do nothing
            end
                
            
%             % Add tool bar          
%             if isBefore2018b
%                 hToolbutton = findall(hToolbar,'tag','Plottools.PlottoolsOn');                        
%                 hToolbutton.Visible = 'off';
%                 hToolbutton.UserData = 'Plot';	
%                 hToolbutton.Separator = 'off';
%                 hToolbutton = findall(hToolbar,'tag','Plottools.PlottoolsOff');            
%                 hToolbutton.Visible = 'off';
%                 hToolbutton.UserData = 'Never';	
%                 hToolbutton.Separator = 'off';
%                 hToolbutton = findall(hToolbar,'tag','Exploration.Brushing');            
%                 hToolbutton.Visible = 'off';
%                 hToolbutton.UserData = 'Plot';
%                 hToolbutton.Separator = 'off';
%                 hToolbutton = findall(hToolbar,'tag','Exploration.DataCursor');            
%                 hToolbutton.Visible = 'off';
%                 hToolbutton.UserData = 'Plot';
%                 hToolbutton.Separator = 'off';
%                 hToolbutton = findall(hToolbar,'tag','Exploration.Rotate');            
%                 hToolbutton.Visible = 'off';
%                 hToolbutton.UserData = 'Never';
%                 hToolbutton.Separator = 'off';
%                 hToolbutton = findall(hToolbar,'tag','Exploration.Pan');            
%                 hToolbutton.Visible = 'off';
%                 hToolbutton.UserData = 'Plot';
%                 hToolbutton.Separator = 'off';
%                 hToolbutton = findall(hToolbar,'tag','Exploration.ZoomOut');            
%                 hToolbutton.Visible = 'off';
%                 hToolbutton.UserData = 'Plot';
%                 hToolbutton.Separator = 'off';
%                 hToolbutton = findall(hToolbar,'tag','Exploration.ZoomIn');            
%                 hToolbutton.Visible = 'off';
%                 hToolbutton.UserData = 'Plot';
%                 hToolbutton.Separator = 'off';
%                 uipushtool(hToolbar,'cdata',iconData.implay, 'tooltip','Export displayed plot to PNG file ...', ...
%                     'ClickedCallback',@this.onExportPlot, ...
%                     'tag','Export.plot', 'Visible','off');
%             end

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
            uipushtool(hToolbar,'cdata',iconData.folder, 'tooltip','Set the project folder ...','Tag','Standard.SetFolder','ClickedCallback',@this.onSetProjectFolder);
            hToolbutton = findall(hToolbar);            
            set(hToolbar,'Children',hToolbutton([3:length(hToolbutton), 2]));            
                                    
            % Add new button for help.
            uipushtool(hToolbar,'cdata',iconData.help, 'tooltip','Open help for the current tab ...', 'ClickedCallback',@this.onDocumentation);
            clear iconData

            % Add separator.
            if isBefore2018b
                hToolbar.Children(13).Separator = 'on';
            end
            
            % Reset hidden state
            set(0,'ShowHiddenHandles',oldState);
            
            %Create Panels for different windows       
            if noDesktop; disp('Creating GUI panels ...'); end
            this.figure_Layout = uiextras.TabPanel( 'Parent', this.Figure, 'Padding',5, 'TabSize',127,'FontSize',8);
            this.tab_Project.Panel = uiextras.Panel( 'Parent', this.figure_Layout, 'Padding', 5, 'Tag','ProjectDescription');            
            this.tab_DataPrep.Panel = uiextras.Panel( 'Parent', this.figure_Layout, 'Padding', 5, 'Tag','DataPreparation');
            this.tab_ModelConstruction.Panel = uiextras.Panel( 'Parent', this.figure_Layout, 'Padding', 5, 'Tag','ModelConstruction');
            this.tab_ModelCalibration.Panel = uiextras.Panel( 'Parent', this.figure_Layout, 'Padding', 5, 'Tag','ModelCalibration');
            this.tab_ModelSimulation.Panel = uiextras.Panel( 'Parent', this.figure_Layout, 'Padding', 5, 'Tag','ModelSimulation');
            this.figure_Layout.TabNames = {'Project Description', 'Outlier Removal','Model Construction', 'Model Calibration','Model Simulation'};
            this.figure_Layout.SelectedChild = 1;
           
%%          Layout Tab1 - Project description
            %------------------------------------------------------------------
            if noDesktop; disp('Creating GUI project description ...'); end
            % Project title
            hbox1t1 = uiextras.VBoxFlex('Parent', this.tab_Project.Panel,'Padding', 3, 'Spacing', 3);
            uicontrol(hbox1t1,'Style','text','String','Project Title: ','HorizontalAlignment','left', 'Units','normalized');            
            this.tab_Project.project_name = uicontrol(hbox1t1,'Style','edit','HorizontalAlignment','left', 'Units','normalized',...
                'TooltipString','Input a project title. This is an optional input to assist project management.','FontSize',12);            
            
            % Empty row spacer
            uicontrol(hbox1t1,'Style','text','String','','Units','normalized');                      
                        
            % Project description
            uicontrol(hbox1t1,'Style','text','String','Project Description: ','HorizontalAlignment','left', 'Units','normalized');                      
            this.tab_Project.project_description = uicontrol(hbox1t1,'Style','edit','HorizontalAlignment','left', 'Units','normalized', ...
                'Min',1,'Max',100,'TooltipString','Input an extended project description. This is an optional input to assist project management.','FontSize',12);            
            
            % Set sizes
            set(hbox1t1, 'Sizes', [20 20 20 20 -1]);            
            
            

%%          Layout Tab2 - Data Preparation
            % -----------------------------------------------------------------
            if noDesktop; disp('Creating GUI outlier detection panel ...'); end
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
                        '<html><center>Bore Depth<br />(Below surface)</center></html>', ...   
                        '<html><center>Surface<br />Elevation</center></html>', ...   
                        '<html><center>Casing Length<br />(Above surface)</center></html>', ...   
                        '<html><center>Construction<br />Date (dd-mmm-yyyy)</center></html>', ...   
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
            rnames1t2 = {1};
            toolTipStr = ['<html>Optional detection and removal<br>' ...
                  'of erroneous groundwater level observations.</ul>'];
            
            % Initialise data.
            data = {false, '', '',0, 0, 0, '01/01/1900',true, true, true, true, 10, 120, 4, 1,...
                '<html><font color = "#FF0000">Not analysed.</font></html>', ...
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
                'CellSelectionCallback', @this.dataPrep_tableSelection, ...
                'CellEditCallback', @this.dataPrep_tableEdit, ...
                'Tag','Data Preparation', 'TooltipString', toolTipStr);                              
                        
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
            vboxTopOuter = uiextras.VBox('Parent',this.tab_DataPrep.modelOptions.vbox, 'Padding', 0, 'Spacing', 0, ...
                'Visible','on', 'Tag','Data Preparation - options panels');
            vboxTopInner1 = uiextras.VBox('Parent',vboxTopOuter, 'Visible','on');
            uicontrol( 'Parent', vboxTopInner1,'Style','text','String',sprintf('%s\n%s%s','Select the Site ID for the analysis:'), 'Units','normalized');            
            this.tab_DataPrep.modelOptions.boreIDList = uicontrol('Parent',vboxTopInner1,'Style','list','BackgroundColor','w', ...
                'String',dynList(:),'Value',1,'Callback',...
                @this.dataPrep_optionsSelection, 'Units','normalized');              
            
            % Add table. Importantly, this is done using createTable, not
            % uitable. This was required to achieve acceptable perforamnce
            % for large tables.
            vboxTopInner2 = uiextras.VBox('Parent',vboxTopOuter, 'Visible','on');
            this.tab_DataPrep.modelOptions.resultsOptions.table = uitable(vboxTopInner2, ...
                'ColumnName',{'Year', 'Month', 'Day', 'Hour', 'Minute', 'Head', 'Date_Error', 'Duplicate_Date_Error', 'Min_Head_Error','Max_Head_Error','Rate_of_Change_Error','Const_Hear_Error','Outlier_Obs'}, ... 
                'Data',cell(0,13), ...
                'ColumnFormat', {'numeric','numeric','numeric','numeric', 'numeric','numeric','logical','logical','logical','logical','logical','logical','logical'}, ...
                'ColumnEditable', [false(1,6) true(1,7)], ...
                'Tag','Data Preparation - results table', ...
                'CellEditCallback', @this.dataPrep_resultsTableEdit, ...,
                'TooltipString', 'Results data from the bore data analysis for erroneous observations and outliers.');   
                        
            vboxTopInner3 = uiextras.VBox('Parent',vboxTopOuter, 'Visible','on');
            uicontrol( 'Parent', vboxTopInner3,'Style','text','String',sprintf('%s\n%s%s','Bore analysis status:'),'Units','normalized');
            uicontrol('Parent',vboxTopInner3,'Style','text','BackgroundColor','w', 'String','','HorizontalAlignment','left','FontSize',10, 'Units','normalized', 'Tag','Data Preparation - status box');

            % Create vbox for showing a table of results and plotting hydrographs
            vboxLowerOuter = uiextras.VBox('Parent', this.tab_DataPrep.modelOptions.vbox);
            vboxLowerInner1 = uipanel('Parent',vboxLowerOuter,'BackgroundColor',[1 1 1]);
            this.tab_DataPrep.modelOptions.resultsOptions.plots = axes( 'Parent', vboxLowerInner1);

            % Resize the panels            
            set(vbox1t2, 'Sizes', [30 -1]);
            set(vboxTopOuter, 'Sizes',[0 0 0]);
            set(this.tab_DataPrep.modelOptions.vbox, 'Sizes', [0 0]);            
            set(vboxTopInner1, 'Sizes', [30 -1]); 
            set(vboxTopInner3, 'Sizes', [30 -1]); 
            
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
            if noDesktop; disp('Creating GUI figure ...'); end
            % Declare panels        
            if noDesktop; disp('Creating GUI model construction panel...'); end
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
                        '<html><center>Site<br />ID</center></html>', ...   
                        '<html><center>Min. Head<br />Timestep (days)</center></html>', ...   
                        '<html><center>Model<br />Type</center></html>', ...                           
                        '<html><center>Model<br />Options</center></html>', ...                           
                        '<html><center>Build<br />Status</center></html>'};
            cformats1t3 = {'logical', 'char', 'char','char','char','char','numeric',this.modelTypes,'char','char'};
            cedit1t3 = logical([1 1 1 1 1 1 1 1 1 0]);            
            rnames1t3 = {1};
            toolTipStr = 'Define the model label, input data, bore ID, head timestep and model structure for each model.';
            
            
            % Initialise data
            data = cell(1,10);
            data{1,10} = '<html><font color = "#FF0000">Not built.</font></html>';

            % Add table. Importantly, this is done using createTable, not
            % uitable. This was required to achieve acceptable perforamnce
            % for large tables.
            this.tab_ModelConstruction.Table = uitable(vbox1t3,'ColumnName',cnames1t3,'Data',data,  ...
                'ColumnEditable',cedit1t3,'ColumnFormat',cformats1t3,'RowName', rnames1t3, ...
                'CellSelectionCallback', @this.modelConstruction_tableSelection,...
                'CellEditCallback', @this.modelConstruction_tableEdit,...
                'Tag','Model Construction', ...
                'TooltipString', toolTipStr);                        
                        
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
            hbox4t3 = uiextras.HBox('Parent',this.tab_ModelConstruction.modelOptions.vbox, 'Padding', 3, 'Spacing', 3, 'Visible','on');
            buttons_boreID = uiextras.VButtonBox('Parent',hbox4t3 ,'Padding', 3, 'Spacing', 3);
            uicontrol('Parent',buttons_boreID,'String','<','FontSize',14,'FontWeight','bold', 'ForegroundColor',[0.07, 0.62 1], ...
                'Callback', @this.modelConstruction_optionsSelection, 'TooltipString','Copy the Site IDs to current model.','Tag','current');
            uicontrol('Parent',buttons_boreID,'String','<<','FontSize',14,'FontWeight','bold', 'ForegroundColor',[0.07, 0.62 1], ...
                'Callback', @this.modelConstruction_optionsSelection, 'TooltipString','Copy the Site IDs to all selected models.','Tag','selected');            
            vbox4t3 = uiextras.VBox('Parent',hbox4t3 , 'Padding', 3, 'Spacing', 3, 'Visible','on');
            uicontrol( 'Parent', vbox4t3,'Style','text','String',sprintf('%s\n%s%s','Please select the Site ID(s) for the model:'), 'Units','normalized');            
            this.tab_ModelConstruction.boreIDList = uicontrol('Parent',vbox4t3,'Style','list','BackgroundColor','w', ...
                'String',dynList(:),'Value',1, 'Units','normalized', 'min',0,'max',2,'Tag','Model Construction - bore ID list', ...
                'Callback', @this.modelConstruction_onBoreListSelection);                         
            this.tab_ModelConstruction.boreID_panel = uipanel('Parent',vbox4t3, 'BackgroundColor','w', 'Tag','Model Construction - bore ID plots panel'); 
            set(hbox4t3, 'Sizes', [40 -1 ]);
            
            % Add model options panel for decriptions of each model type
            vbox5t3 = uiextras.VBox('Parent',this.tab_ModelConstruction.modelOptions.vbox, 'Padding', 3, 'Spacing', 3, 'Visible','on');
            uicontrol( 'Parent', vbox5t3,'Style','text','String',sprintf('%s\n%s%s','Below is a decsription of the selected model type:'), 'Units','normalized');            
            this.tab_ModelConstruction.modelDescriptions = uicontrol( 'Parent', vbox5t3,'Style','text','String','(No model type selected.)', 'HorizontalAlignment','left','Units','normalized');                        
            set(vbox5t3, 'Sizes', [30 -1]);
            
            % Resize the panels
            set(vbox1t3, 'Sizes', [30 -1]);
            set(hbox1t3, 'Sizes', [-2 -1]);
            set(vbox4t3, 'Sizes', [30 -1 -1]);            
            
            % Build model options for each model type                
            includeModelOption = false(length(this.modelTypes),1);
            for i=1:length(this.modelTypes)
                switch this.modelTypes{i}
                    case 'model_TFN'
                        this.tab_ModelConstruction.modelTypes.(this.modelTypes{i}).hbox = uiextras.HBox('Parent',this.tab_ModelConstruction.modelOptions.vbox,'Padding', 3, 'Spacing', 3);
                        this.tab_ModelConstruction.modelTypes.(this.modelTypes{i}).buttons = uiextras.VButtonBox('Parent',this.tab_ModelConstruction.modelTypes.(this.modelTypes{i}).hbox,'Padding', 3, 'Spacing', 3);
                        uicontrol('Parent',this.tab_ModelConstruction.modelTypes.(this.modelTypes{i}).buttons,'String','<','FontSize',14,'FontWeight','bold', 'ForegroundColor',[0.07, 0.62 1], ...
                            'Callback', @this.onApplyModelOptions, 'TooltipString','Copy model options to current model.');
                        uicontrol('Parent',this.tab_ModelConstruction.modelTypes.(this.modelTypes{i}).buttons,'String','<<','FontSize',14,'FontWeight','bold', 'ForegroundColor',[0.07, 0.62 1], ...
                            'Callback', @this.onApplyModelOptions_selectedBores, 'TooltipString','Copy model options to selected models (of the current model type).');
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
                        h = warndlg({['The following model type is not integrated into the user interface: ', this.modelTypes{i}], ...
                            '', 'It could not be included in the user interface.'},'Model type unavailable ...');
                        setIcon(this, h);
                        includeModelOption(i) = false;
                end                
            end
            
            % Redefine model options to include only those that are
            % established in the user interface.
            this.tab_ModelConstruction.Table.ColumnFormat{8} = this.modelTypes(includeModelOption);
            
            % Add model options panel for model construction status.
            vbox6t3 = uiextras.VBox('Parent',this.tab_ModelConstruction.modelOptions.vbox, 'Padding', 3, 'Spacing', 3, 'Visible','on');
            uicontrol( 'Parent', vbox6t3,'Style','text','String',sprintf('%s\n%s%s','Model build status:'),'Units','normalized');
            uicontrol('Parent',vbox6t3,'Style','edit','BackgroundColor','w', 'String','','HorizontalAlignment','left','FontSize',10, 'Units','normalized', ...
                'Tag','Model Construction - status box','Max',100, 'Enable','inactive');
            set(vbox6t3, 'Sizes', [30 -1]);
            
            % Hide all modle option vboxes 
            this.tab_ModelConstruction.modelOptions.vbox.Heights = zeros(size(this.tab_ModelConstruction.modelOptions.vbox.Heights));

            % Add context menu
            %-----------------------------------
            % Create menu
            this.Figure.UIContextMenu = uicontextmenu(this.Figure,'Visible','off');
            
            % Add items
            uimenu(this.Figure.UIContextMenu,'Label','Copy selected row','Callback',@this.rowAddDelete);
            uimenu(this.Figure.UIContextMenu,'Label','Paste rows','Callback',@this.rowAddDelete,'Separator','on');
            uimenu(this.Figure.UIContextMenu,'Label','Insert row above selection','Callback',@this.rowAddDelete);
            uimenu(this.Figure.UIContextMenu,'Label','Insert row below selection','Callback',@this.rowAddDelete);            
            uimenu(this.Figure.UIContextMenu,'Label','Delete selected rows','Callback',@this.rowAddDelete);
            uimenu(this.Figure.UIContextMenu,'Label','Select all','Callback',@this.rowSelection,'Separator','on');
            uimenu(this.Figure.UIContextMenu,'Label','Select none','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Invert selection','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Select row range ...','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Select by col. value ...','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Select by col. value ...','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Copy selected model labels','Callback',@this.rowSelection,'Separator','on');
            uimenu(this.Figure.UIContextMenu,'Label','Select copied model labels','Callback',@this.rowSelection);            
                        
            % Attach menu to the construction table
            set(this.tab_ModelConstruction.Table,'UIContextMenu',this.Figure.UIContextMenu);
                        
            % Add table name to .UserData
            set(this.tab_ModelConstruction.Table.UIContextMenu,'UserData','this.tab_ModelConstruction.Table');
            
            
%%          Layout Tab4 - Calibrate models
            %------------------------------------------------------------------
            if noDesktop; disp('Creating GUI calibration panel ...'); end
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
            rnames1t4 = {1};
            cedit1t4 = logical([1 0 0 0 0 1 1 1 0 0 0 0 0]);            
            %cformats1t4 = {'logical', 'char', 'char','char','char','char','char', {'SP-UCI' 'CMA-ES' 'DREAM' 'Multi-model'},'char','char','char','char','char'};
            cformats1t4 = {'logical', 'char', 'char','char','char','char','char', {'SP-UCI' 'CMA-ES' 'DREAM' },'char','char','char','char','char'};
      
            toolTipStr = 'Calibration of models that have been successfully built.';              
            
            % Add table. Importantly, this is done using createTable, not
            % uitable. This was required to achieve acceptable perforamnce
            % for large tables.
            this.tab_ModelCalibration.resultsOptions.currentTab = [];
            this.tab_ModelCalibration.resultsOptions.currentPlot = [];                                 
            this.tab_ModelCalibration.Table = uitable(vbox1t4,'ColumnName',cnames1t4,'Data',data,  ...
                'ColumnFormat', cformats1t4, 'ColumnEditable', cedit1t4, ...
                'RowName', rnames1t4, 'Tag','Model Calibration', ...
                'CellSelectionCallback', @this.modelCalibration_tableSelection,...
                'TooltipString', toolTipStr, ...
                'Interruptible','off');                            
            
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
            this.tab_ModelCalibration.resultsTabs = uiextras.TabPanel( 'Parent',resultsvbox, 'Padding', 5, 'TabSize',120,'FontSize',8);
            this.tab_ModelCalibration.resultsOptions.statusPanel = uiextras.Panel( 'Parent', this.tab_ModelCalibration.resultsTabs, 'Padding', 5, ...
                'Tag','CalibrationStatusTab');            
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
            this.tab_ModelCalibration.resultsTabs.TabNames = {'Calib. Status','Calib. Results','Forcing Data','Parameters', ...
                'Derived Parameters','Model Specifics'};
            this.tab_ModelCalibration.resultsTabs.SelectedChild = 1;
            this.tab_ModelCalibration.resultsTabs.TabEnables = {'off','off','off','off','off','off'};
                        
            % Build calibration status tab            
            resultsvbox = uiextras.VBoxFlex('Parent',this.tab_ModelCalibration.resultsOptions.statusPanel, 'Padding', 3, ...
                'Spacing', 3, 'Visible','on','Tag','Model Calibration - status box');            
            uicontrol('Parent',resultsvbox,'Style','edit','BackgroundColor','w', 'String','','HorizontalAlignment','left','FontSize',10, 'Units','normalized', ...
                'Tag','Model Calibration - status text box', 'Enable','inactive','Max',100);
            uipanel('Parent',resultsvbox, 'Tag','Model calibration - status plots panel');
            set(resultsvbox, 'Sizes', [-1 0]);

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
            uicontrol(resultsvboxDropDown,'Style','text','String','Plot type:','HorizontalAlignment','left' );
            uicontrol(resultsvboxDropDown,'Style','popupmenu', ...
                'String',{  'Time-series of heads', ...
                            'Time-series of residuals', ...
                            'Histogram of calib. residuals', ...
                            'Histogram of eval. residuals', ...
                            'Quantile-quantile of calib. residuals', ...
                            'Quantile-quantile of eval. residuals', ...
                            'Obs. Head vs Modelled head', ...
                            'Obs. Head vs residuals', ...
                            'Variogram of residuals', ...
                            '(none)'}, ...
                'Tag','Model Calibration - results plot dropdown', ...
                'Value',1,'Callback', @this.modelCalibration_onUpdatePlotSetting);   
            uicontrol(resultsvboxDropDown,'String','<','FontSize',14,'FontWeight','bold', 'ForegroundColor',[0.07, 0.62 1], ...
                'Callback', @this.onNextPlot, 'Tag','Model Calibration - previous results plot', 'TooltipString', 'Previous plot');
            uicontrol(resultsvboxDropDown,'String','>','FontSize',14,'FontWeight','bold', 'ForegroundColor',[0.07, 0.62 1], ...
                'Callback', @this.onNextPlot, 'Tag','Model Calibration - next results plot', 'TooltipString', 'Next plot');
            set(resultsvboxDropDown, 'ColumnSizes', [75,-1,30,30]);
            set(resultsvboxTable, 'ColumnSizes', -1, 'RowSizes', [-1 30] );
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
                'Note, all time-scales >daily are reported as daily mean.'],'HorizontalAlignment','right', ...
                'Tag','Forcing plot calc timestep');    
            uicontrol(resultsvboxOptions,'Style','text','String','Time step metric:','HorizontalAlignment','left' );
            uicontrol(resultsvboxOptions,'Style','popupmenu', ...
                'String',{'sum','mean','st. dev.','variance','skew','min','5th %ile','10th %ile','25th %ile','50th %ile','75th %ile','90th %ile','95th %ile', 'max', ...
                'inter-quantile range', 'No. zero days', 'No. <0 days', 'No. >0 days'}, ...
                'Value',1, 'Callback', @this.modelCalibration_onUpdateForcingData, ...
                'TooltipString', ['<html>Select calculation to apply when aggregating the daily data.  <br>', ...
                'Note, all plots will use the resulting data.'],'HorizontalAlignment','right','Tag','Forcing plot calc type');    

            uicontrol(resultsvboxOptions,'Style','text','String','Start date:','HorizontalAlignment','left');
            uicontrol(resultsvboxOptions,'Style','edit','String','01/01/0001','TooltipString','Filter the data and plot to that above a data (as dd/mm/yyyy).', ...
                'Tag','Forcing plot calc start date', ...
                'Callback', @this.modelCalibration_onUpdateForcingData );

            uicontrol(resultsvboxOptions,'Style','text','String','End date:','HorizontalAlignment','left');
            uicontrol(resultsvboxOptions,'Style','edit','String','31/12/9999','TooltipString','Filter the data and plot to that below a data (as dd/mm/yyyy).', ...
                'Tag','Forcing plot calc end date', ...
                'Callback', @this.modelCalibration_onUpdateForcingData );
                   
            set(resultsvboxOptions, 'ColumnSizes', [-1 -1 -1.5 -1 -1 -1 -1 -1], 'RowSizes', 25 );
            
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
                'box-plot (monthly metric)','box-plot (quarterly metric)','box-plot (annual metric)'}, 'Value',1,'HorizontalAlignment','right', ...
                'Callback',@this.modelCalibration_onUpdateForcingPlotType,'Tag','Forcing plot type');    
            uicontrol(resultsvboxOptions,'Style','text','String','x-axis:' );
            uicontrol(resultsvboxOptions,'Style','popupmenu', 'String',{'(none)', 'Date'}, 'Value',2,'HorizontalAlignment','right','Tag','Forcing plot x-axis');    
            uicontrol(resultsvboxOptions,'Style','text','String',char(247), 'FontSize',14);
            uicontrol(resultsvboxOptions,'Style','popupmenu', 'String',{'(none)', 'Date'}, 'Value',1,'HorizontalAlignment','right','Tag','Forcing plot x-axis denom');    
            uicontrol(resultsvboxOptions,'Style','text','String','y-axis:' );
            uicontrol(resultsvboxOptions,'Style','popupmenu', 'String',{'(none)', 'Date'}, 'Value',2,'HorizontalAlignment','right','Tag','Forcing plot y-axis');                
            uicontrol(resultsvboxOptions,'Style','text','String',char(247), 'FontSize',14);
            uicontrol(resultsvboxOptions,'Style','popupmenu', 'String',{'(none)', 'Date'}, 'Value',1,'HorizontalAlignment','right','Tag','Forcing plot y-axis denom');                
            uicontrol(resultsvboxOptions,'Style','pushbutton','String','Build plot','Callback', @this.modelCalibration_onUpdateForcingPlot, ...
                'Tag','Model Calibration - forcing plot', 'TooltipString', 'Build the forcing plot.','ForegroundColor','blue', 'Tag','Forcing plot build plot');            
            set(resultsvboxOptions, 'ColumnSizes', [-1 -2 -1 -2 10 -2 -1 -2 10 -2 -2], 'RowSizes', 25 );           
            
            uiextras.Panel('Parent', resultsvbox,'BackgroundColor',[1 1 1], 'Tag','Model Calibration - forcing plot panel');             
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
            uimenu(this.Figure.UIContextMenu,'Label','Paste rows','Callback',@this.rowAddDelete);
            uimenu(this.Figure.UIContextMenu,'Label','Select all','Callback',@this.rowSelection,'Separator','on');
            uimenu(this.Figure.UIContextMenu,'Label','Select none','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Invert selection','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Select row range ...','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Select by col. value ...','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Copy selected model labels','Callback',@this.rowSelection,'Separator','on');
            uimenu(this.Figure.UIContextMenu,'Label','Select copied model labels','Callback',@this.rowSelection);
            
            % Attach menu to the construction table
            set(this.tab_ModelCalibration.Table,'UIContextMenu',this.Figure.UIContextMenu);
                        
            % Add table name to .UserData
            set(this.tab_ModelCalibration.Table.UIContextMenu,'UserData','this.tab_ModelCalibration.Table');

            

%%          Layout Tab5 - Model Simulation
            %------------------------------------------------------------------            
            if noDesktop; disp('Creating GUI simulation panel ...'); end
            hbox1t5 = uiextras.HBoxFlex('Parent', this.tab_ModelSimulation.Panel,'Padding', 3, 'Spacing', 3, 'Tag','Model Simulation outer hbox');
            vbox1t5 = uiextras.VBox('Parent',hbox1t5,'Padding', 3, 'Spacing', 3);
            %vbox2t5 = uiextras.VBox('Parent',hbox1t5,'Padding', 3, 'Spacing', 3);
            hbox1t6 = uiextras.HBox('Parent',vbox1t5,'Padding', 3, 'Spacing', 3);
            hboxBtn1 = uiextras.HButtonBox('Parent',hbox1t6 ,'Padding', 3, 'Spacing', 3);             
            hboxBtn2 = uiextras.HButtonBox('Parent',hbox1t6 ,'Padding', 3, 'Spacing', 3);                 
            
                        
            % Add button for simulation
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
                            '<html><center>Simulation<br />Time Step</center></html>', ...                            
                            '<html><center>Krig<br />Sim. Residuals?</center></html>', ... 
                            '<html><center>Simulation<br />Status</center></html>'};
            data = cell(1,12);            
            rnames1t5 = {1};
            cedit1t5 = logical([1 1 0 0 0 1 1 1 1 1 1 0]);            
            cformats1t5 = {'logical', {'(none calibrated)'}', 'char','char','char','char','char','char', 'char',{'Daily' 'Weekly' 'Monthly' 'Yearly'}, 'logical','char' };
            toolTipStr = 'Run simulations of calibrated models';
              
            this.tab_ModelSimulation.Table = uitable(vbox1t5, ...
                'ColumnName', cnames1t5, 'Data', data, ...
                'ColumnFormat', cformats1t5, 'ColumnEditable', cedit1t5, ...
                'RowName', rnames1t5, 'Tag','Model Simulation', ...
                'CellSelectionCallback', @this.modelSimulation_tableSelection,...
                'CellEditCallback', @this.modelSimulation_tableEdit,...
                'TooltipString', toolTipStr);            
                                 
            % Create vbox for the various model options            
            resultsvbox = uiextras.VBoxFlex('Parent',hbox1t5,'Padding', 3, 'Spacing', 3, 'DividerMarkings','off');
                        
            % Add tabs for various types of results            
            this.tab_ModelSimulation.resultsTabs = uiextras.TabPanel( 'Parent',resultsvbox, 'Padding', 5, 'TabSize',100,'FontSize',8);
            this.tab_ModelSimulation.resultsOptions.statusPanel = uiextras.Panel( 'Parent', this.tab_ModelSimulation.resultsTabs, 'Padding', 5, ...
                'Tag','SimulationStatusTab');
            this.tab_ModelSimulation.resultsOptions.simPanel = uiextras.Panel( 'Parent', this.tab_ModelSimulation.resultsTabs, 'Padding', 5, ...
                'Tag','SimulationResultsTab');            
            this.tab_ModelSimulation.resultsOptions.forcingPanel = uiextras.Panel( 'Parent', this.tab_ModelSimulation.resultsTabs, 'Padding', 5, ...
                'Tag','ForcingDataTab');                              
            this.tab_ModelSimulation.resultsTabs.TabNames = {'Simulation Status','Simulated Heads','Forcing Data'};
            this.tab_ModelSimulation.resultsTabs.SelectedChild = 1;
            this.tab_ModelSimulation.resultsTabs.TabEnables = {'off','off','off'};

            % Build simulation status tab
            resultsvbox = uiextras.VBoxFlex('Parent',this.tab_ModelSimulation.resultsOptions.statusPanel, 'Padding', 3, 'Spacing', 3, 'Visible','on');
            uicontrol('Parent',resultsvbox,'Style','edit','BackgroundColor','w', 'String','','HorizontalAlignment','left','FontSize',10, 'Units','normalized', ...
                'Tag','Model Simulation - status box','Max',100,'Enable','inactive');
                        
            % Build simulation results tab            
            resultsvbox= uiextras.VBoxFlex('Parent', this.tab_ModelSimulation.resultsOptions.simPanel,'Padding', 3, 'Spacing', 3);
            resultsvboxTable = uiextras.Grid('Parent', resultsvbox ,'Padding', 3, 'Spacing', 3);            
            tbl = uitable(resultsvboxTable , 'ColumnName',{'Year','Month', 'Day', 'Mod. Head','Noise Lower','Noise Upper'}, ... 
                'Data',cell(0,6), 'ColumnFormat', {'numeric','numeric','numeric','numeric', 'numeric','numeric','numeric'}, ...
                'ColumnEditable', true(1,6), 'Tag','Model Simulation - results table', ...
                'TooltipString','Table shows the simulation results.');   

            % Build simulation results table contect menu
            contextMenu = uicontextmenu(this.Figure,'Visible','on');
            uimenu(contextMenu,'Label','Export table data ...','Tag','Model Simulation - results table export', 'Callback',@this.onExportResults);                 
            set(tbl,'UIContextMenu',contextMenu);
            set(tbl.UIContextMenu,'UserData','Model Simulation - results table');
            
            resultsvboxDropDown = uiextras.Grid('Parent', resultsvboxTable ,'Padding', 3, 'Spacing', 3);            
            uicontrol(resultsvboxDropDown,'Style','text','String','Plot type:','HorizontalAlignment','left' );
            uicontrol(resultsvboxDropDown,'Style','popupmenu', ...
                'String',{  'Simulated Heads', '(none)'}, ...
                'Value',1,'Callback', @this.modelSimulation_onUpdatePlotSetting, ...
                'Tag','Model Simulation - results plot dropdown');                                                
            set(resultsvboxTable, 'ColumnSizes', -1, 'RowSizes', [-1 25] );

            uicontrol('Parent',resultsvboxDropDown,'String','<','FontSize',14,'FontWeight','bold', 'ForegroundColor',[0.07, 0.62 1], ...
                'Callback', @this.onNextPlot, 'Tag','Model Simulation - previous results plot', 'TooltipString', 'Previous plot');
            uicontrol('Parent',resultsvboxDropDown,'String','>','FontSize',14,'FontWeight','bold', 'ForegroundColor',[0.07, 0.62 1], ...
                'Callback', @this.onNextPlot, 'Tag','Model Simulation - next results plot', 'TooltipString', 'Next plot');  
            set(resultsvboxDropDown, 'ColumnSizes', [75,-1,30,30]);

            uiextras.Panel('Parent', resultsvbox,'BackgroundColor',[1 1 1], ...
                'Tag','Model Simulation - results plot');  
            set(resultsvbox, 'Sizes', [-1 -1]);
            
            % Building forcing data
            resultsvbox= uiextras.VBoxFlex('Parent', this.tab_ModelSimulation.resultsOptions.forcingPanel,'Padding', 3, 'Spacing', 3);
            resultsvboxOptions = uiextras.Grid('Parent', resultsvbox,'Padding', 3, 'Spacing', 3);
            uicontrol(resultsvboxOptions,'Style','text','String','Time step:','HorizontalAlignment','left' );
            uicontrol(resultsvboxOptions,'Style','popupmenu', 'String',{'daily','weekly','monthly','quarterly','annual','full-record'}, ...
                'Value',1, 'Callback', @this.modelSimulation_onUpdateForcingData, ...
                'TooltipString', ['<html>Select the time-scale for presentation of the forcing data.  <br>', ...
                'Note, all time-scales >daily are reported as daily mean.'],'HorizontalAlignment','right', ...
                'Tag','Forcing plot calc timestep');
            uicontrol(resultsvboxOptions,'Style','text','String','Time step metric:','HorizontalAlignment','left' );
            uicontrol(resultsvboxOptions,'Style','popupmenu', ...
                'String',{'sum','mean','st. dev.','variance','skew','min','5th %ile','10th %ile','25th %ile','50th %ile','75th %ile','90th %ile','95th %ile', 'max', ...
                'inter-quantile range', 'No. zero days', 'No. <0 days', 'No. >0 days'}, ...
                'Value',1, 'Callback', @this.modelSimulation_onUpdateForcingData, ...
                'TooltipString', ['<html>Select calculation to apply when aggregating the daily data.  <br>', ...
                'Note, all plots will use the resulting data.'],'HorizontalAlignment','right', 'Tag','Forcing plot calc type');    

            uicontrol(resultsvboxOptions,'Style','text','String','Start date:','HorizontalAlignment','left');
            uicontrol(resultsvboxOptions,'Style','edit','String','01/01/0001','TooltipString','Filter the data and plot to that above a data (as dd/mm/yyyy).', ...
                'Tag','Forcing plot calc start date', ...
                'Callback', @this.modelSimulation_onUpdateForcingData );

            uicontrol(resultsvboxOptions,'Style','text','String','End date:','HorizontalAlignment','left');
            uicontrol(resultsvboxOptions,'Style','edit','String','31/12/9999','TooltipString','Filter the data and plot to that below a data (as dd/mm/yyyy).', ...
                'Tag','Forcing plot calc end date', ...
                'Callback', @this.modelSimulation_onUpdateForcingData );
                   
            set(resultsvboxOptions, 'ColumnSizes', [-1 -1 -1.5 -1 -1 -1 -1 -1], 'RowSizes', 25 );
            
            tbl = uitable(resultsvbox, 'ColumnName',{'Year','Month', 'Day'}, ... 
                'Data',cell(0,3), 'ColumnFormat', {'numeric','numeric','numeric'}, ...
                'ColumnEditable', true(1,3), 'Tag','Model Simulation - forcing table', ...
                'TooltipString',['<html>This table allows exploration of the forcing data used for the simulation <br>', ... 
                     '& evaluation and forcing data derived from the model (e.g. from a soil moisture <br>', ... 
                     'transformation model). Use the table to explore forcing dynamics at a range of time-steps.']);  
            contextMenu = uicontextmenu(this.Figure,'Visible','on');
            uimenu(contextMenu,'Label','Export table data ...','Tag','Model Simulation - forcing table export', 'Callback',@this.onExportResults);                 
            set(tbl,'UIContextMenu',contextMenu);
            set(tbl.UIContextMenu,'UserData','Model Simulation - forcing table');
                 
                 
            resultsvboxOptions = uiextras.Grid('Parent', resultsvbox,'Padding', 3, 'Spacing', 3);
            uicontrol(resultsvboxOptions,'Style','text','String','Plot type:' );
            uicontrol(resultsvboxOptions,'Style','popupmenu', 'String',{'line','scatter','bar','histogram','cdf','box-plot (daily metric)', ...
                'box-plot (monthly metric)','box-plot (quarterly metric)','box-plot (annual metric)'}, 'Value',1,'HorizontalAlignment','right', ...
                'Callback',@this.modelSimulation_onUpdateForcingPlotType, 'Tag','Forcing plot type');    
            uicontrol(resultsvboxOptions,'Style','text','String','x-axis:' );
            uicontrol(resultsvboxOptions,'Style','popupmenu', 'String',{'(none)', 'Date'}, 'Value',2,'HorizontalAlignment','right','Tag','Forcing plot x-axis');    
            uicontrol(resultsvboxOptions,'Style','text','String',char(247), 'FontSize',14);
            uicontrol(resultsvboxOptions,'Style','popupmenu', 'String',{'(none)', 'Date'}, 'Value',1,'HorizontalAlignment','right','Tag','Forcing plot x-axis denom');
            uicontrol(resultsvboxOptions,'Style','text','String','y-axis:' );
            uicontrol(resultsvboxOptions,'Style','popupmenu', 'String',{'(none)', 'Date'}, 'Value',2,'HorizontalAlignment','right','Tag','Forcing plot y-axis');       
            uicontrol(resultsvboxOptions,'Style','text','String',char(247), 'FontSize',14);
            uicontrol(resultsvboxOptions,'Style','popupmenu', 'String',{'(none)', 'Date'}, 'Value',1,'HorizontalAlignment','right','Tag','Forcing plot y-axis denom');                
            uicontrol(resultsvboxOptions,'Style','pushbutton','String','Build plot','Callback', @this.modelSimulation_onUpdateForcingPlot, ...
                'Tag','Model Calibration - forcing plot', 'TooltipString', 'Build the forcing plot.','ForegroundColor','blue');            
            set(resultsvboxOptions, 'ColumnSizes', [-1 -2 -1 -2 10 -2 -1 -2 10 -2 -2], 'RowSizes', 25 );          
            
            uiextras.Panel('Parent', resultsvbox,'BackgroundColor',[1 1 1], 'Tag','Model Simulation - forcing plot panel' );             
            set(resultsvbox, 'Sizes', [30 -1 30 -1]);
            
            % set selected tab and plot to 
            this.tab_ModelSimulation.resultsOptions.currentTab = 1;
            this.tab_ModelSimulation.resultsOptions.currentPlot = 7;
            
            % Set box sizes
            set(hbox1t5, 'Sizes', [-2 -1]);
            set(vbox1t5, 'Sizes', [30 -1]);
            %set(vbox2t5, 'Sizes', [30 20 0 0]);
                        
%           Add context menu
            this.Figure.UIContextMenu = uicontextmenu(this.Figure,'Visible','off');
            uimenu(this.Figure.UIContextMenu,'Label','Copy selected row','Callback',@this.rowAddDelete);
            uimenu(this.Figure.UIContextMenu,'Label','Paste rows','Callback',@this.rowAddDelete,'Separator','on');
            uimenu(this.Figure.UIContextMenu,'Label','Insert row above selection','Callback',@this.rowAddDelete);
            uimenu(this.Figure.UIContextMenu,'Label','Insert row below selection','Callback',@this.rowAddDelete);            
            uimenu(this.Figure.UIContextMenu,'Label','Delete selected rows','Callback',@this.rowAddDelete);
            uimenu(this.Figure.UIContextMenu,'Label','Select all','Callback',@this.rowSelection,'Separator','on');
            uimenu(this.Figure.UIContextMenu,'Label','Select none','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Invert selection','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Select row range ...','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Select by col. value ...','Callback',@this.rowSelection);
            uimenu(this.Figure.UIContextMenu,'Label','Copy selected model labels','Callback',@this.rowSelection,'Separator','on');
            uimenu(this.Figure.UIContextMenu,'Label','Select copied model labels','Callback',@this.rowSelection);
            
            % Attach menu to the construction table
            set(this.tab_ModelSimulation.Table,'UIContextMenu',this.Figure.UIContextMenu);
                        
            % Add table name to .UserData
            set(this.tab_ModelSimulation.Table.UIContextMenu,'UserData','this.tab_ModelSimulation.Table');
            
%%          Initialise indexes for selected row and colum  from each table
            this.tab_DataPrep.currentRow = [];
            this.tab_DataPrep.currentCol = [];
            this.tab_ModelConstruction.currentRow = [];
            this.tab_ModelConstruction.currentCol = [];                        
            this.tab_ModelCalibration.currentRow = [];
            this.tab_ModelCalibration.currentCol = [];            
            this.tab_ModelSimulation.currentRow = [];
            this.tab_ModelSimulation.currentCol = [];
            
%%          Store this.models on HDD
            %----------------------------------------------------
            this.modelsOnHDD = '';
            this.models = [];
            
%%          Close the splash window and show the app
            %----------------------------------------------------                    
            this.figure_Layout.Selection = 1;
            set(this.Figure,'Visible','on');
            if (~ispc && ~noDesktop) && (~isdeployed || ~ispc) 
               delete(splashObj);
            end         
            if noDesktop; disp('Finished creating GUI figure.'); end
        end

        % Show show plotting icons
        function plotToolbarState(this,iconState)
            % Check if version is 2018b or later. From this point the
            % plot toolbar buttons moved into the plot.
            % Check if version is 2018b or later. From this point the
            % plot toolbar buttons moved into the plot.
            v=version();
            ind = strfind(v,'.');
            v_major = str2double(v(1:(ind(1)-1)));
            v_minor = str2double(v((ind(1)+1):(ind(2)-1)));
            isBefore2018b = v_major<10 & v_minor<5; %ie is version <9.5;           

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
        function onSetProjectFolder(this,~,~)
            
            % Get project folder
            if isempty(this.project_fileName)
                projectPath = uigetdir('Select project folder.');    
            else
                % Get project folder and file name (if a dir)
                if isfolder(this.project_fileName)
                    projectPath = this.project_fileName;
                else
                    projectPath = fileparts(this.project_fileName);
                end
                                
                if isempty(projectPath)
                    projectPath = uigetdir('Select project folder.'); 
                else
                    projectPath = uigetdir(projectPath, 'Select project folder.'); 
                end
                
            end

            if projectPath~=0

                % Get the current project folder. If the project folder has
                % changed then warn the user that all infput file names
                % must be within the new project folder.
                if ~isempty(this.project_fileName)
                    currentProjectFolder = fileparts(this.project_fileName);
                    
                    if ~strcmp(currentProjectFolder, projectPath)
                        h = warndlg({'The project folder is different to that already set.';''; ...
                                 'Importantly, all file names in the project are relative'; ...
                                 'to the project folder and so all input .csv files must be'; ...
                                 'within the project folder or a sub-folder within it.'},'Invalid file name','modal');
                        setIcon(this, h);
                    end
                end
                
                % Update project folder
                this.project_fileName = projectPath;
                                
                % Update GUI title
                set(this.Figure,'Name',['HydroSight - ', this.project_fileName]);
                drawnow update;
            end 

            % Change cursor
            set(this.Figure, 'pointer', 'arrow');
            drawnow update;
            
        end
            
        function onMoveModels(this,~,~)
            
            % The project must be saved to a file. Check the project file
            % is defined.
            if isempty(this.project_fileName) || isfolder(this.project_fileName)
                h = warndlg({'The project must first be saved to a file.';'Please first save the project.'}, 'Project not saved');
                setIcon(this, h);
                return
            end
               
            % Tell the user what is going to be done.
            if ~isempty(this.modelsOnHDD)
                response = questdlg_timer(this.figure_icon,15,{'Moving the models to the RAM will shift all built, calibrated and '; ...
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
                response = questdlg_timer(this.figure_icon,15,{'Moving the models to the HDD will shift all built, calibrated and '; ...
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
                           
             if isempty(response) || ~strcmp(response,'OK')
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
                     modelonHDD_labels = fieldnames(this.models);
                     nModels = length(modelonHDD_labels);
                     for i=1:nModels
                        tmpModels.(modelonHDD_labels{i}) = getModel(this, modelonHDD_labels{i});
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
                                   
                     h = msgbox('Models were successfully moved to the RAM.','Model relocated','help');
                     setIcon(this, h);
                     
                 catch
                     this.modelsOnHDD = modelsOnHDD_orig;
                     h = msgbox({'Models relocation failed!','','Check access to the project file and RAM availability.'},'Relcation failed.','error');
                     setIcon(this, h);
                 end
             else               % Move models to HDD
                try 
                    
                    % Get the folder for the project files
                    folderName = uigetdir(fileparts(this.project_fileName) ,'Select folder for the model files.');    
                    if isempty(folderName) || (isnumeric(folderName) && folderName==0)
                        return;
                    end                                                                                               
                    
                    % Check models are to go into a subfolder.
                    if ~contains(folderName ,fileparts(this.project_fileName))
                        h = msgbox({'The models must be offloaded to a sub-folder of the project.','','Create a new folder within the project folder.'},'Relcation failed.','error');
                        setIcon(this, h);

                        this.modelsOnHDD = modelsOnHDD_orig;
                        
                        % Change cursor
                        set(this.Figure, 'pointer', 'arrow');
                        drawnow update;   
                        
                        return
                    end

                    % remove project folder from file paths
                    folderName = strrep(folderName ,fileparts(this.project_fileName),'');
                    
                    % Store sub-folder to models in project
                    this.modelsOnHDD = folderName;
                    
                    % Move models to HDD
                    modelonHDD_labels = fieldnames(this.models);
                    nModels = length(modelonHDD_labels);
                    for i=1:nModels
                        model = this.models.(modelonHDD_labels{i});
                        setModel( this, modelonHDD_labels{i}, model);
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
                    
                    h = msgbox('Models were successfully moved to the hard-drive.','Model relocated','help');
                    setIcon(this, h);
                catch
                    this.modelsOnHDD = modelsOnHDD_orig;
                    h = msgbox({'Models relocation failed!','','Check access to the project file and RAM availability.'},'Relcation failed.','error');
                    setIcon(this, h);
                end
             end
             
             % Change cursor
             set(this.Figure, 'pointer', 'arrow');                
             drawnow update;               
        end
        
        % Open saved model
        function onNew(this,~,~)

            % Check if all of the GUI tables are empty. If not, warn the
            % user the opening the example will delete the existing data.
            if ~isempty(this.tab_Project.project_name.String) || ...
            ~isempty(this.tab_Project.project_description.String) || ...
            (size(this.tab_ModelConstruction.Table.Data,1)~=0 && any(~any(cellfun( @(x) isempty(x), this.tab_ModelConstruction.Table.Data(:,1:9))))) || ...
            (size(this.tab_ModelCalibration.Table.Data,1)~=0 && any(~any(cellfun( @(x) isempty(x), this.tab_ModelCalibration.Table.Data)))) || ...
            (size(this.tab_ModelSimulation.Table.Data,1)~=0 && any(~any(cellfun( @(x) isempty(x), this.tab_ModelSimulation.Table.Data))))

                response = questdlg_timer(this.figure_icon,15,{'Started a new project will close the current project.','','Do you want to continue?'}, ...
                 'Close the current project?','Yes','No','No');
             
                if isempty(response) || strcmp(response,'No')
                    set(this.Figure, 'pointer', 'arrow');
                    return;
                end
            end              
            
            % Initialise whole GUI and variables
            set(this.Figure, 'pointer', 'watch');
            initialiseGUI(this);

            set(this.Figure, 'pointer', 'arrow');
            drawnow update;                               
        end
        
        % Open saved model
        function onOpen(this,~,~)
            
            % Check if all of the GUI tables are empty. If not, warn the
            % user the opening the example will delete the existing data.
            if ~isempty(this.tab_Project.project_name.String) || ...
            ~isempty(this.tab_Project.project_description.String) || ...
            (size(this.tab_ModelConstruction.Table.Data,1)~=0 && any(~any(cellfun( @(x) isempty(x), this.tab_ModelConstruction.Table.Data(:,1:9))))) || ...
            (size(this.tab_ModelCalibration.Table.Data,1)~=0 && any(~any(cellfun( @(x) isempty(x), this.tab_ModelCalibration.Table.Data)))) || ...
            (size(this.tab_ModelSimulation.Table.Data,1)~=0 && any(~any(cellfun( @(x) isempty(x), this.tab_ModelSimulation.Table.Data))))

                response = questdlg_timer(this.figure_icon,15,{'Opening a new project will close the current project.','','Do you want to continue?'}, ...
                 'Close the current project?','Yes','No','No');
                
                if isempty(response) || strcmp(response,'No')
                    set(this.Figure, 'pointer', 'arrow');                    
                    return;
                end
            end            
            
            % Set initial folder to the project folder (if set)
            currentProjectFolder=''; %#ok<NASGU> 
            if ~isempty(this.project_fileName)                                
                try    
                    if isfolder(this.project_fileName)
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

            if fName~=0
                % Change cursor
                set(this.Figure, 'pointer', 'watch');
                drawnow update;

                % Initialise whole GUI and variables
                initialiseGUI(this);

                % Assign the file name 
                this.project_fileName = fullfile(pName,fName);               
                
                % Analyse the variables in the file
                %----------------------------------------------------------
                % Get variables in file
                try
                    vars= whos('-file',this.project_fileName);
                catch
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update;
                    errordlg(['The following project file could not be opened:',this.project_fileName],'Project file read error ...');
                    return;
                end

                % Filter out 'models' variable
                j=0;
                hasModelsVar = false;
                for i=1:size(vars)
                   if ~strcmp(vars(i).name,'data') && ~strcmp(vars(i).name,'label') && ~strcmp(vars(i).name,'models') 
                       j=j+1;
                       varNames{j} = vars(i).name; %#ok<AGROW> 
                   end
                   if strcmp(vars(i).name,'data')
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
                catch
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
                        catch
                            % do nothing
                        end                            
                    end

                    if ~isempty(this.modelsOnHDD)
                        
                        % Setup matfile link to 'this'. NOTE: for
                        % offloadeed models setModel() can handle the third input being the 
                        % file name to the matfile link. 
                        % Note 2: The models only need to be loaded if
                        % this.model_labels does not contain calib. status.
                        model_labels = fieldnames(savedData); %#ok<PROPLC> 
                        nModels = length(model_labels); %#ok<PROPLC> 
                        nErr=0;
                        if isempty(this.model_labels) || size(this.model_labels,1)<nModels
                            this.model_labels=[];
                            h = waitbar(0,'Re-building list of calibrated models because of error. Please wait ...');      
                            setIcon(this, h);
                            for i=1:nModels             
                                waitbar(i/nModels);
                                try                                
                                    setModel(this, model_labels{i,1}, savedData.(model_labels{i,1})); %#ok<PROPLC> 
                                catch
                                    nErr = nErr+1;
                                end                                
                            end
                            close(h);
                        else
                            % Update object hold the relative path to the .mat file                            
                            for i=1:nModels   
                                model_label_tmp = HydroSight_GUI.modelLabel2FieldName(model_labels{i,1}); %#ok<PROPLC> 
                                this.models.(model_label_tmp) = fullfile(this.modelsOnHDD, [model_label_tmp,'.mat']);                                
                            end
                        end
                        
                        if nErr>0
                            h = warndlg(['The HDD stored .mat files could not be loaded for ', num2str(nErr), ' models. Check the .mat files exist for all calibrated models in the project'],'Load errors');
                            setIcon(this, h);
                        end
                    else
                        
                        if iscell(savedData)
                            nModels = size(savedData,1);
                            for i=1:nModels                                
                                setModel(this, savedData{i,1}.model_label, savedData{i,1});
                            end
                        else
                            model_labels = fieldnames(savedData); %#ok<PROPLC> 
                            nModels = length(model_labels); %#ok<PROPLC> 
                            for i=1:nModels
                                setModel(this, savedData.(model_labels{i,1}).model_label, savedData.(model_labels{i,1})); %#ok<PROPLC> 
                            end
                        end                 
                    end
                catch
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update;
                    h = warndlg('Loaded models could not be assigned to the user interface.','File model error');
                    setIcon(this, h);
                    set(this.Figure, 'pointer', 'watch');
                    drawnow update;
                end                  
                
                % GET GUI TABLE DATA
                %----------------------------------------------------------
                % Load file (except 'model')
                try
                    savedData = load(this.project_fileName, varNames{:}, '-mat');
                catch
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update;
                    h = warndlg('Project file could not be loaded.','File error');
                    setIcon(this, h);
                    return;
                end
                
                % Assign loaded data to the tables and models.
                try
                    this.tab_Project.project_name.String = savedData.tableData.tab_Project.title;
                    this.tab_Project.project_description.String = savedData.tableData.tab_Project.description;
                catch
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update;
                    h = warndlg('Data could not be assigned to the user interface table: Project Description','File table error');
                    setIcon(this, h);
                    set(this.Figure, 'pointer', 'watch');
                    drawnow update;
                end
                try
                    if size(savedData.tableData.tab_DataPrep,2)==17
                       savedData.tableData.tab_DataPrep = [ savedData.tableData.tab_DataPrep(:,1:14), ...
                                                            false(size(savedData.tableData.tab_DataPrep,1),1), ...
                                                            savedData.tableData.tab_DataPrep(:,15:17) ];
                    end
                    this.tab_DataPrep.Table.Data = savedData.tableData.tab_DataPrep;
                    
                    % Update row numbers
                    nrows = size(this.tab_DataPrep.Table.Data,1);
                    this.tab_DataPrep.Table.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));                    
                catch
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update;
                    h = warndlg('Data could not be assigned to the user interface table: Outlier detection','File table error');
                    setIcon(this, h);
                    set(this.Figure, 'pointer', 'watch');
                    drawnow update;
                end               
                try
                    % If the head obs freq is missing, then add it in.
                    if size(savedData.tableData.tab_ModelConstruction,2)==9
                        numRows = size(savedData.tableData.tab_ModelConstruction,1);
                        savedData.tableData.tab_ModelConstruction = [savedData.tableData.tab_ModelConstruction(:,1:6), ...
                            num2cell(ones(numRows,1)), savedData.tableData.tab_ModelConstruction(:,7:9)];
                    end
                    this.tab_ModelConstruction.Table.Data = savedData.tableData.tab_ModelConstruction;
                    
                    % Update row numbers
                    nrows = size(this.tab_ModelConstruction.Table.Data,1);
                    this.tab_ModelConstruction.Table.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));     
                catch
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update;
                    h = warndlg('Data could not be assigned to the user interface table: Model Construction','File table error');
                    setIcon(this, h);
                    set(this.Figure, 'pointer', 'watch');
                    drawnow update;
                end     
                
                % Read in calib. table
                try       
                    
                    % Check if the input calibration table has 14 columns.
                    % If so, then delete the calib settings column.
                    if size(savedData.tableData.tab_ModelCalibration,2)==14
                        savedData.tableData.tab_ModelCalibration = savedData.tableData.tab_ModelCalibration(:,[1:8,10:14]);
                    end                   
                    this.tab_ModelCalibration.Table.Data = savedData.tableData.tab_ModelCalibration;
                    
                    % Update row numbers
                    nrows = size(this.tab_ModelCalibration.Table.Data,1);
                    this.tab_ModelCalibration.Table.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));           
                catch
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update;
                    h = warndlg('Data could not be assigned to the user interface table: Model Calibration','File table error');
                    setIcon(this, h);
                    set(this.Figure, 'pointer', 'watch');
                    drawnow update;
                end                
                try
                    this.tab_ModelSimulation.Table.Data = savedData.tableData.tab_ModelSimulation;
                    
                    % Update row numbers
                    nrows = size(this.tab_ModelSimulation.Table.Data,1);
                    this.tab_ModelSimulation.Table.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));  

                    % Convert model labels from a variable name to the full
                    % label (ie without _ chars etc)
                    model_label = this.tab_ModelSimulation.Table.Data(:,2);
                    for i=1:length(model_label)
                        if isfield(this.models,model_label{i}) && ...
                           isprop(this.models.(model_label{i}),'model_label')      
                            model_label{i} = this.models.(model_label{i}).model_label;                            
                        end
                    end
                    this.tab_ModelSimulation.Table.Data(:,2) = model_label;
                catch
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update;
                    h = warndlg('Data could not be assigned to the user interface table: Model Simulation','File table error');
                    setIcon(this, h);
                    set(this.Figure, 'pointer', 'watch');
                    drawnow update;
                end                              
                    
                % Assign analysed bores.
                try
                    this.dataPrep = savedData.dataPrep;
                catch
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update;
                    h = warndlg('Loaded data analysis results could not be assigned to the user interface.','File data error');
                    setIcon(this, h);
                    set(this.Figure, 'pointer', 'watch');
                    drawnow update;
                end          
                
                % Update GUI title
                vernum = getHydroSightVersion();
                set(this.Figure,'Name',['HydroSight ', vernum,': ', this.project_fileName]);
                drawnow update;   
                
                % Set current folder to that of the project
                cd(fileparts(this.project_fileName))
                
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

                % TODO Initialise GUI
            end
            set(this.Figure, 'pointer', 'arrow');
            drawnow update;                    
        end

        function onImportModel(this,~,~)

            % Get current project folder
            if isfolder(this.project_fileName)
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
            if fName~=0
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
                h = warndlg({'The new project has the models offloaded to the hard-drive..';''; ...
                         'Importing of such models s not yet supported.'},'Models not imported','modal');                
                setIcon(this, h);
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
                    newModelLabel = [newModelLabel,'_imported']; %#ok<AGROW> 
                end
                
                % Find the model within the GUI tables.
                filt = strcmp(HydroSight_GUI.modelLabel2FieldName(newProjectGUITables.tableData.tab_ModelConstruction(:,2)), ModelLabel);
                if any(filt)
                    newTableData = newProjectGUITables.tableData.tab_ModelConstruction(filt,:);
                    if size(newTableData,2) ~=size(this.tab_ModelConstruction.Table.Data,2)
                        importedModels{nModels,1} = [importedModels{nModels,1},': Error - construction table inconsistency'];
                        continue
                    end
                    newTableData{1,2} = strrep(newTableData{1,2}, ModelLabel, newModelLabel);
                    this.tab_ModelConstruction.Table.Data(end+1,:)=newTableData(1,:);
                    this.tab_ModelConstruction.Table.RowName{end+1} = num2str(str2double(this.tab_ModelConstruction.Table.RowName{end})+1);
                end
                newProjectTableLabels = HydroSight_GUI.modelLabel2FieldName(HydroSight_GUI.removeHTMLTags(newProjectGUITables.tableData.tab_ModelCalibration(:,2)));
                filt = strcmp(newProjectTableLabels, ModelLabel);
                if any(filt)
                    newTableData = newProjectGUITables.tableData.tab_ModelCalibration(filt,:);
                    if size(newTableData,2) ~=size(this.tab_ModelCalibration.Table.Data,2)
                        importedModels{nModels,1} = [importedModels{nModels,1},': Error - calib. table inconsistency'];
                        continue
                    end
                    newTableData{1,2} = strrep(newTableData{1,2}, ModelLabel, newModelLabel);
                    this.tab_ModelCalibration.Table.Data(end+1,:)=newTableData(1,:);
                    this.tab_ModelCalibration.Table.RowName{end+1} = num2str(str2double(this.tab_ModelCalibration.Table.RowName{end})+1);
                end
                newProjectTableLabels = HydroSight_GUI.modelLabel2FieldName(HydroSight_GUI.removeHTMLTags(newProjectGUITables.tableData.tab_ModelSimulation(:,2)));
                filt = strcmp(newProjectTableLabels, ModelLabel);                                
                if ~isempty(filt)
                    for j=filt
                        newTableData = newProjectGUITables.tableData.tab_ModelSimulation(j,:);
                        if size(newTableData,2) ~=size(this.tab_ModelSimulation.Table.Data,2)
                            importedModels{nModels,1} = [importedModels{nModels,1},': Warning - simulation table inconsistency'];
                            break
                        end
                        newTableData{1,2} = strrep(newTableData{1,2}, ModelLabel, newModelLabel);
                        this.tab_ModelSimulation.Table.Data(end+1,:)=newTableData(1,:);
                        this.tab_ModelSimulation.Table.RowName{end+1} = num2str(str2double(this.tab_ModelSimulation.Table.RowName{end})+1);
                    end              
                end
                
                % Add model object and label.
                try          
                    setModel(this, newModelLabel, newProject.(ModelLabel));
                catch
                    importedModels{nModels,1} = [importedModels{nModels,1},': Error - model import failure'];
                    continue
                end
                    
                % Record model was added
                importedModels{nModels,1} = [importedModels{nModels,1},': Successfully imported'];
            end
                
            set(this.Figure, 'pointer', 'arrow');
            drawnow update;               
            
            h = msgbox([{'Below is a summary of the importation:\n'},importedModels'], ...
                         'Imported models','modal');    
            setIcon(this, h);
        end
        
        % Save as current model        
        function status = onSaveAs(this,~,~, fName, pName)
            
            % Initialise output as error
            status = -1;

            % set current folder to the project folder (if set)
            currentProjectFolder='';
            if ~isempty(this.project_fileName)                                
                try    
                    if isfolder(this.project_fileName)
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
            
            if nargin <4
                [fName,pName] = uiputfile({'*.mat'},'Save models as ...');
            end
            if fName~=0
                
                % Get the current project folder. If the project folder has
                % changed then warn the user that all infput file names
                % must be within the new project folder.
                if ~isempty(currentProjectFolder)                    
                    if ~strcmp(currentProjectFolder, pName)
                        h = warndlg({'The project folder is different to that already set.';''; ...
                                 'Importantly, all file names in the project are relative'; ...
                                 'to the project folder and so all input .csv files must be'; ...
                                 'within the project folder or a sub-folder within it.'},'File name invalid.','modal');
                        setIcon(this, h);
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
                dataPrep = this.dataPrep;               %#ok<PROPLC> 
                
                % Get settings
                settings.HPCoffload = this.HPCoffload;
                settings.modelsOnHDD = this.modelsOnHDD;
                
                % Get model labels & calib. status
                model_labels = this.model_labels;                %#ok<PROPLC> 
                
                % Save the GUI tables to the file.
                save(this.project_fileName, 'tableData', 'dataPrep', 'model_labels','settings', '-v7.3');  
                
                % Set current folder to that of the project
                cd(fileparts(this.project_fileName))
                
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

                    catch
                        set(this.Figure, 'pointer', 'arrow');
                        drawnow update;
                        h = warndlg('The project could not be saved. Please check you have write access to the directory.','Project not saved');
                        setIcon(this, h);
                        return;
                    end     
                end
                
                % Update GUI title
                vernum = getHydroSightVersion();
                set(this.Figure,'Name',['HydroSight ', vernum,': ', this.project_fileName]);                
            end
            
            % Change cursor
            set(this.Figure, 'pointer', 'arrow');
            drawnow update;
            
            % Return successful saving
            status = 0;
        end
        
        % Save model        
        function onSave(this,hObject,eventdata)
        
            if isempty(this.project_fileName) || exist(this.project_fileName,'file') ~= 2
                onSaveAs(this,hObject,eventdata);
            else               
                % Change cursor
                set(this.Figure, 'pointer', 'watch');   
                drawnow update;
                
                % Handle paragraph breaks in project desc.
                desc = this.tab_Project.project_description.String;
                descReformatted = char();
                for i=1:size(desc,1)
                    if isempty(strtrim(desc(i,:)))
                        descReformatted = [descReformatted, char newline]; %#ok<AGROW> 
                    else                    
                        descReformatted = [descReformatted, strtrim(desc(i,:))]; %#ok<AGROW> 
                    end
                end

                % Collate the tables of data to a temp variable.
                tableData.tab_Project.title = this.tab_Project.project_name.String;
                tableData.tab_Project.description = descReformatted;
                tableData.tab_DataPrep = this.tab_DataPrep.Table.Data;
                tableData.tab_ModelConstruction = this.tab_ModelConstruction.Table.Data;
                tableData.tab_ModelCalibration = this.tab_ModelCalibration.Table.Data;
                tableData.tab_ModelSimulation = this.tab_ModelSimulation.Table.Data;
                                
                % Get the data preparation results
                dataPrep = this.dataPrep; %#ok<PROPLC> 
                
                % Get settings
                settings.HPCoffload = this.HPCoffload;
                settings.modelsOnHDD = this.modelsOnHDD;                               
                
                % Get model labels & calib. status
                model_labels = this.model_labels; %#ok<PROPLC> 
                
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
                        h = warndlg('The project models could not be saved. Please check you have write access to the directory.','Project not saved');
                        setIcon(this, h);
                        return;                    
                    end
                end
            end            
            
            set(this.Figure, 'pointer', 'arrow');   
            drawnow update;
        end    
        
        % This function runs when the app is closed        
        function onExit(this,hObject,eventdata, defaultResponse)    
            
            if nargin<4
                defaultResponse = 'Cancel';
            end
            response = questdlg_timer(this.figure_icon,15,'Do you want to save the project before exiting?','Save project?','Yes','No','Cancel',defaultResponse);
            
            if isempty(response) || strcmp(response ,'Cancel')
                set(this.Figure, 'pointer', 'arrow');
                return
            end

            % Save project
            if strcmp(response ,'Yes')
                onSave(this,hObject,eventdata);
            end
            
            % Check that it was saved (ie if saveas was called from save() )
            if ~strcmp(response ,'No') && (isempty(this.project_fileName) || exist(this.project_fileName,'file') ~= 2)
                h = warndlg('HydroSight cannot exit because the project does not appear to have been saved.','Project save error');
                setIcon(this, h);
                return
            end
            
            % Exit
            delete(this.Figure);
        end

        function status = dataPrep_tableEdit(this, hObject, eventdata)
            % Have the inputs changed? If so then check if the bore is
            % already analysed then warn the user about changing it.
            status = 0;
            irow = eventdata.Indices(1);  
            icol= eventdata.Indices(2); 
            if icol==1
                return
            end
            if ~isequal(eventdata.PreviousData, eventdata.NewData)
                if isa(hObject,'struct')
                    data=hObject.Data;
                else
                    data=get(hObject,'Data');
                end 
                modelStatus = HydroSight_GUI.removeHTMLTags(data(irow,16));
                oldBoreID = data(irow,3);
                if any(strcmp(modelStatus,{'Analysed.','Bore analysed.'}))
                    msg = [strcat(oldBoreID, ' has already been analysed.'), ...
                        'If you now change the inputs, the results will be deleted.', char newline,  ...
                        'Do you want to continue with the changes to inputs?'];
                    response = questdlg_timer(this.figure_icon,15,msg,'Overwrite existing analysis?','Yes','No','No');
                    
                    if isempty(response) || strcmp(response,'No')
                        data{irow, icol} = eventdata.PreviousData;
                        set(this.tab_DataPrep.Table,'Data', data);
                        set(this.tab_DataPrep.Table,'Data', data);
                        status = -1;
                        return;
                    else
                        % Delete results
                        this.dataPrep = rmfield(this.dataPrep,oldBoreID);

                        % Reset table
                        data{irow,16} = '<html><font color = "#FF0000">Not analysed.</font></html>';
                        data{irow,17} = ['<html><font color = "#808080">','(NA)','</font></html>'];
                        data{irow,18} = ['<html><font color = "#808080">','(NA)','</font></html>'];
                        set(this.tab_DataPrep.Table,'Data', data);
                        status = 1;
                    end
                end
            end
        end

        function dataPrep_tableSelection(this, hObject, eventdata)
            icol=eventdata.Indices(:,2);
            irow=eventdata.Indices(:,1);            
            data=get(hObject,'Data'); % get the data cell array of the table           

            % Fix bug in col 15 bng integer, not logical
            if ~islogical(data{1,15})
                if data{1,15}==1
                    data{1,15}=true;
                else
                    data{1,15}=false;
                end
                set(hObject,'Data',data);
            end

            % Undertake column specific operations.
            if ~isempty(icol) && ~isempty(irow)

                % Record the current row and column numbers
                this.tab_DataPrep.currentRow = irow;
                this.tab_DataPrep.currentCol = icol;
            
                % Remove HTML tags from the column name
                columnName = HydroSight_GUI.removeHTMLTags(eventdata.Source.ColumnName{icol});             
                
                switch columnName
                    case 'Obs. Head File'
                        obj = findobj(this.tab_DataPrep.modelOptions.vbox, 'Tag','Data Preparation - options panels');
                        set(obj,'Sizes',[0; 0; 0]);

                        % Get file name and remove project folder from
                        % preceeding full path.
                        fname = getFileName(this, 'Select the Observed Head file.');                                                
                        if fname~=0
                            % Construct full file path name
                            if isfolder(this.project_fileName)
                                fnameFull = fullfile(this.project_fileName,fname);
                            else
                                fnameFull = fullfile(fileparts(this.project_fileName),fname);
                            end

                            % Check the bore ID file exists.
                            if exist(fnameFull,'file') ~= 2
                                h = warndlg('The observed head file no longer exists.','File error');
                                setIcon(this, h);
                                return;
                            end

                            % Read in the observed head file.
                            try
                                tbl = readtable(fnameFull);
                            catch
                                h = warndlg('The observed head file could not be read in. It must a .csv file of 6 columns','File error');
                                setIcon(this, h);
                                return;
                            end

                            % Check there are the correct number of columns
                            if length(tbl.Properties.VariableNames) < 5 || length(tbl.Properties.VariableNames) >8
                                h = warndlg({'The observed head file must be in one of the following formats:', ...'
                                    '  -boreID, year, month, day, head', ...
                                    '  -boreID, year, month, day, hour, minute, head', ...
                                    '  -boreID, year, month, day, hour, minute, second, head'},'File error');
                                setIcon(this, h);
                                return;
                            end

                            % Check columns 2 to 6 are numeric.
                            if any(any(~isnumeric(tbl{:,2:end})))
                                h = warndlg('Columns 2 to 6 within the observed head file must contain only numeric data.','File error');
                                setIcon(this, h);
                                return;
                            end

                            % Find the unique bore IDs
                            boreIDs = unique(tbl{:,1});

                            % Check the bore IDs are a valid field name.                            
                            tmp=struct();
                            for i=1:length(boreIDs)
                                try
                                    tmp.(boreIDs{i}) = 1;
                                catch
                                    h = warndlg({'Bore ',boreIDs{i}, 'has an invalid format.','It must not start with a number.','Consider appending a non-numeric prefix,','e.g. "Bore_"'},'Bore ID error');
                                    setIcon(this, h);
                                    return;
                                end
                            end

                            % Assign file name to date cell array
                            data{eventdata.Indices(1),eventdata.Indices(2)} = fname;

                            % Input file name to the table
                            set(hObject,'Data',data);

                            % Clear stored head data.
                            this.tab_DataPrep.boreID_data = struct();
                        end
                        set(this.tab_DataPrep.modelOptions.vbox, 'Sizes',[0 0]);
                    case 'Bore ID'
                         % Check the obs. head file is listed
                         fname = data{eventdata.Indices(1),2};
                         if isempty(fname)
                            h = warndlg('The observed head file name must be input before selecting the bore ID','Bore ID error');
                            setIcon(this, h);
                            return;
                         end
                         
                         % Construct full file path name
                         if isfolder(this.project_fileName)                             
                            fname = fullfile(this.project_fileName,fname); 
                         else
                            fname = fullfile(fileparts(this.project_fileName),fname);  
                         end                         
                         
                         % Check the bore ID file exists.
                         if exist(fname,'file') ~= 2
                            h = warndlg('The observed head file does not exist.','File error');
                            setIcon(this, h);
                            return;
                         end
                         
                         % Read in the observed head file.
                         try                            
                            tbl = readtable(fname);
                         catch
                            h = warndlg('The observed head file could not be read in. It must a .csv file of 6 columns','File error');
                            setIcon(this, h);
                            return;
                         end
                            
                         % Find the unique bore IDs   
                         boreIDs = unique(tbl{:,1});
                         
                         % Store the file data for plotting of the
                         % hydrograph as the user selects different bores.
                         this.tab_DataPrep.boreID_data = struct();
                         for i=1:length(boreIDs)
                             filt =  strcmp(tbl{:,1},boreIDs{i});
                             headData = tbl(filt,2:end);
                             headData = sortrows(headData{:,:}, 1:(size(headData,2)-1),'ascend');
                             this.tab_DataPrep.boreID_data.(boreIDs{i}) = single(headData);
                         end

                         % Free up memory
                         clear tbl;
                         
                         % Input the unique bore IDs to the list box.
                         set(this.tab_DataPrep.modelOptions.boreIDList,'String',boreIDs);  
                         
                         % Select the currently input bore ID
                         boreID_current = data{eventdata.Indices(1),3};
                         set(this.tab_DataPrep.modelOptions.boreIDList,'Value',1);  
                         if ~isempty(boreID_current)
                             ind = find(strcmp(boreIDs, boreID_current));
                             if ~isempty(ind)
                                 ind = ind(1);
                                 set(this.tab_DataPrep.modelOptions.boreIDList,'Value',ind);  
                             end
                         end

                         % Show the list box.
                         obj = findobj(this.tab_DataPrep.modelOptions.vbox, 'Tag','Data Preparation - options panels');
                         set(obj,'Sizes',[-1; 0; 0]);
                         set(this.tab_DataPrep.modelOptions.vbox, 'Sizes',[-1 -1]);

                    case 'Analysis Status'
                        modelStatus = HydroSight_GUI.removeHTMLTags(data{irow,16});

                        % Get bore ID
                        boreID = data{irow,3};

                        % Build text for summary of results.
                        if isfield(this.dataPrep,boreID)
                            varnames = this.dataPrep.(boreID).Properties.VariableNames;
                            modelStatus = [modelStatus, char newline, ...
                                char newline, 'Number of ',varnames{7}, 's = ', num2str(sum(table2array(this.dataPrep.(boreID)(:,7)))), ...
                                char newline, 'Number of ',varnames{8}, 's = ', num2str(sum(table2array(this.dataPrep.(boreID)(:,8)))), ...
                                char newline, 'Number of ',varnames{9}, 's = ', num2str(sum(table2array(this.dataPrep.(boreID)(:,9)))), ...
                                char newline, 'Number of ',varnames{10}, 's = ', num2str(sum(table2array(this.dataPrep.(boreID)(:,10)))), ...
                                char newline, 'Number of ',varnames{11}, 's = ', num2str(sum(table2array(this.dataPrep.(boreID)(:,11)))), ...
                                char newline, 'Number of ',varnames{12}, 's = ', num2str(sum(table2array(this.dataPrep.(boreID)(:,12)))), ...
                                char newline, 'Number of ',varnames{13}, 's = ', num2str(sum(table2array(this.dataPrep.(boreID)(:,13))))];
                        end

                        % Find object
                        obj = findobj(this.tab_DataPrep.modelOptions.vbox,'Tag','Data Preparation - status box');

                        % Add ststus to box
                        set(obj,'String',modelStatus);

                         % Show the text box.
                         obj = findobj(this.tab_DataPrep.modelOptions.vbox, 'Tag','Data Preparation - options panels');
                         set(obj,'Sizes',[0; 0; -1]);
                         set(this.tab_DataPrep.modelOptions.vbox, 'Sizes',[-1 -1]);
                    otherwise
                        % Show results table
                        obj = findobj(this.tab_DataPrep.modelOptions.vbox, 'Tag','Data Preparation - options panels');
                        set(obj,'Sizes',[0; -1; 0]);
                end

                % Show the results if the bore has been analysed, else plot the data
                boreID = data{eventdata.Indices(1),3};
                modelStatus = HydroSight_GUI.removeHTMLTags(data{irow,16});
                if ~isempty(boreID) && ~any(strcmp(modelStatus,{'Bore analysed.','Analysed.'}))
                    % Check if head data is in object, else get temp data.
                    % If the data is not there, then read the file in
                    % again.
                    if isfield(this.tab_DataPrep,'boreID_data') && ...
                    isfield(this.tab_DataPrep.boreID_data,boreID) && ...
                    ~isempty(this.tab_DataPrep.boreID_data.(boreID))
                        headData = double(this.tab_DataPrep.boreID_data.(boreID));
                    else
                        % Construct full file path name
                        fname = data{eventdata.Indices(1),2};
                        if isfolder(this.project_fileName)
                            fname = fullfile(this.project_fileName,fname);
                        else
                            fname = fullfile(fileparts(this.project_fileName),fname);
                        end

                        % Read in the observed head file.
                        try
                            tbl = readtable(fname);
                        catch
                            h = warndlg('The observed head file could not be read in. It must a .csv file of 6 columns','File error');
                            setIcon(this, h);
                            return;
                        end

                        % Find the unique bore IDs
                        boreIDs = unique(tbl{:,1});

                        % Store the file data for plotting of the
                        % hydrograph as the user selects different bores.
                        this.tab_DataPrep.boreID_data = struct();
                        for i=1:length(boreIDs)
                            filt =  strcmp(tbl{:,1},boreIDs{i});
                            headData = tbl(filt,2:end);
                            headData = sortrows(headData{:,:}, 1:(size(headData,2)-1),'ascend');
                            this.tab_DataPrep.boreID_data.(boreIDs{i}) = single(headData);
                        end
                        headData = double(this.tab_DataPrep.boreID_data.(boreID));
                    end

                    % Add head data to the uitable
                    this.tab_DataPrep.modelOptions.resultsOptions.table.Data = headData;

                    % Convert head date/time columns to a vector.
                    switch size(headData,2)-1
                        case 3
                            dateVec = datenum(headData(:,1), headData(:,2), headData(:,3));
                            this.tab_DataPrep.modelOptions.resultsOptions.table.ColumnName = {'Year', 'Month', 'Day', 'Head'};
                        case 4
                            dateVec = datenum(headData(:,1), headData(:,2), headData(:,3),headData(:,4), zeros(size(headData,1),1), zeros(size(headData,1),1));
                            this.tab_DataPrep.modelOptions.resultsOptions.table.ColumnName = {'Year', 'Month', 'Day', 'Hour', 'Head'};
                        case 5
                            dateVec = datenum(headData(:,1), headData(:,2), headData(:,3),headData(:,4),headData(:,5), zeros(size(headData,1),1));
                            this.tab_DataPrep.modelOptions.resultsOptions.table.ColumnName = {'Year', 'Month', 'Day', 'Hour', 'Minute', 'Head'};
                        case 6
                            dateVec = datenum(headData(:,1), headData(:,2), headData(:,3),headData(:,4),headData(:,5),headData(:,6));
                            this.tab_DataPrep.modelOptions.resultsOptions.table.ColumnName = {'Year', 'Month', 'Day', 'Hour', 'Minute', 'Second','Head'};
                        otherwise
                            this.tab_DataPrep.Table.Data{irow, 16} = '<html><font color = "#FF0000">Data error - observed head must be 4 to 7 columns with right hand column being the head and the left columns: year; month; day; hour (optional), minute (options), second (optional).</font></html>';
                            return;
                    end
                    headData = [dateVec, headData(:,end)];

                    % Plot the hydrograph
                    plot(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec, headData(:,end),'b.-');
                    set(this.tab_DataPrep.modelOptions.resultsOptions.plots,'Units','normalized');
                    set(this.tab_DataPrep.modelOptions.resultsOptions.plots,'Position',[0.1,0.135,0.875,0.82]);
                    legendstring{1} = 'Obs.';

                    % Format plot
                    datetick(this.tab_DataPrep.modelOptions.resultsOptions.plots,'x');
                    xlabel(this.tab_DataPrep.modelOptions.resultsOptions.plots,'Year');
                    ylabel(this.tab_DataPrep.modelOptions.resultsOptions.plots,'Head');
                    box(this.tab_DataPrep.modelOptions.resultsOptions.plots,'on');
                    axis(this.tab_DataPrep.modelOptions.resultsOptions.plots,'tight');
                    legend(this.tab_DataPrep.modelOptions.resultsOptions.plots, legendstring,'Location','eastoutside');

                    % SHow results                   
                    set(this.tab_DataPrep.modelOptions.vbox, 'Sizes',[-1 -1]);

                    % SHow plot icons
                    plotToolbarState(this,'on');

                elseif ~isempty(this.dataPrep) && ~isempty(boreID) && ...
                        isfield(this.dataPrep,boreID) && ~isempty(this.dataPrep.(boreID)) && ...
                        any(strcmp(modelStatus,{'Bore analysed.','Analysed.'}))

                    % Get the analysis results.
                    headData = this.dataPrep.(boreID);

                    % Add head data to the uitable
                    this.tab_DataPrep.modelOptions.resultsOptions.table.Data = table2cell(headData);
                    this.tab_DataPrep.modelOptions.resultsOptions.table.ColumnName =  {'Year', 'Month', 'Day', 'Hour', 'Minute', 'Head', 'Date_Error', 'Duplicate_Date_Error', 'Min_Head_Error','Max_Head_Error','Rate_of_Change_Error','Const_Hear_Error','Outlier_Obs'};

                    % Convert to a matrix
                    headData = table2array(headData);

                    % Create a time vector form head data.
                    dateVec = datenum(headData(:,1),headData(:,2),headData(:,3),headData(:,4),headData(:,5),zeros(size(headData,1),1));

                    % Plot the hydrograph
                    isError = any(headData(:,7:end)==1,2);
                    plot(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(~isError), headData(~isError,6),'b.-');
                    legendstring{1} = 'Obs.';
                    hold(this.tab_DataPrep.modelOptions.resultsOptions.plots,'on');

                    % Date errors
                    col = 7;
                    isError = headData(:,col)==1;
                    if any(isError)
                        scatter(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(isError), headData(isError,6),'o');
                        legendstring = [legendstring 'Date error'];
                    end

                    col = 8;
                    isError = headData(:,col)==1;
                    if any(isError)
                        scatter(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(isError), headData(isError,6),'o');
                        legendstring = [legendstring 'Duplicate error'];
                    end

                    col = 9;
                    isError = headData(:,col)==1;
                    if any(isError)
                        scatter(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(isError), headData(isError,6),'o');
                        legendstring = [legendstring 'Min head error'];
                    end

                    col = 10;
                    isError = headData(:,col)==1;
                    if any(isError)
                        scatter(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(isError), headData(isError,6),'o');
                        legendstring = [legendstring 'Max head error'];
                    end

                    col = 11;
                    isError = headData(:,col)==1;
                    if any(isError)
                        scatter(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(isError), headData(isError,6),'o');
                        legendstring = [legendstring '|dh/dt| error'];
                    end

                    col = 12;
                    isError = headData(:,col)==1;
                    if any(isError)
                        scatter(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(isError), headData(isError,6),'o');
                        legendstring = [legendstring 'dh/dt=0 error'];
                    end

                    col = 13;
                    isError = headData(:,col)==1;
                    if any(isError)
                        scatter(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(isError), headData(isError,6),'o');
                        legendstring = [legendstring 'Outlier obs.'];
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
                    set(this.tab_DataPrep.modelOptions.vbox, 'Sizes',[-1 -1]);

                    % SHow plot icons
                    plotToolbarState(this,'on');
                else
                    obj = findobj(this.tab_DataPrep.modelOptions.vbox, 'Tag','Data Preparation - options panels');
                    set(obj,'Sizes',[0; 0; 0]);
                    set(this.tab_DataPrep.modelOptions.vbox, 'Sizes',[0 0]);
                end
            end
        end
        
        % Data preparation results table edit.
        function dataPrep_resultsTableEdit(this, hObject, ~)

            % Check the row was found.
            if ~isfield(this.tab_DataPrep,'currentRow') || isempty(this.tab_DataPrep.currentRow)
                h = warndlg('An unexpected system error has occured. Please try re-selecting a grid cell from the main to replot the results.','System error');
                setIcon(this, h);
                return;
            end            
            
            % Get the current row from the main data preparation table.
            irow = this.tab_DataPrep.currentRow;
            boreID = this.tab_DataPrep.Table.Data{irow, 3};
                
            % Check the row was found.
            if isempty(boreID)
                h = warndlg('An unexpected system error has occured. Please try re-selecting a grid cell from the main to replot the results.','System error');
                setIcon(this, h);
                return;
            end

            % Get the new table of data.
            if isa(hObject,'struct')
                headData = hObject.Data;
            else
                headData = get(hObject,'Data');
            end

            % Check the number of rows in the data strcuture equal that of
            % the results table.
            if size(this.dataPrep.(boreID),1) ~= size(headData,1)
                h = warndlg('An unexpected system error has occured. Please try re-selecting a grid cell from the main to replot the results.','System error');
                setIcon(this, h);
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
            % Create a time vector from the head data.
            dateVec = datenum(headData(:,1),headData(:,2),headData(:,3),headData(:,4),headData(:,5),zeros(size(headData,1),1));

            % Plot the hydrograph and the errors and outliers
            isError = any(headData(:,7:end)==1,2);
            plot(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(~isError), headData(~isError,6),'b.-');
            legendstring{1} = 'Obs.';
            hold(this.tab_DataPrep.modelOptions.resultsOptions.plots,'on');

            % Date errors
            col = 7;
            isError = headData(:,col)==1;
            if any(isError)
                scatter(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(isError), headData(isError,6),'o');
                legendstring = [legendstring 'Date error'];
            end

            col = 8;
            isError = headData(:,col)==1;
            if any(isError)
                scatter(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(isError), headData(isError,6),'o');
                legendstring = [legendstring{:} 'Duplicate error'];
            end

            col = 9;
            isError = headData(:,col)==1;
            if any(isError)
%                 scatter(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(isError), headData(isError,6),'o');
                legendstring = [legendstring 'Min error'];
            end   

            col = 10;
            isError = headData(:,col)==1;
            if any(isError)
                scatter(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(isError), headData(isError,6),'o');
                legendstring = [legendstring 'Max error'];
            end  

            col = 11;
            isError = headData(:,col)==1;
            if any(isError)
                scatter(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(isError), headData(isError,6),'o');
                legendstring = [legendstring '|dh/dt| error'];
            end                              

            col = 12;
            isError = headData(:,col)==1;
            if any(isError)
                scatter(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(isError), headData(isError,6),'o');
                legendstring = [legendstring 'dh/dt=0 error'];
            end                              

            col = 13;
            isError = headData(:,col)==1;
            if any(isError)
                scatter(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec(isError), headData(isError,6),'o');
                legendstring = [legendstring 'Outlier'];
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
        
        function dataPrep_optionsSelection(this, hObject, ~)
            try                         
                switch this.tab_DataPrep.currentCol
                    case 3 % Bore ID column
                        
                         % Get selected bores
                         listSelection = get(hObject,'Value');
                         allBoreID = get(hObject,'String');
                         newBoreID = allBoreID{listSelection};  

                         % Get data from model construction table
                         data=get(this.tab_DataPrep.Table,'Data'); 

                         % Get the selected bore ID.
                         index_selected = this.tab_DataPrep.currentRow;
                         oldBoreID = data{index_selected,3};

                         % Check if the bore is already analysed.
                         eventdataNew.PreviousData = oldBoreID;
                         eventdataNew.NewData = newBoreID;
                         eventdataNew.Indices = [this.tab_DataPrep.currentRow, this.tab_DataPrep.currentCol];
                         hObjectNew.Data = data;
                         if dataPrep_tableEdit(this, hObjectNew, eventdataNew)==-1                             
                             listSelection = find(strcmp(allBoreID,oldBoreID));
                             set(hObject,'Value',listSelection);
                             return
                         end
                
                         % Reget data
                         data = get(this.tab_DataPrep.Table,'Data'); 

                         % Add selected bore ID is cell array at the currently
                         % selected bore.
                         data(index_selected,3) =  hObject.String(listSelection,1);

                         % Set bore ID 
                         set(this.tab_DataPrep.Table,'Data', data); 

                         % Update plot of hydrograph.
                         if isfield(this.tab_DataPrep,'boreID_data') && ...
                         isfield(this.tab_DataPrep.boreID_data,newBoreID) && ...
                         ~isempty(this.tab_DataPrep.boreID_data.(newBoreID))
                             
                             headData = double(this.tab_DataPrep.boreID_data.(newBoreID));

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
                             end

                             % Plot the hydrograph
                             plot(this.tab_DataPrep.modelOptions.resultsOptions.plots, dateVec, headData(:,end),'b.-');
                             legendstring{1} = 'Obs.';

                             % Format plot
                             datetick(this.tab_DataPrep.modelOptions.resultsOptions.plots,'x');
                             xlabel(this.tab_DataPrep.modelOptions.resultsOptions.plots,'Year');
                             ylabel(this.tab_DataPrep.modelOptions.resultsOptions.plots,'Head');
                             box(this.tab_DataPrep.modelOptions.resultsOptions.plots,'on');
                             axis(this.tab_DataPrep.modelOptions.resultsOptions.plots,'tight');
                             legend(this.tab_DataPrep.modelOptions.resultsOptions.plots, legendstring,'Location','eastoutside');

                             % SHow results
                             set(this.tab_DataPrep.modelOptions.vbox, 'Sizes',[-1 -1]);
                         end
                end
            catch
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
            this.tab_ModelConstruction.modelOptions.vbox.Heights = [0; 0; 0; 0; 0];
                        
            % Remove HTML tags from the column name
            columnName = HydroSight_GUI.removeHTMLTags(eventdata.Source.ColumnName{icol});

            % Clear the stored head data if the selected row has changed.
            if irow ~= this.tab_ModelConstruction.currentRow
                this.tab_ModelConstruction.boreID_data = struct();
            end

            % Record the current row and column numbers
            this.tab_ModelConstruction.currentRow = irow;
            this.tab_ModelConstruction.currentCol = icol;
                        
            % Get the data cell array of the table            
            data=get(hObject,'Data');                  
            
            % Warn if the selected column would change a model that's
            % already build.
            if any(strcmp(columnName, {'Model Label', 'Obs. Head File','Forcing Data File', ...
                'Coordinates File', 'Model Type', 'Min. Head Timestep (days)'}))

                % Check if the model is build.
                modelLabel = data{irow,2};
                doBuildCheck = true;
                doCalibrationCheck = true;
                doSimulationCheck = true;
                status =  checkEdit2Model(this, modelLabel, '', doBuildCheck, doCalibrationCheck, doSimulationCheck);                
                if status==0
                    % Return if the user has responded that no changes are to be made.
                    return;
                end
             end
            
            % Re-get the data of the table because checkEdit2Model() can
            % update its values.
            data=get(hObject,'Data');   

             switch columnName
                case 'Obs. Head File'
                    % Get file name and remove project folder from
                    % preceeding full path.                    
                    fName = getFileName(this, 'Select the Observed Head file.');               
                    if fName~=0
                        % Assign file name to date cell array
                        data{eventdata.Indices(1),eventdata.Indices(2)} = fName;

                        % Input file name to the table
                        set(hObject,'Data',data);
                    end

                     % Hide the panels.
                     this.tab_ModelConstruction.modelOptions.vbox.Heights = [0; 0 ; 0; 0; 0];                        

                     % Clear stored head data
                     this.tab_ModelConstruction.boreID_data = struct();
                case 'Forcing Data File'

                    % Get file name and remove project folder from
                    % preceeding full path.
                    fName = getFileName(this, 'Select the Forcing Data file.');                                                
                    if fName~=0
                        % Assign file name to date cell array
                        data{eventdata.Indices(1),eventdata.Indices(2)} = fName;

                        % Input file name to the table
                        set(hObject,'Data',data);
                    end
                    % Hide the panels.
                    this.tab_ModelConstruction.modelOptions.vbox.Heights = [0; 0 ; 0; 0; 0];                        

                case 'Coordinates File'
                    % Get file name and remove project folder from
                    % preceeding full path.
                    fName = getFileName(this, 'Select the Coordinates file.');                                                
                    if fName~=0
                        % Assign file name to date cell array
                        data{eventdata.Indices(1),eventdata.Indices(2)} = fName;

                        % Input file name to the table
                        set(hObject,'Data',data);
                    end

                    % Hide the panels.
                    this.tab_ModelConstruction.modelOptions.vbox.Heights = [0; 0 ; 0; 0; 0];

                case 'Site ID'
                     % Check the obs. head file is listed
                     fname = data{eventdata.Indices(1),3};
                     if isempty(fname)
                        h = warndlg('The observed head file name must be input before selecting the bore ID','File error');
                        setIcon(this, h);
                        return;
                     end

                     % Construct full file name.
                     if isfolder(this.project_fileName)                             
                        fname = fullfile(this.project_fileName,fname); 
                     else
                        fname = fullfile(fileparts(this.project_fileName),fname);  
                     end

                     % Check the bore ID file exists.
                     if exist(fname,'file') ~= 2
                        h = warndlg('The observed head file does not exist.','File error');
                        setIcon(this, h);
                        return;
                     end

                     % Read in the observed head file.
                     try
                        tbl = readtable(fname);
                     catch
                        h = warndlg('The observed head file could not be read in. It must a .csv file of 6 columns','File error');
                        setIcon(this, h);
                        return;
                     end

                     % Check there are the correct number of columns
                     if length(tbl.Properties.VariableNames) <5 || length(tbl.Properties.VariableNames) >8
                        h = warndlg({'The observed head file in one of the following structure:', ...
                            '- boreID, year, month, day, head', ...
                            '- boreID, year, month, day, hour, head', ...
                            '- boreID, year, month, day, hour, minute, head', ...
                            '- boreID, year, month, day, hour, minute, second, head', ...
                            },'File error');
                        setIcon(this, h);
                        return;
                     end

                     % Check columns 2 to 6 are numeric.
                     if any(any(~isnumeric(tbl{:,2:length(tbl.Properties.VariableNames)})))
                        h = warndlg(['Columns 2 to ',num2str(length(tbl.Properties.VariableNames)),' within the observed head file must contain only numeric data.'],'File error');
                        setIcon(this, h);
                        return;
                     end

                     % Find the unique bore IDs   
                     boreIDs = unique(tbl{:,1});

                     % Check the bore IDs can make a variable
                     try
                         temp = struct();
                         for i=1:length(boreIDs)
                             temp.(boreIDs{i}) = [1,2,3];
                         end
                     catch
                        h = warndlg(['The observed head file contains invalid site IDs.',char newline,'IDs must start with a letter and have no spaces.'],'Site ID error');
                        setIcon(this, h);
                        return
                     end

                     % Input the unique bore IDs to the list box.
                     set(this.tab_ModelConstruction.boreIDList,'String',boreIDs);  

                     % Show the list box.
                     this.tab_ModelConstruction.modelOptions.vbox.Heights = [-1; 0 ; 0; 0; 0];
                     
                     % Highlight the already selected IDs
                     boreIDs_selected = hObject.Data{irow,icol};
                     if ~isempty(boreIDs_selected)
                         boreIDs_selected  = textscan(boreIDs_selected,'%s','Delimiter',',');
                         boreIDs_selected  = boreIDs_selected{1};
                         ind = find(cellfun(@(x) any(strcmp(boreIDs_selected, x)), boreIDs));                         
                     else
                         ind=1;
                     end
                     set(this.tab_ModelConstruction.boreIDList,'Value',ind);  

                     % Store the data for all bores. This is done so
                     % that the user can select different bores and
                     % then see the hydrographs.
                     this.tab_ModelConstruction.boreID_data = struct();
                     for i=1:length(boreIDs)
                         filt =  strcmp(tbl{:,1},boreIDs{i});
                         headData = tbl(filt,2:end);
                         headData = sortrows(headData{:,:}, 1:(size(headData,2)-1),'ascend');

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
                         end
                         this.tab_ModelConstruction.boreID_data.(boreIDs{i}) = single([dateVec,headData(:,end)]);
                     end

                     % Call plottting function
                     modelConstruction_onBoreListSelection(this, this.tab_ModelConstruction.boreIDList, []);                   
                     
                case 'Model Type'                        
                     % Get the current model type.
                     modelType = data{irow,8};

                     % Get description for the current model type
                     try                         
                        modelDecription  =eval([modelType,'.description()']);                          
                     catch
                        modelDecription = 'No decription is available for the selected model.';
                     end

                     % Assign model decription to GUI string box                         
                     this.tab_ModelConstruction.modelDescriptions.String = modelDecription; 

                     % Show the description.
                     this.tab_ModelConstruction.modelOptions.vbox.Heights = [0; -1 ; 0; 0; 0];

                case 'Model Options'
                    % Check the preceeding inputs have been defined.
                    if  any(cellfun(@(x) isempty(x), data(irow,3:8)))
                        h = warndlg('The observed head data file, forcing data file, coordinates file, bore ID, head time step and model type must be input before the model option can be set.','Inputs error');
                        setIcon(this, h);
                        return;
                    end

                    % Set the forcing data, bore ID, coordinates and options
                    % for the given model type.
                    try          
                        modelType = eventdata.Source.Data{irow,8};

                        if isempty(this.project_fileName)
                            h = warndlg('The project folder must be set before the model options can be viewed or edited.','Project folder not set');
                            setIcon(this, h);
                            return
                        end
                        if isfolder(this.project_fileName)
                            dirname = this.project_fileName;
                        else
                            dirname = fileparts(this.project_fileName);
                        end                            

                        fname = fullfile(dirname,data{irow,4}); 
                        try 
                            % Convert bore ID to cell array
                            boreIDs = textscan(data{irow,6},'%s','Delimiter',',');

                            % Set Bore ID before setting forcing or coordinates data 
                            setBoreID(this.tab_ModelConstruction.modelTypes.(modelType).obj, boreIDs{1} );

                            % Set forcing and coordinates data.
                            setForcingData(this.tab_ModelConstruction.modelTypes.(modelType).obj, fname);
                            fname = fullfile(dirname,data{irow,5});
                            setCoordinatesData(this.tab_ModelConstruction.modelTypes.(modelType).obj, fname);                            
                            
                            % If the model options are empty, then add a
                            % default empty cell, else set the existing
                            % options into the model type GUI RHS panel.
                            if isempty(eventdata.Source.Data{irow,9}) || strcmp(eventdata.Source.Data{irow,9},'{}')
                                %eventdata.Source.Data{irow,8} = [];
                                data{irow,9} = [];
                            end
                            setModelOptions(this.tab_ModelConstruction.modelTypes.(modelType).obj, data{irow,9})
                        catch 
                            % do nothing
                            % It is assmumed that the this.tab_ModelConstruction.modelTypes.(modelType).obj
                            % will throw an error and a message if there is
                            % something wrong with the inputs.
                        end
                        

                    catch
                        h = warndlg('Unknown model type selected or the GUI for the selected model crashed.','Options error');
                        setIcon(this, h);
                        this.tab_ModelConstruction.modelOptions.vbox.Heights = [0; 0;  0; 0; 0];
                    end

                     % Show model type options.
                     switch modelType
                         case 'model_TFN'
                            this.tab_ModelConstruction.modelOptions.vbox.Heights = [0; 0;-1; 0; 0];
                         case 'ExpSmooth'
                            this.tab_ModelConstruction.modelOptions.vbox.Heights = [0; 0; 0; 0; 0];
                         otherwise
                             this.tab_ModelConstruction.modelOptions.vbox.Heights =[0; 0; 0; 0; 0];
                     end
                case 'Build Status'
                    modelStatus = HydroSight_GUI.removeHTMLTags(data{irow,end});

                    % Get the model label.
                    modelLabel = HydroSight_GUI.modelLabel2FieldName(data{irow,2});

                    % Build text for summary of results.
                    if isfield(this.models,modelLabel)
                        % Get the model object.
                        [model, errmsg] = getModel(this, modelLabel);

                        if ~isempty(errmsg)
                            modelStatus = [modelStatus, char newline, char newline, 'Error: ', errmsg];
                        else
                            % Get the bore IDs
                            boreID = model.bore_ID;

                            % Get obs head data.
                            headData = getObservedHead(model);

                            % Get the type of model
                            modelType = class(model.model);

                            % Get the model parameter names.
                            [params, paramNames] = getParameters(model.model);

                            % Get forcing data column names.
                            [forcingData, forcingData_colnames] = getForcingData(model.model);
                            
                            % Start build the model summary text
                            modelStatus = [modelStatus, char newline, char newline];   

                            % Add bore IDs
                            if ischar(boreID)
                                modelStatus = [modelStatus, 'Site ID: ', boreID, char newline];
                            elseif iscell(boreID)
                                modelStatus = [modelStatus, 'Site ID: '];
                                for i=1:length(boreID)
                                    modelStatus = [modelStatus, boreID{i}]; %#ok<AGROW>
                                    if i<length(boreID)
                                        modelStatus = [modelStatus, ', '];%#ok<AGROW>
                                    else
                                        modelStatus = [modelStatus, char newline];%#ok<AGROW>
                                    end
                                end
                            end
                            
                            % Add head data duration and min/max freq.
                            modelStatus = [modelStatus,  'Obs. Head Data: ', char newline];
                             modelStatus = [modelStatus,  '     Duration: ',datestr(headData(1,1),'dd-mmm-yyyy'), ...
                                ' to ',datestr(headData(end,1),'dd-mmm-yyyy'), char newline];
                             headTimestep_min = min(diff(headData(:,1)));
                             headTimestep_max = max(diff(headData(:,1)));
                             modelStatus = [modelStatus,  '     Min/max timestep (days): ',num2str(headTimestep_min), ...
                                ' to ',num2str(headTimestep_max), char newline];                           

                            % Add model type
                            modelStatus = [modelStatus, 'Model type: ', modelType, char newline];
                            
                            % Add forcing daat names and duration
                            modelStatus = [modelStatus,  'Forcing Data: ', char newline];
                            if ~isempty(forcingData_colnames)
                                modelStatus = [modelStatus,  '     Variable names: '];
                                for i=1:length(forcingData_colnames)
                                    modelStatus = [modelStatus, forcingData_colnames{i}]; %#ok<AGROW>
                                    if i<length(forcingData_colnames)
                                        modelStatus = [modelStatus, ', '];%#ok<AGROW>
                                    else
                                        modelStatus = [modelStatus, char newline];%#ok<AGROW>
                                    end
                                end
                            else
                                modelStatus = [modelStatus,  '     Variable names: (none)', char newline];
                            end
                            modelStatus = [modelStatus,  '     Duration: ',datestr(forcingData(1,1),'dd-mmm-yyyy'), ...
                                ' to ',datestr(forcingData(end,1),'dd-mmm-yyyy'), char newline];

                            % Add model parameter details.
                            modelStatus = [modelStatus, 'Number of calibrated parameters: ', num2str(size(params,1)), char newline, ...
                                'Model component label and parameter name: ', char newline];
                            for i=1:size(paramNames,1)
                                modelStatus = [modelStatus, '     ',paramNames{i,1},' : ',paramNames{i,2}, char newline]; %#ok<AGROW> 
                            end                            
                        end 
                    elseif ~strcmp(modelStatus,'Not built.')
                        modelStatus = ['Model build error.', char newline, char newline, 'Error message: ',modelStatus]; 
                    end

                    % Find object
                    obj = findobj(this.tab_ModelConstruction.modelOptions.vbox,'Tag','Model Construction - status box');

                    % Add ststus to box
                    set(obj,'String',modelStatus);

                    % Show the text box.
                    this.tab_ModelConstruction.modelOptions.vbox.Heights = [0; 0; 0; 0; -1];
                otherwise
                     % Hide the panels.
                     this.tab_ModelConstruction.modelOptions.vbox.Heights = [0; 0 ; 0; 0; 0];
            end

        end
            
        function modelConstruction_optionsSelection(this, hObject, ~)
            try                         
                switch this.tab_ModelConstruction.currentCol
                    case 6
                         % Get selected bores
                         listSelection = get(this.tab_ModelConstruction.boreIDList,'Value');

                         % Get data from model construction table
                         data=get(this.tab_ModelConstruction.Table,'Data'); 

                         % Get the selected bore row index.
                         index_selected = this.tab_ModelConstruction.currentRow;

                         % Convert site ID cells to a string.
                         %siteIDs = '{';
                         siteIDs = '';
                         for i=1:length(listSelection)
                             siteIDs = [siteIDs, this.tab_ModelConstruction.boreIDList.String{listSelection(i),1}, ',']; %#ok<AGROW> 
                         end
                         siteIDs = siteIDs(1:(length(siteIDs)-1));
                         
                         % Setup inputs for cheking if the model(s) have
                         % already been built.            
                         doBuildCheck = true;
                         doCalibrationCheck = true;
                         doSimulationCheck = true;

                         % Add selected bore ID is cell array at the currently
                         % selected bore.
                         if strcmp(hObject.Tag,'current')
                             % Check if the model is build.
                             modelLabel = data{index_selected,2};
                             status =  checkEdit2Model(this, modelLabel, '', doBuildCheck, doCalibrationCheck, doSimulationCheck);
                             if status==0
                                 % Return if the user has responded that no changes are to be made.
                                 return;
                             end

                             % Update data from model construction table
                             data=get(this.tab_ModelConstruction.Table,'Data');

                             % Update GUI table
                             data{index_selected,6} = siteIDs;

                             % Set bore ID
                             set(this.tab_ModelConstruction.Table,'Data', data);

                         elseif strcmp(hObject.Tag,'selected')
                             % Get list of selected bores.
                             selectedBores = data(:,1);
                             
                             % Check some bores have been selected.
                             if ~any(cellfun(@(x) x, selectedBores))
                                 h = warndlg('No models are selected using the left checkboxes.', 'No models selected');
                                 setIcon(this, h);
                                 return;
                             end                             
                             
                             for i=1:length(selectedBores)
                                if selectedBores{i}==1
                                    % Check if the model is build.
                                    modelLabel = data{i,2};
                                    status =  checkEdit2Model(this, modelLabel, '', doBuildCheck, doCalibrationCheck, doSimulationCheck);
                                    
                                    % Update data from model construction table
                                    data=get(this.tab_ModelConstruction.Table,'Data');
                                    
                                    if status~=0
                                        % Update GUI table if the user says
                                        % OK to do so
                                        data{i,6} = siteIDs;

                                        % Set bore ID 
                                        set(this.tab_ModelConstruction.Table,'Data', data);
                                    end
                                end
                             end                             
                         end

                         
                end
            catch
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
                if ~isempty(this.models) && ~strcmp(eventdata.PreviousData, eventdata.NewData) && ~isempty(eventdata.PreviousData)
                    if (strcmp(columnName, 'Model Label') || ...
                        strcmp(columnName, 'Obs. Head File') || ...
                        strcmp(columnName, 'Forcing Data File') || ...
                        strcmp(columnName, 'Coordinates File') || ...
                        strcmp(columnName, 'Site ID') || ...
                        strcmp(columnName, 'Model Type') || ...
                        strcmp(columnName, 'Model Options'))

                        % Check if the model is build.
                        modelLabel = hObject.Data{irow,2};
                        doBuildCheck = true;
                        doCalibrationCheck = true;
                        doSimulationCheck = true;
                        status =  checkEdit2Model(this, modelLabel, '', doBuildCheck, doCalibrationCheck, doSimulationCheck);
                        if status==0
                            % Return if the user has responded that no changes are to be made.
                            return;
                        end
                    end
                end
                
                switch columnName                    
                    case 'Model Label'                    
                        % Get current model label
                        newLabel = eventdata.NewData;
                        oldLabel = eventdata.PreviousData;
                        
                        % Check label does not start or end with a space
                        if strcmp(newLabel(end),' ') || strcmp(newLabel(1),' ')
                            h = warndlg('The model label cannot start or end with a space. Spaces hace been trimmed','Model label error','modal');
                            setIcon(this, h);
                            newLabel = strtrim(newLabel);
                            hObject.Data{irow,2} = newLabel;
                        end

                        % Check the model label can be converted to an
                        % appropriate field name (for saving)                        
                        if isempty(HydroSight_GUI.modelLabel2FieldName(newLabel))
                            return;
                        end
                        
                        % Check that the model label is unique.
                        allLabels = hObject.Data(:,2);
                        newLabel = HydroSight_GUI.createUniqueLabel(allLabels, newLabel, irow);                          
                        
                        % Report non-unique error if required
                        if ~strcmp(newLabel, hObject.Data{irow,2})
                            h = warndlg('The model label must be unique! An extension has been added to the label.','Model label error','modal');
                            setIcon(this, h);
                            hObject.Data{irow,2} = oldLabel;
                            return
                        end                        
                        
                        % Report length error if required
                        if length(newLabel)>63
                            h = warndlg('The model label must be <63 characters. Please rename the model.','Model label error','modal');
                            setIcon(this, h);
                            hObject.Data{irow,2} = oldLabel;
                            return
                        end                        
                        
                        % Input model label to GUI
                        hObject.Data{irow,2} = newLabel;
                        
                    case 'Model Options'
                        if any(strcmp(hObject.Data{irow,8},{'model_TFN'}))
                            modelOptionsArray = getModelOptions(this.tab_ModelConstruction.modelTypes.(hObject.Data{irow,8}).obj);
                        elseif strcmp(hObject.Data{irow,8},'expSmooth') 
                            % do nothing
                        else
                            error('Model type unmkown.')
                        end
                        hObject.Data(irow,icol) = modelOptionsArray;

                    case 'Model Type'                        
                         % Get the current model type.
                         modelType = hObject.Data{irow,8};
                         
                         % Get description for the current model type
                         try                         
                            modelDecription  =eval([modelType,'.description()']);                          
                         catch
                         	modelDecription = 'No decription is available for the selected model.';
                         end
                             
                         
                         % Assign model decription to GUI string b8ox                         
                         this.tab_ModelConstruction.modelDescriptions.String = modelDecription; 
                         
                         % Show the description.
                         this.tab_ModelConstruction.modelOptions.vbox.Heights = [0; -1 ; 0; 0; 0];                        
                    otherwise
                            % Do nothing                                             
                end
            end
        end
        
        function modelConstruction_onBoreListSelection(this, hObject, ~)
            % Make pane for plots
            delete( findobj(this.tab_ModelConstruction.boreID_panel,'type','axes'));
            set(this.tab_ModelConstruction.boreID_panel,'BackgroundColor',[1 1 1]);

            try

                % Plot each bore hydrograph
                for i=1:length(hObject.Value)

                    % Get sietID to plot
                    boreID = hObject.String{hObject.Value(i)};

                    % Get ID for bore
                    headData = double(this.tab_ModelConstruction.boreID_data.(boreID));

                    % Make axis for plot
                    if length(hObject.Value)==1
                        ax = axes( 'Parent', this.tab_ModelConstruction.boreID_panel);
                        set(ax,'Units','normalized');
                        set(ax,'Position',[0.1,0.135,0.875,0.82]);
                    else
                        ax=subplot(length(hObject.Value),1,i,'Parent',this.tab_ModelConstruction.boreID_panel);
                        pos = get(ax,'Position');
                        pos(1) = 0.1;
                        pos(3) = 0.875;
                        set(ax,'Position',pos);
                    end

                    % Plot the hydrograph
                    plot(ax, headData(:,1),headData(:,2),'b.-');

                    % Format plot
                    boreID = strrep(boreID,'_',' ');
                    datetick(ax,'x');
                    xlabel(ax,'Year');
                    ylabel(ax,['Obs. head (',boreID,')']);
                    box(ax,'on');
                    axis(ax,'tight');
                end
            catch
                % Clear stored hydrograph data and axes
                this.tab_ModelConstruction.boreID_data = struct();
                delete( findobj(this.tab_ModelConstruction.boreID_panel,'type','axes'));

                h = warndlg({'The observed head data could not be plotted.','', ...
                    'Check that the file is in one of the following column formats:', ...
                    '- boreID, year, month, day, head', ...
                    '- boreID, year, month, day, hour, head', ...
                    '- boreID, year, month, day, hour, minute, head', ...
                    '- boreID, year, month, day, hour, minute, second, head', ...
                    },'Head file error');
                setIcon(this, h);

            end
        end

        function modelCalibration_tableSelection(this, hObject, eventdata)
                        
            % Get indexes to table data
            icol=eventdata.Indices(:,2);
            irow=eventdata.Indices(:,1);            
            data=get(hObject,'Data'); % get the data cell array of the table

            % Exit if no cell is selected.
            if isempty(icol) && isempty(irow)
                return
            end

            % Exit if multiple cell is selected.
            if numel(icol)>1 && numel(irow)>1
                return
            end

            % Check if the selected row has changed.
            if ~isfield(this.tab_ModelCalibration,'currentRow') || isempty(this.tab_ModelCalibration.currentRow)
                hasRowChanged = true;
            else
                hasRowChanged = this.tab_ModelCalibration.currentRow ~= irow;
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

            % Warn the user if the model is already calibrated and the
            % inputs are to change - requiring the model calibration
            % property to be reset.
            if strcmp(columnName, 'Calib. Start Date') || ...
               strcmp(columnName, 'Calib. End Date') || ...
               strcmp(columnName, 'Calib. Method')

                % Check if the model is build.
                modelLabel = data{irow,2};
                doBuildCheck = false;
                doCalibrationCheck = true;
                doSimulationCheck = true;
                status =  checkEdit2Model(this, modelLabel, '', doBuildCheck, doCalibrationCheck, doSimulationCheck);
                if status==0
                    % Return if the user has responded that no changes are to be made.
                    return;
                end

                % Re-get the data cell array of the table
                data=get(hObject,'Data');

                % Reset the stored forcing data.            
                this.tab_ModelCalibration.resultsOptions.forcingData.modelLabel = '';
                this.tab_ModelCalibration.resultsOptions.forcingData.data_input = [];
                this.tab_ModelCalibration.resultsOptions.forcingData.data_derived = [];
                this.tab_ModelCalibration.resultsOptions.forcingData.colnames_input = {};
                this.tab_ModelCalibration.resultsOptions.forcingData.colnames_derived = {};
                this.tab_ModelCalibration.resultsOptions.forcingData.filt=[];                            
            end

            % Change cursor
            set(this.Figure, 'pointer', 'watch');   
            drawnow update;   

            switch columnName
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
                        try
                            inputDate = datenum( data{irow,icol},'dd-mmm-yyyy');
                        catch
                            inputDate = datenum( startDate,'dd-mmm-yyyy');
                        end
                    end
                    selectedDate = uical(inputDate, 'English',startDate, endDate, this.figure_icon,'Start date');

                    % Get the calibration end date 
                    calibEndDate = datenum( data{irow,icol+1},'dd-mmm-yyyy');                        

                    % Check date is between start and end date of obs
                    % head.
                    if selectedDate < startDate || selectedDate > endDate    
                        h = warndlg('The calibration start date must be within the range of the observed head data.','Date error');
                        setIcon(this, h);
                    elseif calibEndDate<=selectedDate
                        h = warndlg('The calibration start date must be less than the calibration end date.','Date error');
                        setIcon(this, h);
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
                        try
                            inputDate = datenum( data{irow,icol},'dd-mmm-yyyy');
                        catch
                            inputDate = datenum( endDate,'dd-mmm-yyyy');
                        end
                    end
                    selectedDate = uical(inputDate, 'English',startDate, endDate, this.figure_icon, 'End date');

                    % Get the calibration start date 
                    calibStartDate = datenum( data{irow,icol-1},'dd-mmm-yyyy');                        

                    % Check date is between start and end date of obs
                    % head.
                    if selectedDate < startDate || selectedDate > endDate    
                        h = warndlg('The calibration end date must be within the range of the observed head data.','Date error');
                        setIcon(this, h);
                    elseif calibStartDate>=selectedDate
                        h = warndlg('The calibration end date must be greater than the calibration start date.','Date error');
                        setIcon(this, h);
                    else
                        data{eventdata.Indices(1),eventdata.Indices(2)} = datestr(selectedDate,'dd-mmm-yyyy');
                    end
                    set(hObject,'Data',data);

                otherwise
                    % Do nothing
            end
            
            % Check there is no table data or no row selected
            if isempty(data) || isempty(irow)
                set(this.Figure, 'pointer', 'arrow');   
                drawnow update;                   
                return;
            end            
                                     
            % Find the current model label            
            calibLabel = HydroSight_GUI.removeHTMLTags(data{this.tab_ModelCalibration.currentRow,2});   
            calibLabel = HydroSight_GUI.modelLabel2FieldName(calibLabel);
            this.tab_ModelCalibration.currentModel = calibLabel;

            % Show calibration status
            calibTableStatus = HydroSight_GUI.removeHTMLTags(data{irow,9});
            calibTableStatus = ['Calibration Status: ',calibTableStatus , char newline, char newline];
            obj = findobj(this.tab_ModelCalibration.resultsTabs, 'Tag','Model Calibration - status text box');
            set(obj,'String',calibTableStatus);
            this.tab_ModelCalibration.resultsTabs.TabEnables{1} = 'on';

            % Clear the stored forcing data if this model
            % label does not equals the model label of the
            % stored data.
            if ~isfield(this.tab_ModelCalibration.resultsOptions,'forcingData') || ...
            (isfield(this.tab_ModelCalibration.resultsOptions.forcingData,'modelLabel') && ...
            ~strcmp(calibLabel,this.tab_ModelCalibration.resultsOptions.forcingData.modelLabel))
                this.tab_ModelCalibration.resultsOptions.forcingData.modelLabel = '';
                this.tab_ModelCalibration.resultsOptions.forcingData.data_input = [];
                this.tab_ModelCalibration.resultsOptions.forcingData.data_derived = [];
                this.tab_ModelCalibration.resultsOptions.forcingData.colnames_input = {};
                this.tab_ModelCalibration.resultsOptions.forcingData.colnames_derived = {};
                this.tab_ModelCalibration.resultsOptions.forcingData.filt=[];  
            end
                     
            % If the selected row has not changed, then do not update the
            % plots and tables. This is done to add to the user experience.
            if ~hasRowChanged && isfield(this.tab_ModelCalibration.resultsOptions.forcingData,'modelLabel') && ...
            strcmp(calibLabel,this.tab_ModelCalibration.resultsOptions.forcingData.modelLabel) 
                set(this.Figure, 'pointer', 'arrow');   
                drawnow update;                   
                return;
            end

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
        
                % Enable results tab if the model since its been calibrated.
                this.tab_ModelCalibration.resultsTabs.TabEnables = repmat({'on'},length(this.tab_ModelCalibration.resultsTabs.TabEnables),1);


                % Add hydrosight version details and date of calib
                if isfield(tmpModel.calibrationResults,'date') 
                    calibTableStatus = [calibTableStatus, 'Date calibrated: ', tmpModel.calibrationResults.date, char newline];
                end
                if isfield(tmpModel.calibrationResults,'HydroSight') && ...
                   isfield(tmpModel.calibrationResults.HydroSight,'versionNum') && ...
                   isfield(tmpModel.calibrationResults.HydroSight,'versionDate')
                     calibTableStatus = [calibTableStatus, 'HydroSight version used:', char newline, ...
                                         '     Version number: ', tmpModel.calibrationResults.HydroSight.versionNum, char newline, ...
                                         '     Version Date: ', tmpModel.calibrationResults.HydroSight.versionDate, char newline];
                end

                    % Update the calibration status if the model was calibrated
                if isfield(tmpModel.calibrationResults,'time_start') && isfield(tmpModel.calibrationResults,'time_end')
                    calibTableStatus = [calibTableStatus, 'Calibration start & end date: ',datestr(tmpModel.calibrationResults.time_start,'dd-mmm-yyyy'), ...
                        ' to ',datestr(tmpModel.calibrationResults.time_end,'dd-mmm-yyyy'), char newline];
                end
                if isfield(tmpModel.calibrationResults,'calibMethod')
                    calibTableStatus = [calibTableStatus, 'Calibration method: ',tmpModel.calibrationResults.calibMethod, char newline];
                end                
                if isfield(tmpModel.calibrationResults,'calibSchemeSettings')
                    calibTableStatus = [calibTableStatus, 'Calibration settings: ',char newline];
                    fnames = fieldnames(tmpModel.calibrationResults.calibSchemeSettings);
                    for i=1:length(fnames)
                        if isnumeric(tmpModel.calibrationResults.calibSchemeSettings.(fnames{i})) || islogical(tmpModel.calibrationResults.calibSchemeSettings.(fnames{i}))
                            calibTableStatus = [calibTableStatus, '     ',fnames{i},': ',num2str(tmpModel.calibrationResults.calibSchemeSettings.(fnames{i})), char newline]; %#ok<AGROW> 
                        elseif ischar(tmpModel.calibrationResults.calibSchemeSettings.(fnames{i}))
                            calibTableStatus = [calibTableStatus, '     ',fnames{i},': ',tmpModel.calibrationResults.calibSchemeSettings.(fnames{i}), char newline]; %#ok<AGROW> 
                        end                        
                    end
                end       
                if isfield(tmpModel.calibrationResults,'performance')
                    if isfield(tmpModel.calibrationResults.performance,'objectiveFunction')
                        if isscalar(tmpModel.calibrationResults.performance.objectiveFunction)
                            calibTableStatus = [calibTableStatus, 'Calibration objective function result: ',num2str(tmpModel.calibrationResults.performance.objectiveFunction), char newline];                        
                        else                            
                            calibTableStatus = [calibTableStatus, 'Calibration objective function result: ', char newline];
                            calibTableStatus = [calibTableStatus, '     Mean:',num2str(mean(tmpModel.calibrationResults.performance.objectiveFunction)), char newline];
                            calibTableStatus = [calibTableStatus, '     Minimum:',num2str(min(tmpModel.calibrationResults.performance.objectiveFunction)), char newline];
                            calibTableStatus = [calibTableStatus, '     Maximum:',num2str(max(tmpModel.calibrationResults.performance.objectiveFunction)), char newline];                        
                        end
                    end
                    if isfield(tmpModel.calibrationResults.performance,'numFunctionEvals')
                        calibTableStatus = [calibTableStatus, 'Number of function evaluations: ',num2str(tmpModel.calibrationResults.performance.numFunctionEvals), char newline];
                    end
                end
                if isfield(tmpModel.calibrationResults,'exitStatus')
                    calibTableStatus = [calibTableStatus, 'Calibration exist message: ',tmpModel.calibrationResults.exitStatus, char newline];
                end                                
                set(obj,'String',calibTableStatus);

                % Rebuild the plots of the calibration iterations - if the
                % data exists within the model.
                if isfield(tmpModel.calibrationResults.parameters,'iterations')
                    % Get panle object for the plots within the stsatus
                    % tabe.
                    obj = this.tab_ModelCalibration.resultsOptions.statusPanel.Children(1).Children(1);
                    set(obj,'BackgroundColor',[1, 1, 1]);

                    % Delete existing panels
                    delete( findobj(obj,'type','axes'));

                    % Re-create the plots
                    nPlots = size(tmpModel.calibrationResults.parameters.iterations,1);
                    for i=1:nPlots
                        h = subplot(ceil(nPlots/4),4,nPlots-i+1,'Parent',obj);
                        box(h,'on');
                        xlabel(h,'Calibration iterations');

                        yyaxis(h,'left');
                        plot(h, tmpModel.calibrationResults.parameters.iterations{i}.left.XData', ...
                            tmpModel.calibrationResults.parameters.iterations{i}.left.YData','Marker','none');
                        ylabel(h,tmpModel.calibrationResults.parameters.iterations{i}.left.ylabel);
                        xlabel(h,'Calibration iteraions');

                        if isfield(tmpModel.calibrationResults.parameters.iterations{i},'right')
                            yyaxis(h,'right');
                            plot(h, tmpModel.calibrationResults.parameters.iterations{i}.right.XData', ...
                                tmpModel.calibrationResults.parameters.iterations{i}.right.YData','Marker','none');
                            ylabel(h,tmpModel.calibrationResults.parameters.iterations{i}.right.ylabel);
                        end
                    end
                    obj = findobj(this.tab_ModelCalibration.resultsTabs, 'Tag','Model Calibration - status box');
                    set(obj, 'Sizes', [275 -1]);
                else
                    obj = findobj(this.tab_ModelCalibration.resultsTabs, 'Tag','Model Calibration - status box');
                    set(obj, 'Sizes', [-1 0]);
                end

                % Show a table of calibration data
                %---------------------------------
                % Get the model calibration data.
                tableData = tmpModel.calibrationResults.data.obsHead;
                hasModelledDistn = false;
                if size(tmpModel.calibrationResults.data.modelledHead,2)>2
                    hasModelledDistn = true;
                end
                if hasModelledDistn
                    residData = prctile(tmpModel.calibrationResults.data.modelledHead_residuals,[5, 95],2);
                    residData = double([tmpModel.calibrationResults.data.modelledHead_residuals(:,1), residData]);
                    tableData = [tableData, ones(size(tableData,1),1), tmpModel.calibrationResults.data.modelledHead(:,2), ...
                        tmpModel.calibrationResults.data.modelledHead(:,3),tmpModel.calibrationResults.data.modelledHead(:,4), ...
                        residData, tmpModel.calibrationResults.data.modelledNoiseBounds(:,end-1:end)];
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
                        residData = prctile(tmpModel.evaluationResults.data.modelledHead_residuals,[5, 95],2);
                        residData = double([tmpModel.evaluationResults.data.modelledHead_residuals(:,1), residData]);
                        evalData = [evalData, zeros(size(evalData,1),1), tmpModel.evaluationResults.data.modelledHead(:,2), ...
                            tmpModel.evaluationResults.data.modelledHead(:,3), tmpModel.evaluationResults.data.modelledHead(:,4), ...
                            residData, tmpModel.evaluationResults.data.modelledNoiseBounds(:,end-1:end)];

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
                    this.tab_ModelCalibration.resultsOptions.calibPanel.Children.Contents(1).Contents(1).ColumnName = {'Year','Month', 'Day','Hour','Minute', 'Obs. Head','Is Calib. Point?','Mod. Head (best)','Mod. Head (5th %ile)','Mod. Head (95th %ile)','Model Residual (best)','Model Residual (5th %ile)','Model Residual (95th %ile)','Total Err. (5th %ile)','Total Err. (95th %ile)'};
                else
                    this.tab_ModelCalibration.resultsOptions.calibPanel.Children.Contents(1).Contents(1).ColumnName = {'Year','Month', 'Day','Hour','Minute', 'Obs. Head','Is Calib. Point?','Mod. Head','Model Residual','Total Err. (5th %ile)','Total Err. (95th %ile)'};
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

                % Get parameter physical limits
                [params_upperLimit, params_lowerLimit] = getParameters_physicalLimit(tmpModel.model);

                % Add to the table
                obj = findobj(this.tab_ModelCalibration.resultsOptions.paramsPanel, 'Tag','Model Calibration - parameter table');
                obj.Data = cell(size(paramValues,1),size(paramValues,2)+4);
                obj.Data(:,1) = paramsNames(:,1);
                obj.Data(:,2) = paramsNames(:,2);
                obj.Data(:,3) = num2cell(params_lowerLimit);
                obj.Data(:,4) = num2cell(params_upperLimit);
                obj.Data(:,5:end) = num2cell(paramValues);

                nparams=size(paramValues,2);
                colnames = cell(nparams+4,1);
                colnames{1,1}='Component Name';
                colnames{2,1}='Parameter Name';
                colnames{3,1}='Lower physical bound';
                colnames{4,1}='Upper physical bound';
                colnames(5:end,1) = strcat(repmat({'Parm. Set '},1,nparams)',num2str(transpose(1:nparams)));
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
                    colnames(3:end,1) = strcat(repmat({'Parm. Set '},1,nderivedParams)',num2str(transpose(1:nderivedParams  )));
                    obj.ColumnName = colnames;
                end
                %---------------------------------

                % Show model forcing data
                %---------------------------------
                % Get the input forcing data
                [tableData, forcingData_colnames] = getForcingData(tmpModel);

                % Get tab index for the forcing data tab.
                tab_ind = strcmp(this.tab_ModelCalibration.resultsTabs.TabTitles,'Forcing Data');

                % Initialise flag to store derived data
                updateStoredForcingData = false;

                % Get the model derived forcing data (if not empty)
                if isempty(tableData)
                    this.tab_ModelCalibration.resultsOptions.forcingData.filt = [];

                    % Disable tab if there is no data
                    this.tab_ModelCalibration.resultsTabs.TabEnables{tab_ind} = 'off';
                else
                    % Enable tab if there is no data
                    this.tab_ModelCalibration.resultsTabs.TabEnables{tab_ind} = 'on';

                    if size(paramValues,2)>1

                        % Only recalculate the forcing data if the model 
                        % label for that call equals the model label of the 
                        % current model, if there is no data saved from a 
                        % previous call to this method or if data is saved but 
                        % it is for a different number of parameters.
                        if ~isfield(this.tab_ModelCalibration.resultsOptions.forcingData,'modelLabel') || ...
                        ~strcmp(calibLabel,this.tab_ModelCalibration.resultsOptions.forcingData.modelLabel) || ...
                        ~isfield(this.tab_ModelCalibration.resultsOptions.forcingData,'data_derived') || ...
                        isempty(this.tab_ModelCalibration.resultsOptions.forcingData.data_derived) || ...
                        size(paramValues,2) ~= size(this.tab_ModelCalibration.resultsOptions.forcingData.data_derived,3)

                            try
                                % Get forcing data from the first parameter set
                                % and set some constants.
                                setParameters(tmpModel.model,paramValues(:,1), paramsNames);
                                [tableData_derived_tmp, forcingData_colnames_derived] = getDerivedForcingData(tmpModel,tableData(:,1));
                                [nTimePoints, nVariables] = size(tableData_derived_tmp);
                                nparamSets = size(paramValues,2);

                                % Initialise derived forcing data matrix
                                this.tab_ModelCalibration.resultsOptions.forcingData.data_derived = repmat(single(nan(nTimePoints,nVariables)), [1, 1, nparamSets]);
                                this.tab_ModelCalibration.resultsOptions.forcingData.data_derived(:,:,1) = single(tableData_derived_tmp);
                                clear tableData_derived_tmp;

                                % Clear remaining saved data (to free up RAM).
                                this.tab_ModelCalibration.resultsOptions.forcingData.modelLabel = '';
                                this.tab_ModelCalibration.resultsOptions.forcingData.data_input = [];
                                this.tab_ModelCalibration.resultsOptions.forcingData.colnames_input = {};
                                this.tab_ModelCalibration.resultsOptions.forcingData.colnames_derived = {};
                                this.tab_ModelCalibration.resultsOptions.forcingData.filt=[];

                                % Derive forcing using parfor.
                                % Note, the use of a waitbar with parfor is adapted
                                % from http://au.mathworks.com/matlabcentral/newsreader/view_thread/166139
                                % Initially, the number of cores is idenified.
                                % A vector of indicies for the number of
                                % parameter sets is then created and reshaped
                                % into a matrix the number of columns equal to the
                                % number cores. The ran a parfor loop for each
                                % column of indicies.
                                poolobj = gcp('nocreate');
                                nLoops = 10;
                                if ~isempty(poolobj)
                                    nLoops = max(nLoops, 4*max(1,poolobj.NumWorkers));
                                end

                                ind=1:nparamSets;
                                indmod=mod(nparamSets,nLoops);
                                ind_mat = reshape(ind(1:(end-indmod)),[],nLoops);
                                if indmod>0
                                    % Add remaining ind to bottom row
                                    ind_mat(end+1,1:indmod) = ind((end-indmod+1):end);
                                end
                                ind_mat(1,1)=0;
                                h = waitbar(0, ['Calculating transformed forcing for ', num2str(size(paramValues,2)), ' parameter sets. Please wait ...']);
                                setIcon(this, h);
                                t = tableData(:,1);
                                for n=1:nLoops
                                    ind = ind_mat(:,n);
                                    ind = ind(ind>0);
                                    nInd = length(ind);
                                    tableData_derived_tmp =  single(nan(nTimePoints,nVariables, nInd));
                                    paramValues_tmp = paramValues(:,ind);
                                    parfor z = 1:nInd
                                        setParameters(tmpModel.model,paramValues_tmp(:,z), paramsNames);  %#ok<PFBNS>
                                        tableData_derived_tmp(:,:,z) = single(getDerivedForcingData(tmpModel,t));
                                    end
                                    this.tab_ModelCalibration.resultsOptions.forcingData.data_derived(:,:,ind) = tableData_derived_tmp;

                                    % update waitbar each "matlabpoolsize"th iteration
                                    waitbar(n/nLoops);
                                end
                                close(h);

                                % Clear temp derived data
                                clear tableData_derived_tmp

                                % Reset all parameters
                                setParameters(tmpModel.model,paramValues, paramsNames);

                                % Clear model object
                                clear tmpModel

                                % Set flag to store derived data
                                updateStoredForcingData = true;
                            catch ME
                                % reassign parameter sets
                                setParameters(tmpModel.model,paramValues, paramsNames);

                                % Disable tab if there is no data
                                this.tab_ModelCalibration.resultsTabs.TabEnables{tab_ind} = 'off';

                                % Display error if caused by lack of RAM 
                                if strcmp(ME.identifier, 'MATLAB:array:SizeLimitExceeded')
                                    reqMat = ceil(nparamSets*nVariables*nTimePoints*4/10^9);
                                    maxMat = memory();
                                    maxMat = floor(maxMat.MaxPossibleArrayBytes/10^9);
                                    h = warndlg(['Forcing data could not be shown because of insufficient RAM.', char newline, ...
                                                 'It requires ~', num2str(reqMat), 'GB and the maximum available is ~', num2str(maxMat), 'GB.', char newline, char newline,...
                                                 'To resolve this issue try the following:', char newline, ...                                                 
                                                 '   1. Reduce the length of the input climate data, ' char newline, ...
                                                 '   2. Reduce the minimum number of DREAM samples (Tmin), or', char newline, ...
                                                 '   3. Avoid using DREAM calibration.'],'Insufficient RAM');
                                    setIcon(this, h);
                                else
                                    h = warndlg(['Forcing data could not be shown because of an unhandled error.', char newline, ...
                                                 'The error message is:' char newline, ...
                                                 ME.message],'Unhandled error');
                                    setIcon(this, h);
                                end

                            end
                        end

                    else
                        [tableData_derived, forcingData_colnames_derived] = getDerivedForcingData(tmpModel,tableData(:,1));
                        this.tab_ModelCalibration.resultsOptions.forcingData.data_derived = single(tableData_derived);

                        % Set flag to store derived data
                        updateStoredForcingData = true;
                    end

                    % Store updated derived data
                    if updateStoredForcingData
                        % Calculate year, month, day etc
                        t = datetime(tableData(:,1), 'ConvertFrom','datenum');
                        tableData = [year(t), quarter(t), month(t), week(t,'weekofyear'), day(t), tableData(:,2:end)];
                        forcingData_colnames = {'Year','Quarter','Month','Week','Day', forcingData_colnames{2:end}};

                        % Store remaining forcing data. This is just done to
                        % avoid re-loading the model within updateForcingData()
                        % and updateForcinfPlot().
                        this.tab_ModelCalibration.resultsOptions.forcingData.modelLabel = calibLabel;
                        this.tab_ModelCalibration.resultsOptions.forcingData.data_input = single(tableData);
                        this.tab_ModelCalibration.resultsOptions.forcingData.colnames_input = forcingData_colnames;
                        this.tab_ModelCalibration.resultsOptions.forcingData.colnames_derived = forcingData_colnames_derived;
                        this.tab_ModelCalibration.resultsOptions.forcingData.filt=true(size(tableData,1),1);

                        % Free up RAM
                        clear tableData_derived tableData
                    end
                end

                % Update table and plots
                if ~isempty(this.tab_ModelCalibration.resultsOptions.forcingData.data_input)
                    modelCalibration_onUpdateForcingData(this)
                end
                %---------------------------------
            else
                % Disable results tab (excluding ststus tab) if the model has not been calibrated.
                this.tab_ModelCalibration.resultsTabs.TabEnables = repmat({'off'},length(this.tab_ModelCalibration.resultsTabs.TabEnables),1);
                this.tab_ModelCalibration.resultsTabs.TabEnables{1} = 'on';

                % Hide calibration status plots
                obj = findobj(this.tab_ModelCalibration.resultsTabs, 'Tag','Model Calibration - status box');
                set(obj, 'Sizes', [-1 0]);
            end
                           
            % Change cursor
            set(this.Figure, 'pointer', 'arrow');      
            drawnow update;
        end                
        
        function modelCalibration_onUpdatePlotSetting(this, ~, ~)
            
            % Change cursor
            set(this.Figure, 'pointer', 'watch');
            drawnow update;

            % Get selected popup menu item
            obj = findobj(this.tab_ModelCalibration.resultsOptions.calibPanel, 'Tag','Model Calibration - results plot dropdown');
            plotID = obj.Value;
            
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
                
                obj = uipanel('Parent', obj,'BackgroundColor',[1,1,1]);
                axisHandle = axes( 'Parent', obj);

                % Show the calibration plots.
                calibrateModelPlotResults(tmpModel, plotID, axisHandle);
                
                % Plot parameters
                %-----------------------
                [paramValues, paramsNames] = getParameters(tmpModel.model);                          
                paramsNames  = strrep(paramsNames(:,2), '_',' ');

                % Create an axis handle for the figure.
                obj = findobj(this.tab_ModelCalibration.resultsOptions.paramsPanel, 'Tag','Model Calibration - parameter plot');
                delete( findobj(obj ,'type','axes'));
                obj = uipanel('Parent', obj,'BackgroundColor',[1,1,1]);
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
                    % problem (see lines 232-236). Numerous other changes were
                    % required to ensure the creation of each axis did not
                    % hide the previously created axis.
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
                obj = uipanel('Parent', obj,'BackgroundColor',[1,1,1]);
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
                        % Filter params to plot only those with a
                        % range > 0.
                        paramHasRange = range(paramValues,2)>0;
                        paramValues = paramValues(paramHasRange,:);
                        paramsNames = paramsNames(paramHasRange);

                        % A bug seems to occur when the builtin plotmatrix is ran to produce a plot inside a GUI 
                        % whereby the default fig menu items and icons
                        % appear. The version of plotmatrix below has a
                        % a few lines commented out to supress this
                        % problem (see lines 232-236)                            
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
        
        % Update calibration GUI plots. Note, this method needs to be public.
        function modelCalibration_CalibPlotsUpdate(this, createNewPlot, calibMethod, param_names, iterationNumber, numFuncEvals, bestParam, bestObj, worstParam, worstObj, bestObj_ever)

            % Get panel object containing the plot axes
            plotsPanel = findobj(this.tab_ModelCalibration.GUI, 'Tag','Model calibration - progress plots panel');
            y2data_objLog = false;
            y1data_objLog = false;
            if strcmp(calibMethod,'DREAM')
                y1label = {'Log Likelihood','(Chains)'};
                y2label_obj = {'Max. convergence, r2','(Converged if <1.2)'};
                y2label_param = {'Convergence, r2','(Converged if <1.2)'};
                nparam_sets = size(bestParam,2);
                text_ypos = 0.05;
                text_ypos_vertalign = 'bottom';
                y2data_obj = worstObj;
                y2data_param = worstParam;    
            elseif strcmp(calibMethod,'CMA-ES')
                y1label = {'Objective function','(best)'};
                y2label_param = 'stdev';
                y2label_obj = 'max(stdev)';
                nparam_sets=1;
                text_ypos=0.925;
                text_ypos_vertalign = 'top';
                y2data_obj = worstObj;
                y1data_objLog = true;
                y2data_objLog = true;
                y2data_param = worstParam;               
            else
                y1label = {'Objective function','(best)'};
                y2label_param = 'best - worst';
                y2label_obj = y2label_param;
                nparam_sets=1;
                text_ypos=0.925;
                text_ypos_vertalign = 'top';
                y1data_objLog = true;
                y2data_objLog = true;
                y2data_obj = abs(bestObj - worstObj);
                y2data_param = abs(bestParam - worstParam);                
            end
            % If iterationNumber, bestParam, bestObj are empty, then initialise
            % the plot axes.
            if createNewPlot
                delete( findobj(plotsPanel ,'type','axes'));
                nParams = size(param_names,1);
                nPlots = nParams+1;
                h = subplot(ceil(nPlots/4),4,1,'Parent',plotsPanel);
                box(h,'on');
                xlabel(h,'Calibration iterations'); 

                yyaxis(h,'left');
                text(h, 0.03,text_ypos,['Num. model runs=',num2str(numFuncEvals)], ...
                        'Units','normalized','FontSize',8, 'VerticalAlignment',text_ypos_vertalign, ...
                        'Tag','Model calibration - progress plots text'); 
                if y1data_objLog
                    semilogy(h, 0,0);
                else
                    plot(h, 0,0);
                end
                ylabel(h,y1label);

                yyaxis(h,'right');
                if y2data_objLog
                    semilogy(h, 0,0);
                else
                    plot(h, 0,0);
                end
                ylabel(h,y2label_obj);

                for j=2:nPlots
                    h = subplot(ceil(nPlots/4),4,j,'Parent',plotsPanel);
                    box(h,'on');
                    xlabel(h,'Calibration iterations');

                    yyaxis(h,'left');
                    plot(h, 0,0);
                    lbl = strrep(param_names{j-1,2},"_","-");
                    lbl = strrep(lbl,"-infilled-position","");
                    if strlength(lbl)>10
                        lbl = strcat(['Param:',char newline],lbl);
                    else
                        lbl = strcat('Param:',lbl);
                    end
                    ylabel(h,lbl);

                    yyaxis(h,'right');
                    semilogy(h, 0,0);
                    ylabel(h,y2label_param);
                end
                return;
            end

            % Else, update an existing plot            
            nAxes = length(plotsPanel.Children);
            if nAxes ~= (size(bestParam,1)+1)
                error('Number of calibration plot axes must equal the number of params. +1.');
            end

            % Update objective function plot data
            ax = plotsPanel.Children(nAxes);
            yyaxis(ax,'left');
            nChildren = length(ax.Children);
            h = ax.Children(nChildren);
            current_XData = get(h,'XData');
            current_YData = get(h,'YData');
            
            if isscalar(current_XData) && isscalar(current_YData) && ...
            all(current_XData==0) && all(current_YData==0) % First edit to plot data
                set(h,{'XData','YData'}, {iterationNumber, bestObj(1)});
                hold(ax,'on');
                for j=2:nparam_sets
                    plot(ax,iterationNumber, bestObj(j),'Marker', 'none');
                end
                hold(ax,'off');
            else
                for j=2:nChildren
                    current_XData = get(ax.Children(j),'XData');
                    current_YData = get(ax.Children(j),'YData');
                    set(ax.Children(j),{'XData','YData'}, ...
                        {[current_XData, iterationNumber], [current_YData, bestObj(j-1)]});
                end                
            end
            if ~strcmp(calibMethod,'DREAM') && length(current_YData)>5
                if bestObj(1) <= min(current_YData)
                    y1 =  [current_YData, bestObj(1)];
                    y1_length = length(y1);
                    y1 = [min(y1), y1(ceil(y1_length*0.25))];
                    y1 = sort([y1(1)*0.999, 1.001*y1(2)]);
                    try
                        ylim(ax,y1);
                    catch
                        % do nothing
                    end
                end
            end

            if ~isempty(numFuncEvals)                
                if nChildren==1
                    if strcmp(calibMethod,'DREAM')
                        text(plotsPanel.Children(nAxes), 0.03,text_ypos,{['Num. model runs=',num2str(numFuncEvals)], ...
                            ['max(r2) converg. criteria=',num2str(bestObj_ever)]},'Units','normalized','FontSize',8, 'VerticalAlignment',text_ypos_vertalign, ...
                            'Tag','Model calibration - progress plots text');
                    else
                        text(plotsPanel.Children(nAxes), 0.03,text_ypos,{['Num. model runs=',num2str(numFuncEvals)], ...
                            ['Lowest obj, func.=',num2str(bestObj_ever)]}, ...
                            'Units','normalized','FontSize',8, 'VerticalAlignment',text_ypos_vertalign, ...
                            'Tag','Model calibration - progress plots text');
                    end
                else
                    if strcmp(calibMethod,'DREAM')
                        set(plotsPanel.Children(nAxes).Children(1),'String',{['Num. model runs=',num2str(numFuncEvals)], ...
                            ['max(r2) converg. criteria=',num2str(bestObj_ever)]});
                    else
                        set(plotsPanel.Children(nAxes).Children(1),'String', {['Num. model runs=',num2str(numFuncEvals)], ...
                            ['Lowest obj, func.=',num2str(bestObj_ever)]});
                    end
                end
            end
            if ~isempty(worstObj)
                yyaxis(plotsPanel.Children(nAxes),'right');
                current_XData = get(plotsPanel.Children(nAxes).Children(1),'XData');
                current_YData = get(plotsPanel.Children(nAxes).Children(1),'YData');
                if isscalar(current_XData) && isscalar(current_YData) && ...
                        all(current_XData==0) && all(current_YData==0) % First edit to plot data
                    set(plotsPanel.Children(nAxes).Children(1),{'XData','YData'}, ...
                        {iterationNumber, y2data_obj});
                else
                    set(plotsPanel.Children(nAxes).Children(1),{'XData','YData'}, ...
                        {[current_XData, iterationNumber], [current_YData, y2data_obj]});
                    if strcmp(calibMethod,'SP-UCI') && length(current_YData)>5
                        try
                            ylim(plotsPanel.Children(nAxes),sort([floor(prctile([current_YData, y2data_obj],25)),0]));
                        catch
                            % do nothing
                        end
                    end
                end
            end

            % Loop through each parameter and update plot data
            for i=(nAxes-1):-1:1
                ax = plotsPanel.Children(i);
                yyaxis(ax,'left');
                nChildren = length(ax.Children);
                h = ax.Children(1);
                current_XData = get(h,'XData');
                current_YData = get(h,'YData');
                if isscalar(current_XData) && isscalar(current_YData) && ...
                all(current_XData==0) && all(current_YData==0) % First edit to plot data
                    set(h,{'XData','YData'}, {iterationNumber, bestParam(nAxes-i,1)});
                    hold(ax,'on');
                    for j=2:nparam_sets
                        plot(ax,iterationNumber, bestParam(nAxes-i,j),'Marker', 'none');
                    end
                    hold(ax,'off');
                else
                    for j=1:nChildren
                        h = ax.Children(j);
                        current_XData = get(h,'XData');
                        current_YData = get(h,'YData');
                        set(h,{'XData','YData'},{[current_XData, iterationNumber], [current_YData, bestParam(nAxes-i,j)]});
                    end

                end
                if ~isempty(worstParam)
                    yyaxis(plotsPanel.Children(i),'right');
                    current_XData = get(plotsPanel.Children(i).Children(1),'XData');
                    current_YData = get(plotsPanel.Children(i).Children(1),'YData');
                    if isscalar(current_XData) && isscalar(current_YData) && ...
                            all(current_XData==0) && all(current_YData==0) % First edit to plot data
                        set(plotsPanel.Children(i).Children(1),{'XData','YData'}, ...
                            {iterationNumber, y2data_param(nAxes-i)});
                    else
                        set(plotsPanel.Children(i).Children(1),{'XData','YData'}, ...
                            {[current_XData, iterationNumber], [current_YData, y2data_param(nAxes-i)]});
                    end
                end
            end
            drawnow update;
        end

        % Define the appropriate type of forcing data to update
        % (i.e. calibration or simulation forcing data) and then call the
        % general function for either to setup the GUI data table and
        % plots.
        %----------------
        function modelCalibration_onUpdateForcingData(this, ~, ~)
            thisPanelName = 'tab_ModelCalibration';
            onUpdateForcingData(this, thisPanelName)
        end

        function modelCalibration_quitListen(this,~,~)
            this.tab_ModelCalibration.quitCalibration = true;
        end

        function modelCalibration_quitNotify(this,~,~)
            % Notify event that the user is quiting the calibration. 
            notify(this,'quitModelCalibration');
        end

        function modelCalibration_skipListen(this,~,~)
            this.tab_ModelCalibration.skipCalibration = true;
        end

        function modelCalibration_skipNotify(this,~,~)
            % Notify event that the user is skipping the current mdoel.
            notify(this,'skipModelCalibration');
        end

        function [exitCalib, exitFlag, exitStatus] = modelCalibration_getCalibState(this)
        % Check if the calibration is to be quit or skipped to next model. 
        % NOTE, the pause() call is required for the event notify/listen to interupt the calibration..
            pause(0.1);
            if isfield(this.tab_ModelCalibration,'quitCalibration') && this.tab_ModelCalibration.quitCalibration
                exitCalib = true;
                exitFlag = -1;
                exitStatus = 'User quit calibration.';
            elseif isfield(this.tab_ModelCalibration,'skipCalibration') && this.tab_ModelCalibration.skipCalibration
                exitCalib = true;
                exitFlag = -2;
                exitStatus = 'User skipped calibration.';
            else
                exitCalib = false;
                exitFlag = 0;
                exitStatus = '';
            end
        end
                                
        function modelSimulation_onUpdateForcingData(this, ~, ~)
            thisPanelName = 'tab_ModelSimulation';
            onUpdateForcingData(this, thisPanelName)
        end

        function modelCalibration_onUpdateForcingPlot(this, ~, ~)
            thisPanelName = 'tab_ModelCalibration';
            onUpdateForcingPlot(this, thisPanelName)
        end

        function modelSimulation_onUpdateForcingPlot(this, ~, ~)
            thisPanelName = 'tab_ModelSimulation';
            onUpdateForcingPlot(this, thisPanelName)
        end

        function modelCalibration_onUpdateForcingPlotType(this, ~, ~)
            thisPanelName = 'tab_ModelCalibration';
            onUpdateForcingPlotType(this, thisPanelName)
        end

        function modelSimulation_onUpdateForcingPlotType(this, ~, ~)
            thisPanelName = 'tab_ModelSimulation';
            onUpdateForcingPlotType(this, thisPanelName)
        end        

        % Setup the forcing data at the user defined timestep and input to
        % the GUI table.
        function onUpdateForcingData(this, thisPanelName)
            
            % Get time step value
            obj = findobj(this.(thisPanelName).resultsOptions.forcingPanel, 'Tag','Forcing plot calc timestep');
            timestepID = obj.Value;
            
            % Get the calculate for the time step aggregation
            obj = findobj(this.(thisPanelName).resultsOptions.forcingPanel, 'Tag','Forcing plot calc type');
            calcID = obj.Value;
            calcString = obj.String{calcID};            
            
            % check the start and end dates
            obj = findobj(this.(thisPanelName).resultsOptions.forcingPanel, 'Tag','Forcing plot calc start date');
            sdate = obj.String;
            obj = findobj(this.(thisPanelName).resultsOptions.forcingPanel, 'Tag','Forcing plot calc end date');
            edate = obj.String;            
            try
                if isempty(sdate)
                    sdate = datetime('01/01/0001','InputFormat','dd/MM/yyyy');
                else
                    sdate=datetime(sdate,'InputFormat','dd/MM/yyyy');
                end
            catch
               errordlg('The start date does not appear to be in the correct format of dd/mm/yyy.','Input date error ...');
               return;
            end
            try
                if isempty(edate)
                    edate= datetime('31/12/9999','InputFormat','dd/MM/yyyy');
                else                
                    edate = datetime(edate,'InputFormat','dd/MM/yyyy');
                end
            catch
               errordlg('The end date does not appear to be in the correct format of dd/mm/yyy.','Input date error ...');
               return;
            end            
            if sdate > edate
               errordlg('The end date must be after the start date.','Input date error ...');
               return;                
            end            
                        
            % Get daily input forcing data.
            tableData = this.(thisPanelName).resultsOptions.forcingData.data_input;
            forcingData_colnames = this.(thisPanelName).resultsOptions.forcingData.colnames_input;
                       
            % Exit if no data
            if isempty(tableData)
                return;
            end
            
            % Change cursor
            set(this.Figure, 'pointer', 'watch');      
            drawnow update;
            
            % Get daily model derived forcing data.
            tableData_derived = this.(thisPanelName).resultsOptions.forcingData.data_derived;
            forcingData_colnames_derived = this.(thisPanelName).resultsOptions.forcingData.colnames_derived;            
            tableData_derived_ndims = ndims(tableData_derived);
            nVariables = length(forcingData_colnames_derived);

            % Filter the table data by the input dates
            t = datetime(tableData(:,1),tableData(:,3),tableData(:,5));
            filt = t>=sdate & t<=edate;
            tableData = tableData(filt,:);
            if tableData_derived_ndims==3
                tableData_derived = tableData_derived(filt,:,:);
            else
                tableData_derived = tableData_derived(filt,:);
            end
            
            % Add filter to object for plotting            
            %this.tab_ModelCalibration.resultsOptions.forcingData.filt = filt;                        
            this.(thisPanelName).resultsOptions.forcingData.filt = filt;
            
            % Build forcing data at requested time step
            switch timestepID
                case 1  %daily
                    ind = transpose(1:size(tableData,1));
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
                    p = str2double(strrep(calcString,'th %ile',''));
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
            if tableData_derived_ndims==3
                % Build colume names without %iles
                forcingData_colnames_yaxis = [forcingData_colnames, forcingData_colnames_derived];
                
                % Upscale derived data
                for i=1:1:nVariables
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
                    upscaledData = [upscaledData, upscaledData_derived_prctiles]; %#ok<AGROW> 
                    
                    
                    % Build column names
                    forcingData_colnames = [forcingData_colnames, ...
                                            [forcingData_colnames_derived{i},'-05th%ile'], ...
                                            [forcingData_colnames_derived{i},'-10th%ile'], ...
                                            [forcingData_colnames_derived{i},'-25th%ile'], ...
                                            [forcingData_colnames_derived{i},'-50th%ile'], ...
                                            [forcingData_colnames_derived{i},'-75th%ile'], ...
                                            [forcingData_colnames_derived{i},'-90th%ile'], ...
                                            [forcingData_colnames_derived{i},'-95th%ile']];                %#ok<AGROW> 
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
                
                forcingData_colnames = [forcingData_colnames, forcingData_colnames_derived];
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
            this.(thisPanelName).resultsOptions.forcingPanel.Children.Children(3).Data = tableData;
            this.(thisPanelName).resultsOptions.forcingPanel.Children.Children(3).ColumnName = forcingData_colnames;
            
            % Disable calcs other than sum of using a daily time step
            objCalcType = findobj(this.(thisPanelName).resultsOptions.forcingPanel, 'Tag','Forcing plot calc type');
            objCalcType.Enable = 'on';
            if timestepID==1    %daily
                objCalcType.Value = 1;
                objCalcType.Enable = 'off';
            end

            % Update the types of box plots available for this time step
            % i.e. the box plot time step must be smaller than the timestep
            % for the data table. Calc cype also diabled if daily. Box
            % plots are not available for DREAM MCMC results.
            obj = findobj(this.(thisPanelName).resultsOptions.forcingPanel, 'Tag','Forcing plot type');            
            plotTypeOptons = {'line','scatter','bar','histogram','cdf','box-plot (daily metric)', ...
                'box-plot (monthly metric)','box-plot (quarterly metric)','box-plot (annual metric)'};
            calcTypeString = objCalcType.String(objCalcType.Value);
            calcTypeString = calcTypeString{1};            
            if tableData_derived_ndims==3
                plotTypeOptons = plotTypeOptons(1:5);
            else
                switch timestepID
                    case 1  %daily
                        plotTypeOptons = plotTypeOptons(1:5);
                        objCalcType.Value = 1;
                        objCalcType.Enable = 'off';
                    case {2, 3}  % weekly or monthly
                        if strcmp(calcTypeString,'sum')
                            plotTypeOptons = plotTypeOptons(1:6);
                        else
                            plotTypeOptons = plotTypeOptons(1:5);
                        end
                    case 4  % quarterly
                        if strcmp(calcTypeString,'sum')
                            plotTypeOptons = plotTypeOptons(1:7);
                        else
                            plotTypeOptons = [plotTypeOptons(1:5), plotTypeOptons(7)];
                        end
                    case 5  % annually
                        if strcmp(calcTypeString,'sum')
                            plotTypeOptons = plotTypeOptons(1:8);
                        else
                            plotTypeOptons = [plotTypeOptons(1:5), plotTypeOptons(7:8)];
                        end
                    case 6  % all data
                        if strcmp(calcTypeString,'sum')
                            plotTypeOptons = plotTypeOptons(1:9);
                        else
                            plotTypeOptons = [plotTypeOptons(1:5), plotTypeOptons(7:9)];
                        end
                    otherwise
                        error('Unknown forcing data time ste.')
                end
            end
            if obj.Value > length(plotTypeOptons)
                obj.Value = 1;
            end            
            obj.String = plotTypeOptons;

            % Get the plotting type again
            plotType_val = obj.Value;
            plotType = obj.String{plotType_val};
            
            % Setup each dropdown with variable names.
            Tage4AxisObj = {'Forcing plot x-axis', 'Forcing plot y-axis', 'Forcing plot x-axis denom', 'Forcing plot y-axis denom'};
            for i=1:length(Tage4AxisObj)

                % Get the currently selected axis options
                obj = findobj(this.(thisPanelName).resultsOptions.forcingPanel ,'Tag',Tage4AxisObj{i});
                forcingData_colnames_axis_prior = obj.String;
                forcingData_value_axis_prior = obj.Value(1);

                % Update the drop-down axis options
                if any(strfind(plotType,'box-plot')) && strcmp(Tage4AxisObj{i},'Forcing plot x-axis')
                    forcingData_colnames_axis = {'(none)', 'Date'};
                elseif any(strfind(plotType,'box-plot')) && strcmp(Tage4AxisObj{i},'Forcing plot x-axis denom')
                    forcingData_colnames_axis = {'(none)'};
                else
                    forcingData_colnames_axis = ['(none)', 'Date', forcingData_colnames_yaxis(6:end)];
                end
                obj.Value = 1;
                obj.String = forcingData_colnames_axis;

                % Update the selected axis item. To do this, the
                % original item is selected, else reset to 1.
                if ~isempty(forcingData_value_axis_prior ) && forcingData_value_axis_prior >0
                    ind = find(strcmp(forcingData_colnames_axis, forcingData_colnames_axis_prior{forcingData_value_axis_prior}));
                    if ~isempty(ind)
                        obj.Value = ind;
                    else
                        obj.Value = 1;
                    end                
                end

            end   
            
            % Update forcing plot
            onUpdateForcingPlot(this, thisPanelName)
            
            % Change cursor
            set(this.Figure, 'pointer', 'arrow');      
            drawnow update;
            
        end

        function onUpdateForcingPlotType(this, thisPanelName)
            
            % Get the forcing data columns
            forcingData_colnames = [this.(thisPanelName).resultsOptions.forcingData.colnames_input, ...
                this.(thisPanelName).resultsOptions.forcingData.colnames_derived];            
            
           % Remove those with %iles
           filt = cellfun(@(x) contains(x,'-05th%ile') || ...
                  contains(x,'-10th%ile') || ...
                  contains(x,'-25th%ile') || ...                                   
                  contains(x,'-50th%ile') || ...                                   
                  contains(x,'-75th%ile') || ...                                   
                  contains(x,'-90th%ile') || ...                                   
                  contains(x,'-95th%ile') ...                                   
                  ,forcingData_colnames);       
            if any(filt)
                forcingData_colnames_wpcntiles = forcingData_colnames(filt);  
                forcingData_colnames_wpcntiles = cellfun(@(x) x(1:length(x) - 9),forcingData_colnames_wpcntiles);
                forcingData_colnames_wpcntiles = unique(forcingData_colnames_wpcntiles );
                forcingData_colnames = [forcingData_colnames{~filt}, forcingData_colnames_wpcntiles];
            end
              
              
            % Get the plotting type
            obj = findobj(this.(thisPanelName).resultsOptions.forcingPanel, 'Tag','Forcing plot type');
            plotType_val = obj.Value;
            plotType = obj.String;
            plotType = plotType{plotType_val};

            % Get axis dropdown objects
            obj_xaxis = findobj(this.(thisPanelName).resultsOptions.forcingPanel ,'Tag','Forcing plot x-axis');
            obj_yaxis = findobj(this.(thisPanelName).resultsOptions.forcingPanel ,'Tag','Forcing plot y-axis');
            obj_xaxis_denom = findobj(this.(thisPanelName).resultsOptions.forcingPanel ,'Tag','Forcing plot x-axis denom');
            obj_yaxis_denom = findobj(this.(thisPanelName).resultsOptions.forcingPanel ,'Tag','Forcing plot y-axis denom');
            
            % Update the drop-down x and y axis options
            if any(strfind(plotType,'box-plot'))
                obj_xaxis.Value = 2;
                obj_xaxis_denom.Value = 1;
                forcingData_colnames_xaxis = {'(none)', 'Date'};   
                forcingData_colnames_xaxis_denom = {'(none)'};   
            else
                forcingData_colnames_xaxis = {'(none)', 'Date', forcingData_colnames{6:end}};
                forcingData_colnames_xaxis_denom = forcingData_colnames_xaxis;
            end
            forcingData_colnames_yaxis = {'(none)', 'Date', forcingData_colnames{6:end}};
            
            % Set dropdown strings
            obj_xaxis.String = forcingData_colnames_xaxis;
            obj_yaxis.String = forcingData_colnames_yaxis;
            obj_xaxis_denom.String = forcingData_colnames_xaxis_denom;
            obj_yaxis_denom.String = forcingData_colnames_yaxis;
        end
        
        function onUpdateForcingPlot(this, thisPanelName)
            
            % Change cursor
            set(this.Figure, 'pointer', 'watch');      
            %drawnow update;
                        
            % Turn on plot icons
            plotToolbarState(this,'on');
            
            % Get the calculate for the time step aggregation
            obj = findobj(this.(thisPanelName).resultsOptions.forcingPanel, 'Tag','Forcing plot calc type');
            calcID = obj.Value;
            calcString = obj.String(calcID);
            
            % Get the user plotting settings
            obj = findobj(this.(thisPanelName).resultsOptions.forcingPanel ,'Tag','Forcing plot type');
            plotType_str = obj.String{obj.Value};

            obj = findobj(this.(thisPanelName).resultsOptions.forcingPanel,'Tag','Forcing plot x-axis');
            xaxis_options = obj.String;
            xaxis_val = min(obj.Value, length(xaxis_options));
            xaxis_str = obj.String{xaxis_val};

            obj = findobj(this.(thisPanelName).resultsOptions.forcingPanel,'Tag','Forcing plot x-axis denom');
            xaxis_options_denom = obj.String;
            xaxis_val_denom = min(obj.Value, length(xaxis_options_denom));            

            obj = findobj(this.(thisPanelName).resultsOptions.forcingPanel,'Tag','Forcing plot y-axis');
            yaxis_options = obj.String;
            yaxis_val = min(obj.Value, length(yaxis_options));
            yaxis_str = obj.String{yaxis_val};

            obj = findobj(this.(thisPanelName).resultsOptions.forcingPanel,'Tag','Forcing plot y-axis denom');
            yaxis_options_denom = obj.String;
            yaxis_val_denom = min(obj.Value, length(yaxis_options_denom));            
                        
            % Get the data
            tableData = this.(thisPanelName).resultsOptions.forcingPanel.Children.Children(3).Data;
            forcingData_colnames = this.(thisPanelName).resultsOptions.forcingPanel.Children.Children(3).ColumnName;
            
            % Calc date
            if xaxis_val==1 || yaxis_val==1 || xaxis_val_denom==1 || yaxis_val_denom==1
                forcingDates = datetime(tableData(:,1), tableData(:,3), tableData(:,5));
            end
            
            %Check if a box plot is to be created
            plotType_isBoxPlot = false;
            if contains(plotType_str,'box-plot')
                plotType_isBoxPlot = true;
            end
            
            % Get axis data
            xdataHasErrorVals =  false;
            ydataHasErrorVals =  false;
            if strcmp(xaxis_str,'Date')
                xdata = forcingDates;
                xdataLabel = 'Date';
            elseif ~strcmp(xaxis_str,'(none)')
                
               % Get the data type to plot
               xdataLabel = xaxis_options{xaxis_val};
                
               % Find the  data columns with the requsted name and extract
               % comulns of data.
               filt = cellfun(@(x) contains(x,[xdataLabel,'-05th%ile']) || ...
                      contains(x,[xdataLabel,'-10th%ile']) || ...
                      contains(x,[xdataLabel,'-25th%ile']) || ...                                   
                      contains(x,[xdataLabel,'-50th%ile']) || ...                                   
                      contains(x,[xdataLabel,'-75th%ile']) || ...                                   
                      contains(x,[xdataLabel,'-90th%ile']) || ...                                   
                      contains(x,[xdataLabel,'-95th%ile']) ...                                   
                      ,forcingData_colnames);   
               if ~any(filt)
                    filt =  strcmp(forcingData_colnames,xdataLabel);
               end                  
               xdata =  tableData(:,filt);
               xdataHasErrorVals = sum(filt)>1;
                  
               % Get the data for the denominator (if not (none)).
               xdataLabel_denom = xaxis_options_denom{xaxis_val_denom};
               if ~strcmp(xdataLabel_denom,'(none)')
                   filt = cellfun(@(x) contains(x,[xdataLabel_denom,'-05th%ile']) || ...
                       contains(x,[xdataLabel_denom,'-10th%ile']) || ...
                       contains(x,[xdataLabel_denom,'-25th%ile']) || ...
                       contains(x,[xdataLabel_denom,'-50th%ile']) || ...
                       contains(x,[xdataLabel_denom,'-75th%ile']) || ...
                       contains(x,[xdataLabel_denom,'-90th%ile']) || ...
                       contains(x,[xdataLabel_denom,'-95th%ile']) ...
                       ,forcingData_colnames);
                   if ~any(filt)
                       filt =  strcmp(forcingData_colnames,xdataLabel_denom);
                   end
                   xdata_denom =  tableData(:,filt);
                   xdata = xdata./xdata_denom;
               end

               % Build the x-label
               if ~plotType_isBoxPlot
                   xdataLabel = [calcString{1},' of ',xdataLabel];
               end
               if ~strcmp(xdataLabel_denom,'(none)')
                   if ~plotType_isBoxPlot
                       xdataLabel_denom = [calcString{1},' of ',xdataLabel_denom];
                   end
                   xdataLabel = [xdataLabel, ' ', char(247),' ', xdataLabel_denom];
               end
               xdataLabel = strrep(xdataLabel,'_',' ');
            else
               xdata = [];
               xdataLabel = '(none)';
            end

            if strcmp(yaxis_str,'Date')
                ydata = forcingDates;
                ydataLabel = 'Date';
            elseif ~strcmp(yaxis_str,'(none)')
               % Get the data type to plot
               ydataLabel = yaxis_options{yaxis_val};
                
               % Find the  data columns with the requsted name and extract
               % comulns of data.
               filt = cellfun(@(x) contains(x,[ydataLabel,'-05th%ile']) || ...
                      contains(x,[ydataLabel,'-10th%ile']) || ...
                      contains(x,[ydataLabel,'-25th%ile']) || ...                                   
                      contains(x,[ydataLabel,'-50th%ile']) || ...                                   
                      contains(x,[ydataLabel,'-75th%ile']) || ...                                   
                      contains(x,[ydataLabel,'-90th%ile']) || ...                                   
                      contains(x,[ydataLabel,'-95th%ile']) ...                                   
                      ,forcingData_colnames);               
               if ~any(filt)
                    filt =  strcmp(forcingData_colnames,ydataLabel);
               end
               ydata =  tableData(:,filt);
               ydataHasErrorVals = sum(filt)>1;
               
               % Get the data for the denominator (if not (none)).
               ydataLabel_denom = yaxis_options_denom{yaxis_val_denom};
               if ~strcmp(ydataLabel_denom,'(none)')
                   filt = cellfun(@(x) contains(x,[ydataLabel_denom,'-05th%ile']) || ...
                       contains(x,[ydataLabel_denom,'-10th%ile']) || ...
                       contains(x,[ydataLabel_denom,'-25th%ile']) || ...
                       contains(x,[ydataLabel_denom,'-50th%ile']) || ...
                       contains(x,[ydataLabel_denom,'-75th%ile']) || ...
                       contains(x,[ydataLabel_denom,'-90th%ile']) || ...
                       contains(x,[ydataLabel_denom,'-95th%ile']) ...
                       ,forcingData_colnames);
                   if ~any(filt)
                       filt =  strcmp(forcingData_colnames,ydataLabel_denom);
                   end
                   ydata_denom =  tableData(:,filt);
                   ydata = ydata./ydata_denom;
               end
               
               % Build the y-label
               if ~plotType_isBoxPlot
                   ydataLabel = [calcString{1},' of ',ydataLabel];
               end
               if ~strcmp(ydataLabel_denom,'(none)')
                   if ~plotType_isBoxPlot
                       ydataLabel_denom = [calcString{1},' of ',ydataLabel_denom];
                   end
                   ydataLabel = [ydataLabel, ' ', char(247),' ',ydataLabel_denom];
               end
               ydataLabel = strrep(ydataLabel,'_',' ');
            else
               ydata = [];
               ydataLabel = '(none)';                
            end

            % Create an axis handle for the figure.
            if strcmp(thisPanelName,'tab_ModelCalibration')
                obj = findobj(this.(thisPanelName).resultsOptions.forcingPanel ,'Tag','Model Calibration - forcing plot panel');
            elseif strcmp(thisPanelName,'tab_ModelSimulation')
                obj = findobj(this.(thisPanelName).resultsOptions.forcingPanel ,'Tag','Model Simulation - forcing plot panel');
            end            
            delete( findobj(obj ,'type','axes'));
            delete( findobj(obj ,'type','legend'));
            obj = uipanel('Parent', obj,'BackgroundColor',[1,1,1]);
            axisHandle = axes( 'Parent', obj);

            % Exit if no data to plot (and not plotting a distrbution)
            if isempty(ydata) && any(strcmp(plotType_str,{'line','scatter','bar'}))
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
            
                        
            switch plotType_str
                case {'line','scatter'}     
                    plotSymbol = 'b.-';
                    if strcmp(plotType_str,'scatter')
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
                        legendstr{1} = '5-95th%ile';
                        hold(axisHandle,'on');                    
                        YFill = [ydata(:,2)', fliplr(ydata(:,6)')];                   
                        fill(XFill, YFill,[0.6 0.6 0.6],'Parent',axisHandle);                    
                        legendstr{2} = '10-90th%ile';
                        hold(axisHandle,'on');
                        YFill = [ydata(:,3)', fliplr(ydata(:,5)')];                   
                        fill(XFill, YFill,[0.4 0.4 0.4],'Parent',axisHandle);                    
                        legendstr{3} = '25-75th%ile';
                        hold(axisHandle,'on');
                        clear XFill YFill     

                        plot(axisHandle,xdata, ydata(:,4),plotSymbol);    
                        legendstr{4} = 'median';
                        
                        % Date date axis. NOTE, code adopted from dateaxis.m.
                        % Pre-2016B dateaxis did not allow input of axis
                        % handle.                        
                        if xdata_isdate
                            dateaxis_local(axisHandle,'x');
                        end
                        if ydata_isdate
                            dateaxis_local(axisHandle,'y');
                        end                
                        legend(axisHandle, legendstr,'Location', 'northeastoutside');
                        set(axisHandle,'Visible','on')                      
                        hold(axisHandle,'off');
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
                    
                case 'bar'
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
                    if xdata_isdate
                        dateaxis_local(axisHandle,'x');
                    end
                    if ydata_isdate
                        dateaxis_local(axisHandle,'y');
                    end
                    axis(axisHandle,'tight');
                case 'histogram'                    
                    if contains(ydataLabel,'(none)')
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
                    elseif ~strcmp(xdataLabel,'(none)') && ~strcmp(ydataLabel,'(none)')
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
                        if xdata_isdate
                            dateaxis_local(axisHandle,'x');
                        end
                        if ydata_isdate
                            dateaxis_local(axisHandle,'y');
                        end
                        if xdataHasErrorVals || ydataHasErrorVals
                            legend(axisHandle, 'Distribution of median','Location', 'northeastoutside');
                        end                        
                    end
                case 'cdf'
                    % Convert date is to be plotted
                    if xdata_isdate
                        xdata=datenum(xdata);
                    end
                    if ydata_isdate
                        ydata=datenum(ydata);
                    end

                    % Make CDF plot
                    if contains(ydataLabel,'(none)')
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
                    elseif ~strcmp(xdataLabel,'(none)') && ~strcmp(ydataLabel,'(none)')
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
                    if xdata_isdate
                        dateaxis_local(axisHandle,'x');
                    end
                    if ydata_isdate
                        dateaxis_local(axisHandle,'y');
                    end                       
                case {'box-plot (daily metric)','box-plot (monthly metric)','box-plot (quarterly metric)','box-plot (annual metric)'}      % Box plots at daily sum, monthly sum, 1/4 sum, annual sum
                    
                    if ydataHasErrorVals || xdataHasErrorVals
                        errordlg('HydroSight cannot create box plots of ensemble data (ie as derived from DREAM calibation).', 'Feature unavailable ...')
                        
                        % Change cursor
                        set(this.Figure, 'pointer', 'arrow');      
                        drawnow update;                        
                        
                        return
                    end
                    
                    % Check the x-axis is date
                    if xdata_isdate                  
                        xdata=datenum(xdata); %#ok<NASGU> 
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
                    tableData = [this.(thisPanelName).resultsOptions.forcingData.data_input, ...
                                 this.(thisPanelName).resultsOptions.forcingData.data_derived];                              

                    filt  = this.(thisPanelName).resultsOptions.forcingData.filt;
                    tableData = tableData(filt,:);
                    
                    % re-extract ydata
                    ydata = tableData(:,yaxis_val-2+5);
    
                    % Calculate time steps                    
                    tableData = [tableData(:,1:5),ydata];                           
                 
                    % Get the calculate for the time stepa aggregation
                    calcID = this.(thisPanelName).resultsOptions.forcingPanel.Contents.Contents(1).Contents(4).Value;
                    calcString = this.(thisPanelName).resultsOptions.forcingPanel.Contents.Contents(1).Contents(4).String;
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
                            p = str2double(strrep(calcString,'th %ile',''));
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

                    
                    % Sum the data to the required sum time step
                    switch plotType_str
                        case 'box-plot (daily metric)'
                            ind = transpose(1:size(tableData,1));
                            ydataLabel = [ydataLabel, ' (daily rate)'];
                        case 'box-plot (monthly metric)'
                            [~,~,ind] = unique(tableData(:,[1,3]),'rows');
                            ydataLabel = [ydataLabel, ' (monthly ',calcString,')'];
                        case 'box-plot (quarterly metric)'
                            [~,~,ind] = unique(tableData(:,[1,2]),'rows');   
                            ydataLabel = [ydataLabel, ' (quarterly ',calcString,')'];
                        case 'box-plot (annual metric)'
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
                    timestepID = this.(thisPanelName).resultsOptions.forcingPanel.Contents.Contents(1).Contents(2).Value;
                    
                    % Group the y-data to the next greatest time step
                    % Build foring data at requtested time step

                    % Build foring data at requtested time step
                    switch timestepID
                        case 1  %daily
                            ind = transpose(1:size(tableData,1));                            
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
                    if strcmp(plotType_str, 'box-plot (daily metric)')
                        boxplot(axisHandle,tableData(:,end), ind,'notch','on','ExtremeMode','clip','Jitter',0.75,'symbol','.');                    
                    else
                        boxplot(axisHandle,tableData(:,end), ind,'notch','off','ExtremeMode','clip','Jitter',0.75,'symbol','.');                    
                    end
                    
                    %Add x tick labels
                    if timestepID<6
                        tableData_year = double(accumarray(ind,tableData(:,1),[],@max));
                        tableData_month = double(accumarray(ind,tableData(:,3),[],@max));            
                        tableData_day = double(accumarray(ind,tableData(:,5),[],@(x) x(end)));
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
        function modelCalibration_onUpdateDerivedData(this, ~, ~)
       
            % Record the current row and column numbers
            irow = this.tab_ModelCalibration.currentRow;

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
                obj = uipanel('Parent', obj,'BackgroundColor',[1,1,1]);
                axisHandle = axes( 'Parent',obj);                

                % Get length of forcing data.
                t = getForcingData(tmpModel);
                t = transpose(1:(max(t(:,1))-min(t(1,1))));

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
            % Get GUI table indexes
            icol=eventdata.Indices(:,2);
            irow=eventdata.Indices(:,1);            
            
            % Record the current row and column numbers
            this.tab_ModelSimulation.currentRow = irow;
            this.tab_ModelSimulation.currentCol = icol;
               
            % Undertake column specific operations.
            if ~isempty(icol) && ~isempty(irow)
                
                % Record the current row and column numbers
                this.tab_ModelSimulation.currentRow = irow;
                this.tab_ModelSimulation.currentCol = icol;
            
                % Remove HTML tags from the column name
                columnName = HydroSight_GUI.removeHTMLTags(eventdata.Source.ColumnName{icol});
                
                % Warn the user if the simulation is already complete and the
                % inputs are to change - requiring the model simulation to to be reset.
                if ~isempty(hObject.Data)
                    if strcmp(columnName, 'Model Label') || ...
                            strcmp(columnName,'Simulation Label') || ...
                            strcmp(columnName, 'Forcing Data File') || ...
                            strcmp(columnName, 'Simulation Start Date') || ...
                            strcmp(columnName, 'Simulation End Date') || ...
                            strcmp(columnName, 'Simulation Time Step') || ...
                            strcmp(columnName, 'Krig Sim. Residuals?')

                        % Check if the model is build.
                        modelLabel = hObject.Data{irow,2};
                        simLabel = hObject.Data{irow,6};
                        doBuildCheck = false;
                        doCalibrationCheck = false;
                        doSimulationCheck = true;
                        if ~isempty(modelLabel)
                            status =  checkEdit2Model(this, modelLabel, simLabel, doBuildCheck, doCalibrationCheck, doSimulationCheck);
                            if status==0
                                % Return if the user has responded that no changes are to be made.
                                return;
                            end
                        end

                        % Re-get the data cell array of the table
                        hObject.Data = get(hObject,'Data');
                    end
                end

                % Change cursor
                set(this.Figure, 'pointer', 'watch');
                drawnow update;

                switch columnName
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
                        
                        % Assign data from the calbration table to the simulation
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
                        hObject.Data{irow,12} = '<html><font color = "#FF0000">Not simulated.</font></html>';
                        
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
                            h = warndlg('The model and simulation label pair must be unique. An modified label has been input','Label error');
                            setIcon(this, h);
                        end                        
                end
            end
            
            set(this.Figure, 'pointer', 'arrow');
            drawnow update;                            

        end 
               
        function modelSimulation_onUpdatePlotSetting(this, ~, ~, tmpModel, simLabel)
            
            % Get the current model if not input
            if nargin<=3                            
                [tmpModel, simLabel]= modelSimulation_getCurrentModel(this);
            end

            % Get selected plot
            obj = findobj(this.tab_ModelSimulation.resultsOptions.simPanel,'Tag','Model Simulation - results plot dropdown');            
            selectedDropDown = obj.Value;
            if selectedDropDown>length(obj.String)
                selectedDropDown = 1;
                obj.Value = selectedDropDown;
            end
            
            % Update plot
            obj = findobj(this.tab_ModelSimulation.resultsOptions.simPanel,'Tag','Model Simulation - results plot');
            
            delete( findobj(obj ,'type','axes'));
            delete( findobj(obj ,'type','legend'));            
            obj = uipanel('Parent', obj,'BackgroundColor',[1,1,1]);
            axisHandle = axes( 'Parent', obj);
            
            % Plot the simulation data using the axis handles
            solveModelPlotResults(tmpModel, simLabel, axisHandle, selectedDropDown-1);
                       
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
            
            % Record the current row and column numbers
            this.tab_ModelSimulation.currentRow = irow;
            this.tab_ModelSimulation.currentCol = icol;            
            
            % Get table data
            data=get(hObject,'Data');
            
            % Warn the user if the simulation is already complete and the
            % inputs are to change - requiring the model simulation to to be reset.
            if ~isempty(hObject.Data)
                if strcmp(columnName, 'Model Label') || ...
                        strcmp(columnName,'Simulation Label') || ...
                        strcmp(columnName, 'Forcing Data File') || ...
                        strcmp(columnName, 'Simulation Start Date') || ...
                        strcmp(columnName, 'Simulation End Date') || ...
                        strcmp(columnName, 'Simulation Time Step') || ...
                        strcmp(columnName, 'Krig Sim. Residuals?')

                    % Check if the model is build.
                    modelLabel = hObject.Data{irow,2};
                    simLabel = hObject.Data{irow,6};
                    simTimestep = hObject.Data{irow,10};
                    doBuildCheck = false;
                    doCalibrationCheck = false;
                    doSimulationCheck = true;
                    if ~isempty(modelLabel)
                        status =  checkEdit2Model(this, modelLabel, simLabel, doBuildCheck, doCalibrationCheck, doSimulationCheck);
                        if status==0
                            % Return if the user has responded that no changes are to be made.
                            if icol==2
                                hObject.Data{irow,icol} = modelLabel;
                            end
                            if icol==10
                                hObject.Data{irow,icol} = simTimestep;
                            end
                            return;
                        end
                    end

                    % Re-get the data cell array of the table
                    data=get(hObject,'Data');
                end
            end
            
            % Change cursor
            set(this.Figure, 'pointer', 'watch');                
            drawnow update;            

            switch columnName
                case 'Model Label'
                    % Check if there are any built models. If not, return.
                    if isempty(this.models)
                        hObject.ColumnFormat{2} = {'(none calibrated)'};
                        return;
                    end

                    % Get list of models
                    model_label = fieldnames(this.models);
                    
                    % Get list of those that are calibrated
                    filt = false(length(model_label),1);
                    for i=1:length(model_label)                                                                         
                        try
                            % Convert model label to field label.
                            model_labelAsField = HydroSight_GUI.modelLabel2FieldName(model_label{i});

                            % Check if model is calibrated
                            filt(i) = this.model_labels{model_labelAsField, 'isCalibrated'};
                        catch
                            filt(i) = false;
                        end
                    end                    
                    model_label = model_label(filt);

                    % Convert model labels from a variable name to the full
                    % label (ie without _ chars etc)
                    for i=1:length(model_label)    
                        model_label{i} = this.models.(model_label{i}).model_label;
                    end

                    % Assign calib model labels to drop down
                    hObject.ColumnFormat{2} = model_label';   

                    % Update status in GUI
                    drawnow update

                case 'Forcing Data File'

                    % Get file name and remove project folder from
                    % preceeding full path.
                    fName = getFileName(this, 'Select the Forcing Data file.');
                    if fName~=0
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
                    if ~this.model_labels{calibLabel, 'isCalibrated'}
                        set(this.Figure, 'pointer', 'arrow');
                        drawnow update;                            
                        h = warndlg('A calibrated model must be first selected from the "Model Label" column.', 'Selection error');
                        setIcon(this, h);
                        return;
                    end

                    % Get the forcing data for the model.
                    % If a new forcing data file is given, then open it
                    % up and get the start and end dates from it.
                    if isempty( data{irow,7}) || strcmp(data{irow,7},'')                            
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
                        if exist(fname,'file') ~= 2   
                            set(this.Figure, 'pointer', 'arrow');
                            drawnow update;                                  
                            h = warndlg('The new forcing date file could not be open for examination of the start and end dates.', 'File error');
                            setIcon(this, h);
                            return;
                        end

                        % Read in the file.
                        try
                           forcingData = readtable(fname);
                        catch           
                            set(this.Figure, 'pointer', 'arrow');
                            drawnow update;                                  
                            h = warndlg('The new forcing date file could not be imported for extraction of the start and end dates. Please check its format.', 'File error');
                            setIcon(this, h);
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
                            h = warndlg('The dates from the new forcing data file could not be calculated. Please check its format.', 'File error');
                            setIcon(this, h);
                            return;                                
                        end
                    end

                    % Open the calander with the already input date,
                    % else use the start date of the obs. head.
                    if isempty(data{irow,icol})
                        inputDate = startDate;                            
                    else
                        try
                            inputDate = datenum( data{irow,icol},'dd-mmm-yyyy');
                        catch
                            inputDate = startDate;
                        end
                    end
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update;                          

                    if strcmp(columnName, 'Simulation Start Date')
                        selectedDate = uical(inputDate, 'English',startDate, endDate, this.figure_icon, 'Start date');
                    else
                        selectedDate = uical(inputDate, 'English',startDate, endDate, this.figure_icon, 'End date');
                    end

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
                            h = warndlg('The simulation start date must be within the range of the observed forcing data.','Date error');
                            setIcon(this, h);
                            return;
                        elseif selectedDate>=simEndDate
                            set(this.Figure, 'pointer', 'arrow');
                            drawnow update;                                                          
                            h = warndlg('The simulation start date must be less than the simulation end date.','Date error');
                            setIcon(this, h);
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
                            h = warndlg('The simulation end date must be within the range of the observed forcing data.','Date error');
                            setIcon(this, h);
                        elseif selectedDate<=simStartDate
                            h = warndlg('The simulation end date must be less than the simulation end date.','Date error');
                            setIcon(this, h);
                        else
                            data{irow,icol} = datestr(selectedDate,'dd-mmm-yyyy');
                            set(hObject,'Data',data);
                        end

                    end

                otherwise
                    % Do nothing
            end

            % Show the simulation status
            if isempty(data{irow,12})
                simTableStatus = 'Not simulated.';
            else
                simTableStatus = HydroSight_GUI.removeHTMLTags(data{irow,12});
            end
            simTableStatus = ['Simulation Status: ',simTableStatus , char newline, char newline];
            obj = findobj(this.tab_ModelSimulation.resultsTabs, 'Tag','Model Simulation - status box');
                set(obj,'String',simTableStatus);
            this.tab_ModelSimulation.resultsTabs.TabEnables{1} = 'on';
                    
            set(this.Figure, 'pointer', 'watch');
            drawnow update;
            
            % Get the current model
            try
                [tmpModel, simLabel, simInd]= modelSimulation_getCurrentModel(this);
            catch 
                h = warndlg('The selected simulation could not be found. Please try re-running the simulation.','Unexpected error');
                setIcon(this, h);
                return;
            end
              
            % Display the requested simulation results if the model object
            % exists and there are simulation results.
            if ~isempty(simInd) && ~isempty(tmpModel) && isfield(tmpModel.simulationResults{simInd,1},'head') && ...
                    ~isempty(tmpModel.simulationResults{simInd,1}.head )             
                                
                % Get the model simulation data.
                tableData = tmpModel.simulationResults{simInd,1}.head;

                % Get the forcing variable names
                forcingVariablesName = tmpModel.simulationResults{simInd,1}.colnames(2:end);

                % Update simulation status with model data                
                simTableStatus = [simTableStatus, 'Simulation start & end date: ',datestr(tableData(1,1),'dd-mmm-yyyy'), ...
                    ' to ',datestr(tableData(end,1),'dd-mmm-yyyy'), char newline];

                simTableStatus = [simTableStatus, 'Simulation minimum time step (days): ',num2str(min(diff(tableData(:,1)))), char newline];
                simTableStatus = [simTableStatus, 'Simulation mean time step (days): ',num2str(mean(diff(tableData(:,1)))), char newline];
                simTableStatus = [simTableStatus, 'Simulation maximum time step (days): ',num2str(max(diff(tableData(:,1)))), char newline];

                if length(forcingVariablesName)>1 && strcmp(forcingVariablesName{end-1},'Kriging Adjustment')
                    simTableStatus = [simTableStatus, 'Kriging of residuals to match observations?: true', char newline];
                else 
                    simTableStatus = [simTableStatus, 'Kriging of residuals to match observations?: false', char newline];
                end
                set(obj,'String',simTableStatus);


                % Setup the simulation data and plot (i.e. not the forcing data)
                %----------------------------------------------------------                                
                
                % Update drop-down list of forcing variables to
                % plot.
                obj = findobj(this.tab_ModelSimulation.resultsOptions.simPanel,'Tag','Model Simulation - results plot dropdown');
                obj.String = forcingVariablesName;
                
                % Calculate year, month, day etc
                tableData = [year(tableData(:,1)), month(tableData(:,1)), day(tableData(:,1)), hour(tableData(:,1)), minute(tableData(:,1)), tableData(:,2:end)];
                
                % Convert to a table data type and add data to the table.
                obj = findobj(this.tab_ModelSimulation.resultsOptions.simPanel,'Tag','Model Simulation - results table');
                obj.Data = tableData;
                
                if size(tmpModel.calibrationResults.parameters.params_final,2)==1
                    obj.ColumnName = [{'Year'},{'Month'},{'Day'},{'Hour'},{'Minute'},forcingVariablesName(:)'];
                else
                    % Create column names
                    colnames={};
                    for i=1:length(forcingVariablesName)
                        colnames = [colnames, [forcingVariablesName{i},'-50th %ile']]; %#ok<AGROW> 
                        colnames = [colnames, [forcingVariablesName{i},'-5th %ile']]; %#ok<AGROW> 
                        colnames = [colnames, [forcingVariablesName{i},'-95th %ile']]; %#ok<AGROW> 
                    end
                    
                    % Convert to a table data type and add data to the table.
                    obj.ColumnName = [{'Year'},{'Month'},{'Day'},{'Hour'},{'Minute'},colnames(:)'];
                end
                
                % Update plot
                plotToolbarState(this,'on');
                modelSimulation_onUpdatePlotSetting(this, hObject, eventdata, tmpModel, simLabel);
                this.tab_ModelSimulation.resultsTabs.TabEnables{2} = 'on';
               
                % Setup the forcing results for the simulation.
                % Note, the forcing results are only shown if the
                % simulation uses new forcing data, else the tab is
                % disabled and blank data is input.
                %----------------------------------------------------------
                
                obj = findobj(this.tab_ModelSimulation.resultsOptions.forcingPanel,'Tag','Model Simulation - forcing table');
                
                fname = data{irow,7};
                if isempty(fname)
                    this.tab_ModelSimulation.resultsTabs.TabEnables{3}= 'off';
                    obj.Data = cell(0,size(obj.Data,2));
                    %this.tab_ModelSimulation.resultsTabs.Selection=1;
                else 
                    this.tab_ModelSimulation.resultsTabs.TabEnables{3}= 'on';
                    
                    % Get the simulation input forcing data
                    tableData_input = tmpModel.simulationResults{simInd,1}.data_input;
                    tableData_colnames_input = tmpModel.simulationResults{simInd,1}.colnames_input;                   
                    tableData_derived = tmpModel.simulationResults{simInd,1}.data_derived;
                    tableData_colnames_derived = tmpModel.simulationResults{simInd,1}.colnames_derived;

                     % Calculate year, month, day etc
                    t = datetime(tableData_input(:,1), 'ConvertFrom','datenum');
                    tableData_input = [year(t), quarter(t), month(t), week(t,'weekofyear'), day(t), tableData_input(:,2:end)];
                    tableData_colnames_input = {'Year','Quarter','Month','Week','Day', tableData_colnames_input{2:end}};

                    % Store the daily forcing data. This is just done to
                    % avoid re-loading the model within modelSimulation_onUpdateForcingData()
                    this.tab_ModelSimulation.resultsOptions.forcingData.data_input = tableData_input;
                    this.tab_ModelSimulation.resultsOptions.forcingData.data_derived = tableData_derived;
                    this.tab_ModelSimulation.resultsOptions.forcingData.colnames_input = tableData_colnames_input;
                    this.tab_ModelSimulation.resultsOptions.forcingData.colnames_derived = tableData_colnames_derived;
                    this.tab_ModelSimulation.resultsOptions.forcingData.filt=true(size(tableData,1),1);

                    % TO DO: Fix setup of tables and plots
                    modelSimulation_onUpdateForcingData(this);
                end

                % Show completed plots
                this.tab_ModelSimulation.resultsTabs.Visible = 1;                
            else
                this.tab_ModelSimulation.resultsTabs.TabEnables = {'on';'off';'off'};
            end
                        
            % Change to pointer
            set(this.Figure, 'pointer', 'arrow');
            drawnow update;
        end        
        
        function modelSimulation_onResultsSelection(this, hObject, ~)
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
        function onApplyModelOptions(this, ~, ~)
            
            % Change cursor
            set(this.Figure, 'pointer', 'watch');   
            drawnow update;    
            
            try
                % get the new model options
                irow = this.tab_ModelConstruction.currentRow;
                modelType = this.tab_ModelConstruction.Table.Data{irow,8};
                modelOptionsArray = getModelOptions(this.tab_ModelConstruction.modelTypes.(modelType).obj);            

                % Warn the user if the model is already built and the
                % inputs are to change - reuiring the model object to be
                % removed.                            
                if ~isempty(this.tab_ModelConstruction.Table.Data{irow,8}) && ...
                ~strcmp(modelOptionsArray, this.tab_ModelConstruction.Table.Data{irow,9} )

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
                        response = questdlg_timer(this.figure_icon,15,msg,'Overwrite existing model?','Yes','No','No');
                        
                        % Check if 'cancel, else delete the model object
                        if isempty(response) || strcmp(response,'No')
                            return;
                        end

                        % Change status of the model object.
                        this.tab_ModelConstruction.Table.Data{irow,end} = '<html><font color = "#FF0000">Not built.</font></html>';

                        % Delete model from calibration table.
                        modelLabels_calibTable =  this.tab_ModelCalibration.Table.Data(:,2);                            
                        modelLabels_calibTable = HydroSight_GUI.removeHTMLTags(modelLabels_calibTable);
                        ind = cellfun( @(x) strcmp(x,modelLabel), modelLabels_calibTable);
                        this.tab_ModelCalibration.Table.Data = this.tab_ModelCalibration.Table.Data(~ind,:);

                        % Update row numbers
                        nrows = size(this.tab_ModelCalibration.Table.Data,1);
                        this.tab_ModelCalibration.Table.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));                     

                        % Delete models from simulations table.
                        if ~isempty(this.tab_ModelSimulation.Table.Data)
                            modelLabels_simTable =  this.tab_ModelSimulation.Table.Data(:,2);
                            modelLabels_simTable = HydroSight_GUI.removeHTMLTags(modelLabels_simTable);
                            ind = cellfun( @(x) strcmp(x,modelLabel), modelLabels_simTable);
                            this.tab_ModelSimulation.Table.Data = this.tab_ModelSimulation.Table.Data(~ind,:);
                        end

                        % Update row numbers
                        nrows = size(this.tab_ModelSimulation.Table.Data,1);
                        this.tab_ModelSimulation.Table.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));                     
                    end
                end

                % Apply new model options.
                this.tab_ModelConstruction.Table.Data{this.tab_ModelConstruction.currentRow,9} = modelOptionsArray;
                
                % Change cursor
                set(this.Figure, 'pointer', 'arrow');   
                drawnow update                
            catch 
                % Change cursor
                set(this.Figure, 'pointer', 'arrow');   
                drawnow update                
                
                errordlg('The model options could not be applied to the model. Please check the model options are sensible.');
            end

        end
        
        % Get the model options cell array (as a string).
        function onApplyModelOptions_selectedBores(this, ~, ~)
            
            try
                % Get the current model type.
                modelTypeColNum = 8;
                modelOptionsColNum = 9;
                currentModelType = this.tab_ModelConstruction.Table.Data{this.tab_ModelConstruction.currentRow, modelTypeColNum};

                % Get list of selected bores.
                selectedBores = this.tab_ModelConstruction.Table.Data(:,1);

                % Check some bores have been selected.
                if ~any(cellfun(@(x) x, selectedBores))
                    h = warndlg('No models are selected.', 'Selection error');
                    setIcon(this, h);
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
                for i=1:length(selectedBores)
                    if selectedBores{i} && strcmp(this.tab_ModelConstruction.Table.Data{i,modelTypeColNum}, currentModelType)

                        % Warn the user if the model is already built and the
                        % inputs are to change - reuiring the model object to be
                        % removed.            
                        if ~isempty(this.tab_ModelConstruction.Table.Data{i,modelOptionsColNum}) && ...
                        ~strcmp(modelOptionsArray, this.tab_ModelConstruction.Table.Data{i,modelOptionsColNum} )

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

                                    response = questdlg_timer(this.figure_icon,15,msg,'Overwrite existing model?','Yes','Yes - all models','No','No');
                                    
                                    % Check if 'cancel, else delete the model object
                                    if isempty(response) || strcmp(response,'No')
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
                                this.tab_ModelCalibration.Table.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));                                   

                                % Delete models from simulations table.
                                modelLabels_simTable =  this.tab_ModelSimulation.Table.Data(:,2);                            
                                modelLabels_simTable = HydroSight_GUI.removeHTMLTags(modelLabels_simTable);
                                ind = cellfun( @(x) strcmp(x,modelLabel), modelLabels_simTable);
                                this.tab_ModelSimulation.Table.Data = this.tab_ModelSimulation.Table.Data(~ind,:);

                                % Update row numbers
                                nrows = size(this.tab_ModelSimulation.Table.Data,1);
                                this.tab_ModelSimulation.Table.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));                              

                            end
                        end                    

                        % Apply model option.
                        this.tab_ModelConstruction.Table.Data{i,modelOptionsColNum} = modelOptionsArray;            
                        
                        % Change status of the model object.
                        this.tab_ModelConstruction.Table.Data{i,end} = '<html><font color = "#FF0000">Not built.</font></html>';
                        
                        nOptionsCopied = nOptionsCopied + 1;
                    end
                end            

                % Change cursor
                set(this.Figure, 'pointer', 'arrow');   
                drawnow update;                
                
                h = msgbox(['The model options were copied to ',num2str(nOptionsCopied), ' "', currentModelType ,'" models.'], 'Model options applied');
                setIcon(this, h);
            catch                
                % Change cursor
                set(this.Figure, 'pointer', 'arrow');   
                drawnow update;                
                
                errordlg('The model options could not be applied to the selected models. Please check the model options are sensible.');
            end

        end

        function onAnalyseBores(this, ~, ~)           
                            
            % Hide plot icons
            plotToolbarState(this,'off');            
            
            % Get table data
            data = this.tab_DataPrep.Table.Data;

            % Check the bore IDs are unique
            boreIDs = this.tab_DataPrep.Table.Data(:,3);
            if length(unique(boreIDs)) ~= length(boreIDs)
                set(this.Figure, 'pointer', 'arrow');
                errordlg('The bore IDs are not unique. Remove duplicates IDs.','Dubplicate bore IDs','modal');
                return;
            end
            % Get list of selected bores.
            selectedBores = data(:,1);

            % Change cursor to arrow
            set(this.Figure, 'pointer', 'watch');
            drawnow update
           
            % Count the number of models selected
            nModels=0;
            for i=1:length(selectedBores)                              
                if ~isempty(selectedBores{i}) && selectedBores{i}
                    nModels = nModels +1;
                end
            end                         
            if nModels==0            
                set(this.Figure, 'pointer', 'arrow');
                h = warndlg('No bores selected for analysis.','No bores analysed','modal');
                setIcon(this, h);
                return;
            end


            % Loop  through the list of selected bore and apply the modle
            % options.
            nAnalysisFailed = 0;
            nBoreNotInHeadFile=0;
            nBoreInputsError = 0;
            nBoreIDLabelError = 0;
            ind = false(length(selectedBores),1);    
            headData = cell(length(selectedBores),1);
            boreDepth = inf(length(selectedBores),1);
            surfaceElevation = inf(length(selectedBores),1);
            caseLength = inf(length(selectedBores),1);
            constructionDate = zeros(length(selectedBores),1);
            checkStartDate = false(length(selectedBores),1);
            checkEndDate = false(length(selectedBores),1);
            checkMinHead = false(length(selectedBores),1);
            checkMaxHead = false(length(selectedBores),1);
            rateOfChangeThreshold = inf(length(selectedBores),1);
            constHeadDuration = inf(length(selectedBores),1);
            numNoiseStdDev = inf(length(selectedBores),1);
            outlierForwadBackward = false(length(selectedBores),1);
            for i=1:length(selectedBores)
                % Check if the model is to be built.
                if isempty(selectedBores{i}) ||  ~selectedBores{i}
                    continue;
                end
                ind(i) = true;

                % Update table with progress'
                this.tab_DataPrep.Table.Data{i, 16} = '<html><font color = "#FFA500">Analysing bore ...</font></html>';
                this.tab_DataPrep.Table.Data{i,17} = ['<html><font color = "#808080">','(NA)','</font></html>'];
                this.tab_DataPrep.Table.Data{i,18} = ['<html><font color = "#808080">','(NA)','</font></html>'];
                    
                % Update status in GUI
                drawnow;
                
                % Import head data
                %----------------------------------------------------------
                % Check the obs. head file is listed
                if isfolder(this.project_fileName)                             
                    fname = fullfile(this.project_fileName,data{i,2}); 
                else
                    fname = fullfile(fileparts(this.project_fileName),data{i,2});  
                end                
                if isempty(fname)                    
                    this.tab_DataPrep.Table.Data{i, 16} = '<html><font color = "#FF0000">Head data file error - file name empty.</font></html>';
                    nAnalysisFailed = nAnalysisFailed + 1;
                    ind(i) = false;
                    continue;
                end

                % Check the bore ID file exists.
                if exist(fname,'file') ~= 2                    
                    this.tab_DataPrep.Table.Data{i, 16} = '<html><font color = "#FF0000">Head data file error - file does not exist.</font></html>';
                    nAnalysisFailed = nAnalysisFailed + 1;
                    ind(i) = false;
                    continue;
                end

                % Read in the observed head file.
                try
                    tbl = readtable(fname);
                catch                    
                    this.tab_DataPrep.Table.Data{i, 16} = '<html><font color = "#FF0000">Head data file error - read in failed.</font></html>';
                    nAnalysisFailed = nAnalysisFailed + 1;
                    ind(i) = false;
                    continue;
                end                
                
                % Filter for the required bore.
                boreID{i} = data{i,3}; %#ok<AGROW> 
                filt =  strcmp(tbl{:,1},boreID{i});
                if sum(filt)<=0
                    this.tab_DataPrep.Table.Data{i, 16} = '<html><font color = "#FF0000">Bore not found in head data file - data error.</font></html>';
                    nBoreNotInHeadFile = nBoreNotInHeadFile +1;
                    ind(i) = false;
                    continue
                end
                headData_tmp = tbl(filt,2:end);
                headData{i} = sortrows(headData_tmp{:,:}, 1:(size(headData_tmp,2)-1),'ascend');          
                %----------------------------------------------------------
                                
                % Get required inputs for analysis
                %----------------------------------------------------------                
                dataCol=4;
                if ~isnumeric(this.tab_DataPrep.Table.Data{i, dataCol})
                    this.tab_DataPrep.Table.Data{i, 16} = ['<html><font color = "#FF0000">Input for column ', num2str(dataCol), ' must be a number. </font></html>'];
                    nBoreInputsError = nBoreInputsError +1;
                    ind(i) = false;
                    continue
                end
                if ~isempty(this.tab_DataPrep.Table.Data{i, dataCol}) && this.tab_DataPrep.Table.Data{i, dataCol}>0
                    boreDepth(i) = this.tab_DataPrep.Table.Data{i, dataCol};
                end
                                
                dataCol = 5;
                if ~isnumeric(this.tab_DataPrep.Table.Data{i, dataCol})
                    this.tab_DataPrep.Table.Data{i, 16} = ['<html><font color = "#FF0000">Input for column ', num2str(dataCol), ' must be a number. </font></html>'];
                    nBoreInputsError = nBoreInputsError +1;
                    ind(i) = false;
                    continue
                end                
                if ~isempty(this.tab_DataPrep.Table.Data{i, dataCol})
                    surfaceElevation(i) = this.tab_DataPrep.Table.Data{i, dataCol};
                end
                                
                dataCol = 6;
                if ~isnumeric(this.tab_DataPrep.Table.Data{i, dataCol})
                    this.tab_DataPrep.Table.Data{i, 16} = ['<html><font color = "#FF0000">Input for column ', num2str(dataCol), ' must be a number. </font></html>'];
                    nBoreInputsError = nBoreInputsError +1;
                    ind(i) = false;
                    continue
                end                
                if ~isempty(this.tab_DataPrep.Table.Data{i, dataCol}) && this.tab_DataPrep.Table.Data{i, dataCol}>0
                    caseLength(i) = this.tab_DataPrep.Table.Data{i, dataCol};
                end
                                
                dataCol = 7;
                if ~isempty(this.tab_DataPrep.Table.Data{i, dataCol})
                    try
                        constructionDate(i) = datenum(this.tab_DataPrep.Table.Data{i, dataCol},'dd-mmm-yyyy');
                        if constructionDate(i) > (now()+1) || constructionDate(i) < datenum(1500,1,1)
                            nBoreInputsError = nBoreInputsError +1;
                            ind(i) = false;
                            continue;
                        end
                    catch
                        this.tab_DataPrep.Table.Data{i, 16} = '<html><font color = "#FF0000">Construction date error - date format must be dd-mmm-yyyy (e.g. 20-Dec-2010).</font></html>';
                        nBoreInputsError = nBoreInputsError +1;
                        ind(i) = false;
                        continue
                    end
                end   
                                
                dataCol = 8;               
                if ~isempty(this.tab_DataPrep.Table.Data{i, dataCol})
                    checkStartDate(i) = this.tab_DataPrep.Table.Data{i, dataCol};
                end                
                
                dataCol = 9;               
                if ~isempty(this.tab_DataPrep.Table.Data{i, dataCol})
                    checkEndDate(i) = this.tab_DataPrep.Table.Data{i, dataCol};
                end       
                                
                dataCol = 10;               
                if ~isempty(this.tab_DataPrep.Table.Data{i, dataCol})
                    checkMinHead(i) = this.tab_DataPrep.Table.Data{i, dataCol};
                end       
                
                dataCol = 11;               
                if ~isempty(this.tab_DataPrep.Table.Data{i, dataCol})
                    checkMaxHead(i) = this.tab_DataPrep.Table.Data{i, dataCol};
                end         
                                                
                dataCol = 12;
                if ~isnumeric(this.tab_DataPrep.Table.Data{i, dataCol})
                    this.tab_DataPrep.Table.Data{i, 16} = ['<html><font color = "#FF0000">Input for column ', num2str(dataCol), ' must be a number. </font></html>'];
                    nBoreInputsError = nBoreInputsError +1;
                    ind(i) = false;
                    continue
                end                
                if ~isempty(this.tab_DataPrep.Table.Data{i, dataCol}) && this.tab_DataPrep.Table.Data{i, dataCol}>0
                    rateOfChangeThreshold(i) = this.tab_DataPrep.Table.Data{i, dataCol};
                end      
                                
                dataCol = 13;
                if ~isnumeric(this.tab_DataPrep.Table.Data{i, dataCol})
                    this.tab_DataPrep.Table.Data{i, 16} = ['<html><font color = "#FF0000">Input for column ', num2str(dataCol), ' must be a number. </font></html>'];
                    nBoreInputsError = nBoreInputsError +1;
                    ind(i) = false;
                    continue
                end                
                if ~isempty(this.tab_DataPrep.Table.Data{i, dataCol}) && this.tab_DataPrep.Table.Data{i, dataCol}>0
                    constHeadDuration(i) = this.tab_DataPrep.Table.Data{i, dataCol};
                end
                                
                dataCol = 14;
                if ~isnumeric(this.tab_DataPrep.Table.Data{i, dataCol})
                    this.tab_DataPrep.Table.Data{i, 16} = ['<html><font color = "#FF0000">Input for column ', num2str(dataCol), ' must be a number. </font></html>'];
                    nBoreInputsError = nBoreInputsError +1;
                    ind(i) = false;
                    continue
                end                
                if ~isempty(this.tab_DataPrep.Table.Data{i, dataCol}) && this.tab_DataPrep.Table.Data{i, dataCol}>0
                    numNoiseStdDev(i) = this.tab_DataPrep.Table.Data{i, dataCol};
                end    
                                                
                dataCol = 15;               
                if ~isempty(this.tab_DataPrep.Table.Data{i, dataCol})
                    outlierForwadBackward(i) = this.tab_DataPrep.Table.Data{i, dataCol};
                end                    
                %----------------------------------------------------------
                                
                % Convert boreID string to appropriate field name and test
                % if is can be converted to a field name
                boreID_label =boreID{i};
                boreID{i} = strrep(boreID{i},' ','_'); %#ok<AGROW> 
                boreID{i} = strrep(boreID{i},'-','_'); %#ok<AGROW> 
                boreID{i} = strrep(boreID{i},'?','');  %#ok<AGROW> 
                boreID{i} = strrep(boreID{i},'\','_'); %#ok<AGROW> 
                boreID{i} = strrep(boreID{i},'/','_'); %#ok<AGROW> 
                try 
                    tmp.(boreID{i}) = [1 2 3]; %#ok<STRNU> 
                    clear tmp;
                catch
                    this.tab_DataPrep.Table.Data{i, 16} = '<html><font color = "#FF0000">Bore ID label error - must start with letters and have only letters and numbers.</font></html>';
                    ind(i) = false;
                    nBoreIDLabelError = nBoreIDLabelError+1;
                end
                    
                % Convert head date/time columns to a vector.
                switch size(headData{i},2)-1
                    case 3
                        dateVec = datenum(headData{i}(:,1), headData{i}(:,2), headData{i}(:,3));
                    case 4
                        dateVec = datenum(headData{i}(:,1), headData{i}(:,2), headData{i}(:,3),headData{i}(:,4), zeros(size(headData{i},1),1), zeros(size(headData{i},1),1));
                    case 5
                        dateVec = datenum(headData{i}(:,1), headData{i}(:,2), headData{i}(:,3),headData{i}(:,4),headData{i}(:,5), zeros(size(headData{i},1),1));
                    case 6
                        dateVec = datenum(headData{i}(:,1), headData{i}(:,2), headData{i}(:,3),headData{i}(:,4),headData{i}(:,5),headData{i}(:,6));
                    otherwise
                        this.tab_DataPrep.Table.Data{i, 16} = '<html><font color = "#FF0000">Data error - observed head must be 4 to 7 columns with right hand column being the head and the left columns: year; month; day; hour (optional), minute (options), second (optional).</font></html>';
                        ind(i) = false;
                        continue;
                end 
                headData{i} = [dateVec, headData{i}(:,end)];
            end


            nBoresAnalysed = false(length(selectedBores),1);
            nAnalysisFailed = false(length(selectedBores),1);
            errorMessage = cell(length(selectedBores),1);
            if any(ind)
                % Filter inputs to only the sites to be analysed for
                % outliers.
                ind = find(ind');
                boreID = boreID(ind);
                headData = headData(ind); 
                boreDepth = boreDepth(ind); 
                surfaceElevation = surfaceElevation(ind); 
                caseLength = caseLength(ind); 
                constructionDate = constructionDate(ind); 
                checkStartDate = checkStartDate(ind);
                checkEndDate = checkEndDate(ind);
                checkMinHead = checkMinHead(ind);
                checkMaxHead = checkMaxHead(ind);
                rateOfChangeThreshold = rateOfChangeThreshold(ind);
                constHeadDuration = constHeadDuration(ind);
                numNoiseStdDev = numNoiseStdDev(ind);
                outlierForwadBackward = outlierForwadBackward(ind);

                % Run error and outlier detection in parallel.
                parfor i=1:length(ind)
                    % Call analysis function
                    try
                        % Do the analysis and add to the object
                        chechDuplicateDates = true;
                        headData{i} = doDataQualityAnalysis(boreID_label, headData{i}, boreDepth(i), surfaceElevation(i), caseLength(i), constructionDate(i), ...
                            checkStartDate(i), checkEndDate(i), chechDuplicateDates, checkMinHead(i), checkMaxHead(i), rateOfChangeThreshold(i), ...
                            constHeadDuration(i), numNoiseStdDev(i), outlierForwadBackward(i) );

                        nBoresAnalysed(i) = true;
                    catch ME
                        nAnalysisFailed(i) = true;
                        errorMessage{i} = ME.message;
                        continue
                    end
                end

                for i=1:length(ind)
                    if nAnalysisFailed(i)
                        % Remove bore from object
                        if isfield(this.dataPrep,boreID{i})
                            this.dataPrep = rmfield(this.dataPrep,boreID{i});
                        end

                        this.tab_DataPrep.Table.Data{ind(i), 16} = ['<html><font color = "#FF0000">Analysis failed - ', errorMessage{i},'</font></html>'];
                        this.tab_DataPrep.Table.Data{ind(i),17} = ['<html><font color = "#808080">','(NA)','</font></html>'];
                        this.tab_DataPrep.Table.Data{ind(i),18} = ['<html><font color = "#808080">','(NA)','</font></html>'];
                    else
                        % Add error and outlier results to object
                        this.dataPrep.(boreID{i}) = headData{i};

                        % Add summary stats
                        numErroneouObs_all = sum(any(table2array(this.dataPrep.(boreID{i})(:,7:12)),2));
                        numOutlierObs = sum(table2array(this.dataPrep.(boreID{i})(:,13)));

                        this.tab_DataPrep.Table.Data{ind(i), 16} = '<html><font color = "#008000">Analysed.</font></html>';
                        this.tab_DataPrep.Table.Data{ind(i),17} = ['<html><font color = "#808080">',num2str(numErroneouObs_all),'</font></html>'];
                        this.tab_DataPrep.Table.Data{ind(i),18} = ['<html><font color = "#808080">',num2str(numOutlierObs),'</font></html>'];
                    end
                end
            end

            % Update status in GUI
            drawnow;
            
            % Change cursor to arrow
            set(this.Figure, 'pointer', 'arrow');
            drawnow update
            
            % Report Summary
            h = msgbox(['The data analysis was successfully for ',num2str(sum(nBoresAnalysed)), ' bores.', char newline, char newline,...
                    'Below is a summary of the failures:', char newline, ...
                    '   - Head data file errors: ', num2str(nBoreNotInHeadFile), char newline, ...
                    '   - Input table data errors: ', num2str(nBoreInputsError), char newline, ...
                    '   - Data analysis algorithm failures: ', num2str(sum(nAnalysisFailed)), char newline, ...
                    '   - Bore IDs not starting with a letter: ', num2str(nBoreIDLabelError)], ...                    
                    'Results summary');
            set(h,'Tag','Data prep msgbox summary');
            setIcon(this, h);
        end
        
        function onBuildModels(this, ~, ~)

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
            for i=1:length(selectedBores)
                if ~isempty(selectedBores{i}) && selectedBores{i}
                    nModels = nModels +1;
                end
            end
            
            % Add wait bar
            minModels4Waitbar = 5;
            iModels=0;
            if nModels>=minModels4Waitbar
                h = waitbar(0, ['Building ', num2str(nModels), ' models. Please wait ...']);
                setIcon(this, h);
            end               
            
            % Loop  through the list of selected bore and apply the modle
            % options.
            nModelsBuilt = 0;
            nModelsBuiltFailed = 0;
            for i=1:length(selectedBores)
                % Check if the model is to be built.
                if isempty(selectedBores{i}) || ~selectedBores{i}
                    continue;
                end

                % Update table with progress'
                this.tab_ModelConstruction.Table.Data{i, end} = '<html><font color = "#FFA500">Building model ...</font></html>';

                % Update status in GUI
                drawnow
                                
                % Import head data
                %----------------------------------------------------------
                % Check the obs. head file is listed
                if isfolder(this.project_fileName)
                    fname = fullfile(this.project_fileName,data{i,3});
                else
                    fname = fullfile(fileparts(this.project_fileName),data{i,3});
                end
                if isempty(fname)                    
                    this.tab_ModelConstruction.Table.Data{i, end} = '<html><font color = "#FF0000">Head data file error - file name empty.</font></html>';
                    nModelsBuiltFailed = nModelsBuiltFailed + 1;
                    continue;
                end

                % Check the bore ID file exists.
                if exist(fname,'file') ~= 2
                    this.tab_ModelConstruction.Table.Data{i, end} = '<html><font color = "#FF0000">Head data file error - file does not exist.</font></html>';
                    nModelsBuiltFailed = nModelsBuiltFailed + 1;
                    continue;
                end

                % Read in the observed head file.
                try
                    tbl = readtable(fname);
                catch
                    this.tab_ModelConstruction.Table.Data{i, end} = '<html><font color = "#FF0000">Head data file error -  read in failed.</font></html>';
                    nModelsBuiltFailed = nModelsBuiltFailed + 1;
                    continue;
                end                
                
                % Filter for the required bore.
                filt =  strcmp(tbl{:,1},data{i,6});
                headData = tbl(filt,2:end);

                % Check all columns are numeric.
                for j=1:size(headData,2)
                    if any(~isnumeric(headData{:,j}))
                        this.tab_ModelConstruction.Table.Data{i, end} = '<html><font color = "#FF0000">Head data file error - non-numeric data.</font></html>';
                        nModelsBuiltFailed = nModelsBuiltFailed + 1;
                        break;
                    end
                end                
                
                % Check if there are any empty rows
                if any(ismissing(headData),'all')
                    this.tab_ModelConstruction.Table.Data{i, end} = '<html><font color = "#FF0000">Head data file error - missing value(s).</font></html>';
                    nModelsBuiltFailed = nModelsBuiltFailed + 1;
                    continue;
                end   

                % Check there is some obs data
                if size(headData,1)<=1
                    this.tab_ModelConstruction.Table.Data{i, end} = '<html><font color = "#FF0000">Head data file error - <=1 observation for bore ID.</font></html>';
                    nModelsBuiltFailed = nModelsBuiltFailed + 1;
                    continue;
                end                  

                % Convert to double and sort in case not in order.
                headData = sortrows(headData{:,:}, 1:(size(headData,2)-1),'ascend');          
                           
                %----------------------------------------------------------
                
                % Import forcing data
                %----------------------------------------------------------
                % Check fname file exists.
                if isfolder(this.project_fileName)
                    fname = fullfile(this.project_fileName,data{i,4});
                else
                    fname = fullfile(fileparts(this.project_fileName),data{i,4});
                end
                if exist(fname,'file') ~= 2                   
                   this.tab_ModelConstruction.Table.Data{i, end} = '<html><font color = "#FF0000">Forcing file error - file does not exist.</font></html>';
                   nModelsBuiltFailed = nModelsBuiltFailed + 1;
                   continue;
                end

                % Read in the file.
                try
                   forcingData = readtable(fname);
                catch
                   this.tab_ModelConstruction.Table.Data{i, end} = '<html><font color = "#FF0000">Forcing file error -  read in failed.</font></html>';
                   nModelsBuiltFailed = nModelsBuiltFailed + 1;
                   continue;
                end      
                if isempty(forcingData)
                   this.tab_ModelConstruction.Table.Data{i, end} = '<html><font color = "#FF0000">Forcing file is empty or open elsewhere -  read in failed.</font></html>';
                   nModelsBuiltFailed = nModelsBuiltFailed + 1;
                   continue;                    
                end

                % Check all columns are numeric.
                for j=1:size(forcingData,2)
                    if any(~isnumeric(forcingData{:,j}))
                        this.tab_ModelConstruction.Table.Data{i, end} = '<html><font color = "#FF0000">Forcing file file error - non-numeric data.</font></html>';
                        nModelsBuiltFailed = nModelsBuiltFailed + 1;
                        break;
                    end
                end

                % Check if there are any empty rows
                if any(ismissing(forcingData),'all')
                    this.tab_ModelConstruction.Table.Data{i, end} = '<html><font color = "#FF0000">Head data file error - missing value(s).</font></html>';
                    nModelsBuiltFailed = nModelsBuiltFailed + 1;
                    continue;
                end

                % Sort in case not in order.
                forcingData = sortrows(forcingData, 1:3,'ascend');

                %----------------------------------------------------------
                
                
                % Import coordintate data
                %----------------------------------------------------------
                % Check fname file exists.
                if isfolder(this.project_fileName)
                    fname = fullfile(this.project_fileName,data{i,5});
                else
                    fname = fullfile(fileparts(this.project_fileName),data{i,5});
                end
                if exist(fname,'file') ~= 2                 
                   nModelsBuiltFailed = nModelsBuiltFailed + 1;
                   this.tab_ModelConstruction.Table.Data{i, end} = '<html><font color = "#FF0000">Coordinate file error - file does not exist.</font></html>';
                   continue;
                end

                % Read in the file.
                try
                   coordData = readtable(fname);
                   coordData = table2cell(coordData);
                catch
                   nModelsBuiltFailed = nModelsBuiltFailed + 1;
                   this.tab_ModelConstruction.Table.Data{i, end} = '<html><font color = "#FF0000">Coordinate file error -  read in failed.</font></html>';
                   continue;
                end
                
                % Check site names are unique
                if length(coordData(:,1)) ~= length(unique(coordData(:,1)))
                   nModelsBuiltFailed = nModelsBuiltFailed + 1;
                   this.tab_ModelConstruction.Table.Data{i, end} = '<html><font color = "#FF0000">Coordinate site IDs not unique.</font></html>';
                   continue;                    
                end
                %----------------------------------------------------------

                % Get model label
                model_label = data{i,2};
                
                % Get bore IDs
                boreID= data{i,6};
                
                % Get heda obs freq,
                maxHeadObsFreq_asDays = data{i,7};
                if ~isnumeric(maxHeadObsFreq_asDays) || maxHeadObsFreq_asDays<1
                    nModelsBuiltFailed = nModelsBuiltFailed + 1;
                    this.tab_ModelConstruction.Table.Data{i, end} = '<html><font color = "#FF0000">Min. obs. head timestep must be >=1.</font></html>';
                    continue;
                end

                % Get model type
                modelType = data{i,8};
                
                % If the modle options are empty, try and add an empty cell
                % in case the model does not need options.
                if isempty(data{i,9})
                    data{i,9} = '{}';
                end
                
                % Get model options
                try
                    modelOptions= eval(data{i,9});
                catch
                    nModelsBuiltFailed = nModelsBuiltFailed + 1;
                    this.tab_ModelConstruction.Table.Data{i, end} = '<html><font color = "#FF0000">Syntax error in model options - Check required options have an input value.</font></html>';
                    continue;
                end                
                
                % Build model
                try 
                    % Build model
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
                            this.tab_ModelCalibration.Table.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));
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
                        this.tab_ModelCalibration.Table.Data{isModelListed,8} = 'CMA-ES';
                        
                        
                        % Update row numbers
                        nrows = size(this.tab_ModelCalibration.Table.Data,1);
                        this.tab_ModelCalibration.Table.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));                        
                        
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
                    
                    this.tab_ModelConstruction.Table.Data{i, end} = '<html><font color = "#008000">Model built.</font></html>';
                    nModelsBuilt = nModelsBuilt + 1; 
                    
                catch ME
                    nModelsBuiltFailed = nModelsBuiltFailed + 1;
                    this.tab_ModelConstruction.Table.Data{i, end} = ['<html><font color = "#FF0000">Model build failed : ', ME.message,'</font></html>'];
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
            h = msgbox(['The model was successfully built for ',num2str(nModelsBuilt), ' models and failed for ',num2str(nModelsBuiltFailed), ' models.'], 'Models built');
            set(h,'Tag','Model construction msgbox summary');
            setIcon(this, h);
                        
        end
        
        function onCalibModels(this, ~, ~)
                  
            % The project must be saved to a file. Check the project file
            % is defined.
            if isempty(this.project_fileName) || isfolder(this.project_fileName)
                h = warndlg({'The project must be saved to a file before calibration can start.';'Please first save the project.'}, 'Project not saved');
                setIcon(this, h);
                return
            end            
            
            % Get table data
            data = this.tab_ModelCalibration.Table.Data;            
            
            % Get list of selected bores and check.
            selectedBores = data(:,1);
            isModelSelected=false;
            for i=1:length(selectedBores)             
                % Check if the model is to be calibrated.
                if ~isempty(selectedBores{i}) && selectedBores{i}
                    isModelSelected=true;
                    break;
                end                
            end                        
            
            if ~isModelSelected
                h = warndlg('No models have been selected for calibration.','Calibration error');
                setIcon(this, h);
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
                h = warndlg('No models appear to have been built. Please build the models then calibrate them.','Calibration error');
                setIcon(this, h);
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

                    h = warndlg('Some models listed in the calibration table are duplicated or not listed in the model construction table and will be deleted. Please re-run the calibration','Unexpected error');
                    setIcon(this, h);
                    this.tab_ModelCalibration.Table.Data = this.tab_ModelCalibration.Table.Data(~deleteCalibRow,:);
                    
                    % Update row numbers
                    nrows = size(this.tab_ModelCalibration.Table.Data,1);
                    this.tab_ModelCalibration.Table.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));                            
                    
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
                'DockControls','off', 'WindowStyle','modal', ...               
                'CloseRequestFcn', @closeCalibFig);
                   
            % Change icon
            setIcon(this, this.tab_ModelCalibration.GUI);

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
                uicontrol('Parent',outerButtons,'String','HPC Retrieval','Callback', @this.onImportFromHPC, 'Tag','Start calibration - useHPC import', 'TooltipString', sprintf('BETA version to retrieve calibrated models from a High Performance Cluster.') );
            end            
            uicontrol('Parent',outerButtons,'String','Skip model','Callback', @this.modelCalibration_skipNotify, 'Enable','off','Tag','Skip calibration', 'TooltipString', sprintf('Skip calibrating the current model & start to next model.') );
            this.tab_ModelCalibration.skipCalibration = false;
            addlistener(this,'skipModelCalibration',@this.modelCalibration_skipListen);            
            uicontrol('Parent',outerButtons,'String','Quit calibration','Callback', @this.modelCalibration_quitNotify, 'Enable','off','Tag','Quit calibration', 'TooltipString', sprintf('Stop calibrating at the end of the current iteration loop.') );
            this.tab_ModelCalibration.quitCalibration = false;
            addlistener(this,'quitModelCalibration',@this.modelCalibration_quitListen);
            outerButtons.ButtonSize(1) = 225;            
            
            % Count the number of models selected
            nModels=0;            
            for i=1:length(selectedBores)                                
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
            ax.XTick = 0:nModels;
            title(ax,'Model Calibration Progress','FontSize',10,'FontWeight','normal');
            
            % Add large box for calib. iterations            
            uipanel('Parent',innerVbox_bottom, 'Tag','Model calibration - progress plots panel');            
            
            set(outerVbox, 'Sizes', [510 -1]);
            set(innerVbox_top, 'Sizes', [30 -1 30 50]);
            set(innerVbox_bottom, 'Sizes', -1);
           
            % Fill in CMA-ES panel               
            CMAES_tabVbox= uiextras.Grid('Parent',CMAES_tab,'Padding', 6, 'Spacing', 6);
            uicontrol(CMAES_tabVbox,'Style','text','String','Maximum number of model evaluations (MaxFunEvals):','HorizontalAlignment','left', 'Units','normalized');                        
            uicontrol(CMAES_tabVbox,'Style','text','String','Number of parameter sets searching for the optima (PopSize) per model parameter :','HorizontalAlignment','left', 'Units','normalized');                        
            uicontrol(CMAES_tabVbox,'Style','text','String','Absolute change in the objective function for convergency (TolFun):','HorizontalAlignment','left', 'Units','normalized');            
            uicontrol(CMAES_tabVbox,'Style','text','String','Largest absolute change in the parameters for convergency (TolX):','HorizontalAlignment','left', 'Units','normalized');                        
            uicontrol(CMAES_tabVbox,'Style','text','String','Number CMA-ES calibration restarts (Restarts):','HorizontalAlignment','left', 'Units','normalized');                        
            uicontrol(CMAES_tabVbox,'Style','text','String','Standard deviation for the initial parameter sampling, as fraction of plausible parameter bounds (sigma):','HorizontalAlignment','left', 'Units','normalized');            
            uicontrol(CMAES_tabVbox,'Style','text','String','Random seed number (only for repetetive testing purposes, an empty value uses a different seed per model):','HorizontalAlignment','left', 'Units','normalized');            
                  
            uicontrol(CMAES_tabVbox,'Style','edit','string','Inf','Max',1, 'Tag','CMAES MaxFunEvals','HorizontalAlignment','right');
            uicontrol(CMAES_tabVbox,'Style','edit','string','4','Max',1, 'Tag','CMAES popsize','HorizontalAlignment','right');
            uicontrol(CMAES_tabVbox,'Style','edit','string','1e-8','Max',1, 'Tag','CMAES TolFun','HorizontalAlignment','right');
            uicontrol(CMAES_tabVbox,'Style','edit','string','1e-7','Max',1, 'Tag','CMAES TolX','HorizontalAlignment','right');
            uicontrol(CMAES_tabVbox,'Style','edit','string','0','Max',1, 'Tag','CMAES Restarts','HorizontalAlignment','right');
            uicontrol(CMAES_tabVbox,'Style','edit','string','0.33','Max',1, 'Tag','CMAES Sigma','HorizontalAlignment','right');
            uicontrol(CMAES_tabVbox,'Style','edit','string',num2str(floor(rand(1)*1e6)),'Max',1, 'Tag','CMAES iseed','HorizontalAlignment','right');
            
            set(CMAES_tabVbox, 'ColumnSizes', [-1 100], 'RowSizes', repmat(20,1,7));                        
            
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
            uicontrol(DREAM_tabVbox,'Style','text','String','Initial sampling method (prior):','HorizontalAlignment','left', 'Units','normalized');
            uicontrol(DREAM_tabVbox,'Style','text','String','Initial sampling stand. dev. for prior=="normal" (sigma):','HorizontalAlignment','left', 'Units','normalized');
            uicontrol(DREAM_tabVbox,'Style','text','String','Number of Markov chains per parameter (N_per_param):','HorizontalAlignment','left', 'Units','normalized');                  
            uicontrol(DREAM_tabVbox,'Style','text','String','Min. number of converged generations per parameter (Tmin):','HorizontalAlignment','left', 'Units','normalized');                  
            uicontrol(DREAM_tabVbox,'Style','text','String','Max. number of model generations per chain (T):','HorizontalAlignment','left', 'Units','normalized');
            uicontrol(DREAM_tabVbox,'Style','text','String','r2 convergence criteria (less than denotes converged iteration):','HorizontalAlignment','left', 'Units','normalized');            
            uicontrol(DREAM_tabVbox,'Style','text','String','Number of crossover values (nCR):','HorizontalAlignment','left', 'Units','normalized');                        
            uicontrol(DREAM_tabVbox,'Style','text','String','Number chain pairs for proposal (delta):','HorizontalAlignment','left', 'Units','normalized');            
            uicontrol(DREAM_tabVbox,'Style','text','String','Random error for ergodicity (lambda):','HorizontalAlignment','left', 'Units','normalized');            
            uicontrol(DREAM_tabVbox,'Style','text','String','Randomization (zeta):','HorizontalAlignment','left', 'Units','normalized');                        
            uicontrol(DREAM_tabVbox,'Style','text','String','Test function name for detecting outlier chains (outlier):','HorizontalAlignment','left', 'Units','normalized');                        
            uicontrol(DREAM_tabVbox,'Style','text','String','Probability of jumprate of 1 (pJumpRate_one):','HorizontalAlignment','left', 'Units','normalized');                        
            uicontrol(DREAM_tabVbox,'Style','text','String','Random seed number:','HorizontalAlignment','left', 'Units','normalized');            

            uicontrol(DREAM_tabVbox,'Style','popupmenu','string',{'uniform','latin','normal'},'Value',2,'Max',1, 'Tag','DREAM prior','HorizontalAlignment','right');
            uicontrol(DREAM_tabVbox,'Style','edit','string','0.5','Max',1, 'Tag','DREAM sigma','HorizontalAlignment','right');
            uicontrol(DREAM_tabVbox,'Style','edit','string','2','Max',1, 'Tag','DREAM N','HorizontalAlignment','right');
            uicontrol(DREAM_tabVbox,'Style','edit','string','1500','Max',1, 'Tag','DREAM Tmin','HorizontalAlignment','right');            
            uicontrol(DREAM_tabVbox,'Style','edit','string','20000','Max',1, 'Tag','DREAM T','HorizontalAlignment','right');
            uicontrol(DREAM_tabVbox,'Style','edit','string','1.2','Max',1, 'Tag','DREAM r2_threshold','HorizontalAlignment','right');
            uicontrol(DREAM_tabVbox,'Style','edit','string','3','Max',1, 'Tag','DREAM nCR','HorizontalAlignment','right');
            uicontrol(DREAM_tabVbox,'Style','edit','string','3','Max',1, 'Tag','DREAM delta','HorizontalAlignment','right');
            uicontrol(DREAM_tabVbox,'Style','edit','string','0.05','Max',1, 'Tag','DREAM lambda','HorizontalAlignment','right');
            uicontrol(DREAM_tabVbox,'Style','edit','string','0.05','Max',1, 'Tag','DREAM zeta','HorizontalAlignment','right');
            uicontrol(DREAM_tabVbox,'Style','edit','string','iqr','Max',1, 'Tag','DREAM outlier','HorizontalAlignment','right');
            uicontrol(DREAM_tabVbox,'Style','edit','string','0.2','Max',1, 'Tag','DREAM pJumpRate_one','HorizontalAlignment','right');            
            uicontrol(DREAM_tabVbox,'Style','edit','string',num2str(floor(rand(1)*1e6)),'Max',1, 'Tag','DREAM iseed','HorizontalAlignment','right');
            
            set(DREAM_tabVbox, 'ColumnSizes', [-1 100], 'RowSizes', repmat(20,1,13));            
            
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
            %showMultiModeltab = false;
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
                        showMultiModeltab = true; %#ok<NASGU> 
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
            function closeCalibFig(obj,~,~)
                set(this.Figure, 'pointer', 'arrow')
                delete(obj);
                this.tab_ModelCalibration = rmfield(this.tab_ModelCalibration,'GUI');
            end
        end
        
        function onSimModels(this, ~, ~)
           
            % Get table data
            data = this.tab_ModelSimulation.Table.Data;
            
            % Get list of selected bores.
            selectedBores = data(:,1);            
            if isempty(selectedBores)
                h = warndlg('No models selected for simulation.','Selection error');
                setIcon(this, h);
            end

            % Change cursor
            set(this.Figure, 'pointer', 'watch');
            drawnow update            

            % Count the number of models selected
            nModels=0;
            for i=1:length(selectedBores)                   
                if ~isempty(selectedBores{i}) && selectedBores{i}
                    nModels = nModels +1;
                end
            end
            
            % Add simulation bar
            minModels4Waitbar = 5;
            iModels=0;
            if nModels>=minModels4Waitbar
                h = waitbar(0, ['Simulating ', num2str(nModels), ' models. Please wait ...']);
                setIcon(this, h);
            end            
            
            % Loop  through the list of selected bore and apply the model
            % options.
            nModelsSim = 0;
            nModelsSimFailed = 0;
            for i=1:length(selectedBores)                                
                
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
                   this.tab_ModelSimulation.Table.Data{i,end} = '<html><font color = "#FF0000">Error: model could not be found. Please rebuild and calibrate it.</font></html>';
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
                   this.tab_ModelSimulation.Table.Data{i,end} = '<html><font color = "#FF0000">Error: no simulation label.</font></html>';
                   continue;
                end                      
                
                % Get the forcing data.
                if ~isempty(forcingdata_fname)

                    % Import forcing data
                    %-----------------------
                    % Check fname file exists.
                    if isfolder(this.project_fileName)
                        forcingdata_fname = fullfile(this.project_fileName,forcingdata_fname);
                    else
                        forcingdata_fname = fullfile(fileparts(this.project_fileName),forcingdata_fname);
                    end
                    
                    if exist(forcingdata_fname,'file') ~= 2                 
                        this.tab_ModelSimulation.Table.Data{i,end} = '<html><font color = "#FF0000">Error: new forcing date file could not be open.</font></html>';
                        nModelsSimFailed = nModelsSimFailed +1;
                        continue;
                    end

                    % Read in the file.
                    try
                       forcingData= readtable(forcingdata_fname);
                    catch                   
                        this.tab_ModelSimulation.Table.Data{i,end} = '<html><font color = "#FF0000">Error: new forcing date file could not be imported.</font></html>';
                        nModelsSimFailed = nModelsSimFailed +1;
                        continue;                        
                    end                    
                   
                    % Convert year, month, day to date vector
                    forcingData_data = table2array(forcingData);
                    forcingDates = datenum(forcingData_data(:,1), forcingData_data(:,2), forcingData_data(:,3));
                    forcingData_data = [forcingDates, forcingData_data(:,4:end)];
                    forcingData_colnames = forcingData.Properties.VariableNames(4:end);
                    forcingData_colnames = ['time', forcingData_colnames]; %#ok<AGROW> 
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
                    this.tab_ModelSimulation.Table.Data{i,end} = '<html><font color = "#FF0000">Error: time step must be specified when the simulation dates are outside of the observed head period.</font></html>';
                    nModelsSimFailed = nModelsSimFailed +1;
                    continue;                        
               end               
               
               % Create a vector of simulation time points 
               switch  simTimeStep
                   case 'Daily'
                       simTimePoints = transpose(simStartDate:1:simEndDate);
                   case 'Weekly'
                       simTimePoints = transpose(simStartDate:7:simEndDate);
                   case 'Monthly'
                       simTimePoints = zeros(0,3);
                       startYear = year(simStartDate);
                       startMonth= month(simStartDate);
                       startDay= 1;
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
                       simTimePoints = transpose(simStartDate:365:simEndDate);
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
                    this.tab_ModelSimulation.Table.Data{i,end} = '<html><font color = "#FF0000">Error: kriging of residuals can only be undertaken if new forcing data is not input.</font></html>';
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
                   this.tab_ModelSimulation.Table.Data{i,end} = ['<html><font color = "#FF0000">Error: ', ME.message,'</font></html>']; '<html><font color = "#FF0000">Failed. </font></html>';                       
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
            h = msgbox(['The simulations were successful for ',num2str(nModelsSim), ' models and failed for ',num2str(nModelsSimFailed), ' models.'], 'Model simulaions');
            set(h,'Tag','Model simulation msgbox summary')
            setIcon(this, h);

        end
                
        function onImportFromHPC(this, ~, ~)
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
            end                          
            
            % Display update
            disp('HPC retrieval progress ...');           
                        
            % Check the local workin folder exists. If not, create it.
            if ~exist(workingFolder,'dir')
                % Display update
                display(['   Making local working folder at:',workingFolder]);               
                
                mkdir(workingFolder);
            end
            cd(workingFolder);
            
            % Check that a SSH channel can be opened           
            disp('   Checking SSH connection to cluster ...');        
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
            for i=1:length(selectedBores)
                % Check if the model is to be calibrated.
                if isempty(selectedBores{i}) || ~selectedBores{i}
                    continue;
                else
                    imodels = [imodels,i]; %#ok<AGROW> 
                end            
            end
            nSelectedModels = length(imodels);
            
            % Get a list of .mat files on remote cluster
            disp('   Getting list of results files on cluster ...');     
            try
                [~,allMatFiles] = ssh2_command(sshChannel,['cd ',folder,'/models ; find -name \*.mat -print']);
            catch
                errordlg({'An SSH connection to the cluster could not be established.','Please check the input URL, username and passord.'},'SSH connection failed.');
                return;
            end
            
            % Filter out the input data files
            ind = cellfun( @(x) ~contains(x, 'HPCmodel.mat'), allMatFiles);
            allMatFiles = allMatFiles(ind);
            
            % Build list of mat files results to download
            disp('   Building list of results files to retieve ...');

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
                
                indResultsFileName = find(cellfun( @(x) contains(x, ['/',calibLabel,'/results.mat']), allMatFiles));                
                if ~isempty(indResultsFileName)
                    changefilename=true;
                else
                    indResultsFileName = find(cellfun( @(x) contains(x, ['/',calibLabel,'/',calibLabel,'.mat']), allMatFiles));
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
                    imodel_filt =  [imodel_filt,true]; %#ok<AGROW> 
                else
                    imodel_filt =  [imodel_filt,false]; %#ok<AGROW> 
                    nModelsNoResult=nModelsNoResult+1;
                end
            end

            % Change file names from results.mat
            if ~isempty(SSH_commands)
                disp(['   Changing file from results.mat to model label .mat at ', num2str(nModelsNamesToChange), ' models...']);               
                try
                    ssh2_command(sshChannel,SSH_commands);
                catch
                    h = warndlg({'Some results.mat files could not be changed to the model label.' ,'These models will not be imported.'},'SSH file name change failed.');
                    setIcon(this, h);
                end
            end
            
            % Download .mat files
            disp(['   Downloading ', num2str(length(resultsToDownload)), ' completed models to working folder ...']);
            imodels = imodels(logical(imodel_filt));            
            try
                scp_get(sshChannel,resultsToDownload, workingFolder, [folder,'/models/']);
            catch
                ssh2_close(sshChannel);        
            end

            disp('   Closing SSH connection to cluster ...');
            
            % Closing connection
            try
                ssh2_close(sshChannel);        
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
                disp(['   Importing model ',num2str(k),' of ',num2str(nModels) ' into the project ...']);
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
                        if isfield(importedModel.model.model.variables,'resid')
                            importedModel.model.model.variables = rmfield(importedModel.model.model.variables, 'resid');
                        end
                    catch        
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
                            for j=1:nvariograms
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
                        for j=1:nvariograms
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

                catch
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
        
        function onImportTable(this, hObject, ~)
        
            
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
                    h = warndlg('Unexpected Error: GUI table type unknown.','Import error');
                    setIcon(this, h);
                    return                    
            end
                
            % Get project folder       
            if isfolder(this.project_fileName)
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
            if fName~=0
                % Assign file name to date cell array
                filename = fullfile(pName,fName);
            else
                return;
            end         
            
            % Read in the table.
            try
                tbl = readtable(filename,'Delimiter',',');
            catch
                h = warndlg('The table datafile could not be read in. Please check it is a CSV file with column headings in the first row.','File error');
                setIcon(this, h);
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
                        h = warndlg('The table datafile must have 18 columns. That is, all columns shown in the model construction table.','Table size error');
                        setIcon(this, h);
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
                                    tableAsCell{i,j} = datestr(tableAsCell{i,j},'dd-mmm-yyyy');
                                end
                            end

                            % Add results text.
                            tableAsCell{i,16} = '<html><font color = "#FF0000">Not analysed.</font></html>'; 
                            tableAsCell{i,17} = ['<html><font color = "#808080">','(NA)','</font></html>'];
                            tableAsCell{i,18} = ['<html><font color = "#808080">','(NA)','</font></html>'];
                            
                            % Convert integer 0/1 to logicals
                            for j=find(strcmp(colFormat,'logical'))
                               if tableAsCell{i,j}==1
                                   tableAsCell{i,j} = true;
                               else
                                   tableAsCell{i,j} = false;
                               end                                       
                            end
                            
                            % Append data
                            this.tab_DataPrep.Table.Data = [this.tab_DataPrep.Table.Data; tableAsCell(i,:)];
                            
                            nImportedRows = nImportedRows + 1;
                        catch
                            nRowsNotImported = nRowsNotImported + 1;
                        end
                        
                    end
                    

                    % Update row numbers.
                    nrows = size(this.tab_DataPrep.Table.Data,1);
                    this.tab_DataPrep.Table.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));                           
                    
                    % Change cursor
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update;                                
                    
                    % Output Summary.
                    h = msgbox({['Data preparation table data was imported to ',num2str(nImportedRows), ' rows.'], ...
                            '', ...
                            ['Number of rows not imported because of data format errors: ',num2str(nRowsNotImported) ]}, 'Analysis table imported');
                    setIcon(this, h);
                    
                    
                case 'Model Construction'
                    if size(tbl,2) ~=10
                        set(this.Figure, 'pointer', 'arrow');
                        drawnow update;                        
                        h = warndlg('The table datafile must have 10 columns. That is, all columns shown in the model construction table.','Table size error');
                        setIcon(this, h);
                        return;
                    end
                        
                    % Set the Model Status column to a cells array (if
                    % empty matlab assumes its NaN)
                    tbl.Select_Model=false(size(tbl,1));
                    tbl.Build_Status = cell(size(tbl,1),1);
                    tbl.Build_Status(:) = {'<html><font color = "#FF0000">Not built.</font></html>'};
                    tbl = table(tbl.Select_Model,tbl.Model_Label,tbl.Obs_Head_File,tbl.Forcing_Data_File,tbl.Coordinates_File,tbl.Site_ID, tbl.Min_Head_Timestep_days, tbl.Model_Type,tbl.Model_Options,tbl.Build_Status);

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
                            ind = find(strcmp(this.tab_ModelConstruction.Table.Data(:,2), modelLabel_src), 1);                        

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
                    this.tab_ModelConstruction.Table.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));                        

                    % Change cursor
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update;                                                    
                    
                    % Output Summary.
                    h = msgbox({['Construction data was imported to ',num2str(nImportedRows), ' rows.'], ...
                            '', ...
                            ['Number of rows not imported because the model label is not unique: ',num2str(nModelsNotUnique) ]}, 'Construction table imported');
                    setIcon(this, h);
                    
                case 'Model Calibration'
                    
                    if size(tbl,2) ~=13
                        set(this.Figure, 'pointer', 'arrow');
                        drawnow update;                        
                        h = warndlg('The table datafile must have 13 columns. That is, all columns shown in the table.','Table size error');
                        setIcon(this, h);
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

                                % Add flag to denote the calibration is not complete.
                                tmpModel.calibrationResults.isCalibrated = false;

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
                    this.tab_ModelCalibration.Table.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));                            

                    % Change cursor
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update;                                
                                        
                    % Output Summary.
                    h = msgbox({['Calibration data was imported to ',num2str(nImportedRows), ' rows.'], ...
                            ['   Number of model labels not found in the calibration table: ',num2str(nModelsNotFound) ], ...
                            ['   Number of rows were the bore IDs did not match: ',num2str(nBoresNotMatching) ], ...
                            ['   Number of rows were existing calibration results were deleted: ',num2str(nCalibBoresDeleted) ]}, 'Calibration table imported');
                    setIcon(this, h);
                case 'Model Simulation'
                    
                    % Check the number of columns
                    if size(tbl,2) ~=12
                        set(this.Figure, 'pointer', 'arrow');
                        drawnow update;                        
                        h = warndlg('The table datafile must have 12 columns. That is, all columns shown in the table.','Table size error');
                        setIcon(this, h);
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
                        ind = find(strcmp(modelLabel_dest, modelLabel_src) & strcmp(simLabel_dest, simLabel_src), 1);
                        
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
                        if ~ischar(rowData{8})
                            rowData{8}='';
                        end
                        if ~ischar(rowData{9})
                            rowData{9}='';
                        end
                        if isa(rowData{4},'datetime')
                            rowData{4} = datestr(rowData{4},'dd-mmm-yyyy');
                        end
                        if isa(rowData{5},'datetime')
                            rowData{5} = datestr(rowData{5},'dd-mmm-yyyy');
                        end
                        if size(this.tab_ModelSimulation.Table.Data,1)==0
                            set(this.tab_ModelSimulation.Table,'Data',rowData);
                        else                            
                            this.tab_ModelSimulation.Table.Data = [this.tab_ModelSimulation.Table.Data; rowData];
                        end

                        nImportedRows = nImportedRows + 1;
                    end

                    % Update row numbers.
                    nrows = size(this.tab_ModelSimulation.Table.Data,1);
                    this.tab_ModelSimulation.Table.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));                            
                                  
                    % Change cursor
                    set(this.Figure, 'pointer', 'arrow');
                    drawnow update;
                    
                    % Output Summary.
                    h = msgbox({['Simulation data was imported to ',num2str(nImportedRows), ' rows.'], ...
                            '', ...
                            ['Number of rows not imported because the model label is not unique: ',num2str(nSimLabelsNotUnique) ]}, ...
                            'Simulation table imported');
                    setIcon(this, h);
                                   
            end
        end        
        
        function onExportTable(this, hObject, ~)
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
                    h = warndlg('Unexpected Error: GUI table type unknown.','Error');
                    setIcon(this, h);
                    return                    
            end

            % Show open file window
            [fName,pName] = uiputfile({'*.csv'},windowString); 
            if fName~=0
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
            catch
                h = warndlg('The table could not be written. Please check you have write permissions to the destination folder.','Export error');
                setIcon(this, h);
                return;
            end            
        end        
        
        function onExportResults(this, hObject, ~)
            
            % Set initial folder to the project folder (if set)
            if ~isempty(this.project_fileName)                                
                try    
                    if isfolder(this.project_fileName)
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
                    if isempty(this.dataPrep) || size(this.dataPrep,1)<1
                        h = warndlg('There is no data analysis results to export.','No data.');
                        setIcon(this, h);
                        return;
                    end
                                  
                     % Check if there are any rows selected for export
                     if ~any( cellfun(@(x) x==1, this.tab_DataPrep.Table.Data(:,1)))
                         h = warndlg({'No rows are selected for export.','Please select the models to export using the left-hand tick boxes.'},'No rows selected for export ...');
                         setIcon(this, h);
                         return;
                     end                        
                    
                    % Ask the user if they want to export all analysis data
                    % (ie logical data reporting on the analysis
                    % undertaken) or just the data not assessed an errerous
                    % or an outlier.
                    response = questdlg_timer(this.figure_icon,15,'Do you want to export the analysis results or just the observations not assessed as being erroneous or outliers?', ...
                        'Data to export?','Export Analysis Results','Export non-erroneous obs.','Cancel','Cancel');
                    
                    if isempty(response) || strcmp(response,'Cancel')
                        return;
                    end
                    
                    if strcmp(response, 'Export Analysis Results')
                        exportAllData = true;
                    else
                        exportAllData = false;
                    end
                    
                    % Get output file name
                    [fName,pName] = uiputfile({'*.csv'},'Input the .csv file name for results file.'); 
                    if fName~=0
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
                    setIcon(this, h);

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
                        if sum(tableInd)==0 || ~this.tab_DataPrep.Table.Data{tableInd,1}
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
                    h = msgbox({'Export of results finished.','', ...
                           ['Number of bore results exported =',num2str(nResultsWritten)], ...
                           ['Number of rows selected for export =',num2str(nResultToExport)], ...
                           ['Number of bore results not exported =',num2str(nResultsNotWritten)]}, ...
                           'Export summary');
                    setIcon(this, h);
                    
                case 'Model Calibration'
                    
                    % Check if there are any rows selected for export
                    if ~any( cellfun(@(x) x==1, this.tab_ModelCalibration.Table.Data(:,1)))
                        h = warndlg({'No rows are selected for export.','Please select the models to export using the left-hand tick boxes.'},'No rows selected for export ...');
                        setIcon(this, h);
                        return;
                    end                    

                    % Ask the user if they want to export the time-series results or the model parameters or the derived parameters.
                    response = questdlg_timer(this.figure_icon,15,'Do you want to export the time-series results, or the model and derived parameters?', ...
                        'Export options.','Time-series results','Model & derived parameters','Cancel','Cancel');                    

                    if isempty(response) || strcmp(response, 'Cancel')
                        return;
                    end
                    
                    % Get output file name
                    [fName,pName] = uiputfile({'*.csv'},'Input the .csv file name for results file.'); 
                    if fName~=0
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
                    if strcmp(response, 'Time-series results')
                        fprintf(fileID,'Model_Label,BoreID,Year,Month,Day,Hour,Minute,Obs_Head,Is_Calib_Point?,Calib_Head,Eval_Head,Model_Err,Noise_Lower,Noise_Upper \n');
                    else 
                        fprintf(fileID,'Model_Label,BoreID,ComponentName,ParameterName,ParameterSetNumber,ParameterSetValue \n');
                    end
                    
                    % Setup wait box
                    h = waitbar(0,'Exporting results. Please wait ...');      
                    setIcon(this, h);
                    
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
                    
                            if strcmp(response, 'Time-series results')
                                % Get the model calibration data.
                                tableData = tmpModel.calibrationResults.data.obsHead;
                                tableData = [tableData, ones(size(tableData,1),1), tmpModel.calibrationResults.data.modelledHead(:,2), ...
                                    nan(size(tableData,1),1), tmpModel.calibrationResults.data.modelledHead_residuals(:,end), ...
                                    tmpModel.calibrationResults.data.modelledNoiseBounds(:,end-1:end)]; %#ok<AGROW> 
                                
                                % Get evaluation data
                                if isfield(tmpModel.evaluationResults,'data')
                                    % Get data
                                    evalData = tmpModel.evaluationResults.data.obsHead;
                                    evalData = [evalData, zeros(size(evalData,1),1), nan(size(evalData,1),1), tmpModel.evaluationResults.data.modelledHead(:,2), ...
                                        tmpModel.evaluationResults.data.modelledHead_residuals(:,end), ...
                                        tmpModel.evaluationResults.data.modelledNoiseBounds(:,end-1:end)]; %#ok<AGROW> 
                                    
                                    % Append to table of calibration data and sort
                                    % by time.
                                    tableData = [tableData; evalData]; %#ok<AGROW> 
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
                                                                
                            else
                                % get the parameters and derived parameters
                                [ParamValues, ParamsNames] = getParameters(tmpModel.model);
                                [derivedParamValues, derivedParamsNames] = getDerivedParameters(tmpModel.model);

                                % Get Bore ID
                                boreID = tmpModel.bore_ID;
                                
                                % Build write format string
                                fmt = '%s,%s,%s,%s,%i,%12.6f \n';                          
                                
                                %Write each parameter and each parameter set (ie if DREAM was used).
                                for j=1:size(ParamsNames,1)
                                    for k=1:size(ParamValues,2)
                                        fprintf(fileID,fmt, modelLabel, boreID, ParamsNames{j,1},ParamsNames{j,2}, k, ParamValues(j,k));
                                    end
                                end
                                
                                %Write each derived parameter and each derived parameter set (ie if DREAM was used).
                                for j=1:size(derivedParamsNames,1)
                                    for k=1:size(derivedParamValues,2)
                                        fprintf(fileID,fmt, modelLabel, boreID, derivedParamsNames{j,1},derivedParamsNames{j,2}, k, derivedParamValues(j,k));
                                    end
                                end                                
                            end
                                
                            % Update counter
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
                    h = msgbox({'Export of results finished.','',['Number of model results exported =',num2str(nResultsWritten)],['Number of models selected for export =',num2str(nModelsToExport)],['Number of selected models not calibrated =',num2str(nModelsNotCalib)]},'Export Summary');
                    setIcon(this, h);
                    
                case 'Model Simulation'
                    % Check if there are any rows selected for export
                    if ~any( cellfun(@(x) x==1, this.tab_ModelSimulation.Table.Data(:,1)))
                        h = warndlg({'No rows are selected for export.','Please select the models to export using the left-hand tick boxes.'},'No rows selected');
                        setIcon(this, h);
                        return;
                    end
                      
                    % Ask the user if they want to export one file per bore (with decomposition)
                    % or all results in one file.
                    response = questdlg_timer(this.figure_icon,15,{'Do you want to export all simulations into one file, or as one file per simulation?','', ...
                        'NOTE: The forcing decomposition results will only be exported using the multi-file option.'}, ...
                        'Export options.','One File','Multiple Files','Cancel','Cancel');
                    
                    if isempty(response) || strcmp(response,'Cancel')
                        return;
                    end
                    
                    if strcmp(response, 'Multiple Files')
                        useMultipleFiles = true;
                        folderName = uigetdir('' ,'Select where to save the .csv simulation files (one file per simulation).');    
                        if isempty(folderName) || (isnumeric(folderName) && folderName==0)
                            return;
                        end
                    else
                        useMultipleFiles = false;
                        fileName = uiputfile({'*.csv','*.*'} ,'Input the file name for the .csv simulation file (all simulations in one file).');    
                        if isempty(fileName) || (isnumeric(fileName) && fileName==0)
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
                    setIcon(this, h);
                    
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
                            
                        catch
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
                            catch
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
                    h = msgbox({'Export of results finished.','', ...
                           ['Number of simulations exported =',num2str(nResultsWritten)], ...
                           ['Number of models not found =',num2str(nModelsNotFound)], ...
                           ['Number of simulations not undertaken =',num2str(nSimsNotUndertaken)], ...
                           ['Number of simulations labels not unique =',num2str(nSimsNotUnique)], ...
                           ['Number of simulations where the construction of results table failed=',num2str(nTableConstFailed)], ...
                           ['Number of simulations where the file could not be written =',num2str(nWritteError)]}, ...
                           'Export Summary');                    
                    setIcon(this, h);
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
                    if fName~=0
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
                    catch
                        % Change cursor
                        set(this.Figure, 'pointer', 'arrow');
                        drawnow update;                            
                        
                        h = warndlg('The table could not be written. Please check you have write permissions to the destination folder.','Save error');
                        setIcon(this, h);
                        return;
                    end

                case {'Model Simulation - results table export', ...
                      'Model Simulation - forcing table export'}
                    
                    % Get model label.
                    modelLabel = this.tab_ModelSimulation.Table.Data{this.tab_ModelSimulation.currentRow,2};
                    modelLabel = HydroSight_GUI.removeHTMLTags(modelLabel);
                    modelLabel = HydroSight_GUI.modelLabel2FieldName(modelLabel);
                                    
                    % Get simulation label
                    simLabel = this.tab_ModelSimulation.Table.Data{this.tab_ModelSimulation.currentRow,6};
                    
                    % Build a default file name.
                    fName = strrep(hObject.Tag, 'Model Simulation - ','');
                    fName = strrep(fName, ' export','');
                    fName = [modelLabel,'_',simLabel,'_', fName,'.csv'];
                  
                    % Get output file name                    
                    [fName,pName] = uiputfile({'*.csv'},'Input the .csv file name for results file.',fName); 
                    if fName~=0
                        % Assign file name to date cell array
                        filename = fullfile(pName,fName);
                    else
                        return;
                    end 
                    
                    % Change cursor
                    set(this.Figure, 'pointer', 'watch');
                    drawnow update;                    
                    
                    % Find table object
                    tablObj = findobj(this.tab_ModelSimulation.resultsTabs,'Tag',strrep(hObject.Tag,' export',''));
                    
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
                    catch
                        % Change cursor
                        set(this.Figure, 'pointer', 'arrow');
                        drawnow update;                            
                        
                        h = warndlg('The table could not be written. Please check you have write permissions to the destination folder.','Save error');
                        setIcon(this, h);
                        return;
                    end
                    
                otherwise
                    h = warndlg('Unexpected Error: GUI table type unknown.','Error');
                    setIcon(this, h);
                    return                    
            end
            
            
        end
        
        function onDocumentation(this, hObject, ~)
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
                    case 'doc_tutes'
                        web('https://github.com/peterson-tim-j/HydroSight/wiki/Tutorials','-browser');
                    case 'doc_Support'
                        web('https://github.com/peterson-tim-j/HydroSight/wiki/Support','-browser');
                end
                
                
            end
            
        end       

        function onCiteProject(this, ~, ~)

            % Check if project includes outlier analysis.
            citeOutliersPaper = false;
            if ~isempty(this.dataPrep)          
                citeOutliersPaper_lbl = 'Error and ourlier detection:';
                citeOutliersPaper = true;
            end

            % Check if project has exp model.
            citeModelExp = false;
            if ~isempty(this.tab_ModelConstruction.Table.Data) && any(strcmp(this.tab_ModelConstruction.Table.Data(:,8),'ExpSmooth'))
                citeModelExp_lbl = 'Exponential smoothing model:';
                citeModelExp = true;
            end

            % Check if project has model_TFN model.
            citeModelTFN = false;
            if ~isempty(this.tab_ModelConstruction.Table.Data) && any(strcmp(this.tab_ModelConstruction.Table.Data(:,8),'model_TFN'))
                citeModelTFN_lbl = 'Nonlinear transfer function noise model:';
                citeModelTFN = true;
            end

            citeShapoori = false;
            citePumpingDownscaling = false;
            citeTwoLayerModel = false;
            citeETConstrainedETLayerModel = false;
            if citeModelTFN
                numRows = size(this.tab_ModelConstruction.Table.Data,1);
                for i=1:numRows
                    % Check if pumping is used.
                    if contains(this.tab_ModelConstruction.Table.Data{i,9},{'responseFunction_FerrisKnowles','responseFunction_FerrisKnowlesJacobs','responseFunction_Hantush'})
                        citeShapoori_lbl = 'Groundwater pumping within transfer function noise model(s):';
                        citeShapoori = true;
                    end

                    % Check if the two layer soil model is used.
                    if contains(this.tab_ModelConstruction.Table.Data{i,9},{'climateTransform_soilMoistureModels_2layer_v2','climateTransform_soilMoistureModels_2layer'})
                        citeTwoLayerModel = true;
                        citeTwoLayerModel_lbl = 'Two-layer soil model within nonlinear transfer function noise model(s):';
                    end                    

                    % Check if the v2 soil models are used.
                    if contains(this.tab_ModelConstruction.Table.Data{i,9},{'climateTransform_soilMoistureModels_v2','climateTransform_soilMoistureModels_2layer_v2'})
                        citeETConstrainedETLayerModel = true;
                        citeETConstrainedETLayerModel_lbl = 'Soil model with ET constrained to within a Budyko derived plausible range range:';
                    end                    
                    
                    % Check if pumping downscaling is used.
                    if contains(this.tab_ModelConstruction.Table.Data{i,9},'pumpingRate_SAestimation')
                        citePumpingDownscaling = true;
                        citePumpingDownscaling_lbl = 'Downscaled estimation of groundwater pumping:';
                    end                    
                    
                end
            end

            % Check calibration schemes
            citeSPUCI = false;
            citeCMAES =  false;
            citeDREAM =  false;
            citeShapooriDREAM = false;
            if ~isempty(this.tab_ModelCalibration.Table.Data) && any(strcmp(this.tab_ModelCalibration.Table.Data(:,8),'SP-UCI'))
                citeSPUCI_lbl = 'Model calibration:';
                citeSPUCI = true;
            end
            if ~isempty(this.tab_ModelCalibration.Table.Data) && any(strcmp(this.tab_ModelCalibration.Table.Data(:,8),'CMA-ES'))
                citeCMAES_lbl = 'Model calibration:';
                citeCMAES = true;
            end
            if ~isempty(this.tab_ModelCalibration.Table.Data) && any(strcmp(this.tab_ModelCalibration.Table.Data(:,8),'DREAM'))
                citeDREAM_lbl = 'Model calibration:';
                citeDREAM = true;
                citeShapooriDREAM = true;
                citeShapooriDREAM_lbl = 'DREAM application to groundwater timeseries modelling:';
            end                        

            % Check if model iterpolation is used.
            citeInterpolationPaper = false;
            if ~isempty(this.tab_ModelSimulation.Table.Data) && any(cell2mat(this.tab_ModelSimulation.Table.Data(:,11)))
                citeInterpolationPaper_lbl = 'Groundwater hydrograph interpolation:';
                citeInterpolationPaper = true;
            end

            % Build citations list
            citations = [];
            if citeSPUCI
                citations = [citations, ...
                    citeSPUCI_lbl, char newline, ...
                    'Chu W., Gao X. and Sorooshian S. (2011). A new evolutionary search strategy for global optimization of high-dimensional problems. Information Sciences, 181(22), 4909–4927. http://dx.doi.org/10.1016/j.ins.2011.06.024 10.1016/j.ins.2011.06.024', ...
                    char newline, char newline];
            end            
            if citeCMAES
                citations = [citations, ...
                    citeCMAES_lbl, char newline, ...
                    'Hansen, N. (2006). The CMA Evolution Strategy: A Comparing Review. In J.A. Lozano, P. Larrañga, I. Inza and E. Bengoetxea (eds.). Towards a new evolutionary computation. Advances in estimation of distribution algorithms. pp. 75-102, Springer', ...
                    char newline, char newline];
            end                      
            if citeTwoLayerModel
                citations = [citations,  ...
                    citeTwoLayerModel_lbl, char newline, ...
                    'Peterson, T.J. and Fulton, S. (2019), Joint Estimation of Gross Recharge, Groundwater Usage, and Hydraulic Properties within HydroSight. Groundwater, 57, 860-876, https://doi.org/10.1111/gwat.12946', ...
                    char newline, char newline];
            end                                
            if citeETConstrainedETLayerModel
                citations = [citations,  ...
                    citeETConstrainedETLayerModel_lbl, char newline, ...
                    'Peterson, T.J. and Fulton, S. (2019), Joint Estimation of Gross Recharge, Groundwater Usage, and Hydraulic Properties within HydroSight. Groundwater, 57, 860-876, https://doi.org/10.1111/gwat.12946', ...
                    char newline, char newline];
            end                    
            if citePumpingDownscaling
                citations = [citations,  ...
                    citePumpingDownscaling_lbl, char newline, ...
                    'Peterson, T.J. and Fulton, S. (2019), Joint Estimation of Gross Recharge, Groundwater Usage, and Hydraulic Properties within HydroSight. Groundwater, 57, 860-876, https://doi.org/10.1111/gwat.12946', ...
                    char newline, char newline];
            end            
            if citeModelTFN
                citations = [citations, ...
                    citeModelTFN_lbl, char newline, ...
                    'Peterson, T. J., and Western, A. W. (2014), Nonlinear time-series modeling of unconfined groundwater head, Water Resour. Res., 50, 8330– 8355, https://doi.org/10.1002/2013WR014800.', ...
                    char newline, char newline];
            end
            if citeInterpolationPaper
                citations = [citations,  ...
                    citeInterpolationPaper_lbl, char newline, ...
                    'Peterson, T.J., & Western, A.W. (2018). Statistical interpolation of groundwater hydrographs. Water Resources Research, 54, 4663– 4680. https://doi.org/10.1029/2017WR021838', ...
                    char newline, char newline];
            end            
            if citeOutliersPaper
                citations = [citations, ...
                    citeOutliersPaper_lbl, char newline, ...
                    'Peterson, T.J., Western, A.W. & Cheng, X. (2018), The good, the bad and the outliers: automated detection of errors and outliers from groundwater hydrographs. Hydrogeol. J., 26, 371–380, https://doi.org/10.1007/s10040-017-1660-7', ...
                    char newline, char newline];
            end

            if citeModelExp
                citations = [citations, ...
                    citeModelExp_lbl, char newline, ...
                    'Peterson, T.J., Western, A.W. & Cheng, X. (2018), The good, the bad and the outliers: automated detection of errors and outliers from groundwater hydrographs. Hydrogeol. J., 26, 371–380, https://doi.org/10.1007/s10040-017-1660-7', ...
                    char newline, char newline];
            end
                        
            if citeShapoori
                citations = [citations, ...
                    citeShapoori_lbl, char newline, ...
                    'Shapoori, V., Peterson, T.J., Western, A.W. and Costelloe, J. F. (2015) Top-down groundwater hydrograph time-series modeling for climate-pumping decomposition. Hydrogeol. J., 23, 819–836, https://doi.org/10.1007/s10040-014-1223-0', ...
                    char newline, char newline];

                citations = [citations, ...
                    'Shapoori, V., Peterson, T.J., Western, A.W. and Costelloe, J. F. (2015) Decomposing groundwater head variations into meteorological and pumping components: a synthetic study. Hydrogeol. J. 23, 1431–1448, https://doi.org/10.1007/s10040-015-1269-7', ...
                    char newline, char newline];
            end
            if citeShapoori
                citations = [citations, ...
                    citeShapoori_lbl, char newline, ...
                    'Shapoori, V., Peterson, T.J., Western, A.W., and Costelloe, J.F. (2015) Estimating aquifer properties using groundwater hydrograph modelling. Hydrol. Process., 29, 5424– 5437, https://doi.org/10.1002/hyp.10583. ', ...
                    char newline, char newline];
            end
            if citeShapooriDREAM
                citations = [citations, ...
                    citeShapooriDREAM_lbl, char newline, ...
                    'Shapoori, V., Peterson, T.J., Western, A.W., and Costelloe, J.F. (2015) Estimating aquifer properties using groundwater hydrograph modelling. Hydrol. Process., 29, 5424– 5437, https://doi.org/10.1002/hyp.10583. ', ...
                    char newline, char newline];
            end
            
            if citeDREAM
                citations = [citations,  ...
                    citeDREAM_lbl, char newline, ...
                    'Vrugt J. (2016). Markov chain Monte Carlo simulation using the DREAM software package: Theory, concepts, and MATLAB implementation. Environmental Modelling & Software 75, 273-316, http://dx.doi.org/10.1016/j.envsoft.2015.08.013 10.1016/j.envsoft.2015.08.013'];
            end

            % Show citations
            f = figure( ...
                'Name', 'HydroSight project citations', ...
                'NumberTitle', 'off', ...
                'MenuBar', 'none', ...
                'HandleVisibility', 'off', ...
                'Visible','on', ...
                'Toolbar','none');                             

            % Set size etc
            windowHeight = f.Parent.ScreenSize(4);
            windowWidth = f.Parent.ScreenSize(3);
            figWidth = 0.7*windowWidth;
            figHeight = 0.5*windowHeight;
            f.Position = [(windowWidth - figWidth)/2 (windowHeight - figHeight)/2 figWidth figHeight];

            % Change icon
            setIcon(this, f);

            hbox = uiextras.VBoxFlex('Parent', f,'Padding', 3, 'Spacing', 3);
            uicontrol(hbox,'Style','text','String','This project uses features from the following papers. Please cite them to support HydroSight development (ctrl-c to copy): ','HorizontalAlignment','left', 'Units','normalized', 'FontSize',12);            
            uicontrol(hbox,'Style','edit','HorizontalAlignment','left', 'Units','normalized',...
                'BackgroundColor',[1 1 1], 'String', citations, 'Min',1,'Max',200, ...
                'TooltipString','Papers to cite for this project.','FontSize',12);   
            bbox = uiextras.HButtonBox('Parent', hbox,'Padding', 3, 'Spacing', 3);
            uicontrol('Parent',bbox,'String','Save as ...','Callback', @saveCitations,  ...
                'FontSize',12,'Tag','Citations save as', 'TooltipString', 'Save citations to a text file.');
            bbox.ButtonSize(1) = 225;
            set(hbox,'Sizes',[30,-1,50]);

            function saveCitations(~,~,~)
                if isempty(this.project_fileName)
                    fname = 'HydroSight_citations.txt';
                else
                    [~,projname]=fileparts(this.project_fileName);
                    fname = [projname,'_citations.txt'];
                end
                [fName,pName] = uiputfile({'*.txt'},'Input file name for citations text file.',fname);   
                fid = fopen(fullfile(pName, fName),'w');
                fprintf(fid, '%s',['The HydroSight project "',projname,'" used features from the following papers. Please cite them to support HydroSight development:',char newline,char newline]); 
                fprintf(fid, '%s',citations);
                fclose(fid);
            end
        end
               
        function onGitHub(this, hObject, ~) %#ok<INUSL> 
           if strcmp(hObject.Tag,'doc_GitHubUpdate') 
               web('https://github.com/peterson-tim-j/HydroSight/releases','-browser');
           elseif strcmp(hObject.Tag,'doc_GitHubIssue') 
               web('https://github.com/peterson-tim-j/HydroSight/issues','-browser');
           end                                   
        end
        
        function onVersion(this, ~, ~)         
            [versionNumber,versionDate] = getHydroSightVersion();
            h = msgbox({['This is version ',versionNumber, ' of HydroSight GUI.'],'',['It was released on ',versionDate]},'HydroSight version');
            setIcon(this, h);
        end
        
        function onLicenseDisclaimer(this, ~, ~) %#ok<INUSD> 
           web('https://github.com/peterson-tim-j/HydroSight/wiki/Disclaimer-and-Licenses','-browser');
        end                       
        
        function onPrint(this, ~, ~)
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
        
%         function onExportPlot(this, ~, ~)
%             set(this.Figure, 'pointer', 'watch');
%             switch this.figure_Layout.Selection
%                 case {1,3}
%                     errordlg('No plot is displayed within the current tab.');
%                     return;
%                 case 2      % Data prep.
%                     pos = get(this.tab_DataPrep.modelOptions.resultsOptions.box.Children(2),'Position'); 
%                     legendObj = this.tab_DataPrep.modelOptions.resultsOptions.plots.Legend;
%                     
%                     f=figure('Visible','off');
%                     copyobj(this.tab_DataPrep.modelOptions.resultsOptions.plots,f);
%                     
%                     % Format figure                    
%                     set(f, 'Color', 'w');
%                     set(f, 'PaperType', 'A4');
%                     set(f, 'PaperOrientation', 'landscape');
%                     set(f, 'Position', pos);
%                 case 4      % Model Calib.
%                     f=figure('Visible','off');
%                     switch this.tab_ModelCalibration.resultsTabs.SelectedChild
%                         case 1
%                             pos = get(this.tab_ModelCalibration.resultsOptions.calibPanel.Children.Children(1).Children(1),'Position');
%                             if length(this.tab_ModelCalibration.resultsOptions.calibPanel.Children.Children(1).Children(1))==1
%                                 legendObj = [];
%                                 copyobj(this.tab_ModelCalibration.resultsOptions.calibPanel.Children.Children(1).Children(1).Children,f);
%                             else
%                                 copyobj(this.tab_ModelCalibration.resultsOptions.calibPanel.Children.Children(1).Children(1).Children(2),f);
%                                 legendObj = this.tab_ModelCalibration.resultsOptions.calibPanel.Children.Children(1).Children(1).Children(1);
%                             end
%                         case 2
%                             pos = get(this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(4),'Position');
%                             if length(this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(4))==1
%                                 copyobj(this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(4).Children,f);
%                                 legendObj = [];
%                             else
%                                 copyobj(this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(4).Children(end),f);
%                                 legendObj = this.tab_ModelCalibration.resultsOptions.forcingPanel.Contents.Contents(4).Children(end-1);                                
%                             end
%                         case 3
%                             pos = get(this.tab_ModelCalibration.resultsOptions.paramsPanel.Children.Children(1),'Position');
%                             copyobj(this.tab_ModelCalibration.resultsOptions.paramsPanel.Children.Children(1).Children,f);                             
%                             legendObj = [];
%                         case 4
%                             pos = get(this.tab_ModelCalibration.resultsOptions.derivedParamsPanel.Children.Children(1),'Position');
%                             copyobj(this.tab_ModelCalibration.resultsOptions.derivedParamsPanel.Children.Children(1).Children,f);                             
%                             legendObj = [];
%                             
%                         case 5
%                             pos = get(this.tab_ModelCalibration.resultsOptions.modelSpecificsPanel.Children.Children(1),'Position');
%                             copyobj(this.tab_ModelCalibration.resultsOptions.modelSpecificsPanel.Children.Children(1).Children,f);                             
%                             legendObj = [];                            
%                     end
% 
%                     % Format figure
%                     set(f, 'Color', 'w');
%                     set(f, 'PaperType', 'A4');
%                     set(f, 'PaperOrientation', 'landscape');
%                     set(f, 'Position', pos);
%                     
%                 case 5      % Model Simulation.    
%                     f=figure('Visible','off');
%                     nplots = length(this.tab_ModelSimulation.resultsOptions.plots.panel.Children);
%                     pos = get(this.tab_ModelSimulation.resultsOptions.plots.panel,'Position');
%                     copyobj(this.tab_ModelSimulation.resultsOptions.plots.panel.Children(1:nplots),f);  
%                     legendObj = [];
%                     
%                     % Format each axes
%                     ax =  findall(f,'type','axes');
%                     for i=1:nplots
%                         set(ax(i), 'Color', 'w');
%                     end
%                     
%                     % Format figure
%                     set(f, 'Color', 'w');
%                     set(f, 'PaperType', 'A4');
%                     set(f, 'PaperOrientation', 'landscape');
%                     set(f, 'Position', pos);                    
%                 otherwise
%                     return;
%             end
%                         
%             % set current folder to the project folder (if set)
%             set(this.Figure, 'pointer', 'arrow');
%             if ~isempty(this.project_fileName)                                
%                 try    
%                     if isfolder(this.project_fileName)
%                         currentProjectFolder = this.project_fileName;
%                     else
%                         currentProjectFolder = fileparts(this.project_fileName);
%                     end 
%                     
%                     currentProjectFolder = [currentProjectFolder,filesep];
%                     cd(currentProjectFolder);
%                 catch
%                     % do nothing
%                 end
%             end
%             fName = uiputfile({'*.png'},'Save plot PNG image as ...','plot.png');    
%             if fName~=0    
%                 set(this.Figure, 'pointer', 'watch');
%                 
%                 % Export image
%                 if ~isempty(legendObj)
%                     legend(gca,legendObj.String,'Location',legendObj.Location)
%                 end
%                 export_fig(f, fName);
%             end
%             close(f);
%             set(this.Figure, 'pointer', 'arrow');
%             
%         end

        % Load example models
        function onExamples(this, ~, eventdata, folderName)
            
            % When foldername is specified (by HydroSightTest()) then the rquest for 
            % user inputs is avoided. This is done to allow automated for unit testing.
            if nargin < 4
                % Check if all of the GUI tables are empty. If not, warn the
                % user the opening the example will delete the existing data.
                if ~isempty(this.tab_Project.project_name.String) || ...
                        ~isempty(this.tab_Project.project_description.String) || ...
                        (size(this.tab_ModelCalibration.Table.Data,1)~=0 && any(~any(cellfun( @(x) isempty(x), this.tab_ModelConstruction.Table.Data(:,1:9))))) || ...
                        (size(this.tab_ModelCalibration.Table.Data,1)~=0 && any(~any(cellfun( @(x) isempty(x), this.tab_ModelCalibration.Table.Data)))) || ...
                        (size(this.tab_ModelSimulation.Table.Data,1)~=0 && any(~any(cellfun( @(x) isempty(x), this.tab_ModelSimulation.Table.Data))))
                    response = questdlg_timer(this.figure_icon,15,{'Opening an example project will close the current project.','','Do you want to continue?'}, ...
                        'Close the current project?','Yes','No','No');

                    if isempty(response) || strcmp(response,'No')
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
                    'time-series models. You can use these models to undertake', ...
                    'simulations, or alternatively you can rebuild and calibrate, or edit,', ...
                    'the models.'},'Opening Example Models ...','help') ;
                setIcon(this, h);
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
                if isempty(folderName) || (isnumeric(folderName) && folderName==0)
                    return;
                end                
            end
            
            % Change cursor
            set(this.Figure, 'pointer', 'watch');      
            drawnow update;

            % Initialise whole GUI and variables
            initialiseGUI(this);
            
            % Set project folder
            this.project_fileName = folderName;

            % Build .csv file names and add to the GUI construction table.
            disp('Saving .csv files ...');
            forcingFileName = fullfile(folderName,'forcing.csv');
            forcingSimulationFileName = fullfile(folderName,'forcingSimulation.csv');
            coordsFileName = fullfile(folderName,'coordinates.csv');
            headFileName = fullfile(folderName,'obsHead.csv');
                        
            % Open example .mat data file for the required example.
            disp('Opening data files ...');
            switch eventdata.Source.Tag
                case 'TFN - LUC'
                    exampleData = load('BourkesFlat_data.mat');
                    writeHeadObsData = true;
                    writeForcingData = true;
                    writeForcingSimulation = true;
                    writeCoordsData = true;
                case 'TFN - Pumping'
                    exampleData = load('Clydebank_data.mat');
                    writeHeadObsData = true;
                    writeForcingData = true;
                    writeForcingSimulation = false;
                    writeCoordsData = true;  
                case 'TFN - Incomplete pumping record'
                    exampleData = load('Warrion_data.mat');
                    writeHeadObsData = true;
                    writeForcingData = true;
                    writeForcingSimulation = false;
                    writeCoordsData = true;                      
                case 'Outlier - Telemetered'
                    exampleData = load('OutlierDetection_data.mat');                    
                    writeHeadObsData = true;
                    writeForcingData = false;
                    writeForcingSimulation = false;
                    writeCoordsData = false;                    
                otherwise
                    set(this.Figure, 'pointer', 'arrow');   
                    drawnow update;
                    h = warndlg('The requested example model could not be found.','Example model error');
                    setIcon(this, h);
                    return;
            end
            
            % Check there is the required data
            if writeHeadObsData && ~isfield(exampleData,'obsHead')
                set(this.Figure, 'pointer', 'arrow');   
                drawnow update;
                h = warndlg('The example data for the model does not exist. It must contain observed head data.','Example Model Data Error ...');
                setIcon(this, h);
                return;                
            end
            if writeForcingData && ~isfield(exampleData,'forcing')
                set(this.Figure, 'pointer', 'arrow');   
                drawnow update;
                h = warndlg('The example data for the model does not exist. It must contain forcing data.','Example Model Data Error ...');
                setIcon(this, h);
                return;                
            end            
            if writeForcingSimulation && ~isfield(exampleData,'forcingSimulation')
                set(this.Figure, 'pointer', 'arrow');
                drawnow update;
                h = warndlg('The example data for the model does not exist. It must contain simulation forcing data.','Example Model Data Error ...');
                setIcon(this, h);
                return;
            end            
            if writeCoordsData &&  ~isfield(exampleData,'coordinates')
                set(this.Figure, 'pointer', 'arrow');   
                drawnow update;
                h = warndlg('The example data for the model does not exist. It must contain coordinates data.','Example Model Data Error ...');
                setIcon(this, h);
                return;                
            end
                        
            % Export the csv file names.
            disp('Saving .csv files ...');
            if writeHeadObsData
                writetable(exampleData.obsHead,headFileName);
            end
            if writeForcingData
                writetable(exampleData.forcing,forcingFileName);
            end
            if writeForcingSimulation
                writetable(exampleData.forcingSimulation,forcingSimulationFileName);
            end            
            if writeCoordsData
                writetable(exampleData.coordinates,coordsFileName);
            end
            
            
            % Load the GUI table data and model.
            disp('Opening model files ...');
            try                
                switch eventdata.Source.Tag
                    case 'TFN - LUC'                    
                        exampleModel = load('BourkesFlat_model.mat');
                    case 'TFN - Pumping'
                        exampleModel = load('Clydebank_model.mat');
                    case 'TFN - Incomplete pumping record'
                        exampleModel = load('Warrion_model.mat');
                    case 'Outlier - Telemetered'
                        exampleModel = load('OutlierDetection_model.mat');                        
                    otherwise
                        set(this.Figure, 'pointer', 'arrow');             
                        drawnow update;
                        h = warndlg('The requested example model could not be found.','Example Model Error ...');
                        setIcon(this, h);
                        return;
                end            
                
            catch
                set(this.Figure, 'pointer', 'arrow');
                drawnow update;
                h = warndlg('Project file could not be loaded.','File error');                
                setIcon(this, h);
                return;
            end
            
            
            % Assign data to the GUI
            %------------------------------          
            disp('Updating file names in GUI ...');
            % Assign loaded data to the tables and models.
            this.tab_Project.project_name.String = exampleModel.tableData.tab_Project.title;
            this.tab_Project.project_description.String = exampleModel.tableData.tab_Project.description;

            % Data prep data.
            this.tab_DataPrep.Table.Data = exampleModel.tableData.tab_DataPrep;
            nrows = size(this.tab_DataPrep.Table.Data,1);
            this.tab_DataPrep.Table.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));                    

            % Model constrcuion data and if the head obs freq is missing, then add it in.
            if size(exampleModel.tableData.tab_ModelConstruction,2)==9
                numRows = size(exampleModel.tableData.tab_ModelConstruction,1);
                exampleModel.tableData.tab_ModelConstruction = [exampleModel.tableData.tab_ModelConstruction(:,1:6), ...
                    num2cell(ones(numRows,1)), exampleModel.tableData.tab_ModelConstruction(:,7:9)];
            end
            this.tab_ModelConstruction.Table.Data = exampleModel.tableData.tab_ModelConstruction;
            nrows = size(this.tab_ModelConstruction.Table.Data,1);
            this.tab_ModelConstruction.Table.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));     

            % Model Calib data
            if size(exampleModel.tableData.tab_ModelCalibration,2)==14
                this.tab_ModelCalibration.Table.Data =  exampleModel.tableData.tab_ModelCalibration(:,[1:8,10:14]);
            else
                this.tab_ModelCalibration.Table.Data = exampleModel.tableData.tab_ModelCalibration;
            end
            nrows = size(this.tab_ModelCalibration.Table.Data,1);
            this.tab_ModelCalibration.Table.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));                      

            % Model Simulation
            this.tab_ModelSimulation.Table.Data = exampleModel.tableData.tab_ModelSimulation;
            nrows = size(this.tab_ModelSimulation.Table.Data,1);
            this.tab_ModelSimulation.Table.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));                       

            % Set flag denoting models are on RAM.            
            this.modelsOnHDD =  '';

            % Load model objects 
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
            vernum = getHydroSightVersion();
            set(this.Figure,'Name',['HydroSight ', vernum,': ', this.project_fileName]);
            drawnow update;                            
            
            % Convert Simulation model labels from a variable name to the full
            % label (ie without _ chars etc)
            if ~isempty(this.tab_ModelSimulation.Table.Data)
                model_label = this.tab_ModelSimulation.Table.Data(:,2);
                for i=1:length(model_label)
                    if isfield(this.models,model_label{i}) && ...
                            isprop(this.models.(model_label{i}),'model_label')
                        model_label{i} = this.models.(model_label{i}).model_label;
                    end
                end
                this.tab_ModelSimulation.Table.Data(:,2) = model_label;
            end

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
                
        function onChangeTableWidth(this, hObject, ~, tableTag)
            
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

        function onNextPlot(this, hObject, eventdata)

            % Get model object
            switch hObject.Tag
                case {'Model Calibration - previous results plot','Model Calibration - next results plot'}
                    tmpModel = getModel(this, this.tab_ModelCalibration.currentModel);
                case {'Model Simulation - next results plot', 'Model Simulation - previous results plot'}
                    irow = this.tab_ModelSimulation.currentRow;
                    modelLabel = this.tab_ModelSimulation.Table.Data{irow, 2};
                    simLabel = this.tab_ModelSimulation.Table.Data{irow, 6};
                    tmpModel = getModel(this, modelLabel);                    
            end
            

            % Exit if model not found.
            if isempty(tmpModel)
                % Turn off plot icons
                plotToolbarState(this,'off');

                % Change cursor
                set(this.Figure, 'pointer', 'arrow');
                drawnow update;
                return;
            end

            switch hObject.Tag              
                case {'Model Calibration - previous results plot','Model Calibration - next results plot'}
                    % Get drodown object
                    obj = findobj(this.tab_ModelCalibration.resultsOptions.calibPanel, 'Tag','Model Calibration - results plot dropdown');
                    plotID = obj.Value;

                    % Get max number of plots.
                    plotID_max = length(obj.String);

                    % Update dropdown value
                    if strcmp( eventdata.Source.Tag,'Model Calibration - previous results plot')
                        if plotID >1
                            plotID = plotID -1;
                        else
                            plotID =plotID_max;                            
                        end                        
                    else
                        if plotID < plotID_max
                            plotID = plotID+1;
                        else 
                            plotID = 1;
                        end                   
                    end
                    obj.Value = plotID;
            
                    % Redraw plot.
                    obj = findobj(this.tab_ModelCalibration.resultsOptions.calibPanel,'Tag','Model Calibration - results plot');
                    delete( findobj(obj ,'type','axes'));
                    delete( findobj(obj ,'type','legend'));

                    obj = uipanel('Parent', obj,'BackgroundColor',[1,1,1]);
                    axisHandle = axes( 'Parent', obj);

                    % Show the calibration plots.
                    calibrateModelPlotResults(tmpModel, plotID, axisHandle);
                    
                case {'Model Simulation - previous results plot', 'Model Simulation - next results plot'}

                    % Get drodown object
                    obj = findobj(this.tab_ModelSimulation.resultsOptions.simPanel, 'Tag','Model Simulation - results plot dropdown');
                    plotID = obj.Value;

                    % Get max number of plots.
                    plotID_max = length(obj.String);

                    % Update dropdown value
                    if strcmp( eventdata.Source.Tag,'Model Simulation - previous results plot')
                        if plotID >1
                            plotID = plotID -1;
                        else
                            plotID =plotID_max;
                        end
                    else
                        if plotID < plotID_max
                            plotID = plotID+1;
                        else
                            plotID = 1;
                        end
                    end
                    obj.Value = plotID;

                    % Update plot
                    plotToolbarState(this,'on');
                    modelSimulation_onUpdatePlotSetting(this, hObject, eventdata, tmpModel, simLabel);
                    this.tab_ModelSimulation.resultsTabs.TabEnables{2} = 'on';

            end

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
                if size(tableObj.Data(:,1),1)>0 &&  ~anySelected 
                    if strcmp(hObject.Label,'Insert row below selection')
                        selectedRows(end) = true;
                    elseif strcmp(hObject.Label,'Insert row above selection')
                        selectedRows(1) = true;
                    elseif ~strcmp(hObject.Label,'Paste rows')
                        h = warndlg('No rows are selected for the requested operation.');
                        setIcon(this, h);
                        return;
                    end
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
                    modelStatus = '<html><font color = "#FF0000">Not analysed.</font></html>';
                    modelStatus_col = 16;
                    defaultData = {false, '', '',0, 0, 0, '01/01/1900',true, true, true, true, 10, 120, 4,false, modelStatus, ...
                    '<html><font color = "#808080">(NA)</font></html>', ...
                    '<html><font color = "#808080">(NA)</font></html>'};
                case 'Model Construction'
                    modelStatus = '<html><font color = "#FF0000">Not built.</font></html>';
                    modelStatus_col = 10;
                case 'Model Calibration'
                    modelStatus = '<html><font color = "#FF0000">Not calibrated.</font></html>';
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
                        h = warndlg('The copied row data was sourced from a different table.','Paste error');
                        setIcon(this, h);
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
                                    tableObj.Data{size(tableObj.Data,1),modelStatus_col} = modelStatus;                                    
                                end
                                % Update row numbers.
                                nrows = size(tableObj.Data,1);
                                tableObj.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));                                
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
                                    tableObj.Data{i,9} = this.copiedData.data{1,9};
                                    this.copiedData.data{i,modelStatus_col} = modelStatus;
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
                                    tableObj.Data{irow,modelStatus_col} = modelStatus;                                    
                                end
                                % Update row numbers.
                                nrows = size(tableObj.Data,1);
                                tableObj.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));                                           
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
                            tableObj.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));                                        
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
                                tableObj.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));                                            
                            end                            
                    end
                    
                    % Update row numbers.
                    nrows = size(tableObj.Data,1);
                    tableObj.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));
                    
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
                    tableObj.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));
                        
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
                    tableObj.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));

                case 'Delete selected rows'    
                    
                    % Delete the model objects if within the model
                    % construction table
                    if strcmp(tableObj.Tag,'Model Construction')                        
                        for i=indSelected
                            % Delete the model object
                            try
                                deleteModel(this, this.tab_ModelConstruction.Table.Data{i,2});

                                % Delete row from calib table.
                                ind = cellfun( @(x) strcmp(x, this.tab_ModelConstruction.Table.Data{i,2}), HydroSight_GUI.removeHTMLTags(this.tab_ModelCalibration.Table.Data(:,2)) );
                                if any(ind)
                                    % Delete row.
                                    this.tab_ModelCalibration.Table.Data = this.tab_ModelCalibration.Table.Data(~ind,:);

                                    % Update row numbers.
                                    nrows = size(this.tab_ModelCalibration.Table.Data,1);
                                    this.tab_ModelCalibration.Table.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));
                                end

                                % Delete row from simulation table.
                                ind = cellfun( @(x) strcmp(x, this.tab_ModelConstruction.Table.Data{i,2}), HydroSight_GUI.removeHTMLTags(this.tab_ModelSimulation.Table.Data(:,2)) );
                                if any(ind)
                                    % Delete row.
                                    this.tab_ModelSimulation.Table.Data = this.tab_ModelSimulation.Table.Data(~ind,:);

                                    % Update row numbers.
                                    nrows = size(this.tab_ModelSimulation.Table.Data,1);
                                    this.tab_ModelSimulation.Table.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));
                                end                                
                            catch
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
                    tableObj.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));
                    
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
                    irows = transpose(1:size(tableObj.Data,1));
                    try
                        startRow=str2double(rowRange{1});
                        endRow=str2double(rowRange{2});
                    catch
                        h = warndlg('The first and last row inputs must be numbers','Input Error');
                        setIcon(this, h);
                        return;
                    end
                    if startRow>= endRow
                        h = warndlg('The first row must be less than the last row.','Input Error');
                        setIcon(this, h);
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
                        filt = cellfun(@(x) contains(upper(x),upper(colNames_str{1})) , tableObj.Data(:,selectedCol));
                        filt = filt | selectedRows;
                        
                        % Select rows
                        tableObj.Data(:,1) =  mat2cell(filt,ones(1, size(selectedRows,1)));
                    end
                case 'Copy selected model labels'
                    % Get selected rows
                    if ~isempty(tableObj.Data) && ...
                    any(strcmp(tableObj.Tag, {'Model Construction', 'Model Calibration', 'Model Simulation'}))
                        for i=1:size(tableObj.Data,1)
                            if isempty(tableObj.Data{i,1})
                                tableObj.Data{i,1}=false;
                            end
                        end
                        selectedRows = cell2mat(tableObj.Data(:,1));

                        this.copiedData.tableName = tableObj.Tag;
                        this.copiedData.data = HydroSight_GUI.removeHTMLTags(tableObj.Data(selectedRows,2));                              
                    end
                case 'Select copied model labels'
                    if ~isempty(tableObj.Data) && ...
                    any(strcmp(tableObj.Tag, {'Model Construction', 'Model Calibration', 'Model Simulation'})) && ...
                    iscell(this.copiedData.data) && size(this.copiedData.data,1)>0 && size(this.copiedData.data,2)==1

                        tableModelLabels = HydroSight_GUI.removeHTMLTags(tableObj.Data(:,2)); 
                        ind = cellfun(@(x) any(strcmp(x,this.copiedData.data)), tableModelLabels);
                        if any(ind)
                            tableObj.Data(ind,1) = {true};
                        end
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
            if isfolder(this.project_fileName)
                projectPath = this.project_fileName;
            else
                projectPath = fileparts(this.project_fileName);
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
            if fName~=0
                % Check if the file name is the same as the
                % project path.
                if ~contains(pName,projectPath)
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
                if ~isempty(this.models) && isa(this.models.(modelLabel),'HydroSightModel')                    
                    model = this.models.(modelLabel);
                    errmsg = '';
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
                    if ~isa(model,'HydroSightModel')
                        errmsg = ['The following model is not a HydroSight object and could not be loaded:',modelLabel];    
                        model=[];
                    else 
                        errmsg = '';
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
                elseif ischar(model)
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
                if isempty(this.model_labels)
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
   
        function startCalibration(this,hObject,eventdata)

            % Get table data
            data = this.tab_ModelCalibration.Table.Data;      
            selectedBores = data(:,1);
                                    
            % Check that the user wants to save the projct after each
            % calib.
            saveModels=false;
            if ~strcmp(hObject.Tag,'Start calibration - useHPC')
                set(this.Figure, 'pointer', 'arrow');
                drawnow update
                
                response = questdlg_timer(this.figure_icon,15,'Do you want to save the project after each model is calibrated?', ...
                    'Auto-save models?','Yes','No','Cancel','Yes');
                if isempty(response) || strcmp(response,'Cancel')
                    return;
                end
                if strcmp(response,'Yes') && (isempty(this.project_fileName) || exist(this.project_fileName,'file') ~= 2)
                    h = msgbox('The project has not yet been saved. Please save it and re-run the calibration.','Project not saved','error');
                    setIcon(this, h);
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
            obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','Skip calibration');
            obj.Enable = 'on';

            if ~isdeployed && ~strcmp(hObject.Tag,'Start calibration - useHPC')
                obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','Start calibration - useHPC');
                obj.Enable = 'off';
                obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','Start calibration - useHPC import');
                obj.Enable = 'off';                
            end            
            
            % Change cursor
            set(this.Figure, 'pointer', 'watch');
            drawnow update
            
            % Open parrallel engine for calibration
            if ~any(strcmp(hObject.Tag,{'Start calibration - useHPC', 'Start calibration - noparpool'}))
                try
                    %nCores=str2double(getenv('NUMBER_OF_PROCESSORS'));
                    parpool('local');
                catch
                    % Do nothing. An error is probably that parpool is already
                    % open
                end
            end
            
            % Count the number of models selected
            nModels=0;
            for i=1:length(selectedBores)                 
                if ~isempty(selectedBores{i}) && selectedBores{i}
                    nModels = nModels +1;
                end
            end
            
            % Setup wait bar
            waitBarPlot = findobj(this.tab_ModelCalibration.GUI, 'Tag','Calib_wait_bar');
            waitBarPlot.YData=0;                                                                       

            % Get initial directoty
            initial_pwd = pwd();

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

                % Clear the stored forcing data if this model
                % label equals the model label of the
                % stored data.
                if ~isfield(this.tab_ModelCalibration.resultsOptions,'forcingData') || ...
                (isfield(this.tab_ModelCalibration.resultsOptions.forcingData,'modelLabel') && ...
                strcmp(calibLabel,this.tab_ModelCalibration.resultsOptions.forcingData.modelLabel))
                    this.tab_ModelCalibration.resultsOptions.forcingData.modelLabel = '';
                    this.tab_ModelCalibration.resultsOptions.forcingData.data_input = [];
                    this.tab_ModelCalibration.resultsOptions.forcingData.data_derived = [];
                    this.tab_ModelCalibration.resultsOptions.forcingData.colnames_input = {};
                    this.tab_ModelCalibration.resultsOptions.forcingData.colnames_derived = {};
                    this.tab_ModelCalibration.resultsOptions.forcingData.filt=[];
                end
                                
                % Get start and end date. Note, start date is at the start
                % of the day and end date is shifted to the end of the day.
                calibStartDate = datenum( data{i,6},'dd-mmm-yyyy');
                calibEndDate = datenum( data{i,7},'dd-mmm-yyyy') + datenum(0,0,0,23,59,59);
                calibMethod = data{i,8};

                % Update progress bar with current model
                set(waitBarPlot.Parent.Title,'String',['Current Model: ',strrep(calibLabel,'_',' '),'. Current Method: ',calibMethod]);               

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

                % Get parameter names.
                [~, param_names] = getParameters(tmpModel.model);

                % Create axes for plots of calibration progress.                
                modelCalibration_CalibPlotsUpdate(this, true, calibMethod, param_names, [], [], [], [], [], []);
                
                % Update status to starting calib.
                this.tab_ModelCalibration.Table.Data{i,9} = '<html><font color = "#FFA500">Calibrating ... </font></html>';

                % Update status in GUI
                drawnow

                % Collate calibration settings
                calibMethodSetting=struct();
                switch calibMethod                    
                    case {'CMAES','CMA-ES'}
                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','CMAES MaxFunEvals');
                        calibMethodSetting.MaxFunEvals= str2double(obj.String);

                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','CMAES popsize');
                        calibMethodSetting.PopSize= str2double(obj.String);

                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','CMAES TolFun');
                        calibMethodSetting.TolFun= str2double(obj.String);

                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','CMAES TolX');
                        calibMethodSetting.TolX= str2double(obj.String);

                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','CMAES Restarts');
                        calibMethodSetting.Restarts= str2double(obj.String);

                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','CMAES Sigma');
                        calibMethodSetting.Sigma= str2double(obj.String);

                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','CMAES iseed');
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
                        [~, param_names] = getParameters(tmpModel.model);
                        nparams = size(param_names,1);

                        % Calculate the number of complexes for this model.
                        calibMethodSetting.ngs = max(ngs_min, min(ngs_max, ngs_per_param*nparams));

                    case 'DREAM'
                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','DREAM prior');
                        calibMethodSetting.prior = obj.String{obj.Value};

                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','DREAM sigma');
                        calibMethodSetting.sigma = str2double(obj.String);
                        
                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','DREAM N');
                        calibMethodSetting.N_per_param = str2double(obj.String);

                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','DREAM Tmin');
                        calibMethodSetting.Tmin = str2double(obj.String);

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

                        obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','DREAM iseed');
                        calibMethodSetting.iseed = str2double(obj.String);  
                end
                        
                % Start calib.
                try                    
                    if strcmp(hObject.Tag,'Start calibration - useHPC')
                        display(['BUILDING OFFLOAD DATA FOR MODEL: ',calibLabel]);
                        disp('  ');
                        
                        nHPCmodels = nHPCmodels +1;
                        HPCmodelData{nHPCmodels,1} = tmpModel; %#ok<AGROW> 
                        HPCmodelData{nHPCmodels,2} = calibStartDate; %#ok<AGROW> 
                        HPCmodelData{nHPCmodels,3} = calibEndDate; %#ok<AGROW> 
                        HPCmodelData{nHPCmodels,4} = calibMethod; %#ok<AGROW> 
                        HPCmodelData{nHPCmodels,5} = calibMethodSetting;                        %#ok<AGROW> 
                        this.tab_ModelCalibration.Table.Data{i,9} = '<html><font color = "#FFA500">Calib. on HPC... </font></html>';
                    else
                        % Change to project folder so that calib files can
                        % be written there.
                        cd(fileparts(this.project_fileName));

                        display(['CALIBRATING MODEL: ',calibLabel]);
                        calibrateModel( tmpModel, this, calibStartDate, calibEndDate, calibMethod,  calibMethodSetting);

                        % Get the data for the plots of the calibration
                        % iterations and store within for model object.
                        % This is done so that the plot can be re-created
                        % within the model status tab.
                        tmpModel.calibrationResults.parameters.iterations = modelCalibration_CalibPlotsGetData(this);

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
                        calibAICc = min(tmpModel.calibrationResults.performance.AICc);
                        calibBIC =min( tmpModel.calibrationResults.performance.BIC);
                        calibCoE = max(tmpModel.calibrationResults.performance.CoeffOfEfficiency_mean.CoE);
                        this.tab_ModelCalibration.Table.Data{i,10} = ['<html><font color = "#808080">',num2str(calibCoE),'</font></html>'];
                        this.tab_ModelCalibration.Table.Data{i,12} = ['<html><font color = "#808080">',num2str(calibAICc),'</font></html>'];
                        this.tab_ModelCalibration.Table.Data{i,13} = ['<html><font color = "#808080">',num2str(calibBIC),'</font></html>'];

                        % Set eval performance stats
                        if isfield(tmpModel.evaluationResults,'performance')
                            %evalAIC = this.models.data{ind, 1}.evaluationResults.performance.AIC;
                            evalCoE = max(tmpModel.evaluationResults.performance.CoeffOfEfficiency_mean.CoE_unbias);

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
                        if exitFlag ==-2
                            this.tab_ModelCalibration.Table.Data{i,9} = '<html><font color = "#FF0000">User skipped calibration.</font></html>';
                        elseif exitFlag ==-1
                            this.tab_ModelCalibration.Table.Data{i,9} = '<html><font color = "#FF0000">User quit calibration.</font></html>';
                        elseif exitFlag ==0
                            this.tab_ModelCalibration.Table.Data{i,9} = ['<html><font color = "#FF0000">Fail-', exitStatus,'</font></html>'];
                        elseif exitFlag ==1
                            this.tab_ModelCalibration.Table.Data{i,9} = '<html><font color = "#FFA500">Partially calibrated</font></html>';
                        elseif exitFlag ==2
                            this.tab_ModelCalibration.Table.Data{i,9} = '<html><font color = "#008000">Calibrated</font></html>';
                        end                      
                        
                    end
                catch ME
                    nModelsCalibFailed = nModelsCalibFailed +1;
                    this.tab_ModelCalibration.Table.Data{i,9} = ['<html><font color = "#FF0000">Fail-', ME.message,'</font></html>'];
                end
                
                % Update wait bar
                waitBarPlot.YData = waitBarPlot.YData+1;
                
                % Update status in GUI
                drawnow

                % Check if the entire calibration should be quit.
                if this.tab_ModelCalibration.quitCalibration
                    break;
                end

                % Reset skip flag in case the user skipped the current
                % model.
                this.tab_ModelCalibration.skipCalibration = false;

            end            
            
            % Change label of button to quit
            obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','Start calibration');
            obj.Enable = 'on';
            obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','Quit calibration');
            obj.Enable = 'off';            
            obj = findobj(this.tab_ModelCalibration.GUI, 'Tag','Skip calibration');
            obj.Enable = 'off';             
            
            % Return to initial folder
            cd(initial_pwd);
            
            % Change cursor to arrow
            set(this.Figure, 'pointer', 'arrow');
            drawnow update
            if strcmp(hObject.Tag,'Start calibration - useHPC')
               project_fileName = this.project_fileName; %#ok<PROPLC> 
               if ~isfolder(this.project_fileName)
                   project_fileName = fileparts(project_fileName); %#ok<PROPLC> 
               end
               
               userData = jobSubmission(this.HPCoffload, project_fileName, HPCmodelData, this.tab_ModelCalibration.QuitObj) ; %#ok<PROPLC> 
               if ~isempty(userData)
                   this.HPCoffload = userData;
               end

                % Update status in GUI
                drawnow update
                    
            else
                % Report Summary
                h = msgbox(['The model was successfully calibrated for ',num2str(nModelsCalib), ' models and failed for ',num2str(nModelsCalibFailed), ' models.'], 'Calibration summary');
                set(h,'Tag','Model calibration msgbox summary');
                setIcon(this, h);
            end        
        end
        
        function paramData = modelCalibration_CalibPlotsGetData(this)

            % Get panel object containing the plot axes
            plotsPanel = findobj(this.tab_ModelCalibration.GUI, 'Tag','Model calibration - progress plots panel');

            % Initialise output
            nAxes = length(plotsPanel.Children);
            paramData = cell(nAxes,1);

            % Look though each axis and extract plot data and store in a cell vector.            
            for i=1:nAxes                
                yyaxis(plotsPanel.Children(i),'left');
                nChildren = length(plotsPanel.Children(i).Children);
                paramData{i}.left.ylabel= get(plotsPanel.Children(i),'YLabel').String;
                paramData{i}.left.XData = [];
                paramData{i}.left.YData = [];
                for j=1:nChildren
                    if isa(plotsPanel.Children(i).Children(j),'matlab.graphics.chart.primitive.Line')
                        paramData{i}.left.XData = [paramData{i}.left.XData; get(plotsPanel.Children(i).Children(j),'XData')];
                        paramData{i}.left.YData = [paramData{i}.left.YData; get(plotsPanel.Children(i).Children(j),'YData')];
                    end
                end

                yyaxis(plotsPanel.Children(i),'right');      
                nChildren = length(plotsPanel.Children(i).Children);
                paramData{i}.right.ylabel= get(plotsPanel.Children(i),'YLabel').String;
                paramData{i}.right.XData = [];
                paramData{i}.right.YData = [];                
                for j=1:nChildren
                    if isa(plotsPanel.Children(i).Children(j),'matlab.graphics.chart.primitive.Line')
                        paramData{i}.right.XData = [paramData{i}.right.XData; get(plotsPanel.Children(i).Children(j),'XData')];
                        paramData{i}.right.YData = [paramData{i}.right.YData; get(plotsPanel.Children(i).Children(j),'YData')];
                    end
                end
                
            end
        end

        function multimodel_moveLeft(this,~,~)
            % Find the RH list object
            leftlistBox = findobj(this.tab_ModelCalibration.GUI, 'Tag','NLMEFIT paramsLeftList');
            rightlistBox = findobj(this.tab_ModelCalibration.GUI, 'Tag','NLMEFIT paramsRightList');
            
            % Add selected params to LH box
            leftlistBox.String = [leftlistBox.String, rightlistBox.String(rightlistBox.Value)];
            leftlistBox.String = sort(leftlistBox.String);
            
            % Remove from RH box.
            ind  = true(size(rightlistBox.String));
            ind(rightlistBox.Value)=false;
            rightlistBox.String = rightlistBox.String(ind);
            rightlistBox.String = sort(rightlistBox.String);
        
        end
        
        function multimodel_moveRight(this,~,~)                    
            % Find the RH list object
            leftlistBox = findobj(this.tab_ModelCalibration.GUI, 'Tag','NLMEFIT paramsLeftList');
            rightlistBox = findobj(this.tab_ModelCalibration.GUI, 'Tag','NLMEFIT paramsRightList');
            
            % Add selected params to RH box
            rightlistBox.String = [rightlistBox.String, leftlistBox.String(leftlistBox.Value)];
            rightlistBox.String = sort(rightlistBox.String);
            
            % Remove from LH box.
            ind  = true(size(leftlistBox.String));
            ind(leftlistBox.Value)=false;
            leftlistBox.String = leftlistBox.String(ind);
            leftlistBox.String = sort(leftlistBox.String);
        end        
        
        % Find the currently selected model object and simulation lablel
        function [tmpModel, simLabel, simInd]= modelSimulation_getCurrentModel(this)
            
            % Initialise outputs
            tmpModel = [];
            simLabel = '';
            simInd = [];

            % Get GUI table indexes
            % Record the current row and column numbers
            irow = this.tab_ModelSimulation.currentRow;
            icol = this.tab_ModelSimulation.currentCol;
            
            % Get table data            
            data=get(this.tab_ModelSimulation.Table,'Data'); % get the data cell array of the table
            
            % Exit of no cells are selected
            if isempty(irow) || isempty(icol)
                set(this.Figure, 'pointer', 'arrow');
                drawnow update;                 
                return
            end
            
            % Find index to the calibrated model label within the list of calibrated
            % models.
            modelLabel = data{irow,2};
            if isempty(modelLabel) || strcmp(modelLabel,'(none calibrated)')
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
                simInd = [];
                set(this.Figure, 'pointer', 'arrow');
                drawnow update; 
                return;
            end          
            simInd = find(simInd);            
        end

        function status = checkEdit2Model(this, modelLabel, simulationLabel, doBuildCheck, doCalibrationCheck, doSimulationCheck)
        % status = -1: Model not built (or not calibrated or simulated)
        % status = 0: Cancel edits and do not change model
        % status = 1: Relevant model deletions have been made.
            status = -1;

            % Return if no model label yet set.
            if isempty(modelLabel) || strcmp(modelLabel,'(none calibrated)')
                return
            end

            % Remove HTML formatting
            modelLabel = HydroSight_GUI.removeHTMLTags(modelLabel);

            % Convert model label to field label.
            model_labelAsField = HydroSight_GUI.modelLabel2FieldName(modelLabel);

            % Check if the model object exists
            if ~isempty(this.models) && any(strcmp(fieldnames(this.models), model_labelAsField))

                % Get model object. Return no error if the model does not
                % exist.
                model = getModel(this, model_labelAsField);

                % Check if model built
                if isempty(model)
                    status = -1;
                    return;
                end
                isBuilt = true;
               
                % Check if the model is calibrated
                isCalibrated = false;
                if isprop(model,'calibrationResults') && isfield(model.calibrationResults,'isCalibrated')
                    isCalibrated = model.calibrationResults.isCalibrated;
                end

                % Check if simulated.
                isSimulated = false;
                if ~isempty(model.simulationResults)
                    if ~doBuildCheck && ~doCalibrationCheck && doSimulationCheck
                        % Only the model simulation is to be checked, so check
                        % if the simulation has actually been undertaken.
                        simulationLabel_ind = cellfun(@(x) strcmp(x.simulationLabel,simulationLabel), model.simulationResults);
                        if ~any(simulationLabel_ind)
                            status = -1;
                            return;
                        end
                        isSimulated = true;
                    elseif ~isempty(model.simulationResults)
                        isSimulated = true;
                    end
                end

                % Create warning message and display
                msg = '';
                if doBuildCheck
                    msgTitle = 'Overwrite existing model build?';
                    if isBuilt && isCalibrated && isSimulated
                        msg = ['Model "',modelLabel, '" has already been built, calibrated and used for simulation.', char newline, char newline, ...
                            'If you now change the model, the model and its calibration and simulations will be deleted.', char newline, char newline, ...
                            'Do you want to continue with the changes to the model?'];
                    elseif isBuilt && isCalibrated
                        msg = ['Model "',modelLabel, '" has already been built and calibrated.', char newline, ...
                            'If you now change the model, the model and its calibration will be deleted.', char newline, char newline, ...
                            'Do you want to continue with the changes to the model?'];
                    elseif isBuilt
                        msg = ['Model "',modelLabel, '" has already been built.', char newline, char newline,...
                            'If you now change the model, the model will be deleted.', char newline, char newline, ...
                            'Do you want to continue with the changes to the model?'];
                    end
                elseif doCalibrationCheck
                    msgTitle = 'Overwrite existing model calibration?';
                    if isBuilt && isCalibrated && isSimulated
                        msg = ['Model "',modelLabel, '" has already been calibrated and used for simulation.', char newline, char newline,...
                            'If you now change the calibration settings, the calibration and simulations will be deleted.', char newline, char newline, ...
                            'Do you want to continue with the changes to the calibration settings?'];
                    elseif isBuilt && isCalibrated
                        msg = ['Model "',modelLabel, '" has already been calibrated.', char newline, ...
                            'If you now change the calibration settings, the calibration will be deleted.', char newline, char newline, ...
                            'Do you want to continue with the changes to the calibration settings?'];
                    end
                elseif doSimulationCheck
                    msgTitle = 'Overwrite existing model simulation?';
                    if isSimulated
                        msg = ['Simulation "',simulationLabel, '" for model "',modelLabel, '" has been undertaken.', char newline, char newline,...
                            'If you now change the simulation settings, this simulations will be deleted.', char newline, char newline, ...
                            'Do you want to continue with the changes to the simulation settings?'];                    
                    end
                end
                if ~isempty(msg)
                    response = questdlg_timer(this.figure_icon,15,msg,msgTitle,'Yes','No','No');
                else
                    status = -1;
                    return                    
                end

                % Check if 'cancel, else delete the model object
                if isempty(response) || strcmp(response,'No')
                    status = 0;
                    return
                end

                % Delete models from simulations table.
                if (doBuildCheck || doCalibrationCheck) && isCalibrated && isSimulated
                    % If the model is to be deleted, then delete all
                    % simulations for this model.
                    ind = cellfun(@(allModelLabels) strcmp(allModelLabels,model_labelAsField), ...
                                          this.tab_ModelSimulation.Table.Data(:,2));
                    if any(ind )
                        % Update table
                        this.tab_ModelSimulation.Table.Data = this.tab_ModelSimulation.Table.Data(~ind,:);
                        status = 1;

                        % Update row numbers
                        nrows = size(this.tab_ModelSimulation.Table.Data,1);
                        this.tab_ModelSimulation.Table.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));
                    end
                elseif ~doBuildCheck && ~doCalibrationCheck && doSimulationCheck && isSimulated
                    % The model object or calibration results are not to be
                    % deleted. Only a simulation is to be deleted.
                    simulationLabel_ind = cellfun(@(x) strcmp(x.simulationLabel,simulationLabel), model.simulationResults);
                    if any(simulationLabel_ind)
                        % Delete simulation result from model.
                        model.simulationResults = model.simulationResults(~simulationLabel_ind,1);
                        setModel(this, modelLabel, model);

                        % Update table
                        simulationLabel_ind = cellfun(@(allModelLabels, allSimulationLabels) strcmp(allModelLabels,modelLabel) && ...
                            strcmp(allSimulationLabels,simulationLabel), ...
                            this.tab_ModelSimulation.Table.Data(:,2),this.tab_ModelSimulation.Table.Data(:,6));
                        this.tab_ModelSimulation.Table.Data(simulationLabel_ind, 12) = {'<html><font color = "#FF0000">Not simulated.</font></html>'};

                    end
                end

                % Delete model from calibration table.
                if isCalibrated && doCalibrationCheck
                    % Remove the calibration settings from the GUI.
                    status = 1;
                    modelLabels_calibTable =  this.tab_ModelCalibration.Table.Data(:,2);
                    modelLabels_calibTable = HydroSight_GUI.removeHTMLTags(modelLabels_calibTable);
                    ind = cellfun( @(x) strcmp(x,modelLabel), modelLabels_calibTable);

                    if any(ind)
                        % Remove calibration results from the model if the
                        % model object has not been deleted.
                        if ~doBuildCheck
                            model.calibrationResults = [];
                            model.calibrationResults.isCalibrated = false;
                            setModel(this, modelLabel, model);

                            ind = find(ind);
                            this.tab_ModelCalibration.Table.Data{ind,9} = '<html><font color = "#FF0000">Not calibrated.</font></html>';
                            this.tab_ModelCalibration.Table.Data{ind,10} = '(NA)';
                            this.tab_ModelCalibration.Table.Data{ind,11} = '(NA)';
                            this.tab_ModelCalibration.Table.Data{ind,12} = '(NA)';
                            this.tab_ModelCalibration.Table.Data{ind,13} = '(NA)';
                        else
                            % Delete table entry
                            this.tab_ModelCalibration.Table.Data = this.tab_ModelCalibration.Table.Data(~ind,:);

                            % Update row numbers
                            nrows = size(this.tab_ModelCalibration.Table.Data,1);
                            this.tab_ModelCalibration.Table.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));                            
                        end
                    end
                end                

                % Delete the model object and update the model build status.
                if doBuildCheck
                    status = 1;
                    deleteModel(this, modelLabel);

                    modelLabels_constTable =  this.tab_ModelConstruction.Table.Data(:,2);
                    modelLabels_constTable  = HydroSight_GUI.removeHTMLTags(modelLabels_constTable );

                    ind = cellfun( @(x) strcmp(x,modelLabel), modelLabels_constTable);
                    this.tab_ModelConstruction.Table.Data{ind,end} = '<html><font color = "#FF0000">Not built.</font></html>';
                end
                drawnow update
            end
        end

        function setIcon(this, h)
            if isa(h, 'matlab.ui.Figure') && isa(this.figure_icon,'javax.swing.ImageIcon')
                try
                    warning ('off','MATLAB:ui:javaframe:PropertyToBeRemoved');
                    javaFrame    = get(h,'JavaFrame'); %#ok<JAVFM> 
                    javaFrame.setFigureIcon(this.figure_icon);
                catch
                    % do nothing
                end
            end
        end

        function initialiseGUI(this)
            % Intialise main GUI              
            this.project_fileName ='';
            this.model_labels=[];
            this.models=[];              
            this.tab_Project.project_name.String = '';
            this.tab_Project.project_description.String = '';
            this.tab_DataPrep.Table.Data = {false, '', '',0, 0, 0, '01/01/1900',true, true, true, true, 10, 120, 4, 1,...
                '<html><font color = "#FF0000">Not analysed.</font></html>', ...
                ['<html><font color = "#808080">','(NA)','</font></html>'], ...
                ['<html><font color = "#808080">','(NA)','</font></html>']};
            this.tab_DataPrep.Table.RowName = {}; 
            this.tab_ModelConstruction.Table.Data = { [],[],[],[],[],[],[],[], [],'<html><font color = "#FF0000">Not built.</font></html>'};
            this.tab_ModelConstruction.Table.RowName = {}; 
            this.tab_ModelCalibration.Table.Data = {};
            this.tab_ModelCalibration.Table.RowName = {};
            this.tab_ModelSimulation.Table.Data = {};
            this.tab_ModelSimulation.Table.RowName = {};
            this.dataPrep = [];
            this.copiedData={};
            this.HPCoffload={};
            this.modelsOnHDD='';

            %Initialise forcing data stored variables
            this.tab_ModelCalibration.resultsOptions.forcingData.modelLabel = '';
            this.tab_ModelCalibration.resultsOptions.forcingData.data_input = [];
            this.tab_ModelCalibration.resultsOptions.forcingData.data_derived = [];
            this.tab_ModelCalibration.resultsOptions.forcingData.colnames_input = {};
            this.tab_ModelCalibration.resultsOptions.forcingData.colnames_derived = {};
            this.tab_ModelCalibration.resultsOptions.forcingData.filt=[];

            % Hide all right hand side options windows.
            %this.tab_DataPrep.modelOptions.resultsOptions.box.Heights = zeros(size(this.tab_DataPrep.modelOptions.resultsOptions.box.Heights));
            this.tab_ModelConstruction.modelOptions.vbox.Heights = zeros(size(this.tab_ModelConstruction.modelOptions.vbox.Heights));
            %this.tab_ModelSimulation.resultsOptions.box.Heights = zeros(size(this.tab_ModelSimulation.resultsOptions.box.Heights));
            this.tab_ModelCalibration.resultsTabs.TabEnables = repmat({'off'},length(this.tab_ModelCalibration.resultsTabs.TabEnables),1);
            this.tab_ModelSimulation.resultsTabs.TabEnables = repmat({'off'},length(this.tab_ModelSimulation.resultsTabs.TabEnables),1);

            % Set project name/title
            vernum = getHydroSightVersion();
            set(this.Figure,'Name',['HydroSight ', vernum]);            
                
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
                       
            % Initialise model options GUI
            for i=1:length(this.modelTypes)
                initialise(this.tab_ModelConstruction.modelTypes.(this.modelTypes{i}).obj);
            end
        end
    end
    
    methods(Static=true)
       
        % Remove HTML tags from each model label
        function str = removeHTMLTags(str)
            if iscell(str)
               for i=1:length(str)
                    if contains(upper(str{i}),'HTML')
                        str{i} = regexp(str{i},'>.*?<','match');
                        str{i} = strrep(str{i}, '<', '');
                        str{i} = strrep(str{i}, '>', '');
                        str{i} = strtrim(strjoin(str{i}));
                    end
               end
            else
                if contains(upper(str),'HTML')
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
            newLabel = inputLabel;
            if ischar(newLabel)
                newLabel = {newLabel};
            end
            showWarningA = true;
            showWarningB = true;
            for i=1:length(newLabel)
                if showWarningA && any(strcmp(newLabel{i}, {'tableData'; 'dataPrep';'settings'}))
                    h = warndlg('Model label cannot be one of the following reserved labels "tableData", "dataPrep", "settings".','Model label error ...');
                    setIcon(this, h);
                    newLabel{i}='';
                    showWarningA = false;
                end

                % Check if a field name can be created with the model label
                try
                    tmp.(newLabel{i}) = [1 2 3]; %#ok<STRNU>
                    clear tmp;
                catch
                    if showWarningB
                        h = warndlg('Model label must start with letters and have only letters and numbers.','Model label error ...');
                        setIcon(this, h);
                        showWarningB = false;
                    end
                    newLabel{i}='';
                end
            end
            if ischar(inputLabel)
                newLabel = newLabel{1};
            end
        end
    end
end

