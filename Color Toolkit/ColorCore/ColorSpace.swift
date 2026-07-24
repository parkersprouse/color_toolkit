//
//  ColorSpace.swift
//  Color Toolkit
//

import Foundation

/// A color space supported by CSS Color Module Level 4.
///
/// Named colors are deliberately *not* a case here. In the CSS spec a keyword is a
/// serialization *format* of sRGB, not a space of its own — modeling it that way
/// keeps `red` and `#f00` the same value, which is what users expect.
/// - Note: `nonisolated` throughout ColorCore. The app target builds with
///   `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, which is right for UI code but
///   would strand the color engine on the main thread — blocking batch palette
///   generation, CVD image filtering, and any future CLI reuse.
nonisolated enum ColorSpace: String, Codable, Sendable, Hashable, CaseIterable {
  // sRGB family — alternate parameterizations of the same gamma-encoded values.
  case srgb
  case hsl
  case hwb
  case srgbLinear = "srgb-linear"

  // CIE Lab family. Note: D50-referenced, per CSS.
  case lab
  case lch

  // OKLab family. Note: D65-referenced, unlike lab/lch above.
  case oklab
  case oklch

  // Wide-gamut RGB spaces, reachable through `color()`.
  case displayP3 = "display-p3"
  case a98RGB = "a98-rgb"
  case proPhotoRGB = "prophoto-rgb"
  case rec2020

  // Connection spaces.
  case xyzD50 = "xyz-d50"
  case xyzD65 = "xyz-d65"
}

nonisolated extension ColorSpace {
  /// Groups spaces that are alternate encodings of the same underlying values.
  ///
  /// Conversions *within* a family go directly rather than detouring through XYZ:
  /// the round trip would add floating-point error and, worse, destroy hue on
  /// achromatic colors.
  enum Family: Sendable, Hashable {
    case srgbEncoded // srgb, hsl, hwb — all describe gamma-encoded sRGB
    case lab // lab, lch
    case oklab // oklab, oklch
    case independent // everything else
  }

  var family: Family {
    switch self {
    case .srgb, .hsl, .hwb: .srgbEncoded
    case .lab, .lch: .lab
    case .oklab, .oklch: .oklab
    default: .independent
    }
  }

  /// Spaces with no inherent gamut limit. Gamut mapping is a no-op for these.
  var isUnbounded: Bool {
    switch self {
    case .lab, .lch, .oklab, .oklch, .xyzD50, .xyzD65: true
    default: false
    }
  }

  /// The RGB space whose `[0, 1]` cube defines this space's gamut, if bounded.
  ///
  /// HSL and HWB have no gamut of their own — they describe sRGB, so they borrow
  /// its cube.
  var rgbBasis: ColorSpace? {
    switch self {
    case .srgb, .hsl, .hwb: .srgb
    case .srgbLinear: .srgbLinear
    case .displayP3: .displayP3
    case .a98RGB: .a98RGB
    case .proPhotoRGB: .proPhotoRGB
    case .rec2020: .rec2020
    default: nil
    }
  }

  /// Index of the hue component, for spaces that have one.
  var hueIndex: Int? {
    switch self {
    case .hsl, .hwb: 0
    case .lch, .oklch: 2
    default: nil
    }
  }

  /// Whether this space can appear inside the CSS `color()` function.
  var isColorFunctionSpace: Bool {
    switch self {
    case .srgb, .srgbLinear, .displayP3, .a98RGB, .proPhotoRGB, .rec2020,
         .xyzD50, .xyzD65:
      true
    default:
      false
    }
  }

  /// Human-facing component labels, in order.
  var componentLabels: (String, String, String) {
    switch self {
    case .srgb, .srgbLinear, .displayP3, .a98RGB, .proPhotoRGB, .rec2020:
      ("Red", "Green", "Blue")
    case .hsl: ("Hue", "Saturation", "Lightness")
    case .hwb: ("Hue", "Whiteness", "Blackness")
    case .lab, .oklab: ("Lightness", "a", "b")
    case .lch, .oklch: ("Lightness", "Chroma", "Hue")
    case .xyzD50, .xyzD65: ("X", "Y", "Z")
    }
  }

  /// Achromatic threshold used when converting a rectangular space to its polar
  /// form. Derived from the base space's `a` reference range divided by 100000,
  /// matching the reference implementation.
  var polarEpsilon: Double? {
    switch self {
    case .lch: 250.0 / 100_000.0 // Lab `a` spans [-125, 125]
    case .oklch: 0.8 / 100_000.0 // OKLab `a` spans [-0.4, 0.4]
    default: nil
    }
  }
}
