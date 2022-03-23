function out = zoom(varargin)
%ZOOM   Zoom in and out on a 2-D plot.
%   ZOOM with no arguments toggles the zoom state.
%   ZOOM(FACTOR) zooms the current axis by FACTOR.
%       Note that this does not affect the zoom state.
%   ZOOM ON turns zoom on for the current figure.
%   ZOOM XON or ZOOM YON turns zoom on for the x or y axis only.
%   ZOOM OFF turns zoom off in the current figure.
%
%   ZOOM RESET resets the zoom out point to the current zoom.
%   ZOOM OUT returns the plot to its current zoom out point.
%   If ZOOM RESET has not been called this is the original
%   non-zoomed plot.  Otherwise it is the zoom out point
%   set by ZOOM RESET.
%
%   When zoom is on, click the left mouse button to zoom in on the
%   point under the mouse.  Click the right mouse button to zoom out.
%   Each time you click, the axes limits will be changed by a factor 
%   of 2 (in or out).  You can also click and drag to zoom into an area.
%   It is not possible to zoom out beyond the plots' current zoom out
%   point.  If ZOOM RESET has not been called the zoom out point is the
%   original non-zoomed plot.  If ZOOM RESET has been called the zoom out
%   point is the zoom point that existed when it was called.
%   Double clicking zooms out to the current zoom out point - 
%   the point at which zoom was first turned on for this figure 
%   (or to the point to which the zoom out point was set by ZOOM RESET).
%   Note that turning zoom on, then off does not reset the zoom out point.
%   This may be done explicitly with ZOOM RESET.
%   
%   ZOOM(FIG,OPTION) applies the zoom command to the figure specified
%   by FIG. OPTION can be any of the above arguments.
%
%   Use LINKAXES to link zooming across multiple axes.
%
%   See also PAN, LINKAXES.

% Copyright 1993-2004 The MathWorks, Inc.

% Internal use undocumented syntax (this may be removed in a future
% release)
% Additional syntax not already ded in zoom m-help
%
% ZOOM(FIG,'UIContextMenu',...)
%    Specify UICONTEXTMENU for use in zoom mode 
% ZOOM(FIG,'Constraint',...)
%    Specify constrain option:
%       'none'       - No constraint (default)
%       'horizontal' - Horizontal zoom only for 2-D plots
%       'vertical'   - Vertical zoom only for 2-D plots
% ZOOM(FIG,'Direction',...) 
%    Specify zoom direction 'in' or 'out'
% OUT = ZOOM(FIG,'IsOn') 
%    Returns true if zoom is on, otherwise returns false.
% OUT = ZOOM(FIG,'Constraint') 
%    Returns 'none','horizontal', or 'vertical'
% OUT = ZOOM(FIG,'Direction')
%    Returns 'in' or 'out'

% Undocumented syntax that will never get documented
% (but we have to keep it around for legacy reasons)
% OUT = ZOOM(FIG,'getmode') 'in'|'out'|'off' 
%
% Undocumented zoom object registration methods
% OUT = ZOOM(FIG,'getzoom')
%    Get zoom object
% ZOOM(FIG,'setzoom',...)
%    Set zoom object

%   Note: zoom uses the figure buttondown and buttonmotion functions
%
%   ZOOM XON zooms x-axis only
%   ZOOM YON zooms y-axis only

%   ZOOM v6 off Switches to new zoom implementation
%   ZOOM v6 on Switches to old zoom implementation

%   ZOOM FILL scales a plot such that it is as big as possible
%   within the axis position rectangle for any azimuth and elevation.

% Undocumented switch to v6 zoom implementation. This will be removed.
if nargin==2 && ...
   isstr(varargin{1}) && ...
   strcmp(varargin{1},'v6') && ...
   isstr(varargin{2})
      if strcmp(varargin{2},'on')
         localSetV6Zoom(true);   
      else
         localSetV6Zoom(false);
      end
      return;
end

% Bypass to v6 zoom
if localIsV6Zoom
    if nargout==0
         v6_zoom(varargin{:});
    else
         out = v6_zoom(varargin{:});
    end
    return;
end

% Parse input arguments
[target,action,action_data] = localParseArgs(varargin{:});

