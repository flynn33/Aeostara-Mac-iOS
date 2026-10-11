// Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.
import Foundation
import CryptoKit
import Darwin
import AeostaraMacDomain

public enum DiagnosticExportStage: String, Codable, Sendable {
    case acquireSnapshot, validate, openRoot, createStage, writeJSON, writeMarkdown, writeMetadata, publish, synchronize
}
public struct DiagnosticExportError: Error, Sendable {
    public let stage: DiagnosticExportStage
    public let nativeCode: Int32?
    public let publicationMayHaveCompleted: Bool
    public let incompleteStageRetained: Bool
    public init(stage: DiagnosticExportStage, nativeCode: Int32? = nil,
                publicationMayHaveCompleted: Bool = false, incompleteStageRetained: Bool = false) {
        self.stage = stage; self.nativeCode = nativeCode
        self.publicationMayHaveCompleted = publicationMayHaveCompleted; self.incompleteStageRetained = incompleteStageRetained
    }
}
public struct DiagnosticExportBundle: Sendable {
    public let snapshotID: UUID
    public let directory: URL
    public var json: URL { directory.appendingPathComponent("Diagnostics.json") }
    public var markdown: URL { directory.appendingPathComponent("Diagnostics.md") }
    public var completionMetadata: URL { directory.appendingPathComponent("COMPLETE.json") }
    public init(snapshotID: UUID, directory: URL) { self.snapshotID = snapshotID; self.directory = directory }
}

