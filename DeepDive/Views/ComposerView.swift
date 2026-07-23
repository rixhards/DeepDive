//
//  ComposerView.swift
//  DeepDive
//

import SwiftUI

struct ComposerView: View {
    @Binding var text: String
    let isDisabled: Bool
    let onSend: () -> Void

    private var canSend: Bool {
        !isDisabled && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 8) {
            TextField("Digite sua mensagem...", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.optionBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.bubbleCornerRadius))
                .foregroundStyle(.white)
                .disabled(isDisabled)

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(canSend ? Theme.playerBubble : Theme.timestampColor)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.vertical, 8)
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        VStack {
            Spacer()
            ComposerView(text: .constant(""), isDisabled: false, onSend: {})
        }
    }
}
