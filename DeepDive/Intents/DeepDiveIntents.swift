//
//  DeepDiveIntents.swift
//  DeepDive
//
//  App Intents are part of the design, not a checkbox (ARCHITECTURE.md): they let Siri and
//  Shortcuts carry the conversation while the app is closed. Three intents:
//
//  1. `MessageHerIntent`        — say something to her and get her reply (a real game turn).
//  2. `CheckOnHerIntent`        — how is she doing? Reads state, consumes no turn.
//  3. `SpontaneousMessageIntent`— she writes first. Pair it with a Shortcuts automation at a
//                                 random hour and a "Show Notification" action, and she
//                                 messages the player out of nowhere.
//
//  In-app App Intents execute inside the app's own process (launched in the background when
//  needed), so the SwiftData store *is* the shared state — nothing extra to sync.
//
//  Turns run through the exact same pipeline as the chat: TurnRunner → parser → resolver →
//  narrator. There is no second set of rules here.

import AppIntents
import Foundation

/// One headless game turn, shared by every entry point that has no UI.
enum GameTurnService {

    /// Runs the player's message against the saved run and returns everything she says.
    static func run(playerText: String) async -> String {
        let trimmed = String(playerText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        guard !trimmed.isEmpty else { return WorldMap.intentNoActiveRun }

        guard let repository = try? SessionRepository(),
              let saved = repository.load(),
              !saved.state.isFinished else {
            // No run to talk to: the silence is in character.
            return WorldMap.intentNoActiveRun
        }

        var state = saved.state
        var memory = saved.memory
        var messages = saved.messages
        messages.append(ChatMessage(text: trimmed, sender: .player, timestamp: Date()))

        let runner = TurnRunner(parser: FoundationModelsActionParser())
        let outcomes = await runner.run(playerText: trimmed, state: &state)

        if state.currentBeat != saved.state.currentBeat {
            memory = StoryMemory.rebuild(from: state, keepingRecent: memory.recentNarrative)
        }

        // Same delivery as the chat, minus the typing theatre.
        let narrator = FoundationModelsNarrator()
        var lines: [String] = []
        for outcome in outcomes {
            guard !outcome.raw else {
                // Authored climaxes go out exactly as written.
                lines.append(contentsOf: outcome.allTexts.filter { !$0.isEmpty })
                continue
            }
            for chunk in outcome.narratableChunks {
                let narrated = await narrator.narrate(NarrationRequest(
                    facts: chunk,
                    sanity: state.sanity,
                    beat: state.currentBeat,
                    beatSummary: WorldMap.beat(state.currentBeat).overview,
                    carrying: ItemID.allCases.filter { state.has($0) }.map(\.name),
                    memory: memory,
                    previousReply: lines.last ?? ""
                ))
                if !narrated.isEmpty { lines.append(narrated) }
            }
        }

        for line in lines {
            messages.append(ChatMessage(text: line, sender: .character, timestamp: Date()))
        }
        let reply = lines.joined(separator: "\n")
        memory.noteExchange(playerText: trimmed, reply: reply)

        if state.isFinished {
            // Same contract as the app: a finished run doesn't resume.
            try? repository.delete()
        } else {
            try? repository.save(GameSession(state: state, memory: memory, messages: messages))
        }

        return reply.isEmpty ? WorldMap.intentNoActiveRun : reply
    }

    /// A message she sends on her own, with no player input. Authored lines only — this can
    /// fire at any hour with the app closed, so it must never depend on the model.
    static func spontaneousMessage() async -> String {
        guard let repository = try? SessionRepository(),
              let saved = repository.load(),
              !saved.state.isFinished else {
            return WorldMap.intentNoActiveRun
        }

        var state = saved.state
        let line = WorldMap.unpromptedMessage(for: state)

        var messages = saved.messages
        messages.append(ChatMessage(text: line, sender: .character, timestamp: Date()))

        // Being left alone in the dark costs her something, which is the point of the feature.
        state.adjustSanity(by: -2)
        var memory = saved.memory
        memory.noteExchange(playerText: "(silêncio)", reply: line)

        if state.isFinished {
            try? repository.delete()
        } else {
            try? repository.save(GameSession(state: state, memory: memory, messages: messages))
        }
        return line
    }

    /// A read-only status line. Consumes no turn and never mutates the run.
    nonisolated static func status() -> String {
        guard let repository = try? SessionRepository(),
              let saved = repository.load(),
              !saved.state.isFinished else {
            return WorldMap.intentNoActiveRun
        }
        return WorldMap.statusLine(for: saved.state)
    }
}

// MARK: - Intents

struct MessageHerIntent: AppIntent {
    static let title: LocalizedStringResource = "Mandar mensagem pra ela"
    static let description = IntentDescription(
        "Manda uma mensagem pra mulher presa na cidade e espera a resposta dela.",
        categoryName: "Conversa"
    )

    @Parameter(title: "Mensagem", requestValueDialog: "O que você quer dizer pra ela?")
    var message: String

    static var parameterSummary: some ParameterSummary {
        Summary("Dizer \(\.$message) pra ela")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let reply = await GameTurnService.run(playerText: message)
        return .result(value: reply, dialog: IntentDialog(stringLiteral: reply))
    }
}

struct CheckOnHerIntent: AppIntent {
    static let title: LocalizedStringResource = "Ver como ela está"
    static let description = IntentDescription(
        "Conta onde ela está, o que ela carrega e como ela está aguentando. Não gasta uma jogada.",
        categoryName: "Conversa"
    )

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let status = GameTurnService.status()
        return .result(value: status, dialog: IntentDialog(stringLiteral: status))
    }
}

struct SpontaneousMessageIntent: AppIntent {
    static let title: LocalizedStringResource = "Receber mensagem dela"
    static let description = IntentDescription(
        """
        Devolve uma mensagem que ela mandou sozinha, sem você ter falado nada. \
        Use numa automação de Atalhos em horário aleatório, junto de "Exibir notificação", \
        pra ela te procurar do nada.
        """,
        categoryName: "Conversa"
    )

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let line = await GameTurnService.spontaneousMessage()
        return .result(value: line, dialog: IntentDialog(stringLiteral: line))
    }
}

// MARK: - Shortcuts registration (no manual setup for the player)

struct DeepDiveShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: MessageHerIntent(),
            phrases: [
                "Mandar mensagem no \(.applicationName)",
                "Falar com ela no \(.applicationName)",
                "Responder ela no \(.applicationName)",
            ],
            shortTitle: "Mandar mensagem",
            systemImageName: "message.fill"
        )
        AppShortcut(
            intent: CheckOnHerIntent(),
            phrases: [
                "Como ela está no \(.applicationName)",
                "Ver como ela está no \(.applicationName)",
            ],
            shortTitle: "Como ela está",
            systemImageName: "heart.text.square"
        )
        AppShortcut(
            intent: SpontaneousMessageIntent(),
            phrases: [
                "Mensagem dela no \(.applicationName)",
                "Ela falou alguma coisa no \(.applicationName)",
            ],
            shortTitle: "Mensagem dela",
            systemImageName: "bell.badge"
        )
    }
}
