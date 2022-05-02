function buttonupfcn2D(hZoom, cpMulAxes)
%MOUSEBTNUPFCN Mouse button up function

% Copyright 2003-2004 The MathWorks, Inc.

% This code originates from simulink zoom. 

% This constant specifies the number of pixels the mouse
% must move in order to do a rbbox zoom.
POINT_MODE_MAX_PIXELS = 5; % pixels

% Get necessary handles
hFig = get(hZoom,'FigureHandle');
hLines     = get(hZoom,'LineHandles');
currentAxes = get(hZoom,'CurrentAxes');

% Get net mouse movement in pixels
orig_units = get(hFig,'Units');
set(hFig,'Units','Pixels');
fp = get(hFig,'CurrentPoint');
set(hFig,'Units',orig_units);
orig_fp = get(hZoom,'MousePoint');
dpixel = abs(orig_fp-fp);

% The first point of line 1 is always the zoom origin.
XDat   = get(hLines(1), 'XData');
YDat   = get(hLines(1), 'YData');
origin = [XDat(1), YDat(1)];

% Loop through all the currentAxes and zoom-in each of them
for k = 1:length(currentAxes),
    cAx = currentAxes(k);

    isPointMode = false;
    
    % cpMulAxes is the zoom origin for multiple axes if any.
    if k > 1
        origin = cpMulAxes(k-1,:);
    end
    
    % Get the current limits.
    currentXLim = get(cAx, 'XLim');
    newXLim = currentXLim;
    currentYLim = get(cAx, 'YLim');
    newYLim = currentYLim;
    
    % Perform zoom operation based on zoom mode.
    switch(get(hZoom,'Constraint')),
        case 'none',
            %
            % Both x and y zoom.
            % RBBOX - lines:
            % 
            %          2
            %    o-------------
            %    |            |
            %  1 |            | 4
            %    |            |
            %    --------------
            %          3
            %
            
            % Determine the end point of zoom operation.
            
            % Get current point.
            cp = get(cAx, 'CurrentPoint'); cp = cp(1,1:2);
            xcp = cp(1);
            ycp = cp(2);
            
            % Uncomment to clip rbbox zoom to current axes limits
            %if xcp > currentXLim(2),
            %    xcp = currentXLim(2);
            %end
            %if xcp < currentXLim(1),
            %    xcp = currentXLim(1);
            %end
            %if ycp > currentYLim(2),
            %    ycp = currentYLim(2);
            %end
            %if ycp < currentYLim(1),
            %    ycp = currentYLim(1);
            %end
            
            endPt = [xcp ycp];
            
            % Determine the mode: POINT or RBBOX.
            if (dpixel(1) <= POINT_MODE_MAX_PIXELS) ...
                 && (dpixel(2) <= POINT_MODE_MAX_PIXELS)
                isPointMode = true;
            end
            newXLim(k,:) = localGetNewXLim(cAx,k,isPointMode,xcp,origin,endPt);
            newYLim(k,:) = localGetNewYLim(cAx,k,isPointMode,ycp,origin,endPt);

        case 'horizontal',
            % x only zoom.
            % RBBOX - lines (only 1-3 used):
            %   
            %    |     1      |
            %  2 o------------| 3 
            %    |            |
            %             
            %
            
            % Determine the end point of zoom operation.
            cp = get(cAx, 'CurrentPoint'); cp = cp(1,1:2);
            xcp = cp(1);
            
            % Uncomment to clip rbbox zoom to current axes limits
            % if xcp > currentXLim(2),
            %    xcp = currentXLim(2);
            % end
            % if xcp < currentXLim(1),
            %    xcp = currentXLim(1);
            % end
            
            endPt = [xcp origin(2)];
            
            % Determine mode: POINT or RBBOX.
            if dpixel(1)  <= POINT_MODE_MAX_PIXELS
                isPointMode = true;
            end

            newXLim(k,:) = localGetNewXLim(cAx,k,isPointMode,xcp,origin,endPt);
            newYLim(k,:) = currentYLim;
            
        case 'vertical',
            % y only zoom.
            % RBBOX - lines (only 1-3 used):
            %    2
            %  --o--  
            %    |
            %  1 |
            %    |
            %  -----           
            %    3
            %
            
            % Determine the end point of zoom operation.
            
            % End pt is the 2nd point of line 1.
            cp = get(cAx, 'CurrentPoint'); cp = cp(1,1:2);
            ycp = cp(2);
            
            % Uncomment to clip rbbox zoom to current axes limits
            % if ycp > currentYLim(2),
            %    ycp = currentYLim(2);
            % end
            % if ycp < currentYLim(1),
            %    ycp = currentYLim(1);
            % end
            
            endPt = [origin(1) ycp];
            
            % Determine mode: POINT or RBBOX.
            if dpixel(2) <= POINT_MODE_MAX_PIXELS
                isPointMode = true;
            end

            newYLim(k,:) = localGetNewYLim(cAx,k,isPointMode,ycp,origin,endPt);
            newXLim(k,:) = currentXLim; 
          
    end % switch
    
    % Actual zoom operation
