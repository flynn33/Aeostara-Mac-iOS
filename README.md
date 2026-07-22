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

The Apple implementation branches pin to Aeostara platform-agnostic base release `v1.0.0` from `flynn33/aeostara` at commit `774b981ef2267a41c1b1a59497b2b0746a86f32b`.

## License

Copyright 2026 James Daley

This project is licensed under the Apache License, Version 2.0.
See the [LICENSE](LICENSE) file for the full terms.
