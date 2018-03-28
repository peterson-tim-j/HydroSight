_HydroSight_ is a highly flexible statistical toolbox for quantitative hydrogeological insights. It comprises of a powerful groundwater hydrograph time-series modelling and simulation framework plus a data quality analysis module. Multiple models can be built for one bore, allowing statistical identification of the dominant processes, or 100's of bores can be modelled to quantify aquifer heterogeneity. This flexibility has allowed many users to develop many novel applications such as:

1. Separations of the impacts from pumping and drought over time.
2. Probabilistic estimation of aquifer hydraulic properties.
3. Estimation of the impacts of re-vegetation on groundwater level.
4. Exploration of groundwater management scenarios.
5. Interpolation and extrapolation irregularly observed hydrograph at a daily time-step.

The toolbox can be used from a highly flexible and stand-alone graphical user interface (available [here](https://github.com/peterson-tim-j/HydroSight/releases)) or programmatically from within Matlab 2014b (or later). 

### What's New
The next release of the stand alone application is out! It contains some exciting new features:
- probabilistic calibration (using DREAM) and parameter estimation.
- calibration using Xeon Phi co-processors.
- offloading of calibration to a cluster (only from within Matlab).
- Google Groups discussion (https://groups.google.com/forum/#!forum/hydrosight). Join now to share ideas, project and issues. 

### Getting Started
To begin using the stand-alone application, simply download and install the above Windows 64bit executable  (available [here](https://github.com/peterson-tim-j/HydroSight/releases)). Below is a screenshot of the GUI. On the left a table shows a list of models available for simulation (only one model is listed) and on the right time-series simulation plots showing the decomposition of the groundwater hydrograph to the influences of climate and pumping extractions.

![Sceenshot of GUI](https://cloud.githubusercontent.com/assets/8623994/12466302/b533a804-c027-11e5-8d66-ff1b69e56616.png)

To being using the toolbox from within Matlab 2014b (or later), change the current path (within MatLab) to the location where the source code was been saved. To use the GUI from within Matlab, simply input the following command into the Matlab command window: GST. Once the GUI opens, use the Help menu to access the required documentation or open one of the example projects. 

To use the toolbox programmatically, please first read the model documentation. It can be accessed by opening MatLab and changing the current path (within MatLab) to the 'algorithms' folder. Next, enter the commands below from within the MatLab command window. The documentation that should appear contains details of algorithms and commands to programmatically build an example model. See the references below for technical details.
```
> addpath(genpath(pwd));
> doc GroundwaterStatisticsToolbox;
```

###About the Researchers.
_HydroSight_ has been developed by the following academics at the University of Melbourne:

1. Dr. Tim Peterson
2. Prof. Andrew Western
3. Dr. Vahid Shapoori
4. Dr. Eleanor Gee

To find out more about the research within the group, or relevant publications, see [Research Group](http://www.ie.eng.unimelb.edu.au/research/water/index.html), [Research Gate](https://www.researchgate.net/profile/Tim_Peterson7) or [Google Scholar](http://scholar.google.com.au/citations?user=kkYJLF4AAAAJ&hl=en&oi=ao)

Alternatively, to stay connected with developments and new versions join us at [LinkedIn](https://au.linkedin.com/pub/tim-peterson/81/40/739)

###Acknowledgements
_HydroSight_ has been generously supported by the following organisations:

- The Australian Research Council grants LP0991280, LP130100958.
- The Bureau of Meteorology (Aust.)
- The Department of Environment, Land, Water and Planning (Vic., Aust.)
- The Department of Economic Development, Jobs, Transport and Resources (Vic., Aust.)
- [Power and Water Corporation, N. T., Aust.](http://www.powerwater.com.au/)

###Disclaimer
_HydroSight_ is provided on an "as is" basis and without any representation as to functionality, performance, suitability or fitness for purpose. You acknowledge and agree that, to the extent permitted under law, and subject to Disclaimers, the University of Melbourne makes no representations, warranties or guarantees:

1. in relation to the functionality, performance, availability, suitability, continuity, reliability, accuracy, currency or security of the Program; or
2. that the Program is free from computer viruses or any other defect or error which may affect Your program or systems or third party software or systems.

You further acknowledge and agree that the University of Melbourne has no obligation to (and makes no representation that it will) maintain or update, or correct any errors or defects in, the Program.

###License
_HydroSight_ is licensed under the open-source license GPL3.0 (or later). See the following for details: http://www.gnu.org/licenses/gpl-3.0.en.html

The following components of _HydroSight_ were developed by others and each has its own license. These components and their licence are within the source code folder: algorithms > calibration.

- SPUCI.m calibration algorithm and its associated functions.
- cmaes.m calibration algorithm.
- variogram.m, variogramfit.m and fminsearchbnd.m for estimating and fitting variograms.
- ipdm.m for calculating the inter-point distance used in the GST temporal kriging.
- GUI Layout Toolbox 2.1 for constructing the panels of the GUI
- uical.m for displaying a graphical calendar within the GUI.

###References:
- Peterson T. J and Western A. W., (2014), Nonlinear Groundwater time-series modeling of unconfined groundwater head, Water Resources Research, DOI: 10.1002/2013WR014800 [PDF copy](https://github.com/peterson-tim-j/Groundwater-Statistics-Toolbox/files/98498/Peterson.and.Western.2014.Nonlinear.time-series.modeling.of.head.pdf)

- Shapoori V., Peterson T.J. , Western A.W. and Costelloe J. F. (2015a). Decomposing groundwater head variations into meteorological and pumping components: a synthetic study, Hydrogeology Journal, DOI: 10.1007/s10040-015-1269-7 [PDF copy](https://github.com/peterson-tim-j/Groundwater-Statistics-Toolbox/files/98513/Shapoori_2015A.pdf)

- Shapoori V., Peterson T.J. , Western A.W. and Costelloe J. F. (2015b). Top-down groundwater hydrograph time-series modeling for climate-pumping decomposition, Hydrogeology Journal, 23(4), 819-83, DOI: 10.1007/s10040-014-1223-0 [PDF copy](https://github.com/peterson-tim-j/Groundwater-Statistics-Toolbox/files/98517/Shapoori_2015B.pdf)

- Shapoori V., Peterson T.J. , Western A.W. and Costelloe J. F. (2015c). Estimating aquifer properties using groundwater hydrograph modeling. Hydrological Processes, 29: 5424–5437. DOI: 10.1002/hyp.10583. [PDF copy](https://github.com/peterson-tim-j/Groundwater-Statistics-Toolbox/files/98508/Shapoori.et.al.2015b.Estimating.aquifer.properties.pdf)

![Corporate logos](https://cloud.githubusercontent.com/assets/8623994/15106237/57553be6-160b-11e6-90fc-53826efb4604.png)
