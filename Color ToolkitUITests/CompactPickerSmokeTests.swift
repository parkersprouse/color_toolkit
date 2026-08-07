//
//  CompactPickerSmokeTests.swift
//  Color ToolkitUITests
//

import XCTest

/// The header swatch's popover picker (M24): opening it from whatever tool is
/// showing, not only the Pick tab, and a drag inside it reaching the shared field.
///
/// See ``PickerSmokeTests`` for the Pick tab's own coverage of the three controls
/// this popover reuses (``PickerPlaneView``, ``PickerHueStripView``,
/// ``PickerAlphaSliderView``) — this file is only the popover-specific surface:
/// the trigger, the identifier collision the plane's `identifier` parameter exists
/// to avoid, and the empty-state hit target.
final class CompactPickerSmokeTests: XCTestCase {
  // MARK: Internal

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    // See `ProjectsSmokeTests` for why this pairs with the AppKit opt-out even though
    // this suite has no persistence argument of its own to pair it with.
    app.launchArguments = ["-NSTreatUnknownArgumentsAsOpen", "NO", "UITestEphemeralPreferences"]
    app.launch()
    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30), "App did not reach the foreground")
  }

  override func tearDownWithError() throws {
    app?.terminate()
    _ = app?.wait(for: .notRunning, timeout: 30)
    app = nil
  }

  // MARK: - Tests

  /// The write-back loop, end to end, reachable from a tool that has nothing to do
  /// with picking — Convert is the default tab, and the popover works from there.
  func testHeaderSwatchOpensAPopoverAndDraggingItWritesToTheField() {
    setField("#3b82f6")

    let swatch = app.buttons["headerSwatch"]
    guard swatch.waitForExistence(timeout: 15) else {
      XCTFail("No header swatch. Tree was:\n\(app.debugDescription)")
      return
    }
    guard waitUntilHittable(swatch) else {
      XCTFail("Header swatch never became hittable. Tree was:\n\(app.debugDescription)")
      return
    }
    swatch.click()

    let plane = app.otherElements["compactPickerPlane"]
    guard plane.waitForExistence(timeout: 15) else {
      XCTFail("Header swatch did not open the popover. Tree was:\n\(app.debugDescription)")
      return
    }

    let field = app.textFields["colorInput"]
    let before = field.value as? String
    plane.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.35))
      .press(forDuration: 0.1,
             thenDragTo: plane.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.7)))

    let after = field.value as? String
    XCTAssertNotEqual(after, before, "Dragging inside the popover did not reach the field")
  }

  /// The reason ``PickerPlaneView/identifier`` and its siblings take a distinct
  /// identifier per host: the header swatch sits above the tool switcher, so nothing
  /// stops opening the popover while already on the Pick tab, and the two planes
  /// have to resolve as two separate elements rather than one ambiguous query — the
  /// exact hazard CLAUDE.md's "never write a fallback chain of XCUITest queries"
  /// note exists to keep out.
  func testThePlaneAndItsPopoverCopyCanBothBeOnScreenAtOnce() {
    setField("#3b82f6")
    click(radioButton: "Pick", "the tool switcher")

    XCTAssertTrue(
      app.otherElements["pickerPlane"].waitForExistence(timeout: 15),
      "the Pick tab's own plane should already be showing",
    )

    let swatch = app.buttons["headerSwatch"]
    guard waitUntilHittable(swatch) else {
      XCTFail("Header swatch never became hittable. Tree was:\n\(app.debugDescription)")
      return
    }
    swatch.click()

    guard app.otherElements["compactPickerPlane"].waitForExistence(timeout: 15) else {
      XCTFail("Popover plane never appeared beside the Pick tab's own. Tree was:\n\(app.debugDescription)")
      return
    }

    // Both present, and querying either identifier alone resolves to exactly one
    // element — the claim a shared identifier could not make.
    XCTAssertEqual(app.otherElements.matching(identifier: "pickerPlane").count, 1)
    XCTAssertEqual(app.otherElements.matching(identifier: "compactPickerPlane").count, 1)
  }

  /// The dashed empty state is a button too (M24), and specifically a button whose
  /// label — a stroked-only rectangle — has nothing filled to catch a click in the
  /// middle unless it claims its own content shape. Clicking dead center with no
  /// color typed is exactly the case that would silently do nothing without it.
  func testTheEmptyStateSwatchOpensThePopoverToo() {
    let field = app.textFields["colorInput"]
    XCTAssertTrue(field.waitForExistence(timeout: 30))
    field.click()
    field.typeKey("a", modifierFlags: .command)
    field.typeText("\u{8}") // backspace, clearing the selection to nothing
    XCTAssertEqual(field.value as? String, "")

    let swatch = app.buttons["headerSwatch"]
    guard waitUntilHittable(swatch) else {
      XCTFail("Header swatch never became hittable. Tree was:\n\(app.debugDescription)")
      return
    }
    swatch.click()

    XCTAssertTrue(
      app.otherElements["compactPickerPlane"].waitForExistence(timeout: 15),
      "Clicking the empty-state swatch did not open the popover. Tree was:\n\(app.debugDescription)",
    )
  }

  // MARK: Private

  private var app: XCUIApplication!

  // MARK: - Helpers

  /// One named query, and the tree on failure. A chain that falls back to an index is
  /// a test that cannot go red — the lesson the contrast switcher taught.
  private func click(radioButton label: String, _ description: String) {
    let button = app.radioButtons[label]
    guard button.waitForExistence(timeout: 15) else {
      XCTFail("No radio button labelled \(label) (\(description)). Tree was:\n\(app.debugDescription)")
      return
    }
    guard waitUntilHittable(button) else {
      XCTFail("\(label) never became hittable (\(description)). Tree was:\n\(app.debugDescription)")
      return
    }
    button.click()
  }

  /// Polls rather than using `waitForExpectations`, whose completion handler cannot
  /// cross into a non-`Sendable` `XCTestCase` under Swift 6.
  private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 15) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if element.isHittable {
        return true
      }
      RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
    return element.isHittable
  }

  private func setField(_ text: String) {
    let field = app.textFields["colorInput"]
    XCTAssertTrue(field.waitForExistence(timeout: 30))
    field.click()
    field.typeKey("a", modifierFlags: .command)
    field.typeText(text)
  }
}
