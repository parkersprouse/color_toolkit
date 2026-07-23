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
