// Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.
import Foundation
import Darwin
import CryptoKit
import AeostaraDomain

public enum DiagnosticExportStage: String, Codable { case snapshot, root, stage, json, markdown, metadata, validate, synchronize, publish, durability }
public struct DiagnosticExportError: Error {
    public let stage: DiagnosticExportStage
    public let nativeCode: Int32?
    public let published: Bool
    public let cleanupFailures: UInt32
    public init(stage: DiagnosticExportStage, nativeCode: Int32? = nil, published: Bool = false, cleanupFailures: UInt32 = 0) {
        self.stage = stage; self.nativeCode = nativeCode; self.published = published; self.cleanupFailures = cleanupFailures
    }
}
public struct DiagnosticExportBundle {
    public let bundleID: UUID
    public let directoryURL, jsonURL, markdownURL, metadataURL: URL
}
public struct DiagnosticExportMetadata: Codable, Equatable {
    public let schemaVersion: String
    public let bundleID: UUID
    public let eventIDs: [UUID]
    public let incidentIDs: [UUID]
    public let jsonBytes, markdownBytes: Int
    public let jsonSHA256, markdownSHA256: String
    public let health: DiagnosticHealth
}

/// Synchronous, offline export. The host invokes this from its own background context and owns retention of published files.
public final class DiagnosticExporter {
    #if DEBUG
    // An internal storage-failure seam permits a focused partial-write test without changing public consumer composition.
    private let stagedFileObserver: ((DiagnosticExportStage) throws -> Void)?
    public init() { stagedFileObserver = nil }
    internal init(stagedFileObserver: @escaping (DiagnosticExportStage) throws -> Void) { self.stagedFileObserver = stagedFileObserver }
    #else
    public init() {}
    #endif
    public func export(recording: DiagnosticRecording, to root: URL) throws -> DiagnosticExportBundle {
        let exportSession = UUID(), exportOperation = UUID()
        let started = recording.record(.init(sessionID: exportSession, operationID: exportOperation,
                                             component: .exporter, stage: .export, outcome: .started))
        let causes = started.map { [$0] } ?? []
        let snapshot: DiagnosticSnapshot
        do { snapshot = try recording.beginExport() } catch {
            recording.record(.init(sessionID: exportSession, operationID: exportOperation, component: .exporter,
                                   stage: .export, outcome: .failed, fault: .init(code: .export), causeEventIDs: causes))
            throw DiagnosticExportError(stage: .snapshot)
        }
        var succeeded = false
        defer { recording.endExport(snapshotID: snapshot.snapshotID, succeeded: succeeded) }
        var rootFD: Int32 = -1, stageFD: Int32 = -1
        let stageName = ".aeostara-stage-" + UUID().uuidString.lowercased()
        let finalName = "Aeostara-Diagnostics-" + snapshot.snapshotID.uuidString.lowercased()
        var ownsStage = false, published = false, failureStage = DiagnosticExportStage.validate
        var stageIdentity: stat?
        var createdFiles: [(name: String, identity: stat)] = []
        defer { if stageFD >= 0 { close(stageFD) }; if rootFD >= 0 { close(rootFD) } }
        do {
            try snapshot.validate()
            let encoder = DiagnosticCoding.encoder()
            let json = try encoder.encode(snapshot)
            let decoded = try DiagnosticCoding.decoder().decode(DiagnosticSnapshot.self, from: json)
            try decoded.validate()
            guard decoded == snapshot else { throw DiagnosticExportError(stage: .validate) }
            let markdown = Data(render(snapshot).utf8)
            let incidents = Array(Set(snapshot.events.compactMap { $0.event.incidentID })).sorted { $0.uuidString < $1.uuidString }
            let metadata = DiagnosticExportMetadata(schemaVersion: "1.0", bundleID: snapshot.snapshotID,
                eventIDs: snapshot.events.map { $0.event.eventID }, incidentIDs: incidents,
                jsonBytes: json.count, markdownBytes: markdown.count,
                jsonSHA256: SHA256.hash(data: json).map { String(format: "%02x", $0) }.joined(),
                markdownSHA256: SHA256.hash(data: markdown).map { String(format: "%02x", $0) }.joined(), health: snapshot.health)
            let metadataData = try encoder.encode(metadata)
            try validateParity(snapshot, markdown: markdown, metadata: metadata)
            failureStage = .root
            guard root.isFileURL, !root.path.isEmpty, !root.path.utf8.contains(0), !root.pathComponents.contains(".."),
                  root.standardizedFileURL.path.utf8.elementsEqual(root.resolvingSymlinksInPath().path.utf8) else { throw DiagnosticExportError(stage: .root) }
            var original = stat()
            guard lstat(root.path, &original) == 0 else { throw DiagnosticExportError(stage: .root, nativeCode: errno) }
            guard (original.st_mode & S_IFMT) == S_IFDIR, original.st_uid == geteuid(),
                  (original.st_mode & 0o022) == 0 else { throw DiagnosticExportError(stage: .root) }
            rootFD = open(root.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard rootFD >= 0 else { throw DiagnosticExportError(stage: .root, nativeCode: errno) }
            var anchored = stat()
            guard fstat(rootFD, &anchored) == 0 else { throw DiagnosticExportError(stage: .root, nativeCode: errno) }
            guard sameIdentity(original, anchored) else { throw DiagnosticExportError(stage: .root) }
            failureStage = .stage
            guard mkdirat(rootFD, stageName, 0o700) == 0 else { throw DiagnosticExportError(stage: .stage, nativeCode: errno) }
            ownsStage = true
            stageFD = openat(rootFD, stageName, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard stageFD >= 0 else { throw DiagnosticExportError(stage: .stage, nativeCode: errno) }
            var ownedDirectory = stat()
            guard fstat(stageFD, &ownedDirectory) == 0, (ownedDirectory.st_mode & S_IFMT) == S_IFDIR,
                  ownedDirectory.st_uid == geteuid(), (ownedDirectory.st_mode & 0o077) == 0 else { throw DiagnosticExportError(stage: .stage, nativeCode: errno) }
            stageIdentity = ownedDirectory
            for (name, data, part) in [("diagnostics.json", json, DiagnosticExportStage.json),
                                      ("diagnostics.md", markdown, .markdown), ("completion.json", metadataData, .metadata)] {
                failureStage = part
                try write(data, name: name, directory: stageFD, stage: part, createdFiles: &createdFiles)
                #if DEBUG
                try stagedFileObserver?(part)
                #endif
            }
            failureStage = .validate
            // Re-read staged bytes through the same descriptor rather than trusting only encoder memory.
            let savedJSON = try read(name: "diagnostics.json", directory: stageFD, maximum: json.count)
            let savedMarkdown = try read(name: "diagnostics.md", directory: stageFD, maximum: markdown.count)
            let savedMetadata = try read(name: "completion.json", directory: stageFD, maximum: metadataData.count)
            guard savedJSON == json, savedMarkdown == markdown,
                  try DiagnosticCoding.decoder().decode(DiagnosticExportMetadata.self, from: savedMetadata) == metadata else { throw DiagnosticExportError(stage: .validate) }
            let savedSnapshot = try DiagnosticCoding.decoder().decode(DiagnosticSnapshot.self, from: savedJSON)
            try savedSnapshot.validate(); try validateParity(savedSnapshot, markdown: savedMarkdown, metadata: metadata)
            failureStage = .synchronize
            guard fsync(stageFD) == 0 else { throw DiagnosticExportError(stage: .synchronize, nativeCode: errno) }
            var current = stat()
            guard lstat(root.path, &current) == 0 else { throw DiagnosticExportError(stage: .root, nativeCode: errno) }
            guard sameIdentity(anchored, current), (current.st_mode & S_IFMT) == S_IFDIR, current.st_uid == geteuid(),
                  (current.st_mode & 0o022) == 0 else { throw DiagnosticExportError(stage: .root) }
            failureStage = .publish
            guard directoryIdentity(rootFD, stageName, matches: ownedDirectory) else { throw DiagnosticExportError(stage: .publish, nativeCode: ESTALE) }
            guard renameatx_np(rootFD, stageName, rootFD, finalName, UInt32(RENAME_EXCL)) == 0 else { throw DiagnosticExportError(stage: .publish, nativeCode: errno) }
            published = true; ownsStage = false
            failureStage = .durability
            guard fsync(rootFD) == 0 else { throw DiagnosticExportError(stage: .durability, nativeCode: errno, published: true) }
            guard directoryIdentity(rootFD, finalName, matches: ownedDirectory),
                  lstat(root.path, &current) == 0, sameIdentity(anchored, current), current.st_uid == geteuid(),
                  (current.st_mode & 0o022) == 0 else { throw DiagnosticExportError(stage: .durability, nativeCode: ESTALE, published: true) }
            succeeded = true
            recording.record(.init(sessionID: exportSession, operationID: exportOperation, component: .exporter,
                                   stage: .export, outcome: .succeeded, causeEventIDs: causes))
            let directory = root.resolvingSymlinksInPath().appendingPathComponent(finalName, isDirectory: true)
            return .init(bundleID: snapshot.snapshotID, directoryURL: directory,
                         jsonURL: directory.appendingPathComponent("diagnostics.json"),
                         markdownURL: directory.appendingPathComponent("diagnostics.md"),
                         metadataURL: directory.appendingPathComponent("completion.json"))
        } catch {
            var cleanupFailures: UInt32 = 0
            if ownsStage {
                if stageFD >= 0 {
                    for file in createdFiles {
                        var currentFile = stat()
                        if fstatat(stageFD, file.name, &currentFile, AT_SYMLINK_NOFOLLOW) == 0 {
                            if sameIdentity(file.identity, currentFile) {
                                if unlinkat(stageFD, file.name, 0) != 0 { cleanupFailures += 1 }
                            } else { cleanupFailures += 1 }
                        } else if errno != ENOENT { cleanupFailures += 1 }
                    }
                }
                if let identity = stageIdentity, directoryIdentity(rootFD, stageName, matches: identity) {
                    if unlinkat(rootFD, stageName, AT_REMOVEDIR) != 0 { cleanupFailures += 1 }
                } else { cleanupFailures += 1 }
            }
            let original = error as? DiagnosticExportError
            recording.record(.init(sessionID: exportSession, operationID: exportOperation, component: .exporter,
                                   stage: .export, outcome: .failed,
                                   fault: .init(code: .export, nativeCode: original?.nativeCode.map { .init(domain: .posix, code: $0) }),
                                   causeEventIDs: causes))
            throw DiagnosticExportError(stage: original?.stage ?? failureStage, nativeCode: original?.nativeCode,
                                        published: published || (original?.published ?? false), cleanupFailures: cleanupFailures)
        }
    }
    private func sameIdentity(_ lhs: stat, _ rhs: stat) -> Bool { lhs.st_dev == rhs.st_dev && lhs.st_ino == rhs.st_ino }
    private func directoryIdentity(_ root: Int32, _ name: String, matches expected: stat) -> Bool {
        var actual = stat()
        return fstatat(root, name, &actual, AT_SYMLINK_NOFOLLOW) == 0 && sameIdentity(expected, actual)
            && (actual.st_mode & S_IFMT) == S_IFDIR && actual.st_uid == geteuid() && (actual.st_mode & 0o077) == 0
    }
    private func write(_ data: Data, name: String, directory: Int32, stage: DiagnosticExportStage,
                       createdFiles: inout [(name: String, identity: stat)]) throws {
        let fd = openat(directory, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw DiagnosticExportError(stage: stage, nativeCode: errno) }
        defer { close(fd) }
        var identity = stat()
        guard fstat(fd, &identity) == 0 else { throw DiagnosticExportError(stage: stage, nativeCode: errno) }
        createdFiles.append((name, identity))
        try data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let result = Darwin.write(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                if result < 0 && errno == EINTR { continue }
                guard result > 0 else { throw DiagnosticExportError(stage: stage, nativeCode: result < 0 ? errno : nil) }
                offset += result
            }
        }
        guard fsync(fd) == 0 else { throw DiagnosticExportError(stage: stage, nativeCode: errno) }
    }
    private func read(name: String, directory: Int32, maximum: Int) throws -> Data {
        let fd = openat(directory, name, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw DiagnosticExportError(stage: .validate, nativeCode: errno) }
        defer { close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG, info.st_size == maximum else { throw DiagnosticExportError(stage: .validate) }
        var result = Data(count: maximum)
        try result.withUnsafeMutableBytes { bytes in
            var offset = 0
            while offset < maximum {
                let count = Darwin.read(fd, bytes.baseAddress!.advanced(by: offset), maximum - offset)
                if count < 0 && errno == EINTR { continue }
                guard count > 0 else { throw DiagnosticExportError(stage: .validate, nativeCode: count < 0 ? errno : nil) }; offset += count
            }
        }
        return result
    }
    private func validateParity(_ snapshot: DiagnosticSnapshot, markdown: Data, metadata: DiagnosticExportMetadata) throws {
        guard let text = String(data: markdown, encoding: .utf8), text.contains("Bundle: " + snapshot.snapshotID.uuidString),
              metadata.bundleID == snapshot.snapshotID, metadata.eventIDs == snapshot.events.map({ $0.event.eventID }),
              metadata.health == snapshot.health, metadata.markdownBytes == markdown.count else { throw DiagnosticExportError(stage: .validate) }
        let timelineIDs = text.split(separator: "\n").compactMap { line -> UUID? in
            guard line.hasPrefix("### Event ") else { return nil }
            return UUID(uuidString: String(line.dropFirst("### Event ".count)))
        }
        let incidentIDs = text.split(separator: "\n").compactMap { line -> UUID? in
            guard line.hasPrefix("### Incident ") else { return nil }
            return UUID(uuidString: String(line.dropFirst("### Incident ".count)))
        }
        guard timelineIDs == metadata.eventIDs, incidentIDs == metadata.incidentIDs else { throw DiagnosticExportError(stage: .validate) }
    }
    private func escaped(_ text: String) -> String {
        var output = text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        for token in ["\\", "`", "*", "_", "{", "}", "[", "]", "(", ")", "#", "+", "-", "!", "|"] { output = output.replacingOccurrences(of: token, with: "\\" + token) }
        return output.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
    }
    private func render(_ snapshot: DiagnosticSnapshot) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        func utc(_ date: Date?) -> String { date.map { formatter.string(from: $0) } ?? "unavailable" }
        var lines = ["# Aeostara Diagnostic Evidence", "", "Bundle: " + snapshot.snapshotID.uuidString,
                     "Schema: " + snapshot.schemaVersion, "Generated UTC: " + utc(snapshot.generatedAt),
                     "Profile: " + snapshot.profile.rawValue, "Retained event count: \(snapshot.events.count)",
                     "Retained serialized event bytes: \(snapshot.retainedBytes)", "",
                     "## Product and environment", "", "SDK: " + escaped(snapshot.provenance.sdkVersion),
                     "Source: " + escaped(snapshot.provenance.sourceCommit ?? "unavailable"),
                     "Build: " + escaped(snapshot.provenance.buildID ?? "unavailable"),
                     "Toolchain: " + escaped(snapshot.provenance.toolchain ?? "unavailable"),
                     "Provenance limitation: " + (snapshot.provenance.provenanceUnavailable?.rawValue ?? "none"),
                     "Base authority: " + snapshot.provenance.baseCommit, "ASH authority: " + snapshot.provenance.ashCommit,
                     "OS version: \(snapshot.environment.osMajor).\(snapshot.environment.osMinor).\(snapshot.environment.osPatch)",
                     "Architecture: " + snapshot.environment.architecture.rawValue, "Execution: " + snapshot.environment.executionKind.rawValue,
                     "", "## Capture scope and evidence health", "",
                     "Limits: \(snapshot.limits.maximumEvents) events; \(snapshot.limits.maximumEventBytes) bytes/event; \(snapshot.limits.maximumRetainedBytes) retained bytes; \(snapshot.limits.maximumAgeSeconds) seconds retention; one recorder export lease.",
                     "Capture enabled: \(snapshot.limits.captureEnabled)",
                     "Loss counters: dropped=\(snapshot.health.dropped), oversized=\(snapshot.health.oversized), expired=\(snapshot.health.expired), purged=\(snapshot.health.purged), invalid=\(snapshot.health.invalid), sampled=\(snapshot.health.sampled), lostLinks=\(snapshot.health.lostLinks), exportFailures=\(snapshot.health.exportFailures).",
                     "Raw configuration, policy, paths, arbitrary messages and metadata are intentionally excluded before retention. Native error descriptions and nested userInfo are never retained.",
                     "Export completion is recorded after this immutable snapshot; completion.json and successful publication establish this bundle receipt. Capture/export failures appear in a subsequent snapshot. No attachment, crash-time flush, underlying failure stack, symbolication, entitlement measurement, reproduction recipe or causal hypothesis is asserted. Numeric stack offsets, when present, describe the recording site in anonymous process-local images.",
                     "JSON wall times are UTC Unix-epoch milliseconds; monotonic times are process-local nanoseconds. Sequence order establishes chronology; only explicit cause IDs establish reported causality.", "", "## Incident index", ""]
        let incidents = Array(Set(snapshot.events.compactMap { $0.event.incidentID })).sorted { $0.uuidString < $1.uuidString }
        if incidents.isEmpty { lines.append("No retained incident identifiers. This does not establish product health.") }
        for incident in incidents {
            let records = snapshot.events.filter { $0.event.incidentID == incident }
            lines += ["### Incident " + incident.uuidString, "", "Observed events: " + records.map { $0.event.eventID.uuidString }.joined(separator: ", "),
                      "Affected operations: " + Array(Set(records.map { $0.event.operationID.uuidString })).sorted().joined(separator: ", "),
                      "Trigger: " + (records.first.map { $0.event.stage.rawValue + " / " + $0.event.outcome.rawValue } ?? "unavailable"),
                      "Response and final observed outcome: " + (records.last.map { $0.event.stage.rawValue + " / " + $0.event.outcome.rawValue } ?? "unavailable"),
                      "Findings: only typed recorded outcomes and explicit earlier-event causes below. Hypotheses, reproduction conditions and unresolved root-cause conclusions: unavailable.", ""]
        }
        lines += ["## Correlated lifecycle timeline", ""]
        for record in snapshot.events {
            let event = record.event
            lines += ["### Event " + event.eventID.uuidString, "", "Sequence: \(record.sequence); UTC: " + utc(record.wallTime),
                      "Monotonic nanoseconds: " + (record.monotonicNanoseconds.map(String.init) ?? "unavailable"),
                      "Clock limitation: " + (record.clockUnavailable?.rawValue ?? "none"),
                      "Session: " + event.sessionID.uuidString, "Operation: " + event.operationID.uuidString,
                      "Parent operation: " + (event.parentOperationID?.uuidString ?? "notProvided"),
                      "Parent coverage: " + (record.parentUnavailable?.rawValue ?? "availableOrNotProvided"),
                      "Incident: " + (event.incidentID?.uuidString ?? "notProvided"),
                      "Component: " + event.component.rawValue, "Stage: " + event.stage.rawValue,
                      "Expected outcome: " + (event.expected?.rawValue ?? "notProvided"), "Observed outcome: " + event.outcome.rawValue,
                      "Fault: " + (event.fault?.code.rawValue ?? "none"),
                      "Native code: " + (event.fault?.nativeCode.map { $0.domain.rawValue + " / " + String($0.code) } ?? "unavailable"),
                      "Native-code limitation: " + (event.fault?.nativeCodeUnavailable?.rawValue ?? "none"),
                      "Message coverage: " + (event.fault?.messageUnavailable.rawValue ?? "noFault"),
                      "Explicit cause IDs: " + event.causeEventIDs.map(\.uuidString).joined(separator: ", "),
                      "Unavailable earlier causes: " + record.missingCauseEventIDs.map(\.uuidString).joined(separator: ", "),
                      "Counters: " + counters(event.counters),
                      "Development details coverage: " + (record.detailsUnavailable?.rawValue ?? "retained"),
                      "Stack coverage: " + record.stackUnavailable.rawValue]
            if let detail = record.details {
                lines += ["Before state: " + state(detail.before), "After state: " + state(detail.after),
                          "Expected state: " + state(detail.expected), "Detail counters: " + counters(detail.counters)]
            }
            for frame in record.stack { lines.append("Recording-site stack frame: anonymous image \(frame.imageIndex), relative byte offset \(frame.imageOffset).") }
            lines.append("")
        }
        lines += ["## Retained-evidence appendix", "", "Every retained record is included above. The following inert data blocks preserve every typed JSON field for audit; they do not provide instructions or executable content.", ""]
        let encoder = DiagnosticCoding.encoder()
        for record in snapshot.events {
            let bytes = (try? encoder.encode(record)) ?? Data()
            let text = String(data: bytes, encoding: .utf8) ?? "unavailable"
            lines += ["Event " + record.event.eventID.uuidString, "", "```json", text, "```", ""]
        }
        lines += ["Envelope and omission evidence", "", "```json", String(data: (try? encoder.encode(snapshot)) ?? Data(), encoding: .utf8) ?? "unavailable", "```", ""]
        return lines.joined(separator: "\n")
    }
    private func counters(_ value: DiagnosticCounters) -> String {
        "inputBytes=\(value.inputBytes), outputBytes=\(value.outputBytes), items=\(value.items), violations=\(value.violations), attempts=\(value.attempts), durationNanoseconds=" + (value.durationNanoseconds.map(String.init) ?? "unavailable")
    }
    private func state(_ value: DiagnosticStateSummary?) -> String {
        value.map { "members=\($0.memberCount), semanticBits=" + ($0.semanticBits.map(String.init) ?? "unavailable") + ", class=" + ($0.classification?.rawValue ?? "unavailable") } ?? "notProvided"
    }
}
