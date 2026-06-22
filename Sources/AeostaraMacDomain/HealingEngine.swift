// Copyright (c) 2026 James Daley. All Rights Reserved.
// Aeostara — Deterministic JSON Configuration Drift Detection and Healing Platform

import Foundation

/// Orchestrates the complete 15-step deterministic healing flow.
/// Implements validate, diff, and heal operations per spec.
public final class HealingEngine: IHealingEngine {

    private let adapter: IConfigAdapter
    private let backupManager: IBackupProvider
    private let driftAnalyzer: DriftAnalyzer
    private let repairPlanner: RepairPlanner
    private let policyEvaluator: PolicyEvaluator
    private let invariantParser: InvariantParser
    private let verification: Verification
    private let rollbackManager: RollbackManager
    private let fileSystem: IFileSystem
    private let timestampProvider: () -> String
    private let eventIDProvider: () -> String

    public init(
        adapter: IConfigAdapter,
        backupManager: IBackupProvider,
        driftAnalyzer: DriftAnalyzer,
        repairPlanner: RepairPlanner,
        policyEvaluator: PolicyEvaluator,
        invariantParser: InvariantParser,
        verification: Verification,
        rollbackManager: RollbackManager,
        fileSystem: IFileSystem,
        timestampProvider: @escaping () -> String,
        eventIDProvider: @escaping () -> String
    ) {
        self.adapter = adapter
        self.backupManager = backupManager
        self.driftAnalyzer = driftAnalyzer
        self.repairPlanner = repairPlanner
        self.policyEvaluator = policyEvaluator
        self.invariantParser = invariantParser
        self.verification = verification
        self.rollbackManager = rollbackManager
        self.fileSystem = fileSystem
        self.timestampProvider = timestampProvider
        self.eventIDProvider = eventIDProvider
    }

    // MARK: - Validate

    public func validate(configPath: String, desiredPath: String, invariantsPath: String?) throws -> ValidationResult {
        // 1. Observe
        let observed: ObservedState
        do {
            observed = try adapter.observe(filePath: configPath)
        } catch {
            return ValidationResult(valid: false, errors: ["Cannot load config: \(error.localizedDescription)"], drifts: [], violations: [])
        }

        // 2. Load desired
        let desired: DesiredState
        do {
            desired = try loadDesiredState(path: desiredPath)
        } catch {
            return ValidationResult(valid: false, errors: ["Cannot load desired state: \(error.localizedDescription)"], drifts: [], violations: [])
        }

        // 3. Load invariants
        let invariants = (try? invariantParser.parseInvariants(from: invariantsPath, fileSystem: fileSystem)) ?? []

        // 4. Encode
        let encoded = adapter.encode(observed: observed, desired: desired)

        // 5. Analyze drift
        let drifts = driftAnalyzer.analyzeDrift(encoded: encoded)

        // 6. Check invariants against observed state
        let violations = policyEvaluator.checkInvariants(invariants, state: encoded.observed)

        // 7. Return result
        return ValidationResult(
            valid: drifts.isEmpty,
            errors: [],
            drifts: drifts,
            violations: violations
        )
    }

    // MARK: - Diff

    public func diff(configPath: String, desiredPath: String, invariantsPath: String?) throws -> DiffResult {
        // 1. Observe
        let observed = try adapter.observe(filePath: configPath)

        // 2. Load desired
        let desired = try loadDesiredState(path: desiredPath)

        // 3. Encode
        let encoded = adapter.encode(observed: observed, desired: desired)

        // 4. Analyze drift
        let drifts = driftAnalyzer.analyzeDrift(encoded: encoded)

        // 5. Generate plan
        let plan: RepairPlan? = drifts.isEmpty ? nil : repairPlanner.generateRepairPlan(drifts: drifts, timestamp: timestampProvider())

        return DiffResult(drifts: drifts, proposedPlan: plan)
    }

    // MARK: - Heal (15-step flow)

