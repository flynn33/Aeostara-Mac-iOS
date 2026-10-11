import Foundation
import Darwin
import AeostaraMacDomain

public struct NativeResourcePaths {
    public let root: URL
    public let configuration: URL
    public let desired: URL
    public let backup: URL
    public let audit: URL
    public init(root: URL, configuration: URL, desired: URL, backup: URL, audit: URL) throws {
        guard root.isFileURL, [root, configuration, desired, backup, audit].allSatisfy({ !$0.path.utf8.contains(0) && !$0.pathComponents.contains("..") }) else { throw NativeResourceError.scopeViolation }
        let root = root.standardizedFileURL
        guard root.path.utf8.elementsEqual(root.resolvingSymlinksInPath().path.utf8) else { throw NativeResourceError.scopeViolation }
        var info = stat()
        guard lstat(root.path, &info) == 0, (info.st_mode & S_IFMT) == S_IFDIR, info.st_uid == geteuid() else { throw NativeResourceError.unsupportedResource }
        func resolve(_ url: URL, mutable: Bool, mayAlias: Bool) throws -> URL {
            guard url.isFileURL else { throw NativeResourceError.scopeViolation }
            let original = url.standardizedFileURL
            let resolved = original.resolvingSymlinksInPath().standardizedFileURL
            guard resolved.path.utf8.starts(with: (root.path + "/").utf8), resolved.path != root.path else { throw NativeResourceError.scopeViolation }
            if !mayAlias, !original.path.utf8.elementsEqual(resolved.path.utf8) { throw NativeResourceError.scopeViolation }
            var parent = stat()
            guard lstat(resolved.deletingLastPathComponent().path, &parent) == 0, (parent.st_mode & S_IFMT) == S_IFDIR, parent.st_uid == geteuid() else { throw NativeResourceError.unsupportedResource }
            var existing = stat()
            if lstat(resolved.path, &existing) == 0 {
                guard (existing.st_mode & S_IFMT) == S_IFREG, existing.st_uid == geteuid(), !mutable || existing.st_nlink == 1 else { throw NativeResourceError.unsupportedResource }
            } else if errno != ENOENT { throw NativeResourceError.unavailable(errno) }
            return resolved
        }
        self.root = root
        self.configuration = try resolve(configuration, mutable: true, mayAlias: true)
        self.desired = try resolve(desired, mutable: false, mayAlias: true)
        self.backup = try resolve(backup, mutable: true, mayAlias: false)
        self.audit = try resolve(audit, mutable: true, mayAlias: false)
        let urls = [self.configuration, self.desired, self.backup, self.audit]
        guard Set(urls.map { Data($0.path.utf8) }).count == urls.count else { throw NativeResourceError.identityCollision }
        var identities = Set<String>()
        for url in urls {
            var state = stat()
            if lstat(url.path, &state) == 0 {
                guard identities.insert("\(state.st_dev):\(state.st_ino)").inserted else { throw NativeResourceError.identityCollision }
            }
        }
    }
}

private final class FileLease: NativeResourceLease {
    let owner: UUID
    private let lock = NSLock()
    private var descriptors: [Int32]
    private let identityChecks: [() throws -> Void]
    init(owner: UUID, descriptors: [Int32], identityChecks: [() throws -> Void]) { self.owner = owner; self.descriptors = descriptors; self.identityChecks = identityChecks }
    func validateIdentities() throws { lock.lock(); defer { lock.unlock() }; guard !descriptors.isEmpty else { throw NativeResourceError.leaseInvalid }; for check in identityChecks { try check() } }
    var active: Bool { lock.lock(); defer { lock.unlock() }; return !descriptors.isEmpty }
    func release() { lock.lock(); defer { lock.unlock() }; for descriptor in descriptors { _ = flock(descriptor, LOCK_UN); Darwin.close(descriptor) }; descriptors = [] }
    deinit { release() }
}

