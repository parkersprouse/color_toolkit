//
//  ColorSyntax.swift
//  Color Toolkit
//

import Foundation

// MARK: - Errors

nonisolated enum ParseError: Error, Equatable, Sendable {
  case empty
  case unexpectedCharacter(Character, at: Int)
  case invalidNumber(String)
  case unknownKeyword(String)
  case unknownFunction(String)
  case unknownColorSpace(String)
  case wrongComponentCount(function: String, expected: Int, got: Int)
  case commaAndSlashMixed
  case inconsistentSeparators
  case alphaWithoutSlash
  case missingAlphaAfterSlash
  case percentageRequiredInLegacy(function: String)
  case mixedNumberAndPercentageInLegacy(function: String)
  case invalidHexLength(Int)
  case unexpectedToken(String)
  case trailingContent(String)
  case unsupportedFunction(String)

  // MARK: Internal

  var message: String {
    switch self {
    case .empty:
      "Empty input."
    case let .unexpectedCharacter(c, i):
      "Unexpected character “\(c)” at position \(i)."
    case let .invalidNumber(s):
      "“\(s)” is not a valid number."
    case let .unknownKeyword(s):
      "“\(s)” is not a CSS color keyword."
    case let .unknownFunction(s):
      "“\(s)()” is not a CSS color function."
    case let .unknownColorSpace(s):
      "“\(s)” is not a color() color space."
    case let .wrongComponentCount(fn, expected, got):
      "\(fn)() takes \(expected) components, got \(got)."
    case .commaAndSlashMixed:
      "Commas and “/” cannot be combined — use one alpha syntax or the other."
    case .inconsistentSeparators:
      "Components must be separated consistently, either all by commas or all by spaces."
    case .alphaWithoutSlash:
      "A fourth component needs “/” before it in modern syntax."
    case .missingAlphaAfterSlash:
      "Expected an alpha value after “/”."
    case let .percentageRequiredInLegacy(fn):
      "Legacy \(fn)() requires percentages for saturation and lightness."
    case let .mixedNumberAndPercentageInLegacy(fn):
      "Legacy \(fn)() cannot mix numbers and percentages."
    case let .invalidHexLength(n):
      "A hex color needs 3, 4, 6 or 8 digits — got \(n)."
    case let .unexpectedToken(s):
      "Unexpected “\(s)”."
    case let .trailingContent(s):
      "Unexpected trailing content “\(s)”."
    case let .unsupportedFunction(name):
      switch name {
      case "var", "env", "attr":
        "\(name)() can’t be resolved without a stylesheet — substitute the value first."
      default:
        "\(name)() is not supported yet."
      }
    }
  }
}

/// CSS functions that can legally appear inside a color but that this parser does
/// not evaluate.
///
/// Detected before tokenizing: a `calc()` body contains operators the color
/// tokenizer has no rules for, so left alone it would fail with “unexpected
/// character +” instead of saying what is actually wrong.
nonisolated enum UnsupportedFunctions {
  static let names = ["calc", "var", "env", "attr", "min", "max", "clamp", "round"]

  /// Returns the first unsupported function called in `input`, if any.
  static func firstCalled(in input: String) -> String? {
    let lowered = input.lowercased()
    return names.first { name in
      guard let range = lowered.range(of: name + "(") else { return false }
      // Must be a whole identifier — `color(` must not match `or(`, and a
      // hypothetical `xcalc(` is not `calc(`.
      guard range.lowerBound > lowered.startIndex else { return true }
      let preceding = lowered[lowered.index(before: range.lowerBound)]
      return !(preceding.isLetter || preceding.isNumber || preceding == "-" || preceding == "_")
    }
  }
}

/// Syntax that parses but is not valid CSS.
///
/// Deliberately only two cases. Both are unambiguous about intent, so rejecting them
/// would be unhelpful — but emitting them would be wrong, and silently accepting them
/// could let invalid CSS reach a stylesheet. Everything else in the grammar is a hard
/// error.
///
/// `none` in legacy syntax lives here rather than in ``ParseError`` on purpose. A
/// `ParseError.noneNotAllowedInLegacy` was declared alongside this for a while,
/// carrying a message and never being thrown — two answers to one question, one of
/// them unreachable. The warning is the answer; the error case is gone.
nonisolated enum ParseWarning: Equatable, Sendable {
  case commasInModernFunction(String)
  case noneInLegacySyntax

  // MARK: Internal

  var message: String {
    switch self {
    case let .commasInModernFunction(fn):
      "\(fn)() does not accept commas in CSS — parsed anyway."
    case .noneInLegacySyntax:
      "“none” is not valid in comma-separated syntax — parsed anyway."
    }
  }
}

// MARK: - Functions

