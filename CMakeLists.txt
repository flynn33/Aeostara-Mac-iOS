# Aeostara — macOS Native Build
# Copyright (c) 2026 James Daley. All Rights Reserved.
# Proprietary and Confidential.

cmake_minimum_required(VERSION 3.28)
project(Aeostara VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Apple Clang warnings — treat warnings as errors
if(CMAKE_CXX_COMPILER_ID MATCHES "Clang|AppleClang")
    add_compile_options(-Wall -Wextra -Werror -Wpedantic)
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    add_compile_options(-Wall -Wextra -Werror -Wpedantic)
endif()

# Dependencies
find_package(nlohmann_json CONFIG REQUIRED)

# Source root for architecture tests
add_compile_definitions(AEOSTARA_SOURCE_DIR="${CMAKE_SOURCE_DIR}")

# Subdirectories
add_subdirectory(src/AeostaraCore)
add_subdirectory(src/AeostaraCLI)

# Testing
option(BUILD_TESTING "Build tests" ON)
if(BUILD_TESTING)
    enable_testing()
    add_subdirectory(tests)
endif()
