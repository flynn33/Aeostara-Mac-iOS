// Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.

import Foundation
@testable import AeostaraDomain

/// In-memory file system for testing. No disk I/O.
class InMemoryFileSystem: IFileSystem, SemanticResourceIO {
    var leased = false
    var files: [String: String] = [:]

    func readFile(path: String) throws -> String {
        guard let content = files[path] else {
            throw AeostaraError.fileNotFound(path)
        }
        return content
    }

    func writeFile(path: String, content: String) throws {
        files[path] = content
    }

    func fileExists(path: String) -> Bool {
        return files[path] != nil
    }

    func copyFile(from sourcePath: String, to destinationPath: String) throws -> Bool {
        guard let content = files[sourcePath] else { return false }
        files[destinationPath] = content
        return true
    }

    func appendFile(path: String, content: String) throws {
        if let existing = files[path] {
            files[path] = existing + content
        } else {
            files[path] = content
        }
    }
}

extension InMemoryFileSystem {
    func read(path: String) throws -> Data { Data(try readFile(path:path).utf8) }
    func acquire(resources: NativeResourceSet) throws -> any NativeResourceLease {
        guard !leased else { throw ResourceIOFault.resourceBusy };leased = true;return MemorySemanticLease(fs:self,resources:resources)
    }
}
private final class MemorySemanticLease: NativeResourceLease {
    let fs: InMemoryFileSystem
    let resources: NativeResourceSet
    var active = true
    init(fs: InMemoryFileSystem,resources: NativeResourceSet) { self.fs = fs;self.resources = resources }
    func readConfiguration() throws -> Data { try fs.read(path:resources.configuration) }
    func readDesired() throws -> Data { try fs.read(path:resources.desired) }
    func persistAudit(events: [AeostaraContract.AuditEvent]) throws {
        for event in events { try fs.appendFile(path:resources.audit,content:String(decoding:ContractCoding.canonicalEncode(event),as:UTF8.self)+"\n") }
    }
    func createBackup(bytes: Data,sourceHash: String,identifier: String) throws -> NativeBackupReceipt {
        let path = resources.configuration+".backup."+identifier
        guard fs.files[path] == nil else { throw ResourceIOFault.backupCollision }
        fs.files[path] = String(decoding:bytes,as:UTF8.self)
        return .init(storageReference:path,bytesHash:CanonicalJSON.hashBytes(bytes),sourceHash:sourceHash)
    }
    func replaceConfiguration(bytes: Data,expectedBytesHash: String) throws {
        guard CanonicalJSON.hashBytes(try readConfiguration()) == expectedBytesHash else { throw ResourceIOFault.staleSnapshot }
        try fs.writeFile(path:resources.configuration,content:String(decoding:bytes,as:UTF8.self))
    }
    func restoreBackup(_ receipt: NativeBackupReceipt,expectedBytesHash: String) throws -> Data {
        let bytes = try fs.read(path:receipt.storageReference)
        guard CanonicalJSON.hashBytes(bytes) == receipt.bytesHash else { throw ResourceIOFault.backupFailed }
        try replaceConfiguration(bytes:bytes,expectedBytesHash:expectedBytesHash);return try readConfiguration()
    }
    func release() { if active { active = false;fs.leased = false } }
}
/// Explicit test-application semantics: mismatch against a caller supplied trusted root emits C's 111100000;
/// the remaining five coordinates are declared reserved zeros. No production API infers this encoding.
enum LegacyTestContext {
    static func make(trusted: JSONValue) throws -> SemanticContext {
        let source = "legacy-test-application-explicit-root-codeword-v1"
        let rule = try AeostaraContract.RuleReference(ruleID:"ASH-STATE-STRUCTURE-001",sourceReference:NativeAshBindingProvider.source(for:"ASH-STATE-STRUCTURE-001"),ruleFamily:"STATE")
        let diagnostic = try AeostaraContract.DiagnosticReference(diagnosticID:source,chainRootReference:source,diagnosticKind:.MAPPING,ruleReferences:[rule])
        let inputEnvelope = try AeostaraContract.DiagnosticEnvelope(diagnosticID:diagnostic.diagnosticID,chainRootReference:diagnostic.chainRootReference,parentDiagnosticID:nil,diagnosticKind:.MAPPING,severity:.INFO,message:"Application declared projection provenance",ruleReferences:[rule],sourceReferences:[rule.sourceReference,source],evidence:.object([JSONMember("source",.string(source))]))
        let inputChain = try AeostaraContract.DiagnosticChain(chainID:"input-"+source,rootDiagnosticID:diagnostic.chainRootReference,diagnostics:[inputEnvelope])
        let pointer = try AeostaraContract.JsonPointer(pointer:"",tokens:[],pointsToMissing:false,pointsToNull:false)
        let bindings = try (0..<9).map { try AeostaraContract.SemanticDimensionBinding(dimensionID:.init(rawValue:"b\($0)")!,sourcePointers:[pointer],mappingRule:"TEST-EXPLICIT-ROOT",evidence:[.object([JSONMember("source",.string(source))])],diagnosticReference:diagnostic) }
        let spec = try AeostaraContract.SemanticProjectionSpec(projectionSpecID:source,dimensions:bindings,version:"1",sourceReferences:[source])
        let mapping = RegisteredMappingRule(identifier:"TEST-EXPLICIT-ROOT",candidates:{ binding,evidence,_ in
            guard let actual = evidence.first?.value else { throw SemanticInputFault.missingEvidence }
            let index = Int(binding.dimensionID.rawValue.dropFirst())!
            return [index < 4 && actual != trusted ? 1 : 0]
        },materialize:{ binding,bit,_,_ in
            guard bit == 0 else { throw SemanticInputFault.missingMaterialization }
            return binding.dimensionID == .b0 ? [MutationDraft(op:.replace,path:JSONPointer(tokens:[]),value:trusted)] : []
        })
        let zero = [Int](repeating:0,count:9),hash = try CanonicalJSON.hash(.array([JSONValue](repeating:.number(.integer("0")),count:9)))
        let state = try AeostaraContract.AshState(stateID:"trusted-application-root",coordinates:zero,sourceReference:source,canonicalHash:hash)
        return try SemanticContext(applicationScopeID:source,projectionSpec:spec,intentConstraints:IntentConstraintSet(applicationScopeID:source,pointers:[JSONPointer(tokens:[])],sourceReferences:[source]),knownValidStates:KnownValidStateContext(applicationScopeID:source,recognizedStates:[state],sourceReferences:[source]),mappingRules:MappingRuleRegistry([mapping]),transitions:TransitionRegistry([]),predicates:PredicateRuleRegistry([]),fallbackPolicies:FallbackPolicyRegistry([]),inputDiagnosticChains:[inputChain])
    }
    static func policies() throws -> NativePolicyRegistry {
        try .init(predicates:[RegisteredPolicyPredicate(identifier:"TEST-AUTHORIZED",sourceReferences:["test-owner-explicit-allow"],evaluate:{_ in true}),RegisteredPolicyPredicate(identifier:"TEST-BOUNDARY",sourceReferences:["test-owner-declared-root-resource"],evaluate:{input in input.plan.recoverySteps.flatMap(\.jsonMutationOperations).allSatisfy{$0.path.pointer == ""}})],propagationRiskPolicyID:"TEST-BOUNDARY")
    }
    static func bundle() throws -> AeostaraContract.PolicyBundle {
        let rules: [JSONValue] = [.object([JSONMember("policyID",.string("TEST-OWNER-POLICY")),JSONMember("predicateID",.string("TEST-AUTHORIZED")),JSONMember("effect",.string("ALLOW"))])]
        let value = JSONValue.object([JSONMember("policyBundleID",.string("test-owner-policy")),JSONMember("rules",.array(rules)),JSONMember("sourceReferences",.array([.string("test-owner-explicit-allow")]))])
        return try .init(policyBundleID:"test-owner-policy",sourceReferences:["test-owner-explicit-allow"],rules:rules,bundleHash:CanonicalJSON.hash(value))
    }
}

