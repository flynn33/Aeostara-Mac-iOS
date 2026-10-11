import Foundation

public enum LifecycleFaultCode: String, Codable {
    case missingSemanticContext, unknownMappingRule, missingEvidence, ambiguousMapping, malformedContract
    case unsupportedCanonicalNumber, intentIncompatible, missingMaterialization, policyBlocked, backupFailed
    case auditFailed, executionFailed, verificationFailed, rollbackFailed, staleSnapshot, scopeViolation
    case resourceBusy, containmentBreach, terminalHalt
}
public struct LifecycleFailure: Error {
    public let code: LifecycleFaultCode
    public let diagnosticChain: AeostaraContract.DiagnosticChain
    public let auditChain: AeostaraContract.AuditChain
}

struct NativeDiagnosticLink {
    let operationID: UUID
    let incidentID: UUID
    let parentOperationID: UUID?
    let causeEventID: UUID?
}

public struct NativeDiagnosisPlan {
    public let observedState: AeostaraContract.ObservedSystemState
    public let desiredIntent: AeostaraContract.DesiredSystemIntent
    public let mapping: AeostaraContract.MappingResult
    public let validityEvidence: AshValidityEvidence
    public let validityDiagnostic: AeostaraContract.StateValidityDiagnostic
    public let stateClass: AeostaraContract.SystemStateClass
    public let recoveryCategory: AeostaraContract.RecoveryCategory
    public let dryRunResult: AeostaraContract.DryRunResult
    public let auditChain: AeostaraContract.AuditChain
    public let observedDocument: JSONValue
    public let desiredDocument: JSONValue
    public let plannedDocument: JSONValue
    public let plannedHash: String
    let issuerID: UUID
    let diagnosticLink: NativeDiagnosticLink
}

final class SemanticLedger {
    let root: String
    let chainID: String
    let time: String
    var diagnostics: [AeostaraContract.DiagnosticEnvelope] = []
    var auditEvents: [AeostaraContract.AuditEvent] = []
    init(identity: String, time: String) throws {
        root = "diagnostic-" + identity; chainID = "chain-" + identity; self.time = time
        _ = try append(kind: .STATE_VALIDITY, event: .OBSERVE, message: "Observed immutable input", rule: "ASH-STATE-STRUCTURE-001")
    }
    init(preparation: NativeDiagnosisPlan, time: String) {
        let chain = preparation.dryRunResult.diagnosticChain
        root = chain.rootDiagnosticID; chainID = chain.chainID; self.time = time
        diagnostics = chain.diagnostics; auditEvents = preparation.auditChain.events
    }
    @discardableResult
    func append(kind: AeostaraContract.DiagnosticEnvelope.DiagnosticKindValue,
                event: AeostaraContract.AuditEvent.EventTypeValue, message: String,
                rule: String = "ASH-STATE-VALIDITY-001", failed: Bool = false,
                evidence: JSONValue = .object([])) throws -> AeostaraContract.DiagnosticReference {
        let source = try NativeAshBindingProvider.source(for:rule)
        let ruleRef = try AeostaraContract.RuleReference(ruleID: rule, sourceReference: source, ruleFamily: String(rule.split(separator: "-")[1]))
        let diagnosticID = diagnostics.isEmpty ? root : root + "-" + String(diagnostics.count+1)
        let envelope = try AeostaraContract.DiagnosticEnvelope(diagnosticID: diagnosticID, chainRootReference: root,
                                                               parentDiagnosticID: diagnostics.last?.diagnosticID, diagnosticKind: kind,
                                                               severity: failed ? .ERROR : .INFO, message: message,
                                                               ruleReferences: [ruleRef], sourceReferences: [source], evidence: evidence)
        diagnostics.append(envelope)
        let reference = try AeostaraContract.DiagnosticReference(diagnosticID: diagnosticID, chainRootReference: root,
                                                                diagnosticKind: .init(rawValue: kind.rawValue)!, ruleReferences: [ruleRef])
        auditEvents.append(try AeostaraContract.AuditEvent(auditEventID: "audit-" + diagnosticID, eventSequence: auditEvents.count+1,
                                                          eventType: event, diagnosticReference: reference, occurredAt: time, details: evidence))
        return reference
    }
    func reference() throws -> AeostaraContract.DiagnosticReference {
        let envelope = diagnostics.last!
        return try AeostaraContract.DiagnosticReference(diagnosticID: envelope.diagnosticID, chainRootReference: root,
                                                        diagnosticKind: .init(rawValue: envelope.diagnosticKind.rawValue)!, ruleReferences: envelope.ruleReferences)
    }
    func diagnosticChain() throws -> AeostaraContract.DiagnosticChain { try AeostaraContract.DiagnosticChain(chainID: chainID, rootDiagnosticID: root, diagnostics: diagnostics) }
    func auditChain() throws -> AeostaraContract.AuditChain { try AeostaraContract.AuditChain(auditChainID: "audit-" + chainID, diagnosticChainReference: chainID, events: auditEvents) }
    func failure(_ code: LifecycleFaultCode) throws -> LifecycleFailure {
        _ = try append(kind: .MAPPING, event: .RESULT, message: "Semantic operation failed closed", failed: true, evidence: .object([JSONMember("fault", .string(code.rawValue))]))
        return try LifecycleFailure(code: code, diagnosticChain: diagnosticChain(), auditChain: auditChain())
    }
}

