//
//  ContentView.swift
//  Color Toolkit
//
//  Created by Parker Sprouse on 7/23/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ContentUnavailableView(
            "Color Toolkit",
            systemImage: "eyedropper.halffull",
            description: Text("The interface arrives in M3. The color engine is being built first.")
        )
        .frame(minWidth: 480, minHeight: 320)
    }
}

#Preview {
    ContentView()
}
