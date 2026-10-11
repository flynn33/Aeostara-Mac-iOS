import Foundation
import AeostaraMacDomain

/// A declared CLI application composition. This adapter accepts only named, explicit mappings.
/// The context file is a native consumer format; it does not extend the frozen upstream DTOs.
public final class NativeCLIContext: IHealingEngine {
    public let context: SemanticContext
    public let resourceRoot: URL
    private let lifecycle: NativeLegacyLifecycle
    public init(data: Data) throws {
        let input = try JSONValue.parse(data)
        guard case .object(let fields) = input,
              Set(fields.map(\.name)) == Set(["formatVersion", "applicationScope", "resourceRoot", "projectionSpec", "intentConstraints", "knownValidStates", "mappings", "inputDiagnosticChains", "policy"]),
              input.member("formatVersion") == .integer("1"), case .string(let scope) = input.member("applicationScope"),
              case .string(let root) = input.member("resourceRoot"), root.hasPrefix("/"),
              let specValue = input.member("projectionSpec"),
              case .object = input.member("intentConstraints"), case .array(let pointers) = input.member("intentConstraints")?.member("pointers"),
              case .array(let intentSources) = input.member("intentConstraints")?.member("sourceReferences"),
              case .array(let states) = input.member("knownValidStates")?.member("states"), case .array(let knownSources) = input.member("knownValidStates")?.member("sourceReferences"),
              case .array(let mappings) = input.member("mappings"), case .array(let chains) = input.member("inputDiagnosticChains"),
              case .object(let policyFields) = input.member("policy"), Set(policyFields.map(\.name)) == Set(["identifier", "sourceReference", "mode"]),
              case .string(let policyID) = input.member("policy")?.member("identifier"), case .string(let policySource) = input.member("policy")?.member("sourceReference"),
              case .string(let policyMode) = input.member("policy")?.member("mode"), ["ALLOW_SCOPED_RECOVERY", "DENY", "REQUIRE_INVARIANTS"].contains(policyMode) else { throw ProjectionProblem.invalidContext }
        func strings(_ values: [JSONValue]) throws -> [String] {
            try values.map { guard case .string(let value) = $0, !value.isEmpty else { throw ProjectionProblem.invalidContext }; return value }
        }
        let rules: [any SemanticMappingRule] = try mappings.map { value in
            guard case .object(let fields) = value, Set(fields.map(\.name)) == Set(["identifier", "sourceReference", "kind"]),
                  case .string(let id) = value.member("identifier"), case .string(let source) = value.member("sourceReference"), case .string(let kind) = value.member("kind") else { throw ProjectionProblem.invalidContext }
            if kind == "BOOLEAN_IDENTITY" { return BooleanMappingRule(identifier: id, sourceReference: source) }
            if kind == "ROOT_DOCUMENT_INTENT_MATCH" { return ExplicitRootIntentMapping(identifier: id, sourceReference: source) }
            throw ProjectionProblem.unknownMappingRule
        }
        context = try .init(applicationScope: scope, projectionSpec: .init(contractJSON: specValue),
            intentConstraints: .init(scopeID: scope, pointers: pointers.map { guard case .string(let value) = $0 else { throw ProjectionProblem.invalidContext }; return value }, sourceReferences: strings(intentSources)),
            knownValidStates: .init(scopeID: scope, states: states.map { state in
                guard case .array(let bits) = state else { throw ProjectionProblem.invalidContext }
                return try bits.map { guard case .integer(let value) = $0, let bit = Int(value) else { throw ProjectionProblem.invalidContext }; return bit }
            }, sourceReferences: strings(knownSources)), mappingRules: rules,
            inputDiagnosticChains: chains.map { try .init(contractJSON: $0) })
        resourceRoot = URL(fileURLWithPath: root, isDirectory: true).resolvingSymlinksInPath()
        let boundContext = context, declaredRoot = resourceRoot
        lifecycle = NativeLegacyLifecycle(context: boundContext, resourceFactory: { configuration, desired, audit in
            let config = URL(fileURLWithPath: configuration).resolvingSymlinksInPath(), intent = URL(fileURLWithPath: desired).resolvingSymlinksInPath()
            let auditURL = audit.map { path in let original = URL(fileURLWithPath: path); return original.deletingLastPathComponent().resolvingSymlinksInPath().appendingPathComponent(original.lastPathComponent) } ?? declaredRoot.appendingPathComponent(".aeostara-readonly-audit.jsonl")
            return try ScopedNativeResourceIO(paths: .init(root: declaredRoot, configuration: config, desired: intent,
                backup: config.appendingPathExtension("aeostara-backup"), audit: auditURL))
        }, policyFactory: { invariants, _, _ in
            let rule = try NativePolicyRule(identifier: policyID, sourceReference: policySource) { _, observed, planned in
                if policyMode == "DENY" { return false }
                if invariants == nil { return policyMode != "REQUIRE_INVARIANTS" }
                let bytes = try Data(contentsOf: URL(fileURLWithPath: invariants!))
                return try Self.invariantsPermit(bytes, observed: observed.value, planned: planned.value)
            }
            return try NativePolicyContext.make(bundleID: "cli-" + policyID, rules: [rule])
        })
    }
    public func validate(configPath: String, desiredPath: String, invariantsPath: String?) throws -> ValidationResult {
        try lifecycle.validate(configPath: configPath, desiredPath: desiredPath, invariantsPath: invariantsPath, semanticContext: context)
    }
    public func diff(configPath: String, desiredPath: String, invariantsPath: String?) throws -> DiffResult {
        try lifecycle.diff(configPath: configPath, desiredPath: desiredPath, invariantsPath: invariantsPath, semanticContext: context)
    }
    public func heal(configPath: String, desiredPath: String, invariantsPath: String?, auditPath: String) throws -> HealResult {
        try lifecycle.heal(configPath: configPath, desiredPath: desiredPath, invariantsPath: invariantsPath, auditPath: auditPath, semanticContext: context)
    }
    private static func invariantsPermit(_ data: Data, observed: JSONValue, planned: JSONValue) throws -> Bool {
        guard case .array(let rules) = try JSONValue.parse(data), !rules.isEmpty else { throw ProjectionProblem.invalidContext }
        for entry in rules {
            guard case .string(let id) = entry.member("invariant_id"), !id.isEmpty,
                  case .string(let severity) = entry.member("severity"), ["critical", "high", "medium", "low"].contains(severity),
                  case .bool(let auto) = entry.member("auto_remediate"), case .string(let expression) = entry.member("expression"),
                  let range = expression.range(of: " == ") else { throw ProjectionProblem.invalidContext }
            // This named CLI policy grammar explicitly declares dot-separated object keys and JSON literals.
            let names = expression[..<range.lowerBound].split(separator: ".", omittingEmptySubsequences: false)
            guard !names.isEmpty, names.allSatisfy({ !$0.isEmpty }) else { throw ProjectionProblem.invalidContext }
            let pointer = "/" + names.map { $0.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(of: "/", with: "~1") }.joined(separator: "/")
            let wanted = try JSONValue.parse(Data(expression[range.upperBound...].utf8))
            let before = try observed.resolve(pointer: pointer), after = try planned.resolve(pointer: pointer)
            if after != wanted || (severity == "critical" && before != wanted) || (!auto && before != wanted) { return false }
        }
        return true
    }
}

/// Consumer-selected root-document equivalence. It maps b0..b3 to mismatch and b4..b8 to zero;
/// that declaration must be explicitly named in every dimension binding. The SDK selects no mapping.
private struct ExplicitRootIntentMapping: SemanticMappingRule {
    let identifier: String
    let sourceReference: String
    func candidates(binding: AeostaraContract.SemanticDimensionBinding, evidence: [PointerObservation], desired: JSONSnapshot) throws -> [Int] {
        guard evidence.count == 1, evidence[0].pointer == "", let root = evidence[0].value,
              let coordinate = Int(binding.dimensionID.rawValue.dropFirst()) else { throw ProjectionProblem.malformedEvidence }
        return [coordinate < 4 && root != desired.value ? 1 : 0]
    }
    func materialize(binding: AeostaraContract.SemanticDimensionBinding, targetBit: Int, observed: JSONSnapshot, desired: JSONSnapshot) throws -> [MutationDraft] {
        guard binding.sourcePointers.count == 1, binding.sourcePointers[0].pointer == "", targetBit == 0 else { throw ProjectionProblem.missingMaterialization }
        return [.init(op: .replace, pointer: "", value: desired.value)]
    }
}
