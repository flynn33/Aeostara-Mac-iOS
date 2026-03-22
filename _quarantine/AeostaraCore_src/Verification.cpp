// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#include "AeostaraCore/Verification.h"
#include "AeostaraCore/JsonPath.h"
#include "AeostaraCore/PolicyEvaluator.h"

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

VerificationResult Verifier::verify(const std::string& filePath,
                                     const DesiredState& desired,
                                     const std::vector<Invariant>& invariants,
                                     IFileSystem& fs) const {
    VerificationResult result;
    result.verifiedAt = currentTimestamp();

    // Reload the file
    std::string content;
    try {
        content = fs.readFile(filePath);
    } catch (const std::exception& e) {
        result.success = false;
        result.failedChecks.push_back(std::string("Cannot read file: ") + e.what());
        return result;
    }

    nlohmann::json reloaded;
    try {
        reloaded = nlohmann::json::parse(content);
    } catch (const std::exception& e) {
        result.success = false;
        result.failedChecks.push_back(std::string("JSON parse error: ") + e.what());
        return result;
    }

    // Flatten both reloaded and desired states
    auto reloadedFlat = JsonPath::flatten(reloaded);
    auto desiredFlat = JsonPath::flatten(desired.data);

    // Check that all desired keys have correct values
    for (const auto& [key, desiredVal] : desiredFlat) {
        auto it = reloadedFlat.find(key);
        if (it == reloadedFlat.end()) {
            result.failedChecks.push_back("Missing key after repair: " + key);
        } else if (it->second != desiredVal) {
            result.failedChecks.push_back("Value mismatch after repair: " + key +
                                           " (expected: " + desiredVal.dump() +
                                           ", got: " + it->second.dump() + ")");
        }
    }

    // Check invariants against the reloaded state
    for (const auto& inv : invariants) {
        bool holds = PolicyEvaluator::evaluateExpression(inv.expression, reloadedFlat);
        if (!holds) {
            result.failedChecks.push_back("Invariant violated: " + inv.name +
                                           " (" + inv.invariantID + ")");
        }
    }

    result.success = result.failedChecks.empty();
    return result;
}

} // namespace Aeostara
