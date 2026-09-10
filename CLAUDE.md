# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Exposure Render 1.1.0 — an interactive CUDA volume renderer implementing the paper *"Direct Volume Rendering with Physically Based Lighting"* (T. Kroes, TU Delft). A Qt desktop application that progressively path-traces a medical volume (`.mhd`/`.raw`) on the GPU and displays the accumulating estimate in a VTK view.

Originally a Visual Studio 2010 / CUDA 4.0 / Qt 4.7 / VTK 5.6 codebase, ported to Linux against **GCC, CUDA 12+, Qt 6 and VTK 9**. Windows paths in the source are preserved but have not been built since the port: `Dll.h` still exports under `_MSC_VER`, and CPack still produces an NSIS installer under `WIN32`.

## Building

There is no test suite, linter, or CI — the only verification is that it compiles and renders. `build.md` has the full setup and a troubleshooting section keyed to specific error text. The short version:

```sh
cmake -S Source -B build \
    -DCMAKE_C_COMPILER=gcc-15 -DCMAKE_CXX_COMPILER=g++-15 \
    -DCMAKE_CUDA_HOST_COMPILER=g++-15
cmake --build build -j$(nproc)
cmake --install build --prefix ./install
```

Four things that are not obvious and each cost real time to work out:

- **The CMake project is `Source/`, not the repo root.**
- **`project()` must list `C`** even though nothing here is written in it. Where VTK is built with MPI, `VTK::mpi` depends on `MPI::MPI_C`, and `FindMPI` refuses to probe its C component unless the consuming project enables C — `find_package(VTK)` then fails at *generate* time, after reporting every component as found.
- **openmpi must be installed** on such distributions. `GUISupportQt` → `FiltersExtraction` → `ParallelMPI` → `libmpi`, and `GUISupportQt` is not optional, so this cannot be routed around in the build file. Everything compiles and the link fails with dozens of undefined `MPI_*` symbols.
- **`CMAKE_CUDA_HOST_COMPILER` usually has to be set.** nvcc rejects host compilers newer than it knows about (CUDA 13.3 refuses GCC 16+). Check the ceiling with `grep "__GNUC__ > " /opt/cuda/include/crt/host_config.h`.

Run from an install tree, not the build directory — the app resolves `Icons/`, `Examples/` and its preset XML relative to the binary:

```sh
cd install/bin && ./ExposureRender Examples/manix_small.mhd
```

The volume argument is optional; without it you get the startup dialog. It is the practical way to exercise the render path without a human clicking.

### Adding a source file

Add it to `ExposureRenderSources` (or `ExposureRenderHeaders`, which exists so AUTOMOC scans headers and IDEs show them) in `Source/CMakeLists.txt`. Nothing globs, but nothing is listed twice either — AUTOMOC replaced the hand-maintained moc list, and one `source_group(TREE ...)` replaced the per-subsystem `SOURCE_GROUP` calls.

Every `.cpp` must `#include "Stable.h"` first — it is the precompiled header. Note that `target_precompile_headers` is deliberately scoped with `$<$<COMPILE_LANGUAGE:CXX>:...>`: `Stable.h` pulls in QtWidgets, and applying it to all languages would force Qt into nvcc, breaking the host/device separation described below.

## Architecture

Two layers with a deliberately narrow bridge:

**Qt/UI layer — `Q`-prefixed classes.** `QCamera`, `QLighting`, `QTransferFunction`, `QAppearance`, etc. `QObject`s that hold the *authored* state, emit `Changed()` signals, and serialize to XML by deriving from `QPresetXML` (`Preset.h`). Widgets edit them; they never touch CUDA. Presets are `QPresetsWidget<T>` templated over any `QPresetXML` subclass, loaded from `*Presets.xml` beside the binary.

**Render core — `C`-prefixed classes.** `CScene` (`Scene.h`) is the single struct the GPU sees: camera, lighting, transfer functions, denoise params, resolution, dirty flags. It is `cudaMemcpy`'d to the device every frame, so anything reachable from it must be trivially copyable — fixed-size arrays, no virtuals, no host pointers. `sizeof(CScene)` is about 7.3 KB. Members are annotated `HOD`/`DEV`/`HO` from `Defines.h`.

**nvcc never sees Qt.** The `.cu`/`.cuh` chain reaches only `Scene.h`, `Geometry.h`, `Spectrum.h`, `Camera.cuh`, `Lighting.cuh`, `Flags.h`, `Timing.h`, `Variance.h` and `CudaUtilities.h` — all Qt-free. Preserve this: it is why the CUDA half compiles cleanly and why the PCH is language-scoped.

**The bridge — `RenderThread.cpp`.** `QRenderThread` connects to `gTransferFunction`/`gCamera`/`gLighting` signals; its slots (`OnUpdateCamera`, `OnUpdateLighting`, `OnUpdateTransferFunction`) lock `gSceneMutex`, copy Q-layer values into the global `gScene`, and set bits in `gScene.m_DirtyFlags` (`EDirty` in `Enumerations.h`).

### Frame loop

`QRenderThread::run()` per iteration: lock `gSceneMutex` → copy `gScene` into a local `SceneCopy` → act on dirty flags (reallocate the film on `FilmResolutionDirty`, re-bind transfer-function textures on `TransferFunctionDirty`, **reset `gScene.SetNoIterations(0)`** on anything that invalidates accumulation) → `ClearAllFlags()` → `BindConstants(&SceneCopy)` → `Render(...)` → increment the iteration count → publish the LDR image into the global `gFrameBuffer`.

Rendering is progressive: the image converges over iterations and any parameter change restarts it at zero. This matters when judging a change — an error affecting only later iterations (in `Estimate.cuh`, or the `CDenoiseParams::m_LerpC` ramp derived from the iteration count) will not show in a first frame.

