//
//  FoundationModelsNarrator.swift
//  DeepDive
//
//  Rewrites a story node's raw JSON text (the "brief") into in-character WhatsApp-style
//  prose, with tone shaped by the current sanity/trust state. Never invents plot facts —
//  the brief is the only source of narrative truth; this only changes how it's said.

import Foundation
import FoundationModels

struct FoundationModelsNarrator: Narrator {
    private let timeoutSeconds: Double = 8

    func narrate(brief: String, sanity: Int, trust: Int, history: [ChatMessage]) async -> String {
        let availability = SystemLanguageModel.default.availability
        guard availability == .available else {
            print("FoundationModelsNarrator: model unavailable (\(availability)) — falling back to the raw brief. Expected in the iOS Simulator; needs a real device with Apple Intelligence enabled.")
            return brief
        }

        let transcript = history.suffix(20)
            .map { "\($0.sender == .player ? "jogador" : "personagem"): \($0.text)" }
            .joined(separator: "\n")

        let instructions = """
        Você é uma pessoa anônima presa em uma cidade fora do tempo, se comunicando com um \
        estranho via WhatsApp. Seu estado emocional atual: sanidade \(sanity)/100, confiança no \
        jogador \(trust)/100.

        Tom por sanidade: alta sanidade = mensagens coerentes e descritivas; baixa sanidade = \
        fragmentadas, erráticas, assustadas.
        Tom por confiança: alta confiança = pessoal, vulnerável, depende do jogador; baixa \
        confiança = na defensiva, seca, desconfiada.

        Reescreva o texto a seguir (o que você precisa comunicar) como 1 a 3 mensagens curtas de \
        WhatsApp em português brasileiro, em primeira pessoa, separadas por quebra de linha, \
        nunca ultrapassando 300 caracteres no total. Não invente fatos novos da história além do \
        que está descrito. Não use aspas nem prefixos como "personagem:".

        Histórico recente da conversa:
        \(transcript)
        """

        let session = LanguageModelSession(instructions: instructions)

        let narrated = await withTimeout(seconds: timeoutSeconds) {
            try await session.respond(to: brief).content
        }

        guard
            let narrated,
            case let trimmed = narrated.trimmingCharacters(in: .whitespacesAndNewlines),
            !trimmed.isEmpty
        else {
            return brief
        }
        return String(trimmed.prefix(300))
    }

    private func withTimeout<T: Sendable>(seconds: Double, operation: @escaping @Sendable () async throws -> T) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask {
                try? await operation()
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(seconds))
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }
}
