# ############
# CosmoStat #
# ############

# -------------- #
# Project Set Up #
# -------------- #

cmake_minimum_required(VERSION 3.12.0)
project(cosmostat)

# Include custom modules in CMake module path
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/")

# Load CMake tools
include(ExternalProject)
include(FindPkgConfig)

# Find Python
find_package(Python COMPONENTS Interpreter Development)
message(STATUS "Python binding install path : ${Python_EXECUTABLE}")

# Add an option to build or skip Sparse2D
option(BUILD_SPARSE2D "Build the Sparse2D binaries" OFF)

if(BUILD_SPARSE2D)
    # Set install directory for Sparse2D binaries
    get_filename_component(SPARSE2D_INSTALL_DIR ${Python_EXECUTABLE} DIRECTORY)
    message(STATUS "Binary install path : ${SPARSE2D_INSTALL_DIR}")

    # Build Sparse2D
    include(BuildSparse2D)
else()
    message(STATUS "Skipping Sparse2D build.")
endif()
