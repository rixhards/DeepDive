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
    private let parser: ActionParser
    private let narrator: Narrator
    private let resolver = ActionResolver()

    private var world = World()
    private var deliveryTask: Task<Void, Never>?
    private var hasStarted = false
    /// Player messages the ending still swallows in silence before the game closes.
    private var silentTurnsRemaining = 0

    /// Current sanity, for the debug meter only.
    var currentSanity: Int { world.sanity }

    init(
        sessionRepository: SessionRepository? = try? SessionRepository(),
        parser: ActionParser = FoundationModelsActionParser(),
        narrator: Narrator = FoundationModelsNarrator()
    ) {
        self.sessionRepository = sessionRepository
        self.parser = parser
        self.narrator = narrator
    }

    /// Loads any saved run and opens the conversation. Safe to call from `onAppear`.
    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        if let saved = sessionRepository?.load(), !saved.world.isOver {
            world = saved.world
            messages = saved.messages
            // A restored run is already mid-conversation; she just picks up where she was.
            isTyping = true
            deliveryTask = Task { [weak self] in
                guard let self else { return }
                var resumed = world
                let outcome = resolver.arrival(at: world.place, world: &resumed)
                world = resumed
                await deliver(outcome, delayOverride: 0.5)
            }
            return
        }

        world = World()
        isTyping = true
        deliveryTask = Task { [weak self] in
            guard let self else { return }
            var fresh = world
            fresh.visited.removeAll()
            let outcome = resolver.arrival(at: fresh.place, world: &fresh)
            world = fresh
            await deliver(outcome)
        }
    }

    /// Wipes the finished run and starts a fresh one, without relaunching the app.
    func restart() {
        deliveryTask?.cancel()
        deliveryTask = nil
        world = World()
        messages = []
        silentTurnsRemaining = 0
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
            let action = await parser.parse(playerText: playerText, world: world)
            var mutated = world
            let outcome = resolver.resolve(action, world: &mutated)
            world = mutated
            saveSession()
            await deliver(outcome)
        }
    }

    private func saveSession() {
        guard !world.isOver else { return }
        try? sessionRepository?.save(GameSession(world: world, messages: messages))
    }

    /// Narrates the outcome, waits a typing delay scaled to the text, then appends it —
    /// followed by any beats, each as its own message.
    private func deliver(_ outcome: Outcome, delayOverride: Double? = nil) async {
        let text = outcome.raw ? outcome.facts.joined(separator: " ") : await narrate(outcome.facts)

        let delay = delayOverride ?? typingDelay(for: text)
        try? await Task.sleep(for: .seconds(delay))
        guard !Task.isCancelled else { return }

        isTyping = false
        if !text.isEmpty {
            messages.append(ChatMessage(text: text, sender: .character, timestamp: Date()))
        }

        // A scene that plays itself out: no way for the player to interrupt.
        for beat in outcome.beats {
            isTyping = true
            let beatText = outcome.raw ? beat : await narrate([beat])
            try? await Task.sleep(for: .seconds(typingDelay(for: beatText)))
            guard !Task.isCancelled else { return }
            isTyping = false
            messages.append(ChatMessage(text: beatText, sender: .character, timestamp: Date()))
        }

        if let ending = world.ending {
            reachedEnding = ending
            // The taken ending keeps the composer alive so the player can shout into the void.
            if outcome.silentTurns > 0 {
                silentTurnsRemaining = outcome.silentTurns
            } else {
                isFinished = true
            }
            try? sessionRepository?.delete()
        }
    }

    private func narrate(_ facts: [String]) async -> String {
        await narrator.narrate(NarrationRequest(
            facts: facts,
            sanity: world.sanity,
            placeSummary: WorldMap.place(world.place).overview,
            carrying: ItemID.allCases.filter { world.has($0) }.map(\.name),
            history: messages
        ))
    }

    private func typingDelay(for text: String) -> Double {
        max(1.5, min(5.0, Double(text.count) / 40.0))
    }

    deinit {
        deliveryTask?.cancel()
    }
}
