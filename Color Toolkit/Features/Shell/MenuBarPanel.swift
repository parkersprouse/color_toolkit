//
//  MenuBarPanel.swift
//  Color Toolkit
//

import AppKit
import SwiftUI

/// What drops down from the menu bar icon.
///
/// Uses the `.window` `MenuBarExtra` style rather than `.menu`, because `.menu`
/// renders a real `NSMenu` and cannot draw arbitrary SwiftUI — which would reduce
/// recent colors to a list of hex strings. For a color tool the swatches *are* the
/// content, so the trade is worth the loss of native menu behavior.
struct MenuBarPanel: View {
    @Environment(ColorStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            current
            Divider()
            recents
            Divider()
            actions
        }
        .frame(width: 272)
    }

    // MARK: - Current color

    private var current: some View {
        HStack(spacing: 10) {
            if let color = store.color {
                ColorSwatch(color: color, cornerRadius: 6)
                    .frame(width: 40, height: 40)
            } else {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(.separator, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    .frame(width: 40, height: 40)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(store.color?.cssStringOrHex(as: .hex, options: store.formatOptions) ?? "No color")
                    .font(.system(.body, design: .monospaced))
                Text(store.inputText.isEmpty ? "Nothing entered" : store.inputText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)

            copyMenu
        }
        .padding(12)
    }

    private var copyMenu: some View {
        Menu {
            ForEach(FormatSection.all) { section in
                Section(section.title) {
                    ForEach(formats(in: section)) { formatted in
                        Button(formatted.format.title) { store.copy(formatted) }
                    }
                }
            }
        } label: {
            Label("Copy as", systemImage: "doc.on.doc")
                .labelStyle(.iconOnly)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(store.color == nil)
        .help("Copy as…")
    }

    private func formats(in section: FormatSection) -> [FormattedColor] {
        guard let color = store.color else { return [] }
        return section.formats.compactMap {
            color.formatted(as: $0, options: store.formatOptions)
        }
    }

    // MARK: - Recents

    private var recents: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !store.recents.isEmpty {
                    Button("Clear") { store.clearRecents() }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if store.recents.isEmpty {
                Text("Colors you copy or submit collect here.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6),
                    spacing: 6
                ) {
                    ForEach(store.recents) { recent in
                        Button { store.use(recent) } label: {
                            ColorSwatch(color: recent.color, cornerRadius: 5, checkerSize: 4)
                                .frame(height: 30)
                        }
                        .buttonStyle(.plain)
                        .help(recent.text)
                    }
                }
            }
        }
        .padding(12)
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 1) {
            MenuBarRow(title: "Open Color Toolkit", systemImage: "macwindow") {
                // A `.window`-style MenuBarExtra does not front the app on its own, so
                // without this the window opens behind whatever you were looking at.
                NSApp.activate()
                openWindow(id: WindowID.main)
            }
            MenuBarRow(title: "Quit", systemImage: "power") {
                NSApp.terminate(nil)
            }
        }
        .padding(6)
    }
}

/// A menu-bar-panel row that highlights on hover, the way a real menu item would.
struct MenuBarRow: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            isHovering ? Color.accentColor : .clear,
            in: RoundedRectangle(cornerRadius: 5, style: .continuous)
        )
        .foregroundStyle(isHovering ? Color.white : Color.primary)
        .onHover { isHovering = $0 }
    }
}
