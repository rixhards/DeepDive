//
//  ChatViewModel.swift
//  DeepDive
//

import Foundation
import Observation

@Observable
final class ChatViewModel {
    enum ChatState {
        case loading
        case ready
        case failed(Error)
    }

    private(set) var state: ChatState = .loading
    private(set) var messages: [ChatMessage] = []
    private(set) var currentOptions: [ChatOption] = []
    private(set) var isTyping = false
    private(set) var isFinished = false

    private let engineProvider: () throws -> GameEngine
    private var engine: GameEngine?
    private var deliveryTask: Task<Void, Never>?
    private var hasStarted = false

    init(engineProvider: @escaping () throws -> GameEngine = { try GameEngine(bundle: .main) }) {
        self.engineProvider = engineProvider
    }

    /// Loads the engine and kicks off the conversation. Safe to call from `onAppear`; only runs once.
    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        do {
            let engine = try engineProvider()
            self.engine = engine
            state = .ready
            deliverWithTypingDelay(engine.start())
        } catch {
            state = .failed(error)
        }
    }

    func select(_ option: ChatOption) {
        guard !isTyping, !isFinished, let engine else { return }
        currentOptions = []
        messages.append(ChatMessage(text: option.text, sender: .player, timestamp: Date()))

        do {
            let response = try engine.advance(choosing: option.id)
            deliverWithTypingDelay(response)
        } catch {
            print("GameEngine error advancing conversation: \(error)")
            isFinished = true
        }
    }

    private func deliverWithTypingDelay(_ response: EngineResponse) {
        isTyping = true

        // Owned by the view model (not a SwiftUI `.task`), so it survives the
        // view disappearing/backgrounding and the reply is never lost.
        deliveryTask = Task { [weak self] in
            guard let self else { return }
            let delay = Double.random(in: 1...3)
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }

            isTyping = false
            messages.append(ChatMessage(text: response.characterText, sender: .character, timestamp: Date()))

            if response.isTerminal {
                isFinished = true
            } else {
                currentOptions = response.options.map { ChatOption(id: $0.id, text: $0.text) }
            }
        }
    }

    deinit {
        deliveryTask?.cancel()
    }
}
