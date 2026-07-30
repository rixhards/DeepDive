//
//  StoryMemory.swift
//  DeepDive
//
//  Context for the LLM session. Discardable — everything except `recentNarrative` is
//  derived from GameState, so a session can be rebuilt at any beat boundary without the
//  full chat history ever entering a prompt (ARCHITECTURE.md, "context strategy").
//
//  The strings are pt-BR because their only consumer is the pt-BR prompt.

import Foundation

nonisolated struct StoryMemory: Codable, Sendable, Equatable {
    /// Core facts that never change (setting, premise).
    var immutableFacts: [String]
    /// What she's trying to do right now.
    var currentObjectives: [String]
    /// Things learned during play.
    var discoveredInformation: Set<String>
    /// The last few exchanges, NOT the full history.
    var recentNarrative: [String]

    /// How many narrative lines are worth carrying across turns. Small on purpose: the
    /// whole budget is 4096 tokens and the session transcript grows on its own mid-beat.
    static let recentNarrativeLimit = 6

    static func initial() -> StoryMemory {
        rebuild(from: GameState(), keepingRecent: [])
    }

    /// Rebuilds the memory from the authoritative state, carrying over only the recent
    /// narrative lines. Called at beat boundaries and after loading a save.
    static func rebuild(from state: GameState, keepingRecent recent: [String]) -> StoryMemory {
        StoryMemory(
            // Deliberately NOT a description of the setting. Anything atmospheric listed
            // here came straight back out of the model in every single message ("tá tudo
            // escuro e úmido"), which is how she started sounding like a loop. The place is
            // described by the beat's own authored text, when the facts call for it.
            immutableFacts: [
                "ela acordou sozinha neste lugar, sem lembrar como chegou.",
                "ela não lembra o próprio nome.",
                "ela fala por mensagens com um estranho anônimo — a única pessoa que respondeu.",
                "ela já se acostumou com o ambiente e NÃO fica redescrevendo o lugar.",
            ],
            currentObjectives: objectives(for: state),
            discoveredInformation: discoveries(for: state),
            recentNarrative: Array(recent.suffix(recentNarrativeLimit))
        )
    }

    /// Appends one exchange, keeping only the newest lines.
    mutating func noteExchange(playerText: String, reply: String) {
        recentNarrative.append("jogador: \(playerText)")
        recentNarrative.append("ela: \(reply)")
        recentNarrative = Array(recentNarrative.suffix(Self.recentNarrativeLimit))
    }

    private static func objectives(for state: GameState) -> [String] {
        if state.has(.key) {
            return ["abrir a porta de aço da trifurcação com a chave e sair daqui."]
        }
        if state.visited.contains(.hayRoom), !state.has(.key) {
            return ["pegar a chave que brilha no meio do feno e abrir a porta de aço."]
        }
        return ["encontrar um jeito de sair deste lugar."]
    }

    private static func discoveries(for state: GameState) -> Set<String> {
        var facts: Set<String> = []
        if state.has(.knife) { facts.insert("ela achou uma faca pequena no chão do salão.") }
        if state.has(.key) { facts.insert("ela está com a chave da porta de aço.") }
        if state.has(.knifeBroken) { facts.insert("a faca quebrou quando ela tentou forçar a fechadura da porta de aço.") }
        if state.has(.knifeLostInHay) { facts.insert("a faca ficou perdida dentro do feno.") }
        if state.has(.knockedWoodDoor) { facts.insert("ela bateu na porta de madeira e alguma coisa se arrastou pra longe.") }
        if state.has(.lampDead) {
            facts.insert("o lampião apagou de vez — o óleo acabou e não acende mais.")
        } else if state.lampFuel <= 1 {
            facts.insert("o óleo do lampião está quase no fim.")
        }
        if state.visited.contains(.trifurcacao) {
            facts.insert("da trifurcação saem três caminhos: um corredor escuro, uma porta de aço trancada e uma porta de madeira sem trava.")
        }
        return facts
    }
}
