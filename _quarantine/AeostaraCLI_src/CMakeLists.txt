# Aeostara CLI — Executable
# Copyright (c) 2026 James Daley. All Rights Reserved.

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
