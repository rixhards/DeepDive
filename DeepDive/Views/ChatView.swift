//
//  ChatView.swift
//  DeepDive
//

import SwiftUI

struct ChatView: View {
    var onExit: (() -> Void)?

    @State private var viewModel = ChatViewModel()
    @State private var inputText = ""
    @State private var isConfirmingRestart = false

    /// When the player has asked the system for less visual noise, her words stay fully
    /// legible and only the vignette carries the degradation (spec 010, casos de borda).
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Group {
            if viewModel.isFinished {
                // Each ending gets its own exclusive screen, replacing the chat.
                EndingRevealView(
                    ending: viewModel.reachedEnding,
                    onRestart: {
                        inputText = ""
                        viewModel.restart()
                    },
                    onMenu: onExit
                )
            } else {
                chatBody
            }
        }
        .animation(.easeInOut(duration: 0.6), value: viewModel.isFinished)
        .background(Theme.background.ignoresSafeArea())
        .onAppear { viewModel.start() }
        .confirmationDialog(
            "recomeçar a partida?",
            isPresented: $isConfirmingRestart,
            titleVisibility: .visible
        ) {
            Button("recomeçar do início", role: .destructive) {
                inputText = ""
                viewModel.restart()
            }
            if onExit != nil {
                Button("voltar ao menu") { onExit?() }
            }
            Button("continuar jogando", role: .cancel) {}
        } message: {
            Text("tudo que ela viveu até aqui se perde.")
        }
    }

    private var chatBody: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                                MessageBubble(
                                    message: message,
                                    maxWidth: geometry.size.width * Theme.bubbleMaxWidthRatio,
                                    // Only the last message of a run of messages from the
                                    // same sender is stamped — a time on every bubble reads
                                    // as a log, not a conversation.
                                    showsTimestamp: isLastOfBlock(index),
                                    characterOpacity: reduceTransparency ? 1 : viewModel.characterBubbleOpacity,
                                    characterTracking: reduceTransparency ? 0 : viewModel.characterTracking
                                )
                                .padding(.top, topSpacing(before: index))
                                .id(message.id)
                            }

                            if viewModel.isTyping {
                                TypingIndicatorView()
                                    .padding(.top, Theme.messageSpacing)
                                    .id(Self.typingIndicatorID)
                            }
                        }
                        .padding(.horizontal, Theme.screenPadding)
                        .padding(.vertical, Theme.screenPadding)
                    }
                    .onChange(of: viewModel.messages.count) {
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: viewModel.isTyping) {
                        scrollToBottom(proxy: proxy)
                    }
                }

                if !viewModel.isTyping {
                    ComposerView(text: $inputText, isDisabled: false) {
                        viewModel.send(inputText)
                        inputText = ""
                    }
                }
            }
            .overlay(
                VignetteOverlay(
                    intensity: viewModel.vignetteIntensity,
                    coldness: viewModel.coldVeilOpacity
                )
            )
        }
    }

    private static let typingIndicatorID = "typing-indicator"

    /// No green dot: she is not online, and a presence indicator borrowed from a messaging
    /// app quietly contradicts the whole premise (spec 010).
    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("número desconhecido")
                    .font(.headline)
                    .foregroundStyle(Theme.primaryText)
                Text("sem operadora · sem data")
                    .font(.caption2)
                    .foregroundStyle(Theme.timestampColor)
            }
            Spacer()
            Button {
                isConfirmingRestart = true
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Theme.primaryText.opacity(0.7))
                    .frame(width: 44, height: 44, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("opções da partida")
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.vertical, 10)
        .background(Theme.headerBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 0.5)
        }
    }

    // MARK: - Message grouping

    private func isLastOfBlock(_ index: Int) -> Bool {
        let messages = viewModel.messages
        guard index < messages.count else { return true }
        guard index + 1 < messages.count else { return true }
        return messages[index + 1].sender != messages[index].sender
    }

    private func topSpacing(before index: Int) -> CGFloat {
        guard index > 0 else { return 0 }
        let messages = viewModel.messages
        let continuesBlock = messages[index - 1].sender == messages[index].sender
        return continuesBlock ? Theme.groupedMessageSpacing : Theme.messageSpacing
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.25)) {
            if viewModel.isTyping {
                proxy.scrollTo(Self.typingIndicatorID, anchor: .bottom)
            } else if let lastID = viewModel.messages.last?.id {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }
}

#Preview {
    ChatView()
}
