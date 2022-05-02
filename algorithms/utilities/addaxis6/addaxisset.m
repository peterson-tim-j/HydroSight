function addaxisset(yl2,axisnumber)
%  addaxisset(new_ylim, axisnumber)
%
%  new_ylim = two element vector with the new y-limits
%  axisnumber = number of axis to be scaled (parent axis = 1)
%  
%  Example
%  x = 0:10;
%  plot(x,x)
%  addaxis(x,x.^2,'-o');
%  addaxisplot(x,x.^1.5,2,'-s','linewidth',2);
%  'press any key to continue'
%  pause
%  addaxisset([0 200],2);
%  'press any key to continue'
%  pause
%  addaxisset([0 15],1);
%  'press any key to continue'
%  pause
%  addaxisset([0 100],2);
  
  cah = gca;
  yp = get(cah,'ylim');
  
  axh = getaddaxisdata(cah,'axisdata');
  
  if axisnumber > 1
    axhan = axh{axisnumber-1}(1);
    plthan = axh{axisnumber-1}(2:end);
    
    yl = get(axhan,'ylim');  %  original ylimits
    set(axhan,'ylim',yl2);
    
    for I = 1:length(plthan)
      y = get(plthan(I),'ydata');
%  rescale y-values
      ynew = (((y-yp(1))./(yp(2)-yp(1)).*(yl(2)-yl(1))+yl(1))-yl2(1))./...
	     (yl2(2)-yl2(1)).*(yp(2)-yp(1))+yp(1);
      set(plthan(I),'ydata',ynew);
    end
    set(cah,'ylim',yp);
  else
%  rescaling parent axis.  All other axes need to be scaled
    ystart = yp;
    yend = yl2;
    for I = 1:length(axh)
      axhan = axh{I}(1);
      axyl = get(axhan,'ylim');
      axylnew(1) = axyl(1)+(yend(1)-ystart(1))/(ystart(2)-ystart(1)).*...
	  (axyl(2)-axyl(1));
      axylnew(2) = axyl(2)-(ystart(2)-yend(2))/(ystart(2)-ystart(1)).*...
	  (axyl(2)-axyl(1));
      set(axhan,'ylim',axylnew);
    end
    set(cah,'ylim',yend);
  end
  

    
  