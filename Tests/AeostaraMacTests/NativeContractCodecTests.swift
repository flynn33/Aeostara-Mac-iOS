import Foundation
import XCTest
import AeostaraMacDomain

/// Frozen source examples exercise DTO codec/schema shape only, never semantic outcomes.
final class NativeContractCodecTests: XCTestCase {
    private func check<T: ContractValue & Equatable>(_ type: T.Type, _ name: String) throws {
        let url = Bundle.module.url(forResource: name + ".example", withExtension: "json", subdirectory: "Fixtures/ContractExamples")!
        let data = try Data(contentsOf: url), raw = try JSONValue.parse(data)
        let value = try ContractCoding.canonicalDecode(type, from: data)
        let output = try ContractCoding.canonicalEncode(value)
        XCTAssertEqual(try JSONValue.parse(output), raw, name)
        XCTAssertEqual(try ContractCoding.canonicalDecode(type, from: output), value, name)
        if case .object(let fields) = raw {
            let extra = try JSONValue.object(fields + [JSONMember("unknownContractField", .bool(true))]).canonicalData()
            XCTAssertThrowsError(try ContractCoding.canonicalDecode(type, from: extra), name)
        }
        if let root = ProcessInfo.processInfo.environment["AEOSTARA_DTO_EVIDENCE_ROOT"] {
            try output.write(to: URL(fileURLWithPath: root).appendingPathComponent(name + ".json"), options: .withoutOverwriting)
        }
    }
    func testAll59FrozenDTOExamplesRoundTripStrictly() throws {
        try check(AeostaraContract.AdmissibilityResult.self, "AdmissibilityResult")
        try check(AeostaraContract.ArtifactEmissionPlan.self, "ArtifactEmissionPlan")
        try check(AeostaraContract.AshSemanticState.self, "AshSemanticState")
        try check(AeostaraContract.AshState.self, "AshState")
        try check(AeostaraContract.AuditChain.self, "AuditChain")
        try check(AeostaraContract.AuditEvent.self, "AuditEvent")
        try check(AeostaraContract.AxiomDiagnostic.self, "AxiomDiagnostic")
        try check(AeostaraContract.BackupRecord.self, "BackupRecord")
        try check(AeostaraContract.BackupResult.self, "BackupResult")
        try check(AeostaraContract.CanonicalCodewordSet.self, "CanonicalCodewordSet")
        try check(AeostaraContract.CodewordTransformation.self, "CodewordTransformation")
        try check(AeostaraContract.ContainmentDecision.self, "ContainmentDecision")
        try check(AeostaraContract.DesiredState.self, "DesiredState")
        try check(AeostaraContract.DesiredSystemIntent.self, "DesiredSystemIntent")
        try check(AeostaraContract.DiagnosticChain.self, "DiagnosticChain")
        try check(AeostaraContract.DiagnosticEnvelope.self, "DiagnosticEnvelope")
        try check(AeostaraContract.DiagnosticReference.self, "DiagnosticReference")
        try check(AeostaraContract.DriftEvent.self, "DriftEvent")
        try check(AeostaraContract.DryRunResult.self, "DryRunResult")
        try check(AeostaraContract.EncodedState.self, "EncodedState")
        try check(AeostaraContract.EscalationDecision.self, "EscalationDecision")
        try check(AeostaraContract.ExecutionContext.self, "ExecutionContext")
        try check(AeostaraContract.ExecutionStepResult.self, "ExecutionStepResult")
        try check(AeostaraContract.FallbackDecision.self, "FallbackDecision")
        try check(AeostaraContract.GenerationPlan.self, "GenerationPlan")
        try check(AeostaraContract.HealResult.self, "HealResult")
        try check(AeostaraContract.Invariant.self, "Invariant")
        try check(AeostaraContract.JsonCanonicalizationRule.self, "JsonCanonicalizationRule")
        try check(AeostaraContract.JsonDocumentReference.self, "JsonDocumentReference")
        try check(AeostaraContract.JsonMutationOperation.self, "JsonMutationOperation")
        try check(AeostaraContract.JsonPointer.self, "JsonPointer")
        try check(AeostaraContract.MappingAmbiguity.self, "MappingAmbiguity")
        try check(AeostaraContract.MappingResult.self, "MappingResult")
        try check(AeostaraContract.ModuleManifest.self, "ModuleManifest")
        try check(AeostaraContract.ObservedState.self, "ObservedState")
        try check(AeostaraContract.ObservedSystemState.self, "ObservedSystemState")
        try check(AeostaraContract.PolicyBundle.self, "PolicyBundle")
        try check(AeostaraContract.PolicyDecision.self, "PolicyDecision")
        try check(AeostaraContract.RealmIdentity.self, "RealmIdentity")
        try check(AeostaraContract.RecoveryCategory.self, "RecoveryCategory")
        try check(AeostaraContract.RecoveryOutcome.self, "RecoveryOutcome")
        try check(AeostaraContract.RecoveryPlan.self, "RecoveryPlan")
        try check(AeostaraContract.RecoveryStep.self, "RecoveryStep")
        try check(AeostaraContract.RepairAction.self, "RepairAction")
        try check(AeostaraContract.RepairPlan.self, "RepairPlan")
        try check(AeostaraContract.RollbackPlan.self, "RollbackPlan")
        try check(AeostaraContract.RollbackResult.self, "RollbackResult")
        try check(AeostaraContract.RuleReference.self, "RuleReference")
        try check(AeostaraContract.SafeHaltDecision.self, "SafeHaltDecision")
        try check(AeostaraContract.SemanticDimensionBinding.self, "SemanticDimensionBinding")
        try check(AeostaraContract.SemanticProjectionSpec.self, "SemanticProjectionSpec")
        try check(AeostaraContract.StateValidityDiagnostic.self, "StateValidityDiagnostic")
        try check(AeostaraContract.SurfaceDifference.self, "SurfaceDifference")
        try check(AeostaraContract.SystemStateClass.self, "SystemStateClass")
        try check(AeostaraContract.TopologyPlan.self, "TopologyPlan")
        try check(AeostaraContract.TransitionDefinition.self, "TransitionDefinition")
        try check(AeostaraContract.TransitionResult.self, "TransitionResult")
        try check(AeostaraContract.VerificationPlan.self, "VerificationPlan")
        try check(AeostaraContract.VerificationResult.self, "VerificationResult")
    }
}
