// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#pragma once

#include "AeostaraCore/Contracts.h"
#include "AeostaraCore/Invariant.h"
#include "AeostaraCore/IFileSystem.h"

#include <memory>
#include <string>
#include <vector>

namespace Aeostara {

/// Post-repair verification: reloads file, checks desired state match and invariants.
class Verifier final {
public:
    /// Verify that a config file matches the desired state and satisfies invariants.
    VerificationResult verify(const std::string& filePath,
                               const DesiredState& desired,
                               const std::vector<Invariant>& invariants,
                               IFileSystem& fs) const;
};

} // namespace Aeostara
