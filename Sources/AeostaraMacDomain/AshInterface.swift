import Foundation

/// Resolves immutable, caller-supplied provenance without treating a reference as evidence.
public enum NativeDiagnosticContext {
    public static func validate(_ chains: [AeostaraContract.DiagnosticChain]) throws {
        var all = Set<Data>()
        for chain in chains {
            guard chain.diagnostics.first?.diagnosticID.utf8.elementsEqual(chain.rootDiagnosticID.utf8) == true else { throw ProjectionProblem.invalidContext }
            var earlier = Set<Data>()
            for (index, envelope) in chain.diagnostics.enumerated() {
                guard !envelope.diagnosticID.isEmpty, all.insert(Data(envelope.diagnosticID.utf8)).inserted,
                      envelope.chainRootReference.utf8.elementsEqual(chain.rootDiagnosticID.utf8),
                      !envelope.sourceReferences.isEmpty, envelope.sourceReferences.allSatisfy({ !$0.isEmpty }),
                      !envelope.ruleReferences.isEmpty, envelope.ruleReferences.allSatisfy({ !$0.ruleID.isEmpty && !$0.sourceReference.isEmpty }),
                      index == 0 ? envelope.parentDiagnosticID == nil : envelope.parentDiagnosticID.map({ earlier.contains(Data($0.utf8)) }) == true else { throw ProjectionProblem.invalidContext }
                earlier.insert(Data(envelope.diagnosticID.utf8))
            }
        }
    }
    public static func resolve(_ reference: AeostaraContract.DiagnosticReference, in chains: [AeostaraContract.DiagnosticChain]) throws {
        guard let chain = chains.first(where: { $0.rootDiagnosticID.utf8.elementsEqual(reference.chainRootReference.utf8) }),
              let envelope = chain.diagnostics.first(where: { $0.diagnosticID.utf8.elementsEqual(reference.diagnosticID.utf8) }),
              envelope.diagnosticKind.rawValue == reference.diagnosticKind.rawValue, envelope.ruleReferences == reference.ruleReferences else { throw ProjectionProblem.invalidContext }
    }
}

extension AeostaraContract {
    public protocol IAshBindingProvider {
        func evaluateAdmissibility(state: AshState) throws -> AdmissibilityResult
        func diagnoseState(state: AshState) throws -> StateValidityDiagnostic
        func classifyState(diagnostic: StateValidityDiagnostic) throws -> SystemStateClass
        func applyCodewordTransformation(transformation: CodewordTransformation) throws -> TransitionResult
        func resolveRealmIdentity(state: AshState) throws -> RealmIdentity
        func resolveTransition(state: AshState, definition: TransitionDefinition) throws -> TransitionResult
        func generateTopology(state: AshState) throws -> TopologyPlan
        func evaluateAxioms(state: AshState) throws -> [AxiomDiagnostic]
        func generateMaterializationPlan(state: AshState) throws -> GenerationPlan
        func planArtifactEmission(plan: GenerationPlan) throws -> ArtifactEmissionPlan
    }
}

