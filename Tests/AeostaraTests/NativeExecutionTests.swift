import Foundation
import XCTest
import AeostaraDomain
import AeostaraServices
import AeostaraDevelopmentDiagnostics

private final class RuntimeFixture {
    let root: URL
    let resources: NativeResourceSet
    let io: ScopedResourceIO
    let observed: JSONValue
    let desired = NativeSliceContext.document()
    init(bits: [Int] = [1,1,1,1,0,0,0,0,0]) throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("native-runtime-"+UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:false,attributes:[.posixPermissions:0o700])
        let backup = root.appendingPathComponent("backups",isDirectory:true)
        try FileManager.default.createDirectory(at:backup,withIntermediateDirectories:false,attributes:[.posixPermissions:0o700])
        resources = try NativeResourceSet(configuration:root.appendingPathComponent("configuration.json").path,desired:root.appendingPathComponent("desired.json").path,audit:root.appendingPathComponent("audit.jsonl").path,backupDirectory:backup.path)
        observed = NativeSliceContext.document(bits,cosmetic:"original display")
        try CanonicalJSON.encode(observed).write(to:URL(fileURLWithPath:resources.configuration))
        try CanonicalJSON.encode(desired).write(to:URL(fileURLWithPath:resources.desired))
        io = try ScopedResourceIO(rootURL:root)
    }
    deinit { try? FileManager.default.removeItem(at:root) }
    func policy(effect: String = "ALLOW") throws -> AeostaraContract.PolicyBundle {
        let rules: [JSONValue] = [.object([JSONMember("policyID",.string("APP-SCOPE-POLICY-V1")),JSONMember("predicateID",.string("APP-SCOPE-MUTATION-V1")),JSONMember("effect",.string(effect))])]
        let value = JSONValue.object([JSONMember("policyBundleID",.string("synthetic-policy")),JSONMember("sourceReferences",.array([.string("synthetic-native-policy-v1")])),JSONMember("rules",.array(rules))])
        return try .init(policyBundleID:"synthetic-policy",sourceReferences:["synthetic-native-policy-v1"],rules:rules,bundleHash:CanonicalJSON.hash(value))
    }
    func policies() throws -> NativePolicyRegistry {
        let expected = resources.configuration
        return try .init(predicates:[
            RegisteredPolicyPredicate(identifier:"APP-SCOPE-MUTATION-V1",sourceReferences:["synthetic-native-policy-v1"],evaluate:{ input in
                input.resources?.configuration == expected && input.plan.recoverySteps.flatMap(\.jsonMutationOperations).allSatisfy { $0.path.pointer.hasPrefix("/signals/s") }
            }),
            RegisteredPolicyPredicate(identifier:"APP-PROPAGATION-BOUNDARY-V1",sourceReferences:["synthetic-native-propagation-v1"],evaluate:{ input in
                input.resources?.configuration == expected && input.plan.recoverySteps.flatMap(\.jsonMutationOperations).allSatisfy { $0.path.tokens.count == 2 && $0.path.tokens[0] == "signals" }
            })],propagationRiskPolicyID:"APP-PROPAGATION-BOUNDARY-V1")
    }
    func engine(io supplied: (any SemanticResourceIO)? = nil, context: SemanticContext? = nil, containment: Bool = false, identifier: @escaping () -> String = { UUID().uuidString }, recorder: (any DiagnosticRecording)? = nil) throws -> NativeHealingEngine {
        let policy = containment ? try NativeContainmentPolicy(policyID:"APP-CONTAINMENT-V1",sourceReferences:["synthetic-safe-operation-subset-v1"],allowedOperations:["observe","diagnose","export"],resources:resources) : nil
        return NativeHealingEngine(context:try context ?? NativeSliceContext.make(),timestampProvider:{"2026-10-11T00:00:00Z"},recorder:recorder,resourceIO:supplied ?? io,policies:try policies(),resources:resources,containmentPolicy:policy,identifierProvider:identifier)
    }
}
private final class FaultingIO: SemanticResourceIO {
    enum Mode { case audit,backup,partialMutation,verifyTamper,rollback,malformedAfterWrite,removedAfterWrite,lateAudit,fallbackBackup,fallbackAudit,fallbackWrite }
    let base: ScopedResourceIO
    let mode: Mode
    init(base: ScopedResourceIO,mode: Mode) { self.base = base;self.mode = mode }
    func read(path: String) throws -> Data { try base.read(path:path) }
    func acquire(resources: NativeResourceSet) throws -> any NativeResourceLease { FaultingLease(base:try base.acquire(resources:resources),io:base,mode:mode) }
}
private final class FaultingLease: NativeResourceLease {
    let base: any NativeResourceLease
    let io: ScopedResourceIO
    let mode: FaultingIO.Mode
    var writes = 0, auditCalls = 0, backupCalls = 0
    var tampered = false
    var resources: NativeResourceSet { base.resources }
    init(base: any NativeResourceLease,io: ScopedResourceIO,mode: FaultingIO.Mode) { self.base = base;self.io = io;self.mode = mode }
    func readConfiguration() throws -> Data { try base.readConfiguration() }
    func readDesired() throws -> Data { try base.readDesired() }
    func persistAudit(events: [AeostaraContract.AuditEvent]) throws {
        auditCalls += 1
        if mode == .audit || (mode == .lateAudit && auditCalls >= 4) || (mode == .fallbackAudit && auditCalls == 4) { throw ResourceIOFault.auditFailed }
        try base.persistAudit(events:events)
        if (mode == .verifyTamper || mode == .rollback || mode == .lateAudit), !tampered, events.contains(where:{$0.eventType == .EXECUTE}) {
            tampered = true
            try io.writeScoped(path:resources.configuration,bytes:CanonicalJSON.encode(NativeSliceContext.document([0,0,0,0,0,0,0,0,1])))
        }
    }
    func createBackup(bytes: Data,sourceHash: String,identifier: String) throws -> NativeBackupReceipt {
        backupCalls += 1
        if mode == .backup || (mode == .fallbackBackup && backupCalls == 2) { throw ResourceIOFault.backupFailed }
        return try base.createBackup(bytes:bytes,sourceHash:sourceHash,identifier:identifier)
    }
    func replaceConfiguration(bytes: Data,expectedBytesHash: String) throws {
        try base.replaceConfiguration(bytes:bytes,expectedBytesHash:expectedBytesHash);writes += 1
        if (mode == .partialMutation || mode == .fallbackBackup || mode == .fallbackAudit || mode == .fallbackWrite) && writes == 1 || mode == .fallbackWrite && writes == 2 { throw ResourceIOFault.writeFailed }
        if mode == .malformedAfterWrite && writes == 1 { try io.writeScoped(path:resources.configuration,bytes:Data("[".utf8));throw ResourceIOFault.writeFailed }
        if mode == .removedAfterWrite && writes == 1 { try FileManager.default.removeItem(atPath:resources.configuration);throw ResourceIOFault.writeFailed }
    }
    func restoreBackup(_ receipt: NativeBackupReceipt,expectedBytesHash: String) throws -> Data {
        if mode == .rollback || mode == .malformedAfterWrite || mode == .removedAfterWrite { throw ResourceIOFault.writeFailed }
        return try base.restoreBackup(receipt,expectedBytesHash:expectedBytesHash)
    }
    func release() { base.release() }
}
final class NativeExecutionTests: XCTestCase {
    func testLateRecoveryAuditFailuresKeepActualStageAndOriginalVerificationFault() throws {
        for recorder in [try ReleaseDiagnosticRecorder() as any DiagnosticRecording,try DevelopmentDiagnosticRecorder() as any DiagnosticRecording] {
            let fixture = try RuntimeFixture()
            let result = try fixture.engine(io:FaultingIO(base:fixture.io,mode:.lateAudit),recorder:recorder).heal(resources:fixture.resources,policyBundle:fixture.policy())
            XCTAssertEqual(result.originatingFailure,.verificationFailed);XCTAssertEqual(result.rollback?.status,.SUCCEEDED)
            XCTAssertEqual(result.result.status,.SAFE_HALT);XCTAssertFalse(result.auditPersisted)
            XCTAssertEqual(try fixture.io.read(path:fixture.resources.configuration),try CanonicalJSON.encode(fixture.observed))
            let records = recorder.snapshot().events.filter{$0.event.component == .domain}
            let original = try XCTUnwrap(records.first{$0.event.stage == .verify && $0.event.fault?.code == .verification})
            let audits = records.filter{$0.event.stage == .audit && $0.event.fault?.code == .audit}
            XCTAssertEqual(audits.count,2)
            for audit in audits { XCTAssertEqual(audit.event.outcome,.failed);XCTAssertEqual(audit.event.incidentID,original.event.incidentID);XCTAssertFalse(audit.event.causeEventIDs.isEmpty);XCTAssertTrue(audit.missingCauseEventIDs.isEmpty) }
            let rollback = try XCTUnwrap(records.first{$0.event.stage == .rollback})
            let halt = try XCTUnwrap(records.first{$0.event.stage == .safeHalt})
            XCTAssertEqual(audits.first?.event.causeEventIDs,[rollback.event.eventID])
            XCTAssertEqual(audits.last?.event.causeEventIDs,[halt.event.eventID])
        }
    }
    func testFallbackDiagnosticsNameActualBackupAuditAndMutationFailures() throws {
        let base = try NativeSliceContext.make(),predicate = try RegisteredStatePredicate(identifier:"APP-FALLBACK-STAGE",sourceReferences:["explicit-fallback-stage-evidence"],evaluate:{_,_ in true})
        let fallback = try FallbackPolicy(policyID:"FALLBACK-RECOVERY-001",applicabilityConditions:[predicate.identifier],candidateStateReference:base.knownValidStates.recognizedStates[0].stateID,orderingRank:0,validationRequirements:[predicate.identifier],escalationOnFailure:.ESCALATE_TO_CONTAINMENT,sourceReferences:["explicit-fallback-stage-evidence"])
        let context = try SemanticContext(applicationScopeID:base.applicationScopeID,projectionSpec:base.projectionSpec,intentConstraints:base.intentConstraints,knownValidStates:base.knownValidStates,mappingRules:base.mappingRules,transitions:base.transitions,predicates:PredicateRuleRegistry([predicate]),fallbackPolicies:FallbackPolicyRegistry([fallback]),inputDiagnosticChains:base.inputDiagnosticChains)
        for (mode,stage,fault) in [(FaultingIO.Mode.fallbackBackup,DiagnosticStage.backup,DiagnosticFaultCode.backup),(.fallbackAudit,.audit,.audit),(.fallbackWrite,.mutate,.execution)] {
            for recorder in [try ReleaseDiagnosticRecorder() as any DiagnosticRecording,try DevelopmentDiagnosticRecorder() as any DiagnosticRecording] {
                let fixture = try RuntimeFixture()
                let result = try fixture.engine(io:FaultingIO(base:fixture.io,mode:mode),context:context,recorder:recorder).heal(resources:fixture.resources,policyBundle:fixture.policy())
                XCTAssertEqual(result.originatingFailure,.executionFailed);XCTAssertEqual(result.rollback?.status,.SUCCEEDED);XCTAssertEqual(result.result.status,.SAFE_HALT)
                XCTAssertEqual(try fixture.io.read(path:fixture.resources.configuration),try CanonicalJSON.encode(fixture.observed))
                let events = recorder.snapshot().events.filter{$0.event.component == .domain}
                let failure = try XCTUnwrap(events.last{$0.event.stage == stage && $0.event.outcome == .failed})
                XCTAssertEqual(failure.event.fault?.code,fault);XCTAssertNotNil(failure.event.incidentID);XCTAssertFalse(failure.event.causeEventIDs.isEmpty);XCTAssertTrue(failure.missingCauseEventIDs.isEmpty)
                XCTAssertEqual(Set(events.compactMap{$0.event.incidentID}).count,1)
            }
        }
    }

