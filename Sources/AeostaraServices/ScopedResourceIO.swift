import Foundation
import Darwin
import AeostaraDomain

fileprivate struct ScopedLockAnchor {
    let resource: String
    let parent: Int32
    let namespace: Int32
    let key: String
    let descriptor: Int32
}

/// Native app-owned resource boundary. Advisory leases serialize cooperating SDK instances.
public final class ScopedResourceIO: SemanticResourceIO {
    public let rootURL: URL
    private let rootFD: Int32
    private let rootIdentity: stat
    private let caseSensitiveNames: Bool
    #if DEBUG
    private var writeStageObserver: ((URL) throws -> Void)?
    convenience init(rootURL: URL,writeStageObserver: @escaping (URL) throws -> Void) throws { try self.init(rootURL:rootURL);self.writeStageObserver = writeStageObserver }
    #endif
    public init(rootURL: URL) throws {
        let canonical = rootURL.standardizedFileURL.resolvingSymlinksInPath()
        var st = stat()
        guard lstat(canonical.path,&st) == 0, (st.st_mode & S_IFMT) == S_IFDIR, st.st_uid == getuid(), (st.st_mode & 0o022) == 0 else { throw ResourceIOFault.scopeViolation }
        let descriptor = open(canonical.path,O_RDONLY|O_DIRECTORY|O_CLOEXEC|O_NOFOLLOW)
        guard descriptor >= 0 else { throw ResourceIOFault.scopeViolation }
        var opened = stat()
        guard fstat(descriptor,&opened) == 0, opened.st_dev == st.st_dev, opened.st_ino == st.st_ino else { close(descriptor); throw ResourceIOFault.scopeViolation }
        guard let caseSensitive = try canonical.resourceValues(forKeys:[.volumeSupportsCaseSensitiveNamesKey]).volumeSupportsCaseSensitiveNames else { close(descriptor); throw ResourceIOFault.scopeViolation }
        self.rootURL = canonical; rootFD = descriptor; rootIdentity = opened; caseSensitiveNames = caseSensitive
    }
    deinit { close(rootFD) }
    private func sameIdentity(_ lhs: stat, _ rhs: stat) -> Bool { lhs.st_dev == rhs.st_dev && lhs.st_ino == rhs.st_ino }
    private func validateRoot() throws {
        var held = stat(), declared = stat()
        guard rootURL.resolvingSymlinksInPath().path.utf8.elementsEqual(rootURL.path.utf8),
              fstat(rootFD,&held) == 0, lstat(rootURL.path,&declared) == 0,
              sameIdentity(held,rootIdentity), sameIdentity(declared,rootIdentity),
              (declared.st_mode & S_IFMT) == S_IFDIR, declared.st_uid == getuid(), (declared.st_mode & 0o022) == 0 else { throw ResourceIOFault.scopeViolation }
    }
    private func validateParent(_ path: String, descriptor: Int32) throws {
        let (fresh,_) = try parent(of:path); defer { close(fresh) }
        var held = stat(), declared = stat()
        guard fstat(descriptor,&held) == 0, fstat(fresh,&declared) == 0, sameIdentity(held,declared) else { throw ResourceIOFault.scopeViolation }
    }
    private func canonical(_ path: String, allowMissing: Bool = false, allowRoot: Bool = false) throws -> String {
        try validateRoot()
        guard path.hasPrefix("/"), !path.utf8.contains(0) else { throw ResourceIOFault.scopeViolation }
        let result = URL(fileURLWithPath:path).standardizedFileURL.resolvingSymlinksInPath().path
        if allowRoot && result.utf8.elementsEqual(rootURL.path.utf8) { return result }
        let prefix = rootURL.path == "/" ? "/" : rootURL.path + "/"
        guard result.utf8.starts(with:prefix.utf8), result.utf8.count > prefix.utf8.count else { throw ResourceIOFault.scopeViolation }
        let (parent,leaf) = try parent(of:result); defer { close(parent) }
        var st = stat()
        if fstatat(parent,leaf,&st,AT_SYMLINK_NOFOLLOW) != 0 { guard allowMissing, errno == ENOENT else { throw ResourceIOFault.readFailed }; return result }
        guard (st.st_mode & S_IFMT) != S_IFLNK else { throw ResourceIOFault.scopeViolation }
        // Existing aliases select the actual directory-entry spelling, including case/Unicode aliases.
        if (st.st_mode & S_IFMT) == S_IFREG {
            guard st.st_nlink == 1 else { throw ResourceIOFault.scopeViolation }
            let parentURL = URL(fileURLWithPath:result).deletingLastPathComponent()
            let names = try FileManager.default.contentsOfDirectory(atPath:parentURL.path)
            for name in names.sorted(by:{ $0.utf8.lexicographicallyPrecedes($1.utf8) }) {
                var candidate = stat()
                if fstatat(parent,name,&candidate,AT_SYMLINK_NOFOLLOW) == 0, candidate.st_dev == st.st_dev, candidate.st_ino == st.st_ino {
                    return parentURL.appendingPathComponent(name).path
                }
            }
            throw ResourceIOFault.scopeViolation
        }
        return result
    }
    private func parent(of path: String) throws -> (Int32,String) {
        try validateRoot()
        let prefix = rootURL.path == "/" ? "/" : rootURL.path + "/"
        guard path.utf8.starts(with:prefix.utf8) else { throw ResourceIOFault.scopeViolation }
        let relative = String(decoding:path.utf8.dropFirst(prefix.utf8.count),as:UTF8.self)
        let parts = relative.split(separator:"/",omittingEmptySubsequences:false).map(String.init)
        guard !parts.isEmpty, parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else { throw ResourceIOFault.scopeViolation }
        var current = dup(rootFD); guard current >= 0 else { throw ResourceIOFault.readFailed }
        do {
            for component in parts.dropLast() {
                let next = openat(current,component,O_RDONLY|O_DIRECTORY|O_CLOEXEC|O_NOFOLLOW)
                guard next >= 0 else { throw ResourceIOFault.scopeViolation }
                var st = stat(); guard fstat(next,&st) == 0, st.st_uid == getuid(), (st.st_mode & 0o022) == 0 else { close(next); throw ResourceIOFault.scopeViolation }
                close(current); current = next
            }
            return (current,parts.last!)
        } catch { close(current); throw error }
    }
    private func regular(_ parent: Int32, _ leaf: String, flags: Int32 = O_RDONLY) throws -> Int32 {
        let fd = openat(parent,leaf,flags|O_CLOEXEC|O_NOFOLLOW)
        guard fd >= 0 else { throw ResourceIOFault.readFailed }
        var st = stat(); guard fstat(fd,&st) == 0, (st.st_mode & S_IFMT) == S_IFREG, st.st_uid == getuid(), st.st_nlink == 1 else { close(fd); throw ResourceIOFault.scopeViolation }
        return fd
    }
    private func bytes(_ fd: Int32) throws -> Data {
        guard lseek(fd,0,SEEK_SET) >= 0 else { throw ResourceIOFault.readFailed }
        var data = Data(); var buffer = [UInt8](repeating:0,count:65536)
        while true {
            let n = Darwin.read(fd,&buffer,buffer.count)
            if n == 0 { return data }
            if n < 0 { if errno == EINTR { continue }; throw ResourceIOFault.readFailed }
            data.append(contentsOf:buffer.prefix(n))
        }
    }
    private func writeAll(_ data: Data, to fd: Int32) throws {
        try data.withUnsafeBytes { raw in
            var offset = 0
            while offset < raw.count {
                let n = Darwin.write(fd,raw.baseAddress!.advanced(by:offset),raw.count-offset)
                if n < 0 { if errno == EINTR { continue }; throw ResourceIOFault.writeFailed }
                guard n > 0 else { throw ResourceIOFault.writeFailed }; offset += n
            }
        }
        guard fsync(fd) == 0 else { throw ResourceIOFault.writeFailed }
    }
    public func read(path: String) throws -> Data { try readCanonical(canonical(path)) }
    fileprivate func readCanonical(_ path: String) throws -> Data {
        let (parent,leaf) = try self.parent(of:path); defer { close(parent) }
        let fd = try regular(parent,leaf); defer { close(fd) }; return try bytes(fd)
    }
    fileprivate func replace(_ path: String, bytes: Data, expectedHash: String?, authorization: (() throws -> Void)? = nil) throws {
        try authorization?()
        let (parent,leaf) = try self.parent(of:path); defer { close(parent) }
        var original = stat()
        if let expectedHash {
            guard fstatat(parent,leaf,&original,AT_SYMLINK_NOFOLLOW) == 0,
                  (original.st_mode & S_IFMT) == S_IFREG, original.st_uid == getuid(), original.st_nlink == 1 else { throw ResourceIOFault.scopeViolation }
            guard CanonicalJSON.hashBytes(try readCanonical(path)) == expectedHash else { throw ResourceIOFault.staleSnapshot }
        } else { guard fstatat(parent,leaf,&original,AT_SYMLINK_NOFOLLOW) != 0, errno == ENOENT else { throw ResourceIOFault.backupCollision } }
        let temporary = ".aeostara-write-" + UUID().uuidString
        let fd = openat(parent,temporary,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW|O_CLOEXEC,0o600)
        guard fd >= 0 else { throw ResourceIOFault.writeFailed }
        var owned = stat()
        guard fstat(fd,&owned) == 0 else { close(fd); throw ResourceIOFault.writeFailed }
        defer {
            close(fd)
            var entry = stat()
            if (try? validateParent(path,descriptor:parent)) != nil,
               fstatat(parent,temporary,&entry,AT_SYMLINK_NOFOLLOW) == 0, sameIdentity(entry,owned) {
                unlinkat(parent,temporary,0)
            }
        }
        try writeAll(bytes,to:fd)
        #if DEBUG
        try writeStageObserver?(URL(fileURLWithPath:path).deletingLastPathComponent().appendingPathComponent(temporary))
        #endif
        try validateParent(path,descriptor:parent)
        var staged = stat(), held = stat(), current = stat()
        guard fstat(fd,&held) == 0, fstatat(parent,temporary,&staged,AT_SYMLINK_NOFOLLOW) == 0,
              sameIdentity(held,owned), sameIdentity(staged,owned), (staged.st_mode & S_IFMT) == S_IFREG,
              staged.st_uid == getuid(), staged.st_nlink == 1 else { throw ResourceIOFault.scopeViolation }
        if let expectedHash {
            guard fstatat(parent,leaf,&current,AT_SYMLINK_NOFOLLOW) == 0, sameIdentity(current,original) else { throw ResourceIOFault.staleSnapshot }
            guard CanonicalJSON.hashBytes(try readCanonical(path)) == expectedHash else { throw ResourceIOFault.staleSnapshot }
        }
        try authorization?()
        let renamed = expectedHash == nil ? renameatx_np(parent,temporary,parent,leaf,UInt32(RENAME_EXCL)) : renameat(parent,temporary,parent,leaf)
        guard renamed == 0, fsync(parent) == 0 else { throw ResourceIOFault.writeFailed }
    }
    public func writeScoped(path: String, bytes: Data) throws {
        let path = try canonical(path,allowMissing:true)
        let existing = try? readCanonical(path)
        try replace(path,bytes:bytes,expectedHash:existing.map(CanonicalJSON.hashBytes))
    }
    public func copyExclusive(from: String, to: String) throws -> Bool {
        let source = try read(path:from), destination = try canonical(to,allowMissing:true)
        do { try replace(destination,bytes:source,expectedHash:nil); return true }
        catch ResourceIOFault.backupCollision { return false }
    }
    public func acquire(resources: NativeResourceSet) throws -> any NativeResourceLease {
        let configuration = try canonical(resources.configuration), desired = try canonical(resources.desired), audit = try canonical(resources.audit,allowMissing:true)
        let backup = try canonical(resources.backupDirectory,allowRoot:true)
        let canonicalResources = try NativeResourceSet(configuration:configuration,desired:desired,audit:audit,backupDirectory:backup)
        guard configuration != desired, configuration != audit, desired != audit else { throw ResourceIOFault.scopeViolation }
        let backupFD: Int32
        if backup.utf8.elementsEqual(rootURL.path.utf8) { backupFD = dup(rootFD) }
        else { let (backupParent,backupLeaf) = try parent(of:backup);defer { close(backupParent) };backupFD = openat(backupParent,backupLeaf,O_RDONLY|O_DIRECTORY|O_CLOEXEC|O_NOFOLLOW) }
        guard backupFD >= 0 else { throw ResourceIOFault.scopeViolation }; defer { close(backupFD) }
        var locks: [ScopedLockAnchor] = []
        do {
            for resource in [configuration,audit].sorted(by:{ $0.utf8.lexicographicallyPrecedes($1.utf8) }) {
                let (parent,leaf) = try self.parent(of:resource); defer { close(parent) }
                let namespace = ".aeostara-resource-locks"
                if mkdirat(parent,namespace,0o700) != 0 && errno != EEXIST { throw ResourceIOFault.scopeViolation }
                let directory = openat(parent,namespace,O_RDONLY|O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC)
                guard directory >= 0 else { throw ResourceIOFault.scopeViolation }; defer { close(directory) }
                var directoryStat = stat(); guard fstat(directory,&directoryStat) == 0, directoryStat.st_uid == getuid(), (directoryStat.st_mode & 0o077) == 0 else { throw ResourceIOFault.scopeViolation }
                var parentStat = stat(); guard fstat(parent,&parentStat) == 0 else { throw ResourceIOFault.scopeViolation }
                let normalizedName = leaf.decomposedStringWithCanonicalMapping
                let nameIdentity = caseSensitiveNames ? normalizedName : normalizedName.lowercased()
                let identity = String(parentStat.st_dev)+":"+String(parentStat.st_ino)+":"+nameIdentity
                let key = CanonicalJSON.hashBytes(Data(identity.utf8)) + ".lock"
                let fd = openat(directory,key,O_RDWR|O_CREAT|O_NOFOLLOW|O_CLOEXEC,0o600)
                guard fd >= 0 else { throw ResourceIOFault.scopeViolation }
                var st = stat(); guard fstat(fd,&st) == 0, (st.st_mode & S_IFMT) == S_IFREG, st.st_uid == getuid(), st.st_nlink == 1, (st.st_mode & 0o077) == 0 else { close(fd); throw ResourceIOFault.scopeViolation }
                guard flock(fd,LOCK_EX|LOCK_NB) == 0 else { close(fd); throw ResourceIOFault.resourceBusy }
                let heldParent = dup(parent), heldNamespace = dup(directory)
                guard heldParent >= 0, heldNamespace >= 0 else {
                    if heldParent >= 0 { close(heldParent) };if heldNamespace >= 0 { close(heldNamespace) }
                    flock(fd,LOCK_UN);close(fd);throw ResourceIOFault.scopeViolation
                }
                locks.append(ScopedLockAnchor(resource:resource,parent:heldParent,namespace:heldNamespace,key:key,descriptor:fd))
            }
            return ScopedLease(owner:self,resources:canonicalResources,locks:locks)
        } catch { for lock in locks { flock(lock.descriptor,LOCK_UN);close(lock.descriptor);close(lock.parent);close(lock.namespace) }; throw error }
    }
    fileprivate func validateLocks(_ locks: [ScopedLockAnchor]) throws {
        try validateRoot()
        for lock in locks {
            try validateParent(lock.resource,descriptor:lock.parent)
            var namespace = stat(), namedNamespace = stat(), held = stat(), named = stat()
            guard fstat(lock.namespace,&namespace) == 0, fstatat(lock.parent,".aeostara-resource-locks",&namedNamespace,AT_SYMLINK_NOFOLLOW) == 0,
                  sameIdentity(namespace,namedNamespace), (namedNamespace.st_mode & S_IFMT) == S_IFDIR,
                  namedNamespace.st_uid == getuid(), (namedNamespace.st_mode & 0o077) == 0,
                  fstat(lock.descriptor,&held) == 0, fstatat(lock.namespace,lock.key,&named,AT_SYMLINK_NOFOLLOW) == 0,
                  sameIdentity(held,named), (named.st_mode & S_IFMT) == S_IFREG, named.st_uid == getuid(), named.st_nlink == 1,
                  (named.st_mode & 0o077) == 0 else { throw ResourceIOFault.scopeViolation }
        }
    }
    fileprivate func backup(bytes: Data, sourceHash: String, identifier: String, resources: NativeResourceSet, authorization: (() throws -> Void)? = nil) throws -> NativeBackupReceipt {
        guard !identifier.isEmpty, identifier.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 }) else { throw ResourceIOFault.scopeViolation }
        let path = URL(fileURLWithPath:resources.backupDirectory).appendingPathComponent("Aeostara-"+identifier+".backup").path
        let destination = try canonical(path,allowMissing:true)
        try replace(destination,bytes:bytes,expectedHash:nil,authorization:authorization)
        guard try readCanonical(destination) == bytes else { throw ResourceIOFault.backupFailed }
        return NativeBackupReceipt(storageReference:destination,bytesHash:CanonicalJSON.hashBytes(bytes),sourceHash:sourceHash)
    }
    fileprivate func audit(events: [AeostaraContract.AuditEvent], resources: NativeResourceSet, authorization: (() throws -> Void)? = nil) throws {
        guard !events.isEmpty else { return }
        var existing = Data(); var hash: String?
        do { existing = try readCanonical(resources.audit); hash = CanonicalJSON.hashBytes(existing) }
        catch ResourceIOFault.readFailed { var st = stat(); guard lstat(resources.audit,&st) != 0, errno == ENOENT else { throw ResourceIOFault.auditFailed } }
        for event in events { existing.append(try ContractCoding.canonicalEncode(event));existing.append(10) }
        do { try replace(resources.audit,bytes:existing,expectedHash:hash,authorization:authorization) } catch { throw ResourceIOFault.auditFailed }
    }
}

