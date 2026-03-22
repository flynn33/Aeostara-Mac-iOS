// Copyright (c) 2026 James Daley. All Rights Reserved.
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
        return try fileSystem.copyFile(from: backupPath, to: originalPath)
    }
}