nonisolated enum ColorFunction: String, CaseIterable, Sendable {
  case rgb, rgba, hsl, hsla, hwb, lab, lch, oklab, oklch, color

  // MARK: Internal

  /// The four functions with a comma-separated legacy form. Everything else is
  /// modern-only, where commas are invalid CSS.
  var hasLegacyForm: Bool {
    switch self {
    case .rgb, .rgba, .hsl, .hsla: true
    default: false
    }
  }

  /// The space this function produces, except `color()` which names its own.
  var space: ColorSpace? {
    switch self {
    case .rgb, .rgba: .srgb
    case .hsl, .hsla: .hsl
    case .hwb: .hwb
    case .lab: .lab
    case .lch: .lch
    case .oklab: .oklab
    case .oklch: .oklch
    case .color: nil
    }
  }
}

// MARK: - Component grammar

/// How one component of a color function interprets its written value.
///
/// The three axes CSS varies per component: what a bare number means, what `100%`
/// maps to, and whether the slot is an angle.
nonisolated struct ComponentGrammar: Sendable {
  static let angle = ComponentGrammar(isAngle: true)

  /// Bare numbers are multiplied by this. Only `rgb()` differs, where the
  /// number form runs 0–255 while storage is 0–1.
  var numberScale: Double = 1
  /// The stored value that `100%` corresponds to.
  var percentReference: Double = 1
  var isAngle: Bool = false
  /// Legacy `hsl()` requires percentages here; a bare number is invalid.
  var requiresPercentageInLegacy: Bool = false

  /// The largest ordinary magnitude this component is written with, in its number
  /// form. Drives how many decimals are worth printing — see
  /// ``CSSFormatOptions/decimals(forFullScale:)``.
  ///
  /// Falls out of the two fields already here: `rgb()` stores 0–1 but writes 0–255,
  /// so `1 / (1/255)` recovers the written scale, while Lab's `a` writes its stored
  /// ±125 directly.
  var fullScale: Double {
    isAngle ? 360 : percentReference / numberScale
  }

  static func percent(_ reference: Double, requiredInLegacy: Bool = false) -> ComponentGrammar {
    ComponentGrammar(
      percentReference: reference,
      requiresPercentageInLegacy: requiredInLegacy,
    )
  }
}

nonisolated enum ColorGrammar {
  /// Alpha: a number in 0–1, or a percentage of 1.
  static let alpha = ComponentGrammar(percentReference: 1)

  /// Space identifiers accepted inside `color()`.
  ///
  /// `xyz` is a spec alias for `xyz-d65`.
  static let colorFunctionSpaces: [String: ColorSpace] = [
    "srgb": .srgb,
    "srgb-linear": .srgbLinear,
    "display-p3": .displayP3,
    "a98-rgb": .a98RGB,
    "prophoto-rgb": .proPhotoRGB,
    "rec2020": .rec2020,
    "xyz": .xyzD65,
    "xyz-d50": .xyzD50,
    "xyz-d65": .xyzD65,
  ]

  /// Per-component grammar for each function.
  ///
  /// The percentage references come straight from CSS Color 4 and are the detail
  /// most often gotten wrong: `100%` means 125 for Lab's a/b but 0.4 for OKLab's,
  /// and 150 for LCH chroma but 0.4 for OKLCH's.
  static func components(for function: ColorFunction) -> [ComponentGrammar] {
    switch function {
    case .rgb, .rgba:
      // Numbers run 0–255, percentages 0–100%, both stored as 0–1.
      let channel = ComponentGrammar(numberScale: 1.0 / 255.0, percentReference: 1)
      return [channel, channel, channel]

    case .hsl, .hsla:
      return [.angle, .percent(100, requiredInLegacy: true), .percent(100, requiredInLegacy: true)]

    case .hwb:
      return [.angle, .percent(100), .percent(100)]

    case .lab:
      return [.percent(100), .percent(125), .percent(125)]

    case .lch:
      return [.percent(100), .percent(150), .angle]

    case .oklab:
      return [.percent(1), .percent(0.4), .percent(0.4)]

    case .oklch:
      return [.percent(1), .percent(0.4), .angle]

    case .color:
      // Every predefined space uses a plain 0–1 range.
      let channel = ComponentGrammar(percentReference: 1)
      return [channel, channel, channel]
    }
  }

  /// The canonical `color()` identifier for a space, for serialization.
  static func colorFunctionIdentifier(for space: ColorSpace) -> String? {
    switch space {
    case .srgb: "srgb"
    case .srgbLinear: "srgb-linear"
    case .displayP3: "display-p3"
    case .a98RGB: "a98-rgb"
    case .proPhotoRGB: "prophoto-rgb"
    case .rec2020: "rec2020"
    case .xyzD50: "xyz-d50"
    case .xyzD65: "xyz-d65"
    default: nil
    }
  }

  /// Converts an angle in `unit` to degrees.
  static func degrees(_ value: Double, unit: String) -> Double? {
    switch unit {
    case "deg": value
    case "rad": value * 180 / .pi
    case "grad": value * 0.9
    case "turn": value * 360
    default: nil
    }
  }
}
