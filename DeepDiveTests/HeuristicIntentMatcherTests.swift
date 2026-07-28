//
//  HeuristicIntentMatcherTests.swift
//  DeepDiveTests
//

import XCTest
@testable import DeepDive

final class HeuristicIntentMatcherTests: XCTestCase {
    private let options = [
        EngineOption(id: "opt_who", text: "quem é você?", hints: ["quem fala", "quem é vc", "me diz seu nome"]),
        EngineOption(id: "opt_where", text: "onde você está?", hints: ["cadê você", "onde vc tá", "que lugar é esse"]),
    ]

    func testMatchesOnExactText() {
        XCTAssertEqual(HeuristicIntentMatcher.bestMatch(for: "onde você está?", among: options), "opt_where")
    }

    func testMatchesDivergentPhrasingViaHint() {
        XCTAssertEqual(HeuristicIntentMatcher.bestMatch(for: "cadê vc", among: options), "opt_where")
        XCTAssertEqual(HeuristicIntentMatcher.bestMatch(for: "quem fala", among: options), "opt_who")
    }

    func testIsAccentAndCaseInsensitive() {
        XCTAssertEqual(HeuristicIntentMatcher.bestMatch(for: "CADÊ VOCÊ", among: options), "opt_where")
    }

    func testReturnsNilForUnrelatedInput() {
        XCTAssertNil(HeuristicIntentMatcher.bestMatch(for: "tá muito frio hoje", among: options))
    }

    func testReturnsNilForEmptyInput() {
        XCTAssertNil(HeuristicIntentMatcher.bestMatch(for: "   ", among: options))
    }

    func testStopwordOnlyOverlapDoesNotCountAsAMatch() {
        // "você" alone is common to both options' vocabulary and carries no
        // discriminating signal — should not be enough to force a guess.
        XCTAssertNil(HeuristicIntentMatcher.bestMatch(for: "você", among: options))
    }

    func testTiedScoresReturnNilRatherThanGuessing() {
        let tiedOptions = [
            EngineOption(id: "opt_a", text: "abre a porta", hints: []),
            EngineOption(id: "opt_b", text: "abre a janela", hints: []),
        ]
        // "abre" matches both equally; neither "porta" nor "janela" is mentioned.
        XCTAssertNil(HeuristicIntentMatcher.bestMatch(for: "abre", among: tiedOptions))
    }

    func testSingleWordOptionsWithNoHintsStillMatchExactly() {
        let singleOption = [EngineOption(id: "opt_hurry", text: "então anda, rápido", hints: [])]
        XCTAssertEqual(HeuristicIntentMatcher.bestMatch(for: "anda rápido", among: singleOption), "opt_hurry")
    }
}
