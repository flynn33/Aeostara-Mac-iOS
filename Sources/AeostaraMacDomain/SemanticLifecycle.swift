import Foundation

public struct LifecycleFailure: Error, Equatable {
    public enum Code: String { case missingSemanticContext, missingEvidence, unknownMappingRule, ambiguousMapping, malformedContract, unsupportedCanonicalNumber, invalidContext, intentIncompatible, missingMaterialization, resourceBusy, staleSnapshot, scopeViolation, policyBlocked, backupFailed, auditFailed, executionFailed, verificationFailed, rollbackFailed, containmentBreach, terminalHalt }
    public let code: Code
    public let failedStage: DiagnosticStage
    public let diagnosticEnvelope: AeostaraContract.DiagnosticEnvelope
    public let diagnosticChain: AeostaraContract.DiagnosticChain
    public let auditChain: AeostaraContract.AuditChain?
    public init(code: Code, failedStage: DiagnosticStage, diagnosticEnvelope: AeostaraContract.DiagnosticEnvelope,
                diagnosticChain: AeostaraContract.DiagnosticChain, auditChain: AeostaraContract.AuditChain? = nil) {
        self.code = code; self.failedStage = failedStage; self.diagnosticEnvelope = diagnosticEnvelope
        self.diagnosticChain = diagnosticChain; self.auditChain = auditChain
    }
    public static func missingContext() throws -> LifecycleFailure {
        var trace = SemanticTrace(identity: try JSONValue.string("missing-explicit-semantic-context").canonicalHash())
        _ = try trace.append(kind: .mapping, ruleID: "ASH-STATE-STRUCTURE-001", message: "Explicit native application semantics and lifecycle are required",
            evidence: .object([JSONMember("status", .string("BLOCKED")), JSONMember("failureCode", .string(Code.missingSemanticContext.rawValue))]), severity: .error)
        return try .init(code: .missingSemanticContext, failedStage: .initialize, diagnosticEnvelope: trace.envelopes.last!, diagnosticChain: trace.chain())
    }
    public static func boundaryFailure(code: Code, stage: DiagnosticStage, scopeIdentity: String) throws -> LifecycleFailure {
        var trace = SemanticTrace(identity: try JSONValue.array([.string(scopeIdentity), .string(code.rawValue), .string(stage.rawValue)]).canonicalHash())
        _ = try trace.append(kind: .mapping, ruleID: "ASH-STATE-STRUCTURE-001", message: "Native boundary rejected unavailable or malformed evidence",
            evidence: .object([JSONMember("status", .string("FAILED")), JSONMember("failureCode", .string(code.rawValue))]), severity: .error)
        return try .init(code: code, failedStage: stage, diagnosticEnvelope: trace.envelopes.last!, diagnosticChain: trace.chain())
    }
}

