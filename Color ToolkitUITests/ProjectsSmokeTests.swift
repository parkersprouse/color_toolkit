//
//  ProjectsSmokeTests.swift
//  Color ToolkitUITests
//

import XCTest

/// The projects panel, against a store that evaporates.
///
/// **Every launch here passes `UITestInMemoryStore`.** XCUITest drives the shipping app,
/// so without it a test that saves a project would deposit it in the person's own
/// library and leave it there — and the next run would find it and assert against it.
/// The launch argument is the only way to reach that decision, the app being a separate
/// process.
///
/// What is worth testing here and nowhere else is the *round trip through the store*:
/// ``ProjectStoreTests`` proves a saved color comes back out of a `ModelContext`, but
/// only a running app can show that clicking a saved swatch puts the spelling back in
/// the field, and that a palette saved in one tool exports under its own name in
/// another.
final class ProjectsSmokeTests: XCTestCase {
  // MARK: Internal

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = ["UITestInMemoryStore"]
    app.launch()
    XCTAssertTrue(
      app.wait(for: .runningForeground, timeout: 30),
      "App did not reach the foreground",
    )
  }

  override func tearDownWithError() throws {
    app?.terminate()
    _ = app?.wait(for: .notRunning, timeout: 30)
    app = nil
  }

  // MARK: - Tests

  /// The whole reason a saved color stores its text: recalling it returns *your*
  /// spelling. A store keeping only components would come back `#663399`, which is the
  /// same color and not the same answer.
  func testARecalledColorKeepsTheSpellingItWasSavedWith() {
    setField("rebeccapurple")
    click(radioButton: "Projects", "the tool switcher")
    createProject()

    clickButton("saveColor", "the save-color button")

    let swatch = app.buttons["savedColor-0"]
    XCTAssertTrue(
      swatch.waitForExistence(timeout: 15),
      "Nothing was saved. Tree was:\n\(app.debugDescription)",
    )
    XCTAssertEqual(
      swatch.label,
      "rebeccapurple",
      "A saved swatch carries its CSS as its accessibility label",
    )
    capture("projects-saved-color")

    // Move the field somewhere else, then click the saved color to bring it back.
    setField("#ff0000")
    XCTAssertTrue(waitUntilHittable(swatch), "The saved swatch never became clickable")
    swatch.click()

    XCTAssertEqual(
      fieldValue(),
      "rebeccapurple",
      "Recalling a saved color must return the spelling, not a canonicalized form",
    )
  }

  /// The seam M8 deferred, end to end: save a ramp in one tool, export it from another.
  ///
  /// Both halves matter. Eleven swatches prove the order and count survived the store —
  /// the entries come back out of an *unordered* SwiftData relationship, sorted by an
  /// explicit index. `--brand-500` proves the palette's own name reached
  /// `ExportOptions`, rather than the export panel keeping whatever it was last set to.
  func testASavedRampExportsUnderItsOwnName() {
    setField("#3b82f6")
    click(radioButton: "Projects", "the tool switcher")
    createProject()

    typeInto("saveName", "brand")
    select(menuItem: "Ramp", fromMenu: "saveSet", "the save-set menu")

    XCTAssertTrue(
      app.otherElements["palette-0-swatch-10"].waitForExistence(timeout: 15),
      "Expected eleven saved ramp stops. Tree was:\n\(app.debugDescription)",
    )
    capture("projects-saved-ramp")

    clickButton("paletteExport-0", "the palette export button")

    let document = readout("exportDocument")
    XCTAssertTrue(
      document.contains("--brand-500:"),
      "A staged palette should export under its own name, got:\n\(document)",
    )
    XCTAssertTrue(
      document.contains("--brand-950:"),
      "The dark end of the saved ramp is missing from:\n\(document)",
    )
    capture("projects-exported-palette")
  }

  /// Deleting a project takes its contents with it, and the panel returns to the state
  /// it started in. The cascade is asserted against a context in ``ProjectStoreTests``;
  /// what this adds is that the view stops showing what was deleted.
  func testDeletingAProjectClearsItsContents() {
    setField("#3b82f6")
    click(radioButton: "Projects", "the tool switcher")
    createProject()
    clickButton("saveColor", "the save-color button")
    XCTAssertTrue(app.buttons["savedColor-0"].waitForExistence(timeout: 15))

    clickButton("projectsDelete", "the delete-project button")
    // Scoped to the sheet. An app-wide `buttons["Delete Project"]` matches more than one
    // element — a confirmation dialog appears in the tree under both the app and its
    // window — and an ambiguous query fails at the click with no tree to read.
    let confirm = app.sheets.buttons["Delete Project"]
    XCTAssertTrue(
      confirm.waitForExistence(timeout: 15),
      "No confirmation sheet. Tree was:\n\(app.debugDescription)",
    )
    confirm.click()

    XCTAssertTrue(
      app.staticTexts["No projects yet"].waitForExistence(timeout: 15),
      "The panel should return to its empty state. Tree was:\n\(app.debugDescription)",
    )
    XCTAssertFalse(app.buttons["savedColor-0"].exists, "A deleted project's colors survived")
  }

  // MARK: Private

  private var app: XCUIApplication!

  // MARK: - Helpers

  /// One named query, and the tree on failure — never a fallback chain, which is a test
  /// that cannot fail. Hittability rather than existence, because switching tools
  /// resizes the window under a click already in flight.
  private func click(radioButton label: String, _ description: String) {
    let button = app.radioButtons[label]
    guard button.waitForExistence(timeout: 15) else {
      XCTFail(
        "No radio button labelled \(label) (\(description)). Tree was:\n\(app.debugDescription)",
      )
      return
    }
    guard waitUntilHittable(button) else {
      XCTFail("\(label) never became hittable (\(description)). Tree:\n\(app.debugDescription)")
      return
    }
    button.click()
  }

  private func clickButton(_ identifier: String, _ description: String) {
    let button = app.buttons[identifier]
    guard button.waitForExistence(timeout: 15) else {
      XCTFail("No button \(identifier) (\(description)). Tree was:\n\(app.debugDescription)")
      return
    }
    guard waitUntilHittable(button) else {
      XCTFail("\(identifier) never became hittable. Tree was:\n\(app.debugDescription)")
      return
    }
    button.click()
  }

  private func select(menuItem title: String, fromMenu identifier: String, _ description: String) {
    // `menuButtons`, not `popUpButtons`: a SwiftUI `Menu` renders as an AppKit
    // MenuButton, where a `Picker` renders as a pop-up. They are different queries and
    // the wrong one simply never matches.
    let popUp = app.menuButtons[identifier]
    guard popUp.waitForExistence(timeout: 15) else {
      XCTFail("No menu \(identifier) (\(description)). Tree was:\n\(app.debugDescription)")
      return
    }
    guard waitUntilHittable(popUp) else {
      XCTFail("\(identifier) never became hittable. Tree was:\n\(app.debugDescription)")
      return
    }
    popUp.click()

    let item = app.menuItems[title]
    guard item.waitForExistence(timeout: 15) else {
      XCTFail("No menu item \(title) in \(identifier). Tree was:\n\(app.debugDescription)")
      return
    }
    item.click()
  }

  /// The panel opens on its empty state, so the first project is made through the button
  /// that sits there.
  private func createProject() {
    clickButton("projectsNew", "the new-project button")
    XCTAssertTrue(
      app.textFields["projectName"].waitForExistence(timeout: 15),
      "No project was created. Tree was:\n\(app.debugDescription)",
    )
  }

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

  private func typeInto(_ identifier: String, _ text: String) {
    let field = app.textFields[identifier]
    guard field.waitForExistence(timeout: 15) else {
      XCTFail("No text field \(identifier). Tree was:\n\(app.debugDescription)")
      return
    }
    field.click()
    field.typeKey("a", modifierFlags: .command)
    field.typeText(text)
  }

  private func setField(_ text: String) {
    typeInto("colorInput", text)
  }

  private func fieldValue() -> String {
    app.textFields["colorInput"].value as? String ?? ""
  }

  /// Reads a readout's `value`, not its `label` — `.accessibilityIdentifier` on a
  /// SwiftUI `Text` publishes the string as the element's value and leaves the label
  /// empty.
  private func readout(_ identifier: String) -> String {
    let element = app.staticTexts[identifier]
    guard element.waitForExistence(timeout: 15) else {
      XCTFail("No readout \(identifier). Tree was:\n\(app.debugDescription)")
      return ""
    }
    return element.value as? String ?? ""
  }

  private func capture(_ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
