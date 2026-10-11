import Foundation

public struct NativeTopologyRequest {
    public let depth: Int
    public let seedToken: String
    public init(depth: Int, seedToken: String) throws {
        guard (0...8).contains(depth), !seedToken.isEmpty else { throw SemanticInputFault.malformedEvidence };self.depth = depth;self.seedToken = seedToken
    }
}
public struct NativeAxiomSubject {
    public let stateHash: String
    public let relationCount: Int
    public let compressedMeasure: Double
    public let rawMeasure: Double
    public let scaleCount: Int
    public let erasureCost: Double
    public let selfReferenceCapable: Bool
    public let selfModelAvailable: Bool
    public let sourceReferences: [String]
    public init(stateHash: String, relationCount: Int, compressedMeasure: Double, rawMeasure: Double, scaleCount: Int,
                erasureCost: Double, selfReferenceCapable: Bool, selfModelAvailable: Bool, sourceReferences: [String]) throws {
        guard !sourceReferences.isEmpty, relationCount >= 0, scaleCount >= 0, [compressedMeasure,rawMeasure,erasureCost].allSatisfy(\.isFinite) else { throw SemanticInputFault.malformedEvidence }
        self.stateHash = stateHash;self.relationCount = relationCount;self.compressedMeasure = compressedMeasure;self.rawMeasure = rawMeasure;self.scaleCount = scaleCount
        self.erasureCost = erasureCost;self.selfReferenceCapable = selfReferenceCapable;self.selfModelAvailable = selfModelAvailable;self.sourceReferences = sourceReferences
    }
}
public struct NativeGenerationRequest {
    public let projectName: String
    public let transitionSequence: [String]
    public let topology: NativeTopologyRequest
    public let profileID: String
    public let namingPolicyID: String
    public let emissionTargetKind: String
    public let sourceReferences: [String]
    public init(projectName: String, transitionSequence: [String], topology: NativeTopologyRequest, profileID: String,
                namingPolicyID: String, emissionTargetKind: String, sourceReferences: [String]) throws {
        guard [projectName,profileID,namingPolicyID,emissionTargetKind].allSatisfy({ !$0.isEmpty }), !sourceReferences.isEmpty else { throw SemanticInputFault.missingEvidence }
        self.projectName = projectName;self.transitionSequence = transitionSequence;self.topology = topology;self.profileID = profileID
        self.namingPolicyID = namingPolicyID;self.emissionTargetKind = emissionTargetKind;self.sourceReferences = sourceReferences
    }
}
public struct RegisteredGenerationProfile {
    public let identifier: String
    public let sourceReferences: [String]
    let roles: ([JSONValue]) throws -> [JSONValue]
    let subject: (AeostaraContract.AshState,[JSONValue],[JSONValue]) throws -> NativeAxiomSubject
    public init(identifier: String, sourceReferences: [String], assignRoles: @escaping ([JSONValue]) throws -> [JSONValue],
                axiomSubject: @escaping (AeostaraContract.AshState,[JSONValue],[JSONValue]) throws -> NativeAxiomSubject) throws {
        guard !identifier.isEmpty,!sourceReferences.isEmpty else { throw SemanticInputFault.missingEvidence };self.identifier = identifier;self.sourceReferences = sourceReferences;roles = assignRoles;subject = axiomSubject
    }
}
public struct RegisteredNamingPolicy {
    public let identifier: String
    public let sourceReferences: [String]
    let names: (String,[JSONValue]) throws -> [String]
    public init(identifier: String,sourceReferences: [String],names: @escaping (String,[JSONValue]) throws -> [String]) throws {
        guard !identifier.isEmpty,!sourceReferences.isEmpty else { throw SemanticInputFault.missingEvidence };self.identifier = identifier;self.sourceReferences = sourceReferences;self.names = names
    }
}
public struct RegisteredArtifactDescriptionRule {
    public let targetKind: String
    public let sourceReferences: [String]
    let descriptions: ([String],[JSONValue]) throws -> [JSONValue]
    public init(targetKind: String,sourceReferences: [String],describe: @escaping ([String],[JSONValue]) throws -> [JSONValue]) throws {
        guard !targetKind.isEmpty,!sourceReferences.isEmpty else { throw SemanticInputFault.missingEvidence };self.targetKind = targetKind;self.sourceReferences = sourceReferences;descriptions = describe
    }
}
public struct GenerationRuleRegistry {
    let profiles: [RegisteredGenerationProfile]
    let namingPolicies: [RegisteredNamingPolicy]
    let artifactRules: [RegisteredArtifactDescriptionRule]
    public init(profiles: [RegisteredGenerationProfile], namingPolicies: [RegisteredNamingPolicy], artifactRules: [RegisteredArtifactDescriptionRule]) throws {
        guard Set(profiles.map { Data($0.identifier.utf8) }).count == profiles.count,
              Set(namingPolicies.map { Data($0.identifier.utf8) }).count == namingPolicies.count,
              Set(artifactRules.map { Data($0.targetKind.utf8) }).count == artifactRules.count else { throw SemanticInputFault.malformedEvidence }
        self.profiles = profiles;self.namingPolicies = namingPolicies;self.artifactRules = artifactRules
    }
}
public struct AshOperationContext {
    public let topology: NativeTopologyRequest?
    public let axiomSubjects: [NativeAxiomSubject]
    public let generationRequest: NativeGenerationRequest?
    public let generationRules: GenerationRuleRegistry?
    public init(topology: NativeTopologyRequest? = nil, axiomSubjects: [NativeAxiomSubject] = [], generationRequest: NativeGenerationRequest? = nil, generationRules: GenerationRuleRegistry? = nil) throws {
        guard Set(axiomSubjects.map(\.stateHash)).count == axiomSubjects.count else { throw SemanticInputFault.malformedEvidence }
        self.topology = topology;self.axiomSubjects = axiomSubjects;self.generationRequest = generationRequest;self.generationRules = generationRules
    }
}
public extension AeostaraContract {
    protocol IAshBindingProvider {
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
extension NativeAshBindingProvider: AeostaraContract.IAshBindingProvider {
    private func validate(_ state: AeostaraContract.AshState, recognized: Bool = false) throws {
        guard try CanonicalJSON.hash(.array(state.coordinates.map { .number(.integer(String($0))) })) == state.canonicalHash else { throw SemanticInputFault.malformedEvidence }
        if recognized { guard context.knownValidStates.recognizedStates.contains(where:{$0.coordinates == state.coordinates}) else { throw SemanticInputFault.malformedEvidence } }
    }
    private func ledger(_ state: AeostaraContract.AshState, operation: String, evidence: JSONValue = .object([])) throws -> SemanticLedger {
        let identity = try CanonicalJSON.hash(.object([JSONMember("operation",.string(operation)),JSONMember("state",state.jsonValue),JSONMember("knownValidContext",.string(context.knownValidStates.contextHash)),JSONMember("evidence",evidence)]))
        return try SemanticLedger(identity:"ash-"+operation+"-"+identity,time:"1970-01-01T00:00:00Z")
    }
    private func fault(_ state: AeostaraContract.AshState, _ error: Error) throws -> LifecycleFailure {
        let code: LifecycleFaultCode = (error as? SemanticInputFault) == .missingEvidence ? .missingEvidence : .malformedContract
        return try ledger(state,operation:"failure-"+code.rawValue).failure(code)
    }
    public func evaluateAdmissibility(state: AeostaraContract.AshState) throws -> AeostaraContract.AdmissibilityResult {
        do { try validate(state);let evidence = try diagnose(state.coordinates,eligibleTargets:context.knownValidStates.recognizedStates.map(\.coordinates)), chain = try ledger(state,operation:"admissibility",evidence:diagnosticEvidence(evidence,state:state))
            let reference = try chain.append(kind:.STATE_VALIDITY,event:.DIAGNOSE,message:"Computed canonical orbit admissibility",rule:"ASH-ADMISSIBILITY-CLASSIFICATION-001")
            try retain(chain)
            return try .init(resultID:"admissibility-"+state.canonicalHash,stateReference:state.stateID,status:evidence.admissibility,orbitReference:CanonicalJSON.hash(.array(evidence.orbit.map { .array($0.map { .number(.integer(String($0))) }) })),diagnosticReference:reference)
        } catch { throw try fault(state,error) }
    }
    public func diagnoseState(state: AeostaraContract.AshState) throws -> AeostaraContract.StateValidityDiagnostic {
        do { try validate(state);let evidence = try diagnose(state.coordinates,eligibleTargets:context.knownValidStates.recognizedStates.map(\.coordinates)), chain = try ledger(state,operation:"diagnosis",evidence:diagnosticEvidence(evidence,state:state))
            _ = try chain.append(kind:.STATE_VALIDITY,event:.DIAGNOSE,message:"Canonical state diagnosis with actual registered correction evidence",rule:"ASH-STATE-VALIDITY-001",evidence:diagnosticEvidence(evidence,state:state))
            try retain(chain)
            return try .init(stateValidityDiagnosticID:"diagnosis-"+state.canonicalHash,diagnosticEnvelope:chain.diagnostics.last!,admissibilityStatus:.init(rawValue:evidence.admissibility.rawValue)!,normalizationStatus:evidence.normalization,recoverabilityRelevance:recoveryCategory(for:classify(evidence)))
        } catch { throw try fault(state,error) }
    }
    public func classifyState(diagnostic: AeostaraContract.StateValidityDiagnostic) throws -> AeostaraContract.SystemStateClass {
        let envelope = diagnostic.diagnosticEnvelope
        let reference = try AeostaraContract.DiagnosticReference(diagnosticID:envelope.diagnosticID,chainRootReference:envelope.chainRootReference,diagnosticKind:.init(rawValue:envelope.diagnosticKind.rawValue)!,ruleReferences:envelope.ruleReferences)
        do {
            guard try diagnosticRegistry().resolve(reference) == envelope, envelope.diagnosticKind == .STATE_VALIDITY,
                  envelope.evidence.member("admissibility_status")?.stringValue == diagnostic.admissibilityStatus.rawValue,
                  envelope.evidence.member("normalization_status")?.stringValue == diagnostic.normalizationStatus.rawValue else { throw SemanticInputFault.malformedEvidence }
            if diagnostic.admissibilityStatus == .UNCLASSIFIED { return .DEGRADED }
            guard let json = envelope.evidence.member("state") else { throw SemanticInputFault.missingEvidence }
            let state = try AeostaraContract.AshState(jsonValue:json)
            try validate(state)
            let evidence = try diagnose(state.coordinates,eligibleTargets:context.knownValidStates.recognizedStates.map(\.coordinates))
            let result = classify(evidence)
            guard diagnostic.admissibilityStatus.rawValue == evidence.admissibility.rawValue,diagnostic.normalizationStatus == evidence.normalization,
                  diagnostic.recoverabilityRelevance == recoveryCategory(for:result),envelope.evidence == diagnosticEvidence(evidence,state:state) else { throw SemanticInputFault.malformedEvidence }
            return result
        } catch {
            let chain = try SemanticLedger(identity:"ash-classification-"+CanonicalJSON.hash(diagnostic.jsonValue),time:"1970-01-01T00:00:00Z")
            throw try chain.failure((error as? SemanticInputFault) == .missingEvidence ? .missingEvidence : .malformedContract)
        }
    }
    public func applyCodewordTransformation(transformation: AeostaraContract.CodewordTransformation) throws -> AeostaraContract.TransitionResult {
        do {
            _ = try diagnosticRegistry().resolve(transformation.diagnosticReference)
            try validate(transformation.inputState,recognized:true);try validate(transformation.outputState)
            guard Self.canonicalCodewords.contains(transformation.codeword), try Self.xor(transformation.inputState.coordinates,transformation.codeword) == transformation.outputState.coordinates else { throw SemanticInputFault.malformedEvidence }
            let chain = try ledger(transformation.inputState,operation:"transformation",evidence:transformation.jsonValue), reference = try chain.append(kind:.STATE_VALIDITY,event:.RESULT,message:"Applied full-nine-coordinate canonical XOR",rule:"ASH-CODEWORD-STRUCTURE-001")
            try retain(chain)
            return try .init(resultID:"transition-"+transformation.transformationID,transitionID:transformation.transformationID,inputState:transformation.inputState,outputState:transformation.outputState,diagnosticReference:reference)
        } catch { throw try fault(transformation.inputState,error) }
    }
    public func resolveRealmIdentity(state: AeostaraContract.AshState) throws -> AeostaraContract.RealmIdentity {
        do { try validate(state,recognized:true);let chain = try ledger(state,operation:"realm");try retain(chain);return try resolveRealmIdentity(state:state,diagnostic:chain.reference()) } catch { throw try fault(state,error) }
    }
    public func resolveTransition(state: AeostaraContract.AshState, definition: AeostaraContract.TransitionDefinition) throws -> AeostaraContract.TransitionResult {
        do {
            try validate(state,recognized:true)
            guard let entry = context.transitions.definitions.first(where:{$0.transitionID.utf8.elementsEqual(definition.transitionID.utf8)}),
                  try ContractCoding.canonicalEncode(entry) == ContractCoding.canonicalEncode(definition), definition.codewordReference.hasPrefix("ASH-CANONICAL-C/") else { throw SemanticInputFault.missingEvidence }
            let token = String(definition.codewordReference.dropFirst("ASH-CANONICAL-C/".count))
            guard let codeword = Self.canonicalCodewords.first(where:{$0.map(String.init).joined() == token}) else { throw SemanticInputFault.malformedEvidence }
            let bits = try Self.xor(state.coordinates,codeword)
            for condition in definition.preconditions { guard try context.predicates.evaluate(condition,observed:state.coordinates,target:bits) else { throw SemanticInputFault.missingEvidence } }
            let hash = try CanonicalJSON.hash(.array(bits.map { .number(.integer(String($0))) }))
            let output = try AeostaraContract.AshState(stateID:"state-"+hash,coordinates:bits,sourceReference:definition.transitionID,canonicalHash:hash)
            let chain = try ledger(state,operation:"transition",evidence:definition.jsonValue), reference = try chain.append(kind:.STATE_VALIDITY,event:.RESULT,message:"Applied registry transition with actual preconditions",rule:"ASH-CODEWORD-STRUCTURE-001")
            try retain(chain)
            return try .init(resultID:"transition-"+state.canonicalHash+"-"+definition.transitionID,transitionID:definition.transitionID,inputState:state,outputState:output,diagnosticReference:reference)
        } catch { throw try fault(state,error) }
    }
    public func generateTopology(state: AeostaraContract.AshState) throws -> AeostaraContract.TopologyPlan {
        do { guard let request = operations?.topology else { throw SemanticInputFault.missingEvidence };return try topology(state:state,request:request) }
        catch { throw try fault(state,error) }
    }
    private func topology(state: AeostaraContract.AshState,request: NativeTopologyRequest) throws -> AeostaraContract.TopologyPlan {
        try validate(state,recognized:true)
        func node(id: String,parent: String?,depth: Int,ordinal: Int,kind: String,path: String) -> JSONValue { .object([JSONMember("node_id",.string(id)),JSONMember("parent_id",parent.map(JSONValue.string) ?? .null),JSONMember("depth",.number(.integer(String(depth)))),JSONMember("ordinal",.number(.integer(String(ordinal)))),JSONMember("branch_kind",.string(kind)),JSONMember("path_token",.string(path))]) }
        let rootID = "node-" + CanonicalJSON.hashBytes(Data(request.seedToken.utf8))
        var current = [node(id:rootID,parent:nil,depth:0,ordinal:0,kind:"root",path:request.seedToken)], lineage = current, edges: [JSONValue] = []
        for depth in 0..<request.depth {
            var next: [JSONValue] = []
            for parent in current {
                for (kind,token) in [("continuation","c"),("positive","p"),("negative","n")] {
                    let path = parent.member("path_token")!.stringValue! + "." + token, id = "node-"+CanonicalJSON.hashBytes(Data(path.utf8))
                    next.append(node(id:id,parent:parent.member("node_id")!.stringValue!,depth:depth+1,ordinal:next.count,kind:kind,path:path))
                    edges.append(.object([JSONMember("parent",parent.member("node_id")!),JSONMember("child",.string(id))]))
                }
            }
            current = next;lineage.append(contentsOf:next)
        }
        let chain = try ledger(state,operation:"topology",evidence:.object([JSONMember("depth",.number(.integer(String(request.depth)))),JSONMember("seed",.string(request.seedToken))])), reference = try chain.append(kind:.STATE_VALIDITY,event:.RESULT,message:"Expanded abstract ternary topology with explicit depth and lineage",rule:"ASH-STATE-STRUCTURE-001")
        let identity = try CanonicalJSON.hash(.object([JSONMember("seed",.string(request.seedToken)),JSONMember("depth",.number(.integer(String(request.depth)))),JSONMember("state",state.jsonValue)]))
        try retain(chain)
        return try .init(topologyID:"topology-"+identity,rootState:state,nodes:current,edges:edges,lineage:.object([JSONMember("nodes",.array(lineage)),JSONMember("source",.string("ASH-Pattern-System@e123f5d7fdbb381179971f721a3292c31eb1cbc2/specs/algorithms/topology-expansion.pseudo.md"))]),diagnosticReferences:[reference])
    }
    public func evaluateAxioms(state: AeostaraContract.AshState) throws -> [AeostaraContract.AxiomDiagnostic] {
        do { try validate(state,recognized:true);guard let subject = operations?.axiomSubjects.first(where:{$0.stateHash == state.canonicalHash}) else { throw SemanticInputFault.missingEvidence };return try axioms(subject:subject,state:state) }
        catch { throw try fault(state,error) }
    }
    private func axioms(subject: NativeAxiomSubject,state: AeostaraContract.AshState) throws -> [AeostaraContract.AxiomDiagnostic] {
        guard subject.stateHash == state.canonicalHash else { throw SemanticInputFault.malformedEvidence }
        let checks = [subject.relationCount > 0,subject.compressedMeasure < subject.rawMeasure,subject.scaleCount > 1,subject.erasureCost > 0,subject.selfReferenceCapable && subject.selfModelAvailable]
        let names = ["a1_relational_existence","a2_structural_compressibility","a3_multi_scale_persistence","a4_energetic_cost_of_erasure","a5_self_reference_for_consciousness"]
        let componentChecks = zip(names,checks).map { JSONMember($0,.bool($1)) }
        let notes = checks.enumerated().map { JSONValue.string("Axiom "+String($0.offset+1)+($0.element ? " passed" : " failed")) }
        let evidence = JSONValue.object(componentChecks + [JSONMember("notes",.array(notes)),JSONMember("algorithm_source",.string("ASH-Pattern-System@e123f5d7fdbb381179971f721a3292c31eb1cbc2/specs/algorithms/axiom-evaluation.pseudo.md")),JSONMember("relation_count",.number(.integer(String(subject.relationCount)))),JSONMember("compressed_measure",.number(.real(subject.compressedMeasure))),JSONMember("raw_measure",.number(.real(subject.rawMeasure))),JSONMember("scale_count",.number(.integer(String(subject.scaleCount)))),JSONMember("erasure_cost",.number(.real(subject.erasureCost))),JSONMember("self_reference_capable",.bool(subject.selfReferenceCapable)),JSONMember("self_model_available",.bool(subject.selfModelAvailable)),JSONMember("overall_pass",.bool(checks.allSatisfy{$0})),JSONMember("sources",.array(subject.sourceReferences.map(JSONValue.string)))])
        let chain = try ledger(state,operation:"axioms",evidence:evidence)
        let result: [AeostaraContract.AxiomDiagnostic] = try checks.enumerated().map { i,passed in
            _ = try chain.append(kind:.STATE_VALIDITY,event:.RESULT,message:"Evaluated canonical axiom "+String(i+1),rule:"ASH-STATE-STRUCTURE-001",failed:!passed,evidence:evidence)
            return try .init(axiomID:"ASH-AXIOM-"+String(i+1),diagnosticEnvelope:chain.diagnostics.last!,evaluationResult:passed ? .PASS : .FAIL,evidence:evidence)
        }
        try retain(chain)
        return result
    }
    private func generationLedger(state: AeostaraContract.AshState,evidence: JSONValue) throws -> SemanticLedger {
        let chain = try ledger(state,operation:"generation",evidence:evidence)
        _ = try chain.append(kind:.RECOVERY,event:.PLAN,message:"Prepared abstract materialization without I/O",rule:"ASH-STATE-STRUCTURE-001")
        return chain
    }
    public func generateMaterializationPlan(state: AeostaraContract.AshState) throws -> AeostaraContract.GenerationPlan {
        do {
            try validate(state);guard let request = operations?.generationRequest, let rules = operations?.generationRules,
                let profile = rules.profiles.first(where:{$0.identifier.utf8.elementsEqual(request.profileID.utf8)}),
                let naming = rules.namingPolicies.first(where:{$0.identifier.utf8.elementsEqual(request.namingPolicyID.utf8)}),
                let emitter = rules.artifactRules.first(where:{$0.targetKind.utf8.elementsEqual(request.emissionTargetKind.utf8)}) else { throw SemanticInputFault.missingEvidence }
            let orbit = try self.orbit(of:state.coordinates)
            guard let normalized = try context.knownValidStates.recognizedStates.filter({ orbit.contains($0.coordinates) }).map({($0,try ContractCoding.canonicalEncode($0))}).sorted(by:{$0.1.lexicographicallyPrecedes($1.1)}).first?.0 else { throw SemanticInputFault.missingEvidence }
            let source = try resolveRealmIdentity(state:normalized);var destinationState = normalized
            for id in request.transitionSequence { guard let definition = context.transitions.definitions.first(where:{$0.transitionID.utf8.elementsEqual(id.utf8)}) else { throw SemanticInputFault.missingEvidence };destinationState = try resolveTransition(state:destinationState,definition:definition).outputState }
            let destination = try resolveRealmIdentity(state:destinationState), topology = try self.topology(state:destinationState,request:request.topology)
            let roles = try profile.roles(topology.nodes)
            guard roles.count == topology.nodes.count, roles.allSatisfy({$0.objectMembers != nil}) else { throw SemanticInputFault.malformedEvidence }
            let subject = try profile.subject(destinationState,topology.nodes,roles), axiom = try axioms(subject:subject,state:destinationState)
            let names = try naming.names(request.projectName,roles)
            guard names.count == roles.count, Set(names.map { Data($0.utf8) }).count == names.count, names.allSatisfy({ !$0.isEmpty }) else { throw SemanticInputFault.malformedEvidence }
            let artifacts = try emitter.descriptions(names,roles)
            guard artifacts.count == roles.count, artifacts.allSatisfy({$0.objectMembers != nil}) else { throw SemanticInputFault.malformedEvidence }
            let semantic = JSONValue.object([JSONMember("seed_state",state.jsonValue),JSONMember("normalized_state",normalized.jsonValue),JSONMember("source_realm",source.jsonValue),JSONMember("destination_realm",destination.jsonValue),JSONMember("topology",topology.jsonValue),JSONMember("role_assignments",.array(roles)),JSONMember("axiom_diagnostics",.array(axiom.map(\.jsonValue))),JSONMember("overall_pass",.bool(axiom.allSatisfy{$0.evaluationResult == .PASS})),JSONMember("warnings",.array(axiom.filter{$0.evaluationResult != .PASS}.map{.string($0.axiomID)})),JSONMember("profile_id",.string(request.profileID)),JSONMember("naming_policy_id",.string(request.namingPolicyID)),JSONMember("emission_target_kind",.string(request.emissionTargetKind)),JSONMember("project_name",.string(request.projectName)),JSONMember("sources",.array(request.sourceReferences.map(JSONValue.string)))])
            let evidence = JSONValue.object([JSONMember("elements",.array(artifacts)),JSONMember("semanticInputs",semantic)])
            let chain = try generationLedger(state:state,evidence:evidence),ref = try chain.reference()
            let hash = try CanonicalJSON.hash(evidence)
            try retain(chain)
            return try .init(planID:"generation-"+hash,planElements:artifacts,semanticInputs:semantic,diagnosticReferences:[ref],planHash:hash)
        } catch { throw try fault(state,error) }
    }
    public func planArtifactEmission(plan: AeostaraContract.GenerationPlan) throws -> AeostaraContract.ArtifactEmissionPlan {
        // The complete immutable plan is the handoff. This boundary never calls a planner or registry callback.
        let chain = try SemanticLedger(identity:"ash-emission-"+CanonicalJSON.hash(plan.jsonValue),time:"1970-01-01T00:00:00Z")
        do {
            let registry = try diagnosticRegistry()
            for reference in plan.diagnosticReferences { _ = try registry.resolve(reference) }
            let identity = JSONValue.object([JSONMember("elements",.array(plan.planElements)),JSONMember("semanticInputs",plan.semanticInputs)])
            guard try CanonicalJSON.hash(identity) == plan.planHash,plan.planID == "generation-"+plan.planHash,
                  let seedJSON = plan.semanticInputs.member("seed_state"), let normalizedJSON = plan.semanticInputs.member("normalized_state"),
                  let topologyJSON = plan.semanticInputs.member("topology"),let axioms = plan.semanticInputs.member("axiom_diagnostics")?.arrayValues,
                  let roles = plan.semanticInputs.member("role_assignments")?.arrayValues,axioms.count == 5,
                  ["profile_id","naming_policy_id","emission_target_kind","project_name"].allSatisfy({plan.semanticInputs.member($0)?.stringValue?.isEmpty == false}) else { throw SemanticInputFault.malformedEvidence }
            let seed = try AeostaraContract.AshState(jsonValue:seedJSON),normalized = try AeostaraContract.AshState(jsonValue:normalizedJSON),topology = try AeostaraContract.TopologyPlan(jsonValue:topologyJSON)
            // Issued generation identity binds every element and semantic input to this immutable context.
            // Reconstructing its ledger identity reads no registry callback and performs no planning.
            let issued = try generationLedger(state:seed,evidence:identity),issuedReference = try issued.reference()
            guard plan.diagnosticReferences == [issuedReference],
                  try registry.chain(for:issuedReference) == issued.diagnosticChain() else { throw SemanticInputFault.malformedEvidence }
            try validate(seed);try validate(normalized,recognized:true);try validate(topology.rootState,recognized:true)
            guard try orbit(of:seed.coordinates).contains(normalized.coordinates),roles.count == topology.nodes.count,plan.planElements.count == roles.count,
                  plan.planElements.allSatisfy({$0.objectMembers != nil}) else { throw SemanticInputFault.malformedEvidence }
            for reference in topology.diagnosticReferences { _ = try registry.resolve(reference) }
            for (key,state) in [("source_realm",normalized),("destination_realm",topology.rootState)] {
                guard let value = plan.semanticInputs.member(key) else { throw SemanticInputFault.missingEvidence }
                let realm = try AeostaraContract.RealmIdentity(jsonValue:value)
                guard try realm == resolveRealmIdentity(state:state,diagnostic:realm.diagnosticReference) else { throw SemanticInputFault.malformedEvidence }
            }
            let decoded = try axioms.map { try AeostaraContract.AxiomDiagnostic(jsonValue:$0) }
            for axiom in decoded {
                let envelope = axiom.diagnosticEnvelope
                let reference = try AeostaraContract.DiagnosticReference(diagnosticID:envelope.diagnosticID,chainRootReference:envelope.chainRootReference,diagnosticKind:.init(rawValue:envelope.diagnosticKind.rawValue)!,ruleReferences:envelope.ruleReferences)
                guard try registry.resolve(reference) == envelope,axiom.evidence == envelope.evidence else { throw SemanticInputFault.malformedEvidence }
            }
            guard Set(decoded.map(\.axiomID)) == Set((1...5).map{"ASH-AXIOM-"+String($0)}),
                  plan.semanticInputs.member("overall_pass")?.boolValue == decoded.allSatisfy({$0.evaluationResult == .PASS}) else { throw SemanticInputFault.malformedEvidence }
            _ = try chain.append(kind:.RECOVERY,event:.PLAN,message:"Validated immutable artifact handoff with resolved provenance",rule:"ASH-STATE-STRUCTURE-001")
            try retain(chain)
            return try .init(emissionPlanID:"emission-"+plan.planHash,generationPlanID:plan.planID,artifacts:plan.planElements,traceability:[.object([JSONMember("generationPlanID",.string(plan.planID)),JSONMember("planHash",.string(plan.planHash)),JSONMember("semanticInputs",plan.semanticInputs)])])
        } catch { throw try chain.failure(.malformedContract) }
    }
    public func average(state: AeostaraContract.AshState, function: ([Int]) throws -> Double) throws -> Double {
        try validate(state);var sum = 0.0
        for codeword in Self.canonicalCodewords { let value = try function(Self.xor(state.coordinates,codeword));guard value.isFinite else { throw try fault(state,SemanticInputFault.malformedEvidence) };sum += value }
        guard sum.isFinite else { throw try fault(state,SemanticInputFault.malformedEvidence) };return sum/16.0
    }
}
