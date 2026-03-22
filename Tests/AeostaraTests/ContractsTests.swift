// Copyright (c) 2026 James Daley. All Rights Reserved.

import XCTest
@testable import AeostaraDomain

final class ContractsTests: XCTestCase {

    func testAnyCodableStringRoundTrip() throws {
        let original = AnyCodable("hello")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        XCTAssertEqual(decoded.stringValue, "hello")
    }

    func testAnyCodableIntRoundTrip() throws {
        let original = AnyCodable(42)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        XCTAssertEqual(decoded.intValue, 42)
    }

    func testAnyCodableBoolRoundTrip() throws {
        let original = AnyCodable(true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        XCTAssertEqual(decoded.boolValue, true)
    }

    func testAnyCodableEquality() {
        XCTAssertEqual(AnyCodable("a"), AnyCodable("a"))
        XCTAssertNotEqual(AnyCodable("a"), AnyCodable("b"))
        XCTAssertEqual(AnyCodable(42), AnyCodable(42))
        XCTAssertEqual(AnyCodable(true), AnyCodable(true))
    }

    func testAnyCodableCrossTypeNumericEquality() {
        XCTAssertEqual(AnyCodable(42), AnyCodable(42.0))
    }

    func testDriftEventCodable() throws {
        let event = DriftEvent(
            keyPath: "server.port",
            type: .valueChanged,
            observedValue: AnyCodable(9090),
            desiredValue: AnyCodable(8080),
            description: "Value differs"
        )
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(DriftEvent.self, from: data)
        XCTAssertEqual(decoded.keyPath, "server.port")
        XCTAssertEqual(decoded.type, .valueChanged)
    }

    func testRepairActionCodable() throws {
        let action = RepairAction(
            keyPath: "server.port",
            actionType: .set,
            fromValue: AnyCodable(9090),
            toValue: AnyCodable(8080),
            rationale: "Restore desired port"
        )
        let data = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(RepairAction.self, from: data)
        XCTAssertEqual(decoded.actionType, .set)
    }

    func testInvariantCodableWithSnakeCase() throws {
        let json = """
        {
            "invariant_id": "INV-001",
            "name": "Test",
            "expression": "server.port == 8080",
            "severity": "Critical",
            "auto_remediate": false
        }
        """.data(using: .utf8)!
        let invariant = try JSONDecoder().decode(Invariant.self, from: json)
        XCTAssertEqual(invariant.invariantID, "INV-001")
        XCTAssertEqual(invariant.severity, .critical)
        XCTAssertFalse(invariant.autoRemediate)
    }

    func testAuditEventCodable() throws {
        let event = AuditEvent(
            eventID: "test-123",
            type: .noDrift,
            timestamp: "2026-03-22T00:00:00Z",
            configFile: "/tmp/config.json"
        )
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(AuditEvent.self, from: data)
        XCTAssertEqual(decoded.eventID, "test-123")
        XCTAssertEqual(decoded.type, .noDrift)
    }
}
