import Foundation

public struct JSONSnapshot {
    public let documentID: String
    public let sourceReference: String
    public let value: JSONValue
    public let canonicalHash: String
    public init(documentID: String, sourceReference: String, data: Data) throws {
        self.documentID = documentID; self.sourceReference = sourceReference
        value = try JSONValue.parse(data); canonicalHash = try value.canonicalHash()
    }
    public func reference(role: AeostaraContract.JsonDocumentReference.Role) throws -> AeostaraContract.JsonDocumentReference {
        try .init(documentID: documentID, role: role, canonicalHash: canonicalHash, sourceReference: sourceReference)
    }
}

public struct PointerObservation {
    public let pointer: String
    public let value: JSONValue?
    public init(pointer: String, value: JSONValue?) { self.pointer = pointer; self.value = value }
}
public struct MutationDraft {
    public let op: AeostaraContract.JsonMutationOperation.Op
    public let pointer: String
    public let value: JSONValue?
    public init(op: AeostaraContract.JsonMutationOperation.Op, pointer: String, value: JSONValue? = nil) {
        self.op = op; self.pointer = pointer; self.value = value
    }
}
public protocol SemanticMappingRule {
    var identifier: String { get }
    var sourceReference: String { get }
    func candidates(binding: AeostaraContract.SemanticDimensionBinding, evidence: [PointerObservation], desired: JSONSnapshot) throws -> [Int]
    func materialize(binding: AeostaraContract.SemanticDimensionBinding, targetBit: Int, observed: JSONSnapshot, desired: JSONSnapshot) throws -> [MutationDraft]
}

/// Explicitly registered application bool identity/consensus semantics; it supplies no ASH outcome.
public struct BooleanMappingRule: SemanticMappingRule {
    public let identifier: String
    public let sourceReference: String
    public init(identifier: String, sourceReference: String) { self.identifier = identifier; self.sourceReference = sourceReference }
    public func candidates(binding: AeostaraContract.SemanticDimensionBinding, evidence: [PointerObservation], desired: JSONSnapshot) throws -> [Int] {
        try evidence.map { item in
            guard let value = item.value else { throw ProjectionProblem.missingEvidence }
            guard case .bool(let bit) = value else { throw ProjectionProblem.malformedEvidence }
            return bit ? 1 : 0
        }
    }
    public func materialize(binding: AeostaraContract.SemanticDimensionBinding, targetBit: Int, observed: JSONSnapshot, desired: JSONSnapshot) throws -> [MutationDraft] {
        guard [0, 1].contains(targetBit) else { throw ProjectionProblem.malformedEvidence }
        return try binding.sourcePointers.compactMap { pointer in
            let old = try observed.value.resolve(pointer: pointer.pointer)
            guard case .bool = old else { throw ProjectionProblem.missingEvidence }
            let target = JSONValue.bool(targetBit == 1)
            return old == target ? nil : MutationDraft(op: .replace, pointer: pointer.pointer, value: target)
        }
    }
}
public struct ProjectionAmbiguity: Error {
    public let dimensionID: AeostaraContract.SemanticDimensionBinding.DimensionID
    public let candidateValues: [Int]
    public let evidence: [JSONValue]
}
public enum ProjectionProblem: Error { case missingEvidence, malformedEvidence, ambiguousEvidence, unknownMappingRule, invalidContext, inconsistentSurfaceEvidence, intentIncompatible, missingMaterialization }

