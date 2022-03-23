%  Removed debugging line 11/15/2005

%  Added zoom support for version R14SP2 11/24/2005

%  Updated installation notes 11/24/2005

%  In addaxisplot, only automatically change color to the axis color, if no
%  other color specified  11/28/2005

%  changed implementation to use appdata instead of userdata. (setaddaxisdata.m, getaddaxisdata.m)  
%  Also, added addaxisreset to delete added axes and reset the parent axis
%  and addaxisset which is used to set the ylimits of any axis after plotting  12/23/05

%  changed splot.m to aa_splot.m to avoid the same name as splot.m that already 
%  exists in another toolbox.  2/15/06

%  changed addaxislabel so it doesn't matter if you use it addaxislabel(axis_number,label)
%  or addaxislabel(label,axis_number) 2/15/06

%  Zoom support for R2010a (maybe later versions as well)


Files

addaxis.m
addaxisplot.m
addaxislabel.m
addaxisset.m
addaxisreset.m
getaddaxisdata.m
setaddaxisdata.m
aa_splot.m
addaxis_zoom_post.m
addaxis_zoom_pre.m



zoom_R11.1_.m     

zoom_R14SP2_.m
buttonupfcn2D_R14SP2_.m


Installation Notes:
-------------------------------------------

Put the addaxis files and aa_splot anywhere in your matlab path.

Finally updated added axis zoom support for R2010a and maybe later versions using the 
ActionPreCallback and ActionPostCallback


-------------------------------------------
Zoom modifications not necessary for R2010a and maybe later or earlier versions

addaxis will work fine, and zoom properly except the axis limits of the added 
axes will not update unless the following modifications to the zoom function(s) 
are made.  These have been tested in R11.1 and R14SP2.  The R14 files should 
work in later versions.  If not, please let me know.


Zoom modifications
------------------------------------------

For version R11.1, inside <matlab_directory>/toolbox/matlab/graph2d/
rename zoom.m to zoom_orig.m, copy zoom_R11.1_.m into the directory
and rename it zoom.m.  

For version R14SP2, inside <matlab_diretory>/toolbox/matlab/graph2d/
rename zoom.m to zoom_orig.m, copy zoom_R14SP2_.m into the directory
and rename it zoom.m.  ALSO, inside
<matlab_directory>/toolbox/matlab/graphics/@graphics/@zoom/  
rename buttonupfcn2D.m to buttonupfcn2D_orig.m, copy
buttonupfcn2D_R14SP2.m into the directory and rename it
buttonupfcn2D.m 


The modifications to the zoom capability in matlab simply get the
ylimits before and after any zoom operation is completed and then
scales the added axes limits accordingly.  





