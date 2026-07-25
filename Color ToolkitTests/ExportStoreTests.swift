//
//  ExportStoreTests.swift
//  Color ToolkitTests
//

@testable import Color_Toolkit
import Foundation
import Testing

/// The seam between the app's state and the export layer: which colors a source names,
/// and under which keys.
///
/// This lives on ``ColorStore`` rather than in the panel precisely so it can be asserted
/// here. Built into the view, "the ramp exports eleven entries keyed 50 to 950" would be
/// reachable only through XCUITest — a claim about a data structure, checked by reading
/// a rendered string.
///
/// - Note: Nothing here calls ``ColorStore/copyExport()``, for the reason
///   ``ColorStoreTests`` gives about ``ColorStore/copy(_:)``: it writes to the real
///   system pasteboard, and a test has no business clobbering it.
@MainActor
@Suite("Export sources")
struct ExportSourceTests {
  @Test("A lone color exports one unkeyed entry")
  func singleColorHasNoKey() throws {
    let store = ColorStore(initialInput: "#3b82f6")
    store.exportSource = .color

    let entries = store.exportEntries
    #expect(entries.count == 1)
    #expect(try #require(entries.first).key.isEmpty)
    #expect(try #require(entries.first).color == ColorValue.srgb8(0x3B, 0x82, 0xF6))
  }

  /// The default ramp is eleven stops, which is exactly Tailwind's scale — so this is
  /// also the check that the two stayed lined up.
  @Test("The default ramp exports Tailwind's eleven keys")
  func rampUsesTailwindKeys() {
    let store = ColorStore(initialInput: "#3b82f6")
    store.exportSource = .ramp

    #expect(store.exportEntries.map(\.key) == PaletteNaming.tailwindScale)
  }

  /// Moving the stepper off eleven has to change the keys too, or ten stops would be
  /// written under eleven names and one color would vanish.
  @Test("A resized ramp falls back to indices")
  func resizedRampUsesIndices() {
    let store = ColorStore(initialInput: "#3b82f6")
    store.exportSource = .ramp
    store.shadeRamp.stops = 5

    #expect(store.exportEntries.map(\.key) == ["1", "2", "3", "4", "5"])
  }

  /// Keys and colors stay in step across every harmony. `zip` truncates silently, so a
  /// naming table one entry short would drop a color with nothing to show for it.
  @Test("Harmony entries pair every member with a key", arguments: Harmony.allCases)
  func harmonyEntriesArePaired(harmony: Harmony) {
    let store = ColorStore(initialInput: "#3b82f6")
    store.exportSource = .harmony
    store.harmony = harmony

    let entries = store.exportEntries
    let members = try? #require(store.color).harmony(harmony, options: store.harmonyOptions)

    #expect(entries.count == members?.count)
    #expect(entries.map(\.color) == members)
    #expect(Set(entries.map(\.key)).count == entries.count)
  }

  /// Empty until something is filed, which is the one source that can legitimately have
  /// nothing in it — and the reason the panel has a message for that case.
  @Test("Recents export in the order they are shown")
  func recentsAreNewestFirst() {
    let store = ColorStore(initialInput: "#3b82f6")
    store.exportSource = .recents
    #expect(store.exportEntries.isEmpty)

    store.remember()
    store.inputText = "#ef4444"
    store.remember()

    let entries = store.exportEntries
    #expect(entries.map(\.key) == ["1", "2"])
    #expect(entries.first?.color == ColorValue.srgb8(0xEF, 0x44, 0x44))
  }

  /// No color in the field means nothing to export, from any source — the panel shows
  /// its unavailable state instead, and the document must not be a lone `:root {}`.
  @Test("An empty field exports nothing at all", arguments: ExportSource.allCases)
  func noColorExportsNothing(source: ExportSource) {
    let store = ColorStore(initialInput: "not a color")
    store.exportSource = source

    #expect(store.exportEntries.isEmpty)
    #expect(store.exportDocument.isEmpty)
  }

  /// The panel's precision control and the toolbar's are one setting, so writing through
  /// either has to move the document. If these ever became separate state this is the
  /// assertion that would fail.
  @Test("The document follows the app-wide precision")
  func documentFollowsFormatOptions() {
    let store = ColorStore(initialInput: "#3b82f6")
    store.exportSource = .color
    store.exportOptions.format = .oklch

    store.formatOptions.precision = 2
    let coarse = store.exportDocument
    store.formatOptions.precision = 10
    let fine = store.exportDocument

    #expect(coarse != fine)
    #expect(fine.count > coarse.count)
  }

  /// The badge counts what the serializer actually moved, because both ask the same
  /// predicate. A hex export of a wide color moves it; an OKLCH export of the same color
  /// does not, OKLCH being unbounded.
  @Test("The mapped count agrees with the format's reach")
  func mappedCountTracksTheFormat() {
    let store = ColorStore(initialInput: "oklch(0.72 0.28 142)")
    store.exportSource = .color

    store.exportOptions.format = .hex
    #expect(store.exportGamutMappedCount == 1)

    store.exportOptions.format = .oklch
    #expect(store.exportGamutMappedCount == 0)
  }
}

/// The export panel's own wording and controls.
///
/// Unlike ``FormatSection``, the presentation here is written as exhaustive `switch`es,
/// so "every case has a title" is already a compile error rather than a test. What the
/// compiler cannot check is that the titles are *usable* — a picker with two identical
/// rows compiles perfectly and is unusable.
///
/// - Note: `@MainActor` for ``Tool`` alone. ``ExportShape`` and ``ExportTemplate`` are
///   `nonisolated`, but `Tool` is shell state that only views ever read, so under
///   `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` its `title` is main-actor isolated. The
///   suite hops rather than the type being loosened, since nothing outside the UI has
///   any business reading it.
@MainActor
@Suite("Export presentation")
struct ExportPresentationTests {
  @Test("Shape titles are distinct and non-empty")
  func shapeTitlesAreUsable() {
    let titles = ExportShape.allCases.map(\.title)
    #expect(titles.allSatisfy { !$0.isEmpty })
    #expect(Set(titles).count == titles.count)
    #expect(ExportShape.allCases.allSatisfy { !$0.summary.isEmpty })
  }

  @Test("Template titles are distinct and name their property")
  func templateTitlesAreUsable() {
    let titles = ExportTemplate.allCases.map(\.title)
    #expect(Set(titles).count == titles.count)
    #expect(ExportTemplate.allCases.allSatisfy { $0.title.hasPrefix($0.property) })
  }

  /// Exactly one shape takes a declaration template, and it is the one that takes no
  /// family name. The panel hides whichever control does not apply, so a shape answering
  /// `true` to both would show a name field that changes nothing.
  @Test("Template and name apply to opposite shapes", arguments: ExportShape.allCases)
  func templateAndNameAreComplementary(shape: ExportShape) {
    #expect(shape.usesTemplate != shape.usesName)
  }

  /// Every tool the switcher offers has a panel behind it. `ContentView`'s `switch` is
  /// exhaustive so a missing branch will not compile, but a `Tool` case added without a
  /// title would render a blank segment.
  @Test("Every tool is labelled")
  func everyToolHasATitle() {
    #expect(Tool.allCases.allSatisfy { !$0.title.isEmpty })
    #expect(Set(Tool.allCases.map(\.title)).count == Tool.allCases.count)
    #expect(Tool.allCases.last == .export, "Export is terminal and belongs last")
  }
}
