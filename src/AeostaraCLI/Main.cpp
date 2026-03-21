// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#include "AeostaraCore/BackupManager.h"
#include "AeostaraCore/HealingEngine.h"
#include "AeostaraCore/IFileSystem.h"
#include "AeostaraCore/JsonConfigAdapter.h"
#include "AeostaraCore/Version.h"
#include "CommandParser.h"
#include "CLIRunner.h"

#include <iostream>
#include <memory>

int main(int argc, char* argv[]) {
    using namespace Aeostara;

    auto cmd = CommandParser::parse(argc, argv);

    if (cmd.help) {
        CommandParser::printUsage();
        return 0;
    }

    if (!cmd.valid) {
        std::cerr << "Error: " << cmd.error << "\n\n";
        CommandParser::printUsage();
        return 2;
    }

    // Construct dependencies via constructor DI
    auto fs = std::make_shared<DefaultFileSystem>();
    auto adapter = std::make_shared<JsonConfigAdapter>(fs);
    auto backup = std::make_shared<BackupManager>(fs);

    auto engine = std::make_shared<HealingEngine>(adapter, backup, fs);

    CLIRunner runner(engine);
    return runner.run(cmd);
}
