function retdata = getaddaxisdata(axishandle,flag)
%  retdata = getaddaxisdata(axishandle,flag)
%
%  internal function for addaxis
%  axishandle is handle to the parent axis onto which other axes were added
%  flag is either 'axisdata', or 'resetinfo' to return the added axis
%  handles and plot handles, or the position of the figure before axes
%  were added. 
  
  if nargin<2, flag = 'axisdata'; end;
  
  aad = getappdata(axishandle,'addaxis_data');
  if length(aad)>=1
    switch flag
     case 'axisdata'
      retdata = aad.axisdata;
     case 'resetinfo'
      retdata = aad.resetinfo;
     case 'ystart'
      retdata = aad.ystart;
     otherwise
      retdata = 0;
    end
  else
    retdata = aad;
    aadnew.resetinfo = get(axishandle,'position');
    aadnew.axisdata = [];
    setappdata(axishandle,'addaxis_data',aadnew);
  end
  