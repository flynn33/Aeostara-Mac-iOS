// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#include "AeostaraCore/RollbackManager.h"

namespace Aeostara {

RollbackManager::RollbackManager(std::shared_ptr<IBackupProvider> backup)
    : backup_(std::move(backup)) {}

RollbackPlan RollbackManager::createRollbackPlan(const std::string& planID,
                                                   const std::string& backupPath,
                                                   const std::string& originalPath) {
    return RollbackPlan{
        .planID = planID,
        .backupFilePath = backupPath,
        .originalFilePath = originalPath
    };
}

bool RollbackManager::executeRollback(const RollbackPlan& plan) const {
    return backup_->restoreBackup(plan.backupFilePath, plan.originalFilePath);
}

} // namespace Aeostara