% If setting zoom object, ZOOM(H,HZOOM), then return early
if strcmp(action,'setzoom')
  localRegisterZoomObject(action_data);
  return;
end

% Return early if target is not an axes or figure
if isempty(target) || ...
   (~isa(target,'hg.axes') && ~isa(target,'hg.figure')) 
   return;
end
hFigure = ancestor(target,'hg.figure');

% Return early if setting zoom off and there's no app data
% this avoids making any objects or setting app data when
% it doesn't need to. For example, hgload calls zoom(fig,'off') 
appdata = localGetData(hFigure);
if strcmp(action,'off') && isempty(appdata.uistate)
   return;
end

% Get zoom object 
hZoom = localGetRegisteredZoomObject(hFigure);

% Update zoom target in case it changed
set(hZoom,'target',target);
   
% Get current axes
hCurrentAxes = get(hFigure,'CurrentAxes');

% Parse various zoom options
change_ui = [];
%========================================================
%  Part of modification for ADDAXIS commands
ystart = get(gca,'ylim');
%========================================================
switch lower(action)

    case 'on'
       set(hZoom,'Constraint','none');
       change_ui = 'on';
    
    case 'xon'
       set(hZoom,'Constraint','horizontal');
       change_ui = 'on';
    
    case 'yon'
       set(hZoom,'Constraint','vertical');
       change_ui = 'on';
    
    case 'getzoom'
       out = hZoom;   
    case 'getmode'
       if localIsZoomOn(hZoom)
          out = get(hZoom,'Direction');
       else
          out = 'off';
       end
    case 'constraint'
       out = get(hZoom,'Constraint');
    case 'direction'
       out = get(hZoom,'Direction');
    case 'ison'
       out = localIsZoomOn(hZoom);
    case 'ison' %TBD: Remove
     out = localIsZoomOn(hZoom);
    case 'getstyle' %TBD: Remove
       out = get(hZoom,'Constraint');       
    case 'getdirection' %TBD: Remove
       out = get(hZoom,'Direction');
    case 'toggle'
       if localIsZoomOn(hZoom)
         change_ui = 'off';
       else
         change_ui = 'on';
       end
      
    % Undocumented legacy API, used by 'ident', see g194435
    % It would be nice to get rid to dependencies on this API, but
    % many old toolboxes seem to be calling this API.
    case 'down'
       buttondownfcn(hZoom,'dorightclick',true);
       hLine = get(hZoom,'LineHandles');
       if ishandle(hLine)
          % Mimic rbbox, don't return until line handles are
          % removed
          waitfor(hLine(1));
       end

    case 'off'
       change_ui = 'off';
    case 'inmode'
       set(hZoom,'Direction','in');
       change_ui = 'on';
    case 'outmode'
       set(hZoom,'Direction','out');      
       change_ui = 'on';
    case 'scale'
       if ~isempty(hCurrentAxes)    
          % Register current axes view for reset view support
          resetplotview(hCurrentAxes,'InitializeCurrentView');
          applyzoomfactor(hZoom,hCurrentAxes,action_data);
       end
    case 'fill'
       if ~isempty(hCurrentAxes)
          resetplot(hZoom,hCurrentAxes);
       end
    case 'reset'
       resetplotview(hCurrentAxes,'SaveCurrentView');
    case 'out'
       if ~isempty(hCurrentAxes)
          resetplot(hZoom,hCurrentAxes);
       end
    case 'setzoomproperties'
       % undocumented 
       set(hZoom,action_data{:});
    otherwise
       return
end

%====================================================================
%  This is a modification to accomodate the ADDAXIS commands.  
%  Check to see if add axis has been used and update the axes using 
%  the same scale factors.  (also put ystart = get(gca,'ylim'); 
%  before the zoom is started above)

yend = get(gca,'ylim');

%  ystart and yend are the starting and ending yaxis limits
%  now go through all of the added axes and scale their limits
%axh = get(gca,'userdata');
axh = getaddaxisdata(gca,'axisdata');
if ~isempty(axh)
  for I = 1:length(axh)
    axhan = axh{I}(1);
    axyl = get(axhan,'ylim');
    axylnew(1) = axyl(1)+(yend(1)-ystart(1))/(ystart(2)-ystart(1)).*...
	                 (axyl(2)-axyl(1));
    axylnew(2) = axyl(2)-(ystart(2)-yend(2))/(ystart(2)-ystart(1)).*...
	                 (axyl(2)-axyl(1));
    set(axhan,'ylim',axylnew);
  end
