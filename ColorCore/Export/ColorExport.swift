//
//  ColorExport.swift
//  Color Toolkit
//

import Foundation

/// What kind of document an export produces.
///
/// Separate from ``ExportTemplate`` because the two answer different questions, and
/// collapsing them is the mistake that makes export panels confusing. A template is
/// *per color* — how one value is spelled in a declaration. A shape is *per document* —
/// what wraps the set. `background-color:` repeated eleven times is not a stylesheet,
/// and a `:root` block containing one `border` shorthand is not a custom property.
nonisolated enum ExportShape: String, CaseIterable, Sendable, Hashable, Identifiable {
  /// Bare declarations, one per color, ready to paste inside a rule.
  case declaration
  /// A `:root` block of custom properties.
  case customProperties
  /// A JSON object, for anything that is not a stylesheet.
  case json
  /// Tailwind v4's CSS-first `@theme` block.
  case tailwindTheme = "tailwind-theme"
  /// Tailwind v3's JavaScript `tailwind.config.js`.
  case tailwindConfig = "tailwind-config"
  /// A hex `:root` block, then the same properties re-declared in `color(display-p3 …)`
  /// inside `@media (color-gamut: p3)`.
  case p3WithFallback = "p3-with-fallback"

  // MARK: Internal

  var id: String {
    rawValue
  }

  /// Whether the shape uses ``ExportOptions/template``. Only one does — for the rest
  /// the wrapper dictates the syntax — so a panel can hide a control that would have
  /// no effect rather than leave it there lying.
  var usesTemplate: Bool {
    self == .declaration
  }

  /// Whether the shape uses ``ExportOptions/name``. The complement of ``usesTemplate``,
  /// and not by coincidence: a bare declaration is the one output with nowhere to put a
  /// family name, because it names a CSS property instead of introducing an identifier.
  var usesName: Bool {
    self != .declaration
  }

  /// Whether the shape uses ``ExportOptions/format``. The third capability flag, and the
  /// first one that exists to stop a control being *harmful* rather than merely inert.
  ///
  /// ``p3WithFallback`` needs two spellings where `format` is one value, and both are
  /// fixed by what the shape is for. Leaving the picker live would let somebody choose
  /// the default, `oklch()` — which is unbounded — and fill the *fallback* block with
  /// out-of-sRGB values, which is precisely the situation the shape exists to avoid. So
  /// the format is not a preference here, and the panel hides the control rather than
  /// offering a choice that is quietly ignored.
  var usesFormat: Bool {
    self != .p3WithFallback
  }
}

nonisolated extension CSSOutputFormat {
  /// The formats an export may be written in: the catalog minus ``keyword``.
  ///
  /// ``keyword`` is excluded structurally rather than handled with a fallback. It names
  /// 148 colors and returns `nil` for everything else, so in a palette of eleven shades
  /// it would spell two of them as keywords and silently switch format for the other
  /// nine. That is fine in the conversion panel, where a format that cannot name the
  /// color simply has no row; it is not fine in a document somebody ships, where the
  /// reader has no way to know a substitution happened.
  ///
  /// Every remaining format is *total* — it can name any color — which is what lets
  /// ``ExportOptions/value(for:formatting:)`` use `cssStringOrHex` without that
  /// fallback ever firing. A test pins it.
  static let exportable: [CSSOutputFormat] = catalog.filter { $0 != .keyword }
}

