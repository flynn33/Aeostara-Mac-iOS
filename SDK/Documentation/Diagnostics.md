# Diagnostics

The source development target provides a rich recorder for engineering investigation. It depends only on `AeostaraMacDomain` and does not ship. The release frameworks expose the lean `ReleaseDiagnosticRecorder` and offline `DiagnosticExporter`; the lean path never invokes development-detail suppliers or captures rich stacks. A disabled development capture also skips detail suppliers and stack capture.

| Profile | Events | Bytes per event | Retained bytes | Retention |
|---|---:|---:|---:|---|
| Internal development | 4096 | 32768 | 16 MiB | 24 hours |
| Shipped lean release | 512 | 4096 | 1 MiB | 24 hours |

Callers may lower or disable these validated limits. These are recorder retention bounds, not a process-memory promise: encoded export buffers, allocator/runtime overhead and caller-retained immutable snapshots also consume memory. One export lease per recorder limits concurrent snapshot/export work. Health counters report dropped, oversized, expired, invalid and failed export evidence. Successful/no-action routine records are evicted before retained failures or policy/containment evidence when possible; causal references lost through eviction are counted.

Events use closed enums, bounded numeric metrics and UUID correlation. Do not pass raw configuration, credentials, filesystem paths, arbitrary messages or error descriptions. Error adaptation preserves only allowlisted domains and numeric codes. Rich fault stacks retain only recognized image offsets; unavailable provenance or stacks are explicit. The SDK reads source/toolchain metadata only from its own identified Domain framework. Source-package or foreign-framework metadata cannot masquerade as SDK provenance.

An export freezes one immutable envelope and produces the complete JSON plus readable Markdown, including the complete JSON appendix and one detail block for every retained event. The completion metadata records actual byte counts and SHA-256 hashes. Both artifacts share event, incident, timeline and health information. Export is offline and headless; the caller selects a background execution context and existing private destination.

The exporter stages privately (directory 0700, files 0600), syncs staged files and directory, and publishes through native exclusive rename. It verifies staged and published inode identities. Collisions or replaced staging names cannot overwrite another bundle or turn a caller-created replacement into success. Cleanup removes only files/directories whose identities the exporter owns. A structured failure records the stage, native code and incomplete-publication/cleanup state without replacing the original runtime incident. Preserve failed-export evidence and choose a new private output root before retrying when cleanup remains incomplete.
