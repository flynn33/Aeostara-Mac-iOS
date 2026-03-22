// Copyright (c) 2026 James Daley. All Rights Reserved.
// Aeostara — Deterministic JSON Configuration Drift Detection and Healing Platform

import Foundation

/// Errors raised by Aeostara domain operations.
public enum AeostaraError: Error, LocalizedError {
    case cannotLoadConfig(String)
    case cannotLoadDesiredState(String)
    case cannotParseJSON(String)
    case backupFailed(String)
    case repairApplyFailed
    case rollbackFailed
    case auditSerializationFailed
    case fileNotFound(String)
    case fileReadFailed(String)
    case fileWriteFailed(String)

    public var errorDescription: String? {
        switch self {
        case .cannotLoadConfig(let path):
            return "Cannot load config file: \(path)"
        case .cannotLoadDesiredState(let path):
            return "Cannot load desired state file: \(path)"
        case .cannotParseJSON(let detail):
            return "Cannot parse JSON: \(detail)"
        case .backupFailed(let path):
            return "Failed to create backup of: \(path)"
        case .repairApplyFailed:
            return "Failed to apply repair plan"
        case .rollbackFailed:
            return "Failed to execute rollback"
        case .auditSerializationFailed:
            return "Failed to serialize audit event"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .fileReadFailed(let path):
            return "Failed to read file: \(path)"
        case .fileWriteFailed(let path):
            return "Failed to write file: \(path)"
        }
    }
}