/// Everything about *how* an export is written, minus the numbers.
///
/// Deliberately not merged with ``CSSFormatOptions``, which owns precision, hex casing
/// and gamut policy. Those are properties of how you write CSS anywhere in the app and
/// are already shared app-wide; these are properties of this one document. The panel
/// passes the store's `CSSFormatOptions` straight through, so raising precision in the
/// toolbar moves the export too — one knob, not two that silently disagree.
nonisolated struct ExportOptions: Sendable, Equatable {
  // MARK: Internal

  static let `default` = ExportOptions()

  /// What an unnamed export is called: the starting value, the fallback when the field
  /// is cleared, and the placeholder a panel shows in the empty field.
  ///
  /// One constant for all three so they cannot drift. They did: the field prompted
  /// `brand` while an empty name exported `--color`, because the fallback came from
  /// ``cssIdentifier(_:fallback:)``'s own default rather than from here.
  static let defaultName = "brand"

  /// What ``ExportShape/p3WithFallback`` writes its first block in.
  ///
  /// Hex on principle rather than for convenience: that block's job is to be what a
  /// browser without P3 support gets, and hex is the most broadly compatible spelling
  /// there is. It is also the only choice that cannot itself carry an out-of-sRGB
  /// value — `cannotRepresentOutOfGamut` — so the fallback provably falls back.
  static let fallbackFormat: CSSOutputFormat = .hex

  /// What ``ExportShape/p3WithFallback`` writes its `@media` block in. The gamut the
  /// query asks about, spelled the way CSS spells it.
  static let wideFormat: CSSOutputFormat = .color(.displayP3)

  var shape: ExportShape = .customProperties
  var template: ExportTemplate = .color

  /// OKLCH by default. It is the format this app is built around, it is unbounded so
  /// nothing is gamut-mapped on the way out, and it is what Tailwind's own default
  /// palette ships in — so an exported theme sits beside the stock one without looking
  /// foreign.
  var format: CSSOutputFormat = .oklch

  /// The family name: `brand` yields `--brand-500` and `colors: { brand: … }`.
  ///
  /// Free text, so it is sanitized into a CSS identifier at the point of use rather
  /// than validated on the way in — rejecting keystrokes while somebody is typing is a
  /// worse experience than accepting them and writing something valid.
  var name: String = ExportOptions.defaultName

  /// `text` reduced to something usable as a CSS identifier and a JavaScript key.
  ///
  /// Anything outside `[A-Za-z0-9_-]` becomes a hyphen, runs collapse, and the ends are
  /// trimmed — so `my brand!` is `my-brand` and `--` is nothing at all. Case survives,
  /// because CSS custom properties are case-sensitive and `--Brand` is a choice.
  static func cssIdentifier(_ text: String, fallback: String = "color") -> String {
    var out = ""
    var pendingHyphen = false
    for character in text {
      if character.isASCII, character.isLetter || character.isNumber || character == "_" {
        if pendingHyphen, !out.isEmpty {
          out.append("-")
        }
        pendingHyphen = false
        out.append(character)
      } else {
        // Collapse any run of junk — spaces, punctuation, existing hyphens — into
        // at most one separator, and only if something follows it.
        pendingHyphen = true
      }
    }
    return out.isEmpty ? fallback : out
  }

  /// `key` as it must appear on the left of a JavaScript object literal.
  ///
  /// Tailwind's own config writes shade keys bare — `50: '#fdf8f6'` — and a bare `50`
  /// is legal because JavaScript accepts numeric literals as keys. `triad-2` is not:
  /// unquoted it parses as a subtraction and the file fails to load. So the rule is
  /// integers and identifiers bare, everything else quoted.
  static func javaScriptKey(_ key: String) -> String {
    if !key.isEmpty, key.allSatisfy(\.isNumber) {
      return key
    }
    let isIdentifier = !key.isEmpty
      && !(key.first?.isNumber ?? true)
      && key.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "$") }
    return isIdentifier ? key : "'\(key)'"
  }

  /// The whole document.
  ///
  /// - Parameter formatting: how each color is spelled — precision, hex casing, gamut
  ///   policy. The app-wide setting, passed through rather than duplicated here.
  func render(_ entries: [PaletteEntry], formatting: CSSFormatOptions = .default) -> String {
    guard !entries.isEmpty else { return "" }
    switch shape {
    case .declaration: return declarations(entries, formatting: formatting)
    case .customProperties: return customProperties(entries, formatting: formatting)
    case .json: return json(entries, formatting: formatting)
    case .tailwindTheme: return tailwindTheme(entries, formatting: formatting)
    case .tailwindConfig: return tailwindConfig(entries, formatting: formatting)
    case .p3WithFallback: return p3WithFallback(entries, formatting: formatting)
    }
  }

  /// The format the "mapped" count is measured against, which is not always ``format``.
  ///
  /// One predicate decides both the badge and the serialized string — the invariant this
  /// property exists to preserve, now that one shape writes two spellings. For that shape
  /// the answer is the **fallback**: hex is where a wide color is actually moved, and the
  /// `@media` block is what recovers it. Measuring against the P3 block instead would
  /// report `0 mapped` for a color sitting outside sRGB while the hex line right below the
  /// badge had been rounded — the badge silent about a value that changed.
  ///
  /// The count therefore refers to the fallback block, and the panel's wording says so.
  /// **A color outside P3 is mapped in both blocks and the badge does not distinguish it**
  /// — an accepted limitation, recorded in PLAN.md rather than answered with a second
  /// count, because a two-number badge is a different feature from the one M16 asked for.
  var mappedCountFormat: CSSOutputFormat {
    shape.usesFormat ? format : Self.fallbackFormat
  }

  /// One color, spelled in ``format``.
  ///
  /// `cssStringOrHex`'s fallback is unreachable for every member of
  /// ``CSSOutputFormat/exportable``, which is the only thing a panel offers — see the
  /// note there. Using it anyway rather than force-unwrapping keeps a wrong `format`
  /// set programmatically from crashing the app over a string.
  func value(for color: ColorValue, formatting: CSSFormatOptions = .default) -> String {
    value(for: color, as: format, formatting: formatting)
  }

  /// One color, spelled in a format the *shape* chose rather than the user.
  ///
  /// The seam that keeps ``p3WithFallback`` from becoming a second serialization path:
  /// the shapes that honour ``format`` reach this through the overload above, so there is
  /// still exactly one place a color becomes a string.
  func value(
    for color: ColorValue,
    as format: CSSOutputFormat,
    formatting: CSSFormatOptions = .default,
  ) -> String {
    color.cssStringOrHex(as: format, options: formatting)
  }

  // MARK: Private

  /// The family name, sanitized. Computed rather than stored so ``name`` stays exactly
  /// what the user typed and the field does not fight them mid-word.
  ///
  /// Every shape goes through this rather than calling ``cssIdentifier(_:fallback:)``
  /// itself, so an emptied field cannot produce one name in CSS and another in JSON.
  private var identifier: String {
    Self.cssIdentifier(name, fallback: Self.defaultName)
  }

  /// `--brand-500`, or `--brand` for a palette of one.
  private func propertyName(_ entry: PaletteEntry, prefix: String = "") -> String {
    let key = Self.cssIdentifier(entry.key, fallback: "")
    let family = prefix + identifier
    return key.isEmpty ? "--\(family)" : "--\(family)-\(key)"
  }

  // MARK: - Shapes

  /// Bare declarations, one per color.
  ///
  /// A single color gets exactly the line you would type. A set gets one line each with
  /// its key in a trailing comment, because eleven `background-color` declarations are
  /// indistinguishable otherwise — and they are meant to be split across the eleven
  /// rules you paste them into, not to stand as a block.
  private func declarations(
    _ entries: [PaletteEntry],
    formatting: CSSFormatOptions,
  ) -> String {
    entries.map { entry in
      let line = template.declaration(for: value(for: entry.color, formatting: formatting))
      // Sanitized even though it is only a comment: a key containing `*/` would
      // close it early and turn the rest of the line into stray CSS.
      let key = Self.cssIdentifier(entry.key, fallback: "")
      guard !key.isEmpty else { return line }
      return "\(line) /* \(key) */"
    }
    .joined(separator: "\n")
  }

  /// `  --brand-500: <value>;` for each entry, indented one level.
  ///
  /// Shared by ``customProperties`` and both halves of ``p3WithFallback`` so the two
  /// blocks of that shape cannot come to name different properties — an override that
  /// misses its base is a `@media` block with no effect, and it looks perfectly fine.
  private func propertyLines(
    _ entries: [PaletteEntry],
    as format: CSSOutputFormat,
    formatting: CSSFormatOptions,
  ) -> [String] {
    entries.map { entry in
      "  \(propertyName(entry)): \(value(for: entry.color, as: format, formatting: formatting));"
    }
  }

  private func customProperties(
    _ entries: [PaletteEntry],
    formatting: CSSFormatOptions,
  ) -> String {
    let body = propertyLines(entries, as: format, formatting: formatting)
    return ([":root {"] + body + ["}"]).joined(separator: "\n")
  }

  /// The progressive-enhancement shape: everything in hex, then everything again in
  /// `color(display-p3 …)` behind the gamut query.
  ///
  /// **The override is emitted for every entry, including colors already inside sRGB.**
  /// A per-entry conditional is the obvious saving and it is the wrong trade: it would
  /// make the media block's *contents* depend on the palette's contents, so editing one
  /// color to a wider one would silently change which properties exist in the document.
  /// A stylesheet whose property set moves under you is worse than a few redundant
  /// lines, and the redundant ones are exactly equal to the values they override.
  ///
  /// The formatting argument is passed through untouched. Hex maps regardless of policy
  /// because it `cannotRepresentOutOfGamut`; the P3 block follows whatever the app-wide
  /// gamut policy is, exactly as choosing `color(display-p3 …)` in any other shape does.
  private func p3WithFallback(
    _ entries: [PaletteEntry],
    formatting: CSSFormatOptions,
  ) -> String {
    let fallback = propertyLines(entries, as: Self.fallbackFormat, formatting: formatting)
    let wide = propertyLines(entries, as: Self.wideFormat, formatting: formatting)
      .map { "  " + $0 }
    return ([":root {"] + fallback + ["}", "", "@media (color-gamut: p3) {", "  :root {"]
      + wide + ["  }", "}"]).joined(separator: "\n")
  }

  /// Tailwind v4, which configures colors in CSS rather than JavaScript.
  ///
  /// The namespace prefix is Tailwind's, not ours: a property called `--color-brand-500`
  /// is what generates `bg-brand-500`, and one called `--brand-500` generates nothing.
  private func tailwindTheme(
    _ entries: [PaletteEntry],
    formatting: CSSFormatOptions,
  ) -> String {
    let body = entries.map { entry in
      "  \(propertyName(entry, prefix: "color-")): \(value(for: entry.color, formatting: formatting));"
    }
    return (["@theme {"] + body + ["}"]).joined(separator: "\n")
  }

  /// Tailwind v3, whose config is a JavaScript module.
  ///
  /// Emitted under `theme.extend` rather than `theme`, which is the difference between
  /// adding a color and replacing the entire default palette with this one.
  private func tailwindConfig(
    _ entries: [PaletteEntry],
    formatting: CSSFormatOptions,
  ) -> String {
    let family = Self.javaScriptKey(identifier)
    var lines = [
      "/** @type {import('tailwindcss').Config} */",
      "module.exports = {",
      "  theme: {",
      "    extend: {",
      "      colors: {",
    ]

    // A palette of one is a color, not a scale: Tailwind accepts a bare string there
    // and writing `{ '': … }` instead would produce a key nothing can reference.
    if let single = soleEntry(entries) {
      lines.append("        \(family): '\(value(for: single.color, formatting: formatting))',")
    } else {
      lines.append("        \(family): {")
      for entry in entries {
        let key = Self.javaScriptKey(Self.cssIdentifier(entry.key, fallback: "_"))
        lines.append("          \(key): '\(value(for: entry.color, formatting: formatting))',")
      }
      lines.append("        },")
    }

    lines.append(contentsOf: ["      },", "    },", "  },", "}"])
    return lines.joined(separator: "\n")
  }

  /// A hand-written object rather than `JSONEncoder` over ``ColorValue``.
  ///
  /// `ColorValue` is `Codable`, so encoding it directly is one line away — and it would
  /// emit this app's internals: a `space` string, a `components` array, a `missing`
  /// bitmask. That is a serialization of the program, not of the color. What a consumer
  /// wants is the same CSS string they would have pasted, which is also the only form
  /// that survives being read by something that is not this app.
  ///
  /// The shape mirrors Tailwind's: a lone color is a string, a scale is an object of
  /// them. Values need no escaping because CSS color syntax has no `"` or `\` in it —
  /// hex digits, function names, numbers and separators are the whole alphabet.
  private func json(_ entries: [PaletteEntry], formatting: CSSFormatOptions) -> String {
    let family = identifier
    if let single = soleEntry(entries) {
      return "{\n  \"\(family)\": \"\(value(for: single.color, formatting: formatting))\"\n}"
    }
    let body = entries.map { entry in
      // Sanitized rather than escaped: the keys this app generates need neither, and
      // a sanitizer that runs everywhere beats an escaper that runs in one place.
      let key = Self.cssIdentifier(entry.key, fallback: "_")
      return "    \"\(key)\": \"\(value(for: entry.color, formatting: formatting))\""
    }
    .joined(separator: ",\n")
    return "{\n  \"\(family)\": {\n\(body)\n  }\n}"
  }

  /// The one entry, when this palette is a single unkeyed color.
  ///
  /// Keyed on the *key* being empty rather than on `count == 1`, because a harmony of
  /// one is still a scale — a one-stop ramp keyed `1` should nest like an eleven-stop
  /// one, so that a consumer's `brand.1` does not become `brand` when the stepper moves.
  private func soleEntry(_ entries: [PaletteEntry]) -> PaletteEntry? {
    guard entries.count == 1, let first = entries.first, first.key.isEmpty else {
      return nil
    }
    return first
  }
}
