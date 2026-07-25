//
//  ProjectsPanel.swift
//  Color Toolkit
//

import SwiftData
import SwiftUI

/// The colors you decided to keep.
///
/// Every other tool answers a question about the color in the field and forgets it the
/// moment the field changes; this one is the only place the app remembers anything on
/// purpose. So the two directions it runs in are the whole feature: **saving** what the
/// other tools produced, and **recalling** it into the field they all read from.
///
/// **The panel owns the only `@Query` and the only `modelContext` in the app.** Nothing
/// downstream of here knows SwiftData exists — a palette leaves as `[PaletteEntry]`,
/// which is the same value type a harmony produces, which is why exporting a saved
/// palette needed one enum case rather than a second path through the export layer. The
/// mutations themselves live in ``ProjectLibrary`` so their rules can be tested against
/// a container instead of through a rendered view.
struct ProjectsPanel: View {
  // MARK: Internal

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        if storeStatus == .unavailable {
          unavailableBanner
        }
        if let message = errorMessage {
          Label(message, systemImage: "exclamationmark.triangle")
            .font(.callout)
            .foregroundStyle(.secondary)
        }

        if projects.isEmpty {
          emptyState
        } else {
          header
          if let project = selectedProject {
            Divider()
            saveControls(project)
            colorsSection(project)
            palettesSection(project)
          }
        }
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  // MARK: Private

  /// The sets worth keeping. ``ExportSource/color`` is absent because Save Color already
  /// does that one, and ``ExportSource/saved`` because saving a saved palette back into
  /// the project it came from is a loop with nothing at the end of it.
  private static let savableSets: [ExportSource] = [.harmony, .ramp, .recents]

  @Environment(ColorStore.self) private var store
  @Environment(\.modelContext) private var context
  @Environment(\.projectStoreStatus) private var storeStatus

