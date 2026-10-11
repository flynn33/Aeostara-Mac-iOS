// Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.
import Foundation

public enum DiagnosticStage: String, Codable, Sendable, CaseIterable {
    case initialize, observe, normalize, project, diagnose, classify, recoverability, plan
    case policy, backup, mutate, verify, rollback, fallback, containment, safeHalt, audit, export
}
public enum DiagnosticOutcome: String, Codable, Sendable {
    case started, succeeded, failed, blocked, unavailable, noAction, rolledBack, contained, halted
}
public enum DiagnosticComponent: String, Codable, Sendable {
    case domain, nativeServices, diagnostics, developmentDiagnostics
}
public enum DiagnosticSeverity: String, Codable, Sendable { case information, warning, error }
public enum DiagnosticFaultCode: String, Codable, Sendable {
    case mapping, policy, backup, audit, execution, verification, rollback, staleSnapshot
    case scopeViolation, invalidContract, export, internalFailure
}
public enum DiagnosticNativeErrorDomain: String, Codable, Sendable { case cocoa, posix, unavailable }
public struct DiagnosticFault: Codable, Equatable, Sendable {
    public let code: DiagnosticFaultCode
    public let nativeDomain: DiagnosticNativeErrorDomain
    public let nativeCode: Int?
    public init(code: DiagnosticFaultCode, nativeDomain: DiagnosticNativeErrorDomain = .unavailable, nativeCode: Int? = nil) {
        self.code = code; self.nativeDomain = nativeDomain
        self.nativeCode = nativeDomain == .unavailable ? nil : nativeCode
    }
    /// Error descriptions, userInfo, underlying errors and arbitrary domains are deliberately omitted.
    public init(code: DiagnosticFaultCode, error: Error) {
        let native = error as NSError
        self.init(code: code,
                  nativeDomain: native.domain == NSCocoaErrorDomain ? .cocoa : native.domain == NSPOSIXErrorDomain ? .posix : .unavailable,
                  nativeCode: native.code)
    }
}
public struct DiagnosticCounters: Codable, Equatable, Sendable {
    public let inputFields: Int
    public let mutations: Int
    public let verifiedItems: Int
    public let recoveryAttempts: Int
    public init(inputFields: Int = 0, mutations: Int = 0, verifiedItems: Int = 0, recoveryAttempts: Int = 0) {
        self.inputFields = inputFields; self.mutations = mutations
        self.verifiedItems = verifiedItems; self.recoveryAttempts = recoveryAttempts
    }
    public var isValid: Bool { [inputFields, mutations, verifiedItems, recoveryAttempts].allSatisfy { (0...1_000_000_000).contains($0) } }
}
public struct DiagnosticDevelopmentDetails: Codable, Equatable, Sendable {
    public let observedFieldCount: Int
    public let desiredFieldCount: Int
    public let ruleCount: Int
    public let durationSeconds: Double?
    public init(observedFieldCount: Int = 0, desiredFieldCount: Int = 0, ruleCount: Int = 0, durationSeconds: Double? = nil) {
        self.observedFieldCount = observedFieldCount; self.desiredFieldCount = desiredFieldCount
        self.ruleCount = ruleCount; self.durationSeconds = durationSeconds
    }
    public var isValid: Bool {
        [observedFieldCount, desiredFieldCount, ruleCount].allSatisfy { (0...1_000_000_000).contains($0) }
        && (durationSeconds.map { $0.isFinite && (0...86_400).contains($0) } ?? true)
    }
}
public struct DiagnosticEvent: Codable, Equatable, Sendable {
    public let eventID: UUID
    public let sessionID: UUID
    public let operationID: UUID
    public let incidentID: UUID?
    public let parentOperationID: UUID?
    public let component: DiagnosticComponent
    public let stage: DiagnosticStage
    public let outcome: DiagnosticOutcome
    public let expected: DiagnosticOutcome?
    public let fault: DiagnosticFault?
    public let causeEventIDs: [UUID]
    public let omittedInputReferences: Int
    public let counters: DiagnosticCounters
    public init(sessionID: UUID, operationID: UUID, incidentID: UUID? = nil, parentOperationID: UUID? = nil,
                component: DiagnosticComponent = .domain, stage: DiagnosticStage, outcome: DiagnosticOutcome,
                expected: DiagnosticOutcome? = nil, fault: DiagnosticFault? = nil,
                causeEventIDs: [UUID] = [], counters: DiagnosticCounters = .init(), eventID: UUID = UUID()) {
        self.eventID = eventID; self.sessionID = sessionID; self.operationID = operationID
        self.incidentID = incidentID; self.parentOperationID = parentOperationID; self.component = component
        self.stage = stage; self.outcome = outcome; self.expected = expected; self.fault = fault
        self.causeEventIDs = Array(causeEventIDs.prefix(32)); self.omittedInputReferences = max(0, causeEventIDs.count - 32)
        self.counters = counters
    }
}
public enum DiagnosticProfile: String, Codable, Sendable { case development, release }
public enum DiagnosticLimitError: Error { case invalidLimits, exportBusy, invalidSnapshot }
public struct DiagnosticLimits: Codable, Equatable, Sendable {
    public let eventCount: Int
    public let eventBytes: Int
    public let retainedBytes: Int
    public let ageSeconds: Double
    public let enabled: Bool
    public init(eventCount: Int = 512, eventBytes: Int = 4096, retainedBytes: Int = 1_048_576,
                ageSeconds: Double = 86_400, enabled: Bool = true) throws {
        guard eventCount > 0, eventCount <= 4096, eventBytes > 0, eventBytes <= 32_768,
              retainedBytes > 0, retainedBytes <= 16_777_216, ageSeconds.isFinite, ageSeconds > 0,
              ageSeconds <= 86_400 else { throw DiagnosticLimitError.invalidLimits }
        self.eventCount = eventCount; self.eventBytes = eventBytes; self.retainedBytes = retainedBytes
        self.ageSeconds = ageSeconds; self.enabled = enabled
    }
    public static var releaseDefaults: DiagnosticLimits { try! .init() }
    public static var developmentDefaults: DiagnosticLimits { try! .init(eventCount: 4096, eventBytes: 32_768, retainedBytes: 16_777_216) }
    public var isReleaseCompatible: Bool { eventCount <= 512 && eventBytes <= 4096 && retainedBytes <= 1_048_576 && ageSeconds <= 86_400 }
    public var isValid: Bool {
        eventCount > 0 && eventCount <= 4096 && eventBytes > 0 && eventBytes <= 32_768
        && retainedBytes > 0 && retainedBytes <= 16_777_216 && ageSeconds.isFinite && ageSeconds > 0 && ageSeconds <= 86_400
    }
}
public struct DiagnosticTime: Sendable {
    public let monotonicSeconds: Double
    public let wallUTCSeconds: Double?
    public init(monotonicSeconds: Double, wallUTCSeconds: Double? = nil) {
        self.monotonicSeconds = monotonicSeconds; self.wallUTCSeconds = wallUTCSeconds
    }
}
public protocol DiagnosticClock { func now() -> DiagnosticTime }
public struct DiagnosticStackFrame: Codable, Equatable, Sendable {
    public let component: DiagnosticComponent
    public let imageOffset: UInt64
    public init(component: DiagnosticComponent, imageOffset: UInt64) { self.component = component; self.imageOffset = imageOffset }
}
public struct DiagnosticRecord: Codable, Equatable, Sendable {
    public let event: DiagnosticEvent
    public let sequence: UInt64
    public let severity: DiagnosticSeverity
    public let monotonicSeconds: Double
    public let wallUTCSeconds: Double?
    public let details: DiagnosticDevelopmentDetails?
    public let stackFrames: [DiagnosticStackFrame]
    public let omittedReferences: Int
    public init(event: DiagnosticEvent, sequence: UInt64, monotonicSeconds: Double, wallUTCSeconds: Double?,
                details: DiagnosticDevelopmentDetails? = nil, stackFrames: [DiagnosticStackFrame] = [], omittedReferences: Int = 0) {
        self.event = event; self.sequence = sequence
        severity = event.fault != nil || event.outcome == .failed || event.outcome == .halted ? .error : event.outcome == .blocked || event.outcome == .contained ? .warning : .information
        self.monotonicSeconds = monotonicSeconds; self.wallUTCSeconds = wallUTCSeconds
        self.details = details; self.stackFrames = Array(stackFrames.prefix(20)); self.omittedReferences = omittedReferences
    }
}
public struct DiagnosticHealth: Codable, Equatable, Sendable {
    public var droppedOversized: UInt64 = 0
    public var evicted: UInt64 = 0
    public var expired: UInt64 = 0
    public var invalidEvidence: UInt64 = 0
    public var omittedCausalReferences: UInt64 = 0
    public var serializationFailures: UInt64 = 0
    public var disabledEvents: UInt64 = 0
    public var exportFailures: UInt64 = 0
    public var purgedEvents: UInt64 = 0
    public init() {}
}
public struct DiagnosticEnvironment: Codable, Equatable, Sendable {
    public let osMajor: Int
    public let osMinor: Int
    public let osPatch: Int
    public let architecture: String
    public let executionKind: String
    public init() {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        osMajor = os.majorVersion; osMinor = os.minorVersion; osPatch = os.patchVersion
        #if arch(arm64)
        architecture = "arm64"
        #elseif arch(x86_64)
        architecture = "x86_64"
        #else
        architecture = "unavailable"
        #endif
        #if targetEnvironment(simulator)
        executionKind = "simulator"
        #elseif os(macOS)
        executionKind = "macOS host"
        #else
        executionKind = "device"
        #endif
    }
    public var isValid: Bool {
        [osMajor, osMinor, osPatch].allSatisfy { (0...1000).contains($0) }
        && ["arm64", "x86_64", "unavailable"].contains(architecture)
        && ["simulator", "macOS host", "device"].contains(executionKind)
    }
}
private final class DiagnosticFrameworkMarker: NSObject {}
public struct SDKDiagnosticIdentity: Codable, Equatable, Sendable {
    public let module: String
    public let version: String
    public let build: String?
    public let sourceCommit: String?
    public let toolchain: String?
    public let baseCommit: String
    public let ashCommit: String
    public init() {
        let bundle = Bundle(for: DiagnosticFrameworkMarker.self)
        let ownsSDKMetadata = bundle.bundleIdentifier == "com.aeostara.sdk.AeostaraMacDomain"
            && bundle.object(forInfoDictionaryKey: "CFBundlePackageType") as? String == "FMWK"
            && bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String == "AeostaraMacDomain"
        module = "AeostaraMacDomain"
        version = "0.1.0-rc.1"
        let source = ownsSDKMetadata ? bundle.object(forInfoDictionaryKey: "AeostaraSourceCommit") as? String : nil
        sourceCommit = source.flatMap { $0.range(of: "^[0-9a-f]{40}$", options: .regularExpression) == nil ? nil : $0 }
        let rawBuild = sourceCommit == nil ? nil : bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        build = rawBuild.flatMap { $0.range(of: "^[0-9]{1,12}$", options: .regularExpression) == nil ? nil : $0 }
        let compiler = sourceCommit == nil ? nil : bundle.object(forInfoDictionaryKey: "AeostaraToolchain") as? String
        toolchain = compiler.flatMap { $0.utf8.count <= 96 && $0.range(of: "^swiftlang-[0-9.]+-clang-[0-9.]+$", options: .regularExpression) != nil ? $0 : nil }
        baseCommit = "774b981ef2267a41c1b1a59497b2b0746a86f32b"
        ashCommit = "e123f5d7fdbb381179971f721a3292c31eb1cbc2"
    }
    public static var current: SDKDiagnosticIdentity { .init() }
    public var isValid: Bool {
        module == "AeostaraMacDomain" && version == "0.1.0-rc.1" && baseCommit == "774b981ef2267a41c1b1a59497b2b0746a86f32b"
        && ashCommit == "e123f5d7fdbb381179971f721a3292c31eb1cbc2"
        && (build.map { $0.range(of: "^[0-9]{1,12}$", options: .regularExpression) != nil } ?? true)
        && (sourceCommit.map { $0.range(of: "^[0-9a-f]{40}$", options: .regularExpression) != nil } ?? true)
        && (sourceCommit != nil || (build == nil && toolchain == nil))
        && (toolchain.map { $0.utf8.count <= 96 && $0.range(of: "^swiftlang-[0-9.]+-clang-[0-9.]+$", options: .regularExpression) != nil } ?? true)
    }
}
public enum DiagnosticCoverageGap: String, Codable, Sendable {
    case rawStateIntentionallyExcluded, absolutePathsIntentionallyExcluded, unownedStackFramesExcluded
    case permissionsUnavailable, crossProcessCausalityUnavailable, fatalTerminationFlushUnverified, sourceProvenanceUnavailable
}
public struct DiagnosticIncident: Codable, Equatable, Sendable {
    public let incidentID: UUID
    public let eventIDs: [UUID]
    public let faultEventIDs: [UUID]
    public let recoveryEventIDs: [UUID]
    public init(incidentID: UUID, records: [DiagnosticRecord]) {
        self.incidentID = incidentID
        let related = records.filter { $0.event.incidentID == incidentID }
        eventIDs = related.map { $0.event.eventID }
        faultEventIDs = related.filter { $0.event.fault != nil || $0.event.outcome == .failed }.map { $0.event.eventID }
        recoveryEventIDs = related.filter { [.rollback, .fallback, .containment, .safeHalt].contains($0.event.stage) }.map { $0.event.eventID }
    }
}
public struct DiagnosticSnapshot: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let snapshotID: UUID
    public let profile: DiagnosticProfile
    public let identity: SDKDiagnosticIdentity
    public let environment: DiagnosticEnvironment
    public let limits: DiagnosticLimits
    public let generatedWallUTCSeconds: Double?
    public let records: [DiagnosticRecord]
    public let incidents: [DiagnosticIncident]
    public let coverageGaps: [DiagnosticCoverageGap]
    public let retainedSerializedBytes: Int
    public let health: DiagnosticHealth
    public let lastAssignedSequence: UInt64
    public init(snapshotID: UUID = UUID(), profile: DiagnosticProfile, limits: DiagnosticLimits,
                generatedWallUTCSeconds: Double?, records: [DiagnosticRecord], retainedSerializedBytes: Int,
                health: DiagnosticHealth, lastAssignedSequence: UInt64) {
        schemaVersion = "1.0"; self.snapshotID = snapshotID; self.profile = profile
        identity = .current; environment = .init(); self.limits = limits
        self.generatedWallUTCSeconds = generatedWallUTCSeconds; self.records = records
        incidents = Array(Set(records.compactMap { $0.event.incidentID })).sorted { $0.uuidString < $1.uuidString }
            .map { DiagnosticIncident(incidentID: $0, records: records) }
        var gaps: [DiagnosticCoverageGap] = [.rawStateIntentionallyExcluded, .absolutePathsIntentionallyExcluded,
                                            .unownedStackFramesExcluded, .permissionsUnavailable,
                                            .crossProcessCausalityUnavailable, .fatalTerminationFlushUnverified]
        if identity.sourceCommit == nil { gaps.append(.sourceProvenanceUnavailable) }
        coverageGaps = gaps
        self.retainedSerializedBytes = retainedSerializedBytes; self.health = health; self.lastAssignedSequence = lastAssignedSequence
    }
    public var incidentIDs: [UUID] { Array(Set(records.compactMap { $0.event.incidentID })).sorted { $0.uuidString < $1.uuidString } }
    public var isValid: Bool {
        guard schemaVersion == "1.0", identity.isValid, environment.isValid, limits.isValid, records.count <= limits.eventCount,
              retainedSerializedBytes >= 0, retainedSerializedBytes <= limits.retainedBytes,
              generatedWallUTCSeconds.map({ $0.isFinite && (0...253_402_300_799).contains($0) }) ?? true else { return false }
        var previous: UInt64 = 0; var earlier = [UUID: DiagnosticRecord](); var serializedBytes = 0
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        for record in records {
            guard record.sequence > previous, record.sequence <= lastAssignedSequence,
                  earlier[record.event.eventID] == nil, record.monotonicSeconds.isFinite, (0...1_000_000_000_000).contains(record.monotonicSeconds),
                  record.wallUTCSeconds.map({ $0.isFinite && (0...253_402_300_799).contains($0) }) ?? true,
                  record.event.counters.isValid, record.details?.isValid ?? true, record.event.causeEventIDs.count <= 32,
                  record.event.omittedInputReferences >= 0, Set(record.event.causeEventIDs).count == record.event.causeEventIDs.count,
                  record.omittedReferences >= 0, record.stackFrames.count <= 20,
                  record.severity == DiagnosticRecord(event: record.event, sequence: record.sequence,
                      monotonicSeconds: record.monotonicSeconds, wallUTCSeconds: record.wallUTCSeconds).severity,
                  record.event.causeEventIDs.allSatisfy({ earlier[$0]?.event.sessionID == record.event.sessionID
                      && earlier[$0]?.event.incidentID == record.event.incidentID }),
                  record.event.parentOperationID.map({ parent in earlier.values.contains { $0.event.operationID == parent && $0.event.sessionID == record.event.sessionID } }) ?? true,
                  let data = try? encoder.encode(record), data.count <= limits.eventBytes else { return false }
            serializedBytes += data.count; earlier[record.event.eventID] = record
            previous = record.sequence
        }
        guard serializedBytes == retainedSerializedBytes,
              incidents == incidentIDs.map({ DiagnosticIncident(incidentID: $0, records: records) }) else { return false }
        return profile != .release || (limits.isReleaseCompatible && records.allSatisfy { $0.details == nil && $0.stackFrames.isEmpty })
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
