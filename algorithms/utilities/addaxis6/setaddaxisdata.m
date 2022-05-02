function setaddaxisdata(axishandle,data,flag);
%  setaddaxisdata(axishandle,data,flag)
%
%  internal function for addaxis to update the added axes handles and plot 
%  handles, or to save the original figure position.
  
  if nargin<3, flag = 'axisdata'; end;
  
  aad = getappdata(axishandle,'addaxis_data');
  switch flag
   case 'axisdata'
    aad.axisdata = data;
   case 'resetinfo'
    aad.resetinfo = data;
   case 'ystart'
    aad.ystart = data;
   otherwise
  end
  
  setappdata(axishandle,'addaxis_data',aad);
  