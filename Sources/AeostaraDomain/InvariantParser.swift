// Copyright (c) 2026 James Daley. All Rights Reserved.
// Aeostara — Deterministic JSON Configuration Drift Detection and Healing Platform

import Foundation

/// Loads invariant rules from a JSON file.
public final class InvariantParser {

    public init() {}

    /// Parse invariants from a JSON file at the given path.
    /// Returns an empty array if the path is nil or the file cannot be parsed.
    public func parseInvariants(from path: String?, fileSystem: IFileSystem) throws -> [Invariant] {
        guard let path = path else { return [] }
        guard fileSystem.fileExists(path: path) else { return [] }

        let content = try fileSystem.readFile(path: path)
        guard let data = content.data(using: .utf8) else { return [] }

        let decoder = JSONDecoder()
        return try decoder.decode([Invariant].self, from: data)
    }
}
