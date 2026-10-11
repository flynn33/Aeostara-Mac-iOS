// Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.
import Foundation

/// Source-compatible file entrypoints backed by explicit native semantic context.
/// The older adapter arguments remain accepted; mutation is owned by SemanticResourceIO.
public final class HealingEngine: IHealingEngine {
    private let fileSystem: IFileSystem
    private let timestampProvider: () -> String
    private let invariantParser: InvariantParser
    private let policyEvaluator: PolicyEvaluator
    private let context: SemanticContext?
    private let resources: NativeResourceSet?
    private let resourceIO: (any SemanticResourceIO)?
    private let policies: NativePolicyRegistry?
    private let policyBundle: AeostaraContract.PolicyBundle?
    private let recorder: (any DiagnosticRecording)?
    private let identifierProvider: () -> String
    private let operationGuard = NSLock()
    private var terminal: LifecycleFailure?

    public init(adapter: IConfigAdapter, backupManager: IBackupProvider, driftAnalyzer: DriftAnalyzer,
                repairPlanner: RepairPlanner, policyEvaluator: PolicyEvaluator, invariantParser: InvariantParser,
                verification: Verification, rollbackManager: RollbackManager, fileSystem: IFileSystem,
                timestampProvider: @escaping () -> String, eventIDProvider: @escaping () -> String,
                semanticContext: SemanticContext? = nil, nativePolicies: NativePolicyRegistry? = nil,
                nativePolicyBundle: AeostaraContract.PolicyBundle? = nil, nativeResources: NativeResourceSet? = nil,
                resourceIO: (any SemanticResourceIO)? = nil, recorder: (any DiagnosticRecording)? = nil,
                identifierProvider: @escaping () -> String = { UUID().uuidString }) {
        self.fileSystem = fileSystem;self.timestampProvider = timestampProvider;self.policyEvaluator = policyEvaluator
        self.invariantParser = invariantParser;context = semanticContext;policies = nativePolicies;policyBundle = nativePolicyBundle
        resources = nativeResources;self.resourceIO = resourceIO ?? (fileSystem as? any SemanticResourceIO)
        self.recorder = recorder;self.identifierProvider = identifierProvider
    }
    private func failure(_ code: LifecycleFaultCode) throws -> LifecycleFailure {
        try SemanticLedger(identity:context?.knownValidStates.contextHash ?? "legacy-missing-semantic-context",time:timestampProvider()).failure(code)
    }
    private func requireContext() throws -> SemanticContext {
        if let terminal { throw terminal }
        guard let context else { throw try failure(.missingSemanticContext) };return context
    }
    private func invariants(_ path: String?) throws -> [Invariant] {
        do { return try invariantParser.parseInvariants(from:path,fileSystem:fileSystem) }
        catch { throw try failure(.malformedContract) }
    }
    private func makeEngine(invariants: [Invariant]) throws -> (NativeHealingEngine,AeostaraContract.PolicyBundle) {
        let context = try requireContext()
        guard let policies,let policyBundle else { throw try failure(.missingSemanticContext) }
        let id = "LEGACY-REQUESTED-INVARIANTS"
        let evaluator = policyEvaluator
        let predicate = try RegisteredPolicyPredicate(identifier:id,sourceReferences:["Aeostara file API: explicitly requested invariant expressions"],evaluate:{ input in
            var planned = input.observed
            for operation in input.plan.recoverySteps.flatMap(\.jsonMutationOperations) { planned = try JSONPointer(operation.path.pointer).applying(operation.op,value:operation.value,to:planned) }
            let criticalObserved = invariants.contains { $0.severity == .critical && !$0.autoRemediate && !evaluator.evaluateExpression($0.expression,document:input.observed) }
            return criticalObserved || invariants.contains { !evaluator.evaluateExpression($0.expression,document:planned) }
        })
        let registry = try policies.adding([predicate])
        let rules = policyBundle.rules + [.object([JSONMember("policyID",.string(id)),JSONMember("predicateID",.string(id)),JSONMember("effect",.string("BLOCK"))])]
        let bundleID = policyBundle.policyBundleID + "-requested-invariants"
        let source = policyBundle.sourceReferences + ["Aeostara file API: invariantsPath nil means intentional omission"]
        // Validate the caller's original bundle before deriving the documented additional invariant gate.
        let originalIdentity = JSONValue.object([JSONMember("policyBundleID",.string(policyBundle.policyBundleID)),JSONMember("rules",.array(policyBundle.rules)),JSONMember("sourceReferences",.array(policyBundle.sourceReferences.map(JSONValue.string)))])
        guard try CanonicalJSON.hash(originalIdentity) == policyBundle.bundleHash else { throw try failure(.malformedContract) }
        let identity = JSONValue.object([JSONMember("policyBundleID",.string(bundleID)),JSONMember("rules",.array(rules)),JSONMember("sourceReferences",.array(source.map(JSONValue.string)))])
        let bundle = try AeostaraContract.PolicyBundle(policyBundleID:bundleID,sourceReferences:source,rules:rules,bundleHash:CanonicalJSON.hash(identity))
        return (NativeHealingEngine(context:context,timestampProvider:timestampProvider,recorder:recorder,resourceIO:resourceIO,policies:registry,resources:resources,identifierProvider:identifierProvider),bundle)
    }
    private func preparation(configPath: String,desiredPath: String,invariantsPath: String?) throws -> (NativeDiagnosisPlan,AeostaraContract.PolicyDecision,[Invariant]) {
        let rules = try invariants(invariantsPath), (engine,bundle) = try makeEngine(invariants:rules)
        let observed = try CanonicalJSON.parse(fileSystem.readFile(path:configPath)),desired = try CanonicalJSON.parse(fileSystem.readFile(path:desiredPath))
        let prepared = try engine.prepare(observed:observed,desired:desired)
        let decision = try engine.policyRegistry!.decide(bundle:bundle,input:.init(plan:prepared.dryRunResult.recoveryPlan,observed:observed,resources:resources),diagnostic:prepared.mapping.diagnosticReferences[0])
        return (prepared,decision,rules)
    }
    public func validate(configPath: String,desiredPath: String,invariantsPath: String?) throws -> ValidationResult {
        _ = try requireContext()
        let rules = try invariants(invariantsPath)
        // Observation errors have a truthful validation result; semantic/policy failures remain typed errors.
        do { _ = try CanonicalJSON.parse(fileSystem.readFile(path:configPath));_ = try CanonicalJSON.parse(fileSystem.readFile(path:desiredPath)) }
        catch { return .init(valid:false,errors:["Cannot load config or desired JSON"],drifts:[],violations:[]) }
        let (prepared,decision,_) = try preparation(configPath:configPath,desiredPath:desiredPath,invariantsPath:invariantsPath)
        let observed = try CanonicalJSON.parse(fileSystem.readFile(path:configPath))
        let violations = rules.filter { !policyEvaluator.evaluateExpression($0.expression,document:observed) }.map { "Invariant violated: "+$0.name }
        return .init(valid:prepared.stateClass == .STABLE && violations.isEmpty && decision.decision == .ALLOW,
                     errors:decision.decision == .ALLOW ? [] : ["Policy blocked"],drifts:surfaceDrifts(prepared),violations:violations,semanticResult:prepared.dryRunResult)
    }
    public func diff(configPath: String,desiredPath: String,invariantsPath: String?) throws -> DiffResult {
        _ = try requireContext()
        let (prepared,decision,_) = try preparation(configPath:configPath,desiredPath:desiredPath,invariantsPath:invariantsPath)
        guard decision.decision == .ALLOW else { throw try failure(.policyBlocked) }
        return .init(drifts:surfaceDrifts(prepared),proposedPlan:legacyPlan(prepared.dryRunResult.recoveryPlan),semanticResult:prepared.dryRunResult)
    }
    public func heal(configPath: String,desiredPath: String,invariantsPath: String?,auditPath: String) throws -> HealResult {
        _ = try requireContext()
        guard operationGuard.try() else { throw try failure(.resourceBusy) };defer { operationGuard.unlock() }
        let rules = try invariants(invariantsPath), (engine,bundle) = try makeEngine(invariants:rules)
        guard let resources,resources.configuration == configPath,resources.desired == desiredPath,resources.audit == auditPath,resourceIO != nil else { throw try failure(.missingSemanticContext) }
        let receipt = try engine.heal(resources:resources,policyBundle:bundle)
        if receipt.safeHalt != nil { terminal = LifecycleFailure(code:.terminalHalt,diagnosticChain:receipt.result.diagnosticChain,auditChain:receipt.result.auditChain) }
        let succeeded = receipt.result.status == .HEALED || receipt.result.status == .NO_ACTION
        let verification = receipt.verification.map { VerificationResult(success:$0.status == .PASSED,failedChecks:$0.status == .PASSED ? [] : ["Native verification failed"],verifiedAt:timestampProvider()) }
        let rollback: RollbackPlan? = receipt.rollback?.status == .SUCCEEDED ? receipt.backup.map { RollbackPlan(planID:receipt.result.recoveryPlan.recoveryPlanID,backupFilePath:$0.backupRecord.storageReference,originalFilePath:configPath) } : nil
        let message = receipt.result.status == .NO_ACTION ? "No semantic recovery required" : (receipt.result.status == .BLOCKED ? "Policy blocked" : (succeeded ? "Heal successful after STABLE verification" : (rollback != nil ? "Recovery failed; exact backup rolled back" : "Recovery failed: "+receipt.result.status.rawValue)))
        return .init(success:succeeded,executedPlan:legacyPlan(receipt.result.recoveryPlan),verification:verification,rollback:rollback,auditEvents:[],message:message,nativeResult:receipt.result,nativeBackup:receipt.backup)
    }
    private func legacyPlan(_ plan: AeostaraContract.RecoveryPlan) -> RepairPlan? {
        guard plan.planDisposition == .MUTATION_REQUIRED else { return nil }
        let actions = plan.recoverySteps.flatMap(\.jsonMutationOperations).filter { $0.op != .test }.map { operation in
            RepairAction(keyPath:operation.path.pointer,actionType:operation.op == .remove ? .remove : (operation.op == .add ? .add : .set),fromValue:nil,toValue:operation.value.map(AnyCodable.init),rationale: "Validated native semantic operation")
        }
        return .init(planID:plan.recoveryPlanID,actions:actions,timestamp:plan.createdAt,requiresBackup:plan.requiresBackup)
    }
    private func surfaceDrifts(_ prepared: NativeDiagnosisPlan) -> [DriftEvent] {
        prepared.observedState.surfaceDifferences.map { difference in
            DriftEvent(keyPath:difference.path.pointer,type:difference.differenceKind == .MISSING ? .keyAdded : (difference.differenceKind == .REMOVED ? .keyRemoved : .valueChanged),observedValue:(try? JSONPointer(difference.path.pointer))?.resolve(in:prepared.observedDocument).map(AnyCodable.init),desiredValue:(try? JSONPointer(difference.path.pointer))?.resolve(in:prepared.desiredDocument).map(AnyCodable.init),description:"Surface evidence at "+difference.path.pointer)
        }
    }
}
