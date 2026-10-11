import Foundation
import XCTest
import Darwin
import AeostaraMacDomain
import AeostaraMacServices

final class NativeResourceTests: XCTestCase {
    private func setup(_ body: (URL, NativeResourcePaths, ScopedNativeResourceIO) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("AeostaraResourceTest-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let config = root.appendingPathComponent("config.json"), desired = root.appendingPathComponent("desired.json")
        try Data("{\"value\":false}".utf8).write(to: config)
        try Data("{\"value\":true}".utf8).write(to: desired)
        let paths = try NativeResourcePaths(root: root, configuration: config, desired: desired,
            backup: root.appendingPathComponent("backup.json"), audit: root.appendingPathComponent("audit.jsonl"))
        try body(root, paths, ScopedNativeResourceIO(paths: paths))
    }
    func testExclusiveBackupCollisionPreservesOriginalBytes() throws {
        try setup { _, paths, io in
            let original = try io.read(.configuration), lease = try io.acquireExclusiveLease()
            defer { lease.release() }
            try io.createBackup(bytes: original, lease: lease)
            XCTAssertThrowsError(try io.createBackup(bytes: Data("replacement".utf8), lease: lease)) { XCTAssertEqual($0 as? NativeResourceError, .backupCollision) }
            XCTAssertEqual(try Data(contentsOf: paths.backup), original)
        }
    }
    func testStaleWriteRejectedAtNativeBoundary() throws {
        try setup { _, paths, io in
            let original = try io.read(.configuration), lease = try io.acquireExclusiveLease()
            defer { lease.release() }
            let newer = Data("{\"value\":true,\"writer\":\"external\"}".utf8)
            try newer.write(to: paths.configuration)
            XCTAssertThrowsError(try io.replaceConfiguration(bytes: Data("{}".utf8), expectedStorageHash: NativeStorageIdentity.hash(original), lease: lease)) {
                XCTAssertEqual($0 as? NativeResourceError, .staleSnapshot)
            }
            XCTAssertEqual(try Data(contentsOf: paths.configuration), newer)
        }
    }
    func testIndependentInstancesAndSymlinkAliasContendOnSameLease() throws {
        try setup { root, paths, io in
            let alias = root.appendingPathComponent("config-alias.json")
            try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: paths.configuration)
            let aliasPaths = try NativeResourcePaths(root: root, configuration: alias, desired: paths.desired, backup: paths.backup, audit: paths.audit)
            let second = try ScopedNativeResourceIO(paths: aliasPaths)
            let lease = try io.acquireExclusiveLease()
            XCTAssertThrowsError(try second.acquireExclusiveLease()) { XCTAssertEqual($0 as? NativeResourceError, .resourceBusy) }
            lease.release()
            let following = try second.acquireExclusiveLease(); following.release()
            XCTAssertEqual(try io.read(.configuration), Data("{\"value\":false}".utf8))
        }
    }
    func testHardlinkScopeEscapeAndDestinationCollisionReject() throws {
        try setup { root, paths, _ in
            let hardlink = root.appendingPathComponent("hardlink.json")
            try FileManager.default.linkItem(at: paths.configuration, to: hardlink)
            XCTAssertThrowsError(try NativeResourcePaths(root: root, configuration: hardlink, desired: paths.desired, backup: paths.backup, audit: paths.audit))
            try FileManager.default.removeItem(at: hardlink)
            XCTAssertThrowsError(try NativeResourcePaths(root: root, configuration: paths.configuration, desired: paths.desired, backup: paths.configuration, audit: paths.audit))
            XCTAssertThrowsError(try NativeResourcePaths(root: root, configuration: URL(fileURLWithPath: "/tmp/outside.json"), desired: paths.desired, backup: paths.backup, audit: paths.audit))
        }
    }
    func testReleasedOrForeignLeaseCannotWrite() throws {
        try setup { _, paths, io in
            let second = try ScopedNativeResourceIO(paths: paths)
            let lease = try io.acquireExclusiveLease()
            XCTAssertThrowsError(try second.createBackup(bytes: Data("{}".utf8), lease: lease)) { XCTAssertEqual($0 as? NativeResourceError, .leaseInvalid) }
            lease.release()
            XCTAssertThrowsError(try io.replaceConfiguration(bytes: Data("{}".utf8), expectedStorageHash: "unbound", lease: lease)) { XCTAssertEqual($0 as? NativeResourceError, .leaseInvalid) }
            XCTAssertFalse(FileManager.default.fileExists(atPath: paths.backup.path))
        }
    }
    func testOversizePublicationRejectedBeforeChangingConfigurationOrCreatingBackup() throws {
        try setup { root, paths, io in
            let original = try io.read(.configuration), lease = try io.acquireExclusiveLease()
            defer { lease.release() }
            let oversized = Data(repeating: 0x20, count: 16 * 1024 * 1024 + 1)
            XCTAssertThrowsError(try io.replaceConfiguration(bytes: oversized, expectedStorageHash: NativeStorageIdentity.hash(original), lease: lease)) {
                XCTAssertEqual($0 as? NativeResourceError, .unsupportedResource)
            }
            XCTAssertEqual(try Data(contentsOf: paths.configuration), original)
            XCTAssertEqual(try io.read(.configuration), original)
            XCTAssertThrowsError(try io.createBackup(bytes: oversized, lease: lease)) {
                XCTAssertEqual($0 as? NativeResourceError, .unsupportedResource)
            }
            XCTAssertFalse(FileManager.default.fileExists(atPath: paths.backup.path))
            XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: root.path).contains { $0.hasPrefix(".aeostara-write-") })
        }
    }
    func testAuditAppendCannotPublishAnUnreadableResource() throws {
        try setup { _, paths, io in
            let full = Data(repeating: 0x20, count: 16 * 1024 * 1024)
            try full.write(to: paths.audit)
            let reference = try AeostaraContract.DiagnosticReference(diagnosticID: "resource-test", chainRootReference: "resource-test", diagnosticKind: .recovery,
                ruleReferences: [.init(ruleID: "ASH-RECOVERY-ACTION-001", sourceReference: "explicit-resource-test", ruleFamily: "RECOVERY")])
            let event = try AeostaraContract.AuditEvent(auditEventID: "resource-test-event", eventSequence: 1, eventType: .observe,
                diagnosticReference: reference, occurredAt: "fixture-time", details: .object([]))
            let lease = try io.acquireExclusiveLease(); defer { lease.release() }
            XCTAssertThrowsError(try io.persistAudit(event, lease: lease)) { XCTAssertEqual($0 as? NativeResourceError, .unsupportedResource) }
            XCTAssertEqual(try Data(contentsOf: paths.audit), full)
            XCTAssertEqual(try io.read(.audit), full)
        }
    }
    func testMovedParentCannotPublishOrReportSuccessOutsideScope() throws {
        let parent = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("AeostaraParentRace-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: parent) }
        let root = parent.appendingPathComponent("root", isDirectory: true), folder = root.appendingPathComponent("resource", isDirectory: true), moved = parent.appendingPathComponent("moved-outside-root", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let config = folder.appendingPathComponent("config.json"), desired = root.appendingPathComponent("desired.json")
        let original = Data("{}".utf8)
        try original.write(to: config); try original.write(to: desired)
        let paths = try NativeResourcePaths(root: root, configuration: config, desired: desired, backup: root.appendingPathComponent("backup.json"), audit: root.appendingPathComponent("audit.jsonl"))
        let io = try ScopedNativeResourceIO(paths: paths), lease = try io.acquireExclusiveLease()
        defer { lease.release() }
        let actorFinished = expectation(description: "isolated parent replacement actor")
        let movedFlag = LockedRaceFlag()
        DispatchQueue.global().async {
            defer { actorFinished.fulfill() }
            for _ in 0..<20000 {
                let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
                if names.contains(where: { $0.hasPrefix(".aeostara-write-") }) {
                    do {
                        try FileManager.default.moveItem(at: folder, to: moved)
                        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
                        try original.write(to: config)
                        movedFlag.set()
                    } catch { }
                    return
                }
                usleep(50)
            }
        }
        let target = Data(repeating: 0x20, count: 16 * 1024 * 1024)
        var rejected = false
        do { try io.replaceConfiguration(bytes: target, expectedStorageHash: NativeStorageIdentity.hash(original), lease: lease) }
        catch { rejected = true }
        wait(for: [actorFinished], timeout: 5)
        XCTAssertTrue(movedFlag.value, "Race precondition was not exercised")
        XCTAssertTrue(rejected, "Moved parent was reported as a successful scoped write")
        XCTAssertEqual(try Data(contentsOf: moved.appendingPathComponent("config.json")), original, "Adapter published outside declared root")
        XCTAssertEqual(try Data(contentsOf: config), original)
    }

}

private final class LockedRaceFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var state = false
    var value: Bool { lock.lock(); defer { lock.unlock() }; return state }
    func set() { lock.lock(); state = true; lock.unlock() }
}
