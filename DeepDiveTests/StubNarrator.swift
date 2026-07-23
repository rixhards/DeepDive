//
//  StubNarrator.swift
//  DeepDiveTests
//

import Foundation
@testable import DeepDive

/// Configurable `Narrator` stand-in for asserting the ViewModel actually uses the
/// narrator's output (and passes it the right state), without calling Foundation Models.
struct StubNarrator: Narrator {
    let result: @Sendable (String, Int, Int, [ChatMessage]) -> String

    func narrate(brief: String, sanity: Int, trust: Int, history: [ChatMessage]) async -> String {
        result(brief, sanity, trust, history)
    }
}
