// Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.
import Foundation
import AeostaraDomain
import Darwin

/// Instance-owned optional telemetry. Mandatory audit is a separate service.
public final class DevelopmentDiagnosticRecorder: DiagnosticRecording {
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
    public init(limits: DiagnosticLimits = .development, clock: DiagnosticClock = SystemDiagnosticClock()) throws {
        try limits.validate()
        guard limits.profile == .development else { throw DiagnosticContractError.invalidLimits }
        self.limits = limits; self.clock = clock
    }
    @discardableResult public func record(_ event: DiagnosticEvent, developmentDetails: (() -> DiagnosticDevelopmentDetails)? = nil) -> UUID? {
        let supplied = limits.captureEnabled ? developmentDetails?() : nil
        let frames = !limits.captureEnabled || event.fault == nil ? [] : safeRecordingStack()
        lock.lock(); defer { lock.unlock() }
        let reading = clock.read()
        updateTime(reading); expire()
        guard limits.captureEnabled else { sampled &+= 1; return nil }
        do { try event.validate(); try supplied?.validate() } catch { invalid &+= 1; return nil }
        guard !events.contains(where: { $0.event.eventID == event.eventID }), sequence < UInt64.max else { invalid &+= 1; return nil }
        sequence += 1
        let record = DiagnosticRecord(event: event, sequence: sequence, wallTime: wallHigh,
            monotonicNanoseconds: monotonicHigh, clockUnavailable: validWall(reading.wallTime) ? nil : .invalidClock,
            details: supplied, detailsUnavailable: supplied == nil ? .notProvided : nil, stack: frames)
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
                details: prior.details, detailsUnavailable: prior.detailsUnavailable, stack: prior.stack, missingCauseEventIDs: missing,
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
    /// Recording-site addresses are reduced to anonymous image-relative offsets; no path, symbol, or raw address is retained.
    private func safeRecordingStack() -> [DiagnosticStackFrame] {
        var images: [UInt] = [], frames: [DiagnosticStackFrame] = []
        for number in Thread.callStackReturnAddresses.prefix(32) {
            let address = number.uintValue
            guard let pointer = UnsafeRawPointer(bitPattern: address) else { continue }
            var info = Dl_info()
            guard dladdr(pointer, &info) != 0, let basePointer = info.dli_fbase else { continue }
            let base = UInt(bitPattern: basePointer)
            guard address >= base, address - base <= 1_000_000_000 else { continue }
            if !images.contains(base) { images.append(base) }
            guard let index = images.firstIndex(of: base) else { continue }
            frames.append(.init(imageIndex: UInt16(index), imageOffset: UInt64(address - base)))
        }
        return frames
    }
    private func frozen() -> DiagnosticSnapshot {
        DiagnosticSnapshot(generatedAt: wallHigh, limits: limits, events: events,
            health: .init(dropped: dropped, oversized: oversized, expired: expired, purged: purged,
                          invalid: invalid, sampled: sampled, lostLinks: lostLinks, exportFailures: exportFailures),
            retainedBytes: eventBytes.values.reduce(0, +))
    }
}
