// Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.
// Aeostara — Deterministic JSON Configuration Drift Detection and Healing Platform

import Foundation

/// Loads invariant rules from a JSON file.
public final class InvariantParser {

    public init() {}

    /// Parse invariants from a JSON file at the given path.
    /// An omitted path is intentional; a requested missing or malformed file throws.
    public func parseInvariants(from path: String?, fileSystem: IFileSystem) throws -> [Invariant] {
        guard let path = path else { return [] }
        guard fileSystem.fileExists(path: path) else { throw AeostaraError.fileNotFound(path) }

        let content = try fileSystem.readFile(path: path)
        guard let data = content.data(using: .utf8) else { throw AeostaraError.cannotParseJSON(path) }

        let decoder = JSONDecoder()
        return try decoder.decode([Invariant].self, from: data)
    }
}
