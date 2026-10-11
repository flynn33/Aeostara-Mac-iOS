import Foundation
import CryptoKit

public enum CanonicalJSONError: Error, Equatable {
    case malformedJSON, duplicateMember, invalidPointer, missingValue, invalidOperation
    case unsupportedNumber, unexpectedType, invalidContract(String)
}

public struct JSONMember: Equatable {
    public let name: String
    public let value: JSONValue
    public init(_ name: String, _ value: JSONValue) { self.name = name; self.value = value }
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.name.utf8.elementsEqual(rhs.name.utf8) && lhs.value == rhs.value
    }
}

public enum JSONNumber: Equatable {
    case integer(String)
    case real(Double)
    /// A decimal/exponent token retained before any binary floating-point conversion.
    case decimal(String)
    public var canonicalText: String {
        get throws {
            switch self {
            case .integer(let text):
                guard let parsed = try? CanonicalJSON.parse(Data(text.utf8)),
                      case .number(.integer(let normalized)) = parsed else { throw CanonicalJSONError.unsupportedNumber }
                return normalized
            case .real(let value):
                guard value.isFinite else { throw CanonicalJSONError.unsupportedNumber }
                return String(value)
            case .decimal(let token): return try ExactJSONDecimal(token).canonicalText
            }
        }
    }
    public static func == (lhs: Self, rhs: Self) -> Bool {
        if case .integer(let a) = lhs, case .integer(let b) = rhs { return a == b }
        if case .integer = lhs { return false }; if case .integer = rhs { return false }
        func exact(_ value: Self) -> ExactJSONDecimal? {
            switch value {
            case .real(let v): return v.isFinite ? try? ExactJSONDecimal(String(v)) : nil
            case .decimal(let token): return try? ExactJSONDecimal(token)
            case .integer: return nil
            }
        }
        guard let a = exact(lhs), let b = exact(rhs) else { return false }
        return a == b
    }
}

