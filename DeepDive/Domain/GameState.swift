//
//  GameState.swift
//  DeepDive
//
//  The authoritative game state. The AI reads this but never writes to it (ADR-002):
//  ActionResolver is the only thing allowed to mutate a GameState.

import Foundation

/// The unit of story progression. Each beat is a scene; LLM sessions are reset at beat
/// boundaries (see ARCHITECTURE.md, "context strategy").
nonisolated enum BeatID: String, Codable, CaseIterable, Sendable {
    case salao         // Salão Principal (spawn)
    case waterTrail    // Trilha na Água (fatal)
    case trifurcacao   // Trifurcação (hub)
    case corridor      // Corredor Escuro
    case steelDoor     // Beyond the steel door (cave → the way out)
    case hayRoom       // Sala da Porta de Madeira
}

nonisolated enum ItemID: String, Codable, CaseIterable, Sendable {
    case knife
    case lamp
    case key

    /// How she refers to it.
    var name: String {
        switch self {
        case .knife: "uma faca pequena"
        case .lamp: "um lampião"
        case .key: "uma chave"
        }
    }

    /// What she notices when she looks at it properly. The lamp's fuel state is appended by
    /// the resolver, which is the only thing that knows how much oil is left.
    var detail: String {
        switch self {
        case .knife: "uma faca pequena, lâmina curta, meio cega. serve pra cortar alguma coisa mole, não muito mais que isso."
        case .lamp: "um lampião de metal, com um pavio e um reservatório de óleo. dá pra acender e apagar."
        case .key: "uma chave de ferro, pesada, com a cabeça torta. parece antiga. tem que ser da porta de aço."
        }
    }

    /// Words the player might use for it.
    var aliases: [String] {
        switch self {
        case .knife: ["faca", "lâmina", "canivete"]
        case .lamp: ["lampião", "lamparina", "lanterna", "luz", "lampiao"]
        case .key: ["chave", "chavinha"]
        }
    }
}

nonisolated enum StoryFlag: String, Codable, Sendable {
    case lampLit
    /// The oil ran out. The lamp can never be lit again.
    case lampDead
    case knockedWoodDoor
    /// Broken forcing the steel door's lock.
    case knifeBroken
    /// Lost pushing the hay aside — spent, not broken.
    case knifeLostInHay
}

nonisolated enum Ending: String, Codable, Sendable {
    case escape     // The only good ending (3 sanity variants of the same ending)
    case death      // 4 different scenarios: water, corridor, hay monster, hay fire
    case madness    // Sanity reached 0
}

/// Authoritative game state. `GameState` + `StoryMemory` is the save file; the LLM session
/// is discardable and gets rebuilt from these at beat boundaries.
nonisolated struct GameState: Codable, Sendable, Equatable {
    /// Scenes of light the lamp starts with. One unit burns per beat transition while lit.
    static let initialLampFuel = 5
    static let initialSanity = 80
    /// How many hostile/abandoning messages she takes before she stops believing anyone is
    /// coming. Reaching it ends the run regardless of sanity — being left alone in there is
    /// its own way to die.
    static let abandonmentLimit = 3

    var currentBeat: BeatID = .salao
    // She wakes up with the lamp in her hand, already lit. The knife is on the salão floor.
    var flags: Set<StoryFlag> = [.lampLit]
    var sanity: Int = GameState.initialSanity
    /// Counts turns, so repeated situations can be phrased differently each time.
    var turn: Int = 0
    var isFinished: Bool = false
    var inventory: Set<ItemID> = [.lamp]
    var lampFuel: Int = GameState.initialLampFuel
    var ending: Ending?
    /// An irreversible move she's standing at the edge of, waiting for a yes or a no.
    var pending: PendingChoice?
    var visited: Set<BeatID> = [.salao]
    /// How many times she's been reassured — only for varying her replies.
    var comfortsTaken: Int = 0
    /// How many times she's studied the carvings; each reading costs more than the last.
    var symbolReadings: Int = 0
    /// How many distressing messages the player has sent. Each one costs more than the last,
    /// and `abandonmentLimit` of them ends the run.
    var distressStrikes: Int = 0

    /// What a distressing message costs right now. The first sting is the authored −4; every
    /// repeat digs deeper, because being told nobody is coming lands harder the third time.
    var nextDistressCost: Int {
        -4 * (distressStrikes + 1)
    }

    /// The one door into finishing a run — keeps `ending` and `isFinished` in lockstep.
    /// The first ending reached wins; nothing overrides it.
    mutating func finish(_ reached: Ending) {
        guard ending == nil else { return }
        ending = reached
        isFinished = true
    }

    mutating func adjustSanity(by delta: Int) {
        sanity = min(100, max(0, sanity + delta))
        // Losing her mind overrides whatever else was about to happen.
        if sanity == 0 {
            finish(.madness)
        }
    }

    func has(_ item: ItemID) -> Bool { inventory.contains(item) }
    func has(_ flag: StoryFlag) -> Bool { flags.contains(flag) }
}
