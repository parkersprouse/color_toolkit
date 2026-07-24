//
//  CSSTokenizer.swift
//  Color Toolkit
//

import Foundation

/// A token from CSS color syntax.
///
/// A focused subset of the CSS token grammar — enough for the color functions and
/// nothing more. A general CSS tokenizer would be far more machinery than the job
/// needs.
nonisolated enum CSSToken: Equatable, Sendable {
  case function(String) // ident immediately followed by "("
  case ident(String) // bare keyword: red, none, srgb, deg
  case number(Double) // 255, -0.5, 1e2
  case percentage(Double) // the value before "%", so 50% is 50
  case dimension(Double, String) // 120deg → (120, "deg")
  case hash(String) // #ff0000 → "ff0000"
  case comma
  case slash
  case closeParen
}

nonisolated enum CSSTokenizer {
  // MARK: Internal

  /// Splits CSS color syntax into tokens, discarding whitespace.
  ///
  /// Whitespace can be dropped because color syntax never needs it to disambiguate:
  /// legacy versus modern form is decided by whether commas are present, which
  /// survives tokenization.
  static func tokenize(_ input: String) throws(ParseError) -> [CSSToken] {
    var tokens: [CSSToken] = []
    let scalars = Array(input.unicodeScalars)
    var i = 0

    while i < scalars.count {
      let c = scalars[i]

      if isWhitespace(c) {
        i += 1
        continue
      }

      switch c {
      case ",":
        tokens.append(.comma)
        i += 1
      case "/":
        tokens.append(.slash)
        i += 1
      case ")":
        tokens.append(.closeParen)
        i += 1
      case "(":
        // A "(" not directly attached to an identifier.
        throw ParseError.unexpectedCharacter("(", at: i)
      case "#":
        i += 1
        var digits = ""
        while i < scalars.count, isHexDigit(scalars[i]) {
          digits.unicodeScalars.append(scalars[i])
          i += 1
        }
        guard !digits.isEmpty else {
          throw ParseError.unexpectedCharacter("#", at: i - 1)
        }
        tokens.append(.hash(digits))
      default:
        if isNumberStart(scalars, at: i) {
          let (value, next) = try scanNumber(scalars, from: i)
          i = next

          if i < scalars.count, scalars[i] == "%" {
            i += 1
            tokens.append(.percentage(value))
          } else if i < scalars.count, isIdentStart(scalars[i]) {
            let (unit, afterUnit) = scanIdent(scalars, from: i)
            i = afterUnit
            tokens.append(.dimension(value, unit.lowercased()))
          } else {
            tokens.append(.number(value))
          }
        } else if isIdentStart(c) {
          let (name, next) = scanIdent(scalars, from: i)
          i = next
          if i < scalars.count, scalars[i] == "(" {
            i += 1
            tokens.append(.function(name.lowercased()))
          } else {
            tokens.append(.ident(name.lowercased()))
          }
        } else {
          throw ParseError.unexpectedCharacter(Character(c), at: i)
        }
      }
    }

    return tokens
  }

  // MARK: Private

  // MARK: - Scanners

  /// Scans a CSS number.
  ///
  /// Boundaries are found here rather than handed to `Double(_:)`, which would
  /// happily swallow trailing characters that belong to the next token — the
  /// classic hand-rolled-tokenizer bug where `1e2deg` or `5px` parse as numbers.
  private static func scanNumber(
    _ s: [Unicode.Scalar],
    from start: Int,
  ) throws(ParseError) -> (Double, Int) {
    var i = start
    var text = ""

    if i < s.count, s[i] == "+" || s[i] == "-" {
      text.unicodeScalars.append(s[i])
      i += 1
    }

    var sawDigit = false
    while i < s.count, isDigit(s[i]) {
      text.unicodeScalars.append(s[i])
      i += 1
      sawDigit = true
    }

    if i < s.count, s[i] == "." {
      // Only consume the dot if a digit follows; otherwise it belongs elsewhere.
      if i + 1 < s.count, isDigit(s[i + 1]) {
        text.unicodeScalars.append(s[i])
        i += 1
        while i < s.count, isDigit(s[i]) {
          text.unicodeScalars.append(s[i])
          i += 1
          sawDigit = true
        }
      }
    }

    guard sawDigit else {
      throw ParseError.unexpectedCharacter(Character(s[start]), at: start)
    }

    // Exponent, but only when it is well-formed — `1e2` is a number while the
    // `e` in `1em` starts a unit.
    if i < s.count, s[i] == "e" || s[i] == "E" {
      var j = i + 1
      var exponent = "e"
      if j < s.count, s[j] == "+" || s[j] == "-" {
        exponent.unicodeScalars.append(s[j])
        j += 1
      }
      if j < s.count, isDigit(s[j]) {
        while j < s.count, isDigit(s[j]) {
          exponent.unicodeScalars.append(s[j])
          j += 1
        }
        text += exponent
        i = j
      }
    }

    guard let value = Double(text) else {
      throw ParseError.invalidNumber(text)
    }
    return (value, i)
  }

  private static func scanIdent(_ s: [Unicode.Scalar], from start: Int) -> (String, Int) {
    var i = start
    var text = ""
    while i < s.count, isIdentChar(s[i]) {
      text.unicodeScalars.append(s[i])
      i += 1
    }
    return (text, i)
  }

  // MARK: - Character classes

  private static func isWhitespace(_ c: Unicode.Scalar) -> Bool {
    c == " " || c == "\t" || c == "\n" || c == "\r" || c == "\u{0C}"
  }

  private static func isDigit(_ c: Unicode.Scalar) -> Bool {
    c >= "0" && c <= "9"
  }

  private static func isHexDigit(_ c: Unicode.Scalar) -> Bool {
    isDigit(c) || (c >= "a" && c <= "f") || (c >= "A" && c <= "F")
  }

  private static func isIdentStart(_ c: Unicode.Scalar) -> Bool {
    (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || c == "-" || c == "_"
  }

  private static func isIdentChar(_ c: Unicode.Scalar) -> Bool {
    isIdentStart(c) || isDigit(c)
  }

  private static func isNumberStart(_ s: [Unicode.Scalar], at i: Int) -> Bool {
    let c = s[i]
    if isDigit(c) {
      return true
    }
    if c == "." {
      return i + 1 < s.count && isDigit(s[i + 1])
    }
    if c == "+" || c == "-" {
      guard i + 1 < s.count else { return false }
      if isDigit(s[i + 1]) {
        return true
      }
      // "-" also begins a dashed-ident (`--custom`), so only treat it as a
      // number when a digit actually follows the decimal point.
      return s[i + 1] == "." && i + 2 < s.count && isDigit(s[i + 2])
    }
    return false
  }
}
