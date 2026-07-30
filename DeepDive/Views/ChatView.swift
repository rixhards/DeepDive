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

                if DebugFlags.showSanityMeter {
                    SanityMeterView(sanity: viewModel.currentSanity)
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: Theme.messageSpacing) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(
                                    message: message,
                                    maxWidth: geometry.size.width * Theme.bubbleMaxWidthRatio
                                )
                                .id(message.id)
                            }

                            if viewModel.isTyping {
                                TypingIndicatorView()
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

                if viewModel.isFinished {
                    EndingRevealView(
                        ending: viewModel.reachedEnding,
                        onRestart: {
                            inputText = ""
                            viewModel.restart()
                        },
                        onMenu: onExit
                    )
                } else if !viewModel.isTyping {
                    ComposerView(text: $inputText, isDisabled: false) {
                        viewModel.send(inputText)
                        inputText = ""
                    }
                }
            }
        }
    }

    private static let typingIndicatorID = "typing-indicator"

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
            Text("número desconhecido")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            Button {
                isConfirmingRestart = true
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("opções da partida")
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.vertical, 12)
        .background(Theme.headerBackground)
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
