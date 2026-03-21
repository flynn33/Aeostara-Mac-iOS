// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#pragma once

#include <string>

namespace Aeostara {

/// Abstract file system interface for testability.
/// All file I/O in Aeostara goes through this interface.
class IFileSystem {
public:
    virtual std::string readFile(const std::string& path) = 0;
    virtual void writeFile(const std::string& path, const std::string& content) = 0;
    virtual bool fileExists(const std::string& path) = 0;
    virtual bool copyFile(const std::string& from, const std::string& to) = 0;

    virtual ~IFileSystem() = default;
};

/// Default file system implementation using std::filesystem and std::fstream.
class DefaultFileSystem final : public IFileSystem {
public:
    std::string readFile(const std::string& path) override;
    void writeFile(const std::string& path, const std::string& content) override;
    bool fileExists(const std::string& path) override;
    bool copyFile(const std::string& from, const std::string& to) override;
};

} // namespace Aeostara
