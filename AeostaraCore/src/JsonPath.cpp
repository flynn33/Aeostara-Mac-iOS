// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#include "AeostaraCore/JsonPath.h"

#include <sstream>
#include <stdexcept>
#include <vector>

namespace Aeostara {

namespace {

std::vector<std::string> splitPath(const std::string& dotPath) {
    std::vector<std::string> parts;
    std::istringstream stream(dotPath);
    std::string part;
    while (std::getline(stream, part, '.')) {
        if (!part.empty()) {
            parts.push_back(part);
        }
    }
    return parts;
}

bool isArrayIndex(const std::string& key) {
    if (key.empty()) return false;
    for (char c : key) {
        if (c < '0' || c > '9') return false;
    }
    return true;
}

} // anonymous namespace

nlohmann::json JsonPath::get(const nlohmann::json& root, const std::string& dotPath) {
    auto parts = splitPath(dotPath);
    const nlohmann::json* current = &root;

    for (const auto& part : parts) {
        if (current->is_object()) {
            auto it = current->find(part);
            if (it == current->end()) {
                return nullptr;
            }
            current = &(*it);
        } else if (current->is_array() && isArrayIndex(part)) {
            size_t index = std::stoull(part);
            if (index >= current->size()) {
                return nullptr;
            }
            current = &(*current)[index];
        } else {
            return nullptr;
        }
    }

    return *current;
}

void JsonPath::set(nlohmann::json& root, const std::string& dotPath, const nlohmann::json& value) {
    auto parts = splitPath(dotPath);
    if (parts.empty()) return;

    nlohmann::json* current = &root;

    for (size_t i = 0; i < parts.size() - 1; ++i) {
        const auto& part = parts[i];
        const auto& nextPart = parts[i + 1];

        if (current->is_null() || (!current->is_object() && !current->is_array())) {
            if (isArrayIndex(nextPart)) {
                (*current)[part] = nlohmann::json::array();
            } else {
                (*current)[part] = nlohmann::json::object();
            }
        } else if (current->is_object()) {
            if (current->find(part) == current->end()) {
                if (isArrayIndex(nextPart)) {
                    (*current)[part] = nlohmann::json::array();
                } else {
                    (*current)[part] = nlohmann::json::object();
                }
            }
        }

        if (current->is_object()) {
            current = &(*current)[part];
        } else if (current->is_array() && isArrayIndex(part)) {
            size_t index = std::stoull(part);
            while (current->size() <= index) {
                current->push_back(nlohmann::json());
            }
            current = &(*current)[index];
        }
    }

    const auto& lastPart = parts.back();
    if (current->is_array() && isArrayIndex(lastPart)) {
        size_t index = std::stoull(lastPart);
        while (current->size() <= index) {
            current->push_back(nlohmann::json());
        }
        (*current)[index] = value;
    } else {
        (*current)[lastPart] = value;
    }
}

bool JsonPath::exists(const nlohmann::json& root, const std::string& dotPath) {
    auto parts = splitPath(dotPath);
    const nlohmann::json* current = &root;

    for (const auto& part : parts) {
        if (current->is_object()) {
            auto it = current->find(part);
            if (it == current->end()) return false;
            current = &(*it);
        } else if (current->is_array() && isArrayIndex(part)) {
            size_t index = std::stoull(part);
            if (index >= current->size()) return false;
            current = &(*current)[index];
        } else {
            return false;
        }
    }

    return true;
}

void JsonPath::flattenRecursive(const nlohmann::json& value,
                                 const std::string& prefix,
                                 std::map<std::string, nlohmann::json>& result) {
    if (value.is_object()) {
        for (auto it = value.begin(); it != value.end(); ++it) {
            std::string key = prefix.empty() ? it.key() : prefix + "." + it.key();
            flattenRecursive(it.value(), key, result);
        }
    } else if (value.is_array()) {
        for (size_t i = 0; i < value.size(); ++i) {
            std::string key = prefix + "." + std::to_string(i);
            flattenRecursive(value[i], key, result);
        }
    } else {
        result[prefix] = value;
    }
}

std::map<std::string, nlohmann::json> JsonPath::flatten(const nlohmann::json& root) {
    std::map<std::string, nlohmann::json> result;
    if (root.is_object() || root.is_array()) {
        flattenRecursive(root, "", result);
    }
    return result;
}

nlohmann::json JsonPath::unflatten(const std::map<std::string, nlohmann::json>& flat) {
    nlohmann::json root = nlohmann::json::object();
    for (const auto& [path, value] : flat) {
        set(root, path, value);
    }
    return root;
}

} // namespace Aeostara
