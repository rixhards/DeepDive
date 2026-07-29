//
//  World.swift
//  DeepDive
//
//  The authoritative game state. Everything the player can learn about the world is derived
//  from here — the AI reads it and describes it, but never writes to it (ADR-002).

import Foundation

enum PlaceID: String, Codable, CaseIterable {
    case salao
    case trifurcacao
    case hayRoom
    case escadaria
    case cisterna
    case coroa
}

enum ItemID: String, Codable, CaseIterable {
    case knife
    case lamp
    case key
    case seal

    /// How she refers to it.
    var name: String {
        switch self {
        case .knife: "uma faca pequena"
        case .lamp: "um lampião"
        case .key: "uma chave"
        case .seal: "um disco de pedra"
        }
    }

    /// What she notices when she looks at it properly.
    var detail: String {
        switch self {
        case .knife: "uma faca pequena, lâmina curta, meio cega. serve pra cortar alguma coisa mole, não muito mais que isso."
        case .lamp: "um lampião com mais ou menos metade do combustível. dá pra acender e apagar."
        case .key: "uma chave de ferro, pesada, com a cabeça torta. parece antiga."
        case .seal: "um disco de pedra do tamanho da minha mão, com os mesmos símbolos entalhados em volta da borda. é mais pesado do que devia ser."
        }
    }

    /// Words the player might use for it.
    var aliases: [String] {
        switch self {
        case .knife: ["faca", "lâmina", "canivete"]
        case .lamp: ["lampião", "lamparina", "lanterna", "luz", "lampiao"]
        case .key: ["chave", "chavinha"]
        case .seal: ["disco", "selo", "medalhão", "medalhao", "pedra redonda", "disco de pedra"]
        }
    }
}

enum Flag: String, Codable {
    case lampLit
    case knockedWoodDoor
    case warnedAboutWaiting
    case knifeBroken
    case sawCorridorHint
    case sawFalseLight
    case heardTheMusic
}

enum Ending: String, Codable {
    case escape
    case surrender
    case taken
}

/// Everything that persists about a run.
struct World: Codable, Equatable {
    var place: PlaceID = .salao
    var inventory: Set<ItemID> = [.knife, .lamp]
    var flags: Set<Flag> = []
    var visited: Set<PlaceID> = [.salao]
    var sanity: Int = 80
    var ending: Ending?
    /// How many times she has studied the carvings. Each reading takes more of her, and the
    /// last one finishes the job — this is the road to the surrender ending.
    var symbolReadings: Int = 0
    /// Reassurance works, but not forever. She notices when it becomes a routine.
    var comfortsTaken: Int = 0
    /// An irreversible move she's standing at the edge of, waiting for a yes or a no.
    var pending: PendingChoice?
    /// Counts her turns, only so repeated refusals can be phrased differently each time.
    var turns: Int = 0

    var isOver: Bool { ending != nil }

    mutating func adjustSanity(by delta: Int) {
        sanity = min(100, max(0, sanity + delta))
        // Losing her mind overrides whatever else was about to happen.
        if sanity == 0, ending == nil {
            ending = .surrender
        }
    }

    func has(_ item: ItemID) -> Bool { inventory.contains(item) }
    func has(_ flag: Flag) -> Bool { flags.contains(flag) }
}
