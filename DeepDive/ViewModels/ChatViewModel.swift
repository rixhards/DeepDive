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
    /// The revision of the save this view model is working from. When the store comes back with
    /// a higher one, something else — an App Intent — took a turn while we weren't looking.
    private var revision = 0
    private var deliveryTask: Task<Void, Never>?
    /// Ends a death that the player never answers, so the reveal isn't gated on typing.
    private var endingGraceTask: Task<Void, Never>?
    /// Invalidates work in flight. Cancellation is cooperative and a model call may not check
    /// it, so a task that outlives a restart must be stopped from writing by identity, not by
    /// hoping it noticed (spec 014).
    private var runToken = UUID()
    private var hasStarted = false
    /// Player messages the ending still swallows in silence before the game closes.
    private var silentTurnsRemaining = 0
    /// The last few things she said, oldest first, so the narrator can avoid repeating them.
    /// One entry was not enough: during the opening the model echoed whole messages from two
    /// turns back, which sailed past a filter that only knew the immediately previous reply.
    private var recentReplies: [String] = []

    /// Current sanity. Never shown as a number (spec 010 removed the HUD) — the view reads
    /// the derived values below instead.
    var currentSanity: Int { state.sanity }

    // MARK: - Environmental degradation (spec 010)
    //
    // Sanity is communicated by how the screen feels, not by a meter. Every value here is
    // derived from `state.sanity` — no new state — and interpolates continuously, so the
    // player never catches a step at a threshold and reads it as a gauge.

    /// How closed the vignette is, 0 (barely there) → 1 (pressing in).
    var vignetteIntensity: Double {
        Self.interpolate(sanity: state.sanity, stops: [(100, 0.06), (80, 0.16), (40, 0.46), (0, 0.86)])
    }

    /// Her bubbles lose contrast as she does. The player's never change — the player is fine.
    var characterBubbleOpacity: Double {
        Self.interpolate(sanity: state.sanity, stops: [(100, 1.0), (80, 1.0), (40, 0.85), (0, 0.72)])
    }

    /// Below 40 her words start drifting apart on the line.
    var characterTracking: Double {
        Self.interpolate(sanity: state.sanity, stops: [(100, 0), (40, 0), (0, 0.9)])
    }

    /// A cold cast over everything, only in the bottom band.
    var coldVeilOpacity: Double {
        Self.interpolate(sanity: state.sanity, stops: [(100, 0), (40, 0), (0, 0.20)])
    }

    /// Linear interpolation across sanity stops, highest sanity first. Values outside the
    /// range clamp to the nearest stop.
    private static func interpolate(sanity: Int, stops: [(sanity: Int, value: Double)]) -> Double {
        let sanity = min(max(sanity, 0), 100)
        guard let first = stops.first, let last = stops.last else { return 0 }
        if sanity >= first.sanity { return first.value }
        if sanity <= last.sanity { return last.value }

        for (upper, lower) in zip(stops, stops.dropFirst()) where sanity <= upper.sanity && sanity >= lower.sanity {
            let span = Double(upper.sanity - lower.sanity)
            guard span > 0 else { return lower.value }
            let progress = Double(sanity - lower.sanity) / span
            return lower.value + (upper.value - lower.value) * progress
        }
        return last.value
    }

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
        runToken = UUID()
        let token = runToken

        if let saved = sessionRepository?.load(), !saved.state.isFinished {
            state = saved.state
            memory = saved.memory
            messages = saved.messages
            revision = saved.revision
            // A restored run is already mid-conversation; she just picks up where she was.
            isTyping = true
            deliveryTask = Task { [weak self] in
                guard let self else { return }
                var resumed = state
                let outcome = runner.arrival(at: state.currentBeat, state: &resumed)
                guard token == runToken else { return }
                state = resumed
                await deliver(outcome, token: token, delayOverride: 0.5)

                // A question she was standing at the edge of is saved with everything else. She
                // has to ask it again — otherwise the next "sim" confirms something the player
                // never read, and that something is usually a death (spec 014).
                // Verbatim: this exact line came back from the model as "quero entrar. só não
                // sei se vai ser seguro." — an inversion that states her wish and drops the
                // question she is waiting on (spec 015).
                guard token == runToken, let pending = state.pending else { return }
                await deliver(Outcome(pending.reminder, delivery: .verbatim), token: token)
            }
            return
        }

        state = GameState()
        memory = StoryMemory.initial()
        revision = 0
        isTyping = true
        deliveryTask = Task { [weak self] in
            guard let self else { return }
            var fresh = state
            fresh.visited.removeAll()
            let outcome = runner.arrival(at: fresh.currentBeat, state: &fresh)
            guard token == runToken else { return }
            state = fresh
            await deliver(outcome, token: token)
            // The run exists the moment she has spoken. Before this the save was only written on
            // the player's first message, so a freshly installed game had nothing for an App
            // Intent to talk to and no "continuar" in the menu (spec 014).
            guard token == runToken else { return }
            saveSession()
        }
    }

    /// Wipes the finished run and starts a fresh one, without relaunching the app.
    func restart() {
        // New identity first: anything still in flight is now writing for a run that is over.
        runToken = UUID()
        deliveryTask?.cancel()
        deliveryTask = nil
        endingGraceTask?.cancel()
        endingGraceTask = nil
        state = GameState()
        memory = StoryMemory.initial()
        messages = []
        revision = 0
        silentTurnsRemaining = 0
        recentReplies.removeAll()
        reachedEnding = nil
        isFinished = false
        isTyping = false
        try? sessionRepository?.delete()
        hasStarted = false
        start()
    }

    /// Called when the app comes back to the foreground. If an App Intent took a turn while we
    /// were away, the store is ahead of us — adopt it, and let the messages she wrote in the
    /// meantime *arrive* rather than appearing spliced into the history (spec 014).
    func refreshFromDisk() {
        // A death waiting on the player resumes its clock here, so time spent in another app
        // never costs someone the ending screen.
        if silentTurnsRemaining > 0 {
            startEndingGrace()
            return
        }
        guard hasStarted, !isFinished, !isTyping else { return }
        adoptStoreIfAhead(deliveringNewMessages: true)
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
            if silentTurnsRemaining == 0 { finishRun() } else { startEndingGrace() }
            return
        }

        guard !isFinished else { return }

        // An App Intent may have taken a turn while the app was on screen. Catch up before
        // adding to the history — quietly, because the player is mid-conversation here and a
        // staged delivery would read as lag rather than as her writing (spec 014).
        adoptStoreIfAhead(deliveringNewMessages: false)

        isTyping = true
        messages.append(ChatMessage(text: playerText, sender: .player, timestamp: Date()))

        let token = runToken
        deliveryTask = Task { [weak self] in
            guard let self else { return }
            let beatBefore = state.currentBeat
            var mutated = state
            // One message can hold more than one act ("pega a faca e vai pela água").
            let outcomes = await runner.run(playerText: playerText, state: &mutated)
            // The run may have been restarted while the parser was thinking. Adopting `mutated`
            // here used to resurrect the abandoned run and persist it over the new one.
            guard token == runToken, !Task.isCancelled else { return }
            state = mutated

            // Crossing a beat boundary discards everything derived and rebuilds it from the
            // authoritative state — this is what keeps the LLM context small forever.
            if state.currentBeat != beatBefore {
                memory = StoryMemory.rebuild(from: state, keepingRecent: memory.recentNarrative)
            }

            saveSession()
            var said: [String] = []
            for outcome in outcomes {
                said.append(await deliver(outcome, token: token))
                guard token == runToken, !Task.isCancelled else { return }
            }
            memory.noteExchange(playerText: playerText, reply: said.joined(separator: " "))
            saveSession()
        }
    }

    // MARK: - The store is the source of truth for a turn (spec 014)

    /// Takes on whatever the store holds when it is ahead of us. `deliveringNewMessages` decides
    /// whether the messages that arrived meanwhile are staged like a real delivery or simply
    /// adopted — staging is for coming back to the app, where it reads as her writing to you.
    private func adoptStoreIfAhead(deliveringNewMessages: Bool) {
        guard let saved = sessionRepository?.load(), saved.revision > revision else { return }

        let alreadyShown = Set(messages.map(\.id))
        let arrived = saved.messages.filter { !alreadyShown.contains($0.id) }

        state = saved.state
        memory = saved.memory
        revision = saved.revision

        guard deliveringNewMessages, !arrived.isEmpty else {
            messages = saved.messages
            return
        }
        messages = saved.messages.filter { alreadyShown.contains($0.id) }
        deliverArrived(arrived)
    }

    /// Plays messages written by an App Intent as if they were landing now.
    private func deliverArrived(_ arrived: [ChatMessage]) {
        let token = runToken
        isTyping = true
        deliveryTask = Task { [weak self] in
            guard let self else { return }
            for message in arrived {
                // What the player said through Siri is already said — only her side gets the
                // typing theatre.
                guard message.sender == .character else {
                    messages.append(message)
                    continue
                }
                isTyping = true
                try? await Task.sleep(for: .seconds(typingDelay(for: message.text, urgent: false)))
                guard token == runToken, !Task.isCancelled else { return }
                isTyping = false
                messages.append(message)
                remember(message.text)
            }
            isTyping = false
        }
    }

    private func saveSession() {
        guard !state.isFinished else { return }
        guard let sessionRepository else { return }
        let session = GameSession(state: state, memory: memory, messages: messages, revision: revision)
        if let stamped = try? sessionRepository.save(session) { revision = stamped }
    }

    // MARK: - Ending

    /// How long a death waits for the player before it closes on its own.
    private static let endingGraceSeconds: Double = 15

    /// The silence after a death is the ending — but it has to end. Before this, a player who
    /// stopped typing never reached the reveal, and the save was already gone (spec 014).
    private func startEndingGrace() {
        endingGraceTask?.cancel()
        let token = runToken
        endingGraceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.endingGraceSeconds))
            guard let self, token == runToken, !Task.isCancelled else { return }
            guard silentTurnsRemaining > 0 else { return }
            silentTurnsRemaining = 0
            finishRun()
        }
    }

    private func finishRun() {
        endingGraceTask?.cancel()
        endingGraceTask = nil
        isFinished = true
        try? sessionRepository?.delete()
    }

    /// Narrates the outcome, waits a typing delay scaled to the text, then appends it —
    /// followed by any beats, each as its own message. Returns everything she said, for
    /// the story memory.
    @discardableResult
    private func deliver(_ outcome: Outcome, token: UUID, delayOverride: Double? = nil) async -> String {
        var everythingSaid: [String] = []
        isTyping = true
        let text = outcome.delivery.skipsNarrator
            ? outcome.facts.joined(separator: " ")
            : await narrate(outcome.facts)

        let delay = delayOverride ?? typingDelay(for: text, urgent: outcome.delivery.isUrgent)
        try? await Task.sleep(for: .seconds(delay))
        guard token == runToken, !Task.isCancelled else { return everythingSaid.joined(separator: " ") }

        isTyping = false
        if !text.isEmpty {
            messages.append(ChatMessage(text: text, sender: .character, timestamp: Date()))
            everythingSaid.append(text)
            remember(text)
        }

        // A scene that plays itself out: no way for the player to interrupt.
        for beat in outcome.beats {
            isTyping = true
            let beatText = outcome.delivery.skipsNarrator ? beat : await narrate([beat])
            try? await Task.sleep(for: .seconds(typingDelay(for: beatText, urgent: outcome.delivery.isUrgent)))
            guard token == runToken, !Task.isCancelled else { break }
            isTyping = false
            if !beatText.isEmpty {
                messages.append(ChatMessage(text: beatText, sender: .character, timestamp: Date()))
                everythingSaid.append(beatText)
                remember(beatText)
            }
        }

        if let ending = state.ending {
            reachedEnding = ending
            // Death keeps the composer alive so the player can shout into the void — and now
            // starts a clock, so the reveal isn't gated on them typing (spec 014).
            if outcome.silentTurns > 0 {
                silentTurnsRemaining = outcome.silentTurns
                startEndingGrace()
                try? sessionRepository?.delete()
            } else {
                finishRun()
            }
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
            recentReplies: recentReplies
        ))
    }

    /// Keeps the dedup window at a fixed size, dropping the oldest reply as new ones land.
    private func remember(_ reply: String) {
        recentReplies.append(reply)
        if recentReplies.count > NarrationRequest.repeatWindow {
            recentReplies.removeFirst(recentReplies.count - NarrationRequest.repeatWindow)
        }
    }

    /// Authored scenes (deaths, the madness, the escape) come through fast and on top of each
    /// other: someone in that much trouble is not composing paragraphs at a measured pace.
    ///
    /// Pace follows `Delivery.isUrgent`, not "was it narrated" — a room description that skips
    /// the narrator is still a room description and must not arrive at the speed of a drowning
    /// (spec 015).
    private func typingDelay(for text: String, urgent: Bool) -> Double {
        guard !urgent else { return max(0.5, min(1.4, Double(text.count) / 90.0)) }
        return max(1.5, min(5.0, Double(text.count) / 40.0))
    }

    deinit {
        deliveryTask?.cancel()
    }
}
