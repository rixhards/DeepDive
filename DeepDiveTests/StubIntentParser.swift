//
//  StubIntentParser.swift
//  DeepDiveTests
//

import Foundation
@testable import DeepDive

/// Deterministic `IntentParser` stand-in — real natural-language matching isn't
/// something a unit test can assert on, so tests configure the exact outcome instead.
struct StubIntentParser: IntentParser {
    let result: @Sendable (String, [EngineOption]) -> IntentResult

    func parse(playerText: String, options: [EngineOption]) async -> IntentResult {
        result(playerText, options)
    }

    /// Always resolves to the first currently valid option — matches how the fixture
    /// stories in these tests are shaped (one option per node until the terminal node).
    static var matchesFirstOption: StubIntentParser {
        StubIntentParser { _, options in
            options.first.map { .match(optionID: $0.id) } ?? .clarify
        }
    }

    static var alwaysClarifies: StubIntentParser {
        StubIntentParser { _, _ in .clarify }
    }
}
