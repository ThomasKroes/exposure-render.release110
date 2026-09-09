# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Exposure Render 1.1.0 — an interactive CUDA volume renderer implementing the paper *"Direct Volume Rendering with Physically Based Lighting"* (T. Kroes, TU Delft). It is a Qt 4 desktop application that progressively path-traces a medical volume (`.mhd`/`.raw`) on the GPU and displays the accumulating estimate in a VTK view.

**This is a Windows/MSVC codebase.** It uses `__declspec(dllexport)` (`Dll.h`), MSVC precompiled-header flags (`/Yu`), backslash includes (`<QtXml\qdom.h>`), and CUDA 4.0-era APIs (texture references, `cudaThreadSynchronize`). It does not build on Linux as-is, even though the repo may be checked out there.

## Building

There is no test suite, linter, or CI. `build.md` has the full dependency setup; the short version:

- Dependencies: CUDA Toolkit 4.0 + GPU Computing SDK, Qt 4.7.3 (built with the same MSVC, `QTDIR` set), VTK 5.6 built **with Qt support** (`RelWithDebInfo`).
- The only `CMakeLists.txt` is `Source/CMakeLists.txt` — point CMake's source dir at `Source/`, not the repo root. Set `VTK_DIR` or CMake fails outright.
- Build type is hardcoded to `RelWithDebInfo`; nvcc targets `compute_20`/`sm_20` only (older arches are commented out and would need re-enabling for pre-Fermi GPUs).
- Qt moc/uic/qmake are taken from what VTK was built with (`VTK_QT_*_EXECUTABLE`) — a mismatched standalone Qt is a common failure.
- Generate the VS solution and build the `ExposureRender` target. Packaging is CPack/NSIS (`INCLUDE(CPack)`), which installs the VTK/Qt/CUDA DLLs, `Examples/`, `Presets/`, and `Icons/` next to the exe.
- Copy `Source/Presets` into the build dir after building, or preset loading finds nothing.

### Adding a source file

`Source/CMakeLists.txt` lists every file **two or three times** and none of it globs:

1. `ExposureRenderSources` / `ExposureRenderHeaders` (what actually compiles),
2. `ExposureRenderMocHeaders` if the class has `Q_OBJECT`,
3. the matching `SOURCE_GROUP` set (`MainSources`, `AppearanceSources`, `CudaSources`, …) — cosmetic VS folders, but kept in sync.

Every `.cpp` must `#include "Stable.h"` first: it is the precompiled header (`/YuStable.h`, created by `Stable.cpp` via `/Yc`). The `PCH_QT4_WRAP_CPP` macro in CMakeLists is a patched `QT4_WRAP_CPP` that force-includes `Stable.h` into generated `moc_*.cxx` for the same reason.

## Architecture

Two layers with a deliberately narrow bridge:

**Qt/UI layer — `Q`-prefixed classes.** `QCamera`, `QLighting`, `QTransferFunction`, `QAppearance`, etc. These are `QObject`s that hold the *authored* state, emit `Changed()` signals, and serialize themselves to XML by deriving from `QPresetXML` (`Preset.h`). Widgets edit them; they never touch CUDA. Presets are `QPresetsWidget<T>` templated over any `QPresetXML` subclass, loaded from `Presets/*.xml`.

**Render core — `C`-prefixed classes.** `CScene` (`Scene.h`) is the single struct the GPU sees: camera, lighting, transfer functions, denoise params, resolution, dirty flags. It is copied wholesale to the device with `cudaMemcpy` every frame, so anything reachable from `CScene` must be trivially copyable — fixed-size arrays, no virtuals, no host pointers. Members are annotated with `HOD`/`DEV`/`HO` from `Defines.h`.

**The bridge — `RenderThread.cpp`.** `QRenderThread` connects to `gTransferFunction`/`gCamera`/`gLighting` signals; its slots (`OnUpdateCamera`, `OnUpdateLighting`, `OnUpdateTransferFunction`) lock `gSceneMutex`, copy Q-layer values into the global `gScene`, and set bits in `gScene.m_DirtyFlags` (`EDirty` in `Enumerations.h`: `CameraDirty`, `LightsDirty`, `TransferFunctionDirty`, `FilmResolutionDirty`, …).

