# IConfigAdapter Interface

Bridges file-specific I/O concerns with the core healing engine. Each config format (JSON, future YAML, etc.) has its own adapter implementation.

## Methods

### observe(filePath) → ObservedState

Read and parse a config file, returning the observed state.

**Parameters:**
- `filePath` (string) — path to the configuration file

**Returns:** ObservedState with parsed data, source file path, and timestamp

### encode(observed, desired) → EncodedState

Flatten and encode observed and desired states into canonical dot-path form for drift comparison.

**Parameters:**
- `observed` (ObservedState) — the observed state
- `desired` (DesiredState) — the desired state

**Returns:** EncodedState with flattened maps for both states

### applyRepair(filePath, plan) → Boolean

Apply a repair plan to the config file by executing each RepairAction.

**Parameters:**
- `filePath` (string) — path to the configuration file
- `plan` (RepairPlan) — the repair plan to apply

**Returns:** true if repair was applied successfully
