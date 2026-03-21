// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#pragma once

#include "AeostaraCore/Contracts.h"
#include "AeostaraCore/IBackupProvider.h"

#include <memory>

namespace Aeostara {

/// Executes rollback by restoring from backup.
class RollbackManager final {
public:
    explicit RollbackManager(std::shared_ptr<IBackupProvider> backup);

    /// Create a rollback plan from a repair plan and backup path.
    static RollbackPlan createRollbackPlan(const std::string& planID,
                                            const std::string& backupPath,
                                            const std::string& originalPath);

    /// Execute the rollback. Returns true on success.
    bool executeRollback(const RollbackPlan& plan) const;

private:
    std::shared_ptr<IBackupProvider> backup_;
};

} // namespace Aeostara
