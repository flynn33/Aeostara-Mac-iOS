// Copyright (c) 2026 James Daley. All Rights Reserved.
// Aeostara — Deterministic JSON Configuration Drift Detection and Healing Platform

import Foundation
import SwiftUI
import AeostaraDomain
import AeostaraServices

/// Main view model coordinating domain healing operations for the iOS app.
@MainActor
public final class AeostaraViewModel: ObservableObject {

    @Published public var configPath: String?
    @Published public var desiredPath: String?
    @Published public var invariantsPath: String?
    @Published public var statusMessage: String = "Ready"
    @Published public var drifts: [DriftEvent] = []
    @Published public var lastResult: String = ""
    @Published public var isProcessing: Bool = false

    private let fileSystem: SandboxFileSystem
    private let engine: HealingEngine
    private let documentImporter: DocumentImporter

    public init() {
        let fs = SandboxFileSystem()
        self.fileSystem = fs

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

        let adapter = JsonConfigAdapter(fileSystem: fs, timestampProvider: timestampProvider)
        let backupManager = BackupManager(fileSystem: fs, timestampProvider: backupTimestampProvider)
        let policyEvaluator = PolicyEvaluator()

        self.engine = HealingEngine(
            adapter: adapter,
            backupManager: backupManager,
            driftAnalyzer: DriftAnalyzer(),
            repairPlanner: RepairPlanner(),
            policyEvaluator: policyEvaluator,
            invariantParser: InvariantParser(),
            verification: Verification(policyEvaluator: policyEvaluator),
            rollbackManager: RollbackManager(backupProvider: backupManager),
            fileSystem: fs,
            timestampProvider: timestampProvider,
            eventIDProvider: { UUID().uuidString }
        )

        self.documentImporter = DocumentImporter(fileSystem: fs)
    }

    // MARK: - File Import

    public func importConfig(from url: URL) {
        do {
            configPath = try documentImporter.importFile(from: url)
            statusMessage = "Config imported: \(url.lastPathComponent)"
        } catch {
            statusMessage = "Failed to import config: \(error.localizedDescription)"
        }
    }

    public func importDesired(from url: URL) {
        do {
            desiredPath = try documentImporter.importFile(from: url)
            statusMessage = "Desired state imported: \(url.lastPathComponent)"
        } catch {
            statusMessage = "Failed to import desired state: \(error.localizedDescription)"
        }
    }

    public func importInvariants(from url: URL) {
        do {
            invariantsPath = try documentImporter.importFile(from: url)
            statusMessage = "Invariants imported: \(url.lastPathComponent)"
        } catch {
            statusMessage = "Failed to import invariants: \(error.localizedDescription)"
        }
    }

    // MARK: - Operations

    public func validate() {
        guard let config = configPath, let desired = desiredPath else {
            statusMessage = "Import config and desired state first"
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            let result = try engine.validate(configPath: config, desiredPath: desired, invariantsPath: invariantsPath)
            drifts = result.drifts
            if result.valid {
                lastResult = "VALID: No drift detected."
                statusMessage = "Validation passed"
            } else {
                lastResult = "DRIFT: \(result.drifts.count) difference(s) found."
                statusMessage = "Drift detected"
            }
        } catch {
            lastResult = "Error: \(error.localizedDescription)"
            statusMessage = "Validation failed"
        }
    }

    public func diff() {
        guard let config = configPath, let desired = desiredPath else {
            statusMessage = "Import config and desired state first"
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            let result = try engine.diff(configPath: config, desiredPath: desired, invariantsPath: invariantsPath)
            drifts = result.drifts
            if result.drifts.isEmpty {
                lastResult = "No drift detected."
            } else if let plan = result.proposedPlan {
                lastResult = "Plan \(plan.planID): \(plan.actions.count) action(s)"
            }
            statusMessage = "Diff complete"
        } catch {
            lastResult = "Error: \(error.localizedDescription)"
            statusMessage = "Diff failed"
        }
    }

    public func heal() {
        guard let config = configPath, let desired = desiredPath else {
            statusMessage = "Import config and desired state first"
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        let auditPath = fileSystem.documentsPath(for: "audit/audit.jsonl")

        do {
            let result = try engine.heal(configPath: config, desiredPath: desired, invariantsPath: invariantsPath, auditPath: auditPath)
            lastResult = result.message
            statusMessage = result.success ? "Heal successful" : "Heal failed"
            drifts = []
        } catch {
            lastResult = "Error: \(error.localizedDescription)"
            statusMessage = "Heal failed"
        }
    }
}