public struct IntentConstraintSet {
    public let scopeID: String
    public let pointers: [String]
    public let sourceReferences: [String]
    public init(scopeID: String, pointers: [String], sourceReferences: [String]) throws {
        guard !scopeID.isEmpty, !pointers.isEmpty, !sourceReferences.isEmpty else { throw ProjectionProblem.invalidContext }
        let keys = pointers.map { Array($0.utf8) }
        guard Set(keys).count == keys.count else { throw ProjectionProblem.invalidContext }
        for pointer in pointers { _ = try JSONValue.pointerTokens(pointer) }
        self.scopeID = scopeID; self.pointers = pointers; self.sourceReferences = sourceReferences
    }
}
public struct KnownValidStateContext {
    public let scopeID: String
    public let states: [[Int]]
    public let sourceReferences: [String]
    public init(scopeID: String, states: [[Int]], sourceReferences: [String]) throws {
        guard !scopeID.isEmpty, !states.isEmpty, !sourceReferences.isEmpty, Set(states).count == states.count else { throw ProjectionProblem.invalidContext }
        for state in states { try NativeAshBindingProvider.validate(state) }
        self.scopeID = scopeID; self.states = states; self.sourceReferences = sourceReferences
    }
}
public struct SemanticPredicate {
    public let identifier: String
    public let sourceReference: String
    private let evaluateBody: ([Int], [Int], JSONSnapshot, JSONSnapshot) throws -> Bool
    public init(identifier: String, sourceReference: String, evaluate: @escaping ([Int], [Int], JSONSnapshot, JSONSnapshot) throws -> Bool) {
        self.identifier = identifier; self.sourceReference = sourceReference; evaluateBody = evaluate
    }
    public func evaluate(input: [Int], target: [Int], observed: JSONSnapshot, desired: JSONSnapshot) throws -> Bool {
        try evaluateBody(input, target, observed, desired)
    }
}
public struct RegisteredTransition {
    public let definition: AeostaraContract.TransitionDefinition
    public let codeword: [Int]
    public init(definition: AeostaraContract.TransitionDefinition, codeword: [Int]) throws {
        try NativeAshBindingProvider.validate(codeword)
        guard NativeAshBindingProvider.codewords.contains(codeword), definition.codewordReference == "ASH-CANONICAL-C/" + codeword.map(String.init).joined() else { throw ProjectionProblem.invalidContext }
        self.definition = definition; self.codeword = codeword
    }
}
public struct NativeFallbackPolicy {
    public let policyID: String
    public let orderingRank: Int
    public let candidate: [Int]
    public let applicabilityPredicates: [String]
    public let validationPredicates: [String]
    public let sourceReferences: [String]
    public init(policyID: String, orderingRank: Int, candidate: [Int], applicabilityPredicates: [String], validationPredicates: [String], sourceReferences: [String]) throws {
        try NativeAshBindingProvider.validate(candidate)
        guard !policyID.isEmpty, !applicabilityPredicates.isEmpty, !validationPredicates.isEmpty, !sourceReferences.isEmpty else { throw ProjectionProblem.invalidContext }
        self.policyID = policyID; self.orderingRank = orderingRank; self.candidate = candidate
        self.applicabilityPredicates = applicabilityPredicates; self.validationPredicates = validationPredicates; self.sourceReferences = sourceReferences
    }
}
public struct SemanticContext {
    public let applicationScope: String
    public let projectionSpec: AeostaraContract.SemanticProjectionSpec
    public let intentConstraints: IntentConstraintSet
    public let knownValidStates: KnownValidStateContext
    public let mappingRules: [any SemanticMappingRule]
    public let transitions: [RegisteredTransition]
    public let fallbackPolicies: [NativeFallbackPolicy]
    public let predicates: [SemanticPredicate]
    public let inputDiagnosticChains: [AeostaraContract.DiagnosticChain]
    public let identity: String
    public init(applicationScope: String, projectionSpec: AeostaraContract.SemanticProjectionSpec, intentConstraints: IntentConstraintSet, knownValidStates: KnownValidStateContext, mappingRules: [any SemanticMappingRule], transitions: [RegisteredTransition] = [], fallbackPolicies: [NativeFallbackPolicy] = [], predicates: [SemanticPredicate] = [], inputDiagnosticChains: [AeostaraContract.DiagnosticChain] = []) throws {
        guard applicationScope.utf8.elementsEqual(intentConstraints.scopeID.utf8), applicationScope.utf8.elementsEqual(knownValidStates.scopeID.utf8), !applicationScope.isEmpty else { throw ProjectionProblem.invalidContext }
        guard Set(projectionSpec.dimensions.map { $0.dimensionID.rawValue }) == Set((0..<9).map { "b\($0)" }) else { throw ProjectionProblem.invalidContext }
        for identifiers in [mappingRules.map(\.identifier), transitions.map { $0.definition.transitionID }, fallbackPolicies.map(\.policyID), predicates.map(\.identifier)] {
            guard Set(identifiers).count == identifiers.count, identifiers.allSatisfy({ $0.range(of: "^[A-Za-z0-9][A-Za-z0-9._/-]{0,127}$", options: .regularExpression) != nil }) else { throw ProjectionProblem.invalidContext }
        }
        guard mappingRules.allSatisfy({ !$0.sourceReference.isEmpty }), predicates.allSatisfy({ !$0.sourceReference.isEmpty }) else { throw ProjectionProblem.invalidContext }
        let bound = projectionSpec.dimensions.flatMap { $0.sourcePointers.map { Array($0.pointer.utf8) } }
        guard intentConstraints.pointers.allSatisfy({ bound.contains(Array($0.utf8)) }) else { throw ProjectionProblem.invalidContext }
        try NativeDiagnosticContext.validate(inputDiagnosticChains)
        for binding in projectionSpec.dimensions { try NativeDiagnosticContext.resolve(binding.diagnosticReference, in: inputDiagnosticChains) }
        self.inputDiagnosticChains = inputDiagnosticChains
        self.applicationScope = applicationScope; self.projectionSpec = projectionSpec; self.intentConstraints = intentConstraints; self.knownValidStates = knownValidStates
        self.mappingRules = mappingRules; self.transitions = transitions; self.fallbackPolicies = fallbackPolicies; self.predicates = predicates
        identity = try JSONValue.object([
            JSONMember("scope", .string(applicationScope)), JSONMember("projection", projectionSpec.contractJSON),
            JSONMember("inputDiagnostics", .array(inputDiagnosticChains.map(\.contractJSON))),
            JSONMember("knownValid", .array(knownValidStates.states.map { .array($0.map { .integer(String($0)) }) })),
            JSONMember("knownSources", .array(knownValidStates.sourceReferences.map(JSONValue.string))),
            JSONMember("intent", .array(intentConstraints.pointers.map(JSONValue.string))),
            JSONMember("intentSources", .array(intentConstraints.sourceReferences.map(JSONValue.string))),
            JSONMember("mappings", .array(mappingRules.map { .object([JSONMember("id", .string($0.identifier)), JSONMember("source", .string($0.sourceReference))]) })),
            JSONMember("transitions", .array(transitions.map { $0.definition.contractJSON })),
            JSONMember("fallbacks", .array(fallbackPolicies.map { .object([JSONMember("id", .string($0.policyID)), JSONMember("rank", .integer(String($0.orderingRank))), JSONMember("candidate", .array($0.candidate.map { .integer(String($0)) })), JSONMember("applicability", .array($0.applicabilityPredicates.map(JSONValue.string))), JSONMember("validation", .array($0.validationPredicates.map(JSONValue.string))), JSONMember("sources", .array($0.sourceReferences.map(JSONValue.string)))]) })),
            JSONMember("predicates", .array(predicates.map { .object([JSONMember("id", .string($0.identifier)), JSONMember("source", .string($0.sourceReference))]) }))
        ]).canonicalHash()
    }
    func mapping(_ id: String) throws -> any SemanticMappingRule {
        guard let rule = mappingRules.first(where: { $0.identifier.utf8.elementsEqual(id.utf8) }) else { throw ProjectionProblem.unknownMappingRule }; return rule
    }
    func predicatesPass(_ names: [String], input: [Int], target: [Int], observed: JSONSnapshot, desired: JSONSnapshot) throws -> Bool {
        for name in names {
            guard let predicate = predicates.first(where: { $0.identifier.utf8.elementsEqual(name.utf8) }) else { throw ProjectionProblem.invalidContext }
            if try !predicate.evaluate(input: input, target: target, observed: observed, desired: desired) { return false }
        }
        return true
    }
}

