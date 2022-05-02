function varargout = addaxislabel(varargin)
%ADDAXISLABEL adds axis labels to axes made with ADDAXIS.m
%
%  handle_to_text = addaxislabel(axis_number, label);
%
%  See also
%  ADDAXISPLOT, ADDAXIS, SPLOT 
  
  if isstr(varargin{1}), 
     axnum = varargin{2}; 
     label = varargin{1};
  else
     label = varargin{2};
     axnum = varargin{1};
  end
  
%  get current axis
  cah = gca;
%  axh = get(cah,'userdata');
  axh = getaddaxisdata(cah,'axisdata');
  
%  get axis handles
  axhand = cah;
  postot(1,:) = get(cah,'position');
  for I = 1:length(axh)
    axhand(I+1) = axh{I}(1);
    postot(I+1,:) = get(axhand(I+1),'position');
  end  

%  set current axis to the axis to be labeled
axes(axhand(axnum));
htxt = ylabel(label);
set(htxt,'color',get(axhand(axnum),'ycolor'));

%  set current axis back to the main axis
axes(cah);

if nargout == 1
  varargout{1} = htxt;
end
