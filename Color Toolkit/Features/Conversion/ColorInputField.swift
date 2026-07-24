//
//  ColorInputField.swift
//  Color Toolkit
//

import SwiftUI

/// The field everything else hangs off: type any CSS color, see it parse as you go.
struct ColorInputField: View {
  // MARK: Internal

  var body: some View {
    @Bindable var store = store

    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .center, spacing: 14) {
        swatch

        VStack(alignment: .leading, spacing: 6) {
          TextField("#3b82f6", text: $store.inputText)
            .textFieldStyle(.plain)
            .font(.system(.title2, design: .monospaced))
            .accessibilityIdentifier("colorInput")
            // Submitting is one of the moments a color is worth keeping,
            // as opposed to the dozens of valid prefixes typed to reach it.
            .onSubmit { store.remember() }
          Divider()
        }

        eyedropper
      }

      status
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  // MARK: Private

  @Environment(ColorStore.self) private var store

  // MARK: - Eyedropper

  /// Samples a pixel into the field. Does **not** touch the clipboard — the field is
  /// right here, and the global shortcut is the variant that copies.
  private var eyedropper: some View {
    Button {
      Task { await store.sampleFromScreen() }
    } label: {
      Image(systemName: "eyedropper")
        .font(.title3)
        .frame(width: 26, height: 26)
        .contentShape(Rectangle())
    }
    .buttonStyle(.borderless)
    .accessibilityIdentifier("eyedropper")
    .accessibilityLabel("Pick a color from the screen")
    .help(
      store.globalShortcutIsActive
        ? "Pick a color from the screen. Works from any app with \(GlobalShortcut.sampleColor.displayString)."
        : "Pick a color from the screen.",
    )
  }

  // MARK: - Swatch

  @ViewBuilder
  private var swatch: some View {
    if let color = store.color {
      ColorSwatch(color: color)
        .frame(width: 58, height: 58)
    } else {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .strokeBorder(
          .separator,
          style: StrokeStyle(lineWidth: 1, dash: [4, 3]),
        )
        .frame(width: 58, height: 58)
    }
  }

  // MARK: - Status

  @ViewBuilder
  private var status: some View {
    switch store.parsed {
    case .empty:
      Text("Hex, rgb(), hsl(), hwb(), lab(), lch(), oklab(), oklch(), color(), or a keyword.")
        .foregroundStyle(.secondary)

    case let .failed(error):
      Label(error.message, systemImage: "exclamationmark.triangle.fill")
        .foregroundStyle(.red)

    case let .parsed(result):
      VStack(alignment: .leading, spacing: 4) {
        summary(for: result)
        // Warnings mean it parsed but is not valid CSS. Shown rather than
        // rejected, because both cases are unambiguous about intent — but
        // shown loudly, because pasting one into a stylesheet does nothing.
        ForEach(Array(result.warnings.enumerated()), id: \.offset) { _, warning in
          Label(warning.message, systemImage: "exclamationmark.circle.fill")
            .foregroundStyle(.orange)
        }
      }
    }
  }

  private func summary(for result: ParseResult) -> some View {
    HStack(spacing: 8) {
      Text(describe(result.notation))
        .foregroundStyle(.secondary)

      if result.color.exceedsDisplayGamut {
        ColorBadge(text: "Beyond this display")
          .help(
            "This color is outside Display P3, so the swatch shows the closest color your screen can produce.",
          )
      } else if result.color.exceedsSRGB {
        ColorBadge(text: "Outside sRGB")
          .help(
            "Outside the sRGB gamut. Formats that cannot express it are gamut-mapped, not clipped.",
          )
      }

      if result.color.isAchromatic, result.color.space.hueIndex != nil {
        ColorBadge(text: "Hue is powerless", tint: .gray)
          .help(
            "The color is neutral, so its hue carries no information. CSS serializes such components as none.",
          )
      }
    }
  }

  private func describe(_ notation: ColorNotation) -> String {
    switch notation {
    case let .hex(digits):
      "\(digits)-digit hex"
    case let .keyword(name):
      "Named color \(name.lowercased())"
    case let .function(function, legacy):
      legacy
        ? "\(function.rawValue)() · legacy comma syntax"
        : "\(function.rawValue)()"
    }
  }
}
