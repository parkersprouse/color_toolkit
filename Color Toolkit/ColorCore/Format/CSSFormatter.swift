//
//  CSSFormatter.swift
//  Color Toolkit
//

import Foundation

/// A CSS serialization target.
///
/// Distinct from `ColorSpace` because one space has several spellings: sRGB can be
/// written as a hex triplet, a keyword, `rgb()`, or `color(srgb …)`, and those are
/// not interchangeable in output.
nonisolated enum CSSOutputFormat: Equatable, Sendable {
    case hex
    case keyword
    case rgb
    case hsl
    case hwb
    case lab
    case lch
    case oklab
    case oklch
    case color(ColorSpace)

    /// The space a color must be converted into for this format.
    var space: ColorSpace {
        switch self {
        case .hex, .keyword, .rgb: .srgb
        case .hsl: .hsl
        case .hwb: .hwb
        case .lab: .lab
        case .lch: .lch
        case .oklab: .oklab
        case .oklch: .oklch
        case .color(let space): space
        }
    }

    /// Formats that cannot express an out-of-gamut value at all.
    ///
    /// Hex is 8-bit unsigned, so a negative channel simply has no spelling; a keyword
    /// is one of 148 fixed points. Both must be gamut-mapped regardless of policy.
    /// `rgb()` and friends, by contrast, accept out-of-range numbers syntactically.
    var requiresGamutMapping: Bool {
        switch self {
        case .hex, .keyword: true
        default: false
        }
    }
}

nonisolated struct CSSFormatOptions: Sendable, Equatable {
    /// Maximum decimal places. Trailing zeros are stripped.
    var precision: Int = 4
    /// Comma-separated output. Only valid for `rgb`/`hsl`; ignored elsewhere.
    var legacy: Bool = false
    /// Write `rgb()` channels as percentages instead of 0–255 numbers.
    var rgbAsPercentage: Bool = false
    /// Shorten `#ffcc00` to `#fc0` when every channel pair repeats.
    var collapseHex: Bool = false
    var uppercaseHex: Bool = false
    var alpha: AlphaPolicy = .whenNotOpaque
    var gamut: GamutPolicy = .map
    /// Also write `none` for hues that are powerless because the color is gray,
    /// not only for components explicitly authored as `none`.
    var noneForPowerlessComponents: Bool = false

    nonisolated enum AlphaPolicy: Sendable, Equatable {
        case whenNotOpaque, always, never
    }

    nonisolated enum GamutPolicy: Sendable, Equatable {
        /// Map into the target's gamut so the output renders as shown.
        case map
        /// Keep out-of-range values wherever the syntax permits them. Faithful to the
        /// authored color, but a browser will clamp it at used-value time.
        case preserve
    }

    static let `default` = CSSFormatOptions()
}

