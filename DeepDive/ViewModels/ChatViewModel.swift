//
//  ChatViewModel.swift
//  DeepDive
//

import Foundation
import Observation

@Observable
final class ChatViewModel {
    private(set) var messages: [ChatMessage] = []
    private(set) var currentOptions: [ConversationOption] = []
    private(set) var isTyping = false
    private(set) var isFinished = false

    private var currentNodeID: String
    private let nodesByID: [String: ConversationNode]
    private var deliveryTask: Task<Void, Never>?
    private var hasStarted = false

    init(
        conversation: [ConversationNode] = MockConversation.nodes,
        startNodeID: String = MockConversation.startNodeID
    ) {
        self.nodesByID = Dictionary(uniqueKeysWithValues: conversation.map { ($0.id, $0) })
        self.currentNodeID = startNodeID
    }

    /// Kicks off the conversation. Safe to call from `onAppear`; only runs once.
    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        deliverCurrentNode()
    }

    func select(_ option: ConversationOption) {
        guard !isTyping, !isFinished else { return }
        isTyping = true
        currentOptions = []
        messages.append(ChatMessage(text: option.text, sender: .player, timestamp: Date()))
        currentNodeID = option.nextNodeID
        deliverCurrentNode()
    }

    private func deliverCurrentNode() {
        guard let node = nodesByID[currentNodeID] else { return }
        isTyping = true

        // Owned by the view model (not a SwiftUI `.task`), so it survives the
        // view disappearing/backgrounding and the reply is never lost.
        deliveryTask = Task { [weak self] in
            guard let self else { return }
            let delay = Double.random(in: 1...3)
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }

            isTyping = false
            messages.append(ChatMessage(text: node.characterText, sender: .character, timestamp: Date()))

            if node.options.isEmpty {
                isFinished = true
            } else {
                currentOptions = node.options
            }
        }
    }

    deinit {
        deliveryTask?.cancel()
    }
}
