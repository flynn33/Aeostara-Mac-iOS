import Foundation
import AeostaraMacDomain

public struct NativeContainmentPolicy {
    public let sourceReference: String
    public let allowedOperations: [String]
    public init(sourceReference: String, allowedOperations: [String]) throws {
        guard !sourceReference.isEmpty, !allowedOperations.isEmpty,
              allowedOperations.allSatisfy({ ["observe", "inspectDiagnostics", "exportDiagnostics"].contains($0) }),
              Set(allowedOperations).count == allowedOperations.count else { throw ProjectionProblem.invalidContext }
        self.sourceReference = sourceReference; self.allowedOperations = allowedOperations
    }
}
public enum NativeLifecycleState: String { case active, contained, safeHalt }
public struct NativeExecutionReceipt {
    public let backup: AeostaraContract.BackupResult?
    public let verification: AeostaraContract.VerificationResult?
    public let rollback: AeostaraContract.RollbackResult?
    public let fallback: AeostaraContract.FallbackDecision?
    public let containment: AeostaraContract.ContainmentDecision?
    public let safeHalt: AeostaraContract.SafeHaltDecision?
    public let diagnosticChain: AeostaraContract.DiagnosticChain
    public let auditChain: AeostaraContract.AuditChain?
}
private struct TransactionEvidence {
    var diagnostics: [AeostaraContract.DiagnosticEnvelope]
    let root: String
    let chainID: String
    var events: [AeostaraContract.AuditEvent] = []
    init(chain: AeostaraContract.DiagnosticChain) { diagnostics = chain.diagnostics; root = chain.rootDiagnosticID; chainID = chain.chainID }
    init(identity: String) { diagnostics = []; root = "diagnostic-" + identity; chainID = "chain-" + root }
    mutating func append(kind: AeostaraContract.DiagnosticEnvelope.DiagnosticKind = .recovery, rule: String = "ASH-RECOVERY-ACTION-001",
                         message: String, details: JSONValue = .object([]), error: Bool = false) throws -> AeostaraContract.DiagnosticReference {
        let source = NativeAshBindingProvider.sourceReference
        let reference = try AeostaraContract.RuleReference(ruleID: rule, sourceReference: source, ruleFamily: rule.split(separator: "-").dropFirst().first.map(String.init) ?? "RECOVERY")
        let id = diagnostics.isEmpty ? root : root + "-" + String(diagnostics.count + 1)
        diagnostics.append(try .init(diagnosticID: id, chainRootReference: root, parentDiagnosticID: diagnostics.last?.diagnosticID,
            diagnosticKind: kind, severity: error ? .error : .info, message: message, ruleReferences: [reference], sourceReferences: [source], evidence: details))
        return try .init(diagnosticID: id, chainRootReference: root, diagnosticKind: .init(rawValue: kind.rawValue)!, ruleReferences: [reference])
    }
    func diagnosticChain() throws -> AeostaraContract.DiagnosticChain { try .init(chainID: chainID, rootDiagnosticID: root, diagnostics: diagnostics) }
    func auditChain() throws -> AeostaraContract.AuditChain? {
        events.isEmpty ? nil : try .init(auditChainID: "audit-" + root, diagnosticChainReference: chainID, events: events)
    }
    mutating func audit(_ type: AeostaraContract.AuditEvent.EventType, reference: AeostaraContract.DiagnosticReference,
                        details: JSONValue, time: String, io: any NativeResourceIO, lease: any NativeResourceLease) throws {
        let event = try AeostaraContract.AuditEvent(auditEventID: root + "-audit-" + String(events.count + 1),
            eventSequence: events.count + 1, eventType: type, diagnosticReference: reference, occurredAt: time, details: details)
        try io.persistAudit(event, lease: lease)
        events.append(event)
    }
}
private final class PreparedExecution: NativePreparedExecution {
    let contextIdentity: String
    let observedCanonicalHash: String
    let desiredCanonicalHash: String
    let policyBundle: AeostaraContract.PolicyBundle
    let preparedPlan: AeostaraContract.DryRunResult
    let executionContext: AeostaraContract.ExecutionContext
    private let lock = NSLock()
    private var consumed = false
    private let body: () throws -> AeostaraContract.HealResult
    init(context: SemanticContext, observed: JSONSnapshot, desired: JSONSnapshot, policy: AeostaraContract.PolicyBundle,
         plan: AeostaraContract.DryRunResult, execution: AeostaraContract.ExecutionContext, body: @escaping () throws -> AeostaraContract.HealResult) {
        contextIdentity = context.identity; observedCanonicalHash = observed.canonicalHash; desiredCanonicalHash = desired.canonicalHash
        policyBundle = policy; preparedPlan = plan; executionContext = execution; self.body = body
    }
    func execute() throws -> AeostaraContract.HealResult {
        guard lock.try() else { throw NativeResourceError.resourceBusy }
        defer { lock.unlock() }
        guard !consumed else { throw NativeResourceError.leaseInvalid }
        consumed = true; return try body()
    }
}