/// Fixed timestamp provider for deterministic tests.
func fixedTimestamp(_ value: String = "2026-03-22T00:00:00Z") -> () -> String {
    return { value }
}

/// Sequential event ID provider for deterministic tests.
func sequentialEventID() -> () -> String {
    var counter = 0
    return {
        counter += 1
        return "event-\(counter)"
    }
}

/// Build a fully wired HealingEngine for integration testing.
func buildTestEngine(fileSystem: InMemoryFileSystem, trustedApplicationDocument: String = "{\"key\":\"value\"}") -> HealingEngine {
    let adapter = TestConfigAdapter(fileSystem: fileSystem)
    let backupManager = BackupManager(fileSystem: fileSystem, timestampProvider: fixedTimestamp("20260322_000000"))
    let driftAnalyzer = DriftAnalyzer()
    let repairPlanner = RepairPlanner()
    let policyEvaluator = PolicyEvaluator()
    let invariantParser = InvariantParser()
    let verification = Verification(policyEvaluator: policyEvaluator)
    let rollbackManager = RollbackManager(backupProvider: backupManager)

    return HealingEngine(
        adapter: adapter,
        backupManager: backupManager,
        driftAnalyzer: driftAnalyzer,
        repairPlanner: repairPlanner,
        policyEvaluator: policyEvaluator,
        invariantParser: invariantParser,
        verification: verification,
        rollbackManager: rollbackManager,
        fileSystem: fileSystem,
        timestampProvider: fixedTimestamp(),
        eventIDProvider: sequentialEventID(),
        semanticContext: try! LegacyTestContext.make(trusted:CanonicalJSON.parse(trustedApplicationDocument)),
        nativePolicies: try! LegacyTestContext.policies(),
        nativePolicyBundle: try! LegacyTestContext.bundle(),
        nativeResources: try! NativeResourceSet(configuration:"/config.json",desired:"/desired.json",audit:"/audit.jsonl",backupDirectory:"/"),
        resourceIO:fileSystem,identifierProvider:{"20260322_000000"}
    )
}

