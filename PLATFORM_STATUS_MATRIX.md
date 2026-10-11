# Platform Status Matrix — SDK 0.1.0-rc.1

| Branch | Product role | Observed qualification |
|---|---|---|
| `main` | Coordination and release metadata | Implementation-free; source and asset identities in [SDK_RELEASE.json](SDK_RELEASE.json) |
| `platform/macos` | macOS 13+ Domain and Services SDK | Source Debug125/125, Release124/124, CLI5/5; final binary Domain2/2, Services9/9; both universal app builds and arm64 host runtimes |
| `platform/ios` | iOS 16+ Domain and Services SDK | Source host129/129, iOS27 simulator Debug129/129, Release125/125; final binary Domain2/2, Services8/8; both universal simulator apps run and both generic device apps compile |

Source test receipts predate notice/format/tool/documentation-only revisions; exact final executable source was independently rebound without claiming a new full suite run. Final remote SDK artifacts were independently inspected, then new admitted consumers exercised their actual binary bytes. Four actual success/fault diagnostic pairs passed full JSON/Markdown/hash/private-mode/causal checks.

Executed runtime destinations: arm64 macOS27.0.1 and iOS27 iPhone18Pro simulator; compiler Xcode27.0 (27A266a), Swift compiler swiftlang-6.4.0.34.1-clang-2100.3.34.1. Intel execution, physical iOS execution, historical minimum OS runtime, sandbox/extension and application distribution qualification remain unverified. Prepared technical acceptance precedes separate tag, draft and published-download verification.