private struct ExactJSONDecimal: Equatable {
    let negative: Bool
    let coefficient: String
    let exponent: Int
    init(_ token: String) throws {
        guard token.range(of:#"^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$"#,options:.regularExpression) == token.startIndex..<token.endIndex else { throw CanonicalJSONError.unsupportedNumber }
        let sign = token.hasPrefix("-")
        let unsigned = sign ? String(token.dropFirst()) : token
        let pieces = unsigned.lowercased().split(separator:"e",omittingEmptySubsequences:false)
        let mantissa = pieces[0].split(separator:".",omittingEmptySubsequences:false)
        let fractionCount = mantissa.count == 2 ? mantissa[1].count : 0
        var digits = String(mantissa.joined().drop(while:{$0 == "0"}))
        if digits.isEmpty { negative = sign; coefficient = "0"; exponent = 0; return }
        guard let suppliedExponent = pieces.count == 2 ? Int(pieces[1]) : 0 else { throw CanonicalJSONError.unsupportedNumber }
        let (shift,overflow) = suppliedExponent.subtractingReportingOverflow(fractionCount)
        guard !overflow else { throw CanonicalJSONError.unsupportedNumber }
        var zeros = 0
        while digits.last == "0" { digits.removeLast(); zeros += 1 }
        let (normalizedExponent,normalizedOverflow) = shift.addingReportingOverflow(zeros)
        guard !normalizedOverflow else { throw CanonicalJSONError.unsupportedNumber }
        negative = sign; coefficient = digits; exponent = normalizedExponent
    }
    static func == (lhs: Self,rhs: Self) -> Bool {
        if lhs.coefficient == "0" && rhs.coefficient == "0" { return true }
        return lhs.negative == rhs.negative && lhs.coefficient == rhs.coefficient && lhs.exponent == rhs.exponent
    }
    var integerText: String {
        get throws {
            if coefficient == "0" { return "0" }
            guard exponent >= 0 else { throw CanonicalJSONError.unexpectedType }
            // Expansion is bounded by the native serialized-output limit; token classification is exact.
            guard exponent <= 16*1024*1024-coefficient.count else { throw CanonicalJSONError.unsupportedNumber }
            return (negative ? "-" : "") + coefficient + String(repeating:"0",count:exponent)
        }
    }
    var canonicalText: String {
        if coefficient == "0" { return negative ? "-0.0" : "0.0" }
        let sign = negative ? "-" : ""
        let (order,overflow) = exponent.addingReportingOverflow(coefficient.count-1)
        if overflow { return sign + coefficient + "e" + (exponent >= 0 ? "+" : "") + String(exponent) }
        let exact: String
        if order >= -6 && order <= 20 {
            if exponent >= 0 { exact = coefficient + String(repeating:"0",count:exponent) + ".0" }
            else if -exponent < coefficient.count {
                let split = coefficient.index(coefficient.endIndex,offsetBy:exponent)
                exact = String(coefficient[..<split]) + "." + String(coefficient[split...])
            } else { exact = "0." + String(repeating:"0",count:-exponent-coefficient.count) + coefficient }
        } else {
            let rest = coefficient.dropFirst()
            exact = String(coefficient.prefix(1)) + (rest.isEmpty ? "" : "."+rest) + "e" + (order >= 0 ? "+" : "") + String(order)
        }
        let token = sign + exact
        // Preserve the existing finite-real spelling only when it represents the exact retained decimal.
        if let value = Double(token), value.isFinite, let decoded = try? Self(String(value)), decoded == self { return String(value) }
        return token
    }
}

/// An exact, unbounded JSON integer. CanonicalContract codecs preserve all decimal digits.
public struct JSONInteger: Equatable, Comparable, Codable, CustomStringConvertible, ExpressibleByIntegerLiteral {
    public let decimalText: String
    public var description: String { decimalText }
    public var intValue: Int? { Int(decimalText) }
    public var jsonValue: JSONValue { .number(.integer(decimalText)) }
    public init(_ value: Int) { decimalText = String(value) }
    public init(integerLiteral value: Int) { self.init(value) }
    public init(decimalText: String) throws {
        guard case .number(.integer(let value)) = try CanonicalJSON.parse(decimalText) else { throw CanonicalJSONError.unexpectedType }
        self.decimalText = value
    }
    public init(jsonValue: JSONValue) throws {
        guard case .number(let number) = jsonValue else { throw CanonicalJSONError.unexpectedType }
        switch number {
        case .integer(let value): try self.init(decimalText:value)
        case .real(let value):
            guard value.isFinite else { throw CanonicalJSONError.unsupportedNumber }
            try self.init(decimalText:ExactJSONDecimal(String(value)).integerText)
        case .decimal(let token): try self.init(decimalText:ExactJSONDecimal(token).integerText)
        }
    }
    public static func < (lhs: Self,rhs: Self) -> Bool {
        let leftNegative = lhs.decimalText.hasPrefix("-"), rightNegative = rhs.decimalText.hasPrefix("-")
        if leftNegative != rightNegative { return leftNegative }
        let left = leftNegative ? String(lhs.decimalText.dropFirst()) : lhs.decimalText
        let right = rightNegative ? String(rhs.decimalText.dropFirst()) : rhs.decimalText
        if left.count != right.count { return leftNegative ? left.count > right.count : left.count < right.count }
        return leftNegative ? right.utf8.lexicographicallyPrecedes(left.utf8) : left.utf8.lexicographicallyPrecedes(right.utf8)
    }
    public init(from decoder: Decoder) throws { try self.init(jsonValue:JSONValue(from:decoder)) }
    public func encode(to encoder: Encoder) throws { try jsonValue.encode(to:encoder) }
}

public indirect enum JSONValue: Equatable, Codable {
    case null, bool(Bool), number(JSONNumber), string(String), array([JSONValue]), object([JSONMember])

    public func member(_ name: String) -> JSONValue? {
        guard case .object(let members) = self else { return nil }
        return members.first { $0.name.utf8.elementsEqual(name.utf8) }?.value
    }
    public var objectMembers: [JSONMember]? { if case .object(let value) = self { return value }; return nil }
    public var arrayValues: [JSONValue]? { if case .array(let value) = self { return value }; return nil }
    public var stringValue: String? { if case .string(let value) = self { return value }; return nil }
    public var boolValue: Bool? { if case .bool(let value) = self { return value }; return nil }
    public var integerValue: Int? { if case .number(.integer(let value)) = self { return Int(value) }; return nil }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null): return true
        case (.bool(let a), .bool(let b)): return a == b
        case (.number(let a), .number(let b)): return a == b
        case (.string(let a), .string(let b)): return a.utf8.elementsEqual(b.utf8)
        case (.array(let a), .array(let b)): return a == b
        case (.object(let a), .object(let b)):
            return a.sorted { $0.name.utf8.lexicographicallyPrecedes($1.name.utf8) }
                == b.sorted { $0.name.utf8.lexicographicallyPrecedes($1.name.utf8) }
        default: return false
        }
    }

    // Foundation Codable is a convenience boundary; exact canonical data uses ContractCoding/CanonicalJSON.
    public init(from decoder: Decoder) throws {
        let single = try decoder.singleValueContainer()
        if single.decodeNil() { self = .null; return }
        if let value = try? single.decode(Bool.self) { self = .bool(value); return }
        if let value = try? single.decode(Int64.self) { self = .number(.integer(String(value))); return }
        if let value = try? single.decode(Double.self) { guard value.isFinite else { throw CanonicalJSONError.unsupportedNumber }; self = .number(.real(value)); return }
        if let value = try? single.decode(String.self) { self = .string(value); return }
        if let value = try? single.decode([JSONValue].self) { self = .array(value); return }
        let container = try decoder.container(keyedBy: JSONCodingKey.self)
        self = .object(try container.allKeys.map { JSONMember($0.stringValue, try container.decode(JSONValue.self, forKey: $0)) })
    }
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .object(let members):
            var container = encoder.container(keyedBy: JSONCodingKey.self)
            for member in members { try container.encode(member.value, forKey: JSONCodingKey(member.name)) }
        default:
            var single = encoder.singleValueContainer()
            switch self {
            case .null: try single.encodeNil()
            case .bool(let value): try single.encode(value)
            case .number(.integer(let value)):
                guard let integer = Int64(value) else { throw CanonicalJSONError.unsupportedNumber }; try single.encode(integer)
            case .number(.real(let value)): guard value.isFinite else { throw CanonicalJSONError.unsupportedNumber }; try single.encode(value)
            case .number(.decimal(let token)):
                let exact = try ExactJSONDecimal(token)
                guard let value = Double(token), value.isFinite, try ExactJSONDecimal(String(value)) == exact else { throw CanonicalJSONError.unsupportedNumber }
                try single.encode(value)
            case .string(let value): try single.encode(value)
            case .array(let value): try single.encode(value)
            case .object: break
            }
        }
    }
}

