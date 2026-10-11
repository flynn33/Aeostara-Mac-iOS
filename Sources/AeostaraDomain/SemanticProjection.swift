import Foundation

public struct JSONSnapshot {
    public let document: JSONValue
    public let reference: AeostaraContract.JsonDocumentReference
    public init(document: JSONValue, reference: AeostaraContract.JsonDocumentReference) throws {
        guard try CanonicalJSON.hash(document) == reference.canonicalHash else { throw CanonicalJSONError.invalidContract("document hash") }
        self.document = document; self.reference = reference
    }
}

public struct PointerObservation {
    public let pointer: JSONPointer
    public let value: JSONValue?
    public init(pointer: JSONPointer, value: JSONValue?) { self.pointer = pointer; self.value = value }
}

public struct MutationDraft {
    public let op: AeostaraContract.JsonMutationOperation.OpValue
    public let path: JSONPointer
    public let value: JSONValue?
    public init(op: AeostaraContract.JsonMutationOperation.OpValue, path: JSONPointer, value: JSONValue? = nil) {
        self.op = op; self.path = path; self.value = value
    }
}

public protocol SemanticMappingRule {
    var identifier: String { get }
    func candidates(binding: AeostaraContract.SemanticDimensionBinding, evidence: [PointerObservation], desired: JSONSnapshot) throws -> [Int]
    func materialize(binding: AeostaraContract.SemanticDimensionBinding, targetBit: Int, observed: JSONSnapshot, desired: JSONSnapshot) throws -> [MutationDraft]
}

/// An explicitly registered application rule. It receives no I/O or lifecycle authorization capability.
public struct RegisteredMappingRule: SemanticMappingRule {
    public let identifier: String
    private let projection: (AeostaraContract.SemanticDimensionBinding, [PointerObservation], JSONSnapshot) throws -> [Int]
    private let inverse: ((AeostaraContract.SemanticDimensionBinding, Int, JSONSnapshot, JSONSnapshot) throws -> [MutationDraft])?
    public init(identifier: String,
                candidates: @escaping (AeostaraContract.SemanticDimensionBinding, [PointerObservation], JSONSnapshot) throws -> [Int],
                materialize: ((AeostaraContract.SemanticDimensionBinding, Int, JSONSnapshot, JSONSnapshot) throws -> [MutationDraft])? = nil) {
        self.identifier = identifier; projection = candidates; inverse = materialize
    }
    public func candidates(binding: AeostaraContract.SemanticDimensionBinding, evidence: [PointerObservation], desired: JSONSnapshot) throws -> [Int] {
        try projection(binding, evidence, desired)
    }
    public func materialize(binding: AeostaraContract.SemanticDimensionBinding, targetBit: Int, observed: JSONSnapshot, desired: JSONSnapshot) throws -> [MutationDraft] {
        guard let inverse else { throw SemanticInputFault.missingMaterialization }
        return try inverse(binding, targetBit, observed, desired)
    }
}

public struct MappingRuleRegistry {
    private let entries: [any SemanticMappingRule]
    public init(_ entries: [any SemanticMappingRule]) throws {
        let names = entries.map { Data($0.identifier.utf8) }
        guard Set(names).count == entries.count, names.allSatisfy({ !$0.isEmpty }) else { throw CanonicalJSONError.invalidContract("mapping registry") }
        self.entries = entries
    }
    public func resolve(_ identifier: String) throws -> any SemanticMappingRule {
        guard let entry = entries.first(where: { $0.identifier.utf8.elementsEqual(identifier.utf8) }) else { throw SemanticInputFault.unknownMappingRule }
        return entry
    }
}

public struct KnownValidStateContext {
    public let applicationScopeID: String
    public let recognizedStates: [AeostaraContract.AshState]
    public let sourceReferences: [String]
    public let contextHash: String
    public init(applicationScopeID: String, recognizedStates: [AeostaraContract.AshState], sourceReferences: [String]) throws {
        guard !applicationScopeID.isEmpty, !recognizedStates.isEmpty, !sourceReferences.isEmpty,
              Set(recognizedStates.map { $0.coordinates }).count == recognizedStates.count else { throw CanonicalJSONError.invalidContract("recognized states") }
        for state in recognizedStates {
            guard try CanonicalJSON.hash(.array(state.coordinates.map { .number(.integer(String($0))) })) == state.canonicalHash else { throw CanonicalJSONError.invalidContract("state hash") }
        }
        self.applicationScopeID = applicationScopeID; self.recognizedStates = recognizedStates; self.sourceReferences = sourceReferences
        contextHash = try CanonicalJSON.hash(.object([JSONMember("scope", .string(applicationScopeID)), JSONMember("recognizedStates", .array(recognizedStates.map(\.jsonValue)))]))
    }
}

