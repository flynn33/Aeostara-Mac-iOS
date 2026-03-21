# Aeostara / ASH / Forsetti Boundaries

## Aeostara (Product)

Aeostara is the product. It owns:
- Customer-facing behavior
- Contracts (11 data types)
- Config adapters (JSON for v0.1)
- Policy evaluation
- Repair planning
- Verification and rollback
- Audit trail
- Packaging and distribution model

## ASH Pattern System (Healing Kernel)

ASH provides the healing semantics. It owns:
- Encoded state model
- Drift distance semantics
- Correction concepts
- Confidence semantics (future)
- Pattern reasoning (future)
- Self-modeling concepts (future)

Aeostara v0.1 is ASH-inspired. Full ASH encoded-state mechanics are not yet implemented.

## Forsetti Framework (Host/Runtime)

Forsetti is the host/runtime framework. It owns:
- Runtime shell and lifecycle
- Module packaging
- Plugin system
- Entitlement
- UI composition
- Host services

## Non-Negotiable Boundary Rules

1. Aeostara Core stays host-agnostic
2. ASH stays framework-agnostic
3. Forsetti integration is explicit and interface-based
4. No core healing module may directly depend on UI code
5. Platform branch separation must not contaminate shared core boundaries
