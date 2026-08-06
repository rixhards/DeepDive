//
//  FoundationModelsActionParser.swift
//  DeepDive
//
//  Extracts a verb, a target and a tone from the player's free text. It never decides
//  whether the action succeeds — that belongs to ActionResolver (ADR-002).
//
//  Two tiers: LocalActionParser handles common phrasings deterministically (and keeps the
//  game playable without Apple Intelligence), the model handles everything else.
//
//  Context note: each parse gets a fresh, tiny session — instructions plus one line of
//  player text — so the parser never accumulates transcript and can't hit the 4096-token
//  window. The narrator is the one that needs beat-boundary session management.

import Foundation
import FoundationModels

@Generable
struct InterpretedAction {
    @Guide(description: """
    O verbo que melhor descreve o que o jogador quer que a personagem faça. Responda com \
    exatamente uma destas palavras, em inglês:
    "look" — abranger o lugar todo ("olha em volta", "o que você tá vendo?").
    "examine" — olhar de perto uma coisa específica ("olha pro teto").
    "search" — remexer, vasculhar, procurar dentro de algo ("revira o feno", "procura uma saída").
    "take" — pegar/recolher um objeto.
    "use" — abrir, empurrar, cortar, forçar, acender, apagar, destrancar.
    "touch" — encostar a mão de propósito ("toca na água", "passa a mão na parede").
    "knock" — bater numa porta.
    "burn" — botar fogo em alguma coisa.
    "go" — se deslocar para outro lugar.
    "wait" — deliberadamente não fazer nada.
    "talk" — perguntar como ela está, confortar, tranquilizar.
    "greet" — cumprimentar ou só reconhecer ("oi", "ok", "beleza", "entendi").
    "ask" — perguntar sobre ela, sobre o que aconteceu, ou o que fazer agora.
    "inventory" — perguntar o que ela está carregando.
    "listen" — prestar atenção nos sons.
    "smell" — sentir o cheiro do lugar.
    "shout" — gritar, chamar alguém em voz alta.
    "hide" — se esconder.
    "rest" — sentar, descansar, recuperar o fôlego.
    "yes" — CONFIRMAR uma pergunta que ela acabou de fazer ("sim", "pode ir", "manda").
    "no" — RECUSAR uma pergunta que ela acabou de fazer ("não", "melhor não", "deixa pra lá").
    "unknown" — só quando nada acima serve.
    """)
    var verb: String

    @Guide(description: """
    The thing the action is aimed at, in the player's own words, without articles. For example \
    "porta de aço", "feno", "pilares". Leave empty when the action has no specific target.
    """)
    var target: String

    @Guide(description: """
    The item the character should act WITH, but ONLY when the player literally wrote the item's \
    name in their message — for example "faca" in "corta o feno com a faca". Leave this EMPTY \
    whenever the player did not name an item. Never fill it in with something she happens to be \
    carrying, and never guess which tool would be useful.
    """)
    var instrument: String

    @Guide(description: """
    The emotional tone of the player's message toward the character. \
    Use "supportive" for encouragement, comfort, reassurance, or positive words. \
    Use "distressing" for hostile, cruel, insulting, dismissive, or dark messages. \
    Use "neutral" for instructions, questions, or anything that is neither supportive nor distressing.
    """)
    var tone: String
}

struct FoundationModelsActionParser: ActionParser {

    /// Words that have to be present before the model is allowed to relocate her.
    private static let movementWords = [
        "vai", "va", "anda", "ande", "caminha", "segue", "siga", "entra", "entre", "atravessa",
        "sobe", "suba", "desce", "desca", "volta", "volte", "retorna", "sai", "saia", "avanca",
        "avance", "corre", "corra", "foge", "fuja", "prossegue", "frente", "adiante", "explora",
        "explore", "continua", "continue", "leva", "ir", "vamos", "segui", "passa", "passe",
    ]

