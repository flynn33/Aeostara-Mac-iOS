import Foundation
import AeostaraMacDomain

/// Explicit application bindings and resource/policy factories retain the legacy command signatures.
public final class NativeLegacyLifecycle: LegacySemanticLifecycle {
    private let context: SemanticContext
    private let resourceFactory: (String, String, String?) throws -> any NativeResourceIO
    private let policyFactory: (String?, JSONSnapshot, JSONSnapshot) throws -> NativePolicyContext
    private let timestamp: () -> String
    private let recorder: (any DiagnosticRecording)?
    public init(context: SemanticContext, resourceFactory: @escaping (String, String, String?) throws -> any NativeResourceIO,
                policyFactory: @escaping (String?, JSONSnapshot, JSONSnapshot) throws -> NativePolicyContext,
                recorder: (any DiagnosticRecording)? = nil, timestampProvider: @escaping () -> String = { ISO8601DateFormatter().string(from: Date()) }) {
        self.context = context; self.resourceFactory = resourceFactory; self.policyFactory = policyFactory; self.recorder = recorder; timestamp = timestampProvider
    }
    private func load(config: String, desired: String, audit: String?, supplied: SemanticContext) throws -> (any NativeResourceIO, JSONSnapshot, JSONSnapshot) {
        guard supplied.identity == context.identity else { throw try LifecycleFailure.boundaryFailure(code: .invalidContext, stage: .initialize, scopeIdentity: context.identity) }
        do {
            let io = try resourceFactory(config, desired, audit)
            let observed = try JSONSnapshot(documentID: "observed-" + io.scopeIdentity, sourceReference: "scoped-configuration:" + io.scopeIdentity, data: io.read(.configuration))
            let intent = try JSONSnapshot(documentID: "desired-" + io.scopeIdentity, sourceReference: "scoped-intent:" + io.scopeIdentity, data: io.read(.desired))
            return (io, observed, intent)
        } catch let failure as LifecycleFailure { throw failure }
        catch { throw try LifecycleFailure.boundaryFailure(code: error is CanonicalJSONError ? .malformedContract : .missingEvidence, stage: .observe, scopeIdentity: context.identity) }
    }
    private func planned(_ result: AeostaraContract.DryRunResult, observed: JSONSnapshot) throws -> JSONSnapshot {
        var value = observed.value
        for operation in result.recoveryPlan.recoverySteps.flatMap(\.jsonMutationOperations) {
            guard operation.preconditionHash == (try value.canonicalHash()) else { throw NativeResourceError.staleSnapshot }
            value = try value.applying(.init(op: operation.op, pointer: operation.path.pointer, value: operation.value))
        }
        return try .init(documentID: "legacy-planned", sourceReference: "native-legacy-plan", data: value.canonicalData())
    }
    private func drift(_ engine: NativeHealingEngine) throws -> [DriftEvent] {
        try engine.observedState().surfaceDifferences.map { difference in
            let old = try engine.observed.value.resolve(pointer: difference.path.pointer)
            let desired = try engine.desired.value.resolve(pointer: difference.path.pointer)
            let type: DriftType = old == nil ? .keyAdded : desired == nil ? .keyRemoved : .valueChanged
            return try .init(keyPath: difference.path.pointer, type: type,
                observedValue: old.map { AnyCodable(try $0.canonicalText()) }, desiredValue: desired.map { AnyCodable(try $0.canonicalText()) },
                description: "Informational JSON Pointer surface difference")
        }
    }
    private func plan(_ native: AeostaraContract.RecoveryPlan) -> RepairPlan? {
        guard native.planDisposition == .mutationRequired else { return nil }
        let actions = native.recoverySteps.flatMap(\.jsonMutationOperations).map { mutation in
            RepairAction(keyPath: mutation.path.pointer, actionType: mutation.op == .remove ? .remove : mutation.op == .add ? .add : .set,
                fromValue: nil, toValue: mutation.value.flatMap { try? AnyCodable($0.canonicalText()) }, rationale: "Native semantic recovery; canonical plan retained")
        }
        return .init(planID: native.recoveryPlanID, actions: actions, timestamp: native.createdAt, requiresBackup: native.requiresBackup)
    }
    public func validate(configPath: String, desiredPath: String, invariantsPath: String?, semanticContext: SemanticContext) throws -> ValidationResult {
        do {
            let (_, observed, desired) = try load(config: configPath, desired: desiredPath, audit: nil, supplied: semanticContext)
            let policy = try policyFactory(invariantsPath, observed, desired)
            let engine = NativeHealingEngine(context: context, observed: observed, desired: desired, recorder: recorder)
            let result = try engine.dryRun(policyBundle: policy.bundle)
            let permitted = try policy.permits(result.recoveryPlan, observed: observed, planned: planned(result, observed: observed))
            return try .init(valid: result.recoveryPlan.stateClass == .stable && permitted, errors: [], drifts: drift(engine),
                violations: permitted ? [] : ["Provided policy rejected observed state"], nativeResult: result)
        } catch let failure as LifecycleFailure {
            return .init(valid: false, errors: [failure.code.rawValue], drifts: [], violations: [], nativeFailure: failure)
        } catch {
            let failure = try LifecycleFailure.boundaryFailure(code: .invalidContext, stage: .policy, scopeIdentity: context.identity)
            return .init(valid: false, errors: [failure.code.rawValue], drifts: [], violations: [], nativeFailure: failure)
        }
    }
    public func diff(configPath: String, desiredPath: String, invariantsPath: String?, semanticContext: SemanticContext) throws -> DiffResult {
        let (_, observed, desired) = try load(config: configPath, desired: desiredPath, audit: nil, supplied: semanticContext)
        let policy = try policyFactory(invariantsPath, observed, desired)
        let engine = NativeHealingEngine(context: context, observed: observed, desired: desired, recorder: recorder)
        let result = try engine.dryRun(policyBundle: policy.bundle)
        let permitted = try policy.permits(result.recoveryPlan, observed: observed, planned: planned(result, observed: observed))
        return try .init(drifts: drift(engine), proposedPlan: plan(result.recoveryPlan), nativeResult: result, violations: permitted ? [] : ["Provided policy rejected observed state"])
    }
    public func heal(configPath: String, desiredPath: String, invariantsPath: String?, auditPath: String, semanticContext: SemanticContext) throws -> HealResult {
        do {
            let (io, observed, desired) = try load(config: configPath, desired: desiredPath, audit: auditPath, supplied: semanticContext)
            let policy = try policyFactory(invariantsPath, observed, desired)
            let service = try NativeHealingService(context: context, io: io, policy: policy,
                containmentPolicy: .init(sourceReference: "explicit-legacy-observation-only-boundary", allowedOperations: ["observe", "inspectDiagnostics", "exportDiagnostics"]),
                recorder: recorder, timestampProvider: timestamp)
            let native = try service.heal()
            let receipt = service.lastReceipt
            let policyBlocked = native.diagnosticChain.diagnostics.contains { $0.evidence.member("failureCode") == .string("policyBlocked") }
            let restored = receipt?.rollback?.status == .succeeded
            let message = native.status == .noAction ? "No drift requiring semantic recovery" : native.status == .healed ? "Heal successful" : policyBlocked ? "Policy blocked" : restored ? "Recovery failed, rolled back to verified backup" : "Recovery failed; containment or safe halt required"
            let verification = receipt?.verification.map { VerificationResult(success: $0.status == .passed, failedChecks: $0.status == .passed ? [] : ["Native semantic/resource verification failed"], verifiedAt: timestamp()) }
            let rollback = restored ? RollbackPlan(planID: native.recoveryPlan.recoveryPlanID, backupFilePath: "native-scoped-backup", originalFilePath: configPath) : nil
            let auditEvents = native.auditChain.events.map { event -> AuditEvent in
                let type: AuditEventType
                switch event.eventType {
                case .observe, .normalize, .project, .diagnose, .classify: type = .validationPerformed
                case .plan: type = .healStarted
                case .policyGate: type = event.details.member("permitted") == .bool(false) ? .policyBlocked : .validationPerformed
                case .backup: type = .backupCreated
                case .execute: type = .repairApplied
                case .verify: type = event.details.member("passed") == .bool(true) ? .verificationSucceeded : .verificationFailed
                case .rollback: type = .rollbackExecuted
                case .result: type = native.status == .noAction ? .noDrift : .validationPerformed
                case .fallback, .containment, .safeHalt: type = .validationPerformed
                }
                return .init(eventID: event.auditEventID, type: type, timestamp: event.occurredAt, configFile: configPath,
                    details: ["nativeEventType": AnyCodable(event.eventType.rawValue), "nativeSequence": AnyCodable(event.eventSequence.description)])
            }
            return .init(success: native.status == .healed || native.status == .noAction, executedPlan: plan(native.recoveryPlan), verification: verification,
                rollback: rollback, auditEvents: auditEvents, message: message, nativeResult: native,
                nativeReceipt: .init(backup: receipt?.backup, verification: receipt?.verification, rollback: receipt?.rollback))
        } catch let failure as LifecycleFailure {
            return .init(success: false, message: failure.failedStage == .observe ? "Cannot load config or desired evidence" : "Native lifecycle failed: " + failure.code.rawValue, nativeFailure: failure)
        } catch { throw try LifecycleFailure.boundaryFailure(code: .invalidContext, stage: .policy, scopeIdentity: context.identity) }
    }
}