public struct IntentConstraintSet {
    public let applicationScopeID: String
    public let pointers: [JSONPointer]
    public let sourceReferences: [String]
    public init(applicationScopeID: String, pointers: [JSONPointer], sourceReferences: [String]) throws {
        guard !applicationScopeID.isEmpty, !pointers.isEmpty, !sourceReferences.isEmpty,
              Set(pointers.map { Data($0.text.utf8) }).count == pointers.count else { throw CanonicalJSONError.invalidContract("intent constraints") }
        self.applicationScopeID = applicationScopeID; self.pointers = pointers; self.sourceReferences = sourceReferences
    }
}

public struct RegisteredStatePredicate {
    public let identifier: String
    public let sourceReferences: [String]
    private let evaluateValue: ([Int], [Int]) throws -> Bool
    public init(identifier: String, sourceReferences: [String], evaluate: @escaping ([Int], [Int]) throws -> Bool) throws {
        guard !identifier.isEmpty, !sourceReferences.isEmpty else { throw CanonicalJSONError.invalidContract("predicate evidence") }
        self.identifier = identifier; self.sourceReferences = sourceReferences; evaluateValue = evaluate
    }
    public func evaluate(observed: [Int], target: [Int]) throws -> Bool { try evaluateValue(observed, target) }
}

public struct PredicateRuleRegistry {
    private let entries: [RegisteredStatePredicate]
    public init(_ entries: [RegisteredStatePredicate]) throws {
        guard Set(entries.map { Data($0.identifier.utf8) }).count == entries.count else { throw CanonicalJSONError.invalidContract("predicate registry") }; self.entries = entries
    }
    public func evaluate(_ identifier: String, observed: [Int], target: [Int]) throws -> Bool {
        guard let entry = entries.first(where: { $0.identifier.utf8.elementsEqual(identifier.utf8) }) else { throw SemanticInputFault.missingEvidence }
        return try entry.evaluate(observed: observed, target: target)
    }
}

public struct TransitionRegistry {
    public let definitions: [AeostaraContract.TransitionDefinition]
    public init(_ definitions: [AeostaraContract.TransitionDefinition]) throws {
        guard Set(definitions.map { Data($0.transitionID.utf8) }).count == definitions.count else { throw CanonicalJSONError.invalidContract("transition registry") }; self.definitions = definitions
    }
}

public struct FallbackPolicy {
    public enum Escalation: String { case TRY_NEXT, ESCALATE_TO_CONTAINMENT }
    public let policyID: String
    public let applicabilityConditions: [String]
    public let candidateStateReference: String
    public let orderingRank: Int
    public let validationRequirements: [String]
    public let escalationOnFailure: Escalation
    public let sourceReferences: [String]
    public init(policyID: String, applicabilityConditions: [String], candidateStateReference: String, orderingRank: Int,
                validationRequirements: [String], escalationOnFailure: Escalation, sourceReferences: [String]) throws {
        guard policyID.range(of: "^FALLBACK-[A-Z]+-[0-9]{3}$", options: .regularExpression) != nil,
              !applicabilityConditions.isEmpty, !validationRequirements.isEmpty, !sourceReferences.isEmpty else { throw CanonicalJSONError.invalidContract("fallback policy") }
        self.policyID = policyID; self.applicabilityConditions = applicabilityConditions; self.candidateStateReference = candidateStateReference
        self.orderingRank = orderingRank; self.validationRequirements = validationRequirements; self.escalationOnFailure = escalationOnFailure; self.sourceReferences = sourceReferences
    }
}
public struct FallbackPolicyRegistry {
    public let entries: [FallbackPolicy]
    public init(_ entries: [FallbackPolicy]) throws {
        guard Set(entries.map { Data($0.policyID.utf8) }).count == entries.count else { throw CanonicalJSONError.invalidContract("fallback registry") }
        self.entries = entries.sorted { $0.orderingRank == $1.orderingRank ? $0.policyID.utf8.lexicographicallyPrecedes($1.policyID.utf8) : $0.orderingRank < $1.orderingRank }
    }
}

