// Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.

import Foundation
@testable import AeostaraMacDomain
import AeostaraMacServices

/// In-memory file system for testing. No disk I/O.
class InMemoryFileSystem: IFileSystem {
    var files: [String: String] = [:]
    let nativeResourceLock = NSLock()

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
func buildTestEngine(fileSystem: InMemoryFileSystem, semanticEnabled: Bool = true) -> HealingEngine {
    let adapter = TestConfigAdapter(fileSystem: fileSystem)
    let backupManager = BackupManager(fileSystem: fileSystem, timestampProvider: fixedTimestamp("20260322_000000"))
    let driftAnalyzer = DriftAnalyzer()
    let repairPlanner = RepairPlanner()
    let policyEvaluator = PolicyEvaluator()
    let invariantParser = InvariantParser()
    let verification = Verification(policyEvaluator: policyEvaluator)
    let rollbackManager = RollbackManager(backupProvider: backupManager)
    let semanticContext = semanticEnabled ? try! explicitLegacyFixtureContext() : nil
    let lifecycle = semanticContext.map { context in
        NativeLegacyLifecycle(context: context, resourceFactory: { configuration, desired, audit in
            NativeMemoryFixtureIO(fileSystem: fileSystem, configuration: configuration, desired: desired,
                audit: audit ?? "/audit.jsonl", backup: configuration + ".backup.20260322_000000")
        }, policyFactory: { path, _, _ in
            let invariants: [Invariant]
            if let path {
                guard fileSystem.fileExists(path: path), let data = try fileSystem.readFile(path: path).data(using: .utf8) else { throw ProjectionProblem.invalidContext }
                invariants = try JSONDecoder().decode([Invariant].self, from: data)
                guard !invariants.isEmpty else { throw ProjectionProblem.invalidContext }
            } else { invariants = [] }
            return try NativePolicyContext.make(bundleID: "explicit-legacy-fixture-policy", rules: [
                .init(identifier: "fixture-critical-invariants", sourceReference: "fixture-application:legacy-invariant-expression-v1") { _, observed, _ in
                    for invariant in invariants where invariant.severity == .critical && !invariant.autoRemediate {
                        guard fixtureInvariantHolds(invariant.expression, value: observed.value) else { return false }
                    }
                    return true
                }
            ])
        }, timestampProvider: fixedTimestamp())
    }

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
        eventIDProvider: sequentialEventID(), semanticContext: semanticContext, nativeLifecycle: lifecycle
    )
}

