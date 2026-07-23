//
//  ColorSwatch.swift
//  Color Toolkit
//

import SwiftUI

/// A color chip drawn over a checkerboard, so partial alpha is visible rather than
/// silently composited against whatever happens to be behind it.
struct ColorSwatch: View {
    let color: ColorValue
    var cornerRadius: CGFloat = 8
    var checkerSize: CGFloat = 5

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        ZStack {
            if color.alpha < 1 {
                Checkerboard(squareSize: checkerSize)
            }
            Rectangle().fill(color.displayColor)
        }
        .clipShape(shape)
        // A hairline border, or a white swatch vanishes into a light window and a
        // black one into a dark one.
        .overlay {
            shape.strokeBorder(.separator, lineWidth: 1)
        }
    }
}

/// The conventional transparency backdrop.
///
/// Fixed light gray in both appearances on purpose: every design tool draws it this
/// way, so an adaptive version would read as part of the color rather than as the
/// absence of one.
struct Checkerboard: View {
    var squareSize: CGFloat = 5

    private static let light = Color(white: 1.0)
    private static let dark = Color(white: 0.82)

    var body: some View {
        Canvas { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Self.light)
            )

            let columns = Int((size.width / squareSize).rounded(.up))
            let rows = Int((size.height / squareSize).rounded(.up))

            // One accumulated path rather than a fill per square: a recents grid can
            // hold a dozen of these and each is redrawn on every window resize.
            var squares = Path()
            for row in 0..<max(rows, 0) {
                for column in 0..<max(columns, 0) where (row + column).isMultiple(of: 2) {
                    squares.addRect(
                        CGRect(
                            x: CGFloat(column) * squareSize,
                            y: CGFloat(row) * squareSize,
                            width: squareSize,
                            height: squareSize
                        )
                    )
                }
            }
            context.fill(squares, with: .color(Self.dark))
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        ColorSwatch(color: .srgb8(59, 130, 246))
        ColorSwatch(color: .srgb8(255, 255, 255))
        ColorSwatch(color: .srgb8(220, 38, 38, alpha: 0.35))
        ColorSwatch(color: ColorValue(space: .oklch, 0.9, 0.3, 140))
    }
    .frame(height: 64)
    .padding()
}
