// Copyright (c) 2026 James Daley. All Rights Reserved.

import XCTest
@testable import AeostaraMacDomain

final class PolicyEvaluatorTests: XCTestCase {

    let evaluator = PolicyEvaluator()

    func testEqualityExpression() {
        let state: [String: Any] = ["server.port": 8080]
        XCTAssertTrue(evaluator.evaluateExpression("server.port == 8080", state: state))
        XCTAssertFalse(evaluator.evaluateExpression("server.port == 9090", state: state))
    }

    func testInequalityExpression() {
        let state: [String: Any] = ["server.port": 8080]
        XCTAssertTrue(evaluator.evaluateExpression("server.port != 9090", state: state))
        XCTAssertFalse(evaluator.evaluateExpression("server.port != 8080", state: state))
    }

    func testGreaterThanExpression() {
        let state: [String: Any] = ["server.port": 8080]
        XCTAssertTrue(evaluator.evaluateExpression("server.port > 80", state: state))
        XCTAssertFalse(evaluator.evaluateExpression("server.port > 9000", state: state))
    }

    func testLessThanExpression() {
        let state: [String: Any] = ["server.port": 8080]
        XCTAssertTrue(evaluator.evaluateExpression("server.port < 9000", state: state))
        XCTAssertFalse(evaluator.evaluateExpression("server.port < 80", state: state))
    }

    func testBooleanExpression() {
        let state: [String: Any] = ["server.ssl_enabled": true]
        XCTAssertTrue(evaluator.evaluateExpression("server.ssl_enabled == true", state: state))
        XCTAssertFalse(evaluator.evaluateExpression("server.ssl_enabled == false", state: state))
    }

    func testStringExpression() {
        let state: [String: Any] = ["logging.level": "INFO"]
        XCTAssertTrue(evaluator.evaluateExpression("logging.level == \"INFO\"", state: state))
        XCTAssertFalse(evaluator.evaluateExpression("logging.level == \"DEBUG\"", state: state))
    }

    func testMissingKeyReturnsFalse() {
        let state: [String: Any] = [:]
        XCTAssertFalse(evaluator.evaluateExpression("missing.key == 42", state: state))
    }

    func testCriticalNonAutoRemediateBlocks() {
        let invariant = Invariant(
            invariantID: "INV-001",
            name: "SSL Required",
            severity: .critical,
            expression: "server.ssl_enabled == true",
            autoRemediate: false
        )
        let plan = RepairPlan(planID: "test", actions: [], timestamp: "now", requiresBackup: true)
        let state: [String: AnyCodable] = [
            "server": AnyCodable(["ssl_enabled": false])
        ]

        let decision = evaluator.evaluatePolicy(plan: plan, invariants: [invariant], state: state)
        XCTAssertFalse(decision.allowed)
    }

    func testCriticalAutoRemediateDoesNotBlock() {
        let invariant = Invariant(
            invariantID: "INV-001",
            name: "Port Standard",
            severity: .critical,
            expression: "database.port == 5432",
            autoRemediate: true
        )
        let plan = RepairPlan(planID: "test", actions: [], timestamp: "now", requiresBackup: true)
        let state: [String: AnyCodable] = [
            "database": AnyCodable(["port": 3306])
        ]

        let decision = evaluator.evaluatePolicy(plan: plan, invariants: [invariant], state: state)
        XCTAssertTrue(decision.allowed)
    }

    func testCheckInvariants() {
        let invariants = [
            Invariant(invariantID: "INV-001", name: "Port Check", expression: "server.port == 8080"),
            Invariant(invariantID: "INV-002", name: "SSL Check", expression: "server.ssl_enabled == true")
        ]
        let state: [String: AnyCodable] = [
            "server.port": AnyCodable(9090),
            "server.ssl_enabled": AnyCodable(true)
        ]
        let violations = evaluator.checkInvariants(invariants, state: state)
        XCTAssertEqual(violations.count, 1)
        XCTAssertTrue(violations[0].contains("Port Check"))
    }
}