private struct LegacyRootComparisonMapping: SemanticMappingRule {
    let identifier = "fixture-root-document-comparison"
    let sourceReference = "fixture-application:whole-document-intent-v1"
    func candidates(binding: AeostaraContract.SemanticDimensionBinding, evidence: [PointerObservation], desired: JSONSnapshot) throws -> [Int] {
        guard let root = evidence.first?.value, evidence.count == 1 else { throw ProjectionProblem.missingEvidence }
        let coordinate = Int(binding.dimensionID.rawValue.dropFirst())!
        return [coordinate < 4 && root != desired.value ? 1 : 0]
    }
    func materialize(binding: AeostaraContract.SemanticDimensionBinding, targetBit: Int, observed: JSONSnapshot, desired: JSONSnapshot) throws -> [MutationDraft] {
        guard targetBit == 0, binding.sourcePointers.count == 1, binding.sourcePointers[0].pointer == "" else { throw ProjectionProblem.missingMaterialization }
        return [.init(op: .replace, pointer: "", value: desired.value)]
    }
}
private func explicitLegacyFixtureContext() throws -> SemanticContext {
    let rule = try AeostaraContract.RuleReference(ruleID: "ASH-STATE-STRUCTURE-001", sourceReference: NativeAshBindingProvider.sourceReference, ruleFamily: "STATE")
    let reference = try AeostaraContract.DiagnosticReference(diagnosticID: "fixture-root", chainRootReference: "fixture-root", diagnosticKind: .mapping, ruleReferences: [rule])

        let inputEnvelope = try AeostaraContract.DiagnosticEnvelope(diagnosticID: reference.diagnosticID, chainRootReference: reference.chainRootReference, parentDiagnosticID: nil, diagnosticKind: .mapping, severity: .info, message: "Application declares explicit projection bindings", ruleReferences: reference.ruleReferences, sourceReferences: ["fixture-application:whole-document-intent-v1"], evidence: .object([JSONMember("declaration", .string("explicit-application-projection"))]))
        let inputChain = try AeostaraContract.DiagnosticChain(chainID: "application-input", rootDiagnosticID: reference.diagnosticID, diagnostics: [inputEnvelope])
    let bindings = try (0..<9).map { index in
        try AeostaraContract.SemanticDimensionBinding(dimensionID: .init(rawValue: "b\(index)")!,
            sourcePointers: [.init(pointer: "", tokens: [], pointsToMissing: false, pointsToNull: false)], mappingRule: "fixture-root-document-comparison",
            evidence: [.object([JSONMember("sourceReference", .string("fixture-application:whole-document-intent-v1"))])], diagnosticReference: reference)
    }
    return try .init(applicationScope: "legacy-fixture-application", projectionSpec: .init(projectionSpecID: "fixture-whole-document-comparison", dimensions: bindings, version: "1", sourceReferences: ["fixture-application:whole-document-intent-v1"]),
        intentConstraints: .init(scopeID: "legacy-fixture-application", pointers: [""], sourceReferences: ["fixture-application:whole-document-intent-v1"]),
        knownValidStates: .init(scopeID: "legacy-fixture-application", states: [[Int](repeating: 0, count: 9)], sourceReferences: ["fixture-application:recognized-matching-document-state-v1"]), mappingRules: [LegacyRootComparisonMapping()], inputDiagnosticChains: [inputChain])
}
private func fixtureInvariantHolds(_ expression: String, value: JSONValue) -> Bool {
    guard let separator = expression.range(of: " == ") else { return false }
    let names = expression[..<separator.lowerBound].split(separator: ".").map(String.init)
    let pointer = "/" + names.map { $0.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(of: "/", with: "~1") }.joined(separator: "/")
    let expected = String(expression[separator.upperBound...])
    guard let wanted = try? JSONValue.parse(Data(expected.utf8)), let actual = try? value.resolve(pointer: pointer) else { return false }
    return actual == wanted
}
private final class MemoryFixtureLease: NativeResourceLease {
    let owner: UUID
    let lock: NSLock
    private(set) var active = true
    init(owner: UUID, lock: NSLock) { self.owner = owner; self.lock = lock }
    func release() { if active { active = false; lock.unlock() } }
    deinit { release() }
}
private final class NativeMemoryFixtureIO: NativeResourceIO {
    let fileSystem: InMemoryFileSystem
    let configuration: String
    let desired: String
    let audit: String
    let backup: String
    private let owner = UUID()
    private var writes = 0
    var scopeIdentity: String { NativeStorageIdentity.hash(Data([configuration, desired, audit, backup].joined(separator: "\n").utf8)) }
    init(fileSystem: InMemoryFileSystem, configuration: String, desired: String, audit: String, backup: String) {
        self.fileSystem = fileSystem; self.configuration = configuration; self.desired = desired; self.audit = audit; self.backup = backup
    }
    func read(_ role: NativeResourceRole) throws -> Data {
        let path: String
        switch role { case .configuration: path = configuration; case .desired: path = desired; case .audit: path = audit; case .backup: path = backup }
        return Data(try fileSystem.readFile(path: path).utf8)
    }
    func acquireExclusiveLease() throws -> any NativeResourceLease {
        guard fileSystem.nativeResourceLock.try() else { throw NativeResourceError.resourceBusy }
        return MemoryFixtureLease(owner: owner, lock: fileSystem.nativeResourceLock)
    }
    private func validate(_ lease: any NativeResourceLease) throws {
        guard let lease = lease as? MemoryFixtureLease, lease.owner == owner, lease.active else { throw NativeResourceError.leaseInvalid }
    }
    func createBackup(bytes: Data, lease: any NativeResourceLease) throws {
        try validate(lease)
        guard !fileSystem.fileExists(path: backup) else { throw NativeResourceError.backupCollision }
        try fileSystem.writeFile(path: backup, content: String(decoding: bytes, as: UTF8.self))
    }
    func replaceConfiguration(bytes: Data, expectedStorageHash: String, lease: any NativeResourceLease) throws {
        try validate(lease)
        guard NativeStorageIdentity.hash(try read(.configuration)) == expectedStorageHash else { throw NativeResourceError.staleSnapshot }
        writes += 1
        try fileSystem.writeFile(path: configuration, content: String(decoding: bytes, as: UTF8.self))
        if fileSystem is CorruptOnVerifyFileSystem, writes == 1 {
            try fileSystem.writeFile(path: configuration, content: "{\"server\":{\"host\":\"CORRUPT\",\"port\":0,\"ssl_enabled\":false}}")
        }
    }
    func persistAudit(_ event: AeostaraContract.AuditEvent, lease: any NativeResourceLease) throws {
        try validate(lease)
        try fileSystem.appendFile(path: audit, content: String(decoding: ContractCoding.canonicalEncode(event), as: UTF8.self) + "\n")
    }
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
