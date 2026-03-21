// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#pragma once

#include "AeostaraCore/Contracts.h"
#include "AeostaraCore/Invariant.h"

#include <optional>
#include <string>
#include <vector>

namespace Aeostara {

/// Top-level abstract interface for the healing engine.
/// Designed to parallel the Forsetti module interface shape for future hosting.
class IHealingEngine {
public:
    struct ValidationResult final {
        bool valid = false;
        std::vector<std::string> errors;
        std::vector<DriftEvent> drifts;
        std::vector<InvariantViolation> violations;
    };

    struct DiffResult final {
        std::vector<DriftEvent> drifts;
        RepairPlan proposedPlan;
    };

    struct HealResult final {
        bool success = false;
        RepairPlan executedPlan;
        VerificationResult verification;
        std::optional<RollbackPlan> rollback;
        std::vector<AuditEvent> auditEvents;
        std::string message;
    };

    virtual ValidationResult validate(const std::string& configPath,
                                       const std::string& desiredPath,
                                       const std::string& invariantsPath) = 0;

    virtual DiffResult diff(const std::string& configPath,
                            const std::string& desiredPath,
                            const std::string& invariantsPath) = 0;

    virtual HealResult heal(const std::string& configPath,
                            const std::string& desiredPath,
                            const std::string& invariantsPath,
                            const std::string& auditPath) = 0;

    virtual ~IHealingEngine() = default;
};

} // namespace Aeostara
