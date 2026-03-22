// Copyright (c) 2026 James Daley. All Rights Reserved.

import XCTest
@testable import AeostaraDomain

final class RepairPlannerTests: XCTestCase {

    let planner = RepairPlanner()
    let timestamp = "2026-03-22T00:00:00Z"

    func testValueChangedProducesSetAction() {
        let drifts = [DriftEvent(
            keyPath: "server.port",
            type: .valueChanged,
            observedValue: AnyCodable(9090),
            desiredValue: AnyCodable(8080),
            description: "Value differs"
        )]
        let plan = planner.generateRepairPlan(drifts: drifts, timestamp: timestamp)
        XCTAssertEqual(plan.actions.count, 1)
        XCTAssertEqual(plan.actions[0].actionType, .set)
        XCTAssertEqual(plan.actions[0].keyPath, "server.port")
        XCTAssertTrue(plan.requiresBackup)
    }

    func testKeyAddedProducesAddAction() {
        let drifts = [DriftEvent(
            keyPath: "new.key",
            type: .keyAdded,
            observedValue: nil,
            desiredValue: AnyCodable("value"),
            description: "Key missing"
        )]
        let plan = planner.generateRepairPlan(drifts: drifts, timestamp: timestamp)
        XCTAssertEqual(plan.actions[0].actionType, .add)
    }

    func testKeyRemovedProducesRemoveAction() {
        let drifts = [DriftEvent(
            keyPath: "extra.key",
            type: .keyRemoved,
            observedValue: AnyCodable("old"),
            desiredValue: nil,
            description: "Key not in desired"
        )]
        let plan = planner.generateRepairPlan(drifts: drifts, timestamp: timestamp)
        XCTAssertEqual(plan.actions[0].actionType, .remove)
    }

    func testPlanIDIsDeterministic() {
        let drifts = [DriftEvent(
            keyPath: "server.port",
            type: .valueChanged,
            observedValue: AnyCodable(9090),
            desiredValue: AnyCodable(8080),
            description: "Value differs"
        )]
        let plan1 = planner.generateRepairPlan(drifts: drifts, timestamp: timestamp)
        let plan2 = planner.generateRepairPlan(drifts: drifts, timestamp: timestamp)
        XCTAssertEqual(plan1.planID, plan2.planID)
    }

    func testFNV1aHash() {
        let hash = FNV1a.hash64(string: "test")
        XCTAssertNotEqual(hash, 0)
        // Same input = same hash
        XCTAssertEqual(FNV1a.hash64(string: "test"), FNV1a.hash64(string: "test"))
        // Different input = different hash
        XCTAssertNotEqual(FNV1a.hash64(string: "test"), FNV1a.hash64(string: "other"))
    }
}
