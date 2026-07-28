//
//  EndingRevealView.swift
//  DeepDive
//
//  Shown in place of the composer once a run is over: names the ending reached and offers a
//  fresh run. "Voltar ao menu" arrives with the menu itself (spec 010).

import SwiftUI

struct EndingRevealView: View {
    let ending: Ending?
    let onRestart: () -> Void

    /// pt-BR label for an ending. Ids stay English like every other identifier; only what the
    /// player reads is translated.
    private var label: String {
        switch ending {
        case .escape: "você a tirou de lá"
        case .surrender: "ela parou de procurar a saída"
        case .taken: "levaram ela"
        case nil: "acabou"
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Theme.timestampColor)
                .multilineTextAlignment(.center)

            Button(action: onRestart) {
                Text("recomeçar")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Theme.optionBackground)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.screenPadding)
        .padding(.vertical, 20)
        .background(Theme.headerBackground)
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        VStack {
            Spacer()
            EndingRevealView(ending: .taken, onRestart: {})
        }
    }
}
