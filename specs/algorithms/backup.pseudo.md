# Backup

Creates timestamped backup copies of configuration files before repair.

## createBackup(filePath) → backupPath

```
FUNCTION createBackup(filePath) → string:
  timestamp ← currentTimestamp("YYYYMMDD_HHmmss")
  backupPath ← filePath + ".backup." + timestamp
  success ← fileSystem.copyFile(filePath, backupPath)

  IF NOT success:
    ERROR "Failed to create backup of " + filePath

  RETURN backupPath
```

## restoreBackup(backupPath, originalPath) → Boolean

```
FUNCTION restoreBackup(backupPath, originalPath) → Boolean:
  IF NOT fileSystem.fileExists(backupPath):
    RETURN false

  success ← fileSystem.copyFile(backupPath, originalPath)
  RETURN success
```
