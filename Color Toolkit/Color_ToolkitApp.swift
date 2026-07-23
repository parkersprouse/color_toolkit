//
//  Color_ToolkitApp.swift
//  Color Toolkit
//
//  Created by Parker Sprouse on 7/23/26.
//

import SwiftUI

enum WindowID {
    static let main = "main"
}

@main
struct Color_ToolkitApp: App {

    /// One store, shared by both scenes.
    ///
    /// Constructing it separately per scene would compile cleanly and then silently
    /// diverge: colors filed from the menu bar would never reach the window, and the
    /// two would disagree about what the current color even is.
    @State private var store = ColorStore()

    var body: some Scene {
        // `Window` rather than `WindowGroup`: this is one workspace, not a document
        // type, so several independent copies of it would only fragment the recents
        // list and the current color.
        Window("Color Toolkit", id: WindowID.main) {
            ContentView()
                .environment(store)
        }
        .defaultSize(width: 620, height: 700)

        MenuBarExtra {
            MenuBarPanel()
                .environment(store)
        } label: {
            Image(systemName: "eyedropper.halffull")
        }
        .menuBarExtraStyle(.window)
    }
}
