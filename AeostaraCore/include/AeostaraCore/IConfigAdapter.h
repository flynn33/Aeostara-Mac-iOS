// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#pragma once

#include "AeostaraCore/Contracts.h"

#include <string>

namespace Aeostara {

/// Abstract config adapter interface.
/// Bridges file-specific I/O concerns with the core healing engine.
class IConfigAdapter {
public:
    /// Read and parse a config file, returning the observed state.
    virtual ObservedState observe(const std::string& filePath) = 0;

    /// Flatten and encode observed and desired states into canonical form.
    virtual EncodedState encode(const ObservedState& observed, const DesiredState& desired) = 0;

    /// Apply a repair plan to the config file.
    virtual bool applyRepair(const std::string& filePath, const RepairPlan& plan) = 0;

    virtual ~IConfigAdapter() = default;
};

} // namespace Aeostara
