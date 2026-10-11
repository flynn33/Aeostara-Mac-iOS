import Foundation

public struct NativeContainmentPolicy {
    public let policyID: String
    public let sourceReferences: [String]
    public let allowedOperations: [String]
    public let resources: NativeResourceSet
    public init(policyID: String, sourceReferences: [String], allowedOperations: [String], resources: NativeResourceSet) throws {
        guard !policyID.isEmpty, !sourceReferences.isEmpty, !allowedOperations.isEmpty,
              allowedOperations.allSatisfy({ ["observe","diagnose","export"].contains($0) }) else { throw SemanticInputFault.malformedEvidence }
        self.policyID = policyID;self.sourceReferences = sourceReferences;self.allowedOperations = allowedOperations;self.resources = resources
    }
}
public struct NativeHaltAuthority {
    public let requestID: String
    public let sourceReferences: [String]
    public init(requestID: String, sourceReferences: [String]) throws {
        guard !requestID.isEmpty, !sourceReferences.isEmpty else { throw SemanticInputFault.missingEvidence };self.requestID = requestID;self.sourceReferences = sourceReferences
    }
}
public struct NativeExecutionReceipt {
    public let result: AeostaraContract.HealResult
    public let policy: AeostaraContract.PolicyDecision?
    public let backup: AeostaraContract.BackupResult?
    public let executionSteps: [AeostaraContract.ExecutionStepResult]
    public let verification: AeostaraContract.VerificationResult?
    public let rollback: AeostaraContract.RollbackResult?
    public let fallback: AeostaraContract.FallbackDecision?
    public let containment: AeostaraContract.ContainmentDecision?
    public let safeHalt: AeostaraContract.SafeHaltDecision?
    public let originatingFailure: LifecycleFaultCode?
    public let auditPersisted: Bool
}
public final class NativePreparedExecution {
    public let executionContext: AeostaraContract.ExecutionContext
    public let preparation: NativeDiagnosisPlan
    let owner: NativeHealingEngine
    let lease: any NativeResourceLease
    let ledger: SemanticLedger
    let policyBundle: AeostaraContract.PolicyBundle
    let backupReceipt: NativeBackupReceipt
    let desired: JSONValue
    let observedBytes: Data
    let operationID: UUID
    var persistedEvents: Int
    private let tokenGuard = NSLock()
    private var consumed = false
    init(owner: NativeHealingEngine, lease: any NativeResourceLease, ledger: SemanticLedger, context: AeostaraContract.ExecutionContext,
         preparation: NativeDiagnosisPlan, policyBundle: AeostaraContract.PolicyBundle, backupReceipt: NativeBackupReceipt,
         desired: JSONValue, observedBytes: Data, operationID: UUID, persistedEvents: Int) {
        self.owner = owner;self.lease = lease;self.ledger = ledger;executionContext = context;self.preparation = preparation
        self.policyBundle = policyBundle;self.backupReceipt = backupReceipt;self.desired = desired;self.observedBytes = observedBytes
        self.operationID = operationID;self.persistedEvents = persistedEvents
    }
    func claim() -> Bool { tokenGuard.lock();defer { tokenGuard.unlock() };guard !consumed else { return false };consumed = true;return true }
    public func cancel() { if claim() { lease.release();owner.endOperation() } }
    deinit { cancel() }
}
public extension AeostaraContract {
    protocol IHealingEngine {
        func dryRun(observedState: ObservedSystemState, desiredIntent: DesiredSystemIntent, projectionSpec: SemanticProjectionSpec, policyBundle: PolicyBundle) throws -> DryRunResult
        func heal(observedState: ObservedSystemState, desiredIntent: DesiredSystemIntent, projectionSpec: SemanticProjectionSpec, policyBundle: PolicyBundle, executionContext: ExecutionContext) throws -> HealResult
    }
}