public struct SemanticContext {
    public let applicationScopeID: String
    public let projectionSpec: AeostaraContract.SemanticProjectionSpec
    public let intentConstraints: IntentConstraintSet
    public let knownValidStates: KnownValidStateContext
    public let mappingRules: MappingRuleRegistry
    public let transitions: TransitionRegistry
    public let predicates: PredicateRuleRegistry
    public let fallbackPolicies: FallbackPolicyRegistry
    public let inputDiagnosticChains: [AeostaraContract.DiagnosticChain]
    public init(applicationScopeID: String, projectionSpec: AeostaraContract.SemanticProjectionSpec,
                intentConstraints: IntentConstraintSet, knownValidStates: KnownValidStateContext,
                mappingRules: MappingRuleRegistry, transitions: TransitionRegistry,
                predicates: PredicateRuleRegistry, fallbackPolicies: FallbackPolicyRegistry, inputDiagnosticChains: [AeostaraContract.DiagnosticChain] = []) throws {
        guard applicationScopeID == knownValidStates.applicationScopeID, applicationScopeID == intentConstraints.applicationScopeID,
              projectionSpec.dimensions.map({ $0.dimensionID.rawValue }) == (0..<9).map({ "b\($0)" }) else { throw CanonicalJSONError.invalidContract("semantic scope/dimensions") }
        var roots = Set<Data>()
        for chain in inputDiagnosticChains {
            guard roots.insert(Data(chain.rootDiagnosticID.utf8)).inserted,chain.diagnostics.first?.diagnosticID == chain.rootDiagnosticID else { throw SemanticInputFault.malformedEvidence }
            var earlier = Set<Data>()
            for (index,envelope) in chain.diagnostics.enumerated() {
                guard envelope.chainRootReference == chain.rootDiagnosticID,earlier.insert(Data(envelope.diagnosticID.utf8)).inserted,
                      index == 0 ? envelope.parentDiagnosticID == nil : envelope.parentDiagnosticID.map({earlier.contains(Data($0.utf8)) && $0 != envelope.diagnosticID}) == true else { throw SemanticInputFault.malformedEvidence }
                for rule in envelope.ruleReferences { guard try NativeAshBindingProvider.source(for:rule.ruleID) == rule.sourceReference else { throw SemanticInputFault.malformedEvidence } }
            }
        }
        self.inputDiagnosticChains = inputDiagnosticChains
        for binding in projectionSpec.dimensions { try Self.validate(reference:binding.diagnosticReference,in:inputDiagnosticChains) }
        self.applicationScopeID = applicationScopeID; self.projectionSpec = projectionSpec; self.intentConstraints = intentConstraints
        self.knownValidStates = knownValidStates; self.mappingRules = mappingRules; self.transitions = transitions; self.predicates = predicates; self.fallbackPolicies = fallbackPolicies
    }
    static func validate(reference: AeostaraContract.DiagnosticReference,in chains: [AeostaraContract.DiagnosticChain]) throws {
        guard let chain = chains.first(where:{$0.rootDiagnosticID == reference.chainRootReference}),
              let envelope = chain.diagnostics.first(where:{$0.diagnosticID == reference.diagnosticID}),
              envelope.diagnosticKind.rawValue == reference.diagnosticKind.rawValue,envelope.ruleReferences == reference.ruleReferences else { throw SemanticInputFault.missingEvidence }
    }

}

/// Immutable provenance snapshot for references crossing the public ASH boundary.
public struct NativeDiagnosticRegistry {
    public let chains: [AeostaraContract.DiagnosticChain]
    public init(chains: [AeostaraContract.DiagnosticChain]) throws {
        var accepted: [AeostaraContract.DiagnosticChain] = [], identifiers = Set<Data>()
        for chain in chains {
            if let same = accepted.first(where:{$0.rootDiagnosticID.utf8.elementsEqual(chain.rootDiagnosticID.utf8)}) {
                guard same == chain else { throw SemanticInputFault.malformedEvidence };continue
            }
            guard chain.diagnostics.first?.diagnosticID.utf8.elementsEqual(chain.rootDiagnosticID.utf8) == true else { throw SemanticInputFault.malformedEvidence }
            var earlier = Set<Data>()
            for (index,envelope) in chain.diagnostics.enumerated() {
                let identity = Data(envelope.diagnosticID.utf8)
                guard envelope.chainRootReference.utf8.elementsEqual(chain.rootDiagnosticID.utf8), identifiers.insert(identity).inserted,
                      index == 0 ? envelope.parentDiagnosticID == nil : envelope.parentDiagnosticID.map({earlier.contains(Data($0.utf8))}) == true else { throw SemanticInputFault.malformedEvidence }
                for rule in envelope.ruleReferences {
                    guard try NativeAshBindingProvider.source(for:rule.ruleID).utf8.elementsEqual(rule.sourceReference.utf8) else { throw SemanticInputFault.malformedEvidence }
                }
                earlier.insert(identity)
            }
            accepted.append(chain)
        }
        self.chains = accepted
    }
    public func resolve(_ reference: AeostaraContract.DiagnosticReference) throws -> AeostaraContract.DiagnosticEnvelope {
        let chain = try self.chain(for:reference)
        guard let envelope = chain.diagnostics.first(where:{$0.diagnosticID.utf8.elementsEqual(reference.diagnosticID.utf8)}),
              envelope.diagnosticKind.rawValue == reference.diagnosticKind.rawValue, envelope.ruleReferences == reference.ruleReferences else { throw SemanticInputFault.missingEvidence }
        return envelope
    }
    public func chain(for reference: AeostaraContract.DiagnosticReference) throws -> AeostaraContract.DiagnosticChain {
        guard let chain = chains.first(where:{$0.rootDiagnosticID.utf8.elementsEqual(reference.chainRootReference.utf8)}),
              chain.diagnostics.contains(where:{$0.diagnosticID.utf8.elementsEqual(reference.diagnosticID.utf8)}) else { throw SemanticInputFault.missingEvidence }
        return chain
    }
}

