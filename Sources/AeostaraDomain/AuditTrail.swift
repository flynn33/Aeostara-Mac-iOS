// Copyright (c) 2026 James Daley. All Rights Reserved.
// Aeostara — Deterministic JSON Configuration Drift Detection and Healing Platform

import Foundation

/// Append-only JSON Lines (.jsonl) audit trail.
public final class AuditTrail: IAuditSink {

    private let auditPath: String
    private let fileSystem: IFileSystem

    public init(auditPath: String, fileSystem: IFileSystem) {
        self.auditPath = auditPath
        self.fileSystem = fileSystem
    }

    /// Record an audit event by appending it as a JSON line.
    public func record(event: AuditEvent) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(event)
        guard let line = String(data: data, encoding: .utf8) else {
            throw AeostaraError.auditSerializationFailed
        }
        try fileSystem.appendFile(path: auditPath, content: line + "\n")
    }

    /// Retrieve all recorded audit events from the trail.
    public func getEvents() throws -> [AuditEvent] {
        guard fileSystem.fileExists(path: auditPath) else { return [] }

        let content = try fileSystem.readFile(path: auditPath)
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)

        let decoder = JSONDecoder()
        var events: [AuditEvent] = []

        for line in lines {
            guard let data = line.data(using: .utf8) else { continue }
            let event = try decoder.decode(AuditEvent.self, from: data)
            events.append(event)
        }

        return events
    }

    /// Create an audit event with the given parameters.
    public static func createEvent(
        type: AuditEventType,
        configFile: String,
        details: [String: AnyCodable]? = nil,
        eventID: String,
        timestamp: String
    ) -> AuditEvent {
        return AuditEvent(
            eventID: eventID,
            type: type,
            timestamp: timestamp,
            configFile: configFile,
            details: details
        )
    }
}
