// Copyright (c) 2026 James Daley. All Rights Reserved.
// Acceptance tests mapping to main/specs/acceptance/acceptance_targets.md

import XCTest
@testable import AeostaraDomain

final class AcceptanceTests: XCTestCase {

    // MARK: - Fixture Data

    static let validConfig = """
    {
      "server": { "host": "localhost", "port": 8080, "ssl_enabled": true },
      "database": { "host": "db.example.com", "port": 5432, "name": "aeostara_prod" },
      "logging": { "level": "INFO", "file": "/var/log/aeostara.log" }
    }
    """

    static let repairableConfig = """
    {
      "server": { "host": "localhost", "port": 9090, "ssl_enabled": true },
      "database": { "host": "db.example.com", "port": 3306, "name": "aeostara_dev" },
      "logging": { "level": "DEBUG", "file": "/var/log/aeostara.log" }
    }
    """

    static let policyBlockedConfig = """
    {
      "server": { "host": "localhost", "port": 8080, "ssl_enabled": false },
      "database": { "host": "db.example.com", "port": 3306, "name": "aeostara_prod" },
      "logging": { "level": "DEBUG", "file": "/var/log/aeostara.log" }
    }
    """

    static let invalidConfig = "{ this is not valid JSON }"

    static let desiredState = """
    {
      "server": { "host": "localhost", "port": 8080, "ssl_enabled": true },
      "database": { "host": "db.example.com", "port": 5432, "name": "aeostara_prod" },
      "logging": { "level": "INFO", "file": "/var/log/aeostara.log" }
    }
    """

    static let invariants = """
    [
      { "invariant_id": "INV-001", "name": "Database Port Standard", "description": "Database port must be 5432", "severity": "High", "expression": "database.port == 5432", "applies_to": ["database"], "auto_remediate": true },
      { "invariant_id": "INV-002", "name": "SSL Required", "description": "SSL must be enabled", "severity": "Critical", "expression": "server.ssl_enabled == true", "applies_to": ["server"], "auto_remediate": true },
      { "invariant_id": "INV-003", "name": "Log Level Valid", "description": "Log level must be INFO", "severity": "Medium", "expression": "logging.level == \\"INFO\\"", "applies_to": ["logging"], "auto_remediate": true }
    ]
    """

    // MARK: - Scenario 1: Valid Config — No Drift

    func testScenario1_ValidConfigNoDrift() throws {
        let fs = InMemoryFileSystem()
        fs.files["/config.json"] = Self.validConfig
        fs.files["/desired.json"] = Self.desiredState
        let engine = buildTestEngine(fileSystem: fs)

        let result = try engine.validate(configPath: "/config.json", desiredPath: "/desired.json", invariantsPath: nil)
        XCTAssertTrue(result.valid)
        XCTAssertTrue(result.drifts.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)
    }

    // MARK: - Scenario 2: Invalid Config — Parse Error

    func testScenario2_InvalidConfigParseError() throws {
        let fs = InMemoryFileSystem()
        fs.files["/config.json"] = Self.invalidConfig
        fs.files["/desired.json"] = Self.desiredState
        let engine = buildTestEngine(fileSystem: fs)

        let result = try engine.validate(configPath: "/config.json", desiredPath: "/desired.json", invariantsPath: nil)
        XCTAssertFalse(result.valid)
        XCTAssertFalse(result.errors.isEmpty)
    }

    // MARK: - Scenario 3: Policy Block — Critical Invariant Violation

    func testScenario3_PolicyBlocked() throws {
        // Use policy_blocked_config which has ssl_enabled=false
        // Add a Critical non-auto-remediate invariant for SSL
        let strictInvariants = """
        [
          { "invariant_id": "INV-SSL", "name": "SSL Required", "severity": "Critical", "expression": "server.ssl_enabled == true", "auto_remediate": false }
        ]
        """

        let fs = InMemoryFileSystem()
        fs.files["/config.json"] = Self.policyBlockedConfig
        fs.files["/desired.json"] = Self.desiredState
        fs.files["/invariants.json"] = strictInvariants
        let engine = buildTestEngine(fileSystem: fs)

        let result = try engine.heal(configPath: "/config.json", desiredPath: "/desired.json", invariantsPath: "/invariants.json", auditPath: "/audit.jsonl")
        XCTAssertFalse(result.success)
        XCTAssertTrue(result.message.contains("Policy blocked"))

        // Check audit contains PolicyBlocked event
        let auditContent = fs.files["/audit.jsonl"] ?? ""
        XCTAssertTrue(auditContent.contains("PolicyBlocked"))
    }

    // MARK: - Scenario 4: Successful Repair

    func testScenario4_SuccessfulRepair() throws {
        let fs = InMemoryFileSystem()
        fs.files["/config.json"] = Self.repairableConfig
        fs.files["/desired.json"] = Self.desiredState
        fs.files["/invariants.json"] = Self.invariants
        let engine = buildTestEngine(fileSystem: fs)

        let result = try engine.heal(configPath: "/config.json", desiredPath: "/desired.json", invariantsPath: "/invariants.json", auditPath: "/audit.jsonl")
        XCTAssertTrue(result.success)
        XCTAssertNotNil(result.executedPlan)
        XCTAssertNotNil(result.verification)
        XCTAssertTrue(result.verification?.success ?? false)

        // Backup should exist
        XCTAssertTrue(fs.fileExists(path: "/config.json.backup.20260322_000000"))

        // Audit trail should contain expected events
        let auditContent = fs.files["/audit.jsonl"] ?? ""
        XCTAssertTrue(auditContent.contains("HealStarted"))
        XCTAssertTrue(auditContent.contains("BackupCreated"))
        XCTAssertTrue(auditContent.contains("RepairApplied"))
        XCTAssertTrue(auditContent.contains("VerificationSucceeded"))
    }

