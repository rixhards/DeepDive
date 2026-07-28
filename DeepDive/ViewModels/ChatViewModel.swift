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
    private(set) var isTyping = false
    private(set) var isFinished = false

    private let engineProvider: () throws -> GameEngine
    private let sessionRepository: SessionRepository?
    private let intentParser: IntentParser
    private let narrator: Narrator
    private var engine: GameEngine?
    private var currentEngineOptions: [EngineOption] = []
    private var deliveryTask: Task<Void, Never>?
    private var hasStarted = false
    private var lastClarification: String?
    /// Player messages the current node still swallows in silence before the game ends.
    /// Transient by design — a restore starts the count over.
    private var silentTurnsRemaining = 0

    /// Current sanity, for the debug meter only. Defaults to the story's own starting value
    /// so the meter reads sensibly before the engine has loaded.
    var currentSanity: Int {
        engine?.state.ints["sanity"] ?? 80
    }

    init(
        engineProvider: @escaping () throws -> GameEngine = { try GameEngine(bundle: .main) },
        sessionRepository: SessionRepository? = try? SessionRepository(),
        intentParser: IntentParser = FoundationModelsIntentParser(),
        narrator: Narrator = FoundationModelsNarrator()
    ) {
        self.engineProvider = engineProvider
        self.sessionRepository = sessionRepository
        self.intentParser = intentParser
        self.narrator = narrator
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
                isTyping = true
                // The save always happens right after `advance()`, before the character's
                // reply for the new node is generated — so a restored session always has a
                // pending reply to catch up on. A short fixed delay reads as "catching up"
                // rather than the normal narration-scaled thinking pause.
                deliveryTask = Task { [weak self] in
                    guard let self else { return }
                    await deliver(engine.start(), delayOverride: 0.5)
                }
            } else {
                state = .ready
                isTyping = true
                deliveryTask = Task { [weak self] in
                    guard let self else { return }
                    await deliver(engine.start())
                }
            }
        } catch {
            state = .failed(error)
        }
    }

    /// Sends the player's free-text message: an `IntentParser` maps it to one of the
    /// engine's currently valid options (or asks the character to clarify).
    func send(_ text: String) {
        guard !isTyping, !isFinished, let engine else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let playerText = String(trimmed.prefix(500))

        // She's gone. The message lands in the chat and nothing answers it — no typing
        // indicator, no engine, no parser. The silence is the ending.
        if silentTurnsRemaining > 0 {
            messages.append(ChatMessage(text: playerText, sender: .player, timestamp: Date()))
            silentTurnsRemaining -= 1
            if silentTurnsRemaining == 0 {
                isFinished = true
                try? sessionRepository?.delete()
            }
            return
        }

        isTyping = true
        messages.append(ChatMessage(text: playerText, sender: .player, timestamp: Date()))

        deliveryTask = Task { [weak self] in
            guard let self else { return }
            let result = await intentParser.parse(playerText: playerText, options: currentEngineOptions)

            switch result {
            case .match(let optionID):
                do {
                    let response = try engine.advance(choosing: optionID)
                    saveSession(engine: engine)
                    await deliver(response)
                } catch {
                    print("GameEngine error advancing conversation: \(error)")
                    isTyping = false
                    isFinished = true
                }
            case .clarify:
                saveSession(engine: engine)
                let clarification = ClarificationMessages.random(excluding: lastClarification)
                lastClarification = clarification
                await deliverClarification(clarification)
            }
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

    /// Narrates the response's raw brief, waits a typing delay scaled to the narrated
    /// text's length (or `delayOverride` if given), then appends it as a character message.
    private func deliver(_ response: EngineResponse, delayOverride: Double? = nil) async {
        let narratedText: String
        if response.rawNarration {
            narratedText = response.characterText
        } else {
            narratedText = await narrator.narrate(
                brief: response.characterText,
                sanity: currentSanity,
                history: messages
            )
        }

        let delay = delayOverride ?? typingDelay(for: narratedText)
        try? await Task.sleep(for: .seconds(delay))
        guard !Task.isCancelled else { return }

        isTyping = false
        messages.append(ChatMessage(text: narratedText, sender: .character, timestamp: Date()))
        currentEngineOptions = response.options

        if response.isTerminal {
            // A node with silent turns keeps the composer alive: the player gets to shout
            // into the void a few times before the game admits it's over.
            if response.silentTurns > 0 {
                silentTurnsRemaining = response.silentTurns
            } else {
                isFinished = true
                try? sessionRepository?.delete()
            }
        }
    }

    private func deliverClarification(_ text: String) async {
        let delay = typingDelay(for: text)
        try? await Task.sleep(for: .seconds(delay))
        guard !Task.isCancelled else { return }

        isTyping = false
        messages.append(ChatMessage(text: text, sender: .character, timestamp: Date()))
    }

    private func typingDelay(for text: String) -> Double {
        max(1.5, min(5.0, Double(text.count) / 40.0))
    }

    deinit {
        deliveryTask?.cancel()
    }
}
