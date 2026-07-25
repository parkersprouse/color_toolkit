//
//  Color_ToolkitApp.swift
//  Color Toolkit
//
//  Created by Parker Sprouse on 7/23/26.
//

import SwiftData
import SwiftUI

enum WindowID {
  static let main = "main"
}

/// What kind of projects store the app opened. See ``PersistenceStack/Status``.
///
/// An environment value rather than a property on ``ColorStore``, because it is a fact
/// about how the *app* was launched rather than app state — nothing can change it, and
/// only one view ever reads it.
extension EnvironmentValues {
  @Entry var projectStoreStatus = PersistenceStack.Status.persistent
}

@main
struct Color_ToolkitApp: App {
  // MARK: Internal

  var body: some Scene {
    // `Window` rather than `WindowGroup`: this is one workspace, not a document
    // type, so several independent copies of it would only fragment the recents
    // list and the current color.
    Window("Color Toolkit", id: WindowID.main) {
      ContentView()
        .environment(store)
        .environment(\.projectStoreStatus, persistence.status)
    }
    .defaultSize(width: 620, height: 700)
    .modelContainer(persistence.container)

    MenuBarExtra {
      MenuBarPanel()
        .environment(store)
    } label: {
      MenuBarLabel()
        .environment(store)
    }
    .menuBarExtraStyle(.window)
    // The same container, for the same reason both scenes share one `ColorStore`: two
    // containers over one store would compile and then disagree, and a project created
    // in one would be invisible to the other until something forced a refetch.
    .modelContainer(persistence.container)
  }

  // MARK: Private

  /// One store, shared by both scenes.
  ///
  /// Constructing it separately per scene would compile cleanly and then silently
  /// diverge: colors filed from the menu bar would never reach the window, and the
  /// two would disagree about what the current color even is.
  @State private var store = ColorStore()

  /// Built once, here, rather than by `.modelContainer(for:)` on each scene — that
  /// modifier makes a container per call site.
  @State private var persistence = PersistenceStack.make()
}

/// The menu bar icon, which doubles as the only feedback a global capture gets.
///
/// Pressing the shortcut from another app shows the loupe, takes a click, and then —
/// without this — nothing visible happens, because the app that captured the color is
/// not the one the user is looking at. A brief checkmark on the icon says the color
/// landed, needs no notification permission, and costs no window.
struct MenuBarLabel: View {
  // MARK: Internal

  var body: some View {
    Image(systemName: store.justCaptured ? "checkmark.circle.fill" : "eyedropper.halffull")
      // One of two places the shortcut is claimed. Both are needed and neither is
      // redundant: this view exists unless the user hides the menu bar item, the
      // window's exists unless the window is closed, and `activateGlobalShortcut`
      // is idempotent so whichever appears first wins.
      .task { store.activateGlobalShortcut() }
  }

  // MARK: Private

  @Environment(ColorStore.self) private var store
}
