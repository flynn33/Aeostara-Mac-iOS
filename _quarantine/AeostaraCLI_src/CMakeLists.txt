# Aeostara CLI — Executable
# Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.

add_executable(aeostara
    Main.cpp
    CommandParser.cpp
    CLIRunner.cpp
)

target_include_directories(aeostara
    PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(aeostara
    PRIVATE AeostaraCore
)
