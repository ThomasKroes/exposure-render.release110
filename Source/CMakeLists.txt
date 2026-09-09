#	Copyright (c) 2011, T. Kroes <t.kroes@tudelft.nl>
#	All rights reserved.
#
#	Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
#
#	- Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
#	- Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
#	- Neither the name of the <ORGANIZATION> nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
#
#	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

cmake_minimum_required(VERSION 3.20)

# C is enabled because nothing here is written in it: distributions that build
# VTK with MPI make VTK::mpi depend on MPI::MPI_C, and FindMPI cannot probe for
# its C component unless the consuming project enables the C language. Without
# it, find_package(VTK) fails at generate time on any such install.
project(ExposureRender
    VERSION     1.1.0
    DESCRIPTION "Direct volume rendering with physically based lighting"
    LANGUAGES   C CXX CUDA)

# ---------------------------------------------------------------------------
# Toolchain
# ---------------------------------------------------------------------------

# Qt 6 requires C++17; nvcc must agree or the shared headers in Geometry.h /
# Spectrum.h are compiled under two different language rules.
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_CUDA_STANDARD 17)
set(CMAKE_CUDA_STANDARD_REQUIRED ON)

set(CMAKE_POSITION_INDEPENDENT_CODE ON)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE RelWithDebInfo CACHE STRING "Build type" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS Debug Release RelWithDebInfo MinSizeRel)
endif()

# "native" builds for the GPU in this machine. Override for redistributable
# builds, e.g. -DCMAKE_CUDA_ARCHITECTURES="75;86;89".
if(NOT DEFINED CMAKE_CUDA_ARCHITECTURES)
    set(CMAKE_CUDA_ARCHITECTURES native)
endif()

# Replaces the hand-maintained moc header list and the PCH_QT4_WRAP_CPP macro
# that used to patch -fStable.h into every moc invocation.
set(CMAKE_AUTOMOC ON)

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------

find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets Xml Network OpenGLWidgets)

find_package(VTK REQUIRED COMPONENTS
    CommonCore
    CommonDataModel
    CommonExecutionModel
    FiltersExtraction
    FiltersSources
    GUISupportQt
    ImagingCore
    ImagingGeneral
    ImagingStatistics
    InteractionStyle
    IOImage
    RenderingCore
    RenderingFreeType
    RenderingVolume
    RenderingOpenGL2)

find_package(CUDAToolkit REQUIRED)

# ---------------------------------------------------------------------------
# Sources
# ---------------------------------------------------------------------------

set(ExposureRenderSources
    AboutDialog.cpp
    Aperture.cpp
    ApertureWidget.cpp
    Appearance.cpp
    AppearanceDockWidget.cpp
    AppearanceSettingsWidget.cpp
    Background.cpp
    BackgroundItem.cpp
    BackgroundWidget.cpp
    Camera.cpp
    CameraDockWidget.cpp
    CameraWidget.cpp
    Controls.cpp
    CudaUtilities.cpp
    EdgeItem.cpp
    Film.cpp
    FilmWidget.cpp
    Flags.cpp
    Focus.cpp
    FocusWidget.cpp
    Geometry.cpp
    GradientRamp.cpp
    GridItem.cpp
    HardwareWidget.cpp
    Histogram.cpp
    HistogramItem.cpp
    HttpGet.cpp
    InteractorStyleRealisticCamera.cpp
    Light.cpp
    LightWidget.cpp
    Lighting.cpp
    LightingDockWidget.cpp
    LightingWidget.cpp
    LightsWidget.cpp
    LoadSettingsDialog.cpp
    LogDockWidget.cpp
    LogWidget.cpp
    Logger.cpp
    Main.cpp
    MainWindow.cpp
    Node.cpp
    NodeItem.cpp
    NodePropertiesWidget.cpp
    NodeSelectionWidget.cpp
    Preset.cpp
    PresetsWidget.cpp
    Projection.cpp
    ProjectionWidget.cpp
    RenderThread.cpp
    Scene.cpp
    SettingsDockWidget.cpp
    Spectrum.cpp
    Stable.cpp
    StartupDialog.cpp
    StatisticsDockWidget.cpp
    StatisticsWidget.cpp
    Status.cpp
    Timing.cpp
    TransferFunction.cpp
    TransferFunctionItem.cpp
    TransferFunctionView.cpp
    TransferFunctionWidget.cpp
    UpdateWidget.cpp
    Utilities.cpp
    Variance.cpp
    VolumeMapper.cpp
    VtkWidget.cpp
    Core.cu)

