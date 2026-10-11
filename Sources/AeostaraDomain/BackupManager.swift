// Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.
// Aeostara — Deterministic JSON Configuration Drift Detection and Healing Platform

import Foundation

/// Creates timestamped backup copies of configuration files.
public final class BackupManager: IBackupProvider {

    private let fileSystem: IFileSystem
    private let timestampProvider: () -> String

    public init(fileSystem: IFileSystem, timestampProvider: @escaping () -> String) {
        self.fileSystem = fileSystem
        self.timestampProvider = timestampProvider
    }

    /// Create a timestamped backup of the given file.
    /// Returns the path to the backup file.
    public func createBackup(filePath: String) throws -> String {
        let timestamp = timestampProvider()
        let backupPath = "\(filePath).backup.\(timestamp)"

        guard !fileSystem.fileExists(path:backupPath) else { throw AeostaraError.backupFailed(filePath) }

        let success = try fileSystem.copyFile(from: filePath, to: backupPath)
        guard success else {
            throw AeostaraError.backupFailed(filePath)
        }

        return backupPath
    }

    /// Restore a backup to the original file path.
    public func restoreBackup(backupPath: String, originalPath: String) throws -> Bool {
        guard fileSystem.fileExists(path: backupPath) else {
            return false
        }
        let content = try fileSystem.readFile(path:backupPath)
        try fileSystem.writeFile(path:originalPath,content:content)
        return try fileSystem.readFile(path:originalPath) == content
    }
}
