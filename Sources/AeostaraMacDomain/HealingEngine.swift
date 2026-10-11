// Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.
import Foundation

/// Legacy signatures delegate to an explicitly bound native semantic lifecycle.
public final class HealingEngine: IHealingEngine {
    private let semanticContext: SemanticContext?
    private let nativeLifecycle: (any LegacySemanticLifecycle)?
    public init(adapter: IConfigAdapter, backupManager: IBackupProvider, driftAnalyzer: DriftAnalyzer,
                repairPlanner: RepairPlanner, policyEvaluator: PolicyEvaluator, invariantParser: InvariantParser,
                verification: Verification, rollbackManager: RollbackManager, fileSystem: IFileSystem,
                timestampProvider: @escaping () -> String, eventIDProvider: @escaping () -> String,
                semanticContext: SemanticContext? = nil, nativeLifecycle: (any LegacySemanticLifecycle)? = nil) {
        self.semanticContext = semanticContext; self.nativeLifecycle = nativeLifecycle
    }
    private func binding() throws -> (SemanticContext, any LegacySemanticLifecycle) {
        guard let context = semanticContext, let lifecycle = nativeLifecycle else { throw try LifecycleFailure.missingContext() }
        return (context, lifecycle)
    }
    public func validate(configPath: String, desiredPath: String, invariantsPath: String?) throws -> ValidationResult {
        let (context, lifecycle) = try binding()
        return try lifecycle.validate(configPath: configPath, desiredPath: desiredPath, invariantsPath: invariantsPath, semanticContext: context)
    }
    public func diff(configPath: String, desiredPath: String, invariantsPath: String?) throws -> DiffResult {
        let (context, lifecycle) = try binding()
        return try lifecycle.diff(configPath: configPath, desiredPath: desiredPath, invariantsPath: invariantsPath, semanticContext: context)
    }
    public func heal(configPath: String, desiredPath: String, invariantsPath: String?, auditPath: String) throws -> HealResult {
        let (context, lifecycle) = try binding()
        return try lifecycle.heal(configPath: configPath, desiredPath: desiredPath, invariantsPath: invariantsPath, auditPath: auditPath, semanticContext: context)
    }
}
