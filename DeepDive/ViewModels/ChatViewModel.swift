//
//  ChatViewModel.swift
//  DeepDive
//

import Foundation
import Observation

@Observable
final class ChatViewModel {
    private(set) var messages: [ChatMessage] = []
    private(set) var isTyping = false
    private(set) var isFinished = false
    private(set) var reachedEnding: Ending?

    private let sessionRepository: SessionRepository?
    private let narrator: Narrator
    private let runner: TurnRunner

    private var state = GameState()
    private var memory = StoryMemory.initial()
    private var deliveryTask: Task<Void, Never>?
    private var hasStarted = false
    /// Player messages the ending still swallows in silence before the game closes.
    private var silentTurnsRemaining = 0
    /// The last thing she said, so the narrator can avoid repeating it.
    private var previousReply = ""

    /// Current sanity, for the debug meter only.
    var currentSanity: Int { state.sanity }

    init(
        sessionRepository: SessionRepository? = try? SessionRepository(),
        parser: ActionParser = FoundationModelsActionParser(),
        narrator: Narrator = FoundationModelsNarrator()
    ) {
        self.sessionRepository = sessionRepository
        self.narrator = narrator
        self.runner = TurnRunner(parser: parser)
    }

    /// Loads any saved run and opens the conversation. Safe to call from `onAppear`.
    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        if let saved = sessionRepository?.load(), !saved.state.isFinished {
            state = saved.state
            memory = saved.memory
            messages = saved.messages
            // A restored run is already mid-conversation; she just picks up where she was.
            isTyping = true
            deliveryTask = Task { [weak self] in
                guard let self else { return }
                var resumed = state
                let outcome = runner.arrival(at: state.currentBeat, state: &resumed)
                state = resumed
                await deliver(outcome, delayOverride: 0.5)
            }
            return
        }

        state = GameState()
        memory = StoryMemory.initial()
        isTyping = true
        deliveryTask = Task { [weak self] in
            guard let self else { return }
            var fresh = state
            fresh.visited.removeAll()
            let outcome = runner.arrival(at: fresh.currentBeat, state: &fresh)
            state = fresh
            await deliver(outcome)
        }
    }

    /// Wipes the finished run and starts a fresh one, without relaunching the app.
    func restart() {
        deliveryTask?.cancel()
        deliveryTask = nil
        state = GameState()
        memory = StoryMemory.initial()
        messages = []
        silentTurnsRemaining = 0
        previousReply = ""
        reachedEnding = nil
        isFinished = false
        isTyping = false
        try? sessionRepository?.delete()
        hasStarted = false
        start()
    }

    /// Sends the player's message: the parser extracts an attempted action, the resolver
    /// decides what actually happens, and the narrator says it in her voice.
    func send(_ text: String) {
        guard !isTyping else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let playerText = String(trimmed.prefix(500))

        // She's gone. The message lands in the chat and nothing answers it — no typing
        // indicator, no parser, no resolver. The silence is the ending.
        if silentTurnsRemaining > 0 {
            messages.append(ChatMessage(text: playerText, sender: .player, timestamp: Date()))
            silentTurnsRemaining -= 1
            if silentTurnsRemaining == 0 {
                isFinished = true
                try? sessionRepository?.delete()
            }
            return
        }

        guard !isFinished else { return }

        isTyping = true
        messages.append(ChatMessage(text: playerText, sender: .player, timestamp: Date()))

        deliveryTask = Task { [weak self] in
            guard let self else { return }
            let beatBefore = state.currentBeat
            var mutated = state
            // One message can hold more than one act ("pega a faca e vai pela água").
            let outcomes = await runner.run(playerText: playerText, state: &mutated)
            state = mutated

            // Crossing a beat boundary discards everything derived and rebuilds it from the
            // authoritative state — this is what keeps the LLM context small forever.
            if state.currentBeat != beatBefore {
                memory = StoryMemory.rebuild(from: state, keepingRecent: memory.recentNarrative)
            }

            saveSession()
            var said: [String] = []
            for outcome in outcomes {
                said.append(await deliver(outcome))
                if Task.isCancelled { break }
            }
            memory.noteExchange(playerText: playerText, reply: said.joined(separator: " "))
            saveSession()
        }
    }

    private func saveSession() {
        guard !state.isFinished else { return }
        try? sessionRepository?.save(GameSession(state: state, memory: memory, messages: messages))
    }

    /// Narrates the outcome, waits a typing delay scaled to the text, then appends it —
    /// followed by any beats, each as its own message. Returns everything she said, for
    /// the story memory.
    @discardableResult
    private func deliver(_ outcome: Outcome, delayOverride: Double? = nil) async -> String {
        var everythingSaid: [String] = []
        isTyping = true
        let text = outcome.raw ? outcome.facts.joined(separator: " ") : await narrate(outcome.facts)

        let delay = delayOverride ?? typingDelay(for: text, raw: outcome.raw)
        try? await Task.sleep(for: .seconds(delay))
        guard !Task.isCancelled else { return everythingSaid.joined(separator: " ") }

        isTyping = false
        if !text.isEmpty {
            messages.append(ChatMessage(text: text, sender: .character, timestamp: Date()))
            everythingSaid.append(text)
            previousReply = text
        }

        // A scene that plays itself out: no way for the player to interrupt.
        for beat in outcome.beats {
            isTyping = true
            let beatText = outcome.raw ? beat : await narrate([beat])
            try? await Task.sleep(for: .seconds(typingDelay(for: beatText, raw: outcome.raw)))
            guard !Task.isCancelled else { break }
            isTyping = false
            if !beatText.isEmpty {
                messages.append(ChatMessage(text: beatText, sender: .character, timestamp: Date()))
                everythingSaid.append(beatText)
                previousReply = beatText
            }
        }

        if let ending = state.ending {
            reachedEnding = ending
            // Death keeps the composer alive so the player can shout into the void.
            if outcome.silentTurns > 0 {
                silentTurnsRemaining = outcome.silentTurns
            } else {
                isFinished = true
            }
            try? sessionRepository?.delete()
        }
        return everythingSaid.joined(separator: " ")
    }

    private func narrate(_ facts: [String]) async -> String {
        await narrator.narrate(NarrationRequest(
            facts: facts,
            sanity: state.sanity,
            beat: state.currentBeat,
            beatSummary: WorldMap.beat(state.currentBeat).overview,
            carrying: ItemID.allCases.filter { state.has($0) }.map(\.name),
            memory: memory,
            previousReply: previousReply
        ))
    }

    /// Authored scenes (deaths, the madness, the escape) come through fast and on top of each
    /// other: someone in that much trouble is not composing paragraphs at a measured pace.
    private func typingDelay(for text: String, raw: Bool) -> Double {
        guard !raw else { return max(0.5, min(1.4, Double(text.count) / 90.0)) }
        return max(1.5, min(5.0, Double(text.count) / 40.0))
    }

    deinit {
        deliveryTask?.cancel()
    }
}
