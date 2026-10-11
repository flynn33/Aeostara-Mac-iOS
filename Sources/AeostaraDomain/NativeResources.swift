import Foundation

public struct NativeResourceSet: Equatable {
    public let configuration: String
    public let desired: String
    public let audit: String
    public let backupDirectory: String
    public init(configuration: String, desired: String, audit: String, backupDirectory: String) throws {
        guard [configuration,desired,audit,backupDirectory].allSatisfy({ $0.hasPrefix("/") && !$0.utf8.contains(0) }),
              Set([configuration,desired,audit].map { Data($0.utf8) }).count == 3 else { throw ResourceIOFault.scopeViolation }
        self.configuration = configuration; self.desired = desired; self.audit = audit; self.backupDirectory = backupDirectory
    }
}
public enum ResourceIOFault: Error, Equatable { case scopeViolation, resourceBusy, staleSnapshot, backupCollision, readFailed, writeFailed, auditFailed, backupFailed }
public struct NativeBackupReceipt {
    public let storageReference: String
    public let bytesHash: String
    public let sourceHash: String
    public init(storageReference: String, bytesHash: String, sourceHash: String) { self.storageReference = storageReference; self.bytesHash = bytesHash; self.sourceHash = sourceHash }
}
public protocol NativeResourceLease: AnyObject {
    var resources: NativeResourceSet { get }
    func readConfiguration() throws -> Data
    func readDesired() throws -> Data
    func persistAudit(events: [AeostaraContract.AuditEvent]) throws
    func createBackup(bytes: Data, sourceHash: String, identifier: String) throws -> NativeBackupReceipt
    func replaceConfiguration(bytes: Data, expectedBytesHash: String) throws
    func restoreBackup(_ receipt: NativeBackupReceipt, expectedBytesHash: String) throws -> Data
    func release()
}
public protocol SemanticResourceIO {
    func read(path: String) throws -> Data
    func acquire(resources: NativeResourceSet) throws -> any NativeResourceLease
}

public struct NativePolicyInput {
    public let plan: AeostaraContract.RecoveryPlan
    public let observed: JSONValue
    public let resources: NativeResourceSet?
}
public struct RegisteredPolicyPredicate {
    public let identifier: String
    public let sourceReferences: [String]
    private let body: (NativePolicyInput) throws -> Bool
    public init(identifier: String, sourceReferences: [String], evaluate: @escaping (NativePolicyInput) throws -> Bool) throws {
        guard !identifier.isEmpty, !sourceReferences.isEmpty else { throw SemanticInputFault.malformedEvidence }
        self.identifier = identifier; self.sourceReferences = sourceReferences; body = evaluate
    }
    public func evaluate(_ input: NativePolicyInput) throws -> Bool { try body(input) }
}
/// Immutable policy membership; registered predicates explain actual applicability, never perform I/O.
public struct NativePolicyRegistry {
    private let predicates: [RegisteredPolicyPredicate]
    public let propagationRiskPolicyID: String
    public init(predicates: [RegisteredPolicyPredicate], propagationRiskPolicyID: String) throws {
        guard Set(predicates.map { Data($0.identifier.utf8) }).count == predicates.count,
              predicates.contains(where: { $0.identifier.utf8.elementsEqual(propagationRiskPolicyID.utf8) }) else { throw SemanticInputFault.missingEvidence }
        self.predicates = predicates; self.propagationRiskPolicyID = propagationRiskPolicyID
    }
    public func adding(_ entries: [RegisteredPolicyPredicate]) throws -> NativePolicyRegistry { try .init(predicates:predicates + entries,propagationRiskPolicyID:propagationRiskPolicyID) }
    public func evaluate(_ identifier: String, input: NativePolicyInput) throws -> Bool {
        guard let entry = predicates.first(where: { $0.identifier.utf8.elementsEqual(identifier.utf8) }) else { throw SemanticInputFault.missingEvidence }
        return try entry.evaluate(input)
    }
    public func decide(bundle: AeostaraContract.PolicyBundle, input: NativePolicyInput, diagnostic: AeostaraContract.DiagnosticReference) throws -> AeostaraContract.PolicyDecision {
        let identity = JSONValue.object([JSONMember("policyBundleID",.string(bundle.policyBundleID)),JSONMember("rules",.array(bundle.rules)),JSONMember("sourceReferences",.array(bundle.sourceReferences.map(JSONValue.string)))])
        guard try CanonicalJSON.hash(identity) == bundle.bundleHash else { throw SemanticInputFault.malformedEvidence }
        var decision = AeostaraContract.PolicyDecision.DecisionValue.ALLOW
        var reasons: [String] = []
        for rule in bundle.rules {
            guard let members = rule.objectMembers, Set(members.map { $0.name }) == ["policyID","predicateID","effect"],
                  let id = rule.member("policyID")?.stringValue, !id.isEmpty,
                  let predicate = rule.member("predicateID")?.stringValue,
                  let effect = rule.member("effect")?.stringValue, let selected = AeostaraContract.PolicyDecision.DecisionValue(rawValue:effect) else { throw SemanticInputFault.malformedEvidence }
            if try evaluate(predicate,input:input) {
                reasons.append(id)
                if selected == .ESCALATE || (selected == .BLOCK && decision != .ESCALATE) { decision = selected }
            }
        }
        guard !reasons.isEmpty else { throw SemanticInputFault.missingEvidence }
        if input.plan.requiresPolicyGate {
            if !(try evaluate(propagationRiskPolicyID,input:input)) { decision = .ESCALATE; reasons.append(propagationRiskPolicyID) }
        }
        let hash = try CanonicalJSON.hash(.object([JSONMember("bundle",.string(bundle.bundleHash)),JSONMember("plan",.string(input.plan.planHash)),JSONMember("decision",.string(decision.rawValue)),JSONMember("reasons",.array(reasons.map(JSONValue.string)))]))
        return try AeostaraContract.PolicyDecision(policyDecisionID:"policy-"+hash,decision:decision,policyBundleID:bundle.policyBundleID,reasons:reasons,diagnosticReference:diagnostic)
    }
}
public struct JSONSnapshotRegistry {
    public let snapshots: [JSONSnapshot]
    public init(_ snapshots: [JSONSnapshot]) throws {
        guard Set(snapshots.map { Data($0.reference.documentID.utf8) }).count == snapshots.count else { throw SemanticInputFault.malformedEvidence }; self.snapshots = snapshots
    }
    public func resolve(_ reference: AeostaraContract.JsonDocumentReference) throws -> JSONSnapshot {
        guard let value = try snapshots.first(where:{ try ContractCoding.canonicalEncode($0.reference) == ContractCoding.canonicalEncode(reference) }) else { throw SemanticInputFault.missingEvidence }; return value
    }
}