/// Call from an application-owned background context. Export is offline and user invoked.
public final class DiagnosticExporter {
    #if DEBUG
    private let injectedFailure: DiagnosticExportStage?
    public init() { injectedFailure = nil }
    internal init(failBefore stage: DiagnosticExportStage) { injectedFailure = stage }
    #else
    public init() {}
    #endif
    public func export(recording: DiagnosticRecording, to root: URL) throws -> DiagnosticExportBundle {
        let operation = UUID(), session = UUID(), incident = UUID()
        let start = recording.record(.init(sessionID: session, operationID: operation, incidentID: incident,
                                           component: .diagnostics, stage: .export, outcome: .started, expected: .succeeded))
        var complete = false
        defer {
            _ = recording.record(.init(sessionID: session, operationID: operation, incidentID: incident,
                                       component: .diagnostics, stage: .export, outcome: complete ? .succeeded : .failed,
                                       expected: .succeeded, fault: complete ? nil : DiagnosticFault(code: .export),
                                       causeEventIDs: start.map { [$0] } ?? []))
        }
        let snapshot: DiagnosticSnapshot
        do { snapshot = try recording.beginExport() }
        catch { throw DiagnosticExportError(stage: .acquireSnapshot) }
        defer { recording.endExport(snapshotID: snapshot.snapshotID, succeeded: complete) }
        guard snapshot.isValid else { throw DiagnosticExportError(stage: .validate) }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        let json: Data
        do { json = try encoder.encode(snapshot) }
        catch { throw DiagnosticExportError(stage: .validate) }
        guard let roundTrip = try? JSONDecoder().decode(DiagnosticSnapshot.self, from: json), roundTrip == snapshot,
              roundTrip.isValid else { throw DiagnosticExportError(stage: .validate) }
        let report = markdown(snapshot)
        func headings(_ kind: String, _ prefix: String) throws -> Set<String> {
            let expression = try NSRegularExpression(pattern: "^" + prefix + " " + kind + " `([A-Fa-f0-9-]+)`$", options: [.anchorsMatchLines])
            return Set(expression.matches(in: report, range: NSRange(report.startIndex..., in: report)).compactMap { match in
                Range(match.range(at: 1), in: report).map { String(report[$0]) }
            })
        }
        guard report.contains("Snapshot: `" + snapshot.snapshotID.uuidString + "`"),
              try headings("Event", "###") == Set(snapshot.records.map { $0.event.eventID.uuidString }),
              try headings("Incident", "##") == Set(snapshot.incidentIDs.map { $0.uuidString }),
              let markdownBytes = report.data(using: .utf8) else { throw DiagnosticExportError(stage: .validate) }
        let parts = ["Diagnostics.json": json, "Diagnostics.md": markdownBytes]
        let metadata = Completion(snapshotID: snapshot.snapshotID, eventCount: snapshot.records.count,
                                  incidentIDs: snapshot.incidentIDs,
                                  parts: parts.map { .init(name: $0.key, bytes: $0.value.count, sha256: digest($0.value)) }.sorted { $0.name < $1.name })
        let metadataBytes: Data
        do { metadataBytes = try encoder.encode(metadata) }
        catch { throw DiagnosticExportError(stage: .validate) }

        guard root.isFileURL, !root.pathComponents.contains(".."), !root.path.utf8.contains(0),
              root.standardizedFileURL.path.utf8.elementsEqual(root.resolvingSymlinksInPath().path.utf8) else {
            throw DiagnosticExportError(stage: .openRoot)
        }
        let rootFD = Darwin.open(root.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard rootFD >= 0 else { throw DiagnosticExportError(stage: .openRoot, nativeCode: errno) }
        defer { Darwin.close(rootFD) }
        var rootStat = stat()
        guard fstat(rootFD, &rootStat) == 0, (rootStat.st_mode & S_IFMT) == S_IFDIR, rootStat.st_uid == geteuid(),
              (rootStat.st_mode & 0o022) == 0,
              rootMatches(root, expected: rootStat) else { throw DiagnosticExportError(stage: .openRoot, nativeCode: errno) }
        let stageName = ".aeostara-export-" + UUID().uuidString
        let bundleName = "Aeostara-Diagnostics-" + snapshot.snapshotID.uuidString
        guard mkdirat(rootFD, stageName, 0o700) == 0 else { throw DiagnosticExportError(stage: .createStage, nativeCode: errno) }
        let stageFD = openat(rootFD, stageName, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard stageFD >= 0 else {
            throw DiagnosticExportError(stage: .createStage, nativeCode: errno, incompleteStageRetained: true)
        }
        defer { Darwin.close(stageFD) }
        var stageStat = stat()
        guard fstat(stageFD, &stageStat) == 0 else {
            throw DiagnosticExportError(stage: .createStage, nativeCode: errno, incompleteStageRetained: true)
        }
        var ownedFiles: [(name: String, identity: stat)] = []
        var published = false
        var currentStage: DiagnosticExportStage = .writeJSON
        do {
            try checkInjection(.writeJSON)
            try write(json, name: "Diagnostics.json", fd: stageFD, owned: &ownedFiles)
            currentStage = .writeMarkdown; try checkInjection(.writeMarkdown)
            try write(markdownBytes, name: "Diagnostics.md", fd: stageFD, owned: &ownedFiles)
            currentStage = .writeMetadata; try checkInjection(.writeMetadata)
            try write(metadataBytes, name: "COMPLETE.json", fd: stageFD, owned: &ownedFiles)
            currentStage = .synchronize
            guard fsync(stageFD) == 0 else { throw NativeFailure(code: errno) }
            currentStage = .publish; try checkInjection(.publish)
            guard rootMatches(root, expected: rootStat), directoryMatches(rootFD, stageName, expected: stageStat) else { throw NativeFailure(code: ESTALE) }
            guard renameatx_np(rootFD, stageName, rootFD, bundleName, UInt32(RENAME_EXCL)) == 0 else { throw NativeFailure(code: errno) }
            published = true; currentStage = .synchronize
            guard fsync(rootFD) == 0 else { throw NativeFailure(code: errno) }
            guard rootMatches(root, expected: rootStat), directoryMatches(rootFD, bundleName, expected: stageStat) else { throw NativeFailure(code: ESTALE) }
            complete = true
            return .init(snapshotID: snapshot.snapshotID, directory: root.appendingPathComponent(bundleName, isDirectory: true))
        } catch {
            var retained = false
            if !published {
                for file in ownedFiles {
                    var found = stat()
                    if fstatat(stageFD, file.name, &found, AT_SYMLINK_NOFOLLOW) == 0,
                       found.st_dev == file.identity.st_dev, found.st_ino == file.identity.st_ino {
                        if unlinkat(stageFD, file.name, 0) != 0 { retained = true }
                    } else { retained = true }
                }
                var foundStage = stat()
                if fstatat(rootFD, stageName, &foundStage, AT_SYMLINK_NOFOLLOW) == 0,
                   foundStage.st_dev == stageStat.st_dev, foundStage.st_ino == stageStat.st_ino {
                    if unlinkat(rootFD, stageName, AT_REMOVEDIR) != 0 { retained = true }
                } else { retained = true }
            }
            throw DiagnosticExportError(stage: currentStage, nativeCode: (error as? NativeFailure)?.code,
                                        publicationMayHaveCompleted: published, incompleteStageRetained: retained)
        }
    }
    private struct NativeFailure: Error { let code: Int32 }
    private struct Part: Codable { let name: String; let bytes: Int; let sha256: String }
    private struct Completion: Encodable {
        let schemaVersion = "1.0"
        let snapshotID: UUID
        let eventCount: Int
        let incidentIDs: [UUID]
        let parts: [Part]
    }
    private func checkInjection(_ stage: DiagnosticExportStage) throws {
        #if DEBUG
        if injectedFailure == stage { throw NativeFailure(code: EIO) }
        #endif
    }
    private func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private func rootMatches(_ root: URL, expected: stat) -> Bool {
        var actual = stat()
        return lstat(root.path, &actual) == 0 && (actual.st_mode & S_IFMT) == S_IFDIR && actual.st_uid == geteuid()
            && (actual.st_mode & 0o022) == 0
            && actual.st_dev == expected.st_dev && actual.st_ino == expected.st_ino
    }
    private func directoryMatches(_ fd: Int32, _ name: String, expected: stat) -> Bool {
        var actual = stat()
        return fstatat(fd, name, &actual, AT_SYMLINK_NOFOLLOW) == 0 && (actual.st_mode & S_IFMT) == S_IFDIR
            && actual.st_uid == geteuid() && (actual.st_mode & 0o077) == 0
            && actual.st_dev == expected.st_dev && actual.st_ino == expected.st_ino
    }
    private func write(_ data: Data, name: String, fd: Int32, owned: inout [(name: String, identity: stat)]) throws {
        let file = openat(fd, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard file >= 0 else { throw NativeFailure(code: errno) }
        defer { Darwin.close(file) }
        var identity = stat()
        guard fstat(file, &identity) == 0 else { throw NativeFailure(code: errno) }
        owned.append((name, identity))
        try data.withUnsafeBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let count = Darwin.write(file, buffer.baseAddress!.advanced(by: offset), buffer.count - offset)
                if count < 0 && errno == EINTR { continue }
                guard count > 0 else { throw NativeFailure(code: count == 0 ? EIO : errno) }
                offset += count
            }
        }
        guard fsync(file) == 0 else { throw NativeFailure(code: errno) }
    }
    private func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "[", with: "\\[").replacingOccurrences(of: "]", with: "\\]")
            .replacingOccurrences(of: "*", with: "\\*").replacingOccurrences(of: "_", with: "\\_")
    }
    private func markdown(_ snapshot: DiagnosticSnapshot) -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        func utc(_ seconds: Double?) -> String {
            guard let seconds else { return "unavailable (clock supplied no finite UTC metadata)" }
            return formatter.string(from: Date(timeIntervalSince1970: seconds))
        }
        func json<T: Encodable>(_ value: T) -> String { (try? encoder.encode(value)).flatMap { String(data: $0, encoding: .utf8) } ?? "Serialization unavailable" }
        var report = "# Aeostara diagnostic evidence\n\nSnapshot: `\(snapshot.snapshotID.uuidString)`\n\n"
        report += "Schema: \(snapshot.schemaVersion). Profile: \(snapshot.profile.rawValue). Retained events: \(snapshot.records.count). Retained serialized event bytes: \(snapshot.retainedSerializedBytes).\n\n"
        report += "Generated UTC: \(utc(snapshot.generatedWallUTCSeconds)). Last assigned process sequence: \(snapshot.lastAssignedSequence).\n\n"
        report += "## Identity and environment\n\n```json\n\(json(snapshot.identity))\n```\n\n```json\n\(json(snapshot.environment))\n```\n\n"
        report += "## Capture policy and diagnostic health\n\n```json\n\(json(snapshot.limits))\n```\n\n```json\n\(json(snapshot.health))\n```\n\n"
        report += "Monotonic timing is process-local, in seconds, using a nondecreasing high-water clock. UTC is optional metadata. Sequence gaps reflect recorded evidence loss; order alone never establishes causality. Snapshot copies retained by the caller are caller-owned memory. Export files are private application-owned files; the host owns their deletion and disk budget.\n\n"
        report += "## Coverage and unavailable evidence\n\n"
        for gap in snapshot.coverageGaps { report += "- \(escape(gap.rawValue))\n" }
        report += "\nRaw JSON state, arbitrary metadata, policy expressions, error descriptions and absolute paths are intentionally excluded. Release capture never evaluates rich detail suppliers and has no development collector. Development safe stack entries contain only recognized native image offsets; absent frames are unavailable or deliberately excluded. Fatal termination does not guarantee a final flush/export.\n\n"
        report += "## Incident index\n\n"
        if snapshot.incidents.isEmpty { report += "No incident identifiers were supplied in retained evidence; this is not a health claim.\n\n" }
        for incident in snapshot.incidents { report += "- `\(incident.incidentID.uuidString)`: \(incident.eventIDs.count) retained events, \(incident.faultEventIDs.count) fault events, \(incident.recoveryEventIDs.count) recovery events.\n" }
        for incident in snapshot.incidents {
            report += "\n## Incident `\(incident.incidentID.uuidString)`\n\n"
            report += "Observed event references: \(incident.eventIDs.map { "`" + $0.uuidString + "`" }.joined(separator: ", ")).\n\n"
            report += "Fault references: \(incident.faultEventIDs.map { "`" + $0.uuidString + "`" }.joined(separator: ", ")). Recovery references: \(incident.recoveryEventIDs.map { "`" + $0.uuidString + "`" }.joined(separator: ", ")).\n\n"
            for record in snapshot.records where record.event.incidentID == incident.incidentID {
                report += "- Sequence \(record.sequence): \(record.event.stage.rawValue), expected \(record.event.expected?.rawValue ?? "unavailable"), observed \(record.event.outcome.rawValue), typed fault \(record.event.fault?.code.rawValue ?? "none recorded").\n"
            }
            report += "\nThese are recorded observations. Explicit cause references are listed in the full timeline. A root cause, reproduction input, cross-process link or hypothesis that was not recorded remains unknown. No automated inference is substituted for evidence.\n"
        }
        report += "\n## Complete retained event timeline\n\n"
        for record in snapshot.records {
            let event = record.event
            report += "### Event `\(event.eventID.uuidString)`\n\n"
            report += "Sequence \(record.sequence); UTC \(utc(record.wallUTCSeconds)); monotonic \(record.monotonicSeconds) seconds; severity \(record.severity.rawValue); component \(event.component.rawValue); stage \(event.stage.rawValue).\n\n"
            report += "Session `\(event.sessionID.uuidString)`; operation `\(event.operationID.uuidString)`; parent \(event.parentOperationID?.uuidString ?? "unavailable or omitted"); incident \(event.incidentID?.uuidString ?? "unavailable").\n\n"
            report += "Expected: \(event.expected?.rawValue ?? "unavailable"). Observed: \(event.outcome.rawValue). Omitted parent/cause references: \(record.omittedReferences).\n\n"
            report += "Explicit earlier causes: \(event.causeEventIDs.map { "`" + $0.uuidString + "`" }.joined(separator: ", ")).\n\n"
            report += "Typed fault/native code, safe counters, development detail and stack offsets follow in the exact retained record. No raw error message or state is reconstructed.\n\n```json\n\(json(record))\n```\n\n"
        }
        report += "## Full retained-evidence appendix\n\nThe following is the complete frozen JSON snapshot used for Diagnostics.json. It includes all retained events, incident membership, health/retention counters and coverage limitations.\n\n```json\n\(json(snapshot))\n```\n"
        return report
    }
}
