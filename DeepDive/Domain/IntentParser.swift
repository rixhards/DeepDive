//
//  IntentParser.swift
//  DeepDive
//

import Foundation

enum IntentResult: Equatable {
    case match(optionID: String)
    case clarify
}

protocol IntentParser {
    func parse(playerText: String, options: [EngineOption]) async -> IntentResult
}
