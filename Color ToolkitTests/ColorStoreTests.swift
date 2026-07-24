//
//  ColorStoreTests.swift
//  Color ToolkitTests
//

import Foundation
import Testing

@testable import Color_Toolkit

/// - Note: Nothing here calls ``ColorStore/copy(_:)``. It writes to the real system
///   pasteboard, and a test suite has no business clobbering whatever the person
///   running it had copied.
@MainActor
@Suite("Color store")
struct ColorStoreTests {

    @Test("Starts on a parsed color")
    func initialState() throws {
        let store = ColorStore(initialInput: "rebeccapurple")
        let color = try #require(store.color)

        #expect(color == ColorValue.srgb8(102, 51, 153))
        #expect(store.parsed.error == nil)
        #expect(store.recents.isEmpty)
    }

    @Test("Empty input clears the color")
    func emptyInputClears() {
        let store = ColorStore(initialInput: "red")
        store.inputText = "   "

        #expect(store.color == nil)
        #expect(store.parsed == .empty)
    }

    /// The behavior that makes live parsing bearable. Every prefix of `#3b82f6` is
    /// typed on the way to it, and most of them are invalid; blanking the whole
    /// conversion panel on each one reads as the app breaking, not as feedback.
    @Test("An invalid edit keeps the last good color on screen")
    func invalidEditRetainsLastColor() throws {
        let store = ColorStore(initialInput: "#3b82f6")
        let before = try #require(store.color)

        store.inputText = "#3b82f"

        #expect(store.color == before)
        #expect(store.parsed.error != nil)
    }

    @Test("Warnings surface without failing the parse")
    func warningsAreReported() throws {
        let store = ColorStore(initialInput: "oklch(0.7, 0.15, 250)")

        #expect(store.color != nil)
        #expect(store.parsed.error == nil)
        #expect(store.parsed.warnings == [.commasInModernFunction("oklch")])
    }

    // MARK: - Recents

    @Test("Remembering keeps the authored text, not a canonical form")
    func recentsPreserveAuthoredText() throws {
        let store = ColorStore(initialInput: "rebeccapurple")
        store.remember()

        let recent = try #require(store.recents.first)
        #expect(recent.text == "rebeccapurple")
        #expect(recent.color == ColorValue.srgb8(102, 51, 153))
    }

    @Test("The same color moves to the front instead of piling up")
    func recentsDedupeByValue() {
        let store = ColorStore(initialInput: "red")
        store.remember()
        store.inputText = "blue"
        store.remember()
        // A different spelling of a color already in the list.
        store.inputText = "#ff0000"
        store.remember()

        #expect(store.recents.count == 2)
        #expect(store.recents.first?.text == "#ff0000")
    }

    /// Colors are deduplicated by value, and a value carries its space. `rgb()` and
    /// `hsl()` describe the same pixel but are not the same authored color — which
    /// space a color lives in is exactly what this app refuses to discard.
    @Test("The same pixel in two spaces stays two entries")
    func recentsKeepSpaceDistinction() {
        let store = ColorStore(initialInput: "rgb(255 0 0)")
        store.remember()
        store.inputText = "hsl(0 100% 50%)"
        store.remember()

        #expect(store.recents.count == 2)
    }

    @Test("Recents are capped")
    func recentsAreCapped() {
        let store = ColorStore(initialInput: "red")
        for value in 0..<40 {
            store.inputText = "rgb(\(value) 0 0)"
            store.remember()
        }

        #expect(store.recents.count == 12)
        // Newest first.
        #expect(store.recents.first?.text == "rgb(39 0 0)")
    }

    @Test("Nothing invalid reaches recents")
    func invalidInputIsNotRemembered() {
        let store = ColorStore(initialInput: "not-a-color")
        store.remember()

        #expect(store.recents.isEmpty)
    }