private final class ScopedLease: NativeResourceLease {
    let owner: ScopedResourceIO
    let resources: NativeResourceSet
    private var locks: [ScopedLockAnchor]
    init(owner: ScopedResourceIO, resources: NativeResourceSet, locks: [ScopedLockAnchor]) { self.owner = owner;self.resources = resources;self.locks = locks }
    deinit { release() }
    private func active() throws { guard !locks.isEmpty else { throw ResourceIOFault.resourceBusy };try owner.validateLocks(locks) }
    func readConfiguration() throws -> Data { try active();return try owner.readCanonical(resources.configuration) }
    func readDesired() throws -> Data { try active();return try owner.readCanonical(resources.desired) }
    func persistAudit(events: [AeostaraContract.AuditEvent]) throws { try active();try owner.audit(events:events,resources:resources,authorization:active) }
    func createBackup(bytes: Data, sourceHash: String, identifier: String) throws -> NativeBackupReceipt { try active();return try owner.backup(bytes:bytes,sourceHash:sourceHash,identifier:identifier,resources:resources,authorization:active) }
    func replaceConfiguration(bytes: Data, expectedBytesHash: String) throws { try active();try owner.replace(resources.configuration,bytes:bytes,expectedHash:expectedBytesHash,authorization:active) }
    func restoreBackup(_ receipt: NativeBackupReceipt, expectedBytesHash: String) throws -> Data {
        try active();let backup = try owner.read(path:receipt.storageReference)
        guard CanonicalJSON.hashBytes(backup) == receipt.bytesHash, try CanonicalJSON.hash(CanonicalJSON.parse(backup)) == receipt.sourceHash else { throw ResourceIOFault.backupFailed }
        try owner.replace(resources.configuration,bytes:backup,expectedHash:expectedBytesHash,authorization:active); return try readConfiguration()
    }
    func release() { for lock in locks { flock(lock.descriptor,LOCK_UN);close(lock.descriptor);close(lock.parent);close(lock.namespace) };locks = [] }
}
