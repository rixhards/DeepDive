//
//  DeepDiveApp.swift
//  DeepDive
//
//  Created by Richard Fagundes Rodrigues on 17/07/26.
//

import AppIntents
import SwiftUI

@main
struct DeepDiveApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .task {
                    // Required: tells iOS to index our App Shortcuts so they appear
                    // in Siri, Spotlight, and the Shortcuts app.
                    DeepDiveShortcuts.updateAppShortcutParameters()
                }
        }
    }
}
