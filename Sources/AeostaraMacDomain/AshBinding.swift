import Foundation

public struct AshValidityEvidence {
    public let coordinates: [Int]
    public let admissibility: AeostaraContract.AdmissibilityResult.Status
    public let normalization: AeostaraContract.StateValidityDiagnostic.NormalizationStatus
    public let stateClass: AeostaraContract.SystemStateClass
    public let recoveryCategory: AeostaraContract.RecoveryCategory
    public let orbit: [[Int]]
    public let knownCorrection: RegisteredTransition?
    public let fallback: NativeFallbackPolicy?
}

public final class NativeAshBindingProvider: AeostaraContract.IAshBindingProvider {
    public static let sourceReference = "ASH-Pattern-System@e123f5d7fdbb381179971f721a3292c31eb1cbc2"
    public static let codewords: [[Int]] = [
        "000000000", "000011110", "001100110", "001111000", "010101010", "010110100", "011001100", "011010010",
        "100101100", "100110010", "101001010", "101010100", "110000110", "110011000", "111100000", "111111110"
    ].map { $0.map { $0 == "1" ? 1 : 0 } }
    let boundContext: SemanticContext?
    let boundObserved: JSONSnapshot?
    let boundDesired: JSONSnapshot?
    let axiomSubject: NativeAxiomSubject?
    let generationContext: NativeGenerationContext?
    let diagnosticLock = NSLock()
    var emittedChains: [AeostaraContract.DiagnosticChain] = []
    public init(context: SemanticContext? = nil, observed: JSONSnapshot? = nil, desired: JSONSnapshot? = nil,
                axiomSubject: NativeAxiomSubject? = nil, generationContext: NativeGenerationContext? = nil) {
        boundContext = context; boundObserved = observed; boundDesired = desired
        self.axiomSubject = axiomSubject; self.generationContext = generationContext
    }
    public static func validate(_ coordinates: [Int]) throws {
        guard coordinates.count == 9, coordinates.allSatisfy({ $0 == 0 || $0 == 1 }) else { throw ProjectionProblem.malformedEvidence }
    }
    public func transform(_ state: [Int], codeword: [Int]) throws -> [Int] {
        try Self.validate(state); try Self.validate(codeword)
        guard Self.codewords.contains(codeword) else { throw ProjectionProblem.invalidContext }
        return zip(state, codeword).map { $0 ^ $1 }
    }
    public func orbit(of state: [Int]) throws -> [[Int]] {
        try Self.validate(state)
        return try Self.codewords.map { try transform(state, codeword: $0) }.sorted { $0.lexicographicallyPrecedes($1) }
    }
    public func admissibility(of state: [Int], knownValid: KnownValidStateContext) throws -> AeostaraContract.AdmissibilityResult.Status {
        try Self.validate(state)
        if knownValid.states.contains(state) { return .valid }
        let states = try orbit(of: state)
        return knownValid.states.contains(where: { states.contains($0) }) ? .transformationCompatible : .transformationIncompatible
    }
    public func diagnose(state: [Int], context: SemanticContext, observed: JSONSnapshot, desired: JSONSnapshot) throws -> AshValidityEvidence {
        let admissibility = try self.admissibility(of: state, knownValid: context.knownValidStates)
        let normalization: AeostaraContract.StateValidityDiagnostic.NormalizationStatus
        switch admissibility {
        case .valid: normalization = .alreadyValid
        case .transformationCompatible: normalization = .normalizable
        case .transformationIncompatible: normalization = .notNormalizable
        case .unclassified: normalization = .blocked
        }
        var correction: RegisteredTransition?
        if admissibility == .transformationCompatible {
            for entry in context.transitions.sorted(by: { $0.definition.transitionID.utf8.lexicographicallyPrecedes($1.definition.transitionID.utf8) }) {
                let target = try transform(state, codeword: entry.codeword)
                if context.knownValidStates.states.contains(target), try intentMatches(target, context: context, desired: desired),
                   try context.predicatesPass(entry.definition.preconditions, input: state, target: target, observed: observed, desired: desired) {
                    correction = entry; break
                }
            }
        }
        var fallback: NativeFallbackPolicy?
        if admissibility == .transformationIncompatible {
            let sorted = context.fallbackPolicies.sorted {
                $0.orderingRank == $1.orderingRank ? $0.policyID.utf8.lexicographicallyPrecedes($1.policyID.utf8) : $0.orderingRank < $1.orderingRank
            }
            for entry in sorted {
                guard context.knownValidStates.states.contains(entry.candidate) else { throw ProjectionProblem.invalidContext }
                if try context.predicatesPass(entry.applicabilityPredicates, input: state, target: entry.candidate, observed: observed, desired: desired),
                   try context.predicatesPass(entry.validationPredicates, input: state, target: entry.candidate, observed: observed, desired: desired) {
                    fallback = entry; break
                }
            }
        }
        let classification = classify(admissibility: admissibility, normalization: normalization, knownCorrection: correction != nil, fallbackAvailable: fallback != nil)
        return AshValidityEvidence(coordinates: state, admissibility: admissibility, normalization: normalization, stateClass: classification,
            recoveryCategory: recoverability(classification), orbit: try orbit(of: state), knownCorrection: correction, fallback: fallback)
    }
    func classify(admissibility: AeostaraContract.AdmissibilityResult.Status, normalization: AeostaraContract.StateValidityDiagnostic.NormalizationStatus,
                         knownCorrection: Bool, fallbackAvailable: Bool, contained: Bool = false, safeHalt: Bool = false) -> AeostaraContract.SystemStateClass {
        if safeHalt { return .safeHalt }
        if contained { return .contained }
        if admissibility == .valid && normalization == .alreadyValid { return .stable }
        if admissibility == .transformationCompatible && normalization == .normalizable { return knownCorrection ? .correctable : .unstable }
        if admissibility == .transformationIncompatible { return fallbackAvailable ? .degraded : .failed }
        return .degraded
    }
    public func recoverability(_ stateClass: AeostaraContract.SystemStateClass) -> AeostaraContract.RecoveryCategory {
        switch stateClass {
        case .stable: return .noAction
        case .unstable: return .normalizeState
        case .correctable: return .applyCorrection
        case .degraded: return .fallbackRequired
        case .contained: return .containmentRequired
        case .failed: return .escalationRequired
        case .safeHalt: return .terminalNoRecovery
        }
    }
    public func intentMatches(_ target: [Int], context: SemanticContext, desired: JSONSnapshot) throws -> Bool {
        try Self.validate(target)
        for binding in context.projectionSpec.dimensions {
            let selected = binding.sourcePointers.filter { pointer in context.intentConstraints.pointers.contains { $0.utf8.elementsEqual(pointer.pointer.utf8) } }
            if selected.isEmpty { continue }
            let evidence = try selected.map { PointerObservation(pointer: $0.pointer, value: try desired.value.resolve(pointer: $0.pointer)) }
            let values = try context.mapping(binding.mappingRule).candidates(binding: binding, evidence: evidence, desired: desired)
            guard !values.isEmpty, values.allSatisfy({ $0 == 0 || $0 == 1 }), Set(values).count == 1 else { throw ProjectionProblem.ambiguousEvidence }
            let index = context.projectionSpec.dimensions.sorted { $0.dimensionID.rawValue < $1.dimensionID.rawValue }.firstIndex { $0.dimensionID == binding.dimensionID }!
            if target[index] != values[0] { return false }
        }
        return true
    }
    public func eligibleFallback(state: [Int], context: SemanticContext, observed: JSONSnapshot, desired: JSONSnapshot) throws -> NativeFallbackPolicy? {
        try Self.validate(state)
        let entries = context.fallbackPolicies.sorted {
            $0.orderingRank == $1.orderingRank ? $0.policyID.utf8.lexicographicallyPrecedes($1.policyID.utf8) : $0.orderingRank < $1.orderingRank
        }
        for entry in entries {
            guard context.knownValidStates.states.contains(entry.candidate) else { throw ProjectionProblem.invalidContext }
            if try context.predicatesPass(entry.applicabilityPredicates, input: state, target: entry.candidate, observed: observed, desired: desired),
               try context.predicatesPass(entry.validationPredicates, input: state, target: entry.candidate, observed: observed, desired: desired),
               try intentMatches(entry.candidate, context: context, desired: desired) { return entry }
        }
        return nil
    }
    func recoveryTarget(_ evidence: AshValidityEvidence, context: SemanticContext, observed: JSONSnapshot, desired: JSONSnapshot) throws -> [Int]? {
        switch evidence.recoveryCategory {
        case .noAction: return evidence.coordinates
        case .applyCorrection:
            guard let correction = evidence.knownCorrection else { throw ProjectionProblem.invalidContext }
            return try transform(evidence.coordinates, codeword: correction.codeword)
        case .normalizeState:
            let candidates = try context.knownValidStates.states.filter {
                guard evidence.orbit.contains($0) else { return false }
                return try intentMatches($0, context: context, desired: desired)
            }
            guard let target = candidates.sorted(by: { $0.lexicographicallyPrecedes($1) }).first else { throw ProjectionProblem.intentIncompatible }
            return target
        case .fallbackRequired: return evidence.fallback?.candidate
        case .containmentRequired, .escalationRequired, .terminalNoRecovery: return nil
        }
    }
}
