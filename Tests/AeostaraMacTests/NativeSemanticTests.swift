import Foundation
import CryptoKit
import XCTest
import AeostaraMacDomain
import AeostaraMacServices
import AeostaraMacDevelopmentDiagnostics

final class NativeSemanticTests: XCTestCase {
    private let pointers = ["/runtime/enabled", "/storage/encrypted", "/network/reachable", "/security/trusted", "/service/healthy", "/cache/fresh", "/identity/bound", "/schedule/active", "/integrity/verified"]
    private func input(_ bits: [Int], label: String = "same") throws -> Data {
        let names = [("runtime", "enabled"), ("storage", "encrypted"), ("network", "reachable"), ("security", "trusted"), ("service", "healthy"), ("cache", "fresh"), ("identity", "bound"), ("schedule", "active"), ("integrity", "verified")]
        return try JSONValue.object(zip(names, bits).map { pair, bit in
            JSONMember(pair.0, .object([JSONMember(pair.1, .bool(bit == 1))]))
        } + [JSONMember("display", .object([JSONMember("label", .string(label))]))]).canonicalData()
    }
    private func reference() throws -> AeostaraContract.DiagnosticReference {
        try .init(diagnosticID: "input-root", chainRootReference: "input-root", diagnosticKind: .mapping,
            ruleReferences: [.init(ruleID: "ASH-STATE-STRUCTURE-001", sourceReference: NativeAshBindingProvider.sourceReference, ruleFamily: "STATE")])
    }
    private func context(rule: String = "APP-BOOL", mapping: (any SemanticMappingRule)? = nil,
                         fallbackPolicies: [NativeFallbackPolicy] = [], predicates: [SemanticPredicate] = [], transitions: [RegisteredTransition] = []) throws -> SemanticContext {
        let ref = try reference()

        let inputEnvelope = try AeostaraContract.DiagnosticEnvelope(diagnosticID: ref.diagnosticID, chainRootReference: ref.chainRootReference, parentDiagnosticID: nil, diagnosticKind: .mapping, severity: .info, message: "Application declares explicit projection bindings", ruleReferences: ref.ruleReferences, sourceReferences: ["explicit-test-application"], evidence: .object([JSONMember("declaration", .string("explicit-application-projection"))]))
        let inputChain = try AeostaraContract.DiagnosticChain(chainID: "application-input", rootDiagnosticID: ref.diagnosticID, diagnostics: [inputEnvelope])
        let bindings = try pointers.enumerated().map { i, path in
            try AeostaraContract.SemanticDimensionBinding(dimensionID: .init(rawValue: "b\(i)")!,
                sourcePointers: [.init(pointer: path, tokens: JSONValue.pointerTokens(path), pointsToMissing: false, pointsToNull: false)],
                mappingRule: rule, evidence: [.object([JSONMember("source", .string("explicit-test-application"))])], diagnosticReference: ref)
        }
        let spec = try AeostaraContract.SemanticProjectionSpec(projectionSpecID: "application-bools-v1", dimensions: bindings, version: "1", sourceReferences: ["explicit-test-application"])
        return try SemanticContext(applicationScope: "native-test-scope", projectionSpec: spec,
            intentConstraints: .init(scopeID: "native-test-scope", pointers: pointers, sourceReferences: ["explicit-test-application"]),
            knownValidStates: .init(scopeID: "native-test-scope", states: [[Int](repeating: 0, count: 9)], sourceReferences: ["explicit-test-recognition"]),
            mappingRules: [mapping ?? BooleanMappingRule(identifier: "APP-BOOL", sourceReference: "explicit-test-application")], transitions: transitions, fallbackPolicies: fallbackPolicies, predicates: predicates, inputDiagnosticChains: [inputChain])
    }
    private func policy() throws -> AeostaraContract.PolicyBundle {
        try .init(policyBundleID: "test-policy", sourceReferences: ["explicit-test-application"], rules: [.object([JSONMember("effect", .string("ALLOW"))])], bundleHash: "test-policy-shape-only")
    }
    private func engine(_ bits: [Int], label: String = "same", context: SemanticContext? = nil, recorder: (any DiagnosticRecording)? = nil) throws -> NativeHealingEngine {
        try .init(context: context ?? self.context(), observed: .init(documentID: "observed-test", sourceReference: "synthetic-test-input", data: input(bits, label: label)),
            desired: .init(documentID: "desired-test", sourceReference: "synthetic-test-intent", data: input([Int](repeating: 0, count: 9))), recorder: recorder)
    }
    func testDeclaredCLIContextLoadsExplicitMappings() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("fixtures/cli_semantic_context.template.json")
        let raw = try JSONValue.parse(Data(contentsOf: file))
        guard case .object(let fields) = raw else { return XCTFail("Expected object") }
        let loaded = try NativeCLIContext(data: JSONValue.object(fields.map { $0.name == "resourceRoot" ? JSONMember($0.name, .string("/tmp")) : $0 }).canonicalData())
        XCTAssertEqual(loaded.context.projectionSpec.dimensions.count, 9)
    }
    func testStableCosmeticDifferenceDoesNotBecomeMutation() throws {
        let engine = try engine([Int](repeating: 0, count: 9), label: "cosmetic-difference")
        XCTAssertEqual(try engine.observedState().surfaceDifferences.count, 1)
        let result = try engine.dryRun(policyBundle: policy())
        XCTAssertEqual(result.recoveryPlan.stateClass, .stable)
        XCTAssertEqual(result.recoveryPlan.recoveryCategory, .noAction)
        XCTAssertFalse(result.wouldMutate)
        XCTAssertTrue(result.recoveryPlan.recoverySteps.isEmpty)
        XCTAssertFalse(result.recoveryPlan.requiresPolicyGate)
        XCTAssertFalse(result.recoveryPlan.requiresBackup)
        XCTAssertEqual(result.diagnosticChain.rootDiagnosticID, result.diagnosticChain.diagnostics.first?.diagnosticID)
        for (i, diagnostic) in result.diagnosticChain.diagnostics.enumerated() {
            XCTAssertEqual(diagnostic.chainRootReference, result.diagnosticChain.rootDiagnosticID)
            XCTAssertEqual(diagnostic.parentDiagnosticID, i == 0 ? nil : result.diagnosticChain.diagnostics[i - 1].diagnosticID)
        }
        XCTAssertEqual(try ContractCoding.canonicalDecode(AeostaraContract.DryRunResult.self, from: ContractCoding.canonicalEncode(result)), result)
    }
    func testCanonicalCompatibilityComputesNormalizationFromActualProof() throws {
        let input = [1,1,1,1,0,0,0,0,0]
        let engine = try engine(input)
        let result = try engine.dryRun(policyBundle: policy())
        XCTAssertEqual(result.recoveryPlan.stateClass, .unstable)
        XCTAssertEqual(result.recoveryPlan.recoveryCategory, .normalizeState)
        XCTAssertEqual(result.recoveryPlan.recoverySteps.flatMap(\.jsonMutationOperations).count, 4)
        XCTAssertTrue(result.wouldMutate)
        XCTAssertEqual(result.verificationPlan.expectedSemanticState.coordinates, [Int](repeating: 0, count: 9))
        XCTAssertEqual(engine.observed.value, try JSONValue.parse(self.input(input)))
        XCTAssertEqual(try engine.dryRun(policyBundle: policy()).recoveryPlan.planHash, result.recoveryPlan.planHash)
    }
    func testUnknownMappingProducesDiagnosticFailureAndSafeCapture() throws {
        let recorder = try ReleaseDiagnosticRecorder()
        let engine = try engine([Int](repeating: 0, count: 9), context: context(rule: "UNREGISTERED"), recorder: recorder)
        XCTAssertThrowsError(try engine.dryRun(policyBundle: policy())) { error in
            guard let failure = error as? LifecycleFailure else { return XCTFail("Missing typed lifecycle failure") }
            XCTAssertEqual(failure.code, .unknownMappingRule)
            XCTAssertEqual(failure.failedStage, .project)
            XCTAssertEqual(failure.diagnosticEnvelope.evidence.member("status"), .string("BLOCKED"))
            do { _ = try ContractCoding.canonicalEncode(failure.diagnosticChain) }
            catch { XCTFail("Invalid serialized failure chain: \(error)") }
        }
        let snapshot = recorder.snapshot()
        XCTAssertTrue(snapshot.isValid)
        XCTAssertTrue(snapshot.records.contains { $0.event.stage == .project && $0.event.outcome == .failed && $0.event.fault?.code == .mapping })
        XCTAssertEqual(snapshot.incidents.count, 1)
        XCTAssertTrue(snapshot.records.allSatisfy { $0.details == nil })
    }
    func testActualPlanningSuccessAndFailureExportBothDiagnosticProfiles() throws {
        let suppliedRoot = ProcessInfo.processInfo.environment["AEOSTARA_FIRST_SLICE_EVIDENCE_ROOT"]
        let parent = suppliedRoot.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? FileManager.default.temporaryDirectory
        let runRoot = parent.appendingPathComponent("MacFirstSlice-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: runRoot, withIntermediateDirectories: true)
        defer { if suppliedRoot == nil { try? FileManager.default.removeItem(at: runRoot) } }
        let privacySentinel = "FIRST_SLICE_RAW_INPUT_MUST_STAY_OUT_OF_DIAGNOSTIC_EXPORT"
        var manifestCases: [JSONValue] = []
        for profile in [DiagnosticProfile.release, .development] {
            for succeeds in [true, false] {
                let recorder: any DiagnosticRecording = profile == .release ? try ReleaseDiagnosticRecorder() : try DevelopmentDiagnosticRecorder()
                let runtime = try engine([1,1,1,1,0,0,0,0,0], label: privacySentinel,
                    context: context(rule: succeeds ? "APP-BOOL" : "UNREGISTERED"), recorder: recorder)
                let behavioralOutput: Data
                if succeeds {
                    let result = try runtime.dryRun(policyBundle: policy())
                    XCTAssertEqual(result.recoveryPlan.stateClass, .unstable)
                    XCTAssertEqual(result.recoveryPlan.recoveryCategory, .normalizeState)
                    XCTAssertEqual(result.recoveryPlan.recoverySteps.flatMap(\.jsonMutationOperations).count, 4)
                    behavioralOutput = try ContractCoding.canonicalEncode(result)
                } else {
                    do {
                        _ = try runtime.dryRun(policyBundle: policy())
                        XCTFail("Unknown registered mapping must fail before diagnosis and planning")
                        continue
                    } catch let failure as LifecycleFailure {
                        XCTAssertEqual(failure.code, .unknownMappingRule)
                        XCTAssertEqual(failure.failedStage, .project)
                        XCTAssertEqual(failure.diagnosticEnvelope.evidence.member("status"), .string("BLOCKED"))
                        behavioralOutput = try ContractCoding.canonicalEncode(failure.diagnosticChain)
                    }
                }
                let nativeCapture = recorder.snapshot()
                XCTAssertTrue(nativeCapture.isValid)
                XCTAssertEqual(nativeCapture.incidents.count, 1)
                XCTAssertEqual(nativeCapture.records.first?.event.stage, .observe)
                XCTAssertEqual(nativeCapture.records.last?.event.stage, succeeds ? .plan : .project)
                XCTAssertEqual(nativeCapture.records.last?.event.outcome, succeeds ? .succeeded : .failed)
                XCTAssertEqual(nativeCapture.records.last?.event.fault?.code, succeeds ? nil : .mapping)
                XCTAssertEqual(nativeCapture.records.filter { $0.event.stage == .diagnose }.count, succeeds ? 1 : 0)
                XCTAssertEqual(nativeCapture.records.filter { $0.event.stage == .plan }.count, succeeds ? 1 : 0)
                XCTAssertFalse(nativeCapture.records.contains { $0.event.stage == .mutate || $0.event.stage == .backup || $0.event.stage == .verify })
                for (index, record) in nativeCapture.records.enumerated() {
                    XCTAssertEqual(record.event.causeEventIDs, index == 0 ? [] : [nativeCapture.records[index - 1].event.eventID])
                    XCTAssertEqual(record.omittedReferences, 0)
                }
                if profile == .release {
                    XCTAssertTrue(nativeCapture.records.allSatisfy { $0.details == nil && $0.stackFrames.isEmpty })
                } else {
                    XCTAssertTrue(nativeCapture.records.allSatisfy { $0.details?.observedFieldCount == 9 && $0.details?.ruleCount == 1 })
                }
                let caseID = profile.rawValue + (succeeds ? "-success" : "-mapping-failure")
                let caseRoot = runRoot.appendingPathComponent(caseID, isDirectory: true)
                try FileManager.default.createDirectory(at: caseRoot, withIntermediateDirectories: false)
                let bundle = try DiagnosticExporter().export(recording: recorder, to: caseRoot)
                let jsonBytes = try Data(contentsOf: bundle.json)
                let markdownBytes = try Data(contentsOf: bundle.markdown)
                let exported = try JSONDecoder().decode(DiagnosticSnapshot.self, from: jsonBytes)
                let markdown = try String(contentsOf: bundle.markdown, encoding: .utf8)
                XCTAssertTrue(exported.isValid)
                XCTAssertEqual(exported.profile, profile)
                XCTAssertEqual(exported.snapshotID, bundle.snapshotID)
                XCTAssertEqual(Array(exported.records.prefix(nativeCapture.records.count)), nativeCapture.records)
                XCTAssertEqual(exported.records.count, nativeCapture.records.count + 1)
                XCTAssertEqual(exported.records.last?.event.stage, .export)
                XCTAssertEqual(exported.records.last?.event.outcome, .started)
                XCTAssertFalse(String(decoding: jsonBytes, as: UTF8.self).contains(privacySentinel))
                XCTAssertFalse(markdown.contains(privacySentinel))
                func ids(_ pattern: String) throws -> Set<String> {
                    let expression = try NSRegularExpression(pattern: pattern)
                    return Set(expression.matches(in: markdown, range: NSRange(markdown.startIndex..., in: markdown)).compactMap {
                        Range($0.range(at: 1), in: markdown).map { String(markdown[$0]) }
                    })
                }
                XCTAssertEqual(try ids("### Event `([A-Fa-f0-9-]+)`"), Set(exported.records.map { $0.event.eventID.uuidString }))
                XCTAssertEqual(try ids("## Incident `([A-Fa-f0-9-]+)`"), Set(exported.incidentIDs.map(\.uuidString)))
                struct Completion: Decodable {
                    struct Part: Decodable { let name: String; let bytes: Int; let sha256: String }
                    let snapshotID: UUID; let eventCount: Int; let incidentIDs: [UUID]; let parts: [Part]
                }
                let completion = try JSONDecoder().decode(Completion.self, from: Data(contentsOf: bundle.completionMetadata))
                XCTAssertEqual(completion.snapshotID, exported.snapshotID)
                XCTAssertEqual(completion.eventCount, exported.records.count)
                XCTAssertEqual(completion.incidentIDs, exported.incidentIDs)
                for (name, bytes) in [("Diagnostics.json", jsonBytes), ("Diagnostics.md", markdownBytes)] {
                    let part = try XCTUnwrap(completion.parts.first { $0.name == name })
                    XCTAssertEqual(part.bytes, bytes.count)
                    XCTAssertEqual(part.sha256, SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined())
                }
                let finalCapture = recorder.snapshot()
                XCTAssertEqual(finalCapture.records.last?.event.stage, .export)
                XCTAssertEqual(finalCapture.records.last?.event.outcome, .succeeded)
                XCTAssertEqual(finalCapture.health.exportFailures, 0)
                try behavioralOutput.write(to: caseRoot.appendingPathComponent("BehavioralOutput.json"), options: .atomic)
                manifestCases.append(.object([
                    JSONMember("case", .string(caseID)), JSONMember("snapshotID", .string(bundle.snapshotID.uuidString)),
                    JSONMember("bundle", .string(bundle.directory.lastPathComponent)),
                    JSONMember("nativeEventCount", .integer(String(nativeCapture.records.count))),
                    JSONMember("exportedEventCount", .integer(String(exported.records.count))),
                    JSONMember("behavioralContract", .string(succeeds ? "DryRunResult" : "DiagnosticChain")),
                    JSONMember("behavioralOutputSHA256", .string(SHA256.hash(data: behavioralOutput).map { String(format: "%02x", $0) }.joined()))
                ]))
            }
        }
        let manifest = JSONValue.object([
            JSONMember("scope", .string("Actual native pure planning and mapping failure capture/export; no resource mutation or healing qualification")),
            JSONMember("test", .string("NativeSemanticTests.testActualPlanningSuccessAndFailureExportBothDiagnosticProfiles")),
            JSONMember("cases", .array(manifestCases))
        ])
        try manifest.canonicalData().write(to: runRoot.appendingPathComponent("Manifest.json"), options: .atomic)
    }
    func testFabricatedEmptySurfaceEvidenceRejectedBeforeProjection() throws {
        let engine = try engine([1,1,1,1,0,0,0,0,0])
        let real = try engine.observedState()
        let falseEvidence = try AeostaraContract.ObservedSystemState(observedSystemStateID: real.observedSystemStateID, documentReference: real.documentReference, surfaceDifferences: [], diagnosticReference: real.diagnosticReference)
        XCTAssertThrowsError(try engine.dryRun(observedState: falseEvidence, desiredIntent: engine.desiredIntent(), projectionSpec: engine.context.projectionSpec, policyBundle: policy()))
    }
    func testFixedASHAlgebraExhaustiveStatesAndOrbits() throws {
        let ash = NativeAshBindingProvider(), known = try context().knownValidStates
        let words = NativeAshBindingProvider.codewords
        XCTAssertEqual(Set(words).count, 16)
        XCTAssertEqual(words.filter { $0.reduce(0,+) == 4 }.count, 14)
        XCTAssertTrue(words.allSatisfy { $0 == [Int](repeating: 0, count: 9) || $0.reduce(0,+) >= 4 })
        for a in words { for b in words { XCTAssertTrue(words.contains(try ash.transform(a, codeword: b))) } }
        var orbits = Set<String>()
        for integer in 0..<512 {
            let state = (0..<9).map { (integer >> (8-$0)) & 1 }
            let orbit = try ash.orbit(of: state)
            XCTAssertEqual(Set(orbit).count, 16)
            orbits.insert(orbit[0].map(String.init).joined())
            let status = try ash.admissibility(of: state, knownValid: known)
            XCTAssertEqual(status == .valid, integer == 0)
            XCTAssertEqual(status != .transformationIncompatible, words.contains(state))
            for word in words { XCTAssertEqual(try ash.orbit(of: ash.transform(state, codeword: word)), orbit) }
        }
        XCTAssertEqual(orbits.count, 32)
    }
    func testCanonicalKeysPointersAndNumbersPreserveIdentity() throws {
        let data = Data(#"{"é":1,"e\u0301":2,"":{},"a.b":[],"a/b":{"~":null},"bool":true,"int":1,"real":1.0}"#.utf8)
        let value = try JSONValue.parse(data)
        XCTAssertEqual(try value.resolve(pointer: "/é"), .integer("1"))
        XCTAssertEqual(try value.resolve(pointer: "/e\u{301}"), .integer("2"))
        XCTAssertEqual(try value.resolve(pointer: "/"), .object([]))
        XCTAssertEqual(try value.resolve(pointer: "/a.b"), .array([]))
        XCTAssertEqual(try value.resolve(pointer: "/a~1b/~0"), .null)
        XCTAssertNil(try value.resolve(pointer: "/missing"))
        XCTAssertNotEqual(value.member("bool"), value.member("int"))
        XCTAssertNotEqual(value.member("int"), value.member("real"))
        XCTAssertEqual(try JSONValue.parse(value.canonicalData()), value)
        XCTAssertThrowsError(try JSONValue.parse(Data(#"{"a":1,"\u0061":2}"#.utf8)))
        XCTAssertThrowsError(try JSONValue.parse(Data(#"{"x":"\uD800"}"#.utf8)))
        XCTAssertEqual(try JSONValue.parse(Data("9007199254740993".utf8)), .integer("9007199254740993"))
        XCTAssertThrowsError(try JSONValue.parse(Data("1e9999".utf8)))
    }
    func testSignedUnicodeEscapesAreMalformedJSON() throws {
        XCTAssertThrowsError(try JSONValue.parse(Data(#"{"x":"\u+041"}"#.utf8)))
        XCTAssertThrowsError(try JSONValue.parse(Data(#"{"x":"\u-000"}"#.utf8)))
        XCTAssertEqual(try JSONValue.parse(Data(#"{"x":"\u0041"}"#.utf8)).member("x"), .string("A"))
    }
    func testCanonicalContractCodecRejectsUnknownFieldsAndKeepsUnicodeFreeValues() throws {
        let rule = try AeostaraContract.RuleReference(ruleID: "ASH-STATE-STRUCTURE-001", sourceReference: "test", ruleFamily: "STATE")
        let ref = try reference()
        let free = try JSONValue.parse(Data(#"{"é":1,"e\u0301":2}"#.utf8))
        let mutation = try AeostaraContract.JsonMutationOperation(operationID: "test-op", op: .replace,
            path: .init(pointer: "/value", tokens: ["value"], pointsToMissing: false, pointsToNull: false), value: free, preconditionHash: "test", diagnosticReference: ref)
        let data = try ContractCoding.canonicalEncode(mutation)
        XCTAssertEqual(try ContractCoding.canonicalDecode(AeostaraContract.JsonMutationOperation.self, from: data).value, free)
        let valid = rule.contractJSON
        guard case .object(let members) = valid else { return XCTFail("Expected object") }
        let unexpected = JSONValue.object(members + [JSONMember("unexpected", .bool(true))])
        XCTAssertThrowsError(try ContractCoding.canonicalDecode(AeostaraContract.RuleReference.self, from: unexpected.canonicalData()))
        XCTAssertThrowsError(try AeostaraContract.AshState(stateID: "invalid", coordinates: [0,1], sourceReference: "test", canonicalHash: "test"))
        XCTAssertThrowsError(try AeostaraContract.SafeHaltDecision(safeHaltDecisionID: "invalid", terminal: false, blockedTransitions: ["mutation"], diagnosticReference: ref))
    }
    func testPinnedFiniteNumericCanonicalCorpus() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "canonical_numeric_corpus", withExtension: "json", subdirectory: "Fixtures"))
        struct Corpus: Decodable { struct Entry: Decodable { let input: String; let canonical: String }; let cases: [Entry] }
        let corpus = try JSONDecoder().decode(Corpus.self, from: Data(contentsOf: url))
        XCTAssertEqual(corpus.cases.count, 28)
        for entry in corpus.cases {
            XCTAssertEqual(try JSONValue.parse(Data(entry.input.utf8)).canonicalText(), entry.canonical, entry.input)
        }
    }
    private func withNativeService(bits: [Int] = [1,1,1,1,0,0,0,0,0],
        fault: NativeTestIO.Fault? = nil, permits: Bool = true, registeredFallback: Bool = false, recorder: (any DiagnosticRecording)? = nil,
        body: (NativeHealingService, NativeTestIO, NativeResourcePaths) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("AeostaraLifecycleTest-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let observed = root.appendingPathComponent("config.json"), desired = root.appendingPathComponent("desired.json")
        try input(bits, label: "preserved-cosmetic").write(to: observed)
        try input([Int](repeating: 0, count: 9)).write(to: desired)
        let paths = try NativeResourcePaths(root: root, configuration: observed, desired: desired,
            backup: root.appendingPathComponent("unique-backup.json"), audit: root.appendingPathComponent("audit.jsonl"))
        let io = NativeTestIO(base: try ScopedNativeResourceIO(paths: paths), fault: fault)
        let policy = try NativePolicyContext.make(bundleID: "explicit-app-policy", rules: [
            .init(identifier: "permit-scoped-recovery", sourceReference: "explicit-test-application-policy") { _, _, _ in permits }
        ])
        let fallbacks = try registeredFallback ? ["Z", "A", "B"].enumerated().map { index, id in
            try NativeFallbackPolicy(policyID: id, orderingRank: index == 2 ? 2 : 1, candidate: [Int](repeating: 0, count: 9),
                applicabilityPredicates: ["same-observed-source"], validationPredicates: ["recognized-target"], sourceReferences: ["explicit-test-fallback-registry"])
        } : []
        let predicates: [SemanticPredicate] = registeredFallback ? [
            .init(identifier: "same-observed-source", sourceReference: "explicit-test-fallback-applicability") { actual, _, observed, _ in
                actual == bits && observed.value.member("display")?.member("label") == .string("preserved-cosmetic")
            },
            .init(identifier: "recognized-target", sourceReference: "explicit-test-fallback-validation") { _, target, _, _ in target == [Int](repeating: 0, count: 9) }
        ] : []
        let service = NativeHealingService(context: try context(fallbackPolicies: fallbacks, predicates: predicates), io: io, policy: policy,
            containmentPolicy: try .init(sourceReference: "explicit-test-observation-only-containment", allowedOperations: ["observe", "inspectDiagnostics", "exportDiagnostics"]),
            recorder: recorder, timestampProvider: { "2026-10-11T14:00:00Z" })
        try body(service, io, paths)
    }
    func testNativeHealActuallyWritesVerifiesAuditsAndKeepsExactBackup() throws {
        try withNativeService { service, io, paths in
            let original = try Data(contentsOf: paths.configuration)
            let result = try service.heal()
            XCTAssertEqual(result.status, .healed)
            XCTAssertEqual(service.lifecycleState, .active)
            XCTAssertEqual(try Data(contentsOf: paths.backup), original)
            let actual = try JSONValue.parse(Data(contentsOf: paths.configuration))
            XCTAssertEqual(try actual.resolve(pointer: "/runtime/enabled"), .bool(false))
            XCTAssertEqual(try actual.resolve(pointer: "/display/label"), .string("preserved-cosmetic"))
            XCTAssertEqual(service.lastReceipt?.verification?.status, .passed)
            XCTAssertNil(service.lastReceipt?.rollback)
            XCTAssertEqual(result.auditChain.events.map { $0.eventSequence.intValue }, Array(1...result.auditChain.events.count).map(Optional.some))
            XCTAssertEqual(result.auditChain.events.map(\.eventType), [.observe, .normalize, .project, .diagnose, .classify, .plan, .policyGate, .backup, .execute, .verify, .result])
            let persisted = try io.read(.audit).split(separator: 10).map { try ContractCoding.canonicalDecode(AeostaraContract.AuditEvent.self, from: Data($0)) }
            XCTAssertEqual(persisted, result.auditChain.events)
            XCTAssertEqual(try ContractCoding.canonicalDecode(AeostaraContract.HealResult.self, from: ContractCoding.canonicalEncode(result)), result)
        }
    }
    func testNativeDryRunCreatesNoLeaseBackupAuditOrMutation() throws {
        try withNativeService { service, _, paths in
            let original = try Data(contentsOf: paths.configuration)
            XCTAssertTrue(try service.dryRun().wouldMutate)
            XCTAssertEqual(try Data(contentsOf: paths.configuration), original)
            XCTAssertFalse(FileManager.default.fileExists(atPath: paths.backup.path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: paths.audit.path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: paths.root.appendingPathComponent(".aeostara-resource-locks").path))
        }
    }
    func testPolicyBlockCannotBackupOrMutateAndPreservesContainmentReason() throws {
        try withNativeService(permits: false) { service, _, paths in
            let original = try Data(contentsOf: paths.configuration)
            let result = try service.heal()
            XCTAssertEqual(result.status, .escalated)
            XCTAssertEqual(service.lifecycleState, .contained)
            XCTAssertFalse(FileManager.default.fileExists(atPath: paths.backup.path))
            XCTAssertEqual(try Data(contentsOf: paths.configuration), original)
            XCTAssertTrue(result.diagnosticChain.diagnostics.contains { $0.evidence.member("failureCode") == .string("policyBlocked") })
            XCTAssertFalse(result.auditChain.events.contains { $0.eventType == .execute })
        }
    }
    func testMandatoryAuditFailureBeforeBackupPreventsMutation() throws {
        try withNativeService(fault: .audit(1)) { service, _, paths in
            let original = try Data(contentsOf: paths.configuration)
            XCTAssertThrowsError(try service.heal()) { XCTAssertEqual(($0 as? LifecycleFailure)?.code, .auditFailed) }
            XCTAssertEqual(try Data(contentsOf: paths.configuration), original)
            XCTAssertFalse(FileManager.default.fileExists(atPath: paths.backup.path))
            XCTAssertEqual(service.lifecycleState, .contained)
        }
    }
    func testAuditFailureAfterMutationUsesOnlyAuthorizedVerifiedRollback() throws {
        try withNativeService(fault: .audit(9)) { service, _, paths in
            let original = try Data(contentsOf: paths.configuration)
            XCTAssertThrowsError(try service.heal()) { XCTAssertEqual(($0 as? LifecycleFailure)?.code, .auditFailed) }
            XCTAssertEqual(try Data(contentsOf: paths.configuration), original)
            XCTAssertEqual(service.lastReceipt?.rollback?.status, .succeeded)
            XCTAssertNil(service.lastReceipt?.verification)
        }
    }
    func testVerificationCorruptionIsObservedAndExactRollbackIsVerified() throws {
        try withNativeService(fault: .corruptAfterWrite) { service, _, paths in
            let original = try Data(contentsOf: paths.configuration)
            let result = try service.heal()
            XCTAssertEqual(result.status, .escalated)
            XCTAssertEqual(service.lastReceipt?.verification?.status, .failed)
            XCTAssertEqual(service.lastReceipt?.rollback?.status, .succeeded)
            XCTAssertEqual(try Data(contentsOf: paths.configuration), original)
            XCTAssertTrue(result.auditChain.events.contains { $0.eventType == .rollback })
            XCTAssertTrue(result.diagnosticChain.diagnostics.contains { $0.evidence.member("failureCode") == .string("verificationFailed") })
        }
    }
    func testPartialExecutionFailureAndFailedRollbackNeverClaimRestoration() throws {
        try withNativeService(fault: .partialWriteAndFailedRollback) { service, _, paths in
            let original = try Data(contentsOf: paths.configuration)
            let result = try service.heal()
            XCTAssertEqual(result.status, .escalated)
            XCTAssertNil(service.lastReceipt?.rollback)
            XCTAssertNotEqual(try Data(contentsOf: paths.configuration), original)
            XCTAssertTrue(result.diagnosticChain.diagnostics.contains { $0.evidence.member("failureCode") == .string("rollbackFailed") })
            XCTAssertFalse(result.auditChain.events.contains { $0.eventType == .rollback })
        }
    }
    func testFreshLeaseObservationRejectsExternalChangeBeforeBackup() throws {
        try withNativeService(fault: .staleOnAcquire) { service, _, paths in
            XCTAssertThrowsError(try service.heal()) { XCTAssertEqual(($0 as? LifecycleFailure)?.code, .staleSnapshot) }
            XCTAssertEqual(try Data(contentsOf: paths.configuration), Data("{\"external\":true}".utf8))
            XCTAssertFalse(FileManager.default.fileExists(atPath: paths.backup.path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: paths.audit.path))
        }
    }
    func testStableNativeHealPreservesCosmeticDifferenceWithoutBackup() throws {
        try withNativeService(bits: [Int](repeating: 0, count: 9)) { service, _, paths in
            let original = try Data(contentsOf: paths.configuration)
            let result = try service.heal()
            XCTAssertEqual(result.status, .noAction)
            XCTAssertEqual(try Data(contentsOf: paths.configuration), original)
            XCTAssertFalse(FileManager.default.fileExists(atPath: paths.backup.path))
            XCTAssertFalse(result.recoveryPlan.requiresBackup)
            XCTAssertFalse(result.auditChain.events.contains { $0.eventType == .execute || $0.eventType == .backup || $0.eventType == .policyGate })
        }
    }
    func testStableNoActionStillEvaluatesProvidedDenyPolicy() throws {
        try withNativeService(bits: [Int](repeating: 0, count: 9), permits: false) { service, _, paths in
            let original = try Data(contentsOf: paths.configuration)
            let result = try service.heal()
            XCTAssertEqual(result.status, .escalated)
            XCTAssertEqual(service.lifecycleState, .contained)
            XCTAssertTrue(result.diagnosticChain.diagnostics.contains { $0.evidence.member("failureCode") == .string("policyBlocked") })
            XCTAssertEqual(try Data(contentsOf: paths.configuration), original)
            XCTAssertFalse(FileManager.default.fileExists(atPath: paths.backup.path))
        }
    }
    func testInitialIncompatibleStateRestoresRegisteredFallbackAcrossOrbit() throws {
        try withNativeService(bits: [0,0,0,0,0,0,0,0,1], registeredFallback: true) { service, _, _ in
            let result = try service.heal()
            XCTAssertEqual(result.status, .healed)
            XCTAssertEqual(result.recoveryPlan.stateClass, .degraded)
            XCTAssertEqual(result.recoveryPlan.recoveryCategory, .fallbackRequired)
            XCTAssertEqual(service.lastReceipt?.fallback?.selectedCandidateID, "A")
            XCTAssertEqual(service.lastReceipt?.verification?.status, .passed)
        }
    }
    func testFailedNormalizationRollsBackThenExecutesSeparatelyApprovedFallback() throws {
        try withNativeService(fault: .corruptAfterWrite, registeredFallback: true) { service, _, paths in
            let result = try service.heal()
            XCTAssertEqual(result.status, .healed)
            XCTAssertEqual(result.recoveryPlan.recoveryCategory, .fallbackRequired)
            XCTAssertEqual(service.lastReceipt?.rollback?.status, .succeeded)
            XCTAssertEqual(service.lastReceipt?.fallback?.selectedCandidateID, "A")
            XCTAssertEqual(service.lastReceipt?.fallback?.status, .selected)
            XCTAssertEqual(service.lastReceipt?.verification?.status, .passed)
            XCTAssertTrue(result.diagnosticChain.diagnostics.contains { $0.evidence.member("failureCode") == .string("verificationFailed") })
            XCTAssertTrue(result.auditChain.events.contains { $0.eventType == .rollback })
            XCTAssertTrue(result.auditChain.events.contains { $0.eventType == .fallback })
            XCTAssertEqual(result.auditChain.events.filter { $0.eventType == .policyGate }.count, 2)
            XCTAssertEqual(try JSONValue.parse(Data(contentsOf: paths.configuration)).resolve(pointer: "/integrity/verified"), .bool(false))
        }
    }
    func testContainmentBreachIsTerminalAndPreservesFrozenEvidence() throws {
        try withNativeService(permits: false) { service, io, paths in
            let original = try Data(contentsOf: paths.configuration)
            _ = try service.heal()
            XCTAssertEqual(service.lifecycleState, .contained)
            try service.authorizeRestrictedOperation("inspectDiagnostics")
            XCTAssertThrowsError(try service.authorizeRestrictedOperation("recovery")) { XCTAssertEqual(($0 as? LifecycleFailure)?.code, .containmentBreach) }
            XCTAssertEqual(service.lifecycleState, .safeHalt)
            XCTAssertTrue(service.lastReceipt?.safeHalt?.terminal == true)
            let persisted = try io.read(.audit).split(separator: 10).map { try ContractCoding.canonicalDecode(AeostaraContract.AuditEvent.self, from: Data($0)) }
            XCTAssertEqual(persisted.last?.eventType, .safeHalt)
            XCTAssertEqual(persisted, service.lastReceipt?.auditChain?.events)
            let frozen = try XCTUnwrap(service.lastReceipt?.diagnosticChain)
            XCTAssertThrowsError(try service.heal()) {
                XCTAssertEqual(($0 as? LifecycleFailure)?.code, .terminalHalt)
                XCTAssertEqual(($0 as? LifecycleFailure)?.diagnosticChain, frozen)
            }
            XCTAssertEqual(service.lastReceipt?.diagnosticChain, frozen)
            XCTAssertEqual(try Data(contentsOf: paths.configuration), original)
            XCTAssertEqual(try io.read(.audit).split(separator: 10).count, persisted.count)
            XCTAssertFalse(FileManager.default.fileExists(atPath: paths.backup.path))
        }
    }
    func testReentrantServiceRequestRejectsBeforeResourceAccess() throws {
        try withNativeService { service, io, _ in
            var rejected: LifecycleFailure?
            io.onAcquire = {
                do { _ = try service.heal(); XCTFail("Reentrant operation succeeded") }
                catch { rejected = error as? LifecycleFailure }
            }
            XCTAssertEqual(try service.heal().status, .healed)
            XCTAssertEqual(rejected?.code, .resourceBusy)
        }
    }
    func testContainedNormalRequestCannotUseEarlierPlanAndAuditsTerminalBreach() throws {
        try withNativeService(permits: false) { service, io, paths in
            let earlierPlan = try service.dryRun(), original = try io.read(.configuration)
            XCTAssertTrue(earlierPlan.wouldMutate)
            _ = try service.heal()
            XCTAssertEqual(service.lifecycleState, .contained)
            XCTAssertThrowsError(try service.heal()) { XCTAssertEqual(($0 as? LifecycleFailure)?.code, .containmentBreach) }
            XCTAssertEqual(service.lifecycleState, .safeHalt)
            XCTAssertEqual(try io.read(.configuration), original)
            XCTAssertFalse(FileManager.default.fileExists(atPath: paths.backup.path))
            let persisted = try io.read(.audit).split(separator: 10).map { try ContractCoding.canonicalDecode(AeostaraContract.AuditEvent.self, from: Data($0)) }
            XCTAssertEqual(persisted.last?.eventType, .safeHalt)
            XCTAssertEqual(persisted, service.lastReceipt?.auditChain?.events)
        }
    }
    func testTerminalAuditFailureRemainsFailureAndFreezesWithoutMutation() throws {
        try withNativeService(permits: false) { service, io, paths in
            let original = try io.read(.configuration)
            _ = try service.heal()
            let priorEvents = try XCTUnwrap(service.lastReceipt?.auditChain?.events)
            io.onAudit = { throw NativeResourceError.partialWrite(5) }
            XCTAssertThrowsError(try service.authorizeRestrictedOperation("recovery")) { XCTAssertEqual(($0 as? LifecycleFailure)?.code, .auditFailed) }
            XCTAssertEqual(service.lifecycleState, .safeHalt)
            XCTAssertEqual(service.lastReceipt?.auditChain?.events, priorEvents)
            let frozen = try XCTUnwrap(service.lastReceipt?.diagnosticChain)
            XCTAssertThrowsError(try service.dryRun()) {
                XCTAssertEqual(($0 as? LifecycleFailure)?.code, .terminalHalt)
                XCTAssertEqual(($0 as? LifecycleFailure)?.diagnosticChain, frozen)
            }
            XCTAssertEqual(try io.read(.configuration), original)
            XCTAssertFalse(FileManager.default.fileExists(atPath: paths.backup.path))
        }
    }
    func testContainmentBreachRetainsActualTerminalTelemetryInBothProfiles() throws {
        let recorders: [any DiagnosticRecording] = [try ReleaseDiagnosticRecorder(), try DevelopmentDiagnosticRecorder()]
        for recorder in recorders {
            try withNativeService(permits: false, recorder: recorder) { service, io, paths in
                let original = try io.read(.configuration)
                _ = try service.heal()
                let prior = try XCTUnwrap(recorder.snapshot().records.last)
                XCTAssertThrowsError(try service.authorizeRestrictedOperation("recovery")) { XCTAssertEqual(($0 as? LifecycleFailure)?.code, .containmentBreach) }
                let snapshot = recorder.snapshot()
                let haltRecord: DiagnosticRecord? = snapshot.records.last { record in record.event.stage == DiagnosticStage.safeHalt && record.event.outcome == DiagnosticOutcome.halted }
                let halt = try XCTUnwrap(haltRecord)
                XCTAssertEqual(halt.event.incidentID, prior.event.incidentID)
                XCTAssertEqual(halt.event.parentOperationID, prior.event.operationID)
                XCTAssertEqual(halt.event.causeEventIDs, [prior.event.eventID])
                XCTAssertEqual(halt.event.fault?.code, .scopeViolation)
                XCTAssertEqual(service.lifecycleState, .safeHalt)
                XCTAssertEqual(try io.read(.configuration), original)
                let count = snapshot.records.count
                XCTAssertThrowsError(try service.dryRun()) { XCTAssertEqual(($0 as? LifecycleFailure)?.code, .terminalHalt) }
                XCTAssertEqual(recorder.snapshot().records.count, count)
                try retainTerminalPair(recorder, paths: paths)
            }
        }
    }
    func testContainmentBreachAuditFailureRetainsOriginalIncidentAndFailure() throws {
        let recorders: [any DiagnosticRecording] = [try ReleaseDiagnosticRecorder(), try DevelopmentDiagnosticRecorder()]
        for recorder in recorders {
            try withNativeService(permits: false, recorder: recorder) { service, io, paths in
                _ = try service.heal()
                let prior = try XCTUnwrap(recorder.snapshot().records.last)
                io.onAudit = { throw NativeResourceError.partialWrite(5) }
                XCTAssertThrowsError(try service.authorizeRestrictedOperation("recovery")) { XCTAssertEqual(($0 as? LifecycleFailure)?.code, .auditFailed) }
                let snapshot = recorder.snapshot()
                let haltRecord: DiagnosticRecord? = snapshot.records.last { record in record.event.stage == DiagnosticStage.safeHalt && record.event.outcome == DiagnosticOutcome.halted }
                let auditRecord: DiagnosticRecord? = snapshot.records.last { record in record.event.stage == DiagnosticStage.audit && record.event.fault?.code == DiagnosticFaultCode.audit }
                let halt = try XCTUnwrap(haltRecord)
                let audit = try XCTUnwrap(auditRecord)
                XCTAssertEqual(halt.event.incidentID, prior.event.incidentID)
                XCTAssertEqual(audit.event.incidentID, halt.event.incidentID)
                XCTAssertEqual(audit.event.causeEventIDs, [halt.event.eventID])
                XCTAssertTrue(service.lastReceipt?.safeHalt?.terminal == true)
                XCTAssertTrue(service.lastReceipt?.diagnosticChain.diagnostics.contains { $0.evidence.member("failureCode") == .string("auditFailed") } == true)
                try retainTerminalPair(recorder, paths: paths)
            }
        }
    }
    private func retainTerminalPair(_ recorder: any DiagnosticRecording, paths: NativeResourcePaths) throws {
        let root = paths.configuration.deletingLastPathComponent()
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        let pair = try DiagnosticExporter().export(recording: recorder, to: root)
        let snapshot = try JSONDecoder().decode(DiagnosticSnapshot.self, from: Data(contentsOf: pair.json))
        XCTAssertTrue(snapshot.isValid)
        let markdown = try String(contentsOf: pair.markdown, encoding: .utf8)
        let appendix = try XCTUnwrap(markdown.components(separatedBy: "## Full retained-evidence appendix").last)
        let json = try XCTUnwrap(appendix.components(separatedBy: "```json\n").last?.components(separatedBy: "\n```").first)
        XCTAssertEqual(try JSONDecoder().decode(DiagnosticSnapshot.self, from: Data(json.utf8)), snapshot)
        if let evidence = ProcessInfo.processInfo.environment["AEOSTARA_TERMINAL_EVIDENCE_ROOT"] {
            let destination = URL(fileURLWithPath: evidence, isDirectory: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try FileManager.default.copyItem(at: pair.json.deletingLastPathComponent(), to: destination.appendingPathComponent(pair.snapshotID.uuidString, isDirectory: true))
        }
    }
    private func state(_ coordinates: [Int]) throws -> AeostaraContract.AshState {
        let hash = try JSONValue.array(coordinates.map { .integer(String($0)) }).canonicalHash()
        return try .init(stateID: "state-" + hash, coordinates: coordinates, sourceReference: "application-explicit-state", canonicalHash: hash)
    }
    private func generation(depth: Int = 2) throws -> NativeGenerationContext {
        try .init(projectName: "Application", transitionSequence: ["identity-transition"], topologyDepth: depth,
            profileID: "application-node-profile", namingPolicyID: "application-node-name", emissionTargetKind: "abstract-manifest", sourceReferences: ["application-generation-fixture-v1"],
            assignRoles: { nodes in nodes.map { node in .object([JSONMember("nodeID", node.member("nodeID")!), JSONMember("role", .string("manifest-entry"))]) } },
            buildSubject: { _, nodes, roles in try .init(relationCount: nodes.count - 1, compressedMeasure: Double(roles.count), rawMeasure: Double(roles.count * 2), scaleCount: 3, erasureCost: Double(roles.count), selfReferenceCapable: true, selfModelAvailable: true, sourceReference: "application-node-subject-fixture-v1") },
            describeArtifacts: { project, roles in roles.enumerated().map { index, role in .object([JSONMember("artifactID", .string(project + "-" + String(index))), JSONMember("kind", .string("abstract-manifest-entry")), JSONMember("role", role)]) } })
    }
    func testAllTenAshInterfaceOperationsUseActualEvidenceAndPurePlans() throws {
        let definition = try AeostaraContract.TransitionDefinition(transitionID: "identity-transition", codewordReference: "ASH-CANONICAL-C/000000000", preconditions: ["application-transition-applicable"], diagnosticRules: reference().ruleReferences)
        let ctx = try context(predicates: [.init(identifier: "application-transition-applicable", sourceReference: "explicit-identity-transition") { _, _, _, _ in true }], transitions: [.init(definition: definition, codeword: [Int](repeating: 0, count: 9))])
        let zero = try state([Int](repeating: 0, count: 9)), current = try engine(zero.coordinates, context: ctx)
        let subject = try NativeAxiomSubject(relationCount: 2, compressedMeasure: 2, rawMeasure: 4, scaleCount: 2, erasureCost: 1, selfReferenceCapable: true, selfModelAvailable: true, sourceReference: "actual-subject-fixture")
        let provider = NativeAshBindingProvider(context: ctx, observed: current.observed, desired: current.desired, axiomSubject: subject, generationContext: try generation())
        XCTAssertEqual(try provider.evaluateAdmissibility(state: zero).status, .valid)
        let diagnosis = try provider.diagnoseState(state: zero)
        XCTAssertEqual(try provider.classifyState(diagnostic: diagnosis), .stable)
        let transformed = try provider.applyCodewordTransformation(transformation: .init(transformationID: "canonical-identity", inputState: zero, codeword: zero.coordinates, outputState: zero, diagnosticReference: reference()))
        XCTAssertEqual(transformed.outputState.coordinates, zero.coordinates)
        XCTAssertEqual(try provider.resolveRealmIdentity(state: zero).encoding, "000000000")
        XCTAssertEqual(try provider.resolveTransition(state: zero, definition: definition).outputState.coordinates, zero.coordinates)
        let topology = try provider.generateTopology(state: zero)
        XCTAssertEqual(topology.nodes.count, 13); XCTAssertEqual(topology.edges.count, 12)
        XCTAssertEqual(topology.lineage.member("leaves"), .array(["F/F/F","F/F/+","F/F/-","F/+/F","F/+/+","F/+/-","F/-/F","F/-/+","F/-/-"].map(JSONValue.string)))
        let axioms = try provider.evaluateAxioms(state: zero)
        XCTAssertEqual(axioms.count, 5); XCTAssertTrue(axioms.allSatisfy { $0.evaluationResult == .pass })
        XCTAssertTrue(axioms.allSatisfy { $0.evidence.member("overallPass") == .bool(true) })
        let plan = try provider.generateMaterializationPlan(state: zero)
        XCTAssertEqual(plan, try provider.generateMaterializationPlan(state: zero))
        XCTAssertEqual(try provider.planArtifactEmission(plan: plan).artifacts, plan.planElements)
        try NativeDiagnosticContext.validate(provider.diagnosticChains)
        for reference in plan.diagnosticReferences { try NativeDiagnosticContext.resolve(reference, in: provider.diagnosticChains) }
        if let root = ProcessInfo.processInfo.environment["AEOSTARA_ASH_EVIDENCE_ROOT"] {
            let outputs: [(String, JSONValue)] = [("AdmissibilityResult", try provider.evaluateAdmissibility(state: zero).contractJSON), ("StateValidityDiagnostic", diagnosis.contractJSON), ("TransitionResult", transformed.contractJSON), ("RealmIdentity", try provider.resolveRealmIdentity(state: zero).contractJSON), ("TopologyPlan", topology.contractJSON), ("GenerationPlan", plan.contractJSON), ("ArtifactEmissionPlan", try provider.planArtifactEmission(plan: plan).contractJSON)]
            for (name, value) in outputs { try value.canonicalData().write(to: URL(fileURLWithPath: root).appendingPathComponent(name + ".json"), options: .withoutOverwriting) }
            for (index, axiom) in axioms.enumerated() { try ContractCoding.canonicalEncode(axiom).write(to: URL(fileURLWithPath: root).appendingPathComponent("AxiomDiagnostic-" + String(index) + ".json"), options: .withoutOverwriting) }
        }
    }
    func testAshRejectsForgedProofInvalidStateAndNoncanonicalCodeword() throws {
        let ctx = try context(), runtime = try engine([Int](repeating: 0, count: 9), context: ctx), provider = NativeAshBindingProvider(context: ctx, observed: runtime.observed, desired: runtime.desired)
        let compatible = try state([1,1,1,1,0,0,0,0,0]), zero = try state([Int](repeating: 0, count: 9))
        XCTAssertEqual(try provider.evaluateAdmissibility(state: compatible).status, .transformationCompatible)
        XCTAssertEqual(try provider.classifyState(diagnostic: provider.diagnoseState(state: compatible)), .unstable)
        XCTAssertThrowsError(try provider.resolveRealmIdentity(state: compatible))
        let valid = try provider.diagnoseState(state: zero)
        let forged = try AeostaraContract.StateValidityDiagnostic(stateValidityDiagnosticID: valid.stateValidityDiagnosticID, diagnosticEnvelope: valid.diagnosticEnvelope, admissibilityStatus: .valid, normalizationStatus: .normalizable, recoverabilityRelevance: .applyCorrection)
        XCTAssertThrowsError(try provider.classifyState(diagnostic: forged))
        XCTAssertThrowsError(try provider.applyCodewordTransformation(transformation: .init(transformationID: "bad-canonical-example", inputState: zero, codeword: [0,0,0,0,0,0,0,0,1], outputState: state([0,0,0,0,0,0,0,0,1]), diagnosticReference: reference())))
        XCTAssertThrowsError(try provider.evaluateAxioms(state: zero)) { XCTAssertEqual(($0 as? LifecycleFailure)?.code, .missingEvidence) }
        let forgedHash = try AeostaraContract.AshState(stateID: zero.stateID, coordinates: zero.coordinates, sourceReference: zero.sourceReference, canonicalHash: "forged")
        XCTAssertThrowsError(try provider.evaluateAdmissibility(state: forgedHash))
    }
    func testKnownRegisteredCorrectionIsDistinguishedFromLaterNormalization() throws {
        let word = [1,1,1,1,0,0,0,0,0]
        let definition = try AeostaraContract.TransitionDefinition(transitionID: "proved-correction", codewordReference: "ASH-CANONICAL-C/111100000", preconditions: ["actual-target-allowed"], diagnosticRules: reference().ruleReferences)
        let ctx = try context(predicates: [.init(identifier: "actual-target-allowed", sourceReference: "application-correction-proof-v1") { _, target, _, _ in target == [Int](repeating: 0, count: 9) }], transitions: [.init(definition: definition, codeword: word)])
        let result = try engine(word, context: ctx).dryRun(policyBundle: policy())
        XCTAssertEqual(result.recoveryPlan.stateClass, .correctable)
        XCTAssertEqual(result.recoveryPlan.recoveryCategory, .applyCorrection)
        XCTAssertEqual(result.recoveryPlan.recoverySteps.first?.stepType, .applyCorrection)
        XCTAssertEqual(result.verificationPlan.expectedSemanticState.coordinates, [Int](repeating: 0, count: 9))
    }
    func testBoundPublicProjectorRejectsUnresolvedObservationReferences() throws {
        let runtime = try engine([Int](repeating: 0, count: 9))
        let projector = NativeSemanticProjector(context: runtime.context, observed: runtime.observed, desired: runtime.desired)
        let observed = try runtime.observedState(), intent = try runtime.desiredIntent()
        let actual = try projector.project(observedState: observed, desiredIntent: intent, projectionSpec: runtime.context.projectionSpec)
        XCTAssertEqual(actual.projectedState.coordinates, [Int](repeating: 0, count: 9))
        let wrong = try AeostaraContract.ObservedSystemState(observedSystemStateID: observed.observedSystemStateID, documentReference: observed.documentReference, surfaceDifferences: observed.surfaceDifferences, diagnosticReference: reference())
        XCTAssertThrowsError(try projector.project(observedState: wrong, desiredIntent: intent, projectionSpec: runtime.context.projectionSpec))
        XCTAssertThrowsError(try runtime.dryRun(observedState: wrong, desiredIntent: intent, projectionSpec: runtime.context.projectionSpec, policyBundle: policy()))
    }

    func testSchemaIntegerAdmissionIsExactAndUnboundedAuditSequenceIsPreserved() throws {
        let ref = try reference()
        let sequence = ["1.0", "9223372036854775808", "-9223372036854775809"]
        for token in sequence {
            let source = "{\"auditEventID\":\"event\",\"eventSequence\":" + token + ",\"eventType\":\"OBSERVE\",\"diagnosticReference\":" + (try ref.contractJSON.canonicalText()) + ",\"occurredAt\":\"fixture-time\",\"details\":{}}"
            let value = try ContractCoding.canonicalDecode(AeostaraContract.AuditEvent.self, from: Data(source.utf8))
            XCTAssertEqual(value.eventSequence.description, token == "1.0" ? "1" : token)
            XCTAssertEqual(try ContractCoding.canonicalDecode(AeostaraContract.AuditEvent.self, from: ContractCoding.canonicalEncode(value)), value)
        }
        let bits = [JSONValue.real("1.0")] + [JSONValue](repeating: .real("0.0"), count: 8)
        let hash = try JSONValue.array([.integer("1")] + [JSONValue](repeating: .integer("0"), count: 8)).canonicalHash()
        let raw = JSONValue.object([JSONMember("stateID", .string("integral-decimal-state")), JSONMember("coordinates", .array(bits)), JSONMember("sourceReference", .string("fixture")), JSONMember("canonicalHash", .string(hash))])
        XCTAssertEqual(try AeostaraContract.AshState(contractJSON: raw).coordinates, [1,0,0,0,0,0,0,0,0])
        XCTAssertThrowsError(try ContractInteger(contractJSON: .real("1.5")))
        XCTAssertThrowsError(try ContractInteger(contractJSON: .bool(true)))
        XCTAssertEqual(try ContractInteger(contractJSON: .real("9007199254740993.0")).description, "9007199254740993")
        XCTAssertEqual(try ContractInteger(contractJSON: .real("10e-1")).description, "1")
    }
    func testPublicContractIntegerDecoderUsesExactDecimalAndExponentTokens() throws {
        let ref = try reference().contractJSON.canonicalText()
        func source(_ sequence: String, details: String = "{}") -> Data {
            Data(("{\"auditEventID\":\"lexical-event\",\"eventSequence\":" + sequence + ",\"eventType\":\"OBSERVE\",\"diagnosticReference\":" + ref + ",\"occurredAt\":\"fixture-time\",\"details\":" + details + "}").utf8)
        }
        let exact: [(String, String)] = [
            ("9007199254740993.0", "9007199254740993"),
            ("9.007199254740993e15", "9007199254740993"),
            ("9223372036854775808.0", "9223372036854775808"),
            ("-9223372036854775809.00", "-9223372036854775809"),
            ("-9.007199254740993E+15", "-9007199254740993"),
            ("10e-1", "1"), ("100.000e-2", "1"), ("-0.000e-400", "0"),
            ("1e309", "1" + String(repeating: "0", count: 309))
        ]
        for (token, expected) in exact {
            do {
                let value = try ContractCoding.canonicalDecode(AeostaraContract.AuditEvent.self, from: source(token))
                XCTAssertEqual(value.eventSequence.description, expected, token)
                let encoded = try ContractCoding.canonicalEncode(value)
                XCTAssertTrue(String(decoding: encoded, as: UTF8.self).contains("\"eventSequence\":" + expected + ","), token)
                XCTAssertEqual(try ContractCoding.canonicalDecode(AeostaraContract.AuditEvent.self, from: encoded), value, token)
            } catch { XCTFail("Exact integral token \(token) failed: \(error)") }
        }
        for token in ["1.0000000000000001", "-1.0000000000000001", "9007199254740993.1", "0.99999999999999999", "1e-400", "-1e-400", "10e-2"] {
            XCTAssertThrowsError(try ContractCoding.canonicalDecode(AeostaraContract.AuditEvent.self, from: source(token)), token)
        }
        // A free JSON field still uses the frozen finite-real canonical representation.
        XCTAssertThrowsError(try ContractCoding.canonicalDecode(AeostaraContract.AuditEvent.self, from: source("1e309", details: "{\"real\":1e309}")))
    }
    func testParsedRealLexemesReachBoundedIntegerValidationWithoutRounding() throws {
        let token = "1.0000000000000001"
        guard case .real(let lexical) = try JSONValue.parse(Data(token.utf8)) else { return XCTFail("Expected real token") }
        XCTAssertEqual(lexical, token)
        XCTAssertThrowsError(try ContractInteger(contractJSON: JSONValue.parse(Data(token.utf8))))
        let statePrefix = "{\"stateID\":\"bounded\",\"sourceReference\":\"fixture\",\"canonicalHash\":\"fixture-hash\",\"coordinates\":["
        for badBit in [token, "0.99999999999999999", "1e-400"] {
            let input = Data((statePrefix + badBit + ",0,0,0,0,0,0,0,0]}").utf8)
            XCTAssertThrowsError(try ContractCoding.canonicalDecode(AeostaraContract.AshState.self, from: input), badBit)
        }
        let variants = try ["1.00", "1e0", "1.0"].map { try JSONValue.parse(Data($0.utf8)) }
        XCTAssertEqual(variants[0], variants[1]); XCTAssertEqual(variants[1], variants[2])
        XCTAssertEqual(try variants.map { try $0.canonicalText() }, ["1.0", "1.0", "1.0"])
        XCTAssertThrowsError(try JSONValue.parse(Data("1e309".utf8)))
    }
    func testFrozenDTOEqualityAndDiagnosticResolutionPreserveRawUnicodeSourceIdentity() throws {
        let a = try AeostaraContract.RuleReference(ruleID: "ASH-STATE-STRUCTURE-001", sourceReference: "source-é", ruleFamily: "STATE")
        let b = try AeostaraContract.RuleReference(ruleID: a.ruleID, sourceReference: "source-e\u{0301}", ruleFamily: "STATE")
        XCTAssertNotEqual(a, b); XCTAssertNotEqual(try ContractCoding.canonicalEncode(a), try ContractCoding.canonicalEncode(b))
        let envelope = try AeostaraContract.DiagnosticEnvelope(diagnosticID: "unicode-source", chainRootReference: "unicode-source", parentDiagnosticID: nil, diagnosticKind: .mapping, severity: .info, message: "actual raw-source provenance", ruleReferences: [a], sourceReferences: [a.sourceReference], evidence: .object([]))
        let chain = try AeostaraContract.DiagnosticChain(chainID: "unicode-chain", rootDiagnosticID: envelope.diagnosticID, diagnostics: [envelope])
        let forged = try AeostaraContract.DiagnosticReference(diagnosticID: envelope.diagnosticID, chainRootReference: envelope.chainRootReference, diagnosticKind: .mapping, ruleReferences: [b])
        XCTAssertThrowsError(try NativeDiagnosticContext.resolve(forged, in: [chain]))
    }

    func testArtifactEmissionUsesCompletePlanWithoutReenteringRegisteredPlannerCallbacks() throws {
        var calls = [0,0,0]
        let gen = try NativeGenerationContext(projectName: "Application", transitionSequence: [], topologyDepth: 1, profileID: "explicit-profile", namingPolicyID: "explicit-naming", emissionTargetKind: "abstract-manifest", sourceReferences: ["explicit-application-generation"],
            assignRoles: { nodes in calls[0] += 1; return nodes.map { .object([JSONMember("nodeID", $0.member("nodeID")!), JSONMember("role", .string("manifest"))]) } },
            buildSubject: { _, nodes, roles in calls[1] += 1; return try .init(relationCount: nodes.count - 1, compressedMeasure: Double(roles.count), rawMeasure: Double(roles.count * 2), scaleCount: 2, erasureCost: Double(roles.count), selfReferenceCapable: true, selfModelAvailable: true, sourceReference: "explicit-measurement-algorithm") },
            describeArtifacts: { name, roles in calls[2] += 1; return [.object([JSONMember("name", .string(name)), JSONMember("roles", .array(roles)), JSONMember("kind", .string("abstract-manifest"))])] })
        let runtime = try engine([Int](repeating: 0, count: 9)), provider = NativeAshBindingProvider(context: runtime.context, observed: runtime.observed, desired: runtime.desired, generationContext: gen)
        let plan = try provider.generateMaterializationPlan(state: state([Int](repeating: 0, count: 9)))
        XCTAssertEqual(calls, [1,1,1])
        let emitter = NativeAshBindingProvider()
        XCTAssertEqual(try emitter.planArtifactEmission(plan: plan).artifacts, plan.planElements)
        XCTAssertEqual(calls, [1,1,1])
        XCTAssertThrowsError(try emitter.planArtifactEmission(plan: .init(planID: plan.planID, planElements: plan.planElements, semanticInputs: plan.semanticInputs, diagnosticReferences: plan.diagnosticReferences, planHash: "forged")))
        XCTAssertEqual(calls, [1,1,1])
        var altered = plan.semanticInputs
        for index in 0..<5 {
            for suffix in ["/evidence/subject/relationCount", "/diagnosticEnvelope/evidence/subject/relationCount"] {
                altered = try altered.applying(.init(op: .replace, pointer: "/axiomDiagnostics/" + String(index) + suffix, value: .integer("0")))
            }
        }
        guard case .array(let chains) = altered.member("diagnosticChains") else { return XCTFail("Plan has no support chains") }
        for (chainIndex, rawChain) in chains.enumerated() {
            guard case .array(let envelopes) = rawChain.member("diagnostics") else { return XCTFail("Support chain has no envelopes") }
            for (envelopeIndex, envelope) in envelopes.enumerated() where envelope.member("evidence")?.member("subject") != nil {
                let chainPath = "/diagnosticChains/" + String(chainIndex) + "/diagnostics/" + String(envelopeIndex)
                let subjectPath = chainPath + "/evidence/subject/relationCount"
                altered = try altered.applying(.init(op: .replace, pointer: subjectPath, value: .integer("0")))
            }
        }
        let hash = try JSONValue.object([JSONMember("planElements", .array(plan.planElements)), JSONMember("semanticInputs", altered), JSONMember("diagnosticReferences", .array(plan.diagnosticReferences.map(\.contractJSON)))]).canonicalHash()
        let inconsistent = try AeostaraContract.GenerationPlan(planID: "generation-" + hash, planElements: plan.planElements, semanticInputs: altered, diagnosticReferences: plan.diagnosticReferences, planHash: hash)
        XCTAssertThrowsError(try emitter.planArtifactEmission(plan: inconsistent), "Rehashed diagnostic flags must not override actual subject measurements")
        XCTAssertEqual(calls, [1,1,1])
    }

    func testActualConsensusAmbiguityPreservesEveryCandidateAndMissingEvidenceBlocks() throws {
        let original = try context(), first = original.projectionSpec.dimensions[0]
        let extra = try AeostaraContract.JsonPointer(pointer: "/alternative", tokens: ["alternative"], pointsToMissing: false, pointsToNull: false)
        let replacement = try AeostaraContract.SemanticDimensionBinding(dimensionID: first.dimensionID, sourcePointers: first.sourcePointers + [extra], mappingRule: first.mappingRule, evidence: first.evidence, diagnosticReference: first.diagnosticReference)
        let ctx = try SemanticContext(applicationScope: original.applicationScope, projectionSpec: .init(projectionSpecID: "consensus-ambiguity", dimensions: [replacement] + original.projectionSpec.dimensions.dropFirst(), version: "1", sourceReferences: original.projectionSpec.sourceReferences), intentConstraints: original.intentConstraints, knownValidStates: original.knownValidStates, mappingRules: original.mappingRules, inputDiagnosticChains: original.inputDiagnosticChains)
        let observedValue = try JSONValue.parse(input([Int](repeating: 0, count: 9))).applying(.init(op: .add, pointer: "/alternative", value: .bool(true)))
        let observed = try JSONSnapshot(documentID: "ambiguous-observed", sourceReference: "explicit-consensus-input", data: observedValue.canonicalData()), desired = try JSONSnapshot(documentID: "consensus-desired", sourceReference: "explicit-consensus-intent", data: input([Int](repeating: 0, count: 9)))
        let runtime = NativeHealingEngine(context: ctx, observed: observed, desired: desired)
        XCTAssertThrowsError(try runtime.dryRun(policyBundle: policy())) { error in
            guard let failure = error as? LifecycleFailure else { return XCTFail("Missing typed ambiguity") }
            XCTAssertEqual(failure.code, .ambiguousMapping); XCTAssertEqual(failure.diagnosticEnvelope.evidence.member("status"), .string("AMBIGUOUS"))
            do {
                let raw = try XCTUnwrap(failure.diagnosticEnvelope.evidence.member("ambiguity"))
                let ambiguity = try AeostaraContract.MappingAmbiguity(contractJSON: raw)
                XCTAssertEqual(ambiguity.candidateValues, [0,1]); XCTAssertEqual(ambiguity.dimensionID, .b0)
                try NativeDiagnosticContext.resolve(ambiguity.diagnosticReference, in: [failure.diagnosticChain])
            } catch { XCTFail("Missing candidate evidence: \(error)") }
        }
        let noEvidence = try JSONSnapshot(documentID: "missing-observed", sourceReference: "explicit-missing-input", data: Data("{}".utf8))
        let missing = try AeostaraContract.SemanticDimensionBinding(dimensionID: first.dimensionID, sourcePointers: [.init(pointer: "/runtime/enabled", tokens: ["runtime","enabled"], pointsToMissing: true, pointsToNull: false)], mappingRule: first.mappingRule, evidence: first.evidence, diagnosticReference: first.diagnosticReference)
        let missingContext = try SemanticContext(applicationScope: original.applicationScope, projectionSpec: .init(projectionSpecID: "missing-evidence", dimensions: [missing] + original.projectionSpec.dimensions.dropFirst(), version: "1", sourceReferences: original.projectionSpec.sourceReferences), intentConstraints: original.intentConstraints, knownValidStates: original.knownValidStates, mappingRules: original.mappingRules, inputDiagnosticChains: original.inputDiagnosticChains)
        XCTAssertThrowsError(try NativeHealingEngine(context: missingContext, observed: noEvidence, desired: desired).dryRun(policyBundle: policy())) {
            XCTAssertEqual(($0 as? LifecycleFailure)?.code, .missingEvidence); XCTAssertEqual(($0 as? LifecycleFailure)?.diagnosticEnvelope.evidence.member("status"), .string("BLOCKED"))
        }
    }
    func testActualNativeExecutionAndVerificationFailureExportBothDiagnosticProfiles() throws {
        let supplied = ProcessInfo.processInfo.environment["AEOSTARA_LIFECYCLE_EVIDENCE_ROOT"]
        let root = (supplied.map { URL(fileURLWithPath: $0) } ?? FileManager.default.temporaryDirectory).appendingPathComponent("MacLifecycle-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { if supplied == nil { try? FileManager.default.removeItem(at: root) } }
        for profile in [DiagnosticProfile.release, .development] {
            for fails in [false, true] {
                let recorder: any DiagnosticRecording = profile == .release ? try ReleaseDiagnosticRecorder() : try DevelopmentDiagnosticRecorder()
                let caseRoot = root.appendingPathComponent(profile.rawValue + (fails ? "-verification-failure" : "-healed"), isDirectory: true)
                try FileManager.default.createDirectory(at: caseRoot, withIntermediateDirectories: false)
                try withNativeService(fault: fails ? .corruptAfterWrite : nil, recorder: recorder) { service, _, _ in
                    let result = try service.heal()
                    XCTAssertEqual(result.status, fails ? .escalated : .healed)
                    if fails { XCTAssertEqual(service.lastReceipt?.rollback?.status, .succeeded) }
                    try ContractCoding.canonicalEncode(result).write(to: caseRoot.appendingPathComponent("HealResult.json"), options: .withoutOverwriting)
                    if let backup = service.lastReceipt?.backup { try ContractCoding.canonicalEncode(backup).write(to: caseRoot.appendingPathComponent("BackupResult.json"), options: .withoutOverwriting) }
                    if let verification = service.lastReceipt?.verification { try ContractCoding.canonicalEncode(verification).write(to: caseRoot.appendingPathComponent("VerificationResult.json"), options: .withoutOverwriting) }
                    if let rollback = service.lastReceipt?.rollback { try ContractCoding.canonicalEncode(rollback).write(to: caseRoot.appendingPathComponent("RollbackResult.json"), options: .withoutOverwriting) }
                    let bundle = try DiagnosticExporter().export(recording: recorder, to: caseRoot)
                    let snapshot = try JSONDecoder().decode(DiagnosticSnapshot.self, from: Data(contentsOf: bundle.json))
                    XCTAssertTrue(snapshot.isValid); XCTAssertEqual(snapshot.profile, profile)
                    let lifecycle = snapshot.records.filter { $0.event.stage != .export }
                    XCTAssertEqual(Set(lifecycle.compactMap { $0.event.incidentID }).count, 1, "Planning and execution must preserve one actual incident")
                    let planning = try XCTUnwrap(lifecycle.last { $0.event.stage == .plan })
                    let policy = try XCTUnwrap(lifecycle.first { $0.event.stage == .policy })
                    XCTAssertEqual(policy.event.causeEventIDs, [planning.event.eventID])
                    XCTAssertEqual(policy.event.parentOperationID, planning.event.operationID)
                    XCTAssertTrue(snapshot.records.contains { $0.event.stage == .verify && $0.event.outcome == (fails ? .failed : .succeeded) })
                    if fails { XCTAssertTrue(snapshot.records.contains { $0.event.stage == .rollback && $0.event.outcome == .rolledBack }) }
                    let markdown = try String(contentsOf: bundle.markdown, encoding: .utf8)
                    let json = try XCTUnwrap(markdown.components(separatedBy: "```json\n").last?.components(separatedBy: "\n```").first)
                    XCTAssertEqual(try JSONDecoder().decode(DiagnosticSnapshot.self, from: Data(json.utf8)), snapshot)
                    if profile == .release { XCTAssertTrue(snapshot.records.allSatisfy { $0.details == nil }) }
                }
            }
        }
    }

}

private final class NativeTestIO: NativeResourceIO {
    enum Fault { case audit(Int), corruptAfterWrite, partialWriteAndFailedRollback, staleOnAcquire }
    let base: ScopedNativeResourceIO
    let fault: Fault?
    var scopeIdentity: String { base.scopeIdentity }
    private var auditCount = 0
    private var writeCount = 0
    var onAcquire: (() -> Void)?
    var onAudit: (() throws -> Void)?
    init(base: ScopedNativeResourceIO, fault: Fault?) { self.base = base; self.fault = fault }
    func read(_ role: NativeResourceRole) throws -> Data { try base.read(role) }
    func acquireExclusiveLease() throws -> any NativeResourceLease {
        let lease = try base.acquireExclusiveLease()
        onAcquire?()
        if case .staleOnAcquire = fault { try Data("{\"external\":true}".utf8).write(to: base.paths.configuration) }
        return lease
    }
    func createBackup(bytes: Data, lease: any NativeResourceLease) throws { try base.createBackup(bytes: bytes, lease: lease) }
    func replaceConfiguration(bytes: Data, expectedStorageHash: String, lease: any NativeResourceLease) throws {
        writeCount += 1
        if case .partialWriteAndFailedRollback = fault, writeCount > 1 { throw NativeResourceError.partialWrite(5) }
        try base.replaceConfiguration(bytes: bytes, expectedStorageHash: expectedStorageHash, lease: lease)
        if case .partialWriteAndFailedRollback = fault { throw NativeResourceError.partialWrite(5) }
        if case .corruptAfterWrite = fault, writeCount == 1 {
            let value = try JSONValue.parse(bytes).applying(.init(op: .replace, pointer: "/integrity/verified", value: .bool(true)))
            try base.replaceConfiguration(bytes: value.canonicalData(), expectedStorageHash: NativeStorageIdentity.hash(bytes), lease: lease)
        }
    }
    func persistAudit(_ event: AeostaraContract.AuditEvent, lease: any NativeResourceLease) throws {
        try onAudit?()
        auditCount += 1
        if case .audit(let number) = fault, auditCount == number { throw NativeResourceError.partialWrite(5) }
        try base.persistAudit(event, lease: lease)
    }
}
