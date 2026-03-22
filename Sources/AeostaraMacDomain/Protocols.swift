// Copyright (c) 2026 James Daley. All Rights Reserved.
// Aeostara — Deterministic JSON Configuration Drift Detection and Healing Platform

import Foundation

// MARK: - IHealingEngine

public protocol IHealingEngine {
    func validate(configPath: String, desiredPath: String, invariantsPath: String?) throws -> ValidationResult
    func diff(configPath: String, desiredPath: String, invariantsPath: String?) throws -> DiffResult
    func heal(configPath: String, desiredPath: String, invariantsPath: String?, auditPath: String) throws -> HealResult
}

// MARK: - IConfigAdapter

public protocol IConfigAdapter {
    func observe(filePath: String) throws -> ObservedState
    func encode(observed: ObservedState, desired: DesiredState) -> EncodedState
    func applyRepair(filePath: String, plan: RepairPlan) throws -> Bool
}

// MARK: - IBackupProvider

public protocol IBackupProvider {
    func createBackup(filePath: String) throws -> String
    func restoreBackup(backupPath: String, originalPath: String) throws -> Bool
}

// MARK: - IAuditSink

public protocol IAuditSink {
    func record(event: AuditEvent) throws
    func getEvents() throws -> [AuditEvent]
}

// MARK: - IFileSystem

public protocol IFileSystem {
    func readFile(path: String) throws -> String
    func writeFile(path: String, content: String) throws
    func fileExists(path: String) -> Bool
    func copyFile(from sourcePath: String, to destinationPath: String) throws -> Bool
    func appendFile(path: String, content: String) throws
}
