// Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.
// Aeostara — Deterministic JSON Configuration Drift Detection and Healing Platform

import Foundation
import AeostaraMacDomain
import AeostaraMacServices

@main
enum AeostaraMacCLI {

    static func main() {
        let command = CommandParser.parse(CommandLine.arguments)
        let runner = CLIRunner()
        let exitCode = runner.run(command: command)
        exit(exitCode)
    }

    private static func timestamp(format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
}
