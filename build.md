# Building Exposure Render

Exposure Render is a CUDA volume renderer with a Qt front end and a VTK display
surface. It was written in 2011 against Visual Studio 2010, CUDA 4.0, Qt 4.7 and
VTK 5.6; it has since been ported to a current Linux toolchain.

## Dependencies

| | Required | Verified against |
|---|---|---|
| CMake | 3.20+ | 4.4.2 |
| C++ compiler | C++17 | GCC 15.3.0 |
| CUDA Toolkit | 12.0+ | 13.3.73 |
| Qt | 6 | 6.11.2 |
| VTK | 9, **built with Qt support** | 9.6.2 |
| GPU | compute capability 5.0+ | RTX 2060 (7.5), driver 610.57 |

VTK must provide the `GUISupportQt` module — that is `QVTKOpenGLNativeWidget`,
which the render canvas is built on. A VTK package without Qt support will fail
at `find_package` time.

On Arch:

```sh
sudo pacman -S cmake gcc15 cuda qt6-base vtk openmpi
```

### Why openmpi

Nothing here uses MPI. But many distributions build VTK with MPI enabled, which
makes `VTK::GUISupportQt` depend on `FiltersExtraction`, which depends on
`ParallelMPI`, which needs `libmpi`. Without it the build compiles cleanly and
then fails at the link step with dozens of undefined `MPI_*` symbols. It cannot
be routed around in the build file, because `GUISupportQt` is not optional.

If your VTK was built without MPI, you do not need this.

### Host compiler

nvcc rejects host compilers newer than it knows about. CUDA 13.3 refuses GCC 16
and later with `#error -- unsupported GNU version!`, so on a distribution that
ships a newer default compiler you must point CMake at an older one.

Check the ceiling for your toolkit:

```sh
grep -m1 "__GNUC__ > " /opt/cuda/include/crt/host_config.h
```

Build the whole project with that compiler rather than mixing versions between
the C++ and CUDA halves.

## Configure and build

```sh
cmake -S Source -B build \
    -DCMAKE_C_COMPILER=gcc-15 \
    -DCMAKE_CXX_COMPILER=g++-15 \
    -DCMAKE_CUDA_HOST_COMPILER=g++-15

cmake --build build -j$(nproc)
```

`nvcc` must be on `PATH`, or pass `-DCMAKE_CUDA_COMPILER=/opt/cuda/bin/nvcc`.

Note that the CMake project lives in `Source/`, not the repository root.

Useful options:

- `-DCMAKE_BUILD_TYPE=` — defaults to `RelWithDebInfo`.
- `-DCMAKE_CUDA_ARCHITECTURES=` — defaults to `native`, which targets the GPU in
  the build machine. For a redistributable build name them explicitly, e.g.
  `"75;86;89"`.

## Install and run

The application resolves `Icons/`, `Examples/` and its preset XML files relative
to the directory holding the binary, so run it from an install tree rather than
from the build directory:

```sh
cmake --install build --prefix ./install
cd install/bin
./ExposureRender
```

Without arguments it opens the startup dialog, which offers the bundled demo
volumes. It also accepts a volume directly:

```sh
./ExposureRender Examples/manix_small.mhd
```

`--help` and `--version` work as usual.

Volumes are MetaImage pairs — a `.mhd` header beside its `.raw` data. The
bundled examples under `Source/Examples` are resampled to 50% to keep the
repository small; `Source/Convert.py` is the VTK script that produced them,
though its paths are hardcoded to a Windows drive.

## Optional settings

The update check is disabled by default: the original endpoint was on Google
Code, which shut down in 2016, and there is no replacement. To point it at a
host of your own, add to the `TU Delft/Exposure Render` settings file:

```ini
[updates]
versionInfoUrl=https://example.org/VersionInfo.xml
```

`Help → Check for updates` then works; with no endpoint set it says so and does
nothing.

## Windows

The MSVC-specific paths in the source are preserved — `Dll.h` still exports with
`__declspec` under `_MSC_VER`, the CPack configuration still produces an NSIS
installer under `WIN32`, and `target_precompile_headers` replaces the old
`/Yu` flags portably.

It has not been built on Windows since the port. The dependency floor is the
same as above, and the same host-compiler constraint applies between nvcc and
the MSVC version.

## Troubleshooting

**`find_package(VTK)` fails at generate time with `MPI::MPI_C` not found.**
The project must enable the C language for `FindMPI` to probe its C component;
this is why `project()` lists `C` even though nothing here is written in it. If
you see this in your own project, that is the cause. Here, it means openmpi is
missing — see above.

**Undefined `MPI_*` symbols at link time.** openmpi is not installed.

**`#error -- unsupported GNU version!`** Your default GCC is newer than the CUDA
toolkit accepts. Set `CMAKE_CUDA_HOST_COMPILER`.

**Every VTK shader fails with `unsupported version 150`, canvas stays blank.**
`QSurfaceFormat::setDefaultFormat(QVTKOpenGLNativeWidget::defaultFormat())` must
run before `QApplication` is constructed. `Main.cpp` does this; if you restructure
startup, keep it first.

**The window title updates but the canvas stays empty.** The volume failed to
load — check the log dock. A `.mhd` whose companion `.raw` is missing or whose
`ElementDataFile` path is wrong fails exactly this way.
