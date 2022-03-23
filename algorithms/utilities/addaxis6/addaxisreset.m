function addaxisreset(axishandle)
%  addaxisreset(axishandle)
%  
%  axishandle is the handle to the parent axis (default = current axis)
%  removes all added axes and deletes the addaxis_data appdata
%
%  Example
%  x = 0:10;
%  plot(x,x)
%  addaxis(x,x.^1.5,'-o');
%  addaxis(x,x.^.5,'-s','linewidth',2);
%  'press any key to continue'
%  pause
%  addaxisreset
%  'press any key to continue'
%  pause
%  cla


  
  if nargin < 1, axishandle = gca;end;
  
  aad = getappdata(axishandle,'addaxis_data');

  if length(aad)>0
    figpos = aad.resetinfo;
    axisdata = aad.axisdata;
 
%  delete added axes
    for I = 1:length(axisdata)
      delete(axisdata{I}(1));
    end

%  restore original axis position    
    set(axishandle,'position',figpos);
    
%  remove the appdata addaxis_data.    
    rmappdata(axishandle,'addaxis_data');    
  end
  
%    focus = gca;
%    axes(axishandle);
%    cla;
%    axes(focus);