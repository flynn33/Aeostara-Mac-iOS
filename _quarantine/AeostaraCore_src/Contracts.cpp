// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#include "AeostaraCore/Contracts.h"

#include <stdexcept>

namespace Aeostara {

// ---------------------------------------------------------------------------
// ObservedState
// ---------------------------------------------------------------------------
void to_json(nlohmann::json& j, const ObservedState& s) {
    j = nlohmann::json{
        {"sourceFile", s.sourceFile},
        {"data", s.data},
        {"timestamp", s.timestamp}
    };
}

void from_json(const nlohmann::json& j, ObservedState& s) {
    j.at("sourceFile").get_to(s.sourceFile);
    j.at("data").get_to(s.data);
    j.at("timestamp").get_to(s.timestamp);
}

// ---------------------------------------------------------------------------
// DesiredState
// ---------------------------------------------------------------------------
void to_json(nlohmann::json& j, const DesiredState& s) {
    j = nlohmann::json{
        {"data", s.data},
        {"source", s.source}
    };
}

void from_json(const nlohmann::json& j, DesiredState& s) {
    j.at("data").get_to(s.data);
    j.at("source").get_to(s.source);
}

// ---------------------------------------------------------------------------
// EncodedState
// ---------------------------------------------------------------------------
void to_json(nlohmann::json& j, const EncodedState& s) {
    j = nlohmann::json{
        {"observed", s.observed},
        {"desired", s.desired}
    };
}

void from_json(const nlohmann::json& j, EncodedState& s) {
    j.at("observed").get_to(s.observed);
    j.at("desired").get_to(s.desired);
}

// ---------------------------------------------------------------------------
// DriftType
// ---------------------------------------------------------------------------
std::string to_string(DriftType type) {
    switch (type) {
        case DriftType::ValueChanged: return "ValueChanged";
        case DriftType::KeyAdded:     return "KeyAdded";
        case DriftType::KeyRemoved:   return "KeyRemoved";
    }
    return "Unknown";
}

DriftType driftTypeFromString(const std::string& str) {
    if (str == "ValueChanged") return DriftType::ValueChanged;
    if (str == "KeyAdded")     return DriftType::KeyAdded;
    if (str == "KeyRemoved")   return DriftType::KeyRemoved;
    throw std::invalid_argument("Unknown DriftType: " + str);
}

void to_json(nlohmann::json& j, DriftType type) {
    j = to_string(type);
}

void from_json(const nlohmann::json& j, DriftType& type) {
    type = driftTypeFromString(j.get<std::string>());
}

// ---------------------------------------------------------------------------
// DriftEvent
// ---------------------------------------------------------------------------
void to_json(nlohmann::json& j, const DriftEvent& e) {
    j = nlohmann::json{
        {"keyPath", e.keyPath},
        {"type", e.type},
        {"observedValue", e.observedValue},
        {"desiredValue", e.desiredValue},
        {"description", e.description}
    };
}

void from_json(const nlohmann::json& j, DriftEvent& e) {
    j.at("keyPath").get_to(e.keyPath);
    j.at("type").get_to(e.type);
    j.at("observedValue").get_to(e.observedValue);
    j.at("desiredValue").get_to(e.desiredValue);
    j.at("description").get_to(e.description);
}

// ---------------------------------------------------------------------------
// RepairActionType
// ---------------------------------------------------------------------------
std::string to_string(RepairActionType type) {
    switch (type) {
        case RepairActionType::Set:    return "Set";
        case RepairActionType::Add:    return "Add";
        case RepairActionType::Remove: return "Remove";
    }
    return "Unknown";
}

RepairActionType repairActionTypeFromString(const std::string& str) {
    if (str == "Set")    return RepairActionType::Set;
    if (str == "Add")    return RepairActionType::Add;
    if (str == "Remove") return RepairActionType::Remove;
    throw std::invalid_argument("Unknown RepairActionType: " + str);
}

void to_json(nlohmann::json& j, RepairActionType type) {
    j = to_string(type);
}

void from_json(const nlohmann::json& j, RepairActionType& type) {
    type = repairActionTypeFromString(j.get<std::string>());
}

// ---------------------------------------------------------------------------
// RepairAction
// ---------------------------------------------------------------------------
void to_json(nlohmann::json& j, const RepairAction& a) {
    j = nlohmann::json{
        {"keyPath", a.keyPath},
        {"actionType", a.actionType},
        {"fromValue", a.fromValue},
        {"toValue", a.toValue},
        {"rationale", a.rationale}
    };
}

void from_json(const nlohmann::json& j, RepairAction& a) {
    j.at("keyPath").get_to(a.keyPath);
    j.at("actionType").get_to(a.actionType);
    j.at("fromValue").get_to(a.fromValue);
    j.at("toValue").get_to(a.toValue);
    j.at("rationale").get_to(a.rationale);
}

// ---------------------------------------------------------------------------
// RepairPlan
// ---------------------------------------------------------------------------
void to_json(nlohmann::json& j, const RepairPlan& p) {
    j = nlohmann::json{
        {"planID", p.planID},
        {"actions", p.actions},
        {"timestamp", p.timestamp},
        {"requiresBackup", p.requiresBackup}
    };
}

void from_json(const nlohmann::json& j, RepairPlan& p) {
    j.at("planID").get_to(p.planID);
    j.at("actions").get_to(p.actions);
    j.at("timestamp").get_to(p.timestamp);
    j.at("requiresBackup").get_to(p.requiresBackup);
}

// ---------------------------------------------------------------------------
// VerificationResult
// ---------------------------------------------------------------------------
void to_json(nlohmann::json& j, const VerificationResult& r) {
    j = nlohmann::json{
        {"success", r.success},
        {"failedChecks", r.failedChecks},
        {"verifiedAt", r.verifiedAt}
    };
}

void from_json(const nlohmann::json& j, VerificationResult& r) {
    j.at("success").get_to(r.success);
    j.at("failedChecks").get_to(r.failedChecks);
    j.at("verifiedAt").get_to(r.verifiedAt);
}

// ---------------------------------------------------------------------------
// RollbackPlan
// ---------------------------------------------------------------------------
void to_json(nlohmann::json& j, const RollbackPlan& p) {
    j = nlohmann::json{
        {"planID", p.planID},
        {"backupFilePath", p.backupFilePath},
        {"originalFilePath", p.originalFilePath}
    };
}

void from_json(const nlohmann::json& j, RollbackPlan& p) {
    j.at("planID").get_to(p.planID);
    j.at("backupFilePath").get_to(p.backupFilePath);
    j.at("originalFilePath").get_to(p.originalFilePath);
}

// ---------------------------------------------------------------------------
// AuditEventType
// ---------------------------------------------------------------------------
std::string to_string(AuditEventType type) {
    switch (type) {
        case AuditEventType::ValidationPerformed:   return "ValidationPerformed";
        case AuditEventType::DiffGenerated:         return "DiffGenerated";
        case AuditEventType::HealStarted:           return "HealStarted";
        case AuditEventType::BackupCreated:         return "BackupCreated";
        case AuditEventType::RepairApplied:         return "RepairApplied";
        case AuditEventType::VerificationSucceeded: return "VerificationSucceeded";
        case AuditEventType::VerificationFailed:    return "VerificationFailed";
        case AuditEventType::RollbackExecuted:      return "RollbackExecuted";
        case AuditEventType::PolicyBlocked:         return "PolicyBlocked";
        case AuditEventType::NoDrift:               return "NoDrift";
    }
    return "Unknown";
}

AuditEventType auditEventTypeFromString(const std::string& str) {
    if (str == "ValidationPerformed")   return AuditEventType::ValidationPerformed;
    if (str == "DiffGenerated")         return AuditEventType::DiffGenerated;
    if (str == "HealStarted")           return AuditEventType::HealStarted;
    if (str == "BackupCreated")         return AuditEventType::BackupCreated;
    if (str == "RepairApplied")         return AuditEventType::RepairApplied;
    if (str == "VerificationSucceeded") return AuditEventType::VerificationSucceeded;
    if (str == "VerificationFailed")    return AuditEventType::VerificationFailed;
    if (str == "RollbackExecuted")      return AuditEventType::RollbackExecuted;
    if (str == "PolicyBlocked")         return AuditEventType::PolicyBlocked;
    if (str == "NoDrift")               return AuditEventType::NoDrift;
    throw std::invalid_argument("Unknown AuditEventType: " + str);
}

void to_json(nlohmann::json& j, AuditEventType type) {
    j = to_string(type);
}

void from_json(const nlohmann::json& j, AuditEventType& type) {
    type = auditEventTypeFromString(j.get<std::string>());
}

// ---------------------------------------------------------------------------
// AuditEvent
// ---------------------------------------------------------------------------
void to_json(nlohmann::json& j, const AuditEvent& e) {
    j = nlohmann::json{
        {"eventID", e.eventID},
        {"type", e.type},
        {"timestamp", e.timestamp},
        {"configFile", e.configFile},
        {"details", e.details}
    };
}

void from_json(const nlohmann::json& j, AuditEvent& e) {
    j.at("eventID").get_to(e.eventID);
    j.at("type").get_to(e.type);
    j.at("timestamp").get_to(e.timestamp);
    j.at("configFile").get_to(e.configFile);
    j.at("details").get_to(e.details);
}

// ---------------------------------------------------------------------------
// ModuleManifest
// ---------------------------------------------------------------------------
void to_json(nlohmann::json& j, const ModuleManifest& m) {
    j = nlohmann::json{
        {"moduleID", m.moduleID},
        {"displayName", m.displayName},
        {"version", m.version},
        {"description", m.description},
        {"supportedConfigTypes", m.supportedConfigTypes}
    };
}

void from_json(const nlohmann::json& j, ModuleManifest& m) {
    j.at("moduleID").get_to(m.moduleID);
    j.at("displayName").get_to(m.displayName);
    j.at("version").get_to(m.version);
    j.at("description").get_to(m.description);
    j.at("supportedConfigTypes").get_to(m.supportedConfigTypes);
}

} // namespace Aeostara
