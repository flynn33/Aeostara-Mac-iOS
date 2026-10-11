# Aeostara Core — Static Library
# Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.

add_library(AeostaraCore STATIC
    Version.cpp
    Contracts.cpp
    Invariant.cpp
    InvariantParser.cpp
    JsonPath.cpp
    DriftAnalyzer.cpp
    RepairPlanner.cpp
    PolicyEvaluator.cpp
    BackupManager.cpp
    Verification.cpp
    RollbackManager.cpp
    AuditTrail.cpp
    HealingEngine.cpp
    JsonConfigAdapter.cpp
    FileSystem.cpp
)

target_include_directories(AeostaraCore
    PUBLIC ${CMAKE_SOURCE_DIR}/include
)

target_link_libraries(AeostaraCore
    PUBLIC nlohmann_json::nlohmann_json
)
