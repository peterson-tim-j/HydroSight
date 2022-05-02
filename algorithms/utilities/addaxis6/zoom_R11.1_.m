function out = zoom(varargin)
%ZOOM   Zoom in and out on a 2-D plot.
%   ZOOM with no arguments toggles the zoom state.
%   ZOOM(FACTOR) zooms the current axis by FACTOR.
%       Note that this does not affect the zoom state.
%   ZOOM ON turns zoom on for the current figure.  
%   ZOOM OFF turns zoom off in the current figure.
%   ZOOM OUT returns the plot to its initial (full) zoom.
%   ZOOM XON or ZOOM YON turns zoom on for the x or y axis only.
%   ZOOM RESET clears the zoom out point.
%
%   When zoom is on, click the left mouse button to zoom in on the
%   point under the mouse.  Click the right mouse button to zoom out
%   (shift-click on the Macintosh).  Each time you click, the axes
%   limits will be changed by a factor of 2 (in or out).  You can also
%   click and drag to zoom into an area.  Double clicking zooms out to
%   the point at which zoom was first turned on for this figure.  Note
%   that turning zoom on, then off does not reset the zoom point.
%   This may be done explicitly with ZOOM RESET.
%   
%   ZOOM(FIG,OPTION) applies the zoom command to the figure specified
%   by FIG. OPTION can be any of the above arguments.

%   ZOOM FILL scales a plot such that it is as big as possible
%   within the axis position rectangle for any azimuth and elevation.

%   Clay M. Thompson 1-25-93
%   Revised 11 Jan 94 by Steven L. Eddins
%   Copyright (c) 1984-98 by The MathWorks, Inc.
%   $Revision: 5.42 $  $Date: 1998/09/30 13:43:56 $

%   Note: zoom uses the figure buttondown and buttonmotion functions
%
%   ZOOM XON zooms x-axis only
%   ZOOM YON zooms y-axis only

switch nargin,
   
   %%%%%%%%%%%%%%%%%%%%%%%%%%
   %%% No Input Arguments %%%
   %%%%%%%%%%%%%%%%%%%%%%%%%%
case 0,
   fig=get(0,'currentfigure');
   if isempty(fig), return, end
   zoomCommand='toggle';
   
   %%%%%%%%%%%%%%%%%%%%%%%%%%
   %%% One Input Argument %%%
   %%%%%%%%%%%%%%%%%%%%%%%%%%
