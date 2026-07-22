//
//  EngineResponse.swift
//  DeepDive
//

import Foundation

struct EngineOption: Equatable {
    let id: String
    let text: String
}

struct EngineResponse: Equatable {
    let nodeID: String
    let characterText: String
    let options: [EngineOption]
    let isTerminal: Bool
}
