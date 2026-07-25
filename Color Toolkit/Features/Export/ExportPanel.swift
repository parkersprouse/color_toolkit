//
//  ExportPanel.swift
//  Color Toolkit
//

import SwiftUI

/// The colors you have, written out as something you can paste.
///
/// Two choices drive everything: **what** to export — this color, or one of the sets the
/// other tools produce — and **what shape** to write it in. Everything below the controls
/// is a live preview of exactly what the copy button puts on the clipboard, which is the
/// property worth protecting: an export panel whose preview and clipboard can disagree is
/// worse than no preview at all.
///
/// **The panel builds no strings.** Every character comes from ``ExportOptions/render``
/// in ColorCore, reached through ``ColorStore/exportDocument``. That is not tidiness for
/// its own sake — tests here must never write to the real pasteboard, so string
/// generation living in a view would be a feature with no assertable surface.
struct ExportPanel: View {
  // MARK: Internal

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        if store.color == nil {
          ContentUnavailableView(
            "No color yet",
            systemImage: "square.and.arrow.up",
            description: Text("Type a CSS color above and it can be exported from here."),
          )
          .frame(maxWidth: .infinity)
        } else {
          controls
          Divider()
          preview
        }
      }
      .padding(16)
    }
  }

  // MARK: Private

  @Environment(ColorStore.self) private var store

  @State private var justCopied = false
  @State private var resetTask: Task<Void, Never>?

  // MARK: - Controls

  private var controls: some View {
    @Bindable var store = store

    return VStack(alignment: .leading, spacing: 14) {
      LabeledContent("Source") {
        Picker("Source", selection: $store.exportSource) {
          ForEach(ExportSource.allCases) { source in
            Text(source.title).tag(source)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityIdentifier("exportSource")
      }

      // A menu rather than a segmented control: five titles, two of them two words
      // long, do not fit across a 520pt window without truncating to initials.
      LabeledContent("Shape") {
        Picker("Shape", selection: $store.exportOptions.shape) {
          ForEach(ExportShape.allCases) { shape in
            Text(shape.title).tag(shape)
          }
        }
        .labelsHidden()
        .accessibilityIdentifier("exportShape")
      }

      Text(store.exportOptions.shape.summary)
        .font(.caption)
        .foregroundStyle(.tertiary)
        .fixedSize(horizontal: false, vertical: true)

      if store.exportOptions.shape.usesTemplate {
        LabeledContent("Declaration") {
          Picker("Declaration", selection: $store.exportOptions.template) {
            ForEach(ExportTemplate.allCases) { template in
              Text(template.title).tag(template)
            }
          }
          .labelsHidden()
          .accessibilityIdentifier("exportTemplate")
        }
      }

      if store.exportOptions.shape.usesName {
        LabeledContent("Name") {
          TextField("Name", text: $store.exportOptions.name, prompt: Text("brand"))
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 200)
            .accessibilityIdentifier("exportName")
        }
      }

      LabeledContent("Format") {
        // `keyword` is absent, and structurally so — see `CSSOutputFormat.exportable`.
        // It names 148 colors, so a palette would come back part keywords and part
        // something else with nothing in the file to say so.
        Picker("Format", selection: $store.exportOptions.format) {
          ForEach(CSSOutputFormat.exportable, id: \.self) { format in
            Text(format.title).tag(format)
          }
        }
        .labelsHidden()
        .accessibilityIdentifier("exportFormat")
      }

      // The *same* setting the toolbar's output menu shows, not a copy of it. Surfaced
      // again here because precision is the one serialization choice you actually think
      // about while exporting, and sending someone to a toolbar menu mid-task to find it
      // is a worse answer than showing one knob in two places.
      LabeledContent("Precision") {
        Picker("Precision", selection: $store.formatOptions.precision) {
          Text("Compact").tag(2)
          Text("Normal").tag(4)
          Text("Fine").tag(6)
          Text("Maximum").tag(10)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityIdentifier("exportPrecision")
      }
    }
  }

  // MARK: - Preview

  private var preview: some View {
    let document = store.exportDocument
    let entries = store.exportEntries
    let mapped = store.exportGamutMappedCount

    return VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text("Output").font(.headline)
        Text(entries.count == 1 ? "1 color" : "\(entries.count) colors")
          .font(.caption)
          .foregroundStyle(.tertiary)
        Spacer()
        Button(justCopied ? "Copied" : "Copy") { copy() }
          .disabled(document.isEmpty)
          .accessibilityIdentifier("exportCopy")
      }

      if entries.isEmpty {
        // Only reachable from Recents, which starts empty. Said plainly rather than
        // shown as an empty code block, which reads as the panel having broken.
        Label(
          "Nothing to export yet — recents fill up as you copy and sample colors.",
          systemImage: "clock",
        )
        .font(.callout)
        .foregroundStyle(.secondary)
      } else {
        if mapped > 0 {
          HStack(spacing: 8) {
            ColorBadge(text: mapped == 1 ? "1 mapped" : "\(mapped) mapped")
            Text(
              "\(store.exportOptions.format.title) cannot express "
                + "\(mapped == 1 ? "one of these colors" : "\(mapped) of these colors"), "
                + "so the values below were brought into gamut.",
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          }
        }

        swatches(entries)

        // Horizontally scrollable rather than wrapping: this is code, and a soft-wrapped
        // Tailwind config is harder to read than one you scroll.
        ScrollView(.horizontal, showsIndicators: true) {
          Text(document)
            .font(.system(.callout, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("exportDocument")
        }
        .padding(10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
      }
    }
  }

  /// What is about to be written, as colors rather than as text.
  ///
  /// Each carries its CSS as an accessibility label, for the reason the transform panel's
  /// swatches do: a colored rectangle announces nothing to VoiceOver, and it is the only
  /// handle a test has on a row of them.
  private func swatches(_ entries: [PaletteEntry]) -> some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 6) {
        ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
          VStack(spacing: 4) {
            ColorSwatch(color: entry.color, cornerRadius: 6)
              .frame(width: 38, height: 38)
            if !entry.key.isEmpty {
              Text(entry.key)
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
          }
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(css(entry.color))
          .accessibilityIdentifier("exportSwatch-\(index)")
        }
      }
      .padding(.vertical, 2)
    }
  }

  // MARK: - Actions

  private func copy() {
    store.copyExport()
    justCopied = true
    // Cancelled first for the reason `FormatRow` gives: two copies in quick succession
    // would otherwise let the earlier timer clear a label the later one just set.
    resetTask?.cancel()
    resetTask = Task {
      try? await Task.sleep(for: .seconds(1.2))
      guard !Task.isCancelled else { return }
      justCopied = false
    }
  }

  /// The swatch label, which is a caption and so uses display precision — the document
  /// itself goes through ``ColorStore/exportDocument``.
  private func css(_ color: ColorValue) -> String {
    color.cssStringOrHex(
      as: color.spelling(preferring: .hex),
      options: store.formatOptions,
    )
  }
}

#Preview {
  ContentView()
    .environment({
      let store = ColorStore(initialInput: "#3b82f6")
      store.tool = .export
      return store
    }())
}
