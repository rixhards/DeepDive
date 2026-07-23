//
//  Narrator.swift
//  DeepDive
//

import Foundation

protocol Narrator {
    func narrate(brief: String, sanity: Int, trust: Int, history: [ChatMessage]) async -> String
}

/// Returns the brief unchanged. Used as the default in tests and as a safe compile-time
/// fallback — the JSON node text is always a valid (if generic) message on its own.
struct StaticNarrator: Narrator {
    func narrate(brief: String, sanity: Int, trust: Int, history: [ChatMessage]) async -> String {
        brief
    }
}
