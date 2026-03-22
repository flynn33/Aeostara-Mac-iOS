// Copyright (c) 2026 James Daley. All Rights Reserved.
// Aeostara — Deterministic JSON Configuration Drift Detection and Healing Platform

import Foundation
import AeostaraDomain

/// Handles importing JSON files from outside the app sandbox via document picker.
/// Copies selected files into the app's Documents directory for safe processing.
public final class DocumentImporter {

    private let fileSystem: SandboxFileSystem

    public init(fileSystem: SandboxFileSystem) {
        self.fileSystem = fileSystem
    }

    /// Import a file from an external URL into the app's Documents directory.
    /// Returns the path to the imported file within the sandbox.
    public func importFile(from sourceURL: URL) throws -> String {
        let filename = sourceURL.lastPathComponent
        let destinationPath = fileSystem.documentsPath(for: filename)

        // Read from external source (requires security-scoped access)
        let shouldStopAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let content = try String(contentsOf: sourceURL, encoding: .utf8)
        try fileSystem.writeFile(path: destinationPath, content: content)

        return destinationPath
    }

    /// List all JSON files in the Documents directory.
    public func listImportedFiles() -> [String] {
        let documentsPath = fileSystem.documentsPath(for: "")
        let documentsURL = URL(fileURLWithPath: documentsPath)

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: documentsURL,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else {
            return []
        }

        return contents
            .filter { $0.pathExtension == "json" }
            .map { $0.path }
    }
}
