// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#pragma once

#include <nlohmann/json.hpp>

#include <map>
#include <optional>
#include <string>
#include <vector>

namespace Aeostara {

// ---------------------------------------------------------------------------
// 1. ObservedState — snapshot of real system config at observation time
// ---------------------------------------------------------------------------
struct ObservedState final {
    std::string sourceFile;
    nlohmann::json data;
    std::string timestamp;  // ISO 8601

    bool operator==(const ObservedState&) const = default;
};

void to_json(nlohmann::json& j, const ObservedState& s);
void from_json(const nlohmann::json& j, ObservedState& s);

// ---------------------------------------------------------------------------
// 2. DesiredState — declared desired configuration
// ---------------------------------------------------------------------------
struct DesiredState final {
    nlohmann::json data;
    std::string source;

    bool operator==(const DesiredState&) const = default;
};

void to_json(nlohmann::json& j, const DesiredState& s);
void from_json(const nlohmann::json& j, DesiredState& s);

// ---------------------------------------------------------------------------
// 3. EncodedState — flattened canonical representations for drift comparison
// ---------------------------------------------------------------------------
struct EncodedState final {
    std::map<std::string, nlohmann::json> observed;
    std::map<std::string, nlohmann::json> desired;

    bool operator==(const EncodedState&) const = default;
};

void to_json(nlohmann::json& j, const EncodedState& s);
void from_json(const nlohmann::json& j, EncodedState& s);

// ---------------------------------------------------------------------------
// 4. DriftEvent — a single detected drift between observed and desired
// ---------------------------------------------------------------------------
enum class DriftType {
    ValueChanged,
    KeyAdded,
    KeyRemoved
};

std::string to_string(DriftType type);
DriftType driftTypeFromString(const std::string& str);

void to_json(nlohmann::json& j, DriftType type);
void from_json(const nlohmann::json& j, DriftType& type);

struct DriftEvent final {
    std::string keyPath;
    DriftType type;
    nlohmann::json observedValue;  // null if KeyAdded
    nlohmann::json desiredValue;   // null if KeyRemoved
    std::string description;

    bool operator==(const DriftEvent&) const = default;
};

void to_json(nlohmann::json& j, const DriftEvent& e);
void from_json(const nlohmann::json& j, DriftEvent& e);

// ---------------------------------------------------------------------------
// 5. RepairAction — a single remediation step
// ---------------------------------------------------------------------------
enum class RepairActionType {
    Set,
    Add,
    Remove
};

std::string to_string(RepairActionType type);
RepairActionType repairActionTypeFromString(const std::string& str);

void to_json(nlohmann::json& j, RepairActionType type);
void from_json(const nlohmann::json& j, RepairActionType& type);

struct RepairAction final {
    std::string keyPath;
    RepairActionType actionType;
    nlohmann::json fromValue;
    nlohmann::json toValue;
    std::string rationale;

    bool operator==(const RepairAction&) const = default;
};

void to_json(nlohmann::json& j, const RepairAction& a);
void from_json(const nlohmann::json& j, RepairAction& a);

// ---------------------------------------------------------------------------
// 6. RepairPlan — complete repair sequence
// ---------------------------------------------------------------------------
struct RepairPlan final {
    std::string planID;
    std::vector<RepairAction> actions;
    std::string timestamp;
    bool requiresBackup = true;

    bool operator==(const RepairPlan&) const = default;
};

void to_json(nlohmann::json& j, const RepairPlan& p);
void from_json(const nlohmann::json& j, RepairPlan& p);

// ---------------------------------------------------------------------------
// 7. VerificationResult — outcome of post-repair verification
// ---------------------------------------------------------------------------
struct VerificationResult final {
    bool success = false;
    std::vector<std::string> failedChecks;
    std::string verifiedAt;  // ISO 8601

    bool operator==(const VerificationResult&) const = default;
};

void to_json(nlohmann::json& j, const VerificationResult& r);
void from_json(const nlohmann::json& j, VerificationResult& r);

// ---------------------------------------------------------------------------
// 8. RollbackPlan — recovery procedure
// ---------------------------------------------------------------------------
struct RollbackPlan final {
    std::string planID;
    std::string backupFilePath;
    std::string originalFilePath;

    bool operator==(const RollbackPlan&) const = default;
};

void to_json(nlohmann::json& j, const RollbackPlan& p);
void from_json(const nlohmann::json& j, RollbackPlan& p);

// ---------------------------------------------------------------------------
// 9. AuditEvent — audit trail record
// ---------------------------------------------------------------------------
enum class AuditEventType {
    ValidationPerformed,
    DiffGenerated,
    HealStarted,
    BackupCreated,
    RepairApplied,
    VerificationSucceeded,
    VerificationFailed,
    RollbackExecuted,
    PolicyBlocked,
    NoDrift
};

std::string to_string(AuditEventType type);
AuditEventType auditEventTypeFromString(const std::string& str);

void to_json(nlohmann::json& j, AuditEventType type);
void from_json(const nlohmann::json& j, AuditEventType& type);

struct AuditEvent final {
    std::string eventID;
    AuditEventType type;
    std::string timestamp;
    std::string configFile;
    nlohmann::json details;

    bool operator==(const AuditEvent&) const = default;
};

void to_json(nlohmann::json& j, const AuditEvent& e);
void from_json(const nlohmann::json& j, AuditEvent& e);

// ---------------------------------------------------------------------------
// 10. ModuleManifest — Aeostara module metadata (NOT Forsetti's)
// ---------------------------------------------------------------------------
struct ModuleManifest final {
    std::string moduleID;
    std::string displayName;
    std::string version;
    std::string description;
    std::vector<std::string> supportedConfigTypes;

    bool operator==(const ModuleManifest&) const = default;
};

void to_json(nlohmann::json& j, const ModuleManifest& m);
void from_json(const nlohmann::json& j, ModuleManifest& m);

} // namespace Aeostara
