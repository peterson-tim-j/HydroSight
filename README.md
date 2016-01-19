Groundwater-Statistics-Toolbox
==============================

The Groundwater Statistics Toolbox (GST) is a highly flexible statistical toolbox for deriving greater quantitative value from groundwater monitoring data. The toolbox can be used programmatically from within Matlab 2014b (or later) or using a highly flexible graphical user interface (GUI); which can also be ran as a stand alone Windows 64 bit application (see https://github.com/peterson-tim-j/Groundwater-Statistics-Toolbox/tree/master/standaloneApplication/Windows64bit) 

Currently, the toolbox contains a highly flexible groundwater hydrograph time-series modelling framework that facilitates the following:

1. Decomposition of hydrographs into individual drivers, such as climate and pumping
2. Decomposition of hydrographs into time-periods causing observed trends
3. Interpolation or extrapolation of the observed hydrograph.

To begin using the standalone application, simply download and install the above Windows 64bit executable. To being using the toolbox from within Matlab 2014b (or later), change the current path (within MatLab) to the location where the source code was been saved. To use the GUI from within Matlab, simply input the following command into the Matlab command window: GST. Once the GUI opens, use the Help menu to access the required documentation or open one of the example projects. 

To use the toolbox programmatically, please first read the model documentation. It can be accessed by opening MatLab and changing the current path (within MatLab) to the 'algorithms' folder. Next, enter the commands below from within the MatLab command window. The documentation that should appear contains details of algorithms and commands to programmatically build an example model. 

> addpath(genpath(pwd));
> doc GroundwaterStatisticsToolbox.

See the following papers for details of the time-series algorithms (available in folder documentation/html/papers):

- Peterson T. J and Western A. W., (2014), Nonlinear Groundwater time-series modeling of unconfined groundwater head, Water Resources Research, DOI: 10.1002/2013WR014800 

- Shapoori V., Peterson T.J. , Western A.W. and Costelloe J. F. (2015a). Decomposing groundwater head variations into meteorological and pumping components: a synthetic study, Hydrogeology Journal, DOI: 10.1007/s10040-015-1269-7

- Shapoori V., Peterson T.J. , Western A.W. and Costelloe J. F. (2015b). Top-down groundwater hydrograph time-series modeling for climate-pumping decomposition, Hydrogeology Journal, 23(4), 819-83, DOI: 10.1007/s10040-014-1223-0

- Shapoori V., Peterson T.J. , Western A.W. and Costelloe J. F. (2015c). Estimating aquifer properties using groundwater hydrograph modeling. Hydrological Processes, Accepted June 2015, DOI: 10.1002/hyp.10583


