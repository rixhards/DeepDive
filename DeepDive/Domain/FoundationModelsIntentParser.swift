//
//  FoundationModelsIntentParser.swift
//  DeepDive
//
//  Maps free-text player input to one of the GameEngine's currently valid options.
//  Three tiers, cheapest/most reliable first:
//   1. A single valid option means there's no real ambiguity to protect against —
//      match it directly.
//   2. HeuristicIntentMatcher (word-overlap against text + hints, no AI) — handles
//      divergent-but-related phrasing deterministically.
//   3. Foundation Models, for genuinely open-ended interpretation. The engine never
//      sees unvalidated model output — any id the model returns that isn't in
//      `options` is treated as an ambiguous match.

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

        // With a single path forward there's no real ambiguity to protect against —
        // stalling the conversation here costs more than it protects.
        if options.count == 1 {
            return .match(optionID: options[0].id)
        }

        if let heuristicID = HeuristicIntentMatcher.bestMatch(for: playerText, among: options) {
            return .match(optionID: heuristicID)
        }

        let availability = SystemLanguageModel.default.availability
        guard availability == .available else {
            print("FoundationModelsIntentParser: model unavailable (\(availability)) — every message will fall back to .clarify. This is expected in the iOS Simulator (no on-device model asset); needs a real device with Apple Intelligence enabled to actually match intent.")
            return .clarify
        }

        let optionsList = options
            .map { option -> String in
                let hintsText = option.hints.isEmpty ? "" : " (também pode ser dito como: \(option.hints.joined(separator: "; ")))"
                return "- id: \"\(option.id)\", text: \"\(option.text)\"\(hintsText)"
            }
            .joined(separator: "\n")

        let instructions = """
        Você está mapeando a mensagem de um jogador para uma das opções narrativas disponíveis \
        em um jogo de chat de terror. O jogador escreve com as próprias palavras — não espere \
        que ele repita o texto da opção.

        Existem dois eixos diferentes, não confunda os dois:
        1. FRASEADO diferente da opção (ok, aceite): o jogador pode usar palavras totalmente \
           diferentes pra dizer a MESMA coisa. "cadê vc" e "onde você está?" são o mesmo pedido.
        2. ASSUNTO diferente da opção (não aceite, responda nil): a mensagem do jogador tem que \
           ser sobre o mesmo tópico/ação de alguma opção. Se ele disser algo que não tem relação \
           de conteúdo com nenhuma opção — mesmo que pareça relacionado ao clima geral da cena —, \
           é nil. Não tente adivinhar uma conexão indireta ou temática; a relação tem que ser \
           direta.

        Ignore diferenças de pontuação (ex.: "?" no final pode estar ausente) — isso nunca deve \
        influenciar o resultado. Nunca invente um id que não esteja na lista abaixo.

        Exemplo 1 (fraseado diferente, MESMO assunto → aceite): opções [{id: "opt_a", text: \
        "quem é você?"}, {id: "opt_b", text: "onde você está?"}], jogador manda "cadê vc" → \
        responda "opt_b" (mesmo pedido de localização, só com outras palavras).

        Exemplo 2 (assunto diferente → nil): opções [{id: "opt_exit", text: "tem alguma saída \
        perto?"}, {id: "opt_who_else", text: "tem mais alguém com você?"}], jogador manda \
        "corre" → responda nil. "Corre" não pergunta sobre saída nem sobre outras pessoas — é \
        uma instrução vaga que não corresponde diretamente a nenhuma das duas opções, mesmo \
        estando no mesmo clima de urgência.

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
