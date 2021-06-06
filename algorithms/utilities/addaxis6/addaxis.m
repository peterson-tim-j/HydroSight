function addaxis(varargin)
%ADDAXIS  adds an axis to the current plot
%  you can add as many axes as you want.
%
%  usage:  
%  use it just like plot, except, you need to specify the abscissa
%  and the third input argument should be the axis limits, if at all.  
%
%  example:  
%
%  x = 0:.1:4*pi;
%  plot(x,sin(x));
%  addaxis(x,sin(x-pi/3));
%  addaxis(x,sin(x-pi/2),[-2 5],'linewidth',2);
%  addaxis(x,sin(x-pi/1.5),[-2 2],'v-','linewidth',2);
%  addaxis(x,5.3*sin(x-pi/1.3),':','linewidth',2);
%
%  addaxislabel(1,'one');
%  addaxislabel(2,'two');
%  addaxislabel(3,'three');
%  addaxislabel(4,'four');
%  addaxislabel(5,'five');
%
%  addaxisplot(x,sin(x-pi/2.3)+2,3,'--','linewidth',2);
%  addaxisplot(x,sin(x-pi/1),5,'--','linewidth',2);
%
%  legend('one','two','three','four','five','three-2','five-2');
%  
%
%  
%  Also requires AA_SPLOT.m, a modified plot function that automatically
%  changes colors everytime you plot.  
%
%  See also
%  ADDAXISPLOT, ADDAXISLABEL, AA_SPLOT 

%  NOTE:  the 'userdata' of the main axis holds a cell array for each axis
%         each cell holds a vector.  The first element is the axis handle
%         the rest are handles to lines that correspond to that axis lines.  
  
  
  %  get current axis
  cah = gca;
  
  %  new for R2010a
  hzoom = zoom;
  set(hzoom,'ActionPostCallback',@addaxis_zoom_post);
  set(hzoom,'ActionPreCallback',@addaxis_zoom_pre);

  if nargin>=3 & ~isstr(varargin{3}) 
    yl2 = varargin{3};
    indkeep = setdiff(1:nargin,3);
    [varargintemp{1:nargin-1}] = deal(varargin{indkeep});
    varargin = varargintemp;
  end
  
  %  assume existing plot has axes scaled the way you want.
  yl = get(cah,'ylim');
  cpos = get(cah,'position');
  set(cah,'box','off');
  
  %  get userdata of current axis.  this will hold handles to
  %  additional axes and the handles to their corresponding plots
  %  in the main axis
%  axh = get(cah,'userdata');
  axh = getaddaxisdata(cah,'axisdata');

  ledge = cpos(1);
  if length(axh)>=1
    if length(axh)/2 == round(length(axh)/2)
      rpos = get(axh{end-1}(1),'position');
      redge = rpos(1);
      lpos = get(axh{end}(1),'position');
      ledge = lpos(1);
    else
      rpos = get(axh{end}(1),'position');
      redge = rpos(1);
      if length(axh)>1
	lpos = get(axh{end-1}(1),'position');
	ledge = lpos(1);
      end    
    end   
  else
    redge = cpos(3)+cpos(1);
    ledge = cpos(1);
  end
  
  totwid = redge-ledge;
      
%  assume axes are added on right, then left, then right, etc.
  numax = length(axh)+1;

  
  %  parameters setting axis separation
  axcompleft=0.12;
  if numax == 1
    axcompright = 0.0;
  else 
    axcompright = 0.12;
  end
  
  if numax/2 == round(numax/2)
    side = 'left';
    xpos = ledge-axcompleft*totwid;
  else
    side = 'right';
    xpos = redge+axcompright*totwid;
  end

  h_ax = axes('position',[xpos, cpos(2), cpos(3)*.015, cpos(4)]);
%  plot in new axis to get the automatically generated ylimits
  hplt = plot(varargin{:});  

  if ~exist('yl2')
    yl2 = get(h_ax,'ylim');
  end


  set(h_ax,'yaxislocation',side);
  set(h_ax,'color',get(gcf,'color'));
  set(h_ax,'box','off');
  set(h_ax,'xtick',[]);
  set(hplt,'visible','off');

  set(h_ax,'ylim',yl2);


%  rescale all y-values
  y = varargin{2};
  
  y = (y-yl2(1))./(yl2(2)-yl2(1)).*(yl(2)-yl(1))+yl(1);
  
  varargin{2} = y;
  axes(cah)
  hplts = aa_splot(varargin{:});
  set(gca,'ylim',yl);
  
  %  store the handles in the axis userdata
  axh{length(axh)+1} = [h_ax;hplts];
% set(cah,'userdata',axh);  
  setaddaxisdata(cah,axh,'axisdata');
  set(cah,'box','off');
  
  %  set the axis color if a single line was added to the plot
  if length(hplts)==1
    set(h_ax,'ycolor',get(hplts,'color'));
  end
 
  %  Now, compress main axis so the extra axes don't interfere
  %  or dissappear
  
  %  get axis handles
  axhand = cah;
  postot(1,:) = get(cah,'position');
  for I = 1:length(axh)
    axhand(I+1) = axh{I}(1);
    postot(I+1,:) = get(axhand(I+1),'position');
  end
  
  if numax/2 == round(numax/2)
%    side = 'left';

    set(cah,'position',[postot(1,1)+axcompleft*totwid,postot(1,2), ...
			postot(1,3)-axcompleft*totwid, postot(1,4)]);
    indshift = [2:2:size(postot,1)-1];
    for I = 1:length(indshift)
      set(axhand(indshift(I)+1),'position',[postot(indshift(I)+1,1)+axcompleft*totwid, ...
		                            postot(indshift(I)+1,2:end)]);
    end
  
  else
 %   side = 'right';

    set(cah,'position',[postot(1,1),postot(1,2),postot(1,3)-axcompright*totwid,postot(1,4)]);
    indshift = [1:2:size(postot,1)-1];
    for I = 1:length(indshift)
      set(axhand(indshift(I)+1),'position',[postot(indshift(I)+1,1)-axcompright*totwid, ...
		    postot(indshift(I)+1,2:end)]);
    end
 
  end
