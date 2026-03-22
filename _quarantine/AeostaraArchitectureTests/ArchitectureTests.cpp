// Aeostara Architecture Enforcement Tests — Catch2
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#include <catch2/catch_test_macros.hpp>

#include <filesystem>
#include <fstream>
#include <regex>
#include <string>
#include <vector>

namespace fs = std::filesystem;

static std::vector<fs::path> collectSourceFiles(const fs::path& root) {
    std::vector<fs::path> result;
    if (!fs::exists(root)) return result;
    for (auto& entry : fs::recursive_directory_iterator(root)) {
        if (entry.is_regular_file()) {
            auto ext = entry.path().extension().string();
            if (ext == ".h" || ext == ".cpp" || ext == ".hpp" ||
                ext == ".cc" || ext == ".cxx" || ext == ".m" || ext == ".mm") {
                result.push_back(entry.path());
            }
        }
    }
    return result;
}

static std::string readFileContent(const fs::path& path) {
    std::ifstream file(path);
    return std::string(std::istreambuf_iterator<char>(file),
                       std::istreambuf_iterator<char>());
}

TEST_CASE("Architecture: No Forsetti includes", "[arch]") {
    auto srcRoot = fs::path(AEOSTARA_SOURCE_DIR);
    auto files = collectSourceFiles(srcRoot / "include");
    auto srcFiles = collectSourceFiles(srcRoot / "src");
    files.insert(files.end(), srcFiles.begin(), srcFiles.end());

    std::regex forsettiInclude(R"(#include\s+[<"]Forsetti)");
    for (const auto& filePath : files) {
        auto content = readFileContent(filePath);
        INFO("Checking: " << filePath.string());
        REQUIRE_FALSE(std::regex_search(content, forsettiInclude));
    }
}

TEST_CASE("Architecture: All concrete classes final", "[arch]") {
    auto srcRoot = fs::path(AEOSTARA_SOURCE_DIR);
    auto files = collectSourceFiles(srcRoot / "include");

    std::regex classDecl(R"((class|struct)\s+(\w+)\s+(final\s+)?[:{])");
    for (const auto& filePath : files) {
        auto filename = filePath.filename().string();
        if (filename.size() > 1 && filename[0] == 'I' && std::isupper(filename[1]))
            continue;

        auto content = readFileContent(filePath);
        std::sregex_iterator it(content.begin(), content.end(), classDecl);
        std::sregex_iterator end;
        for (; it != end; ++it) {
            std::string typeName = (*it)[2].str();
            std::string finalKw = (*it)[3].str();
            if (typeName.size() > 1 && typeName[0] == 'I' && std::isupper(typeName[1]))
                continue;
            if (typeName.find("Type") != std::string::npos) continue;
            if (typeName.find("Severity") != std::string::npos) continue;
            INFO("Non-final type: " << typeName << " in " << filePath.string());
            REQUIRE_FALSE(finalKw.empty());
        }
    }
}

TEST_CASE("Architecture: Correct namespace (no Forsetti)", "[arch]") {
    auto srcRoot = fs::path(AEOSTARA_SOURCE_DIR);
    auto files = collectSourceFiles(srcRoot / "src" / "AeostaraCore");

    std::regex forsettiNs(R"(namespace\s+Forsetti)");
    for (const auto& filePath : files) {
        auto content = readFileContent(filePath);
        INFO("Checking: " << filePath.string());
        REQUIRE_FALSE(std::regex_search(content, forsettiNs));
    }
}

TEST_CASE("Architecture: Copyright headers present", "[arch]") {
    auto srcRoot = fs::path(AEOSTARA_SOURCE_DIR);
    auto files = collectSourceFiles(srcRoot / "include");
    auto srcFiles = collectSourceFiles(srcRoot / "src");
    files.insert(files.end(), srcFiles.begin(), srcFiles.end());

    for (const auto& filePath : files) {
        auto content = readFileContent(filePath);
        INFO("Missing copyright in: " << filePath.string());
        REQUIRE(content.find("Copyright (c) 2026 James Daley") != std::string::npos);
    }
}

TEST_CASE("Architecture: Core does not depend on CLI", "[arch]") {
    auto srcRoot = fs::path(AEOSTARA_SOURCE_DIR);
    auto files = collectSourceFiles(srcRoot / "src" / "AeostaraCore");
    auto headerFiles = collectSourceFiles(srcRoot / "include" / "AeostaraCore");
    files.insert(files.end(), headerFiles.begin(), headerFiles.end());

    std::regex cliInclude(R"(#include.*AeostaraCLI)");
    for (const auto& filePath : files) {
        auto content = readFileContent(filePath);
        INFO("Core depends on CLI: " << filePath.string());
        REQUIRE_FALSE(std::regex_search(content, cliInclude));
    }
}

TEST_CASE("Compliance: No Python in source tree", "[compliance]") {
    auto srcRoot = fs::path(AEOSTARA_SOURCE_DIR);
    auto files = collectSourceFiles(srcRoot / "include");
    auto srcFiles = collectSourceFiles(srcRoot / "src");
    files.insert(files.end(), srcFiles.begin(), srcFiles.end());

    std::regex pythonRef(R"(\bpython\b|\bPython\b|\.py[\"'\s>])");
    for (const auto& filePath : files) {
        auto content = readFileContent(filePath);
        INFO("Python reference in: " << filePath.string());
        REQUIRE_FALSE(std::regex_search(content, pythonRef));
    }
}

TEST_CASE("Compliance: No YAML in source tree", "[compliance]") {
    auto srcRoot = fs::path(AEOSTARA_SOURCE_DIR);
    auto files = collectSourceFiles(srcRoot / "include");
    auto srcFiles = collectSourceFiles(srcRoot / "src");
    files.insert(files.end(), srcFiles.begin(), srcFiles.end());

    std::regex yamlRef(R"(yaml|YAML|Yaml|\.yml|yaml-cpp)");
    for (const auto& filePath : files) {
        auto content = readFileContent(filePath);
        INFO("YAML reference in: " << filePath.string());
        REQUIRE_FALSE(std::regex_search(content, yamlRef));
    }
}
