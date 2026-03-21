// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#include "AeostaraCore/DriftAnalyzer.h"

namespace Aeostara {

DriftAnalyzer::DriftAnalyzer(const EncodedState& state)
    : state_(state) {}

std::vector<DriftEvent> DriftAnalyzer::analyze() const {
    std::vector<DriftEvent> drifts;

    // Keys in desired but not in observed (need to be added)
    for (const auto& [key, desiredVal] : state_.desired) {
        auto it = state_.observed.find(key);
        if (it == state_.observed.end()) {
            drifts.push_back(DriftEvent{
                .keyPath = key,
                .type = DriftType::KeyAdded,
                .observedValue = nullptr,
                .desiredValue = desiredVal,
                .description = "Key missing in observed state, present in desired"
            });
        } else if (it->second != desiredVal) {
            drifts.push_back(DriftEvent{
                .keyPath = key,
                .type = DriftType::ValueChanged,
                .observedValue = it->second,
                .desiredValue = desiredVal,
                .description = "Value differs between observed and desired"
            });
        }
    }

    // Keys in observed but not in desired (informational)
    for (const auto& [key, observedVal] : state_.observed) {
        if (state_.desired.find(key) == state_.desired.end()) {
            drifts.push_back(DriftEvent{
                .keyPath = key,
                .type = DriftType::KeyRemoved,
                .observedValue = observedVal,
                .desiredValue = nullptr,
                .description = "Key present in observed state but absent from desired"
            });
        }
    }

    return drifts;
}

bool DriftAnalyzer::hasDrift() const {
    // Quick check: if sizes differ, there is drift
    if (state_.observed.size() != state_.desired.size()) return true;

    for (const auto& [key, desiredVal] : state_.desired) {
        auto it = state_.observed.find(key);
        if (it == state_.observed.end() || it->second != desiredVal) {
            return true;
        }
    }

    return false;
}

} // namespace Aeostara
