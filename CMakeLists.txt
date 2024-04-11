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

set(CMAKE_MAXIMUM_SUPPORTED_VERSION 3.29)

include("./cmake/HandlePolicies.cmake" NO_POLICY_SCOPE)

project(AccelerateLAPACKE VERSION 1.0.0 LANGUAGES C)

include(FetchContent)

string(COMPARE EQUAL "${CMAKE_PROJECT_NAME}" "${PROJECT_NAME}" IS_TOP_LEVEL)

if (NOT IS_TOP_LEVEL)
    message(FATAL_ERROR "This project is meant to be built as a stand-alone project, only.")
endif ()

if (CMAKE_HOST_SYSTEM_NAME MATCHES "Darwin")
     # Mac OS X 13.3 Ventura
    if (CMAKE_HOST_SYSTEM_VERSION VERSION_GREATER_EQUAL 22.4)
        set(ACCELERATE_NEW_LAPACK_VERSION 3.9.1)
    else ()
        message(FATAL_ERROR "You need at least Mac OS X 13.3 Ventura for Accelerate with BLAS/LAPACK v3.9.1!")
    endif ()
endif ()

set(BLA_VENDOR "Apple")
find_package(LAPACK MODULE)

if (NOT LAPACK_FOUND OR NOT LAPACK_Accelerate_LIBRARY)
    message(FATAL_ERROR "Couldn't find Accelerate framework!")
endif ()

add_subdirectory(src)
