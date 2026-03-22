// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

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
