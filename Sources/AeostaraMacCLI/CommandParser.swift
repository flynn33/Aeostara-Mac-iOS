// Copyright (c) 2026 James Daley. All Rights Reserved.
// Aeostara — Deterministic JSON Configuration Drift Detection and Healing Platform

import Foundation

/// Parsed CLI command and arguments.
enum Command {
    case validate(config: String, desired: String, invariants: String?)
    case diff(config: String, desired: String, invariants: String?)
    case heal(config: String, desired: String, invariants: String?, audit: String)
    case help
}

/// Parses command-line arguments into a Command.
enum CommandParser {

    static func parse(_ arguments: [String]) -> Command {
        // arguments[0] is the executable path
        let args = Array(arguments.dropFirst())

        guard let command = args.first else {
            return .help
        }

        switch command {
        case "validate":
            return parseValidateOrDiff(args: Array(args.dropFirst()), isValidate: true)
        case "diff":
            return parseValidateOrDiff(args: Array(args.dropFirst()), isValidate: false)
        case "heal":
            return parseHeal(args: Array(args.dropFirst()))
        default:
            return .help
        }
    }

    private static func parseValidateOrDiff(args: [String], isValidate: Bool) -> Command {
        var config: String?
        var desired: String?
        var invariants: String?
        var positionalIndex = 0

        var i = 0
        while i < args.count {
            switch args[i] {
            case "--desired":
                i += 1
                if i < args.count { desired = args[i] }
            case "--invariants":
                i += 1
                if i < args.count { invariants = args[i] }
            default:
                if positionalIndex == 0 {
                    config = args[i]
                    positionalIndex += 1
                }
            }
            i += 1
        }

        guard let c = config, let d = desired else {
            return .help
        }

        if isValidate {
            return .validate(config: c, desired: d, invariants: invariants)
        } else {
            return .diff(config: c, desired: d, invariants: invariants)
        }
    }

    private static func parseHeal(args: [String]) -> Command {
        var config: String?
        var desired: String?
        var invariants: String?
        var audit: String = "audit.jsonl"
        var positionalIndex = 0

        var i = 0
        while i < args.count {
            switch args[i] {
            case "--desired":
                i += 1
                if i < args.count { desired = args[i] }
            case "--invariants":
                i += 1
                if i < args.count { invariants = args[i] }
            case "--audit":
                i += 1
                if i < args.count { audit = args[i] }
            default:
                if positionalIndex == 0 {
                    config = args[i]
                    positionalIndex += 1
                }
            }
            i += 1
        }

        guard let c = config, let d = desired else {
            return .help
        }

        return .heal(config: c, desired: d, invariants: invariants, audit: audit)
    }
}
