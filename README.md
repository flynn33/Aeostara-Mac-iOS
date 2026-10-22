# Aeostara Apple SDK 0.1.0-rc.1

This repository coordinates independently maintained native Apple realizations of the frozen Aeostara base and ASH authorities. The release candidate distributes two compiled binary Swift packages; source and binary qualification are recorded separately in the coordinated release record.

| Branch | Role | Public products |
|---|---|---|
| `main` | Coordination, governance and release metadata; no native runtime | None |
| `platform/macos` | Native macOS implementation, minimum macOS 13 | `AeostaraMacDomain`, `AeostaraMacServices` |
| `platform/ios` | Native iOS implementation, minimum iOS 16 | `AeostaraDomain`, `AeostaraServices` |

Domain-only selection links Domain. Services selection includes its platform Domain dependency. The implementations and permanent branch histories do not merge into each other or into `main`.

## SDK consumption boundary

Use only the named public SDK products and their declared dependency closure. Do not copy, vendor, submodule, recursively import, or link this entire repository into an application. Architecture/specification sources are authorities to read; tests and corpora are verification material; examples are references. Application templates, when explicitly designated, become application-owned code. These roles do not make the repository a runtime dependency. The macOS CLI is a separate executable. The iOS app shell is not the SDK and is not designated a production template. Package-manager source fetching alone is not whole-repository incorporation: actual product selection, linkage, resources, and source ownership determine the boundary.

Install the extracted platform SDK as a local Swift package using its named products. The coordinated release contains platform SDK ZIPs, separate consumer-owned examples, an integration/qualification guide, a versioned release manifest, and `SHA256SUMS`. GitHub's automatically generated repository-source archives are not the SDK binaries. Platform-prefixed source tags record provenance rather than a shared conventional SwiftPM SemVer package index.

## Semantic authority

Base `v1.0.0`: `774b981ef2267a41c1b1a59497b2b0746a86f32b`. Controlling ASH lineage: `e123f5d7fdbb381179971f721a3292c31eb1cbc2`. The native realization reads and binds these authorities without incorporating their repositories as runtime dependencies. See [coordinated release record](SDK_RELEASE.md), [baseline reference](AEOSTARA_BASELINE_REFERENCE.md), [branch isolation](BRANCH_ISOLATION.md), and [platform status](PLATFORM_STATUS_MATRIX.md).

The application owns explicit semantic mappings, recognized valid states, desired intent, policies, authorized filesystem scope, consent and lifecycle. Optional lean diagnostics do not replace mandatory durable audit or verified backup/restoration. Rich development diagnostic targets, producer tests, the macOS CLI, the iOS app shell and external authority material are excluded from SDK runtime packages.

## License and maintenance

Copyright (c) 2026 James Daley, Raven Forge Software. Licensed under the Apache License, Version 2.0 in [LICENSE](LICENSE). Outside contributions are not accepted; see [CONTRIBUTING](CONTRIBUTING.md). Historical migration receipts preserve their original identities and do not constitute current SDK acceptance.