struct SemanticTrace {
    let root: String
    private(set) var envelopes: [AeostaraContract.DiagnosticEnvelope] = []
    init(identity: String) { root = "diagnostic-" + identity }
    mutating func append(kind: AeostaraContract.DiagnosticEnvelope.DiagnosticKind, ruleID: String, message: String, evidence: JSONValue = .object([]), severity: AeostaraContract.DiagnosticEnvelope.Severity = .info) throws -> AeostaraContract.DiagnosticReference {
        let rule = try AeostaraContract.RuleReference(ruleID: ruleID, sourceReference: NativeAshBindingProvider.sourceReference, ruleFamily: ruleID.split(separator: "-").dropFirst().first.map(String.init) ?? "STATE")
        let id = envelopes.isEmpty ? root : root + "-" + String(envelopes.count + 1)
        let envelope = try AeostaraContract.DiagnosticEnvelope(diagnosticID: id, chainRootReference: root, parentDiagnosticID: envelopes.last?.diagnosticID,
            diagnosticKind: kind, severity: severity, message: message, ruleReferences: [rule], sourceReferences: [NativeAshBindingProvider.sourceReference], evidence: evidence)
        envelopes.append(envelope)
        return try .init(diagnosticID: id, chainRootReference: root, diagnosticKind: .init(rawValue: kind.rawValue)!, ruleReferences: [rule])
    }
    func chain() throws -> AeostaraContract.DiagnosticChain { try .init(chainID: "chain-" + root, rootDiagnosticID: root, diagnostics: envelopes) }
    mutating func failure(_ error: Error, stage: DiagnosticStage) throws -> LifecycleFailure {
        let code: LifecycleFailure.Code
        let status: String
        switch error {
        case ProjectionProblem.unknownMappingRule: code = .unknownMappingRule; status = "BLOCKED"
        case ProjectionProblem.missingEvidence: code = .missingEvidence; status = "BLOCKED"
        case is ProjectionAmbiguity, ProjectionProblem.ambiguousEvidence: code = .ambiguousMapping; status = "AMBIGUOUS"
        case ProjectionProblem.intentIncompatible: code = .intentIncompatible; status = "BLOCKED"
        case ProjectionProblem.missingMaterialization: code = .missingMaterialization; status = "BLOCKED"
        case CanonicalJSONError.unsupportedCanonicalNumber: code = .unsupportedCanonicalNumber; status = "FAILED"
        case ProjectionProblem.invalidContext: code = .invalidContext; status = "FAILED"
        default: code = .malformedContract; status = "FAILED"
        }
        let reference = try append(kind: .mapping, ruleID: "ASH-STATE-STRUCTURE-001", message: "Required native evidence unavailable or invalid",
            evidence: .object([JSONMember("status", .string(status)), JSONMember("failureCode", .string(code.rawValue))]), severity: .error)
        if let problem = error as? ProjectionAmbiguity {
            let ambiguity = try AeostaraContract.MappingAmbiguity(ambiguityID: "ambiguity-" + reference.diagnosticID, dimensionID: .init(rawValue: problem.dimensionID.rawValue)!, candidateValues: problem.candidateValues, evidence: problem.evidence, blockingRule: reference.ruleReferences[0], diagnosticReference: reference)
            let old = envelopes.last!
            envelopes[envelopes.count - 1] = try .init(diagnosticID: old.diagnosticID, chainRootReference: old.chainRootReference, parentDiagnosticID: old.parentDiagnosticID, diagnosticKind: old.diagnosticKind, severity: old.severity, message: old.message, ruleReferences: old.ruleReferences, sourceReferences: old.sourceReferences, evidence: .object([JSONMember("status", .string(status)), JSONMember("failureCode", .string(code.rawValue)), JSONMember("ambiguity", ambiguity.contractJSON)]))
        }
        return LifecycleFailure(code: code, failedStage: stage, diagnosticEnvelope: envelopes.last!, diagnosticChain: try chain())
    }
}

