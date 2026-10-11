// Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.
import Foundation
import AeostaraDomain

/// App-owned filesystem convenience API, backed by the same native scoped resource boundary as healing.
public final class SandboxFileSystem: IFileSystem, SemanticResourceIO {
    private let documentsDirectory: URL
    private let scoped: ScopedResourceIO?
    public init() {
        let directory = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask).first!
        documentsDirectory = directory
        try? FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        scoped = try? ScopedResourceIO(rootURL:directory)
    }
    public init(documentsDirectory: URL) { self.documentsDirectory = documentsDirectory;scoped = try? ScopedResourceIO(rootURL:documentsDirectory) }
    private func boundary() throws -> ScopedResourceIO { guard let scoped else { throw ResourceIOFault.scopeViolation };return scoped }
    public func read(path: String) throws -> Data { try boundary().read(path:path) }
    public func acquire(resources: NativeResourceSet) throws -> any NativeResourceLease { try boundary().acquire(resources:resources) }
    public func readFile(path: String) throws -> String { guard let value = String(data:try read(path:path),encoding:.utf8) else { throw AeostaraError.fileReadFailed(path) };return value }
    public func writeFile(path: String, content: String) throws { try boundary().writeScoped(path:path,bytes:Data(content.utf8)) }
    public func fileExists(path: String) -> Bool { (try? read(path:path)) != nil }
    public func copyFile(from sourcePath: String, to destinationPath: String) throws -> Bool { try boundary().copyExclusive(from:sourcePath,to:destinationPath) }
    public func appendFile(path: String, content: String) throws {
        let existing = fileExists(path:path) ? try readFile(path:path) : ""
        try writeFile(path:path,content:existing+content)
    }
    public func documentsPath(for filename: String) -> String { documentsDirectory.appendingPathComponent(filename).path }
    public func backupsDirectory() -> String { documentsDirectory.appendingPathComponent("backups").path }
    public func auditDirectory() -> String { documentsDirectory.appendingPathComponent("audit").path }
}