public enum SemanticInputFault: Error, Equatable {
    case unknownMappingRule, missingEvidence, ambiguousMapping([Int]), malformedEvidence, missingMaterialization, intentIncompatible
}

public extension AeostaraContract {
    protocol ISemanticProjector {
        func project(observedState: ObservedSystemState, desiredIntent: DesiredSystemIntent, projectionSpec: SemanticProjectionSpec) throws -> MappingResult
    }
}

public final class NativeSemanticProjector: AeostaraContract.ISemanticProjector {
    private let observed: JSONSnapshot
    private let desired: JSONSnapshot
    private let context: SemanticContext
    private let diagnostic: AeostaraContract.DiagnosticReference
    private let diagnosticChains: [AeostaraContract.DiagnosticChain]
    public init(observed: JSONSnapshot, desired: JSONSnapshot, context: SemanticContext, diagnostic: AeostaraContract.DiagnosticReference, diagnosticChains: [AeostaraContract.DiagnosticChain]? = nil) {
        self.observed = observed; self.desired = desired; self.context = context; self.diagnostic = diagnostic;self.diagnosticChains = diagnosticChains ?? context.inputDiagnosticChains
    }
    public func project(observedState: AeostaraContract.ObservedSystemState, desiredIntent: AeostaraContract.DesiredSystemIntent,
                        projectionSpec: AeostaraContract.SemanticProjectionSpec) throws -> AeostaraContract.MappingResult {
        do { return try projectNative(observedState:observedState,desiredIntent:desiredIntent,projectionSpec:projectionSpec) }
        catch {
            let code: LifecycleFaultCode
            if let fault = error as? SemanticInputFault {
                switch fault { case .unknownMappingRule:code = .unknownMappingRule;case .missingEvidence:code = .missingEvidence;case .ambiguousMapping:code = .ambiguousMapping;case .missingMaterialization:code = .missingMaterialization;case .intentIncompatible:code = .intentIncompatible;case .malformedEvidence:code = .malformedContract }
            } else { code = .malformedContract }
            throw try SemanticLedger(identity:context.knownValidStates.contextHash,time:"1970-01-01T00:00:00Z").failure(code)
        }
    }
    private func projectNative(observedState: AeostaraContract.ObservedSystemState,desiredIntent: AeostaraContract.DesiredSystemIntent,projectionSpec: AeostaraContract.SemanticProjectionSpec) throws -> AeostaraContract.MappingResult {
        try SemanticContext.validate(reference:diagnostic,in:diagnosticChains)
        try SemanticContext.validate(reference:observedState.diagnosticReference,in:diagnosticChains)
        try SemanticContext.validate(reference:desiredIntent.diagnosticReference,in:diagnosticChains)
        for difference in observedState.surfaceDifferences { try SemanticContext.validate(reference:difference.diagnosticReference,in:diagnosticChains) }
        guard try ContractCoding.canonicalEncode(observedState.documentReference) == ContractCoding.canonicalEncode(observed.reference),
              try ContractCoding.canonicalEncode(desiredIntent.documentReference) == ContractCoding.canonicalEncode(desired.reference),
              try ContractCoding.canonicalEncode(projectionSpec) == ContractCoding.canonicalEncode(context.projectionSpec) else { throw SemanticInputFault.malformedEvidence }
        let differences = try Self.surfaceDifferences(observed: observed, desired: desired, diagnostic: diagnostic)
        func signature(_ values: [AeostaraContract.SurfaceDifference]) -> JSONValue {
            .array(values.map { .object([JSONMember("path", $0.path.jsonValue), JSONMember("kind", .string($0.differenceKind.rawValue)), JSONMember("observedHash", .string($0.observedDocument.canonicalHash)), JSONMember("desiredHash", .string($0.desiredDocument.canonicalHash))]) })
        }
        guard try CanonicalJSON.encode(signature(differences)) == CanonicalJSON.encode(signature(observedState.surfaceDifferences)) else { throw SemanticInputFault.malformedEvidence }
        var coordinates: [Int] = []
        for binding in projectionSpec.dimensions {
            let rule = try context.mappingRules.resolve(binding.mappingRule)
            let evidence = try binding.sourcePointers.map { pointer -> PointerObservation in
                let parsed = try JSONPointer(pointer.pointer)
                guard parsed.tokens.map({ Data($0.utf8) }) == pointer.tokens.map({ Data($0.utf8) }) else { throw SemanticInputFault.malformedEvidence }
                let value = parsed.resolve(in: observed.document)
                guard pointer.pointsToMissing == (value == nil), pointer.pointsToNull == (value == .null) else { throw SemanticInputFault.malformedEvidence }
                guard value != nil else { throw SemanticInputFault.missingEvidence }
                return PointerObservation(pointer: parsed, value: value)
            }
            let candidates = try rule.candidates(binding: binding, evidence: evidence, desired: desired)
            guard !candidates.isEmpty else { throw SemanticInputFault.missingEvidence }
            guard candidates.allSatisfy({ $0 == 0 || $0 == 1 }) else { throw SemanticInputFault.malformedEvidence }
            let distinct = Array(Set(candidates)).sorted()
            guard distinct.count == 1 else { throw SemanticInputFault.ambiguousMapping(distinct) }; coordinates.append(distinct[0])
        }
        let hash = try CanonicalJSON.hash(.array(coordinates.map { .number(.integer(String($0))) }))
        let state = try AeostaraContract.AshState(stateID: "state-" + hash, coordinates: coordinates, sourceReference: projectionSpec.projectionSpecID, canonicalHash: hash)
        return try AeostaraContract.MappingResult(mappingResultID: "mapping-" + hash, status: .MAPPED, projectedState: state,
                                                  dimensionBindings: projectionSpec.dimensions, ambiguities: [], diagnosticReferences: [diagnostic])
    }

