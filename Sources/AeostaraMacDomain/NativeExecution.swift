import Foundation

public enum NativeResourceRole: String { case configuration, desired, backup, audit }
public struct NativeLifecycleReceipt: Equatable {
    public let backup: AeostaraContract.BackupResult?
    public let verification: AeostaraContract.VerificationResult?
    public let rollback: AeostaraContract.RollbackResult?
    public init(backup: AeostaraContract.BackupResult?, verification: AeostaraContract.VerificationResult?, rollback: AeostaraContract.RollbackResult?) {
        self.backup = backup; self.verification = verification; self.rollback = rollback
    }
}
public struct NativeStorageSnapshot {
    public let bytes: Data
    public let storageHash: String
    public let document: JSONSnapshot
    public init(bytes: Data, documentID: String, sourceReference: String) throws {
        self.bytes = bytes
        document = try JSONSnapshot(documentID: documentID, sourceReference: sourceReference, data: bytes)
        storageHash = NativeStorageIdentity.hash(bytes)
    }
}
public enum NativeStorageIdentity {
    public static func hash(_ bytes: Data) -> String {
        // Hash the exact stored bytes separately from canonical document identity.
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}
import CryptoKit

public protocol NativeResourceLease: AnyObject { func release() }
public protocol NativeResourceIO: AnyObject {
    var scopeIdentity: String { get }
    func read(_ role: NativeResourceRole) throws -> Data
    func acquireExclusiveLease() throws -> any NativeResourceLease
    func createBackup(bytes: Data, lease: any NativeResourceLease) throws
    func replaceConfiguration(bytes: Data, expectedStorageHash: String, lease: any NativeResourceLease) throws
    func persistAudit(_ event: AeostaraContract.AuditEvent, lease: any NativeResourceLease) throws
}
public enum NativeResourceError: Error, Equatable {
    case scopeViolation, identityCollision, unsupportedResource, resourceBusy, staleSnapshot
    case unavailable(Int32), backupCollision, partialWrite(Int32), leaseInvalid
}

public struct NativePolicyRule {
    public let identifier: String
    public let sourceReference: String
    private let evaluator: (AeostaraContract.RecoveryPlan, JSONSnapshot, JSONSnapshot) throws -> Bool
    public init(identifier: String, sourceReference: String,
                evaluate: @escaping (AeostaraContract.RecoveryPlan, JSONSnapshot, JSONSnapshot) throws -> Bool) throws {
        guard !identifier.isEmpty, !sourceReference.isEmpty, identifier.utf8.allSatisfy({ $0 >= 33 && $0 < 127 }) else { throw ProjectionProblem.invalidContext }
        self.identifier = identifier; self.sourceReference = sourceReference; evaluator = evaluate
    }
    public func permits(_ plan: AeostaraContract.RecoveryPlan, observed: JSONSnapshot, planned: JSONSnapshot) throws -> Bool {
        try evaluator(plan, observed, planned)
    }
}
public struct NativePolicyContext {
    public let bundle: AeostaraContract.PolicyBundle
    public let rules: [NativePolicyRule]
    public init(bundle: AeostaraContract.PolicyBundle, rules: [NativePolicyRule]) throws {
        guard !rules.isEmpty, Set(rules.map(\.identifier)).count == rules.count else { throw ProjectionProblem.invalidContext }
        for entry in bundle.rules {
            guard case .string(let identifier) = entry.member("ruleID"), rules.contains(where: { $0.identifier == identifier }),
                  case .string(let source) = entry.member("sourceReference"), rules.contains(where: { $0.identifier == identifier && $0.sourceReference.utf8.elementsEqual(source.utf8) }) else { throw ProjectionProblem.invalidContext }
        }
        guard bundle.rules.count == rules.count, bundle.sourceReferences.allSatisfy({ !$0.isEmpty }),
              Set(bundle.rules.compactMap { entry -> String? in if case .string(let id) = entry.member("ruleID") { return id }; return nil }) == Set(rules.map(\.identifier)),
              bundle.bundleHash == (try Self.contentHash(bundleID: bundle.policyBundleID, sources: bundle.sourceReferences, rules: bundle.rules)) else { throw ProjectionProblem.invalidContext }
        self.bundle = bundle; self.rules = rules
    }
    public static func contentHash(bundleID: String, sources: [String], rules: [JSONValue]) throws -> String {
        try JSONValue.object([JSONMember("policyBundleID", .string(bundleID)), JSONMember("sourceReferences", .array(sources.map(JSONValue.string))), JSONMember("rules", .array(rules))]).canonicalHash()
    }
    public static func make(bundleID: String, rules: [NativePolicyRule]) throws -> NativePolicyContext {
        let sources = rules.map(\.sourceReference)
        let entries = rules.map { JSONValue.object([JSONMember("ruleID", .string($0.identifier)), JSONMember("sourceReference", .string($0.sourceReference))]) }
        return try .init(bundle: .init(policyBundleID: bundleID, sourceReferences: sources, rules: entries,
            bundleHash: contentHash(bundleID: bundleID, sources: sources, rules: entries)), rules: rules)
    }
    public func permits(_ plan: AeostaraContract.RecoveryPlan, observed: JSONSnapshot, planned: JSONSnapshot) throws -> Bool {
        for entry in bundle.rules {
            guard case .string(let id) = entry.member("ruleID"), let rule = rules.first(where: { $0.identifier == id }) else { throw ProjectionProblem.invalidContext }
            if try !rule.permits(plan, observed: observed, planned: planned) { return false }
        }
        return true
    }
}

public protocol LegacySemanticLifecycle: AnyObject {
    func validate(configPath: String, desiredPath: String, invariantsPath: String?, semanticContext: SemanticContext) throws -> ValidationResult
    func diff(configPath: String, desiredPath: String, invariantsPath: String?, semanticContext: SemanticContext) throws -> DiffResult
    func heal(configPath: String, desiredPath: String, invariantsPath: String?, auditPath: String, semanticContext: SemanticContext) throws -> HealResult
}

public protocol NativePreparedExecution: AnyObject {
    var contextIdentity: String { get }
    var observedCanonicalHash: String { get }
    var desiredCanonicalHash: String { get }
    var policyBundle: AeostaraContract.PolicyBundle { get }
    var preparedPlan: AeostaraContract.DryRunResult { get }
    var executionContext: AeostaraContract.ExecutionContext { get }
    func execute() throws -> AeostaraContract.HealResult
}
extension AeostaraContract {
    public protocol IHealingEngine {
        func dryRun(observedState: ObservedSystemState, desiredIntent: DesiredSystemIntent,
                    projectionSpec: SemanticProjectionSpec, policyBundle: PolicyBundle) throws -> DryRunResult
        func heal(observedState: ObservedSystemState, desiredIntent: DesiredSystemIntent,
                  projectionSpec: SemanticProjectionSpec, policyBundle: PolicyBundle,
                  executionContext: ExecutionContext) throws -> HealResult
    }
    public protocol ISemanticProjector {
        func project(observedState: ObservedSystemState, desiredIntent: DesiredSystemIntent,
                     projectionSpec: SemanticProjectionSpec) throws -> MappingResult
    }
}
