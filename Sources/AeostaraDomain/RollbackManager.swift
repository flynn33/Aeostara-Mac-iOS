// Copyright (c) 2026 James Daley. All Rights Reserved.
// Aeostara — Deterministic JSON Configuration Drift Detection and Healing Platform

import Foundation

/// Manages rollback operations: creates rollback plans and executes them.
public final class RollbackManager {

    private let backupProvider: IBackupProvider

    public init(backupProvider: IBackupProvider) {
        self.backupProvider = backupProvider
    }

    /// Create a rollback plan from a repair plan ID and backup/original paths.
    public func createRollbackPlan(planID: String, backupPath: String, originalPath: String) -> RollbackPlan {
        return RollbackPlan(
            planID: planID,
            backupFilePath: backupPath,
            originalFilePath: originalPath
        )
    }

    /// Execute a rollback by restoring the backup to the original path.
    public func executeRollback(plan: RollbackPlan) throws -> Bool {
        return try backupProvider.restoreBackup(
            backupPath: plan.backupFilePath,
            originalPath: plan.originalFilePath
        )
    }
}