    public static func surfaceDifferences(observed: JSONSnapshot, desired: JSONSnapshot, diagnostic: AeostaraContract.DiagnosticReference) throws -> [AeostaraContract.SurfaceDifference] {
        typealias Difference = (JSONPointer, AeostaraContract.SurfaceDifference.DifferenceKindValue, JSONValue?)
        func compare(_ a: JSONValue?, _ b: JSONValue?, _ tokens: [String]) -> [Difference] {
            if a == b { return [] }
            if a == nil { return [(JSONPointer(tokens: tokens), .MISSING, nil)] }
            if b == nil { return [(JSONPointer(tokens: tokens), .REMOVED, a)] }
            if let aa = a?.objectMembers, let bb = b?.objectMembers {
                let keys = Set((aa + bb).map { Data($0.name.utf8) }).sorted { $0.lexicographicallyPrecedes($1) }
                return keys.flatMap { bytes -> [Difference] in
                    let key = String(decoding: bytes, as: UTF8.self)
                    return compare(a?.member(key), b?.member(key), tokens + [key])
                }
            }
            let kind: AeostaraContract.SurfaceDifference.DifferenceKindValue
            switch (a!, b!) {
            case (.array, .array): kind = .ARRAY_CHANGED
            case (.bool, .bool), (.number, .number), (.string, .string), (.null, .null): kind = .REPLACED
            default: kind = .TYPE_CHANGED
            }
            return [(JSONPointer(tokens: tokens), kind, a)]
        }
        return try compare(observed.document, desired.document, []).map { path, kind, value in
            let pointer = try AeostaraContract.JsonPointer(pointer: path.text, tokens: path.tokens, pointsToMissing: value == nil, pointsToNull: value == .null)
            let identity = try CanonicalJSON.hash(.object([JSONMember("path", .string(path.text)), JSONMember("kind", .string(kind.rawValue)), JSONMember("observed", .string(observed.reference.canonicalHash)), JSONMember("desired", .string(desired.reference.canonicalHash))]))
            return try AeostaraContract.SurfaceDifference(differenceID: "difference-" + identity, path: pointer, differenceKind: kind, observedDocument: observed.reference, desiredDocument: desired.reference, diagnosticReference: diagnostic)
        }
    }
}
