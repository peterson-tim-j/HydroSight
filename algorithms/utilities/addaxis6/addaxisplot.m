function varargout = addaxisplot(varargin)
%ADDAXISPLOT adds a plot to an axis.
%
%  handle_to_plots = addaxisplot(x,y,axis_number,...);
%
%  See also
%  ADDAXIS, ADDAXISLABEL, AA_SPLOT 
  
  
%  get current axis
  cah = gca;
%  axh = get(cah,'userdata');
  axh = getaddaxisdata(cah,'axisdata');  
  
  if nargin>=3 & ~isstr(varargin{3}) 
    plotaxis = varargin{3};
    indkeep = setdiff(1:nargin,3);
    [varargintemp{1:nargin-1}] = deal(varargin{indkeep});
    varargin = varargintemp;
  else
    plotaxis = 1;
  end
  
  
%  get axis handles
  axhand = cah;
  for I = 1:length(axh)
    axhand(I+1) = axh{I}(1);
  end  

%  get the limits for the axis that the plot will go with
  yl = get(axhand(1),'ylim');
  yl2 = get(axhand(plotaxis),'ylim');

  y = varargin{2};
  y = (y-yl2(1))./(yl2(2)-yl2(1)).*(yl(2)-yl(1))+yl(1);
  varargin{2} = y;
  
%  set current axis back to the main axis
  axes(cah);
  hplts = aa_splot(varargin{:});
  
%  Parse varargin to see if a color was chosen, otherwise set
%  color equal to plotaxis
  changecolor = 1;
  coloroptions = ['b';'r';'m';'c';'g';'y';'w';'k'];
%  look at third input to plot if it exists, should be color/style string  
  if length(varargin)>2
     if isstr(varargin{3})
       for K = 1:length(coloroptions)
	 if ~isempty(findstr(varargin{3},coloroptions(K))) & ...
	       ~strcmp(varargin{3},'linewidth')
	   changecolor = 0;
	 end
       end
     end
  end
 
%  Now check to see if 'color' option is used  
  for I = 1:length(varargin)
    if isstr(varargin{I})
      if strmatch(lower(varargin{I}),'color')
	changecolor = 0;
      end
    end
  end
  

  if length(hplts)==1 & changecolor
    set(hplts,'color',get(axhand(plotaxis),'ycolor'));
  end
  set(gca,'ylim',yl);
  
  if plotaxis>1
    axh{plotaxis-1} = [axh{plotaxis-1};hplts];
    setaddaxisdata(cah,axh,'axisdata');
  end

  if nargout == 1
    varargout{1} = hplts;
  end
  