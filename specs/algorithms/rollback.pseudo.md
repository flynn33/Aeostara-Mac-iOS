# Rollback

Restores a configuration file from backup when verification fails.

## createRollbackPlan(planID, backupPath, originalPath) → RollbackPlan

```
RETURN RollbackPlan(
  planID = planID,
  backupFilePath = backupPath,
  originalFilePath = originalPath
)
```

## executeRollback(rollbackPlan) → Boolean

```
FUNCTION executeRollback(plan) → Boolean:
  success ← backup.restoreBackup(plan.backupFilePath, plan.originalFilePath)
  RETURN success
```
