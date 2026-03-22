// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#include "CLIRunner.h"

#include <iostream>

namespace Aeostara {

CLIRunner::CLIRunner(std::shared_ptr<IHealingEngine> engine)
    : engine_(std::move(engine)) {}

int CLIRunner::run(const ParsedCommand& cmd) const {
    if (cmd.command == "validate") return runValidate(cmd);
    if (cmd.command == "diff")     return runDiff(cmd);
    if (cmd.command == "heal")     return runHeal(cmd);

    std::cerr << "Unknown command: " << cmd.command << "\n";
    return 2;
}

int CLIRunner::runValidate(const ParsedCommand& cmd) const {
    try {
        auto result = engine_->validate(
            cmd.configPath, cmd.desiredPath, cmd.invariantsPath);

        nlohmann::json output;
        output["command"] = "validate";
        output["configFile"] = cmd.configPath;
        output["valid"] = result.valid;

        if (!result.errors.empty()) {
            output["errors"] = result.errors;
        }

        if (!result.drifts.empty()) {
            output["driftCount"] = result.drifts.size();
            nlohmann::json driftsJson = nlohmann::json::array();
            for (const auto& d : result.drifts) {
                driftsJson.push_back(nlohmann::json(d));
            }
            output["drifts"] = driftsJson;
        }

        if (!result.violations.empty()) {
            output["violationCount"] = result.violations.size();
            nlohmann::json violationsJson = nlohmann::json::array();
            for (const auto& v : result.violations) {
                violationsJson.push_back(nlohmann::json(v));
            }
            output["violations"] = violationsJson;
        }

        std::cout << output.dump(2) << "\n";

        if (!result.valid) {
            std::cerr << "Drift detected: " << result.drifts.size() << " difference(s)\n";
            return 1;
        }

        std::cerr << "Valid: no drift detected\n";
        return 0;

    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << "\n";
        return 2;
    }
}

int CLIRunner::runDiff(const ParsedCommand& cmd) const {
    try {
        auto result = engine_->diff(
            cmd.configPath, cmd.desiredPath, cmd.invariantsPath);

        nlohmann::json output;
        output["command"] = "diff";
        output["configFile"] = cmd.configPath;
        output["driftCount"] = result.drifts.size();

        nlohmann::json driftsJson = nlohmann::json::array();
        for (const auto& d : result.drifts) {
            driftsJson.push_back(nlohmann::json(d));
        }
        output["drifts"] = driftsJson;

        output["proposedPlan"] = nlohmann::json(result.proposedPlan);

        std::cout << output.dump(2) << "\n";

        if (result.drifts.empty()) {
            std::cerr << "No drift detected\n";
            return 0;
        }

        std::cerr << "Drift detected: " << result.drifts.size()
                  << " difference(s), "
                  << result.proposedPlan.actions.size() << " repair action(s)\n";
        return 1;

    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << "\n";
        return 2;
    }
}

int CLIRunner::runHeal(const ParsedCommand& cmd) const {
    try {
        auto result = engine_->heal(
            cmd.configPath, cmd.desiredPath, cmd.invariantsPath, cmd.auditPath);

        nlohmann::json output;
        output["command"] = "heal";
        output["configFile"] = cmd.configPath;
        output["success"] = result.success;
        output["message"] = result.message;

        if (!result.executedPlan.actions.empty()) {
            output["plan"] = nlohmann::json(result.executedPlan);
        }

        output["verification"] = nlohmann::json(result.verification);

        if (result.rollback.has_value()) {
            output["rollback"] = nlohmann::json(result.rollback.value());
        }

        nlohmann::json eventsJson = nlohmann::json::array();
        for (const auto& e : result.auditEvents) {
            eventsJson.push_back(nlohmann::json(e));
        }
        output["auditEvents"] = eventsJson;

        std::cout << output.dump(2) << "\n";

        if (result.success) {
            std::cerr << "Heal successful: " << result.message << "\n";
            return 0;
        }

        std::cerr << "Heal failed: " << result.message << "\n";
        return 1;

    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << "\n";
        return 2;
    }
}

} // namespace Aeostara
