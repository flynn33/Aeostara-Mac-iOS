// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#include "CppUnitTest.h"

#include <filesystem>
#include <fstream>
#include <regex>
#include <string>
#include <vector>

using namespace Microsoft::VisualStudio::CppUnitTestFramework;
namespace fs = std::filesystem;

namespace AeostaraArchitectureTests {

// Helper: collect all .h and .cpp files under a directory
static std::vector<fs::path> collectSourceFiles(const fs::path& root)
{
    std::vector<fs::path> result;
    if (!fs::exists(root)) return result;
    for (auto& entry : fs::recursive_directory_iterator(root)) {
        if (entry.is_regular_file()) {
            auto ext = entry.path().extension().string();
            if (ext == ".h" || ext == ".cpp" || ext == ".hpp") {
                result.push_back(entry.path());
            }
        }
    }
    return result;
}

// Helper: read entire file contents
static std::string readFileContent(const fs::path& path)
{
    std::ifstream file(path);
    return std::string(std::istreambuf_iterator<char>(file),
                       std::istreambuf_iterator<char>());
}

TEST_CLASS(ArchitectureEnforcementTests)
{
public:

    // R001 compliance: No ForsettiCore or ForsettiPlatform includes in any Aeostara source
    TEST_METHOD(NoForsettiIncludes)
    {
        auto srcRoot = fs::path(AEOSTARA_SOURCE_DIR);
        auto includeRoot = srcRoot / "include";
        auto srcDir = srcRoot / "src";

        auto files = collectSourceFiles(includeRoot);
        auto srcFiles = collectSourceFiles(srcDir);
        files.insert(files.end(), srcFiles.begin(), srcFiles.end());

        std::regex forsettiInclude(R"(#include\s+[<"]Forsetti)");

        for (const auto& filePath : files) {
            auto content = readFileContent(filePath);
            Assert::IsFalse(
                std::regex_search(content, forsettiInclude),
                (L"Forbidden Forsetti include found in: " + filePath.wstring()).c_str());
        }
    }

    // R005 compliance: All concrete classes should be final
    TEST_METHOD(AllConcreteClassesFinal)
    {
        auto srcRoot = fs::path(AEOSTARA_SOURCE_DIR);
        auto includeRoot = srcRoot / "include";

        auto files = collectSourceFiles(includeRoot);

        // Match "class Foo :" or "class Foo {" or "struct Foo :" or "struct Foo {"
        // that are NOT interfaces (I-prefixed) and NOT already final
        std::regex classDecl(R"((class|struct)\s+(\w+)\s+(final\s+)?[:{])");

        for (const auto& filePath : files) {
            auto content = readFileContent(filePath);
            auto filename = filePath.filename().string();

            // Skip interface headers (I*.h)
            if (filename.size() > 1 && filename[0] == 'I' && std::isupper(filename[1])) {
                continue;
            }

            std::sregex_iterator it(content.begin(), content.end(), classDecl);
            std::sregex_iterator end;

            for (; it != end; ++it) {
                std::string typeName = (*it)[2].str();
                std::string finalKeyword = (*it)[3].str();

                // Skip interfaces (I-prefixed types)
                if (typeName.size() > 1 && typeName[0] == 'I' && std::isupper(typeName[1])) {
                    continue;
                }

                // Skip enums disguised as classes/structs
                if (typeName.find("Type") != std::string::npos) continue;
                if (typeName.find("Severity") != std::string::npos) continue;

                Assert::IsFalse(
                    finalKeyword.empty(),
                    (L"Non-final class/struct found: " +
                     std::wstring(typeName.begin(), typeName.end()) +
                     L" in " + filePath.wstring()).c_str());
            }
        }
    }

    // Namespace: all Aeostara code should be in namespace Aeostara, not Forsetti
    TEST_METHOD(CorrectNamespace)
    {
        auto srcRoot = fs::path(AEOSTARA_SOURCE_DIR);
        auto srcDir = srcRoot / "src" / "AeostaraCore";

        auto files = collectSourceFiles(srcDir);

        std::regex forsettiNamespace(R"(namespace\s+Forsetti)");

        for (const auto& filePath : files) {
            auto content = readFileContent(filePath);
            Assert::IsFalse(
                std::regex_search(content, forsettiNamespace),
                (L"Forbidden Forsetti namespace found in: " + filePath.wstring()).c_str());
        }
    }

