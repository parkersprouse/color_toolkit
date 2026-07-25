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
/// ``saved`` arrived with M9 and is the case M8 declined to invent early. It is also the
/// only source that does not read the input field: the other four are derived from
/// whatever is being edited right now, and a palette pulled out of a project is a set
/// that was chosen earlier and stands on its own.
nonisolated enum ExportSource: String, CaseIterable, Identifiable, Sendable {
  case color
  case harmony
  case ramp
  case recents
  case saved

  // MARK: Internal

  var id: String {
    rawValue
  }

  /// Short, and shorter than it wants to be. These are the segments of a segmented
  /// control, which divides its width evenly — so "Saved palette" would make every other
  /// option pay for it, and a fifth segment is already the point where that starts to
  /// bite.
  var title: String {
    switch self {
    case .color: "This color"
    case .harmony: "Harmony"
    case .ramp: "Ramp"
    case .recents: "Recents"
    case .saved: "Saved"
    }
  }

  /// What to say when this source names no colors.
  ///
  /// Per source, because two of them can now be empty for entirely different reasons and
  /// a single line cannot be true of both — telling somebody that "recents fill up as
  /// you copy colors" when what they are missing is a staged palette is the same defect
  /// as M8's placeholder that disagreed with its own fallback.
  var emptyMessage: String {
    switch self {
    case .color, .harmony, .ramp:
      "Type a CSS color above and it can be exported from here."
    case .recents:
      "Nothing to export yet — recents fill up as you copy and sample colors."
    case .saved:
      "No palette staged. Open Projects and choose Export on a saved palette."
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
