// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#include "AeostaraCore/JsonConfigAdapter.h"
#include "AeostaraCore/JsonPath.h"

#include <chrono>
#include <iomanip>
#include <sstream>

namespace Aeostara {

namespace {

std::string currentTimestamp() {
    auto now = std::chrono::system_clock::now();
    auto time_t = std::chrono::system_clock::to_time_t(now);
    std::tm tm{};
    localtime_s(&tm, &time_t);

    std::ostringstream ss;
    ss << std::put_time(&tm, "%Y-%m-%dT%H:%M:%S");
    return ss.str();
}

} // anonymous namespace

JsonConfigAdapter::JsonConfigAdapter(std::shared_ptr<IFileSystem> fs)
    : fs_(std::move(fs)) {}

ObservedState JsonConfigAdapter::observe(const std::string& filePath) {
    std::string content = fs_->readFile(filePath);
    nlohmann::json data = nlohmann::json::parse(content);

    return ObservedState{
        .sourceFile = filePath,
        .data = std::move(data),
        .timestamp = currentTimestamp()
    };
}

EncodedState JsonConfigAdapter::encode(const ObservedState& observed, const DesiredState& desired) {
    return EncodedState{
        .observed = JsonPath::flatten(observed.data),
        .desired = JsonPath::flatten(desired.data)
    };
}

bool JsonConfigAdapter::applyRepair(const std::string& filePath, const RepairPlan& plan) {
    try {
        std::string content = fs_->readFile(filePath);
        nlohmann::json data = nlohmann::json::parse(content);

        for (const auto& action : plan.actions) {
            switch (action.actionType) {
                case RepairActionType::Set:
                case RepairActionType::Add:
                    JsonPath::set(data, action.keyPath, action.toValue);
                    break;
                case RepairActionType::Remove:
                    // Not implemented in v0.1 (conservative approach)
                    break;
            }
        }

        // Write back with sorted keys and 2-space indent for determinism
        std::string output = data.dump(2);
        fs_->writeFile(filePath, output);
        return true;
    } catch (...) {
        return false;
    }
}

} // namespace Aeostara
