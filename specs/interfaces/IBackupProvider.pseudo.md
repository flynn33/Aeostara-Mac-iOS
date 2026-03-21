# IBackupProvider Interface

Abstract backup interface for creating and restoring configuration file backups.

## Methods

### createBackup(filePath) → backupPath

Create a timestamped backup of the given file.

**Parameters:**
- `filePath` (string) — path to the file to back up

**Returns:** string — the path to the created backup file

### restoreBackup(backupPath, originalPath) → Boolean

Restore a backup to the original file path.

**Parameters:**
- `backupPath` (string) — path to the backup file
- `originalPath` (string) — path to restore the backup to

**Returns:** true if restoration was successful
