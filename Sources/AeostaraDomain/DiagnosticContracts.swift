// Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.
import Foundation

public enum DiagnosticProfile: String, Codable { case development, release }
public enum DiagnosticComponent: String, Codable { case domain, services, exporter, composition }
public enum DiagnosticStage: String, Codable, CaseIterable {
    case initialize, observe, normalize, project, diagnose, classify, recoverability, plan, policy
    case backup, mutate, verify, rollback, fallback, containment, safeHalt, audit, export
}
public enum DiagnosticOutcome: String, Codable {
    case started, succeeded, failed, blocked, unavailable, noAction, rolledBack, contained, halted
}
public enum DiagnosticFaultCode: String, Codable {
    case mapping, policy, backup, audit, execution, verification, rollback, staleSnapshot
    case scopeViolation, invalidContract, export, internalFailure
}
public enum DiagnosticNativeDomain: String, Codable { case posix, cocoa, url }
public enum DiagnosticUnavailableReason: String, Codable {
    case notProvided, privacyExcluded, unrecognizedNativeDomain, sourcePackageProvenanceUnavailable
    case symbolicationUnavailable, captureDisabled, developmentExcluded, invalidClock, earlierEvidenceNotRetained
}
public enum DiagnosticContractError: Error { case invalidLimits, invalidSnapshot, exportAlreadyActive }

