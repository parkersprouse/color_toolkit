//
//  ProjectStoreTests.swift
//  Color ToolkitTests
//

@testable import Color_Toolkit
import Foundation
import SwiftData
import Testing

/// The persistence layer against a real, in-memory `ModelContainer`.
///
/// Everything here needs a container because everything here is about what SwiftData
/// does — relationships, cascades, what comes back from a fetch. The *mapping* is
/// asserted in ``ColorRecordTests``, which needs none of this.
@MainActor
@Suite("Project store")
struct ProjectStoreTests {
  // MARK: Internal

  /// The first assertion, and not a formality.
  ///
  /// ``SavedColor`` is the destination of two to-many relationships — a project's loose
  /// colors and a palette's entries — and SwiftData resolves inverses when the container
  /// is built, not when the code compiles. Get it wrong and every model still compiles,
  /// every property still type-checks, and the app throws on launch. This is the check
  /// that turns that into a test failure.
  @Test("The schema builds a container")
  func containerBuilds() throws {
    let container = try Self.makeContainer()

    #expect(container.schema.entities.count == 3)
  }

  /// The app's own factory, not just a hand-rolled container — the launch argument is
  /// the only thing standing between a UI test and the user's real library, so it is
  /// worth an assertion of its own.
  ///
  /// It reports ``PersistenceStack/Status/ephemeralByRequest`` rather than
  /// ``PersistenceStack/Status/unavailable``, which is the distinction that keeps the
  /// panel from warning about a failure that did not happen. The two were one flag until
  /// the UI-test screenshots showed the app announcing a store it "could not open"
  /// during a run that had asked for exactly that store.
  @Test("The launch argument produces a store that says why it is ephemeral")
  func launchArgumentIsEphemeralByRequest() {
    #expect(PersistenceStack.make(inMemory: true).status == .ephemeralByRequest)
  }

  @Test("A saved color comes back as the color that went in")
  func savedColorRoundTrips() throws {
    let library = try Self.makeLibrary()
    let project = try library.createProject(named: "Site")
    let blue = try #require(CSSColorParser.parse("#3b82f6").color)

    try library.saveColor(ColorRecord(blue, text: "#3b82f6"), named: "Brand", to: project)

    let reloaded = try #require(try library.projects().first)
    let color = try #require(reloaded.orderedColors.first)
    #expect(color.name == "Brand")
    #expect(color.colorValue == blue)
  }

  /// The reason the spelling is stored at all, asserted end to end rather than only at
  /// the bridge: recalling this color has to put `rebeccapurple` back in the field, not
  /// the `#663399` a serializer would hand back.
  @Test("A recalled color keeps the spelling it was saved with")
  func savedColorKeepsItsSpelling() throws {
    let library = try Self.makeLibrary()
    let project = try library.createProject(named: "Site")
    let purple = try #require(CSSColorParser.parse("rebeccapurple").color)

    try library.saveColor(ColorRecord(purple, text: "rebeccapurple"), to: project)

    let color = try #require(try library.projects().first?.orderedColors.first)
    #expect(color.text == "rebeccapurple")
  }

  /// A ramp's order *is* its meaning, and a to-many relationship does not promise one —
  /// hence ``SavedColor/sortIndex`` and the sort on read. Eleven stops shuffled is not a
  /// ramp, and the eleven keys would then name the wrong colors.
  @Test("A saved palette keeps its order and its keys")
  func savedPaletteKeepsOrderAndKeys() throws {
    let library = try Self.makeLibrary()
    let project = try library.createProject(named: "Site")
    let base = try #require(CSSColorParser.parse("#3b82f6").color)
    let stops = ShadeRamp.default.generated(from: base)
    let entries = zip(PaletteNaming.rampKeys(count: stops.count), stops)
      .map { PaletteEntry(key: $0, color: $1) }

    try library.savePalette(entries, named: "Brand", kind: .ramp, to: project)

    let palette = try #require(try library.projects().first?.orderedPalettes.first)
    #expect(palette.kind == .ramp)
    #expect(palette.paletteEntries.map(\.key) == PaletteNaming.tailwindScale)
    // Lightest first, all the way down — the property the ramp itself guarantees, now
    // asserted on the other side of a save.
    let lightnesses = palette.paletteEntries.map { $0.color.converted(to: .oklch).components.x }
    #expect(lightnesses == lightnesses.sorted(by: >))
  }