/// Pure native preparation. Platform mutation capability is deliberately absent from this boundary.
public final class NativeHealingEngine {
    public let context: SemanticContext
    let timestampProvider: () -> String
    let recorder: (any DiagnosticRecording)?
    let sessionID: UUID
    let resourceIO: (any SemanticResourceIO)?
    let policyRegistry: NativePolicyRegistry?
    let snapshotRegistry: JSONSnapshotRegistry?
    let defaultResources: NativeResourceSet?
    let containmentPolicy: NativeContainmentPolicy?
    let identifierProvider: () -> String
    let runtimeGuard = NSLock()
    let engineID = UUID()
    var operationActive = false
    var terminalFailure: LifecycleFailure?
    var containment: AeostaraContract.ContainmentDecision?
    var lastLedger: SemanticLedger?
    weak var pendingExecution: NativePreparedExecution?
    var executionDiagnosticLinks: [UUID: NativeDiagnosticLink] = [:]
    public init(context: SemanticContext, timestampProvider: @escaping () -> String,
                recorder: (any DiagnosticRecording)? = nil, sessionID: UUID = UUID(),
                resourceIO: (any SemanticResourceIO)? = nil, policies: NativePolicyRegistry? = nil,
                snapshots: JSONSnapshotRegistry? = nil, resources: NativeResourceSet? = nil,
                containmentPolicy: NativeContainmentPolicy? = nil,
                identifierProvider: @escaping () -> String = { UUID().uuidString }) {
        self.context = context; self.timestampProvider = timestampProvider; self.recorder = recorder; self.sessionID = sessionID
        self.resourceIO = resourceIO; policyRegistry = policies; snapshotRegistry = snapshots; defaultResources = resources
        self.containmentPolicy = containmentPolicy; self.identifierProvider = identifierProvider
    }