public struct DiagnosticNativeCode: Codable, Equatable {
    public let domain: DiagnosticNativeDomain
    public let code: Int32
    public init(domain: DiagnosticNativeDomain, code: Int32) { self.domain = domain; self.code = code }
}
public struct DiagnosticFault: Codable, Equatable {
    public let code: DiagnosticFaultCode
    public let nativeCode: DiagnosticNativeCode?
    public let nativeCodeUnavailable: DiagnosticUnavailableReason?
    public let messageUnavailable: DiagnosticUnavailableReason
    public init(code: DiagnosticFaultCode, nativeCode: DiagnosticNativeCode? = nil,
                nativeCodeUnavailable: DiagnosticUnavailableReason? = .notProvided) {
        self.code = code; self.nativeCode = nativeCode
        self.nativeCodeUnavailable = nativeCode == nil ? (nativeCodeUnavailable ?? .notProvided) : nil
        self.messageUnavailable = .privacyExcluded
    }
    /// Retains only a closed native domain and numeric code. userInfo and descriptions are never read.
    public init(code: DiagnosticFaultCode, error: NSError) {
        self.code = code; self.messageUnavailable = .privacyExcluded
        let domain: DiagnosticNativeDomain?
        switch error.domain {
        case NSPOSIXErrorDomain: domain = .posix
        case NSCocoaErrorDomain: domain = .cocoa
        case NSURLErrorDomain: domain = .url
        default: domain = nil
        }
        if let domain, let numeric = Int32(exactly: error.code) {
            self.nativeCode = .init(domain: domain, code: numeric); self.nativeCodeUnavailable = nil
        } else {
            self.nativeCode = nil; self.nativeCodeUnavailable = .unrecognizedNativeDomain
        }
    }
}
public struct DiagnosticCounters: Codable, Equatable {
    public let inputBytes: UInt64, outputBytes: UInt64, items: UInt64, violations: UInt64, attempts: UInt64
    public let durationNanoseconds: UInt64?
    public init(inputBytes: UInt64 = 0, outputBytes: UInt64 = 0, items: UInt64 = 0,
                violations: UInt64 = 0, attempts: UInt64 = 0, durationNanoseconds: UInt64? = nil) {
        self.inputBytes = inputBytes; self.outputBytes = outputBytes; self.items = items
        self.violations = violations; self.attempts = attempts; self.durationNanoseconds = durationNanoseconds
    }
    public func validate() throws {
        guard [inputBytes, outputBytes, items, violations, attempts].allSatisfy({ $0 <= 1_000_000_000_000 }),
              durationNanoseconds.map({ $0 <= 1_000_000_000_000_000 }) ?? true else { throw DiagnosticContractError.invalidSnapshot }
    }
}
public enum DiagnosticStateClass: String, Codable { case stable, unstable, correctable, degraded, contained, failed, safeHalt }
public struct DiagnosticStateSummary: Codable, Equatable {
    public let memberCount: UInt32
    public let semanticBits: UInt16?
    public let classification: DiagnosticStateClass?
    public init(memberCount: UInt32 = 0, semanticBits: UInt16? = nil, classification: DiagnosticStateClass? = nil) {
        self.memberCount = memberCount; self.semanticBits = semanticBits; self.classification = classification
    }
}
public struct DiagnosticDevelopmentDetails: Codable, Equatable {
    public let before: DiagnosticStateSummary?
    public let after: DiagnosticStateSummary?
    public let expected: DiagnosticStateSummary?
    public let counters: DiagnosticCounters
    public init(before: DiagnosticStateSummary? = nil, after: DiagnosticStateSummary? = nil,
                expected: DiagnosticStateSummary? = nil, counters: DiagnosticCounters = .init()) {
        self.before = before; self.after = after; self.expected = expected; self.counters = counters
    }
    public func validate() throws {
        try counters.validate()
        for state in [before, after, expected].compactMap({ $0 }) {
            guard state.memberCount <= 1_000_000, state.semanticBits.map({ $0 < 512 }) ?? true else { throw DiagnosticContractError.invalidSnapshot }
        }
    }
}
public struct DiagnosticEvent: Codable, Equatable {
    public let eventID: UUID, sessionID: UUID, operationID: UUID
    public let incidentID: UUID?, parentOperationID: UUID?
    public let component: DiagnosticComponent, stage: DiagnosticStage, outcome: DiagnosticOutcome
    public let expected: DiagnosticOutcome?, fault: DiagnosticFault?
    public let causeEventIDs: [UUID]
    public let counters: DiagnosticCounters
    public init(sessionID: UUID, operationID: UUID, incidentID: UUID? = nil, parentOperationID: UUID? = nil,
                component: DiagnosticComponent = .domain, stage: DiagnosticStage, outcome: DiagnosticOutcome,
                expected: DiagnosticOutcome? = nil, fault: DiagnosticFault? = nil, causeEventIDs: [UUID] = [],
                counters: DiagnosticCounters = .init(), eventID: UUID = UUID()) {
        self.sessionID = sessionID; self.operationID = operationID; self.incidentID = incidentID
        self.parentOperationID = parentOperationID; self.component = component; self.stage = stage
        self.outcome = outcome; self.expected = expected; self.fault = fault; self.causeEventIDs = causeEventIDs
        self.counters = counters; self.eventID = eventID
    }
    public func validate() throws {
        try counters.validate()
        guard causeEventIDs.count <= 32, Set(causeEventIDs).count == causeEventIDs.count,
              !causeEventIDs.contains(eventID), fault?.messageUnavailable == .privacyExcluded || fault == nil,
              (fault?.nativeCode != nil ? fault?.nativeCodeUnavailable == nil : (fault == nil || fault?.nativeCodeUnavailable != nil)) else { throw DiagnosticContractError.invalidSnapshot }
    }
}
public struct DiagnosticStackFrame: Codable, Equatable {
    public let imageIndex: UInt16, imageOffset: UInt64
    public init(imageIndex: UInt16, imageOffset: UInt64) { self.imageIndex = imageIndex; self.imageOffset = imageOffset }
}
public struct DiagnosticRecord: Codable, Equatable {
    public let event: DiagnosticEvent
    public let sequence: UInt64
    public let wallTime: Date?
    public let monotonicNanoseconds: UInt64?
    public let clockUnavailable: DiagnosticUnavailableReason?
    public let details: DiagnosticDevelopmentDetails?
    public let detailsUnavailable: DiagnosticUnavailableReason?
    public let stack: [DiagnosticStackFrame]
    public let stackUnavailable: DiagnosticUnavailableReason
    public let missingCauseEventIDs: [UUID]
    public let parentUnavailable: DiagnosticUnavailableReason?
    public init(event: DiagnosticEvent, sequence: UInt64, wallTime: Date?, monotonicNanoseconds: UInt64?,
                clockUnavailable: DiagnosticUnavailableReason?, details: DiagnosticDevelopmentDetails?,
                detailsUnavailable: DiagnosticUnavailableReason?, stack: [DiagnosticStackFrame] = [],
                missingCauseEventIDs: [UUID] = [], parentUnavailable: DiagnosticUnavailableReason? = nil) {
        self.event = event; self.sequence = sequence; self.wallTime = wallTime.flatMap(DiagnosticCoding.canonicalWallTime); self.monotonicNanoseconds = monotonicNanoseconds
        self.clockUnavailable = (wallTime != nil && self.wallTime == nil) ? .invalidClock : clockUnavailable; self.details = details; self.detailsUnavailable = detailsUnavailable
        self.stack = stack; self.stackUnavailable = .symbolicationUnavailable
        self.missingCauseEventIDs = missingCauseEventIDs; self.parentUnavailable = parentUnavailable
    }
    public func validate() throws {
        try event.validate(); try details?.validate()
        guard sequence > 0, stackUnavailable == .symbolicationUnavailable, stack.count <= 32, stack.allSatisfy({ $0.imageIndex < 32 && $0.imageOffset <= 1_000_000_000 }),
              (details != nil ? detailsUnavailable == nil : true),
              wallTime.map({ $0.timeIntervalSince1970.isFinite && abs($0.timeIntervalSince1970) < 253_402_300_800 }) ?? true,
              missingCauseEventIDs.count <= 32, Set(missingCauseEventIDs).count == missingCauseEventIDs.count,
              Set(missingCauseEventIDs).isSubset(of: Set(event.causeEventIDs)) else { throw DiagnosticContractError.invalidSnapshot }
    }
}
public struct DiagnosticLimits: Codable, Equatable {
    public let profile: DiagnosticProfile
    public let maximumEvents: Int, maximumEventBytes: Int, maximumRetainedBytes: Int
    public let maximumAgeSeconds: Double
    public let captureEnabled: Bool
    public init(profile: DiagnosticProfile, maximumEvents: Int? = nil, maximumEventBytes: Int? = nil,
                maximumRetainedBytes: Int? = nil, maximumAgeSeconds: Double = 86_400, captureEnabled: Bool = true) throws {
        self.profile = profile; self.maximumEvents = maximumEvents ?? (profile == .development ? 4096 : 512)
        self.maximumEventBytes = maximumEventBytes ?? (profile == .development ? 32768 : 4096)
        self.maximumRetainedBytes = maximumRetainedBytes ?? (profile == .development ? 16_777_216 : 1_048_576)
        self.maximumAgeSeconds = maximumAgeSeconds; self.captureEnabled = captureEnabled
        try validate()
    }
    public static var development: DiagnosticLimits { try! .init(profile: .development) }
    public static var release: DiagnosticLimits { try! .init(profile: .release) }
    public func validate() throws {
        guard maximumEvents > 0, maximumEvents <= (profile == .development ? 4096 : 512),
              maximumEventBytes > 0, maximumEventBytes <= (profile == .development ? 32768 : 4096),
              maximumRetainedBytes > 0, maximumRetainedBytes <= (profile == .development ? 16_777_216 : 1_048_576),
              maximumAgeSeconds.isFinite, maximumAgeSeconds > 0, maximumAgeSeconds <= 86_400 else { throw DiagnosticContractError.invalidLimits }
    }
}
public struct DiagnosticClockReading {
    public let wallTime: Date, monotonicNanoseconds: UInt64
    public init(wallTime: Date, monotonicNanoseconds: UInt64) { self.wallTime = wallTime; self.monotonicNanoseconds = monotonicNanoseconds }
}
public protocol DiagnosticClock { func read() -> DiagnosticClockReading }
public final class SystemDiagnosticClock: DiagnosticClock {
    public init() {}
    public func read() -> DiagnosticClockReading { .init(wallTime: Date(), monotonicNanoseconds: DispatchTime.now().uptimeNanoseconds) }
}
public struct DiagnosticHealth: Codable, Equatable {
    public let dropped, oversized, expired, purged, invalid, sampled, lostLinks, exportFailures: UInt64
    public init(dropped: UInt64 = 0, oversized: UInt64 = 0, expired: UInt64 = 0, purged: UInt64 = 0,
                invalid: UInt64 = 0, sampled: UInt64 = 0, lostLinks: UInt64 = 0, exportFailures: UInt64 = 0) {
        self.dropped = dropped; self.oversized = oversized; self.expired = expired; self.purged = purged
        self.invalid = invalid; self.sampled = sampled; self.lostLinks = lostLinks; self.exportFailures = exportFailures
    }
}
public enum DiagnosticArchitecture: String, Codable { case arm64, x86_64, unknown }
public enum DiagnosticExecutionKind: String, Codable { case simulator, device, host }
public struct DiagnosticEnvironment: Codable, Equatable {
    public let osMajor, osMinor, osPatch: Int
    public let architecture: DiagnosticArchitecture, executionKind: DiagnosticExecutionKind
    public init() {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        osMajor = os.majorVersion; osMinor = os.minorVersion; osPatch = os.patchVersion
        #if arch(arm64)
        architecture = .arm64
        #elseif arch(x86_64)
        architecture = .x86_64
        #else
        architecture = .unknown
        #endif
        #if targetEnvironment(simulator)
        executionKind = .simulator
        #elseif os(iOS)
        executionKind = .device
        #else
        executionKind = .host
        #endif
    }
    public func validate() throws {
        guard [osMajor, osMinor, osPatch].allSatisfy({ (0...1000).contains($0) }) else { throw DiagnosticContractError.invalidSnapshot }
    }
}
private final class DiagnosticFrameworkMarker: NSObject {}
public struct DiagnosticProvenance: Codable, Equatable {
    public let sdkVersion: String
    public let sourceCommit, buildID, toolchain: String?
    public let provenanceUnavailable: DiagnosticUnavailableReason?
    public let baseCommit, ashCommit: String
    public init() {
        let bundle = Bundle(for: DiagnosticFrameworkMarker.self)
        sdkVersion = "0.1.0-rc.1"
        let ownsSDKMetadata = bundle.bundleURL.pathExtension == "framework"
            && bundle.bundleIdentifier == "com.aeostara.sdk.AeostaraDomain"
            && bundle.object(forInfoDictionaryKey: "CFBundlePackageType") as? String == "FMWK"
            && bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String == "AeostaraDomain"
        let commit = ownsSDKMetadata ? bundle.object(forInfoDictionaryKey: "AeostaraSourceCommit") as? String : nil
        sourceCommit = commit.flatMap { Self.matches($0, "^[0-9a-f]{40}$") ? $0 : nil }
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        buildID = sourceCommit == nil ? nil : build.flatMap { Self.matches($0, "^[0-9]{1,10}(\\.[0-9]{1,10}){0,2}$") ? $0 : nil }
        let compiler = sourceCommit == nil ? nil : bundle.object(forInfoDictionaryKey: "AeostaraToolchain") as? String
        toolchain = compiler.flatMap { $0.utf8.count <= 96 && Self.matches($0, "^swiftlang-[0-9]+(\\.[0-9]+){1,5}-clang-[0-9]+(\\.[0-9]+){1,5}$") ? $0 : nil }
        provenanceUnavailable = sourceCommit == nil ? .sourcePackageProvenanceUnavailable : nil
        baseCommit = "774b981ef2267a41c1b1a59497b2b0746a86f32b"; ashCommit = "e123f5d7fdbb381179971f721a3292c31eb1cbc2"
    }
    private static func matches(_ value: String, _ pattern: String) -> Bool { value.range(of: pattern, options: .regularExpression) != nil }
    public func validate() throws {
        guard sdkVersion == "0.1.0-rc.1", baseCommit == "774b981ef2267a41c1b1a59497b2b0746a86f32b", ashCommit == "e123f5d7fdbb381179971f721a3292c31eb1cbc2",
              sourceCommit.map({ Self.matches($0, "^[0-9a-f]{40}$") }) ?? true,
              buildID.map({ Self.matches($0, "^[0-9]{1,10}(\\.[0-9]{1,10}){0,2}$") }) ?? true,
              toolchain.map({ $0.utf8.count <= 96 && Self.matches($0, "^swiftlang-[0-9]+(\\.[0-9]+){1,5}-clang-[0-9]+(\\.[0-9]+){1,5}$") }) ?? true,
              (sourceCommit != nil ? provenanceUnavailable == nil : (provenanceUnavailable == .sourcePackageProvenanceUnavailable && buildID == nil && toolchain == nil)) else { throw DiagnosticContractError.invalidSnapshot }
    }
}
public struct DiagnosticSnapshot: Codable, Equatable {
    public let schemaVersion: String
    public let snapshotID: UUID
    public let generatedAt: Date?
    public let profile: DiagnosticProfile, limits: DiagnosticLimits
    public let provenance: DiagnosticProvenance, environment: DiagnosticEnvironment
    public let events: [DiagnosticRecord]
    public let health: DiagnosticHealth
    public let retainedBytes: Int
    public init(snapshotID: UUID = UUID(), generatedAt: Date?, limits: DiagnosticLimits,
                events: [DiagnosticRecord], health: DiagnosticHealth, retainedBytes: Int,
                provenance: DiagnosticProvenance = .init(), environment: DiagnosticEnvironment = .init()) {
        schemaVersion = "1.0"; self.snapshotID = snapshotID; self.generatedAt = generatedAt.flatMap(DiagnosticCoding.canonicalWallTime)
        profile = limits.profile; self.limits = limits; self.events = events; self.health = health
        self.retainedBytes = retainedBytes; self.provenance = provenance; self.environment = environment
    }
    public func validate() throws {
        try limits.validate(); try provenance.validate(); try environment.validate()
        guard schemaVersion == "1.0", profile == limits.profile, events.count <= limits.maximumEvents,
              retainedBytes >= 0, retainedBytes <= limits.maximumRetainedBytes,
              generatedAt.map({ $0.timeIntervalSince1970.isFinite && abs($0.timeIntervalSince1970) < 253_402_300_800 }) ?? true,
              Set(events.map({ $0.event.eventID })).count == events.count else { throw DiagnosticContractError.invalidSnapshot }
        var previous: UInt64 = 0, seen = Set<UUID>(), operations = Set<UUID>(), bytes = 0
        for record in events {
            try record.validate()
            guard record.sequence > previous else { throw DiagnosticContractError.invalidSnapshot }
            previous = record.sequence
            let missing = Set(record.event.causeEventIDs).subtracting(seen)
            guard missing == Set(record.missingCauseEventIDs), record.event.parentOperationID.map({ operations.contains($0) || record.parentUnavailable == .earlierEvidenceNotRetained }) ?? true,
                  profile != .release || (record.details == nil && record.stack.isEmpty && record.detailsUnavailable == .developmentExcluded) else { throw DiagnosticContractError.invalidSnapshot }
            let size = try DiagnosticCoding.encoder().encode(record).count
            guard size <= limits.maximumEventBytes else { throw DiagnosticContractError.invalidSnapshot }
            bytes += size; seen.insert(record.event.eventID); operations.insert(record.event.operationID)
        }
        guard bytes == retainedBytes, limits.captureEnabled || events.isEmpty else { throw DiagnosticContractError.invalidSnapshot }
    }
}
public protocol DiagnosticRecording: AnyObject {
    @discardableResult func record(_ event: DiagnosticEvent, developmentDetails: (() -> DiagnosticDevelopmentDetails)?) -> UUID?
    func snapshot() -> DiagnosticSnapshot
    func beginExport() throws -> DiagnosticSnapshot
    func endExport(snapshotID: UUID, succeeded: Bool)
    func purge()
}
public extension DiagnosticRecording {
    @discardableResult func record(_ event: DiagnosticEvent) -> UUID? { record(event, developmentDetails: nil) }
}

public enum DiagnosticCoding {
    public static func canonicalWallTime(_ date: Date) -> Date? {
        let seconds = date.timeIntervalSince1970
        guard seconds.isFinite, abs(seconds) < 253_402_300_800 else { return nil }
        return Date(timeIntervalSince1970: (seconds * 1000).rounded() / 1000)
    }
    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, output in
            guard canonicalWallTime(date) != nil else { throw DiagnosticContractError.invalidSnapshot }
            var container = output.singleValueContainer()
            try container.encode(Int64((date.timeIntervalSince1970 * 1000).rounded()))
        }; return encoder
    }
    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .custom { input in
            let milliseconds = try input.singleValueContainer().decode(Int64.self)
            let date = Date(timeIntervalSince1970: Double(milliseconds) / 1000)
            guard canonicalWallTime(date) != nil else { throw DiagnosticContractError.invalidSnapshot }
            return date
        }; return decoder
    }
}
