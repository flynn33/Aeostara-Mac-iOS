// Aeostara
// Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.

#pragma once

#include "AeostaraCore/Invariant.h"

#include <string>
#include <vector>

namespace Aeostara {

class IFileSystem;

class InvariantParser final {
public:
    /// Parse invariants from a JSON file via the file system abstraction.
    static std::vector<Invariant> parseFile(const std::string& path, IFileSystem& fs);

    /// Parse invariants from a JSON value (array of invariant objects).
    static std::vector<Invariant> parse(const nlohmann::json& j);
};

} // namespace Aeostara
