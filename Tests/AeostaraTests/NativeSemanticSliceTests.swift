import Foundation
import XCTest
import AeostaraDomain
import AeostaraServices

/// Synthetic consumer-owned semantics; these application property names have no implicit ASH meaning.
enum NativeSliceContext {
    static func make(missingLast: Bool = false, unknownRule: Bool = false) throws -> SemanticContext {
        let source = "synthetic-native-qualification-v1"
        let rule = try AeostaraContract.RuleReference(ruleID: "ASH-STATE-STRUCTURE-001", sourceReference: NativeAshBindingProvider.source(for:"ASH-STATE-STRUCTURE-001"), ruleFamily: "STATE")
        let diagnostic = try AeostaraContract.DiagnosticReference(diagnosticID: "synthetic-input", chainRootReference: "synthetic-input", diagnosticKind: .MAPPING, ruleReferences: [rule])
        let inputEnvelope = try AeostaraContract.DiagnosticEnvelope(diagnosticID:diagnostic.diagnosticID,chainRootReference:diagnostic.chainRootReference,parentDiagnosticID:nil,diagnosticKind:.MAPPING,severity:.INFO,message:"Application declared projection provenance",ruleReferences:[rule],sourceReferences:[rule.sourceReference,source],evidence:.object([JSONMember("source",.string(source))]))
        let inputChain = try AeostaraContract.DiagnosticChain(chainID:"input-"+source,rootDiagnosticID:diagnostic.chainRootReference,diagnostics:[inputEnvelope])
        let pointers = try (0..<9).map { try JSONPointer("/signals/s\($0)") }
        let dimensions = try (0..<9).map { index -> AeostaraContract.SemanticDimensionBinding in
            let pointer = try AeostaraContract.JsonPointer(pointer: pointers[index].text, tokens: pointers[index].tokens,
                                                          pointsToMissing: missingLast && index == 8, pointsToNull: false)
            return try AeostaraContract.SemanticDimensionBinding(dimensionID: .init(rawValue: "b\(index)")!, sourcePointers: [pointer],
                                                                 mappingRule: unknownRule && index == 8 ? "UNREGISTERED" : "APP-BOOL-V1",
                                                                 evidence: [.object([JSONMember("source", .string(source))])], diagnosticReference: diagnostic)
        }
        let projection = try AeostaraContract.SemanticProjectionSpec(projectionSpecID: "synthetic-nine-bindings", dimensions: dimensions, version: "1", sourceReferences: [source])
        let mapping = RegisteredMappingRule(identifier: "APP-BOOL-V1", candidates: { _, evidence, _ in
            try evidence.map { evidence in
                guard let value = evidence.value?.boolValue else { throw SemanticInputFault.malformedEvidence }
                return value ? 1 : 0
            }
        }, materialize: { binding, target, _, _ in
            try binding.sourcePointers.map { MutationDraft(op: .replace, path: try JSONPointer($0.pointer), value: .bool(target == 1)) }
        })
        let zero = [Int](repeating: 0, count: 9)
        let hash = try CanonicalJSON.hash(.array(zero.map { .number(.integer(String($0))) }))
        let recognized = try AeostaraContract.AshState(stateID: "synthetic-recognized-zero", coordinates: zero, sourceReference: source, canonicalHash: hash)
        return try SemanticContext(applicationScopeID: source, projectionSpec: projection,
                                   intentConstraints: IntentConstraintSet(applicationScopeID: source, pointers: pointers, sourceReferences: [source]),
                                   knownValidStates: KnownValidStateContext(applicationScopeID: source, recognizedStates: [recognized], sourceReferences: [source]),
                                   mappingRules: MappingRuleRegistry([mapping]), transitions: TransitionRegistry([]), predicates: PredicateRuleRegistry([]), fallbackPolicies: FallbackPolicyRegistry([]),inputDiagnosticChains:[inputChain])
    }
    static func document(_ bits: [Int] = [Int](repeating: 0, count: 9), cosmetic: String = "same", missingLast: Bool = false) -> JSONValue {
        .object([JSONMember("signals", .object(bits.enumerated().filter { !missingLast || $0.offset != 8 }.map { JSONMember("s\($0.offset)", .bool($0.element == 1)) })), JSONMember("display", .string(cosmetic))])
    }
}

final class NativeSemanticSliceTests: XCTestCase {
    func testSurfaceDifferenceDoesNotAuthorizeRecovery() throws {
        let engine = NativeHealingEngine(context: try NativeSliceContext.make(), timestampProvider: { "2026-10-11T00:00:00Z" })
        let result = try engine.prepare(observed: NativeSliceContext.document(cosmetic: "before"), desired: NativeSliceContext.document(cosmetic: "after"))
        XCTAssertEqual(result.observedState.surfaceDifferences.count, 1)
        XCTAssertEqual(result.stateClass, .STABLE)
        XCTAssertEqual(result.recoveryCategory, .NO_ACTION)
        XCTAssertFalse(result.dryRunResult.wouldMutate)
        XCTAssertTrue(result.dryRunResult.recoveryPlan.recoverySteps.isEmpty)
        XCTAssertEqual(result.auditChain.events.map { $0.eventSequence.intValue }, Array(1...result.auditChain.events.count).map(Optional.init))
        XCTAssertEqual(result.dryRunResult.diagnosticChain.diagnostics.first?.diagnosticID, result.dryRunResult.diagnosticChain.rootDiagnosticID)
    }

