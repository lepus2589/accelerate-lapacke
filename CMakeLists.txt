#[[
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
]]

cmake_minimum_required(VERSION 3.12)

set(CMAKE_MAXIMUM_SUPPORTED_VERSION 3.30)

include("./cmake/HandlePolicies.cmake" NO_POLICY_SCOPE)

project(AccelerateLAPACKE VERSION 1.1.0 LANGUAGES C)

include(FetchContent)

string(COMPARE EQUAL "${CMAKE_PROJECT_NAME}" "${PROJECT_NAME}" IS_TOP_LEVEL)

if (NOT IS_TOP_LEVEL)
    message(FATAL_ERROR "This project is meant to be built as a stand-alone project, only.")
endif ()

if (CMAKE_HOST_SYSTEM_NAME MATCHES "Darwin")
    # The available binary Accelerate version is determined by the MacOS system
    message(STATUS "The Darwin kernel version is: ${CMAKE_HOST_SYSTEM_VERSION}")

    if (CMAKE_HOST_SYSTEM_VERSION VERSION_GREATER_EQUAL 24.0)
        # Mac OS X 15.0 Sequoia or later
        message(STATUS "The MacOS version is: >=15.0")
        set(MINIMUM_MACOS_SDK_VERSION 15.0)
        set(ACCELERATE_NEW_LAPACK_VERSION 3.11.0)
    elseif (CMAKE_HOST_SYSTEM_VERSION VERSION_GREATER_EQUAL 22.4)
        # Mac OS X 13.3 Ventura or later
        message(STATUS "The MacOS version is: >=13.3,<15.0")
        set(MINIMUM_MACOS_SDK_VERSION 13.3)
        set(VALID_MACOS_SDK_VERSIONS 14.5 14.4 14.2 14.0 13.3)
        set(ACCELERATE_NEW_LAPACK_VERSION 3.9.1)
    else ()
        message(FATAL_ERROR "You need at least MacOS 13.3 Ventura for Accelerate with BLAS/LAPACK v3.9.1!")
    endif ()

    message(STATUS "The BLAS/LAPACK version provided by the Accelerate framework is: ${ACCELERATE_NEW_LAPACK_VERSION}")
endif ()

string(REGEX MATCH [=[SDKs/MacOSX(.*)\.sdk$]=] _REGEX_DUMMY "${CMAKE_OSX_SYSROOT}")
set(DEFAULT_MACOS_SDK_VERSION "${CMAKE_MATCH_1}")

# The text-based .dylib stubs describing the Accelerate framework are provided
# by the MacOS SDK, which has to match the MacOS system. Otherwise, there might
# be newer symbols in the text-based .dylib stubs that are not provided by the
# Accelerate binary, leading to linking errors.
if (NOT DEFINED VALID_MACOS_SDK_VERSIONS)
    # MacOS system supports the latest iteration of the new Accelerate
    # BLAS/LAPACK. Use the default SDK, if it's recent enough.
    if (DEFAULT_MACOS_SDK_VERSION VERSION_LESS MINIMUM_MACOS_SDK_VERSION)
        message(STATUS "The MacOS SDK is: ${CMAKE_OSX_SYSROOT}")
        message(STATUS "The minimum compatible MacOS SDK version is: ${MINIMUM_MACOS_SDK_VERSION}")
        message(FATAL_ERROR "Please install a more recent XCode for a compatible MacOS SDK.")
    endif ()
elseif (NOT DEFAULT_MACOS_SDK_VERSION IN_LIST VALID_MACOS_SDK_VERSIONS)
    # MacOS system supports one of the past iterations of the new Accelerate
    # BLAS/LAPACK. If the latest possible XCode is installed is installed on
    # this older system, there might be a mismatch between the SDK and the
    # system binary. Find a matching SDK from the Command Line Tools instead. 
    foreach (_MACOS_SDK_VERSION IN LISTS VALID_MACOS_SDK_VERSIONS)
        find_path(VALID_MACOS_SDK NAMES "MacOSX${_MACOS_SDK_VERSION}.sdk" HINTS "/Library/Developer/CommandLineTools/SDKs" NO_CACHE)

        if (VALID_MACOS_SDK)
            set(VALID_MACOS_SDK "${VALID_MACOS_SDK}/MacOSX${_MACOS_SDK_VERSION}.sdk")
            break ()
        endif ()
    endforeach ()

    if (VALID_MACOS_SDK)
        set(CMAKE_OSX_SYSROOT "${VALID_MACOS_SDK}" CACHE PATH "" FORCE)
    else ()
        message(STATUS "The MacOS SDK is: ${CMAKE_OSX_SYSROOT}")
        message(STATUS "The compatible MacOS SDK versions are: ${VALID_MACOS_SDK_VERSIONS}")
        message(FATAL_ERROR "Couldn't find a compatible MacOS SDK. Please install compatible XCode Command Line Tools.")
    endif ()
endif ()

message(STATUS "The MacOS SDK is: ${CMAKE_OSX_SYSROOT}")

set(ENV{CMAKE_FRAMEWORK_PATH} "${CMAKE_OSX_SYSROOT}/System/Library/Frameworks")

set(BLA_VENDOR "Apple")
find_package(LAPACK MODULE)

if (NOT LAPACK_FOUND OR NOT LAPACK_Accelerate_LIBRARY)
    message(FATAL_ERROR "Couldn't find Accelerate framework!")
endif ()

add_subdirectory(src)
