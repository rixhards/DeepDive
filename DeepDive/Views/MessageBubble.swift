//
//  MessageBubble.swift
//  DeepDive
//

import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage
    let maxWidth: CGFloat
    /// Only the last bubble of a consecutive run from one sender is stamped (spec 010).
    var showsTimestamp: Bool = true
    /// How solid her voice still is. Computed by the view model from sanity; the player's
    /// own bubbles ignore it entirely.
    var characterOpacity: Double = 1
    /// Her words drift apart on the line as she comes apart.
    var characterTracking: Double = 0

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private var isPlayer: Bool { message.sender == .player }

    var body: some View {
        HStack(spacing: 0) {
            if isPlayer { Spacer(minLength: 40) }

            VStack(alignment: .leading, spacing: 4) {
                Text(message.text)
                    .foregroundStyle(Theme.primaryText)
                    .tracking(isPlayer ? 0 : characterTracking)
                    .fixedSize(horizontal: false, vertical: true)

                if showsTimestamp {
                    Text(Self.timeFormatter.string(from: message.timestamp))
                        .font(.caption2)
                        .foregroundStyle(Theme.timestampColor)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: maxWidth, alignment: .leading)
            .background(isPlayer ? Theme.playerBubble : Theme.characterBubble)
            .clipShape(RoundedRectangle(cornerRadius: Theme.bubbleCornerRadius))
            // Only she fades. The player is on the other end of the phone, perfectly fine.
            .opacity(isPlayer ? 1 : characterOpacity)
            .animation(Theme.degradationAnimation, value: characterOpacity)

            if !isPlayer { Spacer(minLength: 40) }
        }
    }
}

#Preview("sanidade alta") {
    ZStack {
        Theme.background.ignoresSafeArea()
        VStack(spacing: 3) {
            MessageBubble(
                message: ChatMessage(text: "tem alguém aí?", sender: .character, timestamp: .now),
                maxWidth: 300,
                showsTimestamp: false
            )
            MessageBubble(
                message: ChatMessage(text: "por favor me responde", sender: .character, timestamp: .now),
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

#Preview("sanidade baixa") {
    ZStack {
        Theme.background.ignoresSafeArea()
        VStack(spacing: 3) {
            MessageBubble(
                message: ChatMessage(text: "eu não sei mais... não sei", sender: .character, timestamp: .now),
                maxWidth: 300,
                characterOpacity: 0.72,
                characterTracking: 0.9
            )
            MessageBubble(
                message: ChatMessage(text: "fica comigo", sender: .player, timestamp: .now),
                maxWidth: 300,
                characterOpacity: 0.72
            )
        }
        .padding()
    }
}
