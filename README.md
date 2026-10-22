# Aeostara native macOS SDK 0.1.0-rc.1

This permanent `platform/macos` branch owns the native macOS implementation. It realizes the frozen Aeostara base and upstream ASH authorities with explicit application-owned semantics, policy, resources and lifecycle. The coordinated candidate distributes `AeostaraMacDomain` and `AeostaraMacServices` as binary Swift packages.

| Product | Closure |
|---|---|
| `AeostaraMacDomain` | Domain only |
| `AeostaraMacServices` | Services and `AeostaraMacDomain` |

Minimum macOS 13; Swift tools 5.9. Start with [SDK integration](SDK/Documentation/Integration.md). Compiled packages and the verified consumer guide belong to the coordinated GitHub prerelease, not GitHub's automatically generated source archives.

## SDK consumption boundary

Use only the named public SDK products and their declared dependency closure. Do not copy, vendor, submodule, recursively import, or link this entire repository into an application. Architecture/specification sources are authorities to read; tests and corpora are verification material; examples are references. Application templates, when explicitly designated, become application-owned code. These roles do not make the repository a runtime dependency. The macOS CLI is a separate executable. The iOS app shell is not the SDK and is not designated a production template. Package-manager source fetching alone is not whole-repository incorporation: actual product selection, linkage, resources, and source ownership determine the boundary.

## Authorities and verification

Aeostara is a downstream ASH-based native realization. Base `v1.0.0`: `774b981ef2267a41c1b1a59497b2b0746a86f32b`. Verified ASH lineage: `e123f5d7fdbb381179971f721a3292c31eb1cbc2`. [Native baseline](Docs/NATIVE_BASELINE.md) identifies the accepted design; [conformance trace](Docs/Conformance_Trace.md) maps current native interfaces and verification. Legacy specification/phase reports are historical material, not SDK qualification.

Source checks use `swift test` (Debug and Release); iOS runtime checks use Xcode on actual installed simulators. `Tools/SDK/build_sdk.py` requires exact clean committed source for final archives; `Tools/SDK/package_sdk.py` stages only the SDK allowlist and verifies framework byte inventories. The coordinated guide distinguishes source tests, final artifacts, external binary consumers, draft downloads and published downloads.

## Repository and license

The native implementation branches do not merge into each other or coordination `main`. No new third-party runtime dependency is present. Copyright 2026 James Daley. Licensed under the Apache License, Version 2.0 in [LICENSE](LICENSE). Commercial use is allowed. Retain the LICENSE and NOTICE, credit James Daley for this project, and mark changes so provenance stays intact. Outside contributions are not accepted; the owner's maintenance policy controls this repository.
