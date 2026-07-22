//
//  ErrorView.swift
//  DeepDive
//

import SwiftUI

struct ErrorView: View {
    let error: Error

    var body: some View {
        VStack(spacing: 12) {
            Text("algo deu errado")
                .font(.headline)
                .foregroundStyle(.white)
            Text("não foi possível carregar a conversa. tenta abrir o app de novo.")
                .font(.subheadline)
                .foregroundStyle(Theme.timestampColor)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        ErrorView(error: StoryRepositoryError.missingFile)
    }
}
