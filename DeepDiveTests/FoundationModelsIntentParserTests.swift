//
//  FoundationModelsIntentParserTests.swift
//  DeepDiveTests
//
//  Real on-device inference can't be asserted on in this environment (no Apple
//  Intelligence in CI/simulator test runs), so this only covers the deterministic
//  paths that don't depend on the model actually responding.

import XCTest
@testable import DeepDive

final class FoundationModelsIntentParserTests: XCTestCase {
    func testEmptyOptionsListReturnsClarifyWithoutCallingTheModel() async {
        let parser = FoundationModelsIntentParser()
        let result = await parser.parse(playerText: "qualquer coisa", options: [])
        XCTAssertEqual(result, .clarify)
    }

    func testSingleOptionAlwaysMatchesRegardlessOfInput() async {
        let parser = FoundationModelsIntentParser()
        let options = [EngineOption(id: "opt_only", text: "então anda, rápido")]

        let result = await parser.parse(playerText: "isso não tem nada a ver com nada", options: options)

        XCTAssertEqual(result, .match(optionID: "opt_only"))
    }

    func testHeuristicMatchResolvesWithoutNeedingTheModel() async {
        let parser = FoundationModelsIntentParser()
        let options = [
            EngineOption(id: "opt_who", text: "quem é você?", hints: ["quem fala"]),
            EngineOption(id: "opt_where", text: "onde você está?", hints: ["cadê você"]),
        ]

        // Resolved by HeuristicIntentMatcher before the model-availability check is ever
        // reached — deterministic, and doesn't depend on Foundation Models being present.
        let result = await parser.parse(playerText: "cadê você", options: options)

        XCTAssertEqual(result, .match(optionID: "opt_where"))
    }
}
