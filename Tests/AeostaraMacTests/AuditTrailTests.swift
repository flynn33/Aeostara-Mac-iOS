// Copyright (c) 2026 James Daley. All Rights Reserved.

import XCTest
@testable import AeostaraMacDomain

final class AuditTrailTests: XCTestCase {

    func testRecordAndRetrieve() throws {
        let fs = InMemoryFileSystem()
        let audit = AuditTrail(auditPath: "/audit.jsonl", fileSystem: fs)

        let event = AuditTrail.createEvent(
            type: .noDrift,
            configFile: "/config.json",
            eventID: "event-1",
            timestamp: "2026-03-22T00:00:00Z"
        )

        try audit.record(event: event)

        let events = try audit.getEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventID, "event-1")
        XCTAssertEqual(events[0].type, .noDrift)
    }

    func testMultipleEvents() throws {
        let fs = InMemoryFileSystem()
        let audit = AuditTrail(auditPath: "/audit.jsonl", fileSystem: fs)

        for i in 1...3 {
            let event = AuditTrail.createEvent(
                type: .healStarted,
                configFile: "/config.json",
                eventID: "event-\(i)",
                timestamp: "2026-03-22T00:00:0\(i)Z"
            )
            try audit.record(event: event)
        }

        let events = try audit.getEvents()
        XCTAssertEqual(events.count, 3)
    }

    func testEmptyAuditFile() throws {
        let fs = InMemoryFileSystem()
        let audit = AuditTrail(auditPath: "/audit.jsonl", fileSystem: fs)

        let events = try audit.getEvents()
        XCTAssertTrue(events.isEmpty)
    }

    func testJSONLFormat() throws {
        let fs = InMemoryFileSystem()
        let audit = AuditTrail(auditPath: "/audit.jsonl", fileSystem: fs)

        let event = AuditTrail.createEvent(
            type: .backupCreated,
            configFile: "/config.json",
            details: ["path": AnyCodable("/backup.json")],
            eventID: "event-1",
            timestamp: "2026-03-22T00:00:00Z"
        )
        try audit.record(event: event)

        // Verify it's valid JSONL (one JSON object per line)
        let content = fs.files["/audit.jsonl"]!
        let lines = content.split(separator: "\n")
        XCTAssertEqual(lines.count, 1)

        // Each line should be valid JSON
        let data = lines[0].data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data)
        XCTAssertTrue(parsed is [String: Any])
    }
}
