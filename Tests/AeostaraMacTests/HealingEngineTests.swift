// Copyright (c) 2026 James Daley. All Rights Reserved.

import XCTest
@testable import AeostaraMacDomain

final class HealingEngineTests: XCTestCase {

    func testValidateWithValidConfig() throws {
        let fs = InMemoryFileSystem()
        fs.files["/config.json"] = """
        { "key": "value" }
        """
        fs.files["/desired.json"] = """
        { "key": "value" }
        """
        let engine = buildTestEngine(fileSystem: fs)

        let result = try engine.validate(configPath: "/config.json", desiredPath: "/desired.json", invariantsPath: nil)
        XCTAssertTrue(result.valid)
    }

    func testValidateWithDrift() throws {
        let fs = InMemoryFileSystem()
        fs.files["/config.json"] = """
        { "key": "old" }
        """
        fs.files["/desired.json"] = """
        { "key": "new" }
        """
        let engine = buildTestEngine(fileSystem: fs)

        let result = try engine.validate(configPath: "/config.json", desiredPath: "/desired.json", invariantsPath: nil)
        XCTAssertFalse(result.valid)
        XCTAssertEqual(result.drifts.count, 1)
    }

    func testDiffWithNoDrift() throws {
        let fs = InMemoryFileSystem()
        fs.files["/config.json"] = """
        { "key": "value" }
        """
        fs.files["/desired.json"] = """
        { "key": "value" }
        """
        let engine = buildTestEngine(fileSystem: fs)

        let result = try engine.diff(configPath: "/config.json", desiredPath: "/desired.json", invariantsPath: nil)
        XCTAssertTrue(result.drifts.isEmpty)
        XCTAssertNil(result.proposedPlan)
    }

    func testHealCreatesBackup() throws {
        let fs = InMemoryFileSystem()
        fs.files["/config.json"] = """
        { "key": "old" }
        """
        fs.files["/desired.json"] = """
        { "key": "new" }
        """
        let engine = buildTestEngine(fileSystem: fs)

        let result = try engine.heal(configPath: "/config.json", desiredPath: "/desired.json", invariantsPath: nil, auditPath: "/audit.jsonl")
        XCTAssertTrue(result.success)
        XCTAssertTrue(fs.fileExists(path: "/config.json.backup.20260322_000000"))
    }

    func testHealWithMissingConfig() throws {
        let fs = InMemoryFileSystem()
        fs.files["/desired.json"] = """
        { "key": "value" }
        """
        let engine = buildTestEngine(fileSystem: fs)

        let result = try engine.heal(configPath: "/missing.json", desiredPath: "/desired.json", invariantsPath: nil, auditPath: "/audit.jsonl")
        XCTAssertFalse(result.success)
        XCTAssertTrue(result.message.contains("Cannot load config"))
    }
}
