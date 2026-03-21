// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#pragma once

#include "AeostaraCore/Contracts.h"

#include <vector>

namespace Aeostara {

/// Compares observed and desired encoded states to produce drift events.
class DriftAnalyzer final {
public:
    explicit DriftAnalyzer(const EncodedState& state);

    /// Analyze drift between observed and desired states.
    std::vector<DriftEvent> analyze() const;

    /// Returns true if any drift is detected.
    bool hasDrift() const;

private:
    const EncodedState& state_;
};

} // namespace Aeostara
