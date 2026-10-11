import Foundation
import CryptoKit

public enum CanonicalJSONError: Error, Equatable {
    case malformedJSON
    case duplicateMember
    case unsupportedCanonicalNumber
    case invalidPointer
    case missingPointer
    case invalidContract(String)
}

public struct JSONMember: Codable, Equatable {
    public let name: String
    public let value: JSONValue
    public init(_ name: String, _ value: JSONValue) { self.name = name; self.value = value }
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.name.utf8.elementsEqual(rhs.name.utf8) && lhs.value == rhs.value
    }
}

/// Objects retain decoded UTF-8 member identity; the canonical codec never uses a String dictionary.
public indirect enum JSONValue: Equatable, Codable {
    case null, bool(Bool), integer(String), real(String), string(String)
    case array([JSONValue]), object([JSONMember])

    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null): return true
        case let (.bool(a), .bool(b)): return a == b
        case let (.integer(a), .integer(b)), let (.string(a), .string(b)):
            return a.utf8.elementsEqual(b.utf8)
        case let (.real(a), .real(b)):
            if let left = try? Self.number(a, floating: true), let right = try? Self.number(b, floating: true) {
                return left.utf8.elementsEqual(right.utf8)
            }
            return a.utf8.elementsEqual(b.utf8)
        case let (.array(a), .array(b)): return a == b
        case let (.object(a), .object(b)):
            return a.sorted(by: Self.memberOrder) == b.sorted(by: Self.memberOrder)
        default: return false
        }
    }
    private static func memberOrder(_ a: JSONMember, _ b: JSONMember) -> Bool {
        a.name.utf8.lexicographicallyPrecedes(b.name.utf8)
    }

    public static func parse(_ data: Data) throws -> JSONValue {
        try parse(data, permitsUnboundedIntegerTokens: false)
    }
    static func parseContractInput(_ data: Data) throws -> JSONValue {
        try parse(data, permitsUnboundedIntegerTokens: true)
    }
    private static func parse(_ data: Data, permitsUnboundedIntegerTokens: Bool) throws -> JSONValue {
        var parser = JSONParser(bytes: Array(data), permitsUnboundedIntegerTokens: permitsUnboundedIntegerTokens)
        let value = try parser.value()
        parser.space()
        guard parser.index == parser.bytes.count else { throw CanonicalJSONError.malformedJSON }
        return value
    }
    func validateLexicalStructure() throws {
        switch self {
        case .integer(let token):
            try Self.validateNumberLexeme(token, floating: false)
        case .real(let token):
            try Self.validateNumberLexeme(token, floating: true)
        case .array(let values):
            for value in values { try value.validateLexicalStructure() }
        case .object(let members):
            var names: [[UInt8]] = []
            for member in members {
                let name = Array(member.name.utf8)
                guard !names.contains(name) else { throw CanonicalJSONError.duplicateMember }
                names.append(name)
                try member.value.validateLexicalStructure()
            }
        default: break
        }
    }
    public func canonicalData() throws -> Data { Data(try canonicalText().utf8) }
    public func canonicalHash() throws -> String {
        SHA256.hash(data: try canonicalData()).map { String(format: "%02x", $0) }.joined()
    }
    public func canonicalText() throws -> String {
        switch self {
        case .null: return "null"
        case .bool(let value): return value ? "true" : "false"
        case .integer(let value): return try Self.number(value, floating: false)
        case .real(let value): return try Self.number(value, floating: true)
        case .string(let value): return Self.quoted(value)
        case .array(let values): return "[" + (try values.map { try $0.canonicalText() }.joined(separator: ",")) + "]"
        case .object(let members):
            var names: [[UInt8]] = []
            for member in members {
                let name = Array(member.name.utf8)
                guard !names.contains(name) else { throw CanonicalJSONError.duplicateMember }
                names.append(name)
            }
            return "{" + (try members.sorted(by: Self.memberOrder).map {
                Self.quoted($0.name) + ":" + (try $0.value.canonicalText())
            }.joined(separator: ",")) + "}"
        }
    }
    private static func quoted(_ text: String) -> String {
        var result = "\""
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 34: result += "\\\""
            case 92: result += "\\\\"
            case 8: result += "\\b"
            case 12: result += "\\f"
            case 10: result += "\\n"
            case 13: result += "\\r"
            case 9: result += "\\t"
            case 0..<32: result += String(format: "\\u%04x", scalar.value)
            default: result.unicodeScalars.append(scalar)
            }
        }
        return result + "\""
    }
    private static func validateNumberLexeme(_ text: String, floating: Bool) throws {
        let pattern = "^-?(0|[1-9][0-9]*)(\\.[0-9]+)?([eE][+-]?[0-9]+)?$"
        guard text.range(of: pattern, options: .regularExpression) != nil else {
            throw CanonicalJSONError.unsupportedCanonicalNumber
        }
        if !floating {
            guard !text.contains(".") && !text.lowercased().contains("e") else { throw CanonicalJSONError.unsupportedCanonicalNumber }
        }
    }
    private static func number(_ text: String, floating: Bool) throws -> String {
        try validateNumberLexeme(text, floating: floating)
        if !floating { return text == "-0" ? "0" : text }
        guard let value = Double(text), value.isFinite else { throw CanonicalJSONError.unsupportedCanonicalNumber }
        if value == 0 { return value.sign == .minus ? "-0.0" : "0.0" }
        var repr = String(abs(value)).lowercased()
        let pieces = repr.split(separator: "e")
        let exponent = pieces.count == 2 ? Int(pieces[1])! : 0
        repr = String(pieces[0])
        let decimal = repr.firstIndex(of: ".")
        let before = decimal.map { repr.distance(from: repr.startIndex, to: $0) } ?? repr.count
        var digits = repr.filter { $0 != "." }
        var point = before + exponent
        while digits.first == "0" { digits.removeFirst(); point -= 1 }
        while digits.last == "0" { digits.removeLast() }
        let scientificExponent = point - 1
        let sign = value.sign == .minus ? "-" : ""
        if (-4..<16).contains(scientificExponent) {
            if point <= 0 { return sign + "0." + String(repeating: "0", count: -point) + digits }
            if point >= digits.count { return sign + digits + String(repeating: "0", count: point - digits.count) + ".0" }
            let split = digits.index(digits.startIndex, offsetBy: point)
            return sign + digits[..<split] + "." + digits[split...]
        }
        let mantissa = digits.count == 1 ? digits : String(digits.prefix(1)) + "." + digits.dropFirst()
        let exp = String(format: "%02d", abs(scientificExponent))
        return sign + mantissa + "e" + (scientificExponent < 0 ? "-" : "+") + exp
    }

    public func member(_ name: String) -> JSONValue? {
        guard case .object(let values) = self else { return nil }
        return values.first { $0.name.utf8.elementsEqual(name.utf8) }?.value
    }
    public func resolve(pointer: String) throws -> JSONValue? {
        var cursor = self
        for token in try Self.pointerTokens(pointer) {
            switch cursor {
            case .object: guard let value = cursor.member(token) else { return nil }; cursor = value
            case .array(let values):
                guard token == "0" || (token.first.map { "123456789".contains($0) } == true && token.allSatisfy(\.isNumber)),
                      let index = Int(token), values.indices.contains(index) else { return nil }
                cursor = values[index]
            default: return nil
            }
        }
        return cursor
    }
    public static func pointerTokens(_ pointer: String) throws -> [String] {
        if pointer.isEmpty { return [] }
        guard pointer.first == "/" else { throw CanonicalJSONError.invalidPointer }
        return try pointer.dropFirst().split(separator: "/", omittingEmptySubsequences: false).map { token in
            let bytes = Array(token.utf8); var result: [UInt8] = []; var i = 0
            while i < bytes.count {
                if bytes[i] == 126 {
                    guard i + 1 < bytes.count, bytes[i + 1] == 48 || bytes[i + 1] == 49 else { throw CanonicalJSONError.invalidPointer }
                    result.append(bytes[i + 1] == 48 ? 126 : 47); i += 2
                } else { result.append(bytes[i]); i += 1 }
            }
            return String(decoding: result, as: UTF8.self)
        }
    }

    public func applying(_ draft: MutationDraft) throws -> JSONValue {
        let tokens = try Self.pointerTokens(draft.pointer)
        if draft.op == .test {
            guard let expected = draft.value, try resolve(pointer: draft.pointer) == expected else { throw CanonicalJSONError.invalidContract("test precondition") }
            return self
        }
        func update(_ node: JSONValue, _ remaining: ArraySlice<String>) throws -> JSONValue {
            guard let token = remaining.first else {
                guard draft.op != .remove, let value = draft.value else { throw CanonicalJSONError.invalidPointer }
                _ = try value.canonicalData(); return value
            }
            let tail = remaining.dropFirst()
            switch node {
            case .object(var members):
                let index = members.firstIndex { $0.name.utf8.elementsEqual(token.utf8) }
                if tail.isEmpty {
                    if draft.op == .remove { guard let index else { throw CanonicalJSONError.missingPointer }; members.remove(at: index) }
                    else {
                        guard let value = draft.value else { throw CanonicalJSONError.invalidContract("mutation value required") }
                        if let index { members[index] = JSONMember(token, value) }
                        else { guard draft.op == .add else { throw CanonicalJSONError.missingPointer }; members.append(JSONMember(token, value)) }
                    }
                } else {
                    guard let index else { throw CanonicalJSONError.missingPointer }
                    members[index] = JSONMember(token, try update(members[index].value, tail))
                }
                return .object(members)
            case .array(var values):
                if token == "-", tail.isEmpty, draft.op == .add, let value = draft.value { values.append(value); return .array(values) }
                guard token == "0" || token.range(of: "^[1-9][0-9]*$", options: .regularExpression) != nil,
                      let index = Int(token), index >= 0 else { throw CanonicalJSONError.invalidPointer }
                if tail.isEmpty && draft.op == .add {
                    guard index <= values.count, let value = draft.value else { throw CanonicalJSONError.invalidPointer }; values.insert(value, at: index)
                } else {
                    guard values.indices.contains(index) else { throw CanonicalJSONError.missingPointer }
                    if tail.isEmpty && draft.op == .remove { values.remove(at: index) }
                    else { values[index] = try update(values[index], tail) }
                }
                return .array(values)
            default: throw CanonicalJSONError.invalidPointer
            }
        }
        let result = try update(self, tokens[...]); _ = try result.canonicalData(); return result
    }

    // Foundation Codable is an interoperability path; ContractCoding preserves free-JSON identity.
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Int64.self) { self = .integer(String(v)) }
        else if let v = try? c.decode(Double.self) { self = .real(try Self.number(String(v), floating: true)) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self).map { JSONMember($0.key, $0.value) }) }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .integer(let v): guard let n = Int64(v) else { throw CanonicalJSONError.unsupportedCanonicalNumber }; try c.encode(n)
        case .real(let v): guard let n = Double(v), n.isFinite else { throw CanonicalJSONError.unsupportedCanonicalNumber }; try c.encode(n)
        case .array(let v): try c.encode(v)
        case .object(let v):
            var result: [String: JSONValue] = [:]
            for member in v {
                guard result[member.name] == nil else { throw CanonicalJSONError.duplicateMember }
                result[member.name] = member.value
            }
            try c.encode(result)
        }
    }
}

