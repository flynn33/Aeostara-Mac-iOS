// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#include "AeostaraCore/PolicyEvaluator.h"

#include <sstream>
#include <stdexcept>

namespace Aeostara {

namespace {

// Trim whitespace from both ends
std::string trim(const std::string& s) {
    auto start = s.find_first_not_of(" \t");
    if (start == std::string::npos) return "";
    auto end = s.find_last_not_of(" \t");
    return s.substr(start, end - start + 1);
}

// Parse a value string into a JSON value
nlohmann::json parseValue(const std::string& valueStr) {
    std::string v = trim(valueStr);
    if (v.empty()) return nullptr;

    // Try parsing as JSON literal
    try {
        return nlohmann::json::parse(v);
    } catch (...) {
        // If it fails, treat as a bare string
        return nlohmann::json(v);
    }
}

} // anonymous namespace

PolicyEvaluator::ParsedExpression PolicyEvaluator::parseExpression(const std::string& expression) {
    // Supported operators (check longer ones first)
    static const std::vector<std::string> operators = {
        "!=", ">=", "<=", "==", ">", "<"
    };

    for (const auto& op : operators) {
        auto pos = expression.find(op);
        if (pos != std::string::npos) {
            std::string keyPath = trim(expression.substr(0, pos));
            std::string valueStr = trim(expression.substr(pos + op.size()));
            return ParsedExpression{
                .keyPath = keyPath,
                .op = op,
                .expectedValue = parseValue(valueStr)
            };
        }
    }

    throw std::invalid_argument("Cannot parse invariant expression: " + expression);
}

bool PolicyEvaluator::evaluateExpression(const std::string& expression,
                                          const std::map<std::string, nlohmann::json>& flatState) {
    auto parsed = parseExpression(expression);

    auto it = flatState.find(parsed.keyPath);
    if (it == flatState.end()) {
        // Key does not exist — expression fails
        return false;
    }

    const auto& actual = it->second;
    const auto& expected = parsed.expectedValue;

    if (parsed.op == "==") return actual == expected;
    if (parsed.op == "!=") return actual != expected;

    // Numeric comparisons: both must be numbers
    if (actual.is_number() && expected.is_number()) {
        double a = actual.get<double>();
        double e = expected.get<double>();
        if (parsed.op == ">")  return a > e;
        if (parsed.op == "<")  return a < e;
        if (parsed.op == ">=") return a >= e;
        if (parsed.op == "<=") return a <= e;
    }

    // String comparisons for ordered operators
    if (actual.is_string() && expected.is_string()) {
        std::string a = actual.get<std::string>();
        std::string e = expected.get<std::string>();
        if (parsed.op == ">")  return a > e;
        if (parsed.op == "<")  return a < e;
        if (parsed.op == ">=") return a >= e;
        if (parsed.op == "<=") return a <= e;
    }

    return false;
}

PolicyDecision PolicyEvaluator::evaluate(const RepairPlan& plan,
                                          const std::vector<Invariant>& invariants,
                                          const std::map<std::string, nlohmann::json>& desiredFlat) const {
    (void)plan;  // Plan metadata reserved for future policy rules
    PolicyDecision decision;
    decision.allowed = true;

    for (const auto& inv : invariants) {
        bool holds = evaluateExpression(inv.expression, desiredFlat);

        if (!holds) {
            auto parsed = parseExpression(inv.expression);
            auto it = desiredFlat.find(parsed.keyPath);
            nlohmann::json actualValue = (it != desiredFlat.end()) ? it->second : nullptr;

            InvariantViolation violation{
                .invariantID = inv.invariantID,
                .keyPath = parsed.keyPath,
                .actualValue = actualValue,
                .expectedValue = parsed.expectedValue,
                .severity = inv.severity
            };

            decision.violations.push_back(violation);

            // Block if critical/high severity and not auto-remediate
            if (!inv.autoRemediate &&
                (inv.severity == InvariantSeverity::Critical ||
                 inv.severity == InvariantSeverity::High)) {
                decision.allowed = false;
                decision.reason = "Blocked by invariant: " + inv.name +
                                  " (" + inv.invariantID + ")";
            }
        }
    }

    if (decision.allowed && !decision.violations.empty()) {
        decision.reason = "Violations found but all are auto-remediable or low severity";
    }

    return decision;
}

} // namespace Aeostara
