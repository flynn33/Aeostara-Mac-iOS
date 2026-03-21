// Aeostara Core Tests — Catch2
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#include <catch2/catch_test_macros.hpp>

#include "AeostaraCore/Contracts.h"
#include "AeostaraCore/Invariant.h"
#include "AeostaraCore/InvariantParser.h"
#include "AeostaraCore/JsonPath.h"
#include "AeostaraCore/DriftAnalyzer.h"
#include "AeostaraCore/RepairPlanner.h"
#include "AeostaraCore/PolicyEvaluator.h"
#include "AeostaraCore/BackupManager.h"
#include "AeostaraCore/Verification.h"
#include "AeostaraCore/RollbackManager.h"
#include "AeostaraCore/AuditTrail.h"
#include "AeostaraCore/JsonConfigAdapter.h"
#include "AeostaraCore/HealingEngine.h"

#include "TestHelpers.h"

#include <nlohmann/json.hpp>

using namespace Aeostara;
using namespace Aeostara::Testing;

// ===========================================================================
// Contracts Tests
// ===========================================================================
TEST_CASE("Contracts: ObservedState serialization", "[contracts]") {
    ObservedState state{"config.json", {{"key", "value"}}, "2026-01-01T00:00:00"};
    nlohmann::json j = state;
    auto round_trip = j.get<ObservedState>();
    REQUIRE(round_trip == state);
}

TEST_CASE("Contracts: DesiredState serialization", "[contracts]") {
    DesiredState state{{{"key", "value"}}, "desired.json"};
    nlohmann::json j = state;
    auto round_trip = j.get<DesiredState>();
    REQUIRE(round_trip == state);
}

TEST_CASE("Contracts: DriftEvent serialization", "[contracts]") {
    DriftEvent event{"key.path", DriftType::ValueChanged, "old", "new", "changed"};
    nlohmann::json j = event;
    auto round_trip = j.get<DriftEvent>();
    REQUIRE(round_trip == event);
}

TEST_CASE("Contracts: RepairPlan serialization", "[contracts]") {
    RepairPlan plan;
    plan.planID = "abc123";
    plan.actions = {{{"key", RepairActionType::Set, "old", "new", "fix"}}};
    plan.timestamp = "2026-01-01T00:00:00";
    plan.requiresBackup = true;
    nlohmann::json j = plan;
    auto round_trip = j.get<RepairPlan>();
    REQUIRE(round_trip == plan);
}

TEST_CASE("Contracts: AuditEvent serialization", "[contracts]") {
    AuditEvent event;
    event.eventID = "evt-001";
    event.type = AuditEventType::HealStarted;
    event.timestamp = "2026-01-01T00:00:00";
    event.configFile = "config.json";
    event.details = {{"action", "heal"}};
    nlohmann::json j = event;
    auto round_trip = j.get<AuditEvent>();
    REQUIRE(round_trip == event);
}

// ===========================================================================
// JsonPath Tests
// ===========================================================================
TEST_CASE("JsonPath: get nested value", "[jsonpath]") {
    auto data = nlohmann::json::parse(SAMPLE_CONFIG);
    auto val = JsonPath::get(data, "server.port");
    REQUIRE(val == 8080);
}

TEST_CASE("JsonPath: set creates intermediate objects", "[jsonpath]") {
    nlohmann::json data;
    JsonPath::set(data, "a.b.c", 42);
    REQUIRE(data["a"]["b"]["c"] == 42);
}

TEST_CASE("JsonPath: exists returns true for present path", "[jsonpath]") {
    auto data = nlohmann::json::parse(SAMPLE_CONFIG);
    REQUIRE(JsonPath::exists(data, "server.host"));
    REQUIRE_FALSE(JsonPath::exists(data, "server.nonexistent"));
}

TEST_CASE("JsonPath: flatten and unflatten round-trip", "[jsonpath]") {
    auto data = nlohmann::json::parse(SAMPLE_CONFIG);
    auto flat = JsonPath::flatten(data);
    auto unflat = JsonPath::unflatten(flat);
    REQUIRE(unflat == data);
}

// ===========================================================================
// InvariantParser Tests
// ===========================================================================
TEST_CASE("InvariantParser: parse from JSON string", "[invariant]") {
    auto invariants = InvariantParser::parseFromJson(
        nlohmann::json::parse(SAMPLE_INVARIANTS));
    REQUIRE(invariants.size() == 2);
    REQUIRE(invariants[0].invariantID == "INV-001");
    REQUIRE(invariants[1].severity == InvariantSeverity::Critical);
}

