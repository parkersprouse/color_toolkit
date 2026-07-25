//
//  ProjectLibrary.swift
//  Color Toolkit
//

import Foundation
import SwiftData

/// Every mutation the projects feature performs, in one testable place.
///
/// A thin wrapper over `ModelContext` rather than a store of its own: SwiftData already
/// owns the state, and a second copy of it in an `@Observable` class would be two
/// answers to "what is saved". What this adds is the *rules* — where a new entry's
/// position comes from, what counts as touching a project, which relationship a color
/// belongs to — and having them here rather than inline in the panel is what lets
/// ``ProjectStoreTests`` assert them against an in-memory container instead of through a
/// rendered view.
///
/// Mutations save explicitly rather than leaning on autosave. The main context autosaves
/// on its own schedule, which is fine for an app and useless for a test that wants to
/// fetch back what it just wrote.
@MainActor
struct ProjectLibrary {
  // MARK: Lifecycle

  init(_ context: ModelContext) {
    self.context = context
  }

  // MARK: Internal

  let context: ModelContext

  // MARK: - Reading

  /// Every project, newest first.
  func projects() throws -> [Project] {
    try context.fetch(
      FetchDescriptor<Project>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]),
    )
  }

  /// The project ``ColorStore/selectedProjectID`` names, if it still exists.
  ///
  /// Looked up by ``Project/uuid`` rather than by `PersistentIdentifier` so the selection
  /// can live on a store that does not import SwiftData — see the note on that property.
  func project(uuid: UUID) throws -> Project? {
    var descriptor = FetchDescriptor<Project>(predicate: #Predicate { $0.uuid == uuid })
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
  }

  // MARK: - Projects

  @discardableResult
  func createProject(named name: String) throws -> Project {
    let project = Project(name: Self.cleaned(name, fallback: Self.untitledProject))
    context.insert(project)
    try context.save()
    return project
  }

  func rename(_ project: Project, to name: String) throws {
    project.name = Self.cleaned(name, fallback: Self.untitledProject)
    project.touch()
    try context.save()
  }

  /// Deletes a project and, by cascade, everything inside it.
  ///
  /// The cascade is declared on the relationships rather than performed here, so this
  /// cannot fall out of step with a palette added later. ``ProjectStoreTests`` asserts
  /// that nothing survives, because an orphaned `SavedColor` is invisible — it belongs
  /// to no project, so no view would ever show it and no user would ever know.
  func delete(_ project: Project) throws {
    context.delete(project)
    try context.save()
  }

  // MARK: - Colors

  /// Saves one color into a project's loose colors.
  @discardableResult
  func saveColor(
    _ record: ColorRecord,
    named name: String = "",
    to project: Project,
  ) throws -> SavedColor {
    let color = SavedColor(
      record: record,
      name: name.trimmingCharacters(in: .whitespacesAndNewlines),
      sortIndex: Self.nextIndex(after: project.colors.map(\.sortIndex)),
    )
    context.insert(color)
    color.project = project
    project.touch()
    try context.save()
    return color
  }

  func delete(_ color: SavedColor) throws {
    color.project?.touch()
    color.palette?.project?.touch()
    context.delete(color)
    try context.save()
  }

  // MARK: - Palettes

  /// Saves a set of colors as a palette, keeping their order and their keys.
  ///
  /// The entries arrive as ``PaletteEntry`` — the same value type the export layer
  /// consumes — so this is the one direction the boundary is crossed in: values in,
  /// models out. A ramp's keys become its entries' names, which is what lets a saved
  /// ramp export as `--brand-500` again months later.
  @discardableResult
  func savePalette(
    _ entries: [PaletteEntry],
    named name: String,
    kind: PaletteKind,
    to project: Project,
  ) throws -> Palette {
    let palette = Palette(
      name: Self.cleaned(name, fallback: kind.title),
      kind: kind,
      sortIndex: Self.nextIndex(after: project.palettes.map(\.sortIndex)),
    )
    context.insert(palette)
    palette.project = project

    for (index, entry) in entries.enumerated() {
      let color = SavedColor(
        record: .derived(entry.color, preferring: .oklch),
        name: entry.key,
        sortIndex: index,
      )
      context.insert(color)
      color.palette = palette
    }

    project.touch()
    try context.save()
    return palette
  }

  func rename(_ palette: Palette, to name: String) throws {
    palette.name = Self.cleaned(name, fallback: palette.kind.title)
    palette.project?.touch()
    try context.save()
  }

  func delete(_ palette: Palette) throws {
    palette.project?.touch()
    context.delete(palette)
    try context.save()
  }

  // MARK: Private

  private static let untitledProject = "Untitled Project"

  /// Trimmed, and never empty. A blank name is a row you cannot click on in a list, so
  /// the fallback is applied at the point of storage rather than at the point of
  /// display — where every future view would have to remember it.
  private static func cleaned(_ name: String, fallback: String) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? fallback : trimmed
  }

  /// One past the highest position in use, so a new entry lands at the end even after
  /// deletions have left gaps. `count` would collide: delete the middle of three and the
  /// next insert would reuse position 2.
  private static func nextIndex(after existing: [Int]) -> Int {
    (existing.max() ?? -1) + 1
  }
}
