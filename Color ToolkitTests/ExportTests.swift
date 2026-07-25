//
//  ExportTests.swift
//  Color ToolkitTests
//

@testable import Color_Toolkit
import Foundation
import Testing

/// Proof for the export layer, which has an oracle nothing else in `Transform/` had:
/// **this app's own parser**.
///
/// A harmony can only be checked against its defining properties, because no reference
/// implementation has a notion of one. An exported declaration is different — it is CSS,
/// and CSS is exactly what ``CSSColorParser`` reads. So the discriminating test here is a
/// round trip: pull the value back out of the document, parse it, and require the color
/// that comes back to be the color that went in. That single assertion covers the whole
/// chain — format selection, precision plumbing, and the string surgery of every shape —
/// and it fails loudly if any link rounds when it should not.
@Suite("Export round trip")
struct ExportRoundTripTests {
  /// In sRGB and already on the 8-bit grid, so *every* exportable format can name it
  /// exactly. A wide color would be gamut-mapped by hex, and the round trip would then
  /// be measuring the mapper rather than the exporter.
  static let base = ColorValue.srgb8(0x3B, 0x82, 0xF6)

  /// Every exportable format survives a trip through a custom-property block.
  ///
  /// Parameterized over the whole catalog rather than spot-checking `oklch()`, because
  /// the formats fail differently: hex quantizes, `color()` uses a different function
  /// name, and the polar spaces are where a wrong per-component precision shows up.
  @Test("A value survives the document", arguments: CSSOutputFormat.exportable)
  func valueRoundTripsThroughACustomPropertyBlock(format: CSSOutputFormat) throws {
    var options = ExportOptions.default
    options.shape = .customProperties
    options.format = format

    let document = options.render([PaletteEntry(color: Self.base)], formatting: .lossless)
    let value = try #require(
      Self.propertyValues(in: document).first,
      "No custom property in:\n\(document)",
    )

    let parsed = try #require(
      try CSSColorParser.parse(value).color,
      "Exported \(value), which this app's own parser rejects",
    )

    let original = Self.base.converted(to: .srgb).components
    let returned = parsed.converted(to: .srgb).components
    for index in 0 ..< 3 {
      #expect(
        abs(original[index] - returned[index]) < 1e-7,
        "\(format) round-tripped \(original) to \(returned) via \(value)",
      )
    }
  }

  /// Precision reaches every shape, at both cardinalities.
  ///
  /// This is the mutation check made permanent. Swap `.lossless` for `.default` anywhere
  /// a shape renders and the exact string stops appearing, so a shape that quietly
  /// ignored its `formatting` argument — the easiest mistake to make when there are five
  /// of them and they were written one after another — cannot pass.
  ///
  /// **Both a lone color and a palette**, because `json` and `tailwindConfig` fork on
  /// exactly that: a single color is a bare string and a scale is a nested object, which
  /// are two separate render paths. A single-entry-only version of this test passed
  /// against a deliberately broken multi-entry branch, which is how that came to light.
  @Test("Every shape honors the formatting it is handed", arguments: ExportShape.allCases)
  func formattingReachesEveryShape(shape: ExportShape) {
    var options = ExportOptions.default
    options.shape = shape
    options.format = .oklch

    let coarseOptions = CSSFormatOptions(precision: 2)
    let lossless = Self.base.cssStringOrHex(as: .oklch, options: .lossless)
    let coarse = Self.base.cssStringOrHex(as: .oklch, options: coarseOptions)
    #expect(lossless != coarse, "The two precisions produce the same string; test is blind")

    let cardinalities: [(String, [PaletteEntry])] = [
      ("a lone color", [PaletteEntry(color: Self.base)]),
      ("a palette", [
        PaletteEntry(key: "500", color: Self.base),
        PaletteEntry(key: "600", color: Self.base),
      ]),
    ]

    for (description, entries) in cardinalities {
      #expect(
        options.render(entries, formatting: .lossless).contains(lossless),
        "\(shape) dropped the lossless value for \(description)",
      )
      #expect(
        options.render(entries, formatting: coarseOptions).contains(coarse),
        "\(shape) ignored the coarse precision for \(description)",
      )
    }
  }

  /// Extracts the value from every `--name: value;` line.
  private static func propertyValues(in document: String) -> [String] {
    document.split(separator: "\n").compactMap { line in
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      guard trimmed.hasPrefix("--"), trimmed.hasSuffix(";"),
            let colon = trimmed.firstIndex(of: ":")
      else { return nil }
      return String(trimmed[trimmed.index(after: colon)...])
        .dropLast()
        .trimmingCharacters(in: .whitespaces)
    }
  }
}

