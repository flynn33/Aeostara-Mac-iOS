// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#pragma once

#include "AeostaraCore/IHealingEngine.h"
#include "CommandParser.h"

#include <memory>

namespace Aeostara {

class CLIRunner final {
public:
    explicit CLIRunner(std::shared_ptr<IHealingEngine> engine);

    /// Run the parsed command. Returns exit code (0, 1, or 2).
    int run(const ParsedCommand& cmd) const;

private:
    std::shared_ptr<IHealingEngine> engine_;

    int runValidate(const ParsedCommand& cmd) const;
    int runDiff(const ParsedCommand& cmd) const;
    int runHeal(const ParsedCommand& cmd) const;
};

} // namespace Aeostara
