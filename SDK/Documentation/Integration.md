# iOS integration

Extract `Aeostara-iOS-SDK-0.1.0-rc.1.zip` into a caller-selected directory. Keep the `Package.swift`, both `Frameworks` entries, and documentation together. Verify `SHA256SUMS` before installing. In Xcode, add the extracted `Aeostara-iOS-SDK` as a local package and select the desired library product. No producer repository clone or source edits are required.

For an application-owned Swift package, use a relative local dependency:

```swift
.package(path: "../Aeostara-iOS-SDK")
```

Select Domain only with `.product(name: "AeostaraDomain", package: "Aeostara-iOS-SDK")`, or Services with `.product(name: "AeostaraServices", package: "Aeostara-iOS-SDK")`. The dependency identity follows the extracted directory name; the package display name is `AeostaraIOSSDK`. If you rename the directory, use its new identity consistently. The Services product includes both binary targets because binary targets do not declare target dependencies.

```swift
import AeostaraDomain
import AeostaraServices
```

Construct an application-owned `SemanticContext` with nine explicit dimensions, source-bearing mapping rules, intent constraints, recognized valid states, and applicable transition/fallback definitions. Supply real diagnostic chains for referenced evidence. JSON field names or a generic structural diff do not establish semantic meaning. Construct `NativeHealingEngine` with the platform's native resource adapter and explicitly registered policy. See the ordinary-import consumer composition in the coordinated examples asset; the platforms have independent constructor APIs.

Use an existing private application-owned resource root. Declare configuration, desired-state, backup, and audit resources before healing; choose a fresh backup destination for each operation. Own the service lifecycle. After terminal containment or halt, release the instance and require a new explicit application decision before further recovery.

Attach `try ReleaseDiagnosticRecorder()` when lean diagnostics are wanted. Run offline exports from an application-owned background context to an existing private directory. The exporter does not start networking or a worker service.

## SDK consumption boundary

Use only the named public SDK products and their declared dependency closure. Do not copy, vendor, submodule, recursively import, or link this entire repository into an application. Architecture/specification sources are authorities to read; tests and corpora are verification material; examples are references. Application templates, when explicitly designated, become application-owned code. These roles do not make the repository a runtime dependency. The macOS CLI is a separate executable. The iOS app shell is not the SDK and is not designated a production template. Package-manager source fetching alone is not whole-repository incorporation: actual product selection, linkage, resources, and source ownership determine the boundary.

The platform source tags are provenance refs. Do not substitute a conventional `.package(url: originalRepository, from: "0.1.0")` dependency for this tested binary-package route.