/// The syntax each shape produces, asserted exactly.
///
/// Exact strings are the right standard here and the wrong one three files over. What
/// ``HarmonyPresentation`` says about a triad is editorial and will be reworded; a
/// `:root` block either has its braces or is not a `:root` block. These are the same
/// kind of claim the CSS serializer's own tests make.
@Suite("Export shapes")
struct ExportShapeTests {
  static let blue = ColorValue.srgb8(0x3B, 0x82, 0xF6)
  static let red = ColorValue.srgb8(0xEF, 0x44, 0x44)

  static let palette = [
    PaletteEntry(key: "500", color: blue),
    PaletteEntry(key: "600", color: red),
  ]

  /// A lone color is a bare declaration you can paste inside any rule, with no comment
  /// and no wrapper — the thing you would have typed.
  @Test("One color, one declaration")
  func singleDeclaration() {
    var options = ExportOptions.default
    options.shape = .declaration
    options.template = .border
    options.format = .hex

    let rendered = options.render([PaletteEntry(color: Self.blue)])
    #expect(rendered == "border: 1px solid #3b82f6;")
  }

  /// A set gets its keys in trailing comments, because eleven `background-color` lines
  /// are otherwise indistinguishable from each other.
  @Test("A palette's declarations name themselves")
  func paletteDeclarationsCarryKeys() {
    var options = ExportOptions.default
    options.shape = .declaration
    options.template = .backgroundColor
    options.format = .hex

    #expect(options.render(Self.palette) == """
    background-color: #3b82f6; /* 500 */
    background-color: #ef4444; /* 600 */
    """)
  }

  @Test("Custom properties nest under the family name")
  func customPropertyBlock() {
    var options = ExportOptions.default
    options.shape = .customProperties
    options.format = .hex
    options.name = "brand"

    #expect(options.render(Self.palette) == """
    :root {
      --brand-500: #3b82f6;
      --brand-600: #ef4444;
    }
    """)
  }

  /// A palette of one has no position to name, so it is `--brand` rather than
  /// `--brand-1` — a suffix nothing would reference.
  @Test("A lone color takes the family name unsuffixed")
  func singleCustomProperty() {
    var options = ExportOptions.default
    options.shape = .customProperties
    options.format = .hex

    #expect(options.render([PaletteEntry(color: Self.blue)]) == """
    :root {
      --brand: #3b82f6;
    }
    """)
  }

  /// Tailwind v4's namespace prefix is load-bearing: `--color-brand-500` generates
  /// `bg-brand-500`, and `--brand-500` generates nothing at all.
  @Test("The @theme block carries Tailwind's color namespace")
  func tailwindThemeBlock() {
    var options = ExportOptions.default
    options.shape = .tailwindTheme
    options.format = .hex

    let rendered = options.render(Self.palette)
    #expect(rendered.contains("--color-brand-500: #3b82f6;"))
    #expect(rendered.hasPrefix("@theme {"))
    #expect(rendered.hasSuffix("}"))
  }

  /// Under `theme.extend`, which is the difference between adding a color and replacing
  /// the entire default palette with this one.
  @Test("The v3 config extends rather than replaces")
  func tailwindConfigBlock() {
    var options = ExportOptions.default
    options.shape = .tailwindConfig
    options.format = .hex

    #expect(options.render(Self.palette) == """
    /** @type {import('tailwindcss').Config} */
    module.exports = {
      theme: {
        extend: {
          colors: {
            brand: {
              500: '#3b82f6',
              600: '#ef4444',
            },
          },
        },
      },
    }
    """)
  }

  /// JSON mirrors Tailwind's own shape — a string for a lone color, an object for a
  /// scale — and carries CSS strings rather than this app's internals.
  @Test("JSON is a string or an object, never a ColorValue")
  func jsonShape() {
    var options = ExportOptions.default
    options.shape = .json
    options.format = .hex

    #expect(options.render([PaletteEntry(color: Self.blue)]) == """
    {
      "brand": "#3b82f6"
    }
    """)

    #expect(options.render(Self.palette) == """
    {
      "brand": {
        "500": "#3b82f6",
        "600": "#ef4444"
      }
    }
    """)

    // The failure this shape exists to prevent: `ColorValue` is `Codable`, so the
    // one-line version would have emitted the program's own field names.
    let rendered = options.render(Self.palette)
    #expect(!rendered.contains("components"))
    #expect(!rendered.contains("missing"))
  }

  @Test("An empty palette renders nothing at all")
  func emptyPaletteIsEmpty() {
    for shape in ExportShape.allCases {
      var options = ExportOptions.default
      options.shape = shape
      #expect(options.render([]).isEmpty, "\(shape) rendered a wrapper around nothing")
    }
  }
}

/// Identifiers and keys, which are where an export stops being valid syntax.
@Suite("Export identifiers")
struct ExportIdentifierTests {
  @Test(
    "Free text becomes a usable identifier",
    arguments: [
      ("brand", "brand"),
      ("my brand", "my-brand"),
      ("my  brand!", "my-brand"),
      ("  spaced  ", "spaced"),
      ("--already--hyphenated--", "already-hyphenated"),
      ("emoji🎨here", "emoji-here"),
      ("Brand", "Brand"),
      ("", "color"),
      ("!!!", "color"),
    ],
  )
  func sanitizing(input: String, expected: String) {
    #expect(ExportOptions.cssIdentifier(input) == expected)
  }

  /// The bug this prevents is a config file that will not load. Tailwind writes shade
  /// keys bare because `50:` is a legal numeric key, but a bare `triad-2:` parses as a
  /// subtraction.
  @Test(
    "JavaScript keys are quoted exactly when they must be",
    arguments: [
      ("50", "50"),
      ("950", "950"),
      ("base", "base"),
      ("_private", "_private"),
      ("triad-2", "'triad-2'"),
      ("split-complementary", "'split-complementary'"),
      ("2x", "'2x'"),
      ("", "''"),
    ],
  )
  func javaScriptKeyQuoting(input: String, expected: String) {
    #expect(ExportOptions.javaScriptKey(input) == expected)
  }

  /// A typed family name reaches the output sanitized, not raw — the panel's field
  /// accepts anything, so this is the only thing standing between a space bar and a
  /// broken stylesheet.
  @Test("A messy family name still emits valid CSS")
  func messyNameIsSanitizedInOutput() {
    var options = ExportOptions.default
    options.shape = .customProperties
    options.format = .hex
    options.name = "My Brand!"

    #expect(options.render([PaletteEntry(color: ExportShapeTests.blue)]) == """
    :root {
      --My-Brand: #3b82f6;
    }
    """)
  }

  /// Clearing the field produces the name the panel showed in it while it was empty.
  ///
  /// These were two literals before: the prompt read `brand` while an emptied name
  /// exported `--color`, because the fallback came from `cssIdentifier`'s own default.
  /// Now both are ``ExportOptions/defaultName``, and the failure mode — a property you
  /// were never shown — is a test away rather than a reading away.
  @Test("An emptied name falls back to what the placeholder promises")
  func emptyNameUsesTheDefault() {
    var options = ExportOptions.default
    options.format = .hex
    options.name = ""

    for shape in [ExportShape.customProperties, .json, .tailwindConfig] {
      options.shape = shape
      let rendered = options.render([PaletteEntry(color: ExportShapeTests.blue)])
      #expect(
        rendered.contains(ExportOptions.defaultName),
        "\(shape) named an emptied family something other than the placeholder:\n\(rendered)",
      )
      #expect(!rendered.contains("color\""), "\(shape) fell back to cssIdentifier's default")
    }

    // And the starting value is the same constant, so a fresh panel and an emptied
    // one export identically.
    #expect(ExportOptions.default.name == ExportOptions.defaultName)
  }

  /// Every exportable format can name any color, which is what makes
  /// ``ExportOptions/value(for:formatting:)``'s fallback unreachable rather than merely
  /// unused. `.keyword` is the one that cannot, and it is excluded for exactly this
  /// reason — a palette where two shades became keywords and nine did not is a document
  /// whose reader cannot tell a substitution happened.
  @Test("Exportable formats are total; keyword is not")
  func exportableFormatsNameEveryColor() {
    // Deliberately not a keyword color, and outside sRGB so the wide formats are
    // exercised too.
    let awkward = ColorValue(space: .oklch, 0.72, 0.28, 142)

    #expect(!CSSOutputFormat.exportable.contains(.keyword))
    #expect(CSSOutputFormat.exportable.count == CSSOutputFormat.catalog.count - 1)

    for format in CSSOutputFormat.exportable {
      #expect(
        awkward.cssString(as: format, options: .lossless) != nil,
        "\(format) could not name a color, so it does not belong in `exportable`",
      )
    }
    #expect(awkward.cssString(as: .keyword) == nil)
  }
}

/// Palette keys, which have to be unique or entries silently overwrite each other.
@Suite("Palette naming")
struct PaletteNamingTests {
  /// The scale is Tailwind's, and it is eleven long. A list stopping at `900` looks
  /// right and is a version out of date.
  @Test("Tailwind's scale is 50 through 950")
  func tailwindScaleIsElevenSteps() {
    #expect(PaletteNaming.tailwindScale.count == 11)
    #expect(PaletteNaming.tailwindScale.first == "50")
    #expect(PaletteNaming.tailwindScale.last == "950")
    #expect(PaletteNaming.rampKeys(count: 11) == PaletteNaming.tailwindScale)
  }

  /// A ramp that is not eleven stops gets indices instead of a mapping invented for it.
  /// Not hypothetical: ``Harmony/monochromatic`` asks for five.
  @Test("Other stop counts fall back to indices", arguments: [3, 5, 7, 9, 13, 21])
  func nonTailwindCountsUseIndices(count: Int) {
    let keys = PaletteNaming.rampKeys(count: count)
    #expect(keys.count == count)
    #expect(keys.first == "1")
    #expect(keys.last == String(count))
  }

  /// One key per member, all distinct. Two entries sharing a key would collapse into a
  /// single custom property, losing a color with no error anywhere.
  @Test("Every harmony's keys match its members and are unique", arguments: Harmony.allCases)
  func harmonyKeysAreOneToOneAndUnique(harmony: Harmony) {
    let keys = PaletteNaming.harmonyKeys(harmony)
    let members = ColorValue.srgb8(0x3B, 0x82, 0xF6).harmony(harmony)

    #expect(keys.count == members.count, "\(harmony) has \(members.count) members, \(keys.count) keys")
    #expect(Set(keys).count == keys.count, "\(harmony) repeats a key: \(keys)")
  }

  /// The key marked `base` is the member the harmony itself calls the base. These are
  /// computed independently — one from a switch here, one from the offset table in
  /// ``Harmony`` — so they can drift, and analogous is where they would: it is the only
  /// hue harmony whose base is not first.
  @Test("The base key sits where the harmony puts the base", arguments: Harmony.allCases)
  func baseKeyAgreesWithBaseIndex(harmony: Harmony) {
    let keys = PaletteNaming.harmonyKeys(harmony)
    let baseIndex = harmony.baseIndex()

    guard harmony != .monochromatic else {
      // A ramp's keys are positions on a scale, so its middle is `500`, not `base`.
      #expect(keys[baseIndex] == "3", "A five-stop ramp's middle stop is the third")
      return
    }
    #expect(keys[baseIndex] == "base", "\(harmony) marks \(keys[baseIndex]) as its base")
  }
}
