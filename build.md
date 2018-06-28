## Introduction
This page explains how to build exposure render with Visual Studio 2017

## Dependencies
Exposure render depends on: CUDA, Qt and VTK.

Versions used in this update:
* CUDA 9.2
* Qt 5.11.1
* VTK 7.1.1
* Microsoft Visual Studio 2017

### CUDA
You can skip this step if you already have the CUDA SDK and toolkit installed

The necessary installers can be downloaded from: http://developer.nvidia.com/cuda-toolkit-40
* Download and install the GPU Computing SDK
* Download and install the CUDA Toolkit
* Download and install the developer drivers

### Qt
Skip this step if you already have installed Qt

* Download the Qt installer from: https://www.qt.io/download-qt-installer
* Under Qt->5.11.1, Make sure you check the box for MSVC 2017 64-bit
* Add an environment variable called QTDIR and set it to \<install dir\>\5.11.1\msvc2017_64

### VTK
VTK must be compiled with Qt support
* Download the VTK 7.1.1 sources from the VTK website: http://www.vtk.org/VTK/resources/software.html
* Extract the zip file (for instance c:\VTK\7.1.1)
* Run CMAKE and set the source dir to the VTK root dir
* Make sure to use the 64-bit compiler
* Make sure to check the Qt check box in the VTK settings
* For the GUI to run you need to build VTK with GUI support
* See https://www.vtk.org/Wiki/VTK/Configure_and_Build for additional info/help
* You might also consider to build the examples
* Generate the Visual Studio 2017 solution files
* Open the generated solution and build it, RelWithDebugInfo is advised


### Exposure Render
* Run CMAKE and set the source dir to the Exposure Render Source dir
* Make sure to select the 64-bit compiler.
* After building, copy the presets directory from the source dir to the build dir.

## Notes
* It might be required to update the maximum MVC version number in CUDA code.:
	* In \<CUDA_install_dir\>\NVIDIA GPU Computing Toolkit\CUDA\v9.2\include\crt\host_config.h
	* Change the right hand side of the equation: "#if _MSC_VER < 1600 || _MSC_VER > 1914" to a version number high enough to include your used Visual Studio version
* In order to run Exposure Render from Visual Studio, you might have to set ExposureRender as the startup project.
* Executable might not start due to missing DLL's:
	* Copy all the dll files from \<VTK_build_dir\>bin\Debug to \<ExposureRender_build_dir\>\debug
	* Copy Qt5Cored, Qt5Guid, Qt5Widgetsd, Qt5Xmld dll from \<Qt_install_dir\>\5.11.1\msvc2017_64\bin to \<ExposureRender_build_dir\>\debug
* Examples folder, ReadMe.txt and contets of presets folder from Exposure Source directory might also have to be copied to \<ExposureRender_build_dir\>\debug