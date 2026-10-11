# Native iOS conformance trace

This trace describes the native source realization and its exercised tests. SDK archive, extracted consumer, device compilation, publication, and release qualification are separate records in the release conformance document. Schema round trips establish codec shape; they do not establish healing behavior.

Authority is pinned to [Aeostara base 774b981](https://github.com/flynn33/aeostara/tree/774b981ef2267a41c1b1a59497b2b0746a86f32b) and [ASH e123f5d](https://github.com/flynn33/ASH-Pattern-System/tree/e123f5d7fdbb381179971f721a3292c31eb1cbc2). RFD compatibility is pinned to `8dd6e75a06336491b249fac3577db75458db8c13`, v0.7.0. ASH owns the mathematical codewords, orbit, diagnostic rules, classifications, recoverability, and fallback ordering. The base frozen JSON contracts own serialized fields and enums. Native mechanics implement the explicit app-owned boundary.

## Canonical data and projection

| Pinned source and section | Native owning symbol | Exercised test |
| --- | --- | --- |
| base `specs/algorithms/json_canonicalization.pseudo.md`, Deterministic Ordering and Tie-Breaking; `json_pointer_resolution.pseudo.md` | `CanonicalJSON`, `JSONValue`, `JSONMember`, `JSONPointer` in `Sources/AeostaraDomain/CanonicalJSON.swift` | `NativeSemanticSliceTests.testByteDistinctUnicodeMembersAndPointerIdentity`, `testCanonicalNumberAndBooleanIdentity`; `NativeContractCodecTests.testFreeJSONFieldsPreserveUnicodeIdentityAndRejectDuplicateAndUnknownMembers`, `testPointerMutationRetainsEmptyContainersRootAndArrayOrder` |
| base `specs/contracts/*.schema.json`, exact 59 titles; integer schema admission | `AeostaraContract` immutable DTOs in `ContractModels.swift`; `ContractCoding`; exact unbounded `JSONInteger` for `AuditEvent.eventSequence` | `NativeContractCodecTests.testAllFiftyNineFrozenDTOsRoundTripCanonicalData`, `testSchemaIntegerDecimalsAndUnboundedAuditSequenceArePreserved`, `testLexicalIntegerAdmissionNeverRoundsDecimalOrExponentTokens`; ordinary public 2,697-input schema admission corpus and exact-token precision probes |
| base `specs/algorithms/semantic_projection.pseudo.md`, missing/malformed/ambiguous evidence; `specs/interfaces/ISemanticProjector.pseudo.md` | `SemanticContext`, `MappingRuleRegistry`, `NativeSemanticProjector.project` in `SemanticProjection.swift` | `NativeSemanticSliceTests.testMissingEvidenceReturnsTruthfulDiagnosticFailure`, `testUnknownMappingRuleFailsClosed`, `testEqualDocumentsCanBeSemanticallyIncompatible` |
| base `specs/algorithms/ash_diagnostic_evaluation.pseudo.md`; ASH `specs/core/state-validity-diagnostics.pseudo.md` | `NativeHealingEngine.prepareNative`, `NativeAshBindingProvider.diagnose`, `diagnosticEvidence` | `NativeSemanticSliceTests.testSurfaceDifferenceDoesNotAuthorizeRecovery`, `testCompatibleNormalizationUsesCanonicalCodeword`; actual native success and injected mapping-failure paired exports |
| base `specs/algorithms/diagnostic_chain_integrity.pseudo.md`, earlier parent/root/rule resolution | `SemanticContext.inputDiagnosticChains`, `NativeDiagnosticRegistry.resolve`, `NativeAshBindingProvider.diagnosticRegistry`, `SemanticLedger` | `NativeAshOperationsTests.testPublicDiagnosticRegistryRejectsOrphansAndPreservesDistinctImmutableChains`; ordinary public ASH provenance recheck |

`ContractCoding.canonicalEncode/canonicalDecode` are the exact public canonical boundary. Ordered member names compare decoded UTF-8 bytes: literal `a` and escaped `\u0061` are duplicates; composed and decomposed Unicode spellings remain distinct. Arbitrary integer tokens retain every decimal digit. Decimal/exponent tokens are retained as `JSONNumber.decimal` before binary floating-point conversion; exact coefficient/exponent arithmetic admits only mathematically integral integer DTO inputs. This preserves values beyond Double precision and rejects fractions that Double rounds to an integer. General free JSON keeps its real/decimal category and exact retained value. Programmatic `real(Double)` remains supported only for finite values. Exponents outside native Int and expanded integer outputs above the 16 MiB native output bound fail explicitly; these resource limits are not schema constraints. Foundation `JSONEncoder/JSONDecoder` convenience cannot promise arbitrary member identity or unbounded integer parity and must not replace the canonical codec in hashes or lifecycle inputs.

The caller supplies immutable, application-bound projection rules, pointers, intent constraints, known-valid states, and actual input diagnostic chains. Registered mapping callbacks produce candidate bits and inverse operations; the SDK validates their outputs and derives classifications and write eligibility. Callbacks must honor their declared pure semantics. Missing semantic context on the legacy `HealingEngine` entrypoints produces a typed failure. The legacy adapter delegates complete native recovery when explicit context, policies, scoped resources, and native I/O are supplied.

Full intent means all declared intent constraints, including the nine registered bindings used by the consumer examples. Unbound display fields remain surface evidence. Materialized target hashes and post-execution resource verification are exact; surface differences alone do not authorize recovery.

Optional lifecycle diagnostics carry the actual retained preparation plan event into policy as an explicit cause and parent operation. Verification and fallback preparation are child operations, and their actual terminal retained events become causes of the enclosing execution outcome. A shared incident persists through rollback, fallback, containment, and halt; blocked and malformed policy paths emit their actual outcomes. The release profile retains the plan anchor while earlier routine preparation remains sampled. `NativeExecutionTests.testNativeDiagnosticFaultRecoveryKeepsIncidentAndActualCausalLinks`, `testNativeDiagnosticPolicyDenialRetainsActualPlanningCause`, and `testNativeDiagnosticMalformedPolicyRetainsActualPlanningCause` exercise both profiles and stale-independent mandatory behavior. Actual ordinary-import success, verification-fault/rollback/halt, and denial exports are separately retained with complete JSON/Markdown parity and metadata hashes. Mandatory audit failures during recovery and control emit their actual `.audit` fault and retain the initiating fault and restrictions. Fallback reports the actual failed policy, audit, backup, mutation, or verification stage. `testLateRecoveryAuditFailuresKeepActualStageAndOriginalVerificationFault`, `testFallbackDiagnosticsNameActualBackupAuditAndMutationFailures`, `testOperatorAuditFaultDiagnosticsFollowActualControlDecision`, and `testRejectedContainedMutationAuditFaultIsChainedToTerminalDecision` exercise both diagnostic profiles and original-byte preservation.

## Full public ASH interface

All ten frozen `AeostaraContract.IAshBindingProvider` operations are native in `AshOperations.swift`. Its provider keeps completed diagnostic chains as immutable values scoped to that provider. `diagnosticRegistry()` returns an immutable snapshot; a recipient provider can receive that snapshot explicitly for handoff. Every reference is resolved against actual input or issued chains with exact root, identity, kind, and rules. Operation/evidence content addresses distinguish different operations and preserve equal-request planning. No missing reference creates a replacement record.

| Public operation | Pinned source section or rule | Native implementation and actual test |
| --- | --- | --- |
| `evaluateAdmissibility` | ASH `core/state-admissibility.pseudo.md`; `ASH-ADMISSIBILITY-CLASSIFICATION-001` | `NativeAshBindingProvider.evaluateAdmissibility`, `diagnose`; `NativeAshOperationsTests.testAllTenPublicOperationsAndAveragingUseActualCanonicalEvidence` |
| `diagnoseState` | ASH `core/state-validity-diagnostics.pseudo.md`; `ASH-STATE-VALIDITY-001` | `diagnoseState`, `diagnosticEvidence`; same full-interface test and `testKnownCorrectionEvidenceAndFallbackOrderingAreSourceDerived` |
| `classifyState` | ASH `core/system-state-classification.pseudo.md`; `ASH-CLASSIFICATION-MAPPING-001` | `classifyState`, exact SDK diagnosis recomputation; `testUnclassifiedDefaultAndForgedDiagnosisAreDistinguished` |
| `applyCodewordTransformation` | ASH `core/codeword-set.pseudo.md`; `algorithms/transition-system.pseudo.md`, apply_codeword_transition | `applyCodewordTransformation`, full-nine `xor`; full-interface test and `testPublicDiagnosticRegistryRejectsOrphansAndPreservesDistinctImmutableChains` |
| `resolveRealmIdentity` | ASH `core/realm-identity.pseudo.md`, injective full-nine encoding | `resolveRealmIdentity`; full-interface test, invalid-state rejection in `testMissingGenerationSubjectInvalidCodewordAndNonfiniteAverageFailClosed` |
| `resolveTransition` | ASH `algorithms/transition-system.pseudo.md`, apply_transition | exact immutable registered definition and preconditions; full-interface test |
| `generateTopology` | ASH `algorithms/topology-expansion.pseudo.md`, generate_topology and Determinism rule | explicit `NativeTopologyRequest`, ternary `topology`; full-interface test and `testDepthZeroCannotFabricateAnEdgeToSatisfyFrozenTopologyContract` |
| `evaluateAxioms` | ASH `algorithms/axiom-evaluation.pseudo.md`, diagnose_axioms and Contract rule | explicit `NativeAxiomSubject`, all five `axioms` predicates and notes; full-interface test and `testFailedAxiomsPreserveAllFiveChecksAndNotes` |
| `generateMaterializationPlan` | ASH `algorithms/generation-planning.pseudo.md`, generate_plan and Required invariants | explicit registered roles, naming, descriptions, transitions, measured subject, complete semantic inputs; full-interface test asserts repeated complete canonical plans match |
| `planArtifactEmission` | ASH `algorithms/generation-planning.pseudo.md`, Materialization boundary; base artifact emission interface | `generationLedger`, complete semantic-input/artifact identity bound to its exact issued reference and immutable chain, realm state/encoding and axiom-envelope coherence; full-interface test proves recipient handoff and no planner callbacks; `testEmissionRejectsRehashedSemanticTamperingWithIssuedReferences` rejects rehashed topology, axiom, realm and artifact substitution |

`NativeAshBindingProvider.average` implements the ASH `algorithms/averaging-operator-semantics.pseudo.md` full-codeword-set mean. The full-interface test exercises invariance and idempotence; nonfinite callback results fail closed. `NativeSemanticSliceTests.testExhaustiveCanonicalCodewordOrbits` exercises all 512 nine-bit states with the exact 16 canonical [9,4,4] codewords.

Initial CORRECTABLE requires an actual registered applicable transition and precondition proof. Mathematical compatibility without that proof is UNSTABLE and permits deterministic codeword normalization. Policy denial remains a later policy failure. Fallback uses ASH `registries/fallback-policy-registry.md` ordering rank, then UTF-8 policy ID. Equal-cost admissible recovery targets use the base canonical-byte tie rule after explicit intent filtering.

## Complete recovery and native safety

| Pinned source and obligation | Native owning symbol | Exercised test |
| --- | --- | --- |
| base `specs/algorithms/healing_flow.pseudo.md`, ordered diagnosis/classification/category/planning; `IHealingEngine.pseudo.md` | `NativeHealingEngine.prepareNative`, `dryRun`, `heal`, `NativePreparedExecution` | semantic slice tests; `NativeExecutionTests.testPreparedTokenOwnershipReentrancyAndReplayAreRejected` |
| base `recovery_plan_generation.pseudo.md`, `recovery_step_generation.pseudo.md`, `recovery_plan_deterministic_identity.pseudo.md` | pure canonical target/materialization planning, plan hash excluding creation time | `NativeSemanticSliceTests.testCompatibleNormalizationUsesCanonicalCodeword`; surface/no-action tests |
| base policy gate and propagation boundaries | `NativePolicyRegistry.decide`, `prepareExecution`, `finishWithoutMutation` | `NativeExecutionTests.testPolicyBlockAndMalformedPolicyCannotCreateBackupOrMutate`; ordinary public consumer tests cover stable and drift denial |
| base mandatory audit and backup before mutation | `prepareExecution`; `ScopedResourceIO.audit`, `backup` | `testAuditAndBackupFailuresFailClosedBeforeFirstMutation`, `testStalePreparedStateAndBackupCollisionAreRejected`, `testActualNativeHealPreservesCosmeticEvidenceAndVerifiesFullTarget` |
| explicit app-root scope, resource ownership, aliases and concurrent calls | `ScopedResourceIO.validateRoot`, `validateParent`, `validateLocks`, native advisory leases, inode-checked publication/cleanup | `testTwoRealAdapterInstancesAndSymlinkAliasContendOnSameLease`, `testHardlinkOutsideSymlinkAndPathIdentityCollisionAreRejected`, `testReplacedLockNamespaceOrNamedLockInvalidatesOldLeaseBeforeAnyAuthorizedIO`; `NativeSafetyRegressionTests` root/parent/configuration/staging replacement tests |
| exact live preconditions and immutable prepared ownership | `NativeHealingEngine.execute`, `NativePreparedExecution.claim` | `testStaleConfigurationAfterTokenPreservesCallerBytesWithoutRollback`, token ownership/replay tests |
| base verification before success; ASH recovery postdiagnosis VALID/STABLE | native complete-document/hash/semantic verification | `testActualNativeHealPreservesCosmeticEvidenceAndVerifiesFullTarget`, `testPartialWriteAndVerificationFailureRestoreExactBackup` |
| base rollback integrity and original fault preservation | exact backup restoration/reread; truthful rollback receipt | `testPartialWriteAndVerificationFailureRestoreExactBackup`, `testFailedRollbackNeverClaimsRestoredAndSafeHaltIsTerminal` |
| ASH `algorithms/recovery-fallback-semantics.pseudo.md`, fallback selection and revalidation | `attemptFallback`, fresh policy/audit/backup/verification | `testRegisteredFallbackUsesFreshBackupAndRevalidatesStableAfterOriginalFailure`, `testMalformedResourceAfterFailedWriteAndRollbackStillHaltsWithOriginalFailure` |
| ASH `algorithms/containment-safe-failure-semantics.pseudo.md`, triggers, invariants and diagnostic chaining | `requestContainment`, `rejectContainedMutation`, `enterContainment`, `enterSafeHalt`, durable operator-control audit | `testContainmentInvalidatesEarlierPreparedPlanBeforeExecution`, `testContainmentBreachRecordsTerminalChain`, `testPublicContainmentAndHaltPersistActualNativeAuditBeforeSuccess`, `testOperatorAuditFailureCannotReturnControlSuccessOrRelaxRestriction`, `testUnreadableContainmentBoundaryAfterFailedRollbackEntersTerminalHalt` |
| diagnostic capture/export remains independent of mandatory audit and recovery | optional `DiagnosticRecording`; release collector, development-only collector, paired exporter | `NativeSliceDiagnosticIntegrationTests`; `DiagnosticTests` paired parity, privacy, bounds, retention, expiry, concurrency, collisions, partial export and staging substitution cases |

Advisory leases coordinate cooperating SDK instances. Native guards reject replaced roots, parents, lock namespaces, named locks, configuration identities, and staged names before publication. They do not make arbitrary external namespace changes transactional across an operating-system rename. Root ownership and private directory permissions are required; SDK cleanup removes only its own still-matching inode.

## Frozen-source conflicts and boundaries

* The base first canonical-codeword example contains the first sixteen binary integers. That example is preserved as a static codec fixture, and rejected for runtime ASH use. Runtime mathematics uses the pinned ASH [9,4,4] enumeration.
* Sparse base projection vectors reuse identical empty documents with different expected outcomes and omit required projection evidence. Tests supplement explicit schema-valid app-owned bindings and known-valid contexts; runtime does not dispatch by fixture ID, category, or expected result.
* A malformed sparse UNCLASSIFIED fixture expects FAILED/escalation; ASH's actual UNCLASSIFIED classifier default is DEGRADED. Malformed input is rejected before successful classification. A genuinely registered UNCLASSIFIED diagnostic retains the exact default; changing an issued VALID envelope's status is rejected.
* ASH topology depth zero produces one root and zero edges. Frozen base `TopologyPlan.edges` requires at least one item. The public bridge fails with a diagnostic-bearing error for depth zero and does not invent an edge. Depths one through eight are representable by this boundary.
* The iOS minimum is 16. Native simulator execution was exercised on the installed iOS 27 runtime; that does not establish runtime execution on an unavailable iOS 16 simulator.
* Ordinary source tests are run with testability enabled. Distribution archives and fresh extracted framework consumer checks establish their own module/interface/build settings in release evidence.

## Static codec inventory

Each entry is a real frozen base title represented by `AeostaraContract.<title>` in `ContractModels.swift` and exercised by `NativeContractCodecTests.testAllFiftyNineFrozenDTOsRoundTripCanonicalData`. Static codec coverage is separate from the runtime operation and recovery traces above.

| Frozen schema | Native immutable type |
| --- | --- |
| `AdmissibilityResult.schema.json` | `AeostaraContract.AdmissibilityResult` |
| `ArtifactEmissionPlan.schema.json` | `AeostaraContract.ArtifactEmissionPlan` |
| `AshSemanticState.schema.json` | `AeostaraContract.AshSemanticState` |
| `AshState.schema.json` | `AeostaraContract.AshState` |
| `AuditChain.schema.json` | `AeostaraContract.AuditChain` |
| `AuditEvent.schema.json` | `AeostaraContract.AuditEvent` |
| `AxiomDiagnostic.schema.json` | `AeostaraContract.AxiomDiagnostic` |
| `BackupRecord.schema.json` | `AeostaraContract.BackupRecord` |
| `BackupResult.schema.json` | `AeostaraContract.BackupResult` |
| `CanonicalCodewordSet.schema.json` | `AeostaraContract.CanonicalCodewordSet` |
| `CodewordTransformation.schema.json` | `AeostaraContract.CodewordTransformation` |
| `ContainmentDecision.schema.json` | `AeostaraContract.ContainmentDecision` |
| `DesiredState.schema.json` | `AeostaraContract.DesiredState` |
| `DesiredSystemIntent.schema.json` | `AeostaraContract.DesiredSystemIntent` |
| `DiagnosticChain.schema.json` | `AeostaraContract.DiagnosticChain` |
| `DiagnosticEnvelope.schema.json` | `AeostaraContract.DiagnosticEnvelope` |
| `DiagnosticReference.schema.json` | `AeostaraContract.DiagnosticReference` |
| `DriftEvent.schema.json` | `AeostaraContract.DriftEvent` |
| `DryRunResult.schema.json` | `AeostaraContract.DryRunResult` |
| `EncodedState.schema.json` | `AeostaraContract.EncodedState` |
| `EscalationDecision.schema.json` | `AeostaraContract.EscalationDecision` |
| `ExecutionContext.schema.json` | `AeostaraContract.ExecutionContext` |
| `ExecutionStepResult.schema.json` | `AeostaraContract.ExecutionStepResult` |
| `FallbackDecision.schema.json` | `AeostaraContract.FallbackDecision` |
| `GenerationPlan.schema.json` | `AeostaraContract.GenerationPlan` |
| `HealResult.schema.json` | `AeostaraContract.HealResult` |
| `Invariant.schema.json` | `AeostaraContract.Invariant` |
| `JsonCanonicalizationRule.schema.json` | `AeostaraContract.JsonCanonicalizationRule` |
| `JsonDocumentReference.schema.json` | `AeostaraContract.JsonDocumentReference` |
| `JsonMutationOperation.schema.json` | `AeostaraContract.JsonMutationOperation` |
| `JsonPointer.schema.json` | `AeostaraContract.JsonPointer` |
| `MappingAmbiguity.schema.json` | `AeostaraContract.MappingAmbiguity` |
| `MappingResult.schema.json` | `AeostaraContract.MappingResult` |
| `ModuleManifest.schema.json` | `AeostaraContract.ModuleManifest` |
| `ObservedState.schema.json` | `AeostaraContract.ObservedState` |
| `ObservedSystemState.schema.json` | `AeostaraContract.ObservedSystemState` |
| `PolicyBundle.schema.json` | `AeostaraContract.PolicyBundle` |
| `PolicyDecision.schema.json` | `AeostaraContract.PolicyDecision` |
| `RealmIdentity.schema.json` | `AeostaraContract.RealmIdentity` |
| `RecoveryCategory.schema.json` | `AeostaraContract.RecoveryCategory` |
| `RecoveryOutcome.schema.json` | `AeostaraContract.RecoveryOutcome` |
| `RecoveryPlan.schema.json` | `AeostaraContract.RecoveryPlan` |
| `RecoveryStep.schema.json` | `AeostaraContract.RecoveryStep` |
| `RepairAction.schema.json` | `AeostaraContract.RepairAction` |
| `RepairPlan.schema.json` | `AeostaraContract.RepairPlan` |
| `RollbackPlan.schema.json` | `AeostaraContract.RollbackPlan` |
| `RollbackResult.schema.json` | `AeostaraContract.RollbackResult` |
| `RuleReference.schema.json` | `AeostaraContract.RuleReference` |
| `SafeHaltDecision.schema.json` | `AeostaraContract.SafeHaltDecision` |
| `SemanticDimensionBinding.schema.json` | `AeostaraContract.SemanticDimensionBinding` |
| `SemanticProjectionSpec.schema.json` | `AeostaraContract.SemanticProjectionSpec` |
| `StateValidityDiagnostic.schema.json` | `AeostaraContract.StateValidityDiagnostic` |
| `SurfaceDifference.schema.json` | `AeostaraContract.SurfaceDifference` |
| `SystemStateClass.schema.json` | `AeostaraContract.SystemStateClass` |
| `TopologyPlan.schema.json` | `AeostaraContract.TopologyPlan` |
| `TransitionDefinition.schema.json` | `AeostaraContract.TransitionDefinition` |
| `TransitionResult.schema.json` | `AeostaraContract.TransitionResult` |
| `VerificationPlan.schema.json` | `AeostaraContract.VerificationPlan` |
| `VerificationResult.schema.json` | `AeostaraContract.VerificationResult` |
