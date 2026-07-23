//
//  CSSColorParser.swift
//  Color Toolkit
//

import Foundation

/// The form a color was written in, so the UI can echo it back the same way.
nonisolated enum ColorNotation: Equatable, Sendable {
    case hex(digits: Int)
    case keyword(String)
    case function(ColorFunction, legacy: Bool)
}

nonisolated struct ParseResult: Equatable, Sendable {
    var color: ColorValue
    var notation: ColorNotation
    /// Syntax that parsed but is not valid CSS. Empty for well-formed input.
    var warnings: [ParseWarning] = []
}

/// Parses CSS Color Module Level 4 syntax.
///
/// Targets the CSS grammar itself rather than any convenience library's reading of
/// it. That distinction matters: permissive parsers accept `rgb(a b c)` as
/// `rgb(none none none)`, which would turn a user's typo into a silently valid color
/// — the opposite of useful in a tool whose job is telling you what your CSS means.
/// Invalid input is rejected with a specific reason.
nonisolated enum CSSColorParser {

    /// One written component value, before per-space interpretation.
    private enum Value: Equatable {
        case number(Double)
        case percentage(Double)
        case angle(Double)
        case none

        var isNone: Bool { self == .none }
        var isPercentage: Bool { if case .percentage = self { true } else { false } }
        var isPlainNumber: Bool { if case .number = self { true } else { false } }
    }

    private enum Separator: Equatable {
        case space, comma, slash
    }

    // MARK: - Entry point

    static func parse(_ input: String) throws(ParseError) -> ParseResult {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ParseError.empty }

        // Checked before tokenizing so the user hears "calc() isn't supported"
        // rather than "unexpected character +" from somewhere inside its body.
        if let unsupported = UnsupportedFunctions.firstCalled(in: trimmed) {
            throw ParseError.unsupportedFunction(unsupported)
        }

        let tokens = try CSSTokenizer.tokenize(trimmed)
        guard let first = tokens.first else { throw ParseError.empty }

        switch first {
        case .hash(let digits):
            guard tokens.count == 1 else {
                throw ParseError.trailingContent(describe(tokens[1]))
            }
            return try parseHex(digits)

        case .ident(let name):
            guard tokens.count == 1 else {
                throw ParseError.trailingContent(describe(tokens[1]))
            }
            guard let color = ColorValue.named(name) else {
                throw ParseError.unknownKeyword(name)
            }
            return ParseResult(color: color, notation: .keyword(name))

        case .function(let name):
            return try parseFunction(name, tokens: Array(tokens.dropFirst()))

        default:
            throw ParseError.unexpectedToken(describe(first))
        }
    }

    /// Convenience for callers that only care whether it parsed.
    static func color(_ input: String) -> ColorValue? {
        try? parse(input).color
    }

    // MARK: - Hex

    private static func parseHex(_ digits: String) throws(ParseError) -> ParseResult {
        let chars = Array(digits)
        guard [3, 4, 6, 8].contains(chars.count) else {
            throw ParseError.invalidHexLength(chars.count)
        }

        // Short forms duplicate each digit: #f0a → #ff00aa.
        let expanded: [String] =
            chars.count <= 4
            ? chars.map { String(repeating: String($0), count: 2) }
            : stride(from: 0, to: chars.count, by: 2).map { String(chars[$0...$0 + 1]) }

        let channels = expanded.map { Double(UInt8($0, radix: 16) ?? 0) / 255 }
        let color = ColorValue(
            space: .srgb,
            channels[0],
            channels[1],
            channels[2],
            alpha: channels.count == 4 ? channels[3] : 1
        )
        return ParseResult(color: color, notation: .hex(digits: chars.count))
    }

    // MARK: - Functions

    private static func parseFunction(
        _ name: String,
        tokens: [CSSToken]
    ) throws(ParseError) -> ParseResult {
        guard let function = ColorFunction(rawValue: name) else {
            throw ParseError.unknownFunction(name)
        }

        var rest = tokens
        var space: ColorSpace
        var spaceIdentifier: String?

        if function == .color {
            guard case .ident(let id)? = rest.first else {
                throw ParseError.unknownColorSpace(rest.first.map(describe) ?? "")
            }
            guard let resolved = ColorGrammar.colorFunctionSpaces[id] else {
                throw ParseError.unknownColorSpace(id)
            }
            space = resolved
            spaceIdentifier = id
            rest = Array(rest.dropFirst())
        } else {
            space = function.space!
        }
        _ = spaceIdentifier

        let (values, separators) = try scanArguments(rest)
        return try assemble(
            function: function,
            space: space,
            values: values,
            separators: separators
        )
    }

    /// Splits the argument list into values and the separators between them.
    private static func scanArguments(
        _ tokens: [CSSToken]
    ) throws(ParseError) -> ([Value], [Separator]) {
        var values: [Value] = []
        var separators: [Separator] = []
        var pendingSeparator: Separator?
        var closed = false

        for (index, token) in tokens.enumerated() {
            if closed {
                throw ParseError.trailingContent(describe(token))
            }

            switch token {
            case .closeParen:
                closed = true

            case .comma:
                guard !values.isEmpty, pendingSeparator == nil else {
                    throw ParseError.unexpectedToken(",")
                }
                pendingSeparator = .comma

            case .slash:
                guard !values.isEmpty, pendingSeparator == nil else {
                    throw ParseError.unexpectedToken("/")
                }
                pendingSeparator = .slash

            case .number(let n):
                try append(.number(n), &values, &separators, &pendingSeparator)

            case .percentage(let p):
                try append(.percentage(p), &values, &separators, &pendingSeparator)

            case .dimension(let value, let unit):
                guard let degrees = ColorGrammar.degrees(value, unit: unit) else {
                    throw ParseError.unexpectedToken("\(value)\(unit)")
                }
                try append(.angle(degrees), &values, &separators, &pendingSeparator)

            case .ident(let name) where name == "none":
                try append(.none, &values, &separators, &pendingSeparator)

            case .ident(let name):
                throw ParseError.unexpectedToken(name)

            case .function(let name):
                throw ParseError.unexpectedToken(name)

            case .hash(let h):
                throw ParseError.unexpectedToken("#\(h)")
            }

            _ = index
        }

        if pendingSeparator == .slash { throw ParseError.missingAlphaAfterSlash }
        if pendingSeparator != nil { throw ParseError.unexpectedToken(",") }

        return (values, separators)
    }

    private static func append(
        _ value: Value,
        _ values: inout [Value],
        _ separators: inout [Separator],
        _ pending: inout Separator?
    ) throws(ParseError) {
        if !values.isEmpty {
            separators.append(pending ?? .space)
        }
        pending = nil
        values.append(value)
    }

    // MARK: - Validation and assembly

    /// Applies the legacy/modern rules, then resolves each written value.
    ///
    /// Legacy and modern are two distinct grammars, not merely comma-vs-space, so the
    /// form is decided once from separator shape and then the whole rule set for that
    /// form is enforced.
    private static func assemble(
        function: ColorFunction,
        space: ColorSpace,
        values: [Value],
        separators: [Separator]
    ) throws(ParseError) -> ParseResult {
        var warnings: [ParseWarning] = []

        let hasComma = separators.contains(.comma)
        let hasSlash = separators.contains(.slash)
        if hasComma && hasSlash { throw ParseError.commaAndSlashMixed }

        let isLegacy = hasComma
        if isLegacy && !function.hasLegacyForm {
            // Unambiguous about intent, so parse it — but it is not valid CSS.
            warnings.append(.commasInModernFunction(function.rawValue))
        }

        guard values.count == 3 || values.count == 4 else {
            throw ParseError.wrongComponentCount(
                function: function.rawValue, expected: 3, got: values.count)
        }

        if isLegacy {
            // Every separator must be a comma; a stray space means malformed input.
            guard separators.allSatisfy({ $0 == .comma }) else {
                throw ParseError.inconsistentSeparators
            }
        } else {
            // Modern: the three components are space-separated and alpha, if any,
            // follows a slash. Four space-separated values is not valid CSS.
            let componentSeparators = separators.prefix(2)
            guard componentSeparators.allSatisfy({ $0 == .space }) else {
                throw ParseError.inconsistentSeparators
            }
            if values.count == 4 {
                guard separators.count == 3, separators[2] == .slash else {
                    throw ParseError.alphaWithoutSlash
                }
            }
        }

        let componentValues = Array(values.prefix(3))
        let alphaValue: Value? = values.count == 4 ? values[3] : nil

        if isLegacy && function.hasLegacyForm {
            try validateLegacyBody(function: function, values: componentValues, alpha: alphaValue)
            if componentValues.contains(where: \.isNone) || alphaValue?.isNone == true {
                warnings.append(.noneInLegacySyntax)
            }
        }

        // Resolve each written value against its component's grammar.
        let grammars = ColorGrammar.components(for: function)
        var components = SIMD3<Double>()
        var missing: ComponentMask = []

        for index in 0..<3 {
            switch componentValues[index] {
            case .none:
                components[index] = 0
                missing.insert(.component(index))
            case .number(let n):
                components[index] = n * grammars[index].numberScale
            case .percentage(let p):
                components[index] = p / 100 * grammars[index].percentReference
            case .angle(let degrees):
                guard grammars[index].isAngle else {
                    throw ParseError.unexpectedToken("\(degrees)deg")
                }
                components[index] = degrees
            }
        }

        var alpha = 1.0
        if let alphaValue {
            switch alphaValue {
            case .none:
                alpha = 1
                missing.insert(.alpha)
            case .number(let n):
                alpha = n
            case .percentage(let p):
                alpha = p / 100
            case .angle:
                throw ParseError.unexpectedToken("angle as alpha")
            }
        }

        let color = ColorValue(
            space: space,
            components: components,
            alpha: alpha,
            missing: missing
        )
        return ParseResult(
            color: color,
            notation: .function(function, legacy: isLegacy),
            warnings: warnings
        )
    }

    /// The extra restrictions that apply only inside legacy comma syntax.
    private static func validateLegacyBody(
        function: ColorFunction,
        values: [Value],
        alpha: Value?
    ) throws(ParseError) {
        switch function {
        case .rgb, .rgba:
            // All three channels must be the same type — no mixing 255 with 50%.
            let percentages = values.filter(\.isPercentage).count
            let numbers = values.filter(\.isPlainNumber).count
            if percentages > 0 && numbers > 0 {
                throw ParseError.mixedNumberAndPercentageInLegacy(function: function.rawValue)
            }

        case .hsl, .hsla:
            // Saturation and lightness must be written as percentages.
            for index in 1...2 where values[index].isPlainNumber {
                throw ParseError.percentageRequiredInLegacy(function: function.rawValue)
            }

        default:
            break
        }
        _ = alpha
    }

    // MARK: - Diagnostics

    private static func describe(_ token: CSSToken) -> String {
        switch token {
        case .function(let n): "\(n)("
        case .ident(let n): n
        case .number(let n): "\(n)"
        case .percentage(let p): "\(p)%"
        case .dimension(let v, let u): "\(v)\(u)"
        case .hash(let h): "#\(h)"
        case .comma: ","
        case .slash: "/"
        case .closeParen: ")"
        }
    }
}