  /// Newest first, matching ``ProjectLibrary/projects()`` — the panel and the tests
  /// should not disagree about what "first" means.
  @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]

  /// The name a save will use. One field for both buttons, because naming the thing you
  /// are about to keep is the same act whether it is one color or eleven.
  @State private var entryName = ""
  @State private var errorMessage: String?
  @State private var confirmingProjectDeletion = false

  /// Which saved color's notes are open. A `@Model` is `Identifiable`, so this drives
  /// `.popover(item:)` directly.
  @State private var noteTarget: SavedColor?

  private var library: ProjectLibrary {
    ProjectLibrary(context)
  }

  /// The selected project, falling back to the newest.
  ///
  /// A fallback rather than a write, because this is read during `body`: correcting the
  /// stored selection here would mutate observed state mid-update. The selection is only
  /// ever written by the picker and by ``create()``.
  private var selectedProject: Project? {
    projects.first { $0.uuid == store.selectedProjectID } ?? projects.first
  }

  // MARK: - Chrome

  /// Shown only for ``PersistenceStack/Status/unavailable``, never for a store that is
  /// ephemeral because a test asked it to be. Silence in the failing case would be the
  /// worst option available — the panel would work perfectly and lose everything at
  /// quit — but a warning shown when nothing is wrong is a warning nobody reads.
  private var unavailableBanner: some View {
    Label(
      "Saving is not available — the projects store could not be opened, so anything "
        + "saved here lasts only until you quit.",
      systemImage: "exclamationmark.triangle.fill",
    )
    .font(.callout)
    .foregroundStyle(.secondary)
    .fixedSize(horizontal: false, vertical: true)
  }

  private var emptyState: some View {
    ContentUnavailableView {
      Label("No projects yet", systemImage: "folder")
    } description: {
      Text("A project is somewhere to keep the colors and palettes you want back later.")
    } actions: {
      Button("New Project") { create() }
        .accessibilityIdentifier("projectsNew")
    }
    .frame(maxWidth: .infinity)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 12) {
      LabeledContent("Project") {
        HStack(spacing: 8) {
          Picker(
            "Project",
            selection: Binding(
              get: { selectedProject?.uuid },
              set: { store.selectedProjectID = $0 },
            ),
          ) {
            ForEach(projects) { project in
              Text(project.name).tag(Optional(project.uuid))
            }
          }
          .labelsHidden()
          .accessibilityIdentifier("projectsPicker")

          Button("New") { create() }
            .accessibilityIdentifier("projectsNew")

          Button("Delete", role: .destructive) { confirmingProjectDeletion = true }
            .accessibilityIdentifier("projectsDelete")
            .disabled(selectedProject == nil)
        }
      }

      if let project = selectedProject {
        // Bound straight to the model, which SwiftData observes, so typing renames in
        // place. Committing on submit rather than per keystroke is what applies the
        // empty-name fallback and stamps `modifiedAt` once instead of thirty times.
        LabeledContent("Name") {
          @Bindable var project = project
          TextField("Name", text: $project.name)
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 240)
            .accessibilityIdentifier("projectName")
            .onSubmit { perform { try library.rename(project, to: project.name) } }
        }
      }
    }
    .confirmationDialog(
      "Delete “\(selectedProject?.name ?? "")”?",
      isPresented: $confirmingProjectDeletion,
    ) {
      Button("Delete Project", role: .destructive) {
        guard let project = selectedProject else { return }
        perform {
          try library.delete(project)
          store.selectedProjectID = nil
        }
      }
    } message: {
      Text("Its colors and palettes go with it. This cannot be undone.")
    }
  }

  // MARK: - Saving

  private func saveControls(_ project: Project) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      LabeledContent("Save as") {
        TextField("Save as", text: $entryName, prompt: Text("Optional name"))
          .textFieldStyle(.roundedBorder)
          .frame(maxWidth: 240)
          .accessibilityIdentifier("saveName")
      }

      HStack(spacing: 8) {
        Button("Save Color") { saveColor(to: project) }
          .disabled(store.color == nil)
          .accessibilityIdentifier("saveColor")

        // The sets the other tools are producing right now, asked for by name rather
        // than read off `exportSource` — saving the harmony while the export panel is
        // set to something else is an ordinary thing to want.
        Menu("Save Set") {
          ForEach(Self.savableSets, id: \.self) { source in
            Button(source.title) { savePalette(store.entries(for: source), source, to: project) }
              .disabled(store.entries(for: source).isEmpty)
          }
        }
        .fixedSize()
        .accessibilityIdentifier("saveSet")
      }

      Text(
        "Saved colors keep the spelling you typed, so a recalled color comes back as "
          + "you wrote it rather than canonicalized.",
      )
      .font(.caption)
      .foregroundStyle(.tertiary)
      .fixedSize(horizontal: false, vertical: true)
    }
  }

  // MARK: - Contents

  private func colorsSection(_ project: Project) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Colors").font(.headline)

      if project.colors.isEmpty {
        Text("No colors saved in this project yet.")
          .font(.callout)
          .foregroundStyle(.secondary)
      } else {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 66), spacing: 10)], spacing: 10) {
          ForEach(Array(project.orderedColors.enumerated()), id: \.element.persistentModelID) {
            index, saved in
            savedColorTile(saved, index: index)
          }
        }
        // One popover for the grid rather than one per tile: `item:` already carries
        // which color is being edited, and forty tiles each holding their own would be
        // forty pieces of state for a thing only ever open once.
        .popover(item: $noteTarget) { saved in
          notesEditor(saved)
        }
      }
    }
  }

  /// Why a color was kept, which the swatch cannot say and the name should not have to.
  ///
  /// A popover rather than a field in the grid: notes are the least-used thing here and
  /// giving every tile a permanent text box would bury the colors under them.
  private func notesEditor(_ saved: SavedColor) -> some View {
    @Bindable var saved = saved

    return VStack(alignment: .leading, spacing: 8) {
      Text(saved.name.isEmpty ? saved.text : saved.name)
        .font(.headline)
      TextField("Notes", text: $saved.notes, prompt: Text("What this is for"), axis: .vertical)
        .lineLimit(3 ... 6)
        .textFieldStyle(.roundedBorder)
        .frame(width: 260)
        .accessibilityIdentifier("savedColorNotes")
      Text("Saved as \(saved.text)")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(12)
    // Bound straight to the model, so edits are live; the save is stamped once on the
    // way out rather than on every keystroke.
    .onDisappear { perform { try library.touch(saved) } }
  }

  /// One saved color: click to put it back in the field.
  ///
  /// The button carries the color's CSS as its accessibility label, for the reason every
  /// swatch in this app does — a colored rectangle says nothing to VoiceOver, and it is
  /// the only handle a UI test has on a grid of them.
  private func savedColorTile(_ saved: SavedColor, index: Int) -> some View {
    VStack(spacing: 4) {
      Button {
        // The stored text, not a re-serialization: this is the entire reason the
        // spelling was kept. `rebeccapurple` goes back in as `rebeccapurple`.
        store.inputText = saved.text
      } label: {
        ZStack {
          if let color = saved.colorValue {
            ColorSwatch(color: color, cornerRadius: 6)
          } else {
            // A row this build cannot read. Shown rather than hidden, because a color
            // silently missing from a project is worse than one that says it is.
            RoundedRectangle(cornerRadius: 6).fill(.quaternary)
            Image(systemName: "questionmark").foregroundStyle(.secondary)
          }
        }
        .frame(width: 44, height: 44)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(saved.text)
      .accessibilityIdentifier("savedColor-\(index)")
      .help(tooltip(saved))
      .contextMenu {
        Button("Notes…") { noteTarget = saved }
        Button("Delete", role: .destructive) {
          // Cleared first: the popover holds this object, and leaving it pointed at a
          // deleted model is a reference to a row that no longer exists.
          if noteTarget?.persistentModelID == saved.persistentModelID {
            noteTarget = nil
          }
          perform { try library.delete(saved) }
        }
      }

      Text(saved.name.isEmpty ? saved.text : saved.name)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .truncationMode(.middle)
        .frame(maxWidth: 62)
    }
  }

  private func palettesSection(_ project: Project) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Palettes").font(.headline)

      if project.palettes.isEmpty {
        Text("No palettes saved yet — build a harmony or a ramp, then Save Set.")
          .font(.callout)
          .foregroundStyle(.secondary)
      } else {
        ForEach(Array(project.orderedPalettes.enumerated()), id: \.element.persistentModelID) {
          index, palette in
          paletteRow(palette, index: index)
        }
      }
    }
  }

  private func paletteRow(_ palette: Palette, index: Int) -> some View {
    let entries = palette.paletteEntries

    return VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        Text(palette.name).font(.callout.weight(.medium))
        ColorBadge(text: palette.kind.title, tint: .secondary)
        Spacer()
        Button("Export") { store.stage(entries, named: palette.name) }
          .disabled(entries.isEmpty)
          .accessibilityIdentifier("paletteExport-\(index)")
        Button("Delete", role: .destructive) { perform { try library.delete(palette) } }
          .accessibilityIdentifier("paletteDelete-\(index)")
      }

      HStack(spacing: 4) {
        ForEach(Array(entries.enumerated()), id: \.offset) { entryIndex, entry in
          ColorSwatch(color: entry.color, cornerRadius: 4)
            .frame(width: 24, height: 24)
            .accessibilityLabel(entry.key)
            .accessibilityIdentifier("palette-\(index)-swatch-\(entryIndex)")
        }
      }
    }
    .padding(10)
    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
  }

  /// Name, spelling and notes, in whatever combination exists.
  private func tooltip(_ saved: SavedColor) -> String {
    let heading = saved.name.isEmpty ? saved.text : "\(saved.name) — \(saved.text)"
    return saved.notes.isEmpty ? heading : "\(heading)\n\(saved.notes)"
  }

  private func create() {
    perform {
      let project = try library.createProject(named: entryName)
      store.selectedProjectID = project.uuid
      entryName = ""
    }
  }

  private func saveColor(to project: Project) {
    guard let color = store.color else { return }
    perform {
      // The field's own text, so the spelling survives — see `ColorRecord`.
      try library.saveColor(
        ColorRecord(color, text: store.inputText.trimmingCharacters(in: .whitespacesAndNewlines)),
        named: entryName,
        to: project,
      )
      entryName = ""
    }
  }

  private func savePalette(_ entries: [PaletteEntry], _ source: ExportSource, to project: Project) {
    guard !entries.isEmpty else { return }
    perform {
      try library.savePalette(entries, named: entryName, kind: source.paletteKind, to: project)
      entryName = ""
    }
  }

  /// Runs a mutation and reports what went wrong instead of swallowing it.
  ///
  /// `try?` is the tempting one-liner and it means a save that failed looks exactly like
  /// a save that worked — the panel simply shows nothing new and the user tries again.
  private func perform(_ work: () throws -> Void) {
    do {
      try work()
      errorMessage = nil
    } catch {
      errorMessage = "Could not save: \(error.localizedDescription)"
    }
  }
}

nonisolated extension ExportSource {
  /// What a palette saved from this source is recorded as.
  ///
  /// ``ExportSource/color`` and ``ExportSource/saved`` have no honest answer — one is not
  /// a set and the other already came from a palette whose kind is known — so they fall
  /// to ``PaletteKind/custom`` rather than inventing provenance.
  var paletteKind: PaletteKind {
    switch self {
    case .harmony: .harmony
    case .ramp: .ramp
    case .recents: .recents
    case .color, .saved: .custom
    }
  }
}

#Preview {
  ContentView()
    .environment({
      let store = ColorStore(initialInput: "#3b82f6")
      store.tool = .projects
      return store
    }())
    .modelContainer(PersistenceStack.make(inMemory: true).container)
}
