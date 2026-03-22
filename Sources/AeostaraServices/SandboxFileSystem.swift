// Copyright (c) 2026 James Daley. All Rights Reserved.
// Aeostara — Deterministic JSON Configuration Drift Detection and Healing Platform

import Foundation
import AeostaraDomain

/// FileManager-based implementation of IFileSystem for iOS sandbox environment.
/// All file operations are confined to the app's Documents directory.
public final class SandboxFileSystem: IFileSystem {

    private let documentsDirectory: URL

    public init() {
        self.documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    public init(documentsDirectory: URL) {
        self.documentsDirectory = documentsDirectory
    }

    public func readFile(path: String) throws -> String {
        let url = URL(fileURLWithPath: path)
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw AeostaraError.fileReadFailed(path)
        }
    }

    public func writeFile(path: String, content: String) throws {
        let url = URL(fileURLWithPath: path)

        // Ensure parent directory exists
        let parentDir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw AeostaraError.fileWriteFailed(path)
        }
    }

    public func fileExists(path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }

    public func copyFile(from sourcePath: String, to destinationPath: String) throws -> Bool {
        let sourceURL = URL(fileURLWithPath: sourcePath)
        let destURL = URL(fileURLWithPath: destinationPath)

        // Ensure parent directory exists
        let parentDir = destURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: destinationPath) {
            try FileManager.default.removeItem(at: destURL)
        }

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            return true
        } catch {
            return false
        }
    }

    public func appendFile(path: String, content: String) throws {
        let url = URL(fileURLWithPath: path)

        if FileManager.default.fileExists(atPath: path) {
            guard let handle = try? FileHandle(forWritingTo: url) else {
                throw AeostaraError.fileWriteFailed(path)
            }
            handle.seekToEndOfFile()
            guard let data = content.data(using: .utf8) else {
                throw AeostaraError.fileWriteFailed(path)
            }
            handle.write(data)
            handle.closeFile()
        } else {
            try writeFile(path: path, content: content)
        }
    }

    // MARK: - Sandbox Helpers

    /// Get the path for a file within the Documents directory.
    public func documentsPath(for filename: String) -> String {
        return documentsDirectory.appendingPathComponent(filename).path
    }

    /// Get the backups subdirectory within Documents.
    public func backupsDirectory() -> String {
        return documentsDirectory.appendingPathComponent("backups").path
    }

    /// Get the audit subdirectory within Documents.
    public func auditDirectory() -> String {
        return documentsDirectory.appendingPathComponent("audit").path
    }
}
