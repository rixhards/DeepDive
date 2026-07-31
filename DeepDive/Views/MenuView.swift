//
//  MenuView.swift
//  DeepDive
//

import SwiftUI

struct MenuView: View {
    let hasSavedRun: Bool
    let onContinue: () -> Void
    let onNewGame: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Text("DEEPDIVE")
                    .font(.system(size: 40, weight: .light, design: .serif))
                    .tracking(10)
                    .foregroundStyle(Theme.primaryText)

                // The one warm line on the screen: the lamp she's holding.
                Rectangle()
                    .fill(Theme.accentLamp.opacity(0.6))
                    .frame(width: 56, height: 0.5)

                Text("alguém está te mandando mensagem\nde um lugar que não devia existir")
                    .font(.footnote)
                    .foregroundStyle(Theme.timestampColor)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Spacer()

            VStack(spacing: 12) {
                if hasSavedRun {
                    Button(action: onContinue) {
                        menuLabel("continuar", prominent: true)
                    }
                }
                Button(action: onNewGame) {
                    menuLabel(hasSavedRun ? "recomeçar do início" : "começar", prominent: !hasSavedRun)
                }
            }
            .padding(.horizontal, 40)

            Spacer()
                .frame(height: 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        // Ambient loop lives on the menu; starting a run silences it (GAME_SCOPE, Áudio).
        .onAppear { AudioManager.shared.playAmbience() }
        .onDisappear { AudioManager.shared.stop() }
    }

    /// The primary button is the only one that gets the lamp colour (spec 010).
    private func menuLabel(_ title: String, prominent: Bool) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(prominent ? Theme.accentLamp : Theme.timestampColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(prominent ? Theme.accentLamp.opacity(0.07) : .clear)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(
                    prominent ? Theme.accentLamp.opacity(0.45) : Theme.hairline,
                    lineWidth: 0.5
                )
            )
    }
}

#Preview {
    MenuView(hasSavedRun: true, onContinue: {}, onNewGame: {})
}
