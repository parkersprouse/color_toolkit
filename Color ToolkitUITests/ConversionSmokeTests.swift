//
//  ConversionSmokeTests.swift
//  Color ToolkitUITests
//

import XCTest

/// End-to-end coverage of the one path unit tests cannot reach: text in the field
/// becoming rendered rows on screen.
///
/// Replaces the Xcode template's UI tests, which launched the app three times —
/// including once inside a `measure` loop — and asserted nothing at all. Those
/// launches were pure cost: seconds on every run, and an app instance left behind
/// whenever one failed to terminate.
///
/// - Note: Rows are queried as **buttons**, not static texts. `FormatRow` wraps its
///   label and value in a `Button`, and SwiftUI merges a button's children into one
///   accessibility element whose label is the concatenation — so a row reads as
///   `"hsl(), hsl(217.22 91.22% 59.8%)"` and no `StaticText` for the value exists.
final class ConversionSmokeTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        // Terminate explicitly rather than trusting the runner to clean up. This app
        // has a MenuBarExtra, so a surviving instance leaves an icon in the menu bar
        // that looks like a second copy of the app and cannot be clicked — the exact
        // symptom that prompted this file.
        app?.terminate()
        app = nil
    }

    private func row(_ title: String, _ css: String) -> XCUIElement {
        app.buttons["\(title), \(css)"]
    }

    /// Precision is relative to each component's scale, and this is the only test
    /// that proves it survives the trip through the real view. A hue printed to four
    /// decimals — `hsl(217.2193 …)` — is the defect being guarded against.
    func testPanelRendersEveryFormatAtReadablePrecision() {
        XCTAssertTrue(
            row("Hex", "#3b82f6").waitForExistence(timeout: 30),
            "The conversion panel never rendered its default color"
        )

        for (title, css) in [
            ("rgb()", "rgb(59 130 246)"),
            ("hsl()", "hsl(217.22 91.22% 59.8%)"),
            ("hwb()", "hwb(217.22 23.14% 3.53%)"),
            ("oklch()", "oklch(0.6231 0.188 259.81)"),
            ("oklab()", "oklab(0.6231 -0.0332 -0.1851)"),
            ("lch()", "lch(54.62% 66.37 277.59)"),
            ("lab()", "lab(54.62% 8.76 -65.79)"),
            ("color(display-p3)", "color(display-p3 0.3047 0.5035 0.9338)"),
            ("color(xyz-d65)", "color(xyz-d65 0.2642 0.2355 0.9034)"),
        ] {
            XCTAssertTrue(row(title, css).exists, "Missing row: \(title) → \(css)")
        }
    }

    /// Typing a color no sRGB screen can show must reach the panel *and* be marked,
    /// so a value that was quietly moved never reads as an exact answer.
    func testOutOfGamutColorIsBadgedOnBoundedFormatsOnly() {
        let field = app.textFields["colorInput"]
        XCTAssertTrue(field.waitForExistence(timeout: 30))

        field.click()
        field.typeKey("a", modifierFlags: .command)
        field.typeText("oklch(0.9 0.3 140)")

        // OKLCH is unbounded, so it holds the color exactly and carries no badge.
        let exact = row("oklch()", "oklch(0.9 0.3 140)")
        XCTAssertTrue(exact.waitForExistence(timeout: 15), "The typed color never reached the panel")

        let badged = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "mapped"))
        XCTAssertGreaterThan(badged.count, 0, "An out-of-sRGB color produced no gamut badge")
        XCTAssertFalse(exact.label.contains("mapped"), "oklch() holds this color exactly")
    }
}
