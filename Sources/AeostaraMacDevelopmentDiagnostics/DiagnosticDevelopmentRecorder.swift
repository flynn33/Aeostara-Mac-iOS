// Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.
import Foundation
import AeostaraMacDomain

private final class DevelopmentClock: DiagnosticClock {
    func now() -> DiagnosticTime { .init(monotonicSeconds: ProcessInfo.processInfo.systemUptime, wallUTCSeconds: Date().timeIntervalSince1970) }
}

/// Internal producer target. This type is absent from the released SDK dependency closure.
public final class DevelopmentDiagnosticRecorder: DiagnosticRecording, @unchecked Sendable {
    private struct Stored {
        let value: DiagnosticRecord
        let size: Int
        let retentionWall: Double?
    }
    private let ownership = DispatchQueue(label: "com.aeostara.development-diagnostics")
    private let limits: DiagnosticLimits
    private let clock: DiagnosticClock
    private var stored: [Stored] = []
    private var bytes = 0
    private var health = DiagnosticHealth()
    private var sequence: UInt64 = 0
    private var highMono = 0.0
    private var highWall: Double?
    private var lease: UUID?
    public convenience init(limits: DiagnosticLimits = .developmentDefaults) throws { try self.init(limits: limits, clock: DevelopmentClock()) }
    public init(limits: DiagnosticLimits, clock: DiagnosticClock) throws {
        guard limits.isValid else { throw DiagnosticLimitError.invalidLimits }; self.limits = limits; self.clock = clock
    }
    @discardableResult public func record(_ event: DiagnosticEvent, developmentDetails: (() -> DiagnosticDevelopmentDetails)?) -> UUID? {
        guard limits.enabled else { return ownership.sync { add(&health.disabledEvents); return nil } }
        // Caller suppliers run outside owned storage, so a reentrant supplier cannot deadlock the queue.
        let detail = developmentDetails?()
        let stack = event.fault != nil || event.outcome == .failed ? safeStack() : []
        let sampled = clock.now()
        return ownership.sync {
            let time = normalizeTime(sampled); expire(time)
            guard event.counters.isValid, event.causeEventIDs.count <= 32, event.omittedInputReferences >= 0,
                  detail?.isValid ?? true, sequence < UInt64.max,
                  !stored.contains(where: { $0.value.event.eventID == event.eventID }) else { add(&health.invalidEvidence); return nil }
            var omitted = event.omittedInputReferences
            let safe = resolve(event, earlier: stored.map { $0.value }, omitted: &omitted)
            sequence += 1
            let value = DiagnosticRecord(event: safe, sequence: sequence, monotonicSeconds: time.monotonicSeconds,
                                         wallUTCSeconds: time.wallUTCSeconds, details: detail, stackFrames: stack, omittedReferences: omitted)
            guard let size = sizeOf(value) else { add(&health.serializationFailures); return nil }
            guard size <= limits.eventBytes && size <= limits.retainedBytes else { add(&health.droppedOversized); return nil }
            add(&health.omittedCausalReferences, UInt64(omitted))
            stored.append(.init(value: value, size: size, retentionWall: highWall)); bytes += size
            while stored.count > limits.eventCount || bytes > limits.retainedBytes {
                let victim = stored.firstIndex { $0.value.event.incidentID == nil && $0.value.event.fault == nil && [.succeeded, .noAction].contains($0.value.event.outcome) } ?? 0
                bytes -= stored.remove(at: victim).size; add(&health.evicted)
            }
            return stored.contains { $0.value.event.eventID == event.eventID } ? event.eventID : nil
        }
    }
    public func snapshot() -> DiagnosticSnapshot {
        let sampled = clock.now()
        return ownership.sync { let time = normalizeTime(sampled); expire(time); return frozen(time) }
    }
    public func beginExport() throws -> DiagnosticSnapshot {
        let sampled = clock.now()
        return try ownership.sync {
            guard lease == nil else { throw DiagnosticLimitError.exportBusy }
            let time = normalizeTime(sampled); expire(time); let result = frozen(time)
            guard result.isValid else { add(&health.serializationFailures); throw DiagnosticLimitError.invalidSnapshot }
            lease = result.snapshotID; return result
        }
    }
    public func endExport(snapshotID: UUID, succeeded: Bool) {
        ownership.sync { if lease == snapshotID { if !succeeded { add(&health.exportFailures) }; lease = nil } }
    }
    public func purge() {
        ownership.sync { add(&health.purgedEvents, UInt64(stored.count)); stored.removeAll(keepingCapacity: false); bytes = 0 }
    }
    private func normalizeTime(_ time: DiagnosticTime) -> DiagnosticTime {
        if time.monotonicSeconds.isFinite && (0...1_000_000_000_000).contains(time.monotonicSeconds) {
            if time.monotonicSeconds < highMono { add(&health.invalidEvidence) }; highMono = max(highMono, time.monotonicSeconds)
        } else { add(&health.invalidEvidence) }
        var wall: Double?
        if let value = time.wallUTCSeconds {
            if value.isFinite && (0...253_402_300_799).contains(value) { wall = value; highWall = max(highWall ?? value, value) }
            else { add(&health.invalidEvidence) }
        }
        return .init(monotonicSeconds: highMono, wallUTCSeconds: wall)
    }
    private func expire(_ time: DiagnosticTime) {
        stored.removeAll { record in
            if time.monotonicSeconds - record.value.monotonicSeconds >= limits.ageSeconds
                || (record.retentionWall.flatMap { saved in highWall.map { $0 - saved >= limits.ageSeconds } } ?? false) {
                bytes -= record.size; add(&health.expired); return true
            }; return false
        }
    }
    private func frozen(_ time: DiagnosticTime) -> DiagnosticSnapshot {
        var records: [DiagnosticRecord] = []; var size = 0; var stats = health
        for item in stored {
            var missing = 0
            let event = resolve(item.value.event, earlier: records, omitted: &missing)
            let record = DiagnosticRecord(event: event, sequence: item.value.sequence, monotonicSeconds: item.value.monotonicSeconds,
                                          wallUTCSeconds: item.value.wallUTCSeconds, details: item.value.details,
                                          stackFrames: item.value.stackFrames, omittedReferences: item.value.omittedReferences + missing)
            guard let encoded = sizeOf(record), encoded <= limits.eventBytes, size + encoded <= limits.retainedBytes else {
                add(&stats.serializationFailures); continue
            }
            add(&stats.omittedCausalReferences, UInt64(missing)); records.append(record); size += encoded
        }
        return .init(profile: .development, limits: limits, generatedWallUTCSeconds: time.wallUTCSeconds,
                     records: records, retainedSerializedBytes: size, health: stats, lastAssignedSequence: sequence)
    }
    private func resolve(_ event: DiagnosticEvent, earlier: [DiagnosticRecord], omitted: inout Int) -> DiagnosticEvent {
        var unique = Set<UUID>()
        let causes = event.causeEventIDs.filter { id in
            let present = unique.insert(id).inserted && earlier.contains {
                $0.event.eventID == id && $0.event.sessionID == event.sessionID && $0.event.incidentID == event.incidentID
            }
            if !present { omitted += 1 }; return present
        }
        var parent = event.parentOperationID
        if let supplied = parent, supplied == event.operationID || !earlier.contains(where: { $0.event.sessionID == event.sessionID && $0.event.operationID == supplied }) {
            parent = nil; omitted += 1
        }
        return .init(sessionID: event.sessionID, operationID: event.operationID, incidentID: event.incidentID,
                     parentOperationID: parent, component: event.component, stage: event.stage, outcome: event.outcome,
                     expected: event.expected, fault: event.fault, causeEventIDs: causes, counters: event.counters, eventID: event.eventID)
    }
    private func sizeOf(_ value: DiagnosticRecord) -> Int? {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; return (try? encoder.encode(value))?.count
    }
    private func safeStack() -> [DiagnosticStackFrame] {
        var frames: [DiagnosticStackFrame] = []
        for symbol in Thread.callStackSymbols.prefix(64) {
            let fields = symbol.split(whereSeparator: { $0.isWhitespace })
            guard fields.count >= 4, fields[fields.count - 2] == "+", let offset = UInt64(fields.last!) else { continue }
            let component: DiagnosticComponent
            switch fields[1] {
            case "AeostaraMacDomain": component = .domain
            case "AeostaraMacServices": component = .nativeServices
            case "AeostaraMacDevelopmentDiagnostics": component = .developmentDiagnostics
            default: continue
            }
            frames.append(.init(component: component, imageOffset: offset)); if frames.count == 20 { break }
        }
        return frames
    }
    private func add(_ value: inout UInt64, _ amount: UInt64 = 1) {
        let sum = value.addingReportingOverflow(amount); value = sum.overflow ? UInt64.max : sum.partialValue
    }
}