end

%  END of modification
%================================================================

% Update the user interface 
if ~isempty(change_ui)
   localSetZoomState(hZoom,change_ui);
end

%-----------------------------------------------%
function localSetZoomState(hZoom,state)

hFigure = get(hZoom,'FigureHandle');
appdata = localGetData(hFigure);
uistate = appdata.uistate;

if strcmp(state,'on')    
      
    % Turn off all other interactive modes
    if isempty(uistate)
        % Specify uninstaller callback: zoom(fig,'off') 
        uistate = uiclearmode(double(hFigure),...
                              'docontext',...
                              'zoom',double(hFigure),'off');
        % restore button down functions for uicontrol children of the figure
        uirestore(uistate,'uicontrols');
        appdata.uistate = uistate;
    end

    % Enable zoom mode  
    appdata.ison = true;
    set(hZoom,'IsOn',true);
    localSetData(hFigure,appdata);
    set(hFigure,'WindowButtonMotionFcn',{@localMotionFcn,hZoom});
    set(hFigure,'WindowButtonUpFcn',[])
    set(hFigure,'WindowButtonDownFcn',{@localWindowButtonDownFcn,hZoom});
    set(hFigure,'KeyPressFcn',{@localKeyPressFcn,hZoom});     
    set(hFigure,'PointerShapeHotSpot',[5 5]);
    localMotionFcn(hFigure,[],hZoom);
    
    % Flush queue to update figure pointer display asap.
    drawnow expose;
        
    % Turn on Zoom UI (i.e. toolbar buttons, menus)
    % This must be called AFTER uiclear to avoid uiclear state munging
    zoom_direction = get(hZoom,'Direction');
    switch zoom_direction
       case 'in'
          localUISetZoomIn(hFigure);
       case 'out'
          localUISetZoomOut(hFigure);
    end
    local_scribefiglisten(hFigure,'on');

    % Define appdata to avoid breaking code in 
    % scribefiglisten, hgsave, and figtoolset
    setappdata(hFigure,'ZoomOnState','on');
   
% zoom off    
elseif strcmp(state,'off')
    if ~isempty(uistate)
        % restore figure and non-uicontrol children
        % don't restore uicontrols because they were restored
        % already when zoom was turned on
        uirestore(uistate,'nouicontrols');
        
        % Turn off Zoom UI (i.e. toolbar buttons, menus)
        localUISetZoomOff(hFigure);
        local_scribefiglisten(hFigure,'off');
        
        % Remove uicontextmenu 
        hui = get(hZoom,'UIContextMenu');
        if ishandle(hui)
            delete(hui);
        end
    end
    
    % Reset appdata
    localRmData(hFigure);
    
    % Remove appdata to avoid breaking code in 
    % scribefiglisten, hgsave, and figtoolset
    if isappdata(hFigure,'ZoomOnState');
       rmappdata(hFigure,'ZoomOnState');
    end    
end
    
%-----------------------------------------------%
function [bool] = localIsZoomOn(hZoom)

% TBD, when zoom enabled property is wired correctly
% do the following:
%bool = strcmp(get(hZoom,'Enabled'),'on'));

% For now, use app data
hFigure = get(hZoom,'FigureHandle');
appdata = localGetData(hFigure);
bool = appdata.ison;

%-----------------------------------------------%
function localWindowButtonDownFcn(hFigure,evd,hZoom)

if ~ishandle(hZoom)
    return;
end

fig_sel_type = get(hFigure,'SelectionType');
fig_mod = get(hFigure,'CurrentModifier');

%========================================================
%  Part of modification for ADDAXIS commands
ystart = get(gca,'ylim');
%========================================================