private struct JSONParser {
    let bytes: [UInt8]
    let permitsUnboundedIntegerTokens: Bool
    var index = 0
    mutating func space() { while index < bytes.count && [9,10,13,32].contains(bytes[index]) { index += 1 } }
    mutating func take(_ byte: UInt8) -> Bool {
        space(); guard index < bytes.count && bytes[index] == byte else { return false }; index += 1; return true
    }
    mutating func value() throws -> JSONValue {
        space(); guard index < bytes.count else { throw CanonicalJSONError.malformedJSON }
        if bytes[index] == 34 { return .string(try string()) }
        if take(123) {
            var members: [JSONMember] = []
            if take(125) { return .object(members) }
            repeat {
                let name = try string()
                guard !members.contains(where: { $0.name.utf8.elementsEqual(name.utf8) }) else { throw CanonicalJSONError.duplicateMember }
                guard take(58) else { throw CanonicalJSONError.malformedJSON }
                members.append(JSONMember(name, try value()))
                if take(125) { return .object(members) }
            } while take(44)
            throw CanonicalJSONError.malformedJSON
        }
        if take(91) {
            var values: [JSONValue] = []
            if take(93) { return .array(values) }
            repeat { values.append(try value()); if take(93) { return .array(values) } } while take(44)
            throw CanonicalJSONError.malformedJSON
        }
        for (literal, value) in [("null", JSONValue.null), ("true", .bool(true)), ("false", .bool(false))] {
            let token = Array(literal.utf8)
            if bytes[index...].starts(with: token) { index += token.count; return value }
        }
        let start = index
        while index < bytes.count && [45,43,46,69,101].contains(bytes[index]) || (index < bytes.count && (48...57).contains(bytes[index])) { index += 1 }
        guard index > start else { throw CanonicalJSONError.malformedJSON }
        let text = String(decoding: bytes[start..<index], as: UTF8.self)
        let candidate: JSONValue = text.contains(".") || text.lowercased().contains("e") ? .real(text) : .integer(text)
        try candidate.validateLexicalStructure()
        if case .real = candidate {
            // Schema integer admission must see the original digits, before floating canonicalization.
            if !permitsUnboundedIntegerTokens { _ = try candidate.canonicalText() }
            return candidate
        }
        return .integer(try candidate.canonicalText())
    }
    mutating func string() throws -> String {
        guard take(34) else { throw CanonicalJSONError.malformedJSON }
        var result: [UInt8] = []
        while index < bytes.count {
            let byte = bytes[index]; index += 1
            if byte == 34 {
                guard let text = String(bytes: result, encoding: .utf8) else { throw CanonicalJSONError.malformedJSON }; return text
            }
            if byte == 92 {
                guard index < bytes.count else { throw CanonicalJSONError.malformedJSON }
                let escape = bytes[index]; index += 1
                switch escape {
                case 34,47,92: result.append(escape)
                case 98: result.append(8)
                case 102: result.append(12)
                case 110: result.append(10)
                case 114: result.append(13)
                case 116: result.append(9)
                case 117:
                    var scalar = try hex()
                    if (0xD800...0xDBFF).contains(scalar) {
                        guard index + 2 <= bytes.count && bytes[index] == 92 && bytes[index + 1] == 117 else { throw CanonicalJSONError.malformedJSON }
                        index += 2; let low = try hex()
                        guard (0xDC00...0xDFFF).contains(low) else { throw CanonicalJSONError.malformedJSON }
                        scalar = 0x10000 + (scalar - 0xD800) * 1024 + low - 0xDC00
                    }
                    guard let unicode = UnicodeScalar(scalar) else { throw CanonicalJSONError.malformedJSON }
                    result.append(contentsOf: String(unicode).utf8)
                default: throw CanonicalJSONError.malformedJSON
                }
            } else {
                guard byte >= 32 else { throw CanonicalJSONError.malformedJSON }; result.append(byte)
            }
        }
        throw CanonicalJSONError.malformedJSON
    }
    mutating func hex() throws -> UInt32 {
        guard index + 4 <= bytes.count,
              bytes[index..<index+4].allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }),
              let value = UInt32(String(decoding: bytes[index..<index+4], as: UTF8.self), radix: 16) else { throw CanonicalJSONError.malformedJSON }
        index += 4; return value
    }
}