    func testMissingEvidenceReturnsTruthfulDiagnosticFailure() throws {
        let engine = NativeHealingEngine(context: try NativeSliceContext.make(missingLast: true), timestampProvider: { "2026-10-11T00:00:00Z" })
        XCTAssertThrowsError(try engine.prepare(observed: NativeSliceContext.document(missingLast: true), desired: NativeSliceContext.document())) { error in
            guard let failure = error as? LifecycleFailure else { return XCTFail("Expected a typed diagnostic lifecycle failure") }
            XCTAssertEqual(failure.code, .missingEvidence)
            XCTAssertFalse(failure.diagnosticChain.diagnostics.isEmpty)
            XCTAssertEqual(failure.auditChain.events.last?.eventType, .RESULT)
        }
    }

    func testUnknownMappingRuleFailsClosed() throws {
        let engine = NativeHealingEngine(context: try NativeSliceContext.make(unknownRule: true), timestampProvider: { "2026-10-11T00:00:00Z" })
        XCTAssertThrowsError(try engine.prepare(observed: NativeSliceContext.document(), desired: NativeSliceContext.document())) {
            XCTAssertEqual(($0 as? LifecycleFailure)?.code, .unknownMappingRule)
        }
    }

    func testEqualDocumentsCanBeSemanticallyIncompatible() throws {
        let document = NativeSliceContext.document([0,0,0,0,0,0,0,0,1])
        let engine = NativeHealingEngine(context: try NativeSliceContext.make(), timestampProvider: { "2026-10-11T00:00:00Z" })
        let result = try engine.prepare(observed: document, desired: document)
        XCTAssertTrue(result.observedState.surfaceDifferences.isEmpty)
        XCTAssertEqual(result.stateClass, .FAILED)
        XCTAssertEqual(result.recoveryCategory, .ESCALATION_REQUIRED)
        XCTAssertFalse(result.dryRunResult.wouldMutate)
    }

    func testCompatibleNormalizationUsesCanonicalCodeword() throws {
        let engine = NativeHealingEngine(context: try NativeSliceContext.make(), timestampProvider: { "2026-10-11T00:00:00Z" })
        let result = try engine.prepare(observed: NativeSliceContext.document([1,1,1,1,0,0,0,0,0]), desired: NativeSliceContext.document())
        XCTAssertEqual(result.stateClass, .UNSTABLE)
        XCTAssertEqual(result.recoveryCategory, .NORMALIZE_STATE)
        XCTAssertTrue(result.dryRunResult.wouldMutate)
        XCTAssertEqual(result.dryRunResult.recoveryPlan.recoverySteps[0].jsonMutationOperations.count, 4)
        XCTAssertEqual(result.dryRunResult.verificationPlan.expectedSemanticState.coordinates, [Int](repeating: 0, count: 9))
    }

    func testByteDistinctUnicodeMembersAndPointerIdentity() throws {
        let value = try CanonicalJSON.parse("{\"é\":1,\"e\\u0301\":2,\"\":{},\"a.b\":null,\"a/b~c\":[true]}")
        XCTAssertEqual(value.objectMembers?.count, 5)
        XCTAssertEqual(try JSONPointer("/é").resolve(in: value)?.integerValue, 1)
        XCTAssertEqual(try JSONPointer("/e\u{301}").resolve(in: value)?.integerValue, 2)
        XCTAssertEqual(try JSONPointer("/").resolve(in: value), .object([]))
        XCTAssertEqual(try JSONPointer("/a.b").resolve(in: value), .null)
        XCTAssertEqual(try JSONPointer("/a~1b~0c/0").resolve(in: value), .bool(true))
        XCTAssertEqual(try CanonicalJSON.parse(CanonicalJSON.encode(value)), value)
        XCTAssertThrowsError(try CanonicalJSON.parse("{\"a\":1,\"\\u0061\":2}"))
    }

    func testCanonicalNumberAndBooleanIdentity() throws {
        XCTAssertNotEqual(try CanonicalJSON.parse("1"), try CanonicalJSON.parse("true"))
        XCTAssertNotEqual(try CanonicalJSON.parse("1"), try CanonicalJSON.parse("1.0"))
        XCTAssertEqual(try CanonicalJSON.text(CanonicalJSON.parse("123456789012345678901234567890")), "123456789012345678901234567890")
        XCTAssertEqual(try CanonicalJSON.hash(CanonicalJSON.parse("{\"b\":1,\"a\":[2,3]}")), "2aae3bfa906be39530e7d7a4aa90a7e6d4f29c33e3ac80e1c3b05598c5953c04")
        XCTAssertEqual(try JSONInteger(jsonValue:CanonicalJSON.parse("1e999")).decimalText,"1"+String(repeating:"0",count:999))
        XCTAssertThrowsError(try CanonicalJSON.parse("1e999999999999999999999"))
    }

    func testExhaustiveCanonicalCodewordOrbits() throws {
        let codewords = NativeAshBindingProvider.canonicalCodewords
        XCTAssertEqual(codewords.count, 16)
        XCTAssertEqual(Set(codewords).count, 16)
        XCTAssertTrue(codewords.contains([Int](repeating: 0, count: 9)))
        let binding = NativeAshBindingProvider(context: try NativeSliceContext.make())
        var representatives = Set<[Int]>()
        for value in 0..<512 {
            let state = (0..<9).map { (value >> (8-$0)) & 1 }
            let orbit = try binding.orbit(of: state)
            XCTAssertEqual(Set(orbit).count, 16)
            representatives.insert(orbit[0])
            for codeword in codewords {
                XCTAssertEqual(try binding.orbit(of: NativeAshBindingProvider.xor(state, codeword)), orbit)
            }
        }
        XCTAssertEqual(representatives.count, 32)
        for a in codewords {
            XCTAssertEqual(a.reduce(0,+) % 4, 0)
            for b in codewords { XCTAssertTrue(codewords.contains(try NativeAshBindingProvider.xor(a,b))) }
        }
    }
}
