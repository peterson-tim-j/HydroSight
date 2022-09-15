function res = uical(sDate, lang, minDate, maxDate, figure_icon, figure_name)
% UICAL - Calendar date picker
%
%   Version : 1.1
%   Created : 10/08/2007
%   Modified: 14/08/2007
%   Author  : Thomas Montagnon (The MathWorks France)
%
%   RES = UICAL() displays the calendar in English with the today's date
%   selected. RES is the serial date number corresponding to the date the user
%   selected.
%
%   RES = UICAL(SDATE) displays the calendar in English with SDATE date
%   selected. SDATE can be either a serial date number or a 3-elements vector
%   containing year, month and day in this order.
%
%   RES = UICAL(SDATE,LANG) displays the calendar in the language specified by
%   LANG with SDATE date selected.
%   Default available languages are English and French but you can easily add
%   your own by editing the SET_LANGUAGES nested function at the bottom of this
%   file.
%
%   
%   Customization Tips:
%   You can customize the colors of the calendar by editing the "Colors" section
%   at the begining of the main function. See comments there for more details.
%
%
%   Examples:
%
%     myDate = uical()
%
%     myDate = uical(now+7)
%
%     myDate = uical([1980 7 24],'fr')
%
%   See also CALENDAR.
%


% ------------------------------------------------------------------------------
% --- INITIALIZATIONS                                                        ---
% ------------------------------------------------------------------------------

% Colors
figColor     = get(0,'DefaultUicontrolBackgroundColor'); % Figure background color
colorNoDay   = [0.95  0.95  0.95]; % Background color of the cells that are not days of the selected month
colorDayB    = [1.00  1.00  1.00]; % Background color of the cells that are day of the selected month
colorDayF    = [0.00  0.00  0.00]; % Foreground color of the cells that are day of the selected month
colorDayNB   = [0.30  0.30  0.30]; % Background color of the column headers
colorDayNF   = [1.00  1.00  1.00]; % Foreground color of the column headers
colorSelDayB = [0.70  0.00  0.00]; % Background color of the selected day
colorSelDayF = [1.00  1.00  1.00]; % Foreground color of the selected day

% Default input arguments
sDateDef = now;
langDef  = 'en';

% Use default values if input does not exist
switch nargin
  case 0
    sDate = sDateDef;
    lang  = langDef;
  case 1
    lang = langDef;
end

% Check input argument validity
if ~isnumeric(sDate)
  error('MYCAL:DateFormat:WrongClass','First input must be numeric');
end
switch numel(sDate)
  case 1
    sDate = datevec(sDate);
  case 3
    if sDate(1) < 0
      error('MYCAL:DateFormat:WrongYearVal','First element of the first input must be a valid year number');
    end
    if (sDate(2) > 12) && (sDate(2) < 1)
      error('MYCAL:DateFormat:WrongMonthVal','Second element of the first input must be a valid month number');
    end
    if (sDate(3) > 31) && (sDate(3) < 1)
      error('MYCAL:DateFormat:WrongDayVal','Third element of the first input must be a valid day number');
    end
  otherwise
    error('MYCAL:DateFormat:WrongVal','First input must be a numeric scalar or a 3-elements vector');
end
  