    public func prepare(observed: JSONValue, desired: JSONValue, partialIntent: Bool = false) throws -> NativeDiagnosisPlan {
        try prepareNative(observed:observed,desired:desired,partialIntent:partialIntent)
    }
    func prepareNative(observed: JSONValue, desired: JSONValue, partialIntent: Bool, forcedFallback: Bool = false, fallbackPolicyID: String? = nil, diagnosticParent: NativeDiagnosticLink? = nil) throws -> NativeDiagnosisPlan {
        runtimeGuard.lock(); let terminal = terminalFailure; let contained = containment != nil; runtimeGuard.unlock()
        if let terminal { throw terminal }
        let operationID = UUID()
        let incidentID = diagnosticParent?.incidentID ?? operationID
        var causes: [UUID] = diagnosticParent?.causeEventID.map{[$0]} ?? []
        var currentStage = DiagnosticStage.observe
        func emit(_ stage: DiagnosticStage, _ outcome: DiagnosticOutcome, fault: DiagnosticFaultCode? = nil, items: UInt64 = 0) {
            let event = DiagnosticEvent(sessionID: sessionID, operationID: operationID, incidentID: stage == .plan || fault != nil ? incidentID : nil,
                                        parentOperationID: diagnosticParent?.operationID, stage: stage, outcome: outcome, expected: fault == nil ? nil : .succeeded,
                                        fault: fault.map { DiagnosticFault(code: $0) }, causeEventIDs: causes, counters: .init(items: items))
            if let retained = recorder?.record(event, developmentDetails: nil) {
                causes = [retained]
                if stage == .plan || fault != nil, let parent = diagnosticParent { setTelemetryCause(operation:parent.operationID,eventID:retained) }
            }
        }
        emit(.observe, .started)
        let observedHash: String, desiredHash: String
        do { observedHash = try CanonicalJSON.hash(observed); desiredHash = try CanonicalJSON.hash(desired) }
        catch {
            emit(.observe,.failed,fault:.invalidContract)
            let failureLedger = try SemanticLedger(identity:context.knownValidStates.contextHash,time:timestampProvider())
            throw try failureLedger.failure((error as? CanonicalJSONError) == .unsupportedNumber ? .unsupportedCanonicalNumber : .malformedContract)
        }
        let identity = try CanonicalJSON.hash(.object([JSONMember("observed", .string(observedHash)), JSONMember("desired", .string(desiredHash)), JSONMember("context", .string(context.knownValidStates.contextHash))]))
        let ledger = try SemanticLedger(identity: identity, time: timestampProvider())
        do {
            let observedReference = try AeostaraContract.JsonDocumentReference(documentID: "observed-" + observedHash, role: .OBSERVED, canonicalHash: observedHash, sourceReference: context.applicationScopeID)
            let desiredReference = try AeostaraContract.JsonDocumentReference(documentID: "desired-" + desiredHash, role: .DESIRED, canonicalHash: desiredHash, sourceReference: context.applicationScopeID)
            let observedSnapshot = try JSONSnapshot(document: observed, reference: observedReference)
            let desiredSnapshot = try JSONSnapshot(document: desired, reference: desiredReference)
            emit(.observe, .succeeded)
            currentStage = .normalize
            let normalized = try ledger.append(kind: .JSON_SEMANTICS, event: .NORMALIZE, message: "Canonicalized without mutation", rule: "ASH-STATE-STRUCTURE-001")
            emit(.normalize, .succeeded)
            let differences = try NativeSemanticProjector.surfaceDifferences(observed: observedSnapshot, desired: desiredSnapshot, diagnostic: normalized)
            let observedState = try AeostaraContract.ObservedSystemState(observedSystemStateID: "observation-" + observedHash, documentReference: observedReference, surfaceDifferences: differences, diagnosticReference: normalized)
            let desiredIntent = try AeostaraContract.DesiredSystemIntent(desiredSystemIntentID: "intent-" + desiredHash, documentReference: desiredReference, partialIntent: partialIntent, diagnosticReference: normalized)
            let projector = NativeSemanticProjector(observed: observedSnapshot, desired: desiredSnapshot, context: context, diagnostic: normalized,diagnosticChains:[try ledger.diagnosticChain()])
            currentStage = .project
            let mapping = try projector.project(observedState: observedState, desiredIntent: desiredIntent, projectionSpec: context.projectionSpec)
            _ = try ledger.append(kind: .MAPPING, event: .PROJECT, message: "Resolved all nine coordinates", evidence: .object([JSONMember("dimensionCount", .number(.integer("9")))]))
            emit(.project, .succeeded, items: 9)
            currentStage = .diagnose
            let targets = try eligibleTargets(observed: observedSnapshot, desired: desiredSnapshot, partialIntent: partialIntent)
            let binding = NativeAshBindingProvider(context: context)
            let validity = try binding.diagnose(mapping.projectedState.coordinates, eligibleTargets: targets.map(\.coordinates))
            let diagnosticReference = try ledger.append(kind: .STATE_VALIDITY, event: .DIAGNOSE, message: "Diagnosed canonical full-state orbit", rule: "ASH-ADMISSIBILITY-CLASSIFICATION-001",evidence:binding.diagnosticEvidence(validity,state:mapping.projectedState))
            emit(.diagnose, .succeeded, items: 16)
            currentStage = .classify
            let stateClass = contained ? AeostaraContract.SystemStateClass.CONTAINED : (forcedFallback ? .DEGRADED : binding.classify(validity))
            let category = forcedFallback ? AeostaraContract.RecoveryCategory.FALLBACK_REQUIRED : binding.recoveryCategory(for: stateClass)
            _ = try ledger.append(kind: .STATE_VALIDITY, event: .CLASSIFY, message: "Selected canonical state class and recovery category", rule: "ASH-CLASSIFICATION-MAPPING-001",
                                  evidence: .object([JSONMember("stateClass", stateClass.jsonValue), JSONMember("recoveryCategory", category.jsonValue)]))
            emit(.classify, .succeeded)
            emit(.recoverability, .succeeded)
            currentStage = .plan
            let envelope = ledger.diagnostics.first { $0.diagnosticID == diagnosticReference.diagnosticID }!
            let validityDiagnostic = try AeostaraContract.StateValidityDiagnostic(stateValidityDiagnosticID: "validity-" + mapping.projectedState.canonicalHash,
                                                                                  diagnosticEnvelope: envelope, admissibilityStatus: .init(rawValue: validity.admissibility.rawValue)!,
                                                                                  normalizationStatus: validity.normalization, recoverabilityRelevance: category)
            let expectedState: AeostaraContract.AshState
            let steps: [AeostaraContract.RecoveryStep]
            let disposition: AeostaraContract.RecoveryPlan.PlanDispositionValue
            switch category {
            case .NO_ACTION:
                expectedState = mapping.projectedState; steps = []; disposition = .NO_ACTION
            case .NORMALIZE_STATE, .APPLY_CORRECTION:
                let eligible = targets.filter { validity.recognizedInOrbit.contains($0.coordinates) }
                guard let target = try selectTarget(eligible, proof: validity.knownCorrection) else { throw SemanticInputFault.intentIncompatible }
                if validity.knownCorrection == nil && eligible.count > 1 {
                    _ = try ledger.append(kind:.RECOVERY,event:.PLAN,message:"Equal one-codeword normalization candidates resolved by canonical bytes",evidence:.object([JSONMember("candidates",.array(eligible.map(\.jsonValue))),JSONMember("selected",target.jsonValue)]))
                }
                expectedState = target
                let operations = try materialize(target: target, observed: observedSnapshot, desired: desiredSnapshot, diagnostic: ledger.reference())
                guard !operations.isEmpty else { throw SemanticInputFault.missingMaterialization }
                steps = [try AeostaraContract.RecoveryStep(stepID: "step-" + target.canonicalHash, stepType: category == .NORMALIZE_STATE ? .NORMALIZE_STATE : .APPLY_CORRECTION,
                                                           description: "Apply validated canonical target", jsonMutationOperations: operations, diagnosticReference: ledger.reference())]
                disposition = .MUTATION_REQUIRED
            case .FALLBACK_REQUIRED:
                guard let (_, target) = try binding.eligibleFallbacks(for: mapping.projectedState.coordinates, eligibleTargets: targets.map(\.coordinates)).first(where:{fallbackPolicyID == nil || $0.0.policyID == fallbackPolicyID}) else { throw SemanticInputFault.intentIncompatible }
                expectedState = target
                let operations = try materialize(target: target, observed: observedSnapshot, desired: desiredSnapshot, diagnostic: ledger.reference())
                steps = [try AeostaraContract.RecoveryStep(stepID: "fallback-" + target.canonicalHash, stepType: .SELECT_FALLBACK, description: "Registry selected fallback", jsonMutationOperations: operations, diagnosticReference: ledger.reference())]
                disposition = operations.isEmpty ? .ESCALATION_REQUIRED : .MUTATION_REQUIRED
            case .ESCALATION_REQUIRED, .CONTAINMENT_REQUIRED, .TERMINAL_NO_RECOVERY:
                expectedState = mapping.projectedState; steps = []; disposition = category == .TERMINAL_NO_RECOVERY ? .TERMINAL : .ESCALATION_REQUIRED
            }
            let planReference = try ledger.append(kind: .RECOVERY, event: .PLAN, message: "Prepared non-mutating recovery and verification plans", rule: "ASH-RECOVERY-ACTION-001")
            var plannedDocument = observed
            for operation in steps.flatMap(\.jsonMutationOperations) {
                guard try CanonicalJSON.hash(plannedDocument) == operation.preconditionHash else { throw SemanticInputFault.malformedEvidence }
                plannedDocument = try JSONPointer(operation.path.pointer).applying(operation.op,value:operation.value,to:plannedDocument)
            }
            let plannedHash = try CanonicalJSON.hash(plannedDocument)
            if disposition == .MUTATION_REQUIRED {
                let postReference = try AeostaraContract.JsonDocumentReference(documentID: "planned-" + plannedHash,role:.OBSERVED,canonicalHash:plannedHash,sourceReference:context.applicationScopeID)
                let post = try JSONSnapshot(document:plannedDocument,reference:postReference)
                let postDifferences = try NativeSemanticProjector.surfaceDifferences(observed:post,desired:desiredSnapshot,diagnostic:planReference)
                let postObserved = try AeostaraContract.ObservedSystemState(observedSystemStateID:"planned-" + plannedHash,documentReference:postReference,surfaceDifferences:postDifferences,diagnosticReference:planReference)
                let postMapping = try NativeSemanticProjector(observed:post,desired:desiredSnapshot,context:context,diagnostic:planReference,diagnosticChains:[try ledger.diagnosticChain()]).project(observedState:postObserved,desiredIntent:desiredIntent,projectionSpec:context.projectionSpec)
                guard postMapping.projectedState.coordinates == expectedState.coordinates,
                      binding.classify(try binding.diagnose(postMapping.projectedState.coordinates,eligibleTargets:targets.map(\.coordinates))) == .STABLE else { throw SemanticInputFault.malformedEvidence }
                for pointer in context.intentConstraints.pointers {
                    if partialIntent && pointer.resolve(in:desired) == nil { continue }
                    guard pointer.resolve(in:plannedDocument) == pointer.resolve(in:desired) else { throw SemanticInputFault.intentIncompatible }
                }
            }
            let planIdentity = try CanonicalJSON.hash(.object([JSONMember("observed", .string(observedHash)), JSONMember("target", expectedState.jsonValue), JSONMember("steps", .array(steps.map(\.jsonValue))), JSONMember("category", category.jsonValue)]))
            let plan = try AeostaraContract.RecoveryPlan(recoveryPlanID: "plan-" + planIdentity, planDisposition: disposition, diagnosticReference: planReference,
                                                       stateClass: stateClass, recoveryCategory: category, requiresPolicyGate: disposition == .MUTATION_REQUIRED,
                                                       requiresBackup: disposition == .MUTATION_REQUIRED, recoverySteps: steps, planHash: planIdentity, createdAt: ledger.time)
            let verification = try AeostaraContract.VerificationPlan(verificationPlanID: "verification-" + planIdentity,
                                                                    checks: [.object([JSONMember("check", .string("EXPECTED_FULL_SEMANTIC_STATE"))])], expectedSemanticState: expectedState,
                                                                    generatedBeforeMutation: true, diagnosticReference: planReference)
            _ = try ledger.append(kind: .RECOVERY, event: .RESULT, message: "Dry run completed without mutation", rule: "ASH-RECOVERY-ACTION-001")
            let result = try AeostaraContract.DryRunResult(dryRunResultID: "dry-run-" + planIdentity, wouldMutate: disposition == .MUTATION_REQUIRED,
                                                        recoveryPlan: plan, verificationPlan: verification, diagnosticChain: ledger.diagnosticChain())
            emit(.plan, disposition == .NO_ACTION ? .noAction : .succeeded, items: UInt64(steps.count))
            return try NativeDiagnosisPlan(observedState: observedState, desiredIntent: desiredIntent, mapping: mapping, validityEvidence: validity,
                                           validityDiagnostic: validityDiagnostic, stateClass: stateClass, recoveryCategory: category,
                                           dryRunResult: result, auditChain: ledger.auditChain(), observedDocument:observed,desiredDocument:desired,plannedDocument:plannedDocument,plannedHash:plannedHash,issuerID:engineID,diagnosticLink:.init(operationID:operationID,incidentID:incidentID,parentOperationID:diagnosticParent?.operationID,causeEventID:causes.last))
        } catch let fault as SemanticInputFault {
            let code: LifecycleFaultCode
            switch fault {
            case .unknownMappingRule: code = .unknownMappingRule
            case .missingEvidence: code = .missingEvidence
            case .ambiguousMapping: code = .ambiguousMapping
            case .malformedEvidence: code = .malformedContract
            case .missingMaterialization: code = .missingMaterialization
            case .intentIncompatible: code = .intentIncompatible
            }
            emit(currentStage, .failed, fault: currentStage == .project ? .mapping : .invalidContract)
            throw try ledger.failure(code)
        } catch let failure as LifecycleFailure { emit(currentStage,.failed,fault:currentStage == .project ? .mapping : .invalidContract);throw try ledger.failure(failure.code) }
        catch { emit(currentStage, .failed, fault: .invalidContract); throw try ledger.failure(.malformedContract) }
    }

