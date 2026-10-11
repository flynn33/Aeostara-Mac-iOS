// Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.
import XCTest
import CryptoKit
import Darwin
import AeostaraMacDomain
import AeostaraMacDevelopmentDiagnostics
@testable import AeostaraMacServices

final class DiagnosticTests: XCTestCase {
    private final class Clock: DiagnosticClock {
        var monotonic = 0.0
        var wall = 1_800_000_000.0
        func now() -> DiagnosticTime { .init(monotonicSeconds: monotonic, wallUTCSeconds: wall) }
    }
    private final class Frozen: DiagnosticRecording {
        let value: DiagnosticSnapshot
        init(_ value: DiagnosticSnapshot) { self.value = value }
        func record(_ event: DiagnosticEvent, developmentDetails: (() -> DiagnosticDevelopmentDetails)?) -> UUID? { nil }
        func snapshot() -> DiagnosticSnapshot { value }
        func beginExport() throws -> DiagnosticSnapshot { value }
        func endExport(snapshotID: UUID, succeeded: Bool) {}
        func purge() {}
    }
    private func root() throws -> URL {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("Aeostara-diagnostic-test-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }
    private func event(stage: DiagnosticStage = .observe, outcome: DiagnosticOutcome = .succeeded,
                       fault: DiagnosticFault? = nil, session: UUID = UUID(), operation: UUID = UUID(),
                       incident: UUID? = nil, causes: [UUID] = []) -> DiagnosticEvent {
        .init(sessionID: session, operationID: operation, incidentID: incident, stage: stage,
              outcome: outcome, expected: .succeeded, fault: fault, causeEventIDs: causes,
              counters: .init(inputFields: 9))
    }
    func testRichPairUsesOneFrozenSnapshotAndEveryRetainedField() throws {
        let recorder = try DevelopmentDiagnosticRecorder()
        let session = UUID(), operation = UUID(), incident = UUID()
        let observed = event(session: session, operation: operation, incident: incident)
        XCTAssertEqual(recorder.record(observed, developmentDetails: { .init(observedFieldCount: 9, desiredFieldCount: 9, ruleCount: 9, durationSeconds: 0.1) }), observed.eventID)
        let failed = event(stage: .project, outcome: .failed, fault: .init(code: .mapping), session: session,
                           operation: operation, incident: incident, causes: [observed.eventID])
        XCTAssertEqual(recorder.record(failed), failed.eventID)
        let bundle = try DiagnosticExporter().export(recording: recorder, to: root())
        let data = try Data(contentsOf: bundle.json)
        let snapshot = try JSONDecoder().decode(DiagnosticSnapshot.self, from: data)
        XCTAssertTrue(snapshot.isValid); XCTAssertEqual(snapshot.snapshotID, bundle.snapshotID)
        XCTAssertEqual(snapshot.records.first?.details?.ruleCount, 9)
        XCTAssertEqual(snapshot.records.first(where: { $0.event.eventID == failed.eventID })?.event.causeEventIDs, [observed.eventID])
        let markdown = try String(contentsOf: bundle.markdown, encoding: .utf8)
        for record in snapshot.records { XCTAssertTrue(markdown.contains("### Event `" + record.event.eventID.uuidString + "`")) }
        for id in snapshot.incidentIDs { XCTAssertTrue(markdown.contains("## Incident `" + id.uuidString + "`")) }
        let appendix = try XCTUnwrap(markdown.components(separatedBy: "## Full retained-evidence appendix").last)
        let frozenJSON = try XCTUnwrap(appendix.components(separatedBy: "```json\n").last?.components(separatedBy: "\n```").first)
        XCTAssertEqual(try JSONDecoder().decode(DiagnosticSnapshot.self, from: Data(frozenJSON.utf8)), snapshot)
        let completion = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: bundle.completionMetadata)) as? [String: Any])
        XCTAssertEqual(completion["eventCount"] as? Int, snapshot.records.count)
        for part in try XCTUnwrap(completion["parts"] as? [[String: Any]]) {
            let name = try XCTUnwrap(part["name"] as? String)
            let bytes = try Data(contentsOf: bundle.directory.appendingPathComponent(name))
            XCTAssertEqual(part["bytes"] as? Int, bytes.count)
            XCTAssertEqual(part["sha256"] as? String, SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined())
        }
        XCTAssertEqual((try FileManager.default.attributesOfItem(atPath: bundle.directory.path)[.posixPermissions] as? NSNumber)?.intValue, 0o700)
        for file in [bundle.json, bundle.markdown, bundle.completionMetadata] {
            XCTAssertEqual((try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        }
    }
    func testLeanCaptureNeverEvaluatesRichSupplierAndPreservesSafeFault() throws {
        let recorder = try ReleaseDiagnosticRecorder()
        let sentinel = "SENTINEL_SECRET /Users/private/state.json <script>"
        let inner = NSError(domain: "private-domain-" + sentinel, code: 77, userInfo: [NSLocalizedDescriptionKey: sentinel])
        let error = NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES), userInfo: [NSUnderlyingErrorKey: inner, NSFilePathErrorKey: sentinel])
        var called = false
        recorder.record(event(stage: .audit, outcome: .failed, fault: .init(code: .audit, error: error)), developmentDetails: { called = true; return .init(ruleCount: 9) })
        XCTAssertFalse(called)
        let snapshot = recorder.snapshot()
        XCTAssertTrue(snapshot.isValid); XCTAssertEqual(snapshot.records.first?.event.fault?.nativeCode, Int(EACCES))
        XCTAssertEqual(snapshot.records.first?.event.fault?.code, .audit)
        XCTAssertTrue(snapshot.records.allSatisfy { $0.details == nil && $0.stackFrames.isEmpty })
        let bundle = try DiagnosticExporter().export(recording: recorder, to: root())
        for file in [bundle.json, bundle.markdown, bundle.completionMetadata] {
            let text = try String(contentsOf: file, encoding: .utf8)
            XCTAssertFalse(text.contains("SENTINEL_SECRET")); XCTAssertFalse(text.contains("/Users/private")); XCTAssertFalse(text.contains("private-domain"))
        }
    }
    func testConsumersCanOnlyLowerOrDisableReleaseLimits() throws {
        XCTAssertThrowsError(try ReleaseDiagnosticRecorder(limits: .developmentDefaults))
        XCTAssertThrowsError(try DiagnosticLimits(eventCount: 4097))
        let limits = try DiagnosticLimits(eventCount: 2, eventBytes: 2000, retainedBytes: 3000, ageSeconds: 1, enabled: false)
        let recorder = try ReleaseDiagnosticRecorder(limits: limits)
        var called = false
        XCTAssertNil(recorder.record(event(), developmentDetails: { called = true; return .init() }))
        XCTAssertFalse(called); XCTAssertTrue(recorder.snapshot().records.isEmpty)
        XCTAssertEqual(recorder.snapshot().health.disabledEvents, 1)
    }
    func testCountByteAndPerEventBoundsAccountForLostEvidence() throws {
        let countBound = try ReleaseDiagnosticRecorder(limits: .init(eventCount: 2))
        for _ in 0..<5 { countBound.record(event()) }
        XCTAssertEqual(countBound.snapshot().records.count, 2); XCTAssertEqual(countBound.snapshot().health.evicted, 3)
        let bytes = try ReleaseDiagnosticRecorder(limits: .init(eventCount: 20, eventBytes: 1000, retainedBytes: 1100))
        for _ in 0..<10 { bytes.record(event()) }
        XCTAssertLessThanOrEqual(bytes.snapshot().retainedSerializedBytes, 1100)
        XCTAssertGreaterThan(bytes.snapshot().health.evicted, 0); XCTAssertTrue(bytes.snapshot().isValid)
        let oversized = try ReleaseDiagnosticRecorder(limits: .init(eventBytes: 20))
        XCTAssertNil(oversized.record(event())); XCTAssertEqual(oversized.snapshot().health.droppedOversized, 1)
    }
    func testPolicyDenialSurvivesPreferentialSuccessEviction() throws {
        let limits = try DiagnosticLimits(eventCount: 2)
        for recorder in [try ReleaseDiagnosticRecorder(limits: limits) as any DiagnosticRecording,
                         try DevelopmentDiagnosticRecorder(limits: limits) as any DiagnosticRecording] {
            let blocked = event(stage: .policy, outcome: .blocked)
            let firstSuccess = event(), secondSuccess = event()
            recorder.record(blocked); recorder.record(firstSuccess); recorder.record(secondSuccess)
            let snapshot = recorder.snapshot()
            XCTAssertTrue(snapshot.isValid)
            XCTAssertEqual(snapshot.records.map { $0.event.eventID }, [blocked.eventID, secondSuccess.eventID])
            XCTAssertEqual(snapshot.health.evicted, 1)
        }
    }
    func testExpiredAndMissingCausesRemainExplicitWithBackwardClock() throws {
        let clock = Clock(), limits = try DiagnosticLimits(eventCount: 2, ageSeconds: 10)
        let recorder = try ReleaseDiagnosticRecorder(limits: limits, clock: clock)
        let session = UUID(), operation = UUID(), incident = UUID()
        let first = event(session: session, operation: operation, incident: incident)
        recorder.record(first)
        recorder.record(event(session: session, operation: operation, incident: incident, causes: [first.eventID]))
        recorder.record(event(stage: .verify, session: session, operation: operation, incident: incident))
        let bounded = recorder.snapshot()
        XCTAssertEqual(bounded.records.first?.omittedReferences, 1); XCTAssertTrue(bounded.records.first?.event.causeEventIDs.isEmpty == true)
        XCTAssertTrue(bounded.isValid)
        clock.monotonic = 11; clock.wall += 11
        XCTAssertTrue(recorder.snapshot().records.isEmpty); XCTAssertEqual(recorder.snapshot().health.expired, 2)
        recorder.record(event()); clock.monotonic = 0; clock.wall -= 100
        XCTAssertEqual(recorder.snapshot().records.first?.monotonicSeconds, 11)
        clock.wall += 111
        XCTAssertTrue(recorder.snapshot().records.isEmpty)
        XCTAssertGreaterThan(recorder.snapshot().health.invalidEvidence, 0)
    }
    func testExportLeaseAndPurgeDoNotEraseFrozenEvidence() throws {
        let recorder = try DevelopmentDiagnosticRecorder(); recorder.record(event(outcome: .failed, fault: .init(code: .mapping)))
        let frozen = try recorder.beginExport(); XCTAssertThrowsError(try recorder.beginExport())
        recorder.purge(); XCTAssertTrue(recorder.snapshot().records.isEmpty); XCTAssertEqual(frozen.records.count, 1)
        recorder.endExport(snapshotID: UUID(), succeeded: true); XCTAssertThrowsError(try recorder.beginExport())
        recorder.endExport(snapshotID: frozen.snapshotID, succeeded: false)
        XCTAssertEqual(recorder.snapshot().health.purgedEvents, 1); XCTAssertEqual(recorder.snapshot().health.exportFailures, 1)
        let next = try recorder.beginExport(); recorder.endExport(snapshotID: next.snapshotID, succeeded: true)
    }
    func testConcurrentCaptureProducesUniqueMonotonicSequence() throws {
        let recorder = try ReleaseDiagnosticRecorder()
        DispatchQueue.concurrentPerform(iterations: 300) { _ in recorder.record(event()) }
        let snapshot = recorder.snapshot()
        XCTAssertEqual(snapshot.records.count, 300); XCTAssertTrue(snapshot.isValid)
        XCTAssertEqual(Set(snapshot.records.map { $0.sequence }).count, 300)
        XCTAssertEqual(Set(snapshot.records.map { $0.event.eventID }).count, 300)
    }
    func testExistingPublishedBundleCannotBeOverwritten() throws {
        let recorder = try ReleaseDiagnosticRecorder(); recorder.record(event())
        let frozen = Frozen(recorder.snapshot()), destination = try root()
        let first = try DiagnosticExporter().export(recording: frozen, to: destination)
        let bytes = try Data(contentsOf: first.json)
        XCTAssertThrowsError(try DiagnosticExporter().export(recording: frozen, to: destination)) { error in
            XCTAssertEqual((error as? DiagnosticExportError)?.stage, .publish)
            XCTAssertEqual((error as? DiagnosticExportError)?.publicationMayHaveCompleted, false)
            XCTAssertEqual((error as? DiagnosticExportError)?.incompleteStageRetained, false)
        }
        XCTAssertEqual(try Data(contentsOf: first.json), bytes)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: destination.path).count, 1)
    }
    #if DEBUG
    func testMarkdownFailureCleansOnlyOwnedStageAndPreservesOriginalFault() throws {
        let recorder = try ReleaseDiagnosticRecorder(); recorder.record(event(outcome: .failed, fault: .init(code: .mapping)))
        let destination = try root(), unrelated = destination.appendingPathComponent("caller-owned.txt")
        try Data("preserve".utf8).write(to: unrelated)
        XCTAssertThrowsError(try DiagnosticExporter(failBefore: .writeMarkdown).export(recording: recorder, to: destination)) { error in
            XCTAssertEqual((error as? DiagnosticExportError)?.stage, .writeMarkdown)
            XCTAssertEqual((error as? DiagnosticExportError)?.nativeCode, EIO)
            XCTAssertEqual((error as? DiagnosticExportError)?.publicationMayHaveCompleted, false)
            XCTAssertEqual((error as? DiagnosticExportError)?.incompleteStageRetained, false)
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: destination.path), ["caller-owned.txt"])
        XCTAssertEqual(try String(contentsOf: unrelated, encoding: .utf8), "preserve")
        XCTAssertEqual(recorder.snapshot().records.first?.event.fault?.code, .mapping)
        XCTAssertEqual(recorder.snapshot().health.exportFailures, 1)
        XCTAssertNoThrow(try DiagnosticExporter().export(recording: recorder, to: destination))
    }
    #endif
    func testSymlinkRootAndDecodedUntrustedIdentityFailClosed() throws {
        let destination = try root(), link = destination.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: destination)
        let recorder = try ReleaseDiagnosticRecorder(); recorder.record(event())
        XCTAssertThrowsError(try DiagnosticExporter().export(recording: recorder, to: link))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(recorder.snapshot())) as? [String: Any])
        var identity = try XCTUnwrap(object["identity"] as? [String: Any]); identity["sourceCommit"] = "/Users/private/SENTINEL_SECRET"
        object["identity"] = identity
        let invalid = try JSONDecoder().decode(DiagnosticSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertFalse(invalid.isValid)
        XCTAssertThrowsError(try DiagnosticExporter().export(recording: Frozen(invalid), to: destination))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: destination.path), ["link"])
    }
}
