function addaxis_zoom_pre(obj,evd)
  %  update the added axes with new zoom
  
  
 % disp('zoom pre');
  
%========================================================
%  Part of modification for ADDAXIS commands
ystart = get(gca,'ylim');
%========================================================

  setaddaxisdata(gca,ystart,'ystart');
  end
  