/// Complete scoped native execution. Configuration writes occur only under a policy-bound, backed-up lease.
public final class NativeHealingService {
    public let context: SemanticContext
    public let io: any NativeResourceIO
    public let policy: NativePolicyContext
    private let recorder: (any DiagnosticRecording)?
    private let timestamp: () -> String
    private let operation = NSLock()
    private let stateLock = NSLock()
    private var currentState: NativeLifecycleState = .active
    private var receipt: NativeExecutionReceipt?
    private var diagnosticLink: (session: UUID, operation: UUID, incident: UUID, event: UUID)?
    private let containmentPolicy: NativeContainmentPolicy?
    public var lifecycleState: NativeLifecycleState { stateLock.lock(); defer { stateLock.unlock() }; return currentState }
    public var lastReceipt: NativeExecutionReceipt? { stateLock.lock(); defer { stateLock.unlock() }; return receipt }
    public init(context: SemanticContext, io: any NativeResourceIO, policy: NativePolicyContext,
                containmentPolicy: NativeContainmentPolicy? = nil, recorder: (any DiagnosticRecording)? = nil,
                timestampProvider: @escaping () -> String = { ISO8601DateFormatter().string(from: Date()) }) {
        self.context = context; self.io = io; self.policy = policy; self.containmentPolicy = containmentPolicy
        self.recorder = recorder; timestamp = timestampProvider
    }
    private func set(_ state: NativeLifecycleState, receipt: NativeExecutionReceipt? = nil) {
        stateLock.lock(); defer { stateLock.unlock() }
        if currentState != .safeHalt { currentState = state }
        if let receipt { self.receipt = receipt }
    }
    private func failure(_ code: LifecycleFailure.Code, stage: DiagnosticStage, evidence: inout TransactionEvidence) throws -> LifecycleFailure {
        _ = try evidence.append(message: "Native lifecycle failed closed", details: .object([JSONMember("failureCode", .string(code.rawValue)), JSONMember("status", .string("FAILED"))]), error: true)
        return try .init(code: code, failedStage: stage, diagnosticEnvelope: evidence.diagnostics.last!, diagnosticChain: evidence.diagnosticChain(), auditChain: evidence.auditChain())
    }
    private func begin() throws {
        guard operation.try() else {
            var evidence = TransactionEvidence(identity: io.scopeIdentity)
            throw try failure(.resourceBusy, stage: .initialize, evidence: &evidence)
        }
        if lifecycleState != .active {
            defer { operation.unlock() }
            if lifecycleState == .contained { throw try breachLocked() }
            guard let receipt = lastReceipt, let terminal = receipt.diagnosticChain.diagnostics.last else { throw try LifecycleFailure.missingContext() }
            throw LifecycleFailure(code: .terminalHalt, failedStage: .safeHalt, diagnosticEnvelope: terminal, diagnosticChain: receipt.diagnosticChain, auditChain: receipt.auditChain)
        }
    }
    private func breachLocked() throws -> LifecycleFailure {
        guard let preserved = lastReceipt else { throw try LifecycleFailure.missingContext() }
        var evidence = TransactionEvidence(chain: preserved.diagnosticChain)
        evidence.events = preserved.auditChain?.events ?? []
        let reference = try evidence.append(kind: .safeHalt, rule: "ASH-HALT-TRIGGER-001", message: "A request breached the explicit containment operation boundary",
            details: .object([JSONMember("trigger", .string("CONTAINMENT_BREACH"))]), error: true)
        let halt = try AeostaraContract.SafeHaltDecision(safeHaltDecisionID: "halt-" + evidence.root, terminal: true,
            blockedTransitions: ["mutation", "transition", "recovery"], diagnosticReference: reference)
        set(.safeHalt)
        let previous = diagnosticLink
        let session = previous?.session ?? UUID(), operationID = UUID(), incident = previous?.incident ?? UUID()
        var cause = previous?.event
        func capture(_ stage: DiagnosticStage, _ fault: DiagnosticFaultCode) {
            if let accepted = recorder?.record(.init(sessionID: session, operationID: operationID, incidentID: incident,
                parentOperationID: previous?.operation, stage: stage, outcome: stage == .safeHalt ? .halted : .failed,
                fault: .init(code: fault), causeEventIDs: cause.map { [$0] } ?? []), developmentDetails: nil) {
                cause = accepted
                diagnosticLink = (session, operationID, incident, accepted)
            }
        }
        capture(.safeHalt, .scopeViolation)
        var auditFailed = false
        do {
            let lease = try io.acquireExclusiveLease(); defer { lease.release() }
            try evidence.audit(.safeHalt, reference: reference, details: .object([JSONMember("trigger", .string("CONTAINMENT_BREACH"))]), time: timestamp(), io: io, lease: lease)
        } catch {
            auditFailed = true
            capture(.audit, .audit)
            _ = try evidence.append(message: "Mandatory terminal audit persistence unavailable", details: .object([JSONMember("failureCode", .string("auditFailed"))]), error: true)
        }
        let receipt = try NativeExecutionReceipt(backup: preserved.backup, verification: preserved.verification, rollback: preserved.rollback,
            fallback: preserved.fallback, containment: preserved.containment, safeHalt: halt, diagnosticChain: evidence.diagnosticChain(), auditChain: evidence.auditChain())
        set(.safeHalt, receipt: receipt)
        return .init(code: auditFailed ? .auditFailed : .containmentBreach, failedStage: .safeHalt,
            diagnosticEnvelope: evidence.diagnostics.last!, diagnosticChain: receipt.diagnosticChain, auditChain: receipt.auditChain)
    }
    public func authorizeRestrictedOperation(_ name: String) throws {
        guard operation.try() else {
            var evidence = TransactionEvidence(identity: io.scopeIdentity)
            throw try failure(.resourceBusy, stage: .initialize, evidence: &evidence)
        }
        defer { operation.unlock() }
        if lifecycleState == .contained {
            guard containmentPolicy?.allowedOperations.contains(name) == true else { throw try breachLocked() }
            return
        }
        if lifecycleState == .safeHalt {
            guard let preserved = lastReceipt, let terminal = preserved.diagnosticChain.diagnostics.last else { throw try LifecycleFailure.missingContext() }
            throw LifecycleFailure(code: .terminalHalt, failedStage: .safeHalt, diagnosticEnvelope: terminal, diagnosticChain: preserved.diagnosticChain, auditChain: preserved.auditChain)
        }
        guard ["observe", "inspectDiagnostics", "exportDiagnostics", "recovery"].contains(name) else { throw NativeResourceError.scopeViolation }
    }
    private func snapshots() throws -> (NativeStorageSnapshot, JSONSnapshot) {
        let observed = try NativeStorageSnapshot(bytes: io.read(.configuration), documentID: "observed-" + io.scopeIdentity, sourceReference: "scoped-configuration:" + io.scopeIdentity)
        let desired = try JSONSnapshot(documentID: "desired-" + io.scopeIdentity, sourceReference: "scoped-intent:" + io.scopeIdentity, data: io.read(.desired))
        return (observed, desired)
    }
    public func dryRun(partialIntent: Bool = false) throws -> AeostaraContract.DryRunResult {
        try begin(); defer { operation.unlock() }
        do {
            let (observed, desired) = try snapshots()
            return try NativeHealingEngine(context: context, observed: observed.document, desired: desired, recorder: recorder).dryRun(policyBundle: policy.bundle, partialIntent: partialIntent)
        } catch let error as LifecycleFailure { throw error }
        catch {
            var evidence = TransactionEvidence(identity: io.scopeIdentity)
            throw try failure(error is NativeResourceError ? .scopeViolation : .malformedContract, stage: .observe, evidence: &evidence)
        }
    }
    private func plannedSnapshot(_ plan: AeostaraContract.DryRunResult, observed: JSONSnapshot) throws -> JSONSnapshot {
        var value = observed.value
        for mutation in plan.recoveryPlan.recoverySteps.flatMap(\.jsonMutationOperations) {
            guard mutation.preconditionHash == (try value.canonicalHash()),
                  context.projectionSpec.dimensions.flatMap(\.sourcePointers).contains(where: { $0.pointer.utf8.elementsEqual(mutation.path.pointer.utf8) }) else { throw NativeResourceError.staleSnapshot }
            value = try value.applying(.init(op: mutation.op, pointer: mutation.path.pointer, value: mutation.value))
        }
        return try .init(documentID: "planned-" + plan.recoveryPlan.planHash, sourceReference: "native-prepared-plan", data: value.canonicalData())
    }
    private func fallbackPlan(_ candidate: NativeFallbackPolicy, observed: JSONSnapshot, desired: JSONSnapshot,
                              reference: AeostaraContract.DiagnosticReference) throws -> (AeostaraContract.RecoveryPlan, JSONSnapshot) {
        let coordinates = try NativeSemanticProjector(context: context).projectReobservedCoordinates(observed: observed, desired: desired)
        var value = observed.value
        var operations: [AeostaraContract.JsonMutationOperation] = []
        for binding in context.projectionSpec.dimensions.sorted(by: { $0.dimensionID.rawValue < $1.dimensionID.rawValue }) {
            let index = Int(binding.dimensionID.rawValue.dropFirst())!
            guard coordinates[index] != candidate.candidate[index] else { continue }
            guard let rule = context.mappingRules.first(where: { $0.identifier.utf8.elementsEqual(binding.mappingRule.utf8) }) else { throw ProjectionProblem.unknownMappingRule }
            let drafts = try rule.materialize(binding: binding, targetBit: candidate.candidate[index], observed: observed, desired: desired)
            guard !drafts.isEmpty else { throw ProjectionProblem.missingMaterialization }
            for draft in drafts {
                guard binding.sourcePointers.contains(where: { $0.pointer.utf8.elementsEqual(draft.pointer.utf8) }) else { throw ProjectionProblem.invalidContext }
                let old = try value.resolve(pointer: draft.pointer)
                operations.append(try .init(operationID: "fallback-operation-" + String(operations.count + 1), op: draft.op,
                    path: .init(pointer: draft.pointer, tokens: JSONValue.pointerTokens(draft.pointer), pointsToMissing: old == nil, pointsToNull: old == .null),
                    value: draft.value, preconditionHash: value.canonicalHash(), diagnosticReference: reference))
                value = try value.applying(draft)
            }
        }
        let planned = try JSONSnapshot(documentID: "fallback-planned", sourceReference: "canonical-fallback-registry:" + candidate.policyID, data: value.canonicalData())
        let actual = try NativeSemanticProjector(context: context).projectReobservedCoordinates(observed: planned, desired: desired)
        guard actual == candidate.candidate, context.knownValidStates.states.contains(actual),
              try NativeAshBindingProvider().intentMatches(actual, context: context, desired: desired) else { throw ProjectionProblem.missingMaterialization }
        let steps = [try AeostaraContract.RecoveryStep(stepID: "fallback-step", stepType: .selectFallback,
            description: "Registry-authorized restoration after recorded recovery failure", jsonMutationOperations: operations, diagnosticReference: reference)]
        let hash = try JSONValue.object([JSONMember("context", .string(context.identity)), JSONMember("policy", .string(candidate.policyID)),
            JSONMember("observed", .string(observed.canonicalHash)), JSONMember("desired", .string(desired.canonicalHash)), JSONMember("steps", .array(steps.map(\.contractJSON)))]).canonicalHash()
        let plan = try AeostaraContract.RecoveryPlan(recoveryPlanID: "fallback-plan-" + hash, planDisposition: .mutationRequired,
            diagnosticReference: reference, stateClass: .degraded, recoveryCategory: .fallbackRequired, requiresPolicyGate: true, requiresBackup: true,
            recoverySteps: steps, planHash: hash, createdAt: timestamp())
        return (plan, planned)
    }
    public func heal(partialIntent: Bool = false) throws -> AeostaraContract.HealResult {
        try begin(); defer { operation.unlock() }
        let session = UUID(), operationID = UUID()
        var incident = UUID(), parentOperation: UUID?
        var cause: UUID?
        var linkedPlanning = false
        func capture(_ stage: DiagnosticStage, _ outcome: DiagnosticOutcome, _ fault: DiagnosticFaultCode? = nil) {
            if !linkedPlanning {
                linkedPlanning = true
                if let previous = recorder?.snapshot().records.last(where: { $0.event.sessionID == session && $0.event.operationID != operationID }),
                   let actualIncident = previous.event.incidentID {
                    incident = actualIncident; parentOperation = previous.event.operationID; cause = previous.event.eventID
                }
            }
            cause = recorder?.record(.init(sessionID: session, operationID: operationID, incidentID: incident, parentOperationID: parentOperation, stage: stage, outcome: outcome,
                fault: fault.map { .init(code: $0) }, causeEventIDs: cause.map { [$0] } ?? []), developmentDetails: nil)
            if let cause { diagnosticLink = (session, operationID, incident, cause) }
        }
        var evidence = TransactionEvidence(identity: io.scopeIdentity)
        var stage: DiagnosticStage = .observe
        var backup: AeostaraContract.BackupResult?
        var verification: AeostaraContract.VerificationResult?
        var rollback: AeostaraContract.RollbackResult?
        var fallback: AeostaraContract.FallbackDecision?
        var containment: AeostaraContract.ContainmentDecision?
        var halt: AeostaraContract.SafeHaltDecision?
        var acquired: (any NativeResourceLease)?
        var mutated = false
        var auditHealthy = true
        var plan: AeostaraContract.DryRunResult?
        var original: NativeStorageSnapshot?
        var desiredSnapshot: JSONSnapshot?
        func save() throws {
            set(lifecycleState, receipt: try .init(backup: backup, verification: verification, rollback: rollback, fallback: fallback,
                containment: containment, safeHalt: halt, diagnosticChain: evidence.diagnosticChain(), auditChain: evidence.auditChain()))
        }
        func audit(_ type: AeostaraContract.AuditEvent.EventType, _ reference: AeostaraContract.DiagnosticReference, _ details: JSONValue = .object([])) throws {
            guard let lease = acquired else { throw NativeResourceError.leaseInvalid }
            do { try evidence.audit(type, reference: reference, details: details, time: timestamp(), io: io, lease: lease) }
            catch { auditHealthy = false; stage = .audit; capture(.audit, .failed, .audit); throw try failure(.auditFailed, stage: .audit, evidence: &evidence) }
        }
        defer { acquired?.release() }
        do {
            let (observed, desired) = try snapshots(); original = observed; desiredSnapshot = desired
            let pure = NativeHealingEngine(context: context, observed: observed.document, desired: desired, recorder: recorder, sessionID: session)
            let prepared = try pure.dryRun(policyBundle: policy.bundle, partialIntent: partialIntent); plan = prepared
            evidence = TransactionEvidence(chain: prepared.diagnosticChain)
            let planned = try plannedSnapshot(prepared, observed: observed.document)
            if prepared.recoveryPlan.recoveryCategory == .fallbackRequired {
                let bits = try NativeSemanticProjector(context: context).projectCoordinates(observed: observed.document, desired: desired)
                guard let selected = try NativeAshBindingProvider().eligibleFallback(state: bits, context: context, observed: observed.document, desired: desired) else { throw ProjectionProblem.missingMaterialization }
                fallback = try .init(fallbackDecisionID: "fallback-" + selected.policyID, registryReference: context.identity, selectedCandidateID: selected.policyID,
                    status: .selected, diagnosticReference: prepared.recoveryPlan.diagnosticReference)
            }
            stage = .policy
            let permitted = try policy.permits(prepared.recoveryPlan, observed: observed.document, planned: planned)
            let policyRef = try evidence.append(message: "Completed plan evaluated under explicit policy", details: .object([JSONMember("permitted", .bool(permitted)), JSONMember("policyHash", .string(policy.bundle.bundleHash))]))
            capture(.policy, permitted ? .succeeded : .blocked, permitted ? nil : .policy)
            stage = .initialize; acquired = try io.acquireExclusiveLease()
            guard NativeStorageIdentity.hash(try io.read(.configuration)) == observed.storageHash,
                  try JSONSnapshot(documentID: desired.documentID, sourceReference: desired.sourceReference, data: io.read(.desired)).canonicalHash == desired.canonicalHash else { throw NativeResourceError.staleSnapshot }
            let phaseKinds: [AeostaraContract.AuditEvent.EventType] = [.observe, .normalize, .project, .diagnose, .classify, .plan]
            for (index, type) in phaseKinds.enumerated() {
                let envelope = prepared.diagnosticChain.diagnostics[min(index, prepared.diagnosticChain.diagnostics.count - 1)]
                let ref = try AeostaraContract.DiagnosticReference(diagnosticID: envelope.diagnosticID, chainRootReference: envelope.chainRootReference,
                    diagnosticKind: .init(rawValue: envelope.diagnosticKind.rawValue)!, ruleReferences: envelope.ruleReferences)
                try audit(type, ref, .object([JSONMember("planHash", .string(prepared.recoveryPlan.planHash))]))
            }
            if prepared.recoveryPlan.planDisposition != .noAction || !permitted { try audit(.policyGate, policyRef, .object([JSONMember("permitted", .bool(permitted))])) }
            guard permitted else { throw try failure(.policyBlocked, stage: .policy, evidence: &evidence) }
            guard prepared.recoveryPlan.planDisposition != .escalationRequired else { throw try failure(.executionFailed, stage: .plan, evidence: &evidence) }
            if prepared.recoveryPlan.planDisposition == .noAction {
                let resultRef = try evidence.append(message: "Recognized stable state requires no action")
                try audit(.result, resultRef, .object([JSONMember("status", .string("NO_ACTION"))]))
                try save()
                return try .init(healResultID: "heal-" + prepared.recoveryPlan.planHash, status: .noAction, recoveryPlan: prepared.recoveryPlan,
                    auditChain: evidence.auditChain()!, diagnosticChain: evidence.diagnosticChain())
            }
            stage = .backup; capture(stage, .started)
            try io.createBackup(bytes: observed.bytes, lease: acquired!)
            guard try io.read(.backup) == observed.bytes else { throw NativeResourceError.staleSnapshot }
            let backupRef = try evidence.append(message: "Exclusive exact-byte backup verified", details: .object([JSONMember("storageHash", .string(observed.storageHash))]))
            let backupRecord = try AeostaraContract.BackupRecord(backupRecordID: "backup-" + prepared.recoveryPlan.planHash,
                sourceDocument: observed.document.reference(role: .observed), sourceHash: observed.document.canonicalHash,
                storageReference: "scoped-backup:" + io.scopeIdentity, diagnosticReference: backupRef)
            backup = try .init(backupResultID: "backup-result-" + prepared.recoveryPlan.planHash, status: .succeeded, backupRecord: backupRecord, diagnosticReference: backupRef)
            try audit(.backup, backupRef); capture(stage, .succeeded)
            let policyDecision = try AeostaraContract.PolicyDecision(policyDecisionID: "policy-" + prepared.recoveryPlan.planHash,
                decision: .allow, policyBundleID: policy.bundle.policyBundleID, reasons: ["All explicitly registered policy rules passed"], diagnosticReference: policyRef)
            let execution = try AeostaraContract.ExecutionContext(executionContextID: "execution-" + prepared.recoveryPlan.planHash,
                recoveryPlanID: prepared.recoveryPlan.recoveryPlanID, policyDecision: policyDecision, backupResult: backup!, verificationPlan: prepared.verificationPlan, diagnosticReference: backupRef)
            let capability = PreparedExecution(context: context, observed: observed.document, desired: desired, policy: policy.bundle,
                plan: prepared, execution: execution) {
                stage = .mutate; capture(stage, .started)
                mutated = true // A delegate may write partially and then throw; rollback must remain eligible.
                do { try self.io.replaceConfiguration(bytes: planned.value.canonicalData(), expectedStorageHash: observed.storageHash, lease: acquired!) }
                catch NativeResourceError.staleSnapshot { mutated = false; throw NativeResourceError.staleSnapshot }
                let executeRef = try evidence.append(message: "Approved atomic configuration replacement completed")
                try audit(.execute, executeRef); capture(stage, .succeeded)
                stage = .verify; capture(stage, .started)
                let actualBytes = try self.io.read(.configuration)
                let actual = try JSONSnapshot(documentID: "verified-" + self.io.scopeIdentity, sourceReference: "native-reobservation", data: actualBytes)
                let coordinates = try NativeSemanticProjector(context: self.context).projectReobservedCoordinates(observed: actual, desired: desired)
                let ash = NativeAshBindingProvider(), diagnosed = try ash.diagnose(state: coordinates, context: self.context, observed: actual, desired: desired)
                let intentSatisfied = try ash.intentMatches(coordinates, context: self.context, desired: desired)
                let passed = actual.canonicalHash == planned.canonicalHash && coordinates == prepared.verificationPlan.expectedSemanticState.coordinates
                    && diagnosed.stateClass == .stable && intentSatisfied
                let verifyRef = try evidence.append(message: "Actual resource and semantic state reobserved", details: .object([JSONMember("passed", .bool(passed)), JSONMember("actualHash", .string(actual.canonicalHash)), JSONMember("postStateClass", .string(diagnosed.stateClass.rawValue))]), error: !passed)
                let stateHash = try JSONValue.array(coordinates.map { .integer(String($0)) }).canonicalHash()
                let actualState = try AeostaraContract.AshState(stateID: "state-" + stateHash, coordinates: coordinates, sourceReference: NativeAshBindingProvider.sourceReference, canonicalHash: stateHash)
                verification = try .init(verificationResultID: "verify-" + prepared.recoveryPlan.planHash, verificationPlanID: prepared.verificationPlan.verificationPlanID,
                    status: passed ? .passed : .failed, expectedSemanticState: prepared.verificationPlan.expectedSemanticState, actualSemanticState: actualState, diagnosticReference: verifyRef)
                try audit(.verify, verifyRef, .object([JSONMember("passed", .bool(passed))])); capture(stage, passed ? .succeeded : .failed, passed ? nil : .verification)
                guard passed else { throw try self.failure(.verificationFailed, stage: .verify, evidence: &evidence) }
                let resultRef = try evidence.append(message: "Complete native recovery verified stable")
                try audit(.result, resultRef, .object([JSONMember("status", .string("HEALED"))])); try save()
                return try .init(healResultID: "heal-" + prepared.recoveryPlan.planHash, status: .healed, recoveryPlan: prepared.recoveryPlan,
                    auditChain: evidence.auditChain()!, diagnosticChain: evidence.diagnosticChain())
            }
            let executable = NativeHealingEngine(context: context, observed: observed.document, desired: desired, sessionID: session, preparedExecution: capability)
            return try executable.heal(observedState: pure.observedState(), desiredIntent: pure.desiredIntent(partialIntent: partialIntent),
                projectionSpec: context.projectionSpec, policyBundle: policy.bundle, executionContext: execution)
        } catch {
            if plan == nil, let failure = error as? LifecycleFailure { evidence = TransactionEvidence(chain: failure.diagnosticChain) }
            let rootCode: LifecycleFailure.Code
            if let failure = error as? LifecycleFailure { rootCode = failure.code }
            else if error as? NativeResourceError == .resourceBusy { rootCode = .resourceBusy }
            else if error as? NativeResourceError == .staleSnapshot { rootCode = .staleSnapshot }
            else if stage == .backup { rootCode = .backupFailed }
            else if stage == .verify { rootCode = .verificationFailed }
            else if stage == .mutate { rootCode = .executionFailed }
            else { rootCode = .scopeViolation }
            let primaryStage = (error as? LifecycleFailure)?.failedStage ?? stage
            let primary = try failure(rootCode, stage: primaryStage, evidence: &evidence)
            capture(primaryStage, .failed, primaryStage == .backup ? .backup : primaryStage == .verify ? .verification : primaryStage == .audit ? .audit : .execution)
            if mutated, let original, let backup, let lease = acquired {
                do {
                    stage = .rollback; capture(stage, .started)
                    let bytes = try io.read(.backup)
                    guard bytes == original.bytes else { throw NativeResourceError.staleSnapshot }
                    let current = try io.read(.configuration)
                    try io.replaceConfiguration(bytes: bytes, expectedStorageHash: NativeStorageIdentity.hash(current), lease: lease)
                    let restored = try io.read(.configuration)
                    guard restored == original.bytes else { throw NativeResourceError.staleSnapshot }
                    let rollbackRef = try evidence.append(message: "Previously authorized exact-backup rollback verified", details: .object([JSONMember("restoredStorageHash", .string(original.storageHash))]))
                    rollback = try .init(rollbackResultID: "rollback-" + backup.backupRecord.backupRecordID, status: .succeeded,
                        backupRecordID: backup.backupRecord.backupRecordID, restoredHash: original.document.canonicalHash, diagnosticReference: rollbackRef)
                    if auditHealthy { try audit(.rollback, rollbackRef) }
                    capture(stage, .rolledBack)
                } catch {
                    _ = try evidence.append(message: "Authorized rollback failed; restoration is unverified", details: .object([JSONMember("failureCode", .string("rollbackFailed"))]), error: true)
                    capture(.rollback, .failed, .rollback)
                }
            }
            if rootCode == .resourceBusy || rootCode == .staleSnapshot || (!mutated && rootCode == .backupFailed) {
                try save(); throw try .init(code: primary.code, failedStage: primary.failedStage, diagnosticEnvelope: evidence.diagnostics.last!, diagnosticChain: evidence.diagnosticChain(), auditChain: evidence.auditChain()) as LifecycleFailure
            }
            // A failed correction is never retried. Fallback requires an independently applicable registry and policy proof.
            if let original, let desired = desiredSnapshot {
                let bits = try? NativeSemanticProjector(context: context).projectReobservedCoordinates(observed: original.document, desired: desired)
                let candidate = try? bits.flatMap { try NativeAshBindingProvider().eligibleFallback(state: $0, context: context, observed: original.document, desired: desired) }
                let fallbackRef = try evidence.append(message: candidate == nil ? "No applicable canonical fallback candidate" : "Canonical fallback selected by rank and identifier after recorded recovery failure", details: .object([JSONMember("candidateAvailable", .bool(candidate != nil)), JSONMember("auditAvailable", .bool(auditHealthy)), JSONMember("originalFailureCode", .string(rootCode.rawValue)), JSONMember("selectedPolicyID", candidate.map { .string($0.policyID) } ?? .null)]), error: candidate == nil)
                if let candidate {
                    fallback = try .init(fallbackDecisionID: "fallback-" + candidate.policyID, registryReference: context.identity, selectedCandidateID: candidate.policyID, status: .blocked, diagnosticReference: fallbackRef)
                    if auditHealthy, let lease = acquired, backup != nil {
                        do {
                            guard try io.read(.configuration) == original.bytes, try io.read(.backup) == original.bytes else { throw NativeResourceError.staleSnapshot }
                            let (fallbackRecovery, planned) = try fallbackPlan(candidate, observed: original.document, desired: desired, reference: fallbackRef)
                            let expectedHash = try JSONValue.array(candidate.candidate.map { .integer(String($0)) }).canonicalHash()
                            let expectedState = try AeostaraContract.AshState(stateID: "state-" + expectedHash, coordinates: candidate.candidate,
                                sourceReference: NativeAshBindingProvider.sourceReference, canonicalHash: expectedHash)
                            let fallbackVerification = try AeostaraContract.VerificationPlan(verificationPlanID: "fallback-verification-" + fallbackRecovery.planHash,
                                checks: [.object([JSONMember("kind", .string("EXACT_RESOURCE_AND_SEMANTIC_INTENT")), JSONMember("resourceHash", .string(planned.canonicalHash))])],
                                expectedSemanticState: expectedState, generatedBeforeMutation: true, diagnosticReference: fallbackRef)
                            let permitted = try policy.permits(fallbackRecovery, observed: original.document, planned: planned)
                            let policyRef = try evidence.append(message: "Fallback evaluated under its own completed plan and explicit policy", details: .object([JSONMember("permitted", .bool(permitted)), JSONMember("fallbackPlanHash", .string(fallbackRecovery.planHash))]))
                            try audit(.fallback, fallbackRef)
                            try audit(.plan, policyRef, .object([JSONMember("recoveryPlan", fallbackRecovery.contractJSON), JSONMember("verificationPlan", fallbackVerification.contractJSON)]))
                            try audit(.policyGate, policyRef, .object([JSONMember("permitted", .bool(permitted))]))
                            guard permitted else { throw try failure(.policyBlocked, stage: .fallback, evidence: &evidence) }
                            capture(.fallback, .started)
                            try io.replaceConfiguration(bytes: planned.value.canonicalData(), expectedStorageHash: original.storageHash, lease: lease)
                            let executedRef = try evidence.append(message: "Approved fallback resource restoration completed")
                            try audit(.execute, executedRef)
                            let actual = try JSONSnapshot(documentID: "fallback-actual", sourceReference: "native-fallback-reobservation", data: io.read(.configuration))
                            let actualBits = try NativeSemanticProjector(context: context).projectReobservedCoordinates(observed: actual, desired: desired)
                            let diagnosed = try NativeAshBindingProvider().diagnose(state: actualBits, context: context, observed: actual, desired: desired)
                            let intentSatisfied = try NativeAshBindingProvider().intentMatches(actualBits, context: context, desired: desired)
                            let passed = actual.canonicalHash == planned.canonicalHash && actualBits == candidate.candidate && diagnosed.stateClass == .stable && intentSatisfied
                            let verifyRef = try evidence.append(message: "Fallback resource and semantic state re-diagnosed", details: .object([JSONMember("passed", .bool(passed)), JSONMember("postStateClass", .string(diagnosed.stateClass.rawValue))]), error: !passed)
                            let actualHash = try JSONValue.array(actualBits.map { .integer(String($0)) }).canonicalHash()
                            verification = try .init(verificationResultID: "fallback-verify-" + fallbackRecovery.planHash, verificationPlanID: fallbackVerification.verificationPlanID,
                                status: passed ? .passed : .failed, expectedSemanticState: expectedState,
                                actualSemanticState: .init(stateID: "state-" + actualHash, coordinates: actualBits, sourceReference: NativeAshBindingProvider.sourceReference, canonicalHash: actualHash), diagnosticReference: verifyRef)
                            try audit(.verify, verifyRef, .object([JSONMember("passed", .bool(passed))]))
                            guard passed else { throw try failure(.verificationFailed, stage: .fallback, evidence: &evidence) }
                            fallback = try .init(fallbackDecisionID: "fallback-" + candidate.policyID, registryReference: context.identity, selectedCandidateID: candidate.policyID, status: .selected, diagnosticReference: fallbackRef)
                            capture(.fallback, .succeeded)
                            let resultRef = try evidence.append(message: "Verified fallback recovered the resource while preserving the original failure")
                            try audit(.result, resultRef, .object([JSONMember("status", .string("HEALED")), JSONMember("originalFailureCode", .string(rootCode.rawValue))]))
                            try save()
                            return try .init(healResultID: "heal-fallback-" + fallbackRecovery.planHash, status: .healed, recoveryPlan: fallbackRecovery,
                                auditChain: evidence.auditChain()!, diagnosticChain: evidence.diagnosticChain())
                        } catch {
                            _ = try evidence.append(message: "Fallback failed or lacked fresh backup and policy evidence", details: .object([JSONMember("originalFailureCode", .string(rootCode.rawValue))]), error: true)
                            capture(.fallback, .failed, .verification)
                        }
                    }
                }
                if auditHealthy, acquired != nil { try? audit(.fallback, fallbackRef) }
            }
            let containmentRef = try evidence.append(kind: .containment, rule: "ASH-CONTAINMENT-TRIGGER-001", message: "Recovery failure restricted to explicit containment boundary",
                details: .object([JSONMember("trigger", .string("RECOVERY_VALIDATION_FAILURE")), JSONMember("originalFailureCode", .string(rootCode.rawValue))]), error: true)
            if let policy = containmentPolicy {
                containment = try .init(containmentDecisionID: "containment-" + evidence.root, boundary: .object([JSONMember("scope", .string(io.scopeIdentity)), JSONMember("sourceReference", .string(policy.sourceReference))]),
                    allowedOperations: policy.allowedOperations, restrictedOperations: ["mutation", "transition", "recovery"], diagnosticReference: containmentRef)
                set(.contained); capture(.containment, .contained)
                if auditHealthy, acquired != nil { try? audit(.containment, containmentRef) }
            } else {
                if auditHealthy, acquired != nil { try? audit(.containment, containmentRef) }
                let haltRef = try evidence.append(kind: .safeHalt, rule: "ASH-HALT-TRIGGER-001", message: "No containment authority permits further recovery; terminal safe halt", details: .object([JSONMember("trigger", .string("UNRESOLVABLE_BLOCKED_RECOVERY"))]), error: true)
                halt = try .init(safeHaltDecisionID: "halt-" + evidence.root, terminal: true, blockedTransitions: ["mutation", "transition", "recovery"], diagnosticReference: haltRef)
                set(.safeHalt); capture(.safeHalt, .halted)
                if auditHealthy, acquired != nil { try? audit(.safeHalt, haltRef) }
            }
            if auditHealthy, acquired != nil {
                let resultRef = try evidence.append(message: "Recovery ended in restricted or terminal state", details: .object([JSONMember("state", .string(lifecycleState.rawValue))]))
                try? audit(.result, resultRef)
            }
            try save()
            guard auditHealthy, let plan, let auditChain = try evidence.auditChain() else {
                throw try .init(code: primary.code, failedStage: primary.failedStage, diagnosticEnvelope: evidence.diagnostics.last!, diagnosticChain: evidence.diagnosticChain(), auditChain: evidence.auditChain()) as LifecycleFailure
            }
            return try .init(healResultID: "heal-" + plan.recoveryPlan.planHash, status: lifecycleState == .safeHalt ? .safeHalt : .escalated,
                recoveryPlan: plan.recoveryPlan, auditChain: auditChain, diagnosticChain: evidence.diagnosticChain())
        }
    }
}
