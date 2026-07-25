//
//  ExportPresentation.swift
//  Color Toolkit
//

import SwiftUI

/// Which of the app's colors an export is written from.
///
/// Lives here rather than in ColorCore because it is a question about *this app's
/// state* — what the store happens to be holding — not about CSS. ColorCore takes a
/// `[PaletteEntry]` and neither knows nor cares whether it came from a ramp or from
/// the recents list.
///
/// There is no saved-palette case, deliberately: palettes are M9's, and inventing a
/// `Palette` type here to have something to point at would be building that milestone
/// early and worse. The three multi-color sets the app already has are enough, and each
/// one is genuinely worth exporting.
nonisolated enum ExportSource: String, CaseIterable, Identifiable, Sendable {
  case color
  case harmony
  case ramp
  case recents

  // MARK: Internal

  var id: String {
    rawValue
  }

  var title: String {
    switch self {
    case .color: "This color"
    case .harmony: "Harmony"
    case .ramp: "Ramp"
    case .recents: "Recents"
    }
  }
}

/// - Note: `nonisolated` for the reason ``FormatSection`` gives — these are plain data,
///   and the app target's `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` would otherwise
///   put a string constant behind an actor hop.
nonisolated extension ExportShape {
  var title: String {
    switch self {
    case .declaration: "Declarations"
    case .customProperties: "Custom properties"
    case .json: "JSON"
    case .tailwindTheme: "Tailwind v4"
    case .tailwindConfig: "Tailwind v3"
    }
  }

  /// What the shape is for, in one line. The Tailwind pair need it most: which one you
  /// want is decided by your project's major version and by nothing else, and "v4" alone
  /// does not say that v4 configures colors in CSS rather than JavaScript.
  var summary: String {
    switch self {
    case .declaration:
      "Bare declarations to paste inside a rule."
    case .customProperties:
      "A :root block. The portable answer, and what var() reads."
    case .json:
      "CSS strings under their keys, for anything that is not a stylesheet."
    case .tailwindTheme:
      "@theme in your CSS entry point. Tailwind v4 configures colors here."
    case .tailwindConfig:
      "tailwind.config.js, under theme.extend so the stock palette survives."
    }
  }
}

nonisolated extension ExportTemplate {
  /// The property name, which is already the clearest possible label for it. Written
  /// with its colon so the picker reads as the CSS it produces.
  var title: String {
    "\(property):"
  }
}