case 1,
   
   % If the argument is a string, the argument is a zoom command
   % (i.e. (on, off, down, xdown, etc.).  Otherwise, the argument is
   % assumed to be a figure handle, in which case all we do is
   % toggle the zoom status.
   
   if isstr(varargin{1}),
      fig=get(0,'currentfigure');
      if isempty(fig), return, end
      
      zoomCommand=varargin{1};
   else
      scale_factor=varargin{1};
      zoomCommand='scale';
      fig = gcf;
   end % if
   
   %%%%%%%%%%%%%%%%%%%%%%%%%%%
   %%% Two Input Arguments %%%
   %%%%%%%%%%%%%%%%%%%%%%%%%%%
case 2,
   fig=varargin{1};
   zoomCommand=varargin{2};
   
otherwise,
   error(nargchk(0, 2, nargin));
   
end % switch nargin

%
% handle 'off' commands first
%
if strcmp(zoomCommand,'off'),
   %
   % turn off zoom, and take a hike
   %
   set(findall(fig,'Tag','figToolZoomIn'),'State','off');
   set(findall(fig,'Tag','figToolZoomOut'),'State','off');   
   if ~isempty(getappdata(fig,'ZoomFigureMode'))
      rmappdata(fig,'ZOOMFigureMode');
   end

   state = getuprop(fig,'ZOOMFigureState');
   if ~isempty(state),
      uirestore(state);
      clruprop(fig,'ZOOMFigureState');
   end
   return
end % if

ax=get(fig,'currentaxes');

rbbox_mode = 0;
zoomx = 1; zoomy = 1; % Assume no constraints

zoomCommand=lower(zoomCommand);

if ~isempty(ax) & any(get(ax,'view')~=[0 90]) ...
           & ~(strcmp(zoomCommand,'scale') | ...
           strcmp(zoomCommand,'fill')),
   fZoom3d = 1;
   % set(findall(fig,'Tag','figToolZoom'),'State','off');   
   % warning('Zoom is only supported for 2D plots.');
   % return % Do nothing
else
   fZoom3d = 0;
end

if strcmp(zoomCommand,'toggle'),
   state = getuprop(fig,'ZOOMFigureState');
   if isempty(state)
      zoom(fig,'on');
   else
      zoom(fig,'off');
   end
   return
end % if

% Catch constrained zoom
if strcmp(zoomCommand,'xdown'),
   zoomy = 0; zoomCommand = 'down'; % Constrain y
elseif strcmp(zoomCommand,'ydown')
   zoomx = 0; zoomCommand = 'down'; % Constrain x
end


switch zoomCommand
case 'down',
   % Activate axis that is clicked in
   allAxes = findobj(datachildren(fig),'flat','type','axes');
   ZOOM_found = 0;
   
   % this test may be causing failures for 3d axes
   for i=1:length(allAxes),
      ax=allAxes(i);
      ZOOM_Pt1 = get(ax,'CurrentPoint');
      xlim = get(ax,'xlim');
      ylim = get(ax,'ylim');
      if (xlim(1) <= ZOOM_Pt1(1,1) & ZOOM_Pt1(1,1) <= xlim(2) & ...
            ylim(1) <= ZOOM_Pt1(1,2) & ZOOM_Pt1(1,2) <= ylim(2))
         ZOOM_found = 1;
         set(fig,'currentaxes',ax);
         break
      end % if
   end % for

   if ZOOM_found==0, return, end
   
   % Check for selection type
   selection_type = get(fig,'SelectionType');
   zoomMode = getappdata(fig,'ZOOMFigureMode');

   axz = get(ax,'ZLabel');
   
      if fZoom3d

      viewData = getappdata(axz,'ZOOMAxesView');
      if isempty(viewData)
         viewProps = { 'CameraTarget'...
                    'CameraTargetMode'...
                    'CameraViewAngle'...
                    'CameraViewAngleMode'};
         setappdata(axz,'ZOOMAxesViewProps', viewProps);
         setappdata(axz,'ZOOMAxesView', get(ax,viewProps));
      end
      
      if isempty(zoomMode) | strcmp(zoomMode,'in');
         zoomLeftFactor = 1.5;
         zoomRightFactor = .75;         
      elseif strcmp(zoomMode,'out');
         zoomLeftFactor = .75;
         zoomRightFactor = 1.5;
      end
      
      switch selection_type
         case 'open'
            set(ax,getappdata(axz,'ZOOMAxesViewProps'),...
                    getappdata(axz,'ZOOMAxesView'));
         case 'normal'
            newTarget = mean(get(ax,'CurrentPoint'),1);
            set(ax,'CameraTarget',newTarget);
            camzoom(ax,zoomLeftFactor);
         otherwise
            newTarget = mean(get(ax,'CurrentPoint'),1);
            set(ax,'CameraTarget',newTarget);
            camzoom(ax,zoomRightFactor);
      end

      return
   end

   if isempty(zoomMode) | strcmp(zoomMode,'in');
      switch selection_type
         case 'normal'
            % Zoom in
            m = 1;
            scale_factor = 2; % the default zooming factor
         case 'open'
            % Zoom all the way out
            zoom(fig,'out');
            return;
         otherwise
            % Zoom partially out
            m = -1;
            scale_factor = 2;
      end
   elseif strcmp(zoomMode,'out')
      switch selection_type
         case 'normal'
            % Zoom partially out
            m = -1;
            scale_factor = 2;
         case 'open'
            % Zoom all the way out
            zoom(fig,'out');
            return;
         otherwise
            % Zoom in
            m = 1;
            scale_factor = 2; % the default zooming factor
      end
   else % unrecognized zoomMode
      return
   end
   
   
   ZOOM_Pt1 = get_currentpoint(ax);
   ZOOM_Pt2 = ZOOM_Pt1;
   center = ZOOM_Pt1;
   
   if (m == 1)
      % Zoom in
      units = get(fig,'units'); set(fig,'units','pixels')
      rbbox([get(fig,'currentpoint') 0 0],get(fig,'currentpoint'));
      ZOOM_Pt2 = get_currentpoint(ax);
      set(fig,'units',units)
      
      % Note the currentpoint is set by having a non-trivial up function.
      if min(abs(ZOOM_Pt1-ZOOM_Pt2)) >= ...
            min(.01*[diff(get_xlim(ax)) diff(get_ylim(ax))]),
         % determine axis from rbbox 
         a = [ZOOM_Pt1;ZOOM_Pt2]; a = [min(a);max(a)];
         
         % Undo the effect of get_currentpoint for log axes
         if strcmp(get(ax,'XScale'),'log'),
            a(1:2) = 10.^a(1:2);
         end
         if strcmp(get(ax,'YScale'),'log'),
            a(3:4) = 10.^a(3:4);
         end
         rbbox_mode = 1;
      end
   end
   limits = zoom(fig,'getlimits');
   
case 'scale',
   if all(get(ax,'view')==[0 90]), % 2D zooming with scale_factor
      
      % Activate axis that is clicked in
      ZOOM_found = 0;
      ax = gca;
      xlim = get(ax,'xlim');
      ylim = get(ax,'ylim');
      ZOOM_Pt1 = [sum(xlim)/2 sum(ylim)/2];
      ZOOM_Pt2 = ZOOM_Pt1;
      center = ZOOM_Pt1;
      
      if (xlim(1) <= ZOOM_Pt1(1,1) & ZOOM_Pt1(1,1) <= xlim(2) & ...
            ylim(1) <= ZOOM_Pt1(1,2) & ZOOM_Pt1(1,2) <= ylim(2))
         ZOOM_found = 1;
      end % if
      
      if ZOOM_found==0, return, end
      
      if (scale_factor >= 1)
         m = 1;
      else
         m = -1;
      end
      
   else % 3D
      old_CameraViewAngle = get(ax,'CameraViewAngle')*pi/360;
      ncva = atan(tan(old_CameraViewAngle)*(1/scale_factor))*360/pi;
      set(ax,'CameraViewAngle',ncva);
      return;
   end
   
   limits = zoom(fig,'getlimits');

case 'getmode'
   state = getuprop(fig,'ZOOMFigureState');
   if isempty(state)
      out = 'off';
   else
      mode = getappdata(fig,'ZOOMFigureMode');
      if isempty(mode)
         out = 'on';
      else
         out = mode;
      end
   end
   return

   
case 'on',
   
   set(findall(fig,'Tag','figToolZoomIn'),'State','on');
   
   state = getuprop(fig,'ZOOMFigureState');
   if isempty(state),
      state = uiclearmode(fig,'zoom',fig,'off');
      setuprop(fig,'ZOOMFigureState',state);
   end
   set(fig,'windowbuttondownfcn','zoom down', ...
      'windowbuttonupfcn','ones;', ...
      'windowbuttonmotionfcn','','buttondownfcn','', ...
      'interruptible','on');
   set(ax,'interruptible','on')
   return
   
case 'inmode'
   zoom(fig,'on');
   set(findall(fig,'Tag','figToolZoomIn'),'State','on');   
   set(findall(fig,'Tag','figToolZoomOut'),'State','off');      
   setappdata(fig,'ZOOMFigureMode','in');
   return   
   
case 'outmode'
   zoom(fig,'on');
   set(findall(fig,'Tag','figToolZoomIn'),'State','off');   
   set(findall(fig,'Tag','figToolZoomOut'),'State','on');      
   setappdata(fig,'ZOOMFigureMode','out');
   return
   
case 'reset',
   axz = get(ax,'ZLabel');
   if isappdata(axz,'ZoomAxesData')
     rmappdata(axz,'ZOOMAxesData');
   end
   return
   
case 'xon',
   zoom(fig,'on') % Set up userprop
   set(fig,'windowbuttondownfcn','zoom xdown', ...
      'windowbuttonupfcn','ones;', ...
      'windowbuttonmotionfcn','','buttondownfcn','',...
      'interruptible','on');
   set(ax,'interruptible','on')
   return
   
case 'yon',
   zoom(fig,'on') % Set up userprop
   set(fig,'windowbuttondownfcn','zoom ydown', ...
      'windowbuttonupfcn','ones;', ...
      'windowbuttonmotionfcn','','buttondownfcn','',...
      'interruptible','on');
   set(ax,'interruptible','on')
   return
   
case 'out',
   limits = zoom(fig,'getlimits');
   center = [sum(get_xlim(ax))/2 sum(get_ylim(ax))/2];
   m = -inf; % Zoom totally out
   
case 'getlimits', % Get axis limits
   axz = get(ax,'ZLabel');
   limits = getappdata(axz,'ZOOMAxesData');
   % Do simple checking of userdata
   if size(limits,2)==4 & size(limits,1)<=2, 
      if all(limits(1,[1 3])<limits(1,[2 4])), 
         getlimits = 0; out = limits(1,:); return   % Quick return
      else
         getlimits = -1; % Don't munge data
      end
   else
      if isempty(limits), getlimits = 1; else getlimits = -1; end
   end
   
   % If I've made it to here, we need to compute appropriate axis
   % limits.
   
   if isempty(getappdata(axz,'ZOOMAxesData')),
      % Use quick method if possible
      xlim = get_xlim(ax); xmin = xlim(1); xmax = xlim(2); 
      ylim = get_ylim(ax); ymin = ylim(1); ymax = ylim(2); 
      
   elseif strcmp(get(ax,'xLimMode'),'auto') & ...
         strcmp(get(ax,'yLimMode'),'auto'),
      % Use automatic limits if possible
      xlim = get_xlim(ax); xmin = xlim(1); xmax = xlim(2); 
      ylim = get_ylim(ax); ymin = ylim(1); ymax = ylim(2); 
      
   else
      % Use slow method only if someone else is using the userdata
      h = get(ax,'Children');
      xmin = inf; xmax = -inf; ymin = inf; ymax = -inf;
      for i=1:length(h),
         t = get(h(i),'Type');
         if ~strcmp(t,'text'),
            if strcmp(t,'image'), % Determine axis limits for image
               x = get(h(i),'Xdata'); y = get(h(i),'Ydata');
               x = [min(min(x)) max(max(x))];
               y = [min(min(y)) max(max(y))];
               [ma,na] = size(get(h(i),'Cdata'));
               if na>1, dx = diff(x)/(na-1); else dx = 1; end
               if ma>1, dy = diff(y)/(ma-1); else dy = 1; end
               x = x + [-dx dx]/2; y = y + [-dy dy]/2;
            end
            xmin = min(xmin,min(min(x)));
            xmax = max(xmax,max(max(x)));
            ymin = min(ymin,min(min(y)));
            ymax = max(ymax,max(max(y)));
         end
      end
      
      % Use automatic limits if in use (override previous calculation)
      if strcmp(get(ax,'xLimMode'),'auto'),
         xlim = get_xlim(ax); xmin = xlim(1); xmax = xlim(2); 
      end
      if strcmp(get(ax,'yLimMode'),'auto'),
         ylim = get_ylim(ax); ymin = ylim(1); ymax = ylim(2); 
      end
   end
   
   limits = [xmin xmax ymin ymax];
   if getlimits~=-1, % Don't munge existing data.
      % Store limits ZOOMAxesData
      % store it with the ZLabel, so that it's cleared if the 
      % user plots again into this axis.  If that happens, this
      % state is cleared
      axz = get(ax,'ZLabel');
      setappdata(axz,'ZOOMAxesData',limits);
   end
   
   out = limits;
   return
   
case 'getconnect', % Get connected axes
   axz = get(ax,'ZLabel');
   limits = getappdata(axz,'ZOOMAxesData');
   if all(size(limits)==[2 4]), % Do simple checking
      out = limits(2,[1 2]);
   else
      out = [ax ax];
   end
   return
   
case 'fill',
   old_view = get(ax,'view');
   view(45,45);
   set(ax,'CameraViewAngleMode','auto');
   set(ax,'CameraViewAngle',get(ax,'CameraViewAngle'));
   view(old_view);
   return
   
otherwise
   error(['Unknown option: ',zoomCommand,'.']);
end

%
% Actual zoom operation
%

%========================================================
%  Part of modification for ADDAXIS commands
ystart = get(gca,'ylim');
%========================================================

if ~rbbox_mode,
   xmin = limits(1); xmax = limits(2);   
   ymin = limits(3); ymax = limits(4);   
   
   if m==(-inf),
      dx = xmax-xmin;
      dy = ymax-ymin;
   else
      dx = diff(get_xlim(ax))*(scale_factor.^(-m-1)); dx = min(dx,xmax-xmin);
      dy = diff(get_ylim(ax))*(scale_factor.^(-m-1)); dy = min(dy,ymax-ymin);
   end
   
   % Limit zoom.
   center = max(center,[xmin ymin] + [dx dy]);
   center = min(center,[xmax ymax] - [dx dy]);
   a = [max(xmin,center(1)-dx) min(xmax,center(1)+dx) ...
         max(ymin,center(2)-dy) min(ymax,center(2)+dy)];
   
   % Check for log axes and return to linear values.
   if strcmp(get(ax,'XScale'),'log'),
      a(1:2) = 10.^a(1:2);
   end
   if strcmp(get(ax,'YScale'),'log'),
      a(3:4) = 10.^a(3:4);
   end
   
end

% Check for axis equal and update a as necessary
if strcmp(get(ax,'plotboxaspectratiomode'),'manual') & ...
   strcmp(get(ax,'dataaspectratiomode'),'manual')
   ratio = get(ax,'plotboxaspectratio')./get(ax,'dataaspectratio');
   dx = a(2)-a(1);
   dy = a(4)-a(3);
   [kmax,k] = max([dx dy]./ratio(1:2));
   if k==1
      dy = kmax*ratio(2);
      a(3:4) = mean(a(3:4))+[-dy dy]/2;
   else
     dx = kmax*ratio(1);
     a(1:2) = mean(a(1:2))+[-dx dx]/2;
   end
end

% Update circular list of connected axes
list = zoom(fig,'getconnect'); % Circular list of connected axes.
if zoomx,
   if a(1)==a(2), return, end % Short circuit if zoom is moot.
   set(ax,'xlim',a(1:2))
   h = list(1);
   while h ~= ax,
      set(h,'xlim',a(1:2))
      % Get next axes in the list
      hz = get(h,'ZLabel');
      next = getappdata(hz,'ZOOMAxesData');
      if all(size(next)==[2 4]), h = next(2,1); else h = ax; end
   end
end
if zoomy,
   if a(3)==a(4), return, end % Short circuit if zoom is moot.
   set(ax,'ylim',a(3:4))
   h = list(2);
   while h ~= ax,
      set(h,'ylim',a(3:4))
      % Get next axes in the list
      hz = get(h,'ZLabel');
      next = getappdata(hz,'ZOOMAxesData');
      if all(size(next)==[2 4]), h = next(2,2); else h = ax; end
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

function p = get_currentpoint(ax)
%GET_CURRENTPOINT Return equivalent linear scale current point
p = get(ax,'currentpoint'); p = p(1,1:2);
if strcmp(get(ax,'XScale'),'log'),
   p(1) = log10(p(1));
end
if strcmp(get(ax,'YScale'),'log'),
   p(2) = log10(p(2));
end

function xlim = get_xlim(ax)
%GET_XLIM Return equivalent linear scale xlim
xlim = get(ax,'xlim');
if strcmp(get(ax,'XScale'),'log'),
   xlim = log10(xlim);
end

function ylim = get_ylim(ax)
%GET_YLIM Return equivalent linear scale ylim
ylim = get(ax,'ylim');
if strcmp(get(ax,'YScale'),'log'),
   ylim = log10(ylim);
end