  /// Every stop of a saved ramp has to survive the trip, not just the ends. The stored
  /// spelling is `oklch()` at lossless precision, so agreement here is tight.
  @Test("Every palette entry survives the round trip")
  func paletteEntriesSurvive() throws {
    let library = try Self.makeLibrary()
    let project = try library.createProject(named: "Site")
    let base = try #require(CSSColorParser.parse("#3b82f6").color)
    let original = ShadeRamp.default.generated(from: base)
    let entries = zip(PaletteNaming.rampKeys(count: original.count), original)
      .map { PaletteEntry(key: $0, color: $1) }

    try library.savePalette(entries, named: "Brand", kind: .ramp, to: project)

    let restored = try #require(try library.projects().first?.orderedPalettes.first)
      .paletteEntries.map(\.color)
    #expect(restored.count == original.count)
    for (saved, source) in zip(restored, original) {
      #expect(saved.deltaEOK(to: source) < 1e-9)
    }
  }

  /// An orphaned `SavedColor` belongs to no project, so no view would ever show it and
  /// nobody would ever know it was there. The cascade is declared on the relationships;
  /// this is what proves it reaches both of them — the loose colors *and* the ones two
  /// levels down inside a palette.
  @Test("Deleting a project takes its colors and palettes with it")
  func deletingAProjectCascades() throws {
    let library = try Self.makeLibrary()
    let project = try library.createProject(named: "Site")
    let blue = try #require(CSSColorParser.parse("#3b82f6").color)
    try library.saveColor(ColorRecord(blue, text: "#3b82f6"), to: project)
    try library.savePalette(
      [PaletteEntry(key: "base", color: blue), PaletteEntry(key: "alt", color: blue)],
      named: "Brand",
      kind: .harmony,
      to: project,
    )
    #expect(try library.context.fetch(FetchDescriptor<SavedColor>()).count == 3)

    try library.delete(project)

    #expect(try library.projects().isEmpty)
    #expect(try library.context.fetch(FetchDescriptor<Palette>()).isEmpty)
    #expect(try library.context.fetch(FetchDescriptor<SavedColor>()).isEmpty)
  }

  /// Deleting a palette must not reach the project's loose colors, which is the other
  /// half of the cascade being right: one shared inverse would take both.
  @Test("Deleting a palette leaves the project's own colors alone")
  func deletingAPaletteSparesLooseColors() throws {
    let library = try Self.makeLibrary()
    let project = try library.createProject(named: "Site")
    let blue = try #require(CSSColorParser.parse("#3b82f6").color)
    try library.saveColor(ColorRecord(blue, text: "#3b82f6"), to: project)
    let palette = try library.savePalette(
      [PaletteEntry(key: "base", color: blue)],
      named: "Brand",
      kind: .harmony,
      to: project,
    )

    try library.delete(palette)

    let reloaded = try #require(try library.projects().first)
    #expect(reloaded.orderedColors.count == 1)
    #expect(reloaded.orderedPalettes.isEmpty)
    #expect(try library.context.fetch(FetchDescriptor<SavedColor>()).count == 1)
  }

  /// Positions come from one past the highest in use, not from the count. Delete the
  /// middle of three and a count-based index would reuse position 2, putting the new
  /// color *before* the one already sitting there.
  @Test("A new color lands last even after a deletion")
  func newColorsLandLast() throws {
    let library = try Self.makeLibrary()
    let project = try library.createProject(named: "Site")
    let colors = ["#ff0000", "#00ff00", "#0000ff"]
    for css in colors {
      let color = try #require(CSSColorParser.parse(css).color)
      try library.saveColor(ColorRecord(color, text: css), named: css, to: project)
    }

    let middle = try #require(project.orderedColors.dropFirst().first)
    try library.delete(middle)
    let added = try #require(CSSColorParser.parse("#ffff00").color)
    try library.saveColor(ColorRecord(added, text: "#ffff00"), named: "#ffff00", to: project)

    #expect(project.orderedColors.map(\.name) == ["#ff0000", "#0000ff", "#ffff00"])
  }

  /// A blank name is a row nothing in a list can show, so the fallback is applied where
  /// the value is stored rather than in every view that will ever display one.
  @Test("An empty project name falls back rather than storing nothing")
  func emptyNamesFallBack() throws {
    let library = try Self.makeLibrary()

    let project = try library.createProject(named: "   ")
    let palette = try library.savePalette(
      [PaletteEntry(color: ColorValue.srgb8(0, 0, 0))],
      named: "",
      kind: .ramp,
      to: project,
    )

    #expect(!project.name.isEmpty)
    #expect(palette.name == PaletteKind.ramp.title)
  }

  /// The selection on ``ColorStore`` is a `UUID` so the store need not import SwiftData;
  /// this is the lookup that makes that indirection work, including the case that
  /// matters — a project deleted while it was the selected one.
  @Test("A project is findable by the id the store remembers")
  func projectsAreFindableByUUID() throws {
    let library = try Self.makeLibrary()
    let project = try library.createProject(named: "Site")
    let id = project.uuid

    #expect(try library.project(uuid: id)?.name == "Site")

    try library.delete(project)
    #expect(try library.project(uuid: id) == nil)
  }

