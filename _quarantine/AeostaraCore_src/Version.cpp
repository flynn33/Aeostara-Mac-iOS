// Aeostara
// Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.

#include "AeostaraCore/Version.h"

namespace Aeostara {

std::string AeostaraVersion::toString() {
    return std::to_string(major) + "." +
           std::to_string(minor) + "." +
           std::to_string(patch);
}

} // namespace Aeostara