`CVtkWidget` runs a `QTimer` that copies `gFrameBuffer` under its mutex, then feeds it to `vtkImageImport` → `vtkImageActor` inside a `QVTKOpenGLNativeWidget`. VTK is only a display surface and interactor host (`vtkRealisticCameraStyle` maps mouse gestures to `gCamera`); it does no volume rendering.

`QSurfaceFormat::setDefaultFormat(QVTKOpenGLNativeWidget::defaultFormat())` must run before `QApplication` is constructed (`Main.cpp`). Without it VTK gets a context too old for its own shaders, every shader program fails with "unsupported version 150", and the canvas stays blank.

### CUDA core

`Core.cu` is the only CUDA translation unit. It owns the texture objects, the `__device__ __constant__` globals (`CD` macro), and the reusable device-side `CScene`/`CCudaView`, then `#include`s the `.cuh` files, each containing a `KERNEL` plus its host launcher.

Pipeline, in the order `Render()` calls them: `SingleScattering.cuh` (the main integrator) → `Blur.cuh` → `Estimate.cuh` (running average) → `ToneMap.cuh` → `Denoise.cuh`. Supporting headers: `RayMarching.cuh` (distance sampling), `Transport.cuh`/`Shader.cuh`/`Sample.cuh`/`MonteCarlo.cuh` (light transport and BSDF/phase sampling), `RNG.cuh`, `View.cuh`/`Buffer.cuh` (device framebuffers), `NearestIntersection.cuh` (autofocus).

**Not compiled:** `Woodcock.cuh` and `MultipleScattering.cuh` are not included by `Core.cu`. `gTexExtinction` exists only for `Woodcock.cuh` and is never created, so that path was already dead before the port.

**Textures are texture objects, not references** (references were removed in CUDA 12). Nine `cudaTextureObject_t` live in constant memory so kernels still address them by name. Fetches carry their return type — `tex3D<float>(gTexDensity, ...)`, `tex1D<float4>(gTexDiffuse, ...)` — and that argument is the value returned, not the storage format: the `short` volumes read as `float` under `cudaReadModeNormalizedFloat`, and the `uchar4` running estimate as `float4`. `CreateArrayTextureObject` in `Core.cu` carries the sampling state the old reference members held. The running estimate is pitched linear memory, so it uses a `cudaResourceTypePitch2D` descriptor with unnormalised coordinates and point sampling — `Denoise.cuh` addresses it in pixels (`X + 0.5f`) and depends on exactly that.

A wrong `addressMode`/`filterMode`/`readMode` here compiles cleanly and renders something plausible rather than failing, so changes to texture setup need visual comparison against a known-good render, not just a successful build.

The host↔device API is the `extern "C"` block in `Core.cuh`. Keep new GPU entry points there rather than including `.cuh` files from C++ sources.

`pScene->m_ShadingType` selects the shading model in `KrnlSingleScattering`: 0 = BRDF, 1 = phase function, 2 = stochastic mix weighted by gradient magnitude and `m_GradientFactor` — the paper's hybrid scattering. The bundled presets exercise all three (`engine_small` uses BRDF Only; `manix_small` and `bonsai_small` use Hybrid).

### Global singletons

State is reached through externs, not injection: `gScene`, `gSceneMutex`, `gpRenderThread`, `gFrameBuffer` (`RenderThread.h`/`Scene.h`), `gCamera`, `gLighting`, `gTransferFunction`, `gHistogram`, `gStatus`, `gLogger`, `gpMainWindow`. `gStatus` (`Status.h`) is the app-wide event bus — `RenderBegin`/`RenderEnd`/`PreRenderFrame`/`PostRenderFrame`/`LoadPreset`/`StatisticChanged`; the statistics dock is populated purely by `SetStatisticChanged(group, name, value, unit, icon)` calls scattered through the render thread.

## Conventions

- `C` prefix = core/CUDA-shared, `Q` prefix = Qt/UI, `m_` members, `g` globals, `p` pointers.
- Any read/write of `gScene` from the UI thread must hold `gSceneMutex`; `gFrameBuffer` has its own mutex, which **both** sides must take. Name your `QMutexLocker` — an unnamed temporary releases immediately, and that bug lived here for years.
- `GetIcon("name")` (`Stable.h`) loads from `Icons/` beside the binary. `Icons/Icons.qrc` exists but is **not** compiled in — enabling AUTORCC and switching `GetIcon` to `:/Icons/...` would remove most of the deployment footprint (3,179 loose PNGs).
- The update check is off unless `updates/versionInfoUrl` is set in QSettings; the original Google Code endpoint died in 2016.
- `Convert.py` is a standalone VTK script for downsampling `.mhd` volumes into the `_small` variants in `Examples/`; its paths are hardcoded to `C:\Volumes`.
- `Source/ReadMe.txt` doubles as the installer description and documents the camera/canvas/transfer-function mouse bindings.

## Known rough edges

- Everything resolves against `QApplication::applicationDirPath()` — `Icons/`, `Examples/`, `*Presets.xml`, `Output/`. A real install prefix or `QStandardPaths` would be better.
- `StartupDialog.cpp` looks for `Readme.rtf` then `Readme.txt`; the file on disk is `ReadMe.txt`, which never matches on a case-sensitive filesystem.
- Kernel block sizes (`16×8` for single scattering and blur, `8×8` for tone mapping) were tuned for Fermi and have not been revisited.
- `VolumeMapper.cpp`/`.h` compile to nothing: the `vtkVolumeCudaMapper` class and every one of its methods sit inside comment blocks, leaving only the includes. Dead since before this release.