/// Test config adapter backed by InMemoryFileSystem.
final class TestConfigAdapter: IConfigAdapter {
    private let fileSystem: InMemoryFileSystem

    init(fileSystem: InMemoryFileSystem) {
        self.fileSystem = fileSystem
    }

    func observe(filePath: String) throws -> ObservedState {
        let content = try fileSystem.readFile(path: filePath)
        guard let data = content.data(using: .utf8),
              let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AeostaraError.cannotParseJSON(filePath)
        }
        return ObservedState(
            sourceFile: filePath,
            data: parsed.mapValues { AnyCodable($0) },
            timestamp: "2026-03-22T00:00:00Z"
        )
    }

    func encode(observed: ObservedState, desired: DesiredState) -> EncodedState {
        let observedFlat = JsonPath.flatten(observed.data.mapValues { $0.value })
        let desiredFlat = JsonPath.flatten(desired.data.mapValues { $0.value })
        return EncodedState(
            observed: observedFlat.mapValues { AnyCodable($0) },
            desired: desiredFlat.mapValues { AnyCodable($0) }
        )
    }

    func applyRepair(filePath: String, plan: RepairPlan) throws -> Bool {
        let content = try fileSystem.readFile(path: filePath)
        guard let data = content.data(using: .utf8),
              var configData = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        for action in plan.actions {
            switch action.actionType {
            case .set, .add:
                if let toValue = action.toValue {
                    configData = JsonPath.set(configData, dotPath: action.keyPath, value: toValue.value)
                }
            case .remove:
                configData = JsonPath.remove(configData, dotPath: action.keyPath)
            }
        }

        let outputData = try JSONSerialization.data(withJSONObject: configData, options: [.prettyPrinted, .sortedKeys])
        guard let outputString = String(data: outputData, encoding: .utf8) else { return false }
        try fileSystem.writeFile(path: filePath, content: outputString)
        return true
    }
}
