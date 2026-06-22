# Aeostara Mac and iOS

This repository holds native Apple realizations of the Aeostara base design on isolated permanent implementation branches.

## Branch Model

| Branch | Role |
|---|---|
| `main` | Coordination branch for repository governance, branch map, and migration provenance. No platform implementation source is permitted here. |
| `platform/macos` | Native macOS realization imported from `flynn33/aeostara:platform/macos`. |
| `platform/ios` | Native iOS realization imported from `flynn33/aeostara:platform/ios`. |

The implementation branches are permanent and non-merging. macOS implementation source must not be merged into iOS, iOS implementation source must not be merged into macOS, and neither implementation branch may merge into coordination `main`.

## Base Authority

The Apple implementation branches pin to Aeostara platform-agnostic base release `v1.0.0` from `flynn33/aeostara` at commit `dfa401fa1826a73f5747dd83c74ff963e15eb32f`.