extension NativeHealingEngine: AeostaraContract.IHealingEngine {
    func beginOperation(ledger: SemanticLedger) throws {
        runtimeGuard.lock();defer { runtimeGuard.unlock() }
        if let terminalFailure { throw terminalFailure }
        guard !operationActive else { throw try ledger.failure(.resourceBusy) }
        guard containment == nil else { throw try ledger.failure(.containmentBreach) }
        operationActive = true;lastLedger = ledger
    }
    func endOperation() { runtimeGuard.lock();operationActive = false;pendingExecution = nil;executionDiagnosticLinks.removeAll();runtimeGuard.unlock() }
    func beginTelemetry(preparation: NativeDiagnosisPlan) -> UUID {
        let operation = UUID(), parent = preparation.diagnosticLink
        runtimeGuard.lock();executionDiagnosticLinks[operation] = .init(operationID:operation,incidentID:parent.incidentID,parentOperationID:parent.operationID,causeEventID:parent.causeEventID);runtimeGuard.unlock()
        return operation
    }
    func telemetryLink(_ operation: UUID) -> NativeDiagnosticLink? {
        runtimeGuard.lock();defer { runtimeGuard.unlock() };return executionDiagnosticLinks[operation]
    }
    func setTelemetryCause(operation: UUID,eventID: UUID) {
        runtimeGuard.lock();defer { runtimeGuard.unlock() }
        guard let link = executionDiagnosticLinks[operation] else { return }
        executionDiagnosticLinks[operation] = .init(operationID:operation,incidentID:link.incidentID,parentOperationID:link.parentOperationID,causeEventID:eventID)
    }
    func endTelemetry(_ operation: UUID) { runtimeGuard.lock();executionDiagnosticLinks.removeValue(forKey:operation);runtimeGuard.unlock() }
    func telemetry(stage: DiagnosticStage, outcome: DiagnosticOutcome, operation: UUID, fault: DiagnosticFaultCode? = nil) {
        let link = telemetryLink(operation)
        let retained = recorder?.record(.init(sessionID:sessionID,operationID:operation,incidentID:link?.incidentID ?? operation,
                                  parentOperationID:link?.parentOperationID,stage:stage,outcome:outcome,expected:fault == nil ? nil : .succeeded,fault:fault.map { .init(code:$0) },causeEventIDs:link?.causeEventID.map{[$0]} ?? []),developmentDetails:nil)
        if let retained { setTelemetryCause(operation:operation,eventID:retained) }
    }
    func ioCode(_ error: Error, stage: DiagnosticStage) -> LifecycleFaultCode {
        if let e = error as? ResourceIOFault {
            switch e { case .scopeViolation:return .scopeViolation;case .resourceBusy:return .resourceBusy;case .staleSnapshot:return .staleSnapshot
            case .backupCollision,.backupFailed:return .backupFailed;case .auditFailed:return .auditFailed
            case .readFailed,.writeFailed:break }
        }
        switch stage { case .policy:return .policyBlocked;case .backup:return .backupFailed;case .audit:return .auditFailed
        case .verify:return .verificationFailed;case .rollback:return .rollbackFailed;default:return .executionFailed }
    }
    public func dryRun(observedState: AeostaraContract.ObservedSystemState, desiredIntent: AeostaraContract.DesiredSystemIntent,
                       projectionSpec: AeostaraContract.SemanticProjectionSpec, policyBundle: AeostaraContract.PolicyBundle) throws -> AeostaraContract.DryRunResult {
        guard let snapshotRegistry, let policyRegistry else { throw try contextualFailure(.missingSemanticContext) }
        let observed = try snapshotRegistry.resolve(observedState.documentReference), desired = try snapshotRegistry.resolve(desiredIntent.documentReference)
        _ = try NativeSemanticProjector(observed:observed,desired:desired,context:context,diagnostic:observedState.diagnosticReference).project(observedState:observedState,desiredIntent:desiredIntent,projectionSpec:projectionSpec)
        let prepared = try prepare(observed:observed.document,desired:desired.document,partialIntent:desiredIntent.partialIntent)
        let ledger = SemanticLedger(preparation:prepared,time:timestampProvider())
        let operation = beginTelemetry(preparation:prepared);defer { endTelemetry(operation) }
        let decision: AeostaraContract.PolicyDecision
        do { decision = try policyRegistry.decide(bundle:policyBundle,input:.init(plan:prepared.dryRunResult.recoveryPlan,observed:observed.document,resources:nil),diagnostic:ledger.reference()) }
        catch { telemetry(stage:.policy,outcome:.failed,operation:operation,fault:.invalidContract);throw error }
        guard decision.decision == .ALLOW else { telemetry(stage:.policy,outcome:.blocked,operation:operation,fault:.policy);throw try ledger.failure(.policyBlocked) }
        telemetry(stage:.policy,outcome:.succeeded,operation:operation)
        return prepared.dryRunResult
    }
    public func heal(observedState: AeostaraContract.ObservedSystemState, desiredIntent: AeostaraContract.DesiredSystemIntent,
                     projectionSpec: AeostaraContract.SemanticProjectionSpec, policyBundle: AeostaraContract.PolicyBundle,
                     executionContext: AeostaraContract.ExecutionContext) throws -> AeostaraContract.HealResult {
        runtimeGuard.lock();let prepared = pendingExecution;runtimeGuard.unlock()
        guard let prepared, prepared.owner === self,
              try ContractCoding.canonicalEncode(prepared.executionContext) == ContractCoding.canonicalEncode(executionContext),
              try ContractCoding.canonicalEncode(prepared.policyBundle) == ContractCoding.canonicalEncode(policyBundle),
              try ContractCoding.canonicalEncode(context.projectionSpec) == ContractCoding.canonicalEncode(projectionSpec),
              try ContractCoding.canonicalEncode(observedState) == ContractCoding.canonicalEncode(prepared.preparation.observedState),
              try ContractCoding.canonicalEncode(desiredIntent) == ContractCoding.canonicalEncode(prepared.preparation.desiredIntent) else { throw try contextualFailure(.staleSnapshot) }
        return try execute(prepared).result
    }
    func contextualFailure(_ code: LifecycleFaultCode) throws -> LifecycleFailure {
        let ledger = try SemanticLedger(identity:context.knownValidStates.contextHash,time:timestampProvider());return try ledger.failure(code)
    }
    public func prepareExecution(_ preparation: NativeDiagnosisPlan, resources: NativeResourceSet, policyBundle: AeostaraContract.PolicyBundle) throws -> NativePreparedExecution {
        let ledger = SemanticLedger(preparation:preparation,time:timestampProvider())
        do { try beginOperation(ledger:ledger) }
        catch let failure as LifecycleFailure where failure.code == .containmentBreach { throw try rejectContainedMutation(resources:resources) }
        var lease: (any NativeResourceLease)?
        var stage = DiagnosticStage.policy
        let operation = beginTelemetry(preparation:preparation)
        var policyRecorded = false
        do {
            guard let resourceIO, let policyRegistry else { throw try ledger.failure(.missingSemanticContext) }
            guard preparation.issuerID == engineID, preparation.dryRunResult.recoveryPlan.planDisposition == .MUTATION_REQUIRED,
                  preparation.dryRunResult.verificationPlan.generatedBeforeMutation else { throw try ledger.failure(.malformedContract) }
            let source = try CanonicalJSON.parse(resourceIO.read(path:resources.configuration))
            guard try CanonicalJSON.hash(source) == preparation.observedState.documentReference.canonicalHash else { throw ResourceIOFault.staleSnapshot }
            let policyReference = try ledger.append(kind:.POLICY,event:.POLICY_GATE,message:"Evaluated explicit policy and propagation boundary",rule:"ASH-RECOVERY-ACTION-001")
            let decision = try policyRegistry.decide(bundle:policyBundle,input:.init(plan:preparation.dryRunResult.recoveryPlan,observed:source,resources:resources),diagnostic:policyReference)
            guard decision.decision == .ALLOW else { telemetry(stage:.policy,outcome:.blocked,operation:operation,fault:.policy);policyRecorded = true;throw try ledger.failure(.policyBlocked) }
            telemetry(stage:.policy,outcome:.succeeded,operation:operation);policyRecorded = true
            lease = try resourceIO.acquire(resources:resources)
            let active = lease!
            let observedBytes = try active.readConfiguration(), desiredBytes = try active.readDesired()
            let desired = try CanonicalJSON.parse(desiredBytes)
            guard try CanonicalJSON.hash(CanonicalJSON.parse(observedBytes)) == preparation.observedState.documentReference.canonicalHash,
                  try CanonicalJSON.hash(desired) == preparation.desiredIntent.documentReference.canonicalHash else { throw ResourceIOFault.staleSnapshot }
            stage = .audit
            try active.persistAudit(events:ledger.auditEvents)
            var persisted = ledger.auditEvents.count
            stage = .backup
            let receipt = try active.createBackup(bytes:observedBytes,sourceHash:preparation.observedState.documentReference.canonicalHash,identifier:identifierProvider())
            guard receipt.bytesHash == CanonicalJSON.hashBytes(observedBytes), receipt.sourceHash == preparation.observedState.documentReference.canonicalHash else { throw ResourceIOFault.backupFailed }
            let reference = try ledger.append(kind:.BACKUP,event:.BACKUP,message:"Created and verified exclusive backup",rule:"ASH-RECOVERY-ACTION-001")
            let record = try AeostaraContract.BackupRecord(backupRecordID:"backup-"+receipt.bytesHash+"-"+CanonicalJSON.hashBytes(Data(receipt.storageReference.utf8)),sourceDocument:preparation.observedState.documentReference,sourceHash:receipt.sourceHash,storageReference:receipt.storageReference,diagnosticReference:reference)
            let backup = try AeostaraContract.BackupResult(backupResultID:"backup-result-"+record.backupRecordID,status:.SUCCEEDED,backupRecord:record,diagnosticReference:reference)
            telemetry(stage:.backup,outcome:.succeeded,operation:operation)
            stage = .audit;try active.persistAudit(events:Array(ledger.auditEvents.dropFirst(persisted)));persisted = ledger.auditEvents.count
            let execution = try AeostaraContract.ExecutionContext(executionContextID:"execution-"+record.backupRecordID,recoveryPlanID:preparation.dryRunResult.recoveryPlan.recoveryPlanID,policyDecision:decision,backupResult:backup,verificationPlan:preparation.dryRunResult.verificationPlan,diagnosticReference:reference)
            let token = NativePreparedExecution(owner:self,lease:active,ledger:ledger,context:execution,preparation:preparation,policyBundle:policyBundle,backupReceipt:receipt,desired:desired,observedBytes:observedBytes,operationID:operation,persistedEvents:persisted)
            runtimeGuard.lock();pendingExecution = token;runtimeGuard.unlock();return token
        } catch let failure as LifecycleFailure {
            if stage == .policy && !policyRecorded { telemetry(stage:.policy,outcome:.failed,operation:operation,fault:failure.code == .policyBlocked ? .policy : .invalidContract) }
            lease?.release();endOperation();throw failure
        }
        catch {
            let code = ioCode(error,stage:stage);telemetry(stage:stage,outcome:.failed,operation:operation,fault:stage == .audit ? .audit : (stage == .backup ? .backup : (stage == .policy ? .policy : .execution)))
            lease?.release();endOperation();throw try ledger.failure(code)
        }
    }
    public func heal(resources: NativeResourceSet, policyBundle: AeostaraContract.PolicyBundle, partialIntent: Bool = false) throws -> NativeExecutionReceipt {
        runtimeGuard.lock();let terminal = terminalFailure;let contained = containment;runtimeGuard.unlock()
        if let terminal { throw terminal }
        if contained != nil { throw try rejectContainedMutation(resources:resources) }
        guard let resourceIO else { throw try contextualFailure(.missingSemanticContext) }
        let observed: JSONValue, desired: JSONValue
        do { observed = try CanonicalJSON.parse(resourceIO.read(path:resources.configuration));desired = try CanonicalJSON.parse(resourceIO.read(path:resources.desired)) }
        catch { throw try contextualFailure((error as? CanonicalJSONError) == .unsupportedNumber ? .unsupportedCanonicalNumber : ((error as? ResourceIOFault) == .scopeViolation ? .scopeViolation : .malformedContract)) }
        let prepared = try prepare(observed:observed,desired:desired,partialIntent:partialIntent)
        guard let policyRegistry else { throw try contextualFailure(.missingSemanticContext) }
        let decision: AeostaraContract.PolicyDecision
        do { decision = try policyRegistry.decide(bundle:policyBundle,input:.init(plan:prepared.dryRunResult.recoveryPlan,observed:observed,resources:resources),diagnostic:prepared.dryRunResult.recoveryPlan.diagnosticReference) }
        catch { let operation = beginTelemetry(preparation:prepared);telemetry(stage:.policy,outcome:.failed,operation:operation,fault:.invalidContract);endTelemetry(operation);throw try contextualFailure(.malformedContract) }
        if !prepared.dryRunResult.wouldMutate || decision.decision != .ALLOW { return try finishWithoutMutation(prepared,resources:resources,policyBundle:policyBundle,observed:observed) }
        return try execute(prepareExecution(prepared,resources:resources,policyBundle:policyBundle))
    }
    private func finishWithoutMutation(_ preparation: NativeDiagnosisPlan, resources: NativeResourceSet, policyBundle: AeostaraContract.PolicyBundle, observed: JSONValue) throws -> NativeExecutionReceipt {
        let ledger = SemanticLedger(preparation:preparation,time:timestampProvider());try beginOperation(ledger:ledger);defer { endOperation() }
        guard let resourceIO, let policyRegistry else { throw try ledger.failure(.missingSemanticContext) }
        let operation = beginTelemetry(preparation:preparation)
        let decision: AeostaraContract.PolicyDecision
        do { decision = try policyRegistry.decide(bundle:policyBundle,input:.init(plan:preparation.dryRunResult.recoveryPlan,observed:observed,resources:resources),diagnostic:ledger.reference()) }
        catch { telemetry(stage:.policy,outcome:.failed,operation:operation,fault:.invalidContract);throw error }
        telemetry(stage:.policy,outcome:decision.decision == .ALLOW ? .succeeded : .blocked,operation:operation,fault:decision.decision == .ALLOW ? nil : .policy)
        let lease = try resourceIO.acquire(resources:resources);defer { lease.release() }
        guard try CanonicalJSON.hash(CanonicalJSON.parse(lease.readConfiguration())) == preparation.observedState.documentReference.canonicalHash else { throw try ledger.failure(.staleSnapshot) }
        if decision.decision != .ALLOW {
            _ = try ledger.append(kind:.POLICY,event:.POLICY_GATE,message:"Policy blocked without mutation",failed:true)
            do { try lease.persistAudit(events:ledger.auditEvents) } catch { throw try ledger.failure(.auditFailed) }
            return try receipt(status:.BLOCKED,preparation:preparation,ledger:ledger,policy:decision,failure:.policyBlocked)
        }
        if preparation.recoveryCategory == .NO_ACTION {
            do { try lease.persistAudit(events:ledger.auditEvents) } catch { throw try ledger.failure(.auditFailed) }
            return try receipt(status:.NO_ACTION,preparation:preparation,ledger:ledger,policy:decision)
        }
        let terminal = try enterSafeHalt(trigger:"UNRESOLVABLE_BLOCKED_RECOVERY",authority:nil,ledger:ledger,diagnosticOperation:operation)
        do { try lease.persistAudit(events:ledger.auditEvents) } catch { throw try ledger.failure(.auditFailed) }
        return try receipt(status:.SAFE_HALT,preparation:preparation,ledger:ledger,policy:decision,halt:terminal,failure:.terminalHalt)
    }
    public func execute(_ token: NativePreparedExecution) throws -> NativeExecutionReceipt {
        guard token.owner === self, token.claim() else { throw try contextualFailure(.staleSnapshot) }
        defer { token.lease.release();endOperation() }
        let preparation = token.preparation, ledger = token.ledger, lease = token.lease
        var steps: [AeostaraContract.ExecutionStepResult] = [], verification: AeostaraContract.VerificationResult?
        var stage = DiagnosticStage.mutate
        var mutationAttempted = false
        func persist() throws { try lease.persistAudit(events:Array(ledger.auditEvents.dropFirst(token.persistedEvents)));token.persistedEvents = ledger.auditEvents.count }
        do {
            var current = try lease.readConfiguration()
            guard CanonicalJSON.hashBytes(current) == CanonicalJSON.hashBytes(token.observedBytes) else { throw ResourceIOFault.staleSnapshot }
            for step in preparation.dryRunResult.recoveryPlan.recoverySteps {
                for operation in step.jsonMutationOperations {
                    let document = try CanonicalJSON.parse(current)
                    guard try CanonicalJSON.hash(document) == operation.preconditionHash else { throw ResourceIOFault.staleSnapshot }
                    let output = try JSONPointer(operation.path.pointer).applying(operation.op,value:operation.value,to:document)
                    let bytes = try CanonicalJSON.encode(output)
                    mutationAttempted = true
                    try lease.replaceConfiguration(bytes:bytes,expectedBytesHash:CanonicalJSON.hashBytes(current));current = try lease.readConfiguration()
                    guard current == bytes else { throw ResourceIOFault.writeFailed }
                }
                let reference = try ledger.append(kind:.EXECUTION,event:.EXECUTE,message:"Applied approved recovery step",rule:"ASH-RECOVERY-ACTION-001")
                steps.append(try AeostaraContract.ExecutionStepResult(executionStepResultID:"execution-step-"+step.stepID,stepID:step.stepID,status:.SUCCEEDED,observedHashAfterStep:CanonicalJSON.hash(CanonicalJSON.parse(current)),diagnosticReference:reference))
                telemetry(stage:.mutate,outcome:.succeeded,operation:token.operationID)
                stage = .audit;try persist();stage = .mutate
            }
            stage = .verify
            let reference = try ledger.append(kind:.VERIFICATION,event:.VERIFY,message:"Reobserved and validated planned resource and semantic target",rule:"ASH-STATE-VALIDITY-001")
            let actual = try CanonicalJSON.parse(lease.readConfiguration())
            let diagnosed = try prepareNative(observed:actual,desired:token.desired,partialIntent:preparation.desiredIntent.partialIntent,diagnosticParent:telemetryLink(token.operationID))
            let passed = try CanonicalJSON.hash(actual) == preparation.plannedHash && actual == preparation.plannedDocument && diagnosed.mapping.projectedState.coordinates == preparation.dryRunResult.verificationPlan.expectedSemanticState.coordinates && diagnosed.stateClass == .STABLE
            verification = try AeostaraContract.VerificationResult(verificationResultID:"verified-"+preparation.plannedHash,verificationPlanID:preparation.dryRunResult.verificationPlan.verificationPlanID,status:passed ? .PASSED : .FAILED,expectedSemanticState:preparation.dryRunResult.verificationPlan.expectedSemanticState,actualSemanticState:diagnosed.mapping.projectedState,diagnosticReference:reference)
            guard passed else { throw ResourceIOFault.writeFailed }
            telemetry(stage:.verify,outcome:.succeeded,operation:token.operationID)
            _ = try ledger.append(kind:.RECOVERY,event:.RESULT,message:"Healing completed after verified STABLE state",rule:"ASH-RECOVERY-ACTION-001")
            stage = .audit;try persist()
            return try receipt(status:.HEALED,preparation:preparation,ledger:ledger,policy:token.executionContext.policyDecision,backup:token.executionContext.backupResult,steps:steps,verification:verification)
        } catch {
            let origin = ioCode(error,stage:stage)
            _ = try ledger.append(kind:stage == .verify ? .VERIFICATION : .EXECUTION,event:stage == .verify ? .VERIFY : .EXECUTE,message:"Approved execution failed; original fault preserved",failed:true,evidence:.object([JSONMember("fault",.string(origin.rawValue))]))
            telemetry(stage:stage,outcome:.failed,operation:token.operationID,fault:stage == .verify ? .verification : (stage == .audit ? .audit : .execution))
            var rollback: AeostaraContract.RollbackResult?
            var auditHealthy = origin != .auditFailed
            if mutationAttempted {
            do {
                let live = try lease.readConfiguration()
                let restored = try lease.restoreBackup(token.backupReceipt,expectedBytesHash:CanonicalJSON.hashBytes(live))
                guard restored == token.observedBytes, try CanonicalJSON.hash(CanonicalJSON.parse(restored)) == token.backupReceipt.sourceHash else { throw ResourceIOFault.backupFailed }
                let reference = try ledger.append(kind:.ROLLBACK,event:.ROLLBACK,message:"Exact original backup restored and reread",rule:"ASH-RECOVERY-ACTION-001")
                rollback = try AeostaraContract.RollbackResult(rollbackResultID:"rollback-"+token.executionContext.backupResult.backupRecord.backupRecordID,status:.SUCCEEDED,backupRecordID:token.executionContext.backupResult.backupRecord.backupRecordID,restoredHash:token.backupReceipt.sourceHash,diagnosticReference:reference)
                telemetry(stage:.rollback,outcome:.rolledBack,operation:token.operationID)
            } catch {
                _ = try ledger.append(kind:.ROLLBACK,event:.ROLLBACK,message:"Rollback failed; restored success is unavailable",failed:true,evidence:.object([JSONMember("fault",.string(LifecycleFaultCode.rollbackFailed.rawValue))]))
                telemetry(stage:.rollback,outcome:.failed,operation:token.operationID,fault:.rollback)
            }
            }
            // Audit failure forbids further normal recovery mutations. A previously authorized rollback remains allowed.
            if auditHealthy {
                do { try persist() } catch { auditHealthy = false;telemetry(stage:.audit,outcome:.failed,operation:token.operationID,fault:.audit);_ = try ledger.append(kind:.EXECUTION,event:.RESULT,message:"Mandatory audit persistence failed",failed:true,evidence:.object([JSONMember("fault",.string(LifecycleFaultCode.auditFailed.rawValue))])) }
            }
            if mutationAttempted && auditHealthy, let fallbackReceipt = try attemptFallback(token:token,originalFailure:origin,rollback:rollback,steps:steps,verification:verification) { return fallbackReceipt }
            let contain: AeostaraContract.ContainmentDecision?
            let halt: AeostaraContract.SafeHaltDecision?
            if let containmentPolicy, containmentPolicy.resources == lease.resources {
                do { contain = try enterContainment(trigger:"RECOVERY_VALIDATION_FAILURE",policy:containmentPolicy,ledger:ledger,diagnosticOperation:token.operationID);halt = nil }
                catch {
                    _ = try ledger.append(kind:.CONTAINMENT,event:.CONTAINMENT,message:"Containment boundary unavailable after recovery failure",rule:"ASH-CONTAINMENT-TRIGGER-001",failed:true)
                    contain = nil;halt = try enterSafeHalt(trigger:"UNRESOLVABLE_BLOCKED_RECOVERY",authority:nil,ledger:ledger,diagnosticOperation:token.operationID)
                }
            } else { contain = nil;halt = try enterSafeHalt(trigger:"UNRESOLVABLE_BLOCKED_RECOVERY",authority:nil,ledger:ledger,diagnosticOperation:token.operationID) }
            do { try persist() } catch { auditHealthy = false;telemetry(stage:.audit,outcome:.failed,operation:token.operationID,fault:.audit) }
            return try receipt(status:halt == nil ? .ESCALATED : .SAFE_HALT,preparation:preparation,ledger:ledger,policy:token.executionContext.policyDecision,backup:token.executionContext.backupResult,steps:steps,verification:verification,rollback:rollback,containment:contain,halt:halt,failure:origin,auditPersisted:auditHealthy)
        }
    }
    private func attemptFallback(token: NativePreparedExecution, originalFailure: LifecycleFaultCode, rollback: AeostaraContract.RollbackResult?, steps: [AeostaraContract.ExecutionStepResult], verification: AeostaraContract.VerificationResult?) throws -> NativeExecutionReceipt? {
        let ledger = token.ledger
        let candidates: [(FallbackPolicy,AeostaraContract.AshState)]
        guard let policyRegistry else { return nil }
        telemetry(stage:.fallback,outcome:.started,operation:token.operationID)
        do {
            let current = try CanonicalJSON.parse(token.lease.readConfiguration())
            let provisional = try prepareNative(observed:current,desired:token.desired,partialIntent:token.preparation.desiredIntent.partialIntent,forcedFallback:true,diagnosticParent:telemetryLink(token.operationID))
            let targets = context.knownValidStates.recognizedStates.map(\.coordinates)
            candidates = try NativeAshBindingProvider(context:context).eligibleFallbacks(for:provisional.mapping.projectedState.coordinates,eligibleTargets:targets)
        } catch {
            _ = try ledger.append(kind:.FALLBACK,event:.FALLBACK,message:"Fallback prerequisites unavailable after recorded recovery failure",rule:"ASH-FALLBACK-SELECTION-001",failed:true)
            telemetry(stage:.fallback,outcome:.unavailable,operation:token.operationID,fault:.execution)
            return nil
        }
        if candidates.isEmpty { telemetry(stage:.fallback,outcome:.unavailable,operation:token.operationID) }
        for (candidate,_) in candidates {
            var fallbackBackup: NativeBackupReceipt?
            var fallbackMutationAttempted = false
            var fallbackStage = DiagnosticStage.policy
            do {
                let actualCurrent = try CanonicalJSON.parse(token.lease.readConfiguration())
                let plan = try prepareNative(observed:actualCurrent,desired:token.desired,partialIntent:token.preparation.desiredIntent.partialIntent,forcedFallback:true,fallbackPolicyID:candidate.policyID,diagnosticParent:telemetryLink(token.operationID))
                guard plan.dryRunResult.wouldMutate else { throw SemanticInputFault.missingMaterialization }
                let reference = try ledger.append(kind:.FALLBACK,event:.FALLBACK,message:"Selected registered fallback after recovery failure",rule:"ASH-FALLBACK-SELECTION-001",evidence:.object([JSONMember("plan",plan.dryRunResult.recoveryPlan.jsonValue),JSONMember("policyID",.string(candidate.policyID))]))
                let decision = try policyRegistry.decide(bundle:token.policyBundle,input:.init(plan:plan.dryRunResult.recoveryPlan,observed:actualCurrent,resources:token.lease.resources),diagnostic:reference)
                guard decision.decision == .ALLOW else { throw SemanticInputFault.missingEvidence }
                telemetry(stage:.policy,outcome:.succeeded,operation:token.operationID)
                fallbackStage = .audit
                try token.lease.persistAudit(events:Array(ledger.auditEvents.dropFirst(token.persistedEvents)));token.persistedEvents = ledger.auditEvents.count
                var bytes = try token.lease.readConfiguration()
                guard try CanonicalJSON.hash(CanonicalJSON.parse(bytes)) == plan.observedState.documentReference.canonicalHash else { throw ResourceIOFault.staleSnapshot }
                fallbackStage = .backup
                let backupReceipt = try token.lease.createBackup(bytes:bytes,sourceHash:plan.observedState.documentReference.canonicalHash,identifier:identifierProvider())
                fallbackBackup = backupReceipt
                guard backupReceipt.bytesHash == CanonicalJSON.hashBytes(bytes),backupReceipt.sourceHash == plan.observedState.documentReference.canonicalHash else { throw ResourceIOFault.backupFailed }
                let backupReference = try ledger.append(kind:.BACKUP,event:.BACKUP,message:"Verified fresh fallback snapshot backup",rule:"ASH-RECOVERY-ACTION-001")
                let record = try AeostaraContract.BackupRecord(backupRecordID:"fallback-backup-"+CanonicalJSON.hashBytes(Data(backupReceipt.storageReference.utf8)),sourceDocument:plan.observedState.documentReference,sourceHash:backupReceipt.sourceHash,storageReference:backupReceipt.storageReference,diagnosticReference:backupReference)
                let backup = try AeostaraContract.BackupResult(backupResultID:"fallback-backup-result-"+record.backupRecordID,status:.SUCCEEDED,backupRecord:record,diagnosticReference:backupReference)
                telemetry(stage:.backup,outcome:.succeeded,operation:token.operationID)
                fallbackStage = .audit
                try token.lease.persistAudit(events:Array(ledger.auditEvents.dropFirst(token.persistedEvents)));token.persistedEvents = ledger.auditEvents.count
                fallbackStage = .mutate
                var allSteps = steps
                for step in plan.dryRunResult.recoveryPlan.recoverySteps {
                    for operation in step.jsonMutationOperations {
                        let document = try CanonicalJSON.parse(bytes);guard try CanonicalJSON.hash(document) == operation.preconditionHash else { throw ResourceIOFault.staleSnapshot }
                        let next = try CanonicalJSON.encode(JSONPointer(operation.path.pointer).applying(operation.op,value:operation.value,to:document))
                        fallbackMutationAttempted = true
                        try token.lease.replaceConfiguration(bytes:next,expectedBytesHash:CanonicalJSON.hashBytes(bytes));bytes = try token.lease.readConfiguration();guard bytes == next else { throw ResourceIOFault.writeFailed }
                    }
                    let executed = try ledger.append(kind:.EXECUTION,event:.EXECUTE,message:"Applied approved fallback step",rule:"ASH-RECOVERY-ACTION-001")
                    allSteps.append(try .init(executionStepResultID:"fallback-execution-"+step.stepID,stepID:step.stepID,status:.SUCCEEDED,observedHashAfterStep:CanonicalJSON.hash(CanonicalJSON.parse(bytes)),diagnosticReference:executed))
                    telemetry(stage:.mutate,outcome:.succeeded,operation:token.operationID)
                }
                fallbackStage = .verify
                let actual = try CanonicalJSON.parse(token.lease.readConfiguration()), post = try prepareNative(observed:actual,desired:token.desired,partialIntent:token.preparation.desiredIntent.partialIntent,diagnosticParent:telemetryLink(token.operationID))
                guard actual == plan.plannedDocument, try CanonicalJSON.hash(actual) == plan.plannedHash, post.stateClass == .STABLE,
                      post.mapping.projectedState.coordinates == plan.dryRunResult.verificationPlan.expectedSemanticState.coordinates else { throw SemanticInputFault.malformedEvidence }
                let verifiedReference = try ledger.append(kind:.FALLBACK,event:.VERIFY,message:"Fallback revalidated VALID and STABLE",rule:"ASH-FALLBACK-SELECTION-001")
                let verified = try AeostaraContract.VerificationResult(verificationResultID:"fallback-verified-"+plan.plannedHash,verificationPlanID:plan.dryRunResult.verificationPlan.verificationPlanID,status:.PASSED,expectedSemanticState:plan.dryRunResult.verificationPlan.expectedSemanticState,actualSemanticState:post.mapping.projectedState,diagnosticReference:verifiedReference)
                let fallback = try AeostaraContract.FallbackDecision(fallbackDecisionID:"fallback-"+candidate.policyID,registryReference:context.applicationScopeID,selectedCandidateID:candidate.policyID,status:.SELECTED,diagnosticReference:reference)
                telemetry(stage:.verify,outcome:.succeeded,operation:token.operationID)
                telemetry(stage:.fallback,outcome:.succeeded,operation:token.operationID)
                fallbackStage = .audit
                try token.lease.persistAudit(events:Array(ledger.auditEvents.dropFirst(token.persistedEvents)));token.persistedEvents = ledger.auditEvents.count
                return try receipt(status:.HEALED,preparation:plan,ledger:ledger,policy:decision,backup:backup,steps:allSteps,verification:verified,rollback:rollback,fallback:fallback,failure:originalFailure)
            } catch {
                let recoveryFault: DiagnosticFaultCode
                switch fallbackStage { case .policy:recoveryFault = .policy;case .backup:recoveryFault = .backup;case .audit:recoveryFault = .audit;case .verify:recoveryFault = .verification;default:recoveryFault = .execution }
                telemetry(stage:fallbackStage,outcome:.failed,operation:token.operationID,fault:recoveryFault)
                _ = try ledger.append(kind:.FALLBACK,event:.FALLBACK,message:"Fallback unavailable, blocked, or failed validation",rule:"ASH-FALLBACK-SELECTION-001",failed:true,evidence:.object([JSONMember("policyID",.string(candidate.policyID))]))
                if fallbackMutationAttempted, let backup = fallbackBackup {
                    do { let live = try token.lease.readConfiguration();let restored = try token.lease.restoreBackup(backup,expectedBytesHash:CanonicalJSON.hashBytes(live));guard CanonicalJSON.hashBytes(restored) == backup.bytesHash else { throw ResourceIOFault.backupFailed }
                        _ = try ledger.append(kind:.ROLLBACK,event:.ROLLBACK,message:"Restored actual failed fallback snapshot",rule:"ASH-RECOVERY-ACTION-001")
                        telemetry(stage:.rollback,outcome:.rolledBack,operation:token.operationID)
                    } catch { telemetry(stage:.rollback,outcome:.failed,operation:token.operationID,fault:.rollback);_ = try ledger.append(kind:.ROLLBACK,event:.ROLLBACK,message:"Fallback rollback failed",rule:"ASH-RECOVERY-ACTION-001",failed:true) }
                }
                telemetry(stage:.fallback,outcome:.blocked,operation:token.operationID,fault:.execution)
                do { try token.lease.persistAudit(events:Array(ledger.auditEvents.dropFirst(token.persistedEvents)));token.persistedEvents = ledger.auditEvents.count } catch { telemetry(stage:.audit,outcome:.failed,operation:token.operationID,fault:.audit);return nil }
                if fallbackStage == .audit { return nil }
                if candidate.escalationOnFailure == .ESCALATE_TO_CONTAINMENT { break }
            }
        }
        return nil
    }
    private func beginControlOperation(ledger: SemanticLedger) throws -> UUID {
        runtimeGuard.lock();defer { runtimeGuard.unlock() }
        if let terminalFailure { throw terminalFailure }
        guard !operationActive else { throw try ledger.failure(.resourceBusy) }
        operationActive = true;lastLedger = ledger
        let operation = UUID()
        executionDiagnosticLinks[operation] = .init(operationID:operation,incidentID:operation,parentOperationID:nil,causeEventID:nil)
        return operation
    }
    private func persistControl(_ ledger: SemanticLedger, lease: any NativeResourceLease, diagnosticOperation: UUID) throws {
        do { try lease.persistAudit(events:ledger.auditEvents);telemetry(stage:.audit,outcome:.succeeded,operation:diagnosticOperation) }
        catch {
            telemetry(stage:.audit,outcome:.failed,operation:diagnosticOperation,fault:.audit)
            let failure = try ledger.failure(.auditFailed)
            runtimeGuard.lock()
            if terminalFailure != nil { terminalFailure = LifecycleFailure(code:.terminalHalt,diagnosticChain:failure.diagnosticChain,auditChain:failure.auditChain) }
            runtimeGuard.unlock()
            throw failure
        }
    }
    private func rejectContainedMutation(resources: NativeResourceSet) throws -> LifecycleFailure {
        let ledger = try SemanticLedger(identity:"containment-breach-"+UUID().uuidString,time:timestampProvider())
        let operation = try beginControlOperation(ledger:ledger);defer { endOperation() }
        guard let resourceIO else { throw try ledger.failure(.missingSemanticContext) }
        let lease = try resourceIO.acquire(resources:resources);defer { lease.release() }
        _ = try enterSafeHalt(trigger:"CONTAINMENT_BREACH",authority:nil,ledger:ledger,diagnosticOperation:operation)
        try persistControl(ledger,lease:lease,diagnosticOperation:operation)
        return try LifecycleFailure(code:.containmentBreach,diagnosticChain:ledger.diagnosticChain(),auditChain:ledger.auditChain())
    }
    public func requestContainment(policy: NativeContainmentPolicy) throws -> AeostaraContract.ContainmentDecision {
        let ledger = try SemanticLedger(identity:"operator-containment-"+UUID().uuidString,time:timestampProvider())
        let operation = try beginControlOperation(ledger:ledger);defer { endOperation() }
        guard let resourceIO, defaultResources == nil || defaultResources == policy.resources else { throw try ledger.failure(.missingSemanticContext) }
        let lease = try resourceIO.acquire(resources:policy.resources);defer { lease.release() }
        let decision = try enterContainment(trigger:"OPERATOR_REQUEST",policy:policy,ledger:ledger,diagnosticOperation:operation)
        try persistControl(ledger,lease:lease,diagnosticOperation:operation)
        return decision
    }
    private func enterContainment(trigger: String, policy: NativeContainmentPolicy, ledger: SemanticLedger, diagnosticOperation: UUID? = nil) throws -> AeostaraContract.ContainmentDecision {
        guard ["FALLBACK_FAILURE","PROPAGATION_RISK","OPERATOR_REQUEST","RECOVERY_VALIDATION_FAILURE"].contains(trigger), let resourceIO else { throw try ledger.failure(.missingEvidence) }
        // Resolve the declared boundary through the real adapter before admitting a containment policy.
        _ = try resourceIO.read(path:policy.resources.configuration);_ = try resourceIO.read(path:policy.resources.desired)
        let reference = try ledger.append(kind:.CONTAINMENT,event:.CONTAINMENT,message:"Entered recorded restricted operation subset",rule:"ASH-CONTAINMENT-TRIGGER-001",evidence:.object([JSONMember("trigger",.string(trigger)),JSONMember("policyID",.string(policy.policyID)),JSONMember("sources",.array(policy.sourceReferences.map(JSONValue.string)))]))
        let decision = try AeostaraContract.ContainmentDecision(containmentDecisionID:"containment-"+reference.diagnosticID,boundary:.object([JSONMember("scope",.string(context.applicationScopeID))]),allowedOperations:policy.allowedOperations,restrictedOperations:["mutate","transition","rollback","fallback"],diagnosticReference:reference)
        runtimeGuard.lock();containment = decision;lastLedger = ledger;runtimeGuard.unlock();telemetry(stage:.containment,outcome:.contained,operation:diagnosticOperation ?? UUID());return decision
    }
    public func enterSafeHalt(authority: NativeHaltAuthority) throws -> AeostaraContract.SafeHaltDecision {
        let ledger = try SemanticLedger(identity:"operator-halt-"+UUID().uuidString,time:timestampProvider())
        let operation = try beginControlOperation(ledger:ledger);defer { endOperation() }
        guard let resourceIO, let resources = defaultResources else { throw try ledger.failure(.missingSemanticContext) }
        let lease = try resourceIO.acquire(resources:resources);defer { lease.release() }
        let decision = try enterSafeHalt(trigger:"OPERATOR_HALT_REQUEST",authority:authority,ledger:ledger,diagnosticOperation:operation)
        try persistControl(ledger,lease:lease,diagnosticOperation:operation)
        return decision
    }
    private func enterSafeHalt(trigger: String, authority: NativeHaltAuthority?, ledger supplied: SemanticLedger? = nil, diagnosticOperation: UUID? = nil) throws -> AeostaraContract.SafeHaltDecision {
        runtimeGuard.lock();let existing = lastLedger;let terminal = terminalFailure;runtimeGuard.unlock();if let terminal { throw terminal }
        let ledger = try supplied ?? existing ?? SemanticLedger(identity:context.knownValidStates.contextHash,time:timestampProvider())
        let reference = try ledger.append(kind:.SAFE_HALT,event:.SAFE_HALT,message:"Entered terminal safe halt; subsequent mutation and transitions forbidden",rule:"ASH-HALT-TRIGGER-001",failed:true,evidence:.object([JSONMember("trigger",.string(trigger)),JSONMember("authority",authority.map { .string($0.requestID) } ?? .null)]))
        let decision = try AeostaraContract.SafeHaltDecision(safeHaltDecisionID:"halt-"+reference.diagnosticID,terminal:true,blockedTransitions:["ALL"],diagnosticReference:reference)
        let failure = try LifecycleFailure(code:.terminalHalt,diagnosticChain:ledger.diagnosticChain(),auditChain:ledger.auditChain())
        runtimeGuard.lock();terminalFailure = failure;lastLedger = ledger;runtimeGuard.unlock();telemetry(stage:.safeHalt,outcome:.halted,operation:diagnosticOperation ?? UUID());return decision
    }
    private func receipt(status: AeostaraContract.HealResult.StatusValue, preparation: NativeDiagnosisPlan, ledger: SemanticLedger,
                         policy: AeostaraContract.PolicyDecision? = nil, backup: AeostaraContract.BackupResult? = nil,
                         steps: [AeostaraContract.ExecutionStepResult] = [], verification: AeostaraContract.VerificationResult? = nil,
                         rollback: AeostaraContract.RollbackResult? = nil, fallback: AeostaraContract.FallbackDecision? = nil,
                         containment: AeostaraContract.ContainmentDecision? = nil, halt: AeostaraContract.SafeHaltDecision? = nil,
                         failure: LifecycleFaultCode? = nil, auditPersisted: Bool = true) throws -> NativeExecutionReceipt {
        let result = try AeostaraContract.HealResult(healResultID:"heal-"+preparation.dryRunResult.recoveryPlan.planHash+"-"+status.rawValue,status:status,recoveryPlan:preparation.dryRunResult.recoveryPlan,auditChain:ledger.auditChain(),diagnosticChain:ledger.diagnosticChain())
        return NativeExecutionReceipt(result:result,policy:policy,backup:backup,executionSteps:steps,verification:verification,rollback:rollback,fallback:fallback,containment:containment,safeHalt:halt,originatingFailure:failure,auditPersisted:auditPersisted)
    }
}
