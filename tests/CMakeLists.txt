# Aeostara Tests — Catch2
# Copyright (c) 2026 James Daley. All Rights Reserved.

find_package(Catch2 3 CONFIG REQUIRED)
include(Catch2::Catch2WithMain)
include(CTest)

# Core Tests
add_executable(AeostaraCoreTests
    AeostaraCoreTests/CoreTests.cpp
)
target_include_directories(AeostaraCoreTests
    PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/AeostaraCoreTests
)
target_link_libraries(AeostaraCoreTests
    PRIVATE AeostaraCore Catch2::Catch2WithMain
)
catch_discover_tests(AeostaraCoreTests)

# Architecture Enforcement Tests
add_executable(AeostaraArchitectureTests
    AeostaraArchitectureTests/ArchitectureTests.cpp
)
target_link_libraries(AeostaraArchitectureTests
    PRIVATE Catch2::Catch2WithMain
)
catch_discover_tests(AeostaraArchitectureTests)
