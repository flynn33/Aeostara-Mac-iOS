import Foundation

/// Native immutable values corresponding to the exact Aeostara base contract titles.
public enum AeostaraContract {}

public extension AeostaraContract {
    struct AdmissibilityResult: CanonicalContract {
        public static let contractName = "AdmissibilityResult"
        public enum StatusValue: String, Codable { case VALID = "VALID"; case TRANSFORMATION_COMPATIBLE = "TRANSFORMATION_COMPATIBLE"; case TRANSFORMATION_INCOMPATIBLE = "TRANSFORMATION_INCOMPATIBLE"; case UNCLASSIFIED = "UNCLASSIFIED" }
        public let resultID: String
        public let stateReference: String
        public let status: StatusValue
        public let orbitReference: String
        public let diagnosticReference: DiagnosticReference
        public init(resultID: String, stateReference: String, status: StatusValue, orbitReference: String, diagnosticReference: DiagnosticReference) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("resultID", .string(resultID)))
            members.append(JSONMember("stateReference", .string(stateReference)))
            members.append(JSONMember("status", .string(status.rawValue)))
            members.append(JSONMember("orbitReference", .string(orbitReference)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["resultID", "stateReference", "status", "orbitReference", "diagnosticReference"], required: ["resultID", "stateReference", "status", "orbitReference", "diagnosticReference"])
            self.resultID = try ContractFields.string(fields.require("resultID"))
            self.stateReference = try ContractFields.string(fields.require("stateReference"))
            self.status = try ContractFields.enumeration(StatusValue.self, fields.require("status"))
            self.orbitReference = try ContractFields.string(fields.require("orbitReference"))
            self.diagnosticReference = try DiagnosticReference(jsonValue: fields.require("diagnosticReference"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("resultID", .string(resultID)))
            members.append(JSONMember("stateReference", .string(stateReference)))
            members.append(JSONMember("status", .string(status.rawValue)))
            members.append(JSONMember("orbitReference", .string(orbitReference)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct ArtifactEmissionPlan: CanonicalContract {
        public static let contractName = "ArtifactEmissionPlan"
        public let emissionPlanID: String
        public let generationPlanID: String
        public let artifacts: [JSONValue ]
        public let traceability: [JSONValue ]
        public init(emissionPlanID: String, generationPlanID: String, artifacts: [JSONValue ], traceability: [JSONValue ]) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("emissionPlanID", .string(emissionPlanID)))
            members.append(JSONMember("generationPlanID", .string(generationPlanID)))
            members.append(JSONMember("artifacts", .array(artifacts.map { value in value })))
            members.append(JSONMember("traceability", .array(traceability.map { value in value })))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["emissionPlanID", "generationPlanID", "artifacts", "traceability"], required: ["emissionPlanID", "generationPlanID", "artifacts", "traceability"])
            self.emissionPlanID = try ContractFields.string(fields.require("emissionPlanID"))
            self.generationPlanID = try ContractFields.string(fields.require("generationPlanID"))
            self.artifacts = try ContractFields.array(fields.require("artifacts")).map { value in try ContractFields.object(value) }
            do { let value = try fields.require("artifacts"); guard try ContractFields.array(value).count >= 1 else { throw CanonicalJSONError.invalidContract("ArtifactEmissionPlan.artifacts") } }
            self.traceability = try ContractFields.array(fields.require("traceability")).map { value in try ContractFields.object(value) }
            do { let value = try fields.require("traceability"); guard try ContractFields.array(value).count >= 1 else { throw CanonicalJSONError.invalidContract("ArtifactEmissionPlan.traceability") } }
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("emissionPlanID", .string(emissionPlanID)))
            members.append(JSONMember("generationPlanID", .string(generationPlanID)))
            members.append(JSONMember("artifacts", .array(artifacts.map { value in value })))
            members.append(JSONMember("traceability", .array(traceability.map { value in value })))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct AshSemanticState: CanonicalContract {
        public static let contractName = "AshSemanticState"
        public let ashSemanticStateID: String
        public let ashState: AshState
        public let admissibilityResult: AdmissibilityResult
        public let realmIdentity: RealmIdentity
        public let diagnosticReference: DiagnosticReference
        public init(ashSemanticStateID: String, ashState: AshState, admissibilityResult: AdmissibilityResult, realmIdentity: RealmIdentity, diagnosticReference: DiagnosticReference) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("ashSemanticStateID", .string(ashSemanticStateID)))
            members.append(JSONMember("ashState", ashState.jsonValue))
            members.append(JSONMember("admissibilityResult", admissibilityResult.jsonValue))
            members.append(JSONMember("realmIdentity", realmIdentity.jsonValue))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["ashSemanticStateID", "ashState", "admissibilityResult", "realmIdentity", "diagnosticReference"], required: ["ashSemanticStateID", "ashState", "admissibilityResult", "realmIdentity", "diagnosticReference"])
            self.ashSemanticStateID = try ContractFields.string(fields.require("ashSemanticStateID"))
            self.ashState = try AshState(jsonValue: fields.require("ashState"))
            self.admissibilityResult = try AdmissibilityResult(jsonValue: fields.require("admissibilityResult"))
            self.realmIdentity = try RealmIdentity(jsonValue: fields.require("realmIdentity"))
            self.diagnosticReference = try DiagnosticReference(jsonValue: fields.require("diagnosticReference"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("ashSemanticStateID", .string(ashSemanticStateID)))
            members.append(JSONMember("ashState", ashState.jsonValue))
            members.append(JSONMember("admissibilityResult", admissibilityResult.jsonValue))
            members.append(JSONMember("realmIdentity", realmIdentity.jsonValue))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct AshState: CanonicalContract {
        public static let contractName = "AshState"
        public let stateID: String
        public let coordinates: [Int ]
        public let sourceReference: String
        public let canonicalHash: String
        public init(stateID: String, coordinates: [Int ], sourceReference: String, canonicalHash: String) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("stateID", .string(stateID)))
            members.append(JSONMember("coordinates", .array(coordinates.map { value in .number(.integer(String(value))) })))
            members.append(JSONMember("sourceReference", .string(sourceReference)))
            members.append(JSONMember("canonicalHash", .string(canonicalHash)))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["stateID", "coordinates", "sourceReference", "canonicalHash"], required: ["stateID", "coordinates", "sourceReference", "canonicalHash"])
            self.stateID = try ContractFields.string(fields.require("stateID"))
            self.coordinates = try ContractFields.array(fields.require("coordinates")).map { value in try ContractFields.integer(value) }
            do { let value = try fields.require("coordinates"); guard try ContractFields.array(value).count >= 9 else { throw CanonicalJSONError.invalidContract("AshState.coordinates") }; guard try ContractFields.array(value).count <= 9 else { throw CanonicalJSONError.invalidContract("AshState.coordinates") }; for item in try ContractFields.array(value) { guard [0,1].contains(try ContractFields.integer(item)) else { throw CanonicalJSONError.invalidContract("AshState.coordinates[]") } } }
            self.sourceReference = try ContractFields.string(fields.require("sourceReference"))
            self.canonicalHash = try ContractFields.string(fields.require("canonicalHash"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("stateID", .string(stateID)))
            members.append(JSONMember("coordinates", .array(coordinates.map { value in .number(.integer(String(value))) })))
            members.append(JSONMember("sourceReference", .string(sourceReference)))
            members.append(JSONMember("canonicalHash", .string(canonicalHash)))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct AuditChain: CanonicalContract {
        public static let contractName = "AuditChain"
        public let auditChainID: String
        public let diagnosticChainReference: String
        public let events: [AuditEvent ]
        public init(auditChainID: String, diagnosticChainReference: String, events: [AuditEvent ]) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("auditChainID", .string(auditChainID)))
            members.append(JSONMember("diagnosticChainReference", .string(diagnosticChainReference)))
            members.append(JSONMember("events", .array(events.map { value in value.jsonValue })))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["auditChainID", "diagnosticChainReference", "events"], required: ["auditChainID", "diagnosticChainReference", "events"])
            self.auditChainID = try ContractFields.string(fields.require("auditChainID"))
            self.diagnosticChainReference = try ContractFields.string(fields.require("diagnosticChainReference"))
            self.events = try ContractFields.array(fields.require("events")).map { value in try AuditEvent(jsonValue: value) }
            do { let value = try fields.require("events"); guard try ContractFields.array(value).count >= 1 else { throw CanonicalJSONError.invalidContract("AuditChain.events") } }
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("auditChainID", .string(auditChainID)))
            members.append(JSONMember("diagnosticChainReference", .string(diagnosticChainReference)))
            members.append(JSONMember("events", .array(events.map { value in value.jsonValue })))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct AuditEvent: CanonicalContract {
        public static let contractName = "AuditEvent"
        public enum EventTypeValue: String, Codable { case OBSERVE = "OBSERVE"; case NORMALIZE = "NORMALIZE"; case PROJECT = "PROJECT"; case DIAGNOSE = "DIAGNOSE"; case CLASSIFY = "CLASSIFY"; case PLAN = "PLAN"; case POLICY_GATE = "POLICY_GATE"; case BACKUP = "BACKUP"; case EXECUTE = "EXECUTE"; case VERIFY = "VERIFY"; case ROLLBACK = "ROLLBACK"; case FALLBACK = "FALLBACK"; case CONTAINMENT = "CONTAINMENT"; case SAFE_HALT = "SAFE_HALT"; case RESULT = "RESULT" }
        public let auditEventID: String
        public let eventSequence: JSONInteger
        public let eventType: EventTypeValue
        public let diagnosticReference: DiagnosticReference
        public let occurredAt: String
        public let details: JSONValue
        public init(auditEventID: String, eventSequence: Int, eventType: EventTypeValue, diagnosticReference: DiagnosticReference, occurredAt: String, details: JSONValue) throws {
            try self.init(auditEventID:auditEventID,eventSequence:JSONInteger(eventSequence),eventType:eventType,diagnosticReference:diagnosticReference,occurredAt:occurredAt,details:details)
        }
        public init(auditEventID: String, eventSequence: JSONInteger, eventType: EventTypeValue, diagnosticReference: DiagnosticReference, occurredAt: String, details: JSONValue) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("auditEventID", .string(auditEventID)))
            members.append(JSONMember("eventSequence", eventSequence.jsonValue))
            members.append(JSONMember("eventType", .string(eventType.rawValue)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            members.append(JSONMember("occurredAt", .string(occurredAt)))
            members.append(JSONMember("details", details))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["auditEventID", "eventSequence", "eventType", "diagnosticReference", "occurredAt", "details"], required: ["auditEventID", "eventSequence", "eventType", "diagnosticReference", "occurredAt", "details"])
            self.auditEventID = try ContractFields.string(fields.require("auditEventID"))
            self.eventSequence = try JSONInteger(jsonValue: fields.require("eventSequence"))
            self.eventType = try ContractFields.enumeration(EventTypeValue.self, fields.require("eventType"))
            self.diagnosticReference = try DiagnosticReference(jsonValue: fields.require("diagnosticReference"))
            self.occurredAt = try ContractFields.string(fields.require("occurredAt"))
            self.details = try ContractFields.object(fields.require("details"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("auditEventID", .string(auditEventID)))
            members.append(JSONMember("eventSequence", eventSequence.jsonValue))
            members.append(JSONMember("eventType", .string(eventType.rawValue)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            members.append(JSONMember("occurredAt", .string(occurredAt)))
            members.append(JSONMember("details", details))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct AxiomDiagnostic: CanonicalContract {
        public static let contractName = "AxiomDiagnostic"
        public enum EvaluationResultValue: String, Codable { case PASS = "PASS"; case FAIL = "FAIL"; case BLOCKED = "BLOCKED" }
        public let axiomID: String
        public let diagnosticEnvelope: DiagnosticEnvelope
        public let evaluationResult: EvaluationResultValue
        public let evidence: JSONValue
        public init(axiomID: String, diagnosticEnvelope: DiagnosticEnvelope, evaluationResult: EvaluationResultValue, evidence: JSONValue) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("axiomID", .string(axiomID)))
            members.append(JSONMember("diagnosticEnvelope", diagnosticEnvelope.jsonValue))
            members.append(JSONMember("evaluationResult", .string(evaluationResult.rawValue)))
            members.append(JSONMember("evidence", evidence))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["axiomID", "diagnosticEnvelope", "evaluationResult", "evidence"], required: ["axiomID", "diagnosticEnvelope", "evaluationResult", "evidence"])
            self.axiomID = try ContractFields.string(fields.require("axiomID"))
            self.diagnosticEnvelope = try DiagnosticEnvelope(jsonValue: fields.require("diagnosticEnvelope"))
            self.evaluationResult = try ContractFields.enumeration(EvaluationResultValue.self, fields.require("evaluationResult"))
            self.evidence = try ContractFields.object(fields.require("evidence"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("axiomID", .string(axiomID)))
            members.append(JSONMember("diagnosticEnvelope", diagnosticEnvelope.jsonValue))
            members.append(JSONMember("evaluationResult", .string(evaluationResult.rawValue)))
            members.append(JSONMember("evidence", evidence))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct BackupRecord: CanonicalContract {
        public static let contractName = "BackupRecord"
        public let backupRecordID: String
        public let sourceDocument: JsonDocumentReference
        public let sourceHash: String
        public let storageReference: String
        public let diagnosticReference: DiagnosticReference
        public init(backupRecordID: String, sourceDocument: JsonDocumentReference, sourceHash: String, storageReference: String, diagnosticReference: DiagnosticReference) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("backupRecordID", .string(backupRecordID)))
            members.append(JSONMember("sourceDocument", sourceDocument.jsonValue))
            members.append(JSONMember("sourceHash", .string(sourceHash)))
            members.append(JSONMember("storageReference", .string(storageReference)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["backupRecordID", "sourceDocument", "sourceHash", "storageReference", "diagnosticReference"], required: ["backupRecordID", "sourceDocument", "sourceHash", "storageReference", "diagnosticReference"])
            self.backupRecordID = try ContractFields.string(fields.require("backupRecordID"))
            self.sourceDocument = try JsonDocumentReference(jsonValue: fields.require("sourceDocument"))
            self.sourceHash = try ContractFields.string(fields.require("sourceHash"))
            self.storageReference = try ContractFields.string(fields.require("storageReference"))
            self.diagnosticReference = try DiagnosticReference(jsonValue: fields.require("diagnosticReference"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("backupRecordID", .string(backupRecordID)))
            members.append(JSONMember("sourceDocument", sourceDocument.jsonValue))
            members.append(JSONMember("sourceHash", .string(sourceHash)))
            members.append(JSONMember("storageReference", .string(storageReference)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct BackupResult: CanonicalContract {
        public static let contractName = "BackupResult"
        public enum StatusValue: String, Codable { case SUCCEEDED = "SUCCEEDED"; case FAILED = "FAILED"; case SKIPPED = "SKIPPED" }
        public let backupResultID: String
        public let status: StatusValue
        public let backupRecord: BackupRecord
        public let escalationDecision: EscalationDecision?
        public let diagnosticReference: DiagnosticReference
        public init(backupResultID: String, status: StatusValue, backupRecord: BackupRecord, escalationDecision: EscalationDecision? = nil, diagnosticReference: DiagnosticReference) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("backupResultID", .string(backupResultID)))
            members.append(JSONMember("status", .string(status.rawValue)))
            members.append(JSONMember("backupRecord", backupRecord.jsonValue))
            if let value = escalationDecision { members.append(JSONMember("escalationDecision", value.jsonValue)) }
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["backupResultID", "status", "backupRecord", "escalationDecision", "diagnosticReference"], required: ["backupResultID", "status", "backupRecord", "diagnosticReference"])
            self.backupResultID = try ContractFields.string(fields.require("backupResultID"))
            self.status = try ContractFields.enumeration(StatusValue.self, fields.require("status"))
            self.backupRecord = try BackupRecord(jsonValue: fields.require("backupRecord"))
            self.escalationDecision = try fields.optional("escalationDecision").map { value in try EscalationDecision(jsonValue: value) }
            self.diagnosticReference = try DiagnosticReference(jsonValue: fields.require("diagnosticReference"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("backupResultID", .string(backupResultID)))
            members.append(JSONMember("status", .string(status.rawValue)))
            members.append(JSONMember("backupRecord", backupRecord.jsonValue))
            if let value = escalationDecision { members.append(JSONMember("escalationDecision", value.jsonValue)) }
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct CanonicalCodewordSet: CanonicalContract {
        public static let contractName = "CanonicalCodewordSet"
        public let codewordSetID: String
        public let codewords: [[Int ] ]
        public let sourceReference: String
        public let canonicalHash: String
        public init(codewordSetID: String, codewords: [[Int ] ], sourceReference: String, canonicalHash: String) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("codewordSetID", .string(codewordSetID)))
            members.append(JSONMember("codewords", .array(codewords.map { value in .array(value.map { value in .number(.integer(String(value))) }) })))
            members.append(JSONMember("sourceReference", .string(sourceReference)))
            members.append(JSONMember("canonicalHash", .string(canonicalHash)))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["codewordSetID", "codewords", "sourceReference", "canonicalHash"], required: ["codewordSetID", "codewords", "sourceReference", "canonicalHash"])
            self.codewordSetID = try ContractFields.string(fields.require("codewordSetID"))
            self.codewords = try ContractFields.array(fields.require("codewords")).map { value in try ContractFields.array(value).map { value in try ContractFields.integer(value) } }
            do { let value = try fields.require("codewords"); guard try ContractFields.array(value).count >= 16 else { throw CanonicalJSONError.invalidContract("CanonicalCodewordSet.codewords") }; guard try ContractFields.array(value).count <= 16 else { throw CanonicalJSONError.invalidContract("CanonicalCodewordSet.codewords") }; for item in try ContractFields.array(value) { guard try ContractFields.array(item).count >= 9 else { throw CanonicalJSONError.invalidContract("CanonicalCodewordSet.codewords[]") }; guard try ContractFields.array(item).count <= 9 else { throw CanonicalJSONError.invalidContract("CanonicalCodewordSet.codewords[]") }; for item in try ContractFields.array(item) { guard [0,1].contains(try ContractFields.integer(item)) else { throw CanonicalJSONError.invalidContract("CanonicalCodewordSet.codewords[][]") } } } }
            self.sourceReference = try ContractFields.string(fields.require("sourceReference"))
            self.canonicalHash = try ContractFields.string(fields.require("canonicalHash"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("codewordSetID", .string(codewordSetID)))
            members.append(JSONMember("codewords", .array(codewords.map { value in .array(value.map { value in .number(.integer(String(value))) }) })))
            members.append(JSONMember("sourceReference", .string(sourceReference)))
            members.append(JSONMember("canonicalHash", .string(canonicalHash)))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct CodewordTransformation: CanonicalContract {
        public static let contractName = "CodewordTransformation"
        public let transformationID: String
        public let inputState: AshState
        public let codeword: [Int ]
        public let outputState: AshState
        public let diagnosticReference: DiagnosticReference
        public init(transformationID: String, inputState: AshState, codeword: [Int ], outputState: AshState, diagnosticReference: DiagnosticReference) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("transformationID", .string(transformationID)))
            members.append(JSONMember("inputState", inputState.jsonValue))
            members.append(JSONMember("codeword", .array(codeword.map { value in .number(.integer(String(value))) })))
            members.append(JSONMember("outputState", outputState.jsonValue))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["transformationID", "inputState", "codeword", "outputState", "diagnosticReference"], required: ["transformationID", "inputState", "codeword", "outputState", "diagnosticReference"])
            self.transformationID = try ContractFields.string(fields.require("transformationID"))
            self.inputState = try AshState(jsonValue: fields.require("inputState"))
            self.codeword = try ContractFields.array(fields.require("codeword")).map { value in try ContractFields.integer(value) }
            do { let value = try fields.require("codeword"); guard try ContractFields.array(value).count >= 9 else { throw CanonicalJSONError.invalidContract("CodewordTransformation.codeword") }; guard try ContractFields.array(value).count <= 9 else { throw CanonicalJSONError.invalidContract("CodewordTransformation.codeword") }; for item in try ContractFields.array(value) { guard [0,1].contains(try ContractFields.integer(item)) else { throw CanonicalJSONError.invalidContract("CodewordTransformation.codeword[]") } } }
            self.outputState = try AshState(jsonValue: fields.require("outputState"))
            self.diagnosticReference = try DiagnosticReference(jsonValue: fields.require("diagnosticReference"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("transformationID", .string(transformationID)))
            members.append(JSONMember("inputState", inputState.jsonValue))
            members.append(JSONMember("codeword", .array(codeword.map { value in .number(.integer(String(value))) })))
            members.append(JSONMember("outputState", outputState.jsonValue))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct ContainmentDecision: CanonicalContract {
        public static let contractName = "ContainmentDecision"
        public let containmentDecisionID: String
        public let boundary: JSONValue
        public let allowedOperations: [String ]
        public let restrictedOperations: [String ]
        public let diagnosticReference: DiagnosticReference
        public init(containmentDecisionID: String, boundary: JSONValue, allowedOperations: [String ], restrictedOperations: [String ], diagnosticReference: DiagnosticReference) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("containmentDecisionID", .string(containmentDecisionID)))
            members.append(JSONMember("boundary", boundary))
            members.append(JSONMember("allowedOperations", .array(allowedOperations.map { value in .string(value) })))
            members.append(JSONMember("restrictedOperations", .array(restrictedOperations.map { value in .string(value) })))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["containmentDecisionID", "boundary", "allowedOperations", "restrictedOperations", "diagnosticReference"], required: ["containmentDecisionID", "boundary", "allowedOperations", "restrictedOperations", "diagnosticReference"])
            self.containmentDecisionID = try ContractFields.string(fields.require("containmentDecisionID"))
            self.boundary = try ContractFields.object(fields.require("boundary"))
            self.allowedOperations = try ContractFields.array(fields.require("allowedOperations")).map { value in try ContractFields.string(value) }
            do { let value = try fields.require("allowedOperations"); guard try ContractFields.array(value).count >= 0 else { throw CanonicalJSONError.invalidContract("ContainmentDecision.allowedOperations") } }
            self.restrictedOperations = try ContractFields.array(fields.require("restrictedOperations")).map { value in try ContractFields.string(value) }
            do { let value = try fields.require("restrictedOperations"); guard try ContractFields.array(value).count >= 1 else { throw CanonicalJSONError.invalidContract("ContainmentDecision.restrictedOperations") } }
            self.diagnosticReference = try DiagnosticReference(jsonValue: fields.require("diagnosticReference"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("containmentDecisionID", .string(containmentDecisionID)))
            members.append(JSONMember("boundary", boundary))
            members.append(JSONMember("allowedOperations", .array(allowedOperations.map { value in .string(value) })))
            members.append(JSONMember("restrictedOperations", .array(restrictedOperations.map { value in .string(value) })))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct DesiredState: CanonicalContract {
        public static let contractName = "DesiredState"
        public let desiredStateID: String
        public let desiredSystemIntent: DesiredSystemIntent
        public let evidenceOnly: Bool
        public init(desiredStateID: String, desiredSystemIntent: DesiredSystemIntent, evidenceOnly: Bool) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("desiredStateID", .string(desiredStateID)))
            members.append(JSONMember("desiredSystemIntent", desiredSystemIntent.jsonValue))
            members.append(JSONMember("evidenceOnly", .bool(evidenceOnly)))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["desiredStateID", "desiredSystemIntent", "evidenceOnly"], required: ["desiredStateID", "desiredSystemIntent", "evidenceOnly"])
            self.desiredStateID = try ContractFields.string(fields.require("desiredStateID"))
            self.desiredSystemIntent = try DesiredSystemIntent(jsonValue: fields.require("desiredSystemIntent"))
            self.evidenceOnly = try ContractFields.boolean(fields.require("evidenceOnly"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("desiredStateID", .string(desiredStateID)))
            members.append(JSONMember("desiredSystemIntent", desiredSystemIntent.jsonValue))
            members.append(JSONMember("evidenceOnly", .bool(evidenceOnly)))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct DesiredSystemIntent: CanonicalContract {
        public static let contractName = "DesiredSystemIntent"
        public let desiredSystemIntentID: String
        public let documentReference: JsonDocumentReference
        public let partialIntent: Bool
        public let diagnosticReference: DiagnosticReference
        public init(desiredSystemIntentID: String, documentReference: JsonDocumentReference, partialIntent: Bool, diagnosticReference: DiagnosticReference) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("desiredSystemIntentID", .string(desiredSystemIntentID)))
            members.append(JSONMember("documentReference", documentReference.jsonValue))
            members.append(JSONMember("partialIntent", .bool(partialIntent)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["desiredSystemIntentID", "documentReference", "partialIntent", "diagnosticReference"], required: ["desiredSystemIntentID", "documentReference", "partialIntent", "diagnosticReference"])
            self.desiredSystemIntentID = try ContractFields.string(fields.require("desiredSystemIntentID"))
            self.documentReference = try JsonDocumentReference(jsonValue: fields.require("documentReference"))
            self.partialIntent = try ContractFields.boolean(fields.require("partialIntent"))
            self.diagnosticReference = try DiagnosticReference(jsonValue: fields.require("diagnosticReference"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("desiredSystemIntentID", .string(desiredSystemIntentID)))
            members.append(JSONMember("documentReference", documentReference.jsonValue))
            members.append(JSONMember("partialIntent", .bool(partialIntent)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct DiagnosticChain: CanonicalContract {
        public static let contractName = "DiagnosticChain"
        public let chainID: String
        public let rootDiagnosticID: String
        public let diagnostics: [DiagnosticEnvelope ]
        public init(chainID: String, rootDiagnosticID: String, diagnostics: [DiagnosticEnvelope ]) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("chainID", .string(chainID)))
            members.append(JSONMember("rootDiagnosticID", .string(rootDiagnosticID)))
            members.append(JSONMember("diagnostics", .array(diagnostics.map { value in value.jsonValue })))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["chainID", "rootDiagnosticID", "diagnostics"], required: ["chainID", "rootDiagnosticID", "diagnostics"])
            self.chainID = try ContractFields.string(fields.require("chainID"))
            self.rootDiagnosticID = try ContractFields.string(fields.require("rootDiagnosticID"))
            self.diagnostics = try ContractFields.array(fields.require("diagnostics")).map { value in try DiagnosticEnvelope(jsonValue: value) }
            do { let value = try fields.require("diagnostics"); guard try ContractFields.array(value).count >= 1 else { throw CanonicalJSONError.invalidContract("DiagnosticChain.diagnostics") } }
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("chainID", .string(chainID)))
            members.append(JSONMember("rootDiagnosticID", .string(rootDiagnosticID)))
            members.append(JSONMember("diagnostics", .array(diagnostics.map { value in value.jsonValue })))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct DiagnosticEnvelope: CanonicalContract {
        public static let contractName = "DiagnosticEnvelope"
        public enum DiagnosticKindValue: String, Codable { case STATE_VALIDITY = "STATE_VALIDITY"; case RECOVERY = "RECOVERY"; case POLICY = "POLICY"; case BACKUP = "BACKUP"; case EXECUTION = "EXECUTION"; case VERIFICATION = "VERIFICATION"; case ROLLBACK = "ROLLBACK"; case FALLBACK = "FALLBACK"; case CONTAINMENT = "CONTAINMENT"; case SAFE_HALT = "SAFE_HALT"; case AUDIT = "AUDIT"; case MAPPING = "MAPPING"; case JSON_SEMANTICS = "JSON_SEMANTICS" }
        public enum SeverityValue: String, Codable { case INFO = "INFO"; case WARNING = "WARNING"; case ERROR = "ERROR"; case CRITICAL = "CRITICAL" }
        public let diagnosticID: String
        public let chainRootReference: String
        public let parentDiagnosticID: String?
        public let diagnosticKind: DiagnosticKindValue
        public let severity: SeverityValue
        public let message: String
        public let ruleReferences: [RuleReference ]
        public let sourceReferences: [String ]
        public let evidence: JSONValue
        public init(diagnosticID: String, chainRootReference: String, parentDiagnosticID: String?, diagnosticKind: DiagnosticKindValue, severity: SeverityValue, message: String, ruleReferences: [RuleReference ], sourceReferences: [String ], evidence: JSONValue) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("diagnosticID", .string(diagnosticID)))
            members.append(JSONMember("chainRootReference", .string(chainRootReference)))
            members.append(JSONMember("parentDiagnosticID", parentDiagnosticID.map { .string($0) } ?? .null))
            members.append(JSONMember("diagnosticKind", .string(diagnosticKind.rawValue)))
            members.append(JSONMember("severity", .string(severity.rawValue)))
            members.append(JSONMember("message", .string(message)))
            members.append(JSONMember("ruleReferences", .array(ruleReferences.map { value in value.jsonValue })))
            members.append(JSONMember("sourceReferences", .array(sourceReferences.map { value in .string(value) })))
            members.append(JSONMember("evidence", evidence))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["diagnosticID", "chainRootReference", "parentDiagnosticID", "diagnosticKind", "severity", "message", "ruleReferences", "sourceReferences", "evidence"], required: ["diagnosticID", "chainRootReference", "parentDiagnosticID", "diagnosticKind", "severity", "message", "ruleReferences", "sourceReferences", "evidence"])
            self.diagnosticID = try ContractFields.string(fields.require("diagnosticID"))
            self.chainRootReference = try ContractFields.string(fields.require("chainRootReference"))
            self.parentDiagnosticID = try fields.require("parentDiagnosticID") == .null ? nil : ContractFields.string(fields.require("parentDiagnosticID"))
            self.diagnosticKind = try ContractFields.enumeration(DiagnosticKindValue.self, fields.require("diagnosticKind"))
            self.severity = try ContractFields.enumeration(SeverityValue.self, fields.require("severity"))
            self.message = try ContractFields.string(fields.require("message"))
            self.ruleReferences = try ContractFields.array(fields.require("ruleReferences")).map { value in try RuleReference(jsonValue: value) }
            do { let value = try fields.require("ruleReferences"); guard try ContractFields.array(value).count >= 1 else { throw CanonicalJSONError.invalidContract("DiagnosticEnvelope.ruleReferences") } }
            self.sourceReferences = try ContractFields.array(fields.require("sourceReferences")).map { value in try ContractFields.string(value) }
            do { let value = try fields.require("sourceReferences"); guard try ContractFields.array(value).count >= 1 else { throw CanonicalJSONError.invalidContract("DiagnosticEnvelope.sourceReferences") } }
            self.evidence = try ContractFields.object(fields.require("evidence"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("diagnosticID", .string(diagnosticID)))
            members.append(JSONMember("chainRootReference", .string(chainRootReference)))
            members.append(JSONMember("parentDiagnosticID", parentDiagnosticID.map { .string($0) } ?? .null))
            members.append(JSONMember("diagnosticKind", .string(diagnosticKind.rawValue)))
            members.append(JSONMember("severity", .string(severity.rawValue)))
            members.append(JSONMember("message", .string(message)))
            members.append(JSONMember("ruleReferences", .array(ruleReferences.map { value in value.jsonValue })))
            members.append(JSONMember("sourceReferences", .array(sourceReferences.map { value in .string(value) })))
            members.append(JSONMember("evidence", evidence))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct DiagnosticReference: CanonicalContract {
        public static let contractName = "DiagnosticReference"
        public enum DiagnosticKindValue: String, Codable { case STATE_VALIDITY = "STATE_VALIDITY"; case RECOVERY = "RECOVERY"; case POLICY = "POLICY"; case BACKUP = "BACKUP"; case EXECUTION = "EXECUTION"; case VERIFICATION = "VERIFICATION"; case ROLLBACK = "ROLLBACK"; case FALLBACK = "FALLBACK"; case CONTAINMENT = "CONTAINMENT"; case SAFE_HALT = "SAFE_HALT"; case AUDIT = "AUDIT"; case MAPPING = "MAPPING"; case JSON_SEMANTICS = "JSON_SEMANTICS" }
        public let diagnosticID: String
        public let chainRootReference: String
        public let diagnosticKind: DiagnosticKindValue
        public let ruleReferences: [RuleReference ]
        public init(diagnosticID: String, chainRootReference: String, diagnosticKind: DiagnosticKindValue, ruleReferences: [RuleReference ]) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("diagnosticID", .string(diagnosticID)))
            members.append(JSONMember("chainRootReference", .string(chainRootReference)))
            members.append(JSONMember("diagnosticKind", .string(diagnosticKind.rawValue)))
            members.append(JSONMember("ruleReferences", .array(ruleReferences.map { value in value.jsonValue })))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["diagnosticID", "chainRootReference", "diagnosticKind", "ruleReferences"], required: ["diagnosticID", "chainRootReference", "diagnosticKind", "ruleReferences"])
            self.diagnosticID = try ContractFields.string(fields.require("diagnosticID"))
            self.chainRootReference = try ContractFields.string(fields.require("chainRootReference"))
            self.diagnosticKind = try ContractFields.enumeration(DiagnosticKindValue.self, fields.require("diagnosticKind"))
            self.ruleReferences = try ContractFields.array(fields.require("ruleReferences")).map { value in try RuleReference(jsonValue: value) }
            do { let value = try fields.require("ruleReferences"); guard try ContractFields.array(value).count >= 1 else { throw CanonicalJSONError.invalidContract("DiagnosticReference.ruleReferences") } }
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("diagnosticID", .string(diagnosticID)))
            members.append(JSONMember("chainRootReference", .string(chainRootReference)))
            members.append(JSONMember("diagnosticKind", .string(diagnosticKind.rawValue)))
            members.append(JSONMember("ruleReferences", .array(ruleReferences.map { value in value.jsonValue })))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct DriftEvent: CanonicalContract {
        public static let contractName = "DriftEvent"
        public let driftEventID: String
        public let surfaceDifferences: [SurfaceDifference ]
        public let evidenceOnly: Bool
        public let diagnosticReference: DiagnosticReference
        public init(driftEventID: String, surfaceDifferences: [SurfaceDifference ], evidenceOnly: Bool, diagnosticReference: DiagnosticReference) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("driftEventID", .string(driftEventID)))
            members.append(JSONMember("surfaceDifferences", .array(surfaceDifferences.map { value in value.jsonValue })))
            members.append(JSONMember("evidenceOnly", .bool(evidenceOnly)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["driftEventID", "surfaceDifferences", "evidenceOnly", "diagnosticReference"], required: ["driftEventID", "surfaceDifferences", "evidenceOnly", "diagnosticReference"])
            self.driftEventID = try ContractFields.string(fields.require("driftEventID"))
            self.surfaceDifferences = try ContractFields.array(fields.require("surfaceDifferences")).map { value in try SurfaceDifference(jsonValue: value) }
            do { let value = try fields.require("surfaceDifferences"); guard try ContractFields.array(value).count >= 1 else { throw CanonicalJSONError.invalidContract("DriftEvent.surfaceDifferences") } }
            self.evidenceOnly = try ContractFields.boolean(fields.require("evidenceOnly"))
            self.diagnosticReference = try DiagnosticReference(jsonValue: fields.require("diagnosticReference"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("driftEventID", .string(driftEventID)))
            members.append(JSONMember("surfaceDifferences", .array(surfaceDifferences.map { value in value.jsonValue })))
            members.append(JSONMember("evidenceOnly", .bool(evidenceOnly)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct DryRunResult: CanonicalContract {
        public static let contractName = "DryRunResult"
        public let dryRunResultID: String
        public let wouldMutate: Bool
        public let recoveryPlan: RecoveryPlan
        public let verificationPlan: VerificationPlan
        public let diagnosticChain: DiagnosticChain
        public init(dryRunResultID: String, wouldMutate: Bool, recoveryPlan: RecoveryPlan, verificationPlan: VerificationPlan, diagnosticChain: DiagnosticChain) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("dryRunResultID", .string(dryRunResultID)))
            members.append(JSONMember("wouldMutate", .bool(wouldMutate)))
            members.append(JSONMember("recoveryPlan", recoveryPlan.jsonValue))
            members.append(JSONMember("verificationPlan", verificationPlan.jsonValue))
            members.append(JSONMember("diagnosticChain", diagnosticChain.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["dryRunResultID", "wouldMutate", "recoveryPlan", "verificationPlan", "diagnosticChain"], required: ["dryRunResultID", "wouldMutate", "recoveryPlan", "verificationPlan", "diagnosticChain"])
            self.dryRunResultID = try ContractFields.string(fields.require("dryRunResultID"))
            self.wouldMutate = try ContractFields.boolean(fields.require("wouldMutate"))
            self.recoveryPlan = try RecoveryPlan(jsonValue: fields.require("recoveryPlan"))
            self.verificationPlan = try VerificationPlan(jsonValue: fields.require("verificationPlan"))
            self.diagnosticChain = try DiagnosticChain(jsonValue: fields.require("diagnosticChain"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("dryRunResultID", .string(dryRunResultID)))
            members.append(JSONMember("wouldMutate", .bool(wouldMutate)))
            members.append(JSONMember("recoveryPlan", recoveryPlan.jsonValue))
            members.append(JSONMember("verificationPlan", verificationPlan.jsonValue))
            members.append(JSONMember("diagnosticChain", diagnosticChain.jsonValue))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct EncodedState: CanonicalContract {
        public static let contractName = "EncodedState"
        public let encodedStateID: String
        public let encoding: String
        public let ashState: AshState
        public let evidenceOnly: Bool
        public init(encodedStateID: String, encoding: String, ashState: AshState, evidenceOnly: Bool) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("encodedStateID", .string(encodedStateID)))
            members.append(JSONMember("encoding", .string(encoding)))
            members.append(JSONMember("ashState", ashState.jsonValue))
            members.append(JSONMember("evidenceOnly", .bool(evidenceOnly)))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["encodedStateID", "encoding", "ashState", "evidenceOnly"], required: ["encodedStateID", "encoding", "ashState", "evidenceOnly"])
            self.encodedStateID = try ContractFields.string(fields.require("encodedStateID"))
            self.encoding = try ContractFields.string(fields.require("encoding"))
            self.ashState = try AshState(jsonValue: fields.require("ashState"))
            self.evidenceOnly = try ContractFields.boolean(fields.require("evidenceOnly"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("encodedStateID", .string(encodedStateID)))
            members.append(JSONMember("encoding", .string(encoding)))
            members.append(JSONMember("ashState", ashState.jsonValue))
            members.append(JSONMember("evidenceOnly", .bool(evidenceOnly)))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct EscalationDecision: CanonicalContract {
        public static let contractName = "EscalationDecision"
        public let decisionID: String
        public let fromCategory: RecoveryCategory
        public let toCategory: RecoveryCategory
        public let reason: String
        public let diagnosticReference: DiagnosticReference
        public init(decisionID: String, fromCategory: RecoveryCategory, toCategory: RecoveryCategory, reason: String, diagnosticReference: DiagnosticReference) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("decisionID", .string(decisionID)))
            members.append(JSONMember("fromCategory", fromCategory.jsonValue))
            members.append(JSONMember("toCategory", toCategory.jsonValue))
            members.append(JSONMember("reason", .string(reason)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["decisionID", "fromCategory", "toCategory", "reason", "diagnosticReference"], required: ["decisionID", "fromCategory", "toCategory", "reason", "diagnosticReference"])
            self.decisionID = try ContractFields.string(fields.require("decisionID"))
            self.fromCategory = try RecoveryCategory(jsonValue: fields.require("fromCategory"))
            self.toCategory = try RecoveryCategory(jsonValue: fields.require("toCategory"))
            self.reason = try ContractFields.string(fields.require("reason"))
            self.diagnosticReference = try DiagnosticReference(jsonValue: fields.require("diagnosticReference"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("decisionID", .string(decisionID)))
            members.append(JSONMember("fromCategory", fromCategory.jsonValue))
            members.append(JSONMember("toCategory", toCategory.jsonValue))
            members.append(JSONMember("reason", .string(reason)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct ExecutionContext: CanonicalContract {
        public static let contractName = "ExecutionContext"
        public let executionContextID: String
        public let recoveryPlanID: String
        public let policyDecision: PolicyDecision
        public let backupResult: BackupResult
        public let verificationPlan: VerificationPlan
        public let diagnosticReference: DiagnosticReference
        public init(executionContextID: String, recoveryPlanID: String, policyDecision: PolicyDecision, backupResult: BackupResult, verificationPlan: VerificationPlan, diagnosticReference: DiagnosticReference) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("executionContextID", .string(executionContextID)))
            members.append(JSONMember("recoveryPlanID", .string(recoveryPlanID)))
            members.append(JSONMember("policyDecision", policyDecision.jsonValue))
            members.append(JSONMember("backupResult", backupResult.jsonValue))
            members.append(JSONMember("verificationPlan", verificationPlan.jsonValue))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["executionContextID", "recoveryPlanID", "policyDecision", "backupResult", "verificationPlan", "diagnosticReference"], required: ["executionContextID", "recoveryPlanID", "policyDecision", "backupResult", "verificationPlan", "diagnosticReference"])
            self.executionContextID = try ContractFields.string(fields.require("executionContextID"))
            self.recoveryPlanID = try ContractFields.string(fields.require("recoveryPlanID"))
            self.policyDecision = try PolicyDecision(jsonValue: fields.require("policyDecision"))
            self.backupResult = try BackupResult(jsonValue: fields.require("backupResult"))
            self.verificationPlan = try VerificationPlan(jsonValue: fields.require("verificationPlan"))
            self.diagnosticReference = try DiagnosticReference(jsonValue: fields.require("diagnosticReference"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("executionContextID", .string(executionContextID)))
            members.append(JSONMember("recoveryPlanID", .string(recoveryPlanID)))
            members.append(JSONMember("policyDecision", policyDecision.jsonValue))
            members.append(JSONMember("backupResult", backupResult.jsonValue))
            members.append(JSONMember("verificationPlan", verificationPlan.jsonValue))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct ExecutionStepResult: CanonicalContract {
        public static let contractName = "ExecutionStepResult"
        public enum StatusValue: String, Codable { case SUCCEEDED = "SUCCEEDED"; case FAILED = "FAILED"; case SKIPPED = "SKIPPED"; case BLOCKED = "BLOCKED" }
        public let executionStepResultID: String
        public let stepID: String
        public let status: StatusValue
        public let observedHashAfterStep: String
        public let diagnosticReference: DiagnosticReference
        public init(executionStepResultID: String, stepID: String, status: StatusValue, observedHashAfterStep: String, diagnosticReference: DiagnosticReference) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("executionStepResultID", .string(executionStepResultID)))
            members.append(JSONMember("stepID", .string(stepID)))
            members.append(JSONMember("status", .string(status.rawValue)))
            members.append(JSONMember("observedHashAfterStep", .string(observedHashAfterStep)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["executionStepResultID", "stepID", "status", "observedHashAfterStep", "diagnosticReference"], required: ["executionStepResultID", "stepID", "status", "observedHashAfterStep", "diagnosticReference"])
            self.executionStepResultID = try ContractFields.string(fields.require("executionStepResultID"))
            self.stepID = try ContractFields.string(fields.require("stepID"))
            self.status = try ContractFields.enumeration(StatusValue.self, fields.require("status"))
            self.observedHashAfterStep = try ContractFields.string(fields.require("observedHashAfterStep"))
            self.diagnosticReference = try DiagnosticReference(jsonValue: fields.require("diagnosticReference"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("executionStepResultID", .string(executionStepResultID)))
            members.append(JSONMember("stepID", .string(stepID)))
            members.append(JSONMember("status", .string(status.rawValue)))
            members.append(JSONMember("observedHashAfterStep", .string(observedHashAfterStep)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct FallbackDecision: CanonicalContract {
        public static let contractName = "FallbackDecision"
        public enum StatusValue: String, Codable { case SELECTED = "SELECTED"; case UNAVAILABLE = "UNAVAILABLE"; case BLOCKED = "BLOCKED" }
        public let fallbackDecisionID: String
        public let registryReference: String
        public let selectedCandidateID: String
        public let status: StatusValue
        public let diagnosticReference: DiagnosticReference
        public init(fallbackDecisionID: String, registryReference: String, selectedCandidateID: String, status: StatusValue, diagnosticReference: DiagnosticReference) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("fallbackDecisionID", .string(fallbackDecisionID)))
            members.append(JSONMember("registryReference", .string(registryReference)))
            members.append(JSONMember("selectedCandidateID", .string(selectedCandidateID)))
            members.append(JSONMember("status", .string(status.rawValue)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["fallbackDecisionID", "registryReference", "selectedCandidateID", "status", "diagnosticReference"], required: ["fallbackDecisionID", "registryReference", "selectedCandidateID", "status", "diagnosticReference"])
            self.fallbackDecisionID = try ContractFields.string(fields.require("fallbackDecisionID"))
            self.registryReference = try ContractFields.string(fields.require("registryReference"))
            self.selectedCandidateID = try ContractFields.string(fields.require("selectedCandidateID"))
            self.status = try ContractFields.enumeration(StatusValue.self, fields.require("status"))
            self.diagnosticReference = try DiagnosticReference(jsonValue: fields.require("diagnosticReference"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("fallbackDecisionID", .string(fallbackDecisionID)))
            members.append(JSONMember("registryReference", .string(registryReference)))
            members.append(JSONMember("selectedCandidateID", .string(selectedCandidateID)))
            members.append(JSONMember("status", .string(status.rawValue)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct GenerationPlan: CanonicalContract {
        public static let contractName = "GenerationPlan"
        public let planID: String
        public let planElements: [JSONValue ]
        public let semanticInputs: JSONValue
        public let diagnosticReferences: [DiagnosticReference ]
        public let planHash: String
        public init(planID: String, planElements: [JSONValue ], semanticInputs: JSONValue, diagnosticReferences: [DiagnosticReference ], planHash: String) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("planID", .string(planID)))
            members.append(JSONMember("planElements", .array(planElements.map { value in value })))
            members.append(JSONMember("semanticInputs", semanticInputs))
            members.append(JSONMember("diagnosticReferences", .array(diagnosticReferences.map { value in value.jsonValue })))
            members.append(JSONMember("planHash", .string(planHash)))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["planID", "planElements", "semanticInputs", "diagnosticReferences", "planHash"], required: ["planID", "planElements", "semanticInputs", "diagnosticReferences", "planHash"])
            self.planID = try ContractFields.string(fields.require("planID"))
            self.planElements = try ContractFields.array(fields.require("planElements")).map { value in try ContractFields.object(value) }
            do { let value = try fields.require("planElements"); guard try ContractFields.array(value).count >= 1 else { throw CanonicalJSONError.invalidContract("GenerationPlan.planElements") } }
            self.semanticInputs = try ContractFields.object(fields.require("semanticInputs"))
            self.diagnosticReferences = try ContractFields.array(fields.require("diagnosticReferences")).map { value in try DiagnosticReference(jsonValue: value) }
            do { let value = try fields.require("diagnosticReferences"); guard try ContractFields.array(value).count >= 1 else { throw CanonicalJSONError.invalidContract("GenerationPlan.diagnosticReferences") } }
            self.planHash = try ContractFields.string(fields.require("planHash"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("planID", .string(planID)))
            members.append(JSONMember("planElements", .array(planElements.map { value in value })))
            members.append(JSONMember("semanticInputs", semanticInputs))
            members.append(JSONMember("diagnosticReferences", .array(diagnosticReferences.map { value in value.jsonValue })))
            members.append(JSONMember("planHash", .string(planHash)))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct HealResult: CanonicalContract {
        public static let contractName = "HealResult"
        public enum StatusValue: String, Codable { case NO_ACTION = "NO_ACTION"; case HEALED = "HEALED"; case BLOCKED = "BLOCKED"; case ESCALATED = "ESCALATED"; case SAFE_HALT = "SAFE_HALT" }
        public let healResultID: String
        public let status: StatusValue
        public let recoveryPlan: RecoveryPlan
        public let auditChain: AuditChain
        public let diagnosticChain: DiagnosticChain
        public init(healResultID: String, status: StatusValue, recoveryPlan: RecoveryPlan, auditChain: AuditChain, diagnosticChain: DiagnosticChain) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("healResultID", .string(healResultID)))
            members.append(JSONMember("status", .string(status.rawValue)))
            members.append(JSONMember("recoveryPlan", recoveryPlan.jsonValue))
            members.append(JSONMember("auditChain", auditChain.jsonValue))
            members.append(JSONMember("diagnosticChain", diagnosticChain.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["healResultID", "status", "recoveryPlan", "auditChain", "diagnosticChain"], required: ["healResultID", "status", "recoveryPlan", "auditChain", "diagnosticChain"])
            self.healResultID = try ContractFields.string(fields.require("healResultID"))
            self.status = try ContractFields.enumeration(StatusValue.self, fields.require("status"))
            self.recoveryPlan = try RecoveryPlan(jsonValue: fields.require("recoveryPlan"))
            self.auditChain = try AuditChain(jsonValue: fields.require("auditChain"))
            self.diagnosticChain = try DiagnosticChain(jsonValue: fields.require("diagnosticChain"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("healResultID", .string(healResultID)))
            members.append(JSONMember("status", .string(status.rawValue)))
            members.append(JSONMember("recoveryPlan", recoveryPlan.jsonValue))
            members.append(JSONMember("auditChain", auditChain.jsonValue))
            members.append(JSONMember("diagnosticChain", diagnosticChain.jsonValue))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct Invariant: CanonicalContract {
        public static let contractName = "Invariant"
        public let invariantID: String
        public let conformanceCategory: String
        public let sourceReference: String
        public let diagnosticRule: RuleReference
        public init(invariantID: String, conformanceCategory: String, sourceReference: String, diagnosticRule: RuleReference) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("invariantID", .string(invariantID)))
            members.append(JSONMember("conformanceCategory", .string(conformanceCategory)))
            members.append(JSONMember("sourceReference", .string(sourceReference)))
            members.append(JSONMember("diagnosticRule", diagnosticRule.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["invariantID", "conformanceCategory", "sourceReference", "diagnosticRule"], required: ["invariantID", "conformanceCategory", "sourceReference", "diagnosticRule"])
            self.invariantID = try ContractFields.string(fields.require("invariantID"))
            self.conformanceCategory = try ContractFields.string(fields.require("conformanceCategory"))
            self.sourceReference = try ContractFields.string(fields.require("sourceReference"))
            self.diagnosticRule = try RuleReference(jsonValue: fields.require("diagnosticRule"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("invariantID", .string(invariantID)))
            members.append(JSONMember("conformanceCategory", .string(conformanceCategory)))
            members.append(JSONMember("sourceReference", .string(sourceReference)))
            members.append(JSONMember("diagnosticRule", diagnosticRule.jsonValue))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct JsonCanonicalizationRule: CanonicalContract {
        public static let contractName = "JsonCanonicalizationRule"
        public enum ObjectKeyOrderingValue: String, Codable { case LEXICOGRAPHIC_UTF8 = "LEXICOGRAPHIC_UTF8" }
        public enum ArrayOrderingValue: String, Codable { case PRESERVE_INPUT_ORDER = "PRESERVE_INPUT_ORDER" }
        public enum NumberEncodingValue: String, Codable { case JSON_NUMBER_CANONICAL = "JSON_NUMBER_CANONICAL" }
        public enum HashAlgorithmValue: String, Codable { case SHA_256 = "SHA-256" }
        public let ruleID: String
        public let objectKeyOrdering: ObjectKeyOrderingValue
        public let arrayOrdering: ArrayOrderingValue
        public let numberEncoding: NumberEncodingValue
        public let hashAlgorithm: HashAlgorithmValue
        public init(ruleID: String, objectKeyOrdering: ObjectKeyOrderingValue, arrayOrdering: ArrayOrderingValue, numberEncoding: NumberEncodingValue, hashAlgorithm: HashAlgorithmValue) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("ruleID", .string(ruleID)))
            members.append(JSONMember("objectKeyOrdering", .string(objectKeyOrdering.rawValue)))
            members.append(JSONMember("arrayOrdering", .string(arrayOrdering.rawValue)))
            members.append(JSONMember("numberEncoding", .string(numberEncoding.rawValue)))
            members.append(JSONMember("hashAlgorithm", .string(hashAlgorithm.rawValue)))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["ruleID", "objectKeyOrdering", "arrayOrdering", "numberEncoding", "hashAlgorithm"], required: ["ruleID", "objectKeyOrdering", "arrayOrdering", "numberEncoding", "hashAlgorithm"])
            self.ruleID = try ContractFields.string(fields.require("ruleID"))
            self.objectKeyOrdering = try ContractFields.enumeration(ObjectKeyOrderingValue.self, fields.require("objectKeyOrdering"))
            self.arrayOrdering = try ContractFields.enumeration(ArrayOrderingValue.self, fields.require("arrayOrdering"))
            self.numberEncoding = try ContractFields.enumeration(NumberEncodingValue.self, fields.require("numberEncoding"))
            self.hashAlgorithm = try ContractFields.enumeration(HashAlgorithmValue.self, fields.require("hashAlgorithm"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("ruleID", .string(ruleID)))
            members.append(JSONMember("objectKeyOrdering", .string(objectKeyOrdering.rawValue)))
            members.append(JSONMember("arrayOrdering", .string(arrayOrdering.rawValue)))
            members.append(JSONMember("numberEncoding", .string(numberEncoding.rawValue)))
            members.append(JSONMember("hashAlgorithm", .string(hashAlgorithm.rawValue)))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct JsonDocumentReference: CanonicalContract {
        public static let contractName = "JsonDocumentReference"
        public enum RoleValue: String, Codable { case OBSERVED = "OBSERVED"; case DESIRED = "DESIRED"; case CANONICALIZED = "CANONICALIZED"; case BACKUP = "BACKUP" }
        public let documentID: String
        public let role: RoleValue
        public let canonicalHash: String
        public let sourceReference: String
        public init(documentID: String, role: RoleValue, canonicalHash: String, sourceReference: String) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("documentID", .string(documentID)))
            members.append(JSONMember("role", .string(role.rawValue)))
            members.append(JSONMember("canonicalHash", .string(canonicalHash)))
            members.append(JSONMember("sourceReference", .string(sourceReference)))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["documentID", "role", "canonicalHash", "sourceReference"], required: ["documentID", "role", "canonicalHash", "sourceReference"])
            self.documentID = try ContractFields.string(fields.require("documentID"))
            self.role = try ContractFields.enumeration(RoleValue.self, fields.require("role"))
            self.canonicalHash = try ContractFields.string(fields.require("canonicalHash"))
            self.sourceReference = try ContractFields.string(fields.require("sourceReference"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("documentID", .string(documentID)))
            members.append(JSONMember("role", .string(role.rawValue)))
            members.append(JSONMember("canonicalHash", .string(canonicalHash)))
            members.append(JSONMember("sourceReference", .string(sourceReference)))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct JsonMutationOperation: CanonicalContract {
        public static let contractName = "JsonMutationOperation"
        public enum OpValue: String, Codable { case test = "test"; case add = "add"; case replace = "replace"; case remove = "remove" }
        public let operationID: String
        public let op: OpValue
        public let path: JsonPointer
        public let value: JSONValue?
        public let preconditionHash: String
        public let diagnosticReference: DiagnosticReference
        public init(operationID: String, op: OpValue, path: JsonPointer, value: JSONValue? = nil, preconditionHash: String, diagnosticReference: DiagnosticReference) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("operationID", .string(operationID)))
            members.append(JSONMember("op", .string(op.rawValue)))
            members.append(JSONMember("path", path.jsonValue))
            if let value = value { members.append(JSONMember("value", value)) }
            members.append(JSONMember("preconditionHash", .string(preconditionHash)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["operationID", "op", "path", "value", "preconditionHash", "diagnosticReference"], required: ["operationID", "op", "path", "preconditionHash", "diagnosticReference"])
            self.operationID = try ContractFields.string(fields.require("operationID"))
            self.op = try ContractFields.enumeration(OpValue.self, fields.require("op"))
            self.path = try JsonPointer(jsonValue: fields.require("path"))
            self.value = fields.optional("value")
            self.preconditionHash = try ContractFields.string(fields.require("preconditionHash"))
            self.diagnosticReference = try DiagnosticReference(jsonValue: fields.require("diagnosticReference"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("operationID", .string(operationID)))
            members.append(JSONMember("op", .string(op.rawValue)))
            members.append(JSONMember("path", path.jsonValue))
            if let value = value { members.append(JSONMember("value", value)) }
            members.append(JSONMember("preconditionHash", .string(preconditionHash)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct JsonPointer: CanonicalContract {
        public static let contractName = "JsonPointer"
        public let pointer: String
        public let tokens: [String ]
        public let pointsToMissing: Bool
        public let pointsToNull: Bool
        public init(pointer: String, tokens: [String ], pointsToMissing: Bool, pointsToNull: Bool) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("pointer", .string(pointer)))
            members.append(JSONMember("tokens", .array(tokens.map { value in .string(value) })))
            members.append(JSONMember("pointsToMissing", .bool(pointsToMissing)))
            members.append(JSONMember("pointsToNull", .bool(pointsToNull)))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["pointer", "tokens", "pointsToMissing", "pointsToNull"], required: ["pointer", "tokens", "pointsToMissing", "pointsToNull"])
            self.pointer = try ContractFields.string(fields.require("pointer"))
            do { let value = try fields.require("pointer"); guard try ContractFields.string(value).range(of: "^($|/.*)", options: .regularExpression) != nil else { throw CanonicalJSONError.invalidContract("JsonPointer.pointer") } }
            self.tokens = try ContractFields.array(fields.require("tokens")).map { value in try ContractFields.string(value) }
            do { let value = try fields.require("tokens"); guard try ContractFields.array(value).count >= 0 else { throw CanonicalJSONError.invalidContract("JsonPointer.tokens") } }
            self.pointsToMissing = try ContractFields.boolean(fields.require("pointsToMissing"))
            self.pointsToNull = try ContractFields.boolean(fields.require("pointsToNull"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("pointer", .string(pointer)))
            members.append(JSONMember("tokens", .array(tokens.map { value in .string(value) })))
            members.append(JSONMember("pointsToMissing", .bool(pointsToMissing)))
            members.append(JSONMember("pointsToNull", .bool(pointsToNull)))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct MappingAmbiguity: CanonicalContract {
        public static let contractName = "MappingAmbiguity"
        public enum DimensionIDValue: String, Codable { case b0 = "b0"; case b1 = "b1"; case b2 = "b2"; case b3 = "b3"; case b4 = "b4"; case b5 = "b5"; case b6 = "b6"; case b7 = "b7"; case b8 = "b8" }
        public let ambiguityID: String
        public let dimensionID: DimensionIDValue
        public let candidateValues: [Int ]
        public let evidence: [JSONValue ]
        public let blockingRule: RuleReference
        public let diagnosticReference: DiagnosticReference
        public init(ambiguityID: String, dimensionID: DimensionIDValue, candidateValues: [Int ], evidence: [JSONValue ], blockingRule: RuleReference, diagnosticReference: DiagnosticReference) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("ambiguityID", .string(ambiguityID)))
            members.append(JSONMember("dimensionID", .string(dimensionID.rawValue)))
            members.append(JSONMember("candidateValues", .array(candidateValues.map { value in .number(.integer(String(value))) })))
            members.append(JSONMember("evidence", .array(evidence.map { value in value })))
            members.append(JSONMember("blockingRule", blockingRule.jsonValue))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["ambiguityID", "dimensionID", "candidateValues", "evidence", "blockingRule", "diagnosticReference"], required: ["ambiguityID", "dimensionID", "candidateValues", "evidence", "blockingRule", "diagnosticReference"])
            self.ambiguityID = try ContractFields.string(fields.require("ambiguityID"))
            self.dimensionID = try ContractFields.enumeration(DimensionIDValue.self, fields.require("dimensionID"))
            self.candidateValues = try ContractFields.array(fields.require("candidateValues")).map { value in try ContractFields.integer(value) }
            do { let value = try fields.require("candidateValues"); guard try ContractFields.array(value).count >= 2 else { throw CanonicalJSONError.invalidContract("MappingAmbiguity.candidateValues") }; for item in try ContractFields.array(value) { guard [0,1].contains(try ContractFields.integer(item)) else { throw CanonicalJSONError.invalidContract("MappingAmbiguity.candidateValues[]") } } }
            self.evidence = try ContractFields.array(fields.require("evidence")).map { value in try ContractFields.object(value) }
            do { let value = try fields.require("evidence"); guard try ContractFields.array(value).count >= 1 else { throw CanonicalJSONError.invalidContract("MappingAmbiguity.evidence") } }
            self.blockingRule = try RuleReference(jsonValue: fields.require("blockingRule"))
            self.diagnosticReference = try DiagnosticReference(jsonValue: fields.require("diagnosticReference"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("ambiguityID", .string(ambiguityID)))
            members.append(JSONMember("dimensionID", .string(dimensionID.rawValue)))
            members.append(JSONMember("candidateValues", .array(candidateValues.map { value in .number(.integer(String(value))) })))
            members.append(JSONMember("evidence", .array(evidence.map { value in value })))
            members.append(JSONMember("blockingRule", blockingRule.jsonValue))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct MappingResult: CanonicalContract {
        public static let contractName = "MappingResult"
        public enum StatusValue: String, Codable { case MAPPED = "MAPPED"; case AMBIGUOUS = "AMBIGUOUS"; case BLOCKED = "BLOCKED"; case FAILED = "FAILED" }
        public let mappingResultID: String
        public let status: StatusValue
        public let projectedState: AshState
        public let dimensionBindings: [SemanticDimensionBinding ]
        public let ambiguities: [MappingAmbiguity ]
        public let diagnosticReferences: [DiagnosticReference ]
        public init(mappingResultID: String, status: StatusValue, projectedState: AshState, dimensionBindings: [SemanticDimensionBinding ], ambiguities: [MappingAmbiguity ], diagnosticReferences: [DiagnosticReference ]) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("mappingResultID", .string(mappingResultID)))
            members.append(JSONMember("status", .string(status.rawValue)))
            members.append(JSONMember("projectedState", projectedState.jsonValue))
            members.append(JSONMember("dimensionBindings", .array(dimensionBindings.map { value in value.jsonValue })))
            members.append(JSONMember("ambiguities", .array(ambiguities.map { value in value.jsonValue })))
            members.append(JSONMember("diagnosticReferences", .array(diagnosticReferences.map { value in value.jsonValue })))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["mappingResultID", "status", "projectedState", "dimensionBindings", "ambiguities", "diagnosticReferences"], required: ["mappingResultID", "status", "projectedState", "dimensionBindings", "ambiguities", "diagnosticReferences"])
            self.mappingResultID = try ContractFields.string(fields.require("mappingResultID"))
            self.status = try ContractFields.enumeration(StatusValue.self, fields.require("status"))
            self.projectedState = try AshState(jsonValue: fields.require("projectedState"))
            self.dimensionBindings = try ContractFields.array(fields.require("dimensionBindings")).map { value in try SemanticDimensionBinding(jsonValue: value) }
            do { let value = try fields.require("dimensionBindings"); guard try ContractFields.array(value).count >= 9 else { throw CanonicalJSONError.invalidContract("MappingResult.dimensionBindings") }; guard try ContractFields.array(value).count <= 9 else { throw CanonicalJSONError.invalidContract("MappingResult.dimensionBindings") } }
            self.ambiguities = try ContractFields.array(fields.require("ambiguities")).map { value in try MappingAmbiguity(jsonValue: value) }
            do { let value = try fields.require("ambiguities"); guard try ContractFields.array(value).count >= 0 else { throw CanonicalJSONError.invalidContract("MappingResult.ambiguities") } }
            self.diagnosticReferences = try ContractFields.array(fields.require("diagnosticReferences")).map { value in try DiagnosticReference(jsonValue: value) }
            do { let value = try fields.require("diagnosticReferences"); guard try ContractFields.array(value).count >= 1 else { throw CanonicalJSONError.invalidContract("MappingResult.diagnosticReferences") } }
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("mappingResultID", .string(mappingResultID)))
            members.append(JSONMember("status", .string(status.rawValue)))
            members.append(JSONMember("projectedState", projectedState.jsonValue))
            members.append(JSONMember("dimensionBindings", .array(dimensionBindings.map { value in value.jsonValue })))
            members.append(JSONMember("ambiguities", .array(ambiguities.map { value in value.jsonValue })))
            members.append(JSONMember("diagnosticReferences", .array(diagnosticReferences.map { value in value.jsonValue })))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct ModuleManifest: CanonicalContract {
        public static let contractName = "ModuleManifest"
        public let moduleManifestID: String
        public let aeostaraVersion: String
        public let modules: [JSONValue ]
        public let diagnosticReference: DiagnosticReference
        public init(moduleManifestID: String, aeostaraVersion: String, modules: [JSONValue ], diagnosticReference: DiagnosticReference) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("moduleManifestID", .string(moduleManifestID)))
            members.append(JSONMember("aeostaraVersion", .string(aeostaraVersion)))
            members.append(JSONMember("modules", .array(modules.map { value in value })))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["moduleManifestID", "aeostaraVersion", "modules", "diagnosticReference"], required: ["moduleManifestID", "aeostaraVersion", "modules", "diagnosticReference"])
            self.moduleManifestID = try ContractFields.string(fields.require("moduleManifestID"))
            self.aeostaraVersion = try ContractFields.string(fields.require("aeostaraVersion"))
            self.modules = try ContractFields.array(fields.require("modules")).map { value in try ContractFields.object(value) }
            do { let value = try fields.require("modules"); guard try ContractFields.array(value).count >= 1 else { throw CanonicalJSONError.invalidContract("ModuleManifest.modules") } }
            self.diagnosticReference = try DiagnosticReference(jsonValue: fields.require("diagnosticReference"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("moduleManifestID", .string(moduleManifestID)))
            members.append(JSONMember("aeostaraVersion", .string(aeostaraVersion)))
            members.append(JSONMember("modules", .array(modules.map { value in value })))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct ObservedState: CanonicalContract {
        public static let contractName = "ObservedState"
        public let observedStateID: String
        public let observedSystemState: ObservedSystemState
        public let evidenceOnly: Bool
        public init(observedStateID: String, observedSystemState: ObservedSystemState, evidenceOnly: Bool) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("observedStateID", .string(observedStateID)))
            members.append(JSONMember("observedSystemState", observedSystemState.jsonValue))
            members.append(JSONMember("evidenceOnly", .bool(evidenceOnly)))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["observedStateID", "observedSystemState", "evidenceOnly"], required: ["observedStateID", "observedSystemState", "evidenceOnly"])
            self.observedStateID = try ContractFields.string(fields.require("observedStateID"))
            self.observedSystemState = try ObservedSystemState(jsonValue: fields.require("observedSystemState"))
            self.evidenceOnly = try ContractFields.boolean(fields.require("evidenceOnly"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("observedStateID", .string(observedStateID)))
            members.append(JSONMember("observedSystemState", observedSystemState.jsonValue))
            members.append(JSONMember("evidenceOnly", .bool(evidenceOnly)))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct ObservedSystemState: CanonicalContract {
        public static let contractName = "ObservedSystemState"
        public let observedSystemStateID: String
        public let documentReference: JsonDocumentReference
        public let surfaceDifferences: [SurfaceDifference ]
        public let diagnosticReference: DiagnosticReference
        public init(observedSystemStateID: String, documentReference: JsonDocumentReference, surfaceDifferences: [SurfaceDifference ], diagnosticReference: DiagnosticReference) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("observedSystemStateID", .string(observedSystemStateID)))
            members.append(JSONMember("documentReference", documentReference.jsonValue))
            members.append(JSONMember("surfaceDifferences", .array(surfaceDifferences.map { value in value.jsonValue })))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["observedSystemStateID", "documentReference", "surfaceDifferences", "diagnosticReference"], required: ["observedSystemStateID", "documentReference", "surfaceDifferences", "diagnosticReference"])
            self.observedSystemStateID = try ContractFields.string(fields.require("observedSystemStateID"))
            self.documentReference = try JsonDocumentReference(jsonValue: fields.require("documentReference"))
            self.surfaceDifferences = try ContractFields.array(fields.require("surfaceDifferences")).map { value in try SurfaceDifference(jsonValue: value) }
            do { let value = try fields.require("surfaceDifferences"); guard try ContractFields.array(value).count >= 0 else { throw CanonicalJSONError.invalidContract("ObservedSystemState.surfaceDifferences") } }
            self.diagnosticReference = try DiagnosticReference(jsonValue: fields.require("diagnosticReference"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("observedSystemStateID", .string(observedSystemStateID)))
            members.append(JSONMember("documentReference", documentReference.jsonValue))
            members.append(JSONMember("surfaceDifferences", .array(surfaceDifferences.map { value in value.jsonValue })))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct PolicyBundle: CanonicalContract {
        public static let contractName = "PolicyBundle"
        public let policyBundleID: String
        public let sourceReferences: [String ]
        public let rules: [JSONValue ]
        public let bundleHash: String
        public init(policyBundleID: String, sourceReferences: [String ], rules: [JSONValue ], bundleHash: String) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("policyBundleID", .string(policyBundleID)))
            members.append(JSONMember("sourceReferences", .array(sourceReferences.map { value in .string(value) })))
            members.append(JSONMember("rules", .array(rules.map { value in value })))
            members.append(JSONMember("bundleHash", .string(bundleHash)))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["policyBundleID", "sourceReferences", "rules", "bundleHash"], required: ["policyBundleID", "sourceReferences", "rules", "bundleHash"])
            self.policyBundleID = try ContractFields.string(fields.require("policyBundleID"))
            self.sourceReferences = try ContractFields.array(fields.require("sourceReferences")).map { value in try ContractFields.string(value) }
            do { let value = try fields.require("sourceReferences"); guard try ContractFields.array(value).count >= 1 else { throw CanonicalJSONError.invalidContract("PolicyBundle.sourceReferences") } }
            self.rules = try ContractFields.array(fields.require("rules")).map { value in try ContractFields.object(value) }
            do { let value = try fields.require("rules"); guard try ContractFields.array(value).count >= 1 else { throw CanonicalJSONError.invalidContract("PolicyBundle.rules") } }
            self.bundleHash = try ContractFields.string(fields.require("bundleHash"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("policyBundleID", .string(policyBundleID)))
            members.append(JSONMember("sourceReferences", .array(sourceReferences.map { value in .string(value) })))
            members.append(JSONMember("rules", .array(rules.map { value in value })))
            members.append(JSONMember("bundleHash", .string(bundleHash)))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct PolicyDecision: CanonicalContract {
        public static let contractName = "PolicyDecision"
        public enum DecisionValue: String, Codable { case ALLOW = "ALLOW"; case BLOCK = "BLOCK"; case ESCALATE = "ESCALATE" }
        public let policyDecisionID: String
        public let decision: DecisionValue
        public let policyBundleID: String
        public let reasons: [String ]
        public let diagnosticReference: DiagnosticReference
        public init(policyDecisionID: String, decision: DecisionValue, policyBundleID: String, reasons: [String ], diagnosticReference: DiagnosticReference) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("policyDecisionID", .string(policyDecisionID)))
            members.append(JSONMember("decision", .string(decision.rawValue)))
            members.append(JSONMember("policyBundleID", .string(policyBundleID)))
            members.append(JSONMember("reasons", .array(reasons.map { value in .string(value) })))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["policyDecisionID", "decision", "policyBundleID", "reasons", "diagnosticReference"], required: ["policyDecisionID", "decision", "policyBundleID", "reasons", "diagnosticReference"])
            self.policyDecisionID = try ContractFields.string(fields.require("policyDecisionID"))
            self.decision = try ContractFields.enumeration(DecisionValue.self, fields.require("decision"))
            self.policyBundleID = try ContractFields.string(fields.require("policyBundleID"))
            self.reasons = try ContractFields.array(fields.require("reasons")).map { value in try ContractFields.string(value) }
            do { let value = try fields.require("reasons"); guard try ContractFields.array(value).count >= 1 else { throw CanonicalJSONError.invalidContract("PolicyDecision.reasons") } }
            self.diagnosticReference = try DiagnosticReference(jsonValue: fields.require("diagnosticReference"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("policyDecisionID", .string(policyDecisionID)))
            members.append(JSONMember("decision", .string(decision.rawValue)))
            members.append(JSONMember("policyBundleID", .string(policyBundleID)))
            members.append(JSONMember("reasons", .array(reasons.map { value in .string(value) })))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct RealmIdentity: CanonicalContract {
        public static let contractName = "RealmIdentity"
        public let realmID: String
        public let stateReference: String
        public let encoding: String
        public let diagnosticReference: DiagnosticReference
        public init(realmID: String, stateReference: String, encoding: String, diagnosticReference: DiagnosticReference) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("realmID", .string(realmID)))
            members.append(JSONMember("stateReference", .string(stateReference)))
            members.append(JSONMember("encoding", .string(encoding)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["realmID", "stateReference", "encoding", "diagnosticReference"], required: ["realmID", "stateReference", "encoding", "diagnosticReference"])
            self.realmID = try ContractFields.string(fields.require("realmID"))
            self.stateReference = try ContractFields.string(fields.require("stateReference"))
            self.encoding = try ContractFields.string(fields.require("encoding"))
            self.diagnosticReference = try DiagnosticReference(jsonValue: fields.require("diagnosticReference"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("realmID", .string(realmID)))
            members.append(JSONMember("stateReference", .string(stateReference)))
            members.append(JSONMember("encoding", .string(encoding)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    enum RecoveryCategory: String, CanonicalContract {
        public static let contractName = "RecoveryCategory"
        case NO_ACTION = "NO_ACTION"
        case NORMALIZE_STATE = "NORMALIZE_STATE"
        case APPLY_CORRECTION = "APPLY_CORRECTION"
        case FALLBACK_REQUIRED = "FALLBACK_REQUIRED"
        case CONTAINMENT_REQUIRED = "CONTAINMENT_REQUIRED"
        case ESCALATION_REQUIRED = "ESCALATION_REQUIRED"
        case TERMINAL_NO_RECOVERY = "TERMINAL_NO_RECOVERY"
        public init(jsonValue: JSONValue) throws { self = try ContractFields.enumeration(Self.self, jsonValue) }
        public var jsonValue: JSONValue { .string(rawValue) }
    }
}

public extension AeostaraContract {
    struct RecoveryOutcome: CanonicalContract {
        public static let contractName = "RecoveryOutcome"
        public enum StatusValue: String, Codable { case SUCCEEDED = "SUCCEEDED"; case BLOCKED = "BLOCKED"; case FAILED = "FAILED"; case ESCALATED = "ESCALATED"; case NO_ACTION = "NO_ACTION" }
        public let outcomeID: String
        public let status: StatusValue
        public let recoveryCategory: RecoveryCategory
        public let escalationDecision: EscalationDecision?
        public let diagnosticReference: DiagnosticReference
        public init(outcomeID: String, status: StatusValue, recoveryCategory: RecoveryCategory, escalationDecision: EscalationDecision? = nil, diagnosticReference: DiagnosticReference) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("outcomeID", .string(outcomeID)))
            members.append(JSONMember("status", .string(status.rawValue)))
            members.append(JSONMember("recoveryCategory", recoveryCategory.jsonValue))
            if let value = escalationDecision { members.append(JSONMember("escalationDecision", value.jsonValue)) }
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["outcomeID", "status", "recoveryCategory", "escalationDecision", "diagnosticReference"], required: ["outcomeID", "status", "recoveryCategory", "diagnosticReference"])
            self.outcomeID = try ContractFields.string(fields.require("outcomeID"))
            self.status = try ContractFields.enumeration(StatusValue.self, fields.require("status"))
            self.recoveryCategory = try RecoveryCategory(jsonValue: fields.require("recoveryCategory"))
            self.escalationDecision = try fields.optional("escalationDecision").map { value in try EscalationDecision(jsonValue: value) }
            self.diagnosticReference = try DiagnosticReference(jsonValue: fields.require("diagnosticReference"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("outcomeID", .string(outcomeID)))
            members.append(JSONMember("status", .string(status.rawValue)))
            members.append(JSONMember("recoveryCategory", recoveryCategory.jsonValue))
            if let value = escalationDecision { members.append(JSONMember("escalationDecision", value.jsonValue)) }
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct RecoveryPlan: CanonicalContract {
        public static let contractName = "RecoveryPlan"
        public enum PlanDispositionValue: String, Codable { case NO_ACTION = "NO_ACTION"; case MUTATION_REQUIRED = "MUTATION_REQUIRED"; case ESCALATION_REQUIRED = "ESCALATION_REQUIRED"; case TERMINAL = "TERMINAL" }
        public let recoveryPlanID: String
        public let planDisposition: PlanDispositionValue
        public let diagnosticReference: DiagnosticReference
        public let stateClass: SystemStateClass
        public let recoveryCategory: RecoveryCategory
        public let requiresPolicyGate: Bool
        public let requiresBackup: Bool
        public let recoverySteps: [RecoveryStep ]
        public let planHash: String
        public let createdAt: String
        public init(recoveryPlanID: String, planDisposition: PlanDispositionValue, diagnosticReference: DiagnosticReference, stateClass: SystemStateClass, recoveryCategory: RecoveryCategory, requiresPolicyGate: Bool, requiresBackup: Bool, recoverySteps: [RecoveryStep ], planHash: String, createdAt: String) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("recoveryPlanID", .string(recoveryPlanID)))
            members.append(JSONMember("planDisposition", .string(planDisposition.rawValue)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            members.append(JSONMember("stateClass", stateClass.jsonValue))
            members.append(JSONMember("recoveryCategory", recoveryCategory.jsonValue))
            members.append(JSONMember("requiresPolicyGate", .bool(requiresPolicyGate)))
            members.append(JSONMember("requiresBackup", .bool(requiresBackup)))
            members.append(JSONMember("recoverySteps", .array(recoverySteps.map { value in value.jsonValue })))
            members.append(JSONMember("planHash", .string(planHash)))
            members.append(JSONMember("createdAt", .string(createdAt)))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["recoveryPlanID", "planDisposition", "diagnosticReference", "stateClass", "recoveryCategory", "requiresPolicyGate", "requiresBackup", "recoverySteps", "planHash", "createdAt"], required: ["recoveryPlanID", "planDisposition", "diagnosticReference", "stateClass", "recoveryCategory", "requiresPolicyGate", "requiresBackup", "recoverySteps", "planHash", "createdAt"])
            self.recoveryPlanID = try ContractFields.string(fields.require("recoveryPlanID"))
            self.planDisposition = try ContractFields.enumeration(PlanDispositionValue.self, fields.require("planDisposition"))
            self.diagnosticReference = try DiagnosticReference(jsonValue: fields.require("diagnosticReference"))
            self.stateClass = try SystemStateClass(jsonValue: fields.require("stateClass"))
            self.recoveryCategory = try RecoveryCategory(jsonValue: fields.require("recoveryCategory"))
            self.requiresPolicyGate = try ContractFields.boolean(fields.require("requiresPolicyGate"))
            self.requiresBackup = try ContractFields.boolean(fields.require("requiresBackup"))
            self.recoverySteps = try ContractFields.array(fields.require("recoverySteps")).map { value in try RecoveryStep(jsonValue: value) }
            do { let value = try fields.require("recoverySteps"); guard try ContractFields.array(value).count >= 0 else { throw CanonicalJSONError.invalidContract("RecoveryPlan.recoverySteps") } }
            self.planHash = try ContractFields.string(fields.require("planHash"))
            self.createdAt = try ContractFields.string(fields.require("createdAt"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("recoveryPlanID", .string(recoveryPlanID)))
            members.append(JSONMember("planDisposition", .string(planDisposition.rawValue)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            members.append(JSONMember("stateClass", stateClass.jsonValue))
            members.append(JSONMember("recoveryCategory", recoveryCategory.jsonValue))
            members.append(JSONMember("requiresPolicyGate", .bool(requiresPolicyGate)))
            members.append(JSONMember("requiresBackup", .bool(requiresBackup)))
            members.append(JSONMember("recoverySteps", .array(recoverySteps.map { value in value.jsonValue })))
            members.append(JSONMember("planHash", .string(planHash)))
            members.append(JSONMember("createdAt", .string(createdAt)))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct RecoveryStep: CanonicalContract {
        public static let contractName = "RecoveryStep"
        public enum StepTypeValue: String, Codable { case NORMALIZE_STATE = "NORMALIZE_STATE"; case APPLY_CORRECTION = "APPLY_CORRECTION"; case SELECT_FALLBACK = "SELECT_FALLBACK"; case ENTER_CONTAINMENT = "ENTER_CONTAINMENT"; case ENTER_SAFE_HALT = "ENTER_SAFE_HALT"; case ROLLBACK = "ROLLBACK"; case VERIFY = "VERIFY"; case ESCALATE = "ESCALATE" }
        public let stepID: String
        public let stepType: StepTypeValue
        public let description: String
        public let jsonMutationOperations: [JsonMutationOperation ]
        public let diagnosticReference: DiagnosticReference
        public init(stepID: String, stepType: StepTypeValue, description: String, jsonMutationOperations: [JsonMutationOperation ], diagnosticReference: DiagnosticReference) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("stepID", .string(stepID)))
            members.append(JSONMember("stepType", .string(stepType.rawValue)))
            members.append(JSONMember("description", .string(description)))
            members.append(JSONMember("jsonMutationOperations", .array(jsonMutationOperations.map { value in value.jsonValue })))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["stepID", "stepType", "description", "jsonMutationOperations", "diagnosticReference"], required: ["stepID", "stepType", "description", "jsonMutationOperations", "diagnosticReference"])
            self.stepID = try ContractFields.string(fields.require("stepID"))
            self.stepType = try ContractFields.enumeration(StepTypeValue.self, fields.require("stepType"))
            self.description = try ContractFields.string(fields.require("description"))
            self.jsonMutationOperations = try ContractFields.array(fields.require("jsonMutationOperations")).map { value in try JsonMutationOperation(jsonValue: value) }
            do { let value = try fields.require("jsonMutationOperations"); guard try ContractFields.array(value).count >= 0 else { throw CanonicalJSONError.invalidContract("RecoveryStep.jsonMutationOperations") } }
            self.diagnosticReference = try DiagnosticReference(jsonValue: fields.require("diagnosticReference"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("stepID", .string(stepID)))
            members.append(JSONMember("stepType", .string(stepType.rawValue)))
            members.append(JSONMember("description", .string(description)))
            members.append(JSONMember("jsonMutationOperations", .array(jsonMutationOperations.map { value in value.jsonValue })))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct RepairAction: CanonicalContract {
        public static let contractName = "RepairAction"
        public let repairActionID: String
        public let recoveryStep: RecoveryStep
        public let actuatorParameters: JSONValue
        public init(repairActionID: String, recoveryStep: RecoveryStep, actuatorParameters: JSONValue) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("repairActionID", .string(repairActionID)))
            members.append(JSONMember("recoveryStep", recoveryStep.jsonValue))
            members.append(JSONMember("actuatorParameters", actuatorParameters))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["repairActionID", "recoveryStep", "actuatorParameters"], required: ["repairActionID", "recoveryStep", "actuatorParameters"])
            self.repairActionID = try ContractFields.string(fields.require("repairActionID"))
            self.recoveryStep = try RecoveryStep(jsonValue: fields.require("recoveryStep"))
            self.actuatorParameters = try ContractFields.object(fields.require("actuatorParameters"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("repairActionID", .string(repairActionID)))
            members.append(JSONMember("recoveryStep", recoveryStep.jsonValue))
            members.append(JSONMember("actuatorParameters", actuatorParameters))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct RepairPlan: CanonicalContract {
        public static let contractName = "RepairPlan"
        public let repairPlanID: String
        public let recoveryPlan: RecoveryPlan
        public let repairActions: [RepairAction ]
        public init(repairPlanID: String, recoveryPlan: RecoveryPlan, repairActions: [RepairAction ]) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("repairPlanID", .string(repairPlanID)))
            members.append(JSONMember("recoveryPlan", recoveryPlan.jsonValue))
            members.append(JSONMember("repairActions", .array(repairActions.map { value in value.jsonValue })))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["repairPlanID", "recoveryPlan", "repairActions"], required: ["repairPlanID", "recoveryPlan", "repairActions"])
            self.repairPlanID = try ContractFields.string(fields.require("repairPlanID"))
            self.recoveryPlan = try RecoveryPlan(jsonValue: fields.require("recoveryPlan"))
            self.repairActions = try ContractFields.array(fields.require("repairActions")).map { value in try RepairAction(jsonValue: value) }
            do { let value = try fields.require("repairActions"); guard try ContractFields.array(value).count >= 0 else { throw CanonicalJSONError.invalidContract("RepairPlan.repairActions") } }
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("repairPlanID", .string(repairPlanID)))
            members.append(JSONMember("recoveryPlan", recoveryPlan.jsonValue))
            members.append(JSONMember("repairActions", .array(repairActions.map { value in value.jsonValue })))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct RollbackPlan: CanonicalContract {
        public static let contractName = "RollbackPlan"
        public let rollbackPlanID: String
        public let backupRecordID: String
        public let triggerVerificationResultID: String
        public let diagnosticReference: DiagnosticReference
        public init(rollbackPlanID: String, backupRecordID: String, triggerVerificationResultID: String, diagnosticReference: DiagnosticReference) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("rollbackPlanID", .string(rollbackPlanID)))
            members.append(JSONMember("backupRecordID", .string(backupRecordID)))
            members.append(JSONMember("triggerVerificationResultID", .string(triggerVerificationResultID)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["rollbackPlanID", "backupRecordID", "triggerVerificationResultID", "diagnosticReference"], required: ["rollbackPlanID", "backupRecordID", "triggerVerificationResultID", "diagnosticReference"])
            self.rollbackPlanID = try ContractFields.string(fields.require("rollbackPlanID"))
            self.backupRecordID = try ContractFields.string(fields.require("backupRecordID"))
            self.triggerVerificationResultID = try ContractFields.string(fields.require("triggerVerificationResultID"))
            self.diagnosticReference = try DiagnosticReference(jsonValue: fields.require("diagnosticReference"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("rollbackPlanID", .string(rollbackPlanID)))
            members.append(JSONMember("backupRecordID", .string(backupRecordID)))
            members.append(JSONMember("triggerVerificationResultID", .string(triggerVerificationResultID)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct RollbackResult: CanonicalContract {
        public static let contractName = "RollbackResult"
        public enum StatusValue: String, Codable { case SUCCEEDED = "SUCCEEDED"; case FAILED = "FAILED"; case NOT_REQUIRED = "NOT_REQUIRED" }
        public let rollbackResultID: String
        public let status: StatusValue
        public let backupRecordID: String
        public let restoredHash: String
        public let escalationDecision: EscalationDecision?
        public let diagnosticReference: DiagnosticReference
        public init(rollbackResultID: String, status: StatusValue, backupRecordID: String, restoredHash: String, escalationDecision: EscalationDecision? = nil, diagnosticReference: DiagnosticReference) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("rollbackResultID", .string(rollbackResultID)))
            members.append(JSONMember("status", .string(status.rawValue)))
            members.append(JSONMember("backupRecordID", .string(backupRecordID)))
            members.append(JSONMember("restoredHash", .string(restoredHash)))
            if let value = escalationDecision { members.append(JSONMember("escalationDecision", value.jsonValue)) }
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["rollbackResultID", "status", "backupRecordID", "restoredHash", "escalationDecision", "diagnosticReference"], required: ["rollbackResultID", "status", "backupRecordID", "restoredHash", "diagnosticReference"])
            self.rollbackResultID = try ContractFields.string(fields.require("rollbackResultID"))
            self.status = try ContractFields.enumeration(StatusValue.self, fields.require("status"))
            self.backupRecordID = try ContractFields.string(fields.require("backupRecordID"))
            self.restoredHash = try ContractFields.string(fields.require("restoredHash"))
            self.escalationDecision = try fields.optional("escalationDecision").map { value in try EscalationDecision(jsonValue: value) }
            self.diagnosticReference = try DiagnosticReference(jsonValue: fields.require("diagnosticReference"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("rollbackResultID", .string(rollbackResultID)))
            members.append(JSONMember("status", .string(status.rawValue)))
            members.append(JSONMember("backupRecordID", .string(backupRecordID)))
            members.append(JSONMember("restoredHash", .string(restoredHash)))
            if let value = escalationDecision { members.append(JSONMember("escalationDecision", value.jsonValue)) }
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct RuleReference: CanonicalContract {
        public static let contractName = "RuleReference"
        public let ruleID: String
        public let sourceReference: String
        public let ruleFamily: String
        public init(ruleID: String, sourceReference: String, ruleFamily: String) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("ruleID", .string(ruleID)))
            members.append(JSONMember("sourceReference", .string(sourceReference)))
            members.append(JSONMember("ruleFamily", .string(ruleFamily)))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["ruleID", "sourceReference", "ruleFamily"], required: ["ruleID", "sourceReference", "ruleFamily"])
            self.ruleID = try ContractFields.string(fields.require("ruleID"))
            do { let value = try fields.require("ruleID"); guard try ContractFields.string(value).range(of: "^ASH-[A-Z]+-[A-Z]+-[0-9]{3}$", options: .regularExpression) != nil else { throw CanonicalJSONError.invalidContract("RuleReference.ruleID") } }
            self.sourceReference = try ContractFields.string(fields.require("sourceReference"))
            self.ruleFamily = try ContractFields.string(fields.require("ruleFamily"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("ruleID", .string(ruleID)))
            members.append(JSONMember("sourceReference", .string(sourceReference)))
            members.append(JSONMember("ruleFamily", .string(ruleFamily)))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct SafeHaltDecision: CanonicalContract {
        public static let contractName = "SafeHaltDecision"
        public let safeHaltDecisionID: String
        public let terminal: Bool
        public let blockedTransitions: [String ]
        public let diagnosticReference: DiagnosticReference
        public init(safeHaltDecisionID: String, terminal: Bool, blockedTransitions: [String ], diagnosticReference: DiagnosticReference) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("safeHaltDecisionID", .string(safeHaltDecisionID)))
            members.append(JSONMember("terminal", .bool(terminal)))
            members.append(JSONMember("blockedTransitions", .array(blockedTransitions.map { value in .string(value) })))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["safeHaltDecisionID", "terminal", "blockedTransitions", "diagnosticReference"], required: ["safeHaltDecisionID", "terminal", "blockedTransitions", "diagnosticReference"])
            self.safeHaltDecisionID = try ContractFields.string(fields.require("safeHaltDecisionID"))
            self.terminal = try ContractFields.boolean(fields.require("terminal"))
            do { let value = try fields.require("terminal"); guard value == .bool(true) else { throw CanonicalJSONError.invalidContract("SafeHaltDecision.terminal") } }
            self.blockedTransitions = try ContractFields.array(fields.require("blockedTransitions")).map { value in try ContractFields.string(value) }
            do { let value = try fields.require("blockedTransitions"); guard try ContractFields.array(value).count >= 1 else { throw CanonicalJSONError.invalidContract("SafeHaltDecision.blockedTransitions") } }
            self.diagnosticReference = try DiagnosticReference(jsonValue: fields.require("diagnosticReference"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("safeHaltDecisionID", .string(safeHaltDecisionID)))
            members.append(JSONMember("terminal", .bool(terminal)))
            members.append(JSONMember("blockedTransitions", .array(blockedTransitions.map { value in .string(value) })))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct SemanticDimensionBinding: CanonicalContract {
        public static let contractName = "SemanticDimensionBinding"
        public enum DimensionIDValue: String, Codable { case b0 = "b0"; case b1 = "b1"; case b2 = "b2"; case b3 = "b3"; case b4 = "b4"; case b5 = "b5"; case b6 = "b6"; case b7 = "b7"; case b8 = "b8" }
        public let dimensionID: DimensionIDValue
        public let sourcePointers: [JsonPointer ]
        public let mappingRule: String
        public let evidence: [JSONValue ]
        public let diagnosticReference: DiagnosticReference
        public init(dimensionID: DimensionIDValue, sourcePointers: [JsonPointer ], mappingRule: String, evidence: [JSONValue ], diagnosticReference: DiagnosticReference) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("dimensionID", .string(dimensionID.rawValue)))
            members.append(JSONMember("sourcePointers", .array(sourcePointers.map { value in value.jsonValue })))
            members.append(JSONMember("mappingRule", .string(mappingRule)))
            members.append(JSONMember("evidence", .array(evidence.map { value in value })))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["dimensionID", "sourcePointers", "mappingRule", "evidence", "diagnosticReference"], required: ["dimensionID", "sourcePointers", "mappingRule", "evidence", "diagnosticReference"])
            self.dimensionID = try ContractFields.enumeration(DimensionIDValue.self, fields.require("dimensionID"))
            self.sourcePointers = try ContractFields.array(fields.require("sourcePointers")).map { value in try JsonPointer(jsonValue: value) }
            do { let value = try fields.require("sourcePointers"); guard try ContractFields.array(value).count >= 1 else { throw CanonicalJSONError.invalidContract("SemanticDimensionBinding.sourcePointers") } }
            self.mappingRule = try ContractFields.string(fields.require("mappingRule"))
            self.evidence = try ContractFields.array(fields.require("evidence")).map { value in try ContractFields.object(value) }
            do { let value = try fields.require("evidence"); guard try ContractFields.array(value).count >= 1 else { throw CanonicalJSONError.invalidContract("SemanticDimensionBinding.evidence") } }
            self.diagnosticReference = try DiagnosticReference(jsonValue: fields.require("diagnosticReference"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("dimensionID", .string(dimensionID.rawValue)))
            members.append(JSONMember("sourcePointers", .array(sourcePointers.map { value in value.jsonValue })))
            members.append(JSONMember("mappingRule", .string(mappingRule)))
            members.append(JSONMember("evidence", .array(evidence.map { value in value })))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct SemanticProjectionSpec: CanonicalContract {
        public static let contractName = "SemanticProjectionSpec"
        public let projectionSpecID: String
        public let dimensions: [SemanticDimensionBinding ]
        public let version: String
        public let sourceReferences: [String ]
        public init(projectionSpecID: String, dimensions: [SemanticDimensionBinding ], version: String, sourceReferences: [String ]) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("projectionSpecID", .string(projectionSpecID)))
            members.append(JSONMember("dimensions", .array(dimensions.map { value in value.jsonValue })))
            members.append(JSONMember("version", .string(version)))
            members.append(JSONMember("sourceReferences", .array(sourceReferences.map { value in .string(value) })))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["projectionSpecID", "dimensions", "version", "sourceReferences"], required: ["projectionSpecID", "dimensions", "version", "sourceReferences"])
            self.projectionSpecID = try ContractFields.string(fields.require("projectionSpecID"))
            self.dimensions = try ContractFields.array(fields.require("dimensions")).map { value in try SemanticDimensionBinding(jsonValue: value) }
            do { let value = try fields.require("dimensions"); guard try ContractFields.array(value).count >= 9 else { throw CanonicalJSONError.invalidContract("SemanticProjectionSpec.dimensions") }; guard try ContractFields.array(value).count <= 9 else { throw CanonicalJSONError.invalidContract("SemanticProjectionSpec.dimensions") } }
            self.version = try ContractFields.string(fields.require("version"))
            self.sourceReferences = try ContractFields.array(fields.require("sourceReferences")).map { value in try ContractFields.string(value) }
            do { let value = try fields.require("sourceReferences"); guard try ContractFields.array(value).count >= 1 else { throw CanonicalJSONError.invalidContract("SemanticProjectionSpec.sourceReferences") } }
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("projectionSpecID", .string(projectionSpecID)))
            members.append(JSONMember("dimensions", .array(dimensions.map { value in value.jsonValue })))
            members.append(JSONMember("version", .string(version)))
            members.append(JSONMember("sourceReferences", .array(sourceReferences.map { value in .string(value) })))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct StateValidityDiagnostic: CanonicalContract {
        public static let contractName = "StateValidityDiagnostic"
        public enum AdmissibilityStatusValue: String, Codable { case VALID = "VALID"; case TRANSFORMATION_COMPATIBLE = "TRANSFORMATION_COMPATIBLE"; case TRANSFORMATION_INCOMPATIBLE = "TRANSFORMATION_INCOMPATIBLE"; case UNCLASSIFIED = "UNCLASSIFIED" }
        public enum NormalizationStatusValue: String, Codable { case ALREADY_VALID = "ALREADY_VALID"; case NORMALIZABLE = "NORMALIZABLE"; case NOT_NORMALIZABLE = "NOT_NORMALIZABLE"; case BLOCKED = "BLOCKED" }
        public let stateValidityDiagnosticID: String
        public let diagnosticEnvelope: DiagnosticEnvelope
        public let admissibilityStatus: AdmissibilityStatusValue
        public let normalizationStatus: NormalizationStatusValue
        public let recoverabilityRelevance: RecoveryCategory
        public init(stateValidityDiagnosticID: String, diagnosticEnvelope: DiagnosticEnvelope, admissibilityStatus: AdmissibilityStatusValue, normalizationStatus: NormalizationStatusValue, recoverabilityRelevance: RecoveryCategory) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("stateValidityDiagnosticID", .string(stateValidityDiagnosticID)))
            members.append(JSONMember("diagnosticEnvelope", diagnosticEnvelope.jsonValue))
            members.append(JSONMember("admissibilityStatus", .string(admissibilityStatus.rawValue)))
            members.append(JSONMember("normalizationStatus", .string(normalizationStatus.rawValue)))
            members.append(JSONMember("recoverabilityRelevance", recoverabilityRelevance.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["stateValidityDiagnosticID", "diagnosticEnvelope", "admissibilityStatus", "normalizationStatus", "recoverabilityRelevance"], required: ["stateValidityDiagnosticID", "diagnosticEnvelope", "admissibilityStatus", "normalizationStatus", "recoverabilityRelevance"])
            self.stateValidityDiagnosticID = try ContractFields.string(fields.require("stateValidityDiagnosticID"))
            self.diagnosticEnvelope = try DiagnosticEnvelope(jsonValue: fields.require("diagnosticEnvelope"))
            self.admissibilityStatus = try ContractFields.enumeration(AdmissibilityStatusValue.self, fields.require("admissibilityStatus"))
            self.normalizationStatus = try ContractFields.enumeration(NormalizationStatusValue.self, fields.require("normalizationStatus"))
            self.recoverabilityRelevance = try RecoveryCategory(jsonValue: fields.require("recoverabilityRelevance"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("stateValidityDiagnosticID", .string(stateValidityDiagnosticID)))
            members.append(JSONMember("diagnosticEnvelope", diagnosticEnvelope.jsonValue))
            members.append(JSONMember("admissibilityStatus", .string(admissibilityStatus.rawValue)))
            members.append(JSONMember("normalizationStatus", .string(normalizationStatus.rawValue)))
            members.append(JSONMember("recoverabilityRelevance", recoverabilityRelevance.jsonValue))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct SurfaceDifference: CanonicalContract {
        public static let contractName = "SurfaceDifference"
        public enum DifferenceKindValue: String, Codable { case MISSING = "MISSING"; case ADDED = "ADDED"; case REMOVED = "REMOVED"; case REPLACED = "REPLACED"; case TYPE_CHANGED = "TYPE_CHANGED"; case ARRAY_CHANGED = "ARRAY_CHANGED" }
        public let differenceID: String
        public let path: JsonPointer
        public let differenceKind: DifferenceKindValue
        public let observedDocument: JsonDocumentReference
        public let desiredDocument: JsonDocumentReference
        public let diagnosticReference: DiagnosticReference
        public init(differenceID: String, path: JsonPointer, differenceKind: DifferenceKindValue, observedDocument: JsonDocumentReference, desiredDocument: JsonDocumentReference, diagnosticReference: DiagnosticReference) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("differenceID", .string(differenceID)))
            members.append(JSONMember("path", path.jsonValue))
            members.append(JSONMember("differenceKind", .string(differenceKind.rawValue)))
            members.append(JSONMember("observedDocument", observedDocument.jsonValue))
            members.append(JSONMember("desiredDocument", desiredDocument.jsonValue))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["differenceID", "path", "differenceKind", "observedDocument", "desiredDocument", "diagnosticReference"], required: ["differenceID", "path", "differenceKind", "observedDocument", "desiredDocument", "diagnosticReference"])
            self.differenceID = try ContractFields.string(fields.require("differenceID"))
            self.path = try JsonPointer(jsonValue: fields.require("path"))
            self.differenceKind = try ContractFields.enumeration(DifferenceKindValue.self, fields.require("differenceKind"))
            self.observedDocument = try JsonDocumentReference(jsonValue: fields.require("observedDocument"))
            self.desiredDocument = try JsonDocumentReference(jsonValue: fields.require("desiredDocument"))
            self.diagnosticReference = try DiagnosticReference(jsonValue: fields.require("diagnosticReference"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("differenceID", .string(differenceID)))
            members.append(JSONMember("path", path.jsonValue))
            members.append(JSONMember("differenceKind", .string(differenceKind.rawValue)))
            members.append(JSONMember("observedDocument", observedDocument.jsonValue))
            members.append(JSONMember("desiredDocument", desiredDocument.jsonValue))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    enum SystemStateClass: String, CanonicalContract {
        public static let contractName = "SystemStateClass"
        case STABLE = "STABLE"
        case UNSTABLE = "UNSTABLE"
        case CORRECTABLE = "CORRECTABLE"
        case DEGRADED = "DEGRADED"
        case CONTAINED = "CONTAINED"
        case FAILED = "FAILED"
        case SAFE_HALT = "SAFE_HALT"
        public init(jsonValue: JSONValue) throws { self = try ContractFields.enumeration(Self.self, jsonValue) }
        public var jsonValue: JSONValue { .string(rawValue) }
    }
}

public extension AeostaraContract {
    struct TopologyPlan: CanonicalContract {
        public static let contractName = "TopologyPlan"
        public let topologyID: String
        public let rootState: AshState
        public let nodes: [JSONValue ]
        public let edges: [JSONValue ]
        public let lineage: JSONValue
        public let diagnosticReferences: [DiagnosticReference ]
        public init(topologyID: String, rootState: AshState, nodes: [JSONValue ], edges: [JSONValue ], lineage: JSONValue, diagnosticReferences: [DiagnosticReference ]) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("topologyID", .string(topologyID)))
            members.append(JSONMember("rootState", rootState.jsonValue))
            members.append(JSONMember("nodes", .array(nodes.map { value in value })))
            members.append(JSONMember("edges", .array(edges.map { value in value })))
            members.append(JSONMember("lineage", lineage))
            members.append(JSONMember("diagnosticReferences", .array(diagnosticReferences.map { value in value.jsonValue })))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["topologyID", "rootState", "nodes", "edges", "lineage", "diagnosticReferences"], required: ["topologyID", "rootState", "nodes", "edges", "lineage", "diagnosticReferences"])
            self.topologyID = try ContractFields.string(fields.require("topologyID"))
            self.rootState = try AshState(jsonValue: fields.require("rootState"))
            self.nodes = try ContractFields.array(fields.require("nodes")).map { value in try ContractFields.object(value) }
            do { let value = try fields.require("nodes"); guard try ContractFields.array(value).count >= 1 else { throw CanonicalJSONError.invalidContract("TopologyPlan.nodes") } }
            self.edges = try ContractFields.array(fields.require("edges")).map { value in try ContractFields.object(value) }
            do { let value = try fields.require("edges"); guard try ContractFields.array(value).count >= 1 else { throw CanonicalJSONError.invalidContract("TopologyPlan.edges") } }
            self.lineage = try ContractFields.object(fields.require("lineage"))
            self.diagnosticReferences = try ContractFields.array(fields.require("diagnosticReferences")).map { value in try DiagnosticReference(jsonValue: value) }
            do { let value = try fields.require("diagnosticReferences"); guard try ContractFields.array(value).count >= 1 else { throw CanonicalJSONError.invalidContract("TopologyPlan.diagnosticReferences") } }
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("topologyID", .string(topologyID)))
            members.append(JSONMember("rootState", rootState.jsonValue))
            members.append(JSONMember("nodes", .array(nodes.map { value in value })))
            members.append(JSONMember("edges", .array(edges.map { value in value })))
            members.append(JSONMember("lineage", lineage))
            members.append(JSONMember("diagnosticReferences", .array(diagnosticReferences.map { value in value.jsonValue })))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct TransitionDefinition: CanonicalContract {
        public static let contractName = "TransitionDefinition"
        public let transitionID: String
        public let codewordReference: String
        public let preconditions: [String ]
        public let diagnosticRules: [RuleReference ]
        public init(transitionID: String, codewordReference: String, preconditions: [String ], diagnosticRules: [RuleReference ]) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("transitionID", .string(transitionID)))
            members.append(JSONMember("codewordReference", .string(codewordReference)))
            members.append(JSONMember("preconditions", .array(preconditions.map { value in .string(value) })))
            members.append(JSONMember("diagnosticRules", .array(diagnosticRules.map { value in value.jsonValue })))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["transitionID", "codewordReference", "preconditions", "diagnosticRules"], required: ["transitionID", "codewordReference", "preconditions", "diagnosticRules"])
            self.transitionID = try ContractFields.string(fields.require("transitionID"))
            self.codewordReference = try ContractFields.string(fields.require("codewordReference"))
            self.preconditions = try ContractFields.array(fields.require("preconditions")).map { value in try ContractFields.string(value) }
            do { let value = try fields.require("preconditions"); guard try ContractFields.array(value).count >= 1 else { throw CanonicalJSONError.invalidContract("TransitionDefinition.preconditions") } }
            self.diagnosticRules = try ContractFields.array(fields.require("diagnosticRules")).map { value in try RuleReference(jsonValue: value) }
            do { let value = try fields.require("diagnosticRules"); guard try ContractFields.array(value).count >= 1 else { throw CanonicalJSONError.invalidContract("TransitionDefinition.diagnosticRules") } }
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("transitionID", .string(transitionID)))
            members.append(JSONMember("codewordReference", .string(codewordReference)))
            members.append(JSONMember("preconditions", .array(preconditions.map { value in .string(value) })))
            members.append(JSONMember("diagnosticRules", .array(diagnosticRules.map { value in value.jsonValue })))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct TransitionResult: CanonicalContract {
        public static let contractName = "TransitionResult"
        public let resultID: String
        public let transitionID: String
        public let inputState: AshState
        public let outputState: AshState
        public let diagnosticReference: DiagnosticReference
        public init(resultID: String, transitionID: String, inputState: AshState, outputState: AshState, diagnosticReference: DiagnosticReference) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("resultID", .string(resultID)))
            members.append(JSONMember("transitionID", .string(transitionID)))
            members.append(JSONMember("inputState", inputState.jsonValue))
            members.append(JSONMember("outputState", outputState.jsonValue))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["resultID", "transitionID", "inputState", "outputState", "diagnosticReference"], required: ["resultID", "transitionID", "inputState", "outputState", "diagnosticReference"])
            self.resultID = try ContractFields.string(fields.require("resultID"))
            self.transitionID = try ContractFields.string(fields.require("transitionID"))
            self.inputState = try AshState(jsonValue: fields.require("inputState"))
            self.outputState = try AshState(jsonValue: fields.require("outputState"))
            self.diagnosticReference = try DiagnosticReference(jsonValue: fields.require("diagnosticReference"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("resultID", .string(resultID)))
            members.append(JSONMember("transitionID", .string(transitionID)))
            members.append(JSONMember("inputState", inputState.jsonValue))
            members.append(JSONMember("outputState", outputState.jsonValue))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct VerificationPlan: CanonicalContract {
        public static let contractName = "VerificationPlan"
        public let verificationPlanID: String
        public let checks: [JSONValue ]
        public let expectedSemanticState: AshState
        public let generatedBeforeMutation: Bool
        public let diagnosticReference: DiagnosticReference
        public init(verificationPlanID: String, checks: [JSONValue ], expectedSemanticState: AshState, generatedBeforeMutation: Bool, diagnosticReference: DiagnosticReference) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("verificationPlanID", .string(verificationPlanID)))
            members.append(JSONMember("checks", .array(checks.map { value in value })))
            members.append(JSONMember("expectedSemanticState", expectedSemanticState.jsonValue))
            members.append(JSONMember("generatedBeforeMutation", .bool(generatedBeforeMutation)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["verificationPlanID", "checks", "expectedSemanticState", "generatedBeforeMutation", "diagnosticReference"], required: ["verificationPlanID", "checks", "expectedSemanticState", "generatedBeforeMutation", "diagnosticReference"])
            self.verificationPlanID = try ContractFields.string(fields.require("verificationPlanID"))
            self.checks = try ContractFields.array(fields.require("checks")).map { value in try ContractFields.object(value) }
            do { let value = try fields.require("checks"); guard try ContractFields.array(value).count >= 1 else { throw CanonicalJSONError.invalidContract("VerificationPlan.checks") } }
            self.expectedSemanticState = try AshState(jsonValue: fields.require("expectedSemanticState"))
            self.generatedBeforeMutation = try ContractFields.boolean(fields.require("generatedBeforeMutation"))
            self.diagnosticReference = try DiagnosticReference(jsonValue: fields.require("diagnosticReference"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("verificationPlanID", .string(verificationPlanID)))
            members.append(JSONMember("checks", .array(checks.map { value in value })))
            members.append(JSONMember("expectedSemanticState", expectedSemanticState.jsonValue))
            members.append(JSONMember("generatedBeforeMutation", .bool(generatedBeforeMutation)))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            return .object(members)
        }
    }
}

public extension AeostaraContract {
    struct VerificationResult: CanonicalContract {
        public static let contractName = "VerificationResult"
        public enum StatusValue: String, Codable { case PASSED = "PASSED"; case FAILED = "FAILED"; case BLOCKED = "BLOCKED" }
        public let verificationResultID: String
        public let verificationPlanID: String
        public let status: StatusValue
        public let expectedSemanticState: AshState
        public let actualSemanticState: AshState
        public let diagnosticReference: DiagnosticReference
        public init(verificationResultID: String, verificationPlanID: String, status: StatusValue, expectedSemanticState: AshState, actualSemanticState: AshState, diagnosticReference: DiagnosticReference) throws {
            var members: [JSONMember] = []
            members.append(JSONMember("verificationResultID", .string(verificationResultID)))
            members.append(JSONMember("verificationPlanID", .string(verificationPlanID)))
            members.append(JSONMember("status", .string(status.rawValue)))
            members.append(JSONMember("expectedSemanticState", expectedSemanticState.jsonValue))
            members.append(JSONMember("actualSemanticState", actualSemanticState.jsonValue))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            try self.init(jsonValue: .object(members))
        }
        public init(jsonValue: JSONValue) throws {
            let fields = try ContractFields(jsonValue, allowed: ["verificationResultID", "verificationPlanID", "status", "expectedSemanticState", "actualSemanticState", "diagnosticReference"], required: ["verificationResultID", "verificationPlanID", "status", "expectedSemanticState", "actualSemanticState", "diagnosticReference"])
            self.verificationResultID = try ContractFields.string(fields.require("verificationResultID"))
            self.verificationPlanID = try ContractFields.string(fields.require("verificationPlanID"))
            self.status = try ContractFields.enumeration(StatusValue.self, fields.require("status"))
            self.expectedSemanticState = try AshState(jsonValue: fields.require("expectedSemanticState"))
            self.actualSemanticState = try AshState(jsonValue: fields.require("actualSemanticState"))
            self.diagnosticReference = try DiagnosticReference(jsonValue: fields.require("diagnosticReference"))
        }
        public var jsonValue: JSONValue {
            var members: [JSONMember] = []
            members.append(JSONMember("verificationResultID", .string(verificationResultID)))
            members.append(JSONMember("verificationPlanID", .string(verificationPlanID)))
            members.append(JSONMember("status", .string(status.rawValue)))
            members.append(JSONMember("expectedSemanticState", expectedSemanticState.jsonValue))
            members.append(JSONMember("actualSemanticState", actualSemanticState.jsonValue))
            members.append(JSONMember("diagnosticReference", diagnosticReference.jsonValue))
            return .object(members)
        }
    }
}

private struct ContractFields {
    let value: JSONValue
    init(_ value: JSONValue, allowed: [String], required: [String]) throws {
        guard let members = value.objectMembers else { throw CanonicalJSONError.unexpectedType }
        _ = try CanonicalJSON.encode(value)
        guard members.allSatisfy({ allowed.contains($0.name) }), required.allSatisfy({ value.member($0) != nil }) else { throw CanonicalJSONError.invalidContract("field inventory") }
        self.value = value
    }
    func require(_ name: String) throws -> JSONValue { guard let result = value.member(name) else { throw CanonicalJSONError.invalidContract(name) }; return result }
    func optional(_ name: String) -> JSONValue? { value.member(name) }
    static func string(_ value: JSONValue) throws -> String { guard let v = value.stringValue else { throw CanonicalJSONError.unexpectedType }; return v }
    static func integer(_ value: JSONValue) throws -> Int { guard let v = try JSONInteger(jsonValue:value).intValue else { throw CanonicalJSONError.unexpectedType }; return v }
    static func boolean(_ value: JSONValue) throws -> Bool { guard let v = value.boolValue else { throw CanonicalJSONError.unexpectedType }; return v }
    static func number(_ value: JSONValue) throws -> Double { guard case .number(let n) = value, let v = Double(try n.canonicalText) else { throw CanonicalJSONError.unexpectedType }; return v }
    static func array(_ value: JSONValue) throws -> [JSONValue] { guard let v = value.arrayValues else { throw CanonicalJSONError.unexpectedType }; return v }
    static func object(_ value: JSONValue) throws -> JSONValue { guard value.objectMembers != nil else { throw CanonicalJSONError.unexpectedType }; return value }
    static func enumeration<T: RawRepresentable>(_ type: T.Type, _ value: JSONValue) throws -> T where T.RawValue == String { guard let v = T(rawValue: try string(value)) else { throw CanonicalJSONError.invalidContract("enum") }; return v }
}
