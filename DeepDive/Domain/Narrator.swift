//
//  Narrator.swift
//  DeepDive
//

import Foundation

/// Everything the narrator is allowed to know. `facts` are authoritative — it may rephrase
/// them, never contradict or extend them.
struct NarrationRequest {
    let facts: [String]
    let sanity: Int
    let placeSummary: String
    let carrying: [String]
    let history: [ChatMessage]
}

protocol Narrator {
    func narrate(_ request: NarrationRequest) async -> String
}

/// Returns the facts unchanged. Safe compile-time fallback and the default in tests — the
/// authored facts are already valid pt-BR on their own.
struct StaticNarrator: Narrator {
    func narrate(_ request: NarrationRequest) async -> String {
        request.facts.joined(separator: " ")
    }
}