// ===========================================================================
// DriftAnalyzer Tests
// ===========================================================================
TEST_CASE("DriftAnalyzer: no drift when configs match", "[drift]") {
    auto observed = JsonPath::flatten(nlohmann::json::parse(SAMPLE_CONFIG));
    auto desired = JsonPath::flatten(nlohmann::json::parse(SAMPLE_DESIRED));
    EncodedState encoded{observed, desired};
    auto drifts = DriftAnalyzer::analyze(encoded);
    REQUIRE(drifts.empty());
}

TEST_CASE("DriftAnalyzer: detects value changes", "[drift]") {
    auto observed = JsonPath::flatten(nlohmann::json::parse(DRIFTED_CONFIG));
    auto desired = JsonPath::flatten(nlohmann::json::parse(SAMPLE_DESIRED));
    EncodedState encoded{observed, desired};
    auto drifts = DriftAnalyzer::analyze(encoded);
    REQUIRE_FALSE(drifts.empty());
    // Drifted: port 9090→8080, port 3306→5432, name dev→prod, level DEBUG→INFO
    REQUIRE(drifts.size() >= 3);
}

// ===========================================================================
// RepairPlanner Tests
// ===========================================================================
TEST_CASE("RepairPlanner: generates plan from drifts", "[repair]") {
    auto observed = JsonPath::flatten(nlohmann::json::parse(DRIFTED_CONFIG));
    auto desired = JsonPath::flatten(nlohmann::json::parse(SAMPLE_DESIRED));
    EncodedState encoded{observed, desired};
    auto drifts = DriftAnalyzer::analyze(encoded);
    auto plan = RepairPlanner::createPlan(drifts);
    REQUIRE_FALSE(plan.actions.empty());
    REQUIRE_FALSE(plan.planID.empty());
    REQUIRE(plan.requiresBackup);
}

TEST_CASE("RepairPlanner: deterministic plan IDs", "[repair]") {
    auto observed = JsonPath::flatten(nlohmann::json::parse(DRIFTED_CONFIG));
    auto desired = JsonPath::flatten(nlohmann::json::parse(SAMPLE_DESIRED));
    EncodedState encoded{observed, desired};
    auto drifts = DriftAnalyzer::analyze(encoded);
    auto plan1 = RepairPlanner::createPlan(drifts);
    auto plan2 = RepairPlanner::createPlan(drifts);
    REQUIRE(plan1.planID == plan2.planID);
}

// ===========================================================================
// PolicyEvaluator Tests
// ===========================================================================
TEST_CASE("PolicyEvaluator: allows valid repair", "[policy]") {
    auto desired = nlohmann::json::parse(SAMPLE_DESIRED);
    auto invariants = InvariantParser::parseFromJson(
        nlohmann::json::parse(SAMPLE_INVARIANTS));

    auto observed = JsonPath::flatten(nlohmann::json::parse(DRIFTED_CONFIG));
    auto desiredFlat = JsonPath::flatten(desired);
    EncodedState encoded{observed, desiredFlat};
    auto drifts = DriftAnalyzer::analyze(encoded);
    auto plan = RepairPlanner::createPlan(drifts);

    auto decision = PolicyEvaluator::evaluate(plan, invariants, desired);
    REQUIRE(decision.allowed);
}

TEST_CASE("PolicyEvaluator: blocks non-auto-remediate critical violation", "[policy]") {
    auto desired = nlohmann::json::parse(SAMPLE_DESIRED);
    auto invariants = InvariantParser::parseFromJson(
        nlohmann::json::parse(BLOCKING_INVARIANTS));

    auto observed = JsonPath::flatten(nlohmann::json::parse(DRIFTED_CONFIG));
    auto desiredFlat = JsonPath::flatten(desired);
    EncodedState encoded{observed, desiredFlat};
    auto drifts = DriftAnalyzer::analyze(encoded);
    auto plan = RepairPlanner::createPlan(drifts);

    auto decision = PolicyEvaluator::evaluate(plan, invariants, desired);
    REQUIRE_FALSE(decision.allowed);
    REQUIRE_FALSE(decision.violations.empty());
}

// ===========================================================================
// BackupManager Tests
// ===========================================================================
TEST_CASE("BackupManager: creates backup", "[backup]") {
    auto fs = std::make_shared<MockFileSystem>();
    fs->files["config.json"] = SAMPLE_CONFIG;
    BackupManager backup(fs);
    auto backupPath = backup.createBackup("config.json");
    REQUIRE_FALSE(backupPath.empty());
    REQUIRE(fs->fileExists(backupPath));
    REQUIRE(fs->readFile(backupPath) == SAMPLE_CONFIG);
}

