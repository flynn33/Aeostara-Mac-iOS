// Aeostara
// Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.

#pragma once

#include <string>

namespace Aeostara {

struct ParsedCommand final {
    std::string command;         // validate, diff, heal
    std::string configPath;
    std::string desiredPath;
    std::string invariantsPath;  // optional
    std::string auditPath;       // optional, defaults to "aeostara-audit.jsonl"
    bool help = false;
    bool valid = false;
    std::string error;
};

class CommandParser final {
public:
    static ParsedCommand parse(int argc, char* argv[]);
    static void printUsage();
};

} // namespace Aeostara
