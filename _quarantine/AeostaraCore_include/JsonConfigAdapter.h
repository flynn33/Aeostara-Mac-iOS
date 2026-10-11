// Aeostara
// Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.

#pragma once

#include "AeostaraCore/IConfigAdapter.h"
#include "AeostaraCore/IFileSystem.h"

#include <memory>

namespace Aeostara {

/// JSON config adapter — reads, encodes, and writes JSON configuration files.
class JsonConfigAdapter final : public IConfigAdapter {
public:
    explicit JsonConfigAdapter(std::shared_ptr<IFileSystem> fs);

    ObservedState observe(const std::string& filePath) override;
    EncodedState encode(const ObservedState& observed, const DesiredState& desired) override;
    bool applyRepair(const std::string& filePath, const RepairPlan& plan) override;

private:
    std::shared_ptr<IFileSystem> fs_;
};

} // namespace Aeostara
