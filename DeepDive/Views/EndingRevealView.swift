//
//  EndingRevealView.swift
//  DeepDive
//
//  The exclusive screen each ending gets: a short original phrase in the tone of that
//  ending (never a real quotation), the ambient music, and the way back. Replaces the chat
//  entirely once a run is over.

import SwiftUI

struct EndingRevealView: View {
    let ending: Ending?
    let onRestart: () -> Void
    var onMenu: (() -> Void)?

    /// Drawn once per appearance — the death phrase is random among five and must not
    /// reshuffle on every re-render.
    @State private var phrase = ""

    /// pt-BR label for an ending. Ids stay English like every other identifier; only what
    /// the player reads is translated.
    private var label: String {
        switch ending {
        case .escape: "você a tirou de lá"
        case .madness: "ela parou de querer sair"
        case .death: "ela não conseguiu sair"
        case nil: "acabou"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Text(label)
                    .font(.footnote)
                    .foregroundStyle(Theme.timestampColor)
                    .textCase(.lowercase)

                Text(phrase)
                    .font(.system(size: 24, weight: .light, design: .serif))
                    .italic()
                    .foregroundStyle(Theme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
                Button(action: onRestart) {
                    Text("recomeçar")
                        .font(.headline)
                        .foregroundStyle(Theme.accentLamp)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.accentLamp.opacity(0.07))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Theme.accentLamp.opacity(0.45), lineWidth: 0.5))
                }

                if let onMenu {
                    Button(action: onMenu) {
                        Text("menu")
                            .font(.headline)
                            .foregroundStyle(Theme.timestampColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .overlay(Capsule().stroke(Theme.hairline, lineWidth: 0.5))
                    }
                }
            }
            .padding(.horizontal, 40)

            Spacer()
                .frame(height: 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .onAppear {
            phrase = Self.endingPhrase(for: ending)
            AudioManager.shared.playAmbience()
        }
        .onDisappear {
            AudioManager.shared.stop()
        }
    }

    private static func endingPhrase(for ending: Ending?) -> String {
        switch ending {
        case .escape: WorldMap.escapeEndingPhrase
        case .madness: WorldMap.madnessEndingPhrase
        case .death: WorldMap.deathEndingPhrases.randomElement() ?? ""
        case nil: ""
        }
    }
}

#Preview("morte") {
    EndingRevealView(ending: .death, onRestart: {}, onMenu: {})
}

#Preview("fuga") {
    EndingRevealView(ending: .escape, onRestart: {})
}

#Preview("loucura") {
    EndingRevealView(ending: .madness, onRestart: {})
}
