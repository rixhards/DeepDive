//
//  FoundationModelsActionParser.swift
//  DeepDive
//
//  Extracts a verb and a target from the player's free text. It never decides whether the
//  action succeeds — that belongs to ActionResolver (ADR-002).
//
//  Two tiers: LocalActionParser handles common phrasings deterministically (and keeps the
//  game playable without Apple Intelligence), the model handles everything else.

import Foundation
import FoundationModels

@Generable
struct InterpretedAction {
    @Guide(description: """
    The verb that best matches what the player wants the character to do. Use "look" for taking \
    in the whole place, "examine" for looking closely at one specific thing, "take" for picking \
    something up, "use" for touching/knocking/opening/cutting/burning/lighting, "go" for moving \
    somewhere, "wait" for deliberately doing nothing, "talk" for asking how she is or reassuring \
    her, "inventory" for asking what she is carrying, and "unknown" when nothing fits.
    """)
    var verb: String

    @Guide(description: """
    The thing the action is aimed at, in the player's own words, without articles. For example \
    "porta de ferro", "feno", "pilares". Leave empty when the action has no specific target.
    """)
    var target: String

    @Guide(description: """
    The item the character should act WITH, when the player names one — for example "faca" in \
    "corta o feno com a faca". Leave empty when no item is named.
    """)
    var instrument: String

    @Guide(description: "True when the player's message is hostile, cruel, or insulting toward the character.")
    var isHostile: Bool
}

struct FoundationModelsActionParser: ActionParser {

    func parse(playerText: String, world: World) async -> PlayerAction {
        if let local = LocalActionParser.parse(playerText, world: world) {
            return local
        }

        let availability = SystemLanguageModel.default.availability
        guard availability == .available else {
            print("FoundationModelsActionParser: model unavailable (\(availability)) — falling back to .unknown. Expected in the Simulator; needs a real device with Apple Intelligence.")
            return PlayerAction(verb: .unknown)
        }

        let place = WorldMap.place(world.place)
        let visible = place.features.flatMap(\.aliases).prefix(24).joined(separator: ", ")
        let exits = place.exits.flatMap(\.aliases).prefix(16).joined(separator: ", ")
        let carried = ItemID.allCases.filter { world.has($0) }.map(\.name).joined(separator: ", ")

        let instructions = """
        Você interpreta o que um jogador quer que uma personagem faça, num jogo de terror \
        narrativo em português do Brasil. O jogador escreve com as próprias palavras.

        Extraia SOMENTE a tentativa: o verbo e o alvo. Nunca decida se a ação dá certo, nunca \
        invente resultado, nunca mude o estado do jogo, e nunca assuma que a personagem tem um \
        item que ela não tem.

        Prefira uma interpretação razoável a responder "unknown". Só use "unknown" quando a \
        mensagem realmente não descrever nenhuma ação.

        O alvo deve ser escrito com as palavras do jogador, sem artigo. Se o jogador nomear um \
        item pra usar (\"corta o feno com a faca\"), o alvo é \"feno\" e o instrumento é \"faca\".

        Contexto atual (só pra você reconhecer os alvos — não repita isso na resposta):
        - Lugar: \(place.overview)
        - Coisas visíveis: \(visible)
        - Saídas: \(exits)
        - A personagem carrega: \(carried.isEmpty ? "nada" : carried)
        """

        let session = LanguageModelSession(instructions: instructions)

        do {
            let response = try await session.respond(to: playerText, generating: InterpretedAction.self)
            let content = response.content
            let verb = Verb(rawValue: content.verb.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) ?? .unknown
            return PlayerAction(
                verb: verb,
                target: content.target.isEmpty ? nil : content.target,
                instrument: content.instrument.isEmpty ? nil : content.instrument,
                isHostile: content.isHostile
            )
        } catch {
            print("FoundationModelsActionParser: generation failed for \"\(playerText)\": \(error)")
            return PlayerAction(verb: .unknown)
        }
    }
}