public final class NativeSemanticProjector: AeostaraContract.ISemanticProjector {
    public let context: SemanticContext
    private let observedSnapshot: JSONSnapshot?
    private let desiredSnapshot: JSONSnapshot?
    private let diagnosticLock = NSLock()
    private var emittedChains: [AeostaraContract.DiagnosticChain] = []
    public var diagnosticChains: [AeostaraContract.DiagnosticChain] { diagnosticLock.lock(); defer { diagnosticLock.unlock() }; return emittedChains }
    private func retain(_ trace: SemanticTrace) throws {
        let chain = try trace.chain(); diagnosticLock.lock(); defer { diagnosticLock.unlock() }
        if !emittedChains.contains(where: { $0.chainID == chain.chainID }) { emittedChains.append(chain) }
    }
    public init(context: SemanticContext, observed: JSONSnapshot? = nil, desired: JSONSnapshot? = nil) { self.context = context; observedSnapshot = observed; desiredSnapshot = desired }
    public func project(observedState: AeostaraContract.ObservedSystemState, desiredIntent: AeostaraContract.DesiredSystemIntent, projectionSpec: AeostaraContract.SemanticProjectionSpec) throws -> AeostaraContract.MappingResult {
        var trace = SemanticTrace(identity: try JSONValue.array([.string(context.identity), .string(observedState.documentReference.canonicalHash), .string(desiredIntent.documentReference.canonicalHash)]).canonicalHash())
        do {
            guard let observed = observedSnapshot, let desired = desiredSnapshot else { throw ProjectionProblem.missingEvidence }
            let engine = NativeHealingEngine(context: context, observed: observed, desired: desired)
            guard observedState == (try engine.observedState()), desiredIntent == (try engine.desiredIntent(partialIntent: desiredIntent.partialIntent)), projectionSpec == context.projectionSpec else { throw ProjectionProblem.invalidContext }
            _ = try trace.append(kind: .mapping, ruleID: "ASH-STATE-STRUCTURE-001", message: "Native observation provenance")
            _ = try trace.append(kind: .jsonSemantics, ruleID: "ASH-STATE-STRUCTURE-001", message: "Canonical snapshots and surface evidence established")
            let coordinates = try projectCoordinates(observed: observed, desired: desired)
            let reference = try trace.append(kind: .mapping, ruleID: "ASH-STATE-STRUCTURE-001", message: "All nine coordinates mapped from explicit evidence")
            let hash = try JSONValue.array(coordinates.map { .integer(String($0)) }).canonicalHash()
            let state = try AeostaraContract.AshState(stateID: "state-" + hash, coordinates: coordinates, sourceReference: NativeAshBindingProvider.sourceReference, canonicalHash: hash)
            try retain(trace)
            return try .init(mappingResultID: "mapping-" + hash, status: .mapped, projectedState: state, dimensionBindings: projectionSpec.dimensions, ambiguities: [], diagnosticReferences: [reference])
        } catch { let failure = try trace.failure(error, stage: .project); try retain(trace); throw failure }
    }
    public func projectCoordinates(observed: JSONSnapshot, desired: JSONSnapshot) throws -> [Int] {
        try projectCoordinates(observed: observed, desired: desired, validatePointerEvidence: true)
    }
    public func projectReobservedCoordinates(observed: JSONSnapshot, desired: JSONSnapshot) throws -> [Int] {
        try projectCoordinates(observed: observed, desired: desired, validatePointerEvidence: false)
    }
    func projectCoordinates(observed: JSONSnapshot, desired: JSONSnapshot, validatePointerEvidence: Bool) throws -> [Int] {
        try context.projectionSpec.dimensions.sorted { $0.dimensionID.rawValue < $1.dimensionID.rawValue }.map { binding in
            let evidence = try binding.sourcePointers.map { pointer -> PointerObservation in
                let tokens = try JSONValue.pointerTokens(pointer.pointer)
                guard tokens.count == pointer.tokens.count, zip(tokens, pointer.tokens).allSatisfy({ $0.utf8.elementsEqual($1.utf8) }) else { throw ProjectionProblem.malformedEvidence }
                let value = try observed.value.resolve(pointer: pointer.pointer)
                if validatePointerEvidence && (pointer.pointsToMissing != (value == nil) || pointer.pointsToNull != (value == .null)) { throw ProjectionProblem.malformedEvidence }
                return PointerObservation(pointer: pointer.pointer, value: value)
            }
            let candidates = try context.mapping(binding.mappingRule).candidates(binding: binding, evidence: evidence, desired: desired)
            guard !candidates.isEmpty, candidates.allSatisfy({ $0 == 0 || $0 == 1 }) else { throw ProjectionProblem.malformedEvidence }
            guard Set(candidates).count == 1 else { throw ProjectionAmbiguity(dimensionID: binding.dimensionID, candidateValues: candidates, evidence: evidence.map { .object([JSONMember("pointer", .string($0.pointer)), JSONMember("pointsToMissing", .bool($0.value == nil)), JSONMember("pointsToNull", .bool($0.value == .null))]) }) }
            return candidates[0]
        }
    }
}
