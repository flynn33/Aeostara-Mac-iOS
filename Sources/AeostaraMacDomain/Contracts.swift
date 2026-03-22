// Copyright (c) 2026 James Daley. All Rights Reserved.
// Aeostara — Deterministic JSON Configuration Drift Detection and Healing Platform

import Foundation

// MARK: - ObservedState

public struct ObservedState: Codable, Equatable {
    public let sourceFile: String
    public let data: [String: AnyCodable]
    public let timestamp: String

    public init(sourceFile: String, data: [String: AnyCodable], timestamp: String) {
        self.sourceFile = sourceFile
        self.data = data
        self.timestamp = timestamp
    }
}

// MARK: - DesiredState

public struct DesiredState: Codable, Equatable {
    public let data: [String: AnyCodable]
    public let source: String

    public init(data: [String: AnyCodable], source: String) {
        self.data = data
        self.source = source
    }
}

// MARK: - EncodedState

public struct EncodedState: Equatable {
    public let observed: [String: AnyCodable]
    public let desired: [String: AnyCodable]

    public init(observed: [String: AnyCodable], desired: [String: AnyCodable]) {
        self.observed = observed
        self.desired = desired
    }
}

// MARK: - DriftEvent

public enum DriftType: String, Codable {
    case valueChanged = "ValueChanged"
    case keyAdded = "KeyAdded"
    case keyRemoved = "KeyRemoved"
}

public struct DriftEvent: Codable, Equatable {
    public let keyPath: String
    public let type: DriftType
    public let observedValue: AnyCodable?
    public let desiredValue: AnyCodable?
    public let description: String

    public init(keyPath: String, type: DriftType, observedValue: AnyCodable?, desiredValue: AnyCodable?, description: String) {
        self.keyPath = keyPath
        self.type = type
        self.observedValue = observedValue
        self.desiredValue = desiredValue
        self.description = description
    }
}

// MARK: - RepairAction

public enum ActionType: String, Codable {
    case set = "Set"
    case add = "Add"
    case remove = "Remove"
}

public struct RepairAction: Codable, Equatable {
    public let keyPath: String
    public let actionType: ActionType
    public let fromValue: AnyCodable?
    public let toValue: AnyCodable?
    public let rationale: String

    public init(keyPath: String, actionType: ActionType, fromValue: AnyCodable?, toValue: AnyCodable?, rationale: String) {
        self.keyPath = keyPath
        self.actionType = actionType
        self.fromValue = fromValue
        self.toValue = toValue
        self.rationale = rationale
    }
}

// MARK: - RepairPlan

public struct RepairPlan: Codable, Equatable {
    public let planID: String
    public let actions: [RepairAction]
    public let timestamp: String
    public let requiresBackup: Bool

    public init(planID: String, actions: [RepairAction], timestamp: String, requiresBackup: Bool) {
        self.planID = planID
        self.actions = actions
        self.timestamp = timestamp
        self.requiresBackup = requiresBackup
    }
}

// MARK: - VerificationResult

public struct VerificationResult: Codable, Equatable {
    public let success: Bool
    public let failedChecks: [String]
    public let verifiedAt: String

    public init(success: Bool, failedChecks: [String], verifiedAt: String) {
        self.success = success
        self.failedChecks = failedChecks
        self.verifiedAt = verifiedAt
    }
}

// MARK: - RollbackPlan

public struct RollbackPlan: Codable, Equatable {
    public let planID: String
    public let backupFilePath: String
    public let originalFilePath: String

    public init(planID: String, backupFilePath: String, originalFilePath: String) {
        self.planID = planID
        self.backupFilePath = backupFilePath
        self.originalFilePath = originalFilePath
    }
}

// MARK: - AuditEvent

public enum AuditEventType: String, Codable {
    case validationPerformed = "ValidationPerformed"
    case diffGenerated = "DiffGenerated"
    case healStarted = "HealStarted"
    case backupCreated = "BackupCreated"
    case repairApplied = "RepairApplied"
    case verificationSucceeded = "VerificationSucceeded"
    case verificationFailed = "VerificationFailed"
    case rollbackExecuted = "RollbackExecuted"
    case policyBlocked = "PolicyBlocked"
    case noDrift = "NoDrift"
}

public struct AuditEvent: Codable, Equatable {
    public let eventID: String
    public let type: AuditEventType
    public let timestamp: String
    public let configFile: String
    public let details: [String: AnyCodable]?

    public init(eventID: String, type: AuditEventType, timestamp: String, configFile: String, details: [String: AnyCodable]? = nil) {
        self.eventID = eventID
        self.type = type
        self.timestamp = timestamp
        self.configFile = configFile
        self.details = details
    }
}

// MARK: - Invariant

public enum Severity: String, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
}

public struct Invariant: Codable, Equatable {
    public let invariantID: String
    public let name: String
    public let description: String?
    public let severity: Severity
    public let expression: String
    public let appliesTo: [String]?
    public let autoRemediate: Bool

    public init(invariantID: String, name: String, description: String? = nil, severity: Severity = .medium, expression: String, appliesTo: [String]? = nil, autoRemediate: Bool = false) {
        self.invariantID = invariantID
        self.name = name
        self.description = description
        self.severity = severity
        self.expression = expression
        self.appliesTo = appliesTo
        self.autoRemediate = autoRemediate
    }

    enum CodingKeys: String, CodingKey {
        case invariantID = "invariant_id"
        case name, description, severity, expression
        case appliesTo = "applies_to"
        case autoRemediate = "auto_remediate"
    }
}

// MARK: - ModuleManifest

public struct ModuleManifest: Codable, Equatable {
    public let moduleID: String
    public let displayName: String
    public let version: String
    public let description: String?
    public let supportedConfigTypes: [String]

    public init(moduleID: String, displayName: String, version: String, description: String? = nil, supportedConfigTypes: [String]) {
        self.moduleID = moduleID
        self.displayName = displayName
        self.version = version
        self.description = description
        self.supportedConfigTypes = supportedConfigTypes
    }
}

// MARK: - Result Types

public struct ValidationResult: Equatable {
    public let valid: Bool
    public let errors: [String]
    public let drifts: [DriftEvent]
    public let violations: [String]

    public init(valid: Bool, errors: [String], drifts: [DriftEvent], violations: [String]) {
        self.valid = valid
        self.errors = errors
        self.drifts = drifts
        self.violations = violations
    }
}

public struct DiffResult: Equatable {
    public let drifts: [DriftEvent]
    public let proposedPlan: RepairPlan?

    public init(drifts: [DriftEvent], proposedPlan: RepairPlan?) {
        self.drifts = drifts
        self.proposedPlan = proposedPlan
    }
}

public struct HealResult: Equatable {
    public let success: Bool
    public let executedPlan: RepairPlan?
    public let verification: VerificationResult?
    public let rollback: RollbackPlan?
    public let auditEvents: [AuditEvent]
    public let message: String

    public init(success: Bool, executedPlan: RepairPlan? = nil, verification: VerificationResult? = nil, rollback: RollbackPlan? = nil, auditEvents: [AuditEvent] = [], message: String) {
        self.success = success
        self.executedPlan = executedPlan
        self.verification = verification
        self.rollback = rollback
        self.auditEvents = auditEvents
        self.message = message
    }
}

public struct PolicyDecision: Equatable {
    public let allowed: Bool
    public let reason: String

    public init(allowed: Bool, reason: String) {
        self.allowed = allowed
        self.reason = reason
    }
}
