//
//  RootView.swift
//  DeepDive
//
//  Owns the menu ↔ game switch. `runToken` forces SwiftUI to rebuild ChatView (and with it a
//  fresh ChatViewModel) whenever a new run starts, so no state leaks between runs.

import SwiftUI

struct RootView: View {
    @State private var isPlaying = false
    @State private var hasSavedRun = SessionRepository.savedRunExists()
    @State private var runToken = UUID()

    var body: some View {
        if isPlaying {
            ChatView(onExit: leaveToMenu)
                .id(runToken)
        } else {
            MenuView(
                hasSavedRun: hasSavedRun,
                onContinue: {
                    runToken = UUID()
                    isPlaying = true
                },
                onNewGame: {
                    try? SessionRepository().delete()
                    hasSavedRun = false
                    runToken = UUID()
                    isPlaying = true
                }
            )
        }
    }

    private func leaveToMenu() {
        isPlaying = false
        hasSavedRun = SessionRepository.savedRunExists()
    }
}