%========================================================
%  Part of modification for ADDAXIS commands
ystart = get(gca,'ylim');
%========================================================    
    axis(cAx,[newXLim(k,:),newYLim(k,:)]);   
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

        
end % for

% Delete the RBBOX lines.
if ishandle(hLines)
    scribefiglisten(hFig,'off');
    delete(hLines);
    scribefiglisten(hFig,'on');
end

% Call drawnow to flush axes update since the next line, create2Dundo,
% will take a long time when called for the first time (class loading).
drawnow expose
    
if length(currentAxes)==1
    % This runs slow the first time due to UDD class loading 
    create2Dundo(hZoom,cAx,[currentXLim,currentYLim],[newXLim(k,:),newYLim(k,:)]);
end

%----------------------------------------------------%
function [newXLim] = localGetNewXLim(hAxes,k,isPointMode,xcp,origin,endPt)
% ToDo: clean up input arguments

% Calculate the new X-Limits.
if ~isPointMode % Bounding Box Mode.
    x_lim = [origin(1) endPt(1)];
    if x_lim(1) > x_lim(2),
           x_lim = x_lim([2 1]);
    end
else % Point Mode.
    % Divide the vertical into 5 divisions.
    x_lim = get(hAxes, 'XLim'); 
    if strcmp(get(hAxes, 'XScale'), 'log'),
         diff_log = diff(log10(x_lim))/5;                    
         xcp_log = log10(xcp);
         xmin = 10.^(xcp_log-diff_log);
         xmax = 10.^(xcp_log+diff_log);
         x_lim = [xmin,xmax];                    
     else
         XDiff = (x_lim(2) - x_lim(1)) / 5;
         x_lim = [xcp - XDiff, xcp + XDiff];
     end
end  
            
% Set new Xlimits.
% NOTE: Check that the limits aren't equal.  This happens
%   at very small limits.  In this case, we do nothing.
%
if abs(x_lim(1) - x_lim(2)) > 1e-10*(abs(x_lim(1)) + abs(x_lim(2)))
     newXLim(k,:) = x_lim;                
else
     newXLim = xlim(hAxes);
end


%----------------------------------------------------%
function [newYLim] = localGetNewYLim(hAxes,k,isPointMode,ycp,origin,endPt)
% ToDo: clean up input arguments

% Calculate the new Y-Limits.
if ~isPointMode % Bounding Box Mode.
    y_lim = [origin(2) endPt(2)];
    if y_lim(1) > y_lim(2),
           y_lim = y_lim([2 1]);
    end
else % Point Mode.
    % Divide the vertical into 5 divisions.
    y_lim = get(hAxes, 'YLim'); 
    if strcmp(get(hAxes, 'YScale'), 'log'),
        diff_log = diff(log10(y_lim))/5;                    
        ycp_log = log10(ycp);
        ymin = 10.^(ycp_log-diff_log);
        ymax = 10.^(ycp_log+diff_log);
        y_lim = [ymin,ymax];                    
     else
         YDiff = (y_lim(2) - y_lim(1)) / 5;
         y_lim = [ycp - YDiff, ycp + YDiff];
     end
end  
            
% Set new Ylimits.
% NOTE: Check that the limits aren't equal.  This happens
%   at very small limits.  In this case, we do nothing.
%
if abs(y_lim(1) - y_lim(2)) > 1e-10*(abs(y_lim(1)) + abs(y_lim(2)))
     newYLim(k,:) = y_lim;                
else
     newYLim = ylim(hAxes);
end

