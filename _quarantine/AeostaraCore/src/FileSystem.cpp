// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#include "AeostaraCore/IFileSystem.h"

#include <filesystem>
#include <fstream>
#include <sstream>
#include <stdexcept>

namespace Aeostara {

std::string DefaultFileSystem::readFile(const std::string& path) {
    std::ifstream file(path);
    if (!file.is_open()) {
        throw std::runtime_error("Cannot open file: " + path);
    }
    std::ostringstream ss;
    ss << file.rdbuf();
    return ss.str();
}

void DefaultFileSystem::writeFile(const std::string& path, const std::string& content) {
    std::ofstream file(path);
    if (!file.is_open()) {
        throw std::runtime_error("Cannot write to file: " + path);
    }
    file << content;
}

bool DefaultFileSystem::fileExists(const std::string& path) {
    return std::filesystem::exists(path);
}

bool DefaultFileSystem::copyFile(const std::string& from, const std::string& to) {
    try {
        std::filesystem::copy_file(
            from, to,
            std::filesystem::copy_options::overwrite_existing
        );
        return true;
    } catch (...) {
        return false;
    }
}

} // namespace Aeostara
