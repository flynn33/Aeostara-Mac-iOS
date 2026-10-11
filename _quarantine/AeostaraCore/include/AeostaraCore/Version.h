// Aeostara
// Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.

#pragma once

#include <string>

namespace Aeostara {

struct AeostaraVersion final {
    static constexpr int major = 0;
    static constexpr int minor = 1;
    static constexpr int patch = 0;

    static std::string toString();
};

} // namespace Aeostara
