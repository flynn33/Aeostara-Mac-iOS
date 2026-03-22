# Aeostara — iOS Build System
# Copyright (c) 2026 James Daley. All Rights Reserved.
# Proprietary and Confidential.
#
# Generates an Xcode project for the iOS Aeostara app.
# Usage: cmake -G Xcode -B build/ios -DCMAKE_SYSTEM_NAME=iOS
#    or: cmake -G Xcode -B build/ios (for macOS/simulator testing)

cmake_minimum_required(VERSION 3.28)
project(Aeostara VERSION 0.1.0 LANGUAGES CXX OBJCXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Warnings
add_compile_options(-Wall -Wextra -Werror -Wpedantic)

# Source root for architecture tests
add_compile_definitions(AEOSTARA_SOURCE_DIR="${CMAKE_SOURCE_DIR}")

# Subdirectories
add_subdirectory(AeostaraCore)

# Testing
option(BUILD_TESTING "Build tests" ON)
if(BUILD_TESTING)
    enable_testing()
    add_subdirectory(AeostaraTests)
endif()