/// Exact mathematical integer for the frozen schema's unbounded audit sequence.
/// Integral decimal/exponent JSON tokens are admitted without a Double conversion or clamping.
public struct ContractInteger: ContractValue, Equatable, CustomStringConvertible, ExpressibleByIntegerLiteral {
    public let description: String
    public var intValue: Int? { Int(description) }
    public init(_ value: Int) { description = String(value) }
    public init(integerLiteral value: Int) { self.init(value) }
    public init(contractJSON: JSONValue) throws {
        let token: String
        switch contractJSON { case .integer(let value), .real(let value): token = value; default: throw CanonicalJSONError.invalidContract("integer required") }
        guard token.range(of: "^-?(0|[1-9][0-9]*)(\\.[0-9]+)?([eE][+-]?[0-9]+)?$", options: .regularExpression) != nil else { throw CanonicalJSONError.invalidContract("integer token") }
        let negative = token.first == "-", unsigned = negative ? String(token.dropFirst()) : token
        let parts = unsigned.lowercased().split(separator: "e", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { throw CanonicalJSONError.invalidContract("integer token") }
        let mantissa = String(parts[0]), decimal = mantissa.split(separator: ".", omittingEmptySubsequences: false)
        let fractionalCount = decimal.count == 2 ? decimal[1].count : 0
        var digits = decimal.joined()
        while digits.count > 1 && digits.first == "0" { digits.removeFirst() }
        if digits.allSatisfy({ $0 == "0" }) { description = "0"; return }
        guard let exponent = parts.count == 1 ? 0 : Int(parts[1]), exponent >= Int.min + fractionalCount else { throw CanonicalJSONError.unsupportedCanonicalNumber }
        let shift = exponent - fractionalCount
        if shift >= 0 {
            // Resource exhaustion is an explicit failure channel, not a false/schema-invalid value.
            guard shift <= 16 * 1024 * 1024 else { throw CanonicalJSONError.unsupportedCanonicalNumber }
            digits += String(repeating: "0", count: shift)
        } else {
            guard shift != Int.min, -shift < digits.count, digits.suffix(-shift).allSatisfy({ $0 == "0" }) else { throw CanonicalJSONError.invalidContract("non-integral number") }
            digits.removeLast(-shift)
        }
        description = (negative ? "-" : "") + digits
    }
    public var contractJSON: JSONValue { .integer(description) }
    public init(from decoder: Decoder) throws { try self.init(contractJSON: JSONValue(from: decoder)) }
    public func encode(to encoder: Encoder) throws { try contractJSON.encode(to: encoder) }
}
