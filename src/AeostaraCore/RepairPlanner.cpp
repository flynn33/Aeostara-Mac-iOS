// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#include "AeostaraCore/RepairPlanner.h"

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <iomanip>
#include <sstream>

namespace Aeostara {

namespace {

// FNV-1a 64-bit hash for deterministic plan IDs
uint64_t fnv1a(const std::string& data) {
    constexpr uint64_t FNV_OFFSET_BASIS = 14695981039346656037ULL;
    constexpr uint64_t FNV_PRIME = 1099511628211ULL;

    uint64_t hash = FNV_OFFSET_BASIS;
    for (char c : data) {
        hash ^= static_cast<uint64_t>(static_cast<unsigned char>(c));
        hash *= FNV_PRIME;
    }
    return hash;
}

} // anonymous namespace

RepairPlan RepairPlanner::createPlan(const std::vector<DriftEvent>& drifts) const {
    std::vector<RepairAction> actions;

    for (const auto& drift : drifts) {
        switch (drift.type) {
            case DriftType::ValueChanged:
                actions.push_back(RepairAction{
                    .keyPath = drift.keyPath,
                    .actionType = RepairActionType::Set,
                    .fromValue = drift.observedValue,
                    .toValue = drift.desiredValue,
                    .rationale = "Value changed: " + drift.keyPath
                });
                break;

            case DriftType::KeyAdded:
                actions.push_back(RepairAction{
                    .keyPath = drift.keyPath,
                    .actionType = RepairActionType::Add,
                    .fromValue = nullptr,
                    .toValue = drift.desiredValue,
                    .rationale = "Key added: " + drift.keyPath
                });
                break;

            case DriftType::KeyRemoved:
                // Conservative: do not remove keys. Desired state may be partial.
                break;
        }
    }

    // Sort actions by key path for determinism
    std::sort(actions.begin(), actions.end(),
              [](const RepairAction& a, const RepairAction& b) {
                  return a.keyPath < b.keyPath;
              });

    return RepairPlan{
        .planID = generatePlanID(actions),
        .actions = std::move(actions),
        .timestamp = currentTimestamp(),
        .requiresBackup = true
    };
}

std::string RepairPlanner::generatePlanID(const std::vector<RepairAction>& actions) {
    // Serialize actions to a canonical string for hashing
    std::ostringstream ss;
    for (const auto& action : actions) {
        ss << action.keyPath << "|"
           << to_string(action.actionType) << "|"
           << action.toValue.dump() << ";";
    }

    uint64_t hash = fnv1a(ss.str());

    // Format as hex string
    std::ostringstream hex;
    hex << std::hex << std::setfill('0') << std::setw(16) << hash;
    return "plan-" + hex.str();
}

std::string RepairPlanner::currentTimestamp() {
    auto now = std::chrono::system_clock::now();
    auto time_t = std::chrono::system_clock::to_time_t(now);
    std::tm tm{};
    localtime_s(&tm, &time_t);

    std::ostringstream ss;
    ss << std::put_time(&tm, "%Y-%m-%dT%H:%M:%S");
    return ss.str();
}

} // namespace Aeostara
