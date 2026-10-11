# Apple SDK platform policy — macOS 0.1.0-rc.1

This supplement applies to the native producer branch and preserves the root conformance rules. It does not select a Forsetti runtime. The exact base/ASH authorities in `Docs/NATIVE_BASELINE.md` control semantic behavior. `Docs/Conformance_Trace.md` maps current symbols and test evidence.

1. Production logic remains native Swift with Apple system frameworks (Foundation, CryptoKit and native Darwin services where required). No third-party or interpreted runtime is authorized. Source build/export automation under `Tools/SDK` and `ci` is outside runtime distribution.
2. Domain has no UI, Services, CLI or app dependency. Services depends only on its native Domain and required Apple frameworks. Concrete implementations use cohesive final classes, constructor injection, immutable contracts and explicit instance lifecycle.
3. The SDK requires explicit source-bearing semantic context, registered policies and application-owned resource scope. No directory discovery, guessed valid state or context-free structural healing is authorized.
4. Mutation requires provided-policy evaluation, durable mandatory audit, verified exclusive backup, bounded execution, actual postcondition verification, truthful exact restoration and source-defined fallback/containment/halt. Optional diagnostics never stand in for audit.
5. Canonical identity uses SHA-256 and raw UTF-8 JSON key/pointer/type semantics. Historical FNV identifiers remain legacy compatibility APIs and do not define frozen contract hashes.
6. Rich development diagnostics depend only on Domain and are absent from release frameworks/products. The Services lean recorder/exporter uses validated bounds and private caller-owned publication.
7. Release packaging is an explicit allowlist: named frameworks, relative binary manifest, current SDK documentation and license only. Tests, corpora, specifications, private data, CLI/app, quarantine and raw logs remain excluded.
8. Minimum macOS 13.0; Swift tools 5.9. Exact toolchain, built slices and actual runtime execution are recorded separately. Compilation does not establish device or older-OS runtime qualification.
9. First-party current code uses `Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.` Preserve external and third-party ownership and license notices.
