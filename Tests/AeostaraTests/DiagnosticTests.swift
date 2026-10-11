// Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.
import XCTest
import Darwin
import AeostaraDomain
import AeostaraDevelopmentDiagnostics
@testable import AeostaraServices

final class DiagnosticTests: XCTestCase {
    func testPolicyDenialIsRetainedBeforeSuccessfulEvents() throws {
        for profile in [DiagnosticProfile.release, .development] {
            let limits = try DiagnosticLimits(profile: profile, maximumEvents: 2)
            let recorder: any DiagnosticRecording = profile == .release ? try ReleaseDiagnosticRecorder(limits: limits) : try DevelopmentDiagnosticRecorder(limits: limits)
            let denied = event(.policy, outcome: .blocked), first = event(.mutate), second = event(.mutate)
            recorder.record(denied); recorder.record(first); recorder.record(second)
            let snapshot = recorder.snapshot()
            XCTAssertNoThrow(try snapshot.validate())
            XCTAssertEqual(snapshot.events.map { $0.event.eventID }, [denied.eventID, second.eventID])
            XCTAssertEqual(snapshot.health.dropped, 1)
        }
    }
    #if DEBUG
    func testReplacedStagingNameCannotPublishOrDeleteCallerReplacement() throws {
        let destination = try root().resolvingSymlinksInPath()
        let recorder = try DevelopmentDiagnosticRecorder(); recorder.record(event())
        let exporter = DiagnosticExporter(stagedFileObserver: { stage in
            if stage == .json {
                let name = try XCTUnwrap(FileManager.default.contentsOfDirectory(atPath: destination.path).first { $0.hasPrefix(".aeostara-stage-") })
                let original = destination.appendingPathComponent(name)
                try FileManager.default.moveItem(at: original, to: destination.appendingPathComponent("detached-owned-stage"))
                try FileManager.default.createDirectory(at: original, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
                try Data("caller-owned".utf8).write(to: original.appendingPathComponent("preserve.txt"))
            }
        })
        XCTAssertThrowsError(try exporter.export(recording: recorder, to: destination)) { error in
            XCTAssertEqual((error as? DiagnosticExportError)?.stage, .publish)
            XCTAssertEqual((error as? DiagnosticExportError)?.published, false)
            XCTAssertGreaterThan((error as? DiagnosticExportError)?.cleanupFailures ?? 0, 0)
        }
        let replacement = try XCTUnwrap(FileManager.default.contentsOfDirectory(atPath: destination.path).first { $0.hasPrefix(".aeostara-stage-") })
        XCTAssertEqual(try String(contentsOf: destination.appendingPathComponent(replacement).appendingPathComponent("preserve.txt"), encoding: .utf8), "caller-owned")
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: destination.path).contains { $0.hasPrefix("Aeostara-Diagnostics-") })
        XCTAssertEqual(recorder.snapshot().health.exportFailures, 1)
    }
    #endif
    private final class Clock: DiagnosticClock {
        private let lock = NSLock()
        private var wall = Date(timeIntervalSince1970: 1_800_000_000)
        private var monotonic: UInt64 = 0
        func read() -> DiagnosticClockReading {
            lock.lock(); defer { lock.unlock() }; return .init(wallTime: wall, monotonicNanoseconds: monotonic)
        }
        func advance(wall delta: TimeInterval, monotonic seconds: UInt64) {
            lock.lock(); defer { lock.unlock() }; wall.addTimeInterval(delta); monotonic += seconds * 1_000_000_000
        }
    }
    private func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Aeostara-Diagnostics-Test-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }; return url
    }
    private func event(_ stage: DiagnosticStage = .observe, outcome: DiagnosticOutcome = .succeeded,
                       fault: DiagnosticFault? = nil, causes: [UUID] = [], incident: UUID? = nil,
                       session: UUID = UUID(), operation: UUID = UUID()) -> DiagnosticEvent {
        .init(sessionID: session, operationID: operation, incidentID: incident, stage: stage,
              outcome: outcome, expected: .succeeded, fault: fault, causeEventIDs: causes,
              counters: .init(items: 9, attempts: 1))
    }
    func testDevelopmentCorrelatedPairRetainsEveryTypedFieldAndPrivatePermissions() throws {
        let recorder = try DevelopmentDiagnosticRecorder()
        let session = UUID(), operation = UUID(), incident = UUID()
        let first = event(session: session, operation: operation)
        XCTAssertEqual(recorder.record(first, developmentDetails: {
            .init(before: .init(memberCount: 9, semanticBits: 7, classification: .unstable),
                  after: .init(memberCount: 9, semanticBits: 0, classification: .stable),
                  expected: .init(memberCount: 9, semanticBits: 0), counters: .init(inputBytes: 100, outputBytes: 104))
        }), first.eventID)
        let failure = event(.project, outcome: .failed, fault: .init(code: .mapping), causes: [first.eventID], incident: incident, session: session, operation: operation)
        recorder.record(failure)
        let recovery = event(.containment, outcome: .contained, causes: [failure.eventID], incident: incident, session: session, operation: operation)
        recorder.record(recovery)
        let bundle = try DiagnosticExporter().export(recording: recorder, to: root())
        let snapshot = try DiagnosticCoding.decoder().decode(DiagnosticSnapshot.self, from: Data(contentsOf: bundle.jsonURL))
        try snapshot.validate()
        let markdown = try String(contentsOf: bundle.markdownURL, encoding: .utf8)
        let metadata = try DiagnosticCoding.decoder().decode(DiagnosticExportMetadata.self, from: Data(contentsOf: bundle.metadataURL))
        XCTAssertEqual(snapshot.snapshotID, bundle.bundleID)
        XCTAssertEqual(metadata.bundleID, snapshot.snapshotID)
        XCTAssertEqual(metadata.eventIDs, snapshot.events.map { $0.event.eventID })
        XCTAssertEqual(metadata.incidentIDs, [incident])
        XCTAssertEqual(snapshot.events.prefix(3).map { $0.event.eventID }, [first.eventID, failure.eventID, recovery.eventID])
        XCTAssertEqual(snapshot.events[2].event.outcome, .contained)
        XCTAssertEqual(snapshot.events[1].missingCauseEventIDs, [])
        XCTAssertEqual(snapshot.events[0].details?.after?.semanticBits, 0)
        XCTAssertTrue(markdown.contains(incident.uuidString))
        for record in snapshot.events { XCTAssertTrue(markdown.contains(record.event.eventID.uuidString)) }
        XCTAssertTrue(markdown.contains("Retained-evidence appendix"))
        XCTAssertTrue(markdown.contains("Expected state: members=9"))
        for file in [bundle.jsonURL, bundle.markdownURL, bundle.metadataURL] {
            let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
            XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        }
        XCTAssertEqual((try FileManager.default.attributesOfItem(atPath: bundle.directoryURL.path)[.posixPermissions] as? NSNumber)?.intValue, 0o700)
    }
    func testSyntheticNestedSecretsAndPathsNeverEnterRetentionOrExports() throws {
        let sentinel = "SENTINEL_SECRET_" + UUID().uuidString
        let inner = NSError(domain: sentinel, code: 17, userInfo: [NSLocalizedDescriptionKey: sentinel, NSFilePathErrorKey: "/private/" + sentinel])
        let error = NSError(domain: NSCocoaErrorDomain, code: 260, userInfo: [NSUnderlyingErrorKey: inner, NSLocalizedDescriptionKey: sentinel, "metadata": ["token": sentinel], NSFilePathErrorKey: "/Users/" + sentinel])
        let recorder = try DevelopmentDiagnosticRecorder()
        recorder.record(event(.observe, outcome: .failed, fault: .init(code: .execution, error: error)))
        recorder.record(event(.observe, outcome: .failed, fault: .init(code: .execution, error: inner)))
        let retained = try DiagnosticCoding.encoder().encode(recorder.snapshot())
        XCTAssertFalse(String(decoding: retained, as: UTF8.self).contains(sentinel))
        let bundle = try DiagnosticExporter().export(recording: recorder, to: root())
        for url in [bundle.jsonURL, bundle.markdownURL, bundle.metadataURL] { XCTAssertFalse(try String(contentsOf: url, encoding: .utf8).contains(sentinel)) }
        let snapshot = recorder.snapshot()
        XCTAssertEqual(snapshot.events[0].event.fault?.nativeCode, .init(domain: .cocoa, code: 260))
        XCTAssertNil(snapshot.events[1].event.fault?.nativeCode)
        XCTAssertEqual(snapshot.events[1].event.fault?.nativeCodeUnavailable, .unrecognizedNativeDomain)
    }
    func testReleaseNeverEvaluatesRichSupplierAndRetainsEssentialFaultAndAudit() throws {
        let recorder = try ReleaseDiagnosticRecorder()
        var evaluated = 0
        for _ in 0..<20 { recorder.record(event(), developmentDetails: { evaluated += 1; return .init(before: .init(memberCount: 9)) }) }
        recorder.record(event(.project, outcome: .failed, fault: .init(code: .mapping)), developmentDetails: { evaluated += 1; return .init() })
        recorder.record(event(.audit))
        let snapshot = recorder.snapshot(); try snapshot.validate()
        XCTAssertEqual(evaluated, 0); XCTAssertEqual(snapshot.events.count, 2); XCTAssertEqual(snapshot.health.sampled, 20)
        XCTAssertTrue(snapshot.events.allSatisfy { $0.details == nil && $0.stack.isEmpty && $0.detailsUnavailable == .developmentExcluded })
        let bundle = try DiagnosticExporter().export(recording: recorder, to: root())
        let exported = try DiagnosticCoding.decoder().decode(DiagnosticSnapshot.self, from: Data(contentsOf: bundle.jsonURL))
        XCTAssertEqual(exported.profile, .release); XCTAssertEqual(exported.events[0].event.fault?.code, .mapping)
    }
    func testDisabledReleaseCaptureKeepsHealthWithoutEvaluatingSupplier() throws {
        let recorder = try ReleaseDiagnosticRecorder(limits: .init(profile: .release, captureEnabled: false))
        var invoked = false
        XCTAssertNil(recorder.record(event(.audit), developmentDetails: { invoked = true; return .init() }))
        XCTAssertFalse(invoked); XCTAssertEqual(recorder.snapshot().health.sampled, 1); XCTAssertTrue(recorder.snapshot().events.isEmpty)
    }
    func testLimitsRejectExpansionAndNonfiniteAge() throws {
        XCTAssertThrowsError(try DiagnosticLimits(profile: .release, maximumEvents: 513))
        XCTAssertThrowsError(try DiagnosticLimits(profile: .release, maximumEventBytes: 4097))
        XCTAssertThrowsError(try DiagnosticLimits(profile: .development, maximumRetainedBytes: 16_777_217))
        XCTAssertThrowsError(try DiagnosticLimits(profile: .release, maximumAgeSeconds: .infinity))
        XCTAssertThrowsError(try ReleaseDiagnosticRecorder(limits: .development))
        XCTAssertThrowsError(try DevelopmentDiagnosticRecorder(limits: .release))
    }
    func testCountByteAndOversizeBoundsPreferIncidentEvidenceAndExposeLostCauses() throws {
        let recorder = try DevelopmentDiagnosticRecorder(limits: .init(profile: .development, maximumEvents: 2))
        let first = event(), failure = event(.project, outcome: .failed, fault: .init(code: .mapping), incident: UUID())
        recorder.record(first); recorder.record(failure)
        let last = event(.containment, outcome: .contained, causes: [first.eventID], incident: failure.incidentID)
        recorder.record(last)
        let snapshot = recorder.snapshot(); try snapshot.validate()
        XCTAssertEqual(snapshot.events.map { $0.event.eventID }, [failure.eventID, last.eventID])
        XCTAssertEqual(snapshot.events.last?.missingCauseEventIDs, [first.eventID]); XCTAssertEqual(snapshot.health.dropped, 1); XCTAssertEqual(snapshot.health.lostLinks, 1)
        let small = try DevelopmentDiagnosticRecorder(limits: .init(profile: .development, maximumEventBytes: 16))
        XCTAssertNil(small.record(event())); XCTAssertEqual(small.snapshot().health.oversized, 1)
        let byteBound = try DevelopmentDiagnosticRecorder(limits: .init(profile: .development, maximumRetainedBytes: 1500))
        for _ in 0..<10 { byteBound.record(event()) }
        let byteSnapshot = byteBound.snapshot(); try byteSnapshot.validate()
        XCTAssertLessThanOrEqual(byteSnapshot.retainedBytes, 1500); XCTAssertGreaterThan(byteSnapshot.health.dropped, 0)
    }
    func testMonotonicExpiryAndWallHighWaterPreventBackwardClockRetentionExtension() throws {
        let clock = Clock(), recorder = try DevelopmentDiagnosticRecorder(limits: .init(profile: .development, maximumAgeSeconds: 10), clock: clock)
        recorder.record(event()); clock.advance(wall: -1000, monotonic: 11)
        XCTAssertTrue(recorder.snapshot().events.isEmpty); XCTAssertEqual(recorder.snapshot().health.expired, 1)
        recorder.record(event()); clock.advance(wall: 2000, monotonic: 0)
        XCTAssertTrue(recorder.snapshot().events.isEmpty); XCTAssertEqual(recorder.snapshot().health.expired, 2)
    }
    func testPurgePreservesCallerSnapshotAndSingleExportLeaseIsReleasedExplicitly() throws {
        let recorder = try DevelopmentDiagnosticRecorder(); recorder.record(event())
        let frozen = try recorder.beginExport()
        XCTAssertThrowsError(try recorder.beginExport()); recorder.purge()
        XCTAssertEqual(frozen.events.count, 1); XCTAssertTrue(recorder.snapshot().events.isEmpty); XCTAssertEqual(recorder.snapshot().health.purged, 1)
        recorder.endExport(snapshotID: UUID(), succeeded: false)
        XCTAssertThrowsError(try recorder.beginExport())
        recorder.endExport(snapshotID: frozen.snapshotID, succeeded: false)
        let next = try recorder.beginExport(); XCTAssertEqual(next.health.exportFailures, 1)
        recorder.endExport(snapshotID: next.snapshotID, succeeded: true)
    }
    func testConcurrentCaptureSnapshotsAndExportPreserveBoundedUntornEvidence() throws {
        let recorder = try DevelopmentDiagnosticRecorder(limits: .init(profile: .development, maximumEvents: 64))
        DispatchQueue.concurrentPerform(iterations: 400) { index in
            recorder.record(event(.diagnose, outcome: .succeeded))
            if index.isMultiple(of: 20) {
                do { try recorder.snapshot().validate() } catch { XCTFail("Concurrent snapshot validation failed") }
            }
        }
        let snapshot = recorder.snapshot(); try snapshot.validate()
        XCTAssertEqual(snapshot.events.count, 64); XCTAssertEqual(snapshot.health.dropped, 336)
        XCTAssertEqual(Set(snapshot.events.map { $0.sequence }).count, 64)
        let bundle = try DiagnosticExporter().export(recording: recorder, to: root())
        try DiagnosticCoding.decoder().decode(DiagnosticSnapshot.self, from: Data(contentsOf: bundle.jsonURL)).validate()
    }
    #if DEBUG
    func testPartialNativeExportFailureRemovesOnlyOwnedStagePreservesEvidenceAndLease() throws {
        let recorder = try DevelopmentDiagnosticRecorder(); recorder.record(event(.project, outcome: .failed, fault: .init(code: .mapping)))
        let destination = try root(), unrelated = destination.appendingPathComponent("caller-owned.txt")
        try Data("preserve".utf8).write(to: unrelated)
        let exporter = DiagnosticExporter(stagedFileObserver: { stage in
            if stage == .json { throw DiagnosticExportError(stage: .markdown, nativeCode: ENOSPC) }
        })
        XCTAssertThrowsError(try exporter.export(recording: recorder, to: destination)) { error in
            let failure = error as? DiagnosticExportError
            XCTAssertEqual(failure?.stage, .markdown); XCTAssertEqual(failure?.nativeCode, ENOSPC)
            XCTAssertEqual(failure?.published, false); XCTAssertEqual(failure?.cleanupFailures, 0)
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: destination.path), ["caller-owned.txt"])
        XCTAssertEqual(try String(contentsOf: unrelated, encoding: .utf8), "preserve")
        XCTAssertEqual(recorder.snapshot().events.first?.event.fault?.code, .mapping)
        XCTAssertEqual(recorder.snapshot().health.exportFailures, 1)
        XCTAssertNoThrow(try DiagnosticExporter().export(recording: recorder, to: destination))
    }
    #endif
    func testExistingPublishedBundleIsNeverOverwrittenAndExportLeaseEndsOnCollision() throws {
        final class FrozenRecorder: DiagnosticRecording {
            let frozen: DiagnosticSnapshot
            var completed: [Bool] = []
            init(_ frozen: DiagnosticSnapshot) { self.frozen = frozen }
            func record(_ event: DiagnosticEvent, developmentDetails: (() -> DiagnosticDevelopmentDetails)?) -> UUID? { nil }
            func snapshot() -> DiagnosticSnapshot { frozen }
            func beginExport() throws -> DiagnosticSnapshot { frozen }
            func endExport(snapshotID: UUID, succeeded: Bool) { completed.append(succeeded) }
            func purge() {}
        }
        let capture = try DevelopmentDiagnosticRecorder(); capture.record(event())
        let fixed = FrozenRecorder(capture.snapshot()), destination = try root()
        let first = try DiagnosticExporter().export(recording: fixed, to: destination)
        let original = try Data(contentsOf: first.jsonURL)
        XCTAssertThrowsError(try DiagnosticExporter().export(recording: fixed, to: destination)) { error in
            XCTAssertEqual((error as? DiagnosticExportError)?.stage, .publish)
            XCTAssertEqual((error as? DiagnosticExportError)?.nativeCode, EEXIST)
            XCTAssertEqual((error as? DiagnosticExportError)?.published, false)
        }
        XCTAssertEqual(try Data(contentsOf: first.jsonURL), original)
        XCTAssertEqual(fixed.completed, [true, false])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: destination.path).count, 1)
    }
    func testRootSymlinkAndInvalidDecodedSnapshotRejectedWithoutPublication() throws {
        let destination = try root(), link = destination.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: destination)
        let recorder = try DevelopmentDiagnosticRecorder(); recorder.record(event())
        XCTAssertThrowsError(try DiagnosticExporter().export(recording: recorder, to: link))
        let data = try DiagnosticCoding.encoder().encode(recorder.snapshot())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var provenance = try XCTUnwrap(object["provenance"] as? [String: Any]); provenance["sourceCommit"] = "/Users/private/SENTINEL_SECRET"
        object["provenance"] = provenance
        let invalid = try DiagnosticCoding.decoder().decode(DiagnosticSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertThrowsError(try invalid.validate())
        var limits = try XCTUnwrap(object["limits"] as? [String: Any]); limits["maximumEvents"] = 10_000_000
        object["limits"] = limits
        let expanded = try DiagnosticCoding.decoder().decode(DiagnosticSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertThrowsError(try expanded.validate())
    }
}
