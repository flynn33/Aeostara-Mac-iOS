// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#pragma once

#include "AeostaraCore/Contracts.h"
#include "AeostaraCore/Invariant.h"

#include <string>
#include <vector>

namespace Aeostara {

struct PolicyDecision final {
    bool allowed = true;
    std::string reason;
    std::vector<InvariantViolation> violations;
};

/// Evaluates invariant policy against a proposed repair plan.
/// Blocks repairs that would violate critical non-auto-remediate invariants.
class PolicyEvaluator final {
public:
    /// Evaluate whether a repair plan is allowed by policy.
    /// Checks the post-repair state (desired values) against invariants.
    PolicyDecision evaluate(const RepairPlan& plan,
                            const std::vector<Invariant>& invariants,
                            const std::map<std::string, nlohmann::json>& desiredFlat) const;

    /// Evaluate a single invariant expression against a flat state map.
    /// Returns true if the invariant holds.
    static bool evaluateExpression(const std::string& expression,
                                    const std::map<std::string, nlohmann::json>& flatState);

    /// Parse an expression into (keyPath, operator, expectedValue).
    struct ParsedExpression final {
        std::string keyPath;
        std::string op;
        nlohmann::json expectedValue;
    };

    static ParsedExpression parseExpression(const std::string& expression);
};

} // namespace Aeostara
