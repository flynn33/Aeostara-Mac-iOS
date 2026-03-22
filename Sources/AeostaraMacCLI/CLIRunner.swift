// Copyright (c) 2026 James Daley. All Rights Reserved.
// Aeostara — Deterministic JSON Configuration Drift Detection and Healing Platform

import Foundation
import AeostaraMacDomain
import AeostaraMacServices

/// Executes CLI commands against the healing engine.
final class CLIRunner {

    private let engine: IHealingEngine

    init(engine: IHealingEngine) {
        self.engine = engine
    }

    /// Run the given command. Returns exit code: 0 = success, 1 = drift/blocked, 2 = error.
    func run(command: Command) -> Int32 {
        switch command {
        case .validate(let config, let desired, let invariants):
            return runValidate(config: config, desired: desired, invariants: invariants)
        case .diff(let config, let desired, let invariants):
            return runDiff(config: config, desired: desired, invariants: invariants)
        case .heal(let config, let desired, let invariants, let audit):
            return runHeal(config: config, desired: desired, invariants: invariants, audit: audit)
        case .help:
            printUsage()
            return 0
        }
    }

    // MARK: - Commands

    private func runValidate(config: String, desired: String, invariants: String?) -> Int32 {
        do {
            let result = try engine.validate(configPath: config, desiredPath: desired, invariantsPath: invariants)

            if result.valid {
                print("VALID: No drift detected.")
                return 0
            } else {
                print("DRIFT DETECTED: \(result.drifts.count) difference(s) found.")
                for drift in result.drifts {
                    print("  [\(drift.type.rawValue)] \(drift.keyPath): \(drift.description)")
                }
                if !result.violations.isEmpty {
                    print("VIOLATIONS:")
                    for v in result.violations { print("  - \(v)") }
                }
                return 1
            }
        } catch {
            printError("Validation failed: \(error.localizedDescription)")
            return 2
        }
    }

    private func runDiff(config: String, desired: String, invariants: String?) -> Int32 {
        do {
            let result = try engine.diff(configPath: config, desiredPath: desired, invariantsPath: invariants)

            if result.drifts.isEmpty {
                print("No drift detected.")
                return 0
            }

            print("DRIFT: \(result.drifts.count) difference(s) found.")
            for drift in result.drifts {
                print("  [\(drift.type.rawValue)] \(drift.keyPath): \(drift.description)")
            }

            if let plan = result.proposedPlan {
                print("\nPROPOSED REPAIR PLAN (ID: \(plan.planID)):")
                for action in plan.actions {
                    print("  [\(action.actionType.rawValue)] \(action.keyPath): \(action.rationale)")
                }
            }
            return 1
        } catch {
            printError("Diff failed: \(error.localizedDescription)")
            return 2
        }
    }

    private func runHeal(config: String, desired: String, invariants: String?, audit: String) -> Int32 {
        do {
            let result = try engine.heal(configPath: config, desiredPath: desired, invariantsPath: invariants, auditPath: audit)

            if result.success {
                print("HEAL SUCCESSFUL: \(result.message)")
                if let plan = result.executedPlan {
                    print("  Plan ID: \(plan.planID)")
                    print("  Actions: \(plan.actions.count)")
                }
                return 0
            } else {
                print("HEAL FAILED: \(result.message)")
                return 1
            }
        } catch {
            printError("Heal failed: \(error.localizedDescription)")
            return 2
        }
    }

    // MARK: - Helpers

    private func printUsage() {
        print("""
        Aeostara v0.1 — Deterministic JSON Configuration Drift Detection and Healing

        Usage:
          aeostara validate <config> --desired <desired> [--invariants <invariants>]
          aeostara diff    <config> --desired <desired> [--invariants <invariants>]
          aeostara heal    <config> --desired <desired> [--invariants <invariants>] [--audit <audit.jsonl>]

        Exit codes: 0 = success/no drift, 1 = drift/policy blocked, 2 = error
        """)
    }

    private func printError(_ message: String) {
        FileHandle.standardError.write(Data("ERROR: \(message)\n".utf8))
    }
}