/// Actual subject measurements supplied by the application; the SDK derives all five checks.
public struct NativeAxiomSubject {
    public let relationCount: Int
    public let compressedMeasure: Double
    public let rawMeasure: Double
    public let scaleCount: Int
    public let erasureCost: Double
    public let selfReferenceCapable: Bool
    public let selfModelAvailable: Bool
    public let sourceReference: String
    public init(relationCount: Int, compressedMeasure: Double, rawMeasure: Double, scaleCount: Int,
                erasureCost: Double, selfReferenceCapable: Bool, selfModelAvailable: Bool, sourceReference: String) throws {
        guard relationCount >= 0, scaleCount >= 0, compressedMeasure >= 0, rawMeasure >= 0, erasureCost >= 0,
              compressedMeasure.isFinite, rawMeasure.isFinite, erasureCost.isFinite, !sourceReference.isEmpty else { throw ProjectionProblem.invalidContext }
        self.relationCount = relationCount; self.compressedMeasure = compressedMeasure; self.rawMeasure = rawMeasure
        self.scaleCount = scaleCount; self.erasureCost = erasureCost; self.selfReferenceCapable = selfReferenceCapable
        self.selfModelAvailable = selfModelAvailable; self.sourceReference = sourceReference
    }
    var evidence: JSONValue { .object([
        JSONMember("relationCount", .integer(String(relationCount))), JSONMember("compressedMeasure", .real(String(compressedMeasure))),
        JSONMember("rawMeasure", .real(String(rawMeasure))), JSONMember("scaleCount", .integer(String(scaleCount))),
        JSONMember("erasureCost", .real(String(erasureCost))), JSONMember("selfReferenceCapable", .bool(selfReferenceCapable)),
        JSONMember("selfModelAvailable", .bool(selfModelAvailable)), JSONMember("sourceReference", .string(sourceReference))]) }
    init(evidence: JSONValue) throws {
        let fields = try ContractFields(evidence, allowed: ["relationCount", "compressedMeasure", "rawMeasure", "scaleCount", "erasureCost", "selfReferenceCapable", "selfModelAvailable", "sourceReference"])
        func measure(_ name: String) throws -> Double {
            let token: String
            switch try fields.required(name) {
            case .integer(let value), .real(let value): token = value
            default: throw ProjectionProblem.invalidContext
            }
            guard let value = Double(token), value.isFinite else { throw ProjectionProblem.invalidContext }
            return value
        }
        try self.init(relationCount: ContractFields.integer(fields.required("relationCount")), compressedMeasure: measure("compressedMeasure"),
            rawMeasure: measure("rawMeasure"), scaleCount: ContractFields.integer(fields.required("scaleCount")), erasureCost: measure("erasureCost"),
            selfReferenceCapable: ContractFields.boolean(fields.required("selfReferenceCapable")), selfModelAvailable: ContractFields.boolean(fields.required("selfModelAvailable")),
            sourceReference: ContractFields.string(fields.required("sourceReference")))
    }
    var checks: [(String, Bool, String)] { [
        ("A1_RELATIONAL_EXISTENCE", relationCount > 0, "relationCount > 0"),
        ("A2_STRUCTURAL_COMPRESSIBILITY", compressedMeasure < rawMeasure, "compressedMeasure < rawMeasure"),
        ("A3_MULTI_SCALE_PERSISTENCE", scaleCount > 1, "scaleCount > 1"),
        ("A4_ERASURE_COST", erasureCost > 0, "erasureCost > 0"),
        ("A5_SELF_REFERENCE", selfReferenceCapable && selfModelAvailable, "selfReferenceCapable AND selfModelAvailable")
    ] }
}

/// Explicit immutable generation request and registered pure application profile/naming/emission rules.
/// Callbacks describe abstract records only; they must perform no I/O.
public struct NativeGenerationContext {
    public let projectName: String
    public let transitionSequence: [String]
    public let topologyDepth: Int
    public let profileID: String
    public let namingPolicyID: String
    public let emissionTargetKind: String
    public let sourceReferences: [String]
    let roleAssignment: ([JSONValue]) throws -> [JSONValue]
    let subjectBuilder: (AeostaraContract.AshState, [JSONValue], [JSONValue]) throws -> NativeAxiomSubject
    let artifactDescription: (String, [JSONValue]) throws -> [JSONValue]
    public init(projectName: String, transitionSequence: [String], topologyDepth: Int, profileID: String,
                namingPolicyID: String, emissionTargetKind: String, sourceReferences: [String],
                assignRoles: @escaping ([JSONValue]) throws -> [JSONValue],
                buildSubject: @escaping (AeostaraContract.AshState, [JSONValue], [JSONValue]) throws -> NativeAxiomSubject,
                describeArtifacts: @escaping (String, [JSONValue]) throws -> [JSONValue]) throws {
        guard !projectName.isEmpty, topologyDepth >= 0, topologyDepth <= 8, !profileID.isEmpty, !namingPolicyID.isEmpty,
              !emissionTargetKind.isEmpty, !sourceReferences.isEmpty, sourceReferences.allSatisfy({ !$0.isEmpty }) else { throw ProjectionProblem.invalidContext }
        self.projectName = projectName; self.transitionSequence = transitionSequence; self.topologyDepth = topologyDepth
        self.profileID = profileID; self.namingPolicyID = namingPolicyID; self.emissionTargetKind = emissionTargetKind
        self.sourceReferences = sourceReferences; roleAssignment = assignRoles; subjectBuilder = buildSubject; artifactDescription = describeArtifacts
    }
}

