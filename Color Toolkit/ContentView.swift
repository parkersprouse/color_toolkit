//
//  ContentView.swift
//  Color Toolkit
//
//  Created by Parker Sprouse on 7/23/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(ColorStore.self) private var store

    var body: some View {
        @Bindable var store = store

        return VStack(spacing: 0) {
            // Above the switcher deliberately: the input field belongs to no tool.
            // Every tool is a different question asked about the same color, so moving
            // it inside a tab would imply each one has a color of its own.
            ColorInputField()
                .padding(16)

            Divider()

            switch store.tool {
            case .convert:
                if store.color != nil {
                    ConversionPanel()
                } else {
                    ContentUnavailableView(
                        "No color yet",
                        systemImage: "eyedropper.halffull",
                        description: Text("Type a CSS color above and every other format appears here.")
                    )
                }
            case .pick:
                PickerPanel()
            case .contrast:
                ContrastPanel()
            case .cvd:
                CVDPanel()
            }
        }
        .frame(minWidth: 520, minHeight: 460)
        // See `MenuBarLabel` — the shortcut is claimed from whichever scene appears
        // first, because neither scene is guaranteed to be on screen.
        .task { store.activateGlobalShortcut() }
        .toolbar {
            ToolbarItem(placement: .principal) {
                // Text, not `Label`. A segmented control renders a `Label` icon-only
                // and then hands VoiceOver the SF Symbol name — the picker literally
                // announced "arrow.left.arrow.right" instead of "Convert". Two words
                // are also plainer than two glyphs for a switcher nobody has seen
                // before: neither an arrow pair nor a half-filled circle says which
                // tool it is.
                Picker("Tool", selection: $store.tool) {
                    ForEach(Tool.allCases) { tool in
                        Text(tool.title).tag(tool)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            ToolbarItem {
                OutputOptionsMenu()
            }
        }
    }
}

/// Serialization settings, tucked into the toolbar.
///
/// These change every row in the panel at once, which is why they live here rather
/// than per-row: precision and legacy syntax are properties of how *you* write CSS,
/// not of any one color.
struct OutputOptionsMenu: View {
    @Environment(ColorStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Menu {
            Toggle("Legacy comma syntax", isOn: $store.formatOptions.legacy)
                .help("Writes rgb(255, 0, 0) and hsl(). Other functions have no legacy form.")
            Toggle("rgb() as percentages", isOn: $store.formatOptions.rgbAsPercentage)

            Section("Hex") {
                Toggle("Uppercase", isOn: $store.formatOptions.uppercaseHex)
                Toggle("Shorten when possible", isOn: $store.formatOptions.collapseHex)
            }

            Section("Precision") {
                // Named levels rather than decimal counts, because precision is
                // relative to each component's scale — "4 decimals" would be true of
                // an OKLCH lightness and a lie about a hue in the same row.
                Picker("Precision", selection: $store.formatOptions.precision) {
                    Text("Compact").tag(2)
                    Text("Normal").tag(4)
                    Text("Fine").tag(6)
                    Text("Maximum").tag(10)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section("Out of gamut") {
                Picker("Out of gamut", selection: $store.formatOptions.gamut) {
                    Text("Map into gamut").tag(CSSFormatOptions.GamutPolicy.map)
                    Text("Keep original values").tag(CSSFormatOptions.GamutPolicy.preserve)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section("Alpha") {
                Picker("Alpha", selection: $store.formatOptions.alpha) {
                    Text("Only when transparent").tag(CSSFormatOptions.AlphaPolicy.whenNotOpaque)
                    Text("Always").tag(CSSFormatOptions.AlphaPolicy.always)
                    Text("Never").tag(CSSFormatOptions.AlphaPolicy.never)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        } label: {
            Label("Output options", systemImage: "slider.horizontal.3")
        }
    }
}

#Preview {
    ContentView()
        .environment(ColorStore(initialInput: "oklch(0.7 0.15 250)"))
}
