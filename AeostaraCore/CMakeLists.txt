# AeostaraCore — C++20 Static Library (iOS)
# Copyright (c) 2026 James Daley. All Rights Reserved.

add_library(AeostaraCore STATIC
    src/Version.cpp
    src/Contracts.cpp
    src/Invariant.cpp
    src/InvariantParser.cpp
    src/JsonPath.cpp
    src/DriftAnalyzer.cpp
    src/RepairPlanner.cpp
    src/PolicyEvaluator.cpp
    src/BackupManager.cpp
    src/Verification.cpp
    src/RollbackManager.cpp
    src/AuditTrail.cpp
    src/HealingEngine.cpp
    src/JsonConfigAdapter.cpp
    src/FileSystem.cpp
)

target_include_directories(AeostaraCore
    PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include
)

# nlohmann/json is embedded as single-header (no vcpkg on iOS)
# The header is at AeostaraCore/include/nlohmann/json.hpp