extension NativeAshBindingProvider {
    /// Chains emitted by these pure operations are retained as provenance, with deterministic identities.
    public var diagnosticChains: [AeostaraContract.DiagnosticChain] {
        diagnosticLock.lock(); defer { diagnosticLock.unlock() }; return emittedChains
    }
    func retain(_ trace: SemanticTrace) throws {
        let chain = try trace.chain()
        diagnosticLock.lock(); defer { diagnosticLock.unlock() }
        if !emittedChains.contains(where: { $0.chainID == chain.chainID }) { emittedChains.append(chain) }
    }
    func requireBound() throws -> (SemanticContext, JSONSnapshot, JSONSnapshot) {
        guard let context = boundContext, let observed = boundObserved, let desired = boundDesired else { throw ProjectionProblem.missingEvidence }
        return (context, observed, desired)
    }
    func validateState(_ state: AeostaraContract.AshState) throws {
        try Self.validate(state.coordinates)
        guard !state.stateID.isEmpty, !state.sourceReference.isEmpty,
              state.canonicalHash == (try JSONValue.array(state.coordinates.map { .integer(String($0)) }).canonicalHash()) else { throw ProjectionProblem.invalidContext }
    }
    func dto(_ coordinates: [Int]) throws -> AeostaraContract.AshState {
        try Self.validate(coordinates)
        let hash = try JSONValue.array(coordinates.map { .integer(String($0)) }).canonicalHash()
        return try .init(stateID: "state-" + hash, coordinates: coordinates, sourceReference: Self.sourceReference, canonicalHash: hash)
    }
    func operation<T>(_ name: String, input: JSONValue, body: (inout SemanticTrace) throws -> T) throws -> T {
        var trace = SemanticTrace(identity: try JSONValue.array([.string(name), .string(boundContext?.identity ?? "unbound"), input]).canonicalHash())
        do { let result = try body(&trace); try retain(trace); return result }
        catch let failure as LifecycleFailure { throw failure }
        catch { let failure = try trace.failure(error, stage: .diagnose); try retain(trace); throw failure }
    }
    func requireValid(_ state: AeostaraContract.AshState, context: SemanticContext) throws {
        try validateState(state)
        guard try admissibility(of: state.coordinates, knownValid: context.knownValidStates) == .valid else { throw ProjectionProblem.invalidContext }
    }
    public func evaluateAdmissibility(state: AeostaraContract.AshState) throws -> AeostaraContract.AdmissibilityResult {
        try operation("evaluateAdmissibility", input: state.contractJSON) { trace in
            let (context, _, _) = try requireBound(); try validateState(state)
            let status = try admissibility(of: state.coordinates, knownValid: context.knownValidStates)
            let orbitHash = try JSONValue.array(orbit(of: state.coordinates).map { .array($0.map { .integer(String($0)) }) }).canonicalHash()
            let reference = try trace.append(kind: .stateValidity, ruleID: "ASH-ADMISSIBILITY-CLASSIFICATION-001", message: "Full canonical orbit membership evaluated", evidence: .object([JSONMember("status", status.contractJSON), JSONMember("state", state.contractJSON)]))
            return try .init(resultID: "admissibility-" + state.canonicalHash, stateReference: state.stateID, status: status, orbitReference: "orbit-" + orbitHash, diagnosticReference: reference)
        }
    }
    public func diagnoseState(state: AeostaraContract.AshState) throws -> AeostaraContract.StateValidityDiagnostic {
        try operation("diagnoseState", input: state.contractJSON) { trace in
            let (context, observed, desired) = try requireBound(); try validateState(state)
            let proof = try diagnose(state: state.coordinates, context: context, observed: observed, desired: desired)
            _ = try trace.append(kind: .stateValidity, ruleID: "ASH-STATE-VALIDITY-001", message: "Actual orbit, normalization and registered correction proof evaluated", evidence: .object([
                JSONMember("candidateState", state.contractJSON), JSONMember("contextReference", .string(context.identity)),
                JSONMember("knownCorrection", proof.knownCorrection.map { .string($0.definition.transitionID) } ?? .null),
                JSONMember("fallbackCandidate", proof.fallback.map { .string($0.policyID) } ?? .null)]))
            return try .init(stateValidityDiagnosticID: "validity-" + state.canonicalHash, diagnosticEnvelope: trace.envelopes.last!,
                admissibilityStatus: .init(rawValue: proof.admissibility.rawValue)!, normalizationStatus: proof.normalization, recoverabilityRelevance: proof.recoveryCategory)
        }
    }
    public func classifyState(diagnostic: AeostaraContract.StateValidityDiagnostic) throws -> AeostaraContract.SystemStateClass {
        try operation("classifyState", input: diagnostic.contractJSON) { trace in
            let (context, observed, desired) = try requireBound()
            guard let raw = diagnostic.diagnosticEnvelope.evidence.member("candidateState") else { throw ProjectionProblem.missingEvidence }
            let state = try AeostaraContract.AshState(contractJSON: raw)
            guard diagnostic == (try diagnoseState(state: state)) else { throw ProjectionProblem.invalidContext }
            let proof = try diagnose(state: state.coordinates, context: context, observed: observed, desired: desired)
            _ = try trace.append(kind: .recovery, ruleID: "ASH-CLASSIFICATION-MAPPING-001", message: "Classification derived from verified SDK diagnosis", evidence: .object([JSONMember("stateClass", proof.stateClass.contractJSON)]))
            return proof.stateClass
        }
    }
    public func applyCodewordTransformation(transformation: AeostaraContract.CodewordTransformation) throws -> AeostaraContract.TransitionResult {
        try operation("applyCodewordTransformation", input: transformation.contractJSON) { trace in
            let (context, _, _) = try requireBound(); try requireValid(transformation.inputState, context: context)
            try NativeDiagnosticContext.resolve(transformation.diagnosticReference, in: context.inputDiagnosticChains + diagnosticChains)
            try validateState(transformation.outputState)
            let bits = try transform(transformation.inputState.coordinates, codeword: transformation.codeword)
            guard bits == transformation.outputState.coordinates else { throw ProjectionProblem.invalidContext }
            let reference = try trace.append(kind: .stateValidity, ruleID: "ASH-CODEWORD-STRUCTURE-001", message: "All nine coordinates transformed by a fixed canonical codeword")
            return try .init(resultID: "transition-" + trace.root, transitionID: transformation.transformationID, inputState: transformation.inputState, outputState: transformation.outputState, diagnosticReference: reference)
        }
    }
    public func resolveRealmIdentity(state: AeostaraContract.AshState) throws -> AeostaraContract.RealmIdentity {
        try operation("resolveRealmIdentity", input: state.contractJSON) { trace in
            let (context, _, _) = try requireBound(); try requireValid(state, context: context)
            let encoding = state.coordinates.map(String.init).joined()
            let reference = try trace.append(kind: .stateValidity, ruleID: "ASH-STATE-STRUCTURE-001", message: "Realm identity encodes every coordinate", evidence: .object([JSONMember("signature", .string(encoding))]))
            return try .init(realmID: "realm-" + encoding, stateReference: state.stateID, encoding: encoding, diagnosticReference: reference)
        }
    }
    public func resolveTransition(state: AeostaraContract.AshState, definition: AeostaraContract.TransitionDefinition) throws -> AeostaraContract.TransitionResult {
        try operation("resolveTransition", input: .array([state.contractJSON, definition.contractJSON])) { trace in
            let (context, observed, desired) = try requireBound(); try requireValid(state, context: context)
            guard let entry = context.transitions.first(where: { $0.definition == definition }) else { throw ProjectionProblem.invalidContext }
            let target = try transform(state.coordinates, codeword: entry.codeword)
            guard try context.predicatesPass(definition.preconditions, input: state.coordinates, target: target, observed: observed, desired: desired) else { throw ProjectionProblem.invalidContext }
            let reference = try trace.append(kind: .stateValidity, ruleID: "ASH-CODEWORD-STRUCTURE-001", message: "Registered transition applicability and full XOR proved")
            return try .init(resultID: "transition-" + trace.root, transitionID: definition.transitionID, inputState: state, outputState: dto(target), diagnosticReference: reference)
        }
    }
    func topology(state: AeostaraContract.AshState, depth: Int, reference: AeostaraContract.DiagnosticReference) throws -> AeostaraContract.TopologyPlan {
        // The pinned DTO requires at least one edge; a depth-zero tree cannot truthfully serialize it.
        guard depth > 0 else { throw ProjectionProblem.missingEvidence }
        var nodes: [JSONValue] = [.object([JSONMember("nodeID", .string("F")), JSONMember("parentID", .null), JSONMember("depth", .integer("0")), JSONMember("ordinal", .integer("0")), JSONMember("branchKind", .string("root")), JSONMember("pathToken", .string("F"))])]
        var edges: [JSONValue] = [], current = ["F"]
        for level in 1...depth {
            var next: [String] = []
            for parent in current {
                for (kind, token) in [("continuation", "F"), ("positive", "+"), ("negative", "-")] {
                    let id = parent + "/" + token
                    nodes.append(.object([JSONMember("nodeID", .string(id)), JSONMember("parentID", .string(parent)), JSONMember("depth", .integer(String(level))), JSONMember("ordinal", .integer(String(next.count))), JSONMember("branchKind", .string(kind)), JSONMember("pathToken", .string(token))]))
                    edges.append(.object([JSONMember("parentID", .string(parent)), JSONMember("childID", .string(id)), JSONMember("branchKind", .string(kind))])); next.append(id)
                }
            }
            current = next
        }
        return try .init(topologyID: "topology-" + state.canonicalHash + "-" + String(depth), rootState: state, nodes: nodes, edges: edges,
            lineage: .object([JSONMember("seedToken", .string("F")), JSONMember("depth", .integer(String(depth))), JSONMember("leaves", .array(current.map(JSONValue.string)))]), diagnosticReferences: [reference])
    }
    public func generateTopology(state: AeostaraContract.AshState) throws -> AeostaraContract.TopologyPlan {
        try operation("generateTopology", input: state.contractJSON) { trace in
            let (context, _, _) = try requireBound(); try requireValid(state, context: context)
            guard let generation = generationContext else { throw ProjectionProblem.missingEvidence }
            let reference = try trace.append(kind: .stateValidity, ruleID: "ASH-STATE-STRUCTURE-001", message: "Deterministic ternary abstract topology generated", evidence: .object([JSONMember("depth", .integer(String(generation.topologyDepth)))]))
            return try topology(state: state, depth: generation.topologyDepth, reference: reference)
        }
    }
    func axioms(_ subject: NativeAxiomSubject, trace: inout SemanticTrace) throws -> [AeostaraContract.AxiomDiagnostic] {
        let checks = subject.checks
        let overall = checks.allSatisfy { $0.1 }
        return try checks.map { id, passed, explanation in
            let evidence = JSONValue.object([JSONMember("subject", subject.evidence), JSONMember("predicate", .string(explanation)), JSONMember("overallPass", .bool(overall)), JSONMember("passed", .bool(passed))])
            _ = try trace.append(kind: .stateValidity, ruleID: "ASH-STATE-VALIDITY-001", message: id + ": " + explanation + " = " + String(passed), evidence: evidence, severity: passed ? .info : .warning)
            return try .init(axiomID: id, diagnosticEnvelope: trace.envelopes.last!, evaluationResult: passed ? .pass : .fail, evidence: evidence)
        }
    }
    public func evaluateAxioms(state: AeostaraContract.AshState) throws -> [AeostaraContract.AxiomDiagnostic] {
        try operation("evaluateAxioms", input: state.contractJSON) { trace in
            let (context, _, _) = try requireBound(); try requireValid(state, context: context)
            guard let subject = axiomSubject else { throw ProjectionProblem.missingEvidence }
            return try axioms(subject, trace: &trace)
        }
    }
    public func generateMaterializationPlan(state: AeostaraContract.AshState) throws -> AeostaraContract.GenerationPlan {
        try operation("generateMaterializationPlan", input: state.contractJSON) { trace in
            let (context, observed, desired) = try requireBound(); try validateState(state)
            guard let generation = generationContext else { throw ProjectionProblem.missingEvidence }
            let proof = try diagnose(state: state.coordinates, context: context, observed: observed, desired: desired)
            guard let bits = try recoveryTarget(proof, context: context, observed: observed, desired: desired), proof.admissibility != .transformationIncompatible else { throw ProjectionProblem.invalidContext }
            let normalized = try dto(bits); try requireValid(normalized, context: context)
            let sourceRealm = try resolveRealmIdentity(state: normalized)
            var transformed = normalized
            var transitionReferences: [AeostaraContract.DiagnosticReference] = []
            for id in generation.transitionSequence {
                guard let entry = context.transitions.first(where: { $0.definition.transitionID == id }) else { throw ProjectionProblem.invalidContext }
                let result = try resolveTransition(state: transformed, definition: entry.definition)
                transformed = result.outputState; transitionReferences.append(result.diagnosticReference)
            }
            let destinationRealm = try resolveRealmIdentity(state: transformed)
            let reference = try trace.append(kind: .stateValidity, ruleID: "ASH-STATE-STRUCTURE-001", message: "Registered abstract generation request evaluated")
            let topology = try topology(state: transformed, depth: generation.topologyDepth, reference: reference)
            let roles = try generation.roleAssignment(topology.nodes)
            guard !roles.isEmpty, roles.allSatisfy({ if case .object = $0 { return true }; return false }) else { throw ProjectionProblem.missingEvidence }
            let nodeIDs = Set(topology.nodes.compactMap { if case .string(let id) = $0.member("nodeID") { return id }; return nil })
            for role in roles { guard case .string(let id) = role.member("nodeID"), nodeIDs.contains(id), case .string(let name) = role.member("role"), !name.isEmpty else { throw ProjectionProblem.invalidContext } }
            let subject = try generation.subjectBuilder(transformed, topology.nodes, roles)
            let diagnostics = try axioms(subject, trace: &trace)
            let artifacts = try generation.artifactDescription(generation.projectName, roles)
            guard !artifacts.isEmpty, artifacts.allSatisfy({ if case .object = $0 { return true }; return false }) else { throw ProjectionProblem.missingMaterialization }
            let metadata: JSONValue = .object([JSONMember("projectName", .string(generation.projectName)), JSONMember("profileID", .string(generation.profileID)), JSONMember("namingPolicyID", .string(generation.namingPolicyID)), JSONMember("emissionTargetKind", .string(generation.emissionTargetKind)), JSONMember("sourceReferences", .array(generation.sourceReferences.map(JSONValue.string))), JSONMember("topologyDepth", .integer(String(generation.topologyDepth))), JSONMember("transitionSequence", .array(generation.transitionSequence.map(JSONValue.string)))])
            let requiredRoots = Set(([sourceRealm.diagnosticReference, destinationRealm.diagnosticReference] + transitionReferences).map(\.chainRootReference))
            let supportChains = diagnosticChains.filter { requiredRoots.contains($0.rootDiagnosticID) }
            let semanticInputs: JSONValue = .object([JSONMember("contextReference", .string(context.identity)), JSONMember("knownValidStates", .array(context.knownValidStates.states.map { .array($0.map { .integer(String($0)) }) })), JSONMember("sourceReferences", .array(context.knownValidStates.sourceReferences.map(JSONValue.string))), JSONMember("diagnosticChains", .array((supportChains + [try trace.chain()]).map(\.contractJSON))), JSONMember("seedState", state.contractJSON), JSONMember("normalizedState", normalized.contractJSON), JSONMember("sourceRealm", sourceRealm.contractJSON), JSONMember("destinationRealm", destinationRealm.contractJSON), JSONMember("topology", topology.contractJSON), JSONMember("roles", .array(roles)), JSONMember("axiomDiagnostics", .array(diagnostics.map(\.contractJSON))), JSONMember("warnings", .array(diagnostics.filter { $0.evaluationResult == .fail }.map { .string($0.axiomID + ": failed") })), JSONMember("metadata", metadata)])
            let refs = try trace.envelopes.map { envelope in try AeostaraContract.DiagnosticReference(diagnosticID: envelope.diagnosticID, chainRootReference: envelope.chainRootReference, diagnosticKind: .init(rawValue: envelope.diagnosticKind.rawValue)!, ruleReferences: envelope.ruleReferences) }
            let hash = try JSONValue.object([JSONMember("planElements", .array(artifacts)), JSONMember("semanticInputs", semanticInputs), JSONMember("diagnosticReferences", .array(refs.map(\.contractJSON)))]).canonicalHash()
            return try .init(planID: "generation-" + hash, planElements: artifacts, semanticInputs: semanticInputs, diagnosticReferences: refs, planHash: hash)
        }
    }
    public func planArtifactEmission(plan: AeostaraContract.GenerationPlan) throws -> AeostaraContract.ArtifactEmissionPlan {
        try operation("planArtifactEmission", input: plan.contractJSON) { trace in
            let expectedHash = try JSONValue.object([JSONMember("planElements", .array(plan.planElements)), JSONMember("semanticInputs", plan.semanticInputs), JSONMember("diagnosticReferences", .array(plan.diagnosticReferences.map(\.contractJSON)))]).canonicalHash()
            guard plan.planHash == expectedHash, plan.planID == "generation-" + expectedHash,
                  let rawSeed = plan.semanticInputs.member("seedState"), let rawNormalized = plan.semanticInputs.member("normalizedState"),
                  let rawSource = plan.semanticInputs.member("sourceRealm"), let rawDestination = plan.semanticInputs.member("destinationRealm"),
                  let rawTopology = plan.semanticInputs.member("topology"), case .array(let rawAxioms) = plan.semanticInputs.member("axiomDiagnostics"), rawAxioms.count == 5,
                  case .array(let roles) = plan.semanticInputs.member("roles"), !roles.isEmpty,
                  case .object = plan.semanticInputs.member("metadata"), case .array(let rawChains) = plan.semanticInputs.member("diagnosticChains"),
                  case .array(let rawKnown) = plan.semanticInputs.member("knownValidStates"), !rawKnown.isEmpty else { throw ProjectionProblem.invalidContext }
            let seed = try AeostaraContract.AshState(contractJSON: rawSeed), normalized = try AeostaraContract.AshState(contractJSON: rawNormalized)
            try validateState(seed); try validateState(normalized)
            let source = try AeostaraContract.RealmIdentity(contractJSON: rawSource), destination = try AeostaraContract.RealmIdentity(contractJSON: rawDestination)
            let tree = try AeostaraContract.TopologyPlan(contractJSON: rawTopology); try validateState(tree.rootState)
            let known = try rawKnown.map { raw -> [Int] in guard case .array(let values) = raw else { throw ProjectionProblem.invalidContext }; return try values.map(ContractFields.integer) }
            guard known.contains(normalized.coordinates), known.contains(tree.rootState.coordinates),
                  (try orbit(of: seed.coordinates)).contains(normalized.coordinates), source.stateReference == normalized.stateID,
                  source.encoding == normalized.coordinates.map(String.init).joined(), source.realmID == "realm-" + source.encoding,
                  destination.stateReference == tree.rootState.stateID, destination.encoding == tree.rootState.coordinates.map(String.init).joined(), destination.realmID == "realm-" + destination.encoding else { throw ProjectionProblem.invalidContext }
            let chains = try rawChains.map { try AeostaraContract.DiagnosticChain(contractJSON: $0) }
            try NativeDiagnosticContext.validate(chains)
            for reference in plan.diagnosticReferences + [source.diagnosticReference, destination.diagnosticReference] + tree.diagnosticReferences { try NativeDiagnosticContext.resolve(reference, in: chains) }
            guard case .integer(let token) = tree.lineage.member("depth"), let depth = Int(token), depth > 0, depth <= 8,
                  tree == (try topology(state: tree.rootState, depth: depth, reference: tree.diagnosticReferences[0])) else { throw ProjectionProblem.invalidContext }
            let nodeIDs = Set(tree.nodes.compactMap { if case .string(let id) = $0.member("nodeID") { return id }; return nil })
            for role in roles { guard case .string(let id) = role.member("nodeID"), nodeIDs.contains(id), case .string(let name) = role.member("role"), !name.isEmpty else { throw ProjectionProblem.invalidContext } }
            let axioms = try rawAxioms.map { try AeostaraContract.AxiomDiagnostic(contractJSON: $0) }
            guard let rawSubject = axioms.first?.evidence.member("subject") else { throw ProjectionProblem.missingEvidence }
            let subject = try NativeAxiomSubject(evidence: rawSubject), checks = subject.checks
            let overall = checks.allSatisfy { $0.1 }
            guard axioms.map(\.axiomID) == checks.map({ $0.0 }),
                  plan.semanticInputs.member("warnings") == .array(checks.filter { !$0.1 }.map { .string($0.0 + ": failed") }) else { throw ProjectionProblem.invalidContext }
            for (axiom, check) in zip(axioms, checks) {
                guard axiom.evidence.member("subject") == rawSubject, axiom.evidence.member("predicate") == .string(check.2),
                      axiom.evaluationResult == (check.1 ? .pass : .fail), axiom.evidence.member("passed") == .bool(check.1),
                      axiom.evidence.member("overallPass") == .bool(overall), axiom.diagnosticEnvelope.evidence == axiom.evidence else { throw ProjectionProblem.invalidContext }
                let ref = try AeostaraContract.DiagnosticReference(diagnosticID: axiom.diagnosticEnvelope.diagnosticID, chainRootReference: axiom.diagnosticEnvelope.chainRootReference, diagnosticKind: .init(rawValue: axiom.diagnosticEnvelope.diagnosticKind.rawValue)!, ruleReferences: axiom.diagnosticEnvelope.ruleReferences)
                try NativeDiagnosticContext.resolve(ref, in: chains)
                guard chains.flatMap(\.diagnostics).contains(axiom.diagnosticEnvelope) else { throw ProjectionProblem.invalidContext }
            }
            _ = try trace.append(kind: .stateValidity, ruleID: "ASH-STATE-STRUCTURE-001", message: "Artifact descriptions handed off without side effects")
            return try .init(emissionPlanID: "emission-" + plan.planHash, generationPlanID: plan.planID, artifacts: plan.planElements,
                traceability: plan.planElements.enumerated().map { index, _ in .object([JSONMember("artifactOrdinal", .integer(String(index))), JSONMember("generationPlanID", .string(plan.planID)), JSONMember("planHash", .string(plan.planHash)), JSONMember("diagnosticReference", plan.diagnosticReferences.last!.contractJSON)]) })
        }
    }
}