nonisolated extension ColorValue {

    /// Serializes this color as CSS.
    ///
    /// Returns `nil` only for `.keyword` when no keyword matches — every other format
    /// can represent any color.
    func cssString(
        as format: CSSOutputFormat,
        options: CSSFormatOptions = .default
    ) -> String? {
        let prepared = prepare(for: format, options: options)

        switch format {
        case .hex:
            return prepared.hexString(options: options)
        case .keyword:
            return prepared.namedKeyword
        case .rgb:
            return prepared.functionString(.rgb, options: options)
        case .hsl:
            return prepared.functionString(.hsl, options: options)
        case .hwb:
            return prepared.functionString(.hwb, options: options)
        case .lab:
            return prepared.functionString(.lab, options: options)
        case .lch:
            return prepared.functionString(.lch, options: options)
        case .oklab:
            return prepared.functionString(.oklab, options: options)
        case .oklch:
            return prepared.functionString(.oklch, options: options)
        case .color(let space):
            return prepared.colorFunctionString(space: space, options: options)
        }
    }

    /// Serializes as CSS, falling back to hex when a keyword was requested but none
    /// exists. Convenient for UI that must always show something.
    func cssStringOrHex(
        as format: CSSOutputFormat,
        options: CSSFormatOptions = .default
    ) -> String {
        cssString(as: format, options: options)
            ?? cssString(as: .hex, options: options)
            ?? "#000000"
    }

    // MARK: - Preparation

    /// Converts into the target space, gamut-mapping when the format or policy
    /// requires it.
    private func prepare(
        for format: CSSOutputFormat,
        options: CSSFormatOptions
    ) -> ColorValue {
        let target = format.space
        let mustMap = format.requiresGamutMapping || options.gamut == .map

        var result: ColorValue
        if mustMap && !target.isUnbounded && !inGamut(of: target) {
            result = gamutMapped(to: target)
        } else {
            result = converted(to: target)
        }

        if options.noneForPowerlessComponents {
            result = result.markingPowerlessComponents()
        }
        // The alpha flag survives conversion; component flags do not, so re-apply the
        // authored ones when the space is unchanged.
        if space == target {
            result.missing.formUnion(missing)
        } else if missing.contains(.alpha) {
            result.missing.insert(.alpha)
        }
        return result
    }

    // MARK: - Hex

    private func hexString(options: CSSFormatOptions) -> String {
        func channel(_ value: Double) -> Int {
            Int((value * 255).rounded().clamped(to: 0...255))
        }

        var pairs = [channel(components.x), channel(components.y), channel(components.z)]
        let includeAlpha = shouldEmitAlpha(options: options) && !missing.contains(.alpha)
        if includeAlpha {
            pairs.append(Int((alpha * 255).rounded().clamped(to: 0...255)))
        }

        let digits = pairs.map { String(format: "%02x", $0) }
        let collapsible = options.collapseHex && digits.allSatisfy { $0.first == $0.last }
        let body = collapsible ? digits.map { String($0.first!) }.joined() : digits.joined()

        return "#" + (options.uppercaseHex ? body.uppercased() : body)
    }

    // MARK: - Functions

    private func functionString(
        _ function: ColorFunction,
        options: CSSFormatOptions
    ) -> String {
        let grammars = ColorGrammar.components(for: function)
        // Legacy syntax has no spelling for `none`, so those components fall back to
        // their zero value rather than emitting invalid CSS.
        let useLegacy = options.legacy && function.hasLegacyForm

        var parts: [String] = []
        for index in 0..<3 {
            if missing.contains(.component(index)) && !useLegacy {
                parts.append("none")
                continue
            }
            parts.append(
                componentString(
                    components[index],
                    grammar: grammars[index],
                    function: function,
                    index: index,
                    options: options
                )
            )
        }

        let name = legacyFunctionName(function, options: options)
        let alphaText = alphaString(options: options, allowNone: !useLegacy)

        if useLegacy {
            let body = parts.joined(separator: ", ")
            if let alphaText {
                return "\(name)(\(body), \(alphaText))"
            }
            return "\(name)(\(body))"
        }

        let body = parts.joined(separator: " ")
        if let alphaText {
            return "\(name)(\(body) / \(alphaText))"
        }
        return "\(name)(\(body))"
    }

    private func colorFunctionString(space: ColorSpace, options: CSSFormatOptions) -> String? {
        guard let identifier = ColorGrammar.colorFunctionIdentifier(for: space) else {
            return nil
        }
        var parts: [String] = []
        for index in 0..<3 {
            if missing.contains(.component(index)) {
                parts.append("none")
            } else {
                parts.append(formatNumber(components[index], options: options))
            }
        }
        let body = parts.joined(separator: " ")
        if let alphaText = alphaString(options: options, allowNone: true) {
            return "color(\(identifier) \(body) / \(alphaText))"
        }
        return "color(\(identifier) \(body))"
    }

    private func legacyFunctionName(
        _ function: ColorFunction,
        options: CSSFormatOptions
    ) -> String {
        // rgba()/hsla() exist only so legacy syntax can carry alpha; modern syntax
        // uses the base name with a slash.
        guard options.legacy, function.hasLegacyForm, shouldEmitAlpha(options: options) else {
            return function.rawValue
        }
        switch function {
        case .rgb, .rgba: return "rgba"
        case .hsl, .hsla: return "hsla"
        default: return function.rawValue
        }
    }

    // MARK: - Components

    private func componentString(
        _ value: Double,
        grammar: ComponentGrammar,
        function: ColorFunction,
        index: Int,
        options: CSSFormatOptions
    ) -> String {
        if grammar.isAngle {
            return formatNumber(value, options: options)
        }

        // Percentage-only slots, plus rgb() when the caller asked for percentages.
        let forcePercentage =
            grammar.requiresPercentageInLegacy
            || (function == .hwb && index > 0)
            || ((function == .rgb || function == .rgba) && options.rgbAsPercentage)
            || ((function == .lab || function == .lch) && index == 0)

        if forcePercentage {
            let percent = value / grammar.percentReference * 100
            return formatNumber(percent, options: options) + "%"
        }

        return formatNumber(value / grammar.numberScale, options: options)
    }

    private func shouldEmitAlpha(options: CSSFormatOptions) -> Bool {
        switch options.alpha {
        case .always: true
        case .never: false
        case .whenNotOpaque: alpha < 1 || missing.contains(.alpha)
        }
    }

    private func alphaString(options: CSSFormatOptions, allowNone: Bool) -> String? {
        guard shouldEmitAlpha(options: options) else { return nil }
        if missing.contains(.alpha) {
            return allowNone ? "none" : formatNumber(alpha, options: options)
        }
        return formatNumber(alpha, options: options)
    }

    private func formatNumber(_ value: Double, options: CSSFormatOptions) -> String {
        guard value.isFinite else { return "0" }

        let scale = pow(10.0, Double(options.precision))
        let rounded = (value * scale).rounded() / scale

        // Avoid "-0", which is valid CSS but reads as a bug.
        if rounded == 0 { return "0" }

        var text = String(format: "%.\(options.precision)f", rounded)
        if text.contains(".") {
            while text.hasSuffix("0") { text.removeLast() }
            if text.hasSuffix(".") { text.removeLast() }
        }
        return text
    }
}

nonisolated private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
