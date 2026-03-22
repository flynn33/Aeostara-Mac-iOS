// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#include "AeostaraCore/HealingEngine.h"
#include "AeostaraCore/AuditTrail.h"
#include "AeostaraCore/DriftAnalyzer.h"
#include "AeostaraCore/InvariantParser.h"
#include "AeostaraCore/PolicyEvaluator.h"
#include "AeostaraCore/RepairPlanner.h"
#include "AeostaraCore/RollbackManager.h"
#include "AeostaraCore/Verification.h"

namespace Aeostara {

HealingEngine::HealingEngine(std::shared_ptr<IConfigAdapter> adapter,
                               std::shared_ptr<IBackupProvider> backup,
                               std::shared_ptr<IFileSystem> fs)
    : adapter_(std::move(adapter))
    , backup_(std::move(backup))
    , fs_(std::move(fs)) {}

DesiredState HealingEngine::loadDesired(const std::string& desiredPath) const {
    std::string content = fs_->readFile(desiredPath);
    nlohmann::json data = nlohmann::json::parse(content);
    return DesiredState{.data = std::move(data), .source = desiredPath};
}

std::vector<Invariant> HealingEngine::loadInvariants(const std::string& invariantsPath) const {
    if (invariantsPath.empty()) return {};
    try {
        return InvariantParser::parseFile(invariantsPath, *fs_);
    } catch (...) {
        return {};
    }
}

// ---------------------------------------------------------------------------
// validate: Steps 1-7
// ---------------------------------------------------------------------------
IHealingEngine::ValidationResult HealingEngine::validate(
    const std::string& configPath,
    const std::string& desiredPath,
    const std::string& invariantsPath)
{
    ValidationResult result;

    // Step 1: Load config
    ObservedState observed;
    try {
        observed = adapter_->observe(configPath);
    } catch (const std::exception& e) {
        result.valid = false;
        result.errors.push_back(std::string("Cannot load config: ") + e.what());
        return result;
    }

    // Step 2: Load desired state
    DesiredState desired;
    try {
        desired = loadDesired(desiredPath);
    } catch (const std::exception& e) {
        result.valid = false;
        result.errors.push_back(std::string("Cannot load desired state: ") + e.what());
        return result;
    }

    // Step 3: Load invariants
    auto invariants = loadInvariants(invariantsPath);

    // Step 4-5: Encode both states
    auto encoded = adapter_->encode(observed, desired);

    // Step 6: Analyze drift
    DriftAnalyzer analyzer(encoded);
    result.drifts = analyzer.analyze();
    result.valid = !analyzer.hasDrift();

    // Check invariants against observed state
    for (const auto& inv : invariants) {
        bool holds = PolicyEvaluator::evaluateExpression(inv.expression, encoded.observed);
        if (!holds) {
            auto parsed = PolicyEvaluator::parseExpression(inv.expression);
            auto it = encoded.observed.find(parsed.keyPath);
            nlohmann::json actualValue = (it != encoded.observed.end()) ? it->second : nullptr;

            result.violations.push_back(InvariantViolation{
                .invariantID = inv.invariantID,
                .keyPath = parsed.keyPath,
                .actualValue = actualValue,
                .expectedValue = parsed.expectedValue,
                .severity = inv.severity
            });
        }
    }

    return result;
}

// ---------------------------------------------------------------------------
// diff: Steps 1-8
// ---------------------------------------------------------------------------
IHealingEngine::DiffResult HealingEngine::diff(
    const std::string& configPath,
    const std::string& desiredPath,
    const std::string& invariantsPath)
{
    auto observed = adapter_->observe(configPath);
    auto desired = loadDesired(desiredPath);
    auto invariants = loadInvariants(invariantsPath);
    auto encoded = adapter_->encode(observed, desired);

    DriftAnalyzer analyzer(encoded);
    auto drifts = analyzer.analyze();

    RepairPlanner planner;
    auto plan = planner.createPlan(drifts);

    return DiffResult{
        .drifts = std::move(drifts),
        .proposedPlan = std::move(plan)
    };
}

// ---------------------------------------------------------------------------
// heal: Steps 1-15 (full healing flow)
// ---------------------------------------------------------------------------
IHealingEngine::HealResult HealingEngine::heal(
    const std::string& configPath,
    const std::string& desiredPath,
    const std::string& invariantsPath,
    const std::string& auditPath)
{
    HealResult result;
    auto audit = std::make_shared<JsonLinesAuditTrail>(auditPath, fs_);

    // Step 1: Load config
    ObservedState observed;
    try {
        observed = adapter_->observe(configPath);
    } catch (const std::exception& e) {
        result.success = false;
        result.message = std::string("Cannot load config: ") + e.what();
        return result;
    }

    // Step 2: Load desired state
    DesiredState desired;
    try {
        desired = loadDesired(desiredPath);
    } catch (const std::exception& e) {
        result.success = false;
        result.message = std::string("Cannot load desired state: ") + e.what();
        return result;
    }

    // Step 3: Load invariants
    auto invariants = loadInvariants(invariantsPath);

    // Step 4-5: Encode states
    auto encoded = adapter_->encode(observed, desired);

    // Step 6: Analyze drift
    DriftAnalyzer analyzer(encoded);
    if (!analyzer.hasDrift()) {
        auto evt = JsonLinesAuditTrail::createEvent(
            AuditEventType::NoDrift, configPath,
            {{"message", "No drift detected"}});
        audit->record(evt);
        result.auditEvents.push_back(evt);
        result.success = true;
        result.message = "No drift detected";
        return result;
    }

    auto drifts = analyzer.analyze();

    // Step 7-8: Generate repair plan
    RepairPlanner planner;
    result.executedPlan = planner.createPlan(drifts);

    // Step 9: Evaluate policy
    PolicyEvaluator evaluator;
    auto policyDecision = evaluator.evaluate(result.executedPlan, invariants, encoded.desired);

    // Step 10: If blocked, stop
    if (!policyDecision.allowed) {
        auto evt = JsonLinesAuditTrail::createEvent(
            AuditEventType::PolicyBlocked, configPath,
            {{"reason", policyDecision.reason},
             {"planID", result.executedPlan.planID}});
        audit->record(evt);
        result.auditEvents.push_back(evt);
        result.success = false;
        result.message = "Policy blocked: " + policyDecision.reason;
        return result;
    }

    // Record heal started
    auto healStartEvt = JsonLinesAuditTrail::createEvent(
        AuditEventType::HealStarted, configPath,
        {{"planID", result.executedPlan.planID},
         {"actionCount", result.executedPlan.actions.size()}});
    audit->record(healStartEvt);
    result.auditEvents.push_back(healStartEvt);

    // Step 11: Create backup
    std::string backupPath = backup_->createBackup(configPath);

    auto backupEvt = JsonLinesAuditTrail::createEvent(
        AuditEventType::BackupCreated, configPath,
        {{"backupPath", backupPath}});
    audit->record(backupEvt);
    result.auditEvents.push_back(backupEvt);

    // Step 12: Apply repair
    bool applied = adapter_->applyRepair(configPath, result.executedPlan);
    if (!applied) {
        // Rollback on apply failure
        RollbackManager rollbackMgr(backup_);
        auto rollbackPlan = RollbackManager::createRollbackPlan(
            result.executedPlan.planID, backupPath, configPath);
        rollbackMgr.executeRollback(rollbackPlan);
        result.rollback = rollbackPlan;

        auto rollbackEvt = JsonLinesAuditTrail::createEvent(
            AuditEventType::RollbackExecuted, configPath,
            {{"reason", "Repair apply failed"},
             {"planID", result.executedPlan.planID}});
        audit->record(rollbackEvt);
        result.auditEvents.push_back(rollbackEvt);

        result.success = false;
        result.message = "Repair apply failed, rolled back";
        return result;
    }

    auto repairEvt = JsonLinesAuditTrail::createEvent(
        AuditEventType::RepairApplied, configPath,
        {{"planID", result.executedPlan.planID}});
    audit->record(repairEvt);
    result.auditEvents.push_back(repairEvt);

    // Step 13: Verify
    Verifier verifier;
    result.verification = verifier.verify(configPath, desired, invariants, *fs_);

    // Step 14: If verification succeeds
    if (result.verification.success) {
        auto successEvt = JsonLinesAuditTrail::createEvent(
            AuditEventType::VerificationSucceeded, configPath,
            {{"planID", result.executedPlan.planID}});
        audit->record(successEvt);
        result.auditEvents.push_back(successEvt);

        result.success = true;
        result.message = "Repair applied and verified successfully";
        return result;
    }

    // Step 15: Rollback on verification failure
    auto verFailEvt = JsonLinesAuditTrail::createEvent(
        AuditEventType::VerificationFailed, configPath,
        {{"planID", result.executedPlan.planID},
         {"failedChecks", result.verification.failedChecks}});
    audit->record(verFailEvt);
    result.auditEvents.push_back(verFailEvt);

    RollbackManager rollbackMgr(backup_);
    auto rollbackPlan = RollbackManager::createRollbackPlan(
        result.executedPlan.planID, backupPath, configPath);
    rollbackMgr.executeRollback(rollbackPlan);
    result.rollback = rollbackPlan;

    auto rollbackEvt = JsonLinesAuditTrail::createEvent(
        AuditEventType::RollbackExecuted, configPath,
        {{"reason", "Verification failed"},
         {"planID", result.executedPlan.planID}});
    audit->record(rollbackEvt);
    result.auditEvents.push_back(rollbackEvt);

    result.success = false;
    result.message = "Verification failed, rolled back to backup";
    return result;
}

} // namespace Aeostara
