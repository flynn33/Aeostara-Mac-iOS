// Copyright (c) 2026 James Daley. All Rights Reserved.

import XCTest
@testable import AeostaraMacDomain

final class BackupRollbackTests: XCTestCase {

    func testCreateBackup() throws {
        let fs = InMemoryFileSystem()
        fs.files["/config.json"] = "original content"

        let backup = BackupManager(fileSystem: fs, timestampProvider: fixedTimestamp("20260322_120000"))
        let backupPath = try backup.createBackup(filePath: "/config.json")

        XCTAssertEqual(backupPath, "/config.json.backup.20260322_120000")
        XCTAssertEqual(fs.files[backupPath], "original content")
    }

    func testRestoreBackup() throws {
        let fs = InMemoryFileSystem()
        fs.files["/config.json"] = "modified content"
        fs.files["/config.json.backup.20260322_120000"] = "original content"

        let backup = BackupManager(fileSystem: fs, timestampProvider: fixedTimestamp("20260322_120000"))
        let success = try backup.restoreBackup(
            backupPath: "/config.json.backup.20260322_120000",
            originalPath: "/config.json"
        )

        XCTAssertTrue(success)
        XCTAssertEqual(fs.files["/config.json"], "original content")
    }

    func testRestoreMissingBackup() throws {
        let fs = InMemoryFileSystem()
        let backup = BackupManager(fileSystem: fs, timestampProvider: fixedTimestamp())

        let success = try backup.restoreBackup(backupPath: "/nonexistent", originalPath: "/config.json")
        XCTAssertFalse(success)
    }

    func testRollbackManagerFlow() throws {
        let fs = InMemoryFileSystem()
        fs.files["/config.json"] = "modified"
        fs.files["/config.json.backup"] = "original"

        let backup = BackupManager(fileSystem: fs, timestampProvider: fixedTimestamp())
        let rollback = RollbackManager(backupProvider: backup)

        let plan = rollback.createRollbackPlan(
            planID: "plan-123",
            backupPath: "/config.json.backup",
            originalPath: "/config.json"
        )

        XCTAssertEqual(plan.planID, "plan-123")

        let success = try rollback.executeRollback(plan: plan)
        XCTAssertTrue(success)
        XCTAssertEqual(fs.files["/config.json"], "original")
    }
}
