// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#pragma once

#include <nlohmann/json.hpp>

#include <string>
#include <vector>

namespace Aeostara {

// ---------------------------------------------------------------------------
// InvariantSeverity
// ---------------------------------------------------------------------------
enum class InvariantSeverity {
    Low,
    Medium,
    High,
    Critical
};

std::string to_string(InvariantSeverity severity);
InvariantSeverity invariantSeverityFromString(const std::string& str);

void to_json(nlohmann::json& j, InvariantSeverity severity);
void from_json(const nlohmann::json& j, InvariantSeverity& severity);

// ---------------------------------------------------------------------------
// Invariant — a constraint rule from the invariant rule format
// ---------------------------------------------------------------------------
struct Invariant final {
    std::string invariantID;
    std::string name;
    std::string description;
    InvariantSeverity severity = InvariantSeverity::Medium;
    std::string expression;
    std::vector<std::string> appliesTo;
    bool autoRemediate = false;

    bool operator==(const Invariant&) const = default;
};

void to_json(nlohmann::json& j, const Invariant& inv);
void from_json(const nlohmann::json& j, Invariant& inv);

// ---------------------------------------------------------------------------
// InvariantViolation — result of evaluating an invariant against a state
// ---------------------------------------------------------------------------
struct InvariantViolation final {
    std::string invariantID;
    std::string keyPath;
    nlohmann::json actualValue;
    nlohmann::json expectedValue;
    InvariantSeverity severity;

    bool operator==(const InvariantViolation&) const = default;
};

void to_json(nlohmann::json& j, const InvariantViolation& v);
void from_json(const nlohmann::json& j, InvariantViolation& v);

} // namespace Aeostara
