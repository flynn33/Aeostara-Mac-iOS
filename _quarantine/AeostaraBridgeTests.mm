// Aeostara — iOS Bridge Tests (XCTest)
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.
//
// Tests the Obj-C++ bridge layer and C++ core through the bridge.

#import <XCTest/XCTest.h>
#import "AeostaraKit.h"

#include "AeostaraCore/Contracts.h"
#include "AeostaraCore/JsonPath.h"
#include "AeostaraCore/DriftAnalyzer.h"
#include "AeostaraCore/InvariantParser.h"
#include "AeostaraCore/RepairPlanner.h"
#include "AeostaraCore/HealingEngine.h"
#include "AeostaraCore/JsonConfigAdapter.h"
#include "AeostaraCore/BackupManager.h"
#include "AeostaraCore/IFileSystem.h"

#include <nlohmann/json.hpp>
#include <map>
#include <string>

using namespace Aeostara;

// In-memory mock file system for testing
class TestMockFileSystem final : public IFileSystem {
public:
    std::map<std::string, std::string> files;

    std::string readFile(const std::string& path) override {
        auto it = files.find(path);
        if (it == files.end()) throw std::runtime_error("File not found: " + path);
        return it->second;
    }
    void writeFile(const std::string& path, const std::string& content) override {
        files[path] = content;
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

static NSString* sampleConfig = @"{"
    "\"server\":{\"host\":\"localhost\",\"port\":8080,\"ssl_enabled\":true},"
    "\"database\":{\"host\":\"db.example.com\",\"port\":5432,\"name\":\"aeostara_prod\"},"
    "\"logging\":{\"level\":\"INFO\",\"file\":\"/var/log/aeostara.log\"}}";

static NSString* sampleDesired = @"{"
    "\"server\":{\"host\":\"localhost\",\"port\":8080,\"ssl_enabled\":true},"
    "\"database\":{\"host\":\"db.example.com\",\"port\":5432,\"name\":\"aeostara_prod\"},"
    "\"logging\":{\"level\":\"INFO\",\"file\":\"/var/log/aeostara.log\"}}";

static NSString* driftedConfig = @"{"
    "\"server\":{\"host\":\"localhost\",\"port\":9090,\"ssl_enabled\":true},"
    "\"database\":{\"host\":\"db.example.com\",\"port\":3306,\"name\":\"aeostara_dev\"},"
    "\"logging\":{\"level\":\"DEBUG\",\"file\":\"/var/log/aeostara.log\"}}";

static NSString* sampleInvariants = @"["
    "{\"invariant_id\":\"INV-001\",\"name\":\"DB Port\",\"description\":\"Port must be 5432\","
    "\"severity\":\"high\",\"expression\":\"database.port == 5432\","
    "\"applies_to\":[\"database\"],\"auto_remediate\":true}]";

// ===========================================================================
// C++ Core Tests (through native API)
// ===========================================================================
@interface AeostaraCoreTests : XCTestCase
@end

@implementation AeostaraCoreTests

- (void)testJsonPathGetNestedValue {
    auto data = nlohmann::json::parse(std::string([sampleConfig UTF8String]));
    auto val = JsonPath::get(data, "server.port");
    XCTAssertEqual(val, 8080);
}

- (void)testJsonPathFlattenRoundTrip {
    auto data = nlohmann::json::parse(std::string([sampleConfig UTF8String]));
    auto flat = JsonPath::flatten(data);
    auto unflat = JsonPath::unflatten(flat);
    XCTAssertTrue(unflat == data);
}

- (void)testDriftAnalyzerNoDrift {
    auto config = nlohmann::json::parse(std::string([sampleConfig UTF8String]));
    auto desired = nlohmann::json::parse(std::string([sampleDesired UTF8String]));
    auto obsFlat = JsonPath::flatten(config);
    auto desFlat = JsonPath::flatten(desired);
    EncodedState encoded{obsFlat, desFlat};
    auto drifts = DriftAnalyzer::analyze(encoded);
    XCTAssertTrue(drifts.empty());
}

- (void)testDriftAnalyzerDetectsChanges {
    auto config = nlohmann::json::parse(std::string([driftedConfig UTF8String]));
    auto desired = nlohmann::json::parse(std::string([sampleDesired UTF8String]));
    auto obsFlat = JsonPath::flatten(config);
    auto desFlat = JsonPath::flatten(desired);
    EncodedState encoded{obsFlat, desFlat};
    auto drifts = DriftAnalyzer::analyze(encoded);
    XCTAssertTrue(drifts.size() >= 3);
}

- (void)testRepairPlannerDeterministic {
    auto config = nlohmann::json::parse(std::string([driftedConfig UTF8String]));
    auto desired = nlohmann::json::parse(std::string([sampleDesired UTF8String]));
    auto obsFlat = JsonPath::flatten(config);
    auto desFlat = JsonPath::flatten(desired);
    EncodedState encoded{obsFlat, desFlat};
    auto drifts = DriftAnalyzer::analyze(encoded);
    auto plan1 = RepairPlanner::createPlan(drifts);
    auto plan2 = RepairPlanner::createPlan(drifts);
    XCTAssertTrue(plan1.planID == plan2.planID);
}

// ===========================================================================
// Acceptance Scenario: Valid Config / No Drift
// ===========================================================================
- (void)testAcceptanceNoDrift {
    auto fs = std::make_shared<TestMockFileSystem>();
    fs->files["config.json"] = std::string([sampleConfig UTF8String]);
    fs->files["desired.json"] = std::string([sampleDesired UTF8String]);
    fs->files["invariants.json"] = std::string([sampleInvariants UTF8String]);

    auto adapter = std::make_shared<JsonConfigAdapter>(fs);
    auto backup = std::make_shared<BackupManager>(fs);
    HealingEngine engine(adapter, backup, fs);

    auto result = engine.validate("config.json", "desired.json", "invariants.json");
    XCTAssertTrue(result.valid);
    XCTAssertTrue(result.drifts.empty());
}

// ===========================================================================
// Acceptance Scenario: Successful Repair
// ===========================================================================
- (void)testAcceptanceSuccessfulRepair {
    auto fs = std::make_shared<TestMockFileSystem>();
    fs->files["config.json"] = std::string([driftedConfig UTF8String]);
    fs->files["desired.json"] = std::string([sampleDesired UTF8String]);
    fs->files["invariants.json"] = std::string([sampleInvariants UTF8String]);

    auto adapter = std::make_shared<JsonConfigAdapter>(fs);
    auto backup = std::make_shared<BackupManager>(fs);
    HealingEngine engine(adapter, backup, fs);

    auto result = engine.heal("config.json", "desired.json", "invariants.json", "audit.jsonl");
    XCTAssertTrue(result.success);
    XCTAssertTrue(result.verification.success);
    XCTAssertFalse(result.auditEvents.empty());
}

@end

// ===========================================================================
// Bridge Tests (through Obj-C++ AeostaraEngine)
// ===========================================================================
@interface AeostaraBridgeTests : XCTestCase
@end

@implementation AeostaraBridgeTests

- (void)testBridgeInitializes {
    AeostaraEngine *engine = [[AeostaraEngine alloc] init];
    XCTAssertNotNil(engine);
}

- (void)testBridgeValidateWithMissingFile {
    AeostaraEngine *engine = [[AeostaraEngine alloc] init];
    NSError *error = nil;
    NSDictionary *result = [engine validateConfig:@"/nonexistent/config.json"
                                      desiredPath:@"/nonexistent/desired.json"
                                   invariantsPath:nil
                                            error:&error];
    // Should return nil with error for missing files
    XCTAssertNil(result);
    XCTAssertNotNil(error);
}

- (void)testBridgeValidateWithRealFiles {
    // Write test files to a temp directory
    NSString *tempDir = NSTemporaryDirectory();
    NSString *configPath = [tempDir stringByAppendingPathComponent:@"test_config.json"];
    NSString *desiredPath = [tempDir stringByAppendingPathComponent:@"test_desired.json"];

    [sampleConfig writeToFile:configPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [sampleDesired writeToFile:desiredPath atomically:YES encoding:NSUTF8StringEncoding error:nil];

    AeostaraEngine *engine = [[AeostaraEngine alloc] init];
    NSError *error = nil;
    NSDictionary *result = [engine validateConfig:configPath
                                      desiredPath:desiredPath
                                   invariantsPath:nil
                                            error:&error];

    XCTAssertNotNil(result);
    XCTAssertNil(error);
    XCTAssertTrue([result[@"valid"] boolValue]);

    // Cleanup
    [[NSFileManager defaultManager] removeItemAtPath:configPath error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:desiredPath error:nil];
}

- (void)testBridgeDiffWithDrift {
    NSString *tempDir = NSTemporaryDirectory();
    NSString *configPath = [tempDir stringByAppendingPathComponent:@"test_drifted.json"];
    NSString *desiredPath = [tempDir stringByAppendingPathComponent:@"test_desired.json"];

    [driftedConfig writeToFile:configPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [sampleDesired writeToFile:desiredPath atomically:YES encoding:NSUTF8StringEncoding error:nil];

    AeostaraEngine *engine = [[AeostaraEngine alloc] init];
    NSError *error = nil;
    NSDictionary *result = [engine diffConfig:configPath
                                  desiredPath:desiredPath
                               invariantsPath:nil
                                        error:&error];

    XCTAssertNotNil(result);
    XCTAssertNil(error);
    XCTAssertTrue([result[@"driftCount"] integerValue] > 0);

    // Cleanup
    [[NSFileManager defaultManager] removeItemAtPath:configPath error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:desiredPath error:nil];
}

- (void)testBridgeHealWithAudit {
    NSString *tempDir = NSTemporaryDirectory();
    NSString *configPath = [tempDir stringByAppendingPathComponent:@"test_heal.json"];
    NSString *desiredPath = [tempDir stringByAppendingPathComponent:@"test_desired_heal.json"];
    NSString *auditPath = [tempDir stringByAppendingPathComponent:@"test_audit.jsonl"];

    [driftedConfig writeToFile:configPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [sampleDesired writeToFile:desiredPath atomically:YES encoding:NSUTF8StringEncoding error:nil];

    AeostaraEngine *engine = [[AeostaraEngine alloc] init];
    NSError *error = nil;
    NSDictionary *result = [engine healConfig:configPath
                                  desiredPath:desiredPath
                               invariantsPath:nil
                                    auditPath:auditPath
                                        error:&error];

    XCTAssertNotNil(result);
    XCTAssertNil(error);
    XCTAssertTrue([result[@"success"] boolValue]);

    // Verify audit file was created
    BOOL auditExists = [[NSFileManager defaultManager] fileExistsAtPath:auditPath];
    XCTAssertTrue(auditExists);

    // Cleanup
    [[NSFileManager defaultManager] removeItemAtPath:configPath error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:desiredPath error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:auditPath error:nil];
}

@end
