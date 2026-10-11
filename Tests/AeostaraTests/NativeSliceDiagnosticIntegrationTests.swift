import Foundation
import XCTest
import AeostaraDomain
import AeostaraServices
import AeostaraDevelopmentDiagnostics

final class NativeSliceDiagnosticIntegrationTests: XCTestCase {
    func testNativeSuccessAndInjectedMappingFailureHavePairedExports() throws {
        let configured = ProcessInfo.processInfo.environment["AEOSTARA_SLICE_EVIDENCE_ROOT"]
        let parent = configured.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? FileManager.default.temporaryDirectory
        let owned = parent.appendingPathComponent("native-slice-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: owned, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { if configured == nil { try? FileManager.default.removeItem(at: owned) } }
        let sentinel = "synthetic-sensitive-config-6a91801e"
        let session = UUID()
        let successRecorder = try DevelopmentDiagnosticRecorder()
        let success = try NativeHealingEngine(context: NativeSliceContext.make(), timestampProvider: { "2026-10-11T00:00:00Z" }, recorder: successRecorder, sessionID: session)
            .prepare(observed: NativeSliceContext.document(cosmetic: sentinel), desired: NativeSliceContext.document(cosmetic: "different cosmetic text"))
        XCTAssertEqual(success.stateClass, .STABLE)
        XCTAssertEqual(success.recoveryCategory, .NO_ACTION)
        XCTAssertFalse(success.dryRunResult.wouldMutate)
        let failureRecorder = try DevelopmentDiagnosticRecorder()
        let failedEngine = NativeHealingEngine(context: try NativeSliceContext.make(missingLast: true), timestampProvider: { "2026-10-11T00:00:00Z" }, recorder: failureRecorder, sessionID: session)
        let failure: LifecycleFailure
        do {
            _ = try failedEngine.prepare(observed: NativeSliceContext.document(missingLast: true), desired: NativeSliceContext.document())
            return XCTFail("Missing actual mapping evidence must fail")
        } catch let error as LifecycleFailure { failure = error }
        XCTAssertEqual(failure.code, .missingEvidence)
        let exporter = DiagnosticExporter()
        let successBundle = try exporter.export(recording: successRecorder, to: owned)
        let failureBundle = try exporter.export(recording: failureRecorder, to: owned)
        var bundleEvidence: [JSONValue] = []
        for (label, bundle) in [("success", successBundle), ("mapping-failure", failureBundle)] {
            let json = try Data(contentsOf: bundle.jsonURL)
            let markdown = try String(contentsOf: bundle.markdownURL, encoding: .utf8)
            let snapshot = try DiagnosticCoding.decoder().decode(DiagnosticSnapshot.self, from: json)
            let metadata = try DiagnosticCoding.decoder().decode(DiagnosticExportMetadata.self, from: Data(contentsOf: bundle.metadataURL))
            try snapshot.validate()
            XCTAssertEqual(snapshot.snapshotID, bundle.bundleID)
            XCTAssertEqual(metadata.bundleID, bundle.bundleID)
            XCTAssertEqual(metadata.eventIDs, snapshot.events.map { $0.event.eventID })
            XCTAssertEqual(metadata.jsonSHA256, CanonicalJSON.hashBytes(json))
            XCTAssertEqual(metadata.markdownSHA256, CanonicalJSON.hashBytes(Data(markdown.utf8)))
            XCTAssertFalse(String(decoding: json, as: UTF8.self).contains(sentinel))
            XCTAssertFalse(markdown.contains(sentinel))
            let nativeEvents = snapshot.events.filter { $0.event.component == .domain }
            XCTAssertTrue(nativeEvents.allSatisfy { $0.event.sessionID == session })
            XCTAssertEqual(snapshot.events.last?.event.component, .exporter)
            XCTAssertEqual(snapshot.events.last?.event.stage, .export)
            XCTAssertEqual(snapshot.events.last?.event.outcome, .started)
            for record in snapshot.events { XCTAssertTrue(markdown.contains("Event " + record.event.eventID.uuidString)) }
            if label == "success" {
                XCTAssertEqual(nativeEvents.map { $0.event.stage }, [.observe,.observe,.normalize,.project,.diagnose,.classify,.recoverability,.plan])
                XCTAssertEqual(nativeEvents.last?.event.outcome, .noAction)
                XCTAssertFalse(snapshot.events.contains { $0.event.fault != nil })
            } else {
                let fault = try XCTUnwrap(nativeEvents.last)
                XCTAssertEqual(fault.event.stage, .project)
                XCTAssertEqual(fault.event.outcome, .failed)
                XCTAssertEqual(fault.event.expected, .succeeded)
                XCTAssertEqual(fault.event.fault?.code, .mapping)
                XCTAssertNotNil(fault.event.incidentID)
                XCTAssertFalse(fault.event.causeEventIDs.isEmpty)
                XCTAssertTrue(fault.missingCauseEventIDs.isEmpty)
            }
            bundleEvidence.append(.object([JSONMember("case", .string(label)), JSONMember("bundle", .string(bundle.directoryURL.lastPathComponent)),
                                           JSONMember("eventCount", .number(.integer(String(snapshot.events.count)))),
                                           JSONMember("jsonSHA256", .string(metadata.jsonSHA256)), JSONMember("markdownSHA256", .string(metadata.markdownSHA256))]))
        }
        try ContractCoding.canonicalEncode(success.dryRunResult).write(to: owned.appendingPathComponent("native-success-dry-run.json"))
        try ContractCoding.canonicalEncode(success.validityDiagnostic).write(to: owned.appendingPathComponent("native-success-validity.json"))
        try ContractCoding.canonicalEncode(success.mapping).write(to: owned.appendingPathComponent("native-success-mapping.json"))
        try ContractCoding.canonicalEncode(success.auditChain).write(to: owned.appendingPathComponent("native-success-audit.json"))
        try ContractCoding.canonicalEncode(failure.diagnosticChain).write(to: owned.appendingPathComponent("native-failure-diagnostic-chain.json"))
        try ContractCoding.canonicalEncode(failure.auditChain).write(to: owned.appendingPathComponent("native-failure-audit-chain.json"))
        let receipt = JSONValue.object([JSONMember("scope", .string("Actual minimum native preparation and injected missing mapping evidence; no execution/backup/release claim")),
                                        JSONMember("stateClass", success.stateClass.jsonValue), JSONMember("recoveryCategory", success.recoveryCategory.jsonValue),
                                        JSONMember("wouldMutate", .bool(success.dryRunResult.wouldMutate)), JSONMember("failureCode", .string(failure.code.rawValue)),
                                        JSONMember("bundles", .array(bundleEvidence))])
        try CanonicalJSON.encode(receipt).write(to: owned.appendingPathComponent("native-slice-paired-receipt.json"))
    }
}
