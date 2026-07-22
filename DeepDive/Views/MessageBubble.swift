//
//  MessageBubble.swift
//  DeepDive
//

import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage
    let maxWidth: CGFloat

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private var isPlayer: Bool { message.sender == .player }

    var body: some View {
        HStack {
            if isPlayer { Spacer(minLength: 40) }

            VStack(alignment: .leading, spacing: 4) {
                Text(message.text)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(Self.timeFormatter.string(from: message.timestamp))
                    .font(.caption2)
                    .foregroundStyle(Theme.timestampColor)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: maxWidth, alignment: .leading)
            .background(isPlayer ? Theme.playerBubble : Theme.characterBubble)
            .clipShape(RoundedRectangle(cornerRadius: Theme.bubbleCornerRadius))

            if !isPlayer { Spacer(minLength: 40) }
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        VStack(spacing: 8) {
            MessageBubble(
                message: ChatMessage(text: "tem alguém aí?", sender: .character, timestamp: .now),
                maxWidth: 300
            )
            MessageBubble(
                message: ChatMessage(text: "quem é você?", sender: .player, timestamp: .now),
                maxWidth: 300
            )
        }
        .padding()
    }
}
