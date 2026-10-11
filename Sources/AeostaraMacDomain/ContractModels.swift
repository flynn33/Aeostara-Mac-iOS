import Foundation

public protocol ContractValue: Codable {
    init(contractJSON: JSONValue) throws
    var contractJSON: JSONValue { get }
}

public enum ContractCoding {
    public static func canonicalEncode<T: ContractValue>(_ value: T) throws -> Data { try value.contractJSON.canonicalData() }
    public static func canonicalDecode<T: ContractValue>(_ type: T.Type, from data: Data) throws -> T {
        let value = try T(contractJSON: JSONValue.parseContractInput(data))
        // Typed integer fields have now normalized exact lexemes; free JSON retains finite-real rules.
        _ = try value.contractJSON.canonicalData()
        return value
    }
}

public enum AeostaraContract {
    // Frozen schema AdmissibilityResult.schema.json sha256=3a76cdea67999665270d9717202a88b3ee047cdbe596fb2c2f8fcc18a3f6e80d
    public struct AdmissibilityResult: ContractValue, Equatable {
        public static func == (lhs: AdmissibilityResult, rhs: AdmissibilityResult) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let resultID: String
        public let stateReference: String
        public enum Status: String, ContractValue {
            case valid = "VALID"
            case transformationCompatible = "TRANSFORMATION_COMPATIBLE"
            case transformationIncompatible = "TRANSFORMATION_INCOMPATIBLE"
            case unclassified = "UNCLASSIFIED"
            public init(contractJSON: JSONValue) throws { guard let value = Self(rawValue: try ContractFields.string(contractJSON)) else { throw CanonicalJSONError.invalidContract("AdmissibilityResult.status") }; self = value }
            public var contractJSON: JSONValue { .string(rawValue) }
        }
        public let status: Status
        public let orbitReference: String
        public let diagnosticReference: DiagnosticReference
        public init(resultID: String, stateReference: String, status: Status, orbitReference: String, diagnosticReference: DiagnosticReference) throws {
            self.resultID = resultID
            self.stateReference = stateReference
            self.status = status
            self.orbitReference = orbitReference
            self.diagnosticReference = diagnosticReference
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["resultID", "stateReference", "status", "orbitReference", "diagnosticReference"])
            try self.init(resultID: try ContractFields.string(try fields.required("resultID")), stateReference: try ContractFields.string(try fields.required("stateReference")), status: try Status(contractJSON: try fields.required("status")), orbitReference: try ContractFields.string(try fields.required("orbitReference")), diagnosticReference: try DiagnosticReference(contractJSON: try fields.required("diagnosticReference")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("resultID", .string(resultID)))
            members.append(JSONMember("stateReference", .string(stateReference)))
            members.append(JSONMember("status", status.contractJSON))
            members.append(JSONMember("orbitReference", .string(orbitReference)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema ArtifactEmissionPlan.schema.json sha256=92626e8f2038eeb6c6c081bd528fdc6da51575256c9b6226e4fa53c8d1f0206d
    public struct ArtifactEmissionPlan: ContractValue, Equatable {
        public static func == (lhs: ArtifactEmissionPlan, rhs: ArtifactEmissionPlan) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let emissionPlanID: String
        public let generationPlanID: String
        public let artifacts: [JSONValue]
        public let traceability: [JSONValue]
        public init(emissionPlanID: String, generationPlanID: String, artifacts: [JSONValue], traceability: [JSONValue]) throws {
            self.emissionPlanID = emissionPlanID
            self.generationPlanID = generationPlanID
            self.artifacts = artifacts
            self.traceability = traceability
            guard artifacts.count >= 1 else { throw CanonicalJSONError.invalidContract("ArtifactEmissionPlan.artifacts array bounds") }
            for item in artifacts { guard case .object = item else { throw CanonicalJSONError.invalidContract("ArtifactEmissionPlan.artifacts[] must be object") } }
            guard traceability.count >= 1 else { throw CanonicalJSONError.invalidContract("ArtifactEmissionPlan.traceability array bounds") }
            for item in traceability { guard case .object = item else { throw CanonicalJSONError.invalidContract("ArtifactEmissionPlan.traceability[] must be object") } }
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["emissionPlanID", "generationPlanID", "artifacts", "traceability"])
            try self.init(emissionPlanID: try ContractFields.string(try fields.required("emissionPlanID")), generationPlanID: try ContractFields.string(try fields.required("generationPlanID")), artifacts: try ContractFields.array(try fields.required("artifacts")).map { $0 }, traceability: try ContractFields.array(try fields.required("traceability")).map { $0 })
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("emissionPlanID", .string(emissionPlanID)))
            members.append(JSONMember("generationPlanID", .string(generationPlanID)))
            members.append(JSONMember("artifacts", .array(artifacts.map { $0 })))
            members.append(JSONMember("traceability", .array(traceability.map { $0 })))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema AshSemanticState.schema.json sha256=a3e38b357d3700c3c392d5aeab6c97261ed6ee3e9cf07c65f3dd80b095abd66f
    public struct AshSemanticState: ContractValue, Equatable {
        public static func == (lhs: AshSemanticState, rhs: AshSemanticState) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let ashSemanticStateID: String
        public let ashState: AshState
        public let admissibilityResult: AdmissibilityResult
        public let realmIdentity: RealmIdentity
        public let diagnosticReference: DiagnosticReference
        public init(ashSemanticStateID: String, ashState: AshState, admissibilityResult: AdmissibilityResult, realmIdentity: RealmIdentity, diagnosticReference: DiagnosticReference) throws {
            self.ashSemanticStateID = ashSemanticStateID
            self.ashState = ashState
            self.admissibilityResult = admissibilityResult
            self.realmIdentity = realmIdentity
            self.diagnosticReference = diagnosticReference
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["ashSemanticStateID", "ashState", "admissibilityResult", "realmIdentity", "diagnosticReference"])
            try self.init(ashSemanticStateID: try ContractFields.string(try fields.required("ashSemanticStateID")), ashState: try AshState(contractJSON: try fields.required("ashState")), admissibilityResult: try AdmissibilityResult(contractJSON: try fields.required("admissibilityResult")), realmIdentity: try RealmIdentity(contractJSON: try fields.required("realmIdentity")), diagnosticReference: try DiagnosticReference(contractJSON: try fields.required("diagnosticReference")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("ashSemanticStateID", .string(ashSemanticStateID)))
            members.append(JSONMember("ashState", ashState.contractJSON))
            members.append(JSONMember("admissibilityResult", admissibilityResult.contractJSON))
            members.append(JSONMember("realmIdentity", realmIdentity.contractJSON))
            members.append(JSONMember("diagnosticReference", diagnosticReference.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema AshState.schema.json sha256=27657d88d336290c6e291e22b0899d204ec0151f726b83703684ba61fc8056d4
    public struct AshState: ContractValue, Equatable {
        public static func == (lhs: AshState, rhs: AshState) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let stateID: String
        public let coordinates: [Int]
        public let sourceReference: String
        public let canonicalHash: String
        public init(stateID: String, coordinates: [Int], sourceReference: String, canonicalHash: String) throws {
            self.stateID = stateID
            self.coordinates = coordinates
            self.sourceReference = sourceReference
            self.canonicalHash = canonicalHash
            guard coordinates.count >= 9 && coordinates.count <= 9 else { throw CanonicalJSONError.invalidContract("AshState.coordinates array bounds") }
            for item in coordinates { guard [0,1].contains(item) else { throw CanonicalJSONError.invalidContract("AshState.coordinates[] enum") } }
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["stateID", "coordinates", "sourceReference", "canonicalHash"])
            try self.init(stateID: try ContractFields.string(try fields.required("stateID")), coordinates: try ContractFields.array(try fields.required("coordinates")).map { try ContractFields.integer($0) }, sourceReference: try ContractFields.string(try fields.required("sourceReference")), canonicalHash: try ContractFields.string(try fields.required("canonicalHash")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("stateID", .string(stateID)))
            members.append(JSONMember("coordinates", .array(coordinates.map { .integer(String($0)) })))
            members.append(JSONMember("sourceReference", .string(sourceReference)))
            members.append(JSONMember("canonicalHash", .string(canonicalHash)))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema AuditChain.schema.json sha256=81d89c4d0b4e7a10f3828f3ea97cd0ddfe0c6d8070759d773cef4d7945a7436f
    public struct AuditChain: ContractValue, Equatable {
        public static func == (lhs: AuditChain, rhs: AuditChain) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let auditChainID: String
        public let diagnosticChainReference: String
        public let events: [AuditEvent]
        public init(auditChainID: String, diagnosticChainReference: String, events: [AuditEvent]) throws {
            self.auditChainID = auditChainID
            self.diagnosticChainReference = diagnosticChainReference
            self.events = events
            guard events.count >= 1 else { throw CanonicalJSONError.invalidContract("AuditChain.events array bounds") }
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["auditChainID", "diagnosticChainReference", "events"])
            try self.init(auditChainID: try ContractFields.string(try fields.required("auditChainID")), diagnosticChainReference: try ContractFields.string(try fields.required("diagnosticChainReference")), events: try ContractFields.array(try fields.required("events")).map { try AuditEvent(contractJSON: $0) })
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("auditChainID", .string(auditChainID)))
            members.append(JSONMember("diagnosticChainReference", .string(diagnosticChainReference)))
            members.append(JSONMember("events", .array(events.map { $0.contractJSON })))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema AuditEvent.schema.json sha256=8228db32c7309d70667ce475fc7299db2d7e27506c28a3450239e15050457de5
    public struct AuditEvent: ContractValue, Equatable {
        public static func == (lhs: AuditEvent, rhs: AuditEvent) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let auditEventID: String
        public let eventSequence: ContractInteger
        public enum EventType: String, ContractValue {
            case observe = "OBSERVE"
            case normalize = "NORMALIZE"
            case project = "PROJECT"
            case diagnose = "DIAGNOSE"
            case classify = "CLASSIFY"
            case plan = "PLAN"
            case policyGate = "POLICY_GATE"
            case backup = "BACKUP"
            case execute = "EXECUTE"
            case verify = "VERIFY"
            case rollback = "ROLLBACK"
            case fallback = "FALLBACK"
            case containment = "CONTAINMENT"
            case safeHalt = "SAFE_HALT"
            case result = "RESULT"
            public init(contractJSON: JSONValue) throws { guard let value = Self(rawValue: try ContractFields.string(contractJSON)) else { throw CanonicalJSONError.invalidContract("AuditEvent.eventType") }; self = value }
            public var contractJSON: JSONValue { .string(rawValue) }
        }
        public let eventType: EventType
        public let diagnosticReference: DiagnosticReference
        public let occurredAt: String
        public let details: JSONValue
        public init(auditEventID: String, eventSequence: ContractInteger, eventType: EventType, diagnosticReference: DiagnosticReference, occurredAt: String, details: JSONValue) throws {
            self.auditEventID = auditEventID
            self.eventSequence = eventSequence
            self.eventType = eventType
            self.diagnosticReference = diagnosticReference
            self.occurredAt = occurredAt
            self.details = details
            guard case .object = details else { throw CanonicalJSONError.invalidContract("AuditEvent.details must be object") }
        }
        public init(auditEventID: String, eventSequence: Int, eventType: EventType, diagnosticReference: DiagnosticReference, occurredAt: String, details: JSONValue) throws {
            try self.init(auditEventID: auditEventID, eventSequence: ContractInteger(eventSequence), eventType: eventType, diagnosticReference: diagnosticReference, occurredAt: occurredAt, details: details)
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["auditEventID", "eventSequence", "eventType", "diagnosticReference", "occurredAt", "details"])
            try self.init(auditEventID: try ContractFields.string(try fields.required("auditEventID")), eventSequence: try ContractInteger(contractJSON: fields.required("eventSequence")), eventType: try EventType(contractJSON: try fields.required("eventType")), diagnosticReference: try DiagnosticReference(contractJSON: try fields.required("diagnosticReference")), occurredAt: try ContractFields.string(try fields.required("occurredAt")), details: try fields.required("details"))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("auditEventID", .string(auditEventID)))
            members.append(JSONMember("eventSequence", .integer(eventSequence.description)))
            members.append(JSONMember("eventType", eventType.contractJSON))
            members.append(JSONMember("diagnosticReference", diagnosticReference.contractJSON))
            members.append(JSONMember("occurredAt", .string(occurredAt)))
            members.append(JSONMember("details", details))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema AxiomDiagnostic.schema.json sha256=211efff759e225d283a9f683e8901d5d60740ef640c3bb54ed9bf64074f22ca0
    public struct AxiomDiagnostic: ContractValue, Equatable {
        public static func == (lhs: AxiomDiagnostic, rhs: AxiomDiagnostic) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let axiomID: String
        public let diagnosticEnvelope: DiagnosticEnvelope
        public enum EvaluationResult: String, ContractValue {
            case pass = "PASS"
            case fail = "FAIL"
            case blocked = "BLOCKED"
            public init(contractJSON: JSONValue) throws { guard let value = Self(rawValue: try ContractFields.string(contractJSON)) else { throw CanonicalJSONError.invalidContract("AxiomDiagnostic.evaluationResult") }; self = value }
            public var contractJSON: JSONValue { .string(rawValue) }
        }
        public let evaluationResult: EvaluationResult
        public let evidence: JSONValue
        public init(axiomID: String, diagnosticEnvelope: DiagnosticEnvelope, evaluationResult: EvaluationResult, evidence: JSONValue) throws {
            self.axiomID = axiomID
            self.diagnosticEnvelope = diagnosticEnvelope
            self.evaluationResult = evaluationResult
            self.evidence = evidence
            guard case .object = evidence else { throw CanonicalJSONError.invalidContract("AxiomDiagnostic.evidence must be object") }
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["axiomID", "diagnosticEnvelope", "evaluationResult", "evidence"])
            try self.init(axiomID: try ContractFields.string(try fields.required("axiomID")), diagnosticEnvelope: try DiagnosticEnvelope(contractJSON: try fields.required("diagnosticEnvelope")), evaluationResult: try EvaluationResult(contractJSON: try fields.required("evaluationResult")), evidence: try fields.required("evidence"))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("axiomID", .string(axiomID)))
            members.append(JSONMember("diagnosticEnvelope", diagnosticEnvelope.contractJSON))
            members.append(JSONMember("evaluationResult", evaluationResult.contractJSON))
            members.append(JSONMember("evidence", evidence))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema BackupRecord.schema.json sha256=6297cd19aec0783027414a3f7d0be72efb9a7e1a6d064a0dd51a41e3d971db43
    public struct BackupRecord: ContractValue, Equatable {
        public static func == (lhs: BackupRecord, rhs: BackupRecord) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let backupRecordID: String
        public let sourceDocument: JsonDocumentReference
        public let sourceHash: String
        public let storageReference: String
        public let diagnosticReference: DiagnosticReference
        public init(backupRecordID: String, sourceDocument: JsonDocumentReference, sourceHash: String, storageReference: String, diagnosticReference: DiagnosticReference) throws {
            self.backupRecordID = backupRecordID
            self.sourceDocument = sourceDocument
            self.sourceHash = sourceHash
            self.storageReference = storageReference
            self.diagnosticReference = diagnosticReference
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["backupRecordID", "sourceDocument", "sourceHash", "storageReference", "diagnosticReference"])
            try self.init(backupRecordID: try ContractFields.string(try fields.required("backupRecordID")), sourceDocument: try JsonDocumentReference(contractJSON: try fields.required("sourceDocument")), sourceHash: try ContractFields.string(try fields.required("sourceHash")), storageReference: try ContractFields.string(try fields.required("storageReference")), diagnosticReference: try DiagnosticReference(contractJSON: try fields.required("diagnosticReference")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("backupRecordID", .string(backupRecordID)))
            members.append(JSONMember("sourceDocument", sourceDocument.contractJSON))
            members.append(JSONMember("sourceHash", .string(sourceHash)))
            members.append(JSONMember("storageReference", .string(storageReference)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema BackupResult.schema.json sha256=66be53e5f47113013652f7cd086241e74189a75ccaef2675c522ed7ca3ab3388
    public struct BackupResult: ContractValue, Equatable {
        public static func == (lhs: BackupResult, rhs: BackupResult) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let backupResultID: String
        public enum Status: String, ContractValue {
            case succeeded = "SUCCEEDED"
            case failed = "FAILED"
            case skipped = "SKIPPED"
            public init(contractJSON: JSONValue) throws { guard let value = Self(rawValue: try ContractFields.string(contractJSON)) else { throw CanonicalJSONError.invalidContract("BackupResult.status") }; self = value }
            public var contractJSON: JSONValue { .string(rawValue) }
        }
        public let status: Status
        public let backupRecord: BackupRecord
        public let escalationDecision: EscalationDecision?
        public let diagnosticReference: DiagnosticReference
        public init(backupResultID: String, status: Status, backupRecord: BackupRecord, escalationDecision: EscalationDecision? = nil, diagnosticReference: DiagnosticReference) throws {
            self.backupResultID = backupResultID
            self.status = status
            self.backupRecord = backupRecord
            self.escalationDecision = escalationDecision
            self.diagnosticReference = diagnosticReference
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["backupResultID", "status", "backupRecord", "escalationDecision", "diagnosticReference"])
            try self.init(backupResultID: try ContractFields.string(try fields.required("backupResultID")), status: try Status(contractJSON: try fields.required("status")), backupRecord: try BackupRecord(contractJSON: try fields.required("backupRecord")), escalationDecision: try fields.optional("escalationDecision").map { try EscalationDecision(contractJSON: $0) }, diagnosticReference: try DiagnosticReference(contractJSON: try fields.required("diagnosticReference")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("backupResultID", .string(backupResultID)))
            members.append(JSONMember("status", status.contractJSON))
            members.append(JSONMember("backupRecord", backupRecord.contractJSON))
            if let value = escalationDecision { members.append(JSONMember("escalationDecision", value.contractJSON)) }
            members.append(JSONMember("diagnosticReference", diagnosticReference.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema CanonicalCodewordSet.schema.json sha256=a3be7b22885d150d4aee8e4ca48bdca1c7f60eaada3793b6da972a0423f3d3a7
    public struct CanonicalCodewordSet: ContractValue, Equatable {
        public static func == (lhs: CanonicalCodewordSet, rhs: CanonicalCodewordSet) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let codewordSetID: String
        public let codewords: [[Int]]
        public let sourceReference: String
        public let canonicalHash: String
        public init(codewordSetID: String, codewords: [[Int]], sourceReference: String, canonicalHash: String) throws {
            self.codewordSetID = codewordSetID
            self.codewords = codewords
            self.sourceReference = sourceReference
            self.canonicalHash = canonicalHash
            guard codewords.count >= 16 && codewords.count <= 16 else { throw CanonicalJSONError.invalidContract("CanonicalCodewordSet.codewords array bounds") }
            for item in codewords { guard item.count >= 9 && item.count <= 9 else { throw CanonicalJSONError.invalidContract("CanonicalCodewordSet.codewords[] array bounds") }; for item in item { guard [0,1].contains(item) else { throw CanonicalJSONError.invalidContract("CanonicalCodewordSet.codewords[][] enum") } } }
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["codewordSetID", "codewords", "sourceReference", "canonicalHash"])
            try self.init(codewordSetID: try ContractFields.string(try fields.required("codewordSetID")), codewords: try ContractFields.array(try fields.required("codewords")).map { try ContractFields.array($0).map { try ContractFields.integer($0) } }, sourceReference: try ContractFields.string(try fields.required("sourceReference")), canonicalHash: try ContractFields.string(try fields.required("canonicalHash")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("codewordSetID", .string(codewordSetID)))
            members.append(JSONMember("codewords", .array(codewords.map { .array($0.map { .integer(String($0)) }) })))
            members.append(JSONMember("sourceReference", .string(sourceReference)))
            members.append(JSONMember("canonicalHash", .string(canonicalHash)))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema CodewordTransformation.schema.json sha256=c880dd20d907dc420af1559501af5e48258619963c587703366177f095cbb056
    public struct CodewordTransformation: ContractValue, Equatable {
        public static func == (lhs: CodewordTransformation, rhs: CodewordTransformation) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let transformationID: String
        public let inputState: AshState
        public let codeword: [Int]
        public let outputState: AshState
        public let diagnosticReference: DiagnosticReference
        public init(transformationID: String, inputState: AshState, codeword: [Int], outputState: AshState, diagnosticReference: DiagnosticReference) throws {
            self.transformationID = transformationID
            self.inputState = inputState
            self.codeword = codeword
            self.outputState = outputState
            self.diagnosticReference = diagnosticReference
            guard codeword.count >= 9 && codeword.count <= 9 else { throw CanonicalJSONError.invalidContract("CodewordTransformation.codeword array bounds") }
            for item in codeword { guard [0,1].contains(item) else { throw CanonicalJSONError.invalidContract("CodewordTransformation.codeword[] enum") } }
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["transformationID", "inputState", "codeword", "outputState", "diagnosticReference"])
            try self.init(transformationID: try ContractFields.string(try fields.required("transformationID")), inputState: try AshState(contractJSON: try fields.required("inputState")), codeword: try ContractFields.array(try fields.required("codeword")).map { try ContractFields.integer($0) }, outputState: try AshState(contractJSON: try fields.required("outputState")), diagnosticReference: try DiagnosticReference(contractJSON: try fields.required("diagnosticReference")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("transformationID", .string(transformationID)))
            members.append(JSONMember("inputState", inputState.contractJSON))
            members.append(JSONMember("codeword", .array(codeword.map { .integer(String($0)) })))
            members.append(JSONMember("outputState", outputState.contractJSON))
            members.append(JSONMember("diagnosticReference", diagnosticReference.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema ContainmentDecision.schema.json sha256=37b6780a3c135e4997ace0f4f602dd66e9b930f34955f705ebc59196aa2c9c4b
    public struct ContainmentDecision: ContractValue, Equatable {
        public static func == (lhs: ContainmentDecision, rhs: ContainmentDecision) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let containmentDecisionID: String
        public let boundary: JSONValue
        public let allowedOperations: [String]
        public let restrictedOperations: [String]
        public let diagnosticReference: DiagnosticReference
        public init(containmentDecisionID: String, boundary: JSONValue, allowedOperations: [String], restrictedOperations: [String], diagnosticReference: DiagnosticReference) throws {
            self.containmentDecisionID = containmentDecisionID
            self.boundary = boundary
            self.allowedOperations = allowedOperations
            self.restrictedOperations = restrictedOperations
            self.diagnosticReference = diagnosticReference
            guard case .object = boundary else { throw CanonicalJSONError.invalidContract("ContainmentDecision.boundary must be object") }
            guard allowedOperations.count >= 0 else { throw CanonicalJSONError.invalidContract("ContainmentDecision.allowedOperations array bounds") }
            guard restrictedOperations.count >= 1 else { throw CanonicalJSONError.invalidContract("ContainmentDecision.restrictedOperations array bounds") }
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["containmentDecisionID", "boundary", "allowedOperations", "restrictedOperations", "diagnosticReference"])
            try self.init(containmentDecisionID: try ContractFields.string(try fields.required("containmentDecisionID")), boundary: try fields.required("boundary"), allowedOperations: try ContractFields.array(try fields.required("allowedOperations")).map { try ContractFields.string($0) }, restrictedOperations: try ContractFields.array(try fields.required("restrictedOperations")).map { try ContractFields.string($0) }, diagnosticReference: try DiagnosticReference(contractJSON: try fields.required("diagnosticReference")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("containmentDecisionID", .string(containmentDecisionID)))
            members.append(JSONMember("boundary", boundary))
            members.append(JSONMember("allowedOperations", .array(allowedOperations.map { .string($0) })))
            members.append(JSONMember("restrictedOperations", .array(restrictedOperations.map { .string($0) })))
            members.append(JSONMember("diagnosticReference", diagnosticReference.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema DesiredState.schema.json sha256=b05edf9738ce8578fe0b7c4792287c9e9b49a86edb9ccfcda8c82104baba16af
    public struct DesiredState: ContractValue, Equatable {
        public static func == (lhs: DesiredState, rhs: DesiredState) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let desiredStateID: String
        public let desiredSystemIntent: DesiredSystemIntent
        public let evidenceOnly: Bool
        public init(desiredStateID: String, desiredSystemIntent: DesiredSystemIntent, evidenceOnly: Bool) throws {
            self.desiredStateID = desiredStateID
            self.desiredSystemIntent = desiredSystemIntent
            self.evidenceOnly = evidenceOnly
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["desiredStateID", "desiredSystemIntent", "evidenceOnly"])
            try self.init(desiredStateID: try ContractFields.string(try fields.required("desiredStateID")), desiredSystemIntent: try DesiredSystemIntent(contractJSON: try fields.required("desiredSystemIntent")), evidenceOnly: try ContractFields.boolean(try fields.required("evidenceOnly")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("desiredStateID", .string(desiredStateID)))
            members.append(JSONMember("desiredSystemIntent", desiredSystemIntent.contractJSON))
            members.append(JSONMember("evidenceOnly", .bool(evidenceOnly)))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema DesiredSystemIntent.schema.json sha256=4fec3df36a756da61be59b79e6d9acc1e92205bd3d031f7d168d5091c5a032c2
    public struct DesiredSystemIntent: ContractValue, Equatable {
        public static func == (lhs: DesiredSystemIntent, rhs: DesiredSystemIntent) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let desiredSystemIntentID: String
        public let documentReference: JsonDocumentReference
        public let partialIntent: Bool
        public let diagnosticReference: DiagnosticReference
        public init(desiredSystemIntentID: String, documentReference: JsonDocumentReference, partialIntent: Bool, diagnosticReference: DiagnosticReference) throws {
            self.desiredSystemIntentID = desiredSystemIntentID
            self.documentReference = documentReference
            self.partialIntent = partialIntent
            self.diagnosticReference = diagnosticReference
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["desiredSystemIntentID", "documentReference", "partialIntent", "diagnosticReference"])
            try self.init(desiredSystemIntentID: try ContractFields.string(try fields.required("desiredSystemIntentID")), documentReference: try JsonDocumentReference(contractJSON: try fields.required("documentReference")), partialIntent: try ContractFields.boolean(try fields.required("partialIntent")), diagnosticReference: try DiagnosticReference(contractJSON: try fields.required("diagnosticReference")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("desiredSystemIntentID", .string(desiredSystemIntentID)))
            members.append(JSONMember("documentReference", documentReference.contractJSON))
            members.append(JSONMember("partialIntent", .bool(partialIntent)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema DiagnosticChain.schema.json sha256=1255a5a76633cf7b34658887bdecbb4312cafd75176752ec08e3148591200a1a
    public struct DiagnosticChain: ContractValue, Equatable {
        public static func == (lhs: DiagnosticChain, rhs: DiagnosticChain) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let chainID: String
        public let rootDiagnosticID: String
        public let diagnostics: [DiagnosticEnvelope]
        public init(chainID: String, rootDiagnosticID: String, diagnostics: [DiagnosticEnvelope]) throws {
            self.chainID = chainID
            self.rootDiagnosticID = rootDiagnosticID
            self.diagnostics = diagnostics
            guard diagnostics.count >= 1 else { throw CanonicalJSONError.invalidContract("DiagnosticChain.diagnostics array bounds") }
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["chainID", "rootDiagnosticID", "diagnostics"])
            try self.init(chainID: try ContractFields.string(try fields.required("chainID")), rootDiagnosticID: try ContractFields.string(try fields.required("rootDiagnosticID")), diagnostics: try ContractFields.array(try fields.required("diagnostics")).map { try DiagnosticEnvelope(contractJSON: $0) })
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("chainID", .string(chainID)))
            members.append(JSONMember("rootDiagnosticID", .string(rootDiagnosticID)))
            members.append(JSONMember("diagnostics", .array(diagnostics.map { $0.contractJSON })))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema DiagnosticEnvelope.schema.json sha256=f288f2c53aa49a5fe0ee57c2954c7bbf9b9f6100a249dfd1c51b58641171e977
    public struct DiagnosticEnvelope: ContractValue, Equatable {
        public static func == (lhs: DiagnosticEnvelope, rhs: DiagnosticEnvelope) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let diagnosticID: String
        public let chainRootReference: String
        public let parentDiagnosticID: String?
        public enum DiagnosticKind: String, ContractValue {
            case stateValidity = "STATE_VALIDITY"
            case recovery = "RECOVERY"
            case policy = "POLICY"
            case backup = "BACKUP"
            case execution = "EXECUTION"
            case verification = "VERIFICATION"
            case rollback = "ROLLBACK"
            case fallback = "FALLBACK"
            case containment = "CONTAINMENT"
            case safeHalt = "SAFE_HALT"
            case audit = "AUDIT"
            case mapping = "MAPPING"
            case jsonSemantics = "JSON_SEMANTICS"
            public init(contractJSON: JSONValue) throws { guard let value = Self(rawValue: try ContractFields.string(contractJSON)) else { throw CanonicalJSONError.invalidContract("DiagnosticEnvelope.diagnosticKind") }; self = value }
            public var contractJSON: JSONValue { .string(rawValue) }
        }
        public let diagnosticKind: DiagnosticKind
        public enum Severity: String, ContractValue {
            case info = "INFO"
            case warning = "WARNING"
            case error = "ERROR"
            case critical = "CRITICAL"
            public init(contractJSON: JSONValue) throws { guard let value = Self(rawValue: try ContractFields.string(contractJSON)) else { throw CanonicalJSONError.invalidContract("DiagnosticEnvelope.severity") }; self = value }
            public var contractJSON: JSONValue { .string(rawValue) }
        }
        public let severity: Severity
        public let message: String
        public let ruleReferences: [RuleReference]
        public let sourceReferences: [String]
        public let evidence: JSONValue
        public init(diagnosticID: String, chainRootReference: String, parentDiagnosticID: String?, diagnosticKind: DiagnosticKind, severity: Severity, message: String, ruleReferences: [RuleReference], sourceReferences: [String], evidence: JSONValue) throws {
            self.diagnosticID = diagnosticID
            self.chainRootReference = chainRootReference
            self.parentDiagnosticID = parentDiagnosticID
            self.diagnosticKind = diagnosticKind
            self.severity = severity
            self.message = message
            self.ruleReferences = ruleReferences
            self.sourceReferences = sourceReferences
            self.evidence = evidence
            guard ruleReferences.count >= 1 else { throw CanonicalJSONError.invalidContract("DiagnosticEnvelope.ruleReferences array bounds") }
            guard sourceReferences.count >= 1 else { throw CanonicalJSONError.invalidContract("DiagnosticEnvelope.sourceReferences array bounds") }
            guard case .object = evidence else { throw CanonicalJSONError.invalidContract("DiagnosticEnvelope.evidence must be object") }
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["diagnosticID", "chainRootReference", "parentDiagnosticID", "diagnosticKind", "severity", "message", "ruleReferences", "sourceReferences", "evidence"])
            try self.init(diagnosticID: try ContractFields.string(try fields.required("diagnosticID")), chainRootReference: try ContractFields.string(try fields.required("chainRootReference")), parentDiagnosticID: try ContractFields.nullableString(try fields.required("parentDiagnosticID")), diagnosticKind: try DiagnosticKind(contractJSON: try fields.required("diagnosticKind")), severity: try Severity(contractJSON: try fields.required("severity")), message: try ContractFields.string(try fields.required("message")), ruleReferences: try ContractFields.array(try fields.required("ruleReferences")).map { try RuleReference(contractJSON: $0) }, sourceReferences: try ContractFields.array(try fields.required("sourceReferences")).map { try ContractFields.string($0) }, evidence: try fields.required("evidence"))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("diagnosticID", .string(diagnosticID)))
            members.append(JSONMember("chainRootReference", .string(chainRootReference)))
            members.append(JSONMember("parentDiagnosticID", parentDiagnosticID.map { .string($0) } ?? .null))
            members.append(JSONMember("diagnosticKind", diagnosticKind.contractJSON))
            members.append(JSONMember("severity", severity.contractJSON))
            members.append(JSONMember("message", .string(message)))
            members.append(JSONMember("ruleReferences", .array(ruleReferences.map { $0.contractJSON })))
            members.append(JSONMember("sourceReferences", .array(sourceReferences.map { .string($0) })))
            members.append(JSONMember("evidence", evidence))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema DiagnosticReference.schema.json sha256=f5d21b1afdec6211854f7d13abc92cba94199709494e2f09ccdf8398b45dfcc1
    public struct DiagnosticReference: ContractValue, Equatable {
        public static func == (lhs: DiagnosticReference, rhs: DiagnosticReference) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let diagnosticID: String
        public let chainRootReference: String
        public enum DiagnosticKind: String, ContractValue {
            case stateValidity = "STATE_VALIDITY"
            case recovery = "RECOVERY"
            case policy = "POLICY"
            case backup = "BACKUP"
            case execution = "EXECUTION"
            case verification = "VERIFICATION"
            case rollback = "ROLLBACK"
            case fallback = "FALLBACK"
            case containment = "CONTAINMENT"
            case safeHalt = "SAFE_HALT"
            case audit = "AUDIT"
            case mapping = "MAPPING"
            case jsonSemantics = "JSON_SEMANTICS"
            public init(contractJSON: JSONValue) throws { guard let value = Self(rawValue: try ContractFields.string(contractJSON)) else { throw CanonicalJSONError.invalidContract("DiagnosticReference.diagnosticKind") }; self = value }
            public var contractJSON: JSONValue { .string(rawValue) }
        }
        public let diagnosticKind: DiagnosticKind
        public let ruleReferences: [RuleReference]
        public init(diagnosticID: String, chainRootReference: String, diagnosticKind: DiagnosticKind, ruleReferences: [RuleReference]) throws {
            self.diagnosticID = diagnosticID
            self.chainRootReference = chainRootReference
            self.diagnosticKind = diagnosticKind
            self.ruleReferences = ruleReferences
            guard ruleReferences.count >= 1 else { throw CanonicalJSONError.invalidContract("DiagnosticReference.ruleReferences array bounds") }
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["diagnosticID", "chainRootReference", "diagnosticKind", "ruleReferences"])
            try self.init(diagnosticID: try ContractFields.string(try fields.required("diagnosticID")), chainRootReference: try ContractFields.string(try fields.required("chainRootReference")), diagnosticKind: try DiagnosticKind(contractJSON: try fields.required("diagnosticKind")), ruleReferences: try ContractFields.array(try fields.required("ruleReferences")).map { try RuleReference(contractJSON: $0) })
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("diagnosticID", .string(diagnosticID)))
            members.append(JSONMember("chainRootReference", .string(chainRootReference)))
            members.append(JSONMember("diagnosticKind", diagnosticKind.contractJSON))
            members.append(JSONMember("ruleReferences", .array(ruleReferences.map { $0.contractJSON })))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema DriftEvent.schema.json sha256=21d4934ff1a7c3244595badf876b77ee104e0fb71a1f62ecabe27041df395098
    public struct DriftEvent: ContractValue, Equatable {
        public static func == (lhs: DriftEvent, rhs: DriftEvent) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let driftEventID: String
        public let surfaceDifferences: [SurfaceDifference]
        public let evidenceOnly: Bool
        public let diagnosticReference: DiagnosticReference
        public init(driftEventID: String, surfaceDifferences: [SurfaceDifference], evidenceOnly: Bool, diagnosticReference: DiagnosticReference) throws {
            self.driftEventID = driftEventID
            self.surfaceDifferences = surfaceDifferences
            self.evidenceOnly = evidenceOnly
            self.diagnosticReference = diagnosticReference
            guard surfaceDifferences.count >= 1 else { throw CanonicalJSONError.invalidContract("DriftEvent.surfaceDifferences array bounds") }
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["driftEventID", "surfaceDifferences", "evidenceOnly", "diagnosticReference"])
            try self.init(driftEventID: try ContractFields.string(try fields.required("driftEventID")), surfaceDifferences: try ContractFields.array(try fields.required("surfaceDifferences")).map { try SurfaceDifference(contractJSON: $0) }, evidenceOnly: try ContractFields.boolean(try fields.required("evidenceOnly")), diagnosticReference: try DiagnosticReference(contractJSON: try fields.required("diagnosticReference")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("driftEventID", .string(driftEventID)))
            members.append(JSONMember("surfaceDifferences", .array(surfaceDifferences.map { $0.contractJSON })))
            members.append(JSONMember("evidenceOnly", .bool(evidenceOnly)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema DryRunResult.schema.json sha256=deae36c5a680c5e55699cfefdabfb596fa89162f0befd1caccb02096f5222897
    public struct DryRunResult: ContractValue, Equatable {
        public static func == (lhs: DryRunResult, rhs: DryRunResult) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let dryRunResultID: String
        public let wouldMutate: Bool
        public let recoveryPlan: RecoveryPlan
        public let verificationPlan: VerificationPlan
        public let diagnosticChain: DiagnosticChain
        public init(dryRunResultID: String, wouldMutate: Bool, recoveryPlan: RecoveryPlan, verificationPlan: VerificationPlan, diagnosticChain: DiagnosticChain) throws {
            self.dryRunResultID = dryRunResultID
            self.wouldMutate = wouldMutate
            self.recoveryPlan = recoveryPlan
            self.verificationPlan = verificationPlan
            self.diagnosticChain = diagnosticChain
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["dryRunResultID", "wouldMutate", "recoveryPlan", "verificationPlan", "diagnosticChain"])
            try self.init(dryRunResultID: try ContractFields.string(try fields.required("dryRunResultID")), wouldMutate: try ContractFields.boolean(try fields.required("wouldMutate")), recoveryPlan: try RecoveryPlan(contractJSON: try fields.required("recoveryPlan")), verificationPlan: try VerificationPlan(contractJSON: try fields.required("verificationPlan")), diagnosticChain: try DiagnosticChain(contractJSON: try fields.required("diagnosticChain")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("dryRunResultID", .string(dryRunResultID)))
            members.append(JSONMember("wouldMutate", .bool(wouldMutate)))
            members.append(JSONMember("recoveryPlan", recoveryPlan.contractJSON))
            members.append(JSONMember("verificationPlan", verificationPlan.contractJSON))
            members.append(JSONMember("diagnosticChain", diagnosticChain.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema EncodedState.schema.json sha256=b4ac9a5ca6ed07d08a2068a449c5a6c70fce77a568ee2511f3653a8e8212b5bb
    public struct EncodedState: ContractValue, Equatable {
        public static func == (lhs: EncodedState, rhs: EncodedState) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let encodedStateID: String
        public let encoding: String
        public let ashState: AshState
        public let evidenceOnly: Bool
        public init(encodedStateID: String, encoding: String, ashState: AshState, evidenceOnly: Bool) throws {
            self.encodedStateID = encodedStateID
            self.encoding = encoding
            self.ashState = ashState
            self.evidenceOnly = evidenceOnly
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["encodedStateID", "encoding", "ashState", "evidenceOnly"])
            try self.init(encodedStateID: try ContractFields.string(try fields.required("encodedStateID")), encoding: try ContractFields.string(try fields.required("encoding")), ashState: try AshState(contractJSON: try fields.required("ashState")), evidenceOnly: try ContractFields.boolean(try fields.required("evidenceOnly")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("encodedStateID", .string(encodedStateID)))
            members.append(JSONMember("encoding", .string(encoding)))
            members.append(JSONMember("ashState", ashState.contractJSON))
            members.append(JSONMember("evidenceOnly", .bool(evidenceOnly)))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema EscalationDecision.schema.json sha256=f4584859009a0b8be72ac8b97518b00b0c271bb6249b6189a67ec7376fc28f5d
    public struct EscalationDecision: ContractValue, Equatable {
        public static func == (lhs: EscalationDecision, rhs: EscalationDecision) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let decisionID: String
        public let fromCategory: RecoveryCategory
        public let toCategory: RecoveryCategory
        public let reason: String
        public let diagnosticReference: DiagnosticReference
        public init(decisionID: String, fromCategory: RecoveryCategory, toCategory: RecoveryCategory, reason: String, diagnosticReference: DiagnosticReference) throws {
            self.decisionID = decisionID
            self.fromCategory = fromCategory
            self.toCategory = toCategory
            self.reason = reason
            self.diagnosticReference = diagnosticReference
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["decisionID", "fromCategory", "toCategory", "reason", "diagnosticReference"])
            try self.init(decisionID: try ContractFields.string(try fields.required("decisionID")), fromCategory: try RecoveryCategory(contractJSON: try fields.required("fromCategory")), toCategory: try RecoveryCategory(contractJSON: try fields.required("toCategory")), reason: try ContractFields.string(try fields.required("reason")), diagnosticReference: try DiagnosticReference(contractJSON: try fields.required("diagnosticReference")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("decisionID", .string(decisionID)))
            members.append(JSONMember("fromCategory", fromCategory.contractJSON))
            members.append(JSONMember("toCategory", toCategory.contractJSON))
            members.append(JSONMember("reason", .string(reason)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema ExecutionContext.schema.json sha256=f64a48bcef02f4e01884f3c9dc46eaf72b0e665a184a6956d136672c511dbd6a
    public struct ExecutionContext: ContractValue, Equatable {
        public static func == (lhs: ExecutionContext, rhs: ExecutionContext) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let executionContextID: String
        public let recoveryPlanID: String
        public let policyDecision: PolicyDecision
        public let backupResult: BackupResult
        public let verificationPlan: VerificationPlan
        public let diagnosticReference: DiagnosticReference
        public init(executionContextID: String, recoveryPlanID: String, policyDecision: PolicyDecision, backupResult: BackupResult, verificationPlan: VerificationPlan, diagnosticReference: DiagnosticReference) throws {
            self.executionContextID = executionContextID
            self.recoveryPlanID = recoveryPlanID
            self.policyDecision = policyDecision
            self.backupResult = backupResult
            self.verificationPlan = verificationPlan
            self.diagnosticReference = diagnosticReference
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["executionContextID", "recoveryPlanID", "policyDecision", "backupResult", "verificationPlan", "diagnosticReference"])
            try self.init(executionContextID: try ContractFields.string(try fields.required("executionContextID")), recoveryPlanID: try ContractFields.string(try fields.required("recoveryPlanID")), policyDecision: try PolicyDecision(contractJSON: try fields.required("policyDecision")), backupResult: try BackupResult(contractJSON: try fields.required("backupResult")), verificationPlan: try VerificationPlan(contractJSON: try fields.required("verificationPlan")), diagnosticReference: try DiagnosticReference(contractJSON: try fields.required("diagnosticReference")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("executionContextID", .string(executionContextID)))
            members.append(JSONMember("recoveryPlanID", .string(recoveryPlanID)))
            members.append(JSONMember("policyDecision", policyDecision.contractJSON))
            members.append(JSONMember("backupResult", backupResult.contractJSON))
            members.append(JSONMember("verificationPlan", verificationPlan.contractJSON))
            members.append(JSONMember("diagnosticReference", diagnosticReference.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema ExecutionStepResult.schema.json sha256=c42f2cc506156ee1240870d0a01cc0d783bc753044c85dccaa453e713672af7e
    public struct ExecutionStepResult: ContractValue, Equatable {
        public static func == (lhs: ExecutionStepResult, rhs: ExecutionStepResult) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let executionStepResultID: String
        public let stepID: String
        public enum Status: String, ContractValue {
            case succeeded = "SUCCEEDED"
            case failed = "FAILED"
            case skipped = "SKIPPED"
            case blocked = "BLOCKED"
            public init(contractJSON: JSONValue) throws { guard let value = Self(rawValue: try ContractFields.string(contractJSON)) else { throw CanonicalJSONError.invalidContract("ExecutionStepResult.status") }; self = value }
            public var contractJSON: JSONValue { .string(rawValue) }
        }
        public let status: Status
        public let observedHashAfterStep: String
        public let diagnosticReference: DiagnosticReference
        public init(executionStepResultID: String, stepID: String, status: Status, observedHashAfterStep: String, diagnosticReference: DiagnosticReference) throws {
            self.executionStepResultID = executionStepResultID
            self.stepID = stepID
            self.status = status
            self.observedHashAfterStep = observedHashAfterStep
            self.diagnosticReference = diagnosticReference
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["executionStepResultID", "stepID", "status", "observedHashAfterStep", "diagnosticReference"])
            try self.init(executionStepResultID: try ContractFields.string(try fields.required("executionStepResultID")), stepID: try ContractFields.string(try fields.required("stepID")), status: try Status(contractJSON: try fields.required("status")), observedHashAfterStep: try ContractFields.string(try fields.required("observedHashAfterStep")), diagnosticReference: try DiagnosticReference(contractJSON: try fields.required("diagnosticReference")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("executionStepResultID", .string(executionStepResultID)))
            members.append(JSONMember("stepID", .string(stepID)))
            members.append(JSONMember("status", status.contractJSON))
            members.append(JSONMember("observedHashAfterStep", .string(observedHashAfterStep)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema FallbackDecision.schema.json sha256=84fe0cab2c9b49dfa7cf13f13ade825fb10a1ee318d0d69d8d5b5f6ddaae26d5
    public struct FallbackDecision: ContractValue, Equatable {
        public static func == (lhs: FallbackDecision, rhs: FallbackDecision) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let fallbackDecisionID: String
        public let registryReference: String
        public let selectedCandidateID: String
        public enum Status: String, ContractValue {
            case selected = "SELECTED"
            case unavailable = "UNAVAILABLE"
            case blocked = "BLOCKED"
            public init(contractJSON: JSONValue) throws { guard let value = Self(rawValue: try ContractFields.string(contractJSON)) else { throw CanonicalJSONError.invalidContract("FallbackDecision.status") }; self = value }
            public var contractJSON: JSONValue { .string(rawValue) }
        }
        public let status: Status
        public let diagnosticReference: DiagnosticReference
        public init(fallbackDecisionID: String, registryReference: String, selectedCandidateID: String, status: Status, diagnosticReference: DiagnosticReference) throws {
            self.fallbackDecisionID = fallbackDecisionID
            self.registryReference = registryReference
            self.selectedCandidateID = selectedCandidateID
            self.status = status
            self.diagnosticReference = diagnosticReference
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["fallbackDecisionID", "registryReference", "selectedCandidateID", "status", "diagnosticReference"])
            try self.init(fallbackDecisionID: try ContractFields.string(try fields.required("fallbackDecisionID")), registryReference: try ContractFields.string(try fields.required("registryReference")), selectedCandidateID: try ContractFields.string(try fields.required("selectedCandidateID")), status: try Status(contractJSON: try fields.required("status")), diagnosticReference: try DiagnosticReference(contractJSON: try fields.required("diagnosticReference")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("fallbackDecisionID", .string(fallbackDecisionID)))
            members.append(JSONMember("registryReference", .string(registryReference)))
            members.append(JSONMember("selectedCandidateID", .string(selectedCandidateID)))
            members.append(JSONMember("status", status.contractJSON))
            members.append(JSONMember("diagnosticReference", diagnosticReference.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema GenerationPlan.schema.json sha256=e3f8865a69b8615b74d6a7615612985dc3b5d3becc62d146972d4eb741a58bf4
    public struct GenerationPlan: ContractValue, Equatable {
        public static func == (lhs: GenerationPlan, rhs: GenerationPlan) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let planID: String
        public let planElements: [JSONValue]
        public let semanticInputs: JSONValue
        public let diagnosticReferences: [DiagnosticReference]
        public let planHash: String
        public init(planID: String, planElements: [JSONValue], semanticInputs: JSONValue, diagnosticReferences: [DiagnosticReference], planHash: String) throws {
            self.planID = planID
            self.planElements = planElements
            self.semanticInputs = semanticInputs
            self.diagnosticReferences = diagnosticReferences
            self.planHash = planHash
            guard planElements.count >= 1 else { throw CanonicalJSONError.invalidContract("GenerationPlan.planElements array bounds") }
            for item in planElements { guard case .object = item else { throw CanonicalJSONError.invalidContract("GenerationPlan.planElements[] must be object") } }
            guard case .object = semanticInputs else { throw CanonicalJSONError.invalidContract("GenerationPlan.semanticInputs must be object") }
            guard diagnosticReferences.count >= 1 else { throw CanonicalJSONError.invalidContract("GenerationPlan.diagnosticReferences array bounds") }
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["planID", "planElements", "semanticInputs", "diagnosticReferences", "planHash"])
            try self.init(planID: try ContractFields.string(try fields.required("planID")), planElements: try ContractFields.array(try fields.required("planElements")).map { $0 }, semanticInputs: try fields.required("semanticInputs"), diagnosticReferences: try ContractFields.array(try fields.required("diagnosticReferences")).map { try DiagnosticReference(contractJSON: $0) }, planHash: try ContractFields.string(try fields.required("planHash")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("planID", .string(planID)))
            members.append(JSONMember("planElements", .array(planElements.map { $0 })))
            members.append(JSONMember("semanticInputs", semanticInputs))
            members.append(JSONMember("diagnosticReferences", .array(diagnosticReferences.map { $0.contractJSON })))
            members.append(JSONMember("planHash", .string(planHash)))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema HealResult.schema.json sha256=b65f5c99717a0cc5548ccf72ad469e89f2283d123efd82e012ddbd1fc0a8d3cc
    public struct HealResult: ContractValue, Equatable {
        public static func == (lhs: HealResult, rhs: HealResult) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let healResultID: String
        public enum Status: String, ContractValue {
            case noAction = "NO_ACTION"
            case healed = "HEALED"
            case blocked = "BLOCKED"
            case escalated = "ESCALATED"
            case safeHalt = "SAFE_HALT"
            public init(contractJSON: JSONValue) throws { guard let value = Self(rawValue: try ContractFields.string(contractJSON)) else { throw CanonicalJSONError.invalidContract("HealResult.status") }; self = value }
            public var contractJSON: JSONValue { .string(rawValue) }
        }
        public let status: Status
        public let recoveryPlan: RecoveryPlan
        public let auditChain: AuditChain
        public let diagnosticChain: DiagnosticChain
        public init(healResultID: String, status: Status, recoveryPlan: RecoveryPlan, auditChain: AuditChain, diagnosticChain: DiagnosticChain) throws {
            self.healResultID = healResultID
            self.status = status
            self.recoveryPlan = recoveryPlan
            self.auditChain = auditChain
            self.diagnosticChain = diagnosticChain
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["healResultID", "status", "recoveryPlan", "auditChain", "diagnosticChain"])
            try self.init(healResultID: try ContractFields.string(try fields.required("healResultID")), status: try Status(contractJSON: try fields.required("status")), recoveryPlan: try RecoveryPlan(contractJSON: try fields.required("recoveryPlan")), auditChain: try AuditChain(contractJSON: try fields.required("auditChain")), diagnosticChain: try DiagnosticChain(contractJSON: try fields.required("diagnosticChain")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("healResultID", .string(healResultID)))
            members.append(JSONMember("status", status.contractJSON))
            members.append(JSONMember("recoveryPlan", recoveryPlan.contractJSON))
            members.append(JSONMember("auditChain", auditChain.contractJSON))
            members.append(JSONMember("diagnosticChain", diagnosticChain.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema Invariant.schema.json sha256=d636a46762bad96456eff4cf0dd4d36d5afe2b2741a5624202baf40091e34b3b
    public struct Invariant: ContractValue, Equatable {
        public static func == (lhs: Invariant, rhs: Invariant) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let invariantID: String
        public let conformanceCategory: String
        public let sourceReference: String
        public let diagnosticRule: RuleReference
        public init(invariantID: String, conformanceCategory: String, sourceReference: String, diagnosticRule: RuleReference) throws {
            self.invariantID = invariantID
            self.conformanceCategory = conformanceCategory
            self.sourceReference = sourceReference
            self.diagnosticRule = diagnosticRule
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["invariantID", "conformanceCategory", "sourceReference", "diagnosticRule"])
            try self.init(invariantID: try ContractFields.string(try fields.required("invariantID")), conformanceCategory: try ContractFields.string(try fields.required("conformanceCategory")), sourceReference: try ContractFields.string(try fields.required("sourceReference")), diagnosticRule: try RuleReference(contractJSON: try fields.required("diagnosticRule")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("invariantID", .string(invariantID)))
            members.append(JSONMember("conformanceCategory", .string(conformanceCategory)))
            members.append(JSONMember("sourceReference", .string(sourceReference)))
            members.append(JSONMember("diagnosticRule", diagnosticRule.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema JsonCanonicalizationRule.schema.json sha256=c30398281bb7b597c5b91874e4a20df798b4b20a856e9ce3bf385e4b6c2cf3a3
    public struct JsonCanonicalizationRule: ContractValue, Equatable {
        public static func == (lhs: JsonCanonicalizationRule, rhs: JsonCanonicalizationRule) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let ruleID: String
        public enum ObjectKeyOrdering: String, ContractValue {
            case lexicographicUtf8 = "LEXICOGRAPHIC_UTF8"
            public init(contractJSON: JSONValue) throws { guard let value = Self(rawValue: try ContractFields.string(contractJSON)) else { throw CanonicalJSONError.invalidContract("JsonCanonicalizationRule.objectKeyOrdering") }; self = value }
            public var contractJSON: JSONValue { .string(rawValue) }
        }
        public let objectKeyOrdering: ObjectKeyOrdering
        public enum ArrayOrdering: String, ContractValue {
            case preserveInputOrder = "PRESERVE_INPUT_ORDER"
            public init(contractJSON: JSONValue) throws { guard let value = Self(rawValue: try ContractFields.string(contractJSON)) else { throw CanonicalJSONError.invalidContract("JsonCanonicalizationRule.arrayOrdering") }; self = value }
            public var contractJSON: JSONValue { .string(rawValue) }
        }
        public let arrayOrdering: ArrayOrdering
        public enum NumberEncoding: String, ContractValue {
            case jsonNumberCanonical = "JSON_NUMBER_CANONICAL"
            public init(contractJSON: JSONValue) throws { guard let value = Self(rawValue: try ContractFields.string(contractJSON)) else { throw CanonicalJSONError.invalidContract("JsonCanonicalizationRule.numberEncoding") }; self = value }
            public var contractJSON: JSONValue { .string(rawValue) }
        }
        public let numberEncoding: NumberEncoding
        public enum HashAlgorithm: String, ContractValue {
            case sha256 = "SHA-256"
            public init(contractJSON: JSONValue) throws { guard let value = Self(rawValue: try ContractFields.string(contractJSON)) else { throw CanonicalJSONError.invalidContract("JsonCanonicalizationRule.hashAlgorithm") }; self = value }
            public var contractJSON: JSONValue { .string(rawValue) }
        }
        public let hashAlgorithm: HashAlgorithm
        public init(ruleID: String, objectKeyOrdering: ObjectKeyOrdering, arrayOrdering: ArrayOrdering, numberEncoding: NumberEncoding, hashAlgorithm: HashAlgorithm) throws {
            self.ruleID = ruleID
            self.objectKeyOrdering = objectKeyOrdering
            self.arrayOrdering = arrayOrdering
            self.numberEncoding = numberEncoding
            self.hashAlgorithm = hashAlgorithm
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["ruleID", "objectKeyOrdering", "arrayOrdering", "numberEncoding", "hashAlgorithm"])
            try self.init(ruleID: try ContractFields.string(try fields.required("ruleID")), objectKeyOrdering: try ObjectKeyOrdering(contractJSON: try fields.required("objectKeyOrdering")), arrayOrdering: try ArrayOrdering(contractJSON: try fields.required("arrayOrdering")), numberEncoding: try NumberEncoding(contractJSON: try fields.required("numberEncoding")), hashAlgorithm: try HashAlgorithm(contractJSON: try fields.required("hashAlgorithm")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("ruleID", .string(ruleID)))
            members.append(JSONMember("objectKeyOrdering", objectKeyOrdering.contractJSON))
            members.append(JSONMember("arrayOrdering", arrayOrdering.contractJSON))
            members.append(JSONMember("numberEncoding", numberEncoding.contractJSON))
            members.append(JSONMember("hashAlgorithm", hashAlgorithm.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema JsonDocumentReference.schema.json sha256=add5dfa1ac40dc9e0ea0d1eefbf1fd8b1d5983c6f71ecf66d05d198520530201
    public struct JsonDocumentReference: ContractValue, Equatable {
        public static func == (lhs: JsonDocumentReference, rhs: JsonDocumentReference) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let documentID: String
        public enum Role: String, ContractValue {
            case observed = "OBSERVED"
            case desired = "DESIRED"
            case canonicalized = "CANONICALIZED"
            case backup = "BACKUP"
            public init(contractJSON: JSONValue) throws { guard let value = Self(rawValue: try ContractFields.string(contractJSON)) else { throw CanonicalJSONError.invalidContract("JsonDocumentReference.role") }; self = value }
            public var contractJSON: JSONValue { .string(rawValue) }
        }
        public let role: Role
        public let canonicalHash: String
        public let sourceReference: String
        public init(documentID: String, role: Role, canonicalHash: String, sourceReference: String) throws {
            self.documentID = documentID
            self.role = role
            self.canonicalHash = canonicalHash
            self.sourceReference = sourceReference
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["documentID", "role", "canonicalHash", "sourceReference"])
            try self.init(documentID: try ContractFields.string(try fields.required("documentID")), role: try Role(contractJSON: try fields.required("role")), canonicalHash: try ContractFields.string(try fields.required("canonicalHash")), sourceReference: try ContractFields.string(try fields.required("sourceReference")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("documentID", .string(documentID)))
            members.append(JSONMember("role", role.contractJSON))
            members.append(JSONMember("canonicalHash", .string(canonicalHash)))
            members.append(JSONMember("sourceReference", .string(sourceReference)))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema JsonMutationOperation.schema.json sha256=a58ce2038427be4a5ee3fb6333e0ddc566dd9facef74180aa9b251ff19e586dd
    public struct JsonMutationOperation: ContractValue, Equatable {
        public static func == (lhs: JsonMutationOperation, rhs: JsonMutationOperation) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let operationID: String
        public enum Op: String, ContractValue {
            case test = "test"
            case add = "add"
            case replace = "replace"
            case remove = "remove"
            public init(contractJSON: JSONValue) throws { guard let value = Self(rawValue: try ContractFields.string(contractJSON)) else { throw CanonicalJSONError.invalidContract("JsonMutationOperation.op") }; self = value }
            public var contractJSON: JSONValue { .string(rawValue) }
        }
        public let op: Op
        public let path: JsonPointer
        public let value: JSONValue?
        public let preconditionHash: String
        public let diagnosticReference: DiagnosticReference
        public init(operationID: String, op: Op, path: JsonPointer, value: JSONValue? = nil, preconditionHash: String, diagnosticReference: DiagnosticReference) throws {
            self.operationID = operationID
            self.op = op
            self.path = path
            self.value = value
            self.preconditionHash = preconditionHash
            self.diagnosticReference = diagnosticReference
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["operationID", "op", "path", "value", "preconditionHash", "diagnosticReference"])
            try self.init(operationID: try ContractFields.string(try fields.required("operationID")), op: try Op(contractJSON: try fields.required("op")), path: try JsonPointer(contractJSON: try fields.required("path")), value: fields.optional("value").map { $0 }, preconditionHash: try ContractFields.string(try fields.required("preconditionHash")), diagnosticReference: try DiagnosticReference(contractJSON: try fields.required("diagnosticReference")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("operationID", .string(operationID)))
            members.append(JSONMember("op", op.contractJSON))
            members.append(JSONMember("path", path.contractJSON))
            if let value = value { members.append(JSONMember("value", value)) }
            members.append(JSONMember("preconditionHash", .string(preconditionHash)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema JsonPointer.schema.json sha256=d92a4867714eda194cebaff9cc107bc899ce2622d84702aa8aa7c2864060d103
    public struct JsonPointer: ContractValue, Equatable {
        public static func == (lhs: JsonPointer, rhs: JsonPointer) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let pointer: String
        public let tokens: [String]
        public let pointsToMissing: Bool
        public let pointsToNull: Bool
        public init(pointer: String, tokens: [String], pointsToMissing: Bool, pointsToNull: Bool) throws {
            self.pointer = pointer
            self.tokens = tokens
            self.pointsToMissing = pointsToMissing
            self.pointsToNull = pointsToNull
            guard pointer.range(of: "^($|/.*)", options: .regularExpression) != nil else { throw CanonicalJSONError.invalidContract("JsonPointer.pointer pattern") }
            guard tokens.count >= 0 else { throw CanonicalJSONError.invalidContract("JsonPointer.tokens array bounds") }
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["pointer", "tokens", "pointsToMissing", "pointsToNull"])
            try self.init(pointer: try ContractFields.string(try fields.required("pointer")), tokens: try ContractFields.array(try fields.required("tokens")).map { try ContractFields.string($0) }, pointsToMissing: try ContractFields.boolean(try fields.required("pointsToMissing")), pointsToNull: try ContractFields.boolean(try fields.required("pointsToNull")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("pointer", .string(pointer)))
            members.append(JSONMember("tokens", .array(tokens.map { .string($0) })))
            members.append(JSONMember("pointsToMissing", .bool(pointsToMissing)))
            members.append(JSONMember("pointsToNull", .bool(pointsToNull)))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema MappingAmbiguity.schema.json sha256=7d85a7de4767c6ad91f66d81838aed5d002b9554c86e3b6b707fa635893f46b1
    public struct MappingAmbiguity: ContractValue, Equatable {
        public static func == (lhs: MappingAmbiguity, rhs: MappingAmbiguity) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let ambiguityID: String
        public enum DimensionID: String, ContractValue {
            case b0 = "b0"
            case b1 = "b1"
            case b2 = "b2"
            case b3 = "b3"
            case b4 = "b4"
            case b5 = "b5"
            case b6 = "b6"
            case b7 = "b7"
            case b8 = "b8"
            public init(contractJSON: JSONValue) throws { guard let value = Self(rawValue: try ContractFields.string(contractJSON)) else { throw CanonicalJSONError.invalidContract("MappingAmbiguity.dimensionID") }; self = value }
            public var contractJSON: JSONValue { .string(rawValue) }
        }
        public let dimensionID: DimensionID
        public let candidateValues: [Int]
        public let evidence: [JSONValue]
        public let blockingRule: RuleReference
        public let diagnosticReference: DiagnosticReference
        public init(ambiguityID: String, dimensionID: DimensionID, candidateValues: [Int], evidence: [JSONValue], blockingRule: RuleReference, diagnosticReference: DiagnosticReference) throws {
            self.ambiguityID = ambiguityID
            self.dimensionID = dimensionID
            self.candidateValues = candidateValues
            self.evidence = evidence
            self.blockingRule = blockingRule
            self.diagnosticReference = diagnosticReference
            guard candidateValues.count >= 2 else { throw CanonicalJSONError.invalidContract("MappingAmbiguity.candidateValues array bounds") }
            for item in candidateValues { guard [0,1].contains(item) else { throw CanonicalJSONError.invalidContract("MappingAmbiguity.candidateValues[] enum") } }
            guard evidence.count >= 1 else { throw CanonicalJSONError.invalidContract("MappingAmbiguity.evidence array bounds") }
            for item in evidence { guard case .object = item else { throw CanonicalJSONError.invalidContract("MappingAmbiguity.evidence[] must be object") } }
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["ambiguityID", "dimensionID", "candidateValues", "evidence", "blockingRule", "diagnosticReference"])
            try self.init(ambiguityID: try ContractFields.string(try fields.required("ambiguityID")), dimensionID: try DimensionID(contractJSON: try fields.required("dimensionID")), candidateValues: try ContractFields.array(try fields.required("candidateValues")).map { try ContractFields.integer($0) }, evidence: try ContractFields.array(try fields.required("evidence")).map { $0 }, blockingRule: try RuleReference(contractJSON: try fields.required("blockingRule")), diagnosticReference: try DiagnosticReference(contractJSON: try fields.required("diagnosticReference")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("ambiguityID", .string(ambiguityID)))
            members.append(JSONMember("dimensionID", dimensionID.contractJSON))
            members.append(JSONMember("candidateValues", .array(candidateValues.map { .integer(String($0)) })))
            members.append(JSONMember("evidence", .array(evidence.map { $0 })))
            members.append(JSONMember("blockingRule", blockingRule.contractJSON))
            members.append(JSONMember("diagnosticReference", diagnosticReference.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema MappingResult.schema.json sha256=150035c35bf157f1f97fa9afc2a4b81bd96b2a91c84b68a0afca04d04fe179ca
    public struct MappingResult: ContractValue, Equatable {
        public static func == (lhs: MappingResult, rhs: MappingResult) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let mappingResultID: String
        public enum Status: String, ContractValue {
            case mapped = "MAPPED"
            case ambiguous = "AMBIGUOUS"
            case blocked = "BLOCKED"
            case failed = "FAILED"
            public init(contractJSON: JSONValue) throws { guard let value = Self(rawValue: try ContractFields.string(contractJSON)) else { throw CanonicalJSONError.invalidContract("MappingResult.status") }; self = value }
            public var contractJSON: JSONValue { .string(rawValue) }
        }
        public let status: Status
        public let projectedState: AshState
        public let dimensionBindings: [SemanticDimensionBinding]
        public let ambiguities: [MappingAmbiguity]
        public let diagnosticReferences: [DiagnosticReference]
        public init(mappingResultID: String, status: Status, projectedState: AshState, dimensionBindings: [SemanticDimensionBinding], ambiguities: [MappingAmbiguity], diagnosticReferences: [DiagnosticReference]) throws {
            self.mappingResultID = mappingResultID
            self.status = status
            self.projectedState = projectedState
            self.dimensionBindings = dimensionBindings
            self.ambiguities = ambiguities
            self.diagnosticReferences = diagnosticReferences
            guard dimensionBindings.count >= 9 && dimensionBindings.count <= 9 else { throw CanonicalJSONError.invalidContract("MappingResult.dimensionBindings array bounds") }
            guard ambiguities.count >= 0 else { throw CanonicalJSONError.invalidContract("MappingResult.ambiguities array bounds") }
            guard diagnosticReferences.count >= 1 else { throw CanonicalJSONError.invalidContract("MappingResult.diagnosticReferences array bounds") }
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["mappingResultID", "status", "projectedState", "dimensionBindings", "ambiguities", "diagnosticReferences"])
            try self.init(mappingResultID: try ContractFields.string(try fields.required("mappingResultID")), status: try Status(contractJSON: try fields.required("status")), projectedState: try AshState(contractJSON: try fields.required("projectedState")), dimensionBindings: try ContractFields.array(try fields.required("dimensionBindings")).map { try SemanticDimensionBinding(contractJSON: $0) }, ambiguities: try ContractFields.array(try fields.required("ambiguities")).map { try MappingAmbiguity(contractJSON: $0) }, diagnosticReferences: try ContractFields.array(try fields.required("diagnosticReferences")).map { try DiagnosticReference(contractJSON: $0) })
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("mappingResultID", .string(mappingResultID)))
            members.append(JSONMember("status", status.contractJSON))
            members.append(JSONMember("projectedState", projectedState.contractJSON))
            members.append(JSONMember("dimensionBindings", .array(dimensionBindings.map { $0.contractJSON })))
            members.append(JSONMember("ambiguities", .array(ambiguities.map { $0.contractJSON })))
            members.append(JSONMember("diagnosticReferences", .array(diagnosticReferences.map { $0.contractJSON })))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema ModuleManifest.schema.json sha256=c5e4dcd965344a09246242b00f6c11e6d266895eef40051476984b4a5334e003
    public struct ModuleManifest: ContractValue, Equatable {
        public static func == (lhs: ModuleManifest, rhs: ModuleManifest) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let moduleManifestID: String
        public let aeostaraVersion: String
        public let modules: [JSONValue]
        public let diagnosticReference: DiagnosticReference
        public init(moduleManifestID: String, aeostaraVersion: String, modules: [JSONValue], diagnosticReference: DiagnosticReference) throws {
            self.moduleManifestID = moduleManifestID
            self.aeostaraVersion = aeostaraVersion
            self.modules = modules
            self.diagnosticReference = diagnosticReference
            guard modules.count >= 1 else { throw CanonicalJSONError.invalidContract("ModuleManifest.modules array bounds") }
            for item in modules { guard case .object = item else { throw CanonicalJSONError.invalidContract("ModuleManifest.modules[] must be object") } }
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["moduleManifestID", "aeostaraVersion", "modules", "diagnosticReference"])
            try self.init(moduleManifestID: try ContractFields.string(try fields.required("moduleManifestID")), aeostaraVersion: try ContractFields.string(try fields.required("aeostaraVersion")), modules: try ContractFields.array(try fields.required("modules")).map { $0 }, diagnosticReference: try DiagnosticReference(contractJSON: try fields.required("diagnosticReference")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("moduleManifestID", .string(moduleManifestID)))
            members.append(JSONMember("aeostaraVersion", .string(aeostaraVersion)))
            members.append(JSONMember("modules", .array(modules.map { $0 })))
            members.append(JSONMember("diagnosticReference", diagnosticReference.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema ObservedState.schema.json sha256=f2dfd3f3b1a913edd069fd029f0c54226980581b86ddeb27071ddb91f64b25ed
    public struct ObservedState: ContractValue, Equatable {
        public static func == (lhs: ObservedState, rhs: ObservedState) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let observedStateID: String
        public let observedSystemState: ObservedSystemState
        public let evidenceOnly: Bool
        public init(observedStateID: String, observedSystemState: ObservedSystemState, evidenceOnly: Bool) throws {
            self.observedStateID = observedStateID
            self.observedSystemState = observedSystemState
            self.evidenceOnly = evidenceOnly
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["observedStateID", "observedSystemState", "evidenceOnly"])
            try self.init(observedStateID: try ContractFields.string(try fields.required("observedStateID")), observedSystemState: try ObservedSystemState(contractJSON: try fields.required("observedSystemState")), evidenceOnly: try ContractFields.boolean(try fields.required("evidenceOnly")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("observedStateID", .string(observedStateID)))
            members.append(JSONMember("observedSystemState", observedSystemState.contractJSON))
            members.append(JSONMember("evidenceOnly", .bool(evidenceOnly)))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema ObservedSystemState.schema.json sha256=09706b08c4859476e5dd6df0d85553c7d5cdd7e9f94d11fa01d58f008888c9df
    public struct ObservedSystemState: ContractValue, Equatable {
        public static func == (lhs: ObservedSystemState, rhs: ObservedSystemState) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let observedSystemStateID: String
        public let documentReference: JsonDocumentReference
        public let surfaceDifferences: [SurfaceDifference]
        public let diagnosticReference: DiagnosticReference
        public init(observedSystemStateID: String, documentReference: JsonDocumentReference, surfaceDifferences: [SurfaceDifference], diagnosticReference: DiagnosticReference) throws {
            self.observedSystemStateID = observedSystemStateID
            self.documentReference = documentReference
            self.surfaceDifferences = surfaceDifferences
            self.diagnosticReference = diagnosticReference
            guard surfaceDifferences.count >= 0 else { throw CanonicalJSONError.invalidContract("ObservedSystemState.surfaceDifferences array bounds") }
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["observedSystemStateID", "documentReference", "surfaceDifferences", "diagnosticReference"])
            try self.init(observedSystemStateID: try ContractFields.string(try fields.required("observedSystemStateID")), documentReference: try JsonDocumentReference(contractJSON: try fields.required("documentReference")), surfaceDifferences: try ContractFields.array(try fields.required("surfaceDifferences")).map { try SurfaceDifference(contractJSON: $0) }, diagnosticReference: try DiagnosticReference(contractJSON: try fields.required("diagnosticReference")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("observedSystemStateID", .string(observedSystemStateID)))
            members.append(JSONMember("documentReference", documentReference.contractJSON))
            members.append(JSONMember("surfaceDifferences", .array(surfaceDifferences.map { $0.contractJSON })))
            members.append(JSONMember("diagnosticReference", diagnosticReference.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema PolicyBundle.schema.json sha256=9fb514022d974c4079db890cd3699205f7e5c30cf249e2ae30cd46074391ace2
    public struct PolicyBundle: ContractValue, Equatable {
        public static func == (lhs: PolicyBundle, rhs: PolicyBundle) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let policyBundleID: String
        public let sourceReferences: [String]
        public let rules: [JSONValue]
        public let bundleHash: String
        public init(policyBundleID: String, sourceReferences: [String], rules: [JSONValue], bundleHash: String) throws {
            self.policyBundleID = policyBundleID
            self.sourceReferences = sourceReferences
            self.rules = rules
            self.bundleHash = bundleHash
            guard sourceReferences.count >= 1 else { throw CanonicalJSONError.invalidContract("PolicyBundle.sourceReferences array bounds") }
            guard rules.count >= 1 else { throw CanonicalJSONError.invalidContract("PolicyBundle.rules array bounds") }
            for item in rules { guard case .object = item else { throw CanonicalJSONError.invalidContract("PolicyBundle.rules[] must be object") } }
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["policyBundleID", "sourceReferences", "rules", "bundleHash"])
            try self.init(policyBundleID: try ContractFields.string(try fields.required("policyBundleID")), sourceReferences: try ContractFields.array(try fields.required("sourceReferences")).map { try ContractFields.string($0) }, rules: try ContractFields.array(try fields.required("rules")).map { $0 }, bundleHash: try ContractFields.string(try fields.required("bundleHash")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("policyBundleID", .string(policyBundleID)))
            members.append(JSONMember("sourceReferences", .array(sourceReferences.map { .string($0) })))
            members.append(JSONMember("rules", .array(rules.map { $0 })))
            members.append(JSONMember("bundleHash", .string(bundleHash)))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema PolicyDecision.schema.json sha256=3584739e0e17c56b207265b7bb40f0db3faff5cc8654d782a52d18f69c8e63b2
    public struct PolicyDecision: ContractValue, Equatable {
        public static func == (lhs: PolicyDecision, rhs: PolicyDecision) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let policyDecisionID: String
        public enum Decision: String, ContractValue {
            case allow = "ALLOW"
            case block = "BLOCK"
            case escalate = "ESCALATE"
            public init(contractJSON: JSONValue) throws { guard let value = Self(rawValue: try ContractFields.string(contractJSON)) else { throw CanonicalJSONError.invalidContract("PolicyDecision.decision") }; self = value }
            public var contractJSON: JSONValue { .string(rawValue) }
        }
        public let decision: Decision
        public let policyBundleID: String
        public let reasons: [String]
        public let diagnosticReference: DiagnosticReference
        public init(policyDecisionID: String, decision: Decision, policyBundleID: String, reasons: [String], diagnosticReference: DiagnosticReference) throws {
            self.policyDecisionID = policyDecisionID
            self.decision = decision
            self.policyBundleID = policyBundleID
            self.reasons = reasons
            self.diagnosticReference = diagnosticReference
            guard reasons.count >= 1 else { throw CanonicalJSONError.invalidContract("PolicyDecision.reasons array bounds") }
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["policyDecisionID", "decision", "policyBundleID", "reasons", "diagnosticReference"])
            try self.init(policyDecisionID: try ContractFields.string(try fields.required("policyDecisionID")), decision: try Decision(contractJSON: try fields.required("decision")), policyBundleID: try ContractFields.string(try fields.required("policyBundleID")), reasons: try ContractFields.array(try fields.required("reasons")).map { try ContractFields.string($0) }, diagnosticReference: try DiagnosticReference(contractJSON: try fields.required("diagnosticReference")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("policyDecisionID", .string(policyDecisionID)))
            members.append(JSONMember("decision", decision.contractJSON))
            members.append(JSONMember("policyBundleID", .string(policyBundleID)))
            members.append(JSONMember("reasons", .array(reasons.map { .string($0) })))
            members.append(JSONMember("diagnosticReference", diagnosticReference.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema RealmIdentity.schema.json sha256=23560889d6e5e4a3ddbfc3873fdecc2c870b769bd95b5db0ccea9f4296eeee5a
    public struct RealmIdentity: ContractValue, Equatable {
        public static func == (lhs: RealmIdentity, rhs: RealmIdentity) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let realmID: String
        public let stateReference: String
        public let encoding: String
        public let diagnosticReference: DiagnosticReference
        public init(realmID: String, stateReference: String, encoding: String, diagnosticReference: DiagnosticReference) throws {
            self.realmID = realmID
            self.stateReference = stateReference
            self.encoding = encoding
            self.diagnosticReference = diagnosticReference
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["realmID", "stateReference", "encoding", "diagnosticReference"])
            try self.init(realmID: try ContractFields.string(try fields.required("realmID")), stateReference: try ContractFields.string(try fields.required("stateReference")), encoding: try ContractFields.string(try fields.required("encoding")), diagnosticReference: try DiagnosticReference(contractJSON: try fields.required("diagnosticReference")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("realmID", .string(realmID)))
            members.append(JSONMember("stateReference", .string(stateReference)))
            members.append(JSONMember("encoding", .string(encoding)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema RecoveryCategory.schema.json sha256=393d996fb066ebbdcd967b6934ac69bce8453bf349b59566d6c75a20a045557b
    public enum RecoveryCategory: String, ContractValue {
        case noAction = "NO_ACTION"
        case normalizeState = "NORMALIZE_STATE"
        case applyCorrection = "APPLY_CORRECTION"
        case fallbackRequired = "FALLBACK_REQUIRED"
        case containmentRequired = "CONTAINMENT_REQUIRED"
        case escalationRequired = "ESCALATION_REQUIRED"
        case terminalNoRecovery = "TERMINAL_NO_RECOVERY"
        public init(contractJSON: JSONValue) throws { guard let value = Self(rawValue: try ContractFields.string(contractJSON)) else { throw CanonicalJSONError.invalidContract("RecoveryCategory") }; self = value }
        public var contractJSON: JSONValue { .string(rawValue) }
    }
    // Frozen schema RecoveryOutcome.schema.json sha256=94ebd76423f60a8bb94b12e8c8f0957f52f39dc7e5b1f7a76ad61bfef65c817f
    public struct RecoveryOutcome: ContractValue, Equatable {
        public static func == (lhs: RecoveryOutcome, rhs: RecoveryOutcome) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let outcomeID: String
        public enum Status: String, ContractValue {
            case succeeded = "SUCCEEDED"
            case blocked = "BLOCKED"
            case failed = "FAILED"
            case escalated = "ESCALATED"
            case noAction = "NO_ACTION"
            public init(contractJSON: JSONValue) throws { guard let value = Self(rawValue: try ContractFields.string(contractJSON)) else { throw CanonicalJSONError.invalidContract("RecoveryOutcome.status") }; self = value }
            public var contractJSON: JSONValue { .string(rawValue) }
        }
        public let status: Status
        public let recoveryCategory: RecoveryCategory
        public let escalationDecision: EscalationDecision?
        public let diagnosticReference: DiagnosticReference
        public init(outcomeID: String, status: Status, recoveryCategory: RecoveryCategory, escalationDecision: EscalationDecision? = nil, diagnosticReference: DiagnosticReference) throws {
            self.outcomeID = outcomeID
            self.status = status
            self.recoveryCategory = recoveryCategory
            self.escalationDecision = escalationDecision
            self.diagnosticReference = diagnosticReference
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["outcomeID", "status", "recoveryCategory", "escalationDecision", "diagnosticReference"])
            try self.init(outcomeID: try ContractFields.string(try fields.required("outcomeID")), status: try Status(contractJSON: try fields.required("status")), recoveryCategory: try RecoveryCategory(contractJSON: try fields.required("recoveryCategory")), escalationDecision: try fields.optional("escalationDecision").map { try EscalationDecision(contractJSON: $0) }, diagnosticReference: try DiagnosticReference(contractJSON: try fields.required("diagnosticReference")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("outcomeID", .string(outcomeID)))
            members.append(JSONMember("status", status.contractJSON))
            members.append(JSONMember("recoveryCategory", recoveryCategory.contractJSON))
            if let value = escalationDecision { members.append(JSONMember("escalationDecision", value.contractJSON)) }
            members.append(JSONMember("diagnosticReference", diagnosticReference.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema RecoveryPlan.schema.json sha256=807cb30bc6627e76504c3386fd069c714183a456d01a284595d7496c4771b0cc
    public struct RecoveryPlan: ContractValue, Equatable {
        public static func == (lhs: RecoveryPlan, rhs: RecoveryPlan) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let recoveryPlanID: String
        public enum PlanDisposition: String, ContractValue {
            case noAction = "NO_ACTION"
            case mutationRequired = "MUTATION_REQUIRED"
            case escalationRequired = "ESCALATION_REQUIRED"
            case terminal = "TERMINAL"
            public init(contractJSON: JSONValue) throws { guard let value = Self(rawValue: try ContractFields.string(contractJSON)) else { throw CanonicalJSONError.invalidContract("RecoveryPlan.planDisposition") }; self = value }
            public var contractJSON: JSONValue { .string(rawValue) }
        }
        public let planDisposition: PlanDisposition
        public let diagnosticReference: DiagnosticReference
        public let stateClass: SystemStateClass
        public let recoveryCategory: RecoveryCategory
        public let requiresPolicyGate: Bool
        public let requiresBackup: Bool
        public let recoverySteps: [RecoveryStep]
        public let planHash: String
        public let createdAt: String
        public init(recoveryPlanID: String, planDisposition: PlanDisposition, diagnosticReference: DiagnosticReference, stateClass: SystemStateClass, recoveryCategory: RecoveryCategory, requiresPolicyGate: Bool, requiresBackup: Bool, recoverySteps: [RecoveryStep], planHash: String, createdAt: String) throws {
            self.recoveryPlanID = recoveryPlanID
            self.planDisposition = planDisposition
            self.diagnosticReference = diagnosticReference
            self.stateClass = stateClass
            self.recoveryCategory = recoveryCategory
            self.requiresPolicyGate = requiresPolicyGate
            self.requiresBackup = requiresBackup
            self.recoverySteps = recoverySteps
            self.planHash = planHash
            self.createdAt = createdAt
            guard recoverySteps.count >= 0 else { throw CanonicalJSONError.invalidContract("RecoveryPlan.recoverySteps array bounds") }
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["recoveryPlanID", "planDisposition", "diagnosticReference", "stateClass", "recoveryCategory", "requiresPolicyGate", "requiresBackup", "recoverySteps", "planHash", "createdAt"])
            try self.init(recoveryPlanID: try ContractFields.string(try fields.required("recoveryPlanID")), planDisposition: try PlanDisposition(contractJSON: try fields.required("planDisposition")), diagnosticReference: try DiagnosticReference(contractJSON: try fields.required("diagnosticReference")), stateClass: try SystemStateClass(contractJSON: try fields.required("stateClass")), recoveryCategory: try RecoveryCategory(contractJSON: try fields.required("recoveryCategory")), requiresPolicyGate: try ContractFields.boolean(try fields.required("requiresPolicyGate")), requiresBackup: try ContractFields.boolean(try fields.required("requiresBackup")), recoverySteps: try ContractFields.array(try fields.required("recoverySteps")).map { try RecoveryStep(contractJSON: $0) }, planHash: try ContractFields.string(try fields.required("planHash")), createdAt: try ContractFields.string(try fields.required("createdAt")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("recoveryPlanID", .string(recoveryPlanID)))
            members.append(JSONMember("planDisposition", planDisposition.contractJSON))
            members.append(JSONMember("diagnosticReference", diagnosticReference.contractJSON))
            members.append(JSONMember("stateClass", stateClass.contractJSON))
            members.append(JSONMember("recoveryCategory", recoveryCategory.contractJSON))
            members.append(JSONMember("requiresPolicyGate", .bool(requiresPolicyGate)))
            members.append(JSONMember("requiresBackup", .bool(requiresBackup)))
            members.append(JSONMember("recoverySteps", .array(recoverySteps.map { $0.contractJSON })))
            members.append(JSONMember("planHash", .string(planHash)))
            members.append(JSONMember("createdAt", .string(createdAt)))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema RecoveryStep.schema.json sha256=c541d190b33768a4702d2ea2a5ecbbb66bc11f5beec3532c78122dafaef009a6
    public struct RecoveryStep: ContractValue, Equatable {
        public static func == (lhs: RecoveryStep, rhs: RecoveryStep) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let stepID: String
        public enum StepType: String, ContractValue {
            case normalizeState = "NORMALIZE_STATE"
            case applyCorrection = "APPLY_CORRECTION"
            case selectFallback = "SELECT_FALLBACK"
            case enterContainment = "ENTER_CONTAINMENT"
            case enterSafeHalt = "ENTER_SAFE_HALT"
            case rollback = "ROLLBACK"
            case verify = "VERIFY"
            case escalate = "ESCALATE"
            public init(contractJSON: JSONValue) throws { guard let value = Self(rawValue: try ContractFields.string(contractJSON)) else { throw CanonicalJSONError.invalidContract("RecoveryStep.stepType") }; self = value }
            public var contractJSON: JSONValue { .string(rawValue) }
        }
        public let stepType: StepType
        public let description: String
        public let jsonMutationOperations: [JsonMutationOperation]
        public let diagnosticReference: DiagnosticReference
        public init(stepID: String, stepType: StepType, description: String, jsonMutationOperations: [JsonMutationOperation], diagnosticReference: DiagnosticReference) throws {
            self.stepID = stepID
            self.stepType = stepType
            self.description = description
            self.jsonMutationOperations = jsonMutationOperations
            self.diagnosticReference = diagnosticReference
            guard jsonMutationOperations.count >= 0 else { throw CanonicalJSONError.invalidContract("RecoveryStep.jsonMutationOperations array bounds") }
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["stepID", "stepType", "description", "jsonMutationOperations", "diagnosticReference"])
            try self.init(stepID: try ContractFields.string(try fields.required("stepID")), stepType: try StepType(contractJSON: try fields.required("stepType")), description: try ContractFields.string(try fields.required("description")), jsonMutationOperations: try ContractFields.array(try fields.required("jsonMutationOperations")).map { try JsonMutationOperation(contractJSON: $0) }, diagnosticReference: try DiagnosticReference(contractJSON: try fields.required("diagnosticReference")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("stepID", .string(stepID)))
            members.append(JSONMember("stepType", stepType.contractJSON))
            members.append(JSONMember("description", .string(description)))
            members.append(JSONMember("jsonMutationOperations", .array(jsonMutationOperations.map { $0.contractJSON })))
            members.append(JSONMember("diagnosticReference", diagnosticReference.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema RepairAction.schema.json sha256=4c7707e882630c2e5f6a132e95cb49845db366411c8460ba807dbbecf1b0b77c
    public struct RepairAction: ContractValue, Equatable {
        public static func == (lhs: RepairAction, rhs: RepairAction) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let repairActionID: String
        public let recoveryStep: RecoveryStep
        public let actuatorParameters: JSONValue
        public init(repairActionID: String, recoveryStep: RecoveryStep, actuatorParameters: JSONValue) throws {
            self.repairActionID = repairActionID
            self.recoveryStep = recoveryStep
            self.actuatorParameters = actuatorParameters
            guard case .object = actuatorParameters else { throw CanonicalJSONError.invalidContract("RepairAction.actuatorParameters must be object") }
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["repairActionID", "recoveryStep", "actuatorParameters"])
            try self.init(repairActionID: try ContractFields.string(try fields.required("repairActionID")), recoveryStep: try RecoveryStep(contractJSON: try fields.required("recoveryStep")), actuatorParameters: try fields.required("actuatorParameters"))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("repairActionID", .string(repairActionID)))
            members.append(JSONMember("recoveryStep", recoveryStep.contractJSON))
            members.append(JSONMember("actuatorParameters", actuatorParameters))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema RepairPlan.schema.json sha256=e1b5447fcd8e75288669e968be33fdcd539326400263acf97ab9c2392cc42a29
    public struct RepairPlan: ContractValue, Equatable {
        public static func == (lhs: RepairPlan, rhs: RepairPlan) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let repairPlanID: String
        public let recoveryPlan: RecoveryPlan
        public let repairActions: [RepairAction]
        public init(repairPlanID: String, recoveryPlan: RecoveryPlan, repairActions: [RepairAction]) throws {
            self.repairPlanID = repairPlanID
            self.recoveryPlan = recoveryPlan
            self.repairActions = repairActions
            guard repairActions.count >= 0 else { throw CanonicalJSONError.invalidContract("RepairPlan.repairActions array bounds") }
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["repairPlanID", "recoveryPlan", "repairActions"])
            try self.init(repairPlanID: try ContractFields.string(try fields.required("repairPlanID")), recoveryPlan: try RecoveryPlan(contractJSON: try fields.required("recoveryPlan")), repairActions: try ContractFields.array(try fields.required("repairActions")).map { try RepairAction(contractJSON: $0) })
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("repairPlanID", .string(repairPlanID)))
            members.append(JSONMember("recoveryPlan", recoveryPlan.contractJSON))
            members.append(JSONMember("repairActions", .array(repairActions.map { $0.contractJSON })))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema RollbackPlan.schema.json sha256=9e14116771cfadba190921255667bda25a8c697af3d53784753267c6546a04dd
    public struct RollbackPlan: ContractValue, Equatable {
        public static func == (lhs: RollbackPlan, rhs: RollbackPlan) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let rollbackPlanID: String
        public let backupRecordID: String
        public let triggerVerificationResultID: String
        public let diagnosticReference: DiagnosticReference
        public init(rollbackPlanID: String, backupRecordID: String, triggerVerificationResultID: String, diagnosticReference: DiagnosticReference) throws {
            self.rollbackPlanID = rollbackPlanID
            self.backupRecordID = backupRecordID
            self.triggerVerificationResultID = triggerVerificationResultID
            self.diagnosticReference = diagnosticReference
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["rollbackPlanID", "backupRecordID", "triggerVerificationResultID", "diagnosticReference"])
            try self.init(rollbackPlanID: try ContractFields.string(try fields.required("rollbackPlanID")), backupRecordID: try ContractFields.string(try fields.required("backupRecordID")), triggerVerificationResultID: try ContractFields.string(try fields.required("triggerVerificationResultID")), diagnosticReference: try DiagnosticReference(contractJSON: try fields.required("diagnosticReference")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("rollbackPlanID", .string(rollbackPlanID)))
            members.append(JSONMember("backupRecordID", .string(backupRecordID)))
            members.append(JSONMember("triggerVerificationResultID", .string(triggerVerificationResultID)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema RollbackResult.schema.json sha256=25aa5607a0916a8d0e2c7a81b1f3ea4b776bcddc43c4d9fc1593691611589a73
    public struct RollbackResult: ContractValue, Equatable {
        public static func == (lhs: RollbackResult, rhs: RollbackResult) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let rollbackResultID: String
        public enum Status: String, ContractValue {
            case succeeded = "SUCCEEDED"
            case failed = "FAILED"
            case notRequired = "NOT_REQUIRED"
            public init(contractJSON: JSONValue) throws { guard let value = Self(rawValue: try ContractFields.string(contractJSON)) else { throw CanonicalJSONError.invalidContract("RollbackResult.status") }; self = value }
            public var contractJSON: JSONValue { .string(rawValue) }
        }
        public let status: Status
        public let backupRecordID: String
        public let restoredHash: String
        public let escalationDecision: EscalationDecision?
        public let diagnosticReference: DiagnosticReference
        public init(rollbackResultID: String, status: Status, backupRecordID: String, restoredHash: String, escalationDecision: EscalationDecision? = nil, diagnosticReference: DiagnosticReference) throws {
            self.rollbackResultID = rollbackResultID
            self.status = status
            self.backupRecordID = backupRecordID
            self.restoredHash = restoredHash
            self.escalationDecision = escalationDecision
            self.diagnosticReference = diagnosticReference
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["rollbackResultID", "status", "backupRecordID", "restoredHash", "escalationDecision", "diagnosticReference"])
            try self.init(rollbackResultID: try ContractFields.string(try fields.required("rollbackResultID")), status: try Status(contractJSON: try fields.required("status")), backupRecordID: try ContractFields.string(try fields.required("backupRecordID")), restoredHash: try ContractFields.string(try fields.required("restoredHash")), escalationDecision: try fields.optional("escalationDecision").map { try EscalationDecision(contractJSON: $0) }, diagnosticReference: try DiagnosticReference(contractJSON: try fields.required("diagnosticReference")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("rollbackResultID", .string(rollbackResultID)))
            members.append(JSONMember("status", status.contractJSON))
            members.append(JSONMember("backupRecordID", .string(backupRecordID)))
            members.append(JSONMember("restoredHash", .string(restoredHash)))
            if let value = escalationDecision { members.append(JSONMember("escalationDecision", value.contractJSON)) }
            members.append(JSONMember("diagnosticReference", diagnosticReference.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema RuleReference.schema.json sha256=3b81d72b24e9d6077e40e78679a77865ceba151d666e1fa300866cc51e51162a
    public struct RuleReference: ContractValue, Equatable {
        public static func == (lhs: RuleReference, rhs: RuleReference) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let ruleID: String
        public let sourceReference: String
        public let ruleFamily: String
        public init(ruleID: String, sourceReference: String, ruleFamily: String) throws {
            self.ruleID = ruleID
            self.sourceReference = sourceReference
            self.ruleFamily = ruleFamily
            guard ruleID.range(of: "^ASH-[A-Z]+-[A-Z]+-[0-9]{3}$", options: .regularExpression) != nil else { throw CanonicalJSONError.invalidContract("RuleReference.ruleID pattern") }
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["ruleID", "sourceReference", "ruleFamily"])
            try self.init(ruleID: try ContractFields.string(try fields.required("ruleID")), sourceReference: try ContractFields.string(try fields.required("sourceReference")), ruleFamily: try ContractFields.string(try fields.required("ruleFamily")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("ruleID", .string(ruleID)))
            members.append(JSONMember("sourceReference", .string(sourceReference)))
            members.append(JSONMember("ruleFamily", .string(ruleFamily)))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema SafeHaltDecision.schema.json sha256=e4d1123d7d48ce777fd00b130dd93aa4fc0d886bf125f8e387eac6e66bcf1e74
    public struct SafeHaltDecision: ContractValue, Equatable {
        public static func == (lhs: SafeHaltDecision, rhs: SafeHaltDecision) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let safeHaltDecisionID: String
        public let terminal: Bool
        public let blockedTransitions: [String]
        public let diagnosticReference: DiagnosticReference
        public init(safeHaltDecisionID: String, terminal: Bool, blockedTransitions: [String], diagnosticReference: DiagnosticReference) throws {
            self.safeHaltDecisionID = safeHaltDecisionID
            self.terminal = terminal
            self.blockedTransitions = blockedTransitions
            self.diagnosticReference = diagnosticReference
            guard terminal == true else { throw CanonicalJSONError.invalidContract("SafeHaltDecision.terminal const") }
            guard blockedTransitions.count >= 1 else { throw CanonicalJSONError.invalidContract("SafeHaltDecision.blockedTransitions array bounds") }
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["safeHaltDecisionID", "terminal", "blockedTransitions", "diagnosticReference"])
            try self.init(safeHaltDecisionID: try ContractFields.string(try fields.required("safeHaltDecisionID")), terminal: try ContractFields.boolean(try fields.required("terminal")), blockedTransitions: try ContractFields.array(try fields.required("blockedTransitions")).map { try ContractFields.string($0) }, diagnosticReference: try DiagnosticReference(contractJSON: try fields.required("diagnosticReference")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("safeHaltDecisionID", .string(safeHaltDecisionID)))
            members.append(JSONMember("terminal", .bool(terminal)))
            members.append(JSONMember("blockedTransitions", .array(blockedTransitions.map { .string($0) })))
            members.append(JSONMember("diagnosticReference", diagnosticReference.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema SemanticDimensionBinding.schema.json sha256=7873a4e138e62d7778c9b8210a82d73a2becd7c3d4e112fdc78f3def0a578da5
    public struct SemanticDimensionBinding: ContractValue, Equatable {
        public static func == (lhs: SemanticDimensionBinding, rhs: SemanticDimensionBinding) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public enum DimensionID: String, ContractValue {
            case b0 = "b0"
            case b1 = "b1"
            case b2 = "b2"
            case b3 = "b3"
            case b4 = "b4"
            case b5 = "b5"
            case b6 = "b6"
            case b7 = "b7"
            case b8 = "b8"
            public init(contractJSON: JSONValue) throws { guard let value = Self(rawValue: try ContractFields.string(contractJSON)) else { throw CanonicalJSONError.invalidContract("SemanticDimensionBinding.dimensionID") }; self = value }
            public var contractJSON: JSONValue { .string(rawValue) }
        }
        public let dimensionID: DimensionID
        public let sourcePointers: [JsonPointer]
        public let mappingRule: String
        public let evidence: [JSONValue]
        public let diagnosticReference: DiagnosticReference
        public init(dimensionID: DimensionID, sourcePointers: [JsonPointer], mappingRule: String, evidence: [JSONValue], diagnosticReference: DiagnosticReference) throws {
            self.dimensionID = dimensionID
            self.sourcePointers = sourcePointers
            self.mappingRule = mappingRule
            self.evidence = evidence
            self.diagnosticReference = diagnosticReference
            guard sourcePointers.count >= 1 else { throw CanonicalJSONError.invalidContract("SemanticDimensionBinding.sourcePointers array bounds") }
            guard evidence.count >= 1 else { throw CanonicalJSONError.invalidContract("SemanticDimensionBinding.evidence array bounds") }
            for item in evidence { guard case .object = item else { throw CanonicalJSONError.invalidContract("SemanticDimensionBinding.evidence[] must be object") } }
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["dimensionID", "sourcePointers", "mappingRule", "evidence", "diagnosticReference"])
            try self.init(dimensionID: try DimensionID(contractJSON: try fields.required("dimensionID")), sourcePointers: try ContractFields.array(try fields.required("sourcePointers")).map { try JsonPointer(contractJSON: $0) }, mappingRule: try ContractFields.string(try fields.required("mappingRule")), evidence: try ContractFields.array(try fields.required("evidence")).map { $0 }, diagnosticReference: try DiagnosticReference(contractJSON: try fields.required("diagnosticReference")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("dimensionID", dimensionID.contractJSON))
            members.append(JSONMember("sourcePointers", .array(sourcePointers.map { $0.contractJSON })))
            members.append(JSONMember("mappingRule", .string(mappingRule)))
            members.append(JSONMember("evidence", .array(evidence.map { $0 })))
            members.append(JSONMember("diagnosticReference", diagnosticReference.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema SemanticProjectionSpec.schema.json sha256=650a35f4b26fcfb446b438884494ce6479121a44fa71934d2a217867cfbd5a59
    public struct SemanticProjectionSpec: ContractValue, Equatable {
        public static func == (lhs: SemanticProjectionSpec, rhs: SemanticProjectionSpec) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let projectionSpecID: String
        public let dimensions: [SemanticDimensionBinding]
        public let version: String
        public let sourceReferences: [String]
        public init(projectionSpecID: String, dimensions: [SemanticDimensionBinding], version: String, sourceReferences: [String]) throws {
            self.projectionSpecID = projectionSpecID
            self.dimensions = dimensions
            self.version = version
            self.sourceReferences = sourceReferences
            guard dimensions.count >= 9 && dimensions.count <= 9 else { throw CanonicalJSONError.invalidContract("SemanticProjectionSpec.dimensions array bounds") }
            guard sourceReferences.count >= 1 else { throw CanonicalJSONError.invalidContract("SemanticProjectionSpec.sourceReferences array bounds") }
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["projectionSpecID", "dimensions", "version", "sourceReferences"])
            try self.init(projectionSpecID: try ContractFields.string(try fields.required("projectionSpecID")), dimensions: try ContractFields.array(try fields.required("dimensions")).map { try SemanticDimensionBinding(contractJSON: $0) }, version: try ContractFields.string(try fields.required("version")), sourceReferences: try ContractFields.array(try fields.required("sourceReferences")).map { try ContractFields.string($0) })
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("projectionSpecID", .string(projectionSpecID)))
            members.append(JSONMember("dimensions", .array(dimensions.map { $0.contractJSON })))
            members.append(JSONMember("version", .string(version)))
            members.append(JSONMember("sourceReferences", .array(sourceReferences.map { .string($0) })))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema StateValidityDiagnostic.schema.json sha256=c02d1114b303e8bd013590c22d97a77ce774e05da928e9d9f78dcf2ee148c9cd
    public struct StateValidityDiagnostic: ContractValue, Equatable {
        public static func == (lhs: StateValidityDiagnostic, rhs: StateValidityDiagnostic) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let stateValidityDiagnosticID: String
        public let diagnosticEnvelope: DiagnosticEnvelope
        public enum AdmissibilityStatus: String, ContractValue {
            case valid = "VALID"
            case transformationCompatible = "TRANSFORMATION_COMPATIBLE"
            case transformationIncompatible = "TRANSFORMATION_INCOMPATIBLE"
            case unclassified = "UNCLASSIFIED"
            public init(contractJSON: JSONValue) throws { guard let value = Self(rawValue: try ContractFields.string(contractJSON)) else { throw CanonicalJSONError.invalidContract("StateValidityDiagnostic.admissibilityStatus") }; self = value }
            public var contractJSON: JSONValue { .string(rawValue) }
        }
        public let admissibilityStatus: AdmissibilityStatus
        public enum NormalizationStatus: String, ContractValue {
            case alreadyValid = "ALREADY_VALID"
            case normalizable = "NORMALIZABLE"
            case notNormalizable = "NOT_NORMALIZABLE"
            case blocked = "BLOCKED"
            public init(contractJSON: JSONValue) throws { guard let value = Self(rawValue: try ContractFields.string(contractJSON)) else { throw CanonicalJSONError.invalidContract("StateValidityDiagnostic.normalizationStatus") }; self = value }
            public var contractJSON: JSONValue { .string(rawValue) }
        }
        public let normalizationStatus: NormalizationStatus
        public let recoverabilityRelevance: RecoveryCategory
        public init(stateValidityDiagnosticID: String, diagnosticEnvelope: DiagnosticEnvelope, admissibilityStatus: AdmissibilityStatus, normalizationStatus: NormalizationStatus, recoverabilityRelevance: RecoveryCategory) throws {
            self.stateValidityDiagnosticID = stateValidityDiagnosticID
            self.diagnosticEnvelope = diagnosticEnvelope
            self.admissibilityStatus = admissibilityStatus
            self.normalizationStatus = normalizationStatus
            self.recoverabilityRelevance = recoverabilityRelevance
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["stateValidityDiagnosticID", "diagnosticEnvelope", "admissibilityStatus", "normalizationStatus", "recoverabilityRelevance"])
            try self.init(stateValidityDiagnosticID: try ContractFields.string(try fields.required("stateValidityDiagnosticID")), diagnosticEnvelope: try DiagnosticEnvelope(contractJSON: try fields.required("diagnosticEnvelope")), admissibilityStatus: try AdmissibilityStatus(contractJSON: try fields.required("admissibilityStatus")), normalizationStatus: try NormalizationStatus(contractJSON: try fields.required("normalizationStatus")), recoverabilityRelevance: try RecoveryCategory(contractJSON: try fields.required("recoverabilityRelevance")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("stateValidityDiagnosticID", .string(stateValidityDiagnosticID)))
            members.append(JSONMember("diagnosticEnvelope", diagnosticEnvelope.contractJSON))
            members.append(JSONMember("admissibilityStatus", admissibilityStatus.contractJSON))
            members.append(JSONMember("normalizationStatus", normalizationStatus.contractJSON))
            members.append(JSONMember("recoverabilityRelevance", recoverabilityRelevance.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema SurfaceDifference.schema.json sha256=0104a059f183d1878589881e3462a1ae154b323e44fac7620ea60956d96e66e8
    public struct SurfaceDifference: ContractValue, Equatable {
        public static func == (lhs: SurfaceDifference, rhs: SurfaceDifference) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let differenceID: String
        public let path: JsonPointer
        public enum DifferenceKind: String, ContractValue {
            case missing = "MISSING"
            case added = "ADDED"
            case removed = "REMOVED"
            case replaced = "REPLACED"
            case typeChanged = "TYPE_CHANGED"
            case arrayChanged = "ARRAY_CHANGED"
            public init(contractJSON: JSONValue) throws { guard let value = Self(rawValue: try ContractFields.string(contractJSON)) else { throw CanonicalJSONError.invalidContract("SurfaceDifference.differenceKind") }; self = value }
            public var contractJSON: JSONValue { .string(rawValue) }
        }
        public let differenceKind: DifferenceKind
        public let observedDocument: JsonDocumentReference
        public let desiredDocument: JsonDocumentReference
        public let diagnosticReference: DiagnosticReference
        public init(differenceID: String, path: JsonPointer, differenceKind: DifferenceKind, observedDocument: JsonDocumentReference, desiredDocument: JsonDocumentReference, diagnosticReference: DiagnosticReference) throws {
            self.differenceID = differenceID
            self.path = path
            self.differenceKind = differenceKind
            self.observedDocument = observedDocument
            self.desiredDocument = desiredDocument
            self.diagnosticReference = diagnosticReference
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["differenceID", "path", "differenceKind", "observedDocument", "desiredDocument", "diagnosticReference"])
            try self.init(differenceID: try ContractFields.string(try fields.required("differenceID")), path: try JsonPointer(contractJSON: try fields.required("path")), differenceKind: try DifferenceKind(contractJSON: try fields.required("differenceKind")), observedDocument: try JsonDocumentReference(contractJSON: try fields.required("observedDocument")), desiredDocument: try JsonDocumentReference(contractJSON: try fields.required("desiredDocument")), diagnosticReference: try DiagnosticReference(contractJSON: try fields.required("diagnosticReference")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("differenceID", .string(differenceID)))
            members.append(JSONMember("path", path.contractJSON))
            members.append(JSONMember("differenceKind", differenceKind.contractJSON))
            members.append(JSONMember("observedDocument", observedDocument.contractJSON))
            members.append(JSONMember("desiredDocument", desiredDocument.contractJSON))
            members.append(JSONMember("diagnosticReference", diagnosticReference.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema SystemStateClass.schema.json sha256=8f1fa471e72012f5a65d1867527f399351229d12362aa1bf0be295fb897185ac
    public enum SystemStateClass: String, ContractValue {
        case stable = "STABLE"
        case unstable = "UNSTABLE"
        case correctable = "CORRECTABLE"
        case degraded = "DEGRADED"
        case contained = "CONTAINED"
        case failed = "FAILED"
        case safeHalt = "SAFE_HALT"
        public init(contractJSON: JSONValue) throws { guard let value = Self(rawValue: try ContractFields.string(contractJSON)) else { throw CanonicalJSONError.invalidContract("SystemStateClass") }; self = value }
        public var contractJSON: JSONValue { .string(rawValue) }
    }
    // Frozen schema TopologyPlan.schema.json sha256=f038166ff626e2b332eeb0024980a86d7fcdb5a405c37911d45dd15c020bc892
    public struct TopologyPlan: ContractValue, Equatable {
        public static func == (lhs: TopologyPlan, rhs: TopologyPlan) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let topologyID: String
        public let rootState: AshState
        public let nodes: [JSONValue]
        public let edges: [JSONValue]
        public let lineage: JSONValue
        public let diagnosticReferences: [DiagnosticReference]
        public init(topologyID: String, rootState: AshState, nodes: [JSONValue], edges: [JSONValue], lineage: JSONValue, diagnosticReferences: [DiagnosticReference]) throws {
            self.topologyID = topologyID
            self.rootState = rootState
            self.nodes = nodes
            self.edges = edges
            self.lineage = lineage
            self.diagnosticReferences = diagnosticReferences
            guard nodes.count >= 1 else { throw CanonicalJSONError.invalidContract("TopologyPlan.nodes array bounds") }
            for item in nodes { guard case .object = item else { throw CanonicalJSONError.invalidContract("TopologyPlan.nodes[] must be object") } }
            guard edges.count >= 1 else { throw CanonicalJSONError.invalidContract("TopologyPlan.edges array bounds") }
            for item in edges { guard case .object = item else { throw CanonicalJSONError.invalidContract("TopologyPlan.edges[] must be object") } }
            guard case .object = lineage else { throw CanonicalJSONError.invalidContract("TopologyPlan.lineage must be object") }
            guard diagnosticReferences.count >= 1 else { throw CanonicalJSONError.invalidContract("TopologyPlan.diagnosticReferences array bounds") }
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["topologyID", "rootState", "nodes", "edges", "lineage", "diagnosticReferences"])
            try self.init(topologyID: try ContractFields.string(try fields.required("topologyID")), rootState: try AshState(contractJSON: try fields.required("rootState")), nodes: try ContractFields.array(try fields.required("nodes")).map { $0 }, edges: try ContractFields.array(try fields.required("edges")).map { $0 }, lineage: try fields.required("lineage"), diagnosticReferences: try ContractFields.array(try fields.required("diagnosticReferences")).map { try DiagnosticReference(contractJSON: $0) })
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("topologyID", .string(topologyID)))
            members.append(JSONMember("rootState", rootState.contractJSON))
            members.append(JSONMember("nodes", .array(nodes.map { $0 })))
            members.append(JSONMember("edges", .array(edges.map { $0 })))
            members.append(JSONMember("lineage", lineage))
            members.append(JSONMember("diagnosticReferences", .array(diagnosticReferences.map { $0.contractJSON })))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema TransitionDefinition.schema.json sha256=d28718728cd11f5a80302aa352aed7570725f44e3d084bd70c44791f1864029c
    public struct TransitionDefinition: ContractValue, Equatable {
        public static func == (lhs: TransitionDefinition, rhs: TransitionDefinition) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let transitionID: String
        public let codewordReference: String
        public let preconditions: [String]
        public let diagnosticRules: [RuleReference]
        public init(transitionID: String, codewordReference: String, preconditions: [String], diagnosticRules: [RuleReference]) throws {
            self.transitionID = transitionID
            self.codewordReference = codewordReference
            self.preconditions = preconditions
            self.diagnosticRules = diagnosticRules
            guard preconditions.count >= 1 else { throw CanonicalJSONError.invalidContract("TransitionDefinition.preconditions array bounds") }
            guard diagnosticRules.count >= 1 else { throw CanonicalJSONError.invalidContract("TransitionDefinition.diagnosticRules array bounds") }
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["transitionID", "codewordReference", "preconditions", "diagnosticRules"])
            try self.init(transitionID: try ContractFields.string(try fields.required("transitionID")), codewordReference: try ContractFields.string(try fields.required("codewordReference")), preconditions: try ContractFields.array(try fields.required("preconditions")).map { try ContractFields.string($0) }, diagnosticRules: try ContractFields.array(try fields.required("diagnosticRules")).map { try RuleReference(contractJSON: $0) })
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("transitionID", .string(transitionID)))
            members.append(JSONMember("codewordReference", .string(codewordReference)))
            members.append(JSONMember("preconditions", .array(preconditions.map { .string($0) })))
            members.append(JSONMember("diagnosticRules", .array(diagnosticRules.map { $0.contractJSON })))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema TransitionResult.schema.json sha256=8b5cf4e2e41d71b1743dbc041a6925f7d0eb612be8a15fa69eb97133377b30a7
    public struct TransitionResult: ContractValue, Equatable {
        public static func == (lhs: TransitionResult, rhs: TransitionResult) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let resultID: String
        public let transitionID: String
        public let inputState: AshState
        public let outputState: AshState
        public let diagnosticReference: DiagnosticReference
        public init(resultID: String, transitionID: String, inputState: AshState, outputState: AshState, diagnosticReference: DiagnosticReference) throws {
            self.resultID = resultID
            self.transitionID = transitionID
            self.inputState = inputState
            self.outputState = outputState
            self.diagnosticReference = diagnosticReference
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["resultID", "transitionID", "inputState", "outputState", "diagnosticReference"])
            try self.init(resultID: try ContractFields.string(try fields.required("resultID")), transitionID: try ContractFields.string(try fields.required("transitionID")), inputState: try AshState(contractJSON: try fields.required("inputState")), outputState: try AshState(contractJSON: try fields.required("outputState")), diagnosticReference: try DiagnosticReference(contractJSON: try fields.required("diagnosticReference")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("resultID", .string(resultID)))
            members.append(JSONMember("transitionID", .string(transitionID)))
            members.append(JSONMember("inputState", inputState.contractJSON))
            members.append(JSONMember("outputState", outputState.contractJSON))
            members.append(JSONMember("diagnosticReference", diagnosticReference.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema VerificationPlan.schema.json sha256=6225c161b39ddf9415d05bd277f6f75181863094b2f812d336f213378b2ff13e
    public struct VerificationPlan: ContractValue, Equatable {
        public static func == (lhs: VerificationPlan, rhs: VerificationPlan) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let verificationPlanID: String
        public let checks: [JSONValue]
        public let expectedSemanticState: AshState
        public let generatedBeforeMutation: Bool
        public let diagnosticReference: DiagnosticReference
        public init(verificationPlanID: String, checks: [JSONValue], expectedSemanticState: AshState, generatedBeforeMutation: Bool, diagnosticReference: DiagnosticReference) throws {
            self.verificationPlanID = verificationPlanID
            self.checks = checks
            self.expectedSemanticState = expectedSemanticState
            self.generatedBeforeMutation = generatedBeforeMutation
            self.diagnosticReference = diagnosticReference
            guard checks.count >= 1 else { throw CanonicalJSONError.invalidContract("VerificationPlan.checks array bounds") }
            for item in checks { guard case .object = item else { throw CanonicalJSONError.invalidContract("VerificationPlan.checks[] must be object") } }
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["verificationPlanID", "checks", "expectedSemanticState", "generatedBeforeMutation", "diagnosticReference"])
            try self.init(verificationPlanID: try ContractFields.string(try fields.required("verificationPlanID")), checks: try ContractFields.array(try fields.required("checks")).map { $0 }, expectedSemanticState: try AshState(contractJSON: try fields.required("expectedSemanticState")), generatedBeforeMutation: try ContractFields.boolean(try fields.required("generatedBeforeMutation")), diagnosticReference: try DiagnosticReference(contractJSON: try fields.required("diagnosticReference")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("verificationPlanID", .string(verificationPlanID)))
            members.append(JSONMember("checks", .array(checks.map { $0 })))
            members.append(JSONMember("expectedSemanticState", expectedSemanticState.contractJSON))
            members.append(JSONMember("generatedBeforeMutation", .bool(generatedBeforeMutation)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
    // Frozen schema VerificationResult.schema.json sha256=cfe1e8c7e2c87e515dae82d43ae92f7e59f1d5f9a609278b26869e7a75944ea7
    public struct VerificationResult: ContractValue, Equatable {
        public static func == (lhs: VerificationResult, rhs: VerificationResult) -> Bool { lhs.contractJSON == rhs.contractJSON }
        public let verificationResultID: String
        public let verificationPlanID: String
        public enum Status: String, ContractValue {
            case passed = "PASSED"
            case failed = "FAILED"
            case blocked = "BLOCKED"
            public init(contractJSON: JSONValue) throws { guard let value = Self(rawValue: try ContractFields.string(contractJSON)) else { throw CanonicalJSONError.invalidContract("VerificationResult.status") }; self = value }
            public var contractJSON: JSONValue { .string(rawValue) }
        }
        public let status: Status
        public let expectedSemanticState: AshState
        public let actualSemanticState: AshState
        public let diagnosticReference: DiagnosticReference
        public init(verificationResultID: String, verificationPlanID: String, status: Status, expectedSemanticState: AshState, actualSemanticState: AshState, diagnosticReference: DiagnosticReference) throws {
            self.verificationResultID = verificationResultID
            self.verificationPlanID = verificationPlanID
            self.status = status
            self.expectedSemanticState = expectedSemanticState
            self.actualSemanticState = actualSemanticState
            self.diagnosticReference = diagnosticReference
        }
        public init(contractJSON: JSONValue) throws {
            let fields = try ContractFields(contractJSON, allowed: ["verificationResultID", "verificationPlanID", "status", "expectedSemanticState", "actualSemanticState", "diagnosticReference"])
            try self.init(verificationResultID: try ContractFields.string(try fields.required("verificationResultID")), verificationPlanID: try ContractFields.string(try fields.required("verificationPlanID")), status: try Status(contractJSON: try fields.required("status")), expectedSemanticState: try AshState(contractJSON: try fields.required("expectedSemanticState")), actualSemanticState: try AshState(contractJSON: try fields.required("actualSemanticState")), diagnosticReference: try DiagnosticReference(contractJSON: try fields.required("diagnosticReference")))
        }
        public var contractJSON: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("verificationResultID", .string(verificationResultID)))
            members.append(JSONMember("verificationPlanID", .string(verificationPlanID)))
            members.append(JSONMember("status", status.contractJSON))
            members.append(JSONMember("expectedSemanticState", expectedSemanticState.contractJSON))
            members.append(JSONMember("actualSemanticState", actualSemanticState.contractJSON))
            members.append(JSONMember("diagnosticReference", diagnosticReference.contractJSON))
            return .object(members)
        }
        public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
        public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
    }
}

struct ContractFields {
    let members: [JSONMember]
    init(_ value: JSONValue, allowed: [String]) throws {
        guard case .object(let members) = value else { throw CanonicalJSONError.invalidContract("object required") }
        try value.validateLexicalStructure()
        guard members.allSatisfy({ member in allowed.contains { $0.utf8.elementsEqual(member.name.utf8) } }) else { throw CanonicalJSONError.invalidContract("unknown property") }
        self.members = members
    }
    func required(_ name: String) throws -> JSONValue { guard let value = optional(name) else { throw CanonicalJSONError.invalidContract("missing " + name) }; return value }
    func optional(_ name: String) -> JSONValue? { members.first { $0.name.utf8.elementsEqual(name.utf8) }?.value }
    static func string(_ value: JSONValue) throws -> String { guard case .string(let v) = value else { throw CanonicalJSONError.invalidContract("string required") }; return v }
    static func nullableString(_ value: JSONValue) throws -> String? { if value == .null { return nil }; return try string(value) }
    static func integer(_ value: JSONValue) throws -> Int { let v = try ContractInteger(contractJSON: value); guard let result = v.intValue else { throw CanonicalJSONError.invalidContract("integer required") }; return result }
    static func boolean(_ value: JSONValue) throws -> Bool { guard case .bool(let v) = value else { throw CanonicalJSONError.invalidContract("boolean required") }; return v }
    static func array(_ value: JSONValue) throws -> [JSONValue] { guard case .array(let v) = value else { throw CanonicalJSONError.invalidContract("array required") }; return v }
}
