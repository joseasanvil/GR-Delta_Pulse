# Copyright 2011 Free Software Foundation, Inc.
#
# This file is part of gr-delta_pulse
#
# SPDX-License-Identifier: GPL-3.0-or-later
#

cmake_minimum_required(VERSION 3.10)

project(gr-delta_pulse)

# Find required packages
find_package(PkgConfig REQUIRED)
pkg_check_modules(GR_REQUIRED REQUIRED gnuradio-runtime)

# Find GNU Radio CMake modules
# Try common locations for GNU Radio CMake modules
set(GR_CMAKE_DIRS
    "${CMAKE_INSTALL_PREFIX}/lib/cmake/gnuradio"
    "/usr/lib/cmake/gnuradio"
    "/usr/local/lib/cmake/gnuradio"
    "/opt/homebrew/lib/cmake/gnuradio"
    "/opt/homebrew/Cellar/gnuradio/3.10.12.0_1/lib/cmake/gnuradio"
)

# Also try to find via file glob (for version-independent path)
file(GLOB GR_CELLAR_DIRS "/opt/homebrew/Cellar/gnuradio/*/lib/cmake/gnuradio")
list(APPEND GR_CMAKE_DIRS ${GR_CELLAR_DIRS})

foreach(dir ${GR_CMAKE_DIRS})
    if(EXISTS "${dir}/GrPlatform.cmake")
        list(APPEND CMAKE_MODULE_PATH ${dir})
        message(STATUS "Found GNU Radio CMake modules at: ${dir}")
        break()
    endif()
endforeach()

# Set the version information here
set(VERSION_INFO_MAJOR_VERSION 1)
set(VERSION_INFO_API_VERSION 0)
set(VERSION_INFO_MINOR_VERSION 0)
set(VERSION_INFO "${VERSION_INFO_MAJOR_VERSION}.${VERSION_INFO_API_VERSION}.${VERSION_INFO_MINOR_VERSION}")

message(STATUS "GNU Radio Delta Pulse Module")
message(STATUS "Version: ${VERSION_INFO}")

########################################################################
# Setup directories
########################################################################
# Include GrPlatform if available, otherwise define LIB_SUFFIX manually
include(GrPlatform OPTIONAL)
if(NOT DEFINED LIB_SUFFIX)
    # Default to empty on macOS, "64" on some Linux systems
    set(LIB_SUFFIX "")
endif()

set(GR_INCLUDE_DIR ${CMAKE_INSTALL_PREFIX}/include)
set(GR_LIBRARY_DIR ${CMAKE_INSTALL_PREFIX}/lib${LIB_SUFFIX})
set(GR_PKG_DATA_DIR ${CMAKE_INSTALL_PREFIX}/share/gnuradio)

########################################################################
# Python
########################################################################
# Use the Python from the current environment (conda)
find_program(PYTHON3_EXECUTABLE python3 PATHS ENV PATH NO_DEFAULT_PATH)
if(NOT PYTHON3_EXECUTABLE)
    find_program(PYTHON3_EXECUTABLE python3)
endif()

if(PYTHON3_EXECUTABLE)
    set(Python3_EXECUTABLE ${PYTHON3_EXECUTABLE})
    execute_process(
        COMMAND ${PYTHON3_EXECUTABLE} -c "import sys; print(sys.executable)"
        OUTPUT_VARIABLE PYTHON_EXE
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    message(STATUS "Using Python: ${PYTHON_EXE}")
endif()

find_package(Python3 COMPONENTS Interpreter Development REQUIRED)

# Get GNU Radio prefix to find GRC blocks directory (after Python is found)
execute_process(
    COMMAND ${Python3_EXECUTABLE} -c "from gnuradio import gr; import os; print(os.path.join(gr.prefix(), 'share', 'gnuradio', 'grc', 'blocks'))"
    OUTPUT_VARIABLE GRC_BLOCKS_DIR
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
)

# Fallback to standard location if above fails
if(NOT GRC_BLOCKS_DIR)
    set(GRC_BLOCKS_DIR ${GR_PKG_DATA_DIR}/grc/blocks)
endif()

message(STATUS "GRC blocks directory: ${GRC_BLOCKS_DIR}")

# Get Python site-packages directory from the found Python
execute_process(
    COMMAND ${Python3_EXECUTABLE} -c "import site; print(site.getsitepackages()[0])"
    OUTPUT_VARIABLE PYTHON_SITE_PACKAGES
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
)

# Fallback: try to get from sysconfig if site.getsitepackages() fails
if(NOT PYTHON_SITE_PACKAGES)
    execute_process(
        COMMAND ${Python3_EXECUTABLE} -c "import sysconfig; print(sysconfig.get_path('purelib'))"
        OUTPUT_VARIABLE PYTHON_SITE_PACKAGES
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
endif()

message(STATUS "Python site-packages: ${PYTHON_SITE_PACKAGES}")

# Install Python module to site-packages
install(DIRECTORY python/
    DESTINATION ${PYTHON_SITE_PACKAGES}/delta_pulse
    FILES_MATCHING
    PATTERN "*.py"
    PATTERN "__pycache__" EXCLUDE
    PATTERN "*.pyc" EXCLUDE
)

########################################################################
# Install gnuradio blocks (grc)
########################################################################
install(FILES
    grc/delta_pulse_source.block.yml
    DESTINATION ${GRC_BLOCKS_DIR}
)

########################################################################
# Install CMake search helper for this module (optional)
########################################################################
# Try to include GrMiscUtils if available (for GNU Radio 3.9+)
# This helps with module discovery but is not strictly required
include(GrMiscUtils OPTIONAL)
if(COMMAND GR_REGISTER_COMPONENT)
    GR_REGISTER_COMPONENT("delta_pulse" ENABLE
        ${PYTHON_SITE_PACKAGES}/delta_pulse/__init__.py
        ${GRC_BLOCKS_DIR}/delta_pulse_source.block.yml
    )
endif()

########################################################################
# Print summary
########################################################################
message(STATUS "")
message(STATUS "Using install prefix: ${CMAKE_INSTALL_PREFIX}")
message(STATUS "GRC blocks will be installed to: ${GRC_BLOCKS_DIR}")
message(STATUS "Python modules will be installed to: ${PYTHON_SITE_PACKAGES}/delta_pulse")
message(STATUS "")

