// Copyright (c) 2026 James Daley. All Rights Reserved.

import XCTest
@testable import AeostaraDomain

final class DriftAnalyzerTests: XCTestCase {

    let analyzer = DriftAnalyzer()

    func testNoDrift() {
        let encoded = EncodedState(
            observed: ["server.port": AnyCodable(8080), "server.host": AnyCodable("localhost")],
            desired: ["server.port": AnyCodable(8080), "server.host": AnyCodable("localhost")]
        )
        let drifts = analyzer.analyzeDrift(encoded: encoded)
        XCTAssertTrue(drifts.isEmpty)
        XCTAssertFalse(analyzer.hasDrift(encoded: encoded))
    }

    func testValueChanged() {
        let encoded = EncodedState(
            observed: ["server.port": AnyCodable(9090)],
            desired: ["server.port": AnyCodable(8080)]
        )
        let drifts = analyzer.analyzeDrift(encoded: encoded)
        XCTAssertEqual(drifts.count, 1)
        XCTAssertEqual(drifts[0].type, .valueChanged)
        XCTAssertEqual(drifts[0].keyPath, "server.port")
    }

    func testKeyAdded() {
        let encoded = EncodedState(
            observed: [:],
            desired: ["server.port": AnyCodable(8080)]
        )
        let drifts = analyzer.analyzeDrift(encoded: encoded)
        XCTAssertEqual(drifts.count, 1)
        XCTAssertEqual(drifts[0].type, .keyAdded)
    }

    func testKeyRemoved() {
        let encoded = EncodedState(
            observed: ["server.port": AnyCodable(8080)],
            desired: [:]
        )
        let drifts = analyzer.analyzeDrift(encoded: encoded)
        XCTAssertEqual(drifts.count, 1)
        XCTAssertEqual(drifts[0].type, .keyRemoved)
    }

    func testMultipleDrifts() {
        let encoded = EncodedState(
            observed: [
                "server.port": AnyCodable(9090),
                "server.host": AnyCodable("localhost"),
                "extra.key": AnyCodable("remove-me")
            ],
            desired: [
                "server.port": AnyCodable(8080),
                "server.host": AnyCodable("localhost"),
                "new.key": AnyCodable("add-me")
            ]
        )
        let drifts = analyzer.analyzeDrift(encoded: encoded)
        XCTAssertEqual(drifts.count, 3) // ValueChanged + KeyRemoved + KeyAdded

        let types = Set(drifts.map { $0.type })
        XCTAssertTrue(types.contains(.valueChanged))
        XCTAssertTrue(types.contains(.keyRemoved))
        XCTAssertTrue(types.contains(.keyAdded))
    }
}
