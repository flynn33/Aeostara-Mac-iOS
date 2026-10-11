# Aeostara macOS SDK 0.1.0-rc.1

This release candidate distributes native dynamic frameworks as an extracted local binary Swift package. Select `AeostaraMacDomain` for pure contracts and semantics, or `AeostaraMacServices` with its declared `AeostaraMacDomain` dependency for native resources and lean diagnostics. Minimum macOS 13; Swift package tools 5.9.

Start with [Integration](Documentation/Integration.md), [Public API](Documentation/Public_API.md), and [Safety and recovery](Documentation/Safety_and_Recovery.md). The coordinated release guide records the actual build and executed runtime matrix.

## SDK consumption boundary

Use only the named public SDK products and their declared dependency closure. Do not copy, vendor, submodule, recursively import, or link this entire repository into an application. Architecture/specification sources are authorities to read; tests and corpora are verification material; examples are references. Application templates, when explicitly designated, become application-owned code. These roles do not make the repository a runtime dependency. The macOS CLI is a separate executable. The iOS app shell is not the SDK and is not designated a production template. Package-manager source fetching alone is not whole-repository incorporation: actual product selection, linkage, resources, and source ownership determine the boundary.

## Integrity and license

Compare this ZIP with the coordinated `SHA256SUMS`. `SDK_MANIFEST.json` records the native source commit, authority pins, toolchain, architecture inspections, and every payload entry except itself. The manifest/configuration `signing: "unsigned"` denotes `CODE_SIGNING_ALLOWED=NO` and no distribution signing identity. The macOS frameworks carry linker ad-hoc signatures. A checksum is an integrity comparison, not a distribution signature. Copyright 2026 James Daley. Dual license: non-commercial, academic and personal use under [LICENSE](LICENSE); commercial use requires a separate written license.
