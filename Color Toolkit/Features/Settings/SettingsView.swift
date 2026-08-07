//
//  SettingsView.swift
//  Color Toolkit
//

import SwiftUI

/// The app's `Settings` scene (⌘,).
///
/// Four sections: General, Shortcuts, Output, and a reset. **Output duplicates
/// `OutputOptionsMenu`'s seven controls rather than replacing them** — the same
/// precedent the export panel's own Precision picker already set, documented at
/// ``ColorStore/formatOptions``. Both are surfaces onto the one set of bindings, so
/// changing precision here and in the toolbar menu can never disagree.
struct SettingsView: View {
  // MARK: Internal

  var body: some View {
    @Bindable var store = store

    Form {
      Section("General") {
        Toggle("Web-friendly mode", isOn: $store.webFriendly)
          .help("Hides exotic formats and keeps every value inside sRGB.")
        Toggle("Show recents", isOn: $store.showsRecents)
        Stepper(
          "Recent colors kept: \(store.recentLimit)",
          value: $store.recentLimit,
          in: 1 ... 50,
        )
      }

      Section("Shortcuts") {
        LabeledContent("Pick Color from Screen") {
          ShortcutRecorderField()
        }
        .help("Works from any app, not only while Color Toolkit is frontmost.")
      }

      Section("Output") {
        Toggle("Legacy comma syntax", isOn: $store.formatOptions.legacy)
          .help("Writes rgb(255, 0, 0) and hsl(). Other functions have no legacy form.")
        Toggle("rgb() as percentages", isOn: $store.formatOptions.rgbAsPercentage)
        Toggle("Uppercase hex", isOn: $store.formatOptions.uppercaseHex)
        Toggle("Shorten hex when possible", isOn: $store.formatOptions.collapseHex)

        // Named levels rather than decimal counts, same as the toolbar menu:
        // precision is relative to each component's scale, so "4 decimals" is not
        // one fact about every row.
        Picker("Precision", selection: $store.formatOptions.precision) {
          Text("Compact").tag(2)
          Text("Normal").tag(4)
          Text("Fine").tag(6)
          Text("Maximum").tag(10)
        }

        Picker("Out of gamut", selection: $store.formatOptions.gamut) {
          Text("Map into gamut").tag(CSSFormatOptions.GamutPolicy.map)
          Text("Keep original values").tag(CSSFormatOptions.GamutPolicy.preserve)
        }

        Picker("Alpha", selection: $store.formatOptions.alpha) {
          Text("Only when transparent").tag(CSSFormatOptions.AlphaPolicy.whenNotOpaque)
          Text("Always").tag(CSSFormatOptions.AlphaPolicy.always)
          Text("Never").tag(CSSFormatOptions.AlphaPolicy.never)
        }
      }

      Section {
        Button("Reset to Defaults", role: .destructive) {
          store.preferences = Preferences()
        }
      }
    }
    .formStyle(.grouped)
    .frame(width: 420)
    .padding(.vertical, 8)
  }

  // MARK: Private

  @Environment(ColorStore.self) private var store
}

#Preview {
  SettingsView()
    .environment(ColorStore())
}
