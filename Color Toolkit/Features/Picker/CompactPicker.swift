//
//  CompactPicker.swift
//  Color Toolkit
//

import SwiftUI

/// The popover behind the header swatch (M24): pick a color without leaving whatever
/// tool is open.
///
/// Composes the same three controls `PickerPanel` does — ``PickerPlaneView``,
/// ``PickerHueStripView``, ``PickerAlphaSliderView`` — at a fixed, popover-sized
/// footprint instead of one measured from a resizable window. No numeric readout:
/// that is `PickerPanel`'s payload for someone who opened the Pick tool on purpose,
/// and a popover meant for a quick pick has no room for it anyway.
///
/// Owns its own ``PickerState``, seeded from the store on appear and using the same
/// `lastWritten` loopback guard `PickerPanel` does (``PickerState/syncing(with:color:)``)
/// — the picker must ignore its own writes, or every drag tick inside the popover
/// would re-seed itself. It writes through `store.inputText` on every change and
/// calls `store.remember()` on drag end, exactly as `PickerPanel`'s gestures do,
/// because both routes end in the same shared views — commit-on-release (M23) is not
/// reimplemented here, it is inherited.
struct CompactPicker: View {
  // MARK: Internal

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      modeSwitcher

      HStack(alignment: .top, spacing: 10) {
        PickerPlaneView(state: $state, side: Self.side, identifier: "compactPickerPlane")
        PickerHueStripView(state: $state, height: Self.side, identifier: "compactPickerHue")
      }

      PickerAlphaSliderView(state: $state, identifier: "compactPickerAlpha")
    }
    .padding(14)
    .task { seedFromStore() }
    .onChange(of: store.inputText) { state.syncing(with: store.inputText, color: store.color) }
  }

  // MARK: Private

  /// Smaller than `PickerPanel`'s minimum (240) on purpose — a popover is a quick
  /// pick, not a destination, and this keeps it well clear of the screen edge from
  /// wherever the header swatch happens to sit.
  private static let side: CGFloat = 200

  @Environment(ColorStore.self) private var store

  @State private var state = PickerState()

  private var modeSwitcher: some View {
    Picker(
      "Axes",
      selection: Binding(
        get: { state.mode },
        set: { newMode in
          state.setMode(newMode, carrying: store.color)
          store.pickerMode = newMode
        },
      ),
    ) {
      ForEach(PickerMode.allCases) { mode in
        Text(mode.title).tag(mode)
      }
    }
    .pickerStyle(.segmented)
    .labelsHidden()
    .fixedSize()
    // Distinct from `PickerPanel`'s "pickerMode" for the same reason the three
    // shared views take their own identifiers — see `PickerPlaneView.identifier`.
    .accessibilityIdentifier("compactPickerMode")
  }

  private func seedFromStore() {
    if let color = store.color {
      state.seed(from: color)
    }
    state.setMode(store.pickerMode, carrying: store.color)
  }
}

#Preview {
  CompactPicker()
    .environment(ColorStore(initialInput: "oklch(0.62 0.19 260)"))
}