    private func eligibleTargets(observed: JSONSnapshot, desired: JSONSnapshot, partialIntent: Bool) throws -> [AeostaraContract.AshState] {
        for pointer in context.intentConstraints.pointers where !partialIntent {
            guard pointer.resolve(in: desired.document) != nil else { throw SemanticInputFault.missingEvidence }
        }
        var required: [(Int, Int)] = []
        for (index, binding) in context.projectionSpec.dimensions.enumerated() {
            let pointers = try binding.sourcePointers.map { try JSONPointer($0.pointer) }
            let bound = pointers.contains { pointer in context.intentConstraints.pointers.contains { $0.text.utf8.elementsEqual(pointer.text.utf8) } }
            guard bound else { continue }
            let evidence = pointers.map { PointerObservation(pointer: $0, value: $0.resolve(in: desired.document)) }
            if partialIntent && evidence.contains(where: { $0.value == nil }) { continue }
            guard evidence.allSatisfy({ $0.value != nil }) else { throw SemanticInputFault.missingEvidence }
            let candidates = try context.mappingRules.resolve(binding.mappingRule).candidates(binding: binding, evidence: evidence, desired: desired)
            guard !candidates.isEmpty, candidates.allSatisfy({ $0 == 0 || $0 == 1 }) else { throw SemanticInputFault.malformedEvidence }
            let distinct = Array(Set(candidates)).sorted(); guard distinct.count == 1 else { throw SemanticInputFault.ambiguousMapping(distinct) }
            required.append((index, distinct[0]))
        }
        return context.knownValidStates.recognizedStates.filter { state in required.allSatisfy { state.coordinates[$0.0] == $0.1 } }
    }
    private func selectTarget(_ targets: [AeostaraContract.AshState], proof: SpecificCorrectionProof?) throws -> AeostaraContract.AshState? {
        if let proof { return targets.first { $0.coordinates == proof.targetState } }
        return try targets.map { ($0, try ContractCoding.canonicalEncode($0)) }.sorted { $0.1.lexicographicallyPrecedes($1.1) }.first?.0
    }
    private func materialize(target: AeostaraContract.AshState, observed: JSONSnapshot, desired: JSONSnapshot,
                             diagnostic: AeostaraContract.DiagnosticReference) throws -> [AeostaraContract.JsonMutationOperation] {
        var operations: [AeostaraContract.JsonMutationOperation] = []
        var currentDocument = observed.document
        for (index, binding) in context.projectionSpec.dimensions.enumerated() {
            let rule = try context.mappingRules.resolve(binding.mappingRule)
            let drafts = try rule.materialize(binding: binding, targetBit: target.coordinates[index], observed: observed, desired: desired)
            for draft in drafts {
                guard binding.sourcePointers.contains(where: { $0.pointer.utf8.elementsEqual(draft.path.text.utf8) }) else { throw SemanticInputFault.malformedEvidence }
                let current = draft.path.resolve(in: currentDocument)
                if (draft.op == .replace || draft.op == .test), current == nil { throw SemanticInputFault.missingEvidence }
                if draft.op == .remove, current == nil { throw SemanticInputFault.missingEvidence }
                if draft.op != .remove, draft.value == nil { throw SemanticInputFault.malformedEvidence }
                if draft.op == .replace && current == draft.value { continue }
                let pointer = try AeostaraContract.JsonPointer(pointer: draft.path.text, tokens: draft.path.tokens, pointsToMissing: current == nil, pointsToNull: current == .null)
                let identity = try CanonicalJSON.hash(.object([JSONMember("path", .string(draft.path.text)), JSONMember("op", .string(draft.op.rawValue)), JSONMember("before", .string(observed.reference.canonicalHash)), JSONMember("value", draft.value ?? .null)]))
                operations.append(try AeostaraContract.JsonMutationOperation(operationID: "operation-" + identity, op: draft.op, path: pointer, value: draft.value,
                                                                            preconditionHash: CanonicalJSON.hash(currentDocument), diagnosticReference: diagnostic))
                currentDocument = try draft.path.applying(draft.op,value:draft.value,to:currentDocument)
            }
        }
        return operations
    }
}