# Listed so AUTOMOC scans them and so they appear in IDE project trees.
set(ExposureRenderHeaders
    AboutDialog.h
    Aperture.h
    ApertureWidget.h
    Appearance.h
    AppearanceDockWidget.h
    AppearanceSettingsWidget.h
    Background.h
    BackgroundItem.h
    BackgroundWidget.h
    Camera.h
    CameraDockWidget.h
    CameraWidget.h
    Controls.h
    CudaUtilities.h
    Defines.h
    Dll.h
    EdgeItem.h
    Enumerations.h
    Film.h
    FilmWidget.h
    Flags.h
    Focus.h
    FocusWidget.h
    Geometry.h
    GradientRamp.h
    GridItem.h
    HardwareWidget.h
    Histogram.h
    HistogramItem.h
    HttpGet.h
    InteractorStyleRealisticCamera.h
    Light.h
    LightWidget.h
    Lighting.h
    LightingDockWidget.h
    LightingWidget.h
    LightsWidget.h
    LoadSettingsDialog.h
    LogDockWidget.h
    LogWidget.h
    Logger.h
    MainWindow.h
    Node.h
    NodeItem.h
    NodePropertiesWidget.h
    NodeSelectionWidget.h
    Preset.h
    PresetsWidget.h
    Projection.h
    ProjectionWidget.h
    RenderThread.h
    Scene.h
    SettingsDockWidget.h
    Spectrum.h
    Stable.h
    StartupDialog.h
    StatisticsDockWidget.h
    StatisticsWidget.h
    Status.h
    Timing.h
    TransferFunction.h
    TransferFunctionItem.h
    TransferFunctionView.h
    TransferFunctionWidget.h
    UpdateWidget.h
    Utilities.h
    Variance.h
    VolumeMapper.h
    VtkWidget.h
    Blur.cuh
    Buffer.cuh
    Camera.cuh
    Core.cuh
    Denoise.cuh
    Estimate.cuh
    Lighting.cuh
    Model.cuh
    MonteCarlo.cuh
    MultipleScattering.cuh
    NearestIntersection.cuh
    RNG.cuh
    RayMarching.cuh
    Sample.cuh
    Shader.cuh
    SingleScattering.cuh
    SpecularBloom.cuh
    ToneMap.cuh
    Transport.cuh
    Utilities.cuh
    Variance.cuh
    View.cuh
    Woodcock.cuh)

source_group(TREE "${CMAKE_CURRENT_SOURCE_DIR}" FILES
    ${ExposureRenderSources}
    ${ExposureRenderHeaders})

add_executable(ExposureRender
    ${ExposureRenderSources}
    ${ExposureRenderHeaders})

target_include_directories(ExposureRender PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_BINARY_DIR})

target_link_libraries(ExposureRender PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    Qt6::Xml
    Qt6::Network
    Qt6::OpenGLWidgets
    ${VTK_LIBRARIES}
    CUDA::cudart)

# Registers the OpenGL2 rendering backend and the interaction styles. Without
# this the render window has no factory implementation at run time.
vtk_module_autoinit(TARGETS ExposureRender MODULES ${VTK_LIBRARIES})

# Stable.h pulls in QtWidgets, so it must reach the C++ sources only -- Core.cu
# is compiled by nvcc and is deliberately free of any Qt include.
target_precompile_headers(ExposureRender PRIVATE
    "$<$<COMPILE_LANGUAGE:CXX>:${CMAKE_CURRENT_SOURCE_DIR}/Stable.h>")

if(MSVC)
    target_compile_definitions(ExposureRender PRIVATE _EXPORTING)
endif()

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------

include(GNUInstallDirs)

install(TARGETS ExposureRender RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

install(DIRECTORY Examples/ DESTINATION ${CMAKE_INSTALL_BINDIR}/Examples)
install(DIRECTORY Icons/    DESTINATION ${CMAKE_INSTALL_BINDIR}/Icons FILES_MATCHING PATTERN "*.png")

file(GLOB ExposureRenderPresets "${CMAKE_CURRENT_SOURCE_DIR}/Presets/*.xml")
if(ExposureRenderPresets)
    install(FILES ${ExposureRenderPresets} DESTINATION ${CMAKE_INSTALL_BINDIR})
endif()

install(FILES ReadMe.txt Copyright.txt DESTINATION ${CMAKE_INSTALL_BINDIR})

# ---------------------------------------------------------------------------
# Package
# ---------------------------------------------------------------------------

set(CPACK_PACKAGE_NAME                "Exposure Render")
set(CPACK_PACKAGE_VENDOR              "TU Delft")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "${PROJECT_DESCRIPTION}")
set(CPACK_PACKAGE_DESCRIPTION_FILE    "${CMAKE_CURRENT_SOURCE_DIR}/ReadMe.txt")
set(CPACK_RESOURCE_FILE_LICENSE       "${CMAKE_CURRENT_SOURCE_DIR}/Copyright.txt")
set(CPACK_RESOURCE_FILE_WELCOME       "${CMAKE_CURRENT_SOURCE_DIR}/Welcome.txt")
set(CPACK_PACKAGE_VERSION_MAJOR       ${PROJECT_VERSION_MAJOR})
set(CPACK_PACKAGE_VERSION_MINOR       ${PROJECT_VERSION_MINOR})
set(CPACK_PACKAGE_VERSION_PATCH       ${PROJECT_VERSION_PATCH})

if(WIN32)
    set(CPACK_GENERATOR NSIS)
    set(CPACK_PACKAGE_INSTALL_DIRECTORY  "Exposure Render")
    set(CPACK_PACKAGE_EXECUTABLES        "ExposureRender;Exposure Render")
    set(CPACK_NSIS_PACKAGE_NAME          "Exposure Render")
    set(CPACK_NSIS_DISPLAY_NAME          "Exposure Render")
    set(CPACK_NSIS_CONTACT               "t.kroes@tudelft.nl")
    set(CPACK_NSIS_HELP_LINK             "http://graphics.tudelft.nl/")
    set(CPACK_NSIS_URL_INFO_ABOUT        "http://code.google.com/p/exposure-render/")
    set(CPACK_NSIS_EXECUTABLES_DIRECTORY "${CMAKE_INSTALL_BINDIR}")
    set(CPACK_NSIS_MUI_FINISHPAGE_RUN    "ExposureRender")
    include(InstallRequiredSystemLibraries)
else()
    set(CPACK_GENERATOR TGZ)
endif()

include(CPack)
