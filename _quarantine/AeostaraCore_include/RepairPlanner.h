// Aeostara
// Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.

#pragma once

#include "AeostaraCore/Contracts.h"

#include <string>
#include <vector>

namespace Aeostara {

/// Generates a deterministic RepairPlan from a list of DriftEvents.
class RepairPlanner final {
public:
    /// Create a repair plan from detected drifts.
    /// Actions are sorted by key path for determinism.
    /// KeyRemoved drifts are not acted upon (conservative approach).
    RepairPlan createPlan(const std::vector<DriftEvent>& drifts) const;

    /// Generate a deterministic plan ID from the actions using FNV-1a hash.
    static std::string generatePlanID(const std::vector<RepairAction>& actions);

private:
    static std::string currentTimestamp();
};

} // namespace Aeostara