switch (lower(fig_sel_type))
    case 'alt' % right click
        % display context menu
        hui = localGetContextMenu(hZoom);
                
        curr_point = get(hFigure,'CurrentPoint');
        curr_pixel = hgconvertunits(hFigure,[curr_point 0 0],...
                           get(hFigure,'Units'),'pixels',hFigure);
                                              
        set(hui,'Position',curr_pixel(1:2),'Visible','on')
        
    otherwise % left click, center click, double click
        % Zoom out if user clicked on 'alt'
        if strcmp(fig_mod,'alt')
           switch get(hZoom,'Direction')
              case 'in'
                  applyzoomfactor(hZoom,findaxes(hZoom),.9);   
              case 'out'
                  applyzoomfactor(hZoom,findaxes(hZoom),2);
           end
       % Delegate to registered zoom object
	else
            buttondownfcn(hZoom);
	end 
end
%====================================================================
%  This is a modification to accomodate the ADDAXIS commands.  
%  Check to see if add axis has been used and update the axes using 
%  the same scale factors.  (also put ystart = get(gca,'ylim'); 
%  before the zoom is started above)
yend = get(gca,'ylim');

%  ystart and yend are the starting and ending yaxis limits
%  now go through all of the added axes and scale their limits
%axh = get(gca,'userdata');
axh = getaddaxisdata(gca,'axisdata');
if ~isempty(axh)
  for I = 1:length(axh)
    axhan = axh{I}(1);
    axyl = get(axhan,'ylim');
    axylnew(1) = axyl(1)+(yend(1)-ystart(1))/(ystart(2)-ystart(1)).*...
	                 (axyl(2)-axyl(1));
    axylnew(2) = axyl(2)-(ystart(2)-yend(2))/(ystart(2)-ystart(1)).*...
	                 (axyl(2)-axyl(1));
    set(axhan,'ylim',axylnew);
  end
end

%  END of modification
%================================================================

%-----------------------------------------------%
function localMotionFcn(hFigure,evd,hZoom)

if ishandle(hZoom)
    hTarget = handle(hittest(hFigure));
    if ~isempty(ancestor(hTarget,'axes'))
        if strcmp(get(hZoom,'Direction'),'in')
            setptr(hFigure,'glassplus');
        else
            setptr(hFigure,'glassminus');
        end
    else
        setptr(hFigure,'arrow');
    end
end

%-----------------------------------------------%
function localKeyPressFcn(hFigure,evd,hZoom)

% Delegate to registered zoom object
if ishandle(hZoom)
    keypressfcn(hZoom,evd);
end

%-----------------------------------------------%
function [hZoom] = localGetRegisteredZoomObject(hFigure,dopeek)

% TBD Get Zoom object from Figure Tool Manager
hZoom = getappdata(hFigure,'ZoomObject');
if isempty(hZoom) || ~isa(hZoom,'graphics.zoom')
  hZoom = graphics.zoom(hFigure);
  setappdata(hFigure,'ZoomObject',hZoom);
end

%-----------------------------------------------%
function localRegisterZoomObject(hFigure,hZoom)
hFigure = hZoom.FigureHandle;
setappdata(hFigure,'ZoomObject',hZoom);

%-----------------------------------------------%
function [appdata] = localGetData(fig)
appdata = getappdata(fig,'ZoomFigureState');
if isempty(appdata) || ~isfield(appdata,'uistate')
    appdata.uistate = [];
    appdata.ison = false;
end

%-----------------------------------------------%
function localSetData(fig,appdata)
setappdata(fig,'ZoomFigureState',appdata);

%-----------------------------------------------%
function localRmData(fig)
appdata = localGetData(fig);
appdata.uistate = [];
appdata.ison = false;
localSetData(fig,appdata);

%-----------------------------------------------% 
function [hui] = localUICreateDefaultContextMenu(hZoom)
% Create default context menu

hFig = get(hZoom,'FigureHandle');
props_context.Parent = hFig;
props_context.Tag = 'ZoomContextMenu';
props_context.Callback = {@localUIContextMenuCallback,hZoom};
props_context.ButtonDown = {@localUIContextMenuCallback,hZoom};
hui = uicontextmenu(props_context);

% Generic attributes for all zoom context menus
props.Callback = {@localUIContextMenuCallback,hZoom};
props.Parent = hui;

props.Label = 'Zoom Out       Alt-Click';
props.Tag = 'ZoomInOut';
props.Separator = 'off';
uzoomout = uimenu(props);

