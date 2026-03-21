// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#include "AeostaraCore/BackupManager.h"

#include <chrono>
#include <iomanip>
#include <sstream>

namespace Aeostara {

BackupManager::BackupManager(std::shared_ptr<IFileSystem> fs)
    : fs_(std::move(fs)) {}

std::string BackupManager::createBackup(const std::string& filePath) {
    std::string backupPath = generateBackupPath(filePath);
    fs_->copyFile(filePath, backupPath);
    return backupPath;
}

bool BackupManager::restoreBackup(const std::string& backupPath, const std::string& originalPath) {
    return fs_->copyFile(backupPath, originalPath);
}

std::string BackupManager::generateBackupPath(const std::string& filePath) {
    auto now = std::chrono::system_clock::now();
    auto time_t = std::chrono::system_clock::to_time_t(now);
    std::tm tm{};
    localtime_r(&time_t, &tm);

    std::ostringstream ss;
    ss << filePath << ".backup."
       << std::put_time(&tm, "%Y%m%d_%H%M%S");
    return ss.str();
}

} // namespace Aeostara
