# Aeostara SDK repository guidance

Read the current README, `AEOSTARA_BASELINE_REFERENCE.md`, and applicable native documentation before edits. The native release configuration lives in `SDK/ReleaseConfiguration.json` on each platform branch.

`main` is coordination only. `platform/macos` and `platform/ios` own separate native implementations. Integrate changes only into their own platform branch; never merge native branches into each other or into `main`, or copy native runtime implementation between them.

Use only named public SDK products and their declared dependency closure in applications. Do not copy, vendor, submodule, recursively import or link this entire repository. Specifications are authorities to read; tests and corpora are verification material; examples are references. The macOS CLI and tracked iOS app shell are separate producer consumers, not SDK runtime payloads or designated application templates.

Preserve the exact semantic source bindings declared by the baseline reference. Application-owned mappings, intent constraints, known-valid recognition, policy and resource scope must be explicit. Do not guess them from generic JSON differences. Optional diagnostics do not satisfy mandatory durable audit.

Keep development diagnostics internal and absent from release framework targets. Release consumers use ordinary imports and the extracted binary packages; public acceptance cannot depend on `@testable`, producer sources or undeclared runtime dependencies. Run focused source regressions and the relevant platform tests before claiming a behavior fixed. Final release builds require clean committed sources and externally retained archive, linkage, consumer and asset receipts.

Repository-owned material follows the Apache License, Version 2.0 in `LICENSE`, preserving James Daley's ownership. Commercial use is allowed. Retain attribution and mark changes so provenance stays intact. Do not relicense external authorities or third-party material. Keep build outputs, raw diagnostic bundles, private configuration and credentials outside version control and SDK assets.