/// Native cooperating-instance ownership. Advisory locking does not constrain external writers.
public final class ScopedNativeResourceIO: NativeResourceIO {
    private static let maximumSnapshotBytes = 16 * 1024 * 1024
    public let paths: NativeResourcePaths
    public let scopeIdentity: String
    private let identity = UUID()
    private let rootIdentity: stat
    public init(paths: NativeResourcePaths) throws {
        self.paths = paths
        scopeIdentity = NativeStorageIdentity.hash(Data([paths.root.path, paths.configuration.path, paths.desired.path, paths.backup.path, paths.audit.path].joined(separator: "\n").utf8))
        var state = stat()
        guard lstat(paths.root.path, &state) == 0 else { throw NativeResourceError.unavailable(errno) }
        rootIdentity = state
    }
    private func location(_ role: NativeResourceRole) -> URL {
        switch role { case .configuration: return paths.configuration; case .desired: return paths.desired; case .backup: return paths.backup; case .audit: return paths.audit }
    }
    private func validateRoot() throws {
        var found = stat()
        guard lstat(paths.root.path, &found) == 0, found.st_dev == rootIdentity.st_dev, found.st_ino == rootIdentity.st_ino,
              (found.st_mode & S_IFMT) == S_IFDIR, found.st_uid == geteuid() else { throw NativeResourceError.scopeViolation }
    }
    private func parent(_ url: URL) throws -> Int32 {
        try validateRoot()
        guard url.path.utf8.starts(with: (paths.root.path + "/").utf8), url.path.utf8.elementsEqual(url.resolvingSymlinksInPath().path.utf8) else { throw NativeResourceError.scopeViolation }
        var fd = Darwin.open(paths.root.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard fd >= 0 else { throw NativeResourceError.unavailable(errno) }
        do {
            var openedRoot = stat()
            guard fstat(fd, &openedRoot) == 0, openedRoot.st_dev == rootIdentity.st_dev, openedRoot.st_ino == rootIdentity.st_ino else { throw NativeResourceError.scopeViolation }
            let suffix = url.deletingLastPathComponent().path.dropFirst(paths.root.path.count).split(separator: "/")
            for part in suffix {
                let next = openat(fd, String(part), O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
                guard next >= 0 else { throw NativeResourceError.scopeViolation }
                Darwin.close(fd); fd = next
            }
            var state = stat()
            guard fstat(fd, &state) == 0, state.st_uid == geteuid() else { throw NativeResourceError.unsupportedResource }
            return fd
        } catch { Darwin.close(fd); throw error }
    }
    private func verifyParent(_ descriptor: Int32, url: URL) throws {
        let current = try parent(url); defer { Darwin.close(current) }
        var held = stat(), live = stat()
        guard fstat(descriptor, &held) == 0, fstat(current, &live) == 0,
              held.st_dev == live.st_dev, held.st_ino == live.st_ino else { throw NativeResourceError.scopeViolation }
    }
    private func verifyNamed(_ descriptor: Int32, directory: Int32, name: String, mutable: Bool) throws {
        var held = stat(), live = stat()
        guard fstat(descriptor, &held) == 0, fstatat(directory, name, &live, AT_SYMLINK_NOFOLLOW) == 0,
              held.st_dev == live.st_dev, held.st_ino == live.st_ino, (live.st_mode & S_IFMT) == S_IFREG,
              live.st_uid == geteuid(), !mutable || live.st_nlink == 1 else { throw NativeResourceError.scopeViolation }
    }
    private func verify(_ descriptor: Int32, mutable: Bool) throws {
        var state = stat()
        guard fstat(descriptor, &state) == 0, (state.st_mode & S_IFMT) == S_IFREG, state.st_uid == geteuid(),
              (!mutable || state.st_nlink == 1), state.st_size >= 0, state.st_size <= 16 * 1024 * 1024 else { throw NativeResourceError.unsupportedResource }
    }
    public func read(_ role: NativeResourceRole) throws -> Data {
        let url = location(role), dir = try parent(url)
        defer { Darwin.close(dir) }
        let fd = openat(dir, url.lastPathComponent, O_RDONLY | O_NOFOLLOW)
        guard fd >= 0 else { throw NativeResourceError.unavailable(errno) }
        defer { Darwin.close(fd) }
        try verify(fd, mutable: role != .desired)
        var bytes = Data(), buffer = [UInt8](repeating: 0, count: 16384)
        while true {
            let count = Darwin.read(fd, &buffer, buffer.count)
            if count < 0 { if errno == EINTR { continue }; throw NativeResourceError.unavailable(errno) }
            if count == 0 { break }
            bytes.append(contentsOf: buffer.prefix(count))
            guard bytes.count <= Self.maximumSnapshotBytes else { throw NativeResourceError.unsupportedResource }
        }
        try verifyParent(dir, url: url)
        try verifyNamed(fd, directory: dir, name: url.lastPathComponent, mutable: role != .desired)
        return bytes
    }
    public func acquireExclusiveLease() throws -> any NativeResourceLease {
        var held: [Int32] = []
        var identityChecks: [() throws -> Void] = []
        do {
            let resources = [paths.configuration, paths.audit, paths.backup].sorted { $0.path.utf8.lexicographicallyPrecedes($1.path.utf8) }
            for url in resources {
                let dir = try parent(url)
                defer { Darwin.close(dir) }
                if mkdirat(dir, ".aeostara-resource-locks", 0o700) != 0, errno != EEXIST { throw NativeResourceError.unavailable(errno) }
                let locks = openat(dir, ".aeostara-resource-locks", O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
                guard locks >= 0 else { throw NativeResourceError.scopeViolation }
                defer { Darwin.close(locks) }
                var directory = stat()
                guard fstat(locks, &directory) == 0, directory.st_uid == geteuid(), (directory.st_mode & 0o077) == 0 else { throw NativeResourceError.unsupportedResource }
                let name = NativeStorageIdentity.hash(Data(url.path.utf8)) + ".lock"
                let fd = openat(locks, name, O_RDWR | O_CREAT | O_NOFOLLOW, 0o600)
                guard fd >= 0 else { throw NativeResourceError.scopeViolation }
                do {
                    try verify(fd, mutable: true)
                    var file = stat(); guard fstat(fd, &file) == 0, (file.st_mode & 0o077) == 0 else { throw NativeResourceError.unsupportedResource }
                    guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { throw errno == EWOULDBLOCK ? NativeResourceError.resourceBusy : NativeResourceError.unavailable(errno) }
                    var link = stat()
                    guard fstatat(locks, name, &link, AT_SYMLINK_NOFOLLOW) == 0, link.st_ino == file.st_ino, link.st_dev == file.st_dev else { throw NativeResourceError.scopeViolation }
                    try verifyParent(dir, url: url)
                    let lockedDirectory = directory
                    identityChecks.append { [self] in
                        let scopedParent = try parent(url); defer { Darwin.close(scopedParent) }
                        let liveLocks = openat(scopedParent, ".aeostara-resource-locks", O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
                        guard liveLocks >= 0 else { throw NativeResourceError.scopeViolation }
                        defer { Darwin.close(liveLocks) }
                        var found = stat()
                        guard fstat(liveLocks, &found) == 0, found.st_dev == lockedDirectory.st_dev, found.st_ino == lockedDirectory.st_ino else { throw NativeResourceError.scopeViolation }
                        try verifyNamed(fd, directory: liveLocks, name: name, mutable: true)
                    }
                    held.append(fd)
                } catch { Darwin.close(fd); throw error }
            }
            return FileLease(owner: identity, descriptors: held, identityChecks: identityChecks)
        } catch { for fd in held { _ = flock(fd, LOCK_UN); Darwin.close(fd) }; throw error }
    }
    private func validate(_ lease: any NativeResourceLease) throws {
        guard let lease = lease as? FileLease, lease.owner == identity, lease.active else { throw NativeResourceError.leaseInvalid }
        try validateRoot()
        try lease.validateIdentities()
    }
    private func writeAll(_ bytes: Data, fd: Int32) throws {
        try bytes.withUnsafeBytes { raw in
            var written = 0
            while written < raw.count {
                let count = Darwin.write(fd, raw.baseAddress!.advanced(by: written), raw.count - written)
                if count < 0 { if errno == EINTR { continue }; throw NativeResourceError.partialWrite(errno) }
                guard count > 0 else { throw NativeResourceError.partialWrite(EIO) }
                written += count
            }
        }
    }
    public func createBackup(bytes: Data, lease: any NativeResourceLease) throws {
        try validate(lease)
        guard bytes.count <= Self.maximumSnapshotBytes else { throw NativeResourceError.unsupportedResource }
        let dir = try parent(paths.backup); defer { Darwin.close(dir) }
        let fd = openat(dir, paths.backup.lastPathComponent, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw errno == EEXIST ? NativeResourceError.backupCollision : NativeResourceError.unavailable(errno) }
        defer { Darwin.close(fd) }
        try verifyParent(dir, url: paths.backup)
        try verifyNamed(fd, directory: dir, name: paths.backup.lastPathComponent, mutable: true)
        try writeAll(bytes, fd: fd)
        try verifyParent(dir, url: paths.backup)
        try verifyNamed(fd, directory: dir, name: paths.backup.lastPathComponent, mutable: true)
        guard fsync(fd) == 0, fsync(dir) == 0 else { throw NativeResourceError.unavailable(errno) }
        guard try read(.backup) == bytes else { throw NativeResourceError.staleSnapshot }
    }
    public func replaceConfiguration(bytes: Data, expectedStorageHash: String, lease: any NativeResourceLease) throws {
        try validate(lease)
        guard bytes.count <= Self.maximumSnapshotBytes else { throw NativeResourceError.unsupportedResource }
        let dir = try parent(paths.configuration); defer { Darwin.close(dir) }
        let name = ".aeostara-write-" + UUID().uuidString
        let fd = openat(dir, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw NativeResourceError.unavailable(errno) }
        var published = false
        defer { if !published, (try? verifyParent(dir, url: paths.configuration)) != nil, (try? verifyNamed(fd, directory: dir, name: name, mutable: true)) != nil { _ = unlinkat(dir, name, 0) }; Darwin.close(fd) }
        try writeAll(bytes, fd: fd)
        guard fsync(fd) == 0 else { throw NativeResourceError.unavailable(errno) }
        guard NativeStorageIdentity.hash(try read(.configuration)) == expectedStorageHash else { throw NativeResourceError.staleSnapshot }
        try validate(lease)
        try verifyParent(dir, url: paths.configuration)
        try verifyNamed(fd, directory: dir, name: name, mutable: true)
        guard renameat(dir, name, dir, paths.configuration.lastPathComponent) == 0 else { throw NativeResourceError.unavailable(errno) }
        published = true
        try verifyParent(dir, url: paths.configuration)
        try verifyNamed(fd, directory: dir, name: paths.configuration.lastPathComponent, mutable: true)
        guard fsync(dir) == 0 else { throw NativeResourceError.unavailable(errno) }
    }
    public func persistAudit(_ event: AeostaraContract.AuditEvent, lease: any NativeResourceLease) throws {
        try validate(lease)
        var bytes = try ContractCoding.canonicalEncode(event); bytes.append(10)
        guard bytes.count <= Self.maximumSnapshotBytes else { throw NativeResourceError.unsupportedResource }
        let dir = try parent(paths.audit); defer { Darwin.close(dir) }
        let fd = openat(dir, paths.audit.lastPathComponent, O_WRONLY | O_CREAT | O_APPEND | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw NativeResourceError.unavailable(errno) }
        defer { Darwin.close(fd) }
        try verify(fd, mutable: true)
        var existing = stat()
        guard fstat(fd, &existing) == 0 else { throw NativeResourceError.unavailable(errno) }
        guard existing.st_size >= 0, existing.st_size <= Self.maximumSnapshotBytes - bytes.count else { throw NativeResourceError.unsupportedResource }
        try verifyParent(dir, url: paths.audit)
        try verifyNamed(fd, directory: dir, name: paths.audit.lastPathComponent, mutable: true)
        try writeAll(bytes, fd: fd)
        try verifyParent(dir, url: paths.audit)
        try verifyNamed(fd, directory: dir, name: paths.audit.lastPathComponent, mutable: true)
        guard fsync(fd) == 0, fsync(dir) == 0 else { throw NativeResourceError.unavailable(errno) }
    }
}
