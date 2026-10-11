# Compatibility

Candidate: `0.1.0-rc.1`. Minimum deployment target: iOS 16. Swift package tools: 5.9. Frameworks are dynamic and built with library evolution; that setting does not establish compatibility with every future compiler. Exact Xcode/Swift identity, SDK build versions, source commits and final architecture inspections are recorded in `SDK_MANIFEST.json` and the coordinated release manifest.

Required variants are iOS device arm64, and iOS Simulator arm64 plus toolchain-supported x86_64. Device and simulator are separate XCFramework variants. Cross-compilation is distinct from runtime execution. The release guide records which host/simulator executions passed. Minimum target preservation is not proof of execution on every older OS release.

Physical iPhone/iPad execution is not performed by this assignment. Intel runtime execution, Catalyst, visionOS, tvOS, watchOS, app extensions and arbitrary older compilers are not qualified. The SDK has no distribution signing identity: `signing: "unsigned"` records `CODE_SIGNING_ALLOWED=NO`. Simulator frameworks carry linker ad-hoc signatures; device frameworks are unsigned. No notarization, signed installer or installed application qualification is claimed. Services links its corresponding Domain module and Apple system frameworks recorded in the manifest; there is no third-party runtime dependency.

Compiler ABI descriptors retain their ABI declarations and constant values. Build-local constant source locations are normalized to repository-relative paths; payload inspection rejects machine-private home paths. No native declaration, interface or executable is replaced by this metadata normalization.
