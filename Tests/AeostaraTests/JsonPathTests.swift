// Copyright (c) 2026 James Daley. All Rights Reserved.

import XCTest
@testable import AeostaraDomain

final class JsonPathTests: XCTestCase {

    func testGetSimpleKey() {
        let obj: [String: Any] = ["server": ["host": "localhost", "port": 8080]]
        XCTAssertEqual(JsonPath.get(obj, dotPath: "server.host") as? String, "localhost")
        XCTAssertEqual(JsonPath.get(obj, dotPath: "server.port") as? Int, 8080)
    }

    func testGetMissingKey() {
        let obj: [String: Any] = ["server": ["host": "localhost"]]
        XCTAssertNil(JsonPath.get(obj, dotPath: "server.missing"))
        XCTAssertNil(JsonPath.get(obj, dotPath: "nonexistent.path"))
    }

    func testSetCreatesIntermediates() {
        let obj: [String: Any] = [:]
        let result = JsonPath.set(obj, dotPath: "a.b.c", value: 42)
        XCTAssertEqual(JsonPath.get(result, dotPath: "a.b.c") as? Int, 42)
    }

    func testSetOverwritesExisting() {
        let obj: [String: Any] = ["server": ["port": 8080]]
        let result = JsonPath.set(obj, dotPath: "server.port", value: 9090)
        XCTAssertEqual(JsonPath.get(result, dotPath: "server.port") as? Int, 9090)
    }

    func testRemoveKey() {
        let obj: [String: Any] = ["server": ["host": "localhost", "port": 8080]]
        let result = JsonPath.remove(obj, dotPath: "server.port")
        XCTAssertNil(JsonPath.get(result, dotPath: "server.port"))
        XCTAssertEqual(JsonPath.get(result, dotPath: "server.host") as? String, "localhost")
    }

    func testExists() {
        let obj: [String: Any] = ["server": ["host": "localhost"]]
        XCTAssertTrue(JsonPath.exists(obj, dotPath: "server.host"))
        XCTAssertFalse(JsonPath.exists(obj, dotPath: "server.missing"))
    }

    func testFlatten() {
        let obj: [String: Any] = [
            "server": ["host": "localhost", "port": 8080],
            "name": "test"
        ]
        let flat = JsonPath.flatten(obj)
        XCTAssertEqual(flat["server.host"] as? String, "localhost")
        XCTAssertEqual(flat["server.port"] as? Int, 8080)
        XCTAssertEqual(flat["name"] as? String, "test")
        XCTAssertEqual(flat.count, 3)
    }

    func testUnflatten() {
        let flat: [String: Any] = [
            "server.host": "localhost",
            "server.port": 8080,
            "name": "test"
        ]
        let obj = JsonPath.unflatten(flat)
        XCTAssertEqual((obj["server"] as? [String: Any])?["host"] as? String, "localhost")
        XCTAssertEqual((obj["server"] as? [String: Any])?["port"] as? Int, 8080)
        XCTAssertEqual(obj["name"] as? String, "test")
    }

    func testFlattenUnflattenRoundTrip() {
        let obj: [String: Any] = [
            "database": ["host": "db.example.com", "port": 5432, "name": "prod"],
            "logging": ["level": "INFO"]
        ]
        let flat = JsonPath.flatten(obj)
        let restored = JsonPath.unflatten(flat)

        XCTAssertEqual((restored["database"] as? [String: Any])?["host"] as? String, "db.example.com")
        XCTAssertEqual((restored["database"] as? [String: Any])?["port"] as? Int, 5432)
        XCTAssertEqual((restored["logging"] as? [String: Any])?["level"] as? String, "INFO")
    }
}