% Full View context menu
props.Label = 'Reset to Original View';
props.Tag = 'ResetView';
props.Separator = 'off';
ufullview = uimenu(props);

% Zoom Constraint context menu
props.Callback = '';
props.Label = 'Zoom Options';
props.Tag = 'Constraint';
props.Separator = 'on';
uConstraint = uimenu(props);

props.Parent = uConstraint;

props.Callback = {@localUIContextMenuCallback,hZoom};
props.Label = 'Unconstrained Zoom';
props.Tag = 'ZoomUnconstrained';
props.Separator = 'off';
uimenu(props);

props.Label = 'Horizontal Zoom (2-D Plots Only)';
props.Tag = 'ZoomHorizontal';
uimenu(props);

props.Label = 'Vertical Zoom (2-D Plots Only)';
props.Tag = 'ZoomVertical';
uimenu(props);

localUIContextMenuUpdate(hZoom,get(hZoom,'Constraint'));

%-----------------------------------------------% 
function [hui] = localGetContextMenu(hZoom)
% Create context menu

hui = get(hZoom,'UIContextMenu');
if isempty(hui) || ~ishandle(hui) 
   local_scribefiglisten(get(hZoom,'Figure'),'off');
   hui = localUICreateDefaultContextMenu(hZoom);
   local_scribefiglisten(get(hZoom,'Figure'),'on');
   set(hZoom,'UIContextMenu',hui);
   localUIUpdateContextMenuLabel(hZoom);
   drawnow expose;
end

%-------------------------------------------------%  
function localUIContextMenuCallback(obj,evd,hZoom)

tag = get(obj,'tag');

%========================================================
%  Part of modification for ADDAXIS commands
ystart = get(gca,'ylim');
%========================================================

switch(tag)    
    case 'ZoomInOut'
        switch get(hZoom,'Direction')
            case 'in'
                applyzoomfactor(hZoom,findaxes(hZoom),.9);
            case 'out'
                applyzoomfactor(hZoom,findaxes(hZoom),2);
        end
    case 'ResetView'
        hAxes = findaxes(hZoom);
        resetplotview(hAxes,'ApplyStoredView');
    case 'ZoomContextMenu'
        localUIContextMenuUpdate(hZoom,get(hZoom,'Constraint'));
    case 'ZoomUnconstrained'
        localUIContextMenuUpdate(hZoom,'none');
    case 'ZoomHorizontal'
        localUIContextMenuUpdate(hZoom,'horizontal');
    case 'ZoomVertical'
        localUIContextMenuUpdate(hZoom,'vertical');
end

%====================================================================
%  This is a modification to accomodate the ADDAXIS commands.  
%  Check to see if add axis has been used and update the axes using 
%  the same scale factors.  (also put ystart = get(gca,'ylim'); 
%  before the zoom is started above)

yend = get(gca,'ylim');

%  ystart and yend are the starting and ending yaxis limits
%  now go through all of the added axes and scale their limits
%axh = get(gca,'userdata');
axh = getaddaxisdata(gca,'axisdata');
if ~isempty(axh)
  for I = 1:length(axh)
    axhan = axh{I}(1);
    axyl = get(axhan,'ylim');
    axylnew(1) = axyl(1)+(yend(1)-ystart(1))/(ystart(2)-ystart(1)).*...
	                 (axyl(2)-axyl(1));
    axylnew(2) = axyl(2)-(ystart(2)-yend(2))/(ystart(2)-ystart(1)).*...
	                 (axyl(2)-axyl(1));
    set(axhan,'ylim',axylnew);
  end
end

%  END of modification
%================================================================


%-------------------------------------------------%  
function localUIContextMenuUpdate(hZoom,zoom_Constraint)

hFigure = get(hZoom,'FigureHandle');
ux = findall(hFigure,'Tag','ZoomHorizontal','Type','UIMenu');
uy = findall(hFigure,'Tag','ZoomVertical','Type','UIMenu');
uxy = findall(hFigure,'Tag','ZoomUnconstrained','Type','UIMenu');

