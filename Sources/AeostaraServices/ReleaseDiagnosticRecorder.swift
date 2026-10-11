// Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.
import Foundation
import AeostaraDomain

/// Instance-owned optional telemetry. Mandatory audit is a separate service.
public final class ReleaseDiagnosticRecorder: DiagnosticRecording {
    private let lock = NSLock()
    private let limits: DiagnosticLimits
    private let clock: DiagnosticClock
    private var events: [DiagnosticRecord] = []
    private var eventBytes: [UUID: Int] = [:]
    private var sequence: UInt64 = 0
    private var dropped: UInt64 = 0, oversized: UInt64 = 0, expired: UInt64 = 0, purged: UInt64 = 0
    private var invalid: UInt64 = 0, sampled: UInt64 = 0, lostLinks: UInt64 = 0, exportFailures: UInt64 = 0
    private var wallHigh: Date?, monotonicHigh: UInt64?
    private var activeExport: UUID?
    public init(limits: DiagnosticLimits = .release, clock: DiagnosticClock = SystemDiagnosticClock()) throws {
        try limits.validate()
        guard limits.profile == .release else { throw DiagnosticContractError.invalidLimits }
        self.limits = limits; self.clock = clock
    }
    @discardableResult public func record(_ event: DiagnosticEvent, developmentDetails: (() -> DiagnosticDevelopmentDetails)? = nil) -> UUID? {
        // The supplier is deliberately never called by this implementation.
        lock.lock(); defer { lock.unlock() }
        let reading = clock.read()
        updateTime(reading); expire()
        guard limits.captureEnabled else { sampled &+= 1; return nil }
        let importantStages: Set<DiagnosticStage> = [.policy, .backup, .mutate, .verify, .rollback, .fallback, .containment, .safeHalt, .audit, .export]
        guard event.fault != nil || event.incidentID != nil || importantStages.contains(event.stage) ||
              [.failed, .blocked, .contained, .halted, .unavailable].contains(event.outcome) else { sampled &+= 1; return nil }
        do { try event.validate() } catch { invalid &+= 1; return nil }
        guard !events.contains(where: { $0.event.eventID == event.eventID }), sequence < UInt64.max else { invalid &+= 1; return nil }
        sequence += 1
        let record = DiagnosticRecord(event: event, sequence: sequence, wallTime: wallHigh,
            monotonicNanoseconds: monotonicHigh, clockUnavailable: validWall(reading.wallTime) ? nil : .invalidClock,
            details: nil, detailsUnavailable: .developmentExcluded)
        guard let size = try? DiagnosticCoding.encoder().encode(record).count else { invalid &+= 1; return nil }
        guard size <= limits.maximumEventBytes else { oversized &+= 1; return nil }
        events.append(record); eventBytes[event.eventID] = size; rebalance()
        return events.contains(where: { $0.event.eventID == event.eventID }) ? event.eventID : nil
    }
    public func snapshot() -> DiagnosticSnapshot {
        lock.lock(); defer { lock.unlock() }; let reading = clock.read()
        updateTime(reading); expire(); rebalance(); return frozen()
    }
    public func beginExport() throws -> DiagnosticSnapshot {
        lock.lock(); defer { lock.unlock() }; let reading = clock.read()
        guard activeExport == nil else { throw DiagnosticContractError.exportAlreadyActive }
        updateTime(reading); expire(); rebalance()
        let snapshot = frozen(); activeExport = snapshot.snapshotID; return snapshot
    }
    public func endExport(snapshotID: UUID, succeeded: Bool) {
        lock.lock(); defer { lock.unlock() }
        guard activeExport == snapshotID else { return }
        activeExport = nil; if !succeeded { exportFailures &+= 1 }
    }
    public func purge() {
        lock.lock(); defer { lock.unlock() }
        purged &+= UInt64(events.count); events.removeAll(keepingCapacity: false); eventBytes.removeAll(keepingCapacity: false)
    }
    private func validWall(_ date: Date) -> Bool { date.timeIntervalSince1970.isFinite && abs(date.timeIntervalSince1970) < 253_402_300_800 }
    private func updateTime(_ reading: DiagnosticClockReading) {
        if validWall(reading.wallTime) { wallHigh = max(wallHigh ?? reading.wallTime, reading.wallTime) }
        else { invalid &+= 1 }
        monotonicHigh = max(monotonicHigh ?? reading.monotonicNanoseconds, reading.monotonicNanoseconds)
    }
    private func expire() {
        events.removeAll { record in
            let wallAge = wallHigh.flatMap { now in record.wallTime.map { now.timeIntervalSince($0) } } ?? 0
            let monotonicAge = monotonicHigh.flatMap { now in record.monotonicNanoseconds.map { Double(now - min(now, $0)) / 1_000_000_000 } } ?? 0
            let remove = max(wallAge, monotonicAge) >= limits.maximumAgeSeconds
            if remove { expired &+= 1; eventBytes.removeValue(forKey: record.event.eventID) }; return remove
        }
    }
    private func repairLinks() {
        var seen = Set<UUID>(), operations = Set<UUID>()
        events = events.map { prior in
            let missing = prior.event.causeEventIDs.filter { !seen.contains($0) }
            let parentMissing = prior.event.parentOperationID.map { !operations.contains($0) } ?? false
            lostLinks &+= UInt64(Set(missing).subtracting(prior.missingCauseEventIDs).count)
            if parentMissing && prior.parentUnavailable == nil { lostLinks &+= 1 }
            seen.insert(prior.event.eventID); operations.insert(prior.event.operationID)
            if missing == prior.missingCauseEventIDs && parentMissing == (prior.parentUnavailable != nil) { return prior }
            let adjusted = DiagnosticRecord(event: prior.event, sequence: prior.sequence, wallTime: prior.wallTime,
                monotonicNanoseconds: prior.monotonicNanoseconds, clockUnavailable: prior.clockUnavailable,
                details: nil, detailsUnavailable: .developmentExcluded, missingCauseEventIDs: missing,
                parentUnavailable: parentMissing ? .earlierEvidenceNotRetained : nil)
            eventBytes[prior.event.eventID] = (try? DiagnosticCoding.encoder().encode(adjusted).count) ?? Int.max
            return adjusted
        }
    }
    private func rebalance() {
        repairLinks()
        while !events.isEmpty {
            let sizes = events.map { eventBytes[$0.event.eventID] ?? Int.max }
            if let tooLarge = sizes.firstIndex(where: { $0 > limits.maximumEventBytes }) {
                eventBytes.removeValue(forKey: events[tooLarge].event.eventID); events.remove(at: tooLarge); oversized &+= 1; repairLinks(); continue
            }
            guard events.count > limits.maximumEvents || sizes.reduce(0, +) > limits.maximumRetainedBytes else { break }
            let index = events.firstIndex { $0.event.incidentID == nil && $0.event.fault == nil && [.succeeded, .noAction].contains($0.event.outcome) } ?? 0
            eventBytes.removeValue(forKey: events[index].event.eventID); events.remove(at: index); dropped &+= 1; repairLinks()
        }
    }
    private func frozen() -> DiagnosticSnapshot {
        DiagnosticSnapshot(generatedAt: wallHigh, limits: limits, events: events,
            health: .init(dropped: dropped, oversized: oversized, expired: expired, purged: purged,
                          invalid: invalid, sampled: sampled, lostLinks: lostLinks, exportFailures: exportFailures),
            retainedBytes: eventBytes.values.reduce(0, +))
    }
}
