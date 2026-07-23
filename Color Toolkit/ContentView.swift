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
        VStack(spacing: 0) {
            ColorInputField()
                .padding(16)

            Divider()

            if store.color != nil {
                ConversionPanel()
            } else {
                ContentUnavailableView(
                    "No color yet",
                    systemImage: "eyedropper.halffull",
                    description: Text("Type a CSS color above and every other format appears here.")
                )
            }
        }
        .frame(minWidth: 520, minHeight: 460)
        .toolbar {
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
                Picker("Precision", selection: $store.formatOptions.precision) {
                    ForEach(0...6, id: \.self) { places in
                        Text(places == 0 ? "Whole numbers" : "\(places) decimals").tag(places)
                    }
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