    func testNativeDiagnosticFaultRecoveryKeepsIncidentAndActualCausalLinks() throws {
        for recorder in [try ReleaseDiagnosticRecorder() as any DiagnosticRecording,try DevelopmentDiagnosticRecorder() as any DiagnosticRecording] {
            let fixture = try RuntimeFixture()
            let engine = try fixture.engine(io:FaultingIO(base:fixture.io,mode:.verifyTamper),recorder:recorder)
            let result = try engine.heal(resources:fixture.resources,policyBundle:fixture.policy())
            XCTAssertEqual(result.originatingFailure,.verificationFailed)
            XCTAssertEqual(result.rollback?.status,.SUCCEEDED)
            XCTAssertEqual(result.result.status,.SAFE_HALT)
            XCTAssertEqual(try fixture.io.read(path:fixture.resources.configuration),try CanonicalJSON.encode(fixture.observed))
            let records = recorder.snapshot().events.filter{$0.event.component == .domain}
            let plan = try XCTUnwrap(records.first{$0.event.stage == .plan && $0.event.fault == nil})
            let policy = try XCTUnwrap(records.first{$0.event.stage == .policy && $0.event.outcome == .succeeded})
            XCTAssertNotNil(plan.event.incidentID)
            XCTAssertEqual(policy.event.parentOperationID,plan.event.operationID)
            XCTAssertTrue(policy.event.causeEventIDs.contains(plan.event.eventID))
            let fault = try XCTUnwrap(records.first{$0.event.stage == .verify && $0.event.outcome == .failed})
            let rollback = try XCTUnwrap(records.first{$0.event.stage == .rollback})
            let halt = try XCTUnwrap(records.first{$0.event.stage == .safeHalt})
            XCTAssertEqual(fault.event.incidentID,plan.event.incidentID)
            XCTAssertEqual(rollback.event.incidentID,fault.event.incidentID)
            XCTAssertEqual(halt.event.incidentID,fault.event.incidentID)
            XCTAssertFalse(halt.event.causeEventIDs.isEmpty)
            XCTAssertEqual(Set(records.compactMap{$0.event.incidentID}).count,1)
            var earlier = Set<UUID>(),operations = Set<UUID>()
            for record in records {
                XCTAssertTrue(record.event.causeEventIDs.allSatisfy{earlier.contains($0)})
                XCTAssertTrue(record.missingCauseEventIDs.isEmpty)
                if let parent = record.event.parentOperationID { XCTAssertTrue(operations.contains(parent));XCTAssertNil(record.parentUnavailable) }
                earlier.insert(record.event.eventID);operations.insert(record.event.operationID)
            }
        }
    }
    func testNativeDiagnosticPolicyDenialRetainsActualPlanningCause() throws {
        for bits in [[1,1,1,1,0,0,0,0,0],[Int](repeating:0,count:9)] {
            for recorder in [try ReleaseDiagnosticRecorder() as any DiagnosticRecording,try DevelopmentDiagnosticRecorder() as any DiagnosticRecording] {
                let fixture = try RuntimeFixture(bits:bits)
                let result = try fixture.engine(recorder:recorder).heal(resources:fixture.resources,policyBundle:fixture.policy(effect:"BLOCK"))
                XCTAssertEqual(result.result.status,.BLOCKED)
                let records = recorder.snapshot().events.filter{$0.event.component == .domain}
                let plan = try XCTUnwrap(records.first{$0.event.stage == .plan})
                let denied = try XCTUnwrap(records.first{$0.event.stage == .policy && $0.event.outcome == .blocked})
                XCTAssertEqual(denied.event.fault?.code,.policy)
                XCTAssertEqual(denied.event.incidentID,plan.event.incidentID)
                XCTAssertEqual(denied.event.parentOperationID,plan.event.operationID)
                XCTAssertTrue(denied.event.causeEventIDs.contains(plan.event.eventID))
                XCTAssertTrue(denied.missingCauseEventIDs.isEmpty)
            }
        }
    }
    func testNativeDiagnosticMalformedPolicyRetainsActualPlanningCause() throws {
        let fixture = try RuntimeFixture(), recorder = try ReleaseDiagnosticRecorder()
        let valid = try fixture.policy()
        let bad = try AeostaraContract.PolicyBundle(policyBundleID:valid.policyBundleID,sourceReferences:valid.sourceReferences,rules:valid.rules,bundleHash:"incorrect")
        XCTAssertThrowsError(try fixture.engine(recorder:recorder).heal(resources:fixture.resources,policyBundle:bad)) { XCTAssertEqual(($0 as? LifecycleFailure)?.code,.malformedContract) }
        let records = recorder.snapshot().events.filter{$0.event.component == .domain}
        let plan = try XCTUnwrap(records.first{$0.event.stage == .plan})
        let failure = try XCTUnwrap(records.first{$0.event.stage == .policy && $0.event.outcome == .failed})
        XCTAssertEqual(failure.event.incidentID,plan.event.incidentID)
        XCTAssertTrue(failure.event.causeEventIDs.contains(plan.event.eventID))
        XCTAssertTrue(failure.missingCauseEventIDs.isEmpty)
    }

