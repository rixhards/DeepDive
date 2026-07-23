//
//  ChatView.swift
//  DeepDive
//

import SwiftUI

struct ChatView: View {
    @State private var viewModel = ChatViewModel()
    @State private var inputText = ""

    var body: some View {
        Group {
            if case .failed(let error) = viewModel.state {
                ErrorView(error: error)
            } else {
                chatBody
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .onAppear { viewModel.start() }
    }

    private var chatBody: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header

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

                if case .ready = viewModel.state, !viewModel.isTyping, !viewModel.isFinished {
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
            Image(systemName: "ellipsis")
                .foregroundStyle(.white)
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