/// Immutable snapshot planning. It owns no filesystem or executable mutation capability.
public final class NativeHealingEngine: AeostaraContract.IHealingEngine {
    public let context: SemanticContext
    public let observed: JSONSnapshot
    public let desired: JSONSnapshot
    private let recorder: (any DiagnosticRecording)?
    private let sessionID: UUID
    private let operationLock = NSLock()
    private let preparedExecution: (any NativePreparedExecution)?
    public init(context: SemanticContext, observed: JSONSnapshot, desired: JSONSnapshot, recorder: (any DiagnosticRecording)? = nil,
                sessionID: UUID = UUID(), preparedExecution: (any NativePreparedExecution)? = nil) {
        self.context = context; self.observed = observed; self.desired = desired; self.recorder = recorder; self.sessionID = sessionID
        self.preparedExecution = preparedExecution
    }
    public func heal(observedState: AeostaraContract.ObservedSystemState, desiredIntent: AeostaraContract.DesiredSystemIntent,
                     projectionSpec: AeostaraContract.SemanticProjectionSpec, policyBundle: AeostaraContract.PolicyBundle,
                     executionContext: AeostaraContract.ExecutionContext) throws -> AeostaraContract.HealResult {
        let plan = try dryRun(observedState: observedState, desiredIntent: desiredIntent, projectionSpec: projectionSpec, policyBundle: policyBundle)
        guard let execution = preparedExecution, execution.contextIdentity == context.identity,
              execution.observedCanonicalHash == observed.canonicalHash, execution.desiredCanonicalHash == desired.canonicalHash,
              execution.policyBundle == policyBundle, execution.preparedPlan == plan,
              execution.executionContext == executionContext, executionContext.recoveryPlanID == plan.recoveryPlan.recoveryPlanID,
              executionContext.policyDecision.decision == .allow, executionContext.policyDecision.policyBundleID == policyBundle.policyBundleID,
              executionContext.backupResult.status == .succeeded, executionContext.backupResult.backupRecord.sourceHash == observed.canonicalHash,
              executionContext.verificationPlan == plan.verificationPlan else {
            var trace = SemanticTrace(identity: try traceIdentity())
            throw try trace.failure(ProjectionProblem.invalidContext, stage: .mutate)
        }
        return try execution.execute()
    }
    public func observedState() throws -> AeostaraContract.ObservedSystemState {
        let root = try traceIdentity()
        var trace = SemanticTrace(identity: root)
        let reference = try trace.append(kind: .mapping, ruleID: "ASH-STATE-STRUCTURE-001", message: "Native observation provenance")
        return try .init(observedSystemStateID: "observed-" + observed.canonicalHash,
            documentReference: observed.reference(role: .observed), surfaceDifferences: differences(reference: reference), diagnosticReference: reference)
    }
    public func desiredIntent(partialIntent: Bool = false) throws -> AeostaraContract.DesiredSystemIntent {
        var trace = SemanticTrace(identity: try traceIdentity())
        let reference = try trace.append(kind: .mapping, ruleID: "ASH-STATE-STRUCTURE-001", message: "Native intent provenance")
        return try .init(desiredSystemIntentID: "intent-" + desired.canonicalHash, documentReference: desired.reference(role: .desired), partialIntent: partialIntent, diagnosticReference: reference)
    }
    public func dryRun(policyBundle: AeostaraContract.PolicyBundle, partialIntent: Bool = false) throws -> AeostaraContract.DryRunResult {
        try dryRun(observedState: observedState(), desiredIntent: desiredIntent(partialIntent: partialIntent), projectionSpec: context.projectionSpec, policyBundle: policyBundle)
    }
    public func dryRun(observedState: AeostaraContract.ObservedSystemState, desiredIntent: AeostaraContract.DesiredSystemIntent,
                       projectionSpec: AeostaraContract.SemanticProjectionSpec, policyBundle: AeostaraContract.PolicyBundle) throws -> AeostaraContract.DryRunResult {
        var trace = SemanticTrace(identity: try traceIdentity())
        guard operationLock.try() else {
            let reference = try trace.append(kind: .recovery, ruleID: "ASH-RECOVERY-ACTION-001", message: "Concurrent native planning request rejected", severity: .error)
            _ = reference
            throw LifecycleFailure(code: .resourceBusy, failedStage: .initialize, diagnosticEnvelope: trace.envelopes.last!, diagnosticChain: try trace.chain())
        }
        defer { operationLock.unlock() }
        let operationID = UUID(), incidentID = UUID()
        var cause: UUID?
        var stage: DiagnosticStage = .observe
        func record(_ stage: DiagnosticStage, _ outcome: DiagnosticOutcome, _ fault: DiagnosticFault? = nil, mutations: Int = 0) {
            cause = recorder?.record(.init(sessionID: sessionID, operationID: operationID, incidentID: incidentID, stage: stage,
                outcome: outcome, fault: fault, causeEventIDs: cause.map { [$0] } ?? [], counters: .init(inputFields: 9, mutations: mutations)),
                developmentDetails: { .init(observedFieldCount: 9, desiredFieldCount: 9, ruleCount: self.context.mappingRules.count) })
        }
        do {
            record(.observe, .started)
            guard observedState.documentReference == (try observed.reference(role: .observed)), desiredIntent.documentReference == (try desired.reference(role: .desired)),
                  projectionSpec == context.projectionSpec, observedState.diagnosticReference == (try self.observedState()).diagnosticReference, desiredIntent.diagnosticReference == (try self.desiredIntent(partialIntent: desiredIntent.partialIntent)).diagnosticReference else { throw ProjectionProblem.invalidContext }
            let actualDifferences = try differences(reference: observedState.diagnosticReference)
            guard observedState.surfaceDifferences.count == actualDifferences.count,
                zip(observedState.surfaceDifferences.sorted { $0.path.pointer.utf8.lexicographicallyPrecedes($1.path.pointer.utf8) }, actualDifferences.sorted { $0.path.pointer.utf8.lexicographicallyPrecedes($1.path.pointer.utf8) }).allSatisfy({
                    $0.path == $1.path && $0.differenceKind == $1.differenceKind && $0.observedDocument == $1.observedDocument && $0.desiredDocument == $1.desiredDocument
                }) else { throw ProjectionProblem.inconsistentSurfaceEvidence }
            _ = policyBundle // Pure planning never grants policy authorization or mutation capability.
            _ = try trace.append(kind: .mapping, ruleID: "ASH-STATE-STRUCTURE-001", message: "Native observation provenance")
            _ = try trace.append(kind: .jsonSemantics, ruleID: "ASH-STATE-STRUCTURE-001", message: "Canonical snapshots and surface evidence established")
            record(.observe, .succeeded); record(.normalize, .succeeded)
            stage = .project; record(stage, .started)
            let projector = NativeSemanticProjector(context: context)
            let coordinates = try projector.projectCoordinates(observed: observed, desired: desired)
            let mappingReference = try trace.append(kind: .mapping, ruleID: "ASH-STATE-STRUCTURE-001", message: "All nine coordinates mapped from explicit evidence")
            let state = try stateDTO(coordinates)
            _ = try AeostaraContract.MappingResult(mappingResultID: "mapping-" + state.canonicalHash, status: .mapped, projectedState: state,
                dimensionBindings: projectionSpec.dimensions, ambiguities: [], diagnosticReferences: [mappingReference])
            record(stage, .succeeded)
            stage = .diagnose
            let ash = NativeAshBindingProvider()
            let diagnosis = try ash.diagnose(state: coordinates, context: context, observed: observed, desired: desired)
            let diagnosisReference = try trace.append(kind: .stateValidity, ruleID: "ASH-STATE-VALIDITY-001", message: "State diagnosed against explicit recognized-valid context",
                evidence: .object([JSONMember("admissibility", .string(diagnosis.admissibility.rawValue)), JSONMember("normalization", .string(diagnosis.normalization.rawValue)),
                    JSONMember("candidateState", state.contractJSON), JSONMember("contextReference", .string(context.identity)),
                    JSONMember("orbit", .array(diagnosis.orbit.map { .array($0.map { .integer(String($0)) }) })),
                    JSONMember("knownCorrection", diagnosis.knownCorrection.map { .string($0.definition.transitionID) } ?? .null),
                    JSONMember("fallbackCandidate", diagnosis.fallback.map { .string($0.policyID) } ?? .null)]))
            _ = try AeostaraContract.StateValidityDiagnostic(stateValidityDiagnosticID: "validity-" + state.canonicalHash,
                diagnosticEnvelope: trace.envelopes.last!, admissibilityStatus: .init(rawValue: diagnosis.admissibility.rawValue)!,
                normalizationStatus: diagnosis.normalization, recoverabilityRelevance: diagnosis.recoveryCategory)
            _ = diagnosisReference; record(stage, .succeeded)
            stage = .classify
            _ = try trace.append(kind: .recovery, ruleID: "ASH-CLASSIFICATION-MAPPING-001", message: "Canonical system state classified",
                evidence: .object([JSONMember("stateClass", .string(diagnosis.stateClass.rawValue))]))
            record(stage, .succeeded); stage = .recoverability
            _ = try trace.append(kind: .recovery, ruleID: "ASH-RECOVERY-ACTION-001", message: "Canonical recovery category established",
                evidence: .object([JSONMember("recoveryCategory", .string(diagnosis.recoveryCategory.rawValue))]))
            record(stage, .succeeded); stage = .plan
            let target = try ash.recoveryTarget(diagnosis, context: context, observed: observed, desired: desired)
            if diagnosis.recoveryCategory == .noAction, try !ash.intentMatches(coordinates, context: context, desired: desired) { throw ProjectionProblem.intentIncompatible }
            let reference = try trace.append(kind: .recovery, ruleID: "ASH-RECOVERY-ACTION-001", message: "Pure recovery plan prepared")
            var operations: [AeostaraContract.JsonMutationOperation] = []
            var planned = observed.value
            if let target, diagnosis.recoveryCategory != .noAction {
                for binding in projectionSpec.dimensions.sorted(by: { $0.dimensionID.rawValue < $1.dimensionID.rawValue }) {
                    let i = Int(binding.dimensionID.rawValue.dropFirst())!
                    if target[i] == coordinates[i] { continue }
                    let drafts = try context.mapping(binding.mappingRule).materialize(binding: binding, targetBit: target[i], observed: observed, desired: desired)
                    guard !drafts.isEmpty else { throw ProjectionProblem.missingMaterialization }
                    for draft in drafts {
                        guard binding.sourcePointers.contains(where: { $0.pointer.utf8.elementsEqual(draft.pointer.utf8) }) else { throw ProjectionProblem.invalidContext }
                        let old = try planned.resolve(pointer: draft.pointer)
                        let pointer = try AeostaraContract.JsonPointer(pointer: draft.pointer, tokens: JSONValue.pointerTokens(draft.pointer), pointsToMissing: old == nil, pointsToNull: old == .null)
                        operations.append(try .init(operationID: "operation-\(operations.count + 1)", op: draft.op, path: pointer, value: draft.value,
                            preconditionHash: planned.canonicalHash(), diagnosticReference: reference))
                        planned = try planned.applying(draft)
                    }
                }
                let plannedSnapshot = try JSONSnapshot(documentID: "planned", sourceReference: "native-pure-plan", data: planned.canonicalData())
                guard try projector.projectCoordinates(observed: plannedSnapshot, desired: desired, validatePointerEvidence: false) == target,
                      context.knownValidStates.states.contains(target), try ash.intentMatches(target, context: context, desired: desired) else { throw ProjectionProblem.missingMaterialization }
            }
            let disposition: AeostaraContract.RecoveryPlan.PlanDisposition = diagnosis.recoveryCategory == .noAction ? .noAction : target == nil ? .escalationRequired : .mutationRequired
            let steps: [AeostaraContract.RecoveryStep]
            if diagnosis.recoveryCategory == .noAction { steps = [] }
            else {
                let type: AeostaraContract.RecoveryStep.StepType = diagnosis.recoveryCategory == .normalizeState ? .normalizeState : diagnosis.recoveryCategory == .applyCorrection ? .applyCorrection : diagnosis.recoveryCategory == .fallbackRequired ? .selectFallback : .escalate
                steps = [try .init(stepID: "recovery-step-1", stepType: type, description: "Source-derived native recovery action", jsonMutationOperations: operations, diagnosticReference: reference)]
            }
            let planHash = try JSONValue.object([JSONMember("context", .string(context.identity)), JSONMember("observed", .string(observed.canonicalHash)), JSONMember("desired", .string(desired.canonicalHash)), JSONMember("steps", .array(steps.map(\.contractJSON))), JSONMember("category", diagnosis.recoveryCategory.contractJSON)]).canonicalHash()
            let plan = try AeostaraContract.RecoveryPlan(recoveryPlanID: "plan-" + planHash, planDisposition: disposition, diagnosticReference: reference,
                stateClass: diagnosis.stateClass, recoveryCategory: diagnosis.recoveryCategory, requiresPolicyGate: disposition == .mutationRequired,
                requiresBackup: disposition == .mutationRequired, recoverySteps: steps, planHash: planHash, createdAt: "unavailable-pure-planning-clock")
            let verification = try AeostaraContract.VerificationPlan(verificationPlanID: "verification-" + planHash,
                checks: [.object([JSONMember("kind", .string("EXACT_PLANNED_RESOURCE_AND_SEMANTIC_INTENT")), JSONMember("resourceHash", .string(try planned.canonicalHash()))])],
                expectedSemanticState: stateDTO(target ?? coordinates), generatedBeforeMutation: true, diagnosticReference: reference)
            record(stage, disposition == .noAction ? .noAction : .succeeded, mutations: operations.count)
            return try .init(dryRunResultID: "dry-run-" + planHash, wouldMutate: disposition == .mutationRequired, recoveryPlan: plan, verificationPlan: verification, diagnosticChain: trace.chain())
        } catch {
            record(stage, .failed, .init(code: stage == .project ? .mapping : .invalidContract))
            throw try trace.failure(error, stage: stage)
        }
    }
    private func traceIdentity() throws -> String {
        try JSONValue.array([.string(context.identity), .string(observed.canonicalHash), .string(desired.canonicalHash)]).canonicalHash()
    }
    private func stateDTO(_ coordinates: [Int]) throws -> AeostaraContract.AshState {
        try NativeAshBindingProvider.validate(coordinates)
        let hash = try JSONValue.array(coordinates.map { .integer(String($0)) }).canonicalHash()
        return try .init(stateID: "state-" + hash, coordinates: coordinates, sourceReference: NativeAshBindingProvider.sourceReference, canonicalHash: hash)
    }
    private func differences(reference: AeostaraContract.DiagnosticReference) throws -> [AeostaraContract.SurfaceDifference] {
        var entries: [(String, AeostaraContract.SurfaceDifference.DifferenceKind, JSONValue?)] = []
        func walk(_ old: JSONValue?, _ new: JSONValue?, _ path: String) {
            if old == new { return }
            if case .object(let a) = old, case .object(let b) = new {
                var names = a.map(\.name)
                for member in b where !names.contains(where: { $0.utf8.elementsEqual(member.name.utf8) }) { names.append(member.name) }
                for name in names.sorted(by: { $0.utf8.lexicographicallyPrecedes($1.utf8) }) {
                    walk(old?.member(name), new?.member(name), path + "/" + name.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(of: "/", with: "~1"))
                }
            } else {
                let kind: AeostaraContract.SurfaceDifference.DifferenceKind
                if old == nil { kind = .added }
                else if new == nil { kind = .removed }
                else if case .array = old, case .array = new { kind = .arrayChanged }
                else {
                    func type(_ value: JSONValue?) -> Int {
                        switch value {
                        case .null: return 0
                        case .bool: return 1
                        case .integer: return 2
                        case .real: return 3
                        case .string: return 4
                        case .array: return 5
                        case .object: return 6
                        case nil: return 7
                        }
                    }
                    kind = type(old) == type(new) ? .replaced : .typeChanged
                }
                entries.append((path, kind, old))
            }
        }
        walk(observed.value, desired.value, "")
        return try entries.map { path, kind, old in
            let hash = try JSONValue.array([.string(path), .string(kind.rawValue)]).canonicalHash()
            return try .init(differenceID: "difference-" + hash, path: .init(pointer: path, tokens: JSONValue.pointerTokens(path), pointsToMissing: old == nil, pointsToNull: old == .null),
                differenceKind: kind, observedDocument: observed.reference(role: .observed), desiredDocument: desired.reference(role: .desired), diagnosticReference: reference)
        }
    }
}
