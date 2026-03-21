// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#pragma once

#include <string>

namespace Aeostara {

/// Abstract backup interface.
class IBackupProvider {
public:
    /// Create a backup of the given file. Returns the backup file path.
    virtual std::string createBackup(const std::string& filePath) = 0;

    /// Restore a backup to the original file path. Returns true on success.
    virtual bool restoreBackup(const std::string& backupPath, const std::string& originalPath) = 0;

    virtual ~IBackupProvider() = default;
};

} // namespace Aeostara
