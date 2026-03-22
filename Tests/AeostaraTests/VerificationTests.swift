// Copyright (c) 2026 James Daley. All Rights Reserved.

import XCTest
@testable import AeostaraDomain

final class VerificationTests: XCTestCase {

    func testVerificationSucceeds() {
        let fs = InMemoryFileSystem()
        fs.files["/config.json"] = """
        { "server": { "host": "localhost", "port": 8080 } }
        """

        let desired = DesiredState(
            data: [
                "server": AnyCodable(["host": "localhost", "port": 8080])
            ],
            source: "/desired.json"
        )

        let verifier = Verification(policyEvaluator: PolicyEvaluator())
        let result = verifier.verify(
            configPath: "/config.json",
            desired: desired,
            invariants: [],
            fileSystem: fs,
            timestamp: "2026-03-22T00:00:00Z"
        )

        XCTAssertTrue(result.success)
        XCTAssertTrue(result.failedChecks.isEmpty)
    }

    func testVerificationFailsOnMismatch() {
        let fs = InMemoryFileSystem()
        fs.files["/config.json"] = """
        { "server": { "host": "localhost", "port": 9090 } }
        """

        let desired = DesiredState(
            data: [
                "server": AnyCodable(["host": "localhost", "port": 8080])
            ],
            source: "/desired.json"
        )

        let verifier = Verification(policyEvaluator: PolicyEvaluator())
        let result = verifier.verify(
            configPath: "/config.json",
            desired: desired,
            invariants: [],
            fileSystem: fs,
            timestamp: "2026-03-22T00:00:00Z"
        )

        XCTAssertFalse(result.success)
        XCTAssertTrue(result.failedChecks.contains { $0.contains("server.port") })
    }

    func testVerificationFailsOnMissingFile() {
        let fs = InMemoryFileSystem()
        let desired = DesiredState(data: ["key": AnyCodable("value")], source: "/desired.json")

        let verifier = Verification(policyEvaluator: PolicyEvaluator())
        let result = verifier.verify(
            configPath: "/missing.json",
            desired: desired,
            invariants: [],
            fileSystem: fs,
            timestamp: "2026-03-22T00:00:00Z"
        )

        XCTAssertFalse(result.success)
        XCTAssertTrue(result.failedChecks.contains { $0.contains("Cannot re-read") })
    }

    func testVerificationChecksInvariants() {
        let fs = InMemoryFileSystem()
        fs.files["/config.json"] = """
        { "server": { "port": 3306 } }
        """

        let desired = DesiredState(
            data: ["server": AnyCodable(["port": 3306])],
            source: "/desired.json"
        )

        let invariant = Invariant(
            invariantID: "INV-001",
            name: "Port Must Be 5432",
            expression: "server.port == 5432"
        )

        let verifier = Verification(policyEvaluator: PolicyEvaluator())
        let result = verifier.verify(
            configPath: "/config.json",
            desired: desired,
            invariants: [invariant],
            fileSystem: fs,
            timestamp: "2026-03-22T00:00:00Z"
        )

        XCTAssertFalse(result.success)
        XCTAssertTrue(result.failedChecks.contains { $0.contains("Port Must Be 5432") })
    }
}