% Language dependent strings. 
% Tim Peterson: edits to return daysN (but emerged in matlab ~2021 
[daysN, monthsN] = set_language(lang);

% Initializes output
res = sDate(1:3);

% Dimensions
dayH   = 24;
dayW   = 35;
ctrlH  = 20;
figH   = 7 * (dayH - 1) + ctrlH;
figW   = 7 * (dayW-1);
ctrlYW = 60;
ctrlMW = 80;
ctrlCW = figW - ctrlYW - ctrlMW;

daysNy = figH - ctrlH - dayH + 1;


% ------------------------------------------------------------------------------
% --- UICONTROL CREATION                                                     ---
% ------------------------------------------------------------------------------


% Create figure
handles.FgCal = figure( ...
  'Visible', 'off', ...
  'Tag', 'FgCal', ...
  'Name', '', ...
  'Units', 'pixels', ...
  'Position', [50 50 figW figH], ...
  'Toolbar', 'none', ...
  'MenuBar', 'none', ...
  'NumberTitle', 'off', ...
  'Color', figColor, ...
  'CloseRequestFcn',@FgCal_CloseRequestFcn,...
  'WindowStyle','modal');

% Set hydrosight icon
if isa(figure_icon,'javax.swing.ImageIcon')
    try
        warning ('off','MATLAB:ui:javaframe:PropertyToBeRemoved');
        javaFrame    = get(handles.FgCal,'JavaFrame'); %#ok<JAVFM>
        javaFrame.setFigureIcon(figure_icon);
    catch
        % do nothing
    end
end 

% Move the GUI to the center of the screen
movegui(handles.FgCal,'center')

% remove reside button
set(handles.FgCal,'Resize','off');

% Columns Headers containing initials of the week days
for dayNidx=1:7
  
  daysNx = (dayNidx - 1) * (dayW - 1);
  
  handles.EdDayN(dayNidx) = uicontrol( ...
    'Parent', handles.FgCal, ...
    'Tag', 'EdDay', ...
    'Style', 'edit', ...
    'Units', 'pixels', ...
    'Position', [daysNx daysNy dayW dayH], ...
    'ForegroundColor', colorDayNF, ...
    'BackgroundColor', colorDayNB, ...
    'String', daysN{dayNidx}, ...
    'HorizontalAlignment', 'center', ...
    'Enable','inactive');
  
end

% Days UI controls
for dayIdx=1:42
  
  % X and Y Positions
  [i,j] = ind2sub([6,7],dayIdx);
  
  dayX = (j - 1) * (dayW - 1);
  dayY = (dayH - 1) * 6 - i * (dayH - 1);
  
  handles.EdDay(dayIdx) = uicontrol( ...
    'Parent', handles.FgCal, ...
    'Tag', 'EdDay', ...
    'Style', 'edit', ...
    'Units', 'pixels', ...
    'Position', [dayX dayY dayW dayH], ...
    'BackgroundColor', colorDayB, ...
    'ForegroundColor', colorDayF, ...
    'String', '', ...
    'HorizontalAlignment', 'center', ...
    'Enable','inactive');
  
end

% Listbox containing the list of months
handles.PuMonth = uicontrol( ...
  'Parent', handles.FgCal, ...
  'Tag', 'PuMonth', ...
  'Style', 'popupmenu', ...
  'Units', 'pixels', ...
  'Position', [ctrlYW-2 figH-ctrlH+1 ctrlMW+2 ctrlH], ...
  'BackgroundColor', [1 1 1], ...
  'String', monthsN, ...
  'Value', res(2), ...
  'Callback',@set_cal);

% Edit for drop-down yesr - Tim Peterson March 2015.
% ---------------------------    
% % Edit control which enables you to enter a year number
% handles.EdYear = uicontrol( ...
%   'Parent', handles.FgCal, ...
%   'Tag', 'EdYear', ...
%   'Style', 'edit', ...
%   'Units', 'pixels', ...
%   'Position', [0 figH-ctrlH ctrlYW-1 ctrlH+1], ...
%   'BackgroundColor', [1 1 1], ...
%   'String', res(1), ...
%   'Callback',@set_cal);

% Edit control which enables you to enter a year number
years = [year(minDate):year(maxDate)];
ind = find(years==res(1),1,'first');
res(1) = years(ind);
years_cell = regexp(sprintf('%i ',years),'(\d+)','match');

handles.EdYear = uicontrol( ...
  'Parent', handles.FgCal, ...
  'Tag', 'EdYear', ...
  'Style', 'popupmenu', ...
  'Units', 'pixels', ...
  'Position', [0 figH-ctrlH ctrlYW-1 ctrlH+1], ...
  'BackgroundColor', [1 1 1], ...
  'String',years_cell, ...
  'Value', ind, ...
  'Callback',@set_cal);
% ---------------------------    

% Selection button
handles.PbChoose = uicontrol( ...
  'Parent', handles.FgCal, ...
  'Tag', 'PbChoose', ...
  'Style', 'pushbutton', ...
  'Units', 'pixels', ...
  'Position', [ctrlYW+ctrlMW figH-ctrlH+1 ctrlCW ctrlH], ...
  'String', 'OK', ...
  'Callback','uiresume');

% Display calendar for the default date
set_cal();

% Make the calendar visible
set(handles.FgCal,'Visible','on')

% Wait for user action
uiwait(handles.FgCal);

% Convert date to serial date number
res = datenum(res);

% Close the calendar figure
delete(handles.FgCal);


% ------------------------------------------------------------------------------
% --- CALLBACKS                                                              ---
% ------------------------------------------------------------------------------


%-------------------------------------------------------------------------------
  function FgCal_CloseRequestFcn(varargin)
    % Callback executed when the user click on the close button of the figure.
    % This means he wants to cancel date selection so function returns the
    % intial date (the one used when we opened the calendar)
    
    % Set the output to the intial date value
    res = sDate(1:3);
    
    % End execution of the window
    uiresume;
    
  end


%-------------------------------------------------------------------------------
  function EdDay_ButtonDownFcn(varargin)
    % Callback executed when the user click on day.
    % Updates the RES variable containing the currently selected date and then
    % update the calendar.
    % Edit for drop-down yesr - Tim Peterson March 2015.
    % ---------------------------    
    %res(1) = str2double(get(handles.EdYear,'String'));
    listSelection = get(handles.EdYear,'value');
    year =  str2double(handles.EdYear.String(listSelection,:));
    res(1) = abs(round(year)); % ensure year is a positive integer
    % ---------------------------    
    res(2) = get(handles.PuMonth,'Value');
    res(3) = str2double(get(varargin{1},'String')); % Number of the selected day
    
    set_cal();
    
  end


%-------------------------------------------------------------------------------
  function set_cal(varargin)
    % Displays the calendar according to the selected date stored in RES

    % Get selected Year and Month
    % Edited by Tim Peterson for use of a list. Mar 2015.
    %-------------------------
    %year   = str2double(get(handles.EdYear,'String'));
    listSelection = get(handles.EdYear,'value');
    year =  str2double(handles.EdYear.String(listSelection,:));
    res(1) = abs(round(year)); % ensure year is a positive integer
    res(2) = get(handles.PuMonth,'value');
    
    % Check Year value (keep previous value if the new one is wrong)
    %if ~isnan(year)
    %  res(1) = abs(round(year)); % ensure year is a positive integer
    %end
    %set(handles.EdYear,'value',res(1))
    %-------------------------

    % Get the matrix of the calendar for selected month and year then convert it
    % into a cell array
    c = calendar(res(1),res(2));
    v = mat2cell(c,ones(1,6),ones(1,7));

    % Cell array of indices used to index the vector of handles
    i = mat2cell((1:42)',ones(1,42),1);

    % Set String property for all cells of the calendar
    cellfun(@(i,x) set(handles.EdDay(i),'string',x),i,v(:))

    % Change properties of the "non-day" cells of the calendar
    set(handles.EdDay(c==0), ...
      'ButtonDownFcn'  , '', ...
      'BackgroundColor', colorNoDay, ...
      'string'         , '')
    
    % Change the properties of the calendar's cells containing existing days
    set(handles.EdDay(c~=0), ...
      'ButtonDownFcn'  , @EdDay_ButtonDownFcn, ...
      'BackgroundColor', colorDayB, ...
      'ForegroundColor', colorDayF, ...
      'FontWeight'     ,'normal')

    % Highlight the selected day
    set(handles.EdDay(c==res(3)), ...
      'BackgroundColor', colorSelDayB, ...
      'ForegroundColor', colorSelDayF, ...
      'FontWeight'     ,'bold')
    
    % Update the name of the figure to reflect the selected day
    %set(handles.FgCal,'Name',sprintf('%u/%u/%u',fliplr(res)))

    % Set name
    set(handles.FgCal,'Name',figure_name);

    % Give focus to the "OK" button
    uicontrol(handles.PbChoose);
    
  end


%-------------------------------------------------------------------------------
  function [daysN, monthsN] = set_language(lang)
    % Sets language dependent strings used in the calendar
    % You can add languages by adding cases below.
    
    switch lang
      
      case 'en'
        
        daysN   = {'S','M','T','W','T','F','S'}; % First day is always Sunday
        monthsN = {'January','February','March','April','May','June',...
          'July','August','September','October','November','December'};
        
      case 'fr'
        
        daysN   = {'D','L','M','M','J','V','S'};
        monthsN = {'Janvier','F�vrier','Mars','Avril','Mai','Juin',...
          'Juillet','Ao�t','Septembre','Octobre','Novembre','D�cembre'};
      
      otherwise
        
        % If language is not recognized then use the English strings
        
        daysN   = {'S','M','T','W','T','F','S'};
        monthsN = {'January','February','March','April','May','June',...
          'July','August','September','October','November','December'};
        
    end
    
  end

end