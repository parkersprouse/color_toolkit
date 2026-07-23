//
//  ColorInputField.swift
//  Color Toolkit
//

import SwiftUI

/// The field everything else hangs off: type any CSS color, see it parse as you go.
struct ColorInputField: View {
    @Environment(ColorStore.self) private var store

    var body: some View {
        @Bindable var store = store

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                swatch

                VStack(alignment: .leading, spacing: 6) {
                    TextField("#3b82f6", text: $store.inputText)
                        .textFieldStyle(.plain)
                        .font(.system(.title2, design: .monospaced))
                        // Submitting is one of the moments a color is worth keeping,
                        // as opposed to the dozens of valid prefixes typed to reach it.
                        .onSubmit { store.remember() }
                    Divider()
                }
            }

            status
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
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

        case .failed(let error):
            Label(error.message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)

        case .parsed(let result):
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
                        "This color is outside Display P3, so the swatch shows the closest color your screen can produce."
                    )
            } else if result.color.exceedsSRGB {
                ColorBadge(text: "Outside sRGB")
                    .help(
                        "Outside the sRGB gamut. Formats that cannot express it are gamut-mapped, not clipped."
                    )
            }

            if result.color.isAchromatic, result.color.space.hueIndex != nil {
                ColorBadge(text: "Hue is powerless", tint: .gray)
                    .help(
                        "The color is neutral, so its hue carries no information. CSS serializes such components as none."
                    )
            }
        }
    }

    private func describe(_ notation: ColorNotation) -> String {
        switch notation {
        case .hex(let digits):
            "\(digits)-digit hex"
        case .keyword(let name):
            "Named color \(name.lowercased())"
        case .function(let function, let legacy):
            legacy
                ? "\(function.rawValue)() · legacy comma syntax"
                : "\(function.rawValue)()"
        }
    }
}
