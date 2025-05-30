classdef model_TFN_gui < model_gui_abstract
    %MODEL_TFN_GUI Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % NOTE: Inputs from the parent table are define in abstract
        %  
        % Model specific GUI properties.        
        dropdownOptions
        forcingTranforms
        weightingFunctions
        derivedForcingTranforms
        derivedWeightingFunctions
        modelComponants
        modelOptions 
        
        % Current active main table, row, col
        currentSelection;

        % Copied table rows
        copiedData;
    end
    
    methods
        %% Build the GUI for this model type.
        function this = model_TFN_gui(parent_handle)
            
            % Initialise properties not initialised below
            this.boreID = [];
            this.siteData = [];
            this.forcingData = [];  
            this.currentSelection.table = '';            
            this.currentSelection.row = 0;
            this.currentSelection.col = 0;
            
            % Get the available modle options
            %--------------------------------------------------------------
            % Get the types of weighting function and derived weighting function
            quickload = true;
            if ~isdeployed && ~quickload
                warning('off');
                forcingFunctions = findClassDefsUsingAbstractName( 'forcingTransform_abstract', 'model_TFN');
                derivedForcingFunctions = findClassDefsUsingAbstractName( 'derivedForcingTransform_abstract', 'model_TFN');

                % Get the types of weighting function and derived weighting function
                weightFunctions = findClassDefsUsingAbstractName( 'responseFunction_abstract', 'model_TFN');
                derivedWeightFunctions = findClassDefsUsingAbstractName( 'derivedResponseFunction_abstract', 'model_TFN');
                warning('on');
            else
                % Hard code in function names if the code is deployed. This
                % is required because depfun does not dunction in deployed
                % code.                
                forcingFunctions = {        'climateTransform_soilMoistureModels', ...                                            
                                            'climateTransform_soilMoistureModels_v2', ...
                                            'climateTransform_soilMoistureModels_2layer', ...
                                            'climateTransform_soilMoistureModels_2layer_v2', ...
                                            'pumpingRate_SAestimation'};                
                derivedForcingFunctions = { 'derivedForcing_linearUnconstrainedScaling', ...
                                            'derivedForcing_linearUnconstrainedScaling_dup', ...
                                            'derivedForcing_logisticScaling'};                
                derivedWeightFunctions = {  'derivedweighting_UnconstrainedRescaled', ...
                                            'derivedweighting_PearsonsNegativeRescaled', ...
                                            'derivedweighting_PearsonsPositiveRescaled', ...
                                            'derivedweighting_PearsonsPumping', ...
                                            %'derivedweighting_ExpPumping', ...
                                            };
                weightFunctions = {         'responseFunction_Bruggeman', ...
                                            'responseFunction_exponential', ...
                                            'responseFunction_exponentialNegative', ...
                                            'responseFunction_FerrisKnowles', ...
                                            'responseFunction_FerrisKnowlesJacobs', ...                                            
                                            'responseFunction_Hantush', ...
                                            'responseFunction_Pearsons', ...
                                            'responseFunction_PearsonsNegative', ...
                                            'responseFunction_PearsonsHeadConstrained', ...
                                            'responseFunction_BarometricConfined', ...
                                            };
            end
                

            % Forcing function column headings etc
            cnames_forcing = {'Select','Forcing Transform Function','Input Data', 'Options'};
            cformats_forcing = {'logical',forcingFunctions,'char','char'};
            cedit_forcing = logical([1 1 1 1]);
            rnames_forcing = {'1'};
            cdata_forcing = cell(1,4);
            toolTip_forcing = ['<html>This table (optional) allows the transformation of the input forcing data (e.g. rainfall to recharge). <br>', ...
                          'To build a transformation function, you''ll need to select a function and define the input forcing data <br>', ...                 
                          'that is to be transformed. </html>'];                          
            
            % Derived forcing function column headings etc
            cnames_forcingDerived = {'Select','Forcing Transform Function','Source Forcing Function','Input Data', 'Options'};
            cformats_forcingDerived = {'logical',derivedForcingFunctions,{'(No functions available)'},'char','char'};    
            cedit_forcingDerived = logical([1 1 1 1 1]);
            rnames_forcingDerived = {'1'};
            cdata_forcingDerived = cell(1,5);
            toolTip_forcingDerived = ['<html>This table (optional) allows the transformation of derived forcing data (e.g. recharge) <br>', ...
                          'and can be used to estimate the impacts from, say, land use change on the head.  To build such a transformation <br>', ...
                          'function, you''ll need to first build a transformation function (step 1)</html>'];                          
            
            % Weighting function column headings etc
            cnames_weighting = {'Select','Component Name','Weighting Function','Input Data', 'Options'};
            cformats_weighting = {'logical','char', weightFunctions,'char','char'};
            cedit_weighting = logical([1 1 1 1 1]);
            rnames_weighting = {'1'};
            cdata_weighting = cell(1,5);
            toolTip_weighting = ['<html>This table (required) allows the weighting of forcing data (e.g. rainfall, recharge or pumping). <br>', ...
                          'into a groundwater head change. To build a weighting function, you''ll need to define the name of the model <br>', ...
                          'componant, select a function type and then define the data to be weighted.</html>'];                          

            
            % Derived Weighting function column headings etc
            cnames_weightingDerived = {'Select','Component Name','Weighting Function','Source Component','Input Data', 'Options'};
            cformats_weightingDerived = {'logical','char', derivedWeightFunctions,'char','char','char'};    
            cedit_weightingDerived = logical([1 1 1 1 1 1]);
            rnames_weightingDerived = {'1'};
            cdata_weightingDerived = cell(1,6);
            toolTip_weightingDerived = ['<html>This table (optional) allows weighting of forcing data (e.g. rainfall, recharge <br>', ...
                                               'or pumping) using a previously defined weighting function. </html>'];                          
            
            % Create the GUI elements
            %--------------------------------------------------------------
            % Create grid the model settings            
            this.Figure = uiextras.VBoxFlex('Parent',parent_handle,'Padding', 0, 'Spacing', 0);
            
            % Get handle to main GUI
            objHydroSight = ancestor(this.Figure,'figure','toplevel');
            
            % Get icon
            try
                iconData = load("appIcon.mat");
                this.Figure_icon = iconData.iconData;
            catch
                this.figure_icon = [];
            end

            % Change icon
            setIcon(this, this.Figure);

            % Add box for drop down and for the details of model settings sub-boxes
            this.modelComponants = uiextras.VBoxFlex('Parent', this.Figure,'Padding', 0, 'Spacing', 0);                                    

            % Add drop down to model components
            this.dropdownOptions.hbox = uiextras.HBox('Parent', this.modelComponants,'Padding', 3, 'Spacing', 3);
            this.dropdownOptions.lbl = uicontrol( 'Parent', this.dropdownOptions.hbox,'Style','text', ...
                'String','Select a model component:','HorizontalAlignment','left','Visible','on');
            this.dropdownOptions.dropdown = uicontrol( 'Parent', this.dropdownOptions.hbox,'Style','popupmenu','String', ...
                {'Weighting functions (required)','Forcing transforms (optional)','Derived forcing transforms (optional)','Derived weighting functions (optional)'}, ...
                'Visible','on', 'Callback',@this.componentSelection);

            % Add card panel for each drop down option.
            this.dropdownOptions.cards = uiextras.CardPanel( 'Parent', this.modelComponants, 'Padding', 5 );

            % Build the weighting function settings items
            this.weightingFunctions.tbl = uitable(this.dropdownOptions.cards,'ColumnName',cnames_weighting,...
                'ColumnEditable',cedit_weighting,'ColumnFormat',cformats_weighting,'RowName',...                
                rnames_weighting ,'Data',cdata_weighting, 'Visible','on', 'Units','normalized', ...
                'CellSelectionCallback', @this.tableSelection, ...
                'CellEditCallback', @this.tableEdit, ...
                'Tag','Weighting Functions', ...
                'TooltipString', toolTip_weighting);
                        
            % Build the forcing transformation settings items
            this.forcingTranforms.tbl = uitable(this.dropdownOptions.cards,'ColumnName',cnames_forcing,...
                'ColumnEditable',cedit_forcing,'ColumnFormat',cformats_forcing,'RowName',...
                rnames_forcing ,'Data',cdata_forcing, 'Visible','on', 'Units','normalized', ...
                'CellSelectionCallback', @this.tableSelection, ...
                'CellEditCallback', @this.tableEdit, ...
                'Tag','Forcing Transform', ...
                'TooltipString',toolTip_forcing);
                                    
            % Build the derived  forcing transformation settings items
            this.derivedForcingTranforms.tbl = uitable(this.dropdownOptions.cards,'ColumnName',cnames_forcingDerived, ...
                'ColumnEditable',cedit_forcingDerived,'ColumnFormat',cformats_forcingDerived,'RowName',...
                rnames_forcingDerived ,'Data',cdata_forcingDerived, 'Visible','on', 'Units','normalized', ...
                'CellSelectionCallback', @this.tableSelection, ...
                'CellEditCallback', @this.tableEdit, ...
                'Tag','Derived Forcing Transform', ...
                'TooltipString', toolTip_forcingDerived);
                                    
            % Build the derived weighting functions
            this.derivedWeightingFunctions.tbl = uitable(this.dropdownOptions.cards,'ColumnName',cnames_weightingDerived,...
                'ColumnEditable',cedit_weightingDerived,'ColumnFormat',cformats_weightingDerived,'RowName',...
                rnames_weightingDerived ,'Data',cdata_weightingDerived, 'Visible','on', 'Units','normalized', ...
                'CellSelectionCallback', @this.tableSelection, ...
                'CellEditCallback', @this.tableEdit, ...
                'Tag','Derived Weighting Functions', ...
                'TooltipString', toolTip_weightingDerived);
            
            % Build the forcing transformation and weighting function options
            %----------------------------------------
            % Add card panel for input options for each compoinent.
            this.modelOptions.cards = uiextras.CardPanel( 'Parent', this.Figure, 'Padding', 5 );
            
            % Add list box for selecting the input forcing data
            %-------------------
            cnames = {'Required Model Data', 'Input Forcing Data'};
            cedit = logical([0 1]);
            rnames = {'1'};
            cdata = cell(1,2);
            cformats = {'char', 'char'};
                      
            % Add forcing transform card
            this.modelOptions.options{1,1}.ParentName = 'forcingTranforms';
            this.modelOptions.options{1,1}.ParentSettingName = 'inputForcing';
            this.modelOptions.options{1,1}.tbl =  uitable(this.modelOptions.cards ,'ColumnName',cnames,...
                                                'ColumnEditable',cedit,'ColumnFormat',cformats,'RowName',...
                                                rnames,'Data',cdata, 'Visible','on', 'Units','normalized', ...
                                                'CellEditCallback', @this.optionsSelection, ...                                                
                                                'Tag','Forcing Transform - Input Data');
            
            % Add context menu for Wizard.
            contextMenu = uicontextmenu(objHydroSight,'Visible','on');
            uimenu(contextMenu,'Label','Copy all rows','Callback',@this.rowAddDelete);
            uimenu(contextMenu,'Label','Paste all rows','Callback',@this.rowAddDelete);
            uimenu(contextMenu,'Label','Wizard ...','Callback',@this.wizard,'Separator','on'); 
            uimenu(contextMenu,'Label','Push "Required Data" to component','Callback',@this.push2component);
                           
            set(this.modelOptions.options{1,1}.tbl,'UIContextMenu',contextMenu);
            set(this.modelOptions.options{1,1}.tbl.UIContextMenu,'UserData', 'this.modelOptions.options{1,1}.tbl');
            
            % Add vard for table for defining the transformation options eg soil
            % moisture model parameters for calibration.
            %-------------------
            this.modelOptions.options{2,1}.ParentName = 'forcingTranforms';
            this.modelOptions.options{2,1}.ParentSettingName = 'options';            
            this.modelOptions.options{2,1}.tbl = uitable(this.modelOptions.cards ,'ColumnName',{'Parameter','(none set)'}, ...
                'ColumnEditable',true,'Data',[], ...
                'CellEditCallback', @this.optionsSelection, ...    
                'Tag','Forcing Transform - Model Settings', 'Visible','on');
               
            % Add context menu for Wizard.
            contextMenu = uicontextmenu(objHydroSight,'Visible','on');
            uimenu(contextMenu,'Label','Copy all rows','Callback',@this.rowAddDelete);
            uimenu(contextMenu,'Label','Paste all rows','Callback',@this.rowAddDelete,'Separator','on');
            uimenu(contextMenu,'Label','Wizard ...','Callback',@this.wizard);                
            set(this.modelOptions.options{2,1}.tbl,'UIContextMenu',contextMenu);
            set(this.modelOptions.options{2,1}.tbl.UIContextMenu,'UserData', 'this.modelOptions.options{2,1}.tbl');            
            
            % Add list box for selecting the weighting functions input
            % data.
            % NOTE: Multiple selection of input forcing data is allowed.
            % This is defined in tableSelection().
            %-------------------
            this.modelOptions.options{3,1}.ParentName = 'weightingFunctions';
            this.modelOptions.options{3,1}.ParentSettingName = 'inputForcing';                     
            this.modelOptions.options{3,1}.lst = uicontrol('Parent',this.modelOptions.cards,'Style','list', 'BackgroundColor','w', ...
                'String',{},'Value',1,'Tag','Weighting Functions - Input Data','Callback', @this.optionsSelection, 'Visible','on');

            contextMenu = uicontextmenu(objHydroSight,'Visible','on');
            uimenu(contextMenu,'Label','Wizard ...','Callback',@this.wizard); 
                           
            set(this.modelOptions.options{3,1}.lst,'UIContextMenu',contextMenu);
            set(this.modelOptions.options{3,1}.lst.UIContextMenu,'UserData', 'this.modelOptions.options{3,1}.lst');

            % Add table for selecting the weighting functions options
            %-------------------
            this.modelOptions.options{4,1}.ParentName = 'weightingFunctions';
            this.modelOptions.options{4,1}.ParentSettingName = 'options';                     
            this.modelOptions.options{4,1}.tabs = uiextras.TabPanel( 'Parent', this.modelOptions.cards, 'Padding', 5, 'TabSize',127,'FontSize',8, 'Tag','Weighting Functions - Options');
            
            tab1 = uiextras.Panel( 'Parent', this.modelOptions.options{4,1}.tabs , 'Padding', 5, 'Tag','Weighting Functions - Options Tab 1');            
            tab2 = uiextras.Panel( 'Parent', this.modelOptions.options{4,1}.tabs , 'Padding', 5, 'Tag','Weighting Functions - Options Tab 2');
            tab3 = uiextras.Panel( 'Parent', this.modelOptions.options{4,1}.tabs , 'Padding', 5, 'Tag','Weighting Functions - Options Tab 3');            
            tab4 = uiextras.Panel( 'Parent', this.modelOptions.options{4,1}.tabs , 'Padding', 5, 'Tag','Weighting Functions - Options Tab 4');            
            tab5 = uiextras.Panel( 'Parent', this.modelOptions.options{4,1}.tabs , 'Padding', 5, 'Tag','Weighting Functions - Options Tab 5');            
            
            uitable( tab1,'ColumnName',{'(none)'}, 'ColumnEditable',true,'Data',[], 'Tag','Weighting Functions - Options Tab 1 table', 'CellEditCallback', @this.optionsSelection, 'Visible','on');
            uitable( tab2,'ColumnName',{'(none)'}, 'ColumnEditable',true,'Data',[], 'Tag','Weighting Functions - Options Tab 2 table', 'CellEditCallback', @this.optionsSelection, 'Visible','on');
            uitable( tab3,'ColumnName',{'(none)'}, 'ColumnEditable',true,'Data',[], 'Tag','Weighting Functions - Options Tab 3 table', 'CellEditCallback', @this.optionsSelection, 'Visible','on');
            uitable( tab4,'ColumnName',{'(none)'}, 'ColumnEditable',true,'Data',[], 'Tag','Weighting Functions - Options Tab 4 table', 'CellEditCallback', @this.optionsSelection, 'Visible','on');
            uitable( tab5,'ColumnName',{'(none)'}, 'ColumnEditable',true,'Data',[], 'Tag','Weighting Functions - Options Tab 5 table', 'CellEditCallback', @this.optionsSelection, 'Visible','on');
            this.modelOptions.options{4,1}.tabs.TabNames = {'Option 1', 'Option 2','Option 3', 'Option 4','Option 5'};
            this.modelOptions.options{4,1}.tabs.SelectedChild = 1;            
            
            % Add table for defining the transformation options eg soil
            % moisture model parameters for calibration.            
            %-------------------
            this.modelOptions.options{5,1}.ParentName = 'DerivedForcingTransformation';
            this.modelOptions.options{5,1}.ParentSettingName = 'inputForcing';                     
            this.modelOptions.options{5,1}.lst = uicontrol('Parent',this.modelOptions.cards,'Style','list', 'BackgroundColor','w', ...
                'String',{},'Value',1, ...
                'Tag','Derived Forcing Functions - Source Function', ...
                'Callback', @this.optionsSelection, 'Visible','on');

            % Add table for derived forcing inut data options
            %-------------------
            this.modelOptions.options{6,1}.ParentName = 'DerivedForcingTransformation';           
            this.modelOptions.options{6,1}.ParentSettingName = 'inputForcing';
            this.modelOptions.options{6,1}.tbl =  uitable(this.modelOptions.cards,'ColumnName',cnames,...
                'ColumnEditable',cedit,'ColumnFormat',cformats,'RowName',...
                rnames,'Data',cdata, 'Visible','on', 'Units','normalized', ...
                'CellEditCallback', @this.optionsSelection, ...                                                
                'Tag','Derived Forcing Functions - Input Data');
                        
            % Add table for derived forcing options
            %-------------------
            this.modelOptions.options{7,1}.ParentName = 'DerivedForcingTransformation';
            this.modelOptions.options{7,1}.ParentSettingName = 'options';            
            this.modelOptions.options{7,1}.tbl = uitable(this.modelOptions.cards,'ColumnName',{'Parameter','(none set)'}, ...
                'ColumnEditable',true,'Data',[], ...
                'CellEditCallback', @this.optionsSelection, ...    
                'Tag','Derived Forcing Transform - Model Settings', 'Visible','on');

            % Add list box for selecting the derived weighting functions input
            % data.
            % NOTE: Multiple selection of input forcing data is allowed.
            % This is defined in tableSelection().
            %-------------------
            this.modelOptions.options{8,1}.ParentName = 'derivedWeightingFunctions';
            this.modelOptions.options{8,1}.ParentSettingName = 'inputForcing';                     
            this.modelOptions.options{8,1}.lst = uicontrol('Parent',this.modelOptions.cards,'Style','list', 'BackgroundColor','w', ...
                'String',{},'Value',1,'Tag','Derived Weighting Functions - Input Data','Callback', @this.optionsSelection, 'Visible','on');

            % Add table for selecting the derived weighting functions options
            %-------------------
            this.modelOptions.options{9,1}.ParentName = 'derivedWeightingFunctions';
            this.modelOptions.options{9,1}.ParentSettingName = 'options';                     
            this.modelOptions.options{9,1}.tbl = uitable(this.modelOptions.cards,'ColumnName',{'(none)'}, ...
                'ColumnEditable',true,'Data',[], 'Tag','Derived Weighting Functions - Model Settings', ...
                'CellEditCallback', @this.optionsSelection, 'Visible','on');
            
            % Add label for general communications to user eg to state that
            % a weighting fnction has no options available.
            %-------------------
            this.modelOptions.options{10,1}.ParentName = 'general';
            this.modelOptions.options{10,1}.ParentSettingName = 'general';                     
            this.modelOptions.options{10,1}.lbl = uicontrol( 'Parent', this.modelOptions.cards, ...
                'Style','text','String','(empty)','Visible','on', ...
                'Tag', 'Model options - description');                 
            %----------------------------------------

            % Add context menu for adding /deleting rows
            % NOTE: UIContextMenu.UserData is used to store the table name
            % for the required operation.
            %----------------------------------------
            % Create menu for forcing transforms
            contextMenu = uicontextmenu(objHydroSight,'Visible','on');
            uimenu(contextMenu,'Label','Copy selected rows','Callback',@this.rowAddDelete);
            uimenu(contextMenu,'Label','Paste rows','Callback',@this.rowAddDelete,'Separator','on');
            uimenu(contextMenu,'Label','Insert row above selection','Callback',@this.rowAddDelete);
            uimenu(contextMenu,'Label','Insert row below selection','Callback',@this.rowAddDelete);            
            uimenu(contextMenu,'Label','Delete selected rows','Callback',@this.rowAddDelete);                
            set(this.forcingTranforms.tbl,'UIContextMenu',contextMenu);
            set(this.forcingTranforms.tbl.UIContextMenu,'UserData', 'this.forcingTranforms.tbl');
            
            % Create menu for weighting functions
            contextMenu = uicontextmenu(objHydroSight,'Visible','on');
            uimenu(contextMenu,'Label','Copy selected rows','Callback',@this.rowAddDelete);
            uimenu(contextMenu,'Label','Paste rows','Callback',@this.rowAddDelete,'Separator','on');
            uimenu(contextMenu,'Label','Insert row above selection','Callback',@this.rowAddDelete);
            uimenu(contextMenu,'Label','Insert row below selection','Callback',@this.rowAddDelete);            
            uimenu(contextMenu,'Label','Delete selected rows','Callback',@this.rowAddDelete);            
            set(this.weightingFunctions.tbl,'UIContextMenu',contextMenu);
            set(this.weightingFunctions.tbl.UIContextMenu,'UserData', 'this.weightingFunctions.tbl');
            
            % Create menu for derived forcing transforms
            contextMenu = uicontextmenu(objHydroSight,'Visible','on');
            uimenu(contextMenu,'Label','Copy selected rows','Callback',@this.rowAddDelete);
            uimenu(contextMenu,'Label','Paste rows','Callback',@this.rowAddDelete,'Separator','on');
            uimenu(contextMenu,'Label','Insert row above selection','Callback',@this.rowAddDelete);
            uimenu(contextMenu,'Label','Insert row below selection','Callback',@this.rowAddDelete);            
            uimenu(contextMenu,'Label','Delete selected rows','Callback',@this.rowAddDelete);            
            set(this.derivedForcingTranforms.tbl,'UIContextMenu',contextMenu);
            set(this.derivedForcingTranforms.tbl.UIContextMenu,'UserData', 'this.derivedForcingTranforms.tbl');

            % Create menu for derived weighting functions
            contextMenu = uicontextmenu(objHydroSight,'Visible','on');
            uimenu(contextMenu,'Label','Copy selected rows','Callback',@this.rowAddDelete);
            uimenu(contextMenu,'Label','Paste rows','Callback',@this.rowAddDelete,'Separator','on');
            uimenu(contextMenu,'Label','Insert row above selection','Callback',@this.rowAddDelete);
            uimenu(contextMenu,'Label','Insert row below selection','Callback',@this.rowAddDelete);            
            uimenu(contextMenu,'Label','Delete selected rows','Callback',@this.rowAddDelete);            
            set(this.derivedWeightingFunctions.tbl,'UIContextMenu',contextMenu);
            set(this.derivedWeightingFunctions.tbl.UIContextMenu,'UserData', 'this.derivedWeightingFunctions.tbl');
            
            %----------------------------------------            
            % Set dimensions for the grid     
            this.modelComponants.Heights=[25,-1];
            this.Figure.Heights = [-1 -1];
        end
        
        function initialise(this)
            % Reset GUI table data
            this.weightingFunctions.tbl.Data = cell(0, 5);
            this.derivedWeightingFunctions.tbl.Data = cell(0, 6);
            this.forcingTranforms.tbl.Data = cell(0, 4);
            this.derivedForcingTranforms.tbl.Data = cell(0, 5);

            % Reset interval variables
            this.boreID = '';
            this.siteData = []; 
            this.forcingData.colnames = {};
            this.forcingData.data = [];

            % Hide user options
            setOptionsCardIndex(this, '');
        end
        
        function setForcingData(this, fname)

             % Check fname file exists.
             if exist(fname,'file') ~= 2
                h = warndlg(['The following forcing data file does not exist:', fname],'File error');
                setIcon(this, h);
                return;
             end

             % Read in the file.
             try
                tbl = readtable(fname);
             catch
                h = warndlg(['The following forcing data file could not be read in. It must a .csv file of at least 4 columns (year, month, day, value):',fname],'File error');
                setIcon(this, h);
                clear tbl;
                return;
             end

             % Check there are sufficient number of columns
             if length(tbl.Properties.VariableNames) <4
                h = warndlg(['The following forcing data file must contain at least 4 columns (year, month, day, value):',fname],'File error');
                setIcon(this, h);
                clear tbl;
                return;
             end

             % Check all columns are numeric.
             for i=1:size(tbl,2)
                if any(~isnumeric(tbl{:,i}))
                    h = warndlg(['Column ',num2str(i), ' within the following forcing data file contains non-numeric data:',fname],'File error');
                    setIcon(this, h);
                    clear tbl;
                    return;
                end                    
             end

             % Check if there are any empty rows
             for i=1:size(tbl,2)
                if any(ismissing(tbl{:,i}))
                    h = warndlg(['Column ',num2str(i), ' within the following forcing data file contains row(s) with missing values:',fname],'File error');
                    setIcon(this, h);
                    clear tbl;
                    return;
                end                    
             end
                        
             % Set the column names.
             this.forcingData.colnames = tbl.Properties.VariableNames;
             this.forcingData.data = tbl;
             
             % Clear tbl
             clear tbl;
            
        end
        
        function setCoordinatesData(this, fname)
             % Check fname file exists.
             if exist(fname,'file') ~= 2
                h = warndlg(['The following site coordinates file does not exist:', fname],'File error');
                setIcon(this, h);
                return;
             end

             % Read in the file.
             try
                tbl = readtable(fname);
             catch
                h = warndlg(['The following site coordinates file could not be read in. It must a .csv file of 3 columns (site ID, easting, northing):',fname],'File error');
                setIcon(this, h);
                return;
             end

             % Check there are sufficient number of columns
             if length(tbl.Properties.VariableNames) ~=3
                h = warndlg(['The following site coordinates file must contain 3 columns  (site ID, easting, northing):',fname],'File error');
                setIcon(this, h);
                return;
             end

             % Check all columns are numeric.
             if any(any(~isnumeric(tbl{:,2:3})))
                h = warndlg(['Columns 2 and 3 within the following site coordinates file must contain only numeric data:',fname],'File error');
                setIcon(this, h);
                return;
             end

             % Check if there are any empty rows
             for i=1:size(tbl,2)
                if any(ismissing(tbl{:,i}))
                    h = warndlg(['Column ',num2str(i), ' within the following site coordinates file contains row(s) with missing values:',fname],'File error');
                    setIcon(this, h);
                    clear tbl;
                    return;
                end                    
             end
                                     
             % Check if the Bore ID is listed in the coordinates file
             if ~isempty(this.boreID) && ~any(strcmp(tbl{:,1},this.boreID))
                 h = warndlg(['The following bore is not listed in the coordinates files: ',this.boreID],'File error');
                 setIcon(this, h);
             end
             
             % Set the site data.
             this.siteData = tbl;
             
             % Clear tbl
             clear tbl;
            
        end
        
        function setBoreID(this, boreID)
            if iscell(boreID) && length(boreID)>1
                h = warndlg('TFN models must have a single site ID. Only the first will be considered.','Multiple Site ID error');
                setIcon(this, h);
                boreID = boreID{1};
            end
            if iscell(boreID)
                    this.boreID = boreID{1};
            else
                this.boreID = boreID;
            end
        end
        
        function setModelOptions(this, modelOptionsStr)
            
            % Convert model options string to a cell array
            if isempty(modelOptionsStr)
                modelOptions_all = cell(0,3);
            else
                modelOptions_all = eval(modelOptionsStr);                  
            end
            
            % Get the name of all model components
            componentNames = unique( modelOptions_all(:,1));
                       
            % Clear GUI tables
            this.weightingFunctions.tbl.Data = cell(0, 5);
            this.derivedWeightingFunctions.tbl.Data = cell(0, 6);
            this.forcingTranforms.tbl.Data = cell(0, 4);
            this.derivedForcingTranforms.tbl.Data = cell(0, 5);
            
            % Loop through each weighting function and add the data to the
            % GUI table. Also, get the cell arrays for the transformation
            % functions.
            for i=1:size(componentNames,1)
                
                % Find the cell options for the current weighting function
                compentFilter = cellfun( @(x) strcmp(x, componentNames{i}), modelOptions_all(:,1));
                
                % Get model options relating to the current component.
                modelOption_tmp = modelOptions_all(compentFilter,:);
                
                % initilise variables
                weightingFunctionName = '';
                inputcomponentName = '';
                forcingdataName = '';
                optionsName = '';
                transformFunctionName = '';
                transformForcingdata = '';
                forcingDataforWeighting = '';
                transformInputcomponent = '';
                transformOptions = '';
                
                % Get each term for the component
                weightingFunctionName_filt = cellfun( @(x) strcmp(x, 'weightingfunction'), modelOption_tmp(:,2));
                if any(weightingFunctionName_filt)
                    weightingFunctionName = modelOption_tmp{weightingFunctionName_filt,3};
                end
                
                inputcomponentName_filt = cellfun( @(x) strcmp(x, 'inputcomponent'), modelOption_tmp(:,2));
                if any(inputcomponentName_filt)
                    inputcomponentName = modelOption_tmp{inputcomponentName_filt,3};
                end
                
                forcingdata_filt = cellfun( @(x) strcmp(x, 'forcingdata'), modelOption_tmp(:,2));
                if any(forcingdata_filt)
                    forcingdataName = modelOption_tmp{forcingdata_filt,3};
                end
                
                options_filt = cellfun( @(x) strcmp(x, 'options'), modelOption_tmp(:,2));
                if any(options_filt)
                    optionsName = modelOption_tmp{options_filt,3}; 
                    for k=1:length(optionsName)
                        if ~isempty(optionsName{k}) && iscell(optionsName{k})
                            optionsName{k} = model_TFN_gui.cell2string(optionsName{k}, []);
                        else
                            optionsName{k}='{}';
                        end                        
                    end
                    optionsName = ['{',strjoin(optionsName),'}'];
                end
                
                % Check if the forcing data uses a transformation function.
                % If so, extract the data and get the output required for
                % the weighting function. Else if the forcing data is not
                % empty, then assign the required input data.
                hasTransformFunction = false;
                isFullTransformationFunction = false;
                if ~isempty(forcingdataName) && iscell(forcingdataName) && ...
                (size(forcingdataName,2)==2 || (size(forcingdataName,2)==1 && size(forcingdataName{1},2)==2))
                    hasTransformFunction = true;
                    
                    % If there are multiple input forcing data (eg
                    % multiple groundwater pumps) then find the one that
                    % lists all of the required inputs.
                    forcingDataforWeighting={};
                    if (size(forcingdataName,2)==1 && size(forcingdataName{1},2)==2)                    
                        for k=1:size(forcingdataName,1)
                            forcingdataNameTmp = forcingdataName{k};
                            transformFunctionName_filt = cellfun( @(x) strcmp(x, 'transformfunction'), forcingdataNameTmp(:,1));
                            if any(transformFunctionName_filt)
                                transformFunctionName = forcingdataNameTmp{transformFunctionName_filt,2};
                            end

                            transformForcingdata_filt = cellfun( @(x) strcmp(x, 'forcingdata'), forcingdataNameTmp(:,1));
                            if any(transformForcingdata_filt)
                                transformForcingdata = forcingdataNameTmp{transformForcingdata_filt,2};
                            end

                            forcingDataforWeighting_filt = cellfun( @(x) strcmp(x, 'outputdata'), forcingdataNameTmp(:,1));
                            if any(forcingDataforWeighting_filt )
                                if isempty(forcingDataforWeighting)
                                    forcingDataforWeighting{1,1} = forcingdataNameTmp{forcingDataforWeighting_filt,2};
                                else
                                    forcingDataforWeighting{k,1} = forcingdataNameTmp{forcingDataforWeighting_filt,2}; %#ok<AGROW> 
                                end
                            end

                            transformOptions_filt = cellfun( @(x) strcmp(x, 'options'), forcingdataNameTmp(:,1));
                            if any(transformOptions_filt)
                                transformOptions = forcingdataNameTmp{transformOptions_filt,2};
                            end

                            transformInputcomponent_filt = cellfun( @(x) strcmp(x, 'inputcomponent'), forcingdataNameTmp(:,1));
                            if any(transformInputcomponent_filt)
                                transformInputcomponent = forcingdataNameTmp{transformInputcomponent_filt,2};                    
                            end                           
  
                        end
                        
                    else
                        transformFunctionName_filt = cellfun( @(x) strcmp(x, 'transformfunction'), forcingdataName(:,1));
                        if any(transformFunctionName_filt)
                            transformFunctionName = forcingdataName{transformFunctionName_filt,2};
                        end

                        transformForcingdata_filt = cellfun( @(x) strcmp(x, 'forcingdata'), forcingdataName(:,1));
                        if any(transformForcingdata_filt)
                            transformForcingdata = forcingdataName{transformForcingdata_filt,2};
                        end

                        forcingDataforWeighting_filt = cellfun( @(x) strcmp(x, 'outputdata'), forcingdataName(:,1));
                        if any(forcingDataforWeighting_filt )
                            forcingDataforWeighting = forcingdataName{forcingDataforWeighting_filt,2};
                        end

                        transformOptions_filt = cellfun( @(x) strcmp(x, 'options'), forcingdataName(:,1));
                        if any(transformOptions_filt)
                            transformOptions = forcingdataName{transformOptions_filt,2};
                        end

                        transformInputcomponent_filt = cellfun( @(x) strcmp(x, 'inputcomponent'), forcingdataName(:,1));
                        if any(transformInputcomponent_filt)
                            transformInputcomponent = forcingdataName{transformInputcomponent_filt,2};                    
                        end                        
                    end
                    
                    % Check if the full transformation model is defined or
                    % is it just the output data for a tranformation model
                    % modle defined for another weighting function.
                    isFullTransformationFunction = true;
                    if ~isempty(transformFunctionName) && ~isempty(forcingDataforWeighting) && ...
                       isempty(transformForcingdata) && isempty(transformInputcomponent) && isempty(transformOptions)
                        isFullTransformationFunction = false;
                    end
                elseif ~isempty(forcingdataName)
                    % Data is assumed to be name of an input data column.
                    forcingDataforWeighting = forcingdataName;                    
                end
                
                % Add the weight function data to the GUI table. In doing
                % so, check if it is to be input to the weighting function
                % or derived weighting function.
                if isempty(inputcomponentName)
                   ind = size(this.weightingFunctions.tbl.Data,1)+1;
                   if ind==1
                        this.weightingFunctions.tbl.Data = cell(1,size(this.weightingFunctions.tbl.Data,2)); 
                   else
                       this.weightingFunctions.tbl.Data = [this.weightingFunctions.tbl.Data; cell(1,size(this.weightingFunctions.tbl.Data,2))]; 
                   end
                   this.weightingFunctions.tbl.Data{ind,2} = componentNames{i};
                   this.weightingFunctions.tbl.Data{ind,3} = weightingFunctionName;
                   this.weightingFunctions.tbl.Data{ind,5} = optionsName;
                   this.weightingFunctions.tbl.RowName = 1:size(this.weightingFunctions.tbl.Data,1);

                   % Check if the input comes from the output of a
                   % transformation function.                   
                   if hasTransformFunction
                       if iscell(forcingDataforWeighting)
                           
                            nForcingInputs = size(forcingDataforWeighting,1);
                            LHS = cellstr(repmat([transformFunctionName, ' :'],nForcingInputs,1));
                            RHS = cell(nForcingInputs,1);
                            RHS(:) = {' '};
                            LHS = strcat(LHS,RHS);
                            
                            forcingDataforWeighting = strcat( LHS, forcingDataforWeighting(1:nForcingInputs));
                            forcingDataforWeighting = model_TFN_gui.cell2string(forcingDataforWeighting,'');
                            this.weightingFunctions.tbl.Data{ind,4} = forcingDataforWeighting;
                                                                                                                
                       else
                            this.weightingFunctions.tbl.Data{ind,4} = [transformFunctionName, ' : ', forcingDataforWeighting];
                       end
                   else
                       if iscell(forcingDataforWeighting)
                           
                            nForcingInputs = size(forcingDataforWeighting,1);
                            LHS = cellstr(repmat('Input Data : ',nForcingInputs,1));
                            RHS = cell(nForcingInputs,1);
                            RHS(:) = {' '};
                            LHS = strcat(LHS,RHS);

                            forcingDataforWeighting = strcat( LHS, forcingDataforWeighting(1:nForcingInputs));
                            forcingDataforWeighting = model_TFN_gui.cell2string(forcingDataforWeighting,'');
                            this.weightingFunctions.tbl.Data{ind,4} = forcingDataforWeighting;                            
                       else
                           this.weightingFunctions.tbl.Data{ind,4} = ['Input Data : ', forcingDataforWeighting];
                       end
                   end
                                                      
                else
                   ind = size(this.derivedWeightingFunctions.tbl.Data,1)+1;
                   if ind==1
                        this.derivedWeightingFunctions.tbl.Data = cell(1,size(this.derivedWeightingFunctions.tbl.Data,2)); 
                   else
                       this.derivedWeightingFunctions.tbl.Data = [this.derivedWeightingFunctions.tbl.Data; cell(1,size(this.derivedWeightingFunctions.tbl.Data,2))]; 
                   end                   
                   this.derivedWeightingFunctions.tbl.Data{ind,2} = componentNames{i};
                   this.derivedWeightingFunctions.tbl.Data{ind,3} = weightingFunctionName;
                   this.derivedWeightingFunctions.tbl.Data{ind,4} = inputcomponentName; 
                   this.derivedWeightingFunctions.tbl.Data{ind,6} = optionsName; 
                   this.derivedWeightingFunctions.tbl.RowName = 1:size(this.derivedWeightingFunctions.tbl.Data,1);
                   
                   % Check if the input comes from the output of a
                   % transformation function.
                   if hasTransformFunction
                       if iscell(forcingDataforWeighting)
                            this.derivedWeightingFunctions.tbl.Data{ind,5} = strcat( [transformFunctionName, ' : '], forcingDataforWeighting);
                       else
                            this.derivedWeightingFunctions.tbl.Data{ind,5} = [transformFunctionName, ' : ', forcingDataforWeighting];
                       end
                   else
                       if iscell(forcingDataforWeighting)
                            this.derivedWeightingFunctions.tbl.Data{ind,5} = strcat( ['Input Data : ', forcingDataforWeighting]);
                       else
                           this.derivedWeightingFunctions.tbl.Data{ind,5} = ['Input Data : ', forcingDataforWeighting];
                       end
                   end
                    
                                      
                end
                
                % Add the forcing transforation data to the GUI tables
                if hasTransformFunction && isFullTransformationFunction
                   
                    if isempty(transformInputcomponent)
                        ind = size(this.forcingTranforms.tbl.Data,1)+1;
                        if ind==1
                            this.forcingTranforms.tbl.Data = cell(1,size(this.forcingTranforms.tbl.Data,2)); 
                        else
                            this.forcingTranforms.tbl.Data = [this.forcingTranforms.tbl.Data; cell(1,size(this.forcingTranforms.tbl.Data,2))]; 
                        end                             
                        this.forcingTranforms.tbl.Data{ind,2} = transformFunctionName;
                        
                        if ~isempty(transformForcingdata) && iscell(transformForcingdata)
                            transformForcingdata = model_TFN_gui.cell2string(transformForcingdata, []);
                        end
                        this.forcingTranforms.tbl.Data{ind,3} = transformForcingdata;

                        if ~isempty(transformOptions) && iscell(transformOptions)
                            transformOptions = model_TFN_gui.cell2string(transformOptions, []);
                        end 
                        this.forcingTranforms.tbl.Data{ind,4} = transformOptions;
                        this.forcingTranforms.tbl.RowName = 1:size(this.forcingTranforms.tbl.Data,1);
                    else
                        ind = size(this.derivedForcingTranforms.tbl.Data,1)+1;
                        if ind==1
                            this.derivedForcingTranforms.tbl.Data = cell(1,size(this.derivedForcingTranforms.tbl.Data,2)); 
                        else
                            this.derivedForcingTranforms.tbl.Data = [this.derivedForcingTranforms.tbl.Data; cell(1,size(this.derivedForcingTranforms.tbl.Data,2))]; 
                        end                            
                        this.derivedForcingTranforms.tbl.Data{ind,2} = transformFunctionName;
                        this.derivedForcingTranforms.tbl.Data{ind,3} = transformInputcomponent;                        
                        
                        if ~isempty(transformForcingdata) && iscell(transformForcingdata)
                            transformForcingdata = model_TFN_gui.cell2string(transformForcingdata, []);
                        end
                        this.derivedForcingTranforms.tbl.Data{ind,4} = transformForcingdata;

                        if ~isempty(transformOptions) && iscell(transformOptions)
                            transformOptions = model_TFN_gui.cell2string(transformOptions, []);
                        end 
                        this.derivedForcingTranforms.tbl.Data{ind,5} = transformOptions;                        
                        this.derivedForcingTranforms.tbl.RowName = 1:size(this.derivedForcingTranforms.tbl.Data,1);
                    end
                end     
            end            

            % Update card to selected dropdown item
            this.dropdownOptions.cards.SelectedChild = this.dropdownOptions.dropdown.Value           
        end
        
        function modelOptionsArray = getModelOptions(this)
            % Convert forcing tranformation and derived forcing tranformation functions to strings.
            for k=1:2
                if k==1
                    cellData  = this.forcingTranforms.tbl.Data;                    
                else
                    cellData  = this.derivedForcingTranforms.tbl.Data;
                end
                
                % Goto next loop if all of cell data is empty
                if size(cellData ,1)==1 && all(cellfun(@(x) isempty(x),cellData))
                    continue;
                end
                
                % Loop though each row of cell data
                for j=1:size(cellData ,1)
                   stringCell = '{';           
                   stringCell = strcat(stringCell, sprintf(' ''transformfunction'',  ''%s'';',cellData{j,2} ));
                   if k==2
                       stringCell = strcat(stringCell, sprintf(' ''inputcomponent'',  ''%s'';',cellData{j,3} ));               
                   end
                   stringCell = strcat(stringCell, sprintf(' ''forcingdata'', %s;',cellData{j,2+k} )); 
                   if ~isempty(cellData{j,3+k})
                        stringCell = strcat(stringCell, sprintf(' ''options'', %s;',cellData{j,3+k} )); 
                   end
                   stringCell = strcat(stringCell, '}'); 
                   forcingString.(cellData{j,2}) = stringCell;

                   % Initialise logical variable denoting if its already been
                   % inserted.
                   forcingStringInserted.(cellData{j,2}) = false;
                end
            end
                       
            % Convert weighting functions to string.
            modelOptionsArray =  '{';
            
            for k=1:2
                if k==1
                    cellData  = this.weightingFunctions.tbl.Data;
                else
                    cellData  = this.derivedWeightingFunctions.tbl.Data;
                end
                    
                % Goto next loop if all of cell data is empty
                if size(cellData ,1)==1 && all(cellfun(@(x) isempty(x),cellData))
                    continue;
                end
                
                % Loop through each row of weighting table data
                for i=1:size(cellData ,1)        
                    
                   % Add weighting function name. 
                   modelOptionsArray = strcat(modelOptionsArray, sprintf(' ''%s'', ''weightingfunction'',  ''%s'';',cellData{i,2},cellData{i,3} ));

                   % Add source componant name. 
                   if k==2
                        modelOptionsArray = strcat(modelOptionsArray, sprintf(' ''%s'', ''inputcomponent'',  ''%s'';',cellData{i,2},cellData{i,4} ));
                   end

                   % Add model options 
                   if ~isempty(cellData{i,4+k})
                        modelOptionsArray = strcat(modelOptionsArray, sprintf(' ''%s'', ''options'', %s;',cellData{i,2},cellData{i,4+k} )); 
                   end                   
                                      
                   % Convert forcing data to a cell array
                   try
                       forcingColNames =  eval(cellData{i,3+k});
                   catch
                       forcingColNames =  cellData(i,3+k);
                   end

                   %Check if there is any focring data.
                   if isempty(forcingColNames{1})
                       continue;
                   end
                   
                   % Loop through each forcing data input.
                   for j=1:length(forcingColNames)

                       % Insert input data.                     
                       if ~isempty(strfind(forcingColNames{j}, 'Input Data : '))
                           [~, ind_end] = regexp(forcingColNames{j}, 'Input Data : ');
                           forcingColNames_tmp =  forcingColNames{j}(ind_end+1:end);
                           ind_start = regexp(forcingColNames_tmp, '''');
                           if ~isempty(ind_start)
                                forcingColNames_tmp =  forcingColNames_tmp(1:ind_start-1);
                           end
                       else
                           % Find function name
                           forcingFunc_Ind = regexp(forcingColNames{j}, ' : ');  
                           forcingFuncName = forcingColNames{j}(1:forcingFunc_Ind-1);

                           % Insert cell array string for required function name.
                           % If the forcing function has already been inserted then
                           % just build a string for the forcing to be extracted
                           % from it.
                           if ~forcingStringInserted.(forcingFuncName) 
                                % Get just output name from string
                               [~, ind_end] = regexp(forcingColNames{j}, [forcingFuncName,' : ']);
                               forcingColNames_tmp =  forcingColNames{j}(ind_end+1:end);

                                % Add required output from weighting function to forcing function cell array
                                forcingString.(forcingFuncName) = forcingString.(forcingFuncName)(1:end-1);
                                forcingString.(forcingFuncName) = strcat(forcingString.(forcingFuncName), ...
                                     sprintf(' ''outputdata'' , ''%s'' };', forcingColNames_tmp ) );
                                forcingColNames_tmp = forcingString.(forcingFuncName);
                                forcingStringInserted.(forcingFuncName) = true;
                           else

                                % Get just output name from string
                               [~, ind_end] = regexp(forcingColNames{j}, [forcingFuncName,' : ']);
                               forcingColNames_tmp =  forcingColNames{j}(ind_end+1:end);                           

                               % Create cell array for an already created
                               % forcing transform function but only declare
                               % the forcing to be taken from the function.
                               forcingColNames_tmp = { 'transformfunction', forcingFuncName; 'outputdata', forcingColNames_tmp}; %#ok<AGROW,NASGU> 

                               % Convert to a string
                               className = metaclass(this);
                               className = className.Name;
                               colnames = {'component','property','value'}; %#ok<NASGU> 
                               forcingColNames_tmp =  eval([className,'.cell2string(forcingColNames_tmp, colnames)']);                           
                           end

                       end

                       % Add forcing string to the model options string
                       if length(forcingColNames)==1
                            modelOptionsArray = strcat(modelOptionsArray, sprintf(' ''%s'', ''forcingdata'', ''%s'';',cellData{i,2}, forcingColNames_tmp ));                            
                       elseif length(forcingColNames)>1 && j==1
                            modelOptionsArray = strcat(modelOptionsArray, sprintf(' ''%s'', ''forcingdata'', { ''%s'';',cellData{i,2}, forcingColNames_tmp ));                            
                       elseif length(forcingColNames)>1 && j==length(forcingColNames)
                            modelOptionsArray = strcat(modelOptionsArray, sprintf(' ''%s'' };',forcingColNames_tmp ));                                                    
                       else                           
                            modelOptionsArray = strcat(modelOptionsArray, sprintf(' ''%s'';',forcingColNames_tmp ));
                       end                       
                   end

                end
            end

            modelOptionsArray= strcat(modelOptionsArray, '}'); 

            % Remove any ' symbols for cell arrays internal to the larger
            % string.
            while contains(modelOptionsArray, '}''' )
                ind = strfind(modelOptionsArray, '}''' );
                ind = ind(1);
                modelOptionsArray = [modelOptionsArray(1:ind),  modelOptionsArray(ind+2:end)];
            end
            while contains(modelOptionsArray, '''{' )
                ind = strfind(modelOptionsArray, '''{' );
                ind = ind(1);
                modelOptionsArray = [modelOptionsArray(1:ind-1),  modelOptionsArray(ind+1:end)];
            end            
            while contains(modelOptionsArray, ';'';' )
                ind = strfind(modelOptionsArray, ';'';' );
                ind = ind(1);
                modelOptionsArray = [modelOptionsArray(1:ind),  modelOptionsArray(ind+3:end)];
            end             
        end
        
        function componentSelection(this, hObject, eventdata)
            if this.dropdownOptions.cards.SelectedChild ~= hObject.Value
                setOptionsCardIndex(this,'')
            end
            this.dropdownOptions.cards.SelectedChild = hObject.Value;
        end
        
        function tableSelection(this, hObject, eventdata)
            icol=[];
            irow=[];
            if isprop(eventdata, 'Indices') || isfield(eventdata, 'Indices')
                if ~isempty(eventdata.Indices)
                    icol=eventdata.Indices(:,2);
                    irow=eventdata.Indices(:,1);  
                end
            end
                            
            % Record the current table, row, col if the inputs are
            % not empty. Else, extract the exiting values from
            % this.currentSelection                    
            if ~isempty(irow) && ~isempty(icol)
                this.currentSelection.row = irow;
                this.currentSelection.col= icol;
                this.currentSelection.table = eventdata.Source.Tag;
            else
                irow = this.currentSelection.row;
                icol = this.currentSelection.col;                                                
            end

            % Get handle to main GUI
            objHydroSight = ancestor(this.Figure,'figure','toplevel');

            % Get handle to main GUI out tab panel.
            objOuterTabPanel = findobj(objHydroSight, 'Tag','HydroSight Outer Steps TabPanel');

            % Undertake table/list specific operations.
            switch eventdata.Source.Tag
                case 'Forcing Transform'
                    
                    % Add a row if the table is empty
                    if size(get(hObject,'Data'),1)==0
                        this.forcingTranforms.tbl.Data = cell(1,size(this.forcingTranforms.tbl.Data,2));
                    end

                    % Get the forcing function name.
                    if irow > size(this.forcingTranforms.tbl.Data,1)
                        return;
                    end
                    funName = this.forcingTranforms.tbl.Data{irow, 2};

                    switch eventdata.Source.ColumnName{icol}
                        case 'Forcing Transform Function'
                        
                            % Get description of the function.
                            functionName = this.forcingTranforms.tbl.Data{this.currentSelection.row, 2};
                            if isempty(functionName)
                                return;
                            end
                            modelDescription = eval([functionName,'.modelDescription']);
                            set(this.modelOptions.options{10,1}.lbl,'HorizontalAlignment','left');
                            this.modelOptions.options{10,1}.lbl.String = ['Forcing Transform - Function description','', modelDescription];
                            setOptionsCardIndex(this, 'Model options - description');
                        case 'Input Data'
                           % Define the drop down options for the input
                           % data
                           dropdownOptions = sort(this.forcingData.colnames(4:end));
                           this.modelOptions.options{1, 1}.tbl.ColumnFormat = {'char',{'(none)' dropdownOptions{:}} }; %#ok<CCAT> 
                            
                           % Call function method giving required
                           % variable name.
                           requiredVariables = feval(strcat(funName,'.inputForcingData_required'),this.boreID, this.forcingData.data,  this.forcingData.colnames, this.siteData);

                           % Add row for each required variable
                           if isempty(this.forcingTranforms.tbl.Data{this.currentSelection.row ,3})
                               this.modelOptions.options{1, 1}.tbl.Data = cell(size(requiredVariables,1),2);
                               this.modelOptions.options{1, 1}.tbl.RowName=cell(1,length(requiredVariables)); 
                               for i=1:length(requiredVariables)                                   
                                    this.modelOptions.options{1, 1}.tbl.Data{i,1}= requiredVariables{i};
                                    this.modelOptions.options{1, 1}.tbl.RowName{i}= num2str(i);
                               end
                           else
                               try
                                   this.modelOptions.options{1, 1}.tbl.Data = cell(0,2);
                                   this.modelOptions.options{1, 1}.tbl.RowName = cell(size(this.modelOptions.options{1, 1}.tbl.Data,1),1);
                                   this.modelOptions.options{1, 1}.tbl.Data = eval(this.forcingTranforms.tbl.Data{irow,3});
                                   for i=1:size(this.modelOptions.options{1, 1}.tbl.Data,1)                                                                           
                                        this.modelOptions.options{1, 1}.tbl.RowName{i}= num2str(i);
                                   end
                               catch
                                   h = warndlg('The input string appears to have a syntax error. It should be an Nx2 cell array.','Input error');                                       
                                   setIcon(this, h);
                               end
                           end

                           % Display table
                           setOptionsCardIndex(this, 'Forcing Transform - Input Data');
                        case 'Options' 

                           % Get the model options.
                           [modelSettings, colNames, colFormats, colEdits, tooltips] = feval(strcat(funName,'.modelOptions'));

                           % Check if options are available.
                           if isempty(colNames)                          
                                this.modelOptions.options{2,1}.lbl.String = {'Forcing Transform - Model Settings',['(No options are available for the following weighting function: ',funName,')']};
                                setOptionsCardIndex(this, 'Model options - description');
                           else

                               % Assign model properties and data
                               this.modelOptions.options{2,1}.tbl.ColumnName = colNames;
                               this.modelOptions.options{2,1}.tbl.ColumnEditable = colEdits;
                               this.modelOptions.options{2,1}.tbl.ColumnFormat = colFormats;                               
                               this.modelOptions.options{2,1}.tbl.TooltipString = tooltips;                               
                               this.modelOptions.options{2,1}.tbl.Tag = 'Forcing Transform - Model Settings';                                                              

                               if isempty(this.forcingTranforms.tbl.Data{this.currentSelection.row ,4})
                                   this.forcingTranforms.tbl.Data{this.currentSelection.row ,4} = model_TFN_gui.cell2string(modelSettings,colNames);
                                   this.modelOptions.options{2,1}.tbl.Data = modelSettings;
                               else
                                   try                                       
                                       data = eval(this.forcingTranforms.tbl.Data{irow,4});
                                       if strcmpi(colNames(1),'Select')
                                           data = [ mat2cell(false(size(data,1),1),ones(1,size(data,1))),  data];
                                       end

                                       this.modelOptions.options{2, 1}.tbl.Data = data;
                                   catch
                                       h = warndlg('The function options string appears to have a sytax error. It should be an Nx4 cell array.','Input error');                                       
                                       setIcon(this, h);
                                   end
                               end

                               % Assign context menu if the first column is
                               % named 'Select' and is a tick box.
                               if strcmp(colNames{1},'Select') && strcmp(colFormats{1},'logical')
                                    contextMenu = uicontextmenu(objOuterTabPanel,'Visible','on');
                                    uimenu(contextMenu,'Label','Copy selected rows','Callback',@this.rowAddDelete);
                                    uimenu(contextMenu,'Label','Paste rows','Callback',@this.rowAddDelete,'Separator','on');
                                    uimenu(contextMenu,'Label','Insert row above selection','Callback',@this.rowAddDelete);
                                    uimenu(contextMenu,'Label','Insert row below selection','Callback',@this.rowAddDelete);            
                                    uimenu(contextMenu,'Label','Delete selected rows','Callback',@this.rowAddDelete);            
                                    set(this.modelOptions.options{2, 1}.tbl,'UIContextMenu',contextMenu);  
                                    set(this.modelOptions.options{2, 1}.tbl.UIContextMenu,'UserData', 'this.modelOptions.options{2, 1}.tbl');
                               else
                                   set(this.modelOptions.options{2, 1}.tbl,'UIContextMenu',[]);
                               end                               
                               
                               % Show table
                               setOptionsCardIndex(this, 'Forcing Transform - Model Settings');

                           end
                        otherwise
                            setOptionsCardIndex(this, '');
                    end
                case 'Weighting Functions'


                    % Add a row if the table is empty
                    if size(get(hObject,'Data'),1)==0
                        this.weightingFunctions.tbl.Data = cell(1,size(this.weightingFunctions.tbl.Data,2));
                    end               
                    
                    switch eventdata.Source.ColumnName{icol}
                        case 'Input Data'
                           % Get the list of input forcing data.
                           lstOptions = reshape(this.forcingData.colnames(4:end),[length(this.forcingData.colnames(4:end)),1]);

                           % Add source name
                           lstOptions = strcat('Input Data :',{' '}, lstOptions);

                           % Loop through each forcing function and add
                           % the possible outputs.
                           for i=1: size(this.forcingTranforms.tbl.Data,1)
                               if isempty(this.forcingTranforms.tbl.Data{i,2})
                                   continue
                               end

                               % Get output options.
                               %outputOptions = feval(strcat(this.forcingTranforms.tbl.Data{i,2},'.outputForcingdata_options'),this.forcingData.colnames);
                               outputOptions = feval(strcat(this.forcingTranforms.tbl.Data{i,2},'.outputForcingdata_options'),this.boreID, this.forcingData.data,  this.forcingData.colnames, this.siteData);

                               % Transpose if required
                               if size(outputOptions,1)==1 && size(outputOptions,2)>1
                                   outputOptions = outputOptions';
                               end
                               
                               % Add output options from the function
                               % to the list of available options
                               lstOptions = [lstOptions; strcat(this.forcingTranforms.tbl.Data{i,2},{' : '}, outputOptions)]; %#ok<AGROW> 
                           end


                           % Loop through each derived forcing function and add
                           % the possible outputs.
                           for i=1: size(this.derivedForcingTranforms.tbl.Data,1)
                               if isempty(this.derivedForcingTranforms.tbl.Data{i,2})
                                   continue
                               end

                               % Get output options.
                               outputOptions = feval(strcat(this.derivedForcingTranforms.tbl.Data{i,2},'.outputForcingdata_options'),this.boreID, this.forcingData.data,  this.forcingData.colnames, this.siteData);

                               % Transpose if required
                               if size(outputOptions,1)==1 && size(outputOptions,2)>1
                                   outputOptions = outputOptions';
                               end
                               
                               % Add output options from the function
                               % to the list of available options
                               lstOptions = [lstOptions; strcat(this.derivedForcingTranforms.tbl.Data{i,2},{' : '}, outputOptions)]; %#ok<AGROW> 
                           end                                                      
                           
                           % Assign the list of options to the list box                               
                           this.modelOptions.options{3,1}.lst.String = lstOptions;
                           
                           % Allow multipple-selection.
                           this.modelOptions.options{3,1}.lst.Min = 1;
                           this.modelOptions.options{3,1}.lst.Max = length(lstOptions);
                           
                           % Highlight the previosuly selected option. If
                           % it looks like a string expression for a
                           % cell, evaluate it.
                           userSelections = this.weightingFunctions.tbl.Data{this.currentSelection.row, 4};
                           if ~isempty(userSelections) && strcmp(userSelections(1) ,'{') && strcmp(userSelections(end) ,'}')
                                userSelections = eval(this.weightingFunctions.tbl.Data{this.currentSelection.row, 4});
                           end
                           rowInd= [];
                           if ~iscell(userSelections)
                               userSelections_tmp{1} =userSelections;
                               userSelections = userSelections_tmp;
                               clear userSelections_tmp
                           end
                           for i=1:size(userSelections,1)
                                ind = find(cellfun( @(x) strcmp(x, userSelections{i}), lstOptions ));
                                rowInd = [rowInd; ind]; %#ok<AGROW> 
                           end
                           this.modelOptions.options{3,1}.lst.Value = rowInd;
                           
                           % Show the list box
                           setOptionsCardIndex(this, 'Weighting Functions - Input Data');

                        case 'Weighting Function'   
                            % Get description of the function.
                            functionName = this.weightingFunctions.tbl.Data{this.currentSelection.row, 3};
                            if ~isempty(functionName)
                                modelDescription = eval([functionName,'.modelDescription']);
                                set(this.modelOptions.options{10,1}.lbl,'HorizontalAlignment','left');
                                this.modelOptions.options{10,1}.lbl.String = ['Weighting Functions - Function description','',modelDescription];
                            end
                            setOptionsCardIndex(this, 'Model options - description');

                        case 'Options'
                            % Check that the weigthing function and forcing
                            % data have been defined
                            if any(isempty(this.weightingFunctions.tbl.Data(this.currentSelection.row,2:4)))
                                h = warndlg('The component name, weighting function ands input data must be specified before setting the options.','Input error');
                                setIcon(this, h);
                                return;
                            end
                            
                            % Get the input forcing data options.
                            inputDataNames = this.weightingFunctions.tbl.Data{this.currentSelection.row, 4};
                            
                            % Convert input data to a cell array if it is a
                            % list of multiple inputs.
                            try
                                inputDataNames = eval(inputDataNames);
                            catch
                                % do nothing
                            end
                            
                           % Remove source name for input data.     
                           if ischar(inputDataNames)
                               inputDataNames_tmp{1}=inputDataNames;
                               inputDataNames = inputDataNames_tmp;
                               clear inputDataNames_tmp
                           end
                           for j=1: size(inputDataNames,1)
                               if ~isempty(strfind(inputDataNames{j}, 'Input Data : '))
                                   [~,ind] = regexp(inputDataNames{j}, 'Input Data : ');
                               else
                                   [~,ind] = regexp(inputDataNames{j}, ' : ');  
                               end                                                   
                               %inputDataNames{j} =  inputDataNames{j}(ind+3:end);
                               inputDataNames{j} =  inputDataNames{j}(ind+1:end);
                           end
                           
                           if isempty(inputDataNames) || (iscell(inputDataNames) && isempty(inputDataNames{1,1}))
                               h = warndlg('The input data does not appear to have been input for this model compnenent.','Input data error');
                               setIcon(this, h);
                               return;
                           end
                           
                           % Get the list of input forcing data.
                           funName = this.weightingFunctions.tbl.Data{this.currentSelection.row, 3};

                           % Get the weighting function options.
%                            [modelSettings, colNames, colFormats, colEdits, tooltip] = feval(strcat(funName,'.modelOptions'), ...
%                            this.boreID, inputDataNames, this.siteData);
                           modelSettings= feval(strcat(funName,'.modelOptions'), this.boreID, inputDataNames, this.siteData);

                           % If the function has any options the
                           % display the options else display a message
                           % in box stating no options are available.                           
                           if isempty(modelSettings)  
                               set(this.modelOptions.options{10,1}.lbl,'HorizontalAlignment','center');
                               this.modelOptions.options{10,1}.lbl.String = {'Weighting Functions - Options',['(No options are available for the following weighting function: ',funName,')']};                                    
                               setOptionsCardIndex(this, 'Model options - description');
                           else
                               %this.modelOptions.options{4,1}.lbl.String = 'Weighting Functions - Options';

                               % Loop through each model option
                               if ~iscell(modelSettings)
                                   modelSettingsTmp = cell(1,1);
                                   modelSettingsTmp{1} = modelSettings; 
                                   modelSettings = modelSettingsTmp; 
                                   clear modelSettingsTmp 
                               end
                               
                               % Disable all options tabs
                               for i=1:length(this.modelOptions.options{4, 1}.tabs.TabEnables)
                                  this.modelOptions.options{4, 1}.tabs.TabEnables{i}='off'; 
                                  drawnow();   
                               end
                               
                               % Get existing options data and convert from
                               % a string.
                               haveInputData = false(size(modelSettings));
                               if ~isempty(this.weightingFunctions.tbl.Data{this.currentSelection.row ,5})
                                   try
                                       data = eval(this.weightingFunctions.tbl.Data{this.currentSelection.row ,5});
                                       
                                       % Check 'data' and the model options
                                       % are the same length
                                       if length(data) == length(modelSettings)
                                           for i=1:length(data)                                        
                                               if strcmpi(modelSettings{i}.colNames(1),'Select')
                                                   data{i} = [ mat2cell(false(size(data{i},1),1),ones(1,size(data{i},1))) , data{i}];                                                   
                                               end             
                                               if size(data{i},2)==length(modelSettings{i}.colNames)
                                                   haveInputData(i) =  true;
                                               end                                                      
                                           end 
                                           
                                       else
                                           h = warndlg('There are an inconsistent number of input and expected options. The inputs data is being ignored.','Input error');
                                           setIcon(this, h);
                                       end
                                   catch
                                       h = warndlg('The function options string appears to have a sytax error. It should be an Nx4 cell array.','Input error');
                                       setIcon(this, h);
                                       %this.modelOptions.options{4, 1}.tbl.Data = '';
                                   end
                                   
                               end
                               % Assign model properties and data                               
                               for i=1:length(modelSettings)
                                   
                                   this.modelOptions.options{4, 1}.tabs.TabTitles{i} =  modelSettings{i}.label;
                                   this.modelOptions.options{4, 1}.tabs.TabEnables{i} =  'on';
                                   
                                   optionsTag = ['Weighting Functions - Options Tab ',num2str(i),' table'];
                                   optionsTable = findobj(this.modelOptions.options{4,1}.tabs,'Tag',optionsTag);
                                   optionsTable.Data = {};
                                   optionsTable.ColumnName = modelSettings{i}.colNames;
                                   optionsTable.ColumnEditable = modelSettings{i}.colEdits;
                                   optionsTable.ColumnFormat = modelSettings{i}.colFormats;          
                                   optionsTable.TooltipString = modelSettings{i}.TooltipString;

                                   % Input the existing data or else the
                                   % default settings.
                                   if haveInputData(i)
                                       optionsTable.Data = data{i};
                                   else                                       
                                       if isempty(modelSettings{i}.options)
                                           optionsTable.Data = cell(1,length(modelSettings{i}.colNames));
                                       else
                                           optionsTable.Data = modelSettings{i}.options;
                                       end
                                   end    
                                   
                                   % Assign context menu if the first column is
                                   % named 'Select' and is a tick box.
                                   if strcmp(modelSettings{i}.colNames{1},'Select') && strcmp(modelSettings{i}.colFormats{1},'logical')
                                        contextMenu = uicontextmenu(objHydroSight,'Visible','on');
                                        uimenu(contextMenu,'Label','Copy selected rows','Callback',@this.rowAddDelete);
                                        uimenu(contextMenu,'Label','Paste rows','Callback',@this.rowAddDelete,'Separator','on');
                                        uimenu(contextMenu,'Label','Insert row above selection','Callback',@this.rowAddDelete);
                                        uimenu(contextMenu,'Label','Insert row below selection','Callback',@this.rowAddDelete);            
                                        uimenu(contextMenu,'Label','Delete selected rows','Callback',@this.rowAddDelete);            
                                        set(optionsTable,'UIContextMenu',contextMenu);  
                                        set(optionsTable.UIContextMenu,'UserData', strcat("findobj(this.modelOptions.options{4,1}.tabs,'Tag',['Weighting Functions - Options Tab ",num2str(i)," table'])"));
                                   else
                                       set(optionsTable,'UIContextMenu',[]);
                                   end
                               end
                               % Show table
                               setOptionsCardIndex(this, 'Weighting Functions - Options');
                           end

                        otherwise
                            setOptionsCardIndex(this, '');
                    end

                case 'Derived Forcing Transform'                
                    
                    % Add a row if the table is empty
                    if size(get(hObject,'Data'),1)==0
                        this.derivedForcingTranforms.tbl.Data = cell(1,size(this.derivedForcingTranforms.tbl.Data,2));
                        return;
                    end                    
                    
                    % Get the derived forcing function name.
                    funName = this.derivedForcingTranforms.tbl.Data{irow, 2};

                    % Get the source forcing function name.
                    sourceFunName = this.derivedForcingTranforms.tbl.Data{irow, 3};

                    switch eventdata.Source.ColumnName{icol}
                        case 'Forcing Transform Function'
                        
                            % Get description of the function.
                            functionName = this.derivedForcingTranforms.tbl.Data{this.currentSelection.row, 2};
                            if isempty(functionName)
                                return;
                            end
                            modelDescription = eval([functionName,'.modelDescription']);
                            set(this.modelOptions.options{10,1}.lbl,'HorizontalAlignment','left');
                            this.modelOptions.options{10,1}.lbl.String = ['Derived Forcing Transform - Function description','',modelDescription];
                            setOptionsCardIndex(this, 'Model options - description');
                            
                        case 'Source Forcing Function' 
                            derivedForcingFunctionsListed = this.forcingTranforms.tbl.Data(:,2);
                            this.derivedForcingTranforms.tbl.ColumnFormat{3} = derivedForcingFunctionsListed;
                            setOptionsCardIndex(this, '');
                        case 'Input Data'
                           % Call function method giving required
                           % variable name.
                           requiredVariables = feval(strcat(funName,'.inputForcingData_required'));

                           % Add row for each required variable
                           if isempty(this.derivedForcingTranforms.tbl.Data{this.currentSelection.row ,4})
                               for i=1:length(requiredVariables)                                   
                                    this.modelOptions.options{6, 1}.tbl.Data{i,1}= requiredVariables{i};
                                    this.modelOptions.options{6, 1}.tbl.RowName{i}= num2str(i);
                               end
                           else
                               try
                                   this.modelOptions.options{6, 1}.tbl.Data = eval(this.derivedForcingTranforms.tbl.Data{irow,4});
                                   for i=1:length(requiredVariables)                                                                           
                                        this.modelOptions.options{6, 1}.tbl.RowName{i}= num2str(i);
                                   end
                               catch
                                   h = warndlg('The input string appears to have a syntax error. It should be an Nx2 cell array.','Input error');   
                                   setIcon(this, h);
                               end
                           end
                           
                           % Get the list of input forcing data and add source name
                           lstOptions = reshape(this.forcingData.colnames(4:end),[1, length(this.forcingData.colnames(4:end))]);

                           % Add input list to drop down
                           this.modelOptions.options{6, 1}.tbl.ColumnFormat = {'char',lstOptions};

                           % Display table
                           setOptionsCardIndex(this, 'Derived Forcing Functions - Input Data');
                          
                        case 'Options'    
                           % Get the model options.
                           [modelSettings, colNames, colFormats, colEdits, tooltips] = feval(strcat(funName,'.modelOptions'), sourceFunName );

                           % Check if options are available.
                           if isempty(colNames)                          
                                set(this.modelOptions.options{10,1}.lbl,'HorizontalAlignment','left');
                                this.modelOptions.options{10,1}.lbl.String = {'Derived Forcing Transform - Model Settings','',['(No options are available for the following function: ',funName,')']};
                                setOptionsCardIndex(this, 'Model options - description');
                           else

                               % Assign model properties and data
                               this.modelOptions.options{7,1}.tbl.ColumnName = colNames;
                               this.modelOptions.options{7,1}.tbl.ColumnEditable = colEdits;
                               this.modelOptions.options{7,1}.tbl.ColumnFormat = colFormats;                               
                               this.modelOptions.options{7,1}.tbl.TooltipString = tooltips;                               
                               this.modelOptions.options{7,1}.tbl.Tag = 'Derived Forcing Transform - Model Settings';                                                              

                               if isempty(this.derivedForcingTranforms.tbl.Data{irow ,5})
                                    this.modelOptions.options{7,1}.tbl.Data = modelSettings;
                               else
                                   try                                       
                                       data = eval(this.derivedForcingTranforms.tbl.Data{irow,5});
                                       if strcmpi(colNames(1),'Select')
                                           data = [ mat2cell(false(size(data,1),1),ones(1,size(data,1))),  data];
                                       end

                                       this.modelOptions.options{7, 1}.tbl.Data = data;
                                   catch
                                       h = warndlg('The function options string appears to have a sytax error. It should be an Nx4 cell array.','Input error');                                       
                                       setIcon(this, h);
                                   end
                               end

                               % Assign context menu if the first column is
                               % named 'Select' and is a tick box.
                               if strcmp(colNames{1},'Select') && strcmp(colFormats{1},'logical')
                                    contextMenu = uicontextmenu(objOuterTabPanel,'Visible','on');
                                    uimenu(contextMenu,'Label','Copy selected rows','Callback',@this.rowAddDelete);
                                    uimenu(contextMenu,'Label','Paste rows','Callback',@this.rowAddDelete,'Separator','on');
                                    uimenu(contextMenu,'Label','Insert row above selection','Callback',@this.rowAddDelete);
                                    uimenu(contextMenu,'Label','Insert row below selection','Callback',@this.rowAddDelete);            
                                    uimenu(contextMenu,'Label','Delete selected rows','Callback',@this.rowAddDelete);            
                                    set(this.modelOptions.options{7, 1}.tbl,'UIContextMenu',contextMenu);  
                                    set(this.modelOptions.options{7, 1}.tbl.UIContextMenu,'UserData', 'this.modelOptions.options{2, 1}.tbl');
                               else
                                   set(this.modelOptions.options{7, 1}.tbl,'UIContextMenu',[]);
                               end                               

                               % Display table
                               setOptionsCardIndex(this, this.modelOptions.options{7,1}.tbl.Tag);
                           end
                        otherwise
                            setOptionsCardIndex(this, '');
                    end

                case 'Derived Weighting Functions'

                    % Add a row if the table is empty
                    if size(get(hObject,'Data'),1)==0
                        this.derivedWeightingFunctions.tbl.Data = cell(1,size(this.derivedWeightingFunctions.tbl.Data,2));
                        return;
                    end                    
                    
                    
                    switch eventdata.Source.ColumnName{icol}
                        case 'Weighting Function'   
                            % Get description of the function.
                            functionName = this.derivedWeightingFunctions.tbl.Data{this.currentSelection.row, 3};
                            if isempty(functionName)
                                return;
                            end
                            modelDescription = eval([functionName,'.modelDescription']);
                            set(this.modelOptions.options{10,1}.lbl,'HorizontalAlignment','left');
                            this.modelOptions.options{10,1}.lbl.String = ['Derived Weighting Functions - Function description','',modelDescription];
                            setOptionsCardIndex(this, 'Model options - description');
                        case 'Source Component'
                            derivedWeightingFunctionsListed = this.weightingFunctions.tbl.Data(:,2);
                            this.derivedWeightingFunctions.tbl.ColumnFormat{4} = derivedWeightingFunctionsListed';
                            setOptionsCardIndex(this, '');
                        case 'Input Data'
                            
                           % Get the list of input forcing data.
                           lstOptions = reshape(this.forcingData.colnames(4:end),[length(this.forcingData.colnames(4:end)),1]);

                           % Add source name
                           lstOptions = strcat('Input Data :',{' '}, lstOptions);

                           % Loop through each forcing function and add
                           % the possible outputs.
                           for i=1: size(this.forcingTranforms.tbl.Data,1)
                               if isempty(this.forcingTranforms.tbl.Data{i,2})
                                   continue
                               end

                               % Get output options.
                               outputOptions = feval(strcat(this.forcingTranforms.tbl.Data{i,2},'.outputForcingdata_options'),this.boreID, this.forcingData.data,  this.forcingData.colnames, this.siteData);

                               % Transpose if required
                               if size(outputOptions,1)==1 && size(outputOptions,2)>1
                                   outputOptions = outputOptions';
                               end
                               
                               % Add output options from the function
                               % to the list of available options
                               lstOptions = [lstOptions; strcat(this.forcingTranforms.tbl.Data{i,2},{' : '}, outputOptions)]; %#ok<AGROW> 
                           end


                           % Loop through each derived forcing function and add
                           % the possible outputs.
                           for i=1: size(this.derivedForcingTranforms.tbl.Data,1)
                               if isempty(this.derivedForcingTranforms.tbl.Data{i,2})
                                   continue
                               end

                               % Get output options.
                               outputOptions = feval(strcat(this.derivedForcingTranforms.tbl.Data{i,2},'.outputForcingdata_options'),this.boreID, this.forcingData.data,  this.forcingData.colnames, this.siteData);

                               % Transpose if required
                               if size(outputOptions,1)==1 && size(outputOptions,2)>1
                                   outputOptions = outputOptions';
                               end                               
                               
                               % Add output options from the function
                               % to the list of available options
                               lstOptions = [lstOptions; strcat(this.derivedForcingTranforms.tbl.Data{i,2},{' : '}, outputOptions)]; %#ok<AGROW> 
                           end                                                      
                           
                           % Assign the list of options to the list box                               
                           this.modelOptions.options{8,1}.lst.String = lstOptions;
                           
                           % Allow multipple-selection.
                           this.modelOptions.options{8,1}.lst.Min = 1;
                           this.modelOptions.options{8,1}.lst.Max = length(lstOptions);

                           % Highlight the previosuly selected option. If
                           % it looks like a string expression for a
                           % cell, evaluate it.
                           userSelections = this.derivedWeightingFunctions.tbl.Data{this.currentSelection.row, 5};
                           if ~isempty(userSelections) && strcmp(userSelections(1) ,'{') && strcmp(userSelections(end) ,'}')
                                userSelections = eval(this.derivedWeightingFunctions.tbl.Data{this.currentSelection.row, 5});
                           end
                           
                           rowInd= [];
                           if ~iscell(userSelections)
                               userSelections_tmp{1} =userSelections;
                               userSelections = userSelections_tmp;
                               clear userSelections_tmp
                           end
                           for i=1:size(userSelections,1)
                                ind = find(cellfun( @(x) strcmp(x, userSelections{i}), lstOptions ));
                                rowInd = [rowInd; ind]; %#ok<AGROW> 
                           end
                           this.modelOptions.options{8,1}.lst.Value = rowInd;                           
                           
                           % Show list box 
                           setOptionsCardIndex(this, 'Derived Weighting Functions - Input Data');
                           
                        case 'Options'
                            % Check that the weigthing function and forcing
                            % data have been defined
                            if any(isempty(this.derivedWeightingFunctions.tbl.Data(this.currentSelection.row,2:5)))
                                h = warndlg('The component name, derived weighting function, source function and input data must be specified before setting the options.','Input error');
                                setIcon(this, h);
                                return;
                            end
                            
                            % Get the input forcing data options.
                            inputDataNames = this.derivedWeightingFunctions.tbl.Data{this.currentSelection.row, 5};
                            
                            % Convert input data to a cell array if it is a
                            % list of multiple inputs.
                            try
                                inputDataNames = eval(inputDataNames)';
                            catch
                                % do nothing
                            end
                            
                           % Remove source name for input data.     
                           if ischar(inputDataNames)
                               inputDataNames_tmp{1}=inputDataNames;
                               inputDataNames = inputDataNames_tmp;
                               clear inputDataNames_tmp
                           end
                           for j=1: size(inputDataNames,1)
                               if ~isempty(strfind(inputDataNames{j}, 'Input Data : '))
                                   ind = regexp(inputDataNames{j}, 'Input Data : ');
                               else
                                   ind = regexp(inputDataNames{j}, ' : ');  
                               end                                                   
                               inputDataNames{j} =  inputDataNames{j}(ind+3:end);
                           end                            
                            
                            % Get the list of input forcing data.
                            funName = this.derivedWeightingFunctions.tbl.Data{this.currentSelection.row, 3};

                           % Get the weighting function options.
                           [modelSettings, colNames, colFormats, colEdits, tooltip] = feval(strcat(funName,'.modelOptions'), ...
                           this.boreID, inputDataNames, this.siteData);

                           % If the function has any options the
                           % display the options else display a message
                           % in box stating no options are available.
                           if isempty(colNames)                          
                                set(this.modelOptions.options{10,1}.lbl,'HorizontalAlignment','center');
                                this.modelOptions.options{10,1}.lbl.String = {'Derived Weighting Functions - Options','',['(No options are available for the following weighting function: ',funName,')']};                                    
                                setOptionsCardIndex(this, 'Model options - description');
                           else
                               %this.modelOptions.options{9,1}.lbl.String = '4. Derived Weighting Functions - Options';

                               % Assign model properties and data
                               this.modelOptions.options{9,1}.tbl.ColumnName = colNames;
                               this.modelOptions.options{9,1}.tbl.ColumnEditable = colEdits;
                               this.modelOptions.options{9,1}.tbl.ColumnFormat = colFormats;                               
                               this.modelOptions.options{9,1}.tbl.TooltipString = tooltip;
                               % Input the existing data or else the
                               % default settings.
                               if isempty(this.derivedWeightingFunctions.tbl.Data{this.currentSelection.row ,6})
                                   if isempty(modelSettings)
                                       this.modelOptions.options{9,1}.tbl.Data = cell(1,length(colNames));
                                   else
                                       this.modelOptions.options{9,1}.tbl.Data = modelSettings;
                                   end
                               else
                                   try
                                       data = eval(this.derivedWeightingFunctions.tbl.Data{this.currentSelection.row ,6});
                                       if strcmpi(colNames(1),'Select')
                                           data = [ mat2cell(false(size(data,1),1),ones(1,size(data,1))) , data];
                                       end

                                       this.modelOptions.options{9, 1}.tbl.Data = data;
                                   catch
                                       h = warndlg('The function options string appears to have a sytax error.','Input error');    
                                       setIcon(this, h);
                                   end
                               end                                 
                               % Assign context menu if the first column is
                               % named 'Select' and is a tick box.
                               if strcmp(colNames{1},'Select') && strcmp(colFormats{1},'logical')
                                    contextMenu = uicontextmenu(objOuterTabPanel,'Visible','on');
                                    uimenu(contextMenu,'Label','Copy selected rows','Callback',@this.rowAddDelete);
                                    uimenu(contextMenu,'Label','Paste rows','Callback',@this.rowAddDelete,'Separator','on');
                                    uimenu(contextMenu,'Label','Insert row above selection','Callback',@this.rowAddDelete);
                                    uimenu(contextMenu,'Label','Insert row below selection','Callback',@this.rowAddDelete);            
                                    uimenu(contextMenu,'Label','Delete selected rows','Callback',@this.rowAddDelete);            
                                    set(this.modelOptions.options{9, 1}.tbl,'UIContextMenu',contextMenu);  
                                    set(this.modelOptions.options{9, 1}.tbl.UIContextMenu,'UserData', 'this.modelOptions.options{9, 1}.tbl');
                               else
                                   set(this.modelOptions.options{9, 1}.tbl,'UIContextMenu',[]);
                               end
                               
                               % Show table
                               setOptionsCardIndex(this, 'Derived Weighting Functions - Model Settings');
                           end
                        otherwise
                            setOptionsCardIndex(this, '');
                    end   
            end            
        end
        
        function setOptionsCardIndex(this, optionTag)
            if strcmp(optionTag,'')
                this.modelOptions.options{10,1}.lbl.String = '';
                optionTag = 'Model options - description';
            end
            ind = find(strcmp(get(this.modelOptions.cards.Contents,'Tag'),optionTag));
               
            this.modelOptions.cards.SelectedChild = ind;
        end

        function optionsSelection(this, hObject, eventdata)
            try
                data=get(hObject,'Data'); %#ok<NASGU> % get the data cell array of the table
            catch
                data=[]; %#ok<NASGU> 
            end

            % Get class name (for calling the abstract)
            className = metaclass(this);
            className = className.Name;
                        
            % Undertake table/list specific operations.
            switch eventdata.Source.Tag
               
                case 'Forcing Transform - Input Data'                        
                    colnames = hObject.ColumnName; %#ok<NASGU> 
                    this.forcingTranforms.tbl.Data{this.currentSelection.row ,3} = eval([className,'.cell2string(data, colnames)']);

                case 'Forcing Transform - Model Settings'
                    colnames = hObject.ColumnName; %#ok<NASGU> 
                    this.forcingTranforms.tbl.Data{this.currentSelection.row ,4} = eval([className,'.cell2string(data, colnames)']);

                case 'Weighting Functions - Input Data'       

                    % Get selected input option
                    listSelection = get(hObject,'Value');
 
                    % Get cell array of selected strings.
                    data = hObject.String(listSelection); %#ok<NASGU> 
                    
                    % Convert to string.
                    colnames = 'NA';                    %#ok<NASGU> 
                    this.weightingFunctions.tbl.Data{this.currentSelection.row ,4} = eval([className,'.cell2string(data, colnames)']);

                case {'Weighting Functions - Options Tab 1 table','Weighting Functions - Options Tab 2 table', ...
                     'Weighting Functions - Options Tab 3 table','Weighting Functions - Options Tab 4 table', ...
                     'Weighting Functions - Options Tab 5 table'}
                 
                    optionsString = '{';
                    for i=1:length(this.modelOptions.options{4, 1}.tabs.TabEnables)
                        if strcmp(this.modelOptions.options{4, 1}.tabs.TabEnables{i},'on')
                            optionsTable = findobj(this.modelOptions.options{4,1}.tabs,'Tag',['Weighting Functions - Options Tab ',num2str(i),' table']);
                            data = get(optionsTable,'Data');
                            if any(any(cellfun(@(x) ~isempty(x), data)))
                                colnames = get(optionsTable,'ColumnName');                                %#ok<NASGU> 
                                optionsString  = [optionsString , eval([className,'.cell2string(data, colnames)']),', ']; %#ok<AGROW> 
                            else
                                optionsString  = [optionsString , '{}, ']; %#ok<AGROW> 
                            end                            
                        end                        
                    end
                    if ~isempty(optionsString)
                       optionsString = optionsString(1:end-2); 
                    end
                    optionsString  = [optionsString , '} '];
                    this.weightingFunctions.tbl.Data{this.currentSelection.row ,5} = optionsString;

                case 'Derived Forcing Functions - Source Function'                      
                    % Get selected input option
                    listSelection = get(hObject,'Value');
 
                    % Get cell array of selected strings.
                    data = hObject.String(listSelection);

                    % Assign to the table
                    this.derivedForcingTranforms.tbl.Data{this.currentSelection.row ,3} = data{1};
                    
                    
                case 'Derived Forcing Functions - Input Data'                      
                    
                    colnames = hObject.ColumnName; %#ok<NASGU> 
                    this.derivedForcingTranforms.tbl.Data{this.currentSelection.row ,4} = eval([className,'.cell2string(data, colnames)']);
                    
                case 'Derived Forcing Transform - Model Settings'
                    
                    colnames = hObject.ColumnName; %#ok<NASGU> 
                    this.derivedForcingTranforms.tbl.Data{this.currentSelection.row ,5} = eval([className,'.cell2string(data, colnames)']);
                    
                    
                case 'Derived Weighting Functions - Input Data'      
                    % Get selected input option
                    listSelection = get(hObject,'Value');
 
                    % Get cell array of selected strings.
                    data = hObject.String(listSelection); %#ok<NASGU> 
                    
                    % Convert to string.
                    colnames = 'NA';                    %#ok<NASGU> 
                    this.derivedWeightingFunctions.tbl.Data{this.currentSelection.row ,5} = eval([className,'.cell2string(data, colnames)']);

                case 'Derived Weighting Functions - Model Settings'       
                    colnames = hObject.ColumnName; %#ok<NASGU> 
                    this.derivedWeightingFunctions.tbl.Data{this.currentSelection.row ,6} = eval([className,'.cell2string(data, colnames)']);
                    
                otherwise
                    setOptionsCardIndex(this, '');
            end
        end
        
    %end
    
    %methods(Access=private)  
        
        function tableEdit(this, hObject, eventdata)
            icol=[];
            irow=[];
            if isprop(eventdata, 'Indices') || isfield(eventdata, 'Indices')
                if ~isempty(eventdata.Indices)
                    icol=eventdata.Indices(:,2);
                    irow=eventdata.Indices(:,1);  
                end
            end
            if size(get(hObject,'Data'),1)==0
                return
            end
            
            % Return if the select column is the corrent column
            if icol==1
                return;
            end
           
            % Undertake table/list specific operations.
            switch eventdata.Source.Tag
                case 'Forcing Transform'
                   % Check the function name is unique
                   nrows  = size(this.forcingTranforms.tbl.Data,1);                   
                   otherFunctionNames_ind = [1:irow-1, irow+1:nrows];
                   if nrows>1          
                       otherFunctionNames = this.forcingTranforms.tbl.Data(otherFunctionNames_ind ,3);
                       if any(cellfun(@(x) strcmp(eventdata.NewData,x), otherFunctionNames))                           
                           this.forcingTranforms.tbl.Data{irow ,2} = eventdata.PreviousData;
                           h = warndlg('Each function name must be unique within the model - i.e you can use it only once.','Input error');
                           setIcon(this, h);
                           return;
                       end
                   end
                   
                   % Reset other fields of the model name changes
                   if icol==2 && ~isempty(eventdata.PreviousData) && ~strcmp(eventdata.PreviousData, eventdata.NewData)
                        this.forcingTranforms.tbl.Data{irow ,3} = '';
                        this.forcingTranforms.tbl.Data{irow,4} = '';
                        %this.modelOptions.grid.Widths = zeros(size(this.modelOptions.grid.Widths));
                        setOptionsCardIndex(this, '');
                   end
                   
                case 'Weighting Functions'
                   
                   % Check the function name is unique
                   nrows  = size(this.weightingFunctions.tbl.Data,1);                   
                   otherFunctionNames_ind = [1:irow-1, irow+1:nrows];
                   if nrows>1          
                       otherFunctionNames = this.weightingFunctions.tbl.Data(otherFunctionNames_ind ,2);
                       if any(cellfun(@(x) strcmp(eventdata.NewData,x), otherFunctionNames))                           
                           this.weightingFunctions.tbl.Data{irow ,2} = eventdata.PreviousData;
                           h = warndlg('Each component name must be unique within the model.','Input error');
                           setIcon(this, h);
                           return;
                       end
                   end  
                   
                   % Check that the compent name is a valid fiewd name
                   try
                       componentName = eventdata.NewData;               
                       a.(componentName) = 1; %#ok<STRNU> 
                       clear a
                   catch
                       this.weightingFunctions.tbl.Data{irow ,2} = eventdata.PreviousData;
                       h = warndlg('The component name is invalid. It must contain only letters, numbers and under-scores and cannot start with a number.','Input error');
                       setIcon(this, h);
                       return;
                   end
                    
                   % Reset other fields of the model name changes
                   if icol==3 && ~isempty(eventdata.PreviousData) && ~strcmp(eventdata.PreviousData, eventdata.NewData)
                        this.weightingFunctions.tbl.Data{irow ,4} = '';
                        this.weightingFunctions.tbl.Data{irow ,5} = '';
                        %this.modelOptions.grid.Widths = zeros(size(this.modelOptions.grid.Widths)); 
                        setOptionsCardIndex(this, '');
                   end                   
                case 'Derived Forcing Transform'
                    
                   % Check the function name is unique
                   nrows  = size(this.derivedForcingTranforms.tbl.Data,1);                   
                   otherFunctionNames_ind = [1:irow-1, irow+1:nrows];
                   if nrows>1          
                       otherFunctionNames = this.derivedForcingTranforms.tbl.Data(otherFunctionNames_ind ,2);
                       if any(cellfun(@(x) strcmp(eventdata.NewData,x), otherFunctionNames))                           
                           this.derivedForcingTranforms.tbl.Data{irow ,2} = eventdata.PreviousData;
                           h = warndlg('Each function name must be unique within the model - i.e you can use it only once.','Input error');
                           setIcon(this, h);
                           return;
                       end
                   end
                   
                   % Reset other fields of the model name changes
                   if icol==2 && ~isempty(eventdata.PreviousData) && ~strcmp(eventdata.PreviousData, eventdata.NewData)
                        this.derivedForcingTranforms.tbl.Data{irow ,3} = '';
                        this.derivedForcingTranforms.tbl.Data{irow ,4} = '';
                        this.derivedForcingTranforms.tbl.Data{irow ,5} = '';
                        %this.modelOptions.grid.Widths = zeros(size(this.modelOptions.grid.Widths));  
                        setOptionsCardIndex(this, '');
                   end                   
                case 'Derived Weighting Functions'
                    
                   % Check the function name is unique
                   nrows  = size(this.derivedWeightingFunctions.tbl.Data,1);                   
                   otherFunctionNames_ind = [1:irow-1, irow+1:nrows];
                   if nrows>1          
                       otherFunctionNames = this.derivedWeightingFunctions.tbl.Data(otherFunctionNames_ind ,3);
                       if any(cellfun(@(x) strcmp(eventdata.NewData,x), otherFunctionNames))                           
                           this.derivedWeightingFunctions.tbl.Data{irow ,2} = eventdata.PreviousData;
                           h = warndlg('Each component name must be unique within the model.','Input error');
                           setIcon(this, h);
                           return;
                       end
                   end      
                   
                   % Check that the compent name is a valid fiewd name
                   try
                       componentName = eventdata.NewData;               
                       a.(componentName) = 1; %#ok<STRNU> 
                       clear a
                   catch
                       this.derivedWeightingFunctions.tbl.Data{irow ,2} = eventdata.PreviousData;
                       h = warndlg('The component name is invalid. It must contain only letters, numbers and under-scores and cannot start with a number.','Input error');
                       setIcon(this, h);
                       return;
                   end                   
                   
                   % Reset other fields of the model name changes
                   if icol==3 && ~isempty(eventdata.PreviousData) && ~strcmp(eventdata.PreviousData, eventdata.NewData)
                        this.derivedWeightingFunctions.tbl.Data{irow ,4} = '';
                        this.derivedWeightingFunctions.tbl.Data{irow ,5} = '';
                        this.derivedWeightingFunctions.tbl.Data{irow ,6} = '';
                        %this.modelOptions.grid.Widths = zeros(size(this.modelOptions.grid.Widths));     
                        setOptionsCardIndex(this, '');
                   end                      
                    
            end
        end
        
        function rowAddDelete(this, hObject, eventdata)

           
            % Get the table object from UserData
            tableObj = eval(eventdata.Source.Parent.UserData);
            
            % Get selected rows
            selectedRow = false(size(tableObj.Data(:,1),1),1);
            for i=1:size(tableObj.Data(:,1),1)
                if tableObj.Data{i,1}
                    selectedRow(i) = true;
                end
            end
      
            % Check if any rows are selected. Note, if not then
            % rows will be added (for all but the calibration
            % table).
            anySelected = any(selectedRow);
            indSelected = find(selectedRow)';
            
            if (strcmp(hObject.Label,'Insert row above selection') || strcmp(hObject.Label,'Insert row below selection')) ...
            && sum(selectedRow) == 0
                if ~isempty(selectedRow)
                    selectedRow(end)=true;
                end
            elseif ~strcmp(hObject.Label,'Paste rows') && size(tableObj.Data(:,1),1)>0 &&  sum(selectedRow) == 0                             
                h = warndlg('No rows are selected for the requested operation.', 'Selection error');
                setIcon(this, h);
                return;
            elseif size(tableObj.Data(:,1),1)==0 ...
            &&  (strcmp(hObject.Label, 'Copy selected rows') || strcmp(hObject.Label, 'Delete selected rows'))                
                return;
            end            
            
            % Do the selected action            
            switch hObject.Label
                case 'Copy selected rows'
                    this.copiedData.tableName = tableObj.Tag;
                    this.copiedData.data = tableObj.Data(selectedRow,:);
                    
                case 'Paste rows'    
                    % Check that name of the table is same as that from the
                    % copied data. If so copy the data.
                    if strcmp(this.copiedData.tableName, tableObj.Tag)
                        if anySelected
                            for i=indSelected
                                tableObj.Data{i,:} = this.copiedData.data(1,:);
                            end
                       else
                          for i=1: size(this.copiedData.data,1)
                            tableObj.Data = [tableObj.Data; this.copiedData.data(i,:)];
                          end
 
                        end                        
                    
                        % Update row numbers.
                        nrows = size(tableObj.Data,1);
                        tableObj.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));
                    else
                        h = warndlg('The copied row data was sourced froma different table.','Copy/paste error');
                        setIcon(this, h);
                        return;
                    end    
                    
                case 'Insert row above selection'
                    if size(tableObj.Data,1)==0
                        tableObj.Data = cell(1,size(tableObj.Data,2));
                    else
                        selectedRow= find(selectedRow);
                        for i=1:length(selectedRow)

                            ind = max(0,selectedRow(i) + i-1);

                            tableObj.Data = [tableObj.Data(1:ind-1,:); ...
                                        cell(1,size(tableObj.Data,2)); ...
                                        tableObj.Data(ind:end,:)];
                            tableObj.Data{ind,1} = false;                                                              
                        end
                    end
                    % Update row numbers.
                    nrows = size(tableObj.Data,1);
                    tableObj.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));
                        
                case 'Insert row below selection'    
                    if size(tableObj.Data,1)==0
                        tableObj.Data = cell(1,size(tableObj.Data,2));
                    else
                        selectedRow= find(selectedRow);
                        for i=1:length(selectedRow)

                            ind = selectedRow(i) + i;

                            tableObj.Data = [tableObj.Data(1:ind-1,:); ...
                                        cell(1,size(tableObj.Data,2)); ...
                                        tableObj.Data(ind:end,:)];

                            tableObj.Data{ind,1} = false;                                                              
                        end
                    end
                    % Update row numbers.
                    nrows = size(tableObj.Data,1);
                    tableObj.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));

                case 'Delete selected rows'    
                    tableObj.Data = tableObj.Data(~selectedRow,:);
                    
                    % Update row numbers.
                    nrows = size(tableObj.Data,1);
                    tableObj.RowName = mat2cell(transpose(1:nrows),ones(1, nrows));
            end
        end
        
         function wizard(this, ~, eventdata)
             
            % Get the selelcted table, row and col.
            irow = this.currentSelection.row;
            icol = this.currentSelection.col;
            currentTable = this.currentSelection.table;
            
            % Get the name of the function within the table     
            switch currentTable
                case 'Forcing Transform'
                    className = this.forcingTranforms.tbl.Data{irow, 2};
                    
                    if icol==3
                        methodName = '.dataWizard';
                    elseif icol==4
                        methodName = '.optionsWizard';
                    end
                case  'Weighting Functions'
                    className = this.weightingFunctions.tbl.Data{irow, 3};
                    if icol==4
                        methodName = '.dataWizard';
                    elseif icol==5
                        methodName = '.optionsWizard';
                    end 
                otherwise
                    msgbox('This model componant does not have a data wizard.', 'No data wizard ...','help')     
                    return
            end
            
            
            % Call the wizard for the current table.
            try
               wizardResults= feval(strcat(className,methodName),this.boreID, this.forcingData.data,  this.forcingData.colnames, this.siteData);
               if isempty(wizardResults)
                   return
               end
            catch
               msgbox('This model componant does not have a data wizard.', 'No data wizard ...','help')
               return
            end

           % Input the wizard data into the current table.
           switch currentTable
                case 'Forcing Transform'
                    switch methodName
                        case '.dataWizard'
                           this.modelOptions.options{1, 1}.tbl.Data = cell(0,2);
                           this.modelOptions.options{1, 1}.tbl.Data = cell(size(wizardResults,1),2);
                           this.modelOptions.options{1, 1}.tbl.RowName=cell(1,size(wizardResults,1)); 
                           for i=1:size(wizardResults,1)                                   
                                this.modelOptions.options{1, 1}.tbl.Data{i,1}= wizardResults{i,1};
                                this.modelOptions.options{1, 1}.tbl.Data{i,2}= wizardResults{i,2};
                           end     
                           this.modelOptions.options{1, 1}.tbl.RowName = 1:size(this.modelOptions.options{1, 1}.tbl.Data,1);
                           
                           % In case the user does not input/chnage
                           % the data, then apply it to the forcing
                           % data field.
                           className= 'model_TFN_gui';
                           colnames = {'Required Model Data';'Input Forcing Data'}; %#ok<NASGU> 
                           data=this.modelOptions.options{1, 1}.tbl.Data; %#ok<NASGU> 
                           this.forcingTranforms.tbl.Data{irow ,3} = eval([className,'.cell2string(data, colnames)']);

                        case '.optionsWizard'
                            
                    end
               case 'Weighting Functions'
                    switch methodName
                        case '.dataWizard'
                            % Select the input data as returned by the
                            % the weighting function wizard. Only input
                            % data is selected (not data from transform
                            % functions). The selection add to existing
                            % selections and is pushed back to the
                            % weighting table.
                            inputOptions = this.modelOptions.options{3,1}.lst.String;
                            selectItem =[];
                            wizardAppendStr = {};
                            for i=1:size(wizardResults,1)
                                wizardAppendStr{i,1} = 'Input Data : '; %#ok<AGROW> 
                            end
                            wizardResults = strcat(wizardAppendStr,wizardResults{:,1});
                            for i=1:size(wizardResults,1) 
                                ind = find(strcmp(inputOptions, wizardResults{i}));
                                selectItem = [selectItem, ind]; %#ok<AGROW> 
                            end
                            
                            % Update weighting table
                            this.modelOptions.options{3,1}.lst.Value = unique([this.modelOptions.options{3,1}.lst.Value ,selectItem]);
                            eventdata.Source.Tag='Weighting Functions - Input Data';
                            optionsSelection(this, this.modelOptions.options{3,1}.lst, eventdata);

                        case '.optionsWizard'
                            
                    end

           end

           drawnow();   
         end
         
         function push2component(this, ~, ~)
             
            dlg_title = 'Push required model data to compnant input data ...';
            prompt = 'Select the componant:';      
            ListString = this.weightingFunctions.tbl.Data(:,2);
           
            if length(ListString)<1
                errordlg('The weighting function component names must first be defined.')
                return
            end
            
            [ind, OK]= listdlg('Name',dlg_title, 'PromptString',prompt, 'ListString',ListString, 'SelectionMode','single');
            if OK==1
               
                
                % Get the selelcted table, row and col.
                irow = this.currentSelection.row;
                currentTable = this.currentSelection.table;
                
                % Get the name of the function within the table
                switch currentTable
                    case 'Forcing Transform'
                        className = this.forcingTranforms.tbl.Data{irow, 2};                                               
                    otherwise
                        msgbox('This model componant does not have a data wizard.', 'No data wizard ...','help')
                        return
                end

                % Build filter for rows where the obs data is not "(none)"
                filt = ~strcmp(this.modelOptions.options{1, 1}.tbl.Data(:,2),'(none)');
                
                % get input data names                
                data = this.modelOptions.options{1, 1}.tbl.Data(filt,1);
                
                LHS = [className,'...'];
                data = strcat( LHS, data);
                data = strrep(data,'...',' : '); %#ok<NASGU> 
                               
                % Get class name (for calling the abstract)
                className = metaclass(this);
                className = className.Name;
                
                % Convert to string.
                colnames = 'NA';                    %#ok<NASGU> 
                this.weightingFunctions.tbl.Data{ind,4} = eval([className,'.cell2string(data, colnames)']);
                    
                
                
            end
         end

         function setIcon(this, h)
            if isa(h, 'matlab.ui.Figure') && isa(this.Figure_icon,'javax.swing.ImageIcon')
                try
                    warning ('off','MATLAB:ui:javaframe:PropertyToBeRemoved');
                    javaFrame    = get(h,'JavaFrame'); %#ok<JAVFM> 
                    javaFrame.setFigureIcon(this.Figure_icon);
                catch
                    % do nothing
                end
            end
        end
    end
    
    methods(Static, Access=private)  
        function stringCell = cell2string(cellData, colnames) 
                % Ignore first column of it is for row selection
                if isempty(colnames)
                    startCol = 1; 
                elseif strcmpi(colnames(1),'Select')
                    startCol = 2;                    
                else
                    startCol = 1;
                end
            
                % Check the format of each column.
                % All rows of a column must be numeric to be
                % deemed numeric.
                isNumericColumn = all(cellfun(@(x) isnumeric(x) || (~isempty(str2double(x)) && ~isnan(str2double(x))), cellData),1);
                
                % Loop through each column, then row.
                stringCell= '{';
                for i=1:size(cellData,1)
                    for j=startCol:size(cellData,2)
                        
                        if isNumericColumn(j)
                            if ischar(cellData{i,j})
                                stringCell = strcat(stringCell, sprintf(' %f,',str2double(cellData{i,j}) ));
                            else
                                stringCell = strcat(stringCell, sprintf(' %f,',cellData{i,j} ));
                            end
                        else
                            stringCell = strcat(stringCell, sprintf(' ''%s'',',cellData{i,j} ));
                        end
                    end
                    % remove end ,
                    stringCell = stringCell(1:end-1);
                    % add ;
                    stringCell = strcat(stringCell, ' ; ');
                end
                stringCell = strcat(stringCell,'}');            
        end        
    end
    
end

