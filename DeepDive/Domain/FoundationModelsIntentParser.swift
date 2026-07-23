//
//  FoundationModelsIntentParser.swift
//  DeepDive
//
//  Maps free-text player input to one of the GameEngine's currently valid options using
//  Apple's on-device Foundation Models. The engine never sees unvalidated model output —
//  any id the model returns that isn't in `options` is treated as an ambiguous match.

import Foundation
import FoundationModels

@Generable
struct IntentSelection {
    @Guide(description: "The id of the story option that best matches what the player wants to do, or nil if no option clearly matches their message.")
    let optionID: String?
}

struct FoundationModelsIntentParser: IntentParser {
    func parse(playerText: String, options: [EngineOption]) async -> IntentResult {
        guard !options.isEmpty else { return .clarify }

        let availability = SystemLanguageModel.default.availability
        guard availability == .available else {
            print("FoundationModelsIntentParser: model unavailable (\(availability)) — every message will fall back to .clarify. This is expected in the iOS Simulator (no on-device model asset); needs a real device with Apple Intelligence enabled to actually match intent.")
            return .clarify
        }

        let optionsList = options
            .map { "- id: \"\($0.id)\", text: \"\($0.text)\"" }
            .joined(separator: "\n")

        let instructions = """
        Você está mapeando a mensagem de um jogador para uma das opções narrativas disponíveis \
        em um jogo de chat. Responda apenas com o id da opção que melhor corresponde à intenção \
        do jogador, ou nil se nenhuma opção corresponder claramente. Nunca invente um id que não \
        esteja na lista abaixo.

        Opções disponíveis:
        \(optionsList)
        """

        let session = LanguageModelSession(instructions: instructions)

        do {
            let response = try await session.respond(to: playerText, generating: IntentSelection.self)
            let rawID = response.content.optionID?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard
                let rawID, !rawID.isEmpty,
                let matched = options.first(where: { $0.id.caseInsensitiveCompare(rawID) == .orderedSame })
            else {
                print("FoundationModelsIntentParser: no confident match for \"\(playerText)\" — model returned \(response.content.optionID.map { "\"\($0)\"" } ?? "nil")")
                return .clarify
            }
            return .match(optionID: matched.id)
        } catch {
            print("FoundationModelsIntentParser: generation failed for \"\(playerText)\": \(error)")
            return .clarify
        }
    }
}
