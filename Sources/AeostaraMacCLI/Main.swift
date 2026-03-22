// Copyright (c) 2026 James Daley. All Rights Reserved.
// Aeostara — Deterministic JSON Configuration Drift Detection and Healing Platform

import Foundation
import AeostaraMacDomain
import AeostaraMacServices

// MARK: - Dependency Injection Bootstrap

let fileSystem = DefaultFileSystem()

let timestampProvider: () -> String = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
    formatter.timeZone = TimeZone(identifier: "UTC")
    return formatter.string(from: Date())
}

let backupTimestampProvider: () -> String = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd_HHmmss"
    formatter.timeZone = TimeZone(identifier: "UTC")
    return formatter.string(from: Date())
}

let eventIDProvider: () -> String = {
    UUID().uuidString
}

let adapter = JsonConfigAdapter(fileSystem: fileSystem, timestampProvider: timestampProvider)
let backupManager = BackupManager(fileSystem: fileSystem, timestampProvider: backupTimestampProvider)
let driftAnalyzer = DriftAnalyzer()
let repairPlanner = RepairPlanner()
let policyEvaluator = PolicyEvaluator()
let invariantParser = InvariantParser()
let verification = Verification(policyEvaluator: policyEvaluator)
let rollbackManager = RollbackManager(backupProvider: backupManager)

let engine = HealingEngine(
    adapter: adapter,
    backupManager: backupManager,
    driftAnalyzer: driftAnalyzer,
    repairPlanner: repairPlanner,
    policyEvaluator: policyEvaluator,
    invariantParser: invariantParser,
    verification: verification,
    rollbackManager: rollbackManager,
    fileSystem: fileSystem,
    timestampProvider: timestampProvider,
    eventIDProvider: eventIDProvider
)

// MARK: - Run

let command = CommandParser.parse(CommandLine.arguments)
let runner = CLIRunner(engine: engine)
let exitCode = runner.run(command: command)
exit(exitCode)
