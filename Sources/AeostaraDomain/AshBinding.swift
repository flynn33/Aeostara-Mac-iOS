import Foundation

public struct AshValidityEvidence {
    public let inputState: [Int]
    public let admissibility: AeostaraContract.AdmissibilityResult.StatusValue
    public let normalization: AeostaraContract.StateValidityDiagnostic.NormalizationStatusValue
    public let orbit: [[Int]]
    public let recognizedInOrbit: [[Int]]
    public let knownCorrection: SpecificCorrectionProof?
    public let fallbackAvailable: Bool
}
public struct SpecificCorrectionProof {
    public let transitionID: String
    public let inputState: [Int]
    public let codeword: [Int]
    public let targetState: [Int]
}

public final class NativeAshBindingProvider {
    public static let canonicalCodewords: [[Int]] = [
        "000000000", "000011110", "001100110", "001111000", "010101010", "010110100", "011001100", "011010010",
        "100101100", "100110010", "101001010", "101010100", "110000110", "110011000", "111100000", "111111110"
    ].map { $0.utf8.map { Int($0 - 48) } }
    public static let authorityReference = "ASH-Pattern-System@e123f5d7fdbb381179971f721a3292c31eb1cbc2/specs/core/codeword-set.pseudo.md"
    public static func source(for rule: String) throws -> String {
        let path: String
        switch rule {
        case "ASH-STATE-STRUCTURE-001": path = "core/ash-state-space.pseudo.md"
        case "ASH-STATE-VALIDITY-001": path = "core/state-validity-diagnostics.pseudo.md"
        case "ASH-CODEWORD-STRUCTURE-001": path = "core/codeword-set.pseudo.md"
        case "ASH-ADMISSIBILITY-CLASSIFICATION-001": path = "core/state-admissibility.pseudo.md"
        case "ASH-CLASSIFICATION-MAPPING-001": path = "core/system-state-classification.pseudo.md"
        case "ASH-RECOVERY-ACTION-001": path = "core/recoverability-semantics.pseudo.md"
        case "ASH-FALLBACK-SELECTION-001": path = "registries/fallback-policy-registry.md"
        case "ASH-CONTAINMENT-TRIGGER-001", "ASH-HALT-TRIGGER-001": path = "algorithms/containment-safe-failure-semantics.pseudo.md"
        default: throw SemanticInputFault.malformedEvidence
        }
        return "ASH-Pattern-System@e123f5d7fdbb381179971f721a3292c31eb1cbc2/specs/" + path
    }
    public let context: SemanticContext
    public let operations: AshOperationContext?
    let suppliedDiagnostics: NativeDiagnosticRegistry?
    let provenanceLock = NSLock()
    var issuedDiagnosticChains: [AeostaraContract.DiagnosticChain] = []
    public init(context: SemanticContext, operations: AshOperationContext? = nil, diagnosticRegistry: NativeDiagnosticRegistry? = nil) {
        self.context = context;self.operations = operations;self.suppliedDiagnostics = diagnosticRegistry
    }
    public func diagnosticRegistry() throws -> NativeDiagnosticRegistry {
        provenanceLock.lock();let issued = issuedDiagnosticChains;provenanceLock.unlock()
        return try NativeDiagnosticRegistry(chains:context.inputDiagnosticChains + (suppliedDiagnostics?.chains ?? []) + issued)
    }
    func retain(_ ledger: SemanticLedger) throws {
        let immutable = try ledger.diagnosticChain()
        provenanceLock.lock();defer { provenanceLock.unlock() }
        _ = try NativeDiagnosticRegistry(chains:context.inputDiagnosticChains + (suppliedDiagnostics?.chains ?? []) + issuedDiagnosticChains + [immutable])
        if !issuedDiagnosticChains.contains(where:{$0 == immutable}) { issuedDiagnosticChains.append(immutable) }
    }
    public static func xor(_ state: [Int], _ codeword: [Int]) throws -> [Int] {
        guard state.count == 9, codeword.count == 9, (state + codeword).allSatisfy({ $0 == 0 || $0 == 1 }) else { throw SemanticInputFault.malformedEvidence }
        return zip(state, codeword).map { $0 ^ $1 }
    }
    public func orbit(of coordinates: [Int]) throws -> [[Int]] { try Self.canonicalCodewords.map { try Self.xor(coordinates, $0) }.sorted { $0.lexicographicallyPrecedes($1) } }
    public func diagnose(_ coordinates: [Int], eligibleTargets: [[Int]]) throws -> AshValidityEvidence {
        let orbit = try self.orbit(of: coordinates)
        let known = context.knownValidStates.recognizedStates.map(\.coordinates)
        let reachable = known.filter { orbit.contains($0) }
        let status: AeostaraContract.AdmissibilityResult.StatusValue = known.contains(coordinates) ? .VALID : (reachable.isEmpty ? .TRANSFORMATION_INCOMPATIBLE : .TRANSFORMATION_COMPATIBLE)
        let normalization: AeostaraContract.StateValidityDiagnostic.NormalizationStatusValue = status == .VALID ? .ALREADY_VALID : (status == .TRANSFORMATION_COMPATIBLE ? .NORMALIZABLE : .NOT_NORMALIZABLE)
        var proof: SpecificCorrectionProof?
        for definition in context.transitions.definitions.sorted(by: { $0.transitionID.utf8.lexicographicallyPrecedes($1.transitionID.utf8) }) {
            guard definition.codewordReference.hasPrefix("ASH-CANONICAL-C/") else { throw SemanticInputFault.malformedEvidence }
            let text = String(definition.codewordReference.dropFirst("ASH-CANONICAL-C/".count))
            guard let codeword = Self.canonicalCodewords.first(where: { $0.map(String.init).joined() == text }) else { throw SemanticInputFault.malformedEvidence }
            let target = try Self.xor(coordinates, codeword)
            guard reachable.contains(target), eligibleTargets.contains(target) else { continue }
            var applicable = true
            for condition in definition.preconditions where applicable { applicable = try context.predicates.evaluate(condition, observed: coordinates, target: target) }
            if applicable { proof = SpecificCorrectionProof(transitionID: definition.transitionID, inputState: coordinates, codeword: codeword, targetState: target); break }
        }
        let fallback = try eligibleFallbacks(for: coordinates, eligibleTargets: eligibleTargets)
        return AshValidityEvidence(inputState: coordinates, admissibility: status, normalization: normalization, orbit: orbit,
                                   recognizedInOrbit: reachable, knownCorrection: proof, fallbackAvailable: !fallback.isEmpty)
    }
    func diagnosticEvidence(_ value: AshValidityEvidence,state: AeostaraContract.AshState) -> JSONValue {
        let compatibility = value.admissibility == .TRANSFORMATION_INCOMPATIBLE ? "INCOMPATIBLE" : (value.admissibility == .UNCLASSIFIED ? "UNKNOWN" : "COMPATIBLE")
        let relevance = value.normalization == .ALREADY_VALID ? "NO_RECOVERY_NEEDED" : (value.normalization == .NORMALIZABLE ? "RECOVERY_APPLICABLE" : (value.normalization == .NOT_NORMALIZABLE ? "NOT_RECOVERABLE" : "CONTAINMENT_NEEDED"))
        let notes = ["Admissibility computed against explicit recognized-state context",value.knownCorrection == nil ? "No registered applicable correction path is known" : "Registered preconditions establish a specific correction path"]
        let orbit = JSONValue.object([JSONMember("states",.array(value.orbit.map{.array($0.map{.number(.integer(String($0)))})})),JSONMember("size",.number(.integer(String(value.orbit.count)))),JSONMember("recognized_states",.array(value.recognizedInOrbit.map{.array($0.map{.number(.integer(String($0)))})}))])
        let proof = value.knownCorrection.map { proof in JSONValue.object([JSONMember("transition_id",.string(proof.transitionID)),JSONMember("codeword",.array(proof.codeword.map{.number(.integer(String($0)))})),JSONMember("target",.array(proof.targetState.map{.number(.integer(String($0)))}))]) } ?? .null
        return .object([JSONMember("state",state.jsonValue),JSONMember("input_state",.array(state.coordinates.map{.number(.integer(String($0)))})),JSONMember("admissibility_status",.string(value.admissibility.rawValue)),JSONMember("transformation_compatibility",.string(compatibility)),JSONMember("normalization_status",.string(value.normalization.rawValue)),JSONMember("recoverability_relevance",.string(relevance)),JSONMember("is_valid",.bool(value.admissibility == .VALID && value.normalization == .ALREADY_VALID)),JSONMember("orbit_info",orbit),JSONMember("known_correction",proof),JSONMember("fallback_available",.bool(value.fallbackAvailable)),JSONMember("rule_ids",.array([.string("ASH-STATE-VALIDITY-001"),.string("ASH-ADMISSIBILITY-CLASSIFICATION-001")])),JSONMember("notes",.array(notes.map(JSONValue.string)))])
    }
    public func classify(_ diagnostic: AshValidityEvidence) -> AeostaraContract.SystemStateClass {
        if diagnostic.admissibility == .VALID && diagnostic.normalization == .ALREADY_VALID { return .STABLE }
        if diagnostic.admissibility == .TRANSFORMATION_COMPATIBLE && diagnostic.normalization == .NORMALIZABLE { return diagnostic.knownCorrection == nil ? .UNSTABLE : .CORRECTABLE }
        if diagnostic.admissibility == .TRANSFORMATION_INCOMPATIBLE { return diagnostic.fallbackAvailable ? .DEGRADED : .FAILED }
        return .DEGRADED
    }
    public func recoveryCategory(for stateClass: AeostaraContract.SystemStateClass) -> AeostaraContract.RecoveryCategory {
        switch stateClass {
        case .STABLE: return .NO_ACTION
        case .UNSTABLE: return .NORMALIZE_STATE
        case .CORRECTABLE: return .APPLY_CORRECTION
        case .DEGRADED: return .FALLBACK_REQUIRED
        case .CONTAINED: return .CONTAINMENT_REQUIRED
        case .FAILED: return .ESCALATION_REQUIRED
        case .SAFE_HALT: return .TERMINAL_NO_RECOVERY
        }
    }
    public func eligibleFallbacks(for coordinates: [Int], eligibleTargets: [[Int]]) throws -> [(FallbackPolicy, AeostaraContract.AshState)] {
        var results: [(FallbackPolicy, AeostaraContract.AshState)] = []
        for policy in context.fallbackPolicies.entries {
            guard let target = context.knownValidStates.recognizedStates.first(where: { $0.stateID.utf8.elementsEqual(policy.candidateStateReference.utf8) }), eligibleTargets.contains(target.coordinates) else { continue }
            var matches = true
            for predicate in policy.applicabilityConditions where matches { matches = try context.predicates.evaluate(predicate, observed: coordinates, target: target.coordinates) }
            guard matches else { continue }
            for predicate in policy.validationRequirements where matches { matches = try context.predicates.evaluate(predicate, observed: coordinates, target: target.coordinates) }
            if matches { results.append((policy, target)) }
        }
        return results
    }
    public func canonicalCodewordSet() throws -> AeostaraContract.CanonicalCodewordSet {
        let array = JSONValue.array(Self.canonicalCodewords.map { .array($0.map { .number(.integer(String($0))) }) })
        return try AeostaraContract.CanonicalCodewordSet(codewordSetID: "ASH-CANONICAL-C", codewords: Self.canonicalCodewords, sourceReference: Self.authorityReference, canonicalHash: CanonicalJSON.hash(array))
    }
    public func resolveRealmIdentity(state: AeostaraContract.AshState, diagnostic: AeostaraContract.DiagnosticReference) throws -> AeostaraContract.RealmIdentity {
        guard context.knownValidStates.recognizedStates.contains(where: { $0.coordinates == state.coordinates }) else { throw SemanticInputFault.malformedEvidence }
        _ = try diagnosticRegistry().resolve(diagnostic)
        let encoding = "ASH9:" + state.coordinates.map(String.init).joined()
        return try AeostaraContract.RealmIdentity(realmID: encoding, stateReference: state.stateID, encoding: encoding, diagnosticReference: diagnostic)
    }
}
