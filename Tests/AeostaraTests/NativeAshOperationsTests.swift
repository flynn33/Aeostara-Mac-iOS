import Foundation
import XCTest
import AeostaraDomain

final class NativeAshOperationsTests: XCTestCase {
    private func state(_ bits: [Int],id: String = "test-state") throws -> AeostaraContract.AshState {
        try .init(stateID:id,coordinates:bits,sourceReference:"explicit-test-state",canonicalHash:CanonicalJSON.hash(.array(bits.map{.number(.integer(String($0)))})))
    }
    private func context(known: [[Int]] = [[Int](repeating:0,count:9)],transition: Bool = false,fallback: Bool = false) throws -> SemanticContext {
        let base = try NativeSliceContext.make(),states = try known.enumerated().map{try state($0.element,id:"known-"+String($0.offset))}
        let predicate = try RegisteredStatePredicate(identifier:"TEST-ACTUAL-PRECONDITION",sourceReferences:["explicit-test-coordinate-rule"],evaluate:{ observed,target in observed[8] == 0 && target[8] == 0 })
        let any = try RegisteredStatePredicate(identifier:"TEST-FALLBACK-EVIDENCE",sourceReferences:["explicit-test-fallback-eligibility"],evaluate:{_,_ in true})
        let rule = try AeostaraContract.RuleReference(ruleID:"ASH-CODEWORD-STRUCTURE-001",sourceReference:NativeAshBindingProvider.source(for:"ASH-CODEWORD-STRUCTURE-001"),ruleFamily:"CODEWORD")
        let definition = try AeostaraContract.TransitionDefinition(transitionID:"test-correction",codewordReference:"ASH-CANONICAL-C/111100000",preconditions:[predicate.identifier],diagnosticRules:[rule])
        let fallbackPolicies = try fallback ? [FallbackPolicy(policyID:"FALLBACK-SECOND-002",applicabilityConditions:[any.identifier],candidateStateReference:states[0].stateID,orderingRank:1,validationRequirements:[any.identifier],escalationOnFailure:.TRY_NEXT,sourceReferences:["explicit-test-fallback"]),FallbackPolicy(policyID:"FALLBACK-FIRST-001",applicabilityConditions:[any.identifier],candidateStateReference:states[0].stateID,orderingRank:0,validationRequirements:[any.identifier],escalationOnFailure:.ESCALATE_TO_CONTAINMENT,sourceReferences:["explicit-test-fallback"])] : []
        return try .init(applicationScopeID:base.applicationScopeID,projectionSpec:base.projectionSpec,intentConstraints:base.intentConstraints,knownValidStates:KnownValidStateContext(applicationScopeID:base.applicationScopeID,recognizedStates:states,sourceReferences:["explicit-test-known-valid"]),mappingRules:base.mappingRules,transitions:TransitionRegistry(transition ? [definition] : []),predicates:PredicateRuleRegistry([predicate,any]),fallbackPolicies:FallbackPolicyRegistry(fallbackPolicies),inputDiagnosticChains:base.inputDiagnosticChains)
    }
    func testAllTenPublicOperationsAndAveragingUseActualCanonicalEvidence() throws {
        let zero = [Int](repeating:0,count:9),bits = [1,1,1,1,0,0,0,0,0],context = try context(known:[zero,bits],transition:true)
        let input = try state(zero),subject = try NativeAxiomSubject(stateHash:input.canonicalHash,relationCount:2,compressedMeasure:1,rawMeasure:2,scaleCount:3,erasureCost:1,selfReferenceCapable:true,selfModelAvailable:true,sourceReferences:["test-measured-subject"])
        let topology = try NativeTopologyRequest(depth:2,seedToken:"F"),request = try NativeGenerationRequest(projectName:"Example",transitionSequence:["test-correction"],topology:topology,profileID:"test-profile",namingPolicyID:"test-names",emissionTargetKind:"module-description",sourceReferences:["test-generation-request"])
        var callbacks = 0
        let profile = try RegisteredGenerationProfile(identifier:"test-profile",sourceReferences:["test-role-policy"],assignRoles:{ nodes in callbacks += 1;return nodes.map{.object([JSONMember("node",$0),JSONMember("role",.string("module"))])} },axiomSubject:{ state,_,_ in
            try NativeAxiomSubject(stateHash:state.canonicalHash,relationCount:1,compressedMeasure:1,rawMeasure:2,scaleCount:2,erasureCost:1,selfReferenceCapable:true,selfModelAvailable:true,sourceReferences:["test-derived-subject"])
        })
        let names = try RegisteredNamingPolicy(identifier:"test-names",sourceReferences:["test-name-policy"],names:{ project,roles in roles.indices.map{project+"-"+String($0)} })
        let descriptions = try RegisteredArtifactDescriptionRule(targetKind:"module-description",sourceReferences:["test-emission-description"],describe:{ names,_ in names.map{.object([JSONMember("name",.string($0)),JSONMember("kind",.string("module-description"))])} })
        let binding = NativeAshBindingProvider(context:context,operations:try AshOperationContext(topology:topology,axiomSubjects:[subject],generationRequest:request,generationRules:GenerationRuleRegistry(profiles:[profile],namingPolicies:[names],artifactRules:[descriptions])))
        let api: any AeostaraContract.IAshBindingProvider = binding
        XCTAssertEqual(try api.evaluateAdmissibility(state:input).status,.VALID)
        let diagnosis = try api.diagnoseState(state:input);XCTAssertEqual(try api.classifyState(diagnostic:diagnosis),.STABLE)
        let definition = context.transitions.definitions[0],transformed = try api.resolveTransition(state:input,definition:definition)
        XCTAssertEqual(transformed.outputState.coordinates,bits)
        let transformation = try AeostaraContract.CodewordTransformation(transformationID:"test-transform",inputState:input,codeword:bits,outputState:transformed.outputState,diagnosticReference:diagnosis.diagnosticEnvelopeReference())
        XCTAssertEqual(try api.applyCodewordTransformation(transformation:transformation).outputState.coordinates,bits)
        XCTAssertEqual(try api.resolveRealmIdentity(state:input).encoding,"ASH9:000000000")
        let expanded = try api.generateTopology(state:input);XCTAssertEqual(expanded.nodes.count,9);XCTAssertEqual(expanded.edges.count,12);XCTAssertEqual(expanded.lineage.member("nodes")?.arrayValues?.count,13)
        XCTAssertEqual(expanded.nodes.map{$0.member("ordinal")?.integerValue},Array(0..<9).map(Optional.init))
        let axioms = try api.evaluateAxioms(state:input);XCTAssertEqual(axioms.count,5);XCTAssertTrue(axioms.allSatisfy{$0.evaluationResult == .PASS});XCTAssertEqual(axioms[0].evidence.member("a5_self_reference_for_consciousness"),.bool(true))
        let plan = try api.generateMaterializationPlan(state:input);XCTAssertEqual(plan.planElements.count,9);XCTAssertEqual(callbacks,1)
        let repeatedPlan = try api.generateMaterializationPlan(state:input)
        XCTAssertEqual(try ContractCoding.canonicalEncode(repeatedPlan),try ContractCoding.canonicalEncode(plan),"Identical immutable requests and registry outputs must yield the same complete plan")
        XCTAssertEqual(callbacks,2)
        let emission = try api.planArtifactEmission(plan:plan);XCTAssertEqual(emission.artifacts,plan.planElements);XCTAssertEqual(callbacks,2,"Emission must consume the complete plan without calling planner callbacks")
        let recipient = NativeAshBindingProvider(context:context,diagnosticRegistry:try binding.diagnosticRegistry())
        XCTAssertEqual(try recipient.planArtifactEmission(plan:plan).artifacts,plan.planElements)
        XCTAssertThrowsError(try NativeAshBindingProvider(context:context).planArtifactEmission(plan:plan),"Handoff requires its actual immutable provenance snapshot")
        let f: ([Int]) -> Double = {Double($0.enumerated().reduce(0){$0+$1.offset*$1.element})}
        let mean = try binding.average(state:input,function:f)
        XCTAssertEqual(mean,try binding.average(state:transformed.outputState,function:f))
        XCTAssertEqual(mean,try binding.average(state:input,function:{ bits in try binding.average(state:self.state(bits),function:f) }))
    }
    func testEmissionRejectsRehashedSemanticTamperingWithIssuedReferences() throws {
        let context = try context(),input = try state([Int](repeating:0,count:9))
        let topology = try NativeTopologyRequest(depth:1,seedToken:"F")
        let request = try NativeGenerationRequest(projectName:"Example",transitionSequence:[],topology:topology,profileID:"profile",namingPolicyID:"names",emissionTargetKind:"record",sourceReferences:["test-generation"])
        var callbacks = 0
        let profile = try RegisteredGenerationProfile(identifier:"profile",sourceReferences:["test-profile"],assignRoles:{ nodes in callbacks += 1;return nodes.map{.object([JSONMember("node",$0)])} },axiomSubject:{ state,_,_ in
            callbacks += 1;return try NativeAxiomSubject(stateHash:state.canonicalHash,relationCount:1,compressedMeasure:1,rawMeasure:2,scaleCount:2,erasureCost:1,selfReferenceCapable:true,selfModelAvailable:true,sourceReferences:["test-subject"])
        })
        let naming = try RegisteredNamingPolicy(identifier:"names",sourceReferences:["test-names"],names:{ project,roles in callbacks += 1;return roles.indices.map{project+String($0)} })
        let artifact = try RegisteredArtifactDescriptionRule(targetKind:"record",sourceReferences:["test-artifacts"],describe:{ names,_ in callbacks += 1;return names.map{.object([JSONMember("name",.string($0))])} })
        let producer = NativeAshBindingProvider(context:context,operations:try AshOperationContext(generationRequest:request,generationRules:GenerationRuleRegistry(profiles:[profile],namingPolicies:[naming],artifactRules:[artifact])))
        let plan = try producer.generateMaterializationPlan(state:input)
        let recipient = NativeAshBindingProvider(context:context,diagnosticRegistry:try producer.diagnosticRegistry())
        XCTAssertEqual(try recipient.planArtifactEmission(plan:plan).artifacts,plan.planElements)
        func replacing(_ value: JSONValue,_ key: String,_ replacement: JSONValue) -> JSONValue {
            .object(value.objectMembers!.map{ $0.name.utf8.elementsEqual(key.utf8) ? JSONMember($0.name,replacement) : $0 })
        }
        let falseTopology = replacing(plan.semanticInputs.member("topology")!,"edges",.array([.object([JSONMember("parent",.string("unissued-parent")),JSONMember("child",.string("unissued-child"))])]))
        var axioms = plan.semanticInputs.member("axiom_diagnostics")!.arrayValues!
        axioms[0] = replacing(axioms[0],"evidence",replacing(axioms[0].member("evidence")!,"compressed_measure",.number(.integer("100"))))
        let falseRealm = replacing(replacing(plan.semanticInputs.member("source_realm")!,"encoding",.string("unissued-encoding")),"stateReference",.string("unrecognized-state"))
        let variants: [(JSONValue,[JSONValue])] = [
            (replacing(plan.semanticInputs,"topology",falseTopology),plan.planElements),
            (replacing(plan.semanticInputs,"axiom_diagnostics",.array(axioms)),plan.planElements),
            (replacing(plan.semanticInputs,"source_realm",falseRealm),plan.planElements),
            (plan.semanticInputs,plan.planElements.map{replacing($0,"name",.string("unissued-artifact"))})
        ]
        for (semantic,elements) in variants {
            let hash = try CanonicalJSON.hash(.object([JSONMember("elements",.array(elements)),JSONMember("semanticInputs",semantic)]))
            let altered = try AeostaraContract.GenerationPlan(planID:"generation-"+hash,planElements:elements,semanticInputs:semantic,diagnosticReferences:plan.diagnosticReferences,planHash:hash)
            XCTAssertThrowsError(try recipient.planArtifactEmission(plan:altered)) { XCTAssertEqual(($0 as? LifecycleFailure)?.code,.malformedContract) }
        }
        XCTAssertEqual(callbacks,4,"The recipient has no planning context and cannot rerun callbacks")
    }
    func testUnclassifiedDefaultAndForgedDiagnosisAreDistinguished() throws {
        let binding = NativeAshBindingProvider(context:try context()),valid = try binding.diagnoseState(state:state([Int](repeating:0,count:9)))
        let unclassified = try AeostaraContract.StateValidityDiagnostic(stateValidityDiagnosticID:"actual-unclassified-contract",diagnosticEnvelope:valid.diagnosticEnvelope,admissibilityStatus:.UNCLASSIFIED,normalizationStatus:.BLOCKED,recoverabilityRelevance:.FALLBACK_REQUIRED)
        XCTAssertThrowsError(try binding.classifyState(diagnostic:unclassified),"Changing status on an issued valid envelope must fail")
        let rule = try AeostaraContract.RuleReference(ruleID:"ASH-STATE-VALIDITY-001",sourceReference:NativeAshBindingProvider.source(for:"ASH-STATE-VALIDITY-001"),ruleFamily:"STATE")
        let unknownEnvelope = try AeostaraContract.DiagnosticEnvelope(diagnosticID:"recorded-unclassified",chainRootReference:"recorded-unclassified",parentDiagnosticID:nil,diagnosticKind:.STATE_VALIDITY,severity:.WARNING,message:"Input diagnostic records unavailable classification evidence",ruleReferences:[rule],sourceReferences:[rule.sourceReference],evidence:.object([JSONMember("admissibility_status",.string("UNCLASSIFIED")),JSONMember("normalization_status",.string("BLOCKED"))]))
        let unknownChain = try AeostaraContract.DiagnosticChain(chainID:"recorded-unclassified-chain",rootDiagnosticID:unknownEnvelope.diagnosticID,diagnostics:[unknownEnvelope])
        let registeredUnknown = NativeAshBindingProvider(context:try context(),diagnosticRegistry:try NativeDiagnosticRegistry(chains:[unknownChain]))
        let unknown = try AeostaraContract.StateValidityDiagnostic(stateValidityDiagnosticID:"recorded-unknown",diagnosticEnvelope:unknownEnvelope,admissibilityStatus:.UNCLASSIFIED,normalizationStatus:.BLOCKED,recoverabilityRelevance:.FALLBACK_REQUIRED)
        XCTAssertEqual(try registeredUnknown.classifyState(diagnostic:unknown),.DEGRADED)
        let forged = try AeostaraContract.StateValidityDiagnostic(stateValidityDiagnosticID:"forged",diagnosticEnvelope:valid.diagnosticEnvelope,admissibilityStatus:.TRANSFORMATION_COMPATIBLE,normalizationStatus:.NORMALIZABLE,recoverabilityRelevance:.NORMALIZE_STATE)
        XCTAssertThrowsError(try binding.classifyState(diagnostic:forged))
        let wrongHash = try AeostaraContract.AshState(stateID:"wrong-hash",coordinates:[Int](repeating:0,count:9),sourceReference:"test",canonicalHash:"bad")
        XCTAssertThrowsError(try binding.diagnoseState(state:wrongHash))
    }
    func testPublicDiagnosticRegistryRejectsOrphansAndPreservesDistinctImmutableChains() throws {
        let context = try context(),provider = NativeAshBindingProvider(context:context),input = try state([Int](repeating:0,count:9))
        let admissibility = try provider.evaluateAdmissibility(state:input),diagnosis = try provider.diagnoseState(state:input)
        let snapshot = try provider.diagnosticRegistry()
        XCTAssertNotEqual(admissibility.diagnosticReference.diagnosticID,diagnosis.diagnosticEnvelope.diagnosticID)
        XCTAssertEqual(try snapshot.resolve(admissibility.diagnosticReference).ruleReferences,admissibility.diagnosticReference.ruleReferences)
        XCTAssertEqual(try snapshot.resolve(diagnosis.diagnosticEnvelopeReference()),diagnosis.diagnosticEnvelope)
        let orphan = try AeostaraContract.DiagnosticReference(diagnosticID:"never-issued",chainRootReference:"never-issued-root",diagnosticKind:.STATE_VALIDITY,ruleReferences:diagnosis.diagnosticEnvelope.ruleReferences)
        let invalid = try AeostaraContract.CodewordTransformation(transformationID:"orphan",inputState:input,codeword:input.coordinates,outputState:input,diagnosticReference:orphan)
        XCTAssertThrowsError(try provider.applyCodewordTransformation(transformation:invalid)) { XCTAssertEqual(($0 as? LifecycleFailure)?.code,.missingEvidence) }
        let second = NativeAshBindingProvider(context:context,diagnosticRegistry:snapshot)
        let valid = try AeostaraContract.CodewordTransformation(transformationID:"registered",inputState:input,codeword:input.coordinates,outputState:input,diagnosticReference:diagnosis.diagnosticEnvelopeReference())
        let result = try second.applyCodewordTransformation(transformation:valid)
        XCTAssertEqual(try second.diagnosticRegistry().resolve(result.diagnosticReference).diagnosticID,result.diagnosticReference.diagnosticID)
        XCTAssertThrowsError(try snapshot.resolve(result.diagnosticReference),"An immutable earlier snapshot cannot acquire later evidence")
        let envelope = diagnosis.diagnosticEnvelope
        let forged = try AeostaraContract.DiagnosticEnvelope(diagnosticID:envelope.diagnosticID,chainRootReference:envelope.chainRootReference,parentDiagnosticID:envelope.parentDiagnosticID,diagnosticKind:envelope.diagnosticKind,severity:envelope.severity,message:"Changed record",ruleReferences:envelope.ruleReferences,sourceReferences:envelope.sourceReferences,evidence:envelope.evidence)
        let original = try snapshot.chain(for:diagnosis.diagnosticEnvelopeReference())
        let conflicting = try AeostaraContract.DiagnosticChain(chainID:original.chainID,rootDiagnosticID:original.rootDiagnosticID,diagnostics:original.diagnostics.dropLast()+[forged])
        XCTAssertThrowsError(try NativeDiagnosticRegistry(chains:snapshot.chains+[conflicting]))
    }
    func testKnownCorrectionEvidenceAndFallbackOrderingAreSourceDerived() throws {
        let codeword = [1,1,1,1,0,0,0,0,0],zero = [Int](repeating:0,count:9)
        let correction = NativeAshBindingProvider(context:try context(transition:true))
        XCTAssertEqual(correction.classify(try correction.diagnose(codeword,eligibleTargets:[zero])),.CORRECTABLE)
        let normalization = NativeAshBindingProvider(context:try context())
        XCTAssertEqual(normalization.classify(try normalization.diagnose(codeword,eligibleTargets:[zero])),.UNSTABLE)
        let fallback = NativeAshBindingProvider(context:try context(fallback:true)),incompatible = [0,0,0,0,0,0,0,0,1]
        XCTAssertEqual(fallback.classify(try fallback.diagnose(incompatible,eligibleTargets:[zero])),.DEGRADED)
        XCTAssertEqual(try fallback.eligibleFallbacks(for:incompatible,eligibleTargets:[zero]).map{$0.0.policyID},["FALLBACK-FIRST-001","FALLBACK-SECOND-002"])
        XCTAssertEqual(normalization.classify(try normalization.diagnose(incompatible,eligibleTargets:[zero])),.FAILED)
        for value in AeostaraContract.SystemStateClass.allNativeCases { XCTAssertEqual(fallback.recoveryCategory(for:value).rawValue,["STABLE":"NO_ACTION","UNSTABLE":"NORMALIZE_STATE","CORRECTABLE":"APPLY_CORRECTION","DEGRADED":"FALLBACK_REQUIRED","CONTAINED":"CONTAINMENT_REQUIRED","FAILED":"ESCALATION_REQUIRED","SAFE_HALT":"TERMINAL_NO_RECOVERY"][value.rawValue]) }
    }
    func testMissingGenerationSubjectInvalidCodewordAndNonfiniteAverageFailClosed() throws {
        let binding = NativeAshBindingProvider(context:try context()),zero = try state([Int](repeating:0,count:9))
        XCTAssertThrowsError(try binding.generateTopology(state:zero));XCTAssertThrowsError(try binding.evaluateAxioms(state:zero));XCTAssertThrowsError(try binding.generateMaterializationPlan(state:zero))
        XCTAssertThrowsError(try binding.average(state:zero,function:{_ in .infinity}))
        XCTAssertThrowsError(try NativeTopologyRequest(depth:9,seedToken:"F"))
        let invalid = [1,0,0,0,0,0,0,0,0],output = try state(invalid)
        let diagnostic = try binding.diagnoseState(state:zero)
        let operation = try AeostaraContract.CodewordTransformation(transformationID:"invalid-C",inputState:zero,codeword:invalid,outputState:output,diagnosticReference:diagnostic.diagnosticEnvelopeReference())
        XCTAssertThrowsError(try binding.applyCodewordTransformation(transformation:operation))
        XCTAssertThrowsError(try binding.resolveRealmIdentity(state:output))
    }
    func testDepthZeroCannotFabricateAnEdgeToSatisfyFrozenTopologyContract() throws {
        let binding = NativeAshBindingProvider(context:try context(),operations:try AshOperationContext(topology:NativeTopologyRequest(depth:0,seedToken:"F")))
        XCTAssertThrowsError(try binding.generateTopology(state:state([Int](repeating:0,count:9)))) { XCTAssertEqual(($0 as? LifecycleFailure)?.code,.malformedContract) }
    }
    func testFailedAxiomsPreserveAllFiveChecksAndNotes() throws {
        let context = try context(),state = try self.state([Int](repeating:0,count:9)),subject = try NativeAxiomSubject(stateHash:state.canonicalHash,relationCount:0,compressedMeasure:2,rawMeasure:1,scaleCount:1,erasureCost:0,selfReferenceCapable:true,selfModelAvailable:false,sourceReferences:["test-negative-subject"])
        let values = try NativeAshBindingProvider(context:context,operations:AshOperationContext(axiomSubjects:[subject])).evaluateAxioms(state:state)
        XCTAssertEqual(values.map(\.evaluationResult),Array(repeating:.FAIL,count:5));XCTAssertEqual(values[0].evidence.member("notes")?.arrayValues?.count,5);XCTAssertEqual(values[0].evidence.member("overall_pass"),.bool(false))
    }
}
private extension AeostaraContract.StateValidityDiagnostic {
    func diagnosticEnvelopeReference() throws -> AeostaraContract.DiagnosticReference {
        try .init(diagnosticID:diagnosticEnvelope.diagnosticID,chainRootReference:diagnosticEnvelope.chainRootReference,diagnosticKind:.init(rawValue:diagnosticEnvelope.diagnosticKind.rawValue)!,ruleReferences:diagnosticEnvelope.ruleReferences)
    }
}
private extension AeostaraContract.SystemStateClass { static var allNativeCases: [Self] { [.STABLE,.UNSTABLE,.CORRECTABLE,.DEGRADED,.CONTAINED,.FAILED,.SAFE_HALT] } }
