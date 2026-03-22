// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#include "AeostaraCore/Invariant.h"

#include <stdexcept>

namespace Aeostara {

// ---------------------------------------------------------------------------
// InvariantSeverity
// ---------------------------------------------------------------------------
std::string to_string(InvariantSeverity severity) {
    switch (severity) {
        case InvariantSeverity::Low:      return "low";
        case InvariantSeverity::Medium:   return "medium";
        case InvariantSeverity::High:     return "high";
        case InvariantSeverity::Critical: return "critical";
    }
    return "unknown";
}

InvariantSeverity invariantSeverityFromString(const std::string& str) {
    if (str == "low")      return InvariantSeverity::Low;
    if (str == "medium")   return InvariantSeverity::Medium;
    if (str == "high")     return InvariantSeverity::High;
    if (str == "critical") return InvariantSeverity::Critical;
    throw std::invalid_argument("Unknown InvariantSeverity: " + str);
}

void to_json(nlohmann::json& j, InvariantSeverity severity) {
    j = to_string(severity);
}

void from_json(const nlohmann::json& j, InvariantSeverity& severity) {
    severity = invariantSeverityFromString(j.get<std::string>());
}

// ---------------------------------------------------------------------------
// Invariant
// ---------------------------------------------------------------------------
void to_json(nlohmann::json& j, const Invariant& inv) {
    j = nlohmann::json{
        {"invariant_id", inv.invariantID},
        {"name", inv.name},
        {"description", inv.description},
        {"severity", inv.severity},
        {"expression", inv.expression},
        {"applies_to", inv.appliesTo},
        {"auto_remediate", inv.autoRemediate}
    };
}

void from_json(const nlohmann::json& j, Invariant& inv) {
    j.at("invariant_id").get_to(inv.invariantID);
    j.at("name").get_to(inv.name);
    j.at("description").get_to(inv.description);
    j.at("severity").get_to(inv.severity);
    j.at("expression").get_to(inv.expression);
    j.at("applies_to").get_to(inv.appliesTo);
    j.at("auto_remediate").get_to(inv.autoRemediate);
}

// ---------------------------------------------------------------------------
// InvariantViolation
// ---------------------------------------------------------------------------
void to_json(nlohmann::json& j, const InvariantViolation& v) {
    j = nlohmann::json{
        {"invariantID", v.invariantID},
        {"keyPath", v.keyPath},
        {"actualValue", v.actualValue},
        {"expectedValue", v.expectedValue},
        {"severity", v.severity}
    };
}

void from_json(const nlohmann::json& j, InvariantViolation& v) {
    j.at("invariantID").get_to(v.invariantID);
    j.at("keyPath").get_to(v.keyPath);
    j.at("actualValue").get_to(v.actualValue);
    j.at("expectedValue").get_to(v.expectedValue);
    j.at("severity").get_to(v.severity);
}

} // namespace Aeostara
