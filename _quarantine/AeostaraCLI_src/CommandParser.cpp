// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#include "CommandParser.h"

#include <iostream>
#include <string>

namespace Aeostara {

ParsedCommand CommandParser::parse(int argc, char* argv[]) {
    ParsedCommand cmd;
    cmd.auditPath = "aeostara-audit.jsonl";

    if (argc < 2) {
        cmd.help = true;
        cmd.valid = true;
        return cmd;
    }

    std::string first(argv[1]);

    if (first == "--help" || first == "-h") {
        cmd.help = true;
        cmd.valid = true;
        return cmd;
    }

    if (first != "validate" && first != "diff" && first != "heal") {
        cmd.valid = false;
        cmd.error = "Unknown command: " + first;
        return cmd;
    }

    cmd.command = first;

    // Parse remaining arguments
    for (int i = 2; i < argc; ++i) {
        std::string arg(argv[i]);

        if ((arg == "--config" || arg == "-c") && i + 1 < argc) {
            cmd.configPath = argv[++i];
        } else if ((arg == "--desired" || arg == "-d") && i + 1 < argc) {
            cmd.desiredPath = argv[++i];
        } else if ((arg == "--invariants" || arg == "-i") && i + 1 < argc) {
            cmd.invariantsPath = argv[++i];
        } else if ((arg == "--audit" || arg == "-a") && i + 1 < argc) {
            cmd.auditPath = argv[++i];
        } else if (arg == "--help" || arg == "-h") {
            cmd.help = true;
            cmd.valid = true;
            return cmd;
        } else if (cmd.configPath.empty() && arg[0] != '-') {
            // First positional argument is the config path
            cmd.configPath = arg;
        } else {
            cmd.valid = false;
            cmd.error = "Unknown argument: " + arg;
            return cmd;
        }
    }

    // Validate required arguments
    if (cmd.configPath.empty()) {
        cmd.valid = false;
        cmd.error = "Missing required argument: config path";
        return cmd;
    }

    if (cmd.desiredPath.empty()) {
        cmd.valid = false;
        cmd.error = "Missing required argument: --desired <path>";
        return cmd;
    }

    cmd.valid = true;
    return cmd;
}

void CommandParser::printUsage() {
    std::cerr << "Aeostara v0.1 - Deterministic Config Drift Healing\n"
              << "\n"
              << "Usage:\n"
              << "  aeostara <command> <config> --desired <desired> [options]\n"
              << "\n"
              << "Commands:\n"
              << "  validate   Validate config and detect drift\n"
              << "  diff       Show drift and proposed repair plan\n"
              << "  heal       Apply deterministic repair\n"
              << "\n"
              << "Options:\n"
              << "  --config, -c <path>       Config file path (or first positional arg)\n"
              << "  --desired, -d <path>      Desired state file path (required)\n"
              << "  --invariants, -i <path>   Invariant rules file path (optional)\n"
              << "  --audit, -a <path>        Audit trail file path (default: aeostara-audit.jsonl)\n"
              << "  --help, -h                Show this help message\n"
              << "\n"
              << "Exit codes:\n"
              << "  0  Success / no drift\n"
              << "  1  Drift detected / policy blocked\n"
              << "  2  Error\n";
}

} // namespace Aeostara
