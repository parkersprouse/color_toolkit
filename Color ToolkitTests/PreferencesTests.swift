//
//  PreferencesTests.swift
//  Color ToolkitTests
//

@testable import Color_Toolkit
import Foundation
import Observation
import Testing

/// - Note: Every test here that touches ``PreferenceStore`` injects its own
///   `UserDefaults(suiteName:)`, never `.standard` — a test writing to the real
///   defaults would pollute whatever the developer running it has actually set, exactly
///   the hazard ``PreferenceStore/ephemeralLaunchArgument`` exists to prevent for
///   XCUITest. Each suite is removed in a `defer` so runs do not accumulate state.
@Suite("Preferences")
struct PreferencesTests {
  // MARK: Internal

  @Test("Every field survives an encode/decode round trip")
  func roundTrips() throws {
    let data = try JSONEncoder().encode(Self.nonDefault)
    let decoded = try JSONDecoder().decode(Preferences.self, from: data)

    #expect(decoded == Self.nonDefault)
    // And the default itself, so a field that happens to decode to *some* value
    // rather than the one encoded — the failure mode a dropped `CodingKeys` entry
    // produces — cannot pass by coincidence against only one fixture.
    #expect(decoded != Preferences())
  }

  @Test("Decoding garbage yields defaults, not a crash")
  func corruptStoreYieldsDefaults() throws {
    let defaults = try #require(UserDefaults(suiteName: "PreferencesTests.garbage"))
    defer { defaults.removePersistentDomain(forName: "PreferencesTests.garbage") }

    defaults.set(Data("not json".utf8), forKey: PreferenceStore.defaultsKey)

    #expect(PreferenceStore.load(from: defaults) == Preferences())
  }

  @Test("Nothing stored yields defaults")
  func emptyStoreYieldsDefaults() throws {
    let defaults = try #require(UserDefaults(suiteName: "PreferencesTests.empty"))
    defer { defaults.removePersistentDomain(forName: "PreferencesTests.empty") }

    #expect(PreferenceStore.load(from: defaults) == Preferences())
  }

  @Test("What is saved is what the next load reads back")
  func saveThenLoadRoundTrips() throws {
    let defaults = try #require(UserDefaults(suiteName: "PreferencesTests.roundtrip"))
    defer { defaults.removePersistentDomain(forName: "PreferencesTests.roundtrip") }

    PreferenceStore.save(Self.nonDefault, to: defaults)

    #expect(PreferenceStore.load(from: defaults) == Self.nonDefault)
  }

  @MainActor
  @Test("ColorStore applies a loaded Preferences and re-emits an equal one")
  func colorStoreRoundTripsPreferences() {
    let store = ColorStore()

    store.preferences = Self.nonDefault

    #expect(store.preferences == Self.nonDefault)
    #expect(store.webFriendly == true)
    #expect(store.showsRecents == false)
    #expect(store.recentLimit == 25)
    #expect(store.pickerMode == .oklch)
    #expect(store.cvdDeficiency == .protanomaly)
    #expect(store.exportOptions.shape == .tailwindConfig)
    #expect(store.exportOptions.template == .border)
    #expect(store.exportOptions.format == .color(.displayP3))
    #expect(store.formatOptions == Self.nonDefault.formatOptions)
  }

  /// A regression test for a real crash, not a hypothetical one: `remember()` computes
  /// `recents.removeLast(recents.count - recentLimit)`, and a negative `recentLimit`
  /// makes that argument exceed the array's size the first time a color is
  /// remembered. `Preferences.recentLimit` decodes successfully for any `Int` — the
  /// Settings panel's Stepper is the only thing that keeps it in `1...50` in the
  /// ordinary path, and a hand-edited or corrupted preferences file bypasses it
  /// entirely.
  @MainActor
  @Test("A corrupt negative recentLimit is clamped rather than crashing remember()")
  func negativeRecentLimitIsClamped() {
    let store = ColorStore(initialInput: "red")
    var corrupt = Preferences()
    corrupt.recentLimit = -5

    store.preferences = corrupt
    store.remember()

    #expect(store.recentLimit >= 1)
    #expect(store.recents.count == 1)
  }

  @MainActor
  @Test("Assigning preferences leaves session state untouched")
  func preferencesDoNotTouchSessionState() {
    let store = ColorStore(initialInput: "rebeccapurple")
    let inputBefore = store.inputText
    store.exportOptions.name = "brand"

    store.preferences = Self.nonDefault

    // `exportOptions.name` is session state, deliberately absent from `Preferences` —
    // assigning `preferences` must not reset it to `ExportOptions.defaultName` as a
    // side effect of touching the rest of `exportOptions`.
    #expect(store.exportOptions.name == "brand")
    #expect(store.inputText == inputBefore)
  }

  /// Pins the claim `ColorStore.preferences`'s doc comment makes: reading the computed
  /// getter registers `@Observable` access to every field it touches, which is what
  /// lets `Color_ToolkitApp`'s `.onChange(of: store.preferences)` fire on *any*
  /// persisted change without listing nine properties itself. That claim is exactly
  /// the "compiles perfectly and does nothing" shape this codebase has been burned by
  /// before, so it is checked directly rather than left as reasoning in a comment.
  ///
  /// Three mutation sites, not one: a field directly on the store, one nested inside
  /// `formatOptions`, and one nested inside `exportOptions` — the two nested cases are
  /// what a getter that only tracked its own top-level properties would miss.
  @MainActor
  @Test("Mutating any persisted field invalidates a read of preferences")
  func preferencesObservesEveryPersistedField() {
    let mutations: [(String, (ColorStore) -> Void)] = [
      ("webFriendly", { $0.webFriendly = true }),
      ("formatOptions.legacy", { $0.formatOptions.legacy = true }),
      ("exportOptions.shape", { $0.exportOptions.shape = .json }),
    ]

    for (name, mutate) in mutations {
      let store = ColorStore()
      // `onChange` is `@Sendable`, and this is a same-thread, synchronous test — the
      // mutation happens right after registering the observation and nothing else
      // touches `fired` — so the unchecked opt-out is safe here.
      nonisolated(unsafe) var fired = false
      withObservationTracking {
        _ = store.preferences
      } onChange: {
        fired = true
      }

      mutate(store)

      #expect(fired, "reading `preferences` did not observe a change to \(name)")
    }
  }

  // MARK: Private

  /// Every field changed from its default, so a mistakenly-omitted `CodingKeys` entry
  /// — or one that maps the wrong property — has something to disagree about. `.color`
  /// is deliberately not the chosen ``CSSOutputFormat``: that is the default, and
  /// `.color(.displayP3)` is what exercises `CSSOutputFormat`'s associated-value
  /// encoding path rather than one of its plain cases.
  private static let nonDefault = Preferences(
    formatOptions: CSSFormatOptions(
      precision: 6,
      legacy: true,
      rgbAsPercentage: true,
      collapseHex: true,
      uppercaseHex: true,
      alpha: .always,
      gamut: .preserve,
      noneForPowerlessComponents: true,
    ),
    webFriendly: true,
    showsRecents: false,
    recentLimit: 25,
    pickerMode: .oklch,
    cvdDeficiency: .protanomaly,
    exportShape: .tailwindConfig,
    exportTemplate: .border,
    exportFormat: .color(.displayP3),
  )
}
