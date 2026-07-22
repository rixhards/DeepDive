//
//  DeepDiveApp.swift
//  DeepDive
//
//  Created by Richard Fagundes Rodrigues on 17/07/26.
//

import SwiftUI

@main
struct DeepDiveApp: App {
    var body: some Scene {
        WindowGroup {
            ChatView()
                .preferredColorScheme(.dark)
        }
    }
}