TEST_CASE("BackupManager: restores backup", "[backup]") {
    auto fs = std::make_shared<MockFileSystem>();
    fs->files["config.json"] = SAMPLE_CONFIG;
    BackupManager backup(fs);
    auto backupPath = backup.createBackup("config.json");
    fs->files["config.json"] = "corrupted";
    REQUIRE(backup.restoreBackup(backupPath, "config.json"));
    REQUIRE(fs->readFile("config.json") == SAMPLE_CONFIG);
}

// ===========================================================================
// Verification Tests
// ===========================================================================
TEST_CASE("Verification: succeeds when config matches desired", "[verify]") {
    auto fs = std::make_shared<MockFileSystem>();
    fs->files["config.json"] = SAMPLE_CONFIG;
    auto desired = nlohmann::json::parse(SAMPLE_DESIRED);
    auto invariants = InvariantParser::parseFromJson(
        nlohmann::json::parse(SAMPLE_INVARIANTS));
    auto result = Verifier::verify("config.json", desired, invariants, fs);
    REQUIRE(result.success);
    REQUIRE(result.failedChecks.empty());
}

// ===========================================================================
// RollbackManager Tests
// ===========================================================================
TEST_CASE("RollbackManager: creates rollback plan", "[rollback]") {
    RepairPlan plan;
    plan.planID = "test-plan";
    auto rollback = RollbackManager::createRollbackPlan(plan, "backup.json", "config.json");
    REQUIRE(rollback.planID == "test-plan");
    REQUIRE(rollback.backupFilePath == "backup.json");
    REQUIRE(rollback.originalFilePath == "config.json");
}

// ===========================================================================
// AuditTrail Tests
// ===========================================================================
TEST_CASE("AuditTrail: records and retrieves events", "[audit]") {
    auto fs = std::make_shared<MockFileSystem>();
    JsonLinesAuditTrail audit(fs);
    AuditEvent event;
    event.type = AuditEventType::HealStarted;
    event.configFile = "config.json";
    event.details = {{"test", true}};
    audit.record(event, "audit.jsonl");
    auto events = audit.getEvents("audit.jsonl");
    REQUIRE(events.size() == 1);
    REQUIRE(events[0].type == AuditEventType::HealStarted);
}

// ===========================================================================
// JsonConfigAdapter Tests
// ===========================================================================
TEST_CASE("JsonConfigAdapter: observe reads and parses config", "[adapter]") {
    auto fs = std::make_shared<MockFileSystem>();
    fs->files["config.json"] = SAMPLE_CONFIG;
    JsonConfigAdapter adapter(fs);
    auto observed = adapter.observe("config.json");
    REQUIRE(observed.sourceFile == "config.json");
    REQUIRE(observed.data["server"]["port"] == 8080);
}

TEST_CASE("JsonConfigAdapter: encode flattens states", "[adapter]") {
    auto fs = std::make_shared<MockFileSystem>();
    fs->files["config.json"] = SAMPLE_CONFIG;
    JsonConfigAdapter adapter(fs);
    auto observed = adapter.observe("config.json");
    DesiredState desired{nlohmann::json::parse(SAMPLE_DESIRED), "desired.json"};
    auto encoded = adapter.encode(observed, desired);
    REQUIRE_FALSE(encoded.observed.empty());
    REQUIRE_FALSE(encoded.desired.empty());
}

// ===========================================================================
// HealingEngine Integration Tests — 5 Acceptance Scenarios
// ===========================================================================
TEST_CASE("Acceptance 1: Valid config, no drift", "[acceptance]") {
    auto fs = std::make_shared<MockFileSystem>();
    fs->files["config.json"] = SAMPLE_CONFIG;
    fs->files["desired.json"] = SAMPLE_DESIRED;
    fs->files["invariants.json"] = SAMPLE_INVARIANTS;

    auto adapter = std::make_shared<JsonConfigAdapter>(fs);
    auto backup = std::make_shared<BackupManager>(fs);
    HealingEngine engine(adapter, backup, fs);

    auto result = engine.validate("config.json", "desired.json", "invariants.json");
    REQUIRE(result.valid);
    REQUIRE(result.drifts.empty());
}

TEST_CASE("Acceptance 2: Invalid config, parse error", "[acceptance]") {
    auto fs = std::make_shared<MockFileSystem>();
    fs->files["config.json"] = "{ invalid json";
    fs->files["desired.json"] = SAMPLE_DESIRED;

    auto adapter = std::make_shared<JsonConfigAdapter>(fs);
    auto backup = std::make_shared<BackupManager>(fs);
    HealingEngine engine(adapter, backup, fs);

    auto result = engine.validate("config.json", "desired.json", "");
    REQUIRE_FALSE(result.valid);
    REQUIRE_FALSE(result.errors.empty());
}