### Frame loop

`QRenderThread::run()` per iteration: lock `gSceneMutex` → copy `gScene` into a local `SceneCopy` → act on dirty flags (reallocate the film on `FilmResolutionDirty`, re-bind transfer-function textures on `TransferFunctionDirty`, **reset `gScene.SetNoIterations(0)`** on anything that invalidates accumulation) → `ClearAllFlags()` → `BindConstants(&SceneCopy)` → `Render(...)` → increment the iteration count → publish the LDR image into the global `gFrameBuffer`.

Rendering is progressive: the image converges over iterations and any parameter change restarts it at zero. `CDenoiseParams::m_LerpC` is derived from the iteration count, so denoising fades out as the estimate converges.

`CVtkWidget` runs a `QTimer` that pulls `gFrameBuffer` into a `vtkImageImport` → `vtkImageActor` inside a `QVTKWidget`. VTK is only a display surface and interactor host (`vtkRealisticCameraStyle` maps mouse gestures to `gCamera`); it does no volume rendering.

### CUDA core

`Core.cu` is effectively the only CUDA translation unit: it owns all `texture<>` references (density, gradient magnitude, the five transfer-function LUTs, running estimate) and all `__device__ __constant__` globals (`CD` macro), then `#include`s the `.cuh` files, each of which contains a `KERNEL` plus its host launcher:

`SingleScattering.cuh` (the main integrator) → `Blur.cuh` → `Estimate.cuh` (running average) → `ToneMap.cuh` → `Denoise.cuh`, called in that order by `Render()` in `Core.cu`. Supporting headers: `Woodcock.cuh`/`RayMarching.cuh` (distance sampling), `Transport.cuh`/`Shader.cuh`/`Sample.cuh`/`MonteCarlo.cuh` (light transport and BSDF/phase sampling), `RNG.cuh`, `View.cuh`/`Buffer.cuh` (device framebuffers), `NearestIntersection.cuh` (autofocus). `MultipleScattering.cuh` exists but its call site is commented out.

The host↔device API is the `extern "C"` block in `Core.cuh` — `Bind*Buffer`, `Bind*/Unbind*` for transfer functions, `BindConstants`, `Render`, `GetDisplayEstimate`. Keep new GPU entry points there rather than including `.cuh` files from C++ sources.

`pScene->m_ShadingType` selects the shading model inside `KrnlSingleScattering`: 0 = BRDF, 1 = phase function, 2 = stochastic mix weighted by gradient magnitude and `m_GradientFactor` — this is the paper's hybrid scattering.

### Global singletons

State is reached through externs, not injection: `gScene`, `gSceneMutex`, `gpRenderThread`, `gFrameBuffer` (`RenderThread.h`/`Scene.h`), `gCamera`, `gLighting`, `gTransferFunction`, `gHistogram`, `gStatus`, `gLogger`, `gpMainWindow`. `gStatus` (`Status.h`) is the app-wide event bus — `RenderBegin`/`RenderEnd`/`PreRenderFrame`/`PostRenderFrame`/`LoadPreset`/`StatisticChanged`; the statistics dock is populated purely by `SetStatisticChanged(group, name, value, unit, icon)` calls scattered through the render thread.

## Conventions

- `C` prefix = core/CUDA-shared, `Q` prefix = Qt/UI, `m_` members, `g` globals, `p` pointers.
- Any read/write of `gScene` from the UI thread must hold `gSceneMutex` (`QMutexLocker`).
- Icons come from `Icons/Icons.qrc`; `GetIcon("name")` (`Utilities.h`) resolves them by base name.
- `Convert.py` is a standalone VTK script for downsampling `.mhd` volumes into the `_small` variants in `Examples/`; its paths are hardcoded to `C:\Volumes`.
- `VersionInfo.xml` at the repo root is fetched at runtime by `UpdateWidget`/`HttpGet` for the update check; bump `<ID>`/`<Name>` there alongside `CPACK_PACKAGE_VERSION_*` in CMakeLists.
- `Source/ReadMe.txt` doubles as the installer description and documents the camera/canvas/transfer-function mouse bindings.