    func testActualNativeHealPreservesCosmeticEvidenceAndVerifiesFullTarget() throws {
        let f = try RuntimeFixture(), e = try f.engine()
        let receipt = try e.heal(resources:f.resources,policyBundle:f.policy())
        XCTAssertEqual(receipt.result.status,.HEALED);XCTAssertEqual(receipt.verification?.status,.PASSED)
        XCTAssertEqual(receipt.backup?.status,.SUCCEEDED);XCTAssertTrue(receipt.auditPersisted)
        let result = try CanonicalJSON.parse(f.io.read(path:f.resources.configuration))
        XCTAssertEqual(result.member("display"),.string("original display"))
        XCTAssertEqual(result.member("signals"),f.desired.member("signals"))
        let original = try CanonicalJSON.parse(f.io.read(path:try XCTUnwrap(receipt.backup).backupRecord.storageReference))
        XCTAssertEqual(original,f.observed)
        let lines = try String(data:f.io.read(path:f.resources.audit),encoding:.utf8)!.split(separator:"\n")
        let events = try lines.map { try ContractCoding.canonicalDecode(AeostaraContract.AuditEvent.self,from:Data($0.utf8)) }
        XCTAssertEqual(events.map { $0.eventSequence.intValue },Array(1...events.count).map(Optional.init))
        XCTAssertTrue(events.contains(where:{$0.eventType == .BACKUP}));XCTAssertTrue(events.contains(where:{$0.eventType == .VERIFY}))
    }
    func testPolicyBlockAndMalformedPolicyCannotCreateBackupOrMutate() throws {
        let f = try RuntimeFixture(), e = try f.engine()
        XCTAssertEqual(try e.heal(resources:f.resources,policyBundle:f.policy(effect:"BLOCK")).result.status,.BLOCKED)
        XCTAssertEqual(try CanonicalJSON.parse(f.io.read(path:f.resources.configuration)),f.observed)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath:f.resources.backupDirectory).isEmpty)
        let valid = try f.policy(), malformed = try AeostaraContract.PolicyBundle(policyBundleID:valid.policyBundleID,sourceReferences:valid.sourceReferences,rules:valid.rules,bundleHash:"bad")
        XCTAssertThrowsError(try e.heal(resources:f.resources,policyBundle:malformed))
        XCTAssertEqual(try CanonicalJSON.parse(f.io.read(path:f.resources.configuration)),f.observed)
    }
    func testAuditAndBackupFailuresFailClosedBeforeFirstMutation() throws {
        for mode in [FaultingIO.Mode.audit,.backup] {
            let f = try RuntimeFixture(), e = try f.engine(io:FaultingIO(base:f.io,mode:mode))
            XCTAssertThrowsError(try e.heal(resources:f.resources,policyBundle:f.policy())) { XCTAssertEqual(($0 as? LifecycleFailure)?.code,mode == .audit ? .auditFailed : .backupFailed) }
            XCTAssertEqual(try CanonicalJSON.parse(f.io.read(path:f.resources.configuration)),f.observed)
        }
    }
    func testPartialWriteAndVerificationFailureRestoreExactBackup() throws {
        for mode in [FaultingIO.Mode.partialMutation,.verifyTamper] {
            let f = try RuntimeFixture(), original = try f.io.read(path:f.resources.configuration), e = try f.engine(io:FaultingIO(base:f.io,mode:mode),containment:true)
            let receipt = try e.heal(resources:f.resources,policyBundle:f.policy())
            XCTAssertEqual(receipt.rollback?.status,.SUCCEEDED);XCTAssertEqual(receipt.result.status,.ESCALATED)
            XCTAssertEqual(receipt.originatingFailure,mode == .partialMutation ? .executionFailed : .verificationFailed)
            XCTAssertEqual(try f.io.read(path:f.resources.configuration),original)
            XCTAssertNotNil(receipt.containment);XCTAssertNil(receipt.safeHalt)
        }
    }
    func testFailedRollbackNeverClaimsRestoredAndSafeHaltIsTerminal() throws {
        let f = try RuntimeFixture(), e = try f.engine(io:FaultingIO(base:f.io,mode:.rollback))
        let receipt = try e.heal(resources:f.resources,policyBundle:f.policy())
        XCTAssertEqual(receipt.result.status,.SAFE_HALT);XCTAssertNil(receipt.rollback)
        XCTAssertEqual(receipt.originatingFailure,.verificationFailed);XCTAssertNotNil(receipt.safeHalt)
        XCTAssertNotEqual(try CanonicalJSON.parse(f.io.read(path:f.resources.configuration)),f.observed)
        let before = try f.io.read(path:f.resources.configuration)
        XCTAssertThrowsError(try e.heal(resources:f.resources,policyBundle:f.policy())) { XCTAssertEqual(($0 as? LifecycleFailure)?.code,.terminalHalt) }
        XCTAssertThrowsError(try e.prepare(observed:f.observed,desired:f.desired))
        XCTAssertEqual(try f.io.read(path:f.resources.configuration),before)
    }
    func testMalformedResourceAfterFailedWriteAndRollbackStillHaltsWithOriginalFailure() throws {
        let f = try RuntimeFixture(),engine = try f.engine(io:FaultingIO(base:f.io,mode:.malformedAfterWrite))
        let result = try engine.heal(resources:f.resources,policyBundle:f.policy())
        XCTAssertEqual(result.result.status,.SAFE_HALT);XCTAssertEqual(result.originatingFailure,.executionFailed)
        XCTAssertNil(result.rollback);XCTAssertNotNil(result.safeHalt)
        XCTAssertEqual(try f.io.read(path:f.resources.configuration),Data("[".utf8))
        XCTAssertTrue(result.result.auditChain.events.contains(where:{$0.eventType == .FALLBACK}))
        XCTAssertThrowsError(try engine.prepare(observed:f.observed,desired:f.desired)) { XCTAssertEqual(($0 as? LifecycleFailure)?.code,.terminalHalt) }
    }
    func testUnreadableContainmentBoundaryAfterFailedRollbackEntersTerminalHalt() throws {
        let f = try RuntimeFixture(),engine = try f.engine(io:FaultingIO(base:f.io,mode:.removedAfterWrite),containment:true)
        let result = try engine.heal(resources:f.resources,policyBundle:f.policy())
        XCTAssertEqual(result.result.status,.SAFE_HALT);XCTAssertEqual(result.originatingFailure,.executionFailed)
        XCTAssertNil(result.rollback);XCTAssertNil(result.containment);XCTAssertNotNil(result.safeHalt)
        XCTAssertThrowsError(try engine.prepare(observed:f.observed,desired:f.desired)) { XCTAssertEqual(($0 as? LifecycleFailure)?.code,.terminalHalt) }
    }
    func testOperatorAuditFaultDiagnosticsFollowActualControlDecision() throws {
        for development in [false,true] {
            for halt in [false,true] {
                let recorder: any DiagnosticRecording = development ? try DevelopmentDiagnosticRecorder() : try ReleaseDiagnosticRecorder()
                let f = try RuntimeFixture(),engine = try f.engine(io:FaultingIO(base:f.io,mode:.audit),recorder:recorder)
                if halt {
                    XCTAssertThrowsError(try engine.enterSafeHalt(authority:NativeHaltAuthority(requestID:"operator-halt",sourceReferences:["explicit-request"]))) { XCTAssertEqual(($0 as? LifecycleFailure)?.code,.auditFailed) }
                } else {
                    XCTAssertThrowsError(try engine.requestContainment(policy:NativeContainmentPolicy(policyID:"APP-RESTRICT-V1",sourceReferences:["explicit-request"],allowedOperations:["observe","export"],resources:f.resources))) { XCTAssertEqual(($0 as? LifecycleFailure)?.code,.auditFailed) }
                }
                let records = recorder.snapshot().events
                let decision = try XCTUnwrap(records.first{$0.event.stage == (halt ? .safeHalt : .containment)})
                let fault = try XCTUnwrap(records.first{$0.event.stage == .audit && $0.event.outcome == .failed})
                XCTAssertEqual(fault.event.fault?.code,.audit)
                XCTAssertEqual(fault.event.operationID,decision.event.operationID)
                XCTAssertEqual(fault.event.incidentID,decision.event.incidentID)
                XCTAssertEqual(fault.event.causeEventIDs,[decision.event.eventID])
                XCTAssertEqual(try CanonicalJSON.parse(f.io.read(path:f.resources.configuration)),f.observed)
            }
        }
    }
    func testRejectedContainedMutationAuditFaultIsChainedToTerminalDecision() throws {
        for recorder in [try ReleaseDiagnosticRecorder() as any DiagnosticRecording,try DevelopmentDiagnosticRecorder() as any DiagnosticRecording] {
            let f = try RuntimeFixture(),engine = try f.engine(io:FaultingIO(base:f.io,mode:.audit),recorder:recorder)
            let prepared = try engine.prepare(observed:f.observed,desired:f.desired)
            let policy = try NativeContainmentPolicy(policyID:"APP-RESTRICT-V1",sourceReferences:["explicit-request"],allowedOperations:["observe","export"],resources:f.resources)
            XCTAssertThrowsError(try engine.requestContainment(policy:policy)) { XCTAssertEqual(($0 as? LifecycleFailure)?.code,.auditFailed) }
            XCTAssertThrowsError(try engine.prepareExecution(prepared,resources:f.resources,policyBundle:f.policy())) { XCTAssertEqual(($0 as? LifecycleFailure)?.code,.auditFailed) }
            let records = recorder.snapshot().events
            let halt = try XCTUnwrap(records.first{$0.event.stage == .safeHalt})
            let fault = try XCTUnwrap(records.last{$0.event.stage == .audit && $0.event.fault?.code == .audit})
            XCTAssertEqual(fault.event.operationID,halt.event.operationID);XCTAssertEqual(fault.event.incidentID,halt.event.incidentID)
            XCTAssertEqual(fault.event.causeEventIDs,[halt.event.eventID])
            XCTAssertThrowsError(try engine.prepare(observed:f.observed,desired:f.desired)) { XCTAssertEqual(($0 as? LifecycleFailure)?.code,.terminalHalt) }
            XCTAssertEqual(try CanonicalJSON.parse(f.io.read(path:f.resources.configuration)),f.observed)
        }
    }
    func testOperatorAuditFailureCannotReturnControlSuccessOrRelaxRestriction() throws {
        for halt in [true,false] {
            let f = try RuntimeFixture(),engine = try f.engine(io:FaultingIO(base:f.io,mode:.audit))
            if halt {
                XCTAssertThrowsError(try engine.enterSafeHalt(authority:NativeHaltAuthority(requestID:"operator-halt",sourceReferences:["explicit-request"]))) { XCTAssertEqual(($0 as? LifecycleFailure)?.code,.auditFailed) }
                XCTAssertThrowsError(try engine.prepare(observed:f.observed,desired:f.desired)) { XCTAssertEqual(($0 as? LifecycleFailure)?.code,.terminalHalt) }
            } else {
                let prepared = try engine.prepare(observed:f.observed,desired:f.desired)
                XCTAssertThrowsError(try engine.requestContainment(policy:NativeContainmentPolicy(policyID:"APP-RESTRICT-V1",sourceReferences:["explicit-request"],allowedOperations:["observe","export"],resources:f.resources))) { XCTAssertEqual(($0 as? LifecycleFailure)?.code,.auditFailed) }
                XCTAssertThrowsError(try engine.prepareExecution(prepared,resources:f.resources,policyBundle:f.policy()))
            }
            XCTAssertEqual(try CanonicalJSON.parse(f.io.read(path:f.resources.configuration)),f.observed)
            XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath:f.resources.backupDirectory).isEmpty)
        }
    }
    func testRegisteredFallbackUsesFreshBackupAndRevalidatesStableAfterOriginalFailure() throws {
        let f = try RuntimeFixture(),base = try NativeSliceContext.make(),predicate = try RegisteredStatePredicate(identifier:"APP-FALLBACK-SCOPE",sourceReferences:["explicit-fallback-evidence"],evaluate:{_,_ in true})
        let fallback = try FallbackPolicy(policyID:"FALLBACK-RECOVERY-001",applicabilityConditions:[predicate.identifier],candidateStateReference:base.knownValidStates.recognizedStates[0].stateID,orderingRank:0,validationRequirements:[predicate.identifier],escalationOnFailure:.ESCALATE_TO_CONTAINMENT,sourceReferences:["explicit-fallback-evidence"])
        let context = try SemanticContext(applicationScopeID:base.applicationScopeID,projectionSpec:base.projectionSpec,intentConstraints:base.intentConstraints,knownValidStates:base.knownValidStates,mappingRules:base.mappingRules,transitions:base.transitions,predicates:PredicateRuleRegistry([predicate]),fallbackPolicies:FallbackPolicyRegistry([fallback]),inputDiagnosticChains:base.inputDiagnosticChains)
        let engine = try f.engine(io:FaultingIO(base:f.io,mode:.partialMutation),context:context)
        let result = try engine.heal(resources:f.resources,policyBundle:f.policy())
        XCTAssertEqual(result.result.status,.HEALED);XCTAssertEqual(result.originatingFailure,.executionFailed)
        XCTAssertEqual(result.rollback?.status,.SUCCEEDED);XCTAssertEqual(result.fallback?.selectedCandidateID,fallback.policyID)
        XCTAssertEqual(result.verification?.status,.PASSED);XCTAssertTrue(result.auditPersisted)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath:f.resources.backupDirectory).count,2)
        let actual = try CanonicalJSON.parse(f.io.read(path:f.resources.configuration))
        XCTAssertEqual(actual.member("signals"),f.desired.member("signals"));XCTAssertEqual(actual.member("display"),f.observed.member("display"))
    }
    func testTwoRealAdapterInstancesAndSymlinkAliasContendOnSameLease() throws {
        let f = try RuntimeFixture(), other = try ScopedResourceIO(rootURL:f.root)
        let lease = try f.io.acquire(resources:f.resources);defer { lease.release() }
        XCTAssertThrowsError(try other.acquire(resources:f.resources)) { XCTAssertEqual($0 as? ResourceIOFault,.resourceBusy) }
        let alias = f.root.appendingPathComponent("alias.json")
        try FileManager.default.createSymbolicLink(atPath:alias.path,withDestinationPath:f.resources.configuration)
        let aliased = try NativeResourceSet(configuration:alias.path,desired:f.resources.desired,audit:f.resources.audit,backupDirectory:f.resources.backupDirectory)
        XCTAssertThrowsError(try other.acquire(resources:aliased)) { XCTAssertEqual($0 as? ResourceIOFault,.resourceBusy) }
    }
    func testReplacedLockNamespaceOrNamedLockInvalidatesOldLeaseBeforeAnyAuthorizedIO() throws {
        for replaceDirectory in [true,false] {
            let f = try RuntimeFixture(),original = try f.io.read(path:f.resources.configuration)
            let lease = try f.io.acquire(resources:f.resources);defer { lease.release() }
            let namespace = f.root.appendingPathComponent(".aeostara-resource-locks",isDirectory:true)
            if replaceDirectory {
                try FileManager.default.moveItem(at:namespace,to:f.root.appendingPathComponent("caller-detached-locks",isDirectory:true))
                try FileManager.default.createDirectory(at:namespace,withIntermediateDirectories:false,attributes:[.posixPermissions:0o700])
            } else {
                let name = try XCTUnwrap(FileManager.default.contentsOfDirectory(atPath:namespace.path).first)
                let lock = namespace.appendingPathComponent(name)
                try FileManager.default.moveItem(at:lock,to:f.root.appendingPathComponent("caller-detached-lock"))
                try Data().write(to:lock);try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:lock.path)
            }
            XCTAssertThrowsError(try lease.readConfiguration()) { XCTAssertEqual($0 as? ResourceIOFault,.scopeViolation) }
            XCTAssertThrowsError(try lease.replaceConfiguration(bytes:Data("changed".utf8),expectedBytesHash:CanonicalJSON.hashBytes(original)))
            XCTAssertThrowsError(try lease.createBackup(bytes:original,sourceHash:CanonicalJSON.hash(f.observed),identifier:"stale-lock"))
            let event = try AeostaraContract.AuditEvent(auditEventID:"blocked-audit",eventSequence:1,eventType:.OBSERVE,diagnosticReference:f.engine().prepare(observed:f.observed,desired:f.desired).dryRunResult.recoveryPlan.diagnosticReference,occurredAt:"test",details:.object([]))
            XCTAssertThrowsError(try lease.persistAudit(events:[event]))
            XCTAssertEqual(try f.io.read(path:f.resources.configuration),original)
            XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath:f.resources.backupDirectory).isEmpty)
            XCTAssertFalse(FileManager.default.fileExists(atPath:f.resources.audit))
        }
    }
    func testHardlinkOutsideSymlinkAndPathIdentityCollisionAreRejected() throws {
        let f = try RuntimeFixture()
        let hard = f.root.appendingPathComponent("hard.json");try FileManager.default.linkItem(atPath:f.resources.configuration,toPath:hard.path)
        XCTAssertThrowsError(try f.io.acquire(resources:f.resources)) { XCTAssertEqual($0 as? ResourceIOFault,.scopeViolation) }
        try FileManager.default.removeItem(at:hard)
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("{}".utf8).write(to:outside);defer { try? FileManager.default.removeItem(at:outside) }
        let symlink = f.root.appendingPathComponent("escape.json");try FileManager.default.createSymbolicLink(at:symlink,withDestinationURL:outside)
        XCTAssertThrowsError(try f.io.read(path:symlink.path)) { XCTAssertEqual($0 as? ResourceIOFault,.scopeViolation) }
        XCTAssertThrowsError(try NativeResourceSet(configuration:f.resources.configuration,desired:f.resources.desired,audit:f.resources.configuration,backupDirectory:f.resources.backupDirectory))
    }
    func testStalePreparedStateAndBackupCollisionAreRejected() throws {
        let f = try RuntimeFixture(), e = try f.engine(identifier:{"fixed-backup"})
        let prepared = try e.prepare(observed:f.observed,desired:f.desired)
        try f.io.writeScoped(path:f.resources.configuration,bytes:CanonicalJSON.encode(NativeSliceContext.document([0,0,0,0,0,0,0,0,1])))
        XCTAssertThrowsError(try e.prepareExecution(prepared,resources:f.resources,policyBundle:f.policy())) { XCTAssertEqual(($0 as? LifecycleFailure)?.code,.staleSnapshot) }
        try f.io.writeScoped(path:f.resources.configuration,bytes:CanonicalJSON.encode(f.observed))
        let token = try e.prepareExecution(prepared,resources:f.resources,policyBundle:f.policy())
        let originalBackup = try f.io.read(path:token.executionContext.backupResult.backupRecord.storageReference)
        token.cancel()
        XCTAssertThrowsError(try e.prepareExecution(prepared,resources:f.resources,policyBundle:f.policy())) { XCTAssertEqual(($0 as? LifecycleFailure)?.code,.backupFailed) }
        XCTAssertEqual(try f.io.read(path:URL(fileURLWithPath:f.resources.backupDirectory).appendingPathComponent("Aeostara-fixed-backup.backup").path),originalBackup)
    }
    func testStaleConfigurationAfterTokenPreservesCallerBytesWithoutRollback() throws {
        let f = try RuntimeFixture(),engine = try f.engine(),prepared = try engine.prepare(observed:f.observed,desired:f.desired)
        let token = try engine.prepareExecution(prepared,resources:f.resources,policyBundle:f.policy())
        let callerBytes = try CanonicalJSON.encode(NativeSliceContext.document([0,0,0,0,0,0,0,0,1],cosmetic:"new caller value"))
        try callerBytes.write(to:URL(fileURLWithPath:f.resources.configuration))
        let result = try engine.execute(token)
        XCTAssertEqual(result.originatingFailure,.staleSnapshot);XCTAssertNil(result.rollback);XCTAssertNil(result.fallback)
        XCTAssertTrue(result.executionSteps.isEmpty)
        XCTAssertEqual(try f.io.read(path:f.resources.configuration),callerBytes)
        XCTAssertFalse(result.result.auditChain.events.contains(where:{$0.eventType == .ROLLBACK || $0.eventType == .FALLBACK}))
    }
    func testPreparedTokenOwnershipReentrancyAndReplayAreRejected() throws {
        let f = try RuntimeFixture(), e = try f.engine(), other = try f.engine()
        let prepared = try e.prepare(observed:f.observed,desired:f.desired)
        let token = try e.prepareExecution(prepared,resources:f.resources,policyBundle:f.policy())
        XCTAssertThrowsError(try e.prepareExecution(prepared,resources:f.resources,policyBundle:f.policy())) { XCTAssertEqual(($0 as? LifecycleFailure)?.code,.resourceBusy) }
        XCTAssertThrowsError(try other.execute(token))
        XCTAssertEqual(try e.execute(token).result.status,.HEALED)
        XCTAssertThrowsError(try e.execute(token))
    }
    func testContainmentInvalidatesEarlierPreparedPlanBeforeExecution() throws {
        let f = try RuntimeFixture(),engine = try f.engine(),prepared = try engine.prepare(observed:f.observed,desired:f.desired)
        let restricted = try NativeContainmentPolicy(policyID:"APP-RESTRICT-V1",sourceReferences:["operator-scope-proof"],allowedOperations:["observe","export"],resources:f.resources)
        _ = try engine.requestContainment(policy:restricted)
        XCTAssertThrowsError(try engine.prepareExecution(prepared,resources:f.resources,policyBundle:f.policy()))
        XCTAssertEqual(try CanonicalJSON.parse(f.io.read(path:f.resources.configuration)),f.observed)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath:f.resources.backupDirectory).isEmpty)
    }
    func testPublicContainmentAndHaltPersistActualNativeAuditBeforeSuccess() throws {
        for halt in [false,true] {
            let f = try RuntimeFixture(),engine = try f.engine()
            if halt {
                _ = try engine.enterSafeHalt(authority:NativeHaltAuthority(requestID:"operator-halt",sourceReferences:["explicit-operator-authority"]))
            } else {
                _ = try engine.requestContainment(policy:NativeContainmentPolicy(policyID:"APP-RESTRICT-V1",sourceReferences:["operator-scope-proof"],allowedOperations:["observe","export"],resources:f.resources))
            }
            let data = try f.io.read(path:f.resources.audit)
            let events = try String(decoding:data,as:UTF8.self).split(separator:"\n").map{try ContractCoding.canonicalDecode(AeostaraContract.AuditEvent.self,from:Data($0.utf8))}
            XCTAssertTrue(events.contains(where:{$0.eventType == (halt ? .SAFE_HALT : .CONTAINMENT)}))
            XCTAssertEqual(try CanonicalJSON.parse(f.io.read(path:f.resources.configuration)),f.observed)
        }
    }
    func testContainmentBreachRecordsTerminalChain() throws {
        let f = try RuntimeFixture(), e = try f.engine()
        let policy = try NativeContainmentPolicy(policyID:"APP-RESTRICT-V1",sourceReferences:["synthetic-operator-request"],allowedOperations:["observe","export"],resources:f.resources)
        _ = try e.requestContainment(policy:policy)
        XCTAssertThrowsError(try e.heal(resources:f.resources,policyBundle:f.policy())) { XCTAssertEqual(($0 as? LifecycleFailure)?.code,.containmentBreach) }
        XCTAssertThrowsError(try e.heal(resources:f.resources,policyBundle:f.policy())) { XCTAssertEqual(($0 as? LifecycleFailure)?.code,.terminalHalt) }
        XCTAssertEqual(try CanonicalJSON.parse(f.io.read(path:f.resources.configuration)),f.observed)
    }
}