TEST_CASE("Acceptance 3: Policy blocked", "[acceptance]") {
    auto fs = std::make_shared<MockFileSystem>();
    fs->files["config.json"] = DRIFTED_CONFIG;
    fs->files["desired.json"] = SAMPLE_DESIRED;
    fs->files["invariants.json"] = BLOCKING_INVARIANTS;

    auto adapter = std::make_shared<JsonConfigAdapter>(fs);
    auto backup = std::make_shared<BackupManager>(fs);
    HealingEngine engine(adapter, backup, fs);

    auto result = engine.heal("config.json", "desired.json", "invariants.json", "audit.jsonl");
    REQUIRE_FALSE(result.success);
    REQUIRE(result.message.find("olicy") != std::string::npos); // "Policy" or "policy"

    // Verify audit trail records policy block
    bool foundPolicyBlocked = false;
    for (const auto& evt : result.auditEvents) {
        if (evt.type == AuditEventType::PolicyBlocked) {
            foundPolicyBlocked = true;
            break;
        }
    }
    REQUIRE(foundPolicyBlocked);
}

TEST_CASE("Acceptance 4: Successful repair", "[acceptance]") {
    auto fs = std::make_shared<MockFileSystem>();
    fs->files["config.json"] = DRIFTED_CONFIG;
    fs->files["desired.json"] = SAMPLE_DESIRED;
    fs->files["invariants.json"] = SAMPLE_INVARIANTS;

    auto adapter = std::make_shared<JsonConfigAdapter>(fs);
    auto backup = std::make_shared<BackupManager>(fs);
    HealingEngine engine(adapter, backup, fs);

    auto result = engine.heal("config.json", "desired.json", "invariants.json", "audit.jsonl");
    REQUIRE(result.success);
    REQUIRE(result.verification.success);

    // Verify backup was created
    bool foundBackup = false;
    for (const auto& [path, _] : fs->files) {
        if (path.find(".backup.") != std::string::npos) {
            foundBackup = true;
            break;
        }
    }
    REQUIRE(foundBackup);

    // Verify config was repaired
    auto repairedData = nlohmann::json::parse(fs->readFile("config.json"));
    auto desiredData = nlohmann::json::parse(SAMPLE_DESIRED);
    REQUIRE(repairedData == desiredData);

    // Verify audit trail
    REQUIRE_FALSE(result.auditEvents.empty());
}

TEST_CASE("Acceptance 5: Forced rollback on verification failure", "[acceptance]") {
    // Use a special mock that corrupts the file after repair to force verification failure
    class CorruptingFileSystem final : public IFileSystem {
    public:
        std::map<std::string, std::string> files;
        int writeCount = 0;

        std::string readFile(const std::string& path) override {
            auto it = files.find(path);
            if (it == files.end()) throw std::runtime_error("File not found: " + path);
            return it->second;
        }

        void writeFile(const std::string& path, const std::string& content) override {
            writeCount++;
            if (path == "config.json" && writeCount >= 2) {
                // Second write to config (after repair) — write corrupted content
                // so verification fails
                files[path] = R"({"corrupted": true})";
            } else {
                files[path] = content;
            }
        }

        bool fileExists(const std::string& path) override {
            return files.find(path) != files.end();
        }

        bool copyFile(const std::string& from, const std::string& to) override {
            auto it = files.find(from);
            if (it == files.end()) return false;
            files[to] = it->second;
            return true;
        }
    };

    auto fs = std::make_shared<CorruptingFileSystem>();
    fs->files["config.json"] = DRIFTED_CONFIG;
    fs->files["desired.json"] = SAMPLE_DESIRED;
    fs->files["invariants.json"] = SAMPLE_INVARIANTS;

    auto adapter = std::make_shared<JsonConfigAdapter>(
        std::dynamic_pointer_cast<IFileSystem>(fs));
    auto backup = std::make_shared<BackupManager>(
        std::dynamic_pointer_cast<IFileSystem>(fs));
    HealingEngine engine(adapter, backup,
        std::dynamic_pointer_cast<IFileSystem>(fs));

    auto result = engine.heal("config.json", "desired.json", "invariants.json", "audit.jsonl");
    REQUIRE_FALSE(result.success);
    REQUIRE_FALSE(result.verification.success);
    REQUIRE(result.rollback.has_value());

    // Verify rollback and verification failure audit events
    bool foundVerifyFailed = false;
    bool foundRollback = false;
    for (const auto& evt : result.auditEvents) {
        if (evt.type == AuditEventType::VerificationFailed) foundVerifyFailed = true;
        if (evt.type == AuditEventType::RollbackExecuted) foundRollback = true;
    }
    REQUIRE(foundVerifyFailed);
    REQUIRE(foundRollback);
}