switch(zoom_Constraint) 
  
  case 'none'
      set(hZoom,'Constraint','none');
      set(ux,'checked','off');
      set(uy,'checked','off');
      set(uxy,'checked','on');

  case 'horizontal'
      set(hZoom,'Constraint','horizontal');
      set(ux,'checked','on');
      set(uy,'checked','off');
      set(uxy,'checked','off');

  case 'vertical'
      set(hZoom,'Constraint','vertical');
      set(ux,'checked','off');
      set(uy,'checked','on');
      set(uxy,'checked','off');
end
  
%-----------------------------------------------%
function localUIMenuUpdate(fig)
 
set(findall(fig,'Tag','figMenuZoomIn'),'Checked','on');

%-----------------------------------------------%
function localUISetZoomIn(fig)
set(uigettoolbar(fig,'Exploration.ZoomIn'),'State','on');   
set(uigettoolbar(fig,'Exploration.ZoomOut'),'State','off');    

%-----------------------------------------------%
function localUISetZoomOut(fig)
h = findall(fig,'type','uitoolbar');
set(uigettool(h,'Exploration.ZoomIn'),'State','off');   
set(uigettool(h,'Exploration.ZoomOut'),'State','on');    

%-----------------------------------------------%
function localUISetZoomOff(fig)
h = findall(fig,'type','uitoolbar');
set(uigettool(h,'Exploration.ZoomIn'),'State','off');
set(uigettool(h,'Exploration.ZoomOut'),'State','off');   

% Remove the following lines after UITOOLBARFACTORY API is on by default
set(findall(fig,'Tag','figToolZoomIn'),'State','off');   
set(findall(fig,'Tag','figToolZoomOut'),'State','off'); 

%-----------------------------------------------%
function localUIUpdateContextMenuLabel(hZoom);

h = findobj(get(hZoom,'UIContextMenu'),'Tag','ZoomInOut');
zoom_direction = get(hZoom,'Direction');
if strcmp(zoom_direction,'in')
    set(h,'Label','Zoom Out       Alt-Click');
else
    set(h,'Label','Zoom In        Alt-Click');
end


%-----------------------------------------------%
function localSetNewZoom(bool)

setappdata(0,'NewZoomImplementation',bool);

%-----------------------------------------------%
function [target,action,action_data] = localParseArgs(varargin)

target = [];
action = [];
action_data = [];
errstr = {'Zoom:InvalidSyntax','Invalid Syntax'};
target = get(0,'CurrentFigure');

% zoom
if nargin==0 
    action = 'toggle';
    
elseif nargin==1
    arg1 = varargin{1};
    
    % zoom(SCALE)
    if all(size(arg1)==[1,1]) & isnumeric(arg1)
        action = 'scale';
        action_data = arg1;
        
    % zoom(OPTION)    
    elseif isstr(arg1)
        action = arg1;

    % zoom(FIG)        
    % zoom(HZOOM)
    elseif ishandle(arg1)
        if isa(handle(arg1),'graphics.zoom')
           target = get(arg1,'target');
           action = 'setzoom';
        elseif isa(handle(arg1),'hg.figure')  
           target = arg1;
           action = 'toggle';
        end     
    else
        error(errstr{:});
    end
    

elseif nargin==2 
    
    % zoom('newzoom',0)
    if isstr(varargin{1})
       action = varargin{1};
       action_data = varargin{2};
    
    % zoom(FIG,SCALE)
    % zoom(FIG,OPTION) 
    elseif ishandle(varargin{1}) 
       target = varargin{1};
       arg2 = varargin{2};
       if isstr(arg2)
           action = arg2;
       elseif isnumeric(arg2)
           action = 'scale';
           action_data = arg2;
       end
    end 
    
% zoom(FIG,<paramater/value pairs>);
elseif nargin>=3
   target = varargin{1};
   arg2 = varargin{2};
   if ishandle(target) & isstr(arg2)
        action = 'setzoomproperties';
        action_data = {varargin{2:end}};
   end
end

target = handle(target);

%-----------------------------------------------%
function localSetV6Zoom(bool)
setappdata(0,'V6Zoom',bool);

%-----------------------------------------------%
function [bool] = localIsV6Zoom
bool = getappdata(0,'V6Zoom');

%-----------------------------------------------%
function local_scribefiglisten(hFigure,val)

scribefiglisten(hFigure,val);
