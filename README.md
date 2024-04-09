<img align="left" width="160" height="160" src="https://github.com/peterson-tim-j/HydroSight/blob/master/GUI/icons/icon_webpage.png">  

# _HydroSight_: _Open-source data-driven hydrogeological insights_
 
[![Testing](https://github.com/peterson-tim-j/HydroSight/actions/workflows/testHydroSight.yml/badge.svg)](https://github.com/peterson-tim-j/HydroSight/actions/workflows/testHydroSight.yml) [![Codecov](https://img.shields.io/codecov/c/github/peterson-tim-j/HydroSight?logo=CODECOV)](https://app.codecov.io/github/peterson-tim-j/HydroSight) [![GitHub release](https://img.shields.io/github/release/peterson-tim-j/HydroSight)](https://github.com/peterson-tim-j/HydroSight/releases/) [![View HydroSight on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://au.mathworks.com/matlabcentral/fileexchange/48546-hydrosight) [![Github All Releases](https://img.shields.io/github/downloads/peterson-tim-j/HydroSight/total.svg?style=flat)]()   [![GitHub license](https://img.shields.io/github/license/peterson-tim-j/HydroSight)](https://github.com/peterson-tim-j/HydroSight/blob/master/LICENSE) [![GitHub forks](https://img.shields.io/github/forks/peterson-tim-j/HydroSight)](https://github.com/peterson-tim-j/HydroSight/network) [![GitHub stars](https://img.shields.io/github/stars/peterson-tim-j/HydroSight)](https://github.com/peterson-tim-j/HydroSight/stargazers)

HydroSight is statistical toolbox for data-driven insights into groundwater dynamics and aquifer properties. Many hundreds of bores can be easily analysed, all without any programming, to quantify:

* drivers of groundwater trends, e.g. climate and pumping ([Shapoori et al., 2015a](https://github.com/peterson-tim-j/HydroSight/blob/master/documentation/html/papers/Shapoori_2015A.pdf)) and landuse change ([Peterson and Western, 2014](https://doi.org/10.1029/2017WR021838)).
* recharge over time [Peterson et al., 2019](https://doi.org/10.1111/gwat.12946)).
* aquifer hydraulic properties ([Shapoori et al., 2015c](https://github.com/peterson-tim-j/HydroSight/blob/master/documentation/html/papers/Shapoori_2015C.pdf), [Peterson et al., 2019](https://doi.org/10.1111/gwat.12946))
* statistical identification of the major groundwater processes ([Shapoori et al., 2015b](https://github.com/peterson-tim-j/HydroSight/blob/master/documentation/html/papers/Shapoori_2015B.pdf)).
* interpolate or extrapolate hydrographs to a regular time step ([Peterson & Western, 2018](https://doi.org/10.1029/2017WR021838).
* simulate groundwater level under different climate or, say, pumping scenarios.
* hydrograph monitoring errors and outliers ([Peterson et al., 2018](https://doi.org/10.1007/s10040-017-1660-7)).

## Installation Options

_HydroSight_ is operating system independent and has been tested on Windows 10+, Mac and Linux (Ubuntu 20.04 LTS). There are four installation options:
1. Stand-alone app within Windows. The latest .exe is [available here](https://github.com/peterson-tim-j/HydroSight/releases).
1. Install _Hydrosight_ Matlab source code by (i) downloading the [source code](https://github.com/peterson-tim-j/HydroSight/releases), (ii) unzipping the downloaded file, (ii) setting the Matlab _Current Folder_ to where the file was unzipped and (iv) entering ``HydroSight`` into the Matlab _Command Window_.
1. Install _Hydrosight_ from within Matlab using the _Add-Ons_ menu item and searching for _HydroSight_. From the _Add_ button select _Add to Matlab_. Once installed, enter ``HydroSight`` into the Matlab _Command Window_. 
1. Compile your own stand-alone app from within Matlab by (i) downloading the [source code](https://github.com/peterson-tim-j/HydroSight/releases) and (ii) running the command: ``makeStandaloneHydroSight()``

For futher details see the [installation wiki page](https://github.com/peterson-tim-j/HydroSight/wiki).

## Examples
Multiple examples are built into the _HydroSight_ GUI, each highlighting aspects of the above papers. Soon, each example will be supported by online videos. In the meantime major aspects of the graphical interface and the algorithms are outlined on the [wiki page](https://github.com/peterson-tim-j/HydroSight/wiki).

_HydroSight_ can also be run from the Matlab command window. For an example of this [see here](https://github.com/peterson-tim-j/HydroSight/blob/master/algorithms/models/TransferNoise/Example_model/example_TFN_model.m).

## What does _HydroSight_ look like?

The _HydroSight_ graphical interface includes tabs for each step in the modelling of groundwater hydrographs:
1. Project documentation.
2. Hydrograph outlier detection.
1. Time-series model construction, specifically defining the data and the form of the model.
1. Model calibration and tools to examine the internal dynamics of the calibrated model, e.g. recharge. The screenshot below shows this tab and an estimate of the annual groundwater recharge.  
1. Model simulations, allowing hydrograph decomposition, exploration of scenarios (e.g. different climate or pumping), hindcasting and interpolation.

![_HydroSight_ Recharge estimation](https://user-images.githubusercontent.com/8623994/190363849-d6e8f457-7891-4213-8ace-71076e69e4f6.png)

## Contributing

_HydroSight_ is an ongoing research project and that depends upon [your support](https://github.com/peterson-tim-j/HydroSight/wiki/Support#giving-support-to-hydrosight). Two easy ways to support us are:
1. Give us a GitHub ⭐. 
2. Cite the relevant papers (using the "Cite Project" option within the GUI). 

And, if _HydroSight_ doesn't do what you need then [Support](https://github.com/peterson-tim-j/HydroSight/wiki/Support#giving-support-to-hydrosight) gives more options.