# Aeostara Tests — iOS (XCTest via CMake)
# Copyright (c) 2026 James Daley. All Rights Reserved.
#
# When generating with Xcode, these tests can be run via:
#   xcodebuild test -project build/ios/Aeostara.xcodeproj -scheme AeostaraTests
#
# For non-Xcode builds (e.g. Ninja on macOS for validation):
#   The .mm test file requires an Objective-C++ compiler and XCTest framework.

# XCTest bridge tests (Objective-C++)
add_library(AeostaraTests MODULE
    AeostaraBridgeTests.mm
)

target_include_directories(AeostaraTests
    PRIVATE ${CMAKE_SOURCE_DIR}/platform/ios/AeostaraKit
    PRIVATE ${CMAKE_SOURCE_DIR}/AeostaraCore/include
)

target_link_libraries(AeostaraTests
    PRIVATE AeostaraCore
)

# Link XCTest framework (available on Apple platforms)
if(APPLE)
    find_library(XCTEST_FRAMEWORK XCTest)
    find_library(FOUNDATION_FRAMEWORK Foundation)
    if(XCTEST_FRAMEWORK AND FOUNDATION_FRAMEWORK)
        target_link_libraries(AeostaraTests
            PRIVATE ${XCTEST_FRAMEWORK} ${FOUNDATION_FRAMEWORK}
        )
    endif()
endif()
