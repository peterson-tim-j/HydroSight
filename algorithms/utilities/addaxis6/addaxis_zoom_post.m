function addaxis_zoom_post(obj,evd)
  %  update the added axes with new zoom
  

%  disp('zoom post');
  
%====================================================================
%  This is a modification to accomodate the ADDAXIS commands.  
%  Check to see if add axis has been used and update the axes using 
%  the same scale factors.  (also put ystart = get(gca,'ylim'); 
%  before the zoom is started above)

yend = get(gca,'ylim');

%  ystart and yend are the starting and ending yaxis limits
%  now go through all of the added axes and scale their limits
%axh = get(gca,'userdata');
try
axh = getaddaxisdata(gca,'axisdata');
if ~isempty(axh)
  ystart = getaddaxisdata(gca,'ystart');
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

catch 
end

%  END of modification
%================================================================

  
  end
  