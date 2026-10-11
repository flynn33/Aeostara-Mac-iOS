// Aeostara
// Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.

#include "AeostaraCore/InvariantParser.h"
#include "AeostaraCore/IFileSystem.h"

#include <stdexcept>

namespace Aeostara {

std::vector<Invariant> InvariantParser::parseFile(const std::string& path, IFileSystem& fs) {
    std::string content = fs.readFile(path);
    nlohmann::json j = nlohmann::json::parse(content);
    return parse(j);
}

std::vector<Invariant> InvariantParser::parse(const nlohmann::json& j) {
    if (!j.is_array()) {
        throw std::invalid_argument("Invariants file must contain a JSON array");
    }

    std::vector<Invariant> invariants;
    invariants.reserve(j.size());

    for (const auto& item : j) {
        invariants.push_back(item.get<Invariant>());
    }

    return invariants;
}

} // namespace Aeostara
