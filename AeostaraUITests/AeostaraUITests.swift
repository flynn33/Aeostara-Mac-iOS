// Aeostara — iOS UI Smoke Tests
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.
//
// Basic UI smoke tests to verify the app launches and
// core UI elements are present and interactive.

import XCTest

final class AeostaraUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.exists)
    }

    func testValidateButtonExists() throws {
        let app = XCUIApplication()
        app.launch()

        let validateButton = app.buttons["Validate"]
        XCTAssertTrue(validateButton.waitForExistence(timeout: 5))
    }

    func testDiffButtonExists() throws {
        let app = XCUIApplication()
        app.launch()

        let diffButton = app.buttons["Diff"]
        XCTAssertTrue(diffButton.waitForExistence(timeout: 5))
    }

    func testHealButtonExists() throws {
        let app = XCUIApplication()
        app.launch()

        let healButton = app.buttons["Heal"]
        XCTAssertTrue(healButton.waitForExistence(timeout: 5))
    }
}
