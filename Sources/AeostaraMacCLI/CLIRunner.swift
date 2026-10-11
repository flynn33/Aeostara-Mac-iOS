// Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.
// Aeostara — Deterministic JSON Configuration Drift Detection and Healing Platform

import Foundation
import AeostaraMacDomain
import AeostaraMacServices

/// Executes CLI commands against the healing engine.
final class CLIRunner {

    private var engine: IHealingEngine?

    init(engine: IHealingEngine? = nil) {
        self.engine = engine
    }

    /// Run the given command. Returns exit code: 0 = success, 1 = drift/blocked, 2 = error.
    func run(command: Command) -> Int32 {
        switch command {
        case .validate(let config, let desired, let invariants, let context):
            guard bind(context) else { return 2 }
            return runValidate(config: config, desired: desired, invariants: invariants)
        case .diff(let config, let desired, let invariants, let context):
            guard bind(context) else { return 2 }
            return runDiff(config: config, desired: desired, invariants: invariants)
        case .heal(let config, let desired, let invariants, let audit, let context):
            guard bind(context) else { return 2 }
            return runHeal(config: config, desired: desired, invariants: invariants, audit: audit)
        case .help:
            printUsage()
            return 0
        }
    }

    // MARK: - Commands

    private func runValidate(config: String, desired: String, invariants: String?) -> Int32 {
        do {
            let result = try engine!.validate(configPath: config, desiredPath: desired, invariantsPath: invariants)

            try output([JSONMember("valid", .bool(result.valid)), JSONMember("driftCount", .integer(String(result.drifts.count))), JSONMember("violations", .array(result.violations.map(JSONValue.string))), JSONMember("errors", .array(result.errors.map(JSONValue.string))), JSONMember("nativeResult", result.nativeResult?.contractJSON ?? .null), JSONMember("diagnosticChain", result.nativeFailure?.diagnosticChain.contractJSON ?? .null)])
            return result.errors.isEmpty ? (result.valid ? 0 : 1) : 2
        } catch {
            printFailure(error)
            return 2
        }
    }

    private func runDiff(config: String, desired: String, invariants: String?) -> Int32 {
        do {
            let result = try engine!.diff(configPath: config, desiredPath: desired, invariantsPath: invariants)

            try output([JSONMember("driftCount", .integer(String(result.drifts.count))), JSONMember("violations", .array(result.violations.map(JSONValue.string))), JSONMember("proposedPlan", result.nativeResult?.recoveryPlan.contractJSON ?? .null), JSONMember("nativeResult", result.nativeResult?.contractJSON ?? .null)])
            return result.drifts.isEmpty && result.violations.isEmpty ? 0 : 1
        } catch {
            printFailure(error)
            return 2
        }
    }

    private func runHeal(config: String, desired: String, invariants: String?, audit: String) -> Int32 {
        do {
            let result = try engine!.heal(configPath: config, desiredPath: desired, invariantsPath: invariants, auditPath: audit)

            try output([JSONMember("success", .bool(result.success)), JSONMember("message", .string(result.message)), JSONMember("nativeResult", result.nativeResult?.contractJSON ?? .null), JSONMember("diagnosticChain", result.nativeFailure?.diagnosticChain.contractJSON ?? .null)])
            return result.success ? 0 : result.nativeFailure?.failedStage == .observe ? 2 : 1
        } catch {
            printFailure(error)
            return 2
        }
    }

    // MARK: - Helpers

    private func bind(_ path: String?) -> Bool {
        do {
            if let path { engine = try NativeCLIContext(data: Data(contentsOf: URL(fileURLWithPath: path))) }
            guard engine != nil else { throw try LifecycleFailure.missingContext() }
            return true
        } catch { printFailure(error); return false }
    }
    private func printUsage() {
        print("Aeostara SDK 0.1.0-rc.1: validate|diff|heal <config> --desired <desired> --semantic-context <declared-context.json> [--invariants <invariants>] [--audit <audit.jsonl>]")
    }
    private func output(_ fields: [JSONMember]) throws { print(try JSONValue.object(fields).canonicalText()) }
    private func printFailure(_ error: Error) {
        let failure = error as? LifecycleFailure
        let fields = [JSONMember("error", .string(failure?.code.rawValue ?? "invalidContext")), JSONMember("diagnosticChain", failure?.diagnosticChain.contractJSON ?? .null)]
        if let bytes = try? JSONValue.object(fields).canonicalData() { FileHandle.standardError.write(bytes + Data([10])) }
    }

}
