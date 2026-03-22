// Copyright (c) 2026 James Daley. All Rights Reserved.
// Aeostara — Deterministic JSON Configuration Drift Detection and Healing Platform

import Foundation

/// Dot-path utilities for navigating and mutating nested JSON dictionaries.
public enum JsonPath {

    /// Get a value at a dot-separated key path from a nested dictionary.
    public static func get(_ obj: [String: Any], dotPath: String) -> Any? {
        let keys = dotPath.split(separator: ".").map(String.init)
        var current: Any = obj
        for key in keys {
            guard let dict = current as? [String: Any], let next = dict[key] else {
                return nil
            }
            current = next
        }
        return current
    }

    /// Set a value at a dot-separated key path in a nested dictionary, creating
    /// intermediate dictionaries as needed. Returns a new dictionary.
    public static func set(_ obj: [String: Any], dotPath: String, value: Any) -> [String: Any] {
        let keys = dotPath.split(separator: ".").map(String.init)
        guard !keys.isEmpty else { return obj }

        var result = obj

        if keys.count == 1 {
            result[keys[0]] = value
            return result
        }

        // Build the nested path
        let parentPath = keys.dropLast().joined(separator: ".")
        let lastKey = keys.last!

        var parent = (JsonPath.get(obj, dotPath: parentPath) as? [String: Any]) ?? [:]
        parent[lastKey] = value

        return JsonPath.set(obj, dotPath: parentPath, value: parent)
    }

    /// Remove a key at a dot-separated path. Returns a new dictionary.
    public static func remove(_ obj: [String: Any], dotPath: String) -> [String: Any] {
        let keys = dotPath.split(separator: ".").map(String.init)
        guard !keys.isEmpty else { return obj }

        var result = obj

        if keys.count == 1 {
            result.removeValue(forKey: keys[0])
            return result
        }

        let parentPath = keys.dropLast().joined(separator: ".")
        let lastKey = keys.last!

        guard var parent = JsonPath.get(obj, dotPath: parentPath) as? [String: Any] else {
            return obj
        }
        parent.removeValue(forKey: lastKey)

        return JsonPath.set(obj, dotPath: parentPath, value: parent)
    }

    /// Check if a key path exists in a nested dictionary.
    public static func exists(_ obj: [String: Any], dotPath: String) -> Bool {
        return JsonPath.get(obj, dotPath: dotPath) != nil
    }

    /// Flatten a nested dictionary into a map of dot-path keys to leaf values.
    /// Arrays are treated as leaf values (not recursed into).
    public static func flatten(_ obj: [String: Any], prefix: String = "") -> [String: Any] {
        var result: [String: Any] = [:]

        let sortedKeys = obj.keys.sorted()
        for key in sortedKeys {
            guard let value = obj[key] else { continue }
            let fullPath = prefix.isEmpty ? key : "\(prefix).\(key)"

            if let nested = value as? [String: Any] {
                let sub = flatten(nested, prefix: fullPath)
                for (subKey, subVal) in sub {
                    result[subKey] = subVal
                }
            } else {
                result[fullPath] = value
            }
        }

        return result
    }

    /// Unflatten a dot-path map back into a nested dictionary.
    public static func unflatten(_ flatMap: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (dotPath, value) in flatMap {
            result = JsonPath.set(result, dotPath: dotPath, value: value)
        }
        return result
    }
}
