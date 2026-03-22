// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

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