    // MARK: - Scenario 5: Forced Rollback — Verification Failure

    func testScenario5_ForcedRollback() throws {
        // Use a file system that corrupts data on re-read after write
        let fs = CorruptOnVerifyFileSystem()
        fs.files["/config.json"] = Self.repairableConfig
        fs.files["/desired.json"] = Self.desiredState
        fs.files["/invariants.json"] = Self.invariants

        let adapter = TestConfigAdapterWithCorruptVerify(fileSystem: fs)
        let backupManager = BackupManager(fileSystem: fs, timestampProvider: fixedTimestamp("20260322_000000"))
        let policyEvaluator = PolicyEvaluator()
        let engine = HealingEngine(
            adapter: adapter,
            backupManager: backupManager,
            driftAnalyzer: DriftAnalyzer(),
            repairPlanner: RepairPlanner(),
            policyEvaluator: policyEvaluator,
            invariantParser: InvariantParser(),
            verification: Verification(policyEvaluator: policyEvaluator),
            rollbackManager: RollbackManager(backupProvider: backupManager),
            fileSystem: fs,
            timestampProvider: fixedTimestamp(),
            eventIDProvider: sequentialEventID()
        )

        let result = try engine.heal(configPath: "/config.json", desiredPath: "/desired.json", invariantsPath: "/invariants.json", auditPath: "/audit.jsonl")
        XCTAssertFalse(result.success)
        XCTAssertTrue(result.message.contains("rolled back"))
        XCTAssertNotNil(result.rollback)

        // Audit trail should contain rollback events
        let auditContent = fs.files["/audit.jsonl"] ?? ""
        XCTAssertTrue(auditContent.contains("VerificationFailed") || auditContent.contains("RollbackExecuted"))
    }

    // MARK: - Heal with no drift

    func testHealNoDrift() throws {
        let fs = InMemoryFileSystem()
        fs.files["/config.json"] = Self.validConfig
        fs.files["/desired.json"] = Self.desiredState
        let engine = buildTestEngine(fileSystem: fs)

        let result = try engine.heal(configPath: "/config.json", desiredPath: "/desired.json", invariantsPath: nil, auditPath: "/audit.jsonl")
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.message.contains("No drift"))
    }

    // MARK: - Diff shows plan

    func testDiffShowsPlan() throws {
        let fs = InMemoryFileSystem()
        fs.files["/config.json"] = Self.repairableConfig
        fs.files["/desired.json"] = Self.desiredState
        let engine = buildTestEngine(fileSystem: fs)

        let result = try engine.diff(configPath: "/config.json", desiredPath: "/desired.json", invariantsPath: nil)
        XCTAssertFalse(result.drifts.isEmpty)
        XCTAssertNotNil(result.proposedPlan)
        XCTAssertFalse(result.proposedPlan!.planID.isEmpty)
    }
}

// MARK: - Corrupt-on-verify file system for rollback testing

final class CorruptOnVerifyFileSystem: InMemoryFileSystem {
    var writeCount: [String: Int] = [:]

    override func writeFile(path: String, content: String) throws {
        writeCount[path, default: 0] += 1
        try super.writeFile(path: path, content: content)

        // After the repair write (second write to config), corrupt the data
        // so verification will fail
        if path == "/config.json" && writeCount[path, default: 0] >= 1 {
            // We'll override readFile to return garbage after repair
        }
    }
}

/// Config adapter that applies repair but returns corrupt data on verify re-read.
final class TestConfigAdapterWithCorruptVerify: IConfigAdapter {
    private let fileSystem: CorruptOnVerifyFileSystem
    private var repairApplied = false

    init(fileSystem: CorruptOnVerifyFileSystem) {
        self.fileSystem = fileSystem
    }

    func observe(filePath: String) throws -> ObservedState {
        let content = try fileSystem.readFile(path: filePath)
        guard let data = content.data(using: .utf8),
              let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AeostaraError.cannotParseJSON(filePath)
        }
        return ObservedState(
            sourceFile: filePath,
            data: parsed.mapValues { AnyCodable($0) },
            timestamp: "2026-03-22T00:00:00Z"
        )
    }

    func encode(observed: ObservedState, desired: DesiredState) -> EncodedState {
        let observedFlat = JsonPath.flatten(observed.data.mapValues { $0.value })
        let desiredFlat = JsonPath.flatten(desired.data.mapValues { $0.value })
        return EncodedState(
            observed: observedFlat.mapValues { AnyCodable($0) },
            desired: desiredFlat.mapValues { AnyCodable($0) }
        )
    }

    func applyRepair(filePath: String, plan: RepairPlan) throws -> Bool {
        // Apply the repair, but then write corrupt data so verification fails
        repairApplied = true
        let corruptConfig = """
        { "server": { "host": "CORRUPT", "port": 0, "ssl_enabled": false } }
        """
        try fileSystem.writeFile(path: filePath, content: corruptConfig)
        return true
    }
}