    private static func mentionsMovement(_ foldedText: String) -> Bool {
        let padded = " \(foldedText) "
        return movementWords.contains { padded.contains(" \($0) ") }
    }

    func parse(playerText: String, state: GameState) async -> PlayerAction {
        if let local = LocalActionParser.parse(playerText, state: state) {
            return local
        }

        let availability = SystemLanguageModel.default.availability
        guard availability == .available else {
            print("FoundationModelsActionParser: model unavailable (\(availability)) — falling back to .unknown. Expected in the Simulator; needs a real device with Apple Intelligence.")
            return PlayerAction(verb: .unknown)
        }

        let beat = WorldMap.beat(state.currentBeat)
        let visible = beat.features.flatMap(\.aliases).prefix(24).joined(separator: ", ")
        let exits = beat.exits.flatMap(\.aliases).prefix(16).joined(separator: ", ")
        let carried = ItemID.allCases.filter { state.has($0) }.map(\.name).joined(separator: ", ")

        let instructions = """
        Você interpreta o que um jogador quer que uma personagem faça, num jogo de terror \
        narrativo em português do Brasil. O jogador escreve com as próprias palavras.

        Extraia SOMENTE a tentativa: o verbo, o alvo e o tom. Nunca decida se a ação dá certo, \
        nunca invente resultado, nunca mude o estado do jogo, e nunca assuma que a personagem \
        tem um item que ela não tem.

        Prefira uma interpretação razoável a responder "unknown". Só use "unknown" quando a \
        mensagem realmente não descrever nenhuma ação.

        O alvo deve ser escrito com as palavras do jogador, sem artigo. Se o jogador nomear um \
        item pra usar (\"corta o feno com a faca\"), o alvo é \"feno\" e o instrumento é \"faca\".

        Contexto atual (só pra você reconhecer os alvos — não repita isso na resposta):
        - Lugar: \(beat.overview)
        - Coisas visíveis: \(visible)
        - Saídas: \(exits)
        - A personagem carrega: \(carried.isEmpty ? "nada" : carried)
        """

        let session = LanguageModelSession(instructions: instructions)

        do {
            let response = try await session.respond(to: playerText, generating: InterpretedAction.self)
            let content = response.content
            let verb = Verb(rawValue: content.verb.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) ?? .unknown
            let tone = Tone(rawValue: content.tone.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) ?? .neutral

            // The model likes to helpfully fill in a tool she happens to be carrying, which
            // silently spends items the player never mentioned. Only honour an instrument the
            // player actually wrote.
            let spoken = playerText.folded
            let instrument = content.instrument.isEmpty ? nil : content.instrument
            let confirmedInstrument = instrument.flatMap { candidate -> String? in
                let named = ItemID.allCases.contains { item in
                    item.aliases.contains { alias in
                        candidate.folded.contains(alias.folded) && spoken.contains(alias.folded)
                    }
                }
                return named ? candidate : nil
            }
            if instrument != nil, confirmedInstrument == nil {
                print("FoundationModelsActionParser: dropped invented instrument \"\(instrument!)\" — not present in \"\(playerText)\"")
            }

            // Moving is the only verb that changes the scene, so it's the only one whose
            // mistakes the player really notices. If the model wants to move her, the player
            // has to have actually said something about moving — otherwise "quem é você?"
            // can walk her down the road.
            if verb == .go, !Self.mentionsMovement(spoken) {
                print("FoundationModelsActionParser: refused to move on \"\(playerText)\" — no movement language in it")
                return PlayerAction(verb: .unknown, tone: tone)
            }

            return PlayerAction(
                verb: verb,
                target: content.target.isEmpty ? nil : content.target,
                instrument: confirmedInstrument,
                tone: tone
            )
        } catch {
            print("FoundationModelsActionParser: generation failed for \"\(playerText)\": \(error)")
            return PlayerAction(verb: .unknown)
        }
    }
}
