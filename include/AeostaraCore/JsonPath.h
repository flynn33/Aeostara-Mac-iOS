// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#pragma once

#include <nlohmann/json.hpp>

#include <map>
#include <string>

namespace Aeostara {

class JsonPath final {
public:
    /// Resolve a dot-separated path (e.g., "a.b.c") to a value in the JSON tree.
    /// Returns nullptr json if the path does not exist.
    static nlohmann::json get(const nlohmann::json& root, const std::string& dotPath);

    /// Set a value at a dot-separated path, creating intermediate objects as needed.
    static void set(nlohmann::json& root, const std::string& dotPath, const nlohmann::json& value);

    /// Check if a dot-separated path exists in the JSON tree.
    static bool exists(const nlohmann::json& root, const std::string& dotPath);

    /// Flatten a nested JSON object into a sorted map of dot-separated paths to values.
    /// Arrays are indexed as "key.0", "key.1", etc.
    static std::map<std::string, nlohmann::json> flatten(const nlohmann::json& root);

    /// Reconstruct a nested JSON object from a flattened dot-path map.
    static nlohmann::json unflatten(const std::map<std::string, nlohmann::json>& flat);

private:
    static void flattenRecursive(const nlohmann::json& value,
                                  const std::string& prefix,
                                  std::map<std::string, nlohmann::json>& result);
};

} // namespace Aeostara