    public func heal(configPath: String, desiredPath: String, invariantsPath: String?, auditPath: String) throws -> HealResult {
        let auditTrail = AuditTrail(auditPath: auditPath, fileSystem: fileSystem)
        var auditEvents: [AuditEvent] = []

        func audit(_ type: AuditEventType, details: [String: AnyCodable]? = nil) {
            let event = AuditTrail.createEvent(
                type: type,
                configFile: configPath,
                details: details,
                eventID: eventIDProvider(),
                timestamp: timestampProvider()
            )
            try? auditTrail.record(event: event)
            auditEvents.append(event)
        }

        // Step 1: Observe
        let observed: ObservedState
        do {
            observed = try adapter.observe(filePath: configPath)
        } catch {
            return HealResult(success: false, message: "Cannot load config: \(error.localizedDescription)")
        }

        // Step 2: Load desired state
        let desired: DesiredState
        do {
            desired = try loadDesiredState(path: desiredPath)
        } catch {
            return HealResult(success: false, message: "Cannot load desired state: \(error.localizedDescription)")
        }

        // Step 3: Parse invariants
        let invariants = (try? invariantParser.parseInvariants(from: invariantsPath, fileSystem: fileSystem)) ?? []

        // Step 4: Encode
        let encoded = adapter.encode(observed: observed, desired: desired)

        // Step 5: Analyze drift
        let drifts = driftAnalyzer.analyzeDrift(encoded: encoded)

        // Step 6: No drift?
        if drifts.isEmpty {
            audit(.noDrift)
            return HealResult(success: true, auditEvents: auditEvents, message: "No drift detected")
        }

        // Step 7: Generate repair plan
        let plan = repairPlanner.generateRepairPlan(drifts: drifts, timestamp: timestampProvider())

        // Step 8: Evaluate policy
        let policyDecision = policyEvaluator.evaluatePolicy(
            plan: plan,
            invariants: invariants,
            state: observed.data
        )

        // Step 9: Policy blocked?
        if !policyDecision.allowed {
            audit(.policyBlocked, details: ["reason": AnyCodable(policyDecision.reason)])
            return HealResult(
                success: false,
                executedPlan: plan,
                auditEvents: auditEvents,
                message: "Policy blocked: \(policyDecision.reason)"
            )
        }

        // Step 10: Audit heal started
        audit(.healStarted, details: ["planID": AnyCodable(plan.planID)])

        // Step 11: Create backup
        let backupPath: String
        do {
            backupPath = try backupManager.createBackup(filePath: configPath)
            audit(.backupCreated, details: ["backupPath": AnyCodable(backupPath)])
        } catch {
            return HealResult(success: false, executedPlan: plan, auditEvents: auditEvents, message: "Backup failed: \(error.localizedDescription)")
        }

        // Step 12: Apply repair
        let applied: Bool
        do {
            applied = try adapter.applyRepair(filePath: configPath, plan: plan)
        } catch {
            applied = false
        }

        if !applied {
            let rollbackPlan = rollbackManager.createRollbackPlan(planID: plan.planID, backupPath: backupPath, originalPath: configPath)
            _ = try? rollbackManager.executeRollback(plan: rollbackPlan)
            audit(.rollbackExecuted, details: ["reason": AnyCodable("Repair apply failed")])
            return HealResult(
                success: false,
                executedPlan: plan,
                rollback: rollbackPlan,
                auditEvents: auditEvents,
                message: "Repair apply failed, rolled back"
            )
        }

        audit(.repairApplied, details: ["planID": AnyCodable(plan.planID)])

        // Step 13: Verify
        let verificationResult = verification.verify(
            configPath: configPath,
            desired: desired,
            invariants: invariants,
            fileSystem: fileSystem,
            timestamp: timestampProvider()
        )

        // Step 14: Verification succeeded?
        if verificationResult.success {
            audit(.verificationSucceeded, details: ["planID": AnyCodable(plan.planID)])
            return HealResult(
                success: true,
                executedPlan: plan,
                verification: verificationResult,
                auditEvents: auditEvents,
                message: "Heal successful"
            )
        }

        // Step 15: Verification failed — rollback
        audit(.verificationFailed, details: ["failedChecks": AnyCodable(verificationResult.failedChecks)])
        let rollbackPlan = rollbackManager.createRollbackPlan(planID: plan.planID, backupPath: backupPath, originalPath: configPath)
        _ = try? rollbackManager.executeRollback(plan: rollbackPlan)
        audit(.rollbackExecuted, details: ["reason": AnyCodable("Verification failed")])

        return HealResult(
            success: false,
            executedPlan: plan,
            verification: verificationResult,
            rollback: rollbackPlan,
            auditEvents: auditEvents,
            message: "Verification failed, rolled back to backup"
        )
    }

    // MARK: - Private Helpers

    private func loadDesiredState(path: String) throws -> DesiredState {
        let content = try fileSystem.readFile(path: path)
        guard let data = content.data(using: .utf8),
              let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AeostaraError.cannotLoadDesiredState(path)
        }

        let anyCodableData = parsed.mapValues { AnyCodable($0) }
        return DesiredState(data: anyCodableData, source: path)
    }
}
