//
//  PersistenceStack.swift
//  Color Toolkit
//

import Foundation
import SwiftData

/// The app's SwiftData container, and the two decisions that come with building one.
///
/// **One container, attached to both scenes** — the same rule ``ColorStore`` follows.
/// Two containers over one store would compile and then fight: a project created from
/// the menu bar would be invisible to the window until something forced a refetch.
///
/// **A UI test must never write to the real store.** XCUITest launches the shipping app,
/// so a test that saves a project would deposit it in the user's own library and leave it
/// there — and the next run would find it. The launch argument is the only way in: the
/// app is a separate process, so nothing else a test does can reach this decision.
enum PersistenceStack {
  /// Passed by ``XCUIApplication`` in the UI tests to get a store that evaporates.
  static let inMemoryLaunchArgument = "-in-memory-store"

  static let schema = Schema([Project.self, Palette.self, SavedColor.self])

  /// Whether this process was launched by a UI test.
  static var wantsInMemoryStore: Bool {
    ProcessInfo.processInfo.arguments.contains(inMemoryLaunchArgument)
  }

  /// The container, and whether it is the ephemeral one.
  ///
  /// The fallback is deliberate and so is reporting it. A store that will not open —
  /// corrupt, or written by a version that knows a model this build does not — leaves
  /// two choices: refuse to launch, or run without persistence. For a tool opened dozens
  /// of times a day the second is far better, *provided it says so*: silently accepting
  /// saves that vanish at quit would be the worst of the three. ``ProjectsPanel`` shows a
  /// banner when `isEphemeral` is true, which is why this returns the flag rather than
  /// swallowing it.
  static func make(inMemory: Bool = wantsInMemoryStore) -> (container: ModelContainer, isEphemeral: Bool) {
    if !inMemory {
      let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
      if let container = try? ModelContainer(for: schema, configurations: configuration) {
        return (container, false)
      }
    }

    let ephemeral = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    guard let container = try? ModelContainer(for: schema, configurations: ephemeral) else {
      // An in-memory container failing means the schema itself is invalid — a
      // relationship SwiftData cannot resolve, say. That is a build-time mistake
      // wearing a runtime costume, and there is nothing sensible to run without.
      // `ProjectStoreTests` asserts the container builds precisely so this line is
      // unreachable in a shipped build.
      fatalError("The SwiftData schema is invalid; no container could be created.")
    }
    return (container, true)
  }
}
