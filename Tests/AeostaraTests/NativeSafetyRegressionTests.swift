import Foundation
import XCTest
import AeostaraDomain
@testable import AeostaraServices

final class NativeSafetyRegressionTests: XCTestCase {
    func testSandboxAdapterRejectsOutsideRootWithoutCreatingFile() throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let root = parent.appendingPathComponent("root", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        let outside = parent.appendingPathComponent("outside.json")
        XCTAssertThrowsError(try SandboxFileSystem(documentsDirectory: root).writeFile(path: outside.path, content: "{}"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: outside.path))
    }
    func testNativeCopyCannotReplaceExistingBackup() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source.json"), backup = root.appendingPathComponent("backup.json")
        try Data("new".utf8).write(to: source); try Data("original".utf8).write(to: backup)
        let fs = SandboxFileSystem(documentsDirectory: root)
        XCTAssertFalse(try fs.copyFile(from: source.path, to: backup.path))
        XCTAssertEqual(try String(contentsOf: backup), "original")
    }
    func testReplacedDeclaredRootCannotMutateRelocatedOriginal() throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        let root = parent.appendingPathComponent("root",isDirectory:true),moved = parent.appendingPathComponent("moved",isDirectory:true)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        defer { try? FileManager.default.removeItem(at:parent) }
        let config = root.appendingPathComponent("config.json")
        try Data("original".utf8).write(to:config)
        let io = try ScopedResourceIO(rootURL:root)
        try FileManager.default.moveItem(at:root,to:moved)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:false,attributes:[.posixPermissions:0o700])
        try Data("original".utf8).write(to:config)
        XCTAssertThrowsError(try io.writeScoped(path:config.path,bytes:Data("changed".utf8))) { XCTAssertEqual($0 as? ResourceIOFault,.scopeViolation) }
        XCTAssertEqual(try Data(contentsOf:moved.appendingPathComponent("config.json")),Data("original".utf8))
        XCTAssertEqual(try Data(contentsOf:config),Data("original".utf8))
    }
    #if DEBUG
    func testReplacedWriteStagingNameCannotPublishOrDeleteCallerFile() throws {
        for throwAfterSwap in [false,true] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
            try FileManager.default.createDirectory(at:root,withIntermediateDirectories:false,attributes:[.posixPermissions:0o700])
            defer { try? FileManager.default.removeItem(at:root) }
            let config = root.appendingPathComponent("config.json");try Data("original".utf8).write(to:config)
            var replacement: URL?
            let io = try ScopedResourceIO(rootURL:root,writeStageObserver:{ temporary in
                replacement = temporary
                try FileManager.default.moveItem(at:temporary,to:root.appendingPathComponent("owned-detached"))
                try Data("caller-owned".utf8).write(to:temporary)
                if throwAfterSwap { throw ResourceIOFault.writeFailed }
            })
            XCTAssertThrowsError(try io.writeScoped(path:config.path,bytes:Data("approved".utf8)))
            XCTAssertEqual(try Data(contentsOf:config),Data("original".utf8))
            XCTAssertEqual(try Data(contentsOf:XCTUnwrap(replacement)),Data("caller-owned".utf8))
            XCTAssertEqual(try Data(contentsOf:root.appendingPathComponent("owned-detached")),Data("approved".utf8))
        }
    }
    func testReplacedParentAndConfigurationIdentityCannotPublishOrCleanDetachedStage() throws {
        for replaceParent in [true,false] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
            let directory = root.appendingPathComponent("resources",isDirectory:true), moved = root.appendingPathComponent("detached",isDirectory:true)
            try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
            defer { try? FileManager.default.removeItem(at:root) }
            let config = directory.appendingPathComponent("config.json"); try Data("original".utf8).write(to:config)
            var stage: URL?
            let io = try ScopedResourceIO(rootURL:root,writeStageObserver:{ temporary in
                stage = temporary
                if replaceParent {
                    try FileManager.default.moveItem(at:directory,to:moved)
                    try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:false,attributes:[.posixPermissions:0o700])
                    try Data("original".utf8).write(to:config)
                } else {
                    try FileManager.default.moveItem(at:config,to:directory.appendingPathComponent("detached-config.json"))
                    try Data("original".utf8).write(to:config)
                }
            })
            XCTAssertThrowsError(try io.writeScoped(path:config.path,bytes:Data("approved".utf8)))
            XCTAssertEqual(try Data(contentsOf:config),Data("original".utf8))
            if replaceParent {
                XCTAssertEqual(try Data(contentsOf:moved.appendingPathComponent("config.json")),Data("original".utf8))
                XCTAssertEqual(try Data(contentsOf:moved.appendingPathComponent(XCTUnwrap(stage).lastPathComponent)),Data("approved".utf8))
            } else {
                XCTAssertEqual(try Data(contentsOf:directory.appendingPathComponent("detached-config.json")),Data("original".utf8))
                XCTAssertFalse(FileManager.default.fileExists(atPath:try XCTUnwrap(stage).path))
            }
        }
    }
    #endif
    func testRecursiveArraysVerifyAndNumericOneDoesNotMatchBooleanTrue() throws {
        let fs = InMemoryFileSystem(); fs.files["/config.json"] = "{\"array\":[{\"nested\":[1,null,{}]}],\"flag\":1}"
        let verifier = Verification(policyEvaluator: PolicyEvaluator())
        let desired = DesiredState(data: ["array":AnyCodable([["nested":[1,NSNull(),[:]]]]),"flag":AnyCodable(1)],source:"/desired.json")
        XCTAssertTrue(verifier.verify(configPath:"/config.json",desired:desired,invariants:[],fileSystem:fs,timestamp:"2026-10-11T00:00:00Z").success)
        let booleanDesired = DesiredState(data:["flag":AnyCodable(true)],source:"/desired.json")
        XCTAssertFalse(verifier.verify(configPath:"/config.json",desired:booleanDesired,invariants:[],fileSystem:fs,timestamp:"2026-10-11T00:00:00Z").success)
    }
}
