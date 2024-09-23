<!---
MIT License

CMake build script for the Accelerate LAPACKE project
Copyright (c) 2024 Tim Kaune

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--->

# Accelerate LAPACKE #

Since MacOS 13.3 Ventura, Apple's Accelerate framework comes with a new
[BLAS/LAPACK
interface](https://developer.apple.com/documentation/accelerate/blas) compatible
with [Reference LAPACK
v3.9.1](https://github.com/Reference-LAPACK/lapack/releases/tag/v3.9.1). It also
provides an ILP64 interface. On Apple Silicon M-processors, it utilises the
[proprietary AMX co-processor](https://github.com/corsix/amx), which makes it
especially interesting. Unfortunately, it comes without the LAPACKE C-interface
library.

**Update**: With the release of MacOS 15.0 Sequoia, Apple updated the Accelerate
framework to be compatible with [Reference LAPACK
v3.11.0](https://github.com/Reference-LAPACK/lapack/releases/tag/v3.11.0).
Unfortunately, there is no mention of it in the [MacOS 15.0 Sequoia Release
Notes](), but the note in the [Accelerate BLAS
docs](https://developer.apple.com/documentation/accelerate/blas) has been
updated accordingly.

These new interfaces are hidden behind the preprocessor defines
`ACCELERATE_NEW_LAPACK` and `ACCELERATE_LAPACK_ILP64` and they only work, if you
include the Accelerate C/C++ headers.

## The Problem ##

But what if you have to or just want to link against the Accelerate framework
without including the C/C++ headers, e.&nbsp;g. when compiling Fortran code or a
third-party project, that uses the standard BLAS/LAPACK API? Well, you're out of
luck. The binary symbols for the new LAPACK version exported by the Accelerate
framework do not adhere to the BLAS/LAPACK API. Thus, they cannot be resolved by
the linker, when linking any program or library that uses the standard
BLAS/LAPACK API.

Take, for example, the `dgeqrt` LAPACK routine, that is used by the [Reference
LAPACK CMake
script](https://github.com/Reference-LAPACK/lapack/blob/v3.9.1/CMakeLists.txt#L315-L316)
to determine, if the user provided LAPACK version is recent enough. When the
Fortran test executable is compiled, the `gfortran` compiler creates a function
call with the binary symbol `_dgeqrt_`, which results in the following error
when linking to Accelerate (`ld` is the Apple system linker, here):

```plaintext
ld: Undefined symbols:
  _dgeqrt_, referenced from:
      _MAIN__ in testFortranCompiler.f.o
```

The reason for this is, that the binary symbol provided by the Accelerate
framework is called `_dgeqrt$NEWLAPACK`, literally. This is a symbol, that no
Fortran compiler will probably ever emit voluntarily. So, what to do?

## The Solution ##

According to its `man` page, the Apple system linker `ld` provides the options
`-alias` and `-alias_list`, which let you create alias names for existing binary
symbols. Calling the linker with `-alias '_dgeqrt$NEWLAPACK' _dgeqrt_` makes the
linking of the above Fortran test executable finish successfully.

Because BLAS and LAPACK contain quite a number of subroutines and functions,
this CMake scipt uses the `-alias_list` option, which loads a plaintext file
listing all the aliases.

To generate the full alias list for the Accelerate NEWLAPACK interface, it
parses the symbols listed in the BLAS and LAPACK text-based `.dylib` stubs. For
every symbol that ends in `$NEWLAPACK` (or `$NEWLAPACK$ILP64` for the ILP64
interface), an alias is added to the alias file.

The linker option is injected into the Reference LAPACK configure process using
the `CMAKE_EXE_LINKER_FLAGS` variable for the test compiles and the
`CMAKE_SHARED_LINKER_FLAGS` variable for the shared LAPACKE library.

This enables the compilation of the LAPACKE C-interface library for the
Accelerate framework (e.&nbsp;g. to be used in the `Eigen3` library). Analyzing
the resulting `.dylib` with `otool`, you can see:

```shell
$ otool -L ./build/32/_deps/reference-lapack-build/lib/liblapacke.dylib
./build/32/_deps/reference-lapack-build/lib/liblapacke.dylib:
    @rpath/liblapacke.3.dylib (compatibility version 3.0.0, current version 3.9.1)
    /System/Library/Frameworks/Accelerate.framework/Versions/A/Accelerate (compatibility version 1.0.0, current version 4.0.0)
    /usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1336.61.1)
```

Only the Accelerate framework and the System library are linked into the
`.dylib`. No `libgfortran` or other libraries are needed.

### The alias files (to use in other projects) ###

After the CMake configuration, the alias files can be found in `./build/<32|64>/src`:

```plaintext
./build/<32|64>/src
├── new-lapack-ilp64.alias
└── new-lapack.alias
```

These files can be used to link other projects against Accelerate, too, of course!

## How to compile ##

It is recommended to use the Apple System C Compiler `/usr/bin/cc`. You can also
use a more recent Clang compiler provided by Homebrew or MacPorts. If you have
other compilers installed on your system, make sure CMake finds the correct one.
Otherwise, help CMake by setting the environment variable `$ export
CC=/usr/bin/cc` in your terminal window.

It is also recommended to use at least CMake v3.20 with presets, but the CMake
script also works down to CMake v3.12, if you set the required variables on the
command line.

### Prerequisites ###

Obviously, your operating system must be Mac OS X >=v13.3 Ventura with XCode
installed. Additionally, you'll need the following software (easily obtainable
via Homebrew or MacPorts):

- CMake
- Fortran compiler (e.&nbsp;g. `gfortran` contained in the `gcc` package) to
  make it through the Reference LAPACK configure script

### Configuration with CMake ###

Use the `accelerate-lapacke32` preset (or the `accelerate-lapacke64` preset for
the ILP64 interface) with CMake:

```shell
$ cmake --preset accelerate-lapacke32
```

This will configure LAPACKE to be installed in your `~/.local` directory by
default. If you prefer a different install location (e.&nbsp;g. `/opt/custom`),
you can change it like this:

```shell
$ cmake --preset accelerate-lapacke32 -D "CMAKE_INSTALL_PREFIX=/opt/custom"
```

I wouldn't recommend installing to `/usr/local` (used by Homebrew on Intel Macs)
or `/opt/local` (used by MacPorts).

### Build and install ###

When the configuration finished successfully (fingers crossed), you can build with the
same preset name (`accelerate-lapacke32` or `accelerate-lapacke64`):

```shell
$ cmake --build --preset accelerate-lapacke32 --verbose
```

If everything worked as intended, linking the library should be successful. Now,
you can install to the previously configured install prefix by building the
install target:

```shell
$ cmake --build --preset accelerate-lapacke32 --verbose --target install
```

### Using LAPACKE in another project ###

You can use your self-compiled LAPACKE library in other projects by importing
the CMake package in the other project's `CMakeLists.txt` file:

```cmake
find_package(LAPACKE CONFIG)
```

and providing the above install location via the `CMAKE_PREFIX_PATH` variable
from the command line:

```shell
$ cmake -S . -B ./build -D "CMAKE_PREFIX_PATH=~/.local"
```

This makes the imported `lapacke` shared library target available in the other
project's `CMakeLists.txt`.
