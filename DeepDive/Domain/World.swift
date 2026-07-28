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
    case pastIronDoor
}

enum ItemID: String, Codable, CaseIterable {
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

    /// What she notices when she looks at it properly.
    var detail: String {
        switch self {
        case .knife: "uma faca pequena, lâmina curta, meio cega. serve pra cortar alguma coisa mole, não muito mais que isso."
        case .lamp: "um lampião com mais ou menos metade do combustível. dá pra acender e apagar."
        case .key: "uma chave de ferro, pesada, com a cabeça torta. parece antiga."
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

enum Flag: String, Codable {
    case lampLit
    case knockedWoodDoor
    case warnedAboutWaiting
    case knifeBroken
    case sawCorridorHint
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
