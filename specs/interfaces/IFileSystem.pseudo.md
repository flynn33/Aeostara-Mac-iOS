# IFileSystem Interface

Abstract file system interface. All file I/O in Aeostara goes through this interface, enabling platform-specific implementations and test mocking.

## Methods

### readFile(path) → string

Read the entire contents of a file as a string.

**Parameters:**
- `path` (string) — file path

**Returns:** string — the file contents

**Errors:** throws if the file does not exist or cannot be read

### writeFile(path, content)

Write a string to a file, creating or overwriting it.

**Parameters:**
- `path` (string) — file path
- `content` (string) — the content to write

### fileExists(path) → Boolean

Check if a file exists at the given path.

**Parameters:**
- `path` (string) — file path

**Returns:** true if the file exists

### copyFile(from, to) → Boolean

Copy a file from one path to another.

**Parameters:**
- `from` (string) — source file path
- `to` (string) — destination file path

**Returns:** true if the copy was successful
