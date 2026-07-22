//
//  TypingIndicatorView.swift
//  DeepDive
//

import SwiftUI

struct TypingIndicatorView: View {
    @State private var isAnimating = false

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 6, height: 6)
                        .scaleEffect(isAnimating ? 1 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.15),
                            value: isAnimating
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.characterBubble)
            .clipShape(RoundedRectangle(cornerRadius: Theme.bubbleCornerRadius))

            Spacer(minLength: 40)
        }
        .onAppear { isAnimating = true }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        TypingIndicatorView().padding()
    }
}
