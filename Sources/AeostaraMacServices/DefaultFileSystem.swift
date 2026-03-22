// Copyright (c) 2026 James Daley. All Rights Reserved.
// Aeostara — Deterministic JSON Configuration Drift Detection and Healing Platform

import Foundation
import AeostaraMacDomain

/// FileManager-based implementation of the IFileSystem protocol.
public final class DefaultFileSystem: IFileSystem {

    public init() {}

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

        // Remove destination if it exists
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
}
