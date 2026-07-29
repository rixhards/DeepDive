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

            VStack(spacing: 10) {
                Text("DEEPDIVE")
                    .font(.system(size: 40, weight: .light, design: .serif))
                    .tracking(10)
                    .foregroundStyle(.white)

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
    }

    private func menuLabel(_ title: String, prominent: Bool) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(prominent ? .white : Theme.timestampColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(prominent ? Theme.optionBackground : .clear)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Theme.optionBackground, lineWidth: prominent ? 0 : 1)
            )
    }
}

#Preview {
    MenuView(hasSavedRun: true, onContinue: {}, onNewGame: {})
}