  /// Notes are edited by binding a `TextField` straight to the model, so the write has
  /// already happened by the time anything is called — what ``ProjectLibrary/touch(_:)``
  /// adds is the flush and the timestamp. This is the assertion that the note survives a
  /// fetch rather than living only in the object the panel happens to be holding.
  @Test("A note on a saved color persists")
  func notesPersist() throws {
    let library = try Self.makeLibrary()
    let project = try library.createProject(named: "Site")
    let blue = try #require(CSSColorParser.parse("#3b82f6").color)
    let color = try library.saveColor(ColorRecord(blue, text: "#3b82f6"), named: "Brand", to: project)

    color.notes = "Primary call to action only"
    try library.touch(color)

    let reloaded = try #require(try library.projects().first?.orderedColors.first)
    #expect(reloaded.notes == "Primary call to action only")
  }

  /// `modifiedAt` should mean what it says. Saving into a project is a modification of
  /// it, even though nothing about the `Project` row itself changed.
  @Test("Saving into a project marks it modified")
  func savingTouchesTheProject() throws {
    let library = try Self.makeLibrary()
    let project = try library.createProject(named: "Site")
    let before = project.modifiedAt
    let blue = try #require(CSSColorParser.parse("#3b82f6").color)

    try library.saveColor(ColorRecord(blue, text: "#3b82f6"), to: project)

    #expect(project.modifiedAt > before)
  }

  /// The claim the whole milestone rests on, and the only test here that leaves memory.
  ///
  /// Every other test in this file uses `isStoredInMemoryOnly`, which proves round
  /// tripping *within* a context and structurally cannot prove that anything survives the
  /// app being quit — the thing "saved projects" actually means. So this one writes to a
  /// real SQLite store, drops the container entirely, opens a second one over the same
  /// file and reads it back.
  ///
  /// Both halves of the store's meaning are checked: `rebeccapurple` for the spelling,
  /// and the ramp for order, since ``SavedColor/sortIndex`` is doing its work across a
  /// genuine reopen here rather than across one in-memory fetch.
  ///
  /// The temp path is a *directory*, not a bare file. SQLite writes `-wal` and `-shm`
  /// sidecars beside the store, and removing only the `.store` would leave state behind
  /// that could make a later run pass for the wrong reason.
  @Test("A saved project survives the store closing and reopening")
  func dataSurvivesAReopen() throws {
    let directory = URL.temporaryDirectory
      .appending(path: "m9-reopen-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "projects.store")

    let purple = try #require(CSSColorParser.parse("rebeccapurple").color)
    let base = try #require(CSSColorParser.parse("#3b82f6").color)
    let stops = ShadeRamp.default.generated(from: base)

    // Scoped so the container is released before the second one opens the same file.
    do {
      let library = try ProjectLibrary(ModelContext(Self.makeContainer(at: url)))
      let project = try library.createProject(named: "Site")
      try library.saveColor(ColorRecord(purple, text: "rebeccapurple"), named: "Brand", to: project)
      try library.savePalette(
        zip(PaletteNaming.rampKeys(count: stops.count), stops)
          .map { PaletteEntry(key: $0, color: $1) },
        named: "Brand",
        kind: .ramp,
        to: project,
      )
    }

    let library = try ProjectLibrary(ModelContext(Self.makeContainer(at: url)))
    let project = try #require(try library.projects().first)
    #expect(project.name == "Site")

    let color = try #require(project.orderedColors.first)
    #expect(color.text == "rebeccapurple")
    #expect(color.colorValue == purple)
    #expect(color.name == "Brand")

    let palette = try #require(project.orderedPalettes.first)
    #expect(palette.kind == .ramp)
    #expect(palette.paletteEntries.map(\.key) == PaletteNaming.tailwindScale)
    for (saved, source) in zip(palette.paletteEntries.map(\.color), stops) {
      #expect(saved.deltaEOK(to: source) < 1e-9)
    }
  }

  // MARK: Private

  /// A store on disk, for the one test that has to leave memory.
  private static func makeContainer(at url: URL) throws -> ModelContainer {
    try ModelContainer(
      for: PersistenceStack.schema,
      configurations: ModelConfiguration(schema: PersistenceStack.schema, url: url),
    )
  }

  /// A container that exists only for the duration of one test. Nothing here may touch
  /// the store the app itself writes to.
  private static func makeContainer() throws -> ModelContainer {
    try ModelContainer(
      for: PersistenceStack.schema,
      configurations: ModelConfiguration(
        schema: PersistenceStack.schema,
        isStoredInMemoryOnly: true,
      ),
    )
  }

  private static func makeLibrary() throws -> ProjectLibrary {
    try ProjectLibrary(ModelContext(makeContainer()))
  }
}