    @Test("Choosing a recent restores the text that made it")
    func usingARecentRestoresItsText() {
        let store = ColorStore(initialInput: "oklch(0.7 0.15 250)")
        store.remember()
        store.inputText = "red"

        store.use(store.recents[0])

        #expect(store.inputText == "oklch(0.7 0.15 250)")
        #expect(store.color?.space == .oklch)
    }

    @Test("Adopting a color writes it into the field")
    func adoptWritesInput() {
        let store = ColorStore(initialInput: "")
        store.adopt(.srgb8(59, 130, 246))

        #expect(store.inputText == "#3b82f6")
        #expect(store.color == ColorValue.srgb8(59, 130, 246))
    }

    /// The trap `adopt` has to dodge. This store keeps *text* as its source of truth,
    /// so an adopted color is serialized and immediately parsed back — and hex is
    /// 8-bit sRGB. Spelling a P3 sample as hex would gamut-map it on the way in and
    /// hand back a color the screen never showed, undoing the entire point of reading
    /// the pixel in a wide space to begin with.
    @Test("Adopting a wide-gamut color does not quietly flatten it into sRGB")
    func adoptPreservesWideGamut() throws {
        let store = ColorStore(initialInput: "")
        let p3Red = ColorValue(space: .displayP3, 1, 0, 0)
        store.adopt(p3Red)

        let readBack = try #require(store.color)
        #expect(readBack.exceedsSRGB, "the trip through text flattened the color")
        #expect(readBack.deltaEOK(to: p3Red) < 1e-9)

        // The obvious spelling, shown next to the working one. Hex has to gamut-map to
        // exist at all, and what comes back is a color the display never showed.
        let asHex = try #require(p3Red.cssString(as: .hex))
        let viaHex = try CSSColorParser.parse(asHex).color
        #expect(!viaHex.exceedsSRGB)
        #expect(viaHex.deltaEOK(to: p3Red) > 0.01)
    }

    /// Display precision and storage precision are separate settings for a reason: a
    /// panel that rounds re-derives from the original next frame, while a stored
    /// string that rounds has destroyed it.
    @Test("Adoption ignores the display precision the user picked")
    func adoptIgnoresDisplayPrecision() throws {
        let store = ColorStore(initialInput: "")
        store.formatOptions.precision = 2  // "Compact"

        // Deliberately outside sRGB, so adoption takes the `color(display-p3 …)`
        // branch where precision is actually expressible — a color hex could spell
        // would round-trip through 8-bit integers and prove nothing about digits.
        // colorjs.io 0.7.0 puts these coordinates out of sRGB, and confirms that
        // rounding them to two decimals costs ΔEOK 0.00124 — a difference this
        // assertion is six orders of magnitude tighter than.
        let sampled = ColorValue(space: .displayP3, 0.9876543210, 0.1234567891, 0.0246813579)
        store.adopt(sampled)

        let readBack = try #require(store.color)
        #expect(readBack.exceedsSRGB)
        #expect(readBack.deltaEOK(to: sampled) < 1e-9)
    }

    /// Alpha is the component most easily lost, because the default alpha policy omits
    /// it whenever a color is opaque.
    @Test("Adopting keeps partial alpha")
    func adoptKeepsAlpha() throws {
        let store = ColorStore(initialInput: "")
        store.adopt(ColorValue(space: .srgb, 1, 0, 0, alpha: 0.4))

        let readBack = try #require(store.color)
        #expect(abs(readBack.alpha - 0.4) < 1e-9)
    }

    // MARK: - Output

    @Test("Format options flow through to every row")
    func formatOptionsApply() throws {
        let store = ColorStore(initialInput: "#ffcc00")
        store.formatOptions.uppercaseHex = true
        store.formatOptions.collapseHex = true

        let hex = try #require(store.formats.first { $0.format == .hex })
        #expect(hex.css == "#FC0")
    }

    @Test("No color means no rows")
    func noColorMeansNoFormats() {
        let store = ColorStore(initialInput: "")
        #expect(store.formats.isEmpty)
    }
}
