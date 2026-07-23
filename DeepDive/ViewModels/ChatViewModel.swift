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
    private let sessionRepository: SessionRepository?
    private var engine: GameEngine?
    private var deliveryTask: Task<Void, Never>?
    private var hasStarted = false

    init(
        engineProvider: @escaping () throws -> GameEngine = { try GameEngine(bundle: .main) },
        sessionRepository: SessionRepository? = try? SessionRepository()
    ) {
        self.engineProvider = engineProvider
        self.sessionRepository = sessionRepository
    }

    /// Loads the engine (restoring a saved session if one exists) and kicks off the
    /// conversation. Safe to call from `onAppear`; only runs once.
    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        do {
            let engine = try engineProvider()
            self.engine = engine

            if let session = sessionRepository?.load() {
                try engine.restore(EngineState(currentNodeID: session.currentNodeID, flags: session.flags, ints: session.ints))
                messages = session.messages
                state = .ready
                // The save always happens right after `advance()`, before the character's
                // reply for the new node is generated — so a restored session always has a
                // pending reply to catch up on. A short fixed delay reads as "catching up"
                // rather than the normal 1–3 s thinking pause.
                deliverWithTypingDelay(engine.start(), delay: 0.5)
            } else {
                state = .ready
                deliverWithTypingDelay(engine.start())
            }
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
            saveSession(engine: engine)
            deliverWithTypingDelay(response)
        } catch {
            print("GameEngine error advancing conversation: \(error)")
            isFinished = true
        }
    }

    private func saveSession(engine: GameEngine) {
        let state = engine.state
        let session = GameSession(
            currentNodeID: state.currentNodeID,
            flags: state.flags,
            ints: state.ints,
            messages: messages
        )
        try? sessionRepository?.save(session)
    }

    private func deliverWithTypingDelay(_ response: EngineResponse, delay explicitDelay: Double? = nil) {
        isTyping = true

        // Owned by the view model (not a SwiftUI `.task`), so it survives the
        // view disappearing/backgrounding and the reply is never lost.
        deliveryTask = Task { [weak self] in
            guard let self else { return }
            let delay = explicitDelay ?? Double.random(in: 1...3)
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }

            isTyping = false
            messages.append(ChatMessage(text: response.characterText, sender: .character, timestamp: Date()))

            if response.isTerminal {
                isFinished = true
                try? sessionRepository?.delete()
            } else {
                currentOptions = response.options.map { ChatOption(id: $0.id, text: $0.text) }
            }
        }
    }

    deinit {
        deliveryTask?.cancel()
    }
}
