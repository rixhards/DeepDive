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
}