private struct JSONCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil
    init(_ value: String) { stringValue = value }
    init?(stringValue: String) { self.init(stringValue) }
    init?(intValue: Int) { return nil }
}

public enum CanonicalJSON {
    public static func parse(_ data: Data) throws -> JSONValue { var parser = JSONParser(bytes: Array(data)); return try parser.parse() }
    public static func parse(_ text: String) throws -> JSONValue { try parse(Data(text.utf8)) }
    public static func encode(_ value: JSONValue) throws -> Data { Data(try text(value).utf8) }
    public static func hash(_ value: JSONValue) throws -> String {
        SHA256.hash(data: try encode(value)).map { String(format: "%02x", $0) }.joined()
    }
    public static func hashBytes(_ bytes: Data) -> String { SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() }
    public static func text(_ value: JSONValue) throws -> String {
        switch value {
        case .null: return "null"
        case .bool(let v): return v ? "true" : "false"
        case .number(let v): return try v.canonicalText
        case .string(let v): return quoted(v)
        case .array(let values): return "[" + (try values.map(text)).joined(separator: ",") + "]"
        case .object(let members):
            let sorted = members.sorted { $0.name.utf8.lexicographicallyPrecedes($1.name.utf8) }
            for i in sorted.indices.dropFirst() where sorted[i-1].name.utf8.elementsEqual(sorted[i].name.utf8) { throw CanonicalJSONError.duplicateMember }
            return "{" + (try sorted.map { quoted($0.name) + ":" + (try text($0.value)) }).joined(separator: ",") + "}"
        }
    }
    private static func quoted(_ value: String) -> String {
        var result = "\""
        for scalar in value.unicodeScalars {
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
}

private struct JSONParser {
    let bytes: [UInt8]
    var index = 0
    mutating func parse() throws -> JSONValue { let result = try value(); whitespace(); guard index == bytes.count else { throw CanonicalJSONError.malformedJSON }; return result }
    mutating func whitespace() { while index < bytes.count && [9,10,13,32].contains(bytes[index]) { index += 1 } }
    mutating func consume(_ byte: UInt8) -> Bool { whitespace(); guard index < bytes.count && bytes[index] == byte else { return false }; index += 1; return true }
    mutating func require(_ byte: UInt8) throws { guard consume(byte) else { throw CanonicalJSONError.malformedJSON } }
    mutating func value() throws -> JSONValue {
        whitespace(); guard index < bytes.count else { throw CanonicalJSONError.malformedJSON }
        switch bytes[index] {
        case 34: return .string(try string())
        case 123:
            index += 1; var members: [JSONMember] = []; var names = Set<Data>()
            if consume(125) { return .object([]) }
            repeat {
                let name = try string(); guard names.insert(Data(name.utf8)).inserted else { throw CanonicalJSONError.duplicateMember }
                try require(58); members.append(JSONMember(name, try value()))
                if consume(125) { return .object(members) }; try require(44)
            } while true
        case 91:
            index += 1; var values: [JSONValue] = []
            if consume(93) { return .array([]) }
            repeat { values.append(try value()); if consume(93) { return .array(values) }; try require(44) } while true
        case 116: try literal("true"); return .bool(true)
        case 102: try literal("false"); return .bool(false)
        case 110: try literal("null"); return .null
        case 45,48...57: return try number()
        default: throw CanonicalJSONError.malformedJSON
        }
    }
    mutating func literal(_ text: String) throws {
        let sequence = Array(text.utf8); guard index + sequence.count <= bytes.count && bytes[index..<index+sequence.count].elementsEqual(sequence) else { throw CanonicalJSONError.malformedJSON }; index += sequence.count
    }
    mutating func string() throws -> String {
        try require(34); var output: [UInt8] = []
        while index < bytes.count {
            let byte = bytes[index]; index += 1
            if byte == 34 { guard let string = String(bytes: output, encoding: .utf8) else { throw CanonicalJSONError.malformedJSON }; return string }
            guard byte >= 32 else { throw CanonicalJSONError.malformedJSON }
            if byte != 92 { output.append(byte); continue }
            guard index < bytes.count else { throw CanonicalJSONError.malformedJSON }; let escape = bytes[index]; index += 1
            switch escape {
            case 34,47,92: output.append(escape)
            case 98: output.append(8)
            case 102: output.append(12)
            case 110: output.append(10)
            case 114: output.append(13)
            case 116: output.append(9)
            case 117:
                var scalar = try hex4()
                if (0xd800...0xdbff).contains(scalar) {
                    guard index + 2 <= bytes.count && bytes[index] == 92 && bytes[index+1] == 117 else { throw CanonicalJSONError.malformedJSON }; index += 2
                    let low = try hex4(); guard (0xdc00...0xdfff).contains(low) else { throw CanonicalJSONError.malformedJSON }; scalar = 0x10000 + ((scalar-0xd800)<<10) + low-0xdc00
                }
                guard let decoded = UnicodeScalar(scalar) else { throw CanonicalJSONError.malformedJSON }; output.append(contentsOf: String(decoded).utf8)
            default: throw CanonicalJSONError.malformedJSON
            }
        }
        throw CanonicalJSONError.malformedJSON
    }
    mutating func hex4() throws -> UInt32 {
        guard index + 4 <= bytes.count else { throw CanonicalJSONError.malformedJSON }; var value: UInt32 = 0
        for _ in 0..<4 {
            let byte = bytes[index]; index += 1; let digit: UInt32
            switch byte { case 48...57: digit = UInt32(byte-48); case 65...70: digit = UInt32(byte-55); case 97...102: digit = UInt32(byte-87); default: throw CanonicalJSONError.malformedJSON }
            value = value * 16 + digit
        }
        return value
    }
    mutating func number() throws -> JSONValue {
        let start = index
        if bytes[index] == 45 { index += 1; guard index < bytes.count else { throw CanonicalJSONError.malformedJSON } }
        if bytes[index] == 48 { index += 1 } else {
            guard (49...57).contains(bytes[index]) else { throw CanonicalJSONError.malformedJSON }
            while index < bytes.count && (48...57).contains(bytes[index]) { index += 1 }
        }
        var real = false
        if index < bytes.count && bytes[index] == 46 {
            real = true; index += 1; let digits = index
            while index < bytes.count && (48...57).contains(bytes[index]) { index += 1 }
            guard index > digits else { throw CanonicalJSONError.malformedJSON }
        }
        if index < bytes.count && [69,101].contains(bytes[index]) {
            real = true; index += 1
            if index < bytes.count && [43,45].contains(bytes[index]) { index += 1 }
            let digits = index; while index < bytes.count && (48...57).contains(bytes[index]) { index += 1 }
            guard index > digits else { throw CanonicalJSONError.malformedJSON }
        }
        let text = String(decoding: bytes[start..<index], as: UTF8.self)
        if real { _ = try ExactJSONDecimal(text); return .number(.decimal(text)) }
        return .number(.integer(text == "-0" ? "0" : text))
    }
}

public struct JSONPointer: Equatable {
    public let tokens: [String]
    public init(_ pointer: String) throws {
        if pointer.isEmpty { tokens = []; return }
        guard pointer.first == "/" else { throw CanonicalJSONError.invalidPointer }
        tokens = try pointer.dropFirst().split(separator: "/", omittingEmptySubsequences: false).map { raw in
            var result = ""; var index = raw.startIndex
            while index < raw.endIndex {
                let character = raw[index]; index = raw.index(after: index)
                if character != "~" { result.append(character); continue }
                guard index < raw.endIndex else { throw CanonicalJSONError.invalidPointer }; let escape = raw[index]; index = raw.index(after: index)
                guard escape == "0" || escape == "1" else { throw CanonicalJSONError.invalidPointer }; result.append(escape == "0" ? "~" : "/")
            }
            return result
        }
    }
    public init(tokens: [String]) { self.tokens = tokens }
    public var text: String { tokens.isEmpty ? "" : "/" + tokens.map { $0.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(of: "/", with: "~1") }.joined(separator: "/") }
    public func resolve(in document: JSONValue) -> JSONValue? {
        var value = document
        for token in tokens {
            switch value {
            case .object: guard let child = value.member(token) else { return nil }; value = child
            case .array(let values): guard token == "0" || (!token.hasPrefix("0") && !token.isEmpty), token.utf8.allSatisfy({ (48...57).contains($0) }), let index = Int(token), values.indices.contains(index) else { return nil }; value = values[index]
            default: return nil
            }
        }
        return value
    }
}

public protocol CanonicalContract: Codable, Equatable {
    static var contractName: String { get }
    init(jsonValue: JSONValue) throws
    var jsonValue: JSONValue { get }
}
public extension CanonicalContract {
    static func == (lhs: Self,rhs: Self) -> Bool { lhs.jsonValue == rhs.jsonValue }
    init(from decoder: Decoder) throws { try self.init(jsonValue: JSONValue(from: decoder)) }
    func encode(to encoder: Encoder) throws { try jsonValue.encode(to: encoder) }
}
public enum ContractCoding {
    public static func canonicalEncode<T: CanonicalContract>(_ value: T) throws -> Data { try CanonicalJSON.encode(value.jsonValue) }
    public static func canonicalDecode<T: CanonicalContract>(_ type: T.Type, from data: Data) throws -> T { try T(jsonValue: CanonicalJSON.parse(data)) }
}

public extension JSONPointer {
    /// Applies a validated operation to an immutable document. Array order and empty members survive.
    func applying(_ op: AeostaraContract.JsonMutationOperation.OpValue, value: JSONValue?, to document: JSONValue) throws -> JSONValue {
        if op == .test { guard let value, resolve(in: document) == value else { throw CanonicalJSONError.invalidOperation }; return document }
        func index(_ token: String, count: Int, adding: Bool) throws -> Int {
            if token == "-", adding { return count }
            guard token == "0" || (!token.isEmpty && !token.hasPrefix("0")), token.utf8.allSatisfy({ (48...57).contains($0) }), let n = Int(token), n >= 0, n < count || (adding && n == count) else { throw CanonicalJSONError.invalidPointer }
            return n
        }
        func descend(_ current: JSONValue, _ remaining: ArraySlice<String>) throws -> JSONValue {
            guard let token = remaining.first else {
                guard op != .remove, let value else { throw CanonicalJSONError.invalidOperation }
                return value
            }
            let last = remaining.count == 1
            switch current {
            case .object(var members):
                let location = members.firstIndex { $0.name.utf8.elementsEqual(token.utf8) }
                if last {
                    if op == .remove { guard let location else { throw CanonicalJSONError.missingValue }; members.remove(at: location) }
                    else { guard let value, op == .add || location != nil else { throw CanonicalJSONError.missingValue }; if let location { members[location] = JSONMember(token,value) } else { members.append(JSONMember(token,value)) } }
                } else {
                    guard let location else { throw CanonicalJSONError.missingValue }
                    members[location] = JSONMember(token,try descend(members[location].value,remaining.dropFirst()))
                }
                return .object(members)
            case .array(var values):
                let n = try index(token,count:values.count,adding:last && op == .add)
                if last {
                    switch op {
                    case .add: guard let value else { throw CanonicalJSONError.invalidOperation }; values.insert(value,at:n)
                    case .replace: guard let value else { throw CanonicalJSONError.invalidOperation }; values[n] = value
                    case .remove: values.remove(at:n)
                    case .test: throw CanonicalJSONError.invalidOperation
                    }
                } else { values[n] = try descend(values[n],remaining.dropFirst()) }
                return .array(values)
            default: throw CanonicalJSONError.unexpectedType
            }
        }
        return try descend(document,tokens[...])
    }
}