    // Copyright header: all source files should have the copyright header
    TEST_METHOD(CopyrightHeaders)
    {
        auto srcRoot = fs::path(AEOSTARA_SOURCE_DIR);
        auto includeRoot = srcRoot / "include";
        auto srcDir = srcRoot / "src";

        auto files = collectSourceFiles(includeRoot);
        auto srcFiles = collectSourceFiles(srcDir);
        files.insert(files.end(), srcFiles.begin(), srcFiles.end());

        for (const auto& filePath : files) {
            auto content = readFileContent(filePath);
            Assert::IsTrue(
                content.find("Copyright (c) 2026 James Daley") != std::string::npos,
                (L"Missing copyright header in: " + filePath.wstring()).c_str());
        }
    }

    // Compliance: No Python references in product source
    TEST_METHOD(NoPythonInSourceTree)
    {
        auto srcRoot = fs::path(AEOSTARA_SOURCE_DIR);
        auto includeRoot = srcRoot / "include";
        auto srcDir = srcRoot / "src";

        auto files = collectSourceFiles(includeRoot);
        auto srcFiles = collectSourceFiles(srcDir);
        files.insert(files.end(), srcFiles.begin(), srcFiles.end());

        std::regex pythonRef(R"(\bpython\b|\bPython\b|\.py[\"'\s>])");

        for (const auto& filePath : files) {
            auto content = readFileContent(filePath);
            Assert::IsFalse(
                std::regex_search(content, pythonRef),
                (L"Forbidden Python reference found in: " + filePath.wstring()).c_str());
        }
    }

    // Compliance: No YAML references in product source
    TEST_METHOD(NoYamlInSourceTree)
    {
        auto srcRoot = fs::path(AEOSTARA_SOURCE_DIR);
        auto includeRoot = srcRoot / "include";
        auto srcDir = srcRoot / "src";

        auto files = collectSourceFiles(includeRoot);
        auto srcFiles = collectSourceFiles(srcDir);
        files.insert(files.end(), srcFiles.begin(), srcFiles.end());

        std::regex yamlRef(R"(yaml|YAML|Yaml|\.yml|yaml-cpp)");

        for (const auto& filePath : files) {
            auto content = readFileContent(filePath);
            Assert::IsFalse(
                std::regex_search(content, yamlRef),
                (L"Forbidden YAML reference found in: " + filePath.wstring()).c_str());
        }
    }

    // Compliance: No YAML support claims in documentation
    TEST_METHOD(NoYamlClaimsInDocs)
    {
        auto srcRoot = fs::path(AEOSTARA_SOURCE_DIR);

        std::vector<fs::path> docFiles = {
            srcRoot / "README.md",
            srcRoot / "CHANGELOG.md"
        };

        std::regex yamlClaim(R"(YAML support|yaml support|YAML.+supported|supports?.+YAML)");

        for (const auto& filePath : docFiles) {
            if (!fs::exists(filePath)) continue;
            auto content = readFileContent(filePath);
            Assert::IsFalse(
                std::regex_search(content, yamlClaim),
                (L"YAML support claim found in: " + filePath.wstring()).c_str());
        }
    }

    // One-way dependency: CLI depends on Core, not the reverse
    TEST_METHOD(CoreDoesNotDependOnCLI)
    {
        auto srcRoot = fs::path(AEOSTARA_SOURCE_DIR);
        auto coreDir = srcRoot / "src" / "AeostaraCore";
        auto includeDir = srcRoot / "include" / "AeostaraCore";

        auto files = collectSourceFiles(coreDir);
        auto headerFiles = collectSourceFiles(includeDir);
        files.insert(files.end(), headerFiles.begin(), headerFiles.end());

        std::regex cliInclude(R"(#include.*AeostaraCLI)");

        for (const auto& filePath : files) {
            auto content = readFileContent(filePath);
            Assert::IsFalse(
                std::regex_search(content, cliInclude),
                (L"Core depends on CLI (forbidden): " + filePath.wstring()).c_str());
        }
    }
};

} // namespace AeostaraArchitectureTests
