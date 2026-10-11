// Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.
import Foundation
import AeostaraMacDomain

public final class SystemDiagnosticClock: DiagnosticClock {
    public init() {}
    public func now() -> DiagnosticTime { .init(monotonicSeconds: ProcessInfo.processInfo.systemUptime, wallUTCSeconds: Date().timeIntervalSince1970) }
}

/// Release capture has no dependency, factory or runtime switch for development capture.
public final class ReleaseDiagnosticRecorder: DiagnosticRecording, @unchecked Sendable {
    private struct Entry { let record: DiagnosticRecord; let bytes: Int; let retentionWall: Double? }
    private let lock = NSLock()
    private let limits: DiagnosticLimits
    private let clock: DiagnosticClock
    private var entries: [Entry] = []
    private var retainedBytes = 0
    private var health = DiagnosticHealth()
    private var sequence: UInt64 = 0
    private var monotonicHighWater: Double = 0
    private var wallHighWater: Double?
    private var exportLease: UUID?
    public init(limits: DiagnosticLimits = .releaseDefaults, clock: DiagnosticClock = SystemDiagnosticClock()) throws {
        guard limits.isValid && limits.isReleaseCompatible else { throw DiagnosticLimitError.invalidLimits }
        self.limits = limits; self.clock = clock
    }
    @discardableResult public func record(_ event: DiagnosticEvent, developmentDetails: (() -> DiagnosticDevelopmentDetails)?) -> UUID? {
        // This implementation never calls the developmentDetails supplier.
        lock.lock(); defer { lock.unlock() }
        guard limits.enabled else { increment(&health.disabledEvents); return nil }
        let time = sampleTime(); expire(at: time)
        guard event.counters.isValid, event.causeEventIDs.count <= 32, event.omittedInputReferences >= 0,
              !entries.contains(where: { $0.record.event.eventID == event.eventID }), sequence < UInt64.max else {
            increment(&health.invalidEvidence); return nil
        }
        var omitted = event.omittedInputReferences
        let causes = validCauses(for: event, among: entries.map { $0.record }, omitted: &omitted)
        let parent = validParent(for: event, among: entries.map { $0.record }, omitted: &omitted)
        let safeEvent = normalized(event, causes: causes, parent: parent)
        sequence += 1
        let record = DiagnosticRecord(event: safeEvent, sequence: sequence, monotonicSeconds: time.monotonicSeconds,
                                      wallUTCSeconds: time.wallUTCSeconds, omittedReferences: omitted)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard let bytes = try? encoder.encode(record) else { increment(&health.serializationFailures); return nil }
        guard bytes.count <= limits.eventBytes && bytes.count <= limits.retainedBytes else { increment(&health.droppedOversized); return nil }
        health.omittedCausalReferences = adding(health.omittedCausalReferences, UInt64(omitted))
        entries.append(.init(record: record, bytes: bytes.count, retentionWall: wallHighWater)); retainedBytes += bytes.count
        while entries.count > limits.eventCount || retainedBytes > limits.retainedBytes { evictOne() }
        return entries.contains(where: { $0.record.event.eventID == event.eventID }) ? event.eventID : nil
    }
    public func snapshot() -> DiagnosticSnapshot {
        lock.lock(); defer { lock.unlock() }; let time = sampleTime(); expire(at: time); return makeSnapshot(time: time)
    }
    public func beginExport() throws -> DiagnosticSnapshot {
        lock.lock(); defer { lock.unlock() }
        guard exportLease == nil else { throw DiagnosticLimitError.exportBusy }
        let time = sampleTime(); expire(at: time); let result = makeSnapshot(time: time)
        guard result.isValid else { increment(&health.serializationFailures); throw DiagnosticLimitError.invalidSnapshot }
        exportLease = result.snapshotID; return result
    }
    public func endExport(snapshotID: UUID, succeeded: Bool) {
        lock.lock(); defer { lock.unlock() }
        guard exportLease == snapshotID else { return }
        if !succeeded { increment(&health.exportFailures) }; exportLease = nil
    }
    public func purge() {
        lock.lock(); defer { lock.unlock() }
        health.purgedEvents = adding(health.purgedEvents, UInt64(entries.count)); entries.removeAll(keepingCapacity: false); retainedBytes = 0
    }
    private func sampleTime() -> DiagnosticTime {
        let time = clock.now()
        if time.monotonicSeconds.isFinite && (0...1_000_000_000_000).contains(time.monotonicSeconds) {
            if time.monotonicSeconds < monotonicHighWater { increment(&health.invalidEvidence) }
            monotonicHighWater = max(monotonicHighWater, time.monotonicSeconds)
        } else { increment(&health.invalidEvidence) }
        let wall = time.wallUTCSeconds.flatMap { $0.isFinite && (0...253_402_300_799).contains($0) ? $0 : nil }
        if let wall { wallHighWater = max(wallHighWater ?? wall, wall) }
        else if time.wallUTCSeconds != nil { increment(&health.invalidEvidence) }
        return .init(monotonicSeconds: monotonicHighWater, wallUTCSeconds: wall)
    }
    private func expire(at time: DiagnosticTime) {
        entries.removeAll { entry in
            let monoExpired = time.monotonicSeconds - entry.record.monotonicSeconds >= limits.ageSeconds
            let wallExpired = entry.retentionWall.flatMap { saved in wallHighWater.map { $0 - saved >= limits.ageSeconds } } ?? false
            if monoExpired || wallExpired { retainedBytes -= entry.bytes; increment(&health.expired); return true }
            return false
        }
    }
    private func evictOne() {
        guard !entries.isEmpty else { return }
        let index = entries.firstIndex { $0.record.event.incidentID == nil && $0.record.event.fault == nil && [.succeeded, .noAction].contains($0.record.event.outcome) } ?? 0
        retainedBytes -= entries.remove(at: index).bytes; increment(&health.evicted)
    }
    private func makeSnapshot(time: DiagnosticTime) -> DiagnosticSnapshot {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        var result: [DiagnosticRecord] = []; var byteCount = 0; var snapshotHealth = health
        for entry in entries {
            var omitted = 0
            let causes = validCauses(for: entry.record.event, among: result, omitted: &omitted)
            let parent = validParent(for: entry.record.event, among: result, omitted: &omitted)
            let record = DiagnosticRecord(event: normalized(entry.record.event, causes: causes, parent: parent),
                                          sequence: entry.record.sequence, monotonicSeconds: entry.record.monotonicSeconds,
                                          wallUTCSeconds: entry.record.wallUTCSeconds,
                                          omittedReferences: entry.record.omittedReferences + omitted)
            guard let bytes = try? encoder.encode(record), bytes.count <= limits.eventBytes,
                  byteCount + bytes.count <= limits.retainedBytes else { increment(&snapshotHealth.serializationFailures); continue }
            snapshotHealth.omittedCausalReferences = adding(snapshotHealth.omittedCausalReferences, UInt64(omitted))
            result.append(record); byteCount += bytes.count
        }
        return .init(profile: .release, limits: limits, generatedWallUTCSeconds: time.wallUTCSeconds,
                     records: result, retainedSerializedBytes: byteCount, health: snapshotHealth, lastAssignedSequence: sequence)
    }
    private func normalized(_ event: DiagnosticEvent, causes: [UUID], parent: UUID?) -> DiagnosticEvent {
        .init(sessionID: event.sessionID, operationID: event.operationID, incidentID: event.incidentID,
              parentOperationID: parent, component: event.component, stage: event.stage, outcome: event.outcome,
              expected: event.expected, fault: event.fault, causeEventIDs: causes, counters: event.counters, eventID: event.eventID)
    }
    private func validCauses(for event: DiagnosticEvent, among records: [DiagnosticRecord], omitted: inout Int) -> [UUID] {
        var seen = Set<UUID>()
        return event.causeEventIDs.filter { id in
            let valid = id != event.eventID && seen.insert(id).inserted && records.contains {
                $0.event.eventID == id && $0.event.sessionID == event.sessionID && $0.event.incidentID == event.incidentID
            }
            if !valid { omitted += 1 }; return valid
        }
    }
    private func validParent(for event: DiagnosticEvent, among records: [DiagnosticRecord], omitted: inout Int) -> UUID? {
        guard let parent = event.parentOperationID else { return nil }
        guard parent != event.operationID && records.contains(where: { $0.event.operationID == parent && $0.event.sessionID == event.sessionID }) else { omitted += 1; return nil }
        return parent
    }
    private func adding(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 { let value = lhs.addingReportingOverflow(rhs); return value.overflow ? UInt64.max : value.partialValue }
    private func increment(_ value: inout UInt64) { if value < UInt64.max { value += 1 } }
}
