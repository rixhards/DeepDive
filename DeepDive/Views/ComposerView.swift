//
//  ComposerView.swift
//  DeepDive
//
//  A line to write on, not a chat pill (spec 010): the filled capsule was the last piece of
//  borrowed messaging-app furniture on the screen.

import SwiftUI

struct ComposerView: View {
    @Binding var text: String
    let isDisabled: Bool
    let onSend: () -> Void

    @FocusState private var isFocused: Bool

    private var canSend: Bool {
        !isDisabled && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(spacing: 6) {
                TextField("escreva pra ela...", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Theme.primaryText)
                    .tint(Theme.accentLamp)
                    .focused($isFocused)
                    .disabled(isDisabled)
                    .padding(.top, 6)

                Rectangle()
                    .fill(isFocused ? Theme.accentLamp.opacity(0.55) : Theme.hairline)
                    .frame(height: 0.5)
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
            }

            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(canSend ? Theme.accentLamp : Theme.timestampColor)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle().stroke(
                            canSend ? Theme.accentLamp.opacity(0.5) : Theme.hairline,
                            lineWidth: 0.5
                        )
                    )
                    .contentShape(Circle())
            }
            .disabled(!canSend)
            .accessibilityLabel("enviar mensagem")
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Theme.headerBackground)
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        VStack {
            Spacer()
            ComposerView(text: .constant(""), isDisabled: false, onSend: {})
            ComposerView(text: .constant("vai pela estrada"), isDisabled: false, onSend: {})
        }
    }
}
