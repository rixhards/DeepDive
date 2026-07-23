//
//  NarratorTests.swift
//  DeepDiveTests
//

import XCTest
@testable import DeepDive

final class NarratorTests: XCTestCase {
    func testStaticNarratorReturnsBriefUnchanged() async {
        let narrator = StaticNarrator()
        let result = await narrator.narrate(brief: "a personagem está com medo", sanity: 30, trust: 90, history: [])
        XCTAssertEqual(result, "a personagem está com medo")
    }
}